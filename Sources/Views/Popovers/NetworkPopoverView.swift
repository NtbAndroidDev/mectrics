import SwiftUI

public struct NetworkPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "network")
                    .font(.title2)
                    .foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Network Activity")
                        .font(.headline)
                    Text("\(monitor.network.primaryInterfaceName) • \(monitor.network.ipv4Address)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(monitor.network.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }
            
            // Download Section
            SectionCardView(
                title: "Download (Inbound)",
                icon: "arrow.down.circle",
                headerTrailing: AnyView(
                    Text(formatRate(monitor.network.downloadBytesPerSec))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.teal)
                )
            ) {
                SparklineView(
                    values: monitor.networkDownHistory.values,
                    strokeColor: .teal,
                    gradientColors: [.teal.opacity(0.4), .teal.opacity(0.05)],
                    lineWidth: 1.8,
                    showFill: true,
                    minScale: 0.0,
                    maxScale: nil
                )
                .frame(height: 38)
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Upload Section
            SectionCardView(
                title: "Upload (Outbound)",
                icon: "arrow.up.circle",
                headerTrailing: AnyView(
                    Text(formatRate(monitor.network.uploadBytesPerSec))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.indigo)
                )
            ) {
                SparklineView(
                    values: monitor.networkUpHistory.values,
                    strokeColor: .indigo,
                    gradientColors: [.indigo.opacity(0.4), .indigo.opacity(0.05)],
                    lineWidth: 1.8,
                    showFill: true,
                    minScale: 0.0,
                    maxScale: nil
                )
                .frame(height: 38)
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Cumulative Totals
            SectionCardView(title: "Session Transfer Data", icon: "externaldrive.connected.to.line.below") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Downloaded")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatBytes(monitor.network.totalDownloadedBytes))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Total Uploaded")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatBytes(monitor.network.totalUploadedBytes))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 320)
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
