import Foundation
import IOKit.pwr_mgt

@MainActor
public final class SleepBlocker: ObservableObject {
    public static let shared = SleepBlocker()
    
    @Published public var isKeepAwakeActive: Bool = false {
        didSet {
            toggleSleepAssertion(isKeepAwakeActive)
        }
    }
    
    private var assertionID: IOPMAssertionID = 0
    
    public init() {}
    
    public func toggle() {
        isKeepAwakeActive.toggle()
    }
    
    private func toggleSleepAssertion(_ enable: Bool) {
        if enable {
            let reason = "Mectrics Anti-Sleep Active" as CFString
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &assertionID
            )
            if result != kIOReturnSuccess {
                assertionID = 0
                isKeepAwakeActive = false
            }
        } else {
            if assertionID != 0 {
                IOPMAssertionRelease(assertionID)
                assertionID = 0
            }
        }
    }
    
    /// Temporarily release assertion when system enters sleep to avoid blocking clamshell sleep
    public func suspendAssertion() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
    }
    
    /// Re-engage assertion upon legitimate wake if user preference is active
    public func restoreAssertionIfNeeded() {
        if isKeepAwakeActive && assertionID == 0 {
            toggleSleepAssertion(true)
        }
    }
}

