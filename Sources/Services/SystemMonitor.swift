import Foundation
import Combine

public enum MenuBarDisplayStyle: String, Codable, CaseIterable {
    case full = "Wide"       // Icon + Text + Sparkline
    case compact = "Medium"  // Icon + Text (No sparkline)
    case minimal = "Tiny"    // Text Only (Ultra compact)
}

public enum DiskDisplayMode: String, Codable, CaseIterable {
    case freeSpace = "Free Space (e.g. 59GB)"
    case percentage = "Used Percentage (e.g. 76%)"
}

public enum NetworkDisplayMode: String, Codable, CaseIterable {
    case stacked = "Stacked Down/Up (↓4.1K / ↑6.2K)"
    case totalRate = "Single Total (e.g. 10.3 KB/s)"
}

public enum TemperatureUnit: String, Codable, CaseIterable {
    case celsius = "Celsius (°C)"
    case fahrenheit = "Fahrenheit (°F)"
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
    
    @Published public var showDualStackedMenuBar: Bool {
        didSet { UserDefaults.standard.set(showDualStackedMenuBar, forKey: "pref_showDualStackedMenuBar") }
    }
    
    @Published public var menuBarDisplayStyle: MenuBarDisplayStyle {
        didSet { UserDefaults.standard.set(menuBarDisplayStyle.rawValue, forKey: "pref_menuBarDisplayStyle") }
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
    @Published public var showFansInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showFansInMenuBar, forKey: "pref_showFans") }
    }
    @Published public var temperatureUnit: TemperatureUnit {
        didSet { UserDefaults.standard.set(temperatureUnit.rawValue, forKey: "pref_temperatureUnit") }
    }
    
    public func formatTemperature(_ celsius: Double) -> String {
        if temperatureUnit == .fahrenheit {
            let f = (celsius * 9.0 / 5.0) + 32.0
            return String(format: "%.0f°F", f)
        } else {
            return String(format: "%.0f°C", celsius)
        }
    }
    
    public func formatTemperaturePrecise(_ celsius: Double) -> String {
        if temperatureUnit == .fahrenheit {
            let f = (celsius * 9.0 / 5.0) + 32.0
            return String(format: "%.1f°F", f)
        } else {
            return String(format: "%.1f°C", celsius)
        }
    }
    
    // Background Samplers (Injected Clean Architecture Protocols)
    public let cpuMonitor: any CPUMonitoring
    public let memoryMonitor: any MemoryMonitoring
    public let batteryMonitor: any BatteryMonitoring
    public let networkMonitor: any NetworkMonitoring
    public let diskMonitor: any DiskMonitoring
    public let gpuMonitor: any GPUMonitoring
    public let sensorMonitor: any SensorMonitoring
    
    private var timer: Timer?
    private var isPaused: Bool = false
    private var sampleCycleCount: UInt64 = 0
    
    public init(
        cpuMonitor: (any CPUMonitoring)? = nil,
        memoryMonitor: (any MemoryMonitoring)? = nil,
        batteryMonitor: (any BatteryMonitoring)? = nil,
        networkMonitor: (any NetworkMonitoring)? = nil,
        diskMonitor: (any DiskMonitoring)? = nil,
        gpuMonitor: (any GPUMonitoring)? = nil,
        sensorMonitor: (any SensorMonitoring)? = nil
    ) {
        self.cpuMonitor = cpuMonitor ?? CPUMonitor()
        self.memoryMonitor = memoryMonitor ?? MemoryMonitor()
        self.batteryMonitor = batteryMonitor ?? BatteryMonitor()
        self.networkMonitor = networkMonitor ?? NetworkMonitor()
        self.diskMonitor = diskMonitor ?? DiskMonitor()
        self.gpuMonitor = gpuMonitor ?? GPUMonitor()
        self.sensorMonitor = sensorMonitor ?? SensorMonitor()
        
        // Register defaults
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "pref_updateInterval": 1.0,
            "pref_useCompactHealthBar": false,
            "pref_showDualStackedMenuBar": false,
            "pref_menuBarDisplayStyle": MenuBarDisplayStyle.full.rawValue,
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
            "pref_showSensor": true,
            "pref_showFans": false,
            "pref_temperatureUnit": TemperatureUnit.celsius.rawValue
        ])
        
        // Load persisted settings
        let savedInterval = defaults.double(forKey: "pref_updateInterval")
        self.updateInterval = savedInterval >= 0.5 ? savedInterval : 1.0
        self.useCompactHealthBar = defaults.bool(forKey: "pref_useCompactHealthBar")
        self.showDualStackedMenuBar = defaults.bool(forKey: "pref_showDualStackedMenuBar")
        self.menuBarDisplayStyle = MenuBarDisplayStyle(rawValue: defaults.string(forKey: "pref_menuBarDisplayStyle") ?? "") ?? .full
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
        self.showFansInMenuBar = defaults.bool(forKey: "pref_showFans")
        self.temperatureUnit = TemperatureUnit(rawValue: defaults.string(forKey: "pref_temperatureUnit") ?? "") ?? .celsius
        
        // Initial sample
        refreshAll()
        startTimer()
    }
    
    public func pauseMonitoring() {
        isPaused = true
        timer?.invalidate()
        timer = nil
    }
    
    public func resumeMonitoring() {
        guard isPaused else { return }
        isPaused = false
        refreshAll()
        startTimer()
    }
    
    public func startTimer() {
        timer?.invalidate()
        guard !isPaused else { return }
        let interval = max(0.5, updateInterval > 0 ? updateInterval : 1.0)
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
    
    private var isRefreshing = false
    
    public func refreshAll() {
        guard !isRefreshing, !isPaused else { return }
        isRefreshing = true
        sampleCycleCount &+= 1
        let cycle = sampleCycleCount
        
        let cpuMon = self.cpuMonitor
        let memMon = self.memoryMonitor
        let batMon = self.batteryMonitor
        let netMon = self.networkMonitor
        let diskMon = self.diskMonitor
        let gpuMon = self.gpuMonitor
        let sensorMon = self.sensorMonitor
        
        // Smart adaptive sampling: reduce frequency of heavy IOKit queries if inactive in Menu Bar
        let shouldSampleGPU = showGPUInMenuBar || (cycle % 4 == 0)
        let shouldSampleSensors = showSensorInMenuBar || (cycle % 3 == 0)
        let shouldSampleBattery = (showBatteryInMenuBar && battery.isPresent) || (cycle % 5 == 0)
        
        let lastBattery = self.battery
        let lastGPU = self.gpu
        let lastSensors = self.sensor
        
        Task.detached(priority: .utility) { [weak self] in
            let newCPU = cpuMon.sample()
            let newMem = memMon.sample()
            let newNet = netMon.sample()
            let newDisk = diskMon.sample()
            let newBat = shouldSampleBattery ? batMon.sample() : lastBattery
            let newGPU = shouldSampleGPU ? gpuMon.sample() : lastGPU
            let newSensors = shouldSampleSensors ? sensorMon.sample() : lastSensors
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.applyMetrics(
                    cpu: newCPU,
                    mem: newMem,
                    bat: newBat,
                    net: newNet,
                    disk: newDisk,
                    gpu: newGPU,
                    sensors: newSensors
                )
                self.isRefreshing = false
            }
        }
    }
    
    private func applyMetrics(
        cpu: CPUMetrics,
        mem: MemoryMetrics,
        bat: BatteryMetrics,
        net: NetworkMetrics,
        disk: DiskMetrics,
        gpu: GPUMetrics,
        sensors: SensorMetrics
    ) {
        // Append history for sparklines
        cpuHistory.append(cpu.totalUsage)
        memoryHistory.append(mem.usagePercentage)
        networkDownHistory.append(net.downloadBytesPerSec)
        networkUpHistory.append(net.uploadBytesPerSec)
        diskReadHistory.append(disk.readBytesPerSec)
        diskWriteHistory.append(disk.writeBytesPerSec)
        gpuHistory.append(gpu.usagePercentage)
        tempHistory.append(sensors.cpuTemperature)
        
        // Calculate Compact Health Score
        let newHealth = computeHealthScore(
            cpu: cpu,
            memory: mem,
            battery: bat,
            sensors: sensors,
            disk: disk
        )
        
        // Evaluate Rules
        rulesEngine.evaluate(
            cpu: cpu,
            memory: mem,
            battery: bat,
            disk: disk,
            sensor: sensors,
            gpu: gpu,
            sampleInterval: max(0.5, updateInterval)
        )
        
        self.cpu = cpu
        self.memory = mem
        self.battery = bat
        self.network = net
        self.disk = disk
        self.gpu = gpu
        self.sensor = sensors
        self.health = newHealth
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
