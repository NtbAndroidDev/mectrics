import AppKit
import Combine

/// Monitors macOS power states (screen sleep, system sleep, wake)
/// to intelligently pause background monitoring and prevent battery drain.
@MainActor
public final class PowerLifecycleManager: ObservableObject {
    public static let shared = PowerLifecycleManager()
    
    @Published public private(set) var isSleeping: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupObservers()
    }
    
    private func setupObservers() {
        let wsCenter = NSWorkspace.shared.notificationCenter
        
        // Screen Sleep / Wake
        wsCenter.publisher(for: NSWorkspace.screensDidSleepNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleSleep()
            }
            .store(in: &cancellables)
            
        wsCenter.publisher(for: NSWorkspace.screensDidWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleWake()
            }
            .store(in: &cancellables)
            
        // System Sleep / Wake
        wsCenter.publisher(for: NSWorkspace.willSleepNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleSleep()
            }
            .store(in: &cancellables)
            
        wsCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleWake()
            }
            .store(in: &cancellables)
    }
    
    private func handleSleep() {
        guard !isSleeping else { return }
        isSleeping = true
        SystemMonitor.shared.pauseMonitoring()
    }
    
    private func handleWake() {
        guard isSleeping else { return }
        isSleeping = false
        SystemMonitor.shared.resumeMonitoring()
    }
}
