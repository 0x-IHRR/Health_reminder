import AppKit
import HealthReminderCore
import SwiftUI
import Vortex

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
        OverlayVisualStyle(theme: configuration.theme)
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

private enum ReminderOverlayPhase: Equatable {
    case entering
    case stable
    case exiting
}

private struct ReminderOverlayView: View {
    let title: String
    let messageBody: String
    let configuration: AppConfiguration.Overlay
    let cardSize: CGSize
    let canvasPadding: CGFloat
    let particleCount: Int
    let onFinished: () -> Void

    @State private var phase: ReminderOverlayPhase = .entering
    @State private var cardOpacity = 0.0
    @State private var cardScale = 0.965

    private var style: OverlayVisualStyle {
        OverlayVisualStyle(theme: configuration.theme)
    }

    private var particlesEnabled: Bool {
        configuration.particleStyle != "off"
    }

    var body: some View {
        ZStack {
            if particlesEnabled {
                VortexParticleField(
                    phase: phase,
                    style: style,
                    particleCount: particleCount,
                    particleDuration: configuration.particleDurationSeconds,
                    particleScale: configuration.particleScale
                )
                .frame(
                    width: cardSize.width + canvasPadding * 2,
                    height: cardSize.height + canvasPadding * 2
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }

            OverlayCardView(
                title: title,
                messageBody: messageBody,
                style: style,
                cardSize: cardSize
            )
            .frame(width: cardSize.width, height: cardSize.height)
            .opacity(cardOpacity)
            .scaleEffect(cardScale)
        }
        .frame(
            width: cardSize.width + canvasPadding * 2,
            height: cardSize.height + canvasPadding * 2
        )
        .background(Color.clear)
        .onAppear(perform: startTimeline)
    }

    private func startTimeline() {
        let particleDuration = particlesEnabled ? configuration.particleDurationSeconds : 0
        let cardDelay = particlesEnabled ? particleDuration * 0.34 : 0
        let cardFadeDuration = max(configuration.fadeInSeconds, particleDuration * 0.42)

        DispatchQueue.main.asyncAfter(deadline: .now() + cardDelay) {
            withAnimation(.easeOut(duration: cardFadeDuration)) {
                cardOpacity = 1
                cardScale = 1
            }
        }

        let exitDelay = cardDelay + cardFadeDuration + configuration.displaySeconds
        DispatchQueue.main.asyncAfter(deadline: .now() + exitDelay) {
            phase = .exiting
            withAnimation(.easeInOut(duration: configuration.fadeOutSeconds)) {
                cardOpacity = 0
                cardScale = 0.985
            }
        }

        let finishDelay = exitDelay + max(configuration.fadeOutSeconds, particleDuration) + 0.12
        DispatchQueue.main.asyncAfter(deadline: .now() + finishDelay) {
            onFinished()
        }
    }
}

private struct OverlayCardView: View {
    let title: String
    let messageBody: String
    let style: OverlayVisualStyle
    let cardSize: CGSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(style.material)

            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(style.cardGradient)
                .opacity(style.cardGradientOpacity)

            RoundedRectangle(cornerRadius: style.cornerRadius - 14, style: .continuous)
                .fill(style.innerSheenGradient)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .opacity(style.innerSheenOpacity)

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(style.titleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)

                Text(messageBody)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(style.bodyColor)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: cardSize.width - 64)
            .padding(.horizontal, 32)
        }
        .overlay {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .stroke(style.borderGradient, lineWidth: 1.1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: style.cornerRadius - 1, style: .continuous)
                .stroke(style.hairlineColor, lineWidth: 0.6)
                .padding(1)
        }
        .shadow(color: style.shadowColor, radius: style.shadowRadius, x: 0, y: style.shadowY)
        .shadow(color: style.edgeGlowColor, radius: style.edgeGlowRadius, x: 0, y: 0)
        .compositingGroup()
    }
}

private struct VortexParticleField: View {
    let phase: ReminderOverlayPhase
    let style: OverlayVisualStyle
    let particleCount: Int
    let particleDuration: TimeInterval
    let particleScale: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VortexViewReader { proxy in
                    VortexView(gatherSystem, targetFrameRate: 45) {
                        particleSymbols
                    }
                    .opacity(phase == .entering ? 1 : 0)
                    .onAppear {
                        triggerGather(proxy: proxy, size: geometry.size)
                    }
                }

