import SwiftUI

public struct GaugeRingView: View {
    public let value: Double // 0.0 - 100.0
    public var label: String? = nil
    public var tintColor: Color = .blue
    public var lineWidth: CGFloat = 8
    public var size: CGFloat = 64
    
    public init(
        value: Double,
        label: String? = nil,
        tintColor: Color = .blue,
        lineWidth: CGFloat = 8,
        size: CGFloat = 64
    ) {
        self.value = max(0.0, min(100.0, value))
        self.label = label
        self.tintColor = tintColor
        self.lineWidth = lineWidth
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(value / 100.0))
                .stroke(
                    tintColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: value)
            
            VStack(spacing: 0) {
                Text(String(format: "%.0f%%", value))
                    .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                
                if let label = label {
                    Text(label)
                        .font(.system(size: size * 0.16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

public struct SectionCardView<Content: View>: View {
    public let title: String
    public var icon: String? = nil
    public var headerTrailing: AnyView? = nil
    public let content: Content
    
    public init(
        title: String,
        icon: String? = nil,
        headerTrailing: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.headerTrailing = headerTrailing
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let trailing = headerTrailing {
                    trailing
                }
            }
            
            content
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}
