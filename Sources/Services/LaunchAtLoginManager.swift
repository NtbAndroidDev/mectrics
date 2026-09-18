import Foundation
import ServiceManagement

public final class LaunchAtLoginManager: @unchecked Sendable {
    public static var isEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            }
            return false
        }
        set {
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("Could not update SMAppService status: \(error)")
                }
            }
        }
    }
}
