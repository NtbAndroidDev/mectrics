import AppKit
import Combine
import CoreGraphics

/// Monitors macOS power states (screen sleep, system sleep, wake)
/// to intelligently pause background monitoring and prevent battery drain or darkwake runaway.
@MainActor
public final class PowerLifecycleManager: ObservableObject {
    public static let shared = PowerLifecycleManager()
    
    @Published public private(set) var isSleeping: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    /// Level-triggered safety net while paused. Wake notifications are edge-triggered and unreliable:
    /// `didWake` fires at DarkWake (display off, so we ignore it) and is NOT re-posted on the later
    /// DarkWake -> FullWake transition, while `screensDidWake` is sometimes skipped. Without this the
    /// monitor could stay paused forever after a night of dark wakes, freezing the menu bar.
    /// Timers don't fire during real sleep, so this costs nothing while asleep.
    private var wakeWatchdog: Timer?
    private static let wakeWatchdogInterval: TimeInterval = 10.0
    
    public init() {
        setupObservers()
    }
    
    private func setupObservers() {
        let wsCenter = NSWorkspace.shared.notificationCenter
        
        // Screen Sleep / Wake (Direct trigger when user closes lid or display turns off)
        wsCenter.publisher(for: NSWorkspace.screensDidSleepNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleSleep(reason: "Screens Did Sleep")
            }
            .store(in: &cancellables)
            
        wsCenter.publisher(for: NSWorkspace.screensDidWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleWake(isScreenWake: true, reason: "Screens Did Wake")
            }
            .store(in: &cancellables)
            
        // System Sleep / Wake
        wsCenter.publisher(for: NSWorkspace.willSleepNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleSleep(reason: "System Will Sleep")
            }
            .store(in: &cancellables)
            
        wsCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleWake(isScreenWake: false, reason: "System Did Wake (Checking DarkWake)")
            }
            .store(in: &cancellables)
        
        // Fast user switching: our session going inactive is equivalent to sleep for a menu bar app.
        wsCenter.publisher(for: NSWorkspace.sessionDidResignActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleSleep(reason: "Session Resigned Active")
            }
            .store(in: &cancellables)
        
        wsCenter.publisher(for: NSWorkspace.sessionDidBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleWake(isScreenWake: true, reason: "Session Became Active")
            }
            .store(in: &cancellables)
    }
    
    private func isDisplayAsleep() -> Bool {
        if CGDisplayIsAsleep(CGMainDisplayID()) != 0 {
            return true
        }
        if NSScreen.screens.isEmpty {
            return true
        }
        return false
    }
    
    private func handleSleep(reason: String) {
        guard !isSleeping else { return }
        isSleeping = true
        
        // 1. Temporarily release sleep assertion so clamshell sleep isn't hindered
        SleepBlocker.shared.suspendAssertion()
        
        // 2. Dismiss any open popovers, kill hover timers (40ms loops) immediately
        StatusBarManager.shared.prepareForSleep()
        
        // 3. Invalidate monitor timers and pause polling completely
        SystemMonitor.shared.pauseMonitoring()
        
        startWakeWatchdog()
    }
    
    private func handleWake(isScreenWake: Bool, reason: String) {
        // If system woke due to DarkWake (maintenance, FindMy, APNs) and display is still OFF, DO NOT RESUME!
        if !isScreenWake && isDisplayAsleep() {
            return
        }
        
        guard isSleeping else { return }
        isSleeping = false
        stopWakeWatchdog()
        
        // 1. Restore SleepBlocker if user explicitly kept it on
        SleepBlocker.shared.restoreAssertionIfNeeded()
        
        // 2. Resume periodic hardware monitoring
        SystemMonitor.shared.resumeMonitoring()
    }
    
    /// Resumes on the user's next wake even when no wake notification arrives.
    public func resumeIfAwake() {
        guard isSleeping, !isDisplayAsleep() else { return }
        handleWake(isScreenWake: true, reason: "Display Awake (Watchdog)")
    }
    
    private func startWakeWatchdog() {
        wakeWatchdog?.invalidate()
        let timer = Timer(timeInterval: Self.wakeWatchdogInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resumeIfAwake()
            }
        }
        timer.tolerance = Self.wakeWatchdogInterval * 0.5
        RunLoop.main.add(timer, forMode: .common)
        wakeWatchdog = timer
    }
    
    private func stopWakeWatchdog() {
        wakeWatchdog?.invalidate()
        wakeWatchdog = nil
    }
}
