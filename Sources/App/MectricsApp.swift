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
        
        // MARK: - 2. Disk Item
        MenuBarExtra(isInserted: Binding(
            get: { !appState.monitor.useCompactHealthBar && appState.monitor.showDiskInMenuBar },
            set: { appState.monitor.showDiskInMenuBar = $0 }
        )) {
            DiskPopoverView(monitor: appState.monitor)
        } label: {
            let diskText = (appState.monitor.diskDisplayMode == .percentage)
                ? String(format: "%.0f%%", appState.monitor.disk.usagePercentage)
                : "\(appState.monitor.disk.freeBytes / (1024 * 1024 * 1024))GB"
            MenuBarItemView(
                icon: "internaldrive",
                valueText: diskText,
                tintColor: MectricsTheme.coral
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
                sparklineValues: appState.monitor.showMemorySparkline ? appState.monitor.memoryHistory.values : nil,
                isBoxedSparkline: true,
                tintColor: MectricsTheme.coral
            )
        }
        .menuBarExtraStyle(.window)
        
        // MARK: - 4. CPU Item
        MenuBarExtra(isInserted: Binding(
            get: { !appState.monitor.useCompactHealthBar && appState.monitor.showCPUInMenuBar },
            set: { appState.monitor.showCPUInMenuBar = $0 }
        )) {
            CPUPopoverView(monitor: appState.monitor)
        } label: {
            MenuBarItemView(
                icon: "cpu",
                valueText: String(format: "%.0f%%", appState.monitor.cpu.totalUsage),
                sparklineValues: appState.monitor.showCPUSparkline ? appState.monitor.cpuHistory.values : nil,
                isBoxedSparkline: false,
                tintColor: MectricsTheme.coral
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
            if appState.monitor.networkDisplayMode == .stacked {
                NetworkMenuBarView(
                    downloadBytes: appState.monitor.network.downloadBytesPerSec,
                    uploadBytes: appState.monitor.network.uploadBytesPerSec,
                    tintColor: MectricsTheme.coral
                )
            } else {
                let totalRate = appState.monitor.network.downloadBytesPerSec + appState.monitor.network.uploadBytesPerSec
                MenuBarItemView(
                    icon: "arrow.up.arrow.down",
                    valueText: formatSingleRate(totalRate),
                    tintColor: MectricsTheme.coral
                )
            }
        }
        .menuBarExtraStyle(.window)
        
        // MARK: - 6. Battery Item
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
                tintColor: MectricsTheme.coral
            )
        }
        .menuBarExtraStyle(.window)
        
        // MARK: - 8. Sensor Item
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
    
    private func formatSingleRate(_ bytes: Double) -> String {
        if bytes >= 1024 * 1024 {
            return String(format: "%.1fM/s", bytes / (1024 * 1024))
        } else if bytes >= 1024 {
            return String(format: "%.0fK/s", bytes / 1024)
        } else {
            return "0K/s"
        }
    }
}
