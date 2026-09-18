import SwiftUI
import AppKit

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    @Published public var monitor = SystemMonitor.shared
    public let statusBarManager = StatusBarManager.shared
    
    private init() {
        // Set activation policy to accessory so it does not crowd the Dock
        NSApplication.shared.setActivationPolicy(.accessory)
    }
    
    public func openSettings(tab: SettingsTab = .menuBar) {
        SettingsWindowController.shared.show(tab: tab)
    }
    
    public func openAttentionLog() {
        AttentionLogWindowController.shared.show()
    }
}
