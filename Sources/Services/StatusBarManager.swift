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
    
    // Status item content views (static bitmaps rendered from SwiftUI, see StatusItemHostingView)
    private var unifiedHosting: StatusItemHostingView?
    private var compactHealthHosting: StatusItemHostingView?
    private var dualStackedHosting: StatusItemHostingView?
    private var diskHosting: StatusItemHostingView?
    private var memoryHosting: StatusItemHostingView?
    private var cpuHosting: StatusItemHostingView?
    private var networkHosting: StatusItemHostingView?
    private var batteryHosting: StatusItemHostingView?
    private var sensorHosting: StatusItemHostingView?
    private var fansHosting: StatusItemHostingView?
    private var gpuHosting: StatusItemHostingView?
    private var lastHostingSignatures: [ObjectIdentifier: AnyHashable] = [:]
    
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
        let monitor = self.monitor
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
    
    /// Content factories, keyed by popover. Hosting controllers are only attached while a popover is shown:
    /// a detached-but-alive NSHostingController keeps re-rendering on every SystemMonitor tick
    /// (and CPU/Memory bodies spawn /bin/ps), burning CPU 24/7 even with no popover open.
    private var popoverContentFactories: [ObjectIdentifier: () -> NSViewController] = [:]

    private func createPopover<Content: View>(contentView: @autoclosure @escaping () -> Content) -> NSPopover {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .vibrantDark)
        popover.delegate = self
        popoverContentFactories[ObjectIdentifier(popover)] = { NSHostingController(rootView: contentView()) }
        return popover
    }

    private func attachContentIfNeeded(_ popover: NSPopover) {
        guard popover.contentViewController == nil,
              let factory = popoverContentFactories[ObjectIdentifier(popover)] else { return }
        popover.contentViewController = factory()
    }

    private func detachContent(_ popover: NSPopover) {
        guard !popover.isShown else { return }
        popover.contentViewController = nil
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
        if let closed = notification.object as? NSPopover {
            detachContent(closed)
        }
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
            setVisible(unifiedItem, true)
            setVisible(compactHealthItem, false)
            setVisible(dualStackedItem, false)
            setVisible(diskItem, false)
            setVisible(memoryItem, false)
            setVisible(cpuItem, false)
            setVisible(networkItem, false)
            setVisible(batteryItem, false)
            setVisible(sensorItem, false)
            setVisible(fansItem, false)
            setVisible(gpuItem, false)
            
        case .dualStacked:
            setVisible(unifiedItem, false)
            setVisible(compactHealthItem, false)
            setVisible(dualStackedItem, true)
            setVisible(diskItem, false)
            setVisible(memoryItem, false)
            setVisible(cpuItem, false)
            setVisible(networkItem, false)
            setVisible(batteryItem, false)
            setVisible(sensorItem, false)
            setVisible(fansItem, false)
            setVisible(gpuItem, false)
            
        case .compactHealth:
            setVisible(unifiedItem, false)
            setVisible(compactHealthItem, true)
            setVisible(dualStackedItem, false)
            setVisible(diskItem, false)
            setVisible(memoryItem, false)
            setVisible(cpuItem, false)
            setVisible(networkItem, false)
            setVisible(batteryItem, false)
            setVisible(sensorItem, false)
            setVisible(fansItem, false)
            setVisible(gpuItem, false)
            
        case .separate:
            setVisible(unifiedItem, false)
            setVisible(compactHealthItem, false)
            setVisible(dualStackedItem, false)
            setVisible(diskItem, monitor.showDiskInMenuBar)
            setVisible(memoryItem, monitor.showMemoryInMenuBar)
            setVisible(cpuItem, monitor.showCPUInMenuBar)
            setVisible(networkItem, monitor.showNetworkInMenuBar)
            setVisible(batteryItem, monitor.showBatteryInMenuBar && monitor.battery.isPresent)
            setVisible(sensorItem, monitor.showSensorInMenuBar)
            setVisible(fansItem, monitor.showFansInMenuBar && !monitor.sensor.fans.isEmpty)
            setVisible(gpuItem, monitor.showGPUInMenuBar)
        }
    }
    
    /// Each `isVisible` write is a FrontBoard scene update (IPC), even when the value is unchanged.
    private func setVisible(_ item: NSStatusItem, _ visible: Bool) {
        if item.isVisible != visible {
            item.isVisible = visible
        }
    }
    
    public func updateAllViews() {
        let mode = monitor.menuBarMode
        let style = monitor.menuBarDisplayStyle
        // Round to what the menu bar shows so sub-percent jitter doesn't force a redraw.
        let cpuUsage = monitor.cpu.totalUsage.rounded()
        let memUsage = monitor.memory.usagePercentage.rounded()
        
        // 0. Unified Sample Mode ([M] CPU % RAM %)
        if mode == .unified {
            let uActive = (activeStatusItem === unifiedItem && activePopover?.isShown == true)
            let uSegment = uActive ? activeSegment : .none
            setHostingView(
                for: unifiedItem, hosting: &unifiedHosting,
                view: { AnyView(UnifiedSampleMenuBarView(cpuUsage: cpuUsage, memUsage: memUsage, isActive: uActive, activeSegment: uSegment)) },
                width: 130, hoverType: .master, isUnified: true,
                signature: [cpuUsage, memUsage, uActive, uSegment] as [AnyHashable]
            )
            return
        }
        
        // 1. Compact Health View
        if mode == .compactHealth {
            let chActive = (activeStatusItem === compactHealthItem && activePopover?.isShown == true)
            let level = monitor.health.statusLevel
            setHostingView(
                for: compactHealthItem, hosting: &compactHealthHosting,
                view: { AnyView(CompactHealthBarView(statusLevel: level, isActive: chActive)) },
                width: 26, hoverType: .master,
                signature: [level, chActive] as [AnyHashable]
            )
            return
        }
        
        // 2. Dual Stacked View (CPU & RAM 35px Mini Item)
        if mode == .dualStacked {
            let dualActive = (activeStatusItem === dualStackedItem && activePopover?.isShown == true)
            let dualSegment = dualActive ? activeSegment : .none
            setHostingView(
                for: dualStackedItem, hosting: &dualStackedHosting,
                view: { AnyView(DualStackedMenuBarView(cpuUsage: cpuUsage, memUsage: memUsage, isActive: dualActive, activeSegment: dualSegment)) },
                width: 38, hoverType: .master, isDualStacked: true,
                signature: [cpuUsage, memUsage, dualActive, dualSegment] as [AnyHashable]
            )
            return
        }
        
        // 3. Disk View
        if monitor.showDiskInMenuBar {
            let diskActive = (activeStatusItem === diskItem && activePopover?.isShown == true)
            let diskText = (monitor.diskDisplayMode == .percentage)
                ? String(format: "%.0f%%", monitor.disk.usagePercentage)
                : "\(monitor.disk.freeBytes / (1024 * 1024 * 1024))GB"
            let dWidth: CGFloat = (style == .minimal) ? 34 : ((style == .compact) ? 48 : 58)
            setHostingView(
                for: diskItem, hosting: &diskHosting,
                view: { AnyView(MenuBarItemView(icon: "internaldrive", valueText: diskText, tintColor: MectricsTheme.coral, displayStyle: style, isActive: diskActive)) },
                width: dWidth, hoverType: .disk,
                signature: [diskText, style, diskActive] as [AnyHashable]
            )
        }
        
        // 4. Memory View
        if monitor.showMemoryInMenuBar {
            let memActive = (activeStatusItem === memoryItem && activePopover?.isShown == true)
            let memText = String(format: "%.0f%%", memUsage)
            let memSpark = (monitor.showMemorySparkline && style == .full) ? monitor.memoryHistory.values : nil
            let memWidth: CGFloat = (style == .minimal) ? 32 :
                ((style == .compact) ? 48 :
                (monitor.showMemorySparkline ? 78 : 54))
            setHostingView(
                for: memoryItem, hosting: &memoryHosting,
                view: { AnyView(MenuBarItemView(icon: "memorychip", valueText: memText, sparklineValues: memSpark, isBoxedSparkline: true, tintColor: MectricsTheme.coral, displayStyle: style, isActive: memActive)) },
                width: memWidth, hoverType: .memory,
                signature: [memText, memSpark, style, memActive] as [AnyHashable]
            )
        }
        
        // 5. CPU View
        if monitor.showCPUInMenuBar {
            let cpuActive = (activeStatusItem === cpuItem && activePopover?.isShown == true)
            let cpuText = String(format: "%.0f%%", cpuUsage)
            let cpuSpark = (monitor.showCPUSparkline && style == .full) ? monitor.cpuHistory.values : nil
            let cpuWidth: CGFloat = (style == .minimal) ? 32 :
                ((style == .compact) ? 48 :
                (monitor.showCPUSparkline ? 82 : 54))
            setHostingView(
                for: cpuItem, hosting: &cpuHosting,
                view: { AnyView(MenuBarItemView(icon: "cpu", valueText: cpuText, sparklineValues: cpuSpark, isBoxedSparkline: false, tintColor: MectricsTheme.coral, displayStyle: style, isActive: cpuActive)) },
                width: cpuWidth, hoverType: .cpu,
                signature: [cpuText, cpuSpark, style, cpuActive] as [AnyHashable]
            )
        }
        
        // 6. Network View
        if monitor.showNetworkInMenuBar {
            let netActive = (activeStatusItem === networkItem && activePopover?.isShown == true)
            if monitor.networkDisplayMode == .stacked {
                let down = monitor.network.downloadBytesPerSec
                let up = monitor.network.uploadBytesPerSec
                setHostingView(
                    for: networkItem, hosting: &networkHosting,
                    view: { AnyView(NetworkMenuBarView(downloadBytes: down, uploadBytes: up, tintColor: MectricsTheme.coral, isActive: netActive)) },
                    width: 62, hoverType: .network,
                    signature: ["stacked", formatSingleRate(down), formatSingleRate(up), netActive] as [AnyHashable]
                )
            } else {
                let rateText = formatSingleRate(monitor.network.downloadBytesPerSec + monitor.network.uploadBytesPerSec)
                let nWidth: CGFloat = (style == .minimal) ? 38 : ((style == .compact) ? 50 : 64)
                setHostingView(
                    for: networkItem, hosting: &networkHosting,
                    view: { AnyView(MenuBarItemView(icon: "arrow.up.arrow.down", valueText: rateText, tintColor: MectricsTheme.coral, displayStyle: style, isActive: netActive)) },
                    width: nWidth, hoverType: .network,
                    signature: ["single", rateText, style, netActive] as [AnyHashable]
                )
            }
        }
        
        // 7. Battery View
        if monitor.showBatteryInMenuBar && monitor.battery.isPresent {
            let batActive = (activeStatusItem === batteryItem && activePopover?.isShown == true)
            let batIcon = monitor.battery.isCharging ? "battery.100percent.bolt" : "battery.100percent"
            let batText = String(format: "%.0f%%", monitor.battery.percentage)
            let bWidth: CGFloat = (style == .minimal) ? 32 : ((style == .compact) ? 46 : 54)
            setHostingView(
                for: batteryItem, hosting: &batteryHosting,
                view: { AnyView(MenuBarItemView(icon: batIcon, valueText: batText, tintColor: MectricsTheme.coral, displayStyle: style, isActive: batActive)) },
                width: bWidth, hoverType: .battery,
                signature: [batIcon, batText, style, batActive] as [AnyHashable]
            )
        }
        
        // 8. Sensor View
        if monitor.showSensorInMenuBar {
            let senActive = (activeStatusItem === sensorItem && activePopover?.isShown == true)
            let tempText = monitor.formatTemperature(monitor.sensor.cpuTemperature)
            let tempSpark = style == .full ? monitor.tempHistory.values : nil
            let sWidth: CGFloat = (style == .minimal) ? 34 : ((style == .compact) ? 48 : 56)
            setHostingView(
                for: sensorItem, hosting: &sensorHosting,
                view: { AnyView(MenuBarItemView(icon: "thermometer.medium", valueText: tempText, sparklineValues: tempSpark, tintColor: MectricsTheme.coral, displayStyle: style, isActive: senActive)) },
                width: sWidth, hoverType: .sensor,
                signature: [tempText, tempSpark, style, senActive] as [AnyHashable]
            )
        }
        
        // 9. Fans View
        if monitor.showFansInMenuBar && !monitor.sensor.fans.isEmpty {
            let fanActive = (activeStatusItem === fansItem && activePopover?.isShown == true)
            let fastest = monitor.sensor.fans.map(\.currentRPM).max() ?? 0
            let fanText = "\(fastest > 0 ? "\(fastest)" : "0")R"
            let fWidth: CGFloat = (style == .minimal) ? 36 : ((style == .compact) ? 48 : 54)
            setHostingView(
                for: fansItem, hosting: &fansHosting,
                view: { AnyView(MenuBarItemView(icon: "fan.fill", valueText: fanText, tintColor: MectricsTheme.coral, displayStyle: style, isActive: fanActive)) },
                width: fWidth, hoverType: .fans,
                signature: [fanText, style, fanActive] as [AnyHashable]
            )
        }
        
        // 10. GPU View
        if monitor.showGPUInMenuBar {
            let gpuActive = (activeStatusItem === gpuItem && activePopover?.isShown == true)
            let gpuText = String(format: "%.0f%%", monitor.gpu.usagePercentage)
            let gpuSpark = style == .full ? monitor.gpuHistory.values : nil
            let gWidth: CGFloat = (style == .minimal) ? 32 : ((style == .compact) ? 46 : 56)
            setHostingView(
                for: gpuItem, hosting: &gpuHosting,
                view: { AnyView(MenuBarItemView(icon: "display", valueText: gpuText, sparklineValues: gpuSpark, tintColor: MectricsTheme.coral, displayStyle: style, isActive: gpuActive)) },
                width: gWidth, hoverType: .gpu,
                signature: [gpuText, gpuSpark, style, gpuActive] as [AnyHashable]
            )
        }
    }
    
    private func setHostingView(
        for item: NSStatusItem,
        hosting: inout StatusItemHostingView?,
        view: () -> AnyView,
        width: CGFloat,
        hoverType: HoverDetailType = .master,
        isUnified: Bool = false,
        isDualStacked: Bool = false,
        signature: AnyHashable
    ) {
        guard let button = item.button else { return }
        
        let h: StatusItemHostingView
        if let existing = hosting {
            h = existing
        } else {
            button.window?.acceptsMouseMovedEvents = true
            button.imagePosition = .imageOnly
            // Transparent overlay for hover/click routing only. Autoresizing instead of constraints keeps
            // the status item's size-fitting pass (run on every content change) out of the Auto Layout engine.
            h = StatusItemHostingView(frame: button.bounds)
            h.autoresizingMask = [.width, .height]
            button.addSubview(h)
            hosting = h
        }
        h.defaultHoverType = hoverType
        h.isUnifiedMode = isUnified
        h.isDualStacked = isDualStacked
        h.statusButton = button
        h.statusItem = item
        
        // A live NSHostingView here was the app's dominant idle cost: every value change re-ran SwiftUI
        // layout inside AppKit's replicant snapshot (once per menu bar / display). Instead the SwiftUI view
        // is rendered once into a bitmap and handed to the button's native image path.
        let screen = button.window?.screen ?? NSScreen.main
        let scale = screen?.backingScaleFactor ?? 2
        let colorSpace = screen?.colorSpace?.cgColorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let key = ObjectIdentifier(item)
        let fullSignature: AnyHashable = [signature, width, scale, colorSpace.name as String? ?? ""] as [AnyHashable]
        if lastHostingSignatures[key] != fullSignature || button.image == nil {
            lastHostingSignatures[key] = fullSignature
            button.image = renderedImage(for: fullSignature, width: width, scale: scale, colorSpace: colorSpace, view: view)
        }
        
        // Never clip: grow the item when the rendered content is wider than the preset width
        // (e.g. "100%" or a wide SF Symbol next to the value).
        let length = max(width, ceil((button.image?.size.width ?? 0) + 2))
        if item.length != length {
            item.length = length
        }
    }
    
    /// Rendered bitmaps keyed by signature. Values like "37%" recur constantly, so most ticks skip
    /// ImageRenderer (which builds a fresh SwiftUI view graph per render) entirely.
    private var renderedImageCache: [AnyHashable: NSImage] = [:]
    private static let renderedImageCacheLimit = 256
    
    private func renderedImage(
        for signature: AnyHashable,
        width: CGFloat,
        scale: CGFloat,
        colorSpace: CGColorSpace,
        view: () -> AnyView
    ) -> NSImage? {
        if let cached = renderedImageCache[signature] {
            return cached
        }
        let renderer = ImageRenderer(content: view().lineLimit(1))
        // Fixed menu bar height like the former hosting view, so text can't wrap onto a second line.
        renderer.proposedSize = ProposedViewSize(width: width, height: NSStatusBar.system.thickness)
        renderer.scale = scale
        renderer.isOpaque = false
        guard let rendered = renderer.cgImage else { return nil }
        // ImageRenderer yields RGBA sRGB; the menu bar snapshot would convert pixel format and color-match
        // on every redraw. Convert once to the display's native BGRA layout and color space.
        let cgImage = Self.nativeImage(from: rendered, colorSpace: colorSpace) ?? rendered
        let image = NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width) / scale, height: CGFloat(cgImage.height) / scale))
        image.isTemplate = false
        // Sparkline signatures never repeat; a full reset is cheaper than LRU bookkeeping.
        if renderedImageCache.count >= Self.renderedImageCacheLimit {
            renderedImageCache.removeAll(keepingCapacity: true)
        }
        renderedImageCache[signature] = image
        return image
    }
    
    private static func nativeImage(from image: CGImage, colorSpace: CGColorSpace) -> CGImage? {
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let ctx = CGContext(
            data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return ctx.makeImage()
    }
    
    /// Re-renders every status item bitmap, e.g. after moving to a display with a different scale.
    fileprivate func invalidateStatusItemImages() {
        lastHostingSignatures.removeAll()
        renderedImageCache.removeAll()
        updateAllViews()
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
        
        attachContentIfNeeded(popover)
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
    
    /// Called when machine is entering sleep or screens turn off
    public func prepareForSleep() {
        closeAllPopovers()
        cancelHoverTimers()
        stopHoverLivenessTimer()
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
            detachContent(p)
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

// MARK: - Status Item Content View with Mouse Tracking for Hover Popovers
/// Transparent overlay on the status button: the button draws the pre-rendered image, this view only
/// routes hover and clicks (including per-segment targeting in unified / dual stacked modes).
public final class StatusItemHostingView: NSView {
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
    
    private var lastBackingScale: CGFloat?
    
    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        guard let scale = window?.backingScaleFactor else { return }
        defer { lastBackingScale = scale }
        guard let previous = lastBackingScale, previous != scale else { return }
        // Async: this can fire while StatusBarManager.shared is still initializing.
        DispatchQueue.main.async {
            StatusBarManager.shared.invalidateStatusItemImages()
        }
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
