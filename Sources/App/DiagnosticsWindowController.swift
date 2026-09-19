import AppKit
import SwiftUI

@MainActor
public final class DiagnosticsWindowController: NSObject, NSWindowDelegate {
    public static let shared = DiagnosticsWindowController()
    
    private var window: NSWindow?
    
    public func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let diagView = DiagnosticsView()
        let hosting = NSHostingController(rootView: diagView)
        
        let newWindow = NSWindow(contentViewController: hosting)
        newWindow.title = LocalizationManager.shared.t("System Diagnostics")
        newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
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
