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

/// A high-performance fixed-size circular ring buffer with O(1) append and zero heap reallocations.
public final class MetricHistory: @unchecked Sendable {
    private let capacity: Int
    private var buffer: [Double]
    private var writeIndex: Int = 0
    private var count: Int = 0
    private let lock = NSLock()
    
    public init(capacity: Int = 30, initialValue: Double = 0.0) {
        let cap = max(capacity, 5)
        self.capacity = cap
        self.buffer = Array(repeating: initialValue, count: cap)
        self.count = cap
    }
    
    @inline(__always)
    public func append(_ value: Double) {
        lock.lock()
        defer { lock.unlock() }
        buffer[writeIndex] = value
        writeIndex = (writeIndex + 1) % capacity
        if count < capacity {
            count += 1
        }
    }
    
    public var values: [Double] {
        lock.lock()
        defer { lock.unlock() }
        if count < capacity {
            return Array(buffer[0..<count])
        }
        // Ordered chronologically from oldest to newest
        return Array(buffer[writeIndex..<capacity] + buffer[0..<writeIndex])
    }
    
    public var lastValue: Double {
        lock.lock()
        defer { lock.unlock() }
        guard count > 0 else { return 0.0 }
        let lastIdx = (writeIndex - 1 + capacity) % capacity
        return buffer[lastIdx]
    }
    
    public var average: Double {
        lock.lock()
        defer { lock.unlock() }
        guard count > 0 else { return 0.0 }
        var sum: Double = 0.0
        for i in 0..<count {
            sum += buffer[i]
        }
        return sum / Double(count)
    }
}
