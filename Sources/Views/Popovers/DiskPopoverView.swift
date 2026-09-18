import SwiftUI
import AppKit

public struct DiskPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var showingSettings = false
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            PopoverHeaderView(
                icon: "internaldrive",
                title: "Disk",
                rightText: String(format: "%.1f%%", monitor.disk.usagePercentage),
                ringProgress: monitor.disk.usagePercentage / 100.0
            )
            
            // Multi-segment Disk Bar & Legend
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    let total = max(1, Double(monitor.disk.totalBytes))
                    let usedWidth = geo.size.width * CGFloat(min(1.0, Double(monitor.disk.usedBytes) / total))
                    let purgeWidth = geo.size.width * CGFloat(min(1.0, Double(monitor.disk.purgeableBytes) / total))
                    
                    ZStack(alignment: .leading) {
                        // Background (Free)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(white: 0.22))
                        
                        // Purgeable + Used
                        RoundedRectangle(cornerRadius: 6)
                            .fill(MectricsTheme.purgeableColor)
                            .frame(width: min(geo.size.width, usedWidth + purgeWidth))
                        
                        // Used
                        RoundedRectangle(cornerRadius: 6)
                            .fill(MectricsTheme.coral)
                            .frame(width: usedWidth)
                    }
                }
                .frame(height: 12)
                
                // Legend
                HStack(spacing: 12) {
                    legendItem(color: MectricsTheme.coral, label: "Used")
                    legendItem(color: MectricsTheme.purgeableColor, label: "Purgeable")
                    legendItem(color: Color(white: 0.35), label: "Free")
                }
                .padding(.top, 2)
            }
            
            // Key-Value List
            VStack(spacing: 2) {
                PopoverKeyValueRow(label: "Used", value: formatGB(monitor.disk.usedBytes))
                PopoverKeyValueRow(label: "Free", value: formatGB(monitor.disk.freeBytes))
                PopoverKeyValueRow(label: "Purgeable", value: formatGB(monitor.disk.purgeableBytes))
                PopoverKeyValueRow(label: "Total", value: formatGB(monitor.disk.totalBytes))
                PopoverKeyValueRow(label: "Read", value: formatRate(monitor.disk.readBytesPerSec))
                PopoverKeyValueRow(label: "Write", value: formatRate(monitor.disk.writeBytesPerSec))
            }
            .padding(.vertical, 2)
            
            // Action Button
            PopoverActionButton(icon: "internaldrive", title: "Open Storage Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Storage-Settings.extension") {
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
    
    private func formatRate(_ bytesPerSec: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(bytesPerSec)))/s"
    }
}
