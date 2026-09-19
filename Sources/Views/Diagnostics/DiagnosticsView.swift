import SwiftUI
import AppKit

public struct DiagnosticsView: View {
    @ObservedObject var monitor: SystemMonitor = SystemMonitor.shared
    @State private var copied: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(MectricsTheme.coral)
                    Text(loc("System Diagnostics"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                Button {
                    copyDiagnosticsToClipboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        Text(copied ? loc("Copied!") : loc("Copy Diagnostics"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MectricsTheme.coral.opacity(0.18))
                    .foregroundStyle(copied ? Color.green : MectricsTheme.coral)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(MectricsTheme.coral.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                Button {
                    exportReportToFile()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 11))
                        Text(loc("Export..."))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(white: 0.13))
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // System & OS Info
                    diagnosticsSection(title: loc("Hardware & Operating System"), icon: "laptopcomputer") {
                        diagRow(label: loc("Model Identifier"), value: getSysctl("hw.model") ?? "Mac")
                        diagRow(label: loc("macOS Version"), value: ProcessInfo.processInfo.operatingSystemVersionString)
                        diagRow(label: loc("Kernel Version"), value: getSysctl("kern.osrelease") ?? "Darwin")
                        diagRow(label: loc("System Uptime"), value: formatUptime(ProcessInfo.processInfo.systemUptime))
                        diagRow(label: loc("Privacy Status"), value: loc("100% Offline / Zero Telemetry"))
                    }
                    
                    // Processor (CPU)
                    diagnosticsSection(title: loc("Processor (CPU)"), icon: "cpu") {
                        diagRow(label: loc("Chip"), value: getSysctlString("machdep.cpu.brand_string") ?? "Apple Silicon")
                        diagRow(label: loc("Cores Count"), value: "\(ProcessInfo.processInfo.activeProcessorCount) Cores (\(monitor.cpu.logicalCores) Logical)")
                        diagRow(label: loc("Current Total Usage"), value: String(format: "%.1f%%", monitor.cpu.totalUsage))
                        diagRow(label: loc("Load Average"), value: String(format: "%.2f, %.2f, %.2f", monitor.cpu.loadAverages.one, monitor.cpu.loadAverages.five, monitor.cpu.loadAverages.fifteen))
                    }
                    
                    // Memory (RAM)
                    diagnosticsSection(title: loc("Memory (RAM)"), icon: "memorychip") {
                        let totalGB = Double(monitor.memory.totalBytes) / (1024 * 1024 * 1024)
                        let usedGB = Double(monitor.memory.usedBytes) / (1024 * 1024 * 1024)
                        diagRow(label: loc("Physical Memory"), value: String(format: "%.1f GB (%.1f GB Used)", totalGB, usedGB))
                        diagRow(label: loc("RAM Utilization"), value: String(format: "%.1f%%", monitor.memory.usagePercentage))
                        diagRow(label: loc("Memory Pressure"), value: monitor.memory.pressureLevel.rawValue)
                    }
                    
                    // Power & Battery
                    diagnosticsSection(title: loc("Battery & Power"), icon: "battery.100percent") {
                        if monitor.battery.isPresent {
                            diagRow(label: loc("Battery Charge"), value: String(format: "%.0f%% (%@)", monitor.battery.percentage, monitor.battery.isCharging ? loc("Charging") : loc("Discharging")))
                            diagRow(label: loc("Cycle Count"), value: "\(monitor.battery.cycleCount) Cycles")
                            diagRow(label: loc("Maximum Capacity"), value: "\(monitor.battery.healthPercentage)%")
                            diagRow(label: loc("Power Draw"), value: String(format: "%.2f W", monitor.battery.wattage))
                            diagRow(label: loc("Power Source"), value: monitor.battery.isCharging ? "AC Adapter" : "Battery")
                            diagRow(label: loc("Low Power Mode"), value: monitor.battery.isLowPowerMode ? loc("Enabled") : loc("Disabled"))
                        } else {
                            diagRow(label: loc("Power Architecture"), value: loc("Direct AC Power (Desktop Mac)"))
                        }
                    }
                    
                    // Storage
                    diagnosticsSection(title: loc("Storage Volume"), icon: "internaldrive") {
                        let totalGB = monitor.disk.totalBytes / (1024 * 1024 * 1024)
                        let freeGB = monitor.disk.freeBytes / (1024 * 1024 * 1024)
                        let usedGB = monitor.disk.usedBytes / (1024 * 1024 * 1024)
                        diagRow(label: loc("Volume Path"), value: "/")
                        diagRow(label: loc("Capacity"), value: "\(totalGB) GB Total")
                        diagRow(label: loc("Space Breakdown"), value: "\(usedGB) GB Used · \(freeGB) GB Available")
                        diagRow(label: loc("Disk Utilization"), value: String(format: "%.1f%%", monitor.disk.usagePercentage))
                    }
                    
                    // Thermals & Cooling
                    diagnosticsSection(title: loc("Thermals & Cooling"), icon: "thermometer.medium") {
                        diagRow(label: loc("CPU Thermal Zone"), value: monitor.formatTemperaturePrecise(monitor.sensor.cpuTemperature))
                        diagRow(label: loc("GPU Thermal Zone"), value: monitor.formatTemperaturePrecise(monitor.sensor.gpuTemperature))
                        diagRow(label: loc("macOS Thermal Pressure"), value: monitor.sensor.thermalPressure.rawValue)
                        if !monitor.sensor.fans.isEmpty {
                            ForEach(monitor.sensor.fans) { fan in
                                diagRow(label: fan.name, value: "\(fan.currentRPM) RPM (Min: \(fan.minRPM) · Max: \(fan.maxRPM))")
                            }
                        } else {
                            diagRow(label: loc("Cooling Type"), value: loc("Passive Fanless Architecture"))
                        }
                    }
                    
                    // Network Connectivity
                    diagnosticsSection(title: loc("Network Interfaces"), icon: "network") {
                        diagRow(label: loc("Current Download"), value: formatBytes(monitor.network.downloadBytesPerSec) + "/s")
                        diagRow(label: loc("Current Upload"), value: formatBytes(monitor.network.uploadBytesPerSec) + "/s")
                        if let ping = monitor.network.pingLatencyMs, ping > 0 {
                            diagRow(label: loc("DNS Ping Latency"), value: String(format: "%.1f ms (1.1.1.1:53)", ping))
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 580, height: 620)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .preferredColorScheme(.dark)
    }
    
    private func diagnosticsSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MectricsTheme.coral)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            VStack(spacing: 2) {
                content()
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private func diagRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(MectricsTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.vertical, 2.5)
    }
    
    private func generateDiagnosticsReport() -> String {
        var lines: [String] = []
        lines.append("==================================================")
        lines.append("MECTRICS SYSTEM DIAGNOSTICS REPORT")
        lines.append("Generated: \(Date().formatted(date: .abbreviated, time: .standard))")
        lines.append("Telemetry: None (100% Offline and Private)")
        lines.append("==================================================\n")
        
        lines.append("[HARDWARE & SYSTEM]")
        lines.append("Model: \(getSysctl("hw.model") ?? "Mac")")
        lines.append("OS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        lines.append("Kernel: \(getSysctl("kern.osrelease") ?? "Darwin")")
        lines.append("Uptime: \(formatUptime(ProcessInfo.processInfo.systemUptime))\n")
        
        lines.append("[PROCESSOR (CPU)]")
        lines.append("Chip: \(getSysctlString("machdep.cpu.brand_string") ?? "Apple Silicon")")
        lines.append("Cores: \(ProcessInfo.processInfo.activeProcessorCount) Cores (\(monitor.cpu.logicalCores) Logical)")
        lines.append("Load Avg: \(String(format: "%.2f, %.2f, %.2f", monitor.cpu.loadAverages.one, monitor.cpu.loadAverages.five, monitor.cpu.loadAverages.fifteen))")
        lines.append("Current Usage: \(String(format: "%.1f%%", monitor.cpu.totalUsage))\n")
        
        lines.append("[MEMORY (RAM)]")
        let totalGB = Double(monitor.memory.totalBytes) / (1024 * 1024 * 1024)
        let usedGB = Double(monitor.memory.usedBytes) / (1024 * 1024 * 1024)
        lines.append("RAM Total: \(String(format: "%.1f GB", totalGB)) (Used: \(String(format: "%.1f GB", usedGB)))")
        lines.append("RAM Utilization: \(String(format: "%.1f%%", monitor.memory.usagePercentage))")
        lines.append("Pressure Level: \(monitor.memory.pressureLevel.rawValue)\n")
        
        lines.append("[STORAGE]")
        let dTotal = monitor.disk.totalBytes / (1024 * 1024 * 1024)
        let dFree = monitor.disk.freeBytes / (1024 * 1024 * 1024)
        lines.append("Main Drive: \(dTotal) GB Total (\(dFree) GB Free, \(String(format: "%.1f%%", monitor.disk.usagePercentage)) Used)\n")
        
        lines.append("[THERMALS & COOLING]")
        lines.append("CPU Temperature: \(String(format: "%.1f°C", monitor.sensor.cpuTemperature))")
        lines.append("GPU Temperature: \(String(format: "%.1f°C", monitor.sensor.gpuTemperature))")
        lines.append("Thermal Pressure: \(monitor.sensor.thermalPressure.rawValue)")
        if !monitor.sensor.fans.isEmpty {
            for fan in monitor.sensor.fans {
                lines.append("Fan: \(fan.name) - \(fan.currentRPM) RPM (Min: \(fan.minRPM), Max: \(fan.maxRPM))")
            }
        } else {
            lines.append("Cooling: Fanless Architecture")
        }
        lines.append("\n[BATTERY & POWER]")
        if monitor.battery.isPresent {
            lines.append("Battery Charge: \(String(format: "%.0f%%", monitor.battery.percentage)) (Cycle count: \(monitor.battery.cycleCount), Health: \(monitor.battery.healthPercentage)%)")
            lines.append("Power Draw: \(String(format: "%.2f W", monitor.battery.wattage))")
            lines.append("Power Source: \(monitor.battery.isCharging ? "AC Adapter" : "Battery")")
        } else {
            lines.append("Power Source: Direct AC Power (Desktop Mac)")
        }
        lines.append("\n==================================================")
        return lines.joined(separator: "\n")
    }
    
    private func copyDiagnosticsToClipboard() {
        let text = generateDiagnosticsReport()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { copied = false }
        }
    }
    
    private func exportReportToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Mectrics_Diagnostics_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).txt"
        if panel.runModal() == .OK, let url = panel.url {
            let report = generateDiagnosticsReport()
            try? report.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private func getSysctl(_ name: String) -> String? {
        var size: Int = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buffer, &size, nil, 0)
        return buffer.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return nil }
            return String(cString: base)
        }
    }
    
    private func getSysctlString(_ name: String) -> String? {
        return getSysctl(name)
    }
    
    private func formatUptime(_ seconds: TimeInterval) -> String {
        let d = Int(seconds) / 86400
        let h = (Int(seconds) % 86400) / 3600
        let m = (Int(seconds) % 3600) / 60
        if d > 0 {
            return "\(d)d \(h)h \(m)m"
        } else {
            return "\(h)h \(m)m"
        }
    }
    
    private func formatBytes(_ bytes: Double) -> String {
        if bytes >= 1024 * 1024 {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        } else if bytes >= 1024 {
            return String(format: "%.0f KB", bytes / 1024)
        } else {
            return "0 KB"
        }
    }
}
