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
        activeStatusItem != nil
    }
    
    public func popoverDidClose(_ notification: Notification) {
        activeStatusItem = nil
        updateAllViews()
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
        if mode == .unified {
            let uActive = (activeStatusItem === unifiedItem)
            let uView = AnyView(
                UnifiedSampleMenuBarView(
                    cpuUsage: monitor.cpu.totalUsage,
                    memUsage: monitor.memory.usagePercentage,
                    isActive: uActive
                )
            )
            setHostingView(for: unifiedItem, hosting: &unifiedHosting, view: uView, width: uActive ? 134 : 126, hoverType: .master, isUnified: true)
            return
        }
        
        // 1. Compact Health View
        if mode == .compactHealth {
            let chActive = (activeStatusItem === compactHealthItem)
            let chView = AnyView(
                CompactHealthBarView(statusLevel: monitor.health.statusLevel, isActive: chActive)
            )
            setHostingView(for: compactHealthItem, hosting: &compactHealthHosting, view: chView, width: chActive ? 28 : 22, hoverType: .master)
            return
        }
        
        // 2. Dual Stacked View (CPU & RAM 35px Mini Item)
        if mode == .dualStacked {
            let dualActive = (activeStatusItem === dualStackedItem)
            let dualView = AnyView(
                DualStackedMenuBarView(
                    cpuUsage: monitor.cpu.totalUsage,
                    memUsage: monitor.memory.usagePercentage,
                    isActive: dualActive
                )
            )
            setHostingView(for: dualStackedItem, hosting: &dualStackedHosting, view: dualView, width: dualActive ? 42 : 36, hoverType: .master, isDualStacked: true)
            return
        }
        
        // 3. Disk View
        if monitor.showDiskInMenuBar {
            let diskActive = (activeStatusItem === diskItem)
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
            let dWidth: CGFloat = (style == .minimal) ? (diskActive ? 38 : 32) : ((style == .compact) ? (diskActive ? 52 : 46) : (diskActive ? 64 : 56))
            setHostingView(for: diskItem, hosting: &diskHosting, view: dView, width: dWidth, hoverType: .disk)
        }
        
        // 4. Memory View
        if monitor.showMemoryInMenuBar {
            let memActive = (activeStatusItem === memoryItem)
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
            let memWidth: CGFloat = (style == .minimal) ? (memActive ? 36 : 30) :
                ((style == .compact) ? (memActive ? 52 : 46) :
                (monitor.showMemorySparkline ? (memActive ? 82 : 74) : (memActive ? 58 : 50)))
            setHostingView(for: memoryItem, hosting: &memoryHosting, view: mView, width: memWidth, hoverType: .memory)
        }
        
        // 5. CPU View
        if monitor.showCPUInMenuBar {
            let cpuActive = (activeStatusItem === cpuItem)
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
            let cpuWidth: CGFloat = (style == .minimal) ? (cpuActive ? 36 : 30) :
                ((style == .compact) ? (cpuActive ? 52 : 46) :
                (monitor.showCPUSparkline ? (cpuActive ? 86 : 78) : (cpuActive ? 58 : 50)))
            setHostingView(for: cpuItem, hosting: &cpuHosting, view: cView, width: cpuWidth, hoverType: .cpu)
        }
        
        // 6. Network View
        if monitor.showNetworkInMenuBar {
            let netActive = (activeStatusItem === networkItem)
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
                nWidth = netActive ? 66 : 58
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
                nWidth = (style == .minimal) ? (netActive ? 42 : 36) :
                    ((style == .compact) ? (netActive ? 56 : 48) : (netActive ? 70 : 62))
            }
            setHostingView(for: networkItem, hosting: &networkHosting, view: nView, width: nWidth, hoverType: .network)
        }
        
        // 7. Battery View
        if monitor.showBatteryInMenuBar && monitor.battery.isPresent {
            let batActive = (activeStatusItem === batteryItem)
            let bView = AnyView(
                MenuBarItemView(
                    icon: monitor.battery.isCharging ? "battery.100percent.bolt" : "battery.100percent",
                    valueText: String(format: "%.0f%%", monitor.battery.percentage),
                    tintColor: MectricsTheme.coral,
                    displayStyle: style,
                    isActive: batActive
                )
            )
            let bWidth: CGFloat = (style == .minimal) ? (batActive ? 36 : 30) :
                ((style == .compact) ? (batActive ? 50 : 44) : (batActive ? 58 : 50))
            setHostingView(for: batteryItem, hosting: &batteryHosting, view: bView, width: bWidth, hoverType: .battery)
        }
        
        // 8. Sensor View
        if monitor.showSensorInMenuBar {
            let senActive = (activeStatusItem === sensorItem)
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
            let sWidth: CGFloat = (style == .minimal) ? (senActive ? 38 : 32) :
                ((style == .compact) ? (senActive ? 52 : 46) : (senActive ? 62 : 54))
            setHostingView(for: sensorItem, hosting: &sensorHosting, view: sView, width: sWidth, hoverType: .sensor)
        }
        
        // 9. Fans View
        if monitor.showFansInMenuBar && !monitor.sensor.fans.isEmpty {
            let fanActive = (activeStatusItem === fansItem)
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
            let fWidth: CGFloat = (style == .minimal) ? (fanActive ? 42 : 36) :
                ((style == .compact) ? (fanActive ? 52 : 46) : (fanActive ? 58 : 50))
            setHostingView(for: fansItem, hosting: &fansHosting, view: fView, width: fWidth, hoverType: .fans)
        }
        
        // 10. GPU View
        if monitor.showGPUInMenuBar {
            let gpuActive = (activeStatusItem === gpuItem)
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
            let gWidth: CGFloat = (style == .minimal) ? (gpuActive ? 36 : 30) :
                ((style == .compact) ? (gpuActive ? 50 : 44) : (gpuActive ? 60 : 52))
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
        } else {
            let h = StatusItemHostingView(rootView: view)
            h.defaultHoverType = hoverType
            h.isUnifiedMode = isUnified
            h.isDualStacked = isDualStacked
            h.statusButton = button
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
    
    // MARK: - Actions
    @objc private func toggleUnified() { toggle(unifiedPopover, for: unifiedItem) }
    @objc private func toggleCompactHealth() { toggle(compactHealthPopover, for: compactHealthItem) }
    @objc private func toggleDualStacked() { toggle(dualStackedPopover, for: dualStackedItem) }
    @objc private func toggleDisk() { toggle(diskPopover, for: diskItem) }
    @objc private func toggleMemory() { toggle(memoryPopover, for: memoryItem) }
    @objc private func toggleCPU() { toggle(cpuPopover, for: cpuItem) }
    @objc private func toggleNetwork() { toggle(networkPopover, for: networkItem) }
    @objc private func toggleBattery() { toggle(batteryPopover, for: batteryItem) }
    @objc private func toggleSensor() { toggle(sensorPopover, for: sensorItem) }
    @objc private func toggleFans() { toggle(fansPopover, for: fansItem) }
    @objc private func toggleGPU() { toggle(gpuPopover, for: gpuItem) }
    
    private func toggle(_ popover: NSPopover, for item: NSStatusItem) {
        HoverDetailWindowController.shared.hideImmediately()
        guard let button = item.button else { return }
        
        let isRightClick = (NSApp.currentEvent?.type == .rightMouseUp)
        if isRightClick {
            showContextMenu(for: item)
            return
        }
        
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
    
    private func showContextMenu(for item: NSStatusItem) {
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
    
    public func closeAllPopovers() {
        HoverDetailWindowController.shared.hideImmediately()
        [unifiedPopover, compactHealthPopover, dualStackedPopover, diskPopover, memoryPopover, cpuPopover, networkPopover, batteryPopover, sensorPopover, fansPopover, gpuPopover].forEach {
            $0?.performClose(nil)
        }
    }
}

// MARK: - Status Item Hosting View with Mouse Tracking for Hover Cards
public final class StatusItemHostingView: NSHostingView<AnyView> {
    public var defaultHoverType: HoverDetailType = .master
    public var isUnifiedMode: Bool = false
    public var isDualStacked: Bool = false
    public weak var statusButton: NSStatusBarButton?
    
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
        guard let button = statusButton ?? superview as? NSStatusBarButton else { return }
        let type = resolveHoverType(at: convert(event.locationInWindow, from: nil))
        HoverDetailWindowController.shared.mouseEnteredAnchor(type: type, anchorView: button)
    }
    
    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        guard let button = statusButton ?? superview as? NSStatusBarButton else { return }
        let type = resolveHoverType(at: convert(event.locationInWindow, from: nil))
        HoverDetailWindowController.shared.mouseEnteredAnchor(type: type, anchorView: button)
    }
    
    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        HoverDetailWindowController.shared.mouseExitedAnchor()
    }
    
    private func resolveHoverType(at point: NSPoint) -> HoverDetailType {
        if isUnifiedMode {
            // In Unified Sample View:
            // [M] is roughly 0..32px
            // CPU metric is roughly 32..80px
            // RAM metric is roughly 80..134px
            if point.x < 32 {
                return .master
            } else if point.x < 80 {
                return .cpu
            } else {
                return .memory
            }
        } else if isDualStacked {
            // Dual stacked has CPU on top, RAM on bottom (height is ~22px)
            return point.y > 11 ? .cpu : .memory
        } else {
            return defaultHoverType
        }
    }
}
