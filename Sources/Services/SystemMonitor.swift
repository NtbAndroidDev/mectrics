import Foundation
import Combine

@MainActor
public final class SystemMonitor: ObservableObject {
    public static let shared = SystemMonitor()
    
    // Live Current Metrics
    @Published public var cpu: CPUMetrics = CPUMetrics()
    @Published public var memory: MemoryMetrics = MemoryMetrics()
    @Published public var battery: BatteryMetrics = BatteryMetrics()
    @Published public var network: NetworkMetrics = NetworkMetrics()
    @Published public var disk: DiskMetrics = DiskMetrics()
    @Published public var gpu: GPUMetrics = GPUMetrics()
    @Published public var sensor: SensorMetrics = SensorMetrics()
    @Published public var health: HealthScore = HealthScore()
    
    // Sparkline Histories
    public let cpuHistory = MetricHistory(capacity: 30)
    public let memoryHistory = MetricHistory(capacity: 30)
    public let networkDownHistory = MetricHistory(capacity: 30)
    public let networkUpHistory = MetricHistory(capacity: 30)
    public let diskReadHistory = MetricHistory(capacity: 30)
    public let diskWriteHistory = MetricHistory(capacity: 30)
    public let gpuHistory = MetricHistory(capacity: 30)
    public let tempHistory = MetricHistory(capacity: 30)
    
    // Rules Engine
    public let rulesEngine = RulesEngine()
    
    // Preferences & Settings
    @Published public var updateInterval: Double = 1.0 {
        didSet { restartTimer() }
    }
    @Published public var useCompactHealthBar: Bool = false
    @Published public var showCPUInMenuBar: Bool = true
    @Published public var showMemoryInMenuBar: Bool = true
    @Published public var showBatteryInMenuBar: Bool = true
    @Published public var showNetworkInMenuBar: Bool = true
    @Published public var showDiskInMenuBar: Bool = true
    @Published public var showGPUInMenuBar: Bool = false
    @Published public var showSensorInMenuBar: Bool = true
    
    // Background Samplers
    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let batteryMonitor = BatteryMonitor()
    private let networkMonitor = NetworkMonitor()
    private let diskMonitor = DiskMonitor()
    private let gpuMonitor = GPUMonitor()
    private let sensorMonitor = SensorMonitor()
    
    private var timer: Timer?
    
    private init() {
        // Initial sample
        refreshAll()
        startTimer()
    }
    
    public func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAll()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    private func restartTimer() {
        startTimer()
    }
    
    public func refreshAll() {
        let newCPU = cpuMonitor.sample()
        let newMem = memoryMonitor.sample()
        let newBat = batteryMonitor.sample()
        let newNet = networkMonitor.sample()
        let newDisk = diskMonitor.sample()
        let newGPU = gpuMonitor.sample()
        let newSensors = sensorMonitor.sample()
        
        self.cpu = newCPU
        self.memory = newMem
        self.battery = newBat
        self.network = newNet
        self.disk = newDisk
        self.gpu = newGPU
        self.sensor = newSensors
        
        // Append history for sparklines
        cpuHistory.append(newCPU.totalUsage)
        memoryHistory.append(newMem.usagePercentage)
        networkDownHistory.append(newNet.downloadBytesPerSec)
        networkUpHistory.append(newNet.uploadBytesPerSec)
        diskReadHistory.append(newDisk.readBytesPerSec)
        diskWriteHistory.append(newDisk.writeBytesPerSec)
        gpuHistory.append(newGPU.usagePercentage)
        tempHistory.append(newSensors.cpuTemperature)
        
        // Calculate Compact Health Score
        self.health = computeHealthScore(
            cpu: newCPU,
            memory: newMem,
            battery: newBat,
            sensors: newSensors,
            disk: newDisk
        )
        
        // Evaluate Rules
        rulesEngine.evaluate(
            cpu: newCPU,
            memory: newMem,
            battery: newBat,
            disk: newDisk,
            sensor: newSensors,
            gpu: newGPU,
            sampleInterval: updateInterval
        )
    }
    
    private func computeHealthScore(
        cpu: CPUMetrics,
        memory: MemoryMetrics,
        battery: BatteryMetrics,
        sensors: SensorMetrics,
        disk: DiskMetrics
    ) -> HealthScore {
        var deductions: Double = 0.0
        var issues: [String] = []
        
        // CPU penalty: high usage for extended periods
        if cpu.totalUsage > 85.0 {
            deductions += 15.0
            issues.append("High CPU Load")
        } else if cpu.totalUsage > 60.0 {
            deductions += 5.0
        }
        
        // Memory penalty: RAM usage and pressure
        if memory.pressureLevel == .critical || memory.usagePercentage > 90.0 {
            deductions += 25.0
            issues.append("Memory Pressure Critical")
        } else if memory.pressureLevel == .warning || memory.usagePercentage > 80.0 {
            deductions += 10.0
            issues.append("Memory Warning")
        }
        
        // Thermal pressure penalty
        switch sensors.thermalPressure {
        case .critical:
            deductions += 30.0
            issues.append("Thermal Throttling Critical")
        case .serious:
            deductions += 15.0
            issues.append("Thermal Pressure Elevated")
        case .fair:
            deductions += 5.0
        case .nominal:
            break
        }
        
        // Disk space penalty: if free < 10 GB
        if disk.freeBytes < 10 * 1024 * 1024 * 1024 {
            deductions += 20.0
            issues.append("Disk Space Low")
        }
        
        let score = max(0, min(100, Int(100.0 - deductions)))
        let level: StatusLevel
        let summary: String
        
        if score >= 85 {
            level = .good
            summary = "System Optimal"
        } else if score >= 60 {
            level = .elevated
            summary = issues.isEmpty ? "System Moderate" : issues.joined(separator: ", ")
        } else {
            level = .alert
            summary = issues.isEmpty ? "Action Needed" : issues.joined(separator: ", ")
        }
        
        return HealthScore(overallScore: score, statusSummary: summary, statusLevel: level)
    }
}
