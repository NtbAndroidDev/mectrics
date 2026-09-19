import SwiftUI
import AppKit

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    @Published public var monitor = SystemMonitor.shared
    public let statusBarManager = StatusBarManager.shared
    public let powerManager = PowerLifecycleManager.shared
    
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
    
    public func openDiagnostics() {
        DiagnosticsWindowController.shared.show()
    }
    
    public func installCLI() -> (success: Bool, message: String) {
        let targetPath = "/usr/local/bin/mectrics"
        let sourcePath = Bundle.main.executablePath ?? "/Applications/Mectrics.app/Contents/MacOS/Mectrics"
        
        let fileManager = FileManager.default
        
        // Ensure /usr/local/bin exists
        try? fileManager.createDirectory(atPath: "/usr/local/bin", withIntermediateDirectories: true)
        
        // Remove existing if any
        if fileManager.fileExists(atPath: targetPath) {
            try? fileManager.removeItem(atPath: targetPath)
        }
        
        do {
            try fileManager.createSymbolicLink(atPath: targetPath, withDestinationPath: sourcePath)
            return (true, "mectrics CLI link created at /usr/local/bin/mectrics")
        } catch {
            // If permission error, use AppleScript to elevate
            let script = "do shell script \"mkdir -p /usr/local/bin && ln -sf '\(sourcePath)' '\(targetPath)'\" with administrator privileges"
            var errorInfo: NSDictionary?
            if let appleScript = NSAppleScript(source: script),
               appleScript.executeAndReturnError(&errorInfo).booleanValue == true || errorInfo == nil {
                return (true, "mectrics CLI link installed at /usr/local/bin/mectrics with admin privileges.")
            } else {
                return (false, "Could not create symlink: \(errorInfo?["NSAppleScriptErrorMessage"] ?? error.localizedDescription)")
            }
        }
    }
    
    public func cleanUninstall() {
        let alert = NSAlert()
        let isVi = LocalizationManager.shared.currentLanguage == .vietnamese
        alert.messageText = isVi ? "Gỡ cài đặt Mectrics sạch sẽ?" : "Uninstall Mectrics cleanly?"
        alert.informativeText = isVi
            ? "Thao tác này sẽ xoá cài đặt, tự động huỷ khởi động cùng hệ thống, xoá liên kết lệnh CLI /usr/local/bin/mectrics và thoát ứng dụng."
            : "This will remove all saved preferences, unregister login items, remove /usr/local/bin/mectrics link, and quit the application."
        alert.alertStyle = .critical
        alert.addButton(withTitle: isVi ? "Gỡ cài đặt" : "Uninstall")
        alert.addButton(withTitle: isVi ? "Huỷ" : "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // 1. Unregister login item
            LaunchAtLoginManager.isEnabled = false
            
            // 2. Remove CLI symlink
            try? FileManager.default.removeItem(atPath: "/usr/local/bin/mectrics")
            
            // 3. Clear UserDefaults
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
            UserDefaults.standard.synchronize()
            
            // 4. Terminate app
            NSApplication.shared.terminate(nil)
        }
    }
}
