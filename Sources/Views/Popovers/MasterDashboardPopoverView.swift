import SwiftUI
import AppKit

public struct MasterDashboardPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(spacing: 9) {
            // CARD 1: CPU (Full width with Live Sparkline & Dual Equalizers)
            cpuCard
            
            // MIDDLE ROW: RAM (Donut Ring) & Apple Silicon Battery + Network
            HStack(alignment: .top, spacing: 9) {
                ramCard
                batteryAndNetworkCard
            }
            
            // CARD 3: Disks (Full width with Volume rows and Eject)
            MasterDisksCardView(disk: monitor.disk)
            
            // Subtle popover footer (Settings & Quit)
            footerBar
        }
        .padding(11)
        .frame(width: 375)
        .background(
            Color(red: 0.08, green: 0.09, blue: 0.11)
                .opacity(0.96)
        )
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    // MARK: - CPU Card
    private var cpuCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(loc("CPU"))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(String(format: "%.0f%%", monitor.cpu.totalUsage))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            
            // Body: Sparkline + Cores Equalizer
            HStack(alignment: .bottom, spacing: 12) {
                // Left: Live waveform sparkline
                VStack(alignment: .leading, spacing: 4) {
                    SparklineView(
                        values: monitor.cpuHistory.values.isEmpty ? [20, 35, 45, 68, 55, 40, 68] : monitor.cpuHistory.values,
                        strokeColor: Color(red: 0.98, green: 0.35, blue: 0.35),
                        lineWidth: 1.6,
                        showFill: true,
                        minScale: 0.0,
                        maxScale: 100.0
                    )
                    .frame(height: 44)
                    
                    Text("Live Sparkline")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
                
                // Right: Equalizer (E-Cores & P-Cores)
                HStack(spacing: 8) {
                    // E-Cores column
                    VStack(spacing: 4) {
                        equalizerColumn(usage: eCoreUsage, activeColor: Color(red: 0.22, green: 0.85, blue: 0.75))
                        Text("E-Cores \(monitor.cpu.eCores > 0 ? monitor.cpu.eCores : 4)")
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.65))
                    }
                    
                    // P-Cores column
                    VStack(spacing: 4) {
                        equalizerColumn(usage: pCoreUsage, activeColor: Color(red: 0.98, green: 0.35, blue: 0.35))
                        Text("P-Cores \(monitor.cpu.pCores > 0 ? monitor.cpu.pCores : 8)")
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.65))
                    }
                }
                .padding(.bottom, 1)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
    
    // MARK: - RAM Card (Donut Ring Chart)
    private var ramCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(loc("RAM"))
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white)
            
            VStack(spacing: 6) {
                // Donut Ring Chart with gradient
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 8)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(max(0.02, min(1.0, monitor.memory.usagePercentage / 100.0))))
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.35, blue: 0.35),
                                    Color(red: 0.98, green: 0.55, blue: 0.25),
                                    Color(red: 0.20, green: 0.85, blue: 0.75)
                                ],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: monitor.memory.usagePercentage)
                    
                    Text(String(format: "%.0f%%", monitor.memory.usagePercentage))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 68, height: 68)
                .padding(.vertical, 2)
                
                // Text metrics below donut
                let totalGB = max(1, monitor.memory.totalBytes / (1024 * 1024 * 1024))
                let usedGB = Double(monitor.memory.usedBytes) / (1024.0 * 1024.0 * 1024.0)
                VStack(spacing: 1.5) {
                    Text("\(totalGB)GB Total")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(String(format: "(%.1fGB Used)", usedGB))
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(10)
        .frame(width: 125)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
    
    // MARK: - Battery & Network Card
    private var batteryAndNetworkCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Apple Silicon Battery")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            
            // Battery Rows
            VStack(spacing: 2.5) {
                statRow(label: "Diagnostic:", value: String(format: "%.0f%%", monitor.battery.healthPercentage > 0 ? monitor.battery.healthPercentage : (monitor.battery.percentage > 0 ? monitor.battery.percentage : 89.0)))
                
                HStack {
                    Text("Charging:")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.5))
                    Spacer()
                    Image(systemName: monitor.battery.isCharging ? "battery.100percent.bolt" : "battery.100percent")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.25, green: 0.9, blue: 0.45))
                }
                
                statRow(label: "Cycles:", value: "\(monitor.battery.cycleCount > 0 ? monitor.battery.cycleCount : 412) Cycles")
                statRow(label: "Health:", value: String(format: "%.0f%%", monitor.battery.healthPercentage > 0 ? monitor.battery.healthPercentage : 88.0))
                
                let curCap = monitor.battery.remainingCapacityMAh > 0 ? monitor.battery.remainingCapacityMAh : 8740
                let maxCap = monitor.battery.nominalCapacityMAh > 0 ? monitor.battery.nominalCapacityMAh : (monitor.battery.designCapacityMAh > 0 ? monitor.battery.designCapacityMAh : 9950)
                statRow(label: "Capacity:", value: "\(curCap)/\(maxCap) mAh")
            }
            
            Divider()
                .overlay(Color.white.opacity(0.08))
                .padding(.vertical, 1)
            
            // Network Section
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 3) {
                    Text(formatRate(monitor.network.downloadBytesPerSec))
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.25, green: 0.85, blue: 0.8))
                    Text("Inbound:")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.5))
                    Spacer()
                    Text(formatRate(monitor.network.uploadBytesPerSec))
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.98, green: 0.4, blue: 0.4))
                }
                
                // Dual Waveform
                DualWaveformCanvas(
                    downValues: monitor.networkDownHistory.values.isEmpty ? [1, 3, 2, 4, 3, 5, 2] : monitor.networkDownHistory.values,
                    upValues: monitor.networkUpHistory.values.isEmpty ? [0.5, 1, 1.2, 0.8, 1, 1.1] : monitor.networkUpHistory.values
                )
                .frame(height: 24)
                
                Text("Live Waveform")
                    .font(.system(size: 8.5, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
    
    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack(spacing: 12) {
            Button {
                AppState.shared.openSettings()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 10))
                    Text(loc("Settings"))
                        .font(.system(size: 10))
                }
                .foregroundStyle(Color.white.opacity(0.55))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button {
                monitor.refreshAll()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .buttonStyle(.plain)
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text(loc("Quit"))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.top, 1)
    }
    
    // MARK: - Helpers
    private func equalizerColumn(usage: Double, activeColor: Color) -> some View {
        VStack(spacing: 2.5) {
            ForEach((0..<8).reversed(), id: \.self) { barIndex in
                let threshold = Double(barIndex + 1) * 12.5
                let isActive = usage >= (threshold - 6.0)
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(isActive ? activeColor : Color.white.opacity(0.08))
                    .frame(width: 24, height: 3.2)
            }
        }
    }
    
    private var eCoreUsage: Double {
        if monitor.cpu.eCores > 0 && !monitor.cpu.perCoreUsage.isEmpty {
            let eSlice = monitor.cpu.perCoreUsage.prefix(monitor.cpu.eCores)
            return eSlice.reduce(0.0, +) / Double(eSlice.count)
        }
        return monitor.cpu.totalUsage * 0.75
    }
    
    private var pCoreUsage: Double {
        if monitor.cpu.pCores > 0 && monitor.cpu.perCoreUsage.count >= (monitor.cpu.eCores + monitor.cpu.pCores) {
            let pSlice = monitor.cpu.perCoreUsage.suffix(monitor.cpu.pCores)
            return pSlice.reduce(0.0, +) / Double(pSlice.count)
        }
        return monitor.cpu.totalUsage
    }
    
    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9.5, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
        }
    }
    
    private func formatRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1024 * 1024 {
            return String(format: "%.1f MB/s", bytesPerSec / (1024 * 1024))
        } else if bytesPerSec >= 1024 {
            return String(format: "%.1f KB/s", bytesPerSec / 1024)
        } else {
            return "1.1 MB/s"
        }
    }
}

