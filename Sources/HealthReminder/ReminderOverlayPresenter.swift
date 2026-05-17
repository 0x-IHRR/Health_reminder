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
            context.duration = min(0.18, self.configuration.fadeInSeconds)
            panel.animator().alphaValue = 1
        }

        let cardDelay = shouldShowParticles ? configuration.particleDurationSeconds * 0.34 : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + cardDelay) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = max(self.configuration.fadeInSeconds, self.configuration.particleDurationSeconds * 0.45)
                self.activeContent?.cardView.animator().alphaValue = 1
            }
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
        shouldShowParticles ? effectiveParticleCanvasPadding : 0
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

    private var overlayThemeStyle: OverlayThemeStyle {
        OverlayThemeStyle(theme: configuration.theme)
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
        let style = overlayThemeStyle

        let cardFrame = NSRect(x: padding, y: padding, width: cardSize.width, height: cardSize.height)
        let cardView = NSView(frame: cardFrame)
        cardView.wantsLayer = true
        cardView.layer?.backgroundColor = NSColor.clear.cgColor
        cardView.layer?.masksToBounds = false
        cardView.layer?.zPosition = 10
        addBackgroundLayers(to: cardView, size: cardSize, style: style)

        let titleLabel = NSTextField(labelWithString: message.title)
        titleLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = style.titleColor
        titleLabel.maximumNumberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        let bodyLabel = NSTextField(labelWithString: message.body)
        bodyLabel.alignment = .center
        bodyLabel.font = .systemFont(ofSize: 14, weight: .regular)
        bodyLabel.textColor = style.bodyColor
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
                particleCount: effectiveParticleCount,
                particleScale: CGFloat(configuration.particleScale),
                gatherDuration: configuration.particleDurationSeconds,
                scatterDuration: max(configuration.fadeOutSeconds, configuration.particleDurationSeconds * 0.72),
                velocity: CGFloat(configuration.particleVelocity),
                style: style
            )
            layer.zPosition = 2
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

    private func addBackgroundLayers(to container: NSView, size: NSSize, style: OverlayThemeStyle) {
        guard let layer = container.layer else {
            return
        }

        let bounds = NSRect(origin: .zero, size: size)
        let cornerRadius: CGFloat = min(28, size.height * 0.28)

        let glowLayer = CALayer()
        glowLayer.frame = bounds
        glowLayer.cornerRadius = cornerRadius
        glowLayer.backgroundColor = style.glowFillColor.cgColor
        glowLayer.borderColor = style.outerBorderColor.cgColor
        glowLayer.borderWidth = 1
        glowLayer.shadowColor = style.shadowColor.cgColor
        glowLayer.shadowOpacity = style.shadowOpacity
        glowLayer.shadowRadius = style.shadowRadius
        glowLayer.shadowOffset = .zero
        glowLayer.zPosition = 0
        layer.addSublayer(glowLayer)

        let cardLayer = CAGradientLayer()
        cardLayer.frame = bounds
        cardLayer.cornerRadius = cornerRadius
        cardLayer.colors = style.cardGradientColors.map(\.cgColor)
        cardLayer.locations = [0, 0.58, 1]
        cardLayer.startPoint = CGPoint(x: 0.08, y: 0.08)
        cardLayer.endPoint = CGPoint(x: 1, y: 1)
        cardLayer.borderColor = style.innerBorderColor.cgColor
        cardLayer.borderWidth = 1
        cardLayer.zPosition = 1
        layer.addSublayer(cardLayer)

        let sheenLayer = CAGradientLayer()
        sheenLayer.frame = bounds.insetBy(dx: 18, dy: 14)
        sheenLayer.cornerRadius = max(0, cornerRadius - 10)
        sheenLayer.colors = style.sheenGradientColors.map(\.cgColor)
        sheenLayer.locations = [0, 0.48, 1]
        sheenLayer.startPoint = CGPoint(x: 0.1, y: 0.2)
        sheenLayer.endPoint = CGPoint(x: 0.95, y: 0.8)
        sheenLayer.opacity = style.sheenOpacity
        sheenLayer.zPosition = 2
        layer.addSublayer(sheenLayer)

        let edgeLayer = CAGradientLayer()
        edgeLayer.frame = bounds
        edgeLayer.cornerRadius = cornerRadius
        edgeLayer.colors = style.edgeGradientColors.map(\.cgColor)
        edgeLayer.startPoint = CGPoint(x: 0, y: 0.5)
        edgeLayer.endPoint = CGPoint(x: 1, y: 0.5)
        edgeLayer.opacity = style.edgeOpacity
        edgeLayer.zPosition = 3
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

private struct OverlayThemeStyle {
    let isLight: Bool
    let titleColor: NSColor
    let bodyColor: NSColor
    let glowFillColor: NSColor
    let outerBorderColor: NSColor
    let innerBorderColor: NSColor
    let shadowColor: NSColor
    let shadowOpacity: Float
    let shadowRadius: CGFloat
    let cardGradientColors: [NSColor]
    let sheenGradientColors: [NSColor]
    let sheenOpacity: Float
    let edgeGradientColors: [NSColor]
    let edgeOpacity: Float
    let particleColors: [NSColor]
    let particleShadowOpacity: Float
    let particlePeakOpacity: Float

    init(theme: String) {
        switch theme {
        case "light_particle":
            isLight = true
            titleColor = NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.22, alpha: 0.92)
            bodyColor = NSColor(calibratedRed: 0.32, green: 0.39, blue: 0.48, alpha: 0.78)
            glowFillColor = NSColor(calibratedRed: 0.88, green: 0.96, blue: 1.0, alpha: 0.24)
            outerBorderColor = NSColor(calibratedRed: 0.48, green: 0.82, blue: 1.0, alpha: 0.26)
            innerBorderColor = NSColor.white.withAlphaComponent(0.78)
            shadowColor = NSColor(calibratedRed: 0.38, green: 0.7, blue: 0.92, alpha: 0.46)
            shadowOpacity = 0.32
            shadowRadius = 26
            cardGradientColors = [
                NSColor(calibratedRed: 0.98, green: 1.0, blue: 1.0, alpha: 0.86),
                NSColor(calibratedRed: 0.91, green: 0.965, blue: 1.0, alpha: 0.76),
                NSColor(calibratedRed: 0.99, green: 0.985, blue: 0.96, alpha: 0.84)
            ]
            sheenGradientColors = [
                NSColor.white.withAlphaComponent(0.58),
                NSColor(calibratedRed: 0.68, green: 0.88, blue: 1.0, alpha: 0.12),
                NSColor.clear
            ]
            sheenOpacity = 0.72
            edgeGradientColors = [
                NSColor(calibratedRed: 0.42, green: 0.78, blue: 1.0, alpha: 0.38),
                NSColor(calibratedRed: 0.66, green: 0.54, blue: 1.0, alpha: 0.22),
                NSColor.white.withAlphaComponent(0.34)
            ]
            edgeOpacity = 0.58
            particleColors = [
                NSColor(calibratedRed: 0.34, green: 0.76, blue: 1.0, alpha: 0.64),
                NSColor(calibratedRed: 0.55, green: 0.58, blue: 0.96, alpha: 0.48),
                NSColor.white.withAlphaComponent(0.58),
                NSColor(calibratedRed: 0.96, green: 0.78, blue: 0.46, alpha: 0.36)
            ]
            particleShadowOpacity = 0.34
            particlePeakOpacity = 0.64
        default:
            isLight = false
            titleColor = NSColor(calibratedRed: 0.9, green: 0.96, blue: 1.0, alpha: 0.96)
            bodyColor = NSColor(calibratedRed: 0.64, green: 0.73, blue: 0.84, alpha: 0.78)
            glowFillColor = NSColor(calibratedRed: 0.02, green: 0.06, blue: 0.12, alpha: 0.48)
            outerBorderColor = NSColor(calibratedRed: 0.3, green: 0.68, blue: 1.0, alpha: 0.34)
            innerBorderColor = NSColor.white.withAlphaComponent(0.1)
            shadowColor = NSColor(calibratedRed: 0.36, green: 0.3, blue: 0.98, alpha: 0.68)
            shadowOpacity = 0.5
            shadowRadius = 32
            cardGradientColors = [
                NSColor(calibratedRed: 0.018, green: 0.028, blue: 0.05, alpha: 0.92),
                NSColor(calibratedRed: 0.03, green: 0.06, blue: 0.1, alpha: 0.86),
                NSColor(calibratedRed: 0.02, green: 0.025, blue: 0.04, alpha: 0.94)
            ]
            sheenGradientColors = [
                NSColor(calibratedRed: 0.34, green: 0.78, blue: 1.0, alpha: 0.14),
                NSColor(calibratedRed: 0.56, green: 0.42, blue: 1.0, alpha: 0.08),
                NSColor.clear
            ]
            sheenOpacity = 0.82
            edgeGradientColors = [
                NSColor(calibratedRed: 0.5, green: 0.36, blue: 1.0, alpha: 0.56),
                NSColor(calibratedRed: 0.24, green: 0.78, blue: 1.0, alpha: 0.38),
                NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.42, alpha: 0.24)
            ]
            edgeOpacity = 0.72
            particleColors = [
                NSColor(calibratedRed: 0.48, green: 0.8, blue: 1.0, alpha: 0.72),
                NSColor(calibratedRed: 0.64, green: 0.48, blue: 1.0, alpha: 0.58),
                NSColor.white.withAlphaComponent(0.58),
                NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.38, alpha: 0.34)
            ]
            particleShadowOpacity = 0.58
            particlePeakOpacity = 0.82
        }
    }
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
    private let themeStyle: OverlayThemeStyle

    init(
        frame: NSRect,
        cardFrame: NSRect,
        particleCount: Int,
        particleScale: CGFloat,
        gatherDuration: TimeInterval,
        scatterDuration: TimeInterval,
        velocity: CGFloat,
        style: OverlayThemeStyle
    ) {
        self.gatherDuration = gatherDuration
        self.scatterDuration = scatterDuration
        self.themeStyle = style
        self.particles = ParticleReconstructionLayer.makeParticles(
            frame: frame,
            cardFrame: cardFrame,
            count: particleCount,
            particleScale: particleScale,
            velocity: velocity,
            style: style
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
            let delay = Double((index * 7) % 31) * 0.006
            animate(
                particle: particle,
                from: particle.startPosition,
                to: particle.targetPosition,
                duration: gatherDuration,
                delay: delay,
                startingOpacity: 0,
                peakOpacity: themeStyle.particlePeakOpacity,
                endingOpacity: 0,
                key: "particleGather"
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + gatherDuration + 0.22) {
            self.particles.forEach { $0.layer.opacity = 0 }
        }
    }

    func startScatter() {
        particles.forEach { particle in
            particle.layer.removeAllAnimations()
            particle.layer.position = particle.targetPosition
            particle.layer.opacity = themeStyle.particlePeakOpacity * 0.72
        }

        for (index, particle) in particles.enumerated() {
            let delay = Double((index * 5) % 23) * 0.004
            animate(
                particle: particle,
                from: particle.targetPosition,
                to: particle.endPosition,
                duration: scatterDuration,
                delay: delay,
                startingOpacity: themeStyle.particlePeakOpacity * 0.72,
                peakOpacity: themeStyle.particlePeakOpacity,
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
        peakOpacity: Float,
        endingOpacity: Float,
        key: String
    ) {
        let beginTime = CACurrentMediaTime() + delay

        let positionAnimation = CAKeyframeAnimation(keyPath: "position")
        let path = CGMutablePath()
        path.move(to: startPosition)
        path.addQuadCurve(
            to: endPosition,
            control: controlPoint(from: startPosition, to: endPosition)
        )
        positionAnimation.path = path
        positionAnimation.duration = duration
        positionAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        positionAnimation.fillMode = .forwards
        positionAnimation.isRemovedOnCompletion = false

        let opacityAnimation = CAKeyframeAnimation(keyPath: "opacity")
        opacityAnimation.values = [startingOpacity, peakOpacity, peakOpacity * 0.34, endingOpacity]
        opacityAnimation.keyTimes = [0, 0.32, 0.72, 1]
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

    private func controlPoint(from startPosition: CGPoint, to endPosition: CGPoint) -> CGPoint {
        let mid = CGPoint(
            x: (startPosition.x + endPosition.x) / 2,
            y: (startPosition.y + endPosition.y) / 2
        )
        let dx = endPosition.x - startPosition.x
        let dy = endPosition.y - startPosition.y
        let length = max(1, sqrt(dx * dx + dy * dy))
        let bend = min(92, max(34, length * 0.16))

        return CGPoint(
            x: mid.x - dy / length * bend,
            y: mid.y + dx / length * bend
        )
    }

    private static func makeParticles(
        frame: NSRect,
        cardFrame: NSRect,
        count: Int,
        particleScale: CGFloat,
        velocity: CGFloat,
        style: OverlayThemeStyle
    ) -> [Particle] {
        let safeScale = max(0.012, particleScale)
        let particleSize = max(1.6, min(4.6, safeScale * 120))

        return (0..<count).map { index in
            let target = targetPoint(index: index, count: count, cardFrame: cardFrame)
            let start = outsidePoint(
                index: index,
                frame: frame,
                cardFrame: cardFrame,
                velocity: velocity
            )
            let end = outsidePoint(
                index: index + count / 3,
                frame: frame,
                cardFrame: cardFrame,
                velocity: velocity
            )
            let color = style.particleColors[index % style.particleColors.count]
            let particleLayer = CALayer()
            particleLayer.bounds = CGRect(x: 0, y: 0, width: particleSize, height: particleSize)
            particleLayer.cornerRadius = particleSize / 2
            particleLayer.backgroundColor = color.cgColor
            particleLayer.shadowColor = color.cgColor
            particleLayer.shadowOpacity = style.particleShadowOpacity
            particleLayer.shadowRadius = particleSize * 2.4
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
        let outlineCount = Int(Double(count) * 0.45)
        let cloudCount = Int(Double(count) * 0.35)
        let jitterX = CGFloat(((index * 47) % 100) - 50) / 50
        let jitterY = CGFloat(((index * 71) % 100) - 50) / 50

        if index < outlineCount {
            let progress = CGFloat((index * 17) % max(1, outlineCount)) / CGFloat(max(1, outlineCount))
            let point = roundedRectPerimeterPoint(progress: progress, rect: cardFrame.insetBy(dx: 10, dy: 10))
            return CGPoint(x: point.x + jitterX * 9, y: point.y + jitterY * 7)
        }

        if index < outlineCount + cloudCount {
            let innerIndex = index - outlineCount
            let angle = CGFloat(innerIndex) * 2.399963
            let radius = sqrt(CGFloat(innerIndex + 1) / CGFloat(max(1, cloudCount)))
            let xRadius = cardFrame.width * 0.34
            let yRadius = cardFrame.height * 0.25

            return CGPoint(
                x: cardFrame.midX + cos(angle) * radius * xRadius + jitterX * 8,
                y: cardFrame.midY + sin(angle) * radius * yRadius + jitterY * 6
            )
        }

        let textIndex = index - outlineCount - cloudCount
        let textCount = max(1, count - outlineCount - cloudCount)
        let progress = CGFloat(textIndex) / CGFloat(textCount)
        let row = textIndex % 2
        let x = cardFrame.minX + cardFrame.width * (0.27 + 0.46 * progress)
        let y = cardFrame.midY + CGFloat(row == 0 ? 16 : -16)

        return CGPoint(x: x + jitterX * 6, y: y + jitterY * 4)
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
        cardFrame: NSRect,
        velocity: CGFloat
    ) -> CGPoint {
        let side = index % 4
        let seed = CGFloat((index * 37) % 100) / 100
        let wobble = CGFloat(((index * 53) % 100) - 50) / 50
        let edgeInset: CGFloat = 10
        let innerGap = max(46, min(96, velocity * 1.35))

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
