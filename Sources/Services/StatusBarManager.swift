import AppKit
import SwiftUI
import Combine

@MainActor
public final class StatusBarManager: NSObject, NSPopoverDelegate {
    public static let shared = StatusBarManager()
    
    private let monitor = SystemMonitor.shared
    private var cancellables = Set<AnyCancellable>()
    private var activeStatusItem: NSStatusItem?
    public private(set) var activePopover: NSPopover?
    public private(set) var activeSegment: UnifiedSegment = .none
    public private(set) var isPopoverPinned: Bool = false
    
    private var hoverOpenTimer: Timer?
    private var hoverLivenessTimer: Timer?
    private var outsideGraceTicks: Int = 0
    private var pendingTargetPopover: NSPopover?
    private var pendingTargetSegment: UnifiedSegment = .none
    private var pendingTargetItem: NSStatusItem?
    private var pendingTargetRect: NSRect = .zero
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var lastMouseEvalTime: TimeInterval = 0
    private var currentHoverID = UUID()
    
    // Status Items
    private var unifiedItem: NSStatusItem!
    private var compactHealthItem: NSStatusItem!
    private var dualStackedItem: NSStatusItem!
    private var diskItem: NSStatusItem!
    private var memoryItem: NSStatusItem!
    private var cpuItem: NSStatusItem!
    private var networkItem: NSStatusItem!
    private var batteryItem: NSStatusItem!
    private var sensorItem: NSStatusItem!
    private var fansItem: NSStatusItem!
    private var gpuItem: NSStatusItem!
    
    // Popovers
    private var unifiedPopover: NSPopover!
    private var compactHealthPopover: NSPopover!
    private var dualStackedPopover: NSPopover!
    private var diskPopover: NSPopover!
    private var memoryPopover: NSPopover!
    private var cpuPopover: NSPopover!
    private var networkPopover: NSPopover!
    private var batteryPopover: NSPopover!
    private var sensorPopover: NSPopover!
    private var fansPopover: NSPopover!
    private var gpuPopover: NSPopover!
    
