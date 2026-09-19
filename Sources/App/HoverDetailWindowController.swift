import AppKit
import SwiftUI

@MainActor
public final class HoverDetailWindowController: NSObject {
    public static let shared = HoverDetailWindowController()
    
    private var panel: NSPanel?
    private var hostingView: NSHostingView<HoverDetailView>?
    private var currentType: HoverDetailType?
    private weak var currentAnchorView: NSView?
    
    private var isMouseOverAnchor: Bool = false
    private var isMouseOverPanel: Bool = false
    private var dismissTimer: Timer?
    private var showTimer: Timer?
    
    public override init() {
        super.init()
        setupPanel()
    }
    
    private func setupPanel() {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 310, height: 260),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.alphaValue = 0.0
        p.isMovableByWindowBackground = false
        p.hidesOnDeactivate = false
        
        let container = HoverPanelContainerView(frame: p.contentView?.bounds ?? .zero)
        container.autoresizingMask = [.width, .height]
        
        let visualEffect = NSVisualEffectView(frame: container.bounds)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 14
        visualEffect.layer?.masksToBounds = true
        visualEffect.autoresizingMask = [.width, .height]
        container.addSubview(visualEffect, positioned: .below, relativeTo: nil)
        
        container.onMouseEntered = { [weak self] in
            self?.isMouseOverPanel = true
            self?.cancelDismiss()
        }
        container.onMouseExited = { [weak self] in
            self?.isMouseOverPanel = false
            self?.scheduleDismiss()
        }
        p.contentView = container
        self.panel = p
    }
    
    public func mouseEnteredAnchor(type: HoverDetailType, anchorView: NSView) {
        // If a full popover is already shown, do not display hover window
        if StatusBarManager.shared.hasActivePopover {
            return
        }
        
        isMouseOverAnchor = true
        cancelDismiss()
        
        // If already visible with different type, switch immediately without delay
        if panel?.alphaValue ?? 0 > 0.5 {
            show(type: type, anchorView: anchorView, animated: false)
            return
        }
        
        // Debounce slightly (90ms) to prevent accidental fast swipe triggers
        showTimer?.invalidate()
        showTimer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isMouseOverAnchor else { return }
                self.show(type: type, anchorView: anchorView, animated: true)
            }
        }
    }
    
    public func mouseExitedAnchor() {
        isMouseOverAnchor = false
        showTimer?.invalidate()
        showTimer = nil
        scheduleDismiss()
    }
    
    public func show(type: HoverDetailType, anchorView: NSView, animated: Bool = true) {
        guard let panel = panel else { return }
        
        // Prevent opening if popover is open
        if StatusBarManager.shared.hasActivePopover {
            hideImmediately()
            return
        }
        
        self.currentType = type
        self.currentAnchorView = anchorView
        
        // Setup SwiftUI View
        let view = HoverDetailView(monitor: SystemMonitor.shared, type: type)
        if let hView = hostingView {
            hView.rootView = view
        } else {
            let hView = NSHostingView(rootView: view)
            panel.contentView?.addSubview(hView)
            hView.translatesAutoresizingMaskIntoConstraints = false
            if let container = panel.contentView {
                NSLayoutConstraint.activate([
                    hView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    hView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    hView.topAnchor.constraint(equalTo: container.topAnchor),
                    hView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
                ])
            }
            self.hostingView = hView
        }
        
        // Layout and Position
        panel.layoutIfNeeded()
        updateWindowPosition(anchorView: anchorView)
        
        panel.orderFront(nil)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1.0
            }
        } else {
            panel.alphaValue = 1.0
        }
    }
    
    public func updateWindowPosition(anchorView: NSView) {
        guard let panel = panel,
              let window = anchorView.window,
              let screen = window.screen ?? NSScreen.main else { return }
        
        let anchorRectInWindow = anchorView.convert(anchorView.bounds, to: nil)
        let anchorScreenRect = window.convertToScreen(anchorRectInWindow)
        
        let panelSize = panel.frame.size
        var targetX = anchorScreenRect.midX - (panelSize.width / 2.0)
        let targetY = anchorScreenRect.minY - panelSize.height - 4
        
        let visibleFrame = screen.visibleFrame
        if targetX < visibleFrame.minX + 8 {
            targetX = visibleFrame.minX + 8
        } else if targetX + panelSize.width > visibleFrame.maxX - 8 {
            targetX = visibleFrame.maxX - panelSize.width - 8
        }
        
        panel.setFrameOrigin(NSPoint(x: targetX, y: targetY))
    }
    
    private func scheduleDismiss(delay: TimeInterval = 0.22) {
        cancelDismiss()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if !self.isMouseOverAnchor && !self.isMouseOverPanel {
                    self.hide()
                }
            }
        }
    }
    
    private func cancelDismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
    }
    
    public func hide(animated: Bool = true) {
        guard let panel = panel, panel.alphaValue > 0 else { return }
        
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.14
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0.0
            }, completionHandler: { [weak self] in
                Task { @MainActor in
                    guard let self = self, let panel = self.panel else { return }
                    if panel.alphaValue <= 0.05 {
                        panel.orderOut(nil)
                        self.currentType = nil
                        self.currentAnchorView = nil
                    }
                }
            })
        } else {
            panel.alphaValue = 0.0
            panel.orderOut(nil)
            currentType = nil
            currentAnchorView = nil
        }
    }
    
    public func hideImmediately() {
        cancelDismiss()
        showTimer?.invalidate()
        showTimer = nil
        isMouseOverAnchor = false
        isMouseOverPanel = false
        panel?.alphaValue = 0.0
        panel?.orderOut(nil)
        currentType = nil
        currentAnchorView = nil
    }
}

// MARK: - Container View with Mouse Tracking for the Hover Panel
fileprivate final class HoverPanelContainerView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onMouseEntered?()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onMouseExited?()
    }
}
