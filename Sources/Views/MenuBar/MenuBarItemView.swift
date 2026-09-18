import SwiftUI

public struct MenuBarItemView: View {
    public let icon: String
    public let valueText: String
    public var sparklineValues: [Double]?
    public var isBoxedSparkline: Bool
    public var tintColor: Color
    public var isActive: Bool
    
    public init(
        icon: String,
        valueText: String,
        sparklineValues: [Double]? = nil,
        isBoxedSparkline: Bool = false,
        tintColor: Color = MectricsTheme.coral,
        isActive: Bool = false
    ) {
        self.icon = icon
        self.valueText = valueText
        self.sparklineValues = sparklineValues
        self.isBoxedSparkline = isBoxedSparkline
        self.tintColor = tintColor
        self.isActive = isActive
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tintColor)
            
            Text(valueText)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white)
            
            if let values = sparklineValues, values.count >= 2 {
                if isBoxedSparkline {
                    // Small dark maroon box for Memory sparkline (as in reference Image 4)
                    SparklineView(
                        values: values,
                        strokeColor: tintColor.opacity(0.85),
                        lineWidth: 1.2,
                        showFill: true,
                        minScale: 0.0,
                        maxScale: 100.0
                    )
                    .frame(width: 24, height: 11)
                    .background(Color(red: 0.22, green: 0.08, blue: 0.12))
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
        .padding(.horizontal, isActive ? 6 : 2)
        .padding(.vertical, isActive ? 2 : 0)
        .background(isActive ? Color.white.opacity(0.18) : Color.clear)
        .clipShape(Capsule())
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
        .padding(.horizontal, isActive ? 6 : 2)
        .padding(.vertical, isActive ? 2 : 0)
        .background(isActive ? Color.white.opacity(0.18) : Color.clear)
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
        Image(systemName: "checkmark.shield")
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(statusLevel == .good ? .white : MectricsTheme.coral)
            .padding(.horizontal, isActive ? 6 : 3)
            .padding(.vertical, isActive ? 2 : 0)
            .background(isActive ? Color.white.opacity(0.18) : Color.clear)
            .clipShape(Capsule())
    }
}