                VortexViewReader { proxy in
                    VortexView(scatterSystem, targetFrameRate: 45) {
                        particleSymbols
                    }
                    .opacity(phase == .exiting ? 1 : 0)
                    .onChange(of: phase) { _, newPhase in
                        if newPhase == .exiting {
                            triggerScatter(proxy: proxy, size: geometry.size)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var particleSymbols: some View {
        Circle()
            .fill(.white)
            .frame(width: 18, height: 18)
            .blur(radius: 0.7)
            .blendMode(.plusLighter)
            .tag("mist")

        Circle()
            .fill(.white)
            .frame(width: 9, height: 9)
            .blur(radius: 0.2)
            .blendMode(.plusLighter)
            .tag("spark")

        Capsule()
            .fill(.white)
            .frame(width: 15, height: 5)
            .blur(radius: 0.35)
            .blendMode(.plusLighter)
            .tag("streak")
    }

    private var gatherSystem: VortexSystem {
        VortexSystem(
            tags: ["mist", "spark", "streak"],
            position: [0.5, 0.5],
            shape: .ring(radius: 1.62),
            birthRate: 0,
            burstCount: max(40, particleCount),
            burstCountVariation: max(8, particleCount / 8),
            lifespan: particleDuration * 1.05,
            lifespanVariation: particleDuration * 0.2,
            speed: 0.04,
            speedVariation: 0.22,
            angleRange: .degrees(360),
            attractionStrength: 26,
            dampingFactor: 5.6,
            angularSpeedVariation: [0, 0, 2.4],
            colors: style.vortexGatherColors,
            size: max(0.1, particleScale * 7.0),
            sizeVariation: 0.16,
            sizeMultiplierAtDeath: 0.18,
            stretchFactor: 2.2
        )
    }

    private var scatterSystem: VortexSystem {
        VortexSystem(
            tags: ["mist", "spark", "streak"],
            position: [0.5, 0.5],
            shape: .ellipse(radius: 0.28),
            birthRate: 0,
            burstCount: max(32, Int(Double(particleCount) * 0.72)),
            burstCountVariation: max(6, particleCount / 10),
            lifespan: particleDuration * 0.9,
            lifespanVariation: particleDuration * 0.16,
            speed: 0.32,
            speedVariation: 0.42,
            angleRange: .degrees(360),
            attractionStrength: -13,
            dampingFactor: 0.8,
            angularSpeedVariation: [0, 0, 3.0],
            colors: style.vortexScatterColors,
            size: max(0.09, particleScale * 6.2),
            sizeVariation: 0.14,
            sizeMultiplierAtDeath: 0.45,
            stretchFactor: 3.2
        )
    }

    private func triggerGather(proxy: VortexProxy, size: CGSize) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            proxy.attractTo(CGPoint(x: size.width / 2, y: size.height / 2))
            proxy.burst()
        }
    }

    private func triggerScatter(proxy: VortexProxy, size: CGSize) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            proxy.attractTo(CGPoint(x: size.width / 2, y: size.height / 2))
            proxy.burst()
        }
    }
}

private struct OverlayVisualStyle {
    let isLight: Bool
    let cornerRadius: CGFloat
    let material: Material
    let titleColor: Color
    let bodyColor: Color
    let cardGradient: LinearGradient
    let cardGradientOpacity: Double
    let innerSheenGradient: LinearGradient
    let innerSheenOpacity: Double
    let borderGradient: LinearGradient
    let hairlineColor: Color
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowY: CGFloat
    let edgeGlowColor: Color
    let edgeGlowRadius: CGFloat
    let vortexGatherColors: VortexSystem.ColorMode
    let vortexScatterColors: VortexSystem.ColorMode

