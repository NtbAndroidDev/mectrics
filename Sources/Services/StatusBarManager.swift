import AppKit
import SwiftUI
import Combine

@MainActor
public final class StatusBarManager: NSObject, NSPopoverDelegate {
    public static let shared = StatusBarManager()
    
    private let monitor = SystemMonitor.shared
    private var cancellables = Set<AnyCancellable>()
    private var activeStatusItem: NSStatusItem?
    
    // Status Items
    private var compactHealthItem: NSStatusItem!
    private var diskItem: NSStatusItem!
    private var memoryItem: NSStatusItem!
    private var cpuItem: NSStatusItem!
    private var networkItem: NSStatusItem!
    private var batteryItem: NSStatusItem!
    private var sensorItem: NSStatusItem!
    private var gpuItem: NSStatusItem!
    
    // Popovers
    private var compactHealthPopover: NSPopover!
    private var diskPopover: NSPopover!
    private var memoryPopover: NSPopover!
    private var cpuPopover: NSPopover!
    private var networkPopover: NSPopover!
    private var batteryPopover: NSPopover!
    private var sensorPopover: NSPopover!
    private var gpuPopover: NSPopover!
    
    // Hosting Views
    private var compactHealthHosting: NSHostingView<AnyView>?
    private var diskHosting: NSHostingView<AnyView>?
    private var memoryHosting: NSHostingView<AnyView>?
    private var cpuHosting: NSHostingView<AnyView>?
    private var networkHosting: NSHostingView<AnyView>?
    private var batteryHosting: NSHostingView<AnyView>?
    private var sensorHosting: NSHostingView<AnyView>?
    private var gpuHosting: NSHostingView<AnyView>?
    
    public override init() {
        super.init()
        setupStatusItems()
        setupPopovers()
        updateAllViews()
        updateVisibility()
        observeMonitor()
    }
    
