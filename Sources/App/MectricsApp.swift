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
            CompactHealthBarView(statusLevel: appState.monitor.health.statusLevel)
        }
        .menuBarExtraStyle(.window)
        
        // MARK: - 2. Disk Item (e.g. "59GB")
        MenuBarExtra(isInserted: Binding(
            get: { !appState.monitor.useCompactHealthBar && appState.monitor.showDiskInMenuBar },
            set: { appState.monitor.showDiskInMenuBar = $0 }
        )) {
            DiskPopoverView(monitor: appState.monitor)
        } label: {
            MenuBarItemView(
                icon: "internaldrive",
                valueText: "\(appState.monitor.disk.freeBytes / (1024 * 1024 * 1024))GB",
                tintColor: MectricsTheme.coral
            )
        }
        .menuBarExtraStyle(.window)
        
        // MARK: - 3. Memory Item (e.g. "72%" + boxed sparkline)
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
                isBoxedSparkline: true,
                tintColor: MectricsTheme.coral
            )
        }
        .menuBarExtraStyle(.window)
        
        // MARK: - 4. CPU Item (e.g. "26%" + live sparkline waveform)
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
                isBoxedSparkline: false,
                tintColor: MectricsTheme.coral
            )
        }
        .menuBarExtraStyle(.window)
        
        // MARK: - 5. Network Item (e.g. "↓4.1K / ↑6.2K")
        MenuBarExtra(isInserted: Binding(
            get: { !appState.monitor.useCompactHealthBar && appState.monitor.showNetworkInMenuBar },
            set: { appState.monitor.showNetworkInMenuBar = $0 }
        )) {
            NetworkPopoverView(monitor: appState.monitor)
        } label: {
            NetworkMenuBarView(
                downloadBytes: appState.monitor.network.downloadBytesPerSec,
                uploadBytes: appState.monitor.network.uploadBytesPerSec,
                tintColor: MectricsTheme.coral
            )
        }
        .menuBarExtraStyle(.window)
        
        // MARK: - 6. Battery Item (Optional)
        MenuBarExtra(isInserted: Binding(
            get: { !appState.monitor.useCompactHealthBar && appState.monitor.showBatteryInMenuBar && appState.monitor.battery.isPresent },
            set: { appState.monitor.showBatteryInMenuBar = $0 }
        )) {
            BatteryPopoverView(monitor: appState.monitor)
        } label: {
            MenuBarItemView(
                icon: appState.monitor.battery.isCharging ? "battery.100percent.bolt" : "battery.100percent",
                valueText: String(format: "%.0f%%", appState.monitor.battery.percentage),
                tintColor: MectricsTheme.coral
            )
        }
        .menuBarExtraStyle(.window)
        
        // MARK: - 7. GPU Item (Optional)
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
                tintColor: MectricsTheme.coral
            )
        }
        .menuBarExtraStyle(.window)
        
        // MARK: - 8. Sensor Item (Optional)
        MenuBarExtra(isInserted: Binding(
            get: { !appState.monitor.useCompactHealthBar && appState.monitor.showSensorInMenuBar },
            set: { appState.monitor.showSensorInMenuBar = $0 }
        )) {
            SensorPopoverView(monitor: appState.monitor)
        } label: {
            MenuBarItemView(
                icon: "thermometer.medium",
                valueText: "\(Int(appState.monitor.sensor.cpuTemperature))°C",
                sparklineValues: appState.monitor.tempHistory.values,
                tintColor: MectricsTheme.coral
            )
        }
        .menuBarExtraStyle(.window)
    }
}
