import Foundation

/// 被监控的应用信息
struct MonitoredApp: Identifiable, Codable, Hashable {
    var id: String { bundleIdentifier }
    
    let bundleIdentifier: String
    let name: String
    var isEnabled: Bool = true
    var cpuThreshold: Double = 30.0  // CPU 阈值百分比
    var backgroundDuration: TimeInterval = 30.0  // 后台持续时间阈值（秒）
    var isWhitelisted: Bool = false  // 白名单标记
    
    init(bundleIdentifier: String, name: String, isEnabled: Bool = true, 
         cpuThreshold: Double = 30.0, backgroundDuration: TimeInterval = 30.0) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.isEnabled = isEnabled
        self.cpuThreshold = cpuThreshold
        self.backgroundDuration = backgroundDuration
    }
    
    static func == (lhs: MonitoredApp, rhs: MonitoredApp) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }
}

/// 进程状态快照
struct ProcessSnapshot: Codable {
    let timestamp: Date
    let processIdentifier: Int32
    let bundleIdentifier: String
    let processName: String
    let cpuUsage: Double
    let memoryUsage: UInt64
    let isForeground: Bool
    let isActive: Bool  // 用户是否正在交互
    
    var isHighCPU: Bool {
        cpuUsage > 30.0
    }
}

/// 异常检测结果
struct AnomalyResult: Identifiable {
    let id = UUID()
    let app: MonitoredApp
    let detectedAt: Date
    let cpuUsage: Double
    let duration: TimeInterval
    let isBackground: Bool
    let severity: AnomalySeverity
    let reason: String
}

enum AnomalySeverity: String, Codable {
    case low = "低"
    case medium = "中"
    case high = "高"
}

/// 监控历史记录
struct MonitoringHistory: Identifiable, Codable {
    let id = UUID()
    let appName: String
    let bundleIdentifier: String
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: UInt64
    let duration: TimeInterval
    let action: String  // "notified", "ignored", "terminated"
}