import AppKit
import HealthReminderCore
import QuartzCore

final class ReminderOverlayPresenter {
    private struct OverlayMessage {
        let title: String
        let body: String
    }

    private struct OverlayContent {
        let view: NSView
        let cardView: NSView
        let particleLayer: ParticleReconstructionLayer?
    }

    private let configuration: AppConfiguration.Overlay
    private var queue: [OverlayMessage] = []
    private var isShowing = false
    private var activeContent: OverlayContent?

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

        if let activeContent {
            activeContent.cardView.alphaValue = 0
            activeContent.particleLayer?.startGather()
            activeContent.cardView.layer?.transform = CATransform3DMakeScale(0.94, 0.94, 1)

            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleAnimation.fromValue = 0.94
            scaleAnimation.toValue = 1
            scaleAnimation.duration = max(configuration.fadeInSeconds, configuration.particleDurationSeconds)
            scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            activeContent.cardView.layer?.add(scaleAnimation, forKey: "scaleIn")
            activeContent.cardView.layer?.transform = CATransform3DIdentity
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = configuration.fadeInSeconds
            self.activeContent?.cardView.animator().alphaValue = 1
            panel.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + configuration.displaySeconds) {
            self.activeContent?.particleLayer?.startScatter()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = self.configuration.fadeOutSeconds
                self.activeContent?.cardView.animator().alphaValue = 0
                panel.animator().alphaValue = 0
            } completionHandler: {
                panel.close()
                self.activeContent = nil
                self.isShowing = false
                self.showNextIfNeeded()
            }
        }
    }

    private func makePanel(for message: OverlayMessage) -> NSPanel {
        let cardSize = NSSize(width: configuration.width, height: configuration.height)
        let padding = canvasPadding
        let canvasSize = NSSize(
            width: cardSize.width + padding * 2,
            height: cardSize.height + padding * 2
        )
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
        let content = makeContentView(for: message, cardSize: cardSize, padding: padding)
        activeContent = content
        panel.contentView = content.view

        return panel
    }

    private var shouldShowParticles: Bool {
        configuration.particleStyle != "off"
    }

    private var canvasPadding: CGFloat {
        shouldShowParticles ? CGFloat(configuration.particleCanvasPadding) : 0
    }

    private func makeContentView(
        for message: OverlayMessage,
        cardSize: NSSize,
        padding: CGFloat
    ) -> OverlayContent {
        let canvasSize = NSSize(width: cardSize.width + padding * 2, height: cardSize.height + padding * 2)
        let container = NSView(frame: NSRect(origin: .zero, size: canvasSize))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.layer?.masksToBounds = false

        let cardFrame = NSRect(x: padding, y: padding, width: cardSize.width, height: cardSize.height)
        let cardView = NSView(frame: cardFrame)
        cardView.wantsLayer = true
        cardView.layer?.backgroundColor = NSColor.clear.cgColor
        cardView.layer?.masksToBounds = false
        addBackgroundLayers(to: cardView, size: cardSize)

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

        cardView.addSubview(stackView)
        container.addSubview(cardView)

        let particleLayer: ParticleReconstructionLayer?
        if shouldShowParticles, let containerLayer = container.layer {
            let layer = ParticleReconstructionLayer(
                frame: NSRect(origin: .zero, size: canvasSize),
                cardFrame: cardFrame,
                particleCount: configuration.particleCount,
                particleScale: CGFloat(configuration.particleScale),
                gatherDuration: configuration.particleDurationSeconds,
                scatterDuration: max(configuration.fadeOutSeconds, configuration.particleDurationSeconds * 0.72),
                velocity: CGFloat(configuration.particleVelocity)
            )
            layer.zPosition = 30
            containerLayer.addSublayer(layer)
            particleLayer = layer
        } else {
            particleLayer = nil
        }

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            stackView.widthAnchor.constraint(equalTo: cardView.widthAnchor, constant: -56),
            titleLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            bodyLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor)
        ])

        return OverlayContent(view: container, cardView: cardView, particleLayer: particleLayer)
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

