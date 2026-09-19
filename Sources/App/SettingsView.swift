import SwiftUI
import UserNotifications
import AppKit

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case menuBar = "Menu Bar"
    case alerts = "Alerts"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .general: return "gearshape"
        case .menuBar: return "square.grid.2x2"
        case .alerts: return "bell"
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var locManager = LocalizationManager.shared
    @State private var selectedTab: SettingsTab
    @Environment(\.dismiss) private var dismiss
    
    // Launch at login state
    @State private var launchAtLogin: Bool = LaunchAtLoginManager.isEnabled
    
    // Configurable Rules
    @AppStorage("rule_cpu_enabled") private var cpuRuleEnabled = true
    @AppStorage("rule_cpu_thresh") private var cpuRuleThresh = 85
    @AppStorage("rule_cpu_delay") private var cpuRuleDelay = 30
    
    @AppStorage("rule_mem_enabled") private var memRuleEnabled = false
    @AppStorage("rule_mem_thresh") private var memRuleThresh = 90
    @AppStorage("rule_mem_delay") private var memRuleDelay = 30
    
    @AppStorage("rule_bat_enabled") private var batRuleEnabled = false
    @AppStorage("rule_bat_thresh") private var batRuleThresh = 20
    @AppStorage("rule_bat_delay") private var batRuleDelay = 30
    
    @AppStorage("rule_disk_enabled") private var diskRuleEnabled = true
    @AppStorage("rule_disk_thresh") private var diskRuleThresh = 90
    @AppStorage("rule_disk_delay") private var diskRuleDelay = 30
    
    @AppStorage("rule_diskfree_enabled") private var diskFreeRuleEnabled = false
    @AppStorage("rule_diskfree_thresh") private var diskFreeRuleThresh = 20
    
    @AppStorage("rule_gpu_enabled") private var gpuRuleEnabled = false
    @AppStorage("rule_gpu_thresh") private var gpuRuleThresh = 90
    
    @AppStorage("rule_temp_enabled") private var tempRuleEnabled = false
    @AppStorage("rule_temp_thresh") private var tempRuleThresh = 85
    
    @AppStorage("rule_play_sound") private var playAlertSound = true
    
    @State private var testNotificationSent = false
    @State private var cliInstallStatus: String? = nil
    
    public init(monitor: SystemMonitor, initialTab: SettingsTab = .menuBar) {
        self.monitor = monitor
        self._selectedTab = State(initialValue: initialTab)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Window Toolbar (Matches Image 5)
            HStack {
                Text(loc(selectedTab.rawValue))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Segmented tab switcher buttons
                HStack(spacing: 4) {
                    ForEach(SettingsTab.allCases) { tab in
                        let isActive = (selectedTab == tab)
                        Button {
                            selectedTab = tab
                            SettingsWindowController.shared.updateTitle(loc(tab.rawValue))
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(isActive ? MectricsTheme.coral : MectricsTheme.textSecondary)
                                Text(loc(tab.rawValue))
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(isActive ? .white : MectricsTheme.textSecondary)
                            }
                            .frame(width: 72, height: 44)
                            .background(isActive ? MectricsTheme.coral.opacity(0.16) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isActive ? MectricsTheme.coral.opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(white: 0.13))
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch selectedTab {
                    case .menuBar:
                        menuBarTabContent
                    case .alerts:
                        alertsTabContent
                    case .general:
                        generalTabContent
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 550, height: 640)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .preferredColorScheme(.dark)
        .onAppear {
            syncRulesToEngine()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("didSelectSettingsTab"))) { notif in
            if let tab = notif.object as? SettingsTab {
                selectedTab = tab
            }
        }
    }
    
    // MARK: - Status Bar / Menu Bar Tab
    private var menuBarTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Live Status Bar Preview Box
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(loc("Live Status Bar Preview"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MectricsTheme.textSecondary)
                    Spacer()
                    Text(loc("macOS Menu Bar"))
                        .font(.system(size: 10))
                        .foregroundStyle(MectricsTheme.textTertiary)
                }
                
                HStack(spacing: 14) {
                    if monitor.useCompactHealthBar {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.shield")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(MectricsTheme.coral)
                            Text(loc("All systems normal"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    } else {
                        if monitor.showDiskInMenuBar {
                            HStack(spacing: 4) {
                                Image(systemName: "internaldrive")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(MectricsTheme.coral)
                                let diskText = (monitor.diskDisplayMode == .percentage)
                                    ? String(format: "%.0f%%", monitor.disk.usagePercentage)
                                    : "\(monitor.disk.freeBytes / (1024*1024*1024))GB"
                                Text(diskText)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                        }
                        if monitor.showMemoryInMenuBar {
                            HStack(spacing: 4) {
                                Image(systemName: "memorychip")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(MectricsTheme.coral)
                                Text(String(format: "%.0f%%", monitor.memory.usagePercentage))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white)
                                if monitor.showMemorySparkline {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(white: 0.2))
                                        .frame(width: 20, height: 10)
                                }
                            }
                        }
                        if monitor.showCPUInMenuBar {
                            HStack(spacing: 4) {
                                Image(systemName: "cpu")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(MectricsTheme.coral)
                                Text(String(format: "%.0f%%", monitor.cpu.totalUsage))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white)
                                if monitor.showCPUSparkline {
                                    SparklineView(
                                        values: monitor.cpuHistory.values,
                                        strokeColor: MectricsTheme.coral,
                                        lineWidth: 1.2,
                                        showFill: false
                                    )
                                    .frame(width: 24, height: 10)
                                }
                            }
                        }
                        if monitor.showNetworkInMenuBar {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(MectricsTheme.coral)
                                if monitor.networkDisplayMode == .stacked {
                                    VStack(alignment: .leading, spacing: -1) {
                                        Text("↓1.0K").font(.system(size: 8, weight: .semibold, design: .monospaced))
                                        Text("↑1.0K").font(.system(size: 8, weight: .semibold, design: .monospaced))
                                    }
                                } else {
                                    Text("2.0K/s")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                }
                            }
                        }
                        if monitor.showBatteryInMenuBar && monitor.battery.isPresent {
                            HStack(spacing: 3) {
                                Image(systemName: "battery.100percent")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(MectricsTheme.coral)
                                Text(String(format: "%.0f%%", monitor.battery.percentage))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            }
                        }
                        if monitor.showSensorInMenuBar {
                            HStack(spacing: 3) {
                                Image(systemName: "thermometer.medium")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(MectricsTheme.coral)
                                Text(monitor.formatTemperature(monitor.sensor.cpuTemperature))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            }
                        }
                        if monitor.showFansInMenuBar && !monitor.sensor.fans.isEmpty {
                            let fastest = monitor.sensor.fans.map(\.currentRPM).max() ?? 0
                            HStack(spacing: 3) {
                                Image(systemName: "fan.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(MectricsTheme.coral)
                                Text("\(fastest)R")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            }
                        }
                        if monitor.showGPUInMenuBar {
                            HStack(spacing: 3) {
                                Image(systemName: "display")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(MectricsTheme.coral)
                                Text(String(format: "%.0f%%", monitor.gpu.usagePercentage))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            
            // Menu Bar Optimization & Display Style
            VStack(alignment: .leading, spacing: 12) {
                Text(loc("Menu Bar Optimization"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                
                // 1. Dual Stacked CPU & RAM (Option 1)
                Toggle(loc("Dual Stacked CPU & RAM (35px Slot)"), isOn: $monitor.showDualStackedMenuBar)
                    .toggleStyle(SwitchToggleStyle(tint: MectricsTheme.coral))
                
                Text(loc("Dual Stacked Note"))
                    .font(.system(size: 11))
                    .foregroundStyle(MectricsTheme.textSecondary)
                
                Divider().overlay(Color.white.opacity(0.08))
                
                // 2. Display Style Selector (Option 2)
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc("Item Width & Style"))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Picker("", selection: $monitor.menuBarDisplayStyle) {
                        ForEach(MenuBarDisplayStyle.allCases, id: \.self) { style in
                            Text(loc(style.rawValue)).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(loc("Display Style Note"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(MectricsTheme.textTertiary)
                }
                
                Divider().overlay(Color.white.opacity(0.08))
                
                // 3. Compact Health Mode
                Toggle(loc("Compact Health Mode (Single Shield Slot)"), isOn: $monitor.useCompactHealthBar)
                    .toggleStyle(SwitchToggleStyle(tint: MectricsTheme.coral))
                
                Text(loc("Compact Health Note"))
                    .font(.system(size: 11))
                    .foregroundStyle(MectricsTheme.textSecondary)
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Individual Items Configuration
            if !monitor.useCompactHealthBar {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(loc("Visible Status Bar Items"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Button(loc("Restore Defaults")) {
                            restoreDefaultStatusBar()
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(MectricsTheme.coral)
                        .buttonStyle(.plain)
                    }
                    
                    VStack(spacing: 12) {
                        // 1. Disk
                        itemConfigRow(
                            icon: "internaldrive",
                            title: loc("Disk Storage"),
                            isOn: $monitor.showDiskInMenuBar
                        ) {
                            Picker(loc("Format:"), selection: $monitor.diskDisplayMode) {
                                ForEach(DiskDisplayMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: .infinity)
                        }
                        
                        Divider().overlay(Color.white.opacity(0.06))
                        
                        // 2. Memory
                        itemConfigRow(
                            icon: "memorychip",
                            title: loc("Memory (RAM)"),
                            isOn: $monitor.showMemoryInMenuBar
                        ) {
                            Toggle(loc("Show mini sparkline history box"), isOn: $monitor.showMemorySparkline)
                                .font(.system(size: 11))
                                .foregroundStyle(MectricsTheme.textSecondary)
                        }
                        
                        Divider().overlay(Color.white.opacity(0.06))
                        
                        // 3. CPU
                        itemConfigRow(
                            icon: "cpu",
                            title: loc("Processor (CPU)"),
                            isOn: $monitor.showCPUInMenuBar
                        ) {
                            Toggle(loc("Show live waveform sparkline"), isOn: $monitor.showCPUSparkline)
                                .font(.system(size: 11))
                                .foregroundStyle(MectricsTheme.textSecondary)
                        }
                        
                        Divider().overlay(Color.white.opacity(0.06))
                        
                        // 4. Network
                        itemConfigRow(
                            icon: "arrow.up.arrow.down",
                            title: loc("Network Throughput"),
                            isOn: $monitor.showNetworkInMenuBar
                        ) {
                            Picker(loc("Format:"), selection: $monitor.networkDisplayMode) {
                                ForEach(NetworkDisplayMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: .infinity)
                        }
                        
                        Divider().overlay(Color.white.opacity(0.06))
                        
                        // 5. Battery
                        itemConfigRow(
                            icon: "battery.100percent",
                            title: loc("Battery & Power"),
                            isOn: $monitor.showBatteryInMenuBar
                        ) {
                            Text(locManager.currentLanguage == .vietnamese
                                 ? "Hiển thị mức pin và sạc trên MacBook. Tự động ẩn trên Mac để bàn."
                                 : "Displays battery percentage and charging bolt on MacBooks. Automatically hides on desktop Macs.")
                                .font(.system(size: 11))
                                .foregroundStyle(MectricsTheme.textTertiary)
                        }
                        
                        Divider().overlay(Color.white.opacity(0.06))
                        
                        // 6. Sensor
                        itemConfigRow(
                            icon: "thermometer.medium",
                            title: loc("Sensors & Thermals"),
                            isOn: $monitor.showSensorInMenuBar
                        ) {
                            Text(locManager.currentLanguage == .vietnamese
                                 ? "Hiển thị nhiệt độ CPU theo °C trực tiếp trên thanh menu."
                                 : "Displays CPU temperature in °C directly on the status bar.")
                                .font(.system(size: 11))
                                .foregroundStyle(MectricsTheme.textTertiary)
                        }
                        
                        Divider().overlay(Color.white.opacity(0.06))
                        
                        // 7. GPU
                        itemConfigRow(
                            icon: "display",
                            title: loc("Graphics (GPU)"),
                            isOn: $monitor.showGPUInMenuBar
                        ) {
                            Text(locManager.currentLanguage == .vietnamese
                                 ? "Hiển thị tỷ lệ phần trăm sử dụng chip đồ hoạ theo thời gian thực."
                                 : "Displays real-time graphics silicon utilization percentage.")
                                .font(.system(size: 11))
                                .foregroundStyle(MectricsTheme.textTertiary)
                        }
                        
                        if !monitor.sensor.fans.isEmpty {
                            Divider().overlay(Color.white.opacity(0.06))
                            
                            // 8. Fans
                            itemConfigRow(
                                icon: "fan.fill",
                                title: loc("Cooling Fans"),
                                isOn: $monitor.showFansInMenuBar
                            ) {
                                Text(locManager.currentLanguage == .vietnamese
                                     ? "Hiển thị tốc độ vòng quay quạt RPM trực tiếp trên thanh menu."
                                     : "Displays live cooling fan RPM directly on the menu bar.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(MectricsTheme.textTertiary)
                            }
                        }
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private func itemConfigRow<Content: View>(
        icon: String,
        title: String,
        isOn: Binding<Bool>,
        @ViewBuilder extraContent: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MectricsTheme.coral)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: MectricsTheme.coral))
            }
            
            if isOn.wrappedValue {
                extraContent()
                    .padding(.leading, 24)
            }
        }
    }
    
    private func restoreDefaultStatusBar() {
        monitor.useCompactHealthBar = false
        monitor.showDiskInMenuBar = true
        monitor.diskDisplayMode = .freeSpace
        monitor.showMemoryInMenuBar = true
        monitor.showMemorySparkline = true
        monitor.showCPUInMenuBar = true
        monitor.showCPUSparkline = true
        monitor.showNetworkInMenuBar = true
        monitor.networkDisplayMode = .stacked
        monitor.showBatteryInMenuBar = true
        monitor.showSensorInMenuBar = true
        monitor.showFansInMenuBar = false
        monitor.showGPUInMenuBar = false
    }
    
    // MARK: - Alerts Tab (Matches Reference Image 5)
    private var alertsTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Rules Header
            HStack {
                Text(loc("Rules"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                let activeCount = [cpuRuleEnabled, memRuleEnabled, batRuleEnabled, diskRuleEnabled, diskFreeRuleEnabled, gpuRuleEnabled, tempRuleEnabled].filter { $0 }.count
                Text("\(activeCount) \(loc("on")) · \(monitor.rulesEngine.activeAlerts.count) \(loc("alerting"))")
                    .font(.system(size: 11))
                    .foregroundStyle(MectricsTheme.textTertiary)
            }
            
            VStack(spacing: 10) {
                // 1. CPU
                ruleRow(
                    title: loc("CPU usage above"),
                    value: $cpuRuleThresh,
                    unit: "%",
                    isOn: $cpuRuleEnabled,
                    currentText: "\(loc("Normal")) · \(String(format: "%.1f%%", monitor.cpu.totalUsage))",
                    delaySeconds: $cpuRuleDelay
                )
                
                Divider().overlay(Color.white.opacity(0.06))
                
                // 2. Memory
                ruleRow(
                    title: loc("Memory usage above"),
                    value: $memRuleThresh,
                    unit: "%",
                    isOn: $memRuleEnabled,
                    currentText: "\(loc("Normal")) · \(String(format: "%.1f%%", monitor.memory.usagePercentage))",
                    delaySeconds: $memRuleDelay
                )
                
                Divider().overlay(Color.white.opacity(0.06))
                
                // 3. Battery
                ruleRow(
                    title: loc("Battery charge below"),
                    value: $batRuleThresh,
                    unit: "%",
                    isOn: $batRuleEnabled,
                    currentText: "\(loc("Normal")) · \(String(format: "%.0f%%", monitor.battery.percentage))",
                    delaySeconds: $batRuleDelay
                )
                
                Divider().overlay(Color.white.opacity(0.06))
                
                // 4. Disk usage
                ruleRow(
                    title: loc("Disk usage above"),
                    value: $diskRuleThresh,
                    unit: "%",
                    isOn: $diskRuleEnabled,
                    currentText: "\(loc("Normal")) · \(String(format: "%.1f%%", monitor.disk.usagePercentage))",
                    delaySeconds: $diskRuleDelay
                )
                
                Divider().overlay(Color.white.opacity(0.06))
                
                // 5. Free disk space
                ruleRow(
                    title: loc("Free disk space below"),
                    value: $diskFreeRuleThresh,
                    unit: "GB",
                    isOn: $diskFreeRuleEnabled,
                    currentText: "\(loc("Normal")) · \(monitor.disk.freeBytes / (1024*1024*1024)) GB",
                    delaySeconds: nil
                )
                
                Divider().overlay(Color.white.opacity(0.06))
                
                // 6. GPU usage
                ruleRow(
                    title: loc("GPU usage above"),
                    value: $gpuRuleThresh,
                    unit: "%",
                    isOn: $gpuRuleEnabled,
                    currentText: "\(loc("Normal")) · \(String(format: "%.1f%%", monitor.gpu.usagePercentage))",
                    delaySeconds: nil
                )
                
                Divider().overlay(Color.white.opacity(0.06))
                
                // 7. CPU temperature
                ruleRow(
                    title: loc("CPU temperature above"),
                    value: $tempRuleThresh,
                    unit: "°C",
                    isOn: $tempRuleEnabled,
                    currentText: "\(loc("Normal")) · \(String(format: "%.1f°C", monitor.sensor.cpuTemperature))",
                    delaySeconds: nil
                )
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Description paragraph
            Text(loc("Alert description"))
                .font(.system(size: 11))
                .foregroundStyle(MectricsTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 4)
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            // Audio & Notifications Section
            VStack(alignment: .leading, spacing: 12) {
                Text(loc("Alert Behavior & Delivery"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                
                Toggle(loc("Play audible alert sound when condition triggers"), isOn: $playAlertSound)
                    .toggleStyle(SwitchToggleStyle(tint: MectricsTheme.coral))
                
                HStack(spacing: 12) {
                    Button(loc("Open Notification Settings")) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    
                    Button(testNotificationSent ? loc("Notification Sent!") : loc("Send a Test Notification")) {
                        sendTestNotification()
                        testNotificationSent = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            testNotificationSent = false
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
                
                Text(loc("Notifications Note"))
                    .font(.system(size: 11))
                    .foregroundStyle(MectricsTheme.textTertiary)
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            // Headless CLI Automation (Matches Mectrics Spec)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "terminal")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MectricsTheme.coral)
                    Text(loc("Headless Automation CLI"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                
                Text(locManager.currentLanguage == .vietnamese
                     ? "Cung cấp lệnh 'mectrics' trong Terminal để kiểm tra ngưỡng hệ thống (check, snapshot, doctor, watch) cho scripts và cron jobs."
                     : "Provides the read-only 'mectrics' command in every Terminal for script health checks, snapshots, and alerts watch.")
                    .font(.system(size: 11))
                    .foregroundStyle(MectricsTheme.textSecondary)
                
                HStack(spacing: 12) {
                    Button(loc("Install CLI (/usr/local/bin/mectrics)")) {
                        let res = AppState.shared.installCLI()
                        cliInstallStatus = res.message
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MectricsTheme.coral)
                    
                    if let status = cliInstallStatus {
                        Text(status)
                            .font(.system(size: 11))
                            .foregroundStyle(status.contains("installed") || status.contains("created") ? Color.green : Color.orange)
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private func ruleRow(
        title: String,
        value: Binding<Int>,
        unit: String,
        isOn: Binding<Bool>,
        currentText: String,
        delaySeconds: Binding<Int>?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Stepper / Value
                Menu {
                    let choices = (unit == "GB") ? [5, 10, 15, 20, 30, 50, 100] : [10, 20, 30, 40, 50, 60, 70, 75, 80, 85, 90, 95]
                    ForEach(choices, id: \.self) { v in
                        Button("\(v)\(unit)") {
                            value.wrappedValue = v
                            syncRulesToEngine()
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(value.wrappedValue)\(unit)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                
                // Toggle Switch
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: MectricsTheme.coral))
                    .onChange(of: isOn.wrappedValue) {
                        syncRulesToEngine()
                    }
            }
            
            if isOn.wrappedValue {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 10))
                        Text(currentText)
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(MectricsTheme.textTertiary)
                    
                    Spacer()
                    
                    if let delay = delaySeconds {
                        Menu {
                            Button("Alert after 10 seconds") {
                                delay.wrappedValue = 10
                                syncRulesToEngine()
                            }
                            Button("Alert after 30 seconds") {
                                delay.wrappedValue = 30
                                syncRulesToEngine()
                            }
                            Button("Alert after 60 seconds") {
                                delay.wrappedValue = 60
                                syncRulesToEngine()
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Text("Alert after \(delay.wrappedValue) seconds")
                                    .font(.system(size: 10))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 8))
                            }
                            .foregroundStyle(MectricsTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 2)
            }
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - General Tab
    private var generalTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Appearance & Accent Color
            VStack(alignment: .leading, spacing: 12) {
                Text(loc("Appearance"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc("Accent Color"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MectricsTheme.textSecondary)
                    
                    HStack(spacing: 12) {
                        ForEach(AccentTheme.allCases) { theme in
                            let isSelected = (themeManager.currentTheme == theme)
                            Button {
                                themeManager.currentTheme = theme
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(theme.primaryColor)
                                            .frame(width: 26, height: 26)
                                        
                                        if isSelected {
                                            Circle()
                                                .strokeBorder(Color.white, lineWidth: 2)
                                                .frame(width: 26, height: 26)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .black))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    
                                    Text(theme.rawValue)
                                        .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                                        .foregroundStyle(isSelected ? .white : MectricsTheme.textTertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Divider()
                    .overlay(Color.white.opacity(0.06))
                
                // Language Selection
                HStack {
                    Text(loc("Language"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MectricsTheme.textSecondary)
                    
                    Spacer()
                    
                    Picker("", selection: $locManager.currentLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                Divider()
                    .overlay(Color.white.opacity(0.06))
                
                // Temperature Unit Selection
                HStack {
                    Text(loc("Temperature Unit"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MectricsTheme.textSecondary)
                    
                    Spacer()
                    
                    Picker("", selection: $monitor.temperatureUnit) {
                        ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
            }
            .padding()
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // System Startup
            VStack(alignment: .leading, spacing: 12) {
                Text(loc("Startup"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                
                Toggle(loc("Launch Mectrics automatically at login"), isOn: $launchAtLogin)
                    .toggleStyle(SwitchToggleStyle(tint: MectricsTheme.coral))
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLoginManager.isEnabled = newValue
                    }
            }
            .padding()
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // System Diagnostics (Matches Mectrics Spec)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(loc("System Diagnostics"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                
                Text(locManager.currentLanguage == .vietnamese
                     ? "Xem toàn bộ báo cáo phần cứng, tình trạng pin, quạt, bộ nhớ và sao chép báo cáo chi tiết."
                     : "View comprehensive local system overview, battery health, thermal zones, and export plain text report.")
                    .font(.system(size: 11))
                    .foregroundStyle(MectricsTheme.textSecondary)
                
                Button(loc("Open System Diagnostics…")) {
                    AppState.shared.openDiagnostics()
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
            .padding()
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Performance & Sampling
            VStack(alignment: .leading, spacing: 12) {
                Text(loc("Performance & Polling"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                
                HStack {
                    Text(loc("Hardware Refresh Rate:"))
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $monitor.updateInterval) {
                        Text(locManager.currentLanguage == .vietnamese ? "500ms (Độ chính xác cao)" : "500ms (High precision)").tag(0.5)
                        Text(locManager.currentLanguage == .vietnamese ? "1.0s (Khuyên dùng)" : "1.0s (Recommended)").tag(1.0)
                        Text(locManager.currentLanguage == .vietnamese ? "2.0s (Tiết kiệm pin)" : "2.0s (Battery efficient)").tag(2.0)
                        Text(locManager.currentLanguage == .vietnamese ? "5.0s (Tối thiểu)" : "5.0s (Minimal)").tag(5.0)
                    }
                    .frame(width: 200)
                }
            }
            .padding()
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Privacy & Security
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(MectricsTheme.coral)
                    Text(loc("Zero Network Requests Guarantee"))
                        .font(.system(size: 12, weight: .bold))
                }
                Text(loc("Offline Guarantee Note"))
                    .font(.system(size: 11))
                    .foregroundStyle(MectricsTheme.textSecondary)
            }
            .padding()
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Clean Uninstall (Matches Mectrics Spec)
            VStack(alignment: .leading, spacing: 10) {
                Text(loc("Uninstall Mectrics"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                
                Text(locManager.currentLanguage == .vietnamese
                     ? "Gỡ bỏ hoàn toàn Mectrics, xoá sạch cấu hình đã lưu, huỷ mục khởi động cùng máy và xoá liên kết /usr/local/bin/mectrics."
                     : "Clean removal: unregisters login items, clears settings domain, removes /usr/local/bin/mectrics and quits.")
                    .font(.system(size: 11))
                    .foregroundStyle(MectricsTheme.textSecondary)
                
                Button(role: .destructive) {
                    AppState.shared.cleanUninstall()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text(loc("Uninstall Mectrics…"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red.opacity(0.85))
            }
            .padding()
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            )
            
            // About
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Mectrics v1.0.0")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("macOS 15+ Native")
                        .font(.system(size: 11))
                        .foregroundStyle(MectricsTheme.textTertiary)
                }
                Text(locManager.currentLanguage == .vietnamese
                     ? "Thiết kế thuần Swift 6 và SwiftUI. Mã nguồn mở và hoàn toàn bảo mật."
                     : "Designed natively with Swift 6 and SwiftUI. Free and open source.")
                    .font(.system(size: 11))
                    .foregroundStyle(MectricsTheme.textSecondary)
            }
            .padding()
            .background(Color.white.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private func syncRulesToEngine() {
        var newRules: [AlertRule] = []
        newRules.append(AlertRule(name: "CPU usage above", isEnabled: cpuRuleEnabled, target: .cpuUsage, comparison: .greaterThan, thresholdValue: Double(cpuRuleThresh), sustainedSeconds: cpuRuleDelay))
        newRules.append(AlertRule(name: "Memory usage above", isEnabled: memRuleEnabled, target: .memoryUsage, comparison: .greaterThan, thresholdValue: Double(memRuleThresh), sustainedSeconds: memRuleDelay))
        newRules.append(AlertRule(name: "Battery charge below", isEnabled: batRuleEnabled, target: .batteryLevel, comparison: .lessThan, thresholdValue: Double(batRuleThresh), sustainedSeconds: batRuleDelay))
        newRules.append(AlertRule(name: "Disk usage above", isEnabled: diskRuleEnabled, target: .diskUsage, comparison: .greaterThan, thresholdValue: Double(diskRuleThresh), sustainedSeconds: diskRuleDelay))
        newRules.append(AlertRule(name: "Free disk space below", isEnabled: diskFreeRuleEnabled, target: .freeDiskSpace, comparison: .lessThan, thresholdValue: Double(diskFreeRuleThresh), sustainedSeconds: 30))
        newRules.append(AlertRule(name: "GPU usage above", isEnabled: gpuRuleEnabled, target: .gpuUsage, comparison: .greaterThan, thresholdValue: Double(gpuRuleThresh), sustainedSeconds: 30))
        newRules.append(AlertRule(name: "CPU temperature above", isEnabled: tempRuleEnabled, target: .cpuTemperature, comparison: .greaterThan, thresholdValue: Double(tempRuleThresh), sustainedSeconds: 30))
        
        monitor.rulesEngine.rules = newRules
        monitor.rulesEngine.saveRules()
    }
    
    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Mectrics Test Alert"
        content.body = "Alert conditions are actively monitored and ready."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
