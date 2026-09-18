import Foundation
import Metal
import IOKit

public final class GPUMonitor: @unchecked Sendable {
    private var gpuDevice: MTLDevice?
    
    public init() {
        self.gpuDevice = MTLCreateSystemDefaultDevice()
    }
    
    public func sample() -> GPUMetrics {
        var metrics = GPUMetrics()
        
        if let device = gpuDevice {
            metrics.name = device.name
            metrics.memoryTotalBytes = UInt64(device.recommendedMaxWorkingSetSize)
        }
        
        // Query IOKit IOAccelerator for GPU utilization
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOAccelerator")
        
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess {
            var service = IOIteratorNext(iterator)
            var totalUtilization: Double = 0.0
            var count = 0
            
            while service != 0 {
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                   let dict = props?.takeRetainedValue() as? [String: Any],
                   let perfStats = dict["PerformanceStatistics"] as? [String: Any] {
                    
                    if let util = perfStats["Device Utilization %"] as? Double {
                        totalUtilization += util
                        count += 1
                    } else if let util = perfStats["Device Utilization %"] as? Int {
                        totalUtilization += Double(util)
                        count += 1
                    }
                    
                    if let mem = perfStats["Alloc system memory"] as? UInt64 {
                        metrics.memoryUsedBytes = mem
                    } else if let mem = perfStats["Alloc system memory"] as? Int64 {
                        metrics.memoryUsedBytes = UInt64(max(0, mem))
                    }
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
            
            if count > 0 {
                metrics.usagePercentage = max(0.0, min(100.0, totalUtilization / Double(count)))
            }
        }
        
        return metrics
    }
}
