import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    
    public func show(tab: SettingsTab = .alerts) {
        if let existing = window {
            existing.title = tab.rawValue
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView(monitor: SystemMonitor.shared, initialTab: tab)
        let hostingController = NSHostingController(rootView: settingsView)
        
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = tab.rawValue
        newWindow.styleMask = [.titled, .closable, .miniaturizable]
        newWindow.titleVisibility = .visible
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.center()
        
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
