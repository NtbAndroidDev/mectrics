import Foundation

/// Represents a single timestamped metric sample for sparklines and historical trends.
public struct MetricSample: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let value: Double // normalized or raw value
    
    public init(timestamp: Date = Date(), value: Double) {
        self.timestamp = timestamp
        self.value = value
    }
}

/// A fixed-size circular history buffer to track live sparklines without memory leaks.
public final class MetricHistory: @unchecked Sendable {
    private let capacity: Int
    private var samples: [Double]
    private let lock = NSLock()
    
    public init(capacity: Int = 30, initialValue: Double = 0.0) {
        self.capacity = max(capacity, 5)
        self.samples = Array(repeating: initialValue, count: capacity)
    }
    
    public func append(_ value: Double) {
        lock.lock()
        defer { lock.unlock() }
        if samples.count >= capacity {
            samples.removeFirst()
        }
        samples.append(value)
    }
    
    public var values: [Double] {
        lock.lock()
        defer { lock.unlock() }
        return samples
    }
    
    public var lastValue: Double {
        lock.lock()
        defer { lock.unlock() }
        return samples.last ?? 0.0
    }
    
    public var average: Double {
        lock.lock()
        defer { lock.unlock() }
        guard !samples.isEmpty else { return 0.0 }
        return samples.reduce(0.0, +) / Double(samples.count)
    }
}
