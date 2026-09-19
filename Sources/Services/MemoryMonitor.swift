import Foundation
import Darwin

public final class MemoryMonitor: MemoryMonitoring, @unchecked Sendable {
    private let pageSize: UInt64
    private let totalMemory: UInt64
    
    public init() {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        self.totalMemory = size > 0 ? size : 16 * 1024 * 1024 * 1024
        
        var pSize: vm_size_t = 0
        let initPort = mach_host_self()
        _ = host_page_size(initPort, &pSize)
        mach_port_deallocate(mach_task_self_, initPort)
        self.pageSize = UInt64(pSize > 0 ? pSize : 4096)
    }
    
    public func sample() -> MemoryMetrics {
        var metrics = MemoryMetrics()
        metrics.totalBytes = totalMemory
        
        let hostPort = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, hostPort) }
        
        var vmStat = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let active = UInt64(vmStat.active_count) * pageSize
            let wired = UInt64(vmStat.wire_count) * pageSize
            let compressed = UInt64(vmStat.compressor_page_count) * pageSize
            let free = UInt64(vmStat.free_count) * pageSize
            let purgeable = UInt64(vmStat.purgeable_count) * pageSize
            let inactive = UInt64(vmStat.inactive_count) * pageSize
            
            let used = active + wired + compressed
            let cached = inactive + purgeable
            
            metrics.activeBytes = active
            metrics.wiredBytes = wired
            metrics.compressedBytes = compressed
            metrics.freeBytes = free
            metrics.cachedBytes = cached
            metrics.usedBytes = min(used, totalMemory)
            
            if totalMemory > 0 {
                metrics.usagePercentage = max(0.0, min(100.0, (Double(metrics.usedBytes) / Double(totalMemory)) * 100.0))
            }
        }
        
        // Swap usage via sysctl
        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0 {
            metrics.swapUsedBytes = UInt64(swap.xsu_used)
            metrics.swapTotalBytes = UInt64(swap.xsu_total)
        }
        
        // Pressure evaluation
        if metrics.usagePercentage > 88.0 || metrics.swapUsedBytes > 1024 * 1024 * 1024 {
            metrics.pressureLevel = .critical
        } else if metrics.usagePercentage > 75.0 {
            metrics.pressureLevel = .warning
        } else {
            metrics.pressureLevel = .normal
        }
        
        return metrics
    }
}
