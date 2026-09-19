import SwiftUI
import AppKit

public struct CPUPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var showTopProcesses = false
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            PopoverHeaderView(
                icon: "cpu",
                title: loc("CPU"),
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
            
            // Per-Core Equalizer Blocks
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(loc("Core Activity"))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(MectricsTheme.textSecondary)
                    Spacer()
                    if monitor.cpu.pCores > 0 && monitor.cpu.eCores > 0 {
                        Text("\(monitor.cpu.pCores)P + \(monitor.cpu.eCores)E \(loc("Cores"))")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(MectricsTheme.textTertiary)
                    } else {
                        Text("\(monitor.cpu.logicalCores) \(loc("Cores"))")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(MectricsTheme.textTertiary)
                    }
                }
                
                HStack(spacing: 3.5) {
                    let cores = monitor.cpu.perCoreUsage.isEmpty ? Array(repeating: monitor.cpu.totalUsage, count: monitor.cpu.logicalCores) : monitor.cpu.perCoreUsage
                    let eCount = monitor.cpu.eCores
                    
                    ForEach(Array(cores.enumerated()), id: \.offset) { index, usage in
                        let isECore = (eCount > 0 && index < eCount)
                        let coreLabel = eCount > 0 ? (isECore ? "E\(index + 1)" : "P\(index - eCount + 1)") : "\(index + 1)"
                        let coreHelp = isECore ? "E-Core \(index + 1) (Efficiency): \(String(format: "%.1f%%", usage))" : "P-Core \(eCount > 0 ? index - eCount + 1 : index + 1) (Performance): \(String(format: "%.1f%%", usage))"
                        
                        VStack(spacing: 2) {
                            GeometryReader { geo in
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 2.5)
                                        .fill(Color(white: 0.18))
                                    
                                    let fillHeight = geo.size.height * CGFloat(max(0.04, min(1.0, usage / 100.0)))
                                    RoundedRectangle(cornerRadius: 2.5)
                                        .fill(
                                            usage > 75.0 ? MectricsTheme.coral :
                                            (isECore ? Color(red: 0.35, green: 0.78, blue: 0.98).opacity(max(0.5, usage / 100.0)) :
                                             (usage > 35.0 ? MectricsTheme.coralMuted : Color.white.opacity(0.65)))
                                        )
                                        .frame(height: fillHeight)
                                }
                            }
                            .frame(height: 22)
                            
                            Text(coreLabel)
                                .font(.system(size: 7.0, weight: .semibold, design: .monospaced))
                                .foregroundStyle(isECore ? Color(red: 0.45, green: 0.85, blue: 1.0) : MectricsTheme.textTertiary)
                        }
                        .help(coreHelp)
                    }
                }
                .padding(6)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.vertical, 2)
            
            // Info List
            VStack(spacing: 2) {
                if monitor.cpu.pCores > 0 && monitor.cpu.eCores > 0 {
                    PopoverKeyValueRow(
                        label: loc("Cores"),
                        value: "\(monitor.cpu.logicalCores) (\(monitor.cpu.pCores)P + \(monitor.cpu.eCores)E)",
                        icon: "square.grid.2x2.fill"
                    )
                } else {
                    PopoverKeyValueRow(
                        label: loc("Cores"),
                        value: "\(monitor.cpu.logicalCores)",
                        icon: "square.grid.2x2.fill"
                    )
                }
                PopoverKeyValueRow(
                    label: loc("Busiest core"),
                    value: String(format: "%.0f%%", monitor.cpu.busiestCoreUsage),
                    icon: "bolt.fill"
                )
                PopoverKeyValueRow(
                    label: loc("Temperature"),
                    value: String(format: "%.1f°C", monitor.sensor.cpuTemperature),
                    icon: "thermometer.medium"
                )
                PopoverKeyValueRow(
                    label: loc("Uptime"),
                    value: ProcessMonitor.formattedUptime(),
                    icon: "clock.fill"
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
                        Text(loc("Top processes"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(MectricsTheme.coral)
                }
                .buttonStyle(.plain)
                
                if showTopProcesses {
                    let topList = ProcessMonitor.shared.topCPUProcesses()
                    VStack(spacing: 3) {
                        ForEach(topList) { proc in
                            TopProcessRowView(
                                pid: proc.id,
                                name: proc.name,
                                percentText: String(format: "%.1f%%", proc.cpuPercentage),
                                isHighLoad: proc.cpuPercentage > 40.0,
                                isMediumLoad: proc.cpuPercentage > 15.0,
                                icon: "cpu"
                            )
                        }
                    }
                    .padding(6)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            
            // Open Activity Monitor Action Button
            PopoverActionButton(icon: "speedometer", title: loc("Open Activity Monitor")) {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
                    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                } else {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                }
            }
            .padding(.top, 2)
            
            // Footer (Settings & Quit)
            PopoverFooterView()
        }
        .mectricsPopoverStyle()
    }
}
