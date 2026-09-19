import SwiftUI
import AppKit

public struct MemoryPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var isPurging = false
    @State private var purgedSuccess = false
    @State private var showTopProcesses = false
    
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
            
            // Memory Trend Sparkline
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 10))
                            .foregroundStyle(MectricsTheme.coral)
                        Text(loc("Memory Trend"))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(MectricsTheme.textSecondary)
                    }
                    Spacer()
                    Text(String(format: "%.1f%%", monitor.memory.usagePercentage))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(MectricsTheme.coral)
                }
                SparklineView(
                    values: monitor.memoryHistory.values,
                    strokeColor: MectricsTheme.coral,
                    lineWidth: 1.5,
                    showFill: true,
                    minScale: 0.0,
                    maxScale: 100.0
                )
                .frame(height: 28)
            }
            
            // Key-Value Breakdown
            VStack(spacing: 2) {
                PopoverKeyValueRow(label: loc("App Memory"), value: formatGB(monitor.memory.activeBytes), icon: "app.fill")
                PopoverKeyValueRow(label: loc("Wired Memory"), value: formatGB(monitor.memory.wiredBytes), icon: "lock.fill")
                PopoverKeyValueRow(label: loc("Compressed"), value: formatGB(monitor.memory.compressedBytes), icon: "arrow.down.right.and.arrow.up.left")
                PopoverKeyValueRow(label: loc("Cached Files"), value: formatGB(monitor.memory.cachedBytes), icon: "doc.on.doc.fill")
                PopoverKeyValueRow(label: loc("Total RAM"), value: formatGB(monitor.memory.totalBytes), icon: "memorychip")
                PopoverKeyValueRow(label: loc("Swap Used"), value: formatGB(monitor.memory.swapUsedBytes), icon: "arrow.left.arrow.right", isHighlighted: monitor.memory.swapUsedBytes > 500 * 1024 * 1024)
            }
            .padding(.vertical, 2)
            
            // Collapsible Top Memory Processes
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showTopProcesses.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showTopProcesses ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(loc("Top memory consumers"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(MectricsTheme.coral)
                }
                .buttonStyle(.plain)
                
                if showTopProcesses {
                    let topList = ProcessMonitor.shared.topMemoryProcesses()
                    VStack(spacing: 3) {
                        ForEach(topList) { proc in
                            TopProcessRowView(
                                pid: proc.id,
                                name: proc.name,
                                percentText: String(format: "%.1f%%", proc.memoryPercentage),
                                isHighLoad: proc.memoryPercentage > 10.0,
                                isMediumLoad: proc.memoryPercentage > 4.0,
                                icon: "memorychip"
                            )
                        }
                    }
                    .padding(6)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            
            // Action Buttons
            VStack(spacing: 8) {
                PopoverActionButton(
                    icon: isPurging ? "arrow.triangle.2.circlepath" : "sparkles",
                    title: isPurging ? loc("Purging...") : (purgedSuccess ? loc("Purged!") : loc("Purge Memory Cache"))
                ) {
                    guard !isPurging else { return }
                    isPurging = true
                    DispatchQueue.global(qos: .userInitiated).async {
                        let process = Process()
                        process.executableURL = URL(fileURLWithPath: "/usr/bin/purge")
                        try? process.run()
                        process.waitUntilExit()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            SystemMonitor.shared.refreshAll()
                            isPurging = false
                            purgedSuccess = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                purgedSuccess = false
                            }
                        }
                    }
                }
                
                PopoverActionButton(icon: "memorychip", title: loc("Open Activity Monitor (Memory)")) {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
                        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
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
}
