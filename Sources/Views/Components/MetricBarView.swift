import SwiftUI

public struct MetricBarView: View {
    public let label: String
    public let valueText: String
    public let progress: Double // 0.0 - 1.0
    public var tintColor: Color = .blue
    public var height: CGFloat = 6
    
    public init(
        label: String,
        valueText: String,
        progress: Double,
        tintColor: Color = .blue,
        height: CGFloat = 6
    ) {
        self.label = label
        self.valueText = valueText
        self.progress = max(0.0, min(1.0, progress))
        self.tintColor = tintColor
        self.height = height
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(valueText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Color.secondary.opacity(0.15))
                    
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(tintColor)
                        .frame(width: geo.size.width * CGFloat(progress))
                }
            }
            .frame(height: height)
        }
    }
}
