import Foundation

public struct TopProcessItem: Identifiable, Sendable {
    public let id: Int // PID
    public let name: String
    public let cpuPercentage: Double
    
    public init(id: Int, name: String, cpuPercentage: Double) {
        self.id = id
        self.name = name
        self.cpuPercentage = cpuPercentage
    }
}

public struct TopMemoryProcessItem: Identifiable, Sendable {
    public let id: Int // PID
    public let name: String
    public let memoryPercentage: Double
    
    public init(id: Int, name: String, memoryPercentage: Double) {
        self.id = id
        self.name = name
        self.memoryPercentage = memoryPercentage
    }
}

public final class ProcessMonitor: ProcessMonitoring, @unchecked Sendable {
    public static let shared = ProcessMonitor()
    
    /// Minimum interval between `ps` snapshots. CPU and memory lists share one snapshot.
    private static let refreshInterval: TimeInterval = 2.0
    private static let topCount = 5
    
    private var cachedProcesses: [TopProcessItem] = []
    private var cachedMemoryProcesses: [TopMemoryProcessItem] = []
    private var lastFetchTime = Date.distantPast
    private var isFetching = false
    private let lock = NSLock()
    
    public init() {}
    
    /// Returns the top 5 CPU-intensive processes without blocking the main thread.
    public func topCPUProcesses() -> [TopProcessItem] {
        lock.lock()
        defer { lock.unlock() }
        scheduleFetchIfNeededLocked()
        return cachedProcesses
    }
    
    /// Returns the top 5 Memory-intensive processes without blocking the main thread.
    public func topMemoryProcesses() -> [TopMemoryProcessItem] {
        lock.lock()
        defer { lock.unlock() }
        scheduleFetchIfNeededLocked()
        return cachedMemoryProcesses
    }
    
    /// Gracefully terminates a process by PID
    @discardableResult
    public func terminateProcess(pid: Int) -> Bool {
        return Darwin.kill(pid_t(pid), SIGTERM) == 0
    }
    
    /// Must be called with `lock` held.
    private func scheduleFetchIfNeededLocked() {
        guard !isFetching, Date().timeIntervalSince(lastFetchTime) >= Self.refreshInterval else { return }
        isFetching = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.performFetch()
        }
    }
    
    /// One `ps` spawn feeds both CPU and memory rankings. `/bin/ps` is setuid root, so unlike
    /// libproc (`proc_pid_rusage` fails for root/system processes such as WindowServer) it sees
    /// every process without elevating Mectrics itself.
    private func performFetch() {
        let snapshot = Self.readProcessSnapshot()
        
        lock.lock()
        defer { lock.unlock() }
        if let snapshot {
            cachedProcesses = snapshot.topCPU
            cachedMemoryProcesses = snapshot.topMemory
        }
        // Stamp even on failure so a broken `ps` doesn't get respawned on every render.
        lastFetchTime = Date()
        isFetching = false
    }
    
    private struct ProcessSample {
        let pid: Int
        let cpu: Double
        let mem: Double
        let name: Substring
    }
    
    private static func readProcessSnapshot() -> (topCPU: [TopProcessItem], topMemory: [TopMemoryProcessItem])? {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        // `=` suffixes suppress the header; `-c` yields the bare executable name.
        process.arguments = ["-Aceo", "pid=,%cpu=,%mem=,comm="]
        // Force `.` decimals — locales like vi_VN would print `12,3` and break Double parsing.
        process.environment = ["LC_ALL": "C"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
        } catch {
            return nil
        }
        // Drain before waiting: with many processes the output can exceed the pipe buffer,
        // and waiting first would deadlock with `ps` blocked on write.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        
        let output = String(decoding: data, as: UTF8.self)
        let psPid = Int(process.processIdentifier)
        
        var samples: [ProcessSample] = []
        samples.reserveCapacity(1024)
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4,
                  let pid = Int(parts[0]),
                  let cpu = Double(parts[1]),
                  let mem = Double(parts[2]),
                  pid != psPid else { continue }
            samples.append(ProcessSample(pid: pid, cpu: cpu, mem: mem, name: parts[3]))
        }
        
        let topCPU = samples
            .sorted { $0.cpu > $1.cpu }
            .prefix(topCount)
            .map { TopProcessItem(id: $0.pid, name: String($0.name), cpuPercentage: $0.cpu) }
        let topMemory = samples
            .sorted { $0.mem > $1.mem }
            .prefix(topCount)
            .map { TopMemoryProcessItem(id: $0.pid, name: String($0.name), memoryPercentage: $0.mem) }
        return (topCPU, topMemory)
    }
    
    public static func formattedUptime() -> String {
        let uptimeSec = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptimeSec) / 3600
        let minutes = (Int(uptimeSec) % 3600) / 60
        let days = hours / 24
        
        if days > 0 {
            let remHours = hours % 24
            return "\(days)d \(remHours)h"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }
}
