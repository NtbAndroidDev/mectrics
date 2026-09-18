import SwiftUI

public struct CompactHealthPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var showingRulesSheet = false
    @State private var showingSettingsSheet = false
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Health Ring & Status
            HStack(spacing: 16) {
                GaugeRingView(
                    value: Double(monitor.health.overallScore),
                    label: "Score",
                    tintColor: scoreColor,
                    lineWidth: 7,
                    size: 68
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Machine Health")
                        .font(.headline)
                    
                    Text(monitor.health.statusSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(scoreColor)
                            .frame(width: 7, height: 7)
                        Text(scoreDescription)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(scoreColor)
                    }
                }
                Spacer()
            }
            
            // Active Alerts Banner (from Rules Engine)
            if !monitor.rulesEngine.activeAlerts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundStyle(.red)
                        Text("Active Alert Triggers")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                    }
                    ForEach(monitor.rulesEngine.activeAlerts, id: \.self) { alert in
                        Text("• \(alert)")
                            .font(.caption2)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Grid of Essential Metrics
            SectionCardView(title: "Overview At A Glance", icon: "sparkles") {
                let columns = [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ]
                LazyVGrid(columns: columns, spacing: 8) {
                    miniCard(
                        title: "CPU",
                        value: String(format: "%.0f%%", monitor.cpu.totalUsage),
                        subvalue: String(format: "%.0f°C", monitor.sensor.cpuTemperature),
                        icon: "cpu",
                        color: .blue
                    )
                    miniCard(
                        title: "Memory",
                        value: String(format: "%.0f%%", monitor.memory.usagePercentage),
                        subvalue: monitor.memory.pressureLevel.rawValue,
                        icon: "memorychip",
                        color: .purple
                    )
                    miniCard(
                        title: "Disk Space",
                        value: String(format: "%.0f%%", monitor.disk.usagePercentage),
                        subvalue: "\(monitor.disk.freeBytes / (1024*1024*1024)) GB free",
                        icon: "internaldrive",
                        color: .cyan
                    )
                    miniCard(
                        title: "Thermals",
                        value: monitor.sensor.thermalPressure.rawValue,
                        subvalue: "\(monitor.sensor.fans.first?.currentRPM ?? 0) RPM",
                        icon: monitor.sensor.thermalPressure.sfSymbol,
                        color: .orange
                    )
                }
            }
            
            // Bottom Action Bar
            Divider()
            
            HStack {
                Button {
                    showingRulesSheet = true
                } label: {
                    Label("Rules", systemImage: "bell.badge")
                }
                .buttonStyle(.plain)
                .font(.caption)
                
                Spacer()
                
                Button {
                    showingSettingsSheet = true
                } label: {
                    Label("Preferences", systemImage: "gearshape")
                }
                .buttonStyle(.plain)
                .font(.caption)
                
                Spacer()
                
                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("Quit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 320)
        .sheet(isPresented: $showingRulesSheet) {
            RulesManagerView(rulesEngine: monitor.rulesEngine)
        }
        .sheet(isPresented: $showingSettingsSheet) {
            SettingsView(monitor: monitor)
        }
    }
    
    private func miniCard(title: String, value: String, subvalue: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text(subvalue)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private var scoreColor: Color {
        switch monitor.health.statusLevel {
        case .good: return .green
        case .elevated: return .orange
        case .alert: return .red
        }
    }
    
    private var scoreDescription: String {
        switch monitor.health.statusLevel {
        case .good: return "Optimal"
        case .elevated: return "Attention Needed"
        case .alert: return "High Load / Pressure"
        }
    }
}
