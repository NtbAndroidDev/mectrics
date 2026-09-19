import SwiftUI
import AppKit

public struct PopoverHeaderView: View {
    public let icon: String
    public let title: String
    public var rightText: String? = nil
    public var ringProgress: Double? = nil
    public var iconColor: Color? = nil
    public var onRefresh: (() -> Void)? = nil
    
    public init(
        icon: String,
        title: String,
        rightText: String? = nil,
        ringProgress: Double? = nil,
        iconColor: Color? = nil,
        onRefresh: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.rightText = rightText
        self.ringProgress = ringProgress
        self.iconColor = iconColor
        self.onRefresh = onRefresh
    }
    
    public var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor ?? MectricsTheme.coral)
                
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            if let onRefresh = onRefresh {
                PopoverRefreshButton(action: onRefresh)
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
    public var icon: String? = nil
    public var isHighlighted: Bool = false
    public var isCopyable: Bool = true
    
    @State private var isHovered = false
    @State private var justCopied = false
    
    public init(label: String, value: String, icon: String? = nil, isHighlighted: Bool = false, isCopyable: Bool = true) {
        self.label = label
        self.value = value
        self.icon = icon
        self.isHighlighted = isHighlighted
        self.isCopyable = isCopyable
    }
    
    public var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MectricsTheme.coral)
                    .frame(width: 14)
            }
            
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(MectricsTheme.textSecondary)
            
            Spacer()
            
            HStack(spacing: 5) {
                if justCopied {
                    Text(loc("Copied!"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(MectricsTheme.coral)
                        .transition(.scale.combined(with: .opacity))
                }
                
                Text(value)
                    .font(.system(size: 12, weight: isHighlighted ? .bold : .medium, design: .monospaced))
                    .foregroundStyle(isHighlighted ? MectricsTheme.coral : .white)
                
                if isCopyable && isHovered && !justCopied {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                        .foregroundStyle(MectricsTheme.textTertiary)
                        .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            guard isCopyable else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                justCopied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.2)) {
                    justCopied = false
                }
            }
        }
    }
}

public struct PopoverActionButton: View {
    public let icon: String
    public let title: String
    public let action: () -> Void
    
    @State private var isHovered = false
    
    public init(icon: String, title: String, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.action = action
    }
    
    public var body: some View {
        Button {
            StatusBarManager.shared.closeAllPopovers()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isHovered ? MectricsTheme.coral : .white)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 35)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.white.opacity(0.16) : Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isHovered ? MectricsTheme.coral.opacity(0.4) : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

public struct PopoverFooterView: View {
    @State private var isHoveredSettings = false
    @State private var isHoveredQuit = false
    
    public init(showingSettings: Binding<Bool>? = nil) {}
    
    public var body: some View {
        HStack {
            Button {
                StatusBarManager.shared.closeAllPopovers()
                AppState.shared.openSettings(tab: .menuBar)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                    Text(loc("Settings"))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(isHoveredSettings ? MectricsTheme.coral : MectricsTheme.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(isHoveredSettings ? MectricsTheme.coral.opacity(0.12) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .onHover { isHoveredSettings = $0 }
            
            Spacer()
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "power")
                        .font(.system(size: 11))
                    Text(loc("Quit"))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(isHoveredQuit ? Color(red: 1.0, green: 0.35, blue: 0.38) : MectricsTheme.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(isHoveredQuit ? Color.red.opacity(0.15) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .onHover { isHoveredQuit = $0 }
        }
        .padding(.top, 4)
    }
}

public struct PopoverRefreshButton: View {
    public let action: () -> Void
    @State private var isSpinning = false
    @State private var isHovered = false
    
    public init(action: @escaping () -> Void) {
        self.action = action
    }
    
    public var body: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isSpinning.toggle()
            }
            action()
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered ? MectricsTheme.coral : MectricsTheme.textSecondary)
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .padding(5)
                .background(isHovered ? Color.white.opacity(0.08) : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

public struct TopProcessRowView: View {
    public let pid: Int
    public let name: String
    public let percentText: String
    public let isHighLoad: Bool
    public let isMediumLoad: Bool
    public let icon: String
    
    @State private var isHovered = false
    @State private var isTerminated = false
    
    public init(
        pid: Int,
        name: String,
        percentText: String,
        isHighLoad: Bool,
        isMediumLoad: Bool,
        icon: String = "cpu"
    ) {
        self.pid = pid
        self.name = name
        self.percentText = percentText
        self.isHighLoad = isHighLoad
        self.isMediumLoad = isMediumLoad
        self.icon = icon
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isTerminated ? "xmark.octagon.fill" : icon)
                .font(.system(size: 9))
                .foregroundStyle(isTerminated ? Color.red : MectricsTheme.textTertiary)
            
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isTerminated ? MectricsTheme.textTertiary : MectricsTheme.textPrimary)
                .strikethrough(isTerminated)
                .lineLimit(1)
            
            Spacer()
            
            if isHovered && !isTerminated {
                Button {
                    let success = ProcessMonitor.shared.terminateProcess(pid: pid)
                    if success {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isTerminated = true
                        }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.red.opacity(0.85))
                }
                .buttonStyle(.plain)
                .help("Terminate process (PID \(pid))")
            }
            
            Text(isTerminated ? loc("Stopped") : percentText)
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(isTerminated ? Color.red : (isHighLoad ? MectricsTheme.coral : (isMediumLoad ? MectricsTheme.coralMuted : .white)))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isHighLoad ? MectricsTheme.coral.opacity(0.18) : Color.white.opacity(0.05))
                )
        }
        .padding(.vertical, 1.5)
        .padding(.horizontal, 4)
        .background(isHovered ? Color.white.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onHover { isHovered = $0 }
    }
}
