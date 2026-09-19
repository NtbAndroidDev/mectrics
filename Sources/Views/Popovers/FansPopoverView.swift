import SwiftUI
import AppKit

public struct FansPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            let fastestRPM = monitor.sensor.fans.map(\.currentRPM).max() ?? 0
            PopoverHeaderView(
                icon: "fan.fill",
                title: loc("Cooling Fans"),
                rightText: fastestRPM > 0 ? "\(fastestRPM) RPM" : loc("Idle / Passive")
            )
            
            // Sparkline / Visual Status
            if !monitor.sensor.fans.isEmpty {
                VStack(spacing: 8) {
                    ForEach(monitor.sensor.fans) { fan in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "fan.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(MectricsTheme.coral)
                                    Text(fan.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                Text("\(fan.currentRPM) RPM")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(MectricsTheme.coral)
                            }
                            
                            // RPM Range Bar
                            let pct = min(1.0, max(0.02, Double(fan.currentRPM) / Double(max(1, fan.maxRPM))))
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(white: 0.18))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            LinearGradient(
                                                colors: [MectricsTheme.coral.opacity(0.7), MectricsTheme.coral],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * CGFloat(pct))
                                }
                            }
                            .frame(height: 5)
                            
                            HStack {
                                Text("\(fan.minRPM) RPM")
                                    .font(.system(size: 9))
                                    .foregroundStyle(MectricsTheme.textTertiary)
                                Spacer()
                                Text("\(fan.maxRPM) RPM (Max)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(MectricsTheme.textTertiary)
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.green.opacity(0.8))
                    Text(loc("Fanless Architecture"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(loc("This Mac is passively cooled with zero mechanical noise."))
                        .font(.system(size: 11))
                        .foregroundStyle(MectricsTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            
            // Thermal Details List
            VStack(spacing: 2) {
                PopoverKeyValueRow(
                    label: loc("Thermal State"),
                    value: loc(monitor.sensor.thermalPressure.rawValue),
                    icon: monitor.sensor.thermalPressure.sfSymbol,
                    isHighlighted: monitor.sensor.thermalPressure != .nominal
                )
                PopoverKeyValueRow(
                    label: loc("CPU Thermal Zone"),
                    value: String(format: "%.1f°C", monitor.sensor.cpuTemperature),
                    icon: "thermometer.medium"
                )
                PopoverKeyValueRow(
                    label: loc("GPU Thermal Zone"),
                    value: String(format: "%.1f°C", monitor.sensor.gpuTemperature),
                    icon: "display"
                )
            }
            .padding(.vertical, 2)
            
            // Action Button
            PopoverActionButton(icon: "gauge.with.needle", title: loc("Open Activity Monitor (Energy)")) {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
                    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                }
            }
            
            // Footer
            PopoverFooterView()
        }
        .mectricsPopoverStyle()
    }
}
