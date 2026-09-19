import Foundation
import IOKit.ps

public final class BatteryMonitor: BatteryMonitoring, @unchecked Sendable {
    public init() {}
    
    public func sample() -> BatteryMetrics {
        var metrics = BatteryMetrics()
        
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            // No battery present (Desktop Mac, VM, etc.)
            metrics.isPresent = false
            metrics.percentage = 100.0
            metrics.isPluggedIn = true
            metrics.powerSource = "AC Power (Desktop)"
            return metrics
        }
        
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            metrics.isPresent = true
            
            if let currentCap = desc[kIOPSCurrentCapacityKey as String] as? Int,
               let maxCap = desc[kIOPSMaxCapacityKey as String] as? Int, maxCap > 0 {
                metrics.percentage = max(0.0, min(100.0, (Double(currentCap) / Double(maxCap)) * 100.0))
            }
            
            if let isCharging = desc[kIOPSIsChargingKey as String] as? Bool {
                metrics.isCharging = isCharging
            }
            
            if let powerSourceState = desc[kIOPSPowerSourceStateKey as String] as? String {
                metrics.isPluggedIn = (powerSourceState == (kIOPSACPowerValue as String))
                metrics.powerSource = metrics.isPluggedIn ? "AC Power" : "Battery"
            }
            
            if let timeToEmpty = desc[kIOPSTimeToEmptyKey as String] as? Int, timeToEmpty > 0 {
                metrics.timeRemainingMinutes = timeToEmpty
            } else if let timeToFull = desc[kIOPSTimeToFullChargeKey as String] as? Int, timeToFull > 0 {
                metrics.timeRemainingMinutes = timeToFull
            } else {
                metrics.timeRemainingMinutes = nil
            }
            
            // Additional IOKit fields
            if let health = desc["BatteryHealth"] as? String {
                metrics.condition = health
            }
            if let cycleCount = desc["CycleCount"] as? Int {
                metrics.cycleCount = cycleCount
            }
            if let temp = desc["Temperature"] as? Double {
                metrics.temperature = temp / 100.0 // IOKit often reports in centi-degrees
            }
            if let designCap = desc["DesignCapacity"] as? Double,
               let rawMax = desc[kIOPSMaxCapacityKey as String] as? Double, designCap > 0 {
                metrics.healthPercentage = max(0.0, min(100.0, (rawMax / designCap) * 100.0))
            }
            
            // Calculate live power draw / wattage
            if let voltage = desc["Voltage"] as? Double ?? (desc["Voltage"] as? Int).map(Double.init),
               let amperage = desc["Amperage"] as? Double ?? (desc["Amperage"] as? Int).map(Double.init) {
                let watts = abs(voltage * amperage) / 1_000_000.0
                metrics.wattage = watts
            }
            
            // Check macOS Low Power Mode
            metrics.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            
            // Break after primary internal battery
            break
        }
        
        // 2. Query AppleSmartBattery via IORegistry (accurate cycle count, mAh capacities & health on Apple Silicon)
        enrichFromAppleSmartBattery(&metrics)
        
        return metrics
    }
    
    private func enrichFromAppleSmartBattery(_ metrics: inout BatteryMetrics) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
              let dict = props?.takeRetainedValue() as? [String: Any] else {
            return
        }
        
        if let cycle = dict["CycleCount"] as? Int, cycle > 0 {
            metrics.cycleCount = cycle
        }
        
        if let maxCycles = dict["DesignCycleCount9C"] as? Int, maxCycles > 0 {
            metrics.maxCycles = maxCycles
        }
        
        if let batteryData = dict["BatteryData"] as? [String: Any] {
            let designCap = (batteryData["DesignCapacity"] as? Int) ?? 0
            let nominalCap = (batteryData["NominalChargeCapacity"] as? Int) ?? 0
            let remainingCap = (batteryData["RemainingCapacity"] as? Int) ?? 0
            let avgTimeToEmpty = batteryData["AvgTimeToEmpty"] as? Int
            
            if designCap > 0 {
                metrics.designCapacityMAh = designCap
            }
            if nominalCap > 0 {
                metrics.nominalCapacityMAh = nominalCap
            }
            if remainingCap > 0 {
                metrics.remainingCapacityMAh = remainingCap
            }
            if designCap > 0 && nominalCap > 0 {
                metrics.healthPercentage = max(0.0, min(100.0, (Double(nominalCap) / Double(designCap)) * 100.0))
            }
            if let avgTime = avgTimeToEmpty, avgTime > 0, metrics.timeRemainingMinutes == nil, !metrics.isCharging {
                metrics.timeRemainingMinutes = avgTime
            }
        }
        
        if let temp = dict["Temperature"] as? Int, temp > 0 {
            // Temperature is often reported in deci-Kelvin or centi-Celsius
            if temp > 1000 {
                metrics.temperature = Double(temp) / 100.0
            } else if temp > 200 {
                metrics.temperature = Double(temp - 2731) / 10.0 // from deci-Kelvin
            }
        }
        
        if let adapterInfo = dict["AdapterInfo"] as? Int, adapterInfo > 0 {
            // Some Macs store charger watts in AdapterDetails or ChargerData
        }
        if let chargerData = dict["ChargerData"] as? [String: Any] {
            if let watts = chargerData["Watts"] as? Int {
                metrics.chargerWatts = watts
            }
        }
    }
}
