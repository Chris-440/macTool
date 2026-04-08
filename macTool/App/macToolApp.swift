import SwiftUI

@main
struct macToolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    
    var body: some Scene {
        MenuBarExtra("CPU Monitor", systemImage: appState.statusIcon) {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}