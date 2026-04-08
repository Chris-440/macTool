import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 请求通知权限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("通知权限已授权")
            } else if let error = error {
                print("通知权限请求失败: \(error.localizedDescription)")
            }
        }
        
        UNUserNotificationCenter.current().delegate = self
        
        // 启动监控服务
        MonitorService.shared.startMonitoring()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        MonitorService.shared.stopMonitoring()
    }
    
    // 关闭窗口时不退出应用
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}