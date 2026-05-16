import AppKit
import QuartzCore

final class ReminderOverlayPresenter {
    private struct OverlayMessage {
        let title: String
        let body: String
    }

    private var queue: [OverlayMessage] = []
    private var isShowing = false

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
        let panel = makePanel(for: message)

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        if let contentView = panel.contentView {
            contentView.layer?.transform = CATransform3DMakeScale(0.92, 0.92, 1)

            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleAnimation.fromValue = 0.92
            scaleAnimation.toValue = 1
            scaleAnimation.duration = 0.45
            scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            contentView.layer?.add(scaleAnimation, forKey: "scaleIn")
            contentView.layer?.transform = CATransform3DIdentity
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            panel.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                panel.animator().alphaValue = 0
            } completionHandler: {
                panel.close()
                self.isShowing = false
                self.showNextIfNeeded()
            }
        }
    }

    private func makePanel(for message: OverlayMessage) -> NSPanel {
        let size = NSSize(width: 420, height: 132)
        let frame = centeredFrame(size: size)
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
        panel.contentView = makeContentView(for: message, size: size)

        return panel
    }

    private func makeContentView(for message: OverlayMessage, size: NSSize) -> NSView {
        let container = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        container.blendingMode = .behindWindow
        container.material = .hudWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 18
        container.layer?.masksToBounds = true
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        container.layer?.borderWidth = 1

        let titleLabel = NSTextField(labelWithString: message.title)
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .white.withAlphaComponent(0.94)
        titleLabel.maximumNumberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail

        let bodyLabel = NSTextField(labelWithString: message.body)
        bodyLabel.font = .systemFont(ofSize: 14, weight: .regular)
        bodyLabel.textColor = .white.withAlphaComponent(0.76)
        bodyLabel.maximumNumberOfLines = 2
        bodyLabel.lineBreakMode = .byTruncatingTail

        let stackView = NSStackView(views: [titleLabel, bodyLabel])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10

        container.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 28),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -28),
            stackView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func centeredFrame(size: NSSize) -> NSRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
