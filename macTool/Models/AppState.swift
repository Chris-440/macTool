import SwiftUI
import Combine

/// 全局应用状态
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var monitoredApps: [MonitoredApp] = []
    @Published var currentAnomalies: [AnomalyResult] = []
    @Published var history: [MonitoringHistory] = []
    @Published var isMonitoring: Bool = true
    
    var statusIcon: String {
        if !isMonitoring {
            return "pause.circle"
        }
        if !currentAnomalies.isEmpty {
            return "exclamationmark.triangle.fill"
        }
        return "checkmark.circle"
    }
    
    private let monitoredAppsKey = "monitoredApps"
    private let historyKey = "monitoringHistory"
    
    private init() {
        loadMonitoredApps()
        loadHistory()
        
        // 添加默认监控应用（如果为空）
        if monitoredApps.isEmpty {
            let defaultApps = [
                MonitoredApp(bundleIdentifier: "com.microsoft.edgemac", name: "Microsoft Edge", cpuThreshold: 30.0),
                MonitoredApp(bundleIdentifier: "com.i4tools.i4tools", name: "爱思助手", cpuThreshold: 25.0),
                MonitoredApp(bundleIdentifier: "com.apple.Safari", name: "Safari", cpuThreshold: 35.0),
                MonitoredApp(bundleIdentifier: "com.google.Chrome", name: "Google Chrome", cpuThreshold: 30.0),
                MonitoredApp(bundleIdentifier: "com.electron.wechat", name: "微信", cpuThreshold: 20.0),
            ]
            monitoredApps = defaultApps
            saveMonitoredApps()
        }
    }
    
    func saveMonitoredApps() {
        if let encoded = try? JSONEncoder().encode(monitoredApps) {
            UserDefaults.standard.set(encoded, forKey: monitoredAppsKey)
        }
    }
    
    func loadMonitoredApps() {
        if let data = UserDefaults.standard.data(forKey: monitoredAppsKey),
           let decoded = try? JSONDecoder().decode([MonitoredApp].self, from: data) {
            monitoredApps = decoded
        }
    }
    
    func saveHistory() {
        // 只保留最近 100 条记录
        let recentHistory = Array(history.suffix(100))
        if let encoded = try? JSONEncoder().encode(recentHistory) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }
    
    func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([MonitoringHistory].self, from: data) {
            history = decoded
        }
    }
    
    func addMonitoredApp(_ app: MonitoredApp) {
        if !monitoredApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            monitoredApps.append(app)
            saveMonitoredApps()
        }
    }
    
    func removeMonitoredApp(_ app: MonitoredApp) {
        monitoredApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
        saveMonitoredApps()
    }
    
    func updateMonitoredApp(_ app: MonitoredApp) {
        if let index = monitoredApps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            monitoredApps[index] = app
            saveMonitoredApps()
        }
    }
    
    func addHistory(_ record: MonitoringHistory) {
        history.append(record)
        saveHistory()
    }
    
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }
}