import AppKit
import SwiftUI

@MainActor
public final class AttentionLogWindowController: NSObject, NSWindowDelegate {
    public static let shared = AttentionLogWindowController()
    
    private var window: NSWindow?
    
    public func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let logView = AttentionLogView(rulesEngine: SystemMonitor.shared.rulesEngine)
        let hosting = NSHostingController(rootView: logView)
        
        let newWindow = NSWindow(contentViewController: hosting)
        newWindow.title = "Attention Log"
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
