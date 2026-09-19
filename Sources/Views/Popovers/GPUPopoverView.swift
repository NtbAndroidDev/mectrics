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
                PopoverKeyValueRow(label: loc("Processor"), value: monitor.gpu.name, icon: "cpu")
                PopoverKeyValueRow(label: loc("Working Set VRAM"), value: formatBytes(monitor.gpu.memoryUsedBytes), icon: "memorychip")
                if monitor.gpu.memoryTotalBytes > 0 {
                    PopoverKeyValueRow(label: loc("Total Metal VRAM"), value: formatBytes(monitor.gpu.memoryTotalBytes), icon: "memorychip.fill")
                }
            }
            .padding(.vertical, 2)
            
            // VRAM Usage Progress Bar
            if monitor.gpu.memoryTotalBytes > 0 {
                let vramPct = min(1.0, Double(monitor.gpu.memoryUsedBytes) / Double(monitor.gpu.memoryTotalBytes))
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(loc("VRAM Allocation"))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(MectricsTheme.textSecondary)
                        Spacer()
                        Text(String(format: "%.0f%%", vramPct * 100))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(white: 0.18))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [MectricsTheme.coral, MectricsTheme.coralMuted],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(max(0.04, vramPct)))
                        }
                    }
                    .frame(height: 7)
                }
                .padding(.vertical, 2)
            }
            
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
