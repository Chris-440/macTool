import Foundation
import AppKit

/// 进程监控服务 - 获取进程 CPU、内存等信息
class ProcessMonitor {
    static let shared = ProcessMonitor()
    
    private init() {}
    
    /// 获取所有运行中的应用进程
    func getRunningApplications() -> [ProcessInfo] {
        var processInfos: [ProcessInfo] = []
        
        let runningApps = NSWorkspace.shared.runningApplications
        
        for app in runningApps {
            guard let bundleIdentifier = app.bundleIdentifier else { continue }
            
            // 获取进程 ID
            let pid = app.processIdentifier
            
            // 获取 CPU 使用率
            let cpuUsage = getCPUUsage(for: pid)
            
            // 获取内存使用
            let memoryUsage = getMemoryUsage(for: pid)
            
            // 判断是否为前台应用
            let isForeground = app.isActive
            
            // 判断是否正在被用户使用（通过检测最近输入）
            let isActive = isUserInteracting(with: app)
            
            let processInfo = ProcessInfo(
                pid: pid,
                bundleIdentifier: bundleIdentifier,
                processName: app.localizedName ?? bundleIdentifier,
                cpuUsage: cpuUsage,
                memoryUsage: memoryUsage,
                isForeground: isForeground,
                isActive: isActive
            )
            
            processInfos.append(processInfo)
        }
        
        return processInfos
    }
    
    /// 获取指定进程的 CPU 使用率
    private func getCPUUsage(for pid: pid_t) -> Double {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        var task: mach_port_t = 0
        let kr = task_for_pid(mach_task_self_, pid, &task)
        guard kr == KERN_SUCCESS else { return 0.0 }
        
        defer {
            if let threads = threadList {
                let size = vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.stride)
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), size)
            }
        }
        
        let result = withUnsafeMutablePointer(to: &threadList) {
            return $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(task, $0, &threadCount)
            }
        }
        
        guard result == KERN_SUCCESS, let threads = threadList else { return 0.0 }
        
        var totalCpu: Double = 0
        
        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var count = mach_msg_type_number_t(THREAD_INFO_MAX)
            
            let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
                infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
                }
            }
            
            if kr == KERN_SUCCESS && info.flags & TH_FLAGS_IDLE == 0 {
                totalCpu += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
            }
        }
        
        return totalCpu
    }
    
    /// 获取指定进程的内存使用量（字节）
    private func getMemoryUsage(for pid: pid_t) -> UInt64 {
        var task: mach_port_t = 0
        guard task_for_pid(mach_task_self_, pid, &task) == KERN_SUCCESS else { return 0 }
        
        var info = task_basic_info_64()
        var count = mach_msg_type_number_t(MemoryLayout<task_basic_info_64>.size / MemoryLayout<natural_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(task, task_flavor_t(TASK_BASIC_INFO_64), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0 }
        
        return info.resident_size
    }
    
    /// 检测用户是否正在与指定应用交互
    private func isUserInteracting(with app: NSRunningApplication) -> Bool {
        // 如果应用是活跃状态，认为用户正在交互
        if app.isActive {
            return true
        }
        
        // 检查最近是否有用户输入事件
        // 这里使用一个简单的方法：检查应用是否在最近 N 秒内收到过事件
        // 由于 macOS 限制，我们使用活跃状态作为代理
        return false
    }
    
    /// 根据 bundle identifier 查找进程
    func findProcess(by bundleIdentifier: String) -> ProcessInfo? {
        let apps = NSWorkspace.shared.runningApplications
        for app in apps {
            if app.bundleIdentifier == bundleIdentifier {
                let pid = app.processIdentifier
                return ProcessInfo(
                    pid: pid,
                    bundleIdentifier: bundleIdentifier,
                    processName: app.localizedName ?? bundleIdentifier,
                    cpuUsage: getCPUUsage(for: pid),
                    memoryUsage: getMemoryUsage(for: pid),
                    isForeground: app.isActive,
                    isActive: app.isActive
                )
            }
        }
        return nil
    }
}

/// 进程信息结构
struct ProcessInfo {
    let pid: pid_t
    let bundleIdentifier: String
    let processName: String
    let cpuUsage: Double
    let memoryUsage: UInt64
    let isForeground: Bool
    let isActive: Bool
}