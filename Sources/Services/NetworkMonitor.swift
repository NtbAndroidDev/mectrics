import Foundation
import Darwin

public final class NetworkMonitor: @unchecked Sendable {
    private var previousInBytes: UInt64 = 0
    private var previousOutBytes: UInt64 = 0
    private var previousTimestamp: Date = Date()
    private var isFirstSample = true
    private let lock = NSLock()
    
    public init() {}
    
    public func sample() -> NetworkMetrics {
        lock.lock()
        defer { lock.unlock() }
        
        var metrics = NetworkMetrics()
        var currentInBytes: UInt64 = 0
        var currentOutBytes: UInt64 = 0
        var primaryName = "en0"
        var ipAddress = "127.0.0.1"
        
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else {
            return metrics
        }
        defer { freeifaddrs(ifap) }
        
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            let interface = current.pointee
            let name = String(cString: interface.ifa_name)
            
            // Skip loopback interfaces
            let flags = Int32(interface.ifa_flags)
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0
            
            if !isLoopback && isUp && isRunning {
                // Check for IPv4 address
                if interface.ifa_addr != nil && interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                   &hostname, socklen_t(hostname.count),
                                   nil, 0, NI_NUMERICHOST) == 0 {
                        ipAddress = String(cString: hostname)
                        primaryName = name
                    }
                }
                
                // Read traffic counters from AF_LINK / if_data64
                if interface.ifa_addr != nil && interface.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                    if let data = interface.ifa_data {
                        let networkData = data.assumingMemoryBound(to: if_data64.self).pointee
                        currentInBytes += UInt64(networkData.ifi_ibytes)
                        currentOutBytes += UInt64(networkData.ifi_obytes)
                    }
                }
            }
            ptr = interface.ifa_next
        }
        
        metrics.totalDownloadedBytes = currentInBytes
        metrics.totalUploadedBytes = currentOutBytes
        metrics.primaryInterfaceName = primaryName
        metrics.ipv4Address = ipAddress
        metrics.isConnected = (currentInBytes > 0 || currentOutBytes > 0)
        
        let now = Date()
        let elapsed = max(0.1, now.timeIntervalSince(previousTimestamp))
        
        if !isFirstSample {
            let inDiff = currentInBytes >= previousInBytes ? (currentInBytes - previousInBytes) : 0
            let outDiff = currentOutBytes >= previousOutBytes ? (currentOutBytes - previousOutBytes) : 0
            
            metrics.downloadBytesPerSec = Double(inDiff) / elapsed
            metrics.uploadBytesPerSec = Double(outDiff) / elapsed
        } else {
            isFirstSample = false
            metrics.downloadBytesPerSec = 0
            metrics.uploadBytesPerSec = 0
        }
        
        previousInBytes = currentInBytes
        previousOutBytes = currentOutBytes
        previousTimestamp = now
        
        return metrics
    }
}