    private func setupStatusItems() {
        compactHealthItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton(compactHealthItem.button, action: #selector(toggleCompactHealth))
        
        diskItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton(diskItem.button, action: #selector(toggleDisk))
        
        memoryItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton(memoryItem.button, action: #selector(toggleMemory))
        
        cpuItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton(cpuItem.button, action: #selector(toggleCPU))
        
        networkItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton(networkItem.button, action: #selector(toggleNetwork))
        
        batteryItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton(batteryItem.button, action: #selector(toggleBattery))
        
        sensorItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton(sensorItem.button, action: #selector(toggleSensor))
        
        gpuItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton(gpuItem.button, action: #selector(toggleGPU))
    }
    
    private func setupButton(_ button: NSStatusBarButton?, action: Selector) {
        guard let button = button else { return }
        button.target = self
        button.action = action
        button.sendAction(on: [.leftMouseUp])
    }
    
    private func setupPopovers() {
        compactHealthPopover = createPopover(contentView: CompactHealthPopoverView(monitor: monitor))
        diskPopover = createPopover(contentView: DiskPopoverView(monitor: monitor))
        memoryPopover = createPopover(contentView: MemoryPopoverView(monitor: monitor))
        cpuPopover = createPopover(contentView: CPUPopoverView(monitor: monitor))
        networkPopover = createPopover(contentView: NetworkPopoverView(monitor: monitor))
        batteryPopover = createPopover(contentView: BatteryPopoverView(monitor: monitor))
        sensorPopover = createPopover(contentView: SensorPopoverView(monitor: monitor))
        gpuPopover = createPopover(contentView: GPUPopoverView(monitor: monitor))
    }
    
    private func createPopover<Content: View>(contentView: Content) -> NSPopover {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .vibrantDark)
        popover.delegate = self
        let controller = NSHostingController(rootView: contentView)
        popover.contentViewController = controller
        return popover
    }
    
    public func popoverDidClose(_ notification: Notification) {
        activeStatusItem = nil
        updateAllViews()
    }
    
    private func observeMonitor() {
        monitor.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateAllViews()
                self?.updateVisibility()
            }
            .store(in: &cancellables)
    }
    
    public func updateVisibility() {
        let compact = monitor.useCompactHealthBar
        
        compactHealthItem.isVisible = compact
        diskItem.isVisible = !compact && monitor.showDiskInMenuBar
        memoryItem.isVisible = !compact && monitor.showMemoryInMenuBar
        cpuItem.isVisible = !compact && monitor.showCPUInMenuBar
        networkItem.isVisible = !compact && monitor.showNetworkInMenuBar
        batteryItem.isVisible = !compact && monitor.showBatteryInMenuBar && monitor.battery.isPresent
        sensorItem.isVisible = !compact && monitor.showSensorInMenuBar
        gpuItem.isVisible = !compact && monitor.showGPUInMenuBar
    }
    
    public func updateAllViews() {
        // 1. Compact Health View
        let chActive = (activeStatusItem === compactHealthItem)
        let chView = AnyView(
            CompactHealthBarView(statusLevel: monitor.health.statusLevel, isActive: chActive)
        )
        setHostingView(for: compactHealthItem, hosting: &compactHealthHosting, view: chView, width: chActive ? 28 : 22)
        
        // 2. Disk View
        let diskActive = (activeStatusItem === diskItem)
        let diskText = (monitor.diskDisplayMode == .percentage)
            ? String(format: "%.0f%%", monitor.disk.usagePercentage)
            : "\(monitor.disk.freeBytes / (1024 * 1024 * 1024))GB"
        let dView = AnyView(
            MenuBarItemView(
                icon: "internaldrive",
                valueText: diskText,
                tintColor: MectricsTheme.coral,
                isActive: diskActive
            )
        )
        setHostingView(for: diskItem, hosting: &diskHosting, view: dView, width: diskActive ? 64 : 56)
        
        // 3. Memory View
        let memActive = (activeStatusItem === memoryItem)
        let mView = AnyView(
            MenuBarItemView(
                icon: "memorychip",
                valueText: String(format: "%.0f%%", monitor.memory.usagePercentage),
                sparklineValues: monitor.showMemorySparkline ? monitor.memoryHistory.values : nil,
                isBoxedSparkline: true,
                tintColor: MectricsTheme.coral,
                isActive: memActive
            )
        )
        let memWidth: CGFloat = monitor.showMemorySparkline ? (memActive ? 82 : 74) : (memActive ? 58 : 50)
        setHostingView(for: memoryItem, hosting: &memoryHosting, view: mView, width: memWidth)
        
        // 4. CPU View
        let cpuActive = (activeStatusItem === cpuItem)
        let cView = AnyView(
            MenuBarItemView(
                icon: "cpu",
                valueText: String(format: "%.0f%%", monitor.cpu.totalUsage),
                sparklineValues: monitor.showCPUSparkline ? monitor.cpuHistory.values : nil,
                isBoxedSparkline: false,
                tintColor: MectricsTheme.coral,
                isActive: cpuActive
            )
        )
        let cpuWidth: CGFloat = monitor.showCPUSparkline ? (cpuActive ? 86 : 78) : (cpuActive ? 58 : 50)
        setHostingView(for: cpuItem, hosting: &cpuHosting, view: cView, width: cpuWidth)
        
        // 5. Network View
        let netActive = (activeStatusItem === networkItem)
        let nView: AnyView
        if monitor.networkDisplayMode == .stacked {
            nView = AnyView(
                NetworkMenuBarView(
                    downloadBytes: monitor.network.downloadBytesPerSec,
                    uploadBytes: monitor.network.uploadBytesPerSec,
                    tintColor: MectricsTheme.coral,
                    isActive: netActive
                )
            )
            setHostingView(for: networkItem, hosting: &networkHosting, view: nView, width: netActive ? 66 : 58)
        } else {
            let total = monitor.network.downloadBytesPerSec + monitor.network.uploadBytesPerSec
            nView = AnyView(
                MenuBarItemView(
                    icon: "arrow.up.arrow.down",
                    valueText: formatSingleRate(total),
                    tintColor: MectricsTheme.coral,
                    isActive: netActive
                )
            )
            setHostingView(for: networkItem, hosting: &networkHosting, view: nView, width: netActive ? 70 : 62)
        }
        
        // 6. Battery View
        let batActive = (activeStatusItem === batteryItem)
        let bView = AnyView(
            MenuBarItemView(
                icon: monitor.battery.isCharging ? "battery.100percent.bolt" : "battery.100percent",
                valueText: String(format: "%.0f%%", monitor.battery.percentage),
                tintColor: MectricsTheme.coral,
                isActive: batActive
            )
        )
        setHostingView(for: batteryItem, hosting: &batteryHosting, view: bView, width: batActive ? 58 : 50)
        
        // 7. Sensor View
        let senActive = (activeStatusItem === sensorItem)
        let sView = AnyView(
            MenuBarItemView(
                icon: "thermometer.medium",
                valueText: "\(Int(monitor.sensor.cpuTemperature))°C",
                sparklineValues: monitor.tempHistory.values,
                tintColor: MectricsTheme.coral,
                isActive: senActive
            )
        )
        setHostingView(for: sensorItem, hosting: &sensorHosting, view: sView, width: senActive ? 62 : 54)
        
        // 8. GPU View
        let gpuActive = (activeStatusItem === gpuItem)
        let gView = AnyView(
            MenuBarItemView(
                icon: "display",
                valueText: String(format: "%.0f%%", monitor.gpu.usagePercentage),
                sparklineValues: monitor.gpuHistory.values,
                tintColor: MectricsTheme.coral,
                isActive: gpuActive
            )
        )
        setHostingView(for: gpuItem, hosting: &gpuHosting, view: gView, width: gpuActive ? 60 : 52)
    }
    
    private func setHostingView(
        for item: NSStatusItem,
        hosting: inout NSHostingView<AnyView>?,
        view: AnyView,
        width: CGFloat
    ) {
        guard let button = item.button else { return }
        
        if let h = hosting {
            h.rootView = view
        } else {
            let h = NSHostingView(rootView: view)
            button.addSubview(h)
            h.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                h.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                h.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                h.topAnchor.constraint(equalTo: button.topAnchor),
                h.bottomAnchor.constraint(equalTo: button.bottomAnchor)
            ])
            hosting = h
        }
        
        item.length = width
    }
    
    private func formatSingleRate(_ bytes: Double) -> String {
        if bytes >= 1024 * 1024 {
            return String(format: "%.1fM", bytes / (1024 * 1024))
        } else if bytes >= 1024 {
            return String(format: "%.0fK", bytes / 1024)
        } else {
            return "0K"
        }
    }
    
    // MARK: - Actions
    @objc private func toggleCompactHealth() { toggle(compactHealthPopover, for: compactHealthItem) }
    @objc private func toggleDisk() { toggle(diskPopover, for: diskItem) }
    @objc private func toggleMemory() { toggle(memoryPopover, for: memoryItem) }
    @objc private func toggleCPU() { toggle(cpuPopover, for: cpuItem) }
    @objc private func toggleNetwork() { toggle(networkPopover, for: networkItem) }
    @objc private func toggleBattery() { toggle(batteryPopover, for: batteryItem) }
    @objc private func toggleSensor() { toggle(sensorPopover, for: sensorItem) }
    @objc private func toggleGPU() { toggle(gpuPopover, for: gpuItem) }
    
    private func toggle(_ popover: NSPopover, for item: NSStatusItem) {
        guard let button = item.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
            activeStatusItem = nil
            updateAllViews()
        } else {
            closeAllPopovers()
            activeStatusItem = item
            updateAllViews()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    public func closeAllPopovers() {
        [compactHealthPopover, diskPopover, memoryPopover, cpuPopover, networkPopover, batteryPopover, sensorPopover, gpuPopover].forEach {
            $0?.performClose(nil)
        }
    }
}
