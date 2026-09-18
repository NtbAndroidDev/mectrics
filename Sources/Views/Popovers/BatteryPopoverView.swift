import SwiftUI
import AppKit

public struct BatteryPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            PopoverHeaderView(
                icon: monitor.battery.isCharging ? "battery.100percent.bolt" : "battery.100percent",
                title: loc("Battery"),
                rightText: String(format: "%.0f%%", monitor.battery.percentage),
                ringProgress: monitor.battery.percentage / 100.0
            )
            
            // Key-Value List
            VStack(spacing: 2) {
                PopoverKeyValueRow(
                    label: loc("Power Source"),
                    value: monitor.battery.powerSource
                )
                PopoverKeyValueRow(
                    label: loc("State"),
                    value: monitor.battery.isCharging ? loc("Charging") : (monitor.battery.isPluggedIn ? loc("Plugged In") : loc("Discharging"))
                )
                if let mins = monitor.battery.timeRemainingMinutes {
                    PopoverKeyValueRow(
                        label: monitor.battery.isCharging ? loc("Time to Full") : loc("Time Remaining"),
                        value: "\(mins / 60)h \(mins % 60)m"
                    )
                }
                PopoverKeyValueRow(
                    label: loc("Health Capacity"),
                    value: String(format: "%.1f%%", monitor.battery.healthPercentage)
                )
                PopoverKeyValueRow(
                    label: loc("Cycle Count"),
                    value: "\(monitor.battery.cycleCount)"
                )
                PopoverKeyValueRow(
                    label: loc("Condition"),
                    value: monitor.battery.condition
                )
            }
            .padding(.vertical, 2)
            
            // Action Button
            PopoverActionButton(icon: "battery.100percent", title: loc("Open Battery Settings")) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") {
                    NSWorkspace.shared.open(url)
                } else if let url = URL(string: "x-apple.systempreferences:") {
                    NSWorkspace.shared.open(url)
                }
            }
            
            // Footer
            PopoverFooterView()
        }
        .mectricsPopoverStyle()
    }
}
