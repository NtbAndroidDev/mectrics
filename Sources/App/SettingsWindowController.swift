import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    
    public func show(tab: SettingsTab = .menuBar) {
        let localizedTitle = LocalizationManager.shared.t(tab.rawValue)
        if let existing = window {
            existing.title = localizedTitle
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: Notification.Name("didSelectSettingsTab"), object: tab)
            return
        }
        
        let settingsView = SettingsView(monitor: SystemMonitor.shared, initialTab: tab)
        let hostingController = NSHostingController(rootView: settingsView)
        
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = localizedTitle
        newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        newWindow.minSize = NSSize(width: 520, height: 580)
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .visible
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.center()
        
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func updateTitle(_ title: String) {
        window?.title = title
    }
    
    public func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
