import SwiftUI
import AppKit

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    @Published public var monitor = SystemMonitor.shared
    
    private init() {
        // Set activation policy to accessory so it does not crowd the Dock
        NSApplication.shared.setActivationPolicy(.accessory)
    }
    
    public func openSettings(tab: SettingsTab = .alerts) {
        SettingsWindowController.shared.show(tab: tab)
    }
}
