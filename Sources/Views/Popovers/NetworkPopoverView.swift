import SwiftUI
import AppKit

public struct NetworkPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var showingSettings = false
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            PopoverHeaderView(
                icon: "arrow.up.arrow.down",
                title: "Network",
                rightText: formatRate(monitor.network.downloadBytesPerSec + monitor.network.uploadBytesPerSec)
            )
            
            // Dual Sparklines
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Download (Inbound)")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(MectricsTheme.textSecondary)
                        Spacer()
                        Text(formatRate(monitor.network.downloadBytesPerSec))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(MectricsTheme.coral)
                    }
                    SparklineView(
                        values: monitor.networkDownHistory.values,
                        strokeColor: MectricsTheme.coral,
                        lineWidth: 1.5,
                        showFill: true,
                        minScale: 0.0,
                        maxScale: nil
                    )
                    .frame(height: 32)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Upload (Outbound)")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(MectricsTheme.textSecondary)
                        Spacer()
                        Text(formatRate(monitor.network.uploadBytesPerSec))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(MectricsTheme.coralMuted)
                    }
                    SparklineView(
                        values: monitor.networkUpHistory.values,
                        strokeColor: MectricsTheme.coralMuted,
                        lineWidth: 1.5,
                        showFill: true,
                        minScale: 0.0,
                        maxScale: nil
                    )
                    .frame(height: 32)
                }
            }
            
            // Key-Value List
            VStack(spacing: 2) {
                PopoverKeyValueRow(label: "Interface", value: monitor.network.primaryInterfaceName)
                PopoverKeyValueRow(label: "IP Address", value: monitor.network.ipv4Address)
                PopoverKeyValueRow(label: "Total Downloaded", value: formatBytes(monitor.network.totalDownloadedBytes))
                PopoverKeyValueRow(label: "Total Uploaded", value: formatBytes(monitor.network.totalUploadedBytes))
            }
            .padding(.vertical, 2)
            
            // Action Button
            PopoverActionButton(icon: "network", title: "Open Network Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
                    NSWorkspace.shared.open(url)
                } else if let url = URL(string: "x-apple.systempreferences:") {
                    NSWorkspace.shared.open(url)
                }
            }
            
            // Footer
            PopoverFooterView(showingSettings: $showingSettings)
        }
        .mectricsPopoverStyle()
        .sheet(isPresented: $showingSettings) {
            SettingsView(monitor: monitor)
        }
    }
    
    private func formatRate(_ bytesPerSec: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(bytesPerSec)))/s"
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
