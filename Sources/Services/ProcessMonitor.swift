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

public final class ProcessMonitor: @unchecked Sendable {
    public static let shared = ProcessMonitor()
    
    private var cachedProcesses: [TopProcessItem] = []
    private var lastFetchTime = Date.distantPast
    private let lock = NSLock()
    
    public init() {}
    
    /// Returns the top 5 CPU-intensive processes, refreshed at most every 2 seconds
    public func topCPUProcesses() -> [TopProcessItem] {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        if now.timeIntervalSince(lastFetchTime) < 2.0 && !cachedProcesses.isEmpty {
            return cachedProcesses
        }
        
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
                
                // Skip header line "PID %CPU COMM"
                for line in lines.dropFirst() {
                    let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    guard parts.count >= 3 else { continue }
                    
                    if let pid = Int(parts[0]),
                       let cpu = Double(parts[1]) {
                        let fullComm = parts.dropFirst(2).joined(separator: " ")
                        let appName = (fullComm as NSString).lastPathComponent
                        // Skip ps itself
                        if appName != "ps" && appName != "head" {
                            items.append(TopProcessItem(id: pid, name: appName, cpuPercentage: cpu))
                            if items.count >= 5 { break }
                        }
                    }
                }
                
                self.cachedProcesses = items
                self.lastFetchTime = now
                return items
            }
        } catch {
            // Fallback
        }
        
        return cachedProcesses
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
