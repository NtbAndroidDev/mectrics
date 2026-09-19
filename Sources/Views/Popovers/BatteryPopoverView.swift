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
            
            // Visual Battery Bar
            GeometryReader { geo in
                let pct = max(0.04, min(1.0, monitor.battery.percentage / 100.0))
                let fillColor: Color = monitor.battery.isCharging ? Color(red: 0.20, green: 0.85, blue: 0.65) :
                    (monitor.battery.percentage <= 20 ? MectricsTheme.coral :
                    (monitor.battery.percentage <= 40 ? Color.orange : Color(red: 0.20, green: 0.80, blue: 0.50)))
                
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(white: 0.18))
                    
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [fillColor, fillColor.opacity(0.82)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(pct))
                }
            }
            .frame(height: 12)
            .padding(.vertical, 2)
            
            // Key-Value List
            VStack(spacing: 2) {
                PopoverKeyValueRow(
                    label: loc("Power Source"),
                    value: monitor.battery.powerSource,
                    icon: "bolt.fill"
                )
                PopoverKeyValueRow(
                    label: loc("State"),
                    value: monitor.battery.isCharging ? loc("Charging") : (monitor.battery.isPluggedIn ? loc("Plugged In") : loc("Discharging")),
                    icon: monitor.battery.isCharging ? "bolt.badge.automatic" : (monitor.battery.isPluggedIn ? "powerplug.fill" : "battery.100percent")
                )
                if let mins = monitor.battery.timeRemainingMinutes {
                    PopoverKeyValueRow(
                        label: monitor.battery.isCharging ? loc("Time to Full") : loc("Time Remaining"),
                        value: "\(mins / 60)h \(mins % 60)m",
                        icon: "clock.fill"
                    )
                }
                if monitor.battery.wattage > 0.05 {
                    PopoverKeyValueRow(
                        label: loc("Power Draw"),
                        value: String(format: "%.1f W", monitor.battery.wattage),
                        icon: "bolt.badge.clock.fill"
                    )
                }
                if let charger = monitor.battery.chargerWatts, charger > 0 {
                    PopoverKeyValueRow(
                        label: loc("Charger Power"),
                        value: "\(charger) W",
                        icon: "powerplug.fill"
                    )
                }
                PopoverKeyValueRow(
                    label: loc("Low Power Mode"),
                    value: monitor.battery.isLowPowerMode ? loc("Enabled") : loc("Disabled"),
                    icon: "leaf.fill",
                    isHighlighted: monitor.battery.isLowPowerMode
                )
                PopoverKeyValueRow(
                    label: loc("Health Capacity"),
                    value: String(format: "%.1f%%", monitor.battery.healthPercentage),
                    icon: "heart.fill"
                )
                if monitor.battery.nominalCapacityMAh > 0 && monitor.battery.designCapacityMAh > 0 {
                    PopoverKeyValueRow(
                        label: loc("Full Charge Capacity"),
                        value: "\(monitor.battery.nominalCapacityMAh) mAh",
                        icon: "battery.100percent"
                    )
                    PopoverKeyValueRow(
                        label: loc("Design Capacity"),
                        value: "\(monitor.battery.designCapacityMAh) mAh",
                        icon: "slider.horizontal.3"
                    )
                }
                PopoverKeyValueRow(
                    label: loc("Cycle Count"),
                    value: monitor.battery.cycleCount > 0 ? "\(monitor.battery.cycleCount) / \(monitor.battery.maxCycles)" : "\(monitor.battery.cycleCount)",
                    icon: "arrow.clockwise.circle.fill"
                )
                PopoverKeyValueRow(
                    label: loc("Temperature"),
                    value: String(format: "%.1f°C", monitor.battery.temperature),
                    icon: "thermometer.medium"
                )
                PopoverKeyValueRow(
                    label: loc("Condition"),
                    value: monitor.battery.condition,
                    icon: "checkmark.seal.fill"
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
