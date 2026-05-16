import AppKit
import HealthReminderCore
import QuartzCore

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
        let panel = makePanel(for: message)

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        if let contentView = panel.contentView {
            startParticleAnimation(in: contentView)
            contentView.layer?.transform = CATransform3DMakeScale(0.92, 0.92, 1)

            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleAnimation.fromValue = 0.92
            scaleAnimation.toValue = 1
            scaleAnimation.duration = max(configuration.fadeInSeconds, configuration.particleDurationSeconds)
            scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            contentView.layer?.add(scaleAnimation, forKey: "scaleIn")
            contentView.layer?.transform = CATransform3DIdentity
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = configuration.fadeInSeconds
            panel.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + configuration.displaySeconds) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = self.configuration.fadeOutSeconds
                panel.animator().alphaValue = 0
            } completionHandler: {
                panel.close()
                self.isShowing = false
                self.showNextIfNeeded()
            }
        }
    }

    private func makePanel(for message: OverlayMessage) -> NSPanel {
        let size = NSSize(width: configuration.width, height: configuration.height)
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

    private func startParticleAnimation(in contentView: NSView) {
        guard configuration.particleStyle != "off", let layer = contentView.layer else {
            return
        }

        let emitter = CAEmitterLayer()
        emitter.emitterShape = .circle
        emitter.emitterMode = .outline
        emitter.emitterPosition = CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)
        emitter.emitterSize = CGSize(
            width: contentView.bounds.width * 0.75,
            height: contentView.bounds.height * 0.75
        )
        emitter.beginTime = CACurrentMediaTime()
        emitter.birthRate = 1
        emitter.zPosition = 0

        let cell = CAEmitterCell()
        cell.birthRate = Float(configuration.particleBirthRate)
        cell.lifetime = Float(configuration.particleLifetimeSeconds)
        cell.lifetimeRange = Float(configuration.particleLifetimeSeconds * 0.25)
        cell.velocity = CGFloat(configuration.particleVelocity)
        cell.velocityRange = CGFloat(configuration.particleVelocity * 0.35)
        cell.emissionRange = .pi * 2
        cell.scale = CGFloat(configuration.particleScale)
        cell.scaleRange = CGFloat(configuration.particleScale * 0.6)
        cell.alphaSpeed = -0.9
        cell.contents = particleImage().cgImage(forProposedRect: nil, context: nil, hints: nil)
        cell.color = NSColor(calibratedRed: 0.58, green: 0.95, blue: 0.86, alpha: 0.72).cgColor

        emitter.emitterCells = [cell]
        layer.insertSublayer(emitter, at: 0)

        let sizeAnimation = CABasicAnimation(keyPath: "emitterSize")
        sizeAnimation.fromValue = emitter.emitterSize
        sizeAnimation.toValue = CGSize(width: 24, height: 24)
        sizeAnimation.duration = configuration.particleDurationSeconds
        sizeAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        emitter.add(sizeAnimation, forKey: "particleGather")
        emitter.emitterSize = CGSize(width: 24, height: 24)

        DispatchQueue.main.asyncAfter(deadline: .now() + configuration.particleDurationSeconds) {
            emitter.birthRate = 0
        }
    }

    private func particleImage() -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)

        image.lockFocus()
        defer {
            image.unlockFocus()
        }

        let bounds = NSRect(origin: .zero, size: size)
        let gradient = NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.95),
            NSColor(calibratedRed: 0.58, green: 0.95, blue: 0.86, alpha: 0.35),
            .clear
        ])
        gradient?.draw(in: NSBezierPath(ovalIn: bounds), angle: 0)

        return image
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

private extension AppConfiguration.Overlay {
    static let defaults = AppConfiguration.defaults.overlay
}
