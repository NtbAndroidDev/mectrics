import SwiftUI
import AppKit

public struct PopoverHeaderView: View {
    public let icon: String
    public let title: String
    public var rightText: String? = nil
    public var ringProgress: Double? = nil
    public var onRefresh: (() -> Void)? = nil
    
    public init(
        icon: String,
        title: String,
        rightText: String? = nil,
        ringProgress: Double? = nil,
        onRefresh: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.rightText = rightText
        self.ringProgress = ringProgress
        self.onRefresh = onRefresh
    }
    
    public var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MectricsTheme.coral)
                
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            if let onRefresh = onRefresh {
                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MectricsTheme.textSecondary)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 8) {
                    if let ring = ringProgress {
                        ZStack {
                            Circle()
                                .stroke(MectricsTheme.trackBackground, lineWidth: 3)
                            Circle()
                                .trim(from: 0, to: CGFloat(max(0, min(1, ring))))
                                .stroke(MectricsTheme.coral, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 16, height: 16)
                    }
                    
                    if let text = rightText {
                        Text(text)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
}

public struct PopoverKeyValueRow: View {
    public let label: String
    public let value: String
    public var isHighlighted: Bool = false
    
    public init(label: String, value: String, isHighlighted: Bool = false) {
        self.label = label
        self.value = value
        self.isHighlighted = isHighlighted
    }
    
    public var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(MectricsTheme.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 12, weight: isHighlighted ? .bold : .medium, design: .monospaced))
                .foregroundStyle(isHighlighted ? MectricsTheme.coral : .white)
        }
        .padding(.vertical, 1.5)
    }
}

public struct PopoverActionButton: View {
    public let icon: String
    public let title: String
    public let action: () -> Void
    
    public init(icon: String, title: String, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

public struct PopoverFooterView: View {
    public init(showingSettings: Binding<Bool>? = nil) {}
    
    public var body: some View {
        HStack {
            Button {
                AppState.shared.openSettings(tab: .menuBar)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MectricsTheme.coral)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                    Text("Quit")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MectricsTheme.coral)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }
}
