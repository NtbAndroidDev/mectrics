import SwiftUI

public struct GPUPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "display")
                    .font(.title2)
                    .foregroundStyle(.pink)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Graphics (GPU)")
                        .font(.headline)
                    Text(monitor.gpu.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "%.1f%%", monitor.gpu.usagePercentage))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.pink)
            }
            
            // Live Sparkline
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("GPU Load Trend")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Avg: \(String(format: "%.1f%%", monitor.gpuHistory.average))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                SparklineView(
                    values: monitor.gpuHistory.values,
                    strokeColor: .pink,
                    gradientColors: [.pink.opacity(0.4), .pink.opacity(0.05)],
                    lineWidth: 2,
                    showFill: true
                )
                .frame(height: 50)
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Memory & Details
            SectionCardView(title: "Metal & VRAM Allocation", icon: "square.stack.3d.up") {
                VStack(spacing: 8) {
                    if monitor.gpu.memoryTotalBytes > 0 {
                        MetricBarView(
                            label: "Working Set Memory",
                            valueText: "\(formatBytes(monitor.gpu.memoryUsedBytes)) / \(formatBytes(monitor.gpu.memoryTotalBytes))",
                            progress: Double(monitor.gpu.memoryUsedBytes) / Double(monitor.gpu.memoryTotalBytes),
                            tintColor: .pink
                        )
                    } else {
                        HStack {
                            Text("Unified Memory Shared:")
                                .font(.caption)
                            Spacer()
                            Text(formatBytes(monitor.gpu.memoryUsedBytes))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 300)
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
