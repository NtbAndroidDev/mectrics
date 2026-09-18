import Foundation

// MARK: - CPU Metrics
public struct CPUMetrics: Sendable {
    public var totalUsage: Double = 0.0 // 0.0 - 100.0%
    public var userUsage: Double = 0.0
    public var systemUsage: Double = 0.0
    public var idleUsage: Double = 100.0
    public var perCoreUsage: [Double] = [] // per core 0.0 - 100.0%
    public var loadAverages: (one: Double, five: Double, fifteen: Double) = (0.0, 0.0, 0.0)
    public var temperature: Double = 0.0 // Celsius
    public var physicalCores: Int = 8
    public var logicalCores: Int = 8
    public var modelName: String = "Apple Silicon"
}

// MARK: - Memory Metrics
public struct MemoryMetrics: Sendable {
    public var totalBytes: UInt64 = 0
    public var usedBytes: UInt64 = 0
    public var freeBytes: UInt64 = 0
    public var activeBytes: UInt64 = 0
    public var wiredBytes: UInt64 = 0
    public var compressedBytes: UInt64 = 0
    public var cachedBytes: UInt64 = 0
    public var swapUsedBytes: UInt64 = 0
    public var swapTotalBytes: UInt64 = 0
    public var usagePercentage: Double = 0.0 // 0.0 - 100.0%
    public var pressureLevel: MemoryPressureLevel = .normal
}

public enum MemoryPressureLevel: String, Sendable {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"
}

// MARK: - Battery Metrics
public struct BatteryMetrics: Sendable {
    public var isPresent: Bool = true
    public var percentage: Double = 100.0
    public var isCharging: Bool = false
    public var isPluggedIn: Bool = true
    public var cycleCount: Int = 0
    public var healthPercentage: Double = 100.0
    public var temperature: Double = 30.0 // Celsius
    public var powerSource: String = "AC Power"
    public var condition: String = "Normal"
    public var timeRemainingMinutes: Int? = nil // nil if calculating or AC
    public var wattage: Double = 0.0 // Watts
}

// MARK: - Network Metrics
public struct NetworkMetrics: Sendable {
    public var downloadBytesPerSec: Double = 0.0
    public var uploadBytesPerSec: Double = 0.0
    public var totalDownloadedBytes: UInt64 = 0
    public var totalUploadedBytes: UInt64 = 0
    public var primaryInterfaceName: String = "en0"
    public var ipv4Address: String = "127.0.0.1"
    public var isConnected: Bool = true
}

// MARK: - Disk Metrics
public struct DiskMetrics: Sendable {
    public var totalBytes: UInt64 = 0
    public var usedBytes: UInt64 = 0
    public var freeBytes: UInt64 = 0
    public var usagePercentage: Double = 0.0
    public var readBytesPerSec: Double = 0.0
    public var writeBytesPerSec: Double = 0.0
    public var volumeName: String = "Macintosh HD"
    public var fileSystem: String = "APFS"
}

// MARK: - GPU Metrics
public struct GPUMetrics: Sendable {
    public var usagePercentage: Double = 0.0
    public var memoryUsedBytes: UInt64 = 0
    public var memoryTotalBytes: UInt64 = 0
    public var temperature: Double = 0.0
    public var name: String = "Apple Integrated GPU"
}

// MARK: - Sensor & Thermal Metrics
public struct SensorMetrics: Sendable {
    public var cpuTemperature: Double = 45.0
    public var gpuTemperature: Double = 42.0
    public var batteryTemperature: Double = 29.0
    public var fans: [FanInfo] = []
    public var thermalPressure: ThermalPressureState = .nominal
}

public struct FanInfo: Identifiable, Sendable {
    public let id: Int
    public var name: String
    public var currentRPM: Int
    public var minRPM: Int
    public var maxRPM: Int
}

public enum ThermalPressureState: String, Sendable, CaseIterable {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"
    
    public var sfSymbol: String {
        switch self {
        case .nominal: return "thermometer.sun.fill"
        case .fair: return "thermometer.high"
        case .serious: return "exclamationmark.triangle.fill"
        case .critical: return "flame.fill"
        }
    }
}

// MARK: - Compact Health Score
public struct HealthScore: Sendable {
    public var overallScore: Int = 100 // 0 - 100
    public var statusSummary: String = "System Healthy"
    public var statusLevel: StatusLevel = .good
}

public enum StatusLevel: Sendable {
    case good
    case elevated
    case alert
}
