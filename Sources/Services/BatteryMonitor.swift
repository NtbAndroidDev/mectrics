import Foundation
import IOKit.ps

public final class BatteryMonitor: @unchecked Sendable {
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
            
            // Break after primary internal battery
            break
        }
        
        return metrics
    }
}
