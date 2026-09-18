import SwiftUI
import AppKit

public struct SensorPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var showingSettings = false
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            PopoverHeaderView(
                icon: "thermometer.medium",
                title: "Sensors",
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
                PopoverKeyValueRow(label: "CPU Temperature", value: String(format: "%.1f°C", monitor.sensor.cpuTemperature))
                PopoverKeyValueRow(label: "GPU Temperature", value: String(format: "%.1f°C", monitor.sensor.gpuTemperature))
                PopoverKeyValueRow(label: "Thermal Pressure", value: monitor.sensor.thermalPressure.rawValue, isHighlighted: monitor.sensor.thermalPressure != .nominal)
                if let fan = monitor.sensor.fans.first {
                    PopoverKeyValueRow(label: "Cooling Fan", value: "\(fan.currentRPM) RPM")
                } else {
                    PopoverKeyValueRow(label: "Cooling Architecture", value: "Fanless / Passive")
                }
            }
            .padding(.vertical, 2)
            
            // Action Button
            PopoverActionButton(icon: "thermometer.medium", title: "Open Activity Monitor (Energy)") {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
                    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
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
}
