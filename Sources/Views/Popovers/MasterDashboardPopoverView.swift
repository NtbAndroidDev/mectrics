import SwiftUI
import AppKit

public struct MasterDashboardPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject private var sleepBlocker = SleepBlocker.shared
    @State private var isFlushingDNS = false
    @State private var flushedSuccess = false
    @State private var isTrashCleaning = false
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Mac Model & Overall Health
            HStack(spacing: 8) {
                Image(systemName: "macbook.gen2")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MectricsTheme.coral)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(loc("Master Dashboard"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MectricsTheme.textPrimary)
                    Text(monitor.cpu.modelName)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(MectricsTheme.textSecondary)
                }
                
                Spacer()
                
                // Anti-Sleep Toggle Button
                Button {
                    sleepBlocker.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: sleepBlocker.isKeepAwakeActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                            .font(.system(size: 11))
                        Text(sleepBlocker.isKeepAwakeActive ? loc("Awake") : loc("Sleep OK"))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(sleepBlocker.isKeepAwakeActive ? Color.orange : MectricsTheme.textSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(sleepBlocker.isKeepAwakeActive ? Color.orange.opacity(0.18) : Color.white.opacity(0.06))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 2)
            
            // Grid 2x2: Core Stats
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                // CPU Card
                dashboardCard(
                    icon: "cpu",
                    title: loc("CPU"),
                    primaryText: String(format: "%.0f%%", monitor.cpu.totalUsage),
                    subText: monitor.cpu.pCores > 0 ? "\(monitor.cpu.pCores)P + \(monitor.cpu.eCores)E" : "\(monitor.cpu.logicalCores) Cores",
                    sparklineValues: monitor.cpuHistory.values,
                    accentColor: MectricsTheme.coral
                )
                
                // Memory Card
                dashboardCard(
                    icon: "memorychip",
                    title: loc("Memory"),
                    primaryText: String(format: "%.0f%%", monitor.memory.usagePercentage),
                    subText: "\(monitor.memory.usedBytes / (1024 * 1024 * 1024)) / \(monitor.memory.totalBytes / (1024 * 1024 * 1024)) GB",
                    sparklineValues: monitor.memoryHistory.values,
                    accentColor: monitor.memory.pressureLevel == .critical ? Color.red : (monitor.memory.pressureLevel == .warning ? Color.yellow : Color(red: 0.35, green: 0.78, blue: 0.98))
                )
                
                // Battery Card
                dashboardCard(
                    icon: monitor.battery.isCharging ? "battery.100percent.bolt" : "battery.100percent",
                    title: loc("Battery"),
                    primaryText: String(format: "%.0f%%", monitor.battery.percentage),
                    subText: monitor.battery.cycleCount > 0 ? "\(monitor.battery.cycleCount) cycles (\(String(format: "%.0f%%", monitor.battery.healthPercentage)))" : monitor.battery.powerSource,
                    sparklineValues: nil,
                    accentColor: monitor.battery.isCharging ? Color(red: 0.20, green: 0.85, blue: 0.65) : MectricsTheme.coral
                )
                
                // Disk Card
                dashboardCard(
                    icon: "internaldrive",
                    title: loc("Disk"),
                    primaryText: String(format: "%.0f%%", monitor.disk.usagePercentage),
                    subText: "\(monitor.disk.freeBytes / (1024 * 1024 * 1024)) GB \(loc("Free"))",
                    sparklineValues: nil,
                    accentColor: Color(white: 0.8)
                )
            }
            
            // Network Strip
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(MectricsTheme.coral)
                    Text(formatRate(monitor.network.downloadBytesPerSec))
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(MectricsTheme.coralMuted)
                    Text(formatRate(monitor.network.uploadBytesPerSec))
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                if let ping = monitor.network.pingLatencyMs {
                    Text(String(format: "%.0f ms", ping))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(ping > 120 ? Color.red : MectricsTheme.textSecondary)
                }
            }
            .padding(7)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Thermals & Fans Strip
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 10))
                        .foregroundStyle(monitor.sensor.cpuTemperature > 75.0 ? MectricsTheme.coral : MectricsTheme.textSecondary)
                    Text(monitor.formatTemperaturePrecise(monitor.sensor.cpuTemperature))
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MectricsTheme.textPrimary)
                }
                
                Spacer()
                
                if !monitor.sensor.fans.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "fan.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(MectricsTheme.textSecondary)
                        let maxRPM = monitor.sensor.fans.map(\.currentRPM).max() ?? 0
                        Text("\(maxRPM) RPM")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(MectricsTheme.textPrimary)
                    }
                } else {
                    Text(loc("Fanless / Passive"))
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundStyle(MectricsTheme.textTertiary)
                }
                
                Spacer()
                
                Text(ProcessMonitor.formattedUptime())
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(MectricsTheme.textTertiary)
            }
            .padding(7)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Action Buttons
            HStack(spacing: 6) {
                PopoverActionButton(
                    icon: isFlushingDNS ? "arrow.triangle.2.circlepath" : "bolt.shield",
                    title: isFlushingDNS ? loc("Flushing...") : (flushedSuccess ? loc("Flushed!") : loc("Flush DNS"))
                ) {
                    guard !isFlushingDNS else { return }
                    isFlushingDNS = true
                    DispatchQueue.global(qos: .userInitiated).async {
                        let p1 = Process()
                        p1.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
                        p1.arguments = ["-flushcache"]
                        try? p1.run()
                        p1.waitUntilExit()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isFlushingDNS = false
                            flushedSuccess = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                flushedSuccess = false
                            }
                        }
                    }
                }
                
                PopoverActionButton(icon: "speedometer", title: loc("Activity Monitor")) {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
                        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                    }
                }
            }
            
            // Footer
            PopoverFooterView()
        }
        .frame(width: 290)
        .mectricsPopoverStyle()
    }
    
    private func dashboardCard(
        icon: String,
        title: String,
        primaryText: String,
        subText: String,
        sparklineValues: [Double]?,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(MectricsTheme.textSecondary)
                Spacer()
                Text(primaryText)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            
            if let values = sparklineValues, values.count >= 2 {
                SparklineView(
                    values: values,
                    strokeColor: accentColor,
                    lineWidth: 1.2,
                    showFill: true,
                    minScale: 0.0,
                    maxScale: 100.0
                )
                .frame(height: 16)
            }
            
            Text(subText)
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundStyle(MectricsTheme.textTertiary)
                .lineLimit(1)
        }
        .padding(8)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    private func formatRate(_ bytesPerSec: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(bytesPerSec)))/s"
    }
}
