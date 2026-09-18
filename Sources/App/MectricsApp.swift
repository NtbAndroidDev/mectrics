import SwiftUI
import AppKit

@main
struct MectricsApp: App {
    @StateObject private var appState = AppState.shared
    
    var body: some Scene {
        // MARK: - 1. Compact Health Item
        MenuBarExtra(isInserted: Binding(
            get: { appState.monitor.useCompactHealthBar },
            set: { appState.monitor.useCompactHealthBar = $0 }
        )) {
            CompactHealthPopoverView(monitor: appState.monitor)
        } label: {
            CompactHealthBarView(
                score: appState.monitor.health.overallScore,
                statusLevel: appState.monitor.health.statusLevel
            )
        }
        .menuBarExtraStyle(.window)
        
        // MARK: - 2. CPU Item
        MenuBarExtra(isInserted: Binding(
            get: { !appState.monitor.useCompactHealthBar && appState.monitor.showCPUInMenuBar },
            set: { appState.monitor.showCPUInMenuBar = $0 }
        )) {
            CPUPopoverView(monitor: appState.monitor)
        } label: {
            MenuBarItemView(
                icon: "cpu",
                valueText: String(format: "%.0f%%", appState.monitor.cpu.totalUsage),
                sparklineValues: appState.monitor.cpuHistory.values,
                tintColor: .blue
            )
        }
        .menuBarExtraStyle(.window)
        
        // MARK: - 3. Memory Item
        MenuBarExtra(isInserted: Binding(
            get: { !appState.monitor.useCompactHealthBar && appState.monitor.showMemoryInMenuBar },
            set: { appState.monitor.showMemoryInMenuBar = $0 }
        )) {
            MemoryPopoverView(monitor: appState.monitor)
        } label: {
            MenuBarItemView(
                icon: "memorychip",
                valueText: String(format: "%.0f%%", appState.monitor.memory.usagePercentage),
                sparklineValues: appState.monitor.memoryHistory.values,
                tintColor: .purple
            )
        }
        .menuBarExtraStyle(.window)
        
        // MARK: - 4. Battery Item
        MenuBarExtra(isInserted: Binding(
            get: { !appState.monitor.useCompactHealthBar && appState.monitor.showBatteryInMenuBar && appState.monitor.battery.isPresent },
            set: { appState.monitor.showBatteryInMenuBar = $0 }
        )) {
            BatteryPopoverView(monitor: appState.monitor)
        } label: {
            MenuBarItemView(
                icon: appState.monitor.battery.isCharging ? "battery.100percent.bolt" : "battery.100percent",
                valueText: String(format: "%.0f%%", appState.monitor.battery.percentage),
                tintColor: appState.monitor.battery.percentage <= 20 ? .red : .green
            )
        }
        .menuBarExtraStyle(.window)
        
        // MARK: - 5. Network Item
        MenuBarExtra(isInserted: Binding(
            get: { !appState.monitor.useCompactHealthBar && appState.monitor.showNetworkInMenuBar },
            set: { appState.monitor.showNetworkInMenuBar = $0 }
        )) {
            NetworkPopoverView(monitor: appState.monitor)
        } label: {
            MenuBarItemView(
                icon: "arrow.up.arrow.down",
                valueText: formatNetRates(down: appState.monitor.network.downloadBytesPerSec, up: appState.monitor.network.uploadBytesPerSec),
                tintColor: .teal
            )
        }
        .menuBarExtraStyle(.window)
        
        // MARK: - 6. Disk Item
        MenuBarExtra(isInserted: Binding(
            get: { !appState.monitor.useCompactHealthBar && appState.monitor.showDiskInMenuBar },
            set: { appState.monitor.showDiskInMenuBar = $0 }
        )) {
            DiskPopoverView(monitor: appState.monitor)
        } label: {
            MenuBarItemView(
                icon: "internaldrive",
                valueText: String(format: "%.0f%%", appState.monitor.disk.usagePercentage),
                tintColor: .cyan
            )
        }
        .menuBarExtraStyle(.window)
        
        // MARK: - 7. GPU Item
        MenuBarExtra(isInserted: Binding(
            get: { !appState.monitor.useCompactHealthBar && appState.monitor.showGPUInMenuBar },
            set: { appState.monitor.showGPUInMenuBar = $0 }
        )) {
            GPUPopoverView(monitor: appState.monitor)
        } label: {
            MenuBarItemView(
                icon: "display",
                valueText: String(format: "%.0f%%", appState.monitor.gpu.usagePercentage),
                sparklineValues: appState.monitor.gpuHistory.values,
                tintColor: .pink
            )
        }
        .menuBarExtraStyle(.window)
        
        // MARK: - 8. Sensor & Fan Item
        MenuBarExtra(isInserted: Binding(
            get: { !appState.monitor.useCompactHealthBar && appState.monitor.showSensorInMenuBar },
            set: { appState.monitor.showSensorInMenuBar = $0 }
        )) {
            SensorPopoverView(monitor: appState.monitor)
        } label: {
            MenuBarItemView(
                icon: "thermometer.medium",
                valueText: formatSensorReading(
                    temp: appState.monitor.sensor.cpuTemperature,
                    fanRPM: appState.monitor.sensor.fans.first?.currentRPM
                ),
                sparklineValues: appState.monitor.tempHistory.values,
                tintColor: .orange
            )
        }
        .menuBarExtraStyle(.window)
    }
    
    private func formatNetRates(down: Double, up: Double) -> String {
        return "↓\(compactBytes(down)) ↑\(compactBytes(up))"
    }
    
    private func compactBytes(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1024 * 1024 {
            return String(format: "%.1fM", bytesPerSec / (1024 * 1024))
        } else if bytesPerSec >= 1024 {
            return String(format: "%.0fK", bytesPerSec / 1024)
        } else {
            return "0K"
        }
    }
    
    private func formatSensorReading(temp: Double, fanRPM: Int?) -> String {
        if let rpm = fanRPM, rpm > 0 {
            return "\(Int(temp))°C \(rpm)R"
        }
        return "\(Int(temp))°C"
    }
}