    init(theme: String) {
        switch theme {
        case "light_particle":
            isLight = true
            cornerRadius = 34
            material = .ultraThinMaterial
            titleColor = Color(red: 0.16, green: 0.22, blue: 0.3).opacity(0.94)
            bodyColor = Color(red: 0.36, green: 0.45, blue: 0.55).opacity(0.76)
            cardGradient = LinearGradient(
                colors: [
                    Color.white.opacity(0.72),
                    Color(red: 0.88, green: 0.96, blue: 1).opacity(0.48),
                    Color(red: 0.98, green: 0.96, blue: 0.91).opacity(0.36)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            cardGradientOpacity = 0.86
            innerSheenGradient = LinearGradient(
                colors: [
                    Color.white.opacity(0.72),
                    Color(red: 0.62, green: 0.86, blue: 1).opacity(0.16),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            innerSheenOpacity = 0.74
            borderGradient = LinearGradient(
                colors: [
                    Color.white.opacity(0.82),
                    Color(red: 0.42, green: 0.8, blue: 1).opacity(0.38),
                    Color(red: 0.62, green: 0.52, blue: 1).opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            hairlineColor = Color.white.opacity(0.7)
            shadowColor = Color(red: 0.32, green: 0.62, blue: 0.78).opacity(0.2)
            shadowRadius = 34
            shadowY = 16
            edgeGlowColor = Color(red: 0.48, green: 0.82, blue: 1).opacity(0.14)
            edgeGlowRadius = 18
            vortexGatherColors = .randomRamp(
                [
                    VortexSystem.Color(red: 0.78, green: 0.94, blue: 1, opacity: 0.0),
                    VortexSystem.Color(red: 0.35, green: 0.72, blue: 1, opacity: 0.52),
                    VortexSystem.Color(red: 0.98, green: 1, blue: 1, opacity: 0.0)
                ],
                [
                    VortexSystem.Color(red: 0.72, green: 0.58, blue: 1, opacity: 0.0),
                    VortexSystem.Color(red: 0.66, green: 0.62, blue: 1, opacity: 0.34),
                    VortexSystem.Color(red: 1, green: 1, blue: 1, opacity: 0.0)
                ]
            )
            vortexScatterColors = vortexGatherColors
        default:
            isLight = false
            cornerRadius = 34
            material = .thinMaterial
            titleColor = Color(red: 0.88, green: 0.94, blue: 1).opacity(0.96)
            bodyColor = Color(red: 0.66, green: 0.76, blue: 0.88).opacity(0.78)
            cardGradient = LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.14, blue: 0.22).opacity(0.84),
                    Color(red: 0.05, green: 0.1, blue: 0.17).opacity(0.82),
                    Color(red: 0.12, green: 0.13, blue: 0.22).opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            cardGradientOpacity = 0.9
            innerSheenGradient = LinearGradient(
                colors: [
                    Color(red: 0.42, green: 0.8, blue: 1).opacity(0.16),
                    Color(red: 0.58, green: 0.48, blue: 1).opacity(0.08),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            innerSheenOpacity = 0.76
            borderGradient = LinearGradient(
                colors: [
                    Color(red: 0.66, green: 0.5, blue: 1).opacity(0.42),
                    Color(red: 0.32, green: 0.78, blue: 1).opacity(0.34),
                    Color(red: 1, green: 0.78, blue: 0.44).opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            hairlineColor = Color.white.opacity(0.11)
            shadowColor = Color(red: 0.1, green: 0.18, blue: 0.32).opacity(0.42)
            shadowRadius = 36
            shadowY = 18
            edgeGlowColor = Color(red: 0.38, green: 0.68, blue: 1).opacity(0.2)
            edgeGlowRadius = 22
            vortexGatherColors = .randomRamp(
                [
                    VortexSystem.Color(red: 0.35, green: 0.74, blue: 1, opacity: 0.0),
                    VortexSystem.Color(red: 0.45, green: 0.82, blue: 1, opacity: 0.72),
                    VortexSystem.Color(red: 0.9, green: 0.98, blue: 1, opacity: 0.0)
                ],
                [
                    VortexSystem.Color(red: 0.62, green: 0.44, blue: 1, opacity: 0.0),
                    VortexSystem.Color(red: 0.68, green: 0.52, blue: 1, opacity: 0.54),
                    VortexSystem.Color(red: 0.95, green: 0.9, blue: 1, opacity: 0.0)
                ],
                [
                    VortexSystem.Color(red: 1, green: 0.72, blue: 0.38, opacity: 0.0),
                    VortexSystem.Color(red: 1, green: 0.76, blue: 0.42, opacity: 0.32),
                    VortexSystem.Color(red: 1, green: 0.92, blue: 0.74, opacity: 0.0)
                ]
            )
            vortexScatterColors = vortexGatherColors
        }
    }
}
