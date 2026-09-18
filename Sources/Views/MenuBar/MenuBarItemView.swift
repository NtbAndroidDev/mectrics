import SwiftUI

public struct MenuBarItemView: View {
    public let icon: String
    public let valueText: String
    public var sparklineValues: [Double]? = nil
    public var tintColor: Color = .primary
    
    public init(
        icon: String,
        valueText: String,
        sparklineValues: [Double]? = nil,
        tintColor: Color = .primary
    ) {
        self.icon = icon
        self.valueText = valueText
        self.sparklineValues = sparklineValues
        self.tintColor = tintColor
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tintColor)
            
            Text(valueText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
            
            if let values = sparklineValues, values.count >= 2 {
                SparklineView(
                    values: values,
                    strokeColor: tintColor,
                    gradientColors: [tintColor.opacity(0.4), tintColor.opacity(0.1)],
                    lineWidth: 1.2,
                    showFill: true,
                    minScale: 0.0,
                    maxScale: nil
                )
                .frame(width: 32, height: 12)
            }
        }
        .padding(.horizontal, 2)
    }
}

public struct CompactHealthBarView: View {
    public let score: Int
    public let statusLevel: StatusLevel
    
    public init(score: Int, statusLevel: StatusLevel) {
        self.score = score
        self.statusLevel = statusLevel
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 7, height: 7)
            
            Text("\(score)%")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 3)
    }
    
    private var indicatorColor: Color {
        switch statusLevel {
        case .good: return .green
        case .elevated: return .orange
        case .alert: return .red
        }
    }
}
