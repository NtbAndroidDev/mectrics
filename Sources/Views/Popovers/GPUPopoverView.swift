import SwiftUI
import AppKit

public struct GPUPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            PopoverHeaderView(
                icon: "display",
                title: loc("GPU"),
                rightText: String(format: "%.1f%%", monitor.gpu.usagePercentage),
                ringProgress: monitor.gpu.usagePercentage / 100.0
            )
            
            // Sparkline
            SparklineView(
                values: monitor.gpuHistory.values,
                strokeColor: MectricsTheme.coral,
                lineWidth: 1.8,
                showFill: true,
                minScale: 0.0,
                maxScale: 100.0
            )
            .frame(height: 44)
            
            // Key-Value List
            VStack(spacing: 2) {
                PopoverKeyValueRow(label: loc("Processor"), value: monitor.gpu.name)
                PopoverKeyValueRow(label: loc("Working Set VRAM"), value: formatBytes(monitor.gpu.memoryUsedBytes))
                if monitor.gpu.memoryTotalBytes > 0 {
                    PopoverKeyValueRow(label: loc("Total Metal VRAM"), value: formatBytes(monitor.gpu.memoryTotalBytes))
                }
            }
            .padding(.vertical, 2)
            
            // Action Button
            PopoverActionButton(icon: "display", title: loc("Open Displays Settings")) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") {
                    NSWorkspace.shared.open(url)
                } else if let url = URL(string: "x-apple.systempreferences:") {
                    NSWorkspace.shared.open(url)
                }
            }
            
            // Footer
            PopoverFooterView()
        }
        .mectricsPopoverStyle()
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
