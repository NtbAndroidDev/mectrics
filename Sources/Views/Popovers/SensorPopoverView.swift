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
                PopoverKeyValueRow(label: loc("CPU Temperature"), value: String(format: "%.1f°C", monitor.sensor.cpuTemperature))
                PopoverKeyValueRow(label: loc("GPU Temperature"), value: String(format: "%.1f°C", monitor.sensor.gpuTemperature))
                PopoverKeyValueRow(label: loc("Thermal Pressure"), value: monitor.sensor.thermalPressure.rawValue, isHighlighted: monitor.sensor.thermalPressure != .nominal)
                if let fan = monitor.sensor.fans.first {
                    PopoverKeyValueRow(label: loc("Cooling Fan"), value: "\(fan.currentRPM) RPM")
                } else {
                    PopoverKeyValueRow(label: loc("Cooling Architecture"), value: loc("Fanless / Passive"))
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
