import Foundation
import Darwin
import CoreWLAN

public final class NetworkMonitor: NetworkMonitoring, @unchecked Sendable {
    private var previousInBytes: UInt64 = 0
    private var previousOutBytes: UInt64 = 0
    private var previousTimestamp: Date = Date()
    private var isFirstSample = true
    private let lock = NSLock()
    
    // Background caches
    private var lastPingCheck = Date.distantPast
    private var cachedPingMs: Double? = nil
    private var isPinging = false
    
    private var lastWiFiCheck = Date.distantPast
    private var cachedWiFiRssi: Int? = nil
    private var cachedWiFiTxRate: Double? = nil
    private var cachedWiFiSsid: String? = nil
    
    private var lastPublicIPCheck = Date.distantPast
    private var cachedPublicIP: String? = nil
    
    private var lastGatewayCheck = Date.distantPast
    private var cachedGatewayIP: String? = nil
    
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
                        ipAddress = hostname.withUnsafeBufferPointer { ptr in
                            ptr.baseAddress.map { String(cString: $0) } ?? "127.0.0.1"
                        }
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
        
        // 1. Wi-Fi details via CoreWLAN (cached every 10s to prevent continuous radio driver wakes)
        enrichWiFi(&metrics)
        
        // 2. Gateway IP (cached every 180s)
        if Date().timeIntervalSince(lastGatewayCheck) >= 180.0 || cachedGatewayIP == nil {
            cachedGatewayIP = fetchGatewayIP()
            lastGatewayCheck = Date()
        }
        metrics.gatewayIpAddress = cachedGatewayIP
        
        // 3. Ping Latency in background (every 60s, only when active connection detected)
        if metrics.isConnected {
            measurePingInBackground()
        }
        metrics.pingLatencyMs = cachedPingMs
        
        // 4. Public IP: keep privacy guarantee (zero external network requests)
        metrics.publicIpAddress = ipAddress != "127.0.0.1" ? ipAddress : "Local"
        
        return metrics
    }
    
    private func enrichWiFi(_ metrics: inout NetworkMetrics) {
        let now = Date()
        if now.timeIntervalSince(lastWiFiCheck) >= 10.0 {
            lastWiFiCheck = now
            if let iface = CWWiFiClient.shared().interface() {
                let rssi = iface.rssiValue()
                cachedWiFiRssi = rssi != 0 ? rssi : nil
                let rate = iface.transmitRate()
                cachedWiFiTxRate = rate > 0 ? rate : nil
                if let ssid = iface.ssid(), !ssid.isEmpty {
                    cachedWiFiSsid = ssid
                } else {
                    cachedWiFiSsid = nil
                }
            }
        }
        
        metrics.wifiRssi = cachedWiFiRssi
        metrics.wifiTxRate = cachedWiFiTxRate
        metrics.wifiSsid = cachedWiFiSsid
    }
    
    private func fetchGatewayIP() -> String? {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/sbin/route")
        proc.arguments = ["-n", "get", "default"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let out = String(data: data, encoding: .utf8) {
                for line in out.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("gateway:") {
                        let parts = trimmed.components(separatedBy: ":")
                        if parts.count >= 2 {
                            return parts[1].trimmingCharacters(in: .whitespaces)
                        }
                    }
                }
            }
        } catch {}
        return nil
    }

    private func measurePingInBackground() {
        guard !isPinging && Date().timeIntervalSince(lastPingCheck) >= 60.0 else { return }
        isPinging = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let start = DispatchTime.now()
            var hints = addrinfo()
            hints.ai_family = AF_INET
            hints.ai_socktype = SOCK_STREAM
            var res: UnsafeMutablePointer<addrinfo>?
            
            if getaddrinfo("1.1.1.1", "53", &hints, &res) == 0, let addr = res {
                defer { freeaddrinfo(res) }
                let sock = socket(addr.pointee.ai_family, addr.pointee.ai_socktype, addr.pointee.ai_protocol)
                if sock >= 0 {
                    var tv = timeval(tv_sec: 0, tv_usec: 500_000)
                    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
                    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
                    
                    if connect(sock, addr.pointee.ai_addr, addr.pointee.ai_addrlen) == 0 {
                        let end = DispatchTime.now()
                        let nanos = end.uptimeNanoseconds - start.uptimeNanoseconds
                        let ms = Double(nanos) / 1_000_000.0
                        self?.lock.lock()
                        self?.cachedPingMs = ms
                        self?.lastPingCheck = Date()
                        self?.isPinging = false
                        self?.lock.unlock()
                        close(sock)
                        return
                    }
                    close(sock)
                }
            }
            self?.lock.lock()
            self?.lastPingCheck = Date()
            self?.isPinging = false
            self?.lock.unlock()
        }
    }
}
