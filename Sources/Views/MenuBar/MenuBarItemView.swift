import SwiftUI

public struct MenuBarItemView: View {
    public let icon: String
    public let valueText: String
    public var sparklineValues: [Double]?
    public var isBoxedSparkline: Bool
    public var tintColor: Color
    
    public init(
        icon: String,
        valueText: String,
        sparklineValues: [Double]? = nil,
        isBoxedSparkline: Bool = false,
        tintColor: Color = MectricsTheme.coral
    ) {
        self.icon = icon
        self.valueText = valueText
        self.sparklineValues = sparklineValues
        self.isBoxedSparkline = isBoxedSparkline
        self.tintColor = tintColor
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tintColor)
            
            Text(valueText)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
            
            if let values = sparklineValues, values.count >= 2 {
                if isBoxedSparkline {
                    // Small dark box for Memory sparkline
                    SparklineView(
                        values: values,
                        strokeColor: tintColor.opacity(0.8),
                        lineWidth: 1.2,
                        showFill: true,
                        minScale: 0.0,
                        maxScale: 100.0
                    )
                    .frame(width: 24, height: 11)
                    .background(Color(white: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                } else {
                    // Standard smooth waveform for CPU
                    SparklineView(
                        values: values,
                        strokeColor: tintColor,
                        lineWidth: 1.3,
                        showFill: true,
                        minScale: 0.0,
                        maxScale: 100.0
                    )
                    .frame(width: 28, height: 12)
                }
            }
        }
        .padding(.horizontal, 2)
    }
}

public struct NetworkMenuBarView: View {
    public let downloadBytes: Double
    public let uploadBytes: Double
    public var tintColor: Color = MectricsTheme.coral
    
    public init(downloadBytes: Double, uploadBytes: Double, tintColor: Color = MectricsTheme.coral) {
        self.downloadBytes = downloadBytes
        self.uploadBytes = uploadBytes
        self.tintColor = tintColor
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tintColor)
            
            VStack(alignment: .leading, spacing: -1) {
                HStack(spacing: 1) {
                    Text("↓")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(tintColor)
                    Text(formatRate(downloadBytes))
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                
                HStack(spacing: 1) {
                    Text("↑")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(tintColor)
                    Text(formatRate(uploadBytes))
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 2)
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
    
    public init(statusLevel: StatusLevel = .good) {
        self.statusLevel = statusLevel
    }
    
    public var body: some View {
        Image(systemName: "checkmark.shield")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(statusLevel == .good ? MectricsTheme.coral : .yellow)
            .padding(.horizontal, 2)
    }
}
