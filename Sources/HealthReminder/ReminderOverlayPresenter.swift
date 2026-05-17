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
            startParticleGather(in: contentView)
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
            if let contentView = panel.contentView {
                self.startParticleScatter(in: contentView)
            }

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

    private func startParticleGather(in contentView: NSView) {
        guard shouldShowParticles, let layer = contentView.layer else {
            return
        }

        let emitter = makeParticleEmitter(in: contentView, mode: .gather)
        layer.addSublayer(emitter)

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

    private func startParticleScatter(in contentView: NSView) {
        guard shouldShowParticles, let layer = contentView.layer else {
            return
        }

        let emitter = makeParticleEmitter(in: contentView, mode: .scatter)
        layer.addSublayer(emitter)

        DispatchQueue.main.asyncAfter(deadline: .now() + min(0.35, configuration.particleDurationSeconds)) {
            emitter.birthRate = 0
        }
    }

    private enum ParticleMode {
        case gather
        case scatter
    }

    private var shouldShowParticles: Bool {
        configuration.particleStyle != "off"
    }

    private func makeParticleEmitter(in contentView: NSView, mode: ParticleMode) -> CAEmitterLayer {
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .circle
        emitter.emitterMode = .outline
        emitter.emitterPosition = CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)
        emitter.emitterSize = mode == .gather
            ? CGSize(width: contentView.bounds.width * 0.86, height: contentView.bounds.height * 0.9)
            : CGSize(width: 32, height: 32)
        emitter.beginTime = CACurrentMediaTime()
        emitter.birthRate = 1
        emitter.zPosition = 8

        let cell = CAEmitterCell()
        cell.birthRate = Float(configuration.particleBirthRate)
        cell.lifetime = Float(configuration.particleLifetimeSeconds)
        cell.lifetimeRange = Float(configuration.particleLifetimeSeconds * 0.25)
        cell.velocity = CGFloat(mode == .gather ? configuration.particleVelocity * 0.75 : configuration.particleVelocity * 1.15)
        cell.velocityRange = CGFloat(configuration.particleVelocity * 0.5)
        cell.emissionRange = .pi * 2
        cell.scale = CGFloat(configuration.particleScale)
        cell.scaleRange = CGFloat(configuration.particleScale * 0.65)
        cell.alphaSpeed = -0.85
        cell.contents = particleImage().cgImage(forProposedRect: nil, context: nil, hints: nil)
        cell.color = particleColor(for: mode).cgColor

        emitter.emitterCells = [cell]
        return emitter
    }

    private func particleColor(for mode: ParticleMode) -> NSColor {
        switch mode {
        case .gather:
            return NSColor(calibratedRed: 0.54, green: 0.82, blue: 1.0, alpha: 0.74)
        case .scatter:
            return NSColor(calibratedRed: 0.77, green: 0.46, blue: 1.0, alpha: 0.58)
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
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.layer?.masksToBounds = false

        addBackgroundLayers(to: container, size: size)

        let titleLabel = NSTextField(labelWithString: message.title)
        titleLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: 19, weight: .semibold)
        titleLabel.textColor = NSColor(calibratedRed: 0.92, green: 0.97, blue: 1.0, alpha: 0.96)
        titleLabel.maximumNumberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail

        let bodyLabel = NSTextField(labelWithString: message.body)
        bodyLabel.alignment = .center
        bodyLabel.font = .systemFont(ofSize: 14, weight: .regular)
        bodyLabel.textColor = NSColor(calibratedRed: 0.72, green: 0.8, blue: 0.9, alpha: 0.82)
        bodyLabel.maximumNumberOfLines = 2
        bodyLabel.lineBreakMode = .byTruncatingTail

        let stackView = NSStackView(views: [titleLabel, bodyLabel])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = 9
        stackView.wantsLayer = true
        stackView.layer?.zPosition = 20

        container.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stackView.widthAnchor.constraint(equalTo: container.widthAnchor, constant: -56),
            titleLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            bodyLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor)
        ])

        return container
    }

    private func addBackgroundLayers(to container: NSView, size: NSSize) {
        guard let layer = container.layer else {
            return
        }

        let bounds = NSRect(origin: .zero, size: size)
        let cornerRadius: CGFloat = min(28, size.height * 0.28)

        let glowLayer = CALayer()
        glowLayer.frame = bounds
        glowLayer.cornerRadius = cornerRadius
        glowLayer.backgroundColor = NSColor(calibratedRed: 0.04, green: 0.11, blue: 0.22, alpha: 0.56).cgColor
        glowLayer.borderColor = NSColor(calibratedRed: 0.36, green: 0.78, blue: 1.0, alpha: 0.42).cgColor
        glowLayer.borderWidth = 1.2
        glowLayer.shadowColor = NSColor(calibratedRed: 0.42, green: 0.28, blue: 1.0, alpha: 0.75).cgColor
        glowLayer.shadowOpacity = 0.62
        glowLayer.shadowRadius = 28
        glowLayer.shadowOffset = .zero
        glowLayer.zPosition = 0
        layer.addSublayer(glowLayer)

        let cardLayer = CAGradientLayer()
        cardLayer.frame = bounds
        cardLayer.cornerRadius = cornerRadius
        cardLayer.colors = [
            NSColor(calibratedRed: 0.02, green: 0.035, blue: 0.06, alpha: 0.93).cgColor,
            NSColor(calibratedRed: 0.035, green: 0.065, blue: 0.105, alpha: 0.88).cgColor,
            NSColor(calibratedRed: 0.025, green: 0.025, blue: 0.04, alpha: 0.94).cgColor
        ]
        cardLayer.locations = [0, 0.55, 1]
        cardLayer.startPoint = CGPoint(x: 0.08, y: 0.08)
        cardLayer.endPoint = CGPoint(x: 1, y: 1)
        cardLayer.borderColor = NSColor.white.withAlphaComponent(0.13).cgColor
        cardLayer.borderWidth = 1
        cardLayer.zPosition = 1
        layer.addSublayer(cardLayer)

        let edgeLayer = CAGradientLayer()
        edgeLayer.frame = bounds
        edgeLayer.cornerRadius = cornerRadius
        edgeLayer.colors = [
            NSColor(calibratedRed: 0.55, green: 0.38, blue: 1.0, alpha: 0.78).cgColor,
            NSColor(calibratedRed: 0.25, green: 0.8, blue: 1.0, alpha: 0.36).cgColor,
            NSColor(calibratedRed: 1.0, green: 0.73, blue: 0.28, alpha: 0.42).cgColor
        ]
        edgeLayer.startPoint = CGPoint(x: 0, y: 0.5)
        edgeLayer.endPoint = CGPoint(x: 1, y: 0.5)
        edgeLayer.opacity = 0.86
        edgeLayer.zPosition = 2
        let edgeMask = CAShapeLayer()
        edgeMask.path = CGPath(
            roundedRect: bounds.insetBy(dx: 1, dy: 1),
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        edgeMask.fillColor = NSColor.clear.cgColor
        edgeMask.strokeColor = NSColor.white.cgColor
        edgeMask.lineWidth = 2
        edgeLayer.mask = edgeMask
        layer.addSublayer(edgeLayer)
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
