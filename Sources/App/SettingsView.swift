import SwiftUI

public struct SettingsView: View {
    @ObservedObject var monitor: SystemMonitor
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Mectrics Preferences")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            
            Divider()
            
            Form {
                Section {
                    Toggle("Use Compact Health Bar (Single Slot)", isOn: $monitor.useCompactHealthBar)
                        .help("Folds the entire machine metrics into a single slot in the menu bar with no noise.")
                } header: {
                    Text("Display Mode")
                }
                
                if !monitor.useCompactHealthBar {
                    Section {
                        Toggle("Show CPU (Value & Sparkline)", isOn: $monitor.showCPUInMenuBar)
                        Toggle("Show Memory (Value & Sparkline)", isOn: $monitor.showMemoryInMenuBar)
                        Toggle("Show Battery", isOn: $monitor.showBatteryInMenuBar)
                        Toggle("Show Network Throughput", isOn: $monitor.showNetworkInMenuBar)
                        Toggle("Show Disk Activity", isOn: $monitor.showDiskInMenuBar)
                        Toggle("Show GPU Utilization", isOn: $monitor.showGPUInMenuBar)
                        Toggle("Show Sensors & Thermals", isOn: $monitor.showSensorInMenuBar)
                    } header: {
                        Text("Individual Menu Bar Items")
                    }
                }
                
                Section {
                    Picker("Sampling Interval", selection: $monitor.updateInterval) {
                        Text("500ms (High precision)").tag(0.5)
                        Text("1.0s (Recommended)").tag(1.0)
                        Text("2.0s (Battery efficient)").tag(2.0)
                        Text("5.0s (Minimal)").tag(5.0)
                    }
                } header: {
                    Text("Performance & Polling")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(.green)
                            Text("Zero Network Requests")
                                .fontWeight(.semibold)
                        }
                        Text("Mectrics uses native Darwin Mach APIs, IOKit, and sysctl locally. It contains no analytics, telemetry, or remote connections.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Privacy & Security")
                }
            }
            .formStyle(.grouped)
            .frame(width: 440, height: 380)
        }
    }
}