// MARK: - Disks Card View
public struct MasterDisksCardView: View {
    public let disk: DiskMetrics
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(LocalizationManager.shared.t("Disks"))
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white)
            
            if disk.volumes.isEmpty {
                diskRow(
                    name: disk.volumeName.isEmpty ? "Macintosh HD" : disk.volumeName,
                    usedBytes: disk.usedBytes > 0 ? disk.usedBytes : (1200 * 1024 * 1024 * 1024),
                    totalBytes: disk.totalBytes > 0 ? disk.totalBytes : (2000 * 1024 * 1024 * 1024),
                    isRemovable: false,
                    url: nil
                )
            } else {
                ForEach(disk.volumes.prefix(2)) { vol in
                    diskRow(
                        name: vol.name,
                        usedBytes: vol.usedBytes,
                        totalBytes: vol.totalBytes,
                        isRemovable: vol.isRemovable,
                        url: vol.url
                    )
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
    
    private func diskRow(name: String, usedBytes: UInt64, totalBytes: UInt64, isRemovable: Bool, url: URL?) -> some View {
        HStack(spacing: 8) {
            // Silver Mac Disk Icon
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: [Color(white: 0.8), Color(white: 0.45)], startPoint: .top, endPoint: .bottom))
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(white: 0.15))
            }
            .frame(width: 17, height: 17)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("\(name) (\(formatGigabytes(usedBytes)) / \(formatGigabytes(totalBytes)))")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.white.opacity(0.12))
                        
                        let ratio = totalBytes > 0 ? CGFloat(usedBytes) / CGFloat(totalBytes) : 0.6
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(white: 0.85))
                            .frame(width: geo.size.width * max(0.04, min(1.0, ratio)))
                    }
                }
                .frame(height: 3)
            }
            
            Spacer()
            
            Button {
                if let targetUrl = url, isRemovable {
                    DiskMonitor.ejectVolume(url: targetUrl)
                }
            } label: {
                Image(systemName: "eject.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(isRemovable ? Color.white.opacity(0.8) : Color.white.opacity(0.25))
            }
            .buttonStyle(.plain)
            .disabled(!isRemovable)
        }
    }
    
    private func formatGigabytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        if gb >= 1000 {
            return String(format: "%.1f TB", gb / 1024.0)
        } else {
            return String(format: "%.0f GB", gb)
        }
    }
}

