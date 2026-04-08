import Foundation

/// 异常检测器 - 智能判断 CPU 异常占用
class AnomalyDetector {
    static let shared = AnomalyDetector()
    
    /// 进程历史快照缓存 [bundleIdentifier: [Snapshot]]
    private var processHistory: [String: [ProcessSnapshot]] = [:]
    
    /// 异常开始时间 [bundleIdentifier: Date]
    private var anomalyStartTimes: [String: Date] = [:]
    
    /// 上次通知时间（防止频繁通知）
    private var lastNotificationTimes: [String: Date] = [:]
    
    /// 最小通知间隔（秒）
    private let minNotificationInterval: TimeInterval = 300  // 5分钟
    
    private init() {}
    
    /// 分析进程状态，检测异常
    func analyze(processInfo: ProcessInfo, app: MonitoredApp) -> AnomalyResult? {
        let now = Date()
        let bundleId = app.bundleIdentifier
        
        // 如果应用被禁用或在白名单中，跳过检测
        guard app.isEnabled && !app.isWhitelisted else { return nil }
        
        // 记录快照
        let snapshot = ProcessSnapshot(
            timestamp: now,
            processIdentifier: processInfo.pid,
            bundleIdentifier: bundleId,
            processName: processInfo.processName,
            cpuUsage: processInfo.cpuUsage,
            memoryUsage: processInfo.memoryUsage,
            isForeground: processInfo.isForeground,
            isActive: processInfo.isActive
        )
        
        // 更新历史记录（保留最近 60 个快照，约 1 分钟）
        if processHistory[bundleId] == nil {
            processHistory[bundleId] = []
        }
        processHistory[bundleId]?.append(snapshot)
        if processHistory[bundleId]!.count > 60 {
            processHistory[bundleId]?.removeFirst()
        }
        
        // 检测异常
        let anomaly = detectAnomaly(snapshot: snapshot, app: app, history: processHistory[bundleId] ?? [])
        
        // 更新异常状态
        if let result = anomaly {
            anomalyStartTimes[bundleId] = now
        } else {
            anomalyStartTimes.removeValue(forKey: bundleId)
        }
        
        return anomaly
    }
    
