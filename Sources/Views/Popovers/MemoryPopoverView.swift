import SwiftUI
import AppKit

public struct MemoryPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            PopoverHeaderView(
                icon: "memorychip",
                title: loc("Memory"),
                rightText: String(format: "%.1f%%", monitor.memory.usagePercentage),
                ringProgress: monitor.memory.usagePercentage / 100.0
            )
            
            // Memory Composition Bar
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geo in
                    let total = max(1, Double(monitor.memory.totalBytes))
                    let appWidth = geo.size.width * CGFloat(min(1.0, Double(monitor.memory.activeBytes) / total))
                    let wiredWidth = geo.size.width * CGFloat(min(1.0, Double(monitor.memory.wiredBytes) / total))
                    let compWidth = geo.size.width * CGFloat(min(1.0, Double(monitor.memory.compressedBytes) / total))
                    
                    ZStack(alignment: .leading) {
                        // Background (Cached + Free)
                        Capsule()
                            .fill(Color(white: 0.20))
                        
                        // App + Wired + Compressed
                        Capsule()
                            .fill(MectricsTheme.coralDark)
                            .frame(width: min(geo.size.width, appWidth + wiredWidth + compWidth))
                        
                        // App + Wired
                        Capsule()
                            .fill(MectricsTheme.coralMuted)
                            .frame(width: min(geo.size.width, appWidth + wiredWidth))
                        
                        // App Memory
                        Capsule()
                            .fill(MectricsTheme.coral)
                            .frame(width: appWidth)
                    }
                }
                .frame(height: 14)
                .clipShape(Capsule())
                
                // Legend
                HStack(spacing: 12) {
                    legendItem(color: MectricsTheme.coral, label: loc("App"))
                    legendItem(color: MectricsTheme.coralMuted, label: loc("Wired"))
                    legendItem(color: MectricsTheme.coralDark, label: loc("Compressed"))
                    legendItem(color: Color(white: 0.45), label: loc("Cached"))
                }
                .padding(.top, 2)
            }
            
            // Key-Value Breakdown
            VStack(spacing: 2) {
                PopoverKeyValueRow(label: loc("App Memory"), value: formatGB(monitor.memory.activeBytes))
                PopoverKeyValueRow(label: loc("Wired Memory"), value: formatGB(monitor.memory.wiredBytes))
                PopoverKeyValueRow(label: loc("Compressed"), value: formatGB(monitor.memory.compressedBytes))
                PopoverKeyValueRow(label: loc("Cached Files"), value: formatGB(monitor.memory.cachedBytes))
                PopoverKeyValueRow(label: loc("Total RAM"), value: formatGB(monitor.memory.totalBytes))
                PopoverKeyValueRow(label: loc("Swap Used"), value: formatGB(monitor.memory.swapUsedBytes), isHighlighted: monitor.memory.swapUsedBytes > 500 * 1024 * 1024)
            }
            .padding(.vertical, 2)
            
            // Action Button
            PopoverActionButton(icon: "memorychip", title: loc("Open Activity Monitor (Memory)")) {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
                    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                }
            }
            
            // Footer
            PopoverFooterView()
        }
        .mectricsPopoverStyle()
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(MectricsTheme.textSecondary)
        }
    }
    
    private func formatGB(_ bytes: UInt64) -> String {
        return String(format: "%.1f GB", Double(bytes) / (1024 * 1024 * 1024))
    }
}
