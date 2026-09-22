import SwiftUI

public struct MenuBarItemView: View {
    public let icon: String
    public let valueText: String
    public var sparklineValues: [Double]?
    public var isBoxedSparkline: Bool
    public var tintColor: Color
    public var displayStyle: MenuBarDisplayStyle
    public var isActive: Bool
    
    public init(
        icon: String,
        valueText: String,
        sparklineValues: [Double]? = nil,
        isBoxedSparkline: Bool = false,
        tintColor: Color = MectricsTheme.coral,
        displayStyle: MenuBarDisplayStyle = .full,
        isActive: Bool = false
    ) {
        self.icon = icon
        self.valueText = valueText
        self.sparklineValues = sparklineValues
        self.isBoxedSparkline = isBoxedSparkline
        self.tintColor = tintColor
        self.displayStyle = displayStyle
        self.isActive = isActive
    }
    
    public var body: some View {
        HStack(spacing: 3.5) {
            if displayStyle != .minimal {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tintColor)
            }
            
            Text(valueText)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
            
            if displayStyle == .full, let values = sparklineValues, values.count >= 2 {
                if isBoxedSparkline {
                    // Small dark maroon box for Memory sparkline
                    SparklineView(
                        values: values,
                        strokeColor: tintColor.opacity(0.85),
                        lineWidth: 1.2,
                        showFill: true,
                        minScale: 0.0,
                        maxScale: 100.0
                    )
                    .frame(width: 24, height: 11)
                    .background(tintColor.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 2.5))
                } else {
                    // Smooth live waveform for CPU
                    SparklineView(
                        values: values,
                        strokeColor: tintColor,
                        lineWidth: 1.4,
                        showFill: true,
                        minScale: 0.0,
                        maxScale: 100.0
                    )
                    .frame(width: 26, height: 11)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(isActive ? Color.white.opacity(0.20) : Color.clear)
        .clipShape(Capsule())
    }
}

public struct DualStackedMenuBarView: View {
    public let cpuUsage: Double
    public let memUsage: Double
    public var isActive: Bool
    public var activeSegment: UnifiedSegment
    
    public init(cpuUsage: Double, memUsage: Double, isActive: Bool = false, activeSegment: UnifiedSegment = .none) {
        self.cpuUsage = cpuUsage
        self.memUsage = memUsage
        self.isActive = isActive
        self.activeSegment = activeSegment
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // CPU line
            HStack(spacing: 2.5) {
                Text("C")
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(cpuUsage > 75.0 ? MectricsTheme.coral : Color.white.opacity(0.6))
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(white: 0.25))
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(cpuUsage > 75.0 ? MectricsTheme.coral : Color.white.opacity(0.85))
                            .frame(width: geo.size.width * CGFloat(max(0.05, min(1.0, cpuUsage / 100.0))))
                    }
                }
                .frame(width: 14, height: 3.5)
                
                Text(String(format: "%.0f%%", cpuUsage))
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(cpuUsage > 75.0 ? MectricsTheme.coral : .white)
            }
            .padding(.horizontal, activeSegment == .cpu ? 2 : 0)
            .background(activeSegment == .cpu ? Color.white.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            
            // RAM line
            HStack(spacing: 2.5) {
                Text("M")
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(memUsage > 80.0 ? MectricsTheme.coral : Color.white.opacity(0.6))
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(white: 0.25))
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(memUsage > 80.0 ? MectricsTheme.coral : Color.white.opacity(0.85))
                            .frame(width: geo.size.width * CGFloat(max(0.05, min(1.0, memUsage / 100.0))))
                    }
                }
                .frame(width: 14, height: 3.5)
                
                Text(String(format: "%.0f%%", memUsage))
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(memUsage > 80.0 ? MectricsTheme.coral : .white)
            }
            .padding(.horizontal, activeSegment == .memory ? 2 : 0)
            .background(activeSegment == .memory ? Color.white.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 1)
        .background(isActive ? Color.white.opacity(0.20) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 3.5))
    }
}

public struct NetworkMenuBarView: View {
    public let downloadBytes: Double
    public let uploadBytes: Double
    public var tintColor: Color
    public var isActive: Bool
    
