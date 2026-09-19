import Foundation
import Darwin

public final class DiskMonitor: DiskMonitoring, @unchecked Sendable {
    private var previousReadBytes: UInt64 = 0
    private var previousWriteBytes: UInt64 = 0
    private var previousTimestamp: Date = Date()
    private var isFirstSample = true
    private let lock = NSLock()
    
    public init() {}
    
    public func sample() -> DiskMetrics {
        lock.lock()
        defer { lock.unlock() }
        
        var metrics = DiskMetrics()
        
        // 1. Capacity & Free Space via FileManager
        do {
            let rootURL = URL(fileURLWithPath: "/")
            let values = try rootURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeNameKey
            ])
            
            let total = UInt64(values.volumeTotalCapacity ?? 0)
            let rawAvailable = UInt64(values.volumeAvailableCapacity ?? 0)
            let importantAvailable = UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
            
            let purgeable = importantAvailable > rawAvailable ? (importantAvailable - rawAvailable) : 0
            let free = rawAvailable > 0 ? rawAvailable : importantAvailable
            let used = total >= (free + purgeable) ? (total - free - purgeable) : (total >= free ? (total - free) : 0)
            
            metrics.totalBytes = total
            metrics.freeBytes = free
            metrics.purgeableBytes = purgeable
            metrics.usedBytes = used
            metrics.volumeName = values.volumeName ?? "Macintosh HD"
            
            if total > 0 {
                metrics.usagePercentage = max(0.0, min(100.0, (Double(total - free) / Double(total)) * 100.0))
            }
        } catch {
            // Fallback via statvfs
            var stat = statvfs()
            if statvfs("/", &stat) == 0 {
                let blockSize = UInt64(stat.f_frsize)
                let total = UInt64(stat.f_blocks) * blockSize
                let free = UInt64(stat.f_bavail) * blockSize
                metrics.totalBytes = total
                metrics.freeBytes = free
                metrics.usedBytes = total >= free ? (total - free) : 0
                if total > 0 {
                    metrics.usagePercentage = (Double(metrics.usedBytes) / Double(total)) * 100.0
                }
            }
        }
        
        // 2. Disk I/O Throughput via IOKit (IOBlockStorageDriver)
        let (currentRead, currentWrite) = readDiskIOStats()
        let now = Date()
        let elapsed = max(0.1, now.timeIntervalSince(previousTimestamp))
        
        if !isFirstSample {
            let rDiff = currentRead >= previousReadBytes ? (currentRead - previousReadBytes) : 0
            let wDiff = currentWrite >= previousWriteBytes ? (currentWrite - previousWriteBytes) : 0
            
            metrics.readBytesPerSec = Double(rDiff) / elapsed
            metrics.writeBytesPerSec = Double(wDiff) / elapsed
        } else {
            isFirstSample = false
            metrics.readBytesPerSec = 0
            metrics.writeBytesPerSec = 0
        }
        
        previousReadBytes = currentRead
        previousWriteBytes = currentWrite
        previousTimestamp = now
        
        // 3. Mounted Volumes Scan (Internal & External/USB)
        metrics.volumes = scanMountedVolumes()
        
        // Background trash size calculation
        scanTrashInBackground()
        metrics.trashBytes = cachedTrashBytes
        
        return metrics
    }
    
    private func scanMountedVolumes() -> [VolumeInfo] {
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [
                .volumeNameKey,
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeIsInternalKey,
                .volumeIsRemovableKey
            ],
            options: [.skipHiddenVolumes]
        ) else {
            return []
        }
        
        var list: [VolumeInfo] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: [
                .volumeNameKey,
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeIsInternalKey,
                .volumeIsRemovableKey
            ]) else { continue }
            
            let name = values.volumeName ?? url.lastPathComponent
            let total = UInt64(values.volumeTotalCapacity ?? 0)
            let free = UInt64(values.volumeAvailableCapacity ?? 0)
            let isInternal = values.volumeIsInternal ?? true
            let isRemovable = values.volumeIsRemovable ?? false
            
            if total > 0 {
                list.append(VolumeInfo(
                    name: name,
                    url: url,
                    isInternal: isInternal,
                    isRemovable: isRemovable,
                    totalBytes: total,
                    freeBytes: free
                ))
            }
        }
        return list.sorted { $0.totalBytes > $1.totalBytes }
    }
    
    public static func ejectVolume(url: URL) {
        NSWorkspace.shared.unmountAndEjectDevice(at: url) { error in
            if let error = error {
                NSLog("Failed to eject \(url.path): \(error.localizedDescription)")
            }
        }
    }
    
    private var cachedTrashBytes: UInt64 = 0
    private var lastTrashScan = Date.distantPast
    private var isScanningTrash = false

    private func scanTrashInBackground() {
        guard !isScanningTrash && Date().timeIntervalSince(lastTrashScan) >= 10.0 else { return }
        isScanningTrash = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var size: UInt64 = 0
            if let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first,
               let enumerator = FileManager.default.enumerator(at: trashURL, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey], options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    if let res = try? fileURL.resourceValues(forKeys: [.fileSizeKey]), let s = res.fileSize {
                        size += UInt64(s)
                    }
                }
            }
            self?.lock.lock()
            self?.cachedTrashBytes = size
            self?.lastTrashScan = Date()
            self?.isScanningTrash = false
            self?.lock.unlock()
        }
    }
    
    public static func emptyTrash() {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = "tell application \"Finder\" to empty trash"
            if let appleScript = NSAppleScript(source: script) {
                var err: NSDictionary?
                appleScript.executeAndReturnError(&err)
            }
        }
    }
    
    private func readDiskIOStats() -> (UInt64, UInt64) {
        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0
        
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOBlockStorageDriver")
        
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess {
            var service = IOIteratorNext(iterator)
            while service != 0 {
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                   let dict = props?.takeRetainedValue() as? [String: Any],
                   let stats = dict["Statistics"] as? [String: Any] {
                    if let r = stats["Bytes (Read)"] as? UInt64 {
                        totalRead += r
                    } else if let r = stats["Bytes (Read)"] as? Int64 {
                        totalRead += UInt64(max(0, r))
                    }
                    
                    if let w = stats["Bytes (Write)"] as? UInt64 {
                        totalWrite += w
                    } else if let w = stats["Bytes (Write)"] as? Int64 {
                        totalWrite += UInt64(max(0, w))
                    }
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }
        
        return (totalRead, totalWrite)
    }
}
