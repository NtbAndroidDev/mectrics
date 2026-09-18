import SwiftUI

public struct SparklineView: View {
    public let values: [Double]
    public var strokeColor: Color
    public var lineWidth: CGFloat
    public var showFill: Bool
    public var minScale: Double?
    public var maxScale: Double?
    
    public init(
        values: [Double],
        strokeColor: Color = MectricsTheme.coral,
        lineWidth: CGFloat = 1.6,
        showFill: Bool = true,
        minScale: Double? = 0.0,
        maxScale: Double? = 100.0
    ) {
        self.values = values
        self.strokeColor = strokeColor
        self.lineWidth = lineWidth
        self.showFill = showFill
        self.minScale = minScale
        self.maxScale = maxScale
    }
    
    public var body: some View {
        Canvas { context, size in
            guard values.count >= 2 else { return }
            
            let minVal = minScale ?? (values.min() ?? 0.0)
            let maxVal = max(maxScale ?? (values.max() ?? 100.0), minVal + 0.01)
            let range = maxVal - minVal
            
            let stepX = size.width / CGFloat(values.count - 1)
            
            var linePath = Path()
            var fillPath = Path()
            
            for (index, val) in values.enumerated() {
                let clamped = max(minVal, min(maxVal, val))
                let normalizedY = 1.0 - CGFloat((clamped - minVal) / range)
                let x = CGFloat(index) * stepX
                let y = normalizedY * (size.height - 4) + 2
                
                if index == 0 {
                    linePath.move(to: CGPoint(x: x, y: y))
                    fillPath.move(to: CGPoint(x: x, y: size.height))
                    fillPath.addLine(to: CGPoint(x: x, y: y))
                } else {
                    linePath.addLine(to: CGPoint(x: x, y: y))
                    fillPath.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
            fillPath.closeSubpath()
            
            if showFill {
                let grad = Gradient(colors: [
                    strokeColor.opacity(0.35),
                    strokeColor.opacity(0.02)
                ])
                context.fill(
                    fillPath,
                    with: .linearGradient(
                        grad,
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
            }
            
            context.stroke(
                linePath,
                with: .color(strokeColor),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }
}
