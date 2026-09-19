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
        // Only block menu bar hover if a full popover is already shown
        let isMenuBar = anchorView.window?.className.contains("StatusBar") ?? false
        if isMenuBar && StatusBarManager.shared.hasActivePopover {
            return
        }
        
        guard let window = anchorView.window else { return }
        let anchorRectInWindow = anchorView.convert(anchorView.bounds, to: nil)
        let anchorScreenRect = window.convertToScreen(anchorRectInWindow)
        
        mouseEnteredScreenRect(type: type, screenRect: anchorScreenRect, isSideAnchor: false)
    }
    
    public func mouseEnteredRow(type: HoverDetailType, screenRect: NSRect) {
        mouseEnteredScreenRect(type: type, screenRect: screenRect, isSideAnchor: true)
    }
    
    private func mouseEnteredScreenRect(type: HoverDetailType, screenRect: NSRect, isSideAnchor: Bool) {
        isMouseOverAnchor = true
        cancelDismiss()
        
        // If already visible, switch immediately without delay
        if panel?.alphaValue ?? 0 > 0.4 {
            showAtScreenRect(type: type, screenRect: screenRect, isSideAnchor: isSideAnchor, animated: false)
            return
        }
        
        showTimer?.invalidate()
        showTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isMouseOverAnchor else { return }
                self.showAtScreenRect(type: type, screenRect: screenRect, isSideAnchor: isSideAnchor, animated: true)
            }
        }
    }
    
    public func mouseExitedAnchor() {
        isMouseOverAnchor = false
        showTimer?.invalidate()
        showTimer = nil
        scheduleDismiss(delay: 0.20)
    }
    
    public func show(type: HoverDetailType, anchorView: NSView, animated: Bool = true) {
        guard let window = anchorView.window else { return }
        let anchorRectInWindow = anchorView.convert(anchorView.bounds, to: nil)
        let anchorScreenRect = window.convertToScreen(anchorRectInWindow)
        showAtScreenRect(type: type, screenRect: anchorScreenRect, isSideAnchor: false, animated: animated)
    }
    
    public func showAtScreenRect(type: HoverDetailType, screenRect: NSRect, isSideAnchor: Bool, animated: Bool = true) {
        guard let panel = panel else { return }
        
        self.currentType = type
        
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
        
        // Position panel
        panel.layoutIfNeeded()
        
        let screen = NSScreen.screens.first(where: { NSPointInRect(NSPoint(x: screenRect.midX, y: screenRect.midY), $0.frame) }) ?? NSScreen.main ?? NSScreen.screens[0]
        let panelSize = panel.frame.size
        
        var targetX: CGFloat
        var targetY: CGFloat
        
        if isSideAnchor {
            // Anchor to the side of the popover row (prefer left)
            if screenRect.minX - panelSize.width - 10 >= screen.visibleFrame.minX {
                targetX = screenRect.minX - panelSize.width - 10
            } else {
                targetX = screenRect.maxX + 10
            }
            targetY = screenRect.midY - (panelSize.height / 2.0)
        } else {
            targetX = screenRect.midX - (panelSize.width / 2.0)
            targetY = screenRect.minY - panelSize.height - 4
        }
        
        let visibleFrame = screen.visibleFrame
        if targetX < visibleFrame.minX + 8 {
            targetX = visibleFrame.minX + 8
        } else if targetX + panelSize.width > visibleFrame.maxX - 8 {
            targetX = visibleFrame.maxX - panelSize.width - 8
        }
        
        if targetY < visibleFrame.minY + 8 {
            targetY = visibleFrame.minY + 8
        } else if targetY + panelSize.height > visibleFrame.maxY - 8 {
            targetY = visibleFrame.maxY - panelSize.height - 8
        }
        
        panel.setFrameOrigin(NSPoint(x: targetX, y: targetY))
        panel.orderFront(nil)
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1.0
            }
        } else {
            panel.alphaValue = 1.0
        }
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
