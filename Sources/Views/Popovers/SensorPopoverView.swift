import SwiftUI
import AppKit

public struct SensorPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            PopoverHeaderView(
                icon: "thermometer.medium",
                title: loc("Sensors"),
                rightText: String(format: "%.1f°C", monitor.sensor.cpuTemperature)
            )
            
            // Sparkline
            SparklineView(
                values: monitor.tempHistory.values,
                strokeColor: MectricsTheme.coral,
                lineWidth: 1.8,
                showFill: true,
                minScale: 30.0,
                maxScale: 100.0
            )
            .frame(height: 44)
            
            // Key-Value List
            VStack(spacing: 2) {
                PopoverKeyValueRow(label: loc("CPU Temperature"), value: String(format: "%.1f°C", monitor.sensor.cpuTemperature), icon: "thermometer.medium")
                PopoverKeyValueRow(label: loc("GPU Temperature"), value: String(format: "%.1f°C", monitor.sensor.gpuTemperature), icon: "display")
                PopoverKeyValueRow(
                    label: loc("Thermal Pressure"),
                    value: loc(monitor.sensor.thermalPressure.rawValue),
                    icon: monitor.sensor.thermalPressure.sfSymbol,
                    isHighlighted: monitor.sensor.thermalPressure != .nominal
                )
                if let fan = monitor.sensor.fans.first {
                    PopoverKeyValueRow(label: loc("Cooling Fan"), value: "\(fan.currentRPM) RPM", icon: "fan.fill")
                    let fanPct = min(1.0, Double(fan.currentRPM) / Double(max(1, fan.maxRPM)))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(white: 0.18))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(MectricsTheme.coral)
                                .frame(width: geo.size.width * CGFloat(max(0.04, fanPct)))
                        }
                    }
                    .frame(height: 5)
                    .padding(.bottom, 2)
                } else {
                    PopoverKeyValueRow(label: loc("Cooling Architecture"), value: loc("Fanless / Passive"), icon: "wind")
                }
            }
            .padding(.vertical, 2)
            
            // Action Button
            PopoverActionButton(icon: "thermometer.medium", title: loc("Open Activity Monitor (Energy)")) {
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
