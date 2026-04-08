import SwiftUI

/// 菜单栏视图 - 美化的窗口样式
struct MenuBarView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var monitorService = MonitorService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部状态栏
            HStack {
                ZStack {
                    Circle()
                        .fill(monitorService.isRunning ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: monitorService.isRunning ? "checkmark.circle.fill" : "pause.circle")
                        .font(.system(size: 20))
                        .foregroundColor(monitorService.isRunning ? .green : .gray)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("CPU 监控")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(monitorService.isRunning ? "正在监控" : "已暂停")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !appState.currentAnomalies.isEmpty {
                    Text("\(appState.currentAnomalies.count)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 异常列表或正常状态
            if appState.currentAnomalies.isEmpty {
                // 正常状态 - 居中显示
                VStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green.opacity(0.6))
                        
                        Text("所有应用运行正常")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: 120)
            } else {
                // 异常列表
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appState.currentAnomalies) { anomaly in
                            AnomalyCard(anomaly: anomaly)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 200)
            }
            
            Divider()
            
            // 底部操作栏 - 居中
            HStack {
                Spacer()
                
                HStack(spacing: 12) {
                    // 监控开关
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if monitorService.isRunning {
                                monitorService.stopMonitoring()
                            } else {
                                monitorService.startMonitoring()
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: monitorService.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 12))
                            Text(monitorService.isRunning ? "暂停" : "启动")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(monitorService.isRunning ? .secondary : .green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(monitorService.isRunning ? Color.secondary.opacity(0.1) : Color.green.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // 设置按钮
                    Button(action: {
                        openSettingsWindow()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 12))
                            Text("设置")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // 退出按钮
                    Button(action: {
                        NSApp.terminate(nil)
                    }) {
                        Image(systemName: "power")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 320)
    }
    
    private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        
        if let window = NSApp.windows.first(where: { $0.title == "设置" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "设置"
            window.contentViewController = hostingController
            window.center()
            window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)
        }
    }
}

/// 异常卡片视图
struct AnomalyCard: View {
    let anomaly: AnomalyResult
    @StateObject private var monitorService = MonitorService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 应用名称和 CPU 占用
            HStack {
                // 严重程度指示器
                Circle()
                    .fill(severityColor)
                    .frame(width: 8, height: 8)
                
                Text(anomaly.app.name)
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                // CPU 占用
                HStack(spacing: 2) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                    Text("\(String(format: "%.1f", anomaly.cpuUsage))%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(severityColor)
                }
            }
            
            // 异常原因
            Text(anomaly.reason)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            // 操作按钮 - 居中
            HStack {
                Spacer()
                
                HStack(spacing: 6) {
                    Button(action: {
                        monitorService.terminateApp(anomaly.app.bundleIdentifier)
                    }) {
                        Text("退出")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.red)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        monitorService.ignoreAnomaly(anomaly.app.bundleIdentifier)
                    }) {
                        Text("忽略")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        monitorService.addToWhitelist(anomaly.app.bundleIdentifier)
                    }) {
                        Text("白名单")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(severityColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var severityColor: Color {
        switch anomaly.severity {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .yellow
        }
    }
}