    // Hosting Views
    private var unifiedHosting: NSHostingView<AnyView>?
    private var compactHealthHosting: NSHostingView<AnyView>?
    private var dualStackedHosting: NSHostingView<AnyView>?
    private var diskHosting: NSHostingView<AnyView>?
    private var memoryHosting: NSHostingView<AnyView>?
    private var cpuHosting: NSHostingView<AnyView>?
    private var networkHosting: NSHostingView<AnyView>?
    private var batteryHosting: NSHostingView<AnyView>?
    private var sensorHosting: NSHostingView<AnyView>?
    private var fansHosting: NSHostingView<AnyView>?
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
        unifiedItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton(unifiedItem.button, action: #selector(toggleUnified))
        
        compactHealthItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton(compactHealthItem.button, action: #selector(toggleCompactHealth))
        
        dualStackedItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton(dualStackedItem.button, action: #selector(toggleDualStacked))
        
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
        
        fansItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton(fansItem.button, action: #selector(toggleFans))
        
        gpuItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton(gpuItem.button, action: #selector(toggleGPU))
    }
    
    private func setupButton(_ button: NSStatusBarButton?, action: Selector) {
        guard let button = button else { return }
        button.target = self
        button.action = action
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    private func setupPopovers() {
        unifiedPopover = createPopover(contentView: MasterDashboardPopoverView(monitor: monitor))
        compactHealthPopover = createPopover(contentView: CompactHealthPopoverView(monitor: monitor))
        dualStackedPopover = createPopover(contentView: MasterDashboardPopoverView(monitor: monitor))
        diskPopover = createPopover(contentView: DiskPopoverView(monitor: monitor))
        memoryPopover = createPopover(contentView: MemoryPopoverView(monitor: monitor))
        cpuPopover = createPopover(contentView: CPUPopoverView(monitor: monitor))
        networkPopover = createPopover(contentView: NetworkPopoverView(monitor: monitor))
        batteryPopover = createPopover(contentView: BatteryPopoverView(monitor: monitor))
        sensorPopover = createPopover(contentView: SensorPopoverView(monitor: monitor))
        fansPopover = createPopover(contentView: FansPopoverView(monitor: monitor))
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
    
    public var hasActivePopover: Bool {
        activePopover?.isShown == true
    }
    
    public func popover(for type: HoverDetailType, item: NSStatusItem) -> NSPopover {
        switch type {
        case .cpu: return cpuPopover
        case .memory: return memoryPopover
        case .disk: return diskPopover
        case .network: return networkPopover
        case .battery: return batteryPopover
        case .sensor: return sensorPopover
        case .fans: return fansPopover
        case .gpu: return gpuPopover
        case .master:
            if item === compactHealthItem {
                return compactHealthPopover
            } else if item === dualStackedItem {
                return dualStackedPopover
            } else {
                return unifiedPopover
            }
        }
    }
    
    public func popoverDidClose(_ notification: Notification) {
        if (notification.object as? NSPopover) === activePopover {
            activePopover = nil
            activeStatusItem = nil
            activeSegment = .none
            isPopoverPinned = false
            cancelHoverTimers()
            stopHoverLivenessTimer()
            stopMouseMonitoring()
            updateAllViews()
        }
    }
    
    private func observeMonitor() {
        monitor.objectWillChange
            .throttle(for: .milliseconds(150), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                self?.updateVisibility()
                self?.updateAllViews()
            }
            .store(in: &cancellables)
    }
    
    public func updateVisibility() {
        switch monitor.menuBarMode {
        case .unified:
            unifiedItem.isVisible = true
            compactHealthItem.isVisible = false
            dualStackedItem.isVisible = false
            diskItem.isVisible = false
            memoryItem.isVisible = false
            cpuItem.isVisible = false
            networkItem.isVisible = false
            batteryItem.isVisible = false
            sensorItem.isVisible = false
            fansItem.isVisible = false
            gpuItem.isVisible = false
            
        case .dualStacked:
            unifiedItem.isVisible = false
            compactHealthItem.isVisible = false
            dualStackedItem.isVisible = true
            diskItem.isVisible = false
            memoryItem.isVisible = false
            cpuItem.isVisible = false
            networkItem.isVisible = false
            batteryItem.isVisible = false
            sensorItem.isVisible = false
            fansItem.isVisible = false
            gpuItem.isVisible = false
            
        case .compactHealth:
            unifiedItem.isVisible = false
            compactHealthItem.isVisible = true
            dualStackedItem.isVisible = false
            diskItem.isVisible = false
            memoryItem.isVisible = false
            cpuItem.isVisible = false
            networkItem.isVisible = false
            batteryItem.isVisible = false
            sensorItem.isVisible = false
            fansItem.isVisible = false
            gpuItem.isVisible = false
            
        case .separate:
            unifiedItem.isVisible = false
            compactHealthItem.isVisible = false
            dualStackedItem.isVisible = false
            diskItem.isVisible = monitor.showDiskInMenuBar
            memoryItem.isVisible = monitor.showMemoryInMenuBar
            cpuItem.isVisible = monitor.showCPUInMenuBar
            networkItem.isVisible = monitor.showNetworkInMenuBar
            batteryItem.isVisible = monitor.showBatteryInMenuBar && monitor.battery.isPresent
            sensorItem.isVisible = monitor.showSensorInMenuBar
            fansItem.isVisible = monitor.showFansInMenuBar && !monitor.sensor.fans.isEmpty
            gpuItem.isVisible = monitor.showGPUInMenuBar
        }
    }
    
    public func updateAllViews() {
        let mode = monitor.menuBarMode
        let style = monitor.menuBarDisplayStyle
        
        // 0. Unified Sample Mode ([M] CPU % RAM %)
        // 0. Unified Sample Mode ([M] CPU % RAM %)
        if mode == .unified {
            let uActive = (activeStatusItem === unifiedItem && activePopover?.isShown == true)
            let uView = AnyView(
                UnifiedSampleMenuBarView(
                    cpuUsage: monitor.cpu.totalUsage,
                    memUsage: monitor.memory.usagePercentage,
                    isActive: uActive,
                    activeSegment: uActive ? activeSegment : .none
                )
            )
            setHostingView(for: unifiedItem, hosting: &unifiedHosting, view: uView, width: 130, hoverType: .master, isUnified: true)
            return
        }
        
        // 1. Compact Health View
        if mode == .compactHealth {
            let chActive = (activeStatusItem === compactHealthItem && activePopover?.isShown == true)
            let chView = AnyView(
                CompactHealthBarView(statusLevel: monitor.health.statusLevel, isActive: chActive)
            )
            setHostingView(for: compactHealthItem, hosting: &compactHealthHosting, view: chView, width: 26, hoverType: .master)
            return
        }
        
        // 2. Dual Stacked View (CPU & RAM 35px Mini Item)
        if mode == .dualStacked {
            let dualActive = (activeStatusItem === dualStackedItem && activePopover?.isShown == true)
            let dualView = AnyView(
                DualStackedMenuBarView(
                    cpuUsage: monitor.cpu.totalUsage,
                    memUsage: monitor.memory.usagePercentage,
                    isActive: dualActive,
                    activeSegment: dualActive ? activeSegment : .none
                )
            )
            setHostingView(for: dualStackedItem, hosting: &dualStackedHosting, view: dualView, width: 38, hoverType: .master, isDualStacked: true)
            return
        }
        
        // 3. Disk View
        if monitor.showDiskInMenuBar {
            let diskActive = (activeStatusItem === diskItem && activePopover?.isShown == true)
            let diskText = (monitor.diskDisplayMode == .percentage)
                ? String(format: "%.0f%%", monitor.disk.usagePercentage)
                : "\(monitor.disk.freeBytes / (1024 * 1024 * 1024))GB"
            let dView = AnyView(
                MenuBarItemView(
                    icon: "internaldrive",
                    valueText: diskText,
                    tintColor: MectricsTheme.coral,
                    displayStyle: style,
                    isActive: diskActive
                )
            )
            let dWidth: CGFloat = (style == .minimal) ? 34 : ((style == .compact) ? 48 : 58)
            setHostingView(for: diskItem, hosting: &diskHosting, view: dView, width: dWidth, hoverType: .disk)
        }
        
        // 4. Memory View
        if monitor.showMemoryInMenuBar {
            let memActive = (activeStatusItem === memoryItem && activePopover?.isShown == true)
            let mView = AnyView(
                MenuBarItemView(
                    icon: "memorychip",
                    valueText: String(format: "%.0f%%", monitor.memory.usagePercentage),
                    sparklineValues: monitor.showMemorySparkline ? monitor.memoryHistory.values : nil,
                    isBoxedSparkline: true,
                    tintColor: MectricsTheme.coral,
                    displayStyle: style,
                    isActive: memActive
                )
            )
            let memWidth: CGFloat = (style == .minimal) ? 32 :
                ((style == .compact) ? 48 :
                (monitor.showMemorySparkline ? 78 : 54))
            setHostingView(for: memoryItem, hosting: &memoryHosting, view: mView, width: memWidth, hoverType: .memory)
        }
        
        // 5. CPU View
        if monitor.showCPUInMenuBar {
            let cpuActive = (activeStatusItem === cpuItem && activePopover?.isShown == true)
            let cView = AnyView(
                MenuBarItemView(
                    icon: "cpu",
                    valueText: String(format: "%.0f%%", monitor.cpu.totalUsage),
                    sparklineValues: monitor.showCPUSparkline ? monitor.cpuHistory.values : nil,
                    isBoxedSparkline: false,
                    tintColor: MectricsTheme.coral,
                    displayStyle: style,
                    isActive: cpuActive
                )
            )
            let cpuWidth: CGFloat = (style == .minimal) ? 32 :
                ((style == .compact) ? 48 :
                (monitor.showCPUSparkline ? 82 : 54))
            setHostingView(for: cpuItem, hosting: &cpuHosting, view: cView, width: cpuWidth, hoverType: .cpu)
        }
        
        // 6. Network View
        if monitor.showNetworkInMenuBar {
            let netActive = (activeStatusItem === networkItem && activePopover?.isShown == true)
            let nView: AnyView
            let nWidth: CGFloat
            if monitor.networkDisplayMode == .stacked {
                nView = AnyView(
                    NetworkMenuBarView(
                        downloadBytes: monitor.network.downloadBytesPerSec,
                        uploadBytes: monitor.network.uploadBytesPerSec,
                        tintColor: MectricsTheme.coral,
                        isActive: netActive
                    )
                )
                nWidth = 62
            } else {
                let total = monitor.network.downloadBytesPerSec + monitor.network.uploadBytesPerSec
                nView = AnyView(
                    MenuBarItemView(
                        icon: "arrow.up.arrow.down",
                        valueText: formatSingleRate(total),
                        tintColor: MectricsTheme.coral,
                        displayStyle: style,
                        isActive: netActive
                    )
                )
                nWidth = (style == .minimal) ? 38 : ((style == .compact) ? 50 : 64)
            }
            setHostingView(for: networkItem, hosting: &networkHosting, view: nView, width: nWidth, hoverType: .network)
        }
        
        // 7. Battery View
        if monitor.showBatteryInMenuBar && monitor.battery.isPresent {
            let batActive = (activeStatusItem === batteryItem && activePopover?.isShown == true)
            let bView = AnyView(
                MenuBarItemView(
                    icon: monitor.battery.isCharging ? "battery.100percent.bolt" : "battery.100percent",
                    valueText: String(format: "%.0f%%", monitor.battery.percentage),
                    tintColor: MectricsTheme.coral,
                    displayStyle: style,
                    isActive: batActive
                )
            )
            let bWidth: CGFloat = (style == .minimal) ? 32 : ((style == .compact) ? 46 : 54)
            setHostingView(for: batteryItem, hosting: &batteryHosting, view: bView, width: bWidth, hoverType: .battery)
        }
        
        // 8. Sensor View
        if monitor.showSensorInMenuBar {
            let senActive = (activeStatusItem === sensorItem && activePopover?.isShown == true)
            let sView = AnyView(
                MenuBarItemView(
                    icon: "thermometer.medium",
                    valueText: monitor.formatTemperature(monitor.sensor.cpuTemperature),
                    sparklineValues: monitor.tempHistory.values,
                    tintColor: MectricsTheme.coral,
                    displayStyle: style,
                    isActive: senActive
                )
            )
            let sWidth: CGFloat = (style == .minimal) ? 34 : ((style == .compact) ? 48 : 56)
            setHostingView(for: sensorItem, hosting: &sensorHosting, view: sView, width: sWidth, hoverType: .sensor)
        }
        
        // 9. Fans View
        if monitor.showFansInMenuBar && !monitor.sensor.fans.isEmpty {
            let fanActive = (activeStatusItem === fansItem && activePopover?.isShown == true)
            let fastest = monitor.sensor.fans.map(\.currentRPM).max() ?? 0
            let fanText = fastest > 0 ? "\(fastest)" : "0"
            let fView = AnyView(
                MenuBarItemView(
                    icon: "fan.fill",
                    valueText: "\(fanText)R",
                    tintColor: MectricsTheme.coral,
                    displayStyle: style,
                    isActive: fanActive
                )
            )
            let fWidth: CGFloat = (style == .minimal) ? 36 : ((style == .compact) ? 48 : 54)
            setHostingView(for: fansItem, hosting: &fansHosting, view: fView, width: fWidth, hoverType: .fans)
        }
        
        // 10. GPU View
        if monitor.showGPUInMenuBar {
            let gpuActive = (activeStatusItem === gpuItem && activePopover?.isShown == true)
            let gView = AnyView(
                MenuBarItemView(
                    icon: "display",
                    valueText: String(format: "%.0f%%", monitor.gpu.usagePercentage),
                    sparklineValues: monitor.gpuHistory.values,
                    tintColor: MectricsTheme.coral,
                    displayStyle: style,
                    isActive: gpuActive
                )
            )
            let gWidth: CGFloat = (style == .minimal) ? 32 : ((style == .compact) ? 46 : 56)
            setHostingView(for: gpuItem, hosting: &gpuHosting, view: gView, width: gWidth, hoverType: .gpu)
        }
    }
    
    private func setHostingView(
        for item: NSStatusItem,
        hosting: inout NSHostingView<AnyView>?,
        view: AnyView,
        width: CGFloat,
        hoverType: HoverDetailType = .master,
        isUnified: Bool = false,
        isDualStacked: Bool = false
    ) {
        guard let button = item.button else { return }
        button.window?.acceptsMouseMovedEvents = true
        
        if let h = hosting as? StatusItemHostingView {
            h.rootView = view
            h.defaultHoverType = hoverType
            h.isUnifiedMode = isUnified
            h.isDualStacked = isDualStacked
            h.statusButton = button
            h.statusItem = item
        } else {
            let h = StatusItemHostingView(rootView: view)
            h.defaultHoverType = hoverType
            h.isUnifiedMode = isUnified
            h.isDualStacked = isDualStacked
            h.statusButton = button
            h.statusItem = item
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
        
        if item.length != width {
            item.length = width
        }
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
    
    // MARK: - Actions & Click Handling
    @objc private func toggleUnified() {
        guard let button = unifiedItem.button else { return }
        let isRightClick = (NSApp.currentEvent?.type == .rightMouseUp)
        if isRightClick {
            showContextMenu(for: unifiedItem)
            return
        }
        let mouseInWin = NSApp.currentEvent?.locationInWindow ?? .zero
        let point = button.convert(mouseInWin, from: nil)
        
        let popover: NSPopover
        let sourceRect: NSRect
        let segment: UnifiedSegment
        if point.x < 32 {
            popover = unifiedPopover
            sourceRect = NSRect(x: 0, y: 0, width: 32, height: button.bounds.height)
            segment = .master
        } else if point.x < 80 {
            popover = cpuPopover
            sourceRect = NSRect(x: 32, y: 0, width: 48, height: button.bounds.height)
            segment = .cpu
        } else {
            popover = memoryPopover
            sourceRect = NSRect(x: 80, y: 0, width: max(20, button.bounds.width - 80), height: button.bounds.height)
            segment = .memory
        }
        handleItemClick(popover: popover, for: unifiedItem, sourceRect: sourceRect, segment: segment)
    }
    
    @objc private func toggleCompactHealth() {
        handleItemClick(popover: compactHealthPopover, for: compactHealthItem, sourceRect: compactHealthItem.button?.bounds ?? .zero, segment: .master)
    }
    
    @objc private func toggleDualStacked() {
        guard let button = dualStackedItem.button else { return }
        let isRightClick = (NSApp.currentEvent?.type == .rightMouseUp)
        if isRightClick {
            showContextMenu(for: dualStackedItem)
            return
        }
        let mouseInWin = NSApp.currentEvent?.locationInWindow ?? .zero
        let point = button.convert(mouseInWin, from: nil)
        let isTop = point.y > 11
        let popover = isTop ? cpuPopover! : memoryPopover!
        let segment: UnifiedSegment = isTop ? .cpu : .memory
        handleItemClick(popover: popover, for: dualStackedItem, sourceRect: button.bounds, segment: segment)
    }
    
    @objc private func toggleDisk() { handleItemClick(popover: diskPopover, for: diskItem, sourceRect: diskItem.button?.bounds ?? .zero, segment: .none) }
    @objc private func toggleMemory() { handleItemClick(popover: memoryPopover, for: memoryItem, sourceRect: memoryItem.button?.bounds ?? .zero, segment: .none) }
    @objc private func toggleCPU() { handleItemClick(popover: cpuPopover, for: cpuItem, sourceRect: cpuItem.button?.bounds ?? .zero, segment: .none) }
    @objc private func toggleNetwork() { handleItemClick(popover: networkPopover, for: networkItem, sourceRect: networkItem.button?.bounds ?? .zero, segment: .none) }
    @objc private func toggleBattery() { handleItemClick(popover: batteryPopover, for: batteryItem, sourceRect: batteryItem.button?.bounds ?? .zero, segment: .none) }
    @objc private func toggleSensor() { handleItemClick(popover: sensorPopover, for: sensorItem, sourceRect: sensorItem.button?.bounds ?? .zero, segment: .none) }
    @objc private func toggleFans() { handleItemClick(popover: fansPopover, for: fansItem, sourceRect: fansItem.button?.bounds ?? .zero, segment: .none) }
    @objc private func toggleGPU() { handleItemClick(popover: gpuPopover, for: gpuItem, sourceRect: gpuItem.button?.bounds ?? .zero, segment: .none) }
    
    // MARK: - Popover Hover & Pinning System
    
    public func handleMouseEnteredSegment(
        popover: NSPopover,
        for item: NSStatusItem,
        sourceRect: NSRect,
        segment: UnifiedSegment = .none
    ) {
        if isPopoverPinned && activePopover?.isShown == true {
            return
        }
        
        // 1. If this exact popover is already showing on this segment
        if activePopover === popover && popover.isShown {
            outsideGraceTicks = 0
            hoverOpenTimer?.invalidate()
            hoverOpenTimer = nil
            pendingTargetPopover = nil
            if activeSegment != segment {
                activeSegment = segment
                updateAllViews()
            }
            return
        }
        
        // 2. Fast Switching: If another popover is already open, switch immediately without delay
        if let current = activePopover, current.isShown, current !== popover {
            cancelHoverTimers()
            pendingTargetPopover = nil
            showPopover(popover, for: item, sourceRect: sourceRect, segment: segment, pinned: false)
            return
        }
        
        // 3. Debounce: If already waiting to open this exact target, don't re-trigger
        if pendingTargetPopover === popover && pendingTargetSegment == segment && hoverOpenTimer != nil {
            return
        }
        
        pendingTargetPopover = popover
        pendingTargetSegment = segment
        pendingTargetItem = item
        pendingTargetRect = sourceRect
        
        let requestID = UUID()
        currentHoverID = requestID
        hoverOpenTimer?.invalidate()
        hoverOpenTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self,
                      self.currentHoverID == requestID,
                      let targetItem = self.pendingTargetItem else { return }
                let targetRect = self.pendingTargetRect
                self.hoverOpenTimer = nil
                self.pendingTargetPopover = nil
                self.pendingTargetItem = nil
                self.showPopover(popover, for: targetItem, sourceRect: targetRect, segment: segment, pinned: false)
            }
        }
    }
    
    public func handleMouseExitedSegment() {
        if isPopoverPinned {
            return
        }
        
        // If mouse left before opening, cancel pending open
        if hoverOpenTimer != nil {
            cancelHoverTimers()
            pendingTargetPopover = nil
        }
        
        // Check mouse position immediately
        evaluateHoverLiveness()
    }
    
    public func handleItemClick(
        popover: NSPopover,
        for item: NSStatusItem,
        sourceRect: NSRect,
        segment: UnifiedSegment = .none
    ) {
        HoverDetailWindowController.shared.hideImmediately()
        guard item.button != nil else { return }
        
        // Luxurious Apple tactile haptic click
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        
        let isRightClick = (NSApp.currentEvent?.type == .rightMouseUp)
        if isRightClick {
            showContextMenu(for: item)
            return
        }
        
        // Standard macOS Toggle UX:
        // If this exact popover is already showing on this segment, click toggles it off
        if activePopover === popover && popover.isShown && (activeSegment == segment || segment == .none) {
            closeActivePopover()
        } else {
            closeAllPopovers()
            showPopover(popover, for: item, sourceRect: sourceRect, segment: segment, pinned: true)
        }
    }
    
    private func showPopover(
        _ popover: NSPopover,
        for item: NSStatusItem,
        sourceRect: NSRect,
        segment: UnifiedSegment,
        pinned: Bool
    ) {
        guard let button = item.button else { return }
        
        cancelHoverTimers()
        
        // 1. Guard against re-showing the same already-visible popover
        if activePopover === popover && popover.isShown {
            if activeSegment != segment {
                activeSegment = segment
                updateAllViews()
            }
            isPopoverPinned = pinned
            if !pinned {
                startHoverLivenessTimer()
            } else {
                stopHoverLivenessTimer()
            }
            return
        }
        
        // 2. Strict Single-Window Guarantee: Synchronously purge ALL other popovers instantly
        closeAllPopoversImmediately(except: popover)
        
        activePopover = popover
        activeStatusItem = item
        activeSegment = segment
        isPopoverPinned = pinned
        
        updateAllViews()
        
        if pinned {
            NSApp.activate(ignoringOtherApps: true)
            stopHoverLivenessTimer()
        }
        
        popover.show(relativeTo: sourceRect, of: button, preferredEdge: .minY)
        startMouseMonitoring()
        
        if !pinned {
            startHoverLivenessTimer()
        }
    }
    
    public func closeActivePopover() {
        cancelHoverTimers()
        stopHoverLivenessTimer()
        currentHoverID = UUID()
        stopMouseMonitoring()
        isPopoverPinned = false
        activeSegment = .none
        pendingTargetPopover = nil
        
        closeAllPopoversImmediately()
        activePopover = nil
        activeStatusItem = nil
        updateAllViews()
    }
    
    public func closeAllPopovers() {
        HoverDetailWindowController.shared.hideImmediately()
        cancelHoverTimers()
        stopHoverLivenessTimer()
        currentHoverID = UUID()
        stopMouseMonitoring()
        isPopoverPinned = false
        activePopover = nil
        activeStatusItem = nil
        activeSegment = .none
        pendingTargetPopover = nil
        
        closeAllPopoversImmediately()
        updateAllViews()
    }
    
    private func closeAllPopoversImmediately(except keepPopover: NSPopover? = nil) {
        let all: [NSPopover?] = [
            unifiedPopover, compactHealthPopover, dualStackedPopover,
            diskPopover, memoryPopover, cpuPopover, networkPopover,
            batteryPopover, sensorPopover, fansPopover, gpuPopover
        ]
        for p in all {
            guard let p = p, p !== keepPopover else { continue }
            p.animates = false
            p.performClose(nil)
            p.close()
            if let win = p.contentViewController?.view.window {
                win.orderOut(nil)
            }
            p.animates = true
        }
        
        // Ensure no orphan popover windows stay visible on screen
        for window in NSApp.windows {
            let className = String(describing: type(of: window))
            if className.contains("Popover") {
                if let keepWin = keepPopover?.contentViewController?.view.window, window === keepWin {
                    continue
                }
                window.orderOut(nil)
            }
        }
    }
    
    // MARK: - Hover Liveness Monitoring (Deterministic 40ms loop)
    private func startHoverLivenessTimer() {
        stopHoverLivenessTimer()
        outsideGraceTicks = 0
        hoverLivenessTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.evaluateHoverLiveness()
            }
        }
    }
    
    private func stopHoverLivenessTimer() {
        hoverLivenessTimer?.invalidate()
        hoverLivenessTimer = nil
        outsideGraceTicks = 0
    }
    
    private func evaluateHoverLiveness() {
        guard let popover = activePopover, popover.isShown, !isPopoverPinned else {
            stopHoverLivenessTimer()
            return
        }
        
        let mouseLoc = NSEvent.mouseLocation
        if isMouseOverActivePopoverOrButton(mouseLoc: mouseLoc) {
            outsideGraceTicks = 0
        } else {
            outsideGraceTicks += 1
            // 4 ticks * 40ms = 160ms outside -> auto close cleanly without flickering!
            if outsideGraceTicks >= 4 {
                closeActivePopover()
            }
        }
    }
    
    private func isMouseOverActivePopoverOrButton(mouseLoc: NSPoint) -> Bool {
        guard let popover = activePopover, popover.isShown else { return false }
        
        // 1. Active popover window frame (+ 6pt safety margin)
        if let popWindow = popover.contentViewController?.view.window {
            let popFrame = popWindow.frame.insetBy(dx: -6, dy: -6)
            if popFrame.contains(mouseLoc) {
                return true
            }
            
            // 2. Active status item button frame (+ 4pt safety margin)
            if let button = activeStatusItem?.button, let win = button.window {
                let rectInWin = button.convert(button.bounds, to: nil)
                let buttonScreenRect = win.convertToScreen(rectInWin).insetBy(dx: -4, dy: -4)
                if buttonScreenRect.contains(mouseLoc) {
                    return true
                }
                
                // 3. Narrow bridge between menu bar button and popover top edge
                // Only covers the narrow vertical gap between button and popover top, with button width + 24pt
                let bridgeMinY = min(buttonScreenRect.minY, popFrame.maxY) - 2
                let bridgeMaxY = max(buttonScreenRect.minY, popFrame.maxY) + 2
                let bridgeMinX = min(buttonScreenRect.minX - 12, popFrame.midX - 30)
                let bridgeMaxX = max(buttonScreenRect.maxX + 12, popFrame.midX + 30)
                let bridgeRect = NSRect(
                    x: bridgeMinX,
                    y: bridgeMinY,
                    width: max(bridgeMaxX - bridgeMinX, 20),
                    height: max(bridgeMaxY - bridgeMinY, 4)
                )
                if bridgeRect.contains(mouseLoc) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func startMouseMonitoring() {
        stopMouseMonitoring()
        
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .keyDown]) { [weak self] event in
            guard let self = self else { return event }
            
            // ESC key (code 53) closes any open popover instantly
            if event.type == .keyDown && event.keyCode == 53 {
                self.closeActivePopover()
                return nil
            }
            
            if event.type == .leftMouseDown {
                if let popWindow = self.activePopover?.contentViewController?.view.window,
                   popWindow.frame.contains(NSEvent.mouseLocation) {
                    self.isPopoverPinned = true
                    self.stopHoverLivenessTimer()
                    self.stopGlobalMouseMonitoring()
                }
            }
            return event
        }
        
        // Monitor global mouse moves while unpinned to immediately trigger liveness evaluation
        if !isPopoverPinned {
            globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.evaluateHoverLiveness()
                }
            }
        }
    }
    
    private func stopGlobalMouseMonitoring() {
        if let global = globalMouseMonitor {
            NSEvent.removeMonitor(global)
            globalMouseMonitor = nil
        }
    }
    
    private func stopMouseMonitoring() {
        if let local = localMouseMonitor {
            NSEvent.removeMonitor(local)
            localMouseMonitor = nil
        }
        stopGlobalMouseMonitoring()
    }
    
    private func cancelHoverTimers() {
        hoverOpenTimer?.invalidate()
        hoverOpenTimer = nil
        pendingTargetPopover = nil
        pendingTargetItem = nil
    }
    
    public func showContextMenu(for item: NSStatusItem) {
        guard let button = item.button else { return }
        closeAllPopovers()
        
        let menu = NSMenu()
        let isVi = LocalizationManager.shared.currentLanguage == .vietnamese
        
        let settingsItem = NSMenuItem(title: isVi ? "Cài đặt Mectrics..." : "Mectrics Settings...", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)
        
        let diagItem = NSMenuItem(title: isVi ? "Chẩn đoán hệ thống..." : "System Diagnostics...", action: #selector(openDiagnosticsAction), keyEquivalent: "d")
        diagItem.target = self
        diagItem.image = NSImage(systemSymbolName: "stethoscope", accessibilityDescription: nil)
        menu.addItem(diagItem)
        
        let logItem = NSMenuItem(title: isVi ? "Nhật ký Cảnh báo..." : "Attention Log...", action: #selector(openAttentionLogAction), keyEquivalent: "l")
        logItem.target = self
        logItem.image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: nil)
        menu.addItem(logItem)
        
        // Anti-Sleep / Keep Awake Mode
        let keepAwakeActive = SleepBlocker.shared.isKeepAwakeActive
        let keepAwakeItem = NSMenuItem(
            title: isVi ? "Chống ngủ máy (Keep Awake)" : "Keep Awake (Anti-Sleep)",
            action: #selector(toggleKeepAwakeAction),
            keyEquivalent: "k"
        )
        keepAwakeItem.target = self
        keepAwakeItem.image = NSImage(systemSymbolName: keepAwakeActive ? "cup.and.saucer.fill" : "cup.and.saucer", accessibilityDescription: nil)
        keepAwakeItem.state = keepAwakeActive ? .on : .off
        menu.addItem(keepAwakeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quick Theme Selection
        let themeMenu = NSMenu()
        for theme in AccentTheme.allCases {
            let tItem = NSMenuItem(title: theme.rawValue, action: #selector(selectThemeAction(_:)), keyEquivalent: "")
            tItem.target = self
            tItem.representedObject = theme.rawValue
            if ThemeManager.shared.currentTheme == theme {
                tItem.state = .on
            }
            themeMenu.addItem(tItem)
        }
        let themeSubmenuItem = NSMenuItem(title: isVi ? "Màu sắc chủ đạo" : "Accent Color", action: nil, keyEquivalent: "")
        themeSubmenuItem.image = NSImage(systemSymbolName: "paintpalette", accessibilityDescription: nil)
        themeSubmenuItem.submenu = themeMenu
        menu.addItem(themeSubmenuItem)
        
        // Quick Language Selection
        let langMenu = NSMenu()
        for lang in AppLanguage.allCases {
            let lItem = NSMenuItem(title: lang.displayName, action: #selector(selectLanguageAction(_:)), keyEquivalent: "")
            lItem.target = self
            lItem.representedObject = lang.rawValue
            if LocalizationManager.shared.currentLanguage == lang {
                lItem.state = .on
            }
            langMenu.addItem(lItem)
        }
        let langSubmenuItem = NSMenuItem(title: isVi ? "Ngôn ngữ" : "Language", action: nil, keyEquivalent: "")
        langSubmenuItem.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        langSubmenuItem.submenu = langMenu
        menu.addItem(langSubmenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: isVi ? "Thoát Mectrics" : "Quit Mectrics", action: #selector(quitAppAction), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }
    
    @objc private func openSettingsAction() {
        AppState.shared.openSettings(tab: .menuBar)
    }
    
    @objc private func openDiagnosticsAction() {
        AppState.shared.openDiagnostics()
    }
    
    @objc private func openAttentionLogAction() {
        AppState.shared.openAttentionLog()
    }
    
    @objc private func toggleKeepAwakeAction() {
        SleepBlocker.shared.toggle()
    }
    
    @objc private func selectThemeAction(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let theme = AccentTheme(rawValue: raw) {
            ThemeManager.shared.currentTheme = theme
            updateAllViews()
        }
    }
    
    @objc private func selectLanguageAction(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let lang = AppLanguage(rawValue: raw) {
            LocalizationManager.shared.currentLanguage = lang
            updateAllViews()
        }
    }
    
    @objc private func quitAppAction() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Status Item Hosting View with Mouse Tracking for Hover Popovers
public final class StatusItemHostingView: NSHostingView<AnyView> {
    public var defaultHoverType: HoverDetailType = .master
    public var isUnifiedMode: Bool = false
    public var isDualStacked: Bool = false
    public weak var statusButton: NSStatusBarButton?
    public weak var statusItem: NSStatusItem?
    
    private var trackingArea: NSTrackingArea?
    
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        handleHoverEvent(event)
    }
    
    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        handleHoverEvent(event)
    }
    
    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        StatusBarManager.shared.handleMouseExitedSegment()
    }
    
    public override func mouseDown(with event: NSEvent) {
        handleClickEvent(event)
    }
    
    public override func rightMouseDown(with event: NSEvent) {
        guard let item = statusItem else { return }
        StatusBarManager.shared.showContextMenu(for: item)
    }
    
    private func handleClickEvent(_ event: NSEvent) {
        guard let item = statusItem else { return }
        let point = convert(event.locationInWindow, from: nil)
        let (popover, sourceRect, segment) = resolveTarget(at: point)
        StatusBarManager.shared.handleItemClick(popover: popover, for: item, sourceRect: sourceRect, segment: segment)
    }
    
    private func handleHoverEvent(_ event: NSEvent) {
        guard let item = statusItem else { return }
        let point = convert(event.locationInWindow, from: nil)
        let (popover, sourceRect, segment) = resolveTarget(at: point)
        StatusBarManager.shared.handleMouseEnteredSegment(popover: popover, for: item, sourceRect: sourceRect, segment: segment)
    }
    
    private func resolveTarget(at point: NSPoint) -> (NSPopover, NSRect, UnifiedSegment) {
        let mgr = StatusBarManager.shared
        guard let item = statusItem else {
            return (mgr.popover(for: defaultHoverType, item: NSStatusItem()), bounds, .none)
        }
        
        if isUnifiedMode {
            if point.x < 32 {
                return (mgr.popover(for: .master, item: item), NSRect(x: 0, y: 0, width: 32, height: bounds.height), .master)
            } else if point.x < 80 {
                return (mgr.popover(for: .cpu, item: item), NSRect(x: 32, y: 0, width: 48, height: bounds.height), .cpu)
            } else {
                return (mgr.popover(for: .memory, item: item), NSRect(x: 80, y: 0, width: max(20, bounds.width - 80), height: bounds.height), .memory)
            }
        } else if isDualStacked {
            if point.y > 11 {
                return (mgr.popover(for: .cpu, item: item), bounds, .cpu)
            } else {
                return (mgr.popover(for: .memory, item: item), bounds, .memory)
            }
        } else {
            return (mgr.popover(for: defaultHoverType, item: item), bounds, .none)
        }
    }
}
