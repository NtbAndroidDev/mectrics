import SwiftUI

public struct CPUPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "cpu")
                    .font(.title2)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Processor (CPU)")
                        .font(.headline)
                    Text(monitor.cpu.modelName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f%%", monitor.cpu.totalUsage))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                    Text(String(format: "%.1f°C", monitor.sensor.cpuTemperature))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Live Sparkline Trend
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Live Trend (Last 30s)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Avg: \(String(format: "%.1f%%", monitor.cpuHistory.average))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                SparklineView(
                    values: monitor.cpuHistory.values,
                    strokeColor: .blue,
                    gradientColors: [.blue.opacity(0.4), .blue.opacity(0.05)],
                    lineWidth: 2,
                    showFill: true
                )
                .frame(height: 50)
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Core Bars
            SectionCardView(title: "Per-Core Activity (\(monitor.cpu.perCoreUsage.count) Cores)", icon: "square.grid.2x2") {
                let columns = [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ]
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(monitor.cpu.perCoreUsage.enumerated()), id: \.offset) { index, usage in
                        MetricBarView(
                            label: "Core \(index + 1)",
                            valueText: String(format: "%.0f%%", usage),
                            progress: usage / 100.0,
                            tintColor: colorForUsage(usage),
                            height: 5
                        )
                    }
                }
            }
            
            // Load Averages & Breakdown
            SectionCardView(title: "Execution Breakdown", icon: "chart.bar.xaxis") {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("User: \(String(format: "%.1f%%", monitor.cpu.userUsage))")
                            .font(.caption)
                        Text("System: \(String(format: "%.1f%%", monitor.cpu.systemUsage))")
                            .font(.caption)
                        Text("Idle: \(String(format: "%.1f%%", monitor.cpu.idleUsage))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                        .frame(height: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Load 1m: \(String(format: "%.2f", monitor.cpu.loadAverages.one))")
                            .font(.caption)
                        Text("Load 5m: \(String(format: "%.2f", monitor.cpu.loadAverages.five))")
                            .font(.caption)
                        Text("Load 15m: \(String(format: "%.2f", monitor.cpu.loadAverages.fifteen))")
                            .font(.caption)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 320)
    }
    
    private func colorForUsage(_ val: Double) -> Color {
        if val > 80 { return .red }
        if val > 50 { return .orange }
        return .blue
    }
}
