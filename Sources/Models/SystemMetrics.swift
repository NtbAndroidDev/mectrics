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
    public var pCores: Int = 0
    public var eCores: Int = 0
    public var busiestCoreUsage: Double = 0.0
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
    public var maxCycles: Int = 1000
    public var healthPercentage: Double = 100.0
    public var nominalCapacityMAh: Int = 0
    public var designCapacityMAh: Int = 0
    public var remainingCapacityMAh: Int = 0
    public var temperature: Double = 30.0 // Celsius
    public var powerSource: String = "AC Power"
    public var condition: String = "Normal"
    public var timeRemainingMinutes: Int? = nil // nil if calculating or AC
    public var wattage: Double = 0.0 // Watts
    public var chargerWatts: Int? = nil
    public var isLowPowerMode: Bool = false
}

// MARK: - Network Metrics
public struct NetworkMetrics: Sendable {
    public var downloadBytesPerSec: Double = 0.0
    public var uploadBytesPerSec: Double = 0.0
    public var totalDownloadedBytes: UInt64 = 0
    public var totalUploadedBytes: UInt64 = 0
    public var primaryInterfaceName: String = "en0"
    public var ipv4Address: String = "127.0.0.1"
    public var publicIpAddress: String? = nil
    public var gatewayIpAddress: String? = nil
    public var wifiSsid: String? = nil
    public var wifiRssi: Int? = nil
    public var wifiTxRate: Double? = nil
    public var isConnected: Bool = true
    public var pingLatencyMs: Double? = nil
}

// MARK: - Disk Metrics
public struct VolumeInfo: Identifiable, Sendable, Hashable {
    public var id: String { url.path }
    public let name: String
    public let url: URL
    public let isInternal: Bool
    public let isRemovable: Bool
    public let totalBytes: UInt64
    public let freeBytes: UInt64
    
    public init(name: String, url: URL, isInternal: Bool, isRemovable: Bool, totalBytes: UInt64, freeBytes: UInt64) {
        self.name = name
        self.url = url
        self.isInternal = isInternal
        self.isRemovable = isRemovable
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
    }
    
    public var usedBytes: UInt64 {
        totalBytes >= freeBytes ? (totalBytes - freeBytes) : 0
    }
    
    public var usagePercentage: Double {
        totalBytes > 0 ? (Double(usedBytes) / Double(totalBytes)) * 100.0 : 0.0
    }
}

public struct DiskMetrics: Sendable {
    public var totalBytes: UInt64 = 0
    public var usedBytes: UInt64 = 0
    public var freeBytes: UInt64 = 0
    public var purgeableBytes: UInt64 = 0
    public var usagePercentage: Double = 0.0
    public var readBytesPerSec: Double = 0.0
    public var writeBytesPerSec: Double = 0.0
    public var volumeName: String = "Macintosh HD"
    public var fileSystem: String = "APFS"
    public var trashBytes: UInt64 = 0
    public var volumes: [VolumeInfo] = []
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
