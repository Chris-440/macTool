import SwiftUI

/// 设置视图
struct SettingsView: View {
    @StateObject private var appState = AppState.shared
    @State private var showingAddApp = false
    
    var body: some View {
        TabView {
            MonitoredAppsView()
                .tabItem {
                    Label("监控列表", systemImage: "list.bullet.rectangle")
                }
            
            HistoryView()
                .tabItem {
                    Label("历史记录", systemImage: "clock.arrow.circlepath")
                }
            
            GeneralSettingsView()
                .tabItem {
                    Label("通用设置", systemImage: "gearshape")
                }
        }
        .frame(width: 600, height: 500)
    }
}

/// 监控应用列表视图
struct MonitoredAppsView: View {
    @StateObject private var appState = AppState.shared
    @State private var showingAddApp = false
    @State private var selectedApp: MonitoredApp?
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Text("监控应用列表")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddApp = true }) {
                    Label("添加应用", systemImage: "plus")
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // 应用列表
            List(selection: $selectedApp) {
                ForEach(appState.monitoredApps) { app in
                    MonitoredAppRow(app: app)
                        .tag(app)
                }
                .onDelete { indexSet in
                    indexSet.forEach { appState.monitoredApps.remove(at: $0) }
                    appState.saveMonitoredApps()
                }
            }
            .listStyle(.inset)
            
            Divider()
            
            // 详情编辑
            if let app = selectedApp {
                AppDetailView(app: Binding(
                    get: { app },
                    set: { appState.updateMonitoredApp($0) }
                ))
            }
        }
        .sheet(isPresented: $showingAddApp) {
            AddAppView()
        }
    }
}

/// 监控应用行
struct MonitoredAppRow: View {
    let app: MonitoredApp
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(app.name)
                        .fontWeight(.medium)
                    if app.isWhitelisted {
                        Text("白名单")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { app.isEnabled },
                set: { _ in }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

/// 应用详情编辑视图
struct AppDetailView: View {
    @Binding var app: MonitoredApp
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("应用设置")
                .font(.headline)
            
            HStack {
                Text("启用监控")
                Spacer()
                Toggle("", isOn: $app.isEnabled)
                    .labelsHidden()
            }
            
            HStack {
                Text("CPU 阈值")
                Spacer()
                TextField("", value: $app.cpuThreshold, formatter: NumberFormatter())
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                Text("%")
            }
            
            HStack {
                Text("后台持续时间阈值")
                Spacer()
                TextField("", value: $app.backgroundDuration, formatter: NumberFormatter())
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                Text("秒")
            }
            
            HStack {
                Text("加入白名单")
                Spacer()
                Toggle("", isOn: $app.isWhitelisted)
                    .labelsHidden()
            }
            
            HStack {
                Spacer()
                Button("保存") {
                    AppState.shared.updateMonitoredApp(app)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

/// 添加应用视图
struct AddAppView: View {
    @StateObject private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBundleId = ""
    @State private var customName = ""
    @State private var cpuThreshold = 30.0
    
    private let suggestedApps = [
        ("com.microsoft.edgemac", "Microsoft Edge"),
        ("com.google.Chrome", "Google Chrome"),
        ("com.apple.Safari", "Safari"),
        ("com.electron.wechat", "微信"),
        ("com.tencent.xinWeChat", "微信 (原生)"),
        ("com.i4tools.i4tools", "爱思助手"),
        ("com.apple.mail", "邮件"),
        ("com.microsoft.teams", "Microsoft Teams"),
        ("com.spotify.client", "Spotify"),
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("添加监控应用")
                .font(.headline)
            
            Picker("选择应用", selection: $selectedBundleId) {
                Text("选择一个应用...").tag("")
                ForEach(suggestedApps, id: \.0) { app in
                    Text(app.1).tag(app.0)
                }
            }
            .frame(width: 300)
            
            Text("或输入自定义 Bundle ID:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField("com.example.app", text: $selectedBundleId)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            HStack {
                Text("应用名称:")
                TextField("名称", text: $customName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
            
            HStack {
                Text("CPU 阈值:")
                Slider(value: $cpuThreshold, in: 10...100, step: 5)
                    .frame(width: 150)
                Text("\(Int(cpuThreshold))%")
            }
            
            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("添加") {
                    let name = customName.isEmpty ? selectedBundleId : customName
                    let newApp = MonitoredApp(
                        bundleIdentifier: selectedBundleId,
                        name: name,
                        cpuThreshold: cpuThreshold
                    )
                    appState.addMonitoredApp(newApp)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedBundleId.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

/// 历史记录视图
struct HistoryView: View {
    @StateObject private var appState = AppState.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("历史记录")
                    .font(.headline)
                Spacer()
                Button("清空") {
                    appState.clearHistory()
                }
            }
            .padding()
            
            Divider()
            
            if appState.history.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("暂无历史记录")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(appState.history.reversed()) { record in
                        HistoryRow(record: record)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

/// 历史记录行
struct HistoryRow: View {
    let record: MonitoringHistory
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.appName)
                    .fontWeight(.medium)
                Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.1f", record.cpuUsage))% CPU")
                    .foregroundColor(cpuColor)
                Text(actionText)
                    .font(.caption)
                    .foregroundColor(actionColor)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var cpuColor: Color {
        if record.cpuUsage > 50 {
            return .red
        } else if record.cpuUsage > 30 {
            return .orange
        }
        return .primary
    }
    
    private var actionText: String {
        switch record.action {
        case "notified": return "已通知"
        case "terminated": return "已退出"
        case "ignored": return "已忽略"
        default: return record.action
        }
    }
    
    private var actionColor: Color {
        switch record.action {
        case "notified": return .orange
        case "terminated": return .red
        case "ignored": return .secondary
        default: return .secondary
        }
    }
}

/// 通用设置视图
struct GeneralSettingsView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var monitorService = MonitorService.shared
    @State private var isAutoLaunchEnabled = false
    @State private var showAutoLaunchError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("通用设置")
                .font(.headline)
            
            // 监控状态
            HStack {
                Text("监控状态")
                Spacer()
                Toggle("", isOn: Binding(
                    get: { monitorService.isRunning },
                    set: { $0 ? monitorService.startMonitoring() : monitorService.stopMonitoring() }
                ))
                .labelsHidden()
            }
            
            Divider()
            
            // 开机自动启动
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("开机自动启动")
                    Text("登录时自动启动应用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isAutoLaunchEnabled)
                    .labelsHidden()
                    .onChange(of: isAutoLaunchEnabled) { newValue in
                        let success = AutoLaunchManager.shared.setAutoLaunch(enabled: newValue)
                        if !success {
                            showAutoLaunchError = true
                            isAutoLaunchEnabled = AutoLaunchManager.shared.isAutoLaunchEnabled
                        }
                    }
            }
            .alert("设置失败", isPresented: $showAutoLaunchError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text("无法更改开机自动启动设置。请检查系统权限。")
            }
            .onAppear {
                isAutoLaunchEnabled = AutoLaunchManager.shared.isAutoLaunchEnabled
            }
            
            Divider()
            
            // 关于
            VStack(alignment: .leading, spacing: 8) {
                Text("关于")
                    .font(.headline)
                Text("CPU Monitor - macOS 进程监控工具")
                    .foregroundColor(.secondary)
                Text("版本 1.0.0")
                    .foregroundColor(.secondary)
                Text("检测后台应用 CPU 异常占用，及时提醒用户")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            Spacer()
        }
        .padding()
    }
}