private final class ParticleReconstructionLayer: CALayer {
    private struct Particle {
        let layer: CALayer
        let startPosition: CGPoint
        let targetPosition: CGPoint
        let endPosition: CGPoint
    }

    private let particles: [Particle]
    private let gatherDuration: TimeInterval
    private let scatterDuration: TimeInterval

    init(
        frame: NSRect,
        cardFrame: NSRect,
        particleCount: Int,
        particleScale: CGFloat,
        gatherDuration: TimeInterval,
        scatterDuration: TimeInterval,
        velocity: CGFloat
    ) {
        self.gatherDuration = gatherDuration
        self.scatterDuration = scatterDuration
        self.particles = ParticleReconstructionLayer.makeParticles(
            frame: frame,
            cardFrame: cardFrame,
            count: particleCount,
            particleScale: particleScale,
            velocity: velocity
        )
        super.init()
        self.frame = frame
        masksToBounds = false

        for particle in particles {
            particle.layer.position = particle.startPosition
            particle.layer.opacity = 0
            addSublayer(particle.layer)
        }
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func startGather() {
        for (index, particle) in particles.enumerated() {
            let delay = Double(index % 24) * 0.006
            animate(
                particle: particle,
                from: particle.startPosition,
                to: particle.targetPosition,
                duration: gatherDuration,
                delay: delay,
                startingOpacity: 0,
                endingOpacity: 0.92,
                key: "particleGather"
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + gatherDuration + 0.15) {
            self.particles.forEach { $0.layer.opacity = 0 }
        }
    }

    func startScatter() {
        particles.forEach { particle in
            particle.layer.removeAllAnimations()
            particle.layer.position = particle.targetPosition
            particle.layer.opacity = 0.82
        }

        for (index, particle) in particles.enumerated() {
            let delay = Double(index % 18) * 0.004
            animate(
                particle: particle,
                from: particle.targetPosition,
                to: particle.endPosition,
                duration: scatterDuration,
                delay: delay,
                startingOpacity: 0.82,
                endingOpacity: 0,
                key: "particleScatter"
            )
        }
    }

    private func animate(
        particle: Particle,
        from startPosition: CGPoint,
        to endPosition: CGPoint,
        duration: TimeInterval,
        delay: TimeInterval,
        startingOpacity: Float,
        endingOpacity: Float,
        key: String
    ) {
        let beginTime = CACurrentMediaTime() + delay

        let positionAnimation = CABasicAnimation(keyPath: "position")
        positionAnimation.fromValue = startPosition
        positionAnimation.toValue = endPosition
        positionAnimation.duration = duration
        positionAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        positionAnimation.fillMode = .forwards
        positionAnimation.isRemovedOnCompletion = false

        let opacityAnimation = CAKeyframeAnimation(keyPath: "opacity")
        opacityAnimation.values = [startingOpacity, 0.95, endingOpacity]
        opacityAnimation.keyTimes = [0, 0.45, 1]
        opacityAnimation.duration = duration
        opacityAnimation.fillMode = .forwards
        opacityAnimation.isRemovedOnCompletion = false

        let group = CAAnimationGroup()
        group.animations = [positionAnimation, opacityAnimation]
        group.beginTime = beginTime
        group.duration = duration
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false

        particle.layer.add(group, forKey: key)
    }

    private static func makeParticles(
        frame: NSRect,
        cardFrame: NSRect,
        count: Int,
        particleScale: CGFloat,
        velocity: CGFloat
    ) -> [Particle] {
        let safeScale = max(0.012, particleScale)
        let particleSize = max(2.4, min(7.0, safeScale * 140))
        let colors = [
            NSColor(calibratedRed: 0.55, green: 0.82, blue: 1.0, alpha: 0.9),
            NSColor(calibratedRed: 0.68, green: 0.46, blue: 1.0, alpha: 0.78),
            NSColor(calibratedRed: 1.0, green: 0.75, blue: 0.35, alpha: 0.62),
            NSColor.white.withAlphaComponent(0.78)
        ]

        return (0..<count).map { index in
            let target = targetPoint(index: index, count: count, cardFrame: cardFrame)
            let start = outsidePoint(
                index: index,
                frame: frame,
                cardFrame: cardFrame
            )
            let end = outsidePoint(
                index: index + count / 3,
                frame: frame,
                cardFrame: cardFrame
            )
            let particleLayer = CALayer()
            particleLayer.bounds = CGRect(x: 0, y: 0, width: particleSize, height: particleSize)
            particleLayer.cornerRadius = particleSize / 2
            particleLayer.backgroundColor = colors[index % colors.count].cgColor
            particleLayer.shadowColor = colors[index % colors.count].cgColor
            particleLayer.shadowOpacity = 0.74
            particleLayer.shadowRadius = particleSize * 1.7
            particleLayer.shadowOffset = .zero

            return Particle(
                layer: particleLayer,
                startPosition: start,
                targetPosition: target,
                endPosition: end
            )
        }
    }

    private static func targetPoint(index: Int, count: Int, cardFrame: NSRect) -> CGPoint {
        let borderCount = Int(Double(count) * 0.62)

        if index < borderCount {
            let progress = CGFloat(index) / CGFloat(max(1, borderCount))
            return roundedRectPerimeterPoint(progress: progress, rect: cardFrame.insetBy(dx: 8, dy: 8))
        }

        let innerIndex = index - borderCount
        let innerCount = max(1, count - borderCount)
        let progress = CGFloat(innerIndex) / CGFloat(innerCount)
        let row = innerIndex % 3
        let x = cardFrame.minX + cardFrame.width * (0.22 + 0.56 * progress)
        let y = cardFrame.midY + CGFloat(row - 1) * 18

        return CGPoint(x: x, y: y)
    }

    private static func roundedRectPerimeterPoint(progress: CGFloat, rect: NSRect) -> CGPoint {
        let clampedProgress = progress.truncatingRemainder(dividingBy: 1)

        switch clampedProgress {
        case 0..<0.25:
            let local = clampedProgress / 0.25
            return CGPoint(x: rect.minX + rect.width * local, y: rect.maxY)
        case 0.25..<0.5:
            let local = (clampedProgress - 0.25) / 0.25
            return CGPoint(x: rect.maxX, y: rect.maxY - rect.height * local)
        case 0.5..<0.75:
            let local = (clampedProgress - 0.5) / 0.25
            return CGPoint(x: rect.maxX - rect.width * local, y: rect.minY)
        default:
            let local = (clampedProgress - 0.75) / 0.25
            return CGPoint(x: rect.minX, y: rect.minY + rect.height * local)
        }
    }

    private static func outsidePoint(
        index: Int,
        frame: NSRect,
        cardFrame: NSRect
    ) -> CGPoint {
        let side = index % 4
        let seed = CGFloat((index * 37) % 100) / 100
        let wobble = CGFloat(((index * 53) % 100) - 50) / 50
        let edgeInset: CGFloat = 10
        let innerGap: CGFloat = 28

        switch side {
        case 0:
            return CGPoint(
                x: frame.minX + edgeInset + max(0, cardFrame.minX - innerGap - edgeInset) * seed,
                y: frame.minY + frame.height * seed + wobble * 18
            )
        case 1:
            return CGPoint(
                x: cardFrame.maxX + innerGap + max(0, frame.maxX - cardFrame.maxX - innerGap - edgeInset) * seed,
                y: frame.minY + frame.height * seed + wobble * 18
            )
        case 2:
            return CGPoint(
                x: frame.minX + frame.width * seed + wobble * 18,
                y: cardFrame.maxY + innerGap + max(0, frame.maxY - cardFrame.maxY - innerGap - edgeInset) * seed
            )
        default:
            return CGPoint(
                x: frame.minX + frame.width * seed + wobble * 18,
                y: frame.minY + edgeInset + max(0, cardFrame.minY - innerGap - edgeInset) * seed
            )
        }
    }
}
