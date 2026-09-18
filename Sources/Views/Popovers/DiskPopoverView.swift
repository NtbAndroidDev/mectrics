import SwiftUI

public struct DiskPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "internaldrive")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text(monitor.disk.volumeName)
                        .font(.headline)
                    Text("Primary Storage System • \(monitor.disk.fileSystem)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "%.1f%%", monitor.disk.usagePercentage))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.cyan)
            }
            
            // Storage Capacity Meter
            SectionCardView(title: "Capacity Breakdown", icon: "chart.bar.fill") {
                VStack(alignment: .leading, spacing: 6) {
                    MetricBarView(
                        label: "Used Space",
                        valueText: "\(formatBytes(monitor.disk.usedBytes)) of \(formatBytes(monitor.disk.totalBytes))",
                        progress: monitor.disk.totalBytes > 0 ? Double(monitor.disk.usedBytes) / Double(monitor.disk.totalBytes) : 0,
                        tintColor: monitor.disk.usagePercentage > 90 ? .red : .cyan,
                        height: 8
                    )
                    
                    HStack {
                        Text("Free Available:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatBytes(monitor.disk.freeBytes))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }
            }
            
            // Live Read & Write Throughput
            SectionCardView(title: "Live Disk I/O Throughput", icon: "waveform.path.ecg") {
                VStack(spacing: 10) {
                    // Read
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("Read Rate")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatRate(monitor.disk.readBytesPerSec))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                        SparklineView(
                            values: monitor.diskReadHistory.values,
                            strokeColor: .blue,
                            gradientColors: [.blue.opacity(0.35), .blue.opacity(0.05)],
                            lineWidth: 1.5,
                            showFill: true,
                            minScale: 0.0,
                            maxScale: nil
                        )
                        .frame(height: 32)
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    // Write
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("Write Rate")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatRate(monitor.disk.writeBytesPerSec))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                        }
                        SparklineView(
                            values: monitor.diskWriteHistory.values,
                            strokeColor: .orange,
                            gradientColors: [.orange.opacity(0.35), .orange.opacity(0.05)],
                            lineWidth: 1.5,
                            showFill: true,
                            minScale: 0.0,
                            maxScale: nil
                        )
                        .frame(height: 32)
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
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
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