    /// 核心异常检测逻辑
    private func detectAnomaly(snapshot: ProcessSnapshot, app: MonitoredApp, history: [ProcessSnapshot]) -> AnomalyResult? {
        let now = Date()
        
        // 检查通知冷却
        if let lastTime = lastNotificationTimes[app.bundleIdentifier],
           now.timeIntervalSince(lastTime) < minNotificationInterval {
            return nil
        }
        
        // 策略 1: 前台活跃应用 - 更宽松的阈值
        if snapshot.isForeground && snapshot.isActive {
            // 前台活跃应用，用户正在使用，使用更高阈值
            let foregroundThreshold = app.cpuThreshold * 2.5  // 例如 30% -> 75%
            if snapshot.cpuUsage > foregroundThreshold {
                // 即使前台，如果 CPU 极高，也提醒（可能是卡死）
                let duration = getHighCPUDuration(history: history, threshold: foregroundThreshold)
                if duration >= 60 {  // 持续 60 秒
                    lastNotificationTimes[app.bundleIdentifier] = now
                    return AnomalyResult(
                        app: app,
                        detectedAt: now,
                        cpuUsage: snapshot.cpuUsage,
                        duration: duration,
                        isBackground: false,
                        severity: .medium,
                        reason: "前台应用 CPU 占用极高(\(String(format: "%.1f", snapshot.cpuUsage))%)，可能存在卡顿"
                    )
                }
            }
            return nil  // 前台活跃应用，正常使用，不报警
        }
        
        // 策略 2: 后台应用 - 主要检测场景
        if !snapshot.isForeground {
            // 后台应用 CPU 超过阈值
            if snapshot.cpuUsage > app.cpuThreshold {
                let duration = getHighCPUDuration(history: history, threshold: app.cpuThreshold)
                
                // 检查是否持续足够时间
                if duration >= app.backgroundDuration {
                    // 分析趋势：CPU 是否在上升
                    let trend = analyzeTrend(history: history)
                    
                    let severity: AnomalySeverity
                    var reason: String
                    
                    if trend == .increasing {
                        severity = .high
                        reason = "后台 CPU 占用持续上升(\(String(format: "%.1f", snapshot.cpuUsage))%)，建议检查"
                    } else if trend == .stable {
                        severity = .medium
                        reason = "后台 CPU 占用持续偏高(\(String(format: "%.1f", snapshot.cpuUsage))%)"
                    } else {
                        severity = .low
                        reason = "后台 CPU 占用较高但正在下降(\(String(format: "%.1f", snapshot.cpuUsage))%)"
                    }
                    
                    lastNotificationTimes[app.bundleIdentifier] = now
                    return AnomalyResult(
                        app: app,
                        detectedAt: now,
                        cpuUsage: snapshot.cpuUsage,
                        duration: duration,
                        isBackground: true,
                        severity: severity,
                        reason: reason
                    )
                }
            }
        }
        
        // 策略 3: 前台但不活跃（用户可能切换了窗口但应用还在前台）
        if snapshot.isForeground && !snapshot.isActive {
            if snapshot.cpuUsage > app.cpuThreshold * 1.5 {  // 中等阈值
                let duration = getHighCPUDuration(history: history, threshold: app.cpuThreshold * 1.5)
                if duration >= app.backgroundDuration * 1.5 {
                    lastNotificationTimes[app.bundleIdentifier] = now
                    return AnomalyResult(
                        app: app,
                        detectedAt: now,
                        cpuUsage: snapshot.cpuUsage,
                        duration: duration,
                        isBackground: false,
                        severity: .medium,
                        reason: "前台但非活跃窗口，CPU 占用较高(\(String(format: "%.1f", snapshot.cpuUsage))%)"
                    )
                }
            }
        }
        
        return nil
    }
    
    /// 获取 CPU 超过阈值的持续时间
    private func getHighCPUDuration(history: [ProcessSnapshot], threshold: Double) -> TimeInterval {
        guard !history.isEmpty else { return 0 }
        
        var duration: TimeInterval = 0
        let interval: TimeInterval = 1.0  // 假设每秒采样一次
        
        // 从最近的快照往前查找
        for snapshot in history.reversed() {
            if snapshot.cpuUsage > threshold {
                duration += interval
            } else {
                break
            }
        }
        
        return duration
    }
    
    /// 分析 CPU 使用趋势
    private func analyzeTrend(history: [ProcessSnapshot]) -> CPUTrend {
        guard history.count >= 10 else { return .stable }
        
        let recentHistory = Array(history.suffix(10))
        
        // 计算前半段和后半段的平均 CPU
        let firstHalf = recentHistory.prefix(5)
        let secondHalf = recentHistory.suffix(5)
        
        let firstAvg = firstHalf.reduce(0) { $0 + $1.cpuUsage } / 5.0
        let secondAvg = secondHalf.reduce(0) { $0 + $1.cpuUsage } / 5.0
        
        let change = secondAvg - firstAvg
        
        if change > 5 {
            return .increasing
        } else if change < -5 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    /// 重置指定应用的检测状态
    func reset(for bundleIdentifier: String) {
        processHistory.removeValue(forKey: bundleIdentifier)
        anomalyStartTimes.removeValue(forKey: bundleIdentifier)
        lastNotificationTimes.removeValue(forKey: bundleIdentifier)
    }
    
    /// 重置所有状态
    func resetAll() {
        processHistory.removeAll()
        anomalyStartTimes.removeAll()
        lastNotificationTimes.removeAll()
    }
}

/// CPU 使用趋势
enum CPUTrend {
    case increasing  // 上升
    case decreasing  // 下降
    case stable      // 稳定
}