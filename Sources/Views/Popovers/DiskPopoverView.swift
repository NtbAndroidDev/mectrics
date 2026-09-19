import SwiftUI
import AppKit

public struct DiskPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var isEmptyingTrash = false
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header (Matches Image 3)
            PopoverHeaderView(
                icon: "internaldrive",
                title: loc("Disk"),
                rightText: String(format: "%.1f%%", monitor.disk.usagePercentage),
                ringProgress: monitor.disk.usagePercentage / 100.0
            )
            
            // Multi-segment Disk Bar & Legend
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geo in
                    let total = max(1, Double(monitor.disk.totalBytes))
                    let usedWidth = geo.size.width * CGFloat(min(1.0, Double(monitor.disk.usedBytes) / total))
                    let purgeWidth = geo.size.width * CGFloat(min(1.0, Double(monitor.disk.purgeableBytes) / total))
                    
                    ZStack(alignment: .leading) {
                        // Background (Free)
                        Capsule()
                            .fill(Color(white: 0.20))
                        
                        // Purgeable + Used
                        Capsule()
                            .fill(MectricsTheme.purgeableColor)
                            .frame(width: min(geo.size.width, usedWidth + purgeWidth))
                        
                        // Used
                        Capsule()
                            .fill(MectricsTheme.coral)
                            .frame(width: usedWidth)
                    }
                }
                .frame(height: 14)
                .clipShape(Capsule())
                
                // Legend
                HStack(spacing: 14) {
                    legendItem(color: MectricsTheme.coral, label: loc("Used"))
                    legendItem(color: MectricsTheme.purgeableColor, label: loc("Purgeable"))
                    legendItem(color: Color(white: 0.45), label: loc("Free"))
                }
                .padding(.top, 2)
            }
            
            // Dual Disk I/O Sparklines
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(MectricsTheme.coral)
                            Text(loc("Read (Disk I/O)"))
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(MectricsTheme.textSecondary)
                        }
                        Spacer()
                        Text(formatRate(monitor.disk.readBytesPerSec))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(MectricsTheme.coral)
                    }
                    SparklineView(
                        values: monitor.diskReadHistory.values,
                        strokeColor: MectricsTheme.coral,
                        lineWidth: 1.4,
                        showFill: true,
                        minScale: 0.0,
                        maxScale: nil
                    )
                    .frame(height: 26)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(MectricsTheme.coralMuted)
                            Text(loc("Write (Disk I/O)"))
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(MectricsTheme.textSecondary)
                        }
                        Spacer()
                        Text(formatRate(monitor.disk.writeBytesPerSec))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(MectricsTheme.coralMuted)
                    }
                    SparklineView(
                        values: monitor.diskWriteHistory.values,
                        strokeColor: MectricsTheme.coralMuted,
                        lineWidth: 1.4,
                        showFill: true,
                        minScale: 0.0,
                        maxScale: nil
                    )
                    .frame(height: 26)
                }
            }
            
            // Key-Value List
            VStack(spacing: 2) {
                PopoverKeyValueRow(label: loc("Volume"), value: "\(monitor.disk.volumeName) (\(monitor.disk.fileSystem))", icon: "internaldrive")
                PopoverKeyValueRow(label: loc("Used"), value: formatGB(monitor.disk.usedBytes), icon: "chart.pie.fill")
                PopoverKeyValueRow(label: loc("Free"), value: formatGB(monitor.disk.freeBytes), icon: "arrow.down.right.circle")
                PopoverKeyValueRow(label: loc("Purgeable"), value: formatGB(monitor.disk.purgeableBytes), icon: "arrow.3.trianglepath")
                PopoverKeyValueRow(label: loc("Total"), value: formatGB(monitor.disk.totalBytes), icon: "circle.grid.cross.fill")
                if monitor.disk.trashBytes > 1024 {
                    PopoverKeyValueRow(label: loc("Trash"), value: formatBytes(monitor.disk.trashBytes), icon: "trash.fill")
                }
            }
            .padding(.vertical, 2)
            
            // Mounted Volumes (Internal & External / USB)
            if !monitor.disk.volumes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc("Mounted Volumes"))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(MectricsTheme.textSecondary)
                    
                    VStack(spacing: 5) {
                        ForEach(monitor.disk.volumes) { vol in
                            VolumeRowView(volume: vol)
                        }
                    }
                    .padding(6)
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(.vertical, 2)
            }
            
            // Action Buttons
            VStack(spacing: 8) {
                if monitor.disk.trashBytes > 1024 {
                    PopoverActionButton(
                        icon: isEmptyingTrash ? "arrow.triangle.2.circlepath" : "trash",
                        title: isEmptyingTrash ? loc("Emptying Trash...") : loc("Empty Trash")
                    ) {
                        guard !isEmptyingTrash else { return }
                        isEmptyingTrash = true
                        DiskMonitor.emptyTrash()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            isEmptyingTrash = false
                            SystemMonitor.shared.refreshAll()
                        }
                    }
                }
                
                PopoverActionButton(icon: "wrench.and.screwdriver", title: loc("Open Disk Utility")) {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.DiskUtility") {
                        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                    }
                }
                
                PopoverActionButton(icon: "internaldrive", title: loc("Open Storage Settings")) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Storage-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    } else if let url = URL(string: "x-apple.systempreferences:") {
                        NSWorkspace.shared.open(url)
                    }
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
    
    private func formatRate(_ bytesPerSec: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(bytesPerSec)))/s"
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

public struct VolumeRowView: View {
    public let volume: VolumeInfo
    @State private var isHovered = false
    @State private var isEjecting = false
    
    public init(volume: VolumeInfo) {
        self.volume = volume
    }
    
    public var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: volume.isRemovable ? "externaldrive.fill" : "internaldrive.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(volume.isRemovable ? Color.orange : MectricsTheme.coral)
                
                Text(volume.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MectricsTheme.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                if volume.isRemovable {
                    Button {
                        isEjecting = true
                        DiskMonitor.ejectVolume(url: volume.url)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "eject.fill")
                                .font(.system(size: 8))
                            Text(isEjecting ? loc("Ejecting...") : loc("Eject"))
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(Color.red.opacity(0.9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .disabled(isEjecting)
                }
                
                Text(String(format: "%.0f%%", volume.usagePercentage))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(volume.usagePercentage > 85.0 ? MectricsTheme.coral : MectricsTheme.textSecondary)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(white: 0.18))
                    
                    Capsule()
                        .fill(volume.usagePercentage > 85.0 ? MectricsTheme.coral : Color.white.opacity(0.65))
                        .frame(width: geo.size.width * CGFloat(max(0.02, min(1.0, volume.usagePercentage / 100.0))))
                }
            }
            .frame(height: 4)
            
            HStack {
                Text("\(formatGB(volume.freeBytes)) \(loc("Free"))")
                    .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(MectricsTheme.textTertiary)
                Spacer()
                Text("\(formatGB(volume.totalBytes)) \(loc("Total"))")
                    .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(MectricsTheme.textTertiary)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(isHovered ? Color.white.opacity(0.04) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onHover { isHovered = $0 }
    }
    
    private func formatGB(_ bytes: UInt64) -> String {
        return String(format: "%.1f GB", Double(bytes) / (1024 * 1024 * 1024))
    }
}
