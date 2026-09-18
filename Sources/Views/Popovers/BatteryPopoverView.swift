import SwiftUI
import AppKit

public struct BatteryPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var showingSettings = false
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            PopoverHeaderView(
                icon: monitor.battery.isCharging ? "battery.100percent.bolt" : "battery.100percent",
                title: "Battery",
                rightText: String(format: "%.0f%%", monitor.battery.percentage),
                ringProgress: monitor.battery.percentage / 100.0
            )
            
            // Key-Value List
            VStack(spacing: 2) {
                PopoverKeyValueRow(
                    label: "Power Source",
                    value: monitor.battery.powerSource
                )
                PopoverKeyValueRow(
                    label: "State",
                    value: monitor.battery.isCharging ? "Charging" : (monitor.battery.isPluggedIn ? "Plugged In" : "Discharging")
                )
                if let mins = monitor.battery.timeRemainingMinutes {
                    PopoverKeyValueRow(
                        label: monitor.battery.isCharging ? "Time to Full" : "Time Remaining",
                        value: "\(mins / 60)h \(mins % 60)m"
                    )
                }
                PopoverKeyValueRow(
                    label: "Health Capacity",
                    value: String(format: "%.1f%%", monitor.battery.healthPercentage)
                )
                PopoverKeyValueRow(
                    label: "Cycle Count",
                    value: "\(monitor.battery.cycleCount)"
                )
                PopoverKeyValueRow(
                    label: "Condition",
                    value: monitor.battery.condition
                )
            }
            .padding(.vertical, 2)
            
            // Action Button
            PopoverActionButton(icon: "battery.100percent", title: "Open Battery Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") {
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
}
