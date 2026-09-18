import Foundation
import Combine

public enum DiskDisplayMode: String, Codable, CaseIterable {
    case freeSpace = "Free Space (e.g. 59GB)"
    case percentage = "Used Percentage (e.g. 76%)"
}

public enum NetworkDisplayMode: String, Codable, CaseIterable {
    case stacked = "Stacked Down/Up (↓4.1K / ↑6.2K)"
    case totalRate = "Single Total (e.g. 10.3 KB/s)"
}

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
    
    // Preferences & Settings (Persisted in UserDefaults)
    @Published public var updateInterval: Double {
        didSet {
            UserDefaults.standard.set(updateInterval, forKey: "pref_updateInterval")
            restartTimer()
        }
    }
    
    @Published public var useCompactHealthBar: Bool {
        didSet { UserDefaults.standard.set(useCompactHealthBar, forKey: "pref_useCompactHealthBar") }
    }
    
    @Published public var showCPUInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showCPUInMenuBar, forKey: "pref_showCPU") }
    }
    @Published public var showCPUSparkline: Bool {
        didSet { UserDefaults.standard.set(showCPUSparkline, forKey: "pref_showCPUSparkline") }
    }
    
    @Published public var showMemoryInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showMemoryInMenuBar, forKey: "pref_showMemory") }
    }
    @Published public var showMemorySparkline: Bool {
        didSet { UserDefaults.standard.set(showMemorySparkline, forKey: "pref_showMemorySparkline") }
    }
    
    @Published public var showDiskInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showDiskInMenuBar, forKey: "pref_showDisk") }
    }
    @Published public var diskDisplayMode: DiskDisplayMode {
        didSet { UserDefaults.standard.set(diskDisplayMode.rawValue, forKey: "pref_diskDisplayMode") }
    }
    
    @Published public var showNetworkInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showNetworkInMenuBar, forKey: "pref_showNetwork") }
    }
    @Published public var networkDisplayMode: NetworkDisplayMode {
        didSet { UserDefaults.standard.set(networkDisplayMode.rawValue, forKey: "pref_networkDisplayMode") }
    }
    
    @Published public var showBatteryInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showBatteryInMenuBar, forKey: "pref_showBattery") }
    }
    @Published public var showGPUInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showGPUInMenuBar, forKey: "pref_showGPU") }
    }
    @Published public var showSensorInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showSensorInMenuBar, forKey: "pref_showSensor") }
    }
    
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
        // Register defaults
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "pref_updateInterval": 1.0,
            "pref_useCompactHealthBar": false,
            "pref_showCPU": true,
            "pref_showCPUSparkline": true,
            "pref_showMemory": true,
            "pref_showMemorySparkline": true,
            "pref_showDisk": true,
            "pref_diskDisplayMode": DiskDisplayMode.freeSpace.rawValue,
            "pref_showNetwork": true,
            "pref_networkDisplayMode": NetworkDisplayMode.stacked.rawValue,
            "pref_showBattery": true,
            "pref_showGPU": false,
            "pref_showSensor": true
        ])
        
        // Load persisted settings
        self.updateInterval = defaults.double(forKey: "pref_updateInterval")
        self.useCompactHealthBar = defaults.bool(forKey: "pref_useCompactHealthBar")
        self.showCPUInMenuBar = defaults.bool(forKey: "pref_showCPU")
        self.showCPUSparkline = defaults.bool(forKey: "pref_showCPUSparkline")
        self.showMemoryInMenuBar = defaults.bool(forKey: "pref_showMemory")
        self.showMemorySparkline = defaults.bool(forKey: "pref_showMemorySparkline")
        self.showDiskInMenuBar = defaults.bool(forKey: "pref_showDisk")
        self.diskDisplayMode = DiskDisplayMode(rawValue: defaults.string(forKey: "pref_diskDisplayMode") ?? "") ?? .freeSpace
        self.showNetworkInMenuBar = defaults.bool(forKey: "pref_showNetwork")
        self.networkDisplayMode = NetworkDisplayMode(rawValue: defaults.string(forKey: "pref_networkDisplayMode") ?? "") ?? .stacked
        self.showBatteryInMenuBar = defaults.bool(forKey: "pref_showBattery")
        self.showGPUInMenuBar = defaults.bool(forKey: "pref_showGPU")
        self.showSensorInMenuBar = defaults.bool(forKey: "pref_showSensor")
        
        // Initial sample
        refreshAll()
        startTimer()
    }
    
    public func startTimer() {
        timer?.invalidate()
        let interval = max(0.2, updateInterval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
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
        
        if cpu.totalUsage > 85.0 {
            deductions += 15.0
            issues.append("High CPU Load")
        } else if cpu.totalUsage > 60.0 {
            deductions += 5.0
        }
        
        if memory.pressureLevel == .critical || memory.usagePercentage > 90.0 {
            deductions += 25.0
            issues.append("Memory Pressure Critical")
        } else if memory.pressureLevel == .warning || memory.usagePercentage > 80.0 {
            deductions += 10.0
            issues.append("Memory Warning")
        }
        
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
