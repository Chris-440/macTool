import Foundation
import Combine
import UserNotifications
import AppKit

/// 监控服务 - 主服务，协调进程监控和异常检测
class MonitorService: ObservableObject {
    static let shared = MonitorService()
    
    @Published var isRunning = false
    @Published var currentProcesses: [ProcessInfo] = []
    
    private var timer: Timer?
    private var detector = AnomalyDetector.shared
    private let monitorInterval: TimeInterval = 1.0  // 每秒采样一次
    
    private init() {}
    
    /// 开始监控
    func startMonitoring() {
        guard !isRunning else { return }
        
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: monitorInterval, repeats: true) { [weak self] _ in
            self?.performMonitoringCycle()
        }
        
        // 立即执行一次
        performMonitoringCycle()
    }
    
    /// 停止监控
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
    
    /// 执行一次监控周期
    private func performMonitoringCycle() {
        let processMonitor = ProcessMonitor.shared
        let appState = AppState.shared
        
        // 获取所有运行中的进程
        let processes = processMonitor.getRunningApplications()
        currentProcesses = processes
        
        // 获取需要监控的应用
        let monitoredApps = appState.monitoredApps.filter { $0.isEnabled }
        
        // 检查每个被监控的应用
        for app in monitoredApps {
            guard let processInfo = processes.first(where: { $0.bundleIdentifier == app.bundleIdentifier }) else {
                continue
            }
            
            // 进行异常检测
            if let anomaly = detector.analyze(processInfo: processInfo, app: app) {
                handleAnomaly(anomaly, processInfo: processInfo)
            }
        }
        
        // 清理已结束进程的异常
        cleanupEndedProcesses()
    }
    
    /// 处理检测到的异常
    private func handleAnomaly(_ anomaly: AnomalyResult, processInfo: ProcessInfo) {
        DispatchQueue.main.async {
            let appState = AppState.shared
            
            // 添加到当前异常列表（避免重复）
            if !appState.currentAnomalies.contains(where: { $0.app.bundleIdentifier == anomaly.app.bundleIdentifier }) {
                appState.currentAnomalies.append(anomaly)
            }
            
            // 发送通知
            self.sendNotification(for: anomaly)
            
            // 记录历史
            let history = MonitoringHistory(
                appName: anomaly.app.name,
                bundleIdentifier: anomaly.app.bundleIdentifier,
                timestamp: anomaly.detectedAt,
                cpuUsage: anomaly.cpuUsage,
                memoryUsage: processInfo.memoryUsage,
                duration: anomaly.duration,
                action: "notified"
            )
            appState.addHistory(history)
        }
    }
    
    /// 发送系统通知
    private func sendNotification(for anomaly: AnomalyResult) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ \(anomaly.app.name) CPU 异常"
        content.body = anomaly.reason
        content.sound = .default
        content.categoryIdentifier = "CPU_ALERT"
        
        // 添加操作按钮
        let terminateAction = UNNotificationAction(
            identifier: "TERMINATE",
            title: "退出应用",
            options: [.destructive]
        )
        let ignoreAction = UNNotificationAction(
            identifier: "IGNORE",
            title: "忽略",
            options: []
        )
        let whitelistAction = UNNotificationAction(
            identifier: "WHITELIST",
            title: "加入白名单",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "CPU_ALERT",
            actions: [terminateAction, ignoreAction, whitelistAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
        
        let request = UNNotificationRequest(
            identifier: anomaly.app.bundleIdentifier,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    /// 清理已结束进程的异常记录
    private func cleanupEndedProcesses() {
        DispatchQueue.main.async {
            let appState = AppState.shared
            let runningBundleIds = self.currentProcesses.map { $0.bundleIdentifier }
            
            appState.currentAnomalies.removeAll { anomaly in
                !runningBundleIds.contains(anomaly.app.bundleIdentifier)
            }
        }
    }
    
    /// 手动终止应用
    func terminateApp(_ bundleIdentifier: String) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            return
        }
        
        app.terminate()
        
        // 记录操作
        DispatchQueue.main.async {
            let appState = AppState.shared
            if let anomaly = appState.currentAnomalies.first(where: { $0.app.bundleIdentifier == bundleIdentifier }) {
                let history = MonitoringHistory(
                    appName: anomaly.app.name,
                    bundleIdentifier: bundleIdentifier,
                    timestamp: Date(),
                    cpuUsage: anomaly.cpuUsage,
                    memoryUsage: 0,
                    duration: anomaly.duration,
                    action: "terminated"
                )
                appState.addHistory(history)
            }
            
            appState.currentAnomalies.removeAll { $0.app.bundleIdentifier == bundleIdentifier }
        }
    }
    
    /// 忽略异常
    func ignoreAnomaly(_ bundleIdentifier: String) {
        DispatchQueue.main.async {
            let appState = AppState.shared
            appState.currentAnomalies.removeAll { $0.app.bundleIdentifier == bundleIdentifier }
        }
    }
    
    /// 添加到白名单
    func addToWhitelist(_ bundleIdentifier: String) {
        DispatchQueue.main.async {
            let appState = AppState.shared
            if let index = appState.monitoredApps.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier }) {
                appState.monitoredApps[index].isWhitelisted = true
                appState.saveMonitoredApps()
            }
            appState.currentAnomalies.removeAll { $0.app.bundleIdentifier == bundleIdentifier }
        }
    }
}