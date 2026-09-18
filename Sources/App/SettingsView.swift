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
    
    @State private var testNotificationSent = false
    
    public init(monitor: SystemMonitor, initialTab: SettingsTab = .alerts) {
        self.monitor = monitor
        self._selectedTab = State(initialValue: initialTab)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Window Toolbar
            HStack {
                Text(selectedTab.rawValue)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Tab switcher pills
                HStack(spacing: 2) {
                    ForEach(SettingsTab.allCases) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11, weight: .medium))
                                Text(tab.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedTab == tab ? Color.white.opacity(0.12) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(selectedTab == tab ? .white : MectricsTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(white: 0.12))
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch selectedTab {
                    case .alerts:
                        alertsTabContent
                    case .menuBar:
                        menuBarTabContent
                    case .general:
                        generalTabContent
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 530, height: 620)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .preferredColorScheme(.dark)
        .onAppear {
            syncRulesToEngine()
        }
    }
    
    // MARK: - Alerts Tab (Matches Reference Image 5)
    private var alertsTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Rules Header
            HStack {
                Text("Rules")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                let activeCount = [cpuRuleEnabled, memRuleEnabled, batRuleEnabled, diskRuleEnabled, diskFreeRuleEnabled, gpuRuleEnabled, tempRuleEnabled].filter { $0 }.count
                Text("\(activeCount) on · \(monitor.rulesEngine.activeAlerts.count) alerting")
                    .font(.system(size: 11))
                    .foregroundStyle(MectricsTheme.textTertiary)
            }
            
            VStack(spacing: 12) {
                // 1. CPU
                ruleRow(
                    title: "CPU usage above",
                    value: $cpuRuleThresh,
                    unit: "%",
                    isOn: $cpuRuleEnabled,
                    currentText: "Normal · \(String(format: "%.1f%%", monitor.cpu.totalUsage))",
                    delaySeconds: $cpuRuleDelay
                )
                
                // 2. Memory
                ruleRow(
                    title: "Memory usage above",
                    value: $memRuleThresh,
                    unit: "%",
                    isOn: $memRuleEnabled,
                    currentText: "Normal · \(String(format: "%.1f%%", monitor.memory.usagePercentage))",
                    delaySeconds: $memRuleDelay
                )
                
                // 3. Battery
                ruleRow(
                    title: "Battery charge below",
                    value: $batRuleThresh,
                    unit: "%",
                    isOn: $batRuleEnabled,
                    currentText: "Normal · \(String(format: "%.0f%%", monitor.battery.percentage))",
                    delaySeconds: $batRuleDelay
                )
                
                // 4. Disk usage
                ruleRow(
                    title: "Disk usage above",
                    value: $diskRuleThresh,
                    unit: "%",
                    isOn: $diskRuleEnabled,
                    currentText: "Normal · \(String(format: "%.1f%%", monitor.disk.usagePercentage))",
                    delaySeconds: $diskRuleDelay
                )
                
                // 5. Free disk space
                ruleRow(
                    title: "Free disk space below",
                    value: $diskFreeRuleThresh,
                    unit: "GB",
                    isOn: $diskFreeRuleEnabled,
                    currentText: "Normal · \(monitor.disk.freeBytes / (1024*1024*1024)) GB",
                    delaySeconds: nil
                )
                
                // 6. GPU usage
                ruleRow(
                    title: "GPU usage above",
                    value: $gpuRuleThresh,
                    unit: "%",
                    isOn: $gpuRuleEnabled,
                    currentText: "Normal · \(String(format: "%.1f%%", monitor.gpu.usagePercentage))",
                    delaySeconds: nil
                )
                
                // 7. CPU temperature
                ruleRow(
                    title: "CPU temperature above",
                    value: $tempRuleThresh,
                    unit: "°C",
                    isOn: $tempRuleEnabled,
                    currentText: "Normal · \(String(format: "%.1f°C", monitor.sensor.cpuTemperature))",
                    delaySeconds: nil
                )
            }
            
            // Description paragraph
            Text("When a rule alerts it notifies you, marks the Compact Health item, and is recorded in the Attention Log. A rule rests for 15 minutes after it alerts.")
                .font(.system(size: 11))
                .foregroundStyle(MectricsTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 4)
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            // Notifications Section
            VStack(alignment: .leading, spacing: 10) {
                Text("Notifications")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                
                HStack(spacing: 12) {
                    Button("Open Notification Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    
                    Button(testNotificationSent ? "Notification Sent!" : "Send a Test Notification") {
                        sendTestNotification()
                        testNotificationSent = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            testNotificationSent = false
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
                
                Text("macOS owns notification permission and decides how alerts are presented. Mectrics cannot show one until you allow it there.")
                    .font(.system(size: 11))
                    .foregroundStyle(MectricsTheme.textTertiary)
            }
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
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: isOn.wrappedValue) { _ in
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
    
    // MARK: - Menu Bar Tab
    private var menuBarTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Live Preview Card
            VStack(alignment: .leading, spacing: 8) {
                Text("Live Menu Bar Preview")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MectricsTheme.textSecondary)
                
                HStack(spacing: 12) {
                    if monitor.useCompactHealthBar {
                        Image(systemName: "checkmark.shield")
                            .foregroundStyle(MectricsTheme.coral)
                    } else {
                        if monitor.showDiskInMenuBar {
                            HStack(spacing: 3) {
                                Image(systemName: "internaldrive")
                                    .foregroundStyle(MectricsTheme.coral)
                                Text("\(monitor.disk.freeBytes / (1024*1024*1024))GB")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            }
                        }
                        if monitor.showMemoryInMenuBar {
                            HStack(spacing: 3) {
                                Image(systemName: "memorychip")
                                    .foregroundStyle(MectricsTheme.coral)
                                Text(String(format: "%.0f%%", monitor.memory.usagePercentage))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            }
                        }
                        if monitor.showCPUInMenuBar {
                            HStack(spacing: 3) {
                                Image(systemName: "cpu")
                                    .foregroundStyle(MectricsTheme.coral)
                                Text(String(format: "%.0f%%", monitor.cpu.totalUsage))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            }
                        }
                        if monitor.showNetworkInMenuBar {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .foregroundStyle(MectricsTheme.coral)
                                Text("↓1.0K ↑1.0K")
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Display Mode")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                
                Toggle("Compact Health Bar (Single Slot)", isOn: $monitor.useCompactHealthBar)
                    .help("Folds all hardware meters into a single shield icon to save menu bar space.")
            }
            .padding()
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            if !monitor.useCompactHealthBar {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Individual Item Visibility")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Toggle("Disk Free Space", isOn: $monitor.showDiskInMenuBar)
                    Toggle("Memory Usage & Sparkline Box", isOn: $monitor.showMemoryInMenuBar)
                    Toggle("CPU Usage & Live Waveform", isOn: $monitor.showCPUInMenuBar)
                    Toggle("Network Inbound / Outbound", isOn: $monitor.showNetworkInMenuBar)
                    Toggle("Battery Status", isOn: $monitor.showBatteryInMenuBar)
                    Toggle("GPU Graphics Utilization", isOn: $monitor.showGPUInMenuBar)
                    Toggle("Sensors & Thermal Pressure", isOn: $monitor.showSensorInMenuBar)
                }
                .padding()
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    // MARK: - General Tab
    private var generalTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // System Startup
            VStack(alignment: .leading, spacing: 12) {
                Text("Startup")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                
                Toggle("Launch Mectrics automatically at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        LaunchAtLoginManager.isEnabled = newValue
                    }
            }
            .padding()
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Performance & Sampling
            VStack(alignment: .leading, spacing: 12) {
                Text("Performance & Polling")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                
                HStack {
                    Text("Hardware Refresh Rate:")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $monitor.updateInterval) {
                        Text("500ms (High precision)").tag(0.5)
                        Text("1.0s (Recommended)").tag(1.0)
                        Text("2.0s (Battery efficient)").tag(2.0)
                        Text("5.0s (Minimal)").tag(5.0)
                    }
                    .frame(width: 190)
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
                    Text("Zero Network Requests Guarantee")
                        .font(.system(size: 12, weight: .bold))
                }
                Text("Mectrics operates 100% offline using Darwin Mach kernel, sysctl, and IOKit APIs. No telemetry, crash reporting, or network sockets are ever opened.")
                    .font(.system(size: 11))
                    .foregroundStyle(MectricsTheme.textSecondary)
            }
            .padding()
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
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
                Text("Designed natively with Swift 6 and SwiftUI. Free and open source.")
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
