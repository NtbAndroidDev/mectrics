import SwiftUI

public enum AccentTheme: String, CaseIterable, Identifiable {
    case coral = "Coral"
    case ocean = "Ocean Blue"
    case emerald = "Emerald"
    case amber = "Amber"
    case purple = "Purple"
    case silver = "Silver"
    
    public var id: String { rawValue }
    
    public var primaryColor: Color {
        switch self {
        case .coral: return Color(red: 0.98, green: 0.36, blue: 0.45) // #FA5C73
        case .ocean: return Color(red: 0.22, green: 0.74, blue: 0.97) // #38BDF8
        case .emerald: return Color(red: 0.10, green: 0.80, blue: 0.55) // #10B981
        case .amber: return Color(red: 0.98, green: 0.62, blue: 0.08) // #F59E0B
        case .purple: return Color(red: 0.66, green: 0.33, blue: 0.97) // #A855F7
        case .silver: return Color(red: 0.90, green: 0.92, blue: 0.95) // Silver
        }
    }
    
    public var mutedColor: Color {
        primaryColor.opacity(0.72)
    }
    
    public var darkColor: Color {
        primaryColor.opacity(0.42)
    }
    
    public var purgeableColor: Color {
        switch self {
        case .coral: return Color(red: 0.42, green: 0.18, blue: 0.22)
        case .ocean: return Color(red: 0.12, green: 0.28, blue: 0.42)
        case .emerald: return Color(red: 0.10, green: 0.30, blue: 0.22)
        case .amber: return Color(red: 0.42, green: 0.25, blue: 0.10)
        case .purple: return Color(red: 0.35, green: 0.15, blue: 0.42)
        case .silver: return Color(white: 0.35)
        }
    }
}

@MainActor
public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    
    @AppStorage("app_accent_theme") public var selectedThemeName: String = AccentTheme.coral.rawValue {
        didSet {
            objectWillChange.send()
            SystemMonitor.shared.objectWillChange.send()
        }
    }
    
    public var currentTheme: AccentTheme {
        get { AccentTheme(rawValue: selectedThemeName) ?? .coral }
        set { selectedThemeName = newValue.rawValue }
    }
    
    public var coral: Color { currentTheme.primaryColor }
    public var coralMuted: Color { currentTheme.mutedColor }
    public var coralDark: Color { currentTheme.darkColor }
    public var purgeableColor: Color { currentTheme.purgeableColor }
}

public enum MectricsTheme {
    /// Dynamic Mectrics Accent Colors
    public static var coral: Color { ThemeManager.shared.coral }
    public static var coralMuted: Color { ThemeManager.shared.coralMuted }
    public static var coralDark: Color { ThemeManager.shared.coralDark }
    public static var purgeableColor: Color { ThemeManager.shared.purgeableColor }
    
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
