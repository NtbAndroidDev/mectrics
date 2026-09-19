import SwiftUI
import AppKit

public struct CompactHealthPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject private var sleepBlocker = SleepBlocker.shared
    @State private var copiedSummaryAlert = false
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header (Matches Image 2)
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
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(monitor.rulesEngine.activeAlerts.isEmpty ? MectricsTheme.textSecondary : MectricsTheme.coral)
                .fixedSize(horizontal: false, vertical: true)
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            // Status Items
            VStack(spacing: 3) {
                CompactStatusRow(
                    icon: "cpu",
                    title: loc("CPU"),
                    value: String(format: "%.0f%%", monitor.cpu.totalUsage),
                    progress: monitor.cpu.totalUsage / 100.0
                )
                CompactStatusRow(
                    icon: "memorychip",
                    title: loc("Memory"),
                    value: String(format: "%.0f%%", monitor.memory.usagePercentage),
                    progress: monitor.memory.usagePercentage / 100.0
                )
                CompactStatusRow(
                    icon: "arrow.up.arrow.down",
                    title: loc("Network"),
                    value: formatNetworkThroughput()
                )
                CompactStatusRow(
                    icon: "internaldrive",
                    title: loc("Disk"),
                    value: String(format: "%.0f%%", monitor.disk.usagePercentage),
                    progress: monitor.disk.usagePercentage / 100.0
                )
                if monitor.battery.isPresent {
                    CompactStatusRow(
                        icon: monitor.battery.isCharging ? "battery.100percent.bolt" : "battery.100percent",
                        title: loc("Battery"),
                        value: String(format: "%.0f%%", monitor.battery.percentage),
                        progress: monitor.battery.percentage / 100.0
                    )
                }
                CompactStatusRow(
                    icon: "thermometer.medium",
                    title: loc("Temperature"),
                    value: "\(Int(monitor.sensor.cpuTemperature))°C",
                    progress: max(0.0, min(1.0, (monitor.sensor.cpuTemperature - 30.0) / 70.0))
                )
            }
            .padding(.vertical, 2)
            
            // Action Buttons
            VStack(spacing: 8) {
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

public struct CompactStatusRow: View {
    public let icon: String
    public let title: String
    public let value: String
    public var progress: Double? = nil
    
    @State private var isHovered = false
    @State private var justCopied = false
    
    public init(icon: String, title: String, value: String, progress: Double? = nil) {
        self.icon = icon
        self.title = title
        self.value = value
        self.progress = progress
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MectricsTheme.coral)
                .frame(width: 16)
            
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(MectricsTheme.textSecondary)
            
            Spacer()
            
            if let p = progress {
                GeometryReader { _ in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(white: 0.18))
                        Capsule()
                            .fill(MectricsTheme.coral)
                            .frame(width: CGFloat(max(0.04, min(1.0, p))) * 38)
                    }
                }
                .frame(width: 38, height: 4)
                .padding(.trailing, 2)
            }
            
            HStack(spacing: 4) {
                if justCopied {
                    Text(loc("Copied!"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(MectricsTheme.coral)
                        .transition(.scale.combined(with: .opacity))
                }
                
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3.5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("\(title): \(value)", forType: .string)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                justCopied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.2)) {
                    justCopied = false
                }
            }
        }
    }
}

public struct AttentionLogView: View {
    @ObservedObject var rulesEngine: RulesEngine
    @Environment(\.dismiss) private var dismiss
    
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
