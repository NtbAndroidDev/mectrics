import SwiftUI

public enum MectricsTheme {
    /// Signature Mectrics Coral Accent (from official UI)
    public static let coral = Color(red: 0.98, green: 0.36, blue: 0.45) // #FA5C73
    public static let coralMuted = Color(red: 0.85, green: 0.30, blue: 0.38)
    public static let coralDark = Color(red: 0.55, green: 0.20, blue: 0.26)
    public static let purgeableColor = Color(red: 0.60, green: 0.25, blue: 0.32)
    
    /// Backgrounds
    public static let popoverBackground = Color.black.opacity(0.20)
    public static let cardBackground = Color.white.opacity(0.04)
    public static let cardBorder = Color.white.opacity(0.08)
    public static let trackBackground = Color(white: 0.22)
    
    /// Text styles
    public static let textPrimary = Color.white
    public static let textSecondary = Color(white: 0.65)
    public static let textTertiary = Color(white: 0.45)
    
    /// Standard Popover Dimensions
    public static let popoverWidth: CGFloat = 295
    public static let popoverCornerRadius: CGFloat = 16
}

public struct PopoverContainerModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(width: MectricsTheme.popoverWidth)
            .background(MectricsTheme.popoverBackground)
            .preferredColorScheme(.dark)
    }
}

extension View {
    public func mectricsPopoverStyle() -> some View {
        self.modifier(PopoverContainerModifier())
    }
}
