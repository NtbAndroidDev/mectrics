import SwiftUI

public struct BatteryPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: monitor.battery.isCharging ? "battery.100percent.bolt" : "battery.100percent")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Battery & Power")
                        .font(.headline)
                    Text(monitor.battery.powerSource)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "%.0f%%", monitor.battery.percentage))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(monitor.battery.percentage <= 20 ? .red : .green)
            }
            
            if !monitor.battery.isPresent {
                SectionCardView(title: "Status", icon: "powerplug") {
                    Text("No internal battery detected. System is running on continuous direct power.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                // Main Gauge & Time Remaining
                HStack(spacing: 16) {
                    GaugeRingView(
                        value: monitor.battery.percentage,
                        label: monitor.battery.isCharging ? "⚡️" : nil,
                        tintColor: monitor.battery.percentage <= 20 ? .red : .green,
                        lineWidth: 7,
                        size: 60
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if let mins = monitor.battery.timeRemainingMinutes {
                            let hours = mins / 60
                            let remainingMins = mins % 60
                            Text(monitor.battery.isCharging ? "Time until full:" : "Remaining:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(hours)h \(remainingMins)m")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        } else {
                            Text(monitor.battery.isPluggedIn ? "Fully Charged / Plugged in" : "Calculating time...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("State: \(monitor.battery.isCharging ? "Charging" : (monitor.battery.isPluggedIn ? "Power Adapter" : "Discharging"))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                
                // Battery Health & Diagnostics
                SectionCardView(title: "Diagnostics & Health", icon: "heart.text.square") {
                    VStack(spacing: 6) {
                        HStack {
                            Text("Health Maximum Capacity:")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.1f%%", monitor.battery.healthPercentage))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("Cycle Count:")
                                .font(.caption)
                            Spacer()
                            Text("\(monitor.battery.cycleCount)")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("Condition:")
                                .font(.caption)
                            Spacer()
                            Text(monitor.battery.condition)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(monitor.battery.condition == "Normal" ? .green : .orange)
                        }
                        if monitor.battery.temperature > 0 {
                            HStack {
                                Text("Temperature:")
                                    .font(.caption)
                                Spacer()
                                Text(String(format: "%.1f°C", monitor.battery.temperature))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}
