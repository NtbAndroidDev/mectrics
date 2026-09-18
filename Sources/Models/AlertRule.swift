import Foundation

public enum RuleMetricTarget: String, CaseIterable, Identifiable, Codable, Sendable {
    case cpuUsage = "CPU Usage (%)"
    case memoryUsage = "Memory Usage (%)"
    case batteryLevel = "Battery Level (%)"
    case diskUsage = "Disk Usage (%)"
    case cpuTemperature = "CPU Temperature (°C)"
    case thermalPressure = "macOS Thermal Pressure"
    
    public var id: String { rawValue }
}

public enum RuleOperator: String, CaseIterable, Identifiable, Codable, Sendable {
    case greaterThan = ">"
    case lessThan = "<"
    case equals = "=="
    
    public var id: String { rawValue }
}

public struct AlertRule: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var isEnabled: Bool
    public var target: RuleMetricTarget
    public var comparison: RuleOperator
    public var thresholdValue: Double
    public var thermalThreshold: String // Used if target == .thermalPressure
    /// Condition must hold for this duration (in seconds or samples) before speaking up
    public var sustainedSeconds: Int
    
    // Runtime transient state
    public var consecutiveHits: Int
    public var isTriggered: Bool
    public var lastTriggeredDate: Date?
    
    public init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        target: RuleMetricTarget,
        comparison: RuleOperator = .greaterThan,
        thresholdValue: Double,
        thermalThreshold: String = "Serious",
        sustainedSeconds: Int = 10,
        consecutiveHits: Int = 0,
        isTriggered: Bool = false,
        lastTriggeredDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.target = target
        self.comparison = comparison
        self.thresholdValue = thresholdValue
        self.thermalThreshold = thermalThreshold
        self.sustainedSeconds = sustainedSeconds
        self.consecutiveHits = consecutiveHits
        self.isTriggered = isTriggered
        self.lastTriggeredDate = lastTriggeredDate
    }
}
