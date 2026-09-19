import Foundation

/// Core Domain Protocols for hardware monitoring services.
/// Conforming to Clean Architecture / Dependency Inversion principles.

public protocol CPUMonitoring: Sendable {
    func sample() -> CPUMetrics
}

public protocol MemoryMonitoring: Sendable {
    func sample() -> MemoryMetrics
}

public protocol DiskMonitoring: Sendable {
    func sample() -> DiskMetrics
}

public protocol NetworkMonitoring: Sendable {
    func sample() -> NetworkMetrics
}

public protocol BatteryMonitoring: Sendable {
    func sample() -> BatteryMetrics
}

public protocol GPUMonitoring: Sendable {
    func sample() -> GPUMetrics
}

public protocol SensorMonitoring: Sendable {
    func sample() -> SensorMetrics
}

public protocol ProcessMonitoring: Sendable {
    func topCPUProcesses() -> [TopProcessItem]
}