    public init(
        downloadBytes: Double,
        uploadBytes: Double,
        tintColor: Color = MectricsTheme.coral,
        isActive: Bool = false
    ) {
        self.downloadBytes = downloadBytes
        self.uploadBytes = uploadBytes
        self.tintColor = tintColor
        self.isActive = isActive
    }
    
    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tintColor)
            
            VStack(alignment: .leading, spacing: -1) {
                HStack(spacing: 1) {
                    Text("↓")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(formatRate(downloadBytes))
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                
                HStack(spacing: 1) {
                    Text("↑")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(formatRate(uploadBytes))
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(isActive ? Color.white.opacity(0.20) : Color.clear)
        .clipShape(Capsule())
    }
    
    private func formatRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1024 * 1024 {
            return String(format: "%.1fM", bytesPerSec / (1024 * 1024))
        } else if bytesPerSec >= 1024 {
            return String(format: "%.1fK", bytesPerSec / 1024)
        } else {
            return "0.0K"
        }
    }
}

public struct CompactHealthBarView: View {
    public let statusLevel: StatusLevel
    public var isActive: Bool
    
    public init(statusLevel: StatusLevel = .good, isActive: Bool = false) {
        self.statusLevel = statusLevel
        self.isActive = isActive
    }
    
    public var body: some View {
        Image(systemName: statusLevel == .good ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(statusLevel == .good ? MectricsTheme.coral : Color.red)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(isActive ? Color.white.opacity(0.20) : Color.clear)
            .clipShape(Capsule())
    }
}

public enum UnifiedSegment: Sendable {
    case none
    case master
    case cpu
    case memory
}

public struct UnifiedSampleMenuBarView: View {
    public let cpuUsage: Double
    public let memUsage: Double
    public var isActive: Bool
    public var activeSegment: UnifiedSegment
    
    public init(cpuUsage: Double, memUsage: Double, isActive: Bool = false, activeSegment: UnifiedSegment = .none) {
        self.cpuUsage = cpuUsage
        self.memUsage = memUsage
        self.isActive = isActive
        self.activeSegment = activeSegment
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            // [ M ] Brand Badge with Apple Silicon hardware finish
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: activeSegment == .master ? [Color(white: 0.32), Color(white: 0.20)] : [Color(white: 0.22), Color(white: 0.13)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(
                                LinearGradient(
                                    colors: activeSegment == .master ? [MectricsTheme.coral, MectricsTheme.coral.opacity(0.5)] : [Color.white.opacity(0.35), Color.white.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: activeSegment == .master ? 1.2 : 0.8
                            )
                    )
                Text("M")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(activeSegment == .master ? MectricsTheme.coral : .white)
                    .shadow(color: Color.black.opacity(0.4), radius: 0.5, y: 0.5)
            }
            .frame(width: 17, height: 17)
            
            // CPU & RAM Text metrics with intelligent status coloring
            HStack(spacing: 5) {
                let isCpuHigh = cpuUsage > 80.0
                HStack(spacing: 2) {
                    Text("CPU")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isCpuHigh ? MectricsTheme.coral.opacity(0.9) : (activeSegment == .cpu ? .white : Color.white.opacity(0.65)))
                    Text(String(format: "%.0f%%", cpuUsage))
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(isCpuHigh ? MectricsTheme.coral : .white)
                }
                .padding(.horizontal, activeSegment == .cpu ? 4 : 2)
                .padding(.vertical, activeSegment == .cpu ? 1.5 : 1)
                .background(activeSegment == .cpu ? Color.white.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 3.5))
                
                let isMemHigh = memUsage > 85.0
                HStack(spacing: 2) {
                    Text("RAM")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isMemHigh ? Color.orange.opacity(0.9) : (activeSegment == .memory ? .white : Color.white.opacity(0.65)))
                    Text(String(format: "%.0f%%", memUsage))
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(isMemHigh ? Color.orange : .white)
                }
                .padding(.horizontal, activeSegment == .memory ? 4 : 2)
                .padding(.vertical, activeSegment == .memory ? 1.5 : 1)
                .background(activeSegment == .memory ? Color.white.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 3.5))
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(isActive ? Color.white.opacity(0.20) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
