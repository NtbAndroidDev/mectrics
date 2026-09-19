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
            
            let points: [CGPoint] = values.enumerated().map { index, val in
                let clamped = max(minVal, min(maxVal, val))
                let normalizedY = 1.0 - CGFloat((clamped - minVal) / range)
                let x = CGFloat(index) * stepX
                let y = normalizedY * (size.height - 4) + 2
                return CGPoint(x: x, y: y)
            }
            
            guard points.count >= 2 else { return }
            
            var linePath = Path()
            var fillPath = Path()
            
            linePath.move(to: points[0])
            fillPath.move(to: CGPoint(x: points[0].x, y: size.height))
            fillPath.addLine(to: points[0])
            
            for i in 0..<points.count - 1 {
                let current = points[i]
                let next = points[i + 1]
                let midPoint = CGPoint(x: (current.x + next.x) / 2, y: (current.y + next.y) / 2)
                
                if i == 0 {
                    linePath.addLine(to: midPoint)
                    fillPath.addLine(to: midPoint)
                } else {
                    linePath.addQuadCurve(to: midPoint, control: current)
                    fillPath.addQuadCurve(to: midPoint, control: current)
                }
            }
            
            if let last = points.last {
                linePath.addLine(to: last)
                fillPath.addLine(to: last)
                fillPath.addLine(to: CGPoint(x: last.x, y: size.height))
                fillPath.closeSubpath()
            }
            
            if showFill {
                let grad = Gradient(colors: [
                    strokeColor.opacity(0.40),
                    strokeColor.opacity(0.0)
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
