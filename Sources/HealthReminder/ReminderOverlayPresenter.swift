import AppKit
import HealthReminderCore
import SwiftUI

final class ReminderOverlayPresenter {
    private struct OverlayMessage {
        let title: String
        let body: String
    }

    private let configuration: AppConfiguration.Overlay
    private var queue: [OverlayMessage] = []
    private var isShowing = false

    init(configuration: AppConfiguration.Overlay = .defaults) {
        self.configuration = configuration
    }

    func show(title: String, body: String) {
        DispatchQueue.main.async {
            self.queue.append(OverlayMessage(title: title, body: body))
            self.showNextIfNeeded()
        }
    }

    private func showNextIfNeeded() {
        guard !isShowing, !queue.isEmpty else {
            return
        }

        isShowing = true
        let message = queue.removeFirst()
        let cardSize = NSSize(width: configuration.width, height: configuration.height)
        let padding = shouldShowParticles ? effectiveParticleCanvasPadding : 0
        let canvasSize = NSSize(
            width: cardSize.width + padding * 2,
            height: cardSize.height + padding * 2
        )
        let panel = makePanel(canvasSize: canvasSize, cardSize: cardSize, padding: padding)

        let rootView = ReminderOverlayView(
            title: message.title,
            messageBody: message.body,
            configuration: configuration,
            cardSize: CGSize(width: cardSize.width, height: cardSize.height),
            canvasPadding: padding,
            particleCount: effectiveParticleCount,
            onFinished: { [weak self, weak panel] in
                panel?.close()
                self?.isShowing = false
                self?.showNextIfNeeded()
            }
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: canvasSize)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        panel.orderFrontRegardless()
    }

    private var shouldShowParticles: Bool {
        configuration.particleStyle != "off"
    }

    private var effectiveParticleCount: Int {
        if overlayThemeStyle.isLight,
           configuration.particleCount == AppConfiguration.defaults.overlay.particleCount {
            return 110
        }

        return configuration.particleCount
    }

    private var effectiveParticleCanvasPadding: CGFloat {
        if overlayThemeStyle.isLight,
           configuration.particleCanvasPadding == AppConfiguration.defaults.overlay.particleCanvasPadding {
            return 200
        }

        return CGFloat(configuration.particleCanvasPadding)
    }

    private var overlayThemeStyle: OverlayVisualStyle {
        OverlayVisualStyle(
            theme: configuration.theme,
            textStyle: configuration.textStyle,
            textSize: configuration.textSize
        )
    }

    private func makePanel(canvasSize: NSSize, cardSize: NSSize, padding: CGFloat) -> NSPanel {
        let frame = overlayFrame(canvasSize: canvasSize, cardSize: cardSize, padding: padding)
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isMovable = false
        panel.isOpaque = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating

        return panel
    }

    private func overlayFrame(canvasSize: NSSize, cardSize: NSSize, padding: CGFloat) -> NSRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let desiredCardCenterY: CGFloat

        switch configuration.position {
        case "center":
            desiredCardCenterY = screenFrame.midY
        default:
            desiredCardCenterY = screenFrame.midY + screenFrame.height * CGFloat(configuration.verticalOffsetRatio)
        }

        let safeMargin: CGFloat = 24
        let desiredOriginY = desiredCardCenterY - cardSize.height / 2 - padding
        let minY = screenFrame.minY + safeMargin
        let maxY = screenFrame.maxY - canvasSize.height - safeMargin
        let originY = min(max(desiredOriginY, minY), maxY)

        return NSRect(
            x: screenFrame.midX - canvasSize.width / 2,
            y: originY,
            width: canvasSize.width,
            height: canvasSize.height
        )
    }
}

private extension AppConfiguration.Overlay {
    static let defaults = AppConfiguration.defaults.overlay
}
