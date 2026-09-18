import SwiftUI

public struct MemoryPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "memorychip")
                    .font(.title2)
                    .foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Memory (RAM)")
                        .font(.headline)
                    Text("\(formatBytes(monitor.memory.usedBytes)) of \(formatBytes(monitor.memory.totalBytes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f%%", monitor.memory.usagePercentage))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.purple)
                    
                    Text(monitor.memory.pressureLevel.rawValue)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(pressureColor.opacity(0.15))
                        .foregroundStyle(pressureColor)
                        .clipShape(Capsule())
                }
            }
            
            // Live Sparkline
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Memory Trend (Last 30s)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Available: \(formatBytes(monitor.memory.freeBytes + monitor.memory.cachedBytes))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                SparklineView(
                    values: monitor.memoryHistory.values,
                    strokeColor: .purple,
                    gradientColors: [.purple.opacity(0.4), .purple.opacity(0.05)],
                    lineWidth: 2,
                    showFill: true
                )
                .frame(height: 50)
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Memory Breakdown
            SectionCardView(title: "Memory Composition", icon: "chart.pie") {
                VStack(spacing: 8) {
                    MetricBarView(
                        label: "App Memory",
                        valueText: formatBytes(monitor.memory.activeBytes),
                        progress: ratio(monitor.memory.activeBytes),
                        tintColor: .blue
                    )
                    MetricBarView(
                        label: "Wired Memory",
                        valueText: formatBytes(monitor.memory.wiredBytes),
                        progress: ratio(monitor.memory.wiredBytes),
                        tintColor: .red
                    )
                    MetricBarView(
                        label: "Compressed",
                        valueText: formatBytes(monitor.memory.compressedBytes),
                        progress: ratio(monitor.memory.compressedBytes),
                        tintColor: .orange
                    )
                    MetricBarView(
                        label: "Cached Files",
                        valueText: formatBytes(monitor.memory.cachedBytes),
                        progress: ratio(monitor.memory.cachedBytes),
                        tintColor: .green
                    )
                }
            }
            
            // Swap File Section
            SectionCardView(title: "Virtual Memory (Swap)", icon: "arrow.triangle.2.circlepath") {
                HStack {
                    Text("Swap Used:")
                        .font(.caption)
                    Spacer()
                    Text(formatBytes(monitor.memory.swapUsedBytes))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(monitor.memory.swapUsedBytes > 500 * 1024 * 1024 ? .orange : .primary)
                }
            }
        }
        .padding(16)
        .frame(width: 320)
    }
    
    private var pressureColor: Color {
        switch monitor.memory.pressureLevel {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    private func ratio(_ bytes: UInt64) -> Double {
        guard monitor.memory.totalBytes > 0 else { return 0 }
        return Double(bytes) / Double(monitor.memory.totalBytes)
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
