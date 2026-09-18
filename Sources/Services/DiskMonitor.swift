import Foundation
import Darwin

public final class DiskMonitor: @unchecked Sendable {
    private var previousReadBytes: UInt64 = 0
    private var previousWriteBytes: UInt64 = 0
    private var previousTimestamp: Date = Date()
    private var isFirstSample = true
    private let lock = NSLock()
    
    public init() {}
    
    public func sample() -> DiskMetrics {
        lock.lock()
        defer { lock.unlock() }
        
        var metrics = DiskMetrics()
        
        // 1. Capacity & Free Space via FileManager
        do {
            let rootURL = URL(fileURLWithPath: "/")
            let values = try rootURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeNameKey
            ])
            
            let total = UInt64(values.volumeTotalCapacity ?? 0)
            let free = UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
            let used = total >= free ? (total - free) : 0
            
            metrics.totalBytes = total
            metrics.freeBytes = free
            metrics.usedBytes = used
            metrics.volumeName = values.volumeName ?? "Macintosh HD"
            
            if total > 0 {
                metrics.usagePercentage = max(0.0, min(100.0, (Double(used) / Double(total)) * 100.0))
            }
        } catch {
            // Fallback via statvfs
            var stat = statvfs()
            if statvfs("/", &stat) == 0 {
                let blockSize = UInt64(stat.f_frsize)
                let total = UInt64(stat.f_blocks) * blockSize
                let free = UInt64(stat.f_bavail) * blockSize
                metrics.totalBytes = total
                metrics.freeBytes = free
                metrics.usedBytes = total >= free ? (total - free) : 0
                if total > 0 {
                    metrics.usagePercentage = (Double(metrics.usedBytes) / Double(total)) * 100.0
                }
            }
        }
        
        // 2. Disk I/O Throughput via IOKit (IOBlockStorageDriver)
        let (currentRead, currentWrite) = readDiskIOStats()
        let now = Date()
        let elapsed = max(0.1, now.timeIntervalSince(previousTimestamp))
        
        if !isFirstSample {
            let rDiff = currentRead >= previousReadBytes ? (currentRead - previousReadBytes) : 0
            let wDiff = currentWrite >= previousWriteBytes ? (currentWrite - previousWriteBytes) : 0
            
            metrics.readBytesPerSec = Double(rDiff) / elapsed
            metrics.writeBytesPerSec = Double(wDiff) / elapsed
        } else {
            isFirstSample = false
            metrics.readBytesPerSec = 0
            metrics.writeBytesPerSec = 0
        }
        
        previousReadBytes = currentRead
        previousWriteBytes = currentWrite
        previousTimestamp = now
        
        return metrics
    }
    
    private func readDiskIOStats() -> (UInt64, UInt64) {
        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0
        
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOBlockStorageDriver")
        
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess {
            var service = IOIteratorNext(iterator)
            while service != 0 {
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                   let dict = props?.takeRetainedValue() as? [String: Any],
                   let stats = dict["Statistics"] as? [String: Any] {
                    if let r = stats["Bytes (Read)"] as? UInt64 {
                        totalRead += r
                    } else if let r = stats["Bytes (Read)"] as? Int64 {
                        totalRead += UInt64(max(0, r))
                    }
                    
                    if let w = stats["Bytes (Write)"] as? UInt64 {
                        totalWrite += w
                    } else if let w = stats["Bytes (Write)"] as? Int64 {
                        totalWrite += UInt64(max(0, w))
                    }
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }
        
        return (totalRead, totalWrite)
    }
}
