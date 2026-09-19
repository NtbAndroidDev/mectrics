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
    
    private var cachedProcesses: [TopProcessItem] = []
    private var cachedMemoryProcesses: [TopMemoryProcessItem] = []
    private var lastFetchTime = Date.distantPast
    private var lastMemFetchTime = Date.distantPast
    private let lock = NSLock()
    
    public init() {}
    
    private var isFetching = false
    private var isMemFetching = false
    
    /// Returns the top 5 CPU-intensive processes without blocking the main thread.
    public func topCPUProcesses() -> [TopProcessItem] {
        lock.lock()
        let items = cachedProcesses
        let shouldFetch = Date().timeIntervalSince(lastFetchTime) >= 2.0 && !isFetching
        if shouldFetch {
            isFetching = true
            lock.unlock()
            
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.performFetch()
            }
            return items
        }
        lock.unlock()
        return items
    }
    
    /// Returns the top 5 Memory-intensive processes without blocking the main thread.
    public func topMemoryProcesses() -> [TopMemoryProcessItem] {
        lock.lock()
        let items = cachedMemoryProcesses
        let shouldFetch = Date().timeIntervalSince(lastMemFetchTime) >= 2.5 && !isMemFetching
        if shouldFetch {
            isMemFetching = true
            lock.unlock()
            
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.performMemFetch()
            }
            return items
        }
        lock.unlock()
        return items
    }
    
    /// Gracefully terminates a process by PID
    @discardableResult
    public func terminateProcess(pid: Int) -> Bool {
        return Darwin.kill(pid_t(pid), SIGTERM) == 0
    }
    
    private func performFetch() {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-Aceo", "pid,%cpu,comm", "-r"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var items: [TopProcessItem] = []
                let lines = output.components(separatedBy: .newlines)
                
                for line in lines.dropFirst() {
                    let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    guard parts.count >= 3 else { continue }
                    
                    if let pid = Int(parts[0]),
                       let cpu = Double(parts[1]) {
                        let fullComm = parts.dropFirst(2).joined(separator: " ")
                        let appName = (fullComm as NSString).lastPathComponent
                        if appName != "ps" && appName != "head" {
                            items.append(TopProcessItem(id: pid, name: appName, cpuPercentage: cpu))
                            if items.count >= 5 { break }
                        }
                    }
                }
                
                lock.lock()
                self.cachedProcesses = items
                self.lastFetchTime = Date()
                self.isFetching = false
                lock.unlock()
                return
            }
        } catch {
            // Fallback
        }
        
        lock.lock()
        self.isFetching = false
        lock.unlock()
    }
    
    private func performMemFetch() {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-Aceo", "pid,%mem,comm", "-m"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var items: [TopMemoryProcessItem] = []
                let lines = output.components(separatedBy: .newlines)
                
                for line in lines.dropFirst() {
                    let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    guard parts.count >= 3 else { continue }
                    
                    if let pid = Int(parts[0]),
                       let mem = Double(parts[1]) {
                        let fullComm = parts.dropFirst(2).joined(separator: " ")
                        let appName = (fullComm as NSString).lastPathComponent
                        if appName != "ps" && appName != "head" {
                            items.append(TopMemoryProcessItem(id: pid, name: appName, memoryPercentage: mem))
                            if items.count >= 5 { break }
                        }
                    }
                }
                
                lock.lock()
                self.cachedMemoryProcesses = items
                self.lastMemFetchTime = Date()
                self.isMemFetching = false
                lock.unlock()
                return
            }
        } catch {
            // Fallback
        }
        
        lock.lock()
        self.isMemFetching = false
        lock.unlock()
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
