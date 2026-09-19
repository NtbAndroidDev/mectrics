import Foundation
import AppKit
import UserNotifications

@MainActor
public final class RulesEngine: ObservableObject {
    @Published public var rules: [AlertRule] = []
    @Published public var activeAlerts: [String] = []
    
    private let userDefaultsKey = "com.openmectrics.savedRules"
    
    public init() {
        loadRules()
        requestNotificationPermission()
    }
    
    public func requestNotificationPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }
    
    public func loadRules() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([AlertRule].self, from: data) {
            self.rules = decoded
        } else {
            // Default built-in sensible rules matching Image 5
            self.rules = [
                AlertRule(
                    name: "CPU usage above",
                    isEnabled: true,
                    target: .cpuUsage,
                    comparison: .greaterThan,
                    thresholdValue: 85.0,
                    sustainedSeconds: 30
                ),
                AlertRule(
                    name: "Memory usage above",
                    isEnabled: false,
                    target: .memoryUsage,
                    comparison: .greaterThan,
                    thresholdValue: 90.0,
                    sustainedSeconds: 30
                ),
                AlertRule(
                    name: "Battery charge below",
                    isEnabled: false,
                    target: .batteryLevel,
                    comparison: .lessThan,
                    thresholdValue: 20.0,
                    sustainedSeconds: 30
                ),
                AlertRule(
                    name: "Disk usage above",
                    isEnabled: true,
                    target: .diskUsage,
                    comparison: .greaterThan,
                    thresholdValue: 90.0,
                    sustainedSeconds: 30
                ),
                AlertRule(
                    name: "Free disk space below",
                    isEnabled: false,
                    target: .freeDiskSpace,
                    comparison: .lessThan,
                    thresholdValue: 20.0,
                    sustainedSeconds: 30
                ),
                AlertRule(
                    name: "GPU usage above",
                    isEnabled: false,
                    target: .gpuUsage,
                    comparison: .greaterThan,
                    thresholdValue: 90.0,
                    sustainedSeconds: 30
                ),
                AlertRule(
                    name: "CPU temperature above",
                    isEnabled: false,
                    target: .cpuTemperature,
                    comparison: .greaterThan,
                    thresholdValue: 85.0,
                    sustainedSeconds: 30
                )
            ]
            saveRules()
        }
    }
    
    public func saveRules() {
        if let encoded = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    public func addRule(_ rule: AlertRule) {
        rules.append(rule)
        saveRules()
    }
    
    public func deleteRule(id: UUID) {
        rules.removeAll { $0.id == id }
        saveRules()
    }
    
    public func toggleRule(id: UUID) {
        if let index = rules.firstIndex(where: { $0.id == id }) {
            rules[index].isEnabled.toggle()
            saveRules()
        }
    }
    
    public func updateRule(id: UUID, threshold: Double, delaySeconds: Int? = nil) {
        if let index = rules.firstIndex(where: { $0.id == id }) {
            rules[index].thresholdValue = threshold
            if let delay = delaySeconds {
                rules[index].sustainedSeconds = delay
            }
            saveRules()
        }
    }
    
    /// Evaluates rules against current system metrics.
    /// Condition must hold for `sustainedSeconds` samples before triggering!
    /// Cooldown: rests for 15 minutes after alerting.
    public func evaluate(
        cpu: CPUMetrics,
        memory: MemoryMetrics,
        battery: BatteryMetrics,
        disk: DiskMetrics,
        sensor: SensorMetrics,
        gpu: GPUMetrics,
        sampleInterval: Double
    ) {
        var currentActiveAlerts: [String] = []
        let now = Date()
        
        for i in 0..<rules.count {
            guard rules[i].isEnabled else {
                rules[i].consecutiveHits = 0
                rules[i].isTriggered = false
                continue
            }
            
            let conditionMet: Bool
            let displayVal: String
            
            switch rules[i].target {
            case .cpuUsage:
                conditionMet = checkNumeric(rules[i].comparison, actual: cpu.totalUsage, target: rules[i].thresholdValue)
                displayVal = String(format: "%.1f%%", cpu.totalUsage)
                
            case .memoryUsage:
                conditionMet = checkNumeric(rules[i].comparison, actual: memory.usagePercentage, target: rules[i].thresholdValue)
                displayVal = String(format: "%.1f%%", memory.usagePercentage)
                
            case .batteryLevel:
                if battery.isPresent && !battery.isPluggedIn {
                    conditionMet = checkNumeric(rules[i].comparison, actual: battery.percentage, target: rules[i].thresholdValue)
                    displayVal = String(format: "%.0f%%", battery.percentage)
                } else {
                    conditionMet = false
                    displayVal = "N/A"
                }
                
            case .diskUsage:
                conditionMet = checkNumeric(rules[i].comparison, actual: disk.usagePercentage, target: rules[i].thresholdValue)
                displayVal = String(format: "%.1f%%", disk.usagePercentage)
                
            case .freeDiskSpace:
                let freeGB = Double(disk.freeBytes) / (1024 * 1024 * 1024)
                conditionMet = checkNumeric(rules[i].comparison, actual: freeGB, target: rules[i].thresholdValue)
                displayVal = String(format: "%.1f GB", freeGB)
                
            case .gpuUsage:
                conditionMet = checkNumeric(rules[i].comparison, actual: gpu.usagePercentage, target: rules[i].thresholdValue)
                displayVal = String(format: "%.1f%%", gpu.usagePercentage)
                
            case .cpuTemperature:
                conditionMet = checkNumeric(rules[i].comparison, actual: sensor.cpuTemperature, target: rules[i].thresholdValue)
                displayVal = String(format: "%.1f°C", sensor.cpuTemperature)
                
            case .thermalPressure:
                let actual = sensor.thermalPressure.rawValue
                conditionMet = (actual == rules[i].thermalThreshold) ||
                    (rules[i].thermalThreshold == "Serious" && actual == "Critical")
                displayVal = actual
            }
            
            let requiredHits = max(1, Int(Double(rules[i].sustainedSeconds) / max(0.5, sampleInterval)))
            
            if conditionMet {
                rules[i].consecutiveHits += 1
                if rules[i].consecutiveHits >= requiredHits {
                    // Check cooldown (rests for 15 minutes)
                    let shouldDispatch: Bool
                    if let lastTrigger = rules[i].lastTriggeredDate {
                        shouldDispatch = now.timeIntervalSince(lastTrigger) >= 15 * 60
                    } else {
                        shouldDispatch = true
                    }
                    
                    if shouldDispatch && !rules[i].isTriggered {
                        rules[i].isTriggered = true
                        rules[i].lastTriggeredDate = now
                        dispatchNotification(rule: rules[i], currentValue: displayVal)
                    }
                    currentActiveAlerts.append("\(rules[i].target.rawValue) (\(displayVal))")
                }
            } else {
                rules[i].consecutiveHits = 0
                rules[i].isTriggered = false
            }
        }
        
        self.activeAlerts = currentActiveAlerts
    }
    
    private func checkNumeric(_ op: RuleOperator, actual: Double, target: Double) -> Bool {
        switch op {
        case .greaterThan: return actual > target
        case .lessThan: return actual < target
        case .equals: return abs(actual - target) < 0.01
        }
    }
    
    private func dispatchNotification(rule: AlertRule, currentValue: String) {
        if UserDefaults.standard.bool(forKey: "rule_play_sound") {
            NSSound.beep()
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Mectrics Alert: \(rule.name)"
        content.body = "Condition sustained for \(rule.sustainedSeconds)s. Current value: \(currentValue)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "mectrics_rule_\(rule.id)",
            content: content,
            trigger: nil // Immediate delivery
        )
        
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
