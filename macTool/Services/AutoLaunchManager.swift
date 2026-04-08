import Foundation
import ServiceManagement

/// 开机自动启动管理器
class AutoLaunchManager {
    static let shared = AutoLaunchManager()
    
    private let bundleIdentifier: String
    
    private init() {
        // 获取主应用的 bundle identifier
        self.bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.dzj.macTool"
    }
    
    /// 检查是否已设置开机自动启动
    var isAutoLaunchEnabled: Bool {
        get {
            // 使用 SMAppService 检查状态
            let service = SMAppService.mainApp
            return service.status == .enabled
        }
    }
    
    /// 设置开机自动启动
    func setAutoLaunch(enabled: Bool) -> Bool {
        let service = SMAppService.mainApp
        
        do {
            if enabled {
                try service.register()
                print("开机自动启动已启用")
            } else {
                try service.unregister()
                print("开机自动启动已禁用")
            }
            return true
        } catch {
            print("设置开机自动启动失败: \(error.localizedDescription)")
            return false
        }
    }
}