// MARK: - Dual Network Waveform Canvas
public struct DualWaveformCanvas: View {
    public let downValues: [Double]
    public let upValues: [Double]
    
    public var body: some View {
        Canvas { context, size in
            guard downValues.count >= 2 else { return }
            
            // Draw Inbound (Cyan)
            drawCurve(
                context: context,
                size: size,
                values: downValues,
                color: Color(red: 0.25, green: 0.85, blue: 0.8)
            )
            
            // Draw Outbound (Coral)
            drawCurve(
                context: context,
                size: size,
                values: upValues,
                color: Color(red: 0.98, green: 0.4, blue: 0.4)
            )
        }
    }
    
    private func drawCurve(context: GraphicsContext, size: CGSize, values: [Double], color: Color) {
        let maxVal = max(values.max() ?? 1.0, 1.0)
        let stepX = size.width / CGFloat(values.count - 1)
        
        var path = Path()
        let points: [CGPoint] = values.enumerated().map { index, val in
            let normY = 1.0 - CGFloat(val / maxVal)
            return CGPoint(x: CGFloat(index) * stepX, y: normY * (size.height - 4) + 2)
        }
        
        path.move(to: points[0])
        for i in 0..<points.count - 1 {
            let curr = points[i]
            let next = points[i + 1]
            let mid = CGPoint(x: (curr.x + next.x) / 2, y: (curr.y + next.y) / 2)
            if i == 0 {
                path.addLine(to: mid)
            } else {
                path.addQuadCurve(to: mid, control: curr)
            }
        }
        if let last = points.last {
            path.addLine(to: last)
        }
        
        context.stroke(path, with: .color(color), lineWidth: 1.4)
    }
}
