import SwiftUI

public struct SensorPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "thermometer.medium")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thermals & Fans")
                        .font(.headline)
                    Text("Sensors & Cooling Diagnostics")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "%.1f°C", monitor.sensor.cpuTemperature))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(tempColor(monitor.sensor.cpuTemperature))
            }
            
            // macOS Thermal Pressure State
            SectionCardView(
                title: "macOS Thermal Pressure",
                icon: monitor.sensor.thermalPressure.sfSymbol,
                headerTrailing: AnyView(
                    Text(monitor.sensor.thermalPressure.rawValue)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(thermalStateColor.opacity(0.18))
                        .foregroundStyle(thermalStateColor)
                        .clipShape(Capsule())
                )
            ) {
                Text(thermalExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Temperature Sparkline
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("CPU Core Temp Trend")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Avg: \(String(format: "%.1f°C", monitor.tempHistory.average))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                SparklineView(
                    values: monitor.tempHistory.values,
                    strokeColor: .orange,
                    gradientColors: [.orange.opacity(0.4), .orange.opacity(0.05)],
                    lineWidth: 2,
                    showFill: true,
                    minScale: 30.0,
                    maxScale: 100.0
                )
                .frame(height: 44)
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Fan Speeds
            SectionCardView(title: "Cooling Fans", icon: "fanblades.fill") {
                if monitor.sensor.fans.isEmpty {
                    Text("Passive cooling system (Fanless architecture)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(monitor.sensor.fans) { fan in
                            MetricBarView(
                                label: fan.name,
                                valueText: "\(fan.currentRPM) RPM",
                                progress: fan.maxRPM > 0 ? Double(fan.currentRPM) / Double(fan.maxRPM) : 0,
                                tintColor: fanColor(fan.currentRPM, max: fan.maxRPM),
                                height: 6
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 310)
    }
    
    private var thermalStateColor: Color {
        switch monitor.sensor.thermalPressure {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        }
    }
    
    private var thermalExplanation: String {
        switch monitor.sensor.thermalPressure {
        case .nominal:
            return "Operating within optimal thermal limits. Full performance available."
        case .fair:
            return "Slightly elevated temperatures. System performance maintained."
        case .serious:
            return "High thermal load. macOS is actively modulating background tasks."
        case .critical:
            return "Critical temperature limit. Heavy throttling in progress to prevent overheating."
        }
    }
    
    private func tempColor(_ t: Double) -> Color {
        if t > 85 { return .red }
        if t > 70 { return .orange }
        return .primary
    }
    
    private func fanColor(_ current: Int, max: Int) -> Color {
        let ratio = Double(current) / Double(max)
        if ratio > 0.75 { return .red }
        if ratio > 0.45 { return .orange }
        return .teal
    }
}
