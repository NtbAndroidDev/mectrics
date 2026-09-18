import SwiftUI
import AppKit

public struct CPUPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var showingSettings = false
    @State private var showTopProcesses = false
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            PopoverHeaderView(
                icon: "cpu",
                title: "CPU",
                rightText: String(format: "%.1f%%", monitor.cpu.totalUsage)
            )
            
            // Live Sparkline Waveform
            SparklineView(
                values: monitor.cpuHistory.values,
                strokeColor: MectricsTheme.coral,
                lineWidth: 1.8,
                showFill: true,
                minScale: 0.0,
                maxScale: 100.0
            )
            .frame(height: 44)
            
            // Horizontal Cores Blocks (as in reference Image 1)
            HStack(spacing: 4) {
                let cores = monitor.cpu.perCoreUsage.isEmpty ? Array(repeating: monitor.cpu.totalUsage, count: monitor.cpu.logicalCores) : monitor.cpu.perCoreUsage
                ForEach(Array(cores.enumerated()), id: \.offset) { index, usage in
                    GeometryReader { geo in
                        ZStack(alignment: .bottom) {
                            // Dark background block
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(white: 0.22))
                            
                            // Fill from bottom
                            let fillHeight = geo.size.height * CGFloat(max(0.04, min(1.0, usage / 100.0)))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(MectricsTheme.coral)
                                .frame(height: fillHeight)
                        }
                    }
                    .frame(height: 18)
                }
            }
            .padding(.vertical, 2)
            
            // Info List
            VStack(spacing: 2) {
                PopoverKeyValueRow(
                    label: "Cores",
                    value: "\(monitor.cpu.logicalCores)"
                )
                PopoverKeyValueRow(
                    label: "Busiest core",
                    value: String(format: "%.0f%%", monitor.cpu.busiestCoreUsage)
                )
                PopoverKeyValueRow(
                    label: "Temperature",
                    value: String(format: "%.1f°C", monitor.sensor.cpuTemperature)
                )
                PopoverKeyValueRow(
                    label: "Uptime",
                    value: ProcessMonitor.formattedUptime()
                )
            }
            
            // Collapsible Top Processes
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showTopProcesses.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showTopProcesses ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                        Text("Top processes")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(MectricsTheme.coral)
                }
                .buttonStyle(.plain)
                
                if showTopProcesses {
                    let topList = ProcessMonitor.shared.topCPUProcesses()
                    VStack(spacing: 3) {
                        ForEach(topList) { proc in
                            HStack {
                                Text(proc.name)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(MectricsTheme.textSecondary)
                                    .lineLimit(1)
                                Spacer()
                                Text(String(format: "%.1f%%", proc.cpuPercentage))
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            
            // Open Activity Monitor Action Button
            PopoverActionButton(icon: "gauge.with.needle", title: "Open Activity Monitor") {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
                    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                } else {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                }
            }
            .padding(.top, 2)
            
            // Footer (Settings & Quit)
            PopoverFooterView(showingSettings: $showingSettings)
        }
        .mectricsPopoverStyle()
        .sheet(isPresented: $showingSettings) {
            SettingsView(monitor: monitor)
        }
    }
}
