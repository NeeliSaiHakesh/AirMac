import AppKit
import SwiftUI

/// AppKit Window Controller managing the top-right floating translucent hand skeleton HUD.
@MainActor
public final class FloatingOverlayController: NSObject {
    public static let shared = FloatingOverlayController()

    private var panel: NSPanel?
    private weak var appState: AppState?

    private override init() {
        super.init()
    }

    public func configure(with appState: AppState) {
        self.appState = appState
        if appState.showFloatingOverlay {
            showOverlay()
        }
    }

    public func showOverlay() {
        guard let appState = appState else { return }

        if panel == nil {
            let overlayView = FloatingHandView(appState: appState)
            let hostingView = NSHostingView(rootView: overlayView)

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 180, height: 140),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )

            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isMovableByWindowBackground = true
            panel.contentView = hostingView

            // Position at top-right corner with 24px padding
            if let screen = NSScreen.main {
                let screenRect = screen.visibleFrame
                let x = screenRect.maxX - 180 - 20
                let y = screenRect.maxY - 140 - 20
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }

            self.panel = panel
        }

        panel?.orderFront(nil)
    }

    public func hideOverlay() {
        panel?.orderOut(nil)
    }

    public func toggle(show: Bool) {
        if show {
            showOverlay()
        } else {
            hideOverlay()
        }
    }
}
