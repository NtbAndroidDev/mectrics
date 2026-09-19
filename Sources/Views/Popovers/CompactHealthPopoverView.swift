import SwiftUI
import AppKit

public enum CompactMetricType: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "Memory"
    case network = "Network"
    case disk = "Disk"
    case battery = "Battery"
    case temperature = "Temperature"
    
    public var id: String { rawValue }
}

public struct CompactHealthPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject private var sleepBlocker = SleepBlocker.shared
    @State private var copiedSummaryAlert = false
    
    // Interactive pin state
    @State private var pinnedMetric: CompactMetricType? = nil
    
    private var activeMetric: CompactMetricType? {
        pinnedMetric
    }
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            // Header
            PopoverHeaderView(
                icon: "checkmark.shield",
                title: monitor.rulesEngine.activeAlerts.isEmpty ? loc("All systems normal") : loc("Active Alerts"),
                iconColor: monitor.rulesEngine.activeAlerts.isEmpty ? .white : MectricsTheme.coral,
                onRefresh: {
                    monitor.refreshAll()
                }
            )
            
            // Subtitle
            Text(monitor.rulesEngine.activeAlerts.isEmpty ?
                 loc("Mectrics will show selected alert conditions here.") :
                 monitor.rulesEngine.activeAlerts.joined(separator: "\n"))
                .font(.system(size: 11.5, weight: .regular))
                .foregroundStyle(monitor.rulesEngine.activeAlerts.isEmpty ? MectricsTheme.textSecondary : MectricsTheme.coral)
                .fixedSize(horizontal: false, vertical: true)
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            // Status Items with Hover/Click to Reveal Details
            VStack(spacing: 3) {
                // 1. CPU Row
                CompactInteractiveRow(
                    icon: "cpu",
                    title: loc("CPU"),
                    value: String(format: "%.0f%%", monitor.cpu.totalUsage),
                    progress: monitor.cpu.totalUsage / 100.0,
                    isExpanded: activeMetric == .cpu,
                    hoverMetricType: .cpu,
                    onTogglePin: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            pinnedMetric = (pinnedMetric == .cpu) ? nil : .cpu
                        }
                    }
                ) {
                    cpuDetailView
                }
                
                // 2. Memory Row
                CompactInteractiveRow(
                    icon: "memorychip",
                    title: loc("Memory"),
                    value: String(format: "%.0f%%", monitor.memory.usagePercentage),
                    progress: monitor.memory.usagePercentage / 100.0,
                    isExpanded: activeMetric == .memory,
                    hoverMetricType: .memory,
                    onTogglePin: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            pinnedMetric = (pinnedMetric == .memory) ? nil : .memory
                        }
                    }
                ) {
                    memoryDetailView
                }
                
                // 3. Network Row
                CompactInteractiveRow(
                    icon: "arrow.up.arrow.down",
                    title: loc("Network"),
                    value: formatNetworkThroughput(),
                    progress: nil,
                    isExpanded: activeMetric == .network,
                    hoverMetricType: .network,
                    onTogglePin: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            pinnedMetric = (pinnedMetric == .network) ? nil : .network
                        }
                    }
                ) {
                    networkDetailView
                }
                
                // 4. Disk Row
                CompactInteractiveRow(
                    icon: "internaldrive",
                    title: loc("Disk"),
                    value: String(format: "%.0f%%", monitor.disk.usagePercentage),
                    progress: monitor.disk.usagePercentage / 100.0,
                    isExpanded: activeMetric == .disk,
                    hoverMetricType: .disk,
                    onTogglePin: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            pinnedMetric = (pinnedMetric == .disk) ? nil : .disk
                        }
                    }
                ) {
                    diskDetailView
                }
                
                // 5. Battery Row (if present)
                if monitor.battery.isPresent {
                    CompactInteractiveRow(
                        icon: monitor.battery.isCharging ? "battery.100percent.bolt" : "battery.100percent",
                        title: loc("Battery"),
                        value: String(format: "%.0f%%", monitor.battery.percentage),
                        progress: monitor.battery.percentage / 100.0,
                        isExpanded: activeMetric == .battery,
                        hoverMetricType: .battery,
                        onTogglePin: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                pinnedMetric = (pinnedMetric == .battery) ? nil : .battery
                            }
                        }
                    ) {
                        batteryDetailView
                    }
                }
                
                // 6. Temperature Row
                CompactInteractiveRow(
                    icon: "thermometer.medium",
                    title: loc("Temperature"),
                    value: "\(Int(monitor.sensor.cpuTemperature))°C",
                    progress: max(0.0, min(1.0, (monitor.sensor.cpuTemperature - 30.0) / 70.0)),
                    isExpanded: activeMetric == .temperature,
                    hoverMetricType: .sensor,
                    onTogglePin: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            pinnedMetric = (pinnedMetric == .temperature) ? nil : .temperature
                        }
                    }
                ) {
                    temperatureDetailView
                }
            }
            .padding(.vertical, 2)
            
            // Action Buttons
            VStack(spacing: 7) {
                PopoverActionButton(
                    icon: sleepBlocker.isKeepAwakeActive ? "cup.and.saucer.fill" : "cup.and.saucer",
                    title: sleepBlocker.isKeepAwakeActive ? loc("Keep Awake: Active") : loc("Keep Awake: Off")
                ) {
                    sleepBlocker.toggle()
                }
                
                PopoverActionButton(icon: "list.bullet.rectangle", title: loc("Open Attention Log")) {
                    AppState.shared.openAttentionLog()
                }
                
                PopoverActionButton(icon: "doc.on.doc", title: copiedSummaryAlert ? loc("Summary Copied!") : loc("Copy System Summary")) {
                    copySummaryToClipboard()
                    copiedSummaryAlert = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copiedSummaryAlert = false
                    }
                }
            }
            
            // Footer
            PopoverFooterView()
        }
        .mectricsPopoverStyle()
    }
    
    // MARK: - Detail Views
    private var cpuDetailView: some View {
        VStack(alignment: .leading, spacing: 5) {
            SparklineView(
                values: monitor.cpuHistory.values.isEmpty ? [10, 20, 30] : monitor.cpuHistory.values,
                strokeColor: MectricsTheme.coral,
                lineWidth: 1.3,
                showFill: true,
                minScale: 0.0,
                maxScale: 100.0
            )
            .frame(height: 24)
            
            HStack {
                let coreText = monitor.cpu.pCores > 0 ? "\(monitor.cpu.pCores)P + \(monitor.cpu.eCores)E Cores" : "\(monitor.cpu.logicalCores) Cores"
                Text(coreText)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.8))
                Spacer()
                Text("Busiest: \(String(format: "%.0f%%", monitor.cpu.busiestCoreUsage))")
                    .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
        }
    }
    
    private var memoryDetailView: some View {
        VStack(alignment: .leading, spacing: 5) {
            SparklineView(
                values: monitor.memoryHistory.values.isEmpty ? [40, 50, 60] : monitor.memoryHistory.values,
                strokeColor: Color(red: 0.35, green: 0.78, blue: 0.98),
                lineWidth: 1.3,
                showFill: true,
                minScale: 0.0,
                maxScale: 100.0
            )
            .frame(height: 24)
            
            HStack {
                Text("\(formatGB(monitor.memory.usedBytes)) / \(formatGB(monitor.memory.totalBytes))")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.8))
                Spacer()
                Text("Pressure: \(monitor.memory.pressureLevel.rawValue.capitalized)")
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundStyle(monitor.memory.pressureLevel == .critical ? Color.red : (monitor.memory.pressureLevel == .warning ? Color.yellow : Color.green))
            }
        }
    }
    
    private var networkDetailView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 3) {
                    Text("↓")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(red: 0.25, green: 0.85, blue: 0.8))
                    Text(formatNet(monitor.network.downloadBytesPerSec))
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                }
                Spacer()
                HStack(spacing: 3) {
                    Text("↑")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(red: 0.98, green: 0.4, blue: 0.4))
                    Text(formatNet(monitor.network.uploadBytesPerSec))
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
            
            HStack {
                Text("IP: \(monitor.network.ipv4Address)")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                if let ping = monitor.network.pingLatencyMs {
                    Text(String(format: "Ping: %.0f ms", ping))
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(ping > 120 ? Color.red : Color.white.opacity(0.55))
                }
            }
        }
    }
    
    private var diskDetailView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(monitor.disk.volumeName) (\(monitor.disk.fileSystem))")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .lineLimit(1)
                Spacer()
                Text("\(formatGB(monitor.disk.freeBytes)) Free")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MectricsTheme.coral)
            }
            
            HStack {
                Text("R: \(formatNet(monitor.disk.readBytesPerSec))")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                Text("W: \(formatNet(monitor.disk.writeBytesPerSec))")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
        }
    }
    
    private var batteryDetailView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Health: \(String(format: "%.0f%%", monitor.battery.healthPercentage))")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.8))
                Spacer()
                Text("\(monitor.battery.cycleCount) Cycles")
                    .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            
            HStack {
                Text(monitor.battery.powerSource)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                if monitor.battery.wattage > 0.1 {
                    Text(String(format: "%.1f W", monitor.battery.wattage))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.green)
                }
            }
        }
    }
    
    private var temperatureDetailView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Thermal State: \(monitor.sensor.thermalPressure.rawValue.capitalized)")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.8))
                Spacer()
                Text(monitor.formatTemperaturePrecise(monitor.sensor.cpuTemperature))
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(MectricsTheme.coral)
            }
            
            HStack {
                if !monitor.sensor.fans.isEmpty {
                    let rpm = monitor.sensor.fans.map(\.currentRPM).max() ?? 0
                    Text("Fan Speed: \(rpm) RPM")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.6))
                } else {
                    Text(loc("Fanless / Passive"))
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                Spacer()
            }
        }
    }
    
    private func formatNetworkThroughput() -> String {
        let totalBytes = monitor.network.downloadBytesPerSec + monitor.network.uploadBytesPerSec
        if totalBytes >= 1024 * 1024 {
            return String(format: "%.1f MB/s", totalBytes / (1024 * 1024))
        } else if totalBytes >= 1024 {
            return String(format: "%.1f KB/s", totalBytes / 1024)
        } else {
            return "0.0 B/s"
        }
    }
    
    private func copySummaryToClipboard() {
        let summary = """
        Mectrics System Summary (\(Date().formatted()))
        ------------------------------------------
        CPU: \(String(format: "%.1f%%", monitor.cpu.totalUsage)) (Busiest: \(String(format: "%.0f%%", monitor.cpu.busiestCoreUsage)), Temp: \(String(format: "%.1f°C", monitor.sensor.cpuTemperature)))
        Memory: \(String(format: "%.1f%%", monitor.memory.usagePercentage)) (\(formatGB(monitor.memory.usedBytes)) / \(formatGB(monitor.memory.totalBytes)))
        Disk: \(String(format: "%.1f%%", monitor.disk.usagePercentage)) (Free: \(formatGB(monitor.disk.freeBytes)), Purgeable: \(formatGB(monitor.disk.purgeableBytes)))
        Network: Down: \(formatNet(monitor.network.downloadBytesPerSec)), Up: \(formatNet(monitor.network.uploadBytesPerSec))
        Uptime: \(ProcessMonitor.formattedUptime())
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }
    
    private func formatGB(_ bytes: UInt64) -> String {
        return String(format: "%.1f GB", Double(bytes) / (1024 * 1024 * 1024))
    }
    
    private func formatNet(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1024 * 1024 {
            return String(format: "%.1f MB/s", bytesPerSec / (1024 * 1024))
        } else {
            return String(format: "%.0f KB/s", bytesPerSec / 1024)
        }
    }
}

// MARK: - Interactive Row Component with Hover Detail Window
public struct CompactInteractiveRow<DetailContent: View>: View {
    public let icon: String
    public let title: String
    public let value: String
    public var progress: Double? = nil
    public var isExpanded: Bool
    public var hoverMetricType: HoverDetailType? = nil
    public var onHoverChanged: ((Bool) -> Void)? = nil
    public var onTogglePin: () -> Void
    @ViewBuilder public let detailContent: () -> DetailContent
    
    @State private var isHovered = false
    
    public init(
        icon: String,
        title: String,
        value: String,
        progress: Double? = nil,
        isExpanded: Bool,
        hoverMetricType: HoverDetailType? = nil,
        onHoverChanged: ((Bool) -> Void)? = nil,
        onTogglePin: @escaping () -> Void,
        @ViewBuilder detailContent: @escaping () -> DetailContent
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.progress = progress
        self.isExpanded = isExpanded
        self.hoverMetricType = hoverMetricType
        self.onHoverChanged = onHoverChanged
        self.onTogglePin = onTogglePin
        self.detailContent = detailContent
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Main Row
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MectricsTheme.coral)
                    .frame(width: 16)
                
                Text(title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(isHovered || isExpanded ? .white : MectricsTheme.textSecondary)
                
                Spacer()
                
                if let p = progress {
                    GeometryReader { _ in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(white: 0.18))
                            Capsule()
                                .fill(p > 0.85 ? MectricsTheme.coral : Color(red: 0.25, green: 0.85, blue: 0.65))
                                .frame(width: CGFloat(max(0.04, min(1.0, p))) * 38)
                        }
                    }
                    .frame(width: 38, height: 4)
                    .padding(.trailing, 2)
                }
                
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(isExpanded ? MectricsTheme.coral : Color.white.opacity(0.2))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .padding(.leading, 2)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isExpanded ? Color.white.opacity(0.08) : (isHovered ? Color.white.opacity(0.05) : Color.clear))
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
                onHoverChanged?(hovering)
            }
            .onTapGesture {
                onTogglePin()
            }
            
            // Expanded Detail Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    detailContent()
                }
                .padding(8)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
                .padding(.horizontal, 4)
                .padding(.top, 3)
                .padding(.bottom, 4)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                    removal: .opacity
                ))
            }
        }
    }
}

public struct AttentionLogView: View {
    @ObservedObject var rulesEngine: RulesEngine
    @Environment(\.dismiss) private var dismiss
    
    public init(rulesEngine: RulesEngine) {
        self.rulesEngine = rulesEngine
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(MectricsTheme.coral)
                    Text(loc("Attention Log"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button(loc("Done")) { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(MectricsTheme.coral)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            if rulesEngine.activeAlerts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(MectricsTheme.coral)
                    Text(loc("No active alerts or events"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MectricsTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(rulesEngine.activeAlerts, id: \.self) { alert in
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(MectricsTheme.coral)
                                Text(alert)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(MectricsTheme.coral.opacity(0.25), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .frame(width: 440, height: 320)
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
        .preferredColorScheme(.dark)
    }
}

