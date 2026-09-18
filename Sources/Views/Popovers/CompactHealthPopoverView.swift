import SwiftUI
import AppKit

public struct CompactHealthPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var showingSettings = false
    @State private var showingAttentionLog = false
    @State private var copiedSummaryAlert = false
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            PopoverHeaderView(
                icon: "checkmark.shield",
                title: monitor.rulesEngine.activeAlerts.isEmpty ? "All systems normal" : "Active Alerts",
                onRefresh: {
                    monitor.refreshAll()
                }
            )
            
            // Subtitle
            Text(monitor.rulesEngine.activeAlerts.isEmpty ?
                 "Mectrics will show selected alert conditions here." :
                 monitor.rulesEngine.activeAlerts.joined(separator: "\n"))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(monitor.rulesEngine.activeAlerts.isEmpty ? MectricsTheme.textSecondary : MectricsTheme.coral)
                .fixedSize(horizontal: false, vertical: true)
            
            // Status Items
            VStack(spacing: 8) {
                statusRow(
                    icon: "cpu",
                    title: "CPU",
                    value: String(format: "%.0f%%", monitor.cpu.totalUsage)
                )
                statusRow(
                    icon: "memorychip",
                    title: "Memory",
                    value: String(format: "%.0f%%", monitor.memory.usagePercentage)
                )
                statusRow(
                    icon: "arrow.up.arrow.down",
                    title: "Network",
                    value: formatNetworkThroughput()
                )
                statusRow(
                    icon: "internaldrive",
                    title: "Disk",
                    value: String(format: "%.0f%%", monitor.disk.usagePercentage)
                )
            }
            .padding(.vertical, 4)
            
            // Action Buttons
            VStack(spacing: 8) {
                PopoverActionButton(icon: "list.bullet.rectangle", title: "Open Attention Log") {
                    AppState.shared.openAttentionLog()
                }
                
                PopoverActionButton(icon: "doc.on.doc", title: copiedSummaryAlert ? "Summary Copied!" : "Copy System Summary") {
                    copySummaryToClipboard()
                    copiedSummaryAlert = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copiedSummaryAlert = false
                    }
                }
            }
            
            // Footer
            PopoverFooterView(showingSettings: $showingSettings)
        }
        .mectricsPopoverStyle()
        .sheet(isPresented: $showingSettings) {
            SettingsView(monitor: monitor)
        }
        .sheet(isPresented: $showingAttentionLog) {
            AttentionLogView(rulesEngine: monitor.rulesEngine)
        }
    }
    
    private func statusRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MectricsTheme.textSecondary)
                .frame(width: 18)
            
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
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

public struct AttentionLogView: View {
    @ObservedObject var rulesEngine: RulesEngine
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Attention Log")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
            
            Divider()
            
            if rulesEngine.activeAlerts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.largeTitle)
                        .foregroundStyle(MectricsTheme.coral)
                    Text("No active alerts or events")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(rulesEngine.activeAlerts, id: \.self) { alert in
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(MectricsTheme.coral)
                        Text(alert)
                            .font(.system(size: 13))
                    }
                }
            }
        }
        .frame(width: 400, height: 300)
    }
}
