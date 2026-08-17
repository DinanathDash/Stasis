import AppKit
import SwiftUI

class NotchWindow: NSPanel {

    /// Shadow padding around the content to allow for drop shadows or glow effects.
    /// Increase if your content has large shadows.
    var shadowPadding: CGFloat = 20

    /// The width of the content area (excluding shadow padding).
    var contentWidth: CGFloat = 360

    /// The height of the content area (excluding shadow padding).
    var contentHeight: CGFloat = 140

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        canBecomeVisibleWithoutLogin = true
    }

    /// Show the notch overlay with the given SwiftUI content.
    ///
    /// The window is positioned at `CGShieldingWindowLevel` (above everything)
    /// centered at the top of the target screen, flush with the top edge.
    func showNotch<Content: View>(on screen: NSScreen, content: Content) {
        // Use maximum possible window level to guarantee appearing above all other HUDs like Alcove
        level = NSWindow.Level(rawValue: Int(Int32.max))
        collectionBehavior = [.stationary, .canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        // Use the entire screen width so the SwiftUI view can center itself naturally
        let totalWidth = screen.frame.width
        let totalHeight = contentHeight + shadowPadding

        let x = screen.frame.origin.x
        let y = screen.frame.origin.y + screen.frame.height - totalHeight
        setFrame(CGRect(x: x, y: y, width: totalWidth, height: totalHeight), display: false)

        let hosting = NSHostingView(rootView:
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        )
        hosting.translatesAutoresizingMaskIntoConstraints = false
        contentView = hosting

        alphaValue = 1
        orderFrontRegardless()
        TopWindowElevator.shared.elevate(window: self)
    }

    /// Show as a floating pill at the top of the screen (fallback for non-notch Macs).
    func showPill<Content: View>(on screen: NSScreen, content: Content) {
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Use the entire screen width to prevent clipping
        let totalWidth = screen.frame.width
        let totalHeight = contentHeight + shadowPadding
        
        let x = screen.frame.origin.x
        // Position below the menu bar
        let y = screen.visibleFrame.maxY - totalHeight - 10
        setFrame(CGRect(x: x, y: y, width: totalWidth, height: totalHeight), display: false)

        let hosting = NSHostingView(rootView:
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        )
        hosting.translatesAutoresizingMaskIntoConstraints = false
        contentView = hosting

        alphaValue = 1
        orderFrontRegardless()
        TopWindowElevator.shared.elevate(window: self)
    }

    /// Hide with a fade-out animation.
    func hideNotch(completion: (@Sendable () -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.orderOut(nil)
                completion?()
            }
        })
    }

    /// Whether the given screen has a hardware notch.
    static func hasNotch(screen: NSScreen) -> Bool {
        return screen.safeAreaInsets.top > 0
    }
}
