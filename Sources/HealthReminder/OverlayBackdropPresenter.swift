import AppKit
import HealthReminderCore
import SwiftUI

final class OverlayBackdropPresenter {
    private let style: String
    private let opacity: Double
    private let fadeInSeconds: TimeInterval
    private let fadeOutSeconds: TimeInterval
    private let focusFrame: NSRect
    private var panels: [NSPanel] = []

    init(configuration: AppConfiguration.Overlay, focusFrame: NSRect) {
        self.style = configuration.backdropStyle
        self.opacity = configuration.backdropOpacity
        self.fadeInSeconds = configuration.fadeInSeconds
        self.fadeOutSeconds = configuration.fadeOutSeconds
        self.focusFrame = focusFrame
    }

    func show() {
        guard isEnabled else {
            return
        }

        panels = NSScreen.screens.map { screen in
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.backgroundColor = .clear
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.isMovable = false
            panel.isOpaque = false
            panel.isReleasedWhenClosed = false
            panel.level = .floating
            panel.alphaValue = 0

            let hostingView = NSHostingView(
                rootView: OverlayBackdropView(
                    style: style,
                    opacity: opacity,
                    screenFrame: screen.frame,
                    focusFrame: focusFrame
                )
            )
            hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor
            panel.contentView = hostingView
            panel.orderFrontRegardless()

            return panel
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeInSeconds
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for panel in panels {
                panel.animator().alphaValue = 1
            }
        }
    }

    func hideThenClose(completion: @escaping () -> Void) {
        guard !panels.isEmpty else {
            completion()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeOutSeconds
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for panel in panels {
                panel.animator().alphaValue = 0
            }
        } completionHandler: { [panels] in
            for panel in panels {
                panel.close()
            }
            completion()
        }
        panels.removeAll()
    }

    private var isEnabled: Bool {
        style != "off" && opacity > 0
    }
}

private struct OverlayBackdropView: View {
    let style: String
    let opacity: Double
    let screenFrame: NSRect
    let focusFrame: NSRect

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(opacity)

                if style == "dim_glow", screenFrame.intersects(focusFrame) {
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.13),
                            Color(red: 0.38, green: 0.68, blue: 1).opacity(0.08),
                            Color.clear
                        ],
                        center: focusCenter(),
                        startRadius: 18,
                        endRadius: 240
                    )
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
                }
            }
            .ignoresSafeArea()
        }
    }

    private func focusCenter() -> UnitPoint {
        let localX = (focusFrame.midX - screenFrame.minX) / max(screenFrame.width, 1)
        let localYFromBottom = (focusFrame.midY - screenFrame.minY) / max(screenFrame.height, 1)
        let clampedX = min(max(localX, 0), 1)
        let clampedY = min(max(1 - localYFromBottom, 0), 1)

        return UnitPoint(x: clampedX, y: clampedY)
    }
}
