import Foundation
import Darwin

public final class CPUMonitor: @unchecked Sendable {
    private var previousPerCoreTicks: [[UInt32]] = []
    private var previousCpuLoad: host_cpu_load_info = host_cpu_load_info()
    private var hasPreviousLoad = false
    private let lock = NSLock()
    
    public init() {}
    
    public func sample() -> CPUMetrics {
        lock.lock()
        defer { lock.unlock() }
        
        var metrics = CPUMetrics()
        metrics.physicalCores = ProcessInfo.processInfo.activeProcessorCount
        metrics.logicalCores = ProcessInfo.processInfo.processorCount
        metrics.modelName = getCPUBrandString()
        
        // 1. Overall CPU Load via host_statistics
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuLoad = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            if hasPreviousLoad {
                let userDiff = Double(cpuLoad.cpu_ticks.0 - previousCpuLoad.cpu_ticks.0)
                let sysDiff  = Double(cpuLoad.cpu_ticks.1 - previousCpuLoad.cpu_ticks.1)
                let idleDiff = Double(cpuLoad.cpu_ticks.2 - previousCpuLoad.cpu_ticks.2)
                let niceDiff = Double(cpuLoad.cpu_ticks.3 - previousCpuLoad.cpu_ticks.3)
                
                let totalDiff = userDiff + sysDiff + idleDiff + niceDiff
                if totalDiff > 0 {
                    metrics.userUsage = max(0.0, min(100.0, ((userDiff + niceDiff) / totalDiff) * 100.0))
                    metrics.systemUsage = max(0.0, min(100.0, (sysDiff / totalDiff) * 100.0))
                    metrics.idleUsage = max(0.0, min(100.0, (idleDiff / totalDiff) * 100.0))
                    metrics.totalUsage = max(0.0, min(100.0, metrics.userUsage + metrics.systemUsage))
                }
            }
            previousCpuLoad = cpuLoad
            hasPreviousLoad = true
        }
        
        // 2. Per-core CPU Load via host_processor_info
        var numProcessors: natural_t = 0
        var processorInfo: processor_info_array_t?
        var numProcessorInfo: mach_msg_type_number_t = 0
        
        let procResult = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numProcessors,
            &processorInfo,
            &numProcessorInfo
        )
        
        if procResult == KERN_SUCCESS, let info = processorInfo {
            var currentTicks: [[UInt32]] = []
            let cpuCount = Int(numProcessors)
            
            for i in 0..<cpuCount {
                let offset = i * Int(CPU_STATE_MAX)
                let u = UInt32(info[offset + Int(CPU_STATE_USER)])
                let s = UInt32(info[offset + Int(CPU_STATE_SYSTEM)])
                let id = UInt32(info[offset + Int(CPU_STATE_IDLE)])
                let n = UInt32(info[offset + Int(CPU_STATE_NICE)])
                currentTicks.append([u, s, id, n])
            }
            
            if previousPerCoreTicks.count == currentTicks.count {
                var perCore: [Double] = []
                for i in 0..<cpuCount {
                    let uDiff = Double(currentTicks[i][0] - previousPerCoreTicks[i][0])
                    let sDiff = Double(currentTicks[i][1] - previousPerCoreTicks[i][1])
                    let idDiff = Double(currentTicks[i][2] - previousPerCoreTicks[i][2])
                    let nDiff = Double(currentTicks[i][3] - previousPerCoreTicks[i][3])
                    
                    let total = uDiff + sDiff + idDiff + nDiff
                    if total > 0 {
                        let usage = ((uDiff + sDiff + nDiff) / total) * 100.0
                        perCore.append(max(0.0, min(100.0, usage)))
                    } else {
                        perCore.append(0.0)
                    }
                }
                metrics.perCoreUsage = perCore
            } else {
                metrics.perCoreUsage = Array(repeating: metrics.totalUsage, count: cpuCount)
            }
            metrics.busiestCoreUsage = metrics.perCoreUsage.max() ?? metrics.totalUsage
            
            previousPerCoreTicks = currentTicks
            
            // Deallocate VM buffer
            let size = vm_size_t(numProcessorInfo) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }
        
        // 3. Load Averages (1, 5, 15 min)
        var loadAvg = [Double](repeating: 0.0, count: 3)
        getloadavg(&loadAvg, 3)
        metrics.loadAverages = (loadAvg[0], loadAvg[1], loadAvg[2])
        
        return metrics
    }
    
    private func getCPUBrandString() -> String {
        var size: Int = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return "Apple Silicon" }
        
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }
}
