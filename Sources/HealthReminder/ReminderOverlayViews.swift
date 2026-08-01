import AppKit
import HealthReminderCore
import SwiftUI
import Vortex

enum ReminderOverlayPhase: Equatable {
    case entering
    case stable
    case exiting
}

enum ReminderCharacterLayout {
    static let horizontalPadding: CGFloat = 20

    static func topPadding(for cardSize: CGSize) -> CGFloat {
        min(max(cardSize.height * 1.05, 150), 230)
    }

    static func characterHeight(for cardSize: CGSize) -> CGFloat {
        min(max(cardSize.height * 3.8, 520), 880)
    }

    static func bottomPadding(for cardSize: CGSize) -> CGFloat {
        max(
            characterHeight(for: cardSize) - topPadding(for: cardSize) - cardSize.height,
            150
        )
    }

    static func compositionSize(for cardSize: CGSize) -> CGSize {
        return CGSize(
            width: cardSize.width,
            height: cardSize.height + topPadding(for: cardSize) + bottomPadding(for: cardSize)
        )
    }
}

struct ReminderOverlayView: View {
    let title: String
    let messageBody: String
    let configuration: AppConfiguration.Overlay
    let cardSize: CGSize
    let canvasSize: CGSize
    let particleCount: Int
    let onFinished: () -> Void

    @State private var phase: ReminderOverlayPhase = .entering
    @State private var cardOpacity = 0.0
    @State private var cardScale = 0.965
    @State private var cardOffsetY = 72.0
    @State private var cardRotation = -2.0

    private var style: OverlayVisualStyle {
        OverlayVisualStyle(
            theme: configuration.theme,
            textStyle: configuration.textStyle,
            textSize: configuration.textSize
        )
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
                    width: canvasSize.width,
                    height: canvasSize.height
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }

            CatHoldingReminderCardView(
                title: title,
                messageBody: messageBody,
                style: style,
                cardSize: cardSize
            )
            .frame(
                width: ReminderCharacterLayout.compositionSize(for: cardSize).width,
                height: ReminderCharacterLayout.compositionSize(for: cardSize).height
            )
            .opacity(cardOpacity)
            .scaleEffect(cardScale)
            .offset(y: cardOffsetY)
            .rotationEffect(.degrees(cardRotation))
        }
        .frame(
            width: canvasSize.width,
            height: canvasSize.height
        )
        .background(Color.clear)
        .onAppear(perform: startTimeline)
    }

    private func startTimeline() {
        let particleDuration = particlesEnabled ? configuration.particleDurationSeconds : 0
        let cardDelay = particlesEnabled ? particleDuration * 0.34 : 0
        let cardEntranceDuration = max(configuration.fadeInSeconds, particleDuration * 0.42, 0.62)

        DispatchQueue.main.asyncAfter(deadline: .now() + cardDelay) {
            withAnimation(.spring(response: cardEntranceDuration, dampingFraction: 0.74)) {
                cardOpacity = 1
                cardScale = 1
                cardOffsetY = 0
                cardRotation = 0
            }
        }

        let exitDelay = cardDelay + cardEntranceDuration + configuration.displaySeconds
        DispatchQueue.main.asyncAfter(deadline: .now() + exitDelay) {
            phase = .exiting
            withAnimation(.easeInOut(duration: configuration.fadeOutSeconds)) {
                cardOpacity = 0
                cardScale = 0.985
                cardOffsetY = 54
                cardRotation = 1.2
            }
        }

        let finishDelay = exitDelay + max(configuration.fadeOutSeconds, particleDuration) + 0.12
        DispatchQueue.main.asyncAfter(deadline: .now() + finishDelay) {
            onFinished()
        }
    }
}

struct ReminderOverlayPreviewView: View {
    let title: String
    let messageBody: String
    let configuration: AppConfiguration.Overlay

    private var cardSize: CGSize {
        CGSize(width: configuration.width, height: configuration.height)
    }

    private var contentSize: CGSize {
        let compositionSize = ReminderCharacterLayout.compositionSize(for: cardSize)
        return CGSize(width: compositionSize.width + 64, height: compositionSize.height + 32)
    }

    private var viewportSize: CGSize {
        CGSize(width: 484, height: 196)
    }

    private var previewScale: CGFloat {
        min(viewportSize.width / contentSize.width, viewportSize.height / contentSize.height, 1)
    }

    private var style: OverlayVisualStyle {
        OverlayVisualStyle(
            theme: configuration.theme,
            textStyle: configuration.textStyle,
            textSize: configuration.textSize
        )
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: style.cornerRadius + 20, style: .continuous)
                .fill(previewBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: style.cornerRadius + 20, style: .continuous)
                        .stroke(Color.white.opacity(style.isLight ? 0.52 : 0.08), lineWidth: 1)
                }
                .overlay {
                    if configuration.backdropStyle != "off" {
                        RoundedRectangle(cornerRadius: style.cornerRadius + 20, style: .continuous)
                            .fill(Color.black.opacity(min(configuration.backdropOpacity, 0.64)))
                    }
                }
                .overlay {
                    if configuration.backdropStyle == "dim_glow" {
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.14),
                                style.isAlert
                                    ? Color(red: 1, green: 0.72, blue: 0.04).opacity(0.18)
                                    : Color(red: 0.38, green: 0.68, blue: 1).opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: 170
                        )
                        .blendMode(.plusLighter)
                        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius + 20, style: .continuous))
                    }
                }

            CatHoldingReminderCardView(
                title: title,
                messageBody: messageBody,
                style: style,
                cardSize: cardSize
            )
            .frame(
                width: ReminderCharacterLayout.compositionSize(for: cardSize).width,
                height: ReminderCharacterLayout.compositionSize(for: cardSize).height
            )
        }
        .frame(width: contentSize.width, height: contentSize.height)
        .scaleEffect(previewScale)
        .frame(width: viewportSize.width, height: viewportSize.height)
    }

    private var previewBackground: LinearGradient {
        if style.isAlert {
            return LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.12, blue: 0.13),
                    Color(red: 0.04, green: 0.05, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if style.isLight {
            return LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.98, blue: 1),
                    Color(red: 0.88, green: 0.94, blue: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.07, blue: 0.12),
                Color(red: 0.08, green: 0.1, blue: 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct CatHoldingReminderCardView: View {
    let title: String
    let messageBody: String
    let style: OverlayVisualStyle
    let cardSize: CGSize

    private var topPadding: CGFloat {
        ReminderCharacterLayout.topPadding(for: cardSize)
    }

    private var compositionSize: CGSize {
        ReminderCharacterLayout.compositionSize(for: cardSize)
    }

    private var catSize: CGSize {
        let height = ReminderCharacterLayout.characterHeight(for: cardSize)
        return CGSize(
            width: height * 0.666,
            height: height
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            catImage

            OverlayCardView(
                title: title,
                messageBody: messageBody,
                style: style,
                cardSize: cardSize
            )
            .frame(width: cardSize.width, height: cardSize.height)
            .offset(y: topPadding)

            catImage
                .mask(alignment: .top) {
                    foregroundCatMask
                }
        }
        .frame(
            width: compositionSize.width,
            height: compositionSize.height,
            alignment: .top
        )
        .accessibilityElement(children: .contain)
    }

    private var foregroundCatMask: some View {
        let pawHeight = catSize.height * 0.044
        let pawWidth = catSize.width * 0.21
        let pawSpacing = catSize.width * 0.32

        return ZStack(alignment: .top) {
            Rectangle()
                .frame(maxWidth: .infinity)
                .frame(height: topPadding)

            HStack(spacing: pawSpacing) {
                RoundedRectangle(cornerRadius: pawHeight / 2, style: .continuous)
                    .frame(width: pawWidth, height: pawHeight)
                RoundedRectangle(cornerRadius: pawHeight / 2, style: .continuous)
                    .frame(width: pawWidth, height: pawHeight)
            }
            .offset(y: topPadding - pawHeight * 0.5)
        }
        .frame(width: catSize.width, height: catSize.height, alignment: .top)
    }

    private var catImage: some View {
        Image(nsImage: Self.characterImage)
            .resizable()
            .scaledToFit()
            .frame(width: catSize.width, height: catSize.height)
            .scaleEffect(x: 1.18, y: 1, anchor: .top)
            .accessibilityHidden(true)
    }

    private static let characterImage: NSImage = {
        let url = Bundle.main.url(
            forResource: "CatClimbCharacterBlue",
            withExtension: "png"
        ) ?? Bundle.module.url(
            forResource: "CatClimbCharacterBlue",
            withExtension: "png"
        )

        guard let url else {
            return NSImage()
        }

        return NSImage(contentsOf: url) ?? NSImage()
    }()
}

struct OverlayCardView: View {
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
                    .font(.system(size: style.titleFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(style.titleForegroundStyle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)

                Text(messageBody)
                    .font(.system(size: style.bodyFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(style.bodyForegroundStyle)
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

struct OverlayVisualStyle {
    let isLight: Bool
    let isAlert: Bool
    let textStyle: String
    let titleFontSize: CGFloat
    let bodyFontSize: CGFloat
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

    var titleForegroundStyle: AnyShapeStyle {
        if isAlert {
            switch textStyle {
            case "prism":
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.03, green: 0.12, blue: 0.18),
                            Color(red: 0.16, green: 0.08, blue: 0.2)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            case "aurora":
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.15, blue: 0.12),
                            Color(red: 0.11, green: 0.09, blue: 0.2)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            case "warm":
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.08, blue: 0.02),
                            Color(red: 0.08, green: 0.06, blue: 0.03)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            default:
                return AnyShapeStyle(titleColor)
            }
        }

        switch textStyle {
        case "prism":
            return AnyShapeStyle(
                LinearGradient(
                    colors: isLight
                        ? [
                            Color(red: 0.09, green: 0.23, blue: 0.34),
                            Color(red: 0.0, green: 0.42, blue: 0.62),
                            Color(red: 0.33, green: 0.27, blue: 0.72)
                        ]
                        : [
                            Color(red: 0.9, green: 0.98, blue: 1),
                            Color(red: 0.42, green: 0.83, blue: 1),
                            Color(red: 0.75, green: 0.62, blue: 1)
                        ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case "aurora":
            return AnyShapeStyle(
                LinearGradient(
                    colors: isLight
                        ? [
                            Color(red: 0.08, green: 0.22, blue: 0.34),
                            Color(red: 0.0, green: 0.42, blue: 0.64),
                            Color(red: 0.4, green: 0.24, blue: 0.76)
                        ]
                        : [
                            Color(red: 0.94, green: 0.99, blue: 1),
                            Color(red: 0.36, green: 0.84, blue: 1),
                            Color(red: 1.0, green: 0.72, blue: 0.38)
                        ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case "warm":
            return AnyShapeStyle(
                LinearGradient(
                    colors: isLight
                        ? [
                            Color(red: 0.78, green: 0.28, blue: 0.14),
                            Color(red: 0.36, green: 0.32, blue: 0.76)
                        ]
                        : [
                            Color(red: 1.0, green: 0.76, blue: 0.42),
                            Color(red: 0.72, green: 0.78, blue: 1.0)
                        ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        default:
            return AnyShapeStyle(titleColor)
        }
    }

    var bodyForegroundStyle: AnyShapeStyle {
        if isAlert {
            return AnyShapeStyle(bodyColor)
        }

        switch textStyle {
        case "aurora" where !isLight:
            return AnyShapeStyle(Color(red: 0.82, green: 0.9, blue: 1).opacity(0.9))
        case "warm" where isLight:
            return AnyShapeStyle(Color(red: 0.28, green: 0.3, blue: 0.34).opacity(0.88))
        default:
            return AnyShapeStyle(bodyColor)
        }
    }

    init(theme: String, textStyle: String, textSize: String) {
        self.textStyle = textStyle
        isAlert = theme == "alert_yellow"
        switch textSize {
        case "small":
            titleFontSize = 20
            bodyFontSize = 14
        case "large":
            titleFontSize = 36
            bodyFontSize = 24
        default:
            titleFontSize = 23
            bodyFontSize = 15.5
        }

        switch theme {
        case "alert_yellow":
            isLight = true
            cornerRadius = 34
            material = .thinMaterial
            titleColor = Color(red: 0.07, green: 0.07, blue: 0.06).opacity(0.98)
            bodyColor = Color(red: 0.12, green: 0.1, blue: 0.06).opacity(0.88)
            cardGradient = LinearGradient(
                colors: [
                    Color(red: 1, green: 0.96, blue: 0.1).opacity(0.98),
                    Color(red: 1, green: 0.78, blue: 0.02).opacity(0.98),
                    Color(red: 1, green: 0.55, blue: 0).opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            cardGradientOpacity = 1
            innerSheenGradient = LinearGradient(
                colors: [
                    Color.white.opacity(0.46),
                    Color(red: 1, green: 0.92, blue: 0.2).opacity(0.24),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            innerSheenOpacity = 0.86
            borderGradient = LinearGradient(
                colors: [
                    Color.white.opacity(0.82),
                    Color(red: 1, green: 0.58, blue: 0).opacity(0.9),
                    Color(red: 0.76, green: 0.28, blue: 0).opacity(0.62)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            hairlineColor = Color.black.opacity(0.14)
            shadowColor = Color.black.opacity(0.48)
            shadowRadius = 40
            shadowY = 20
            edgeGlowColor = Color(red: 1, green: 0.72, blue: 0.02).opacity(0.5)
            edgeGlowRadius = 30
            vortexGatherColors = .randomRamp(
                [
                    VortexSystem.Color(red: 1, green: 0.95, blue: 0.32, opacity: 0),
                    VortexSystem.Color(red: 1, green: 0.84, blue: 0.08, opacity: 0.82),
                    VortexSystem.Color(red: 1, green: 1, blue: 0.9, opacity: 0)
                ],
                [
                    VortexSystem.Color(red: 1, green: 0.56, blue: 0, opacity: 0),
                    VortexSystem.Color(red: 1, green: 0.66, blue: 0.02, opacity: 0.68),
                    VortexSystem.Color(red: 1, green: 0.93, blue: 0.58, opacity: 0)
                ],
                [
                    VortexSystem.Color(red: 1, green: 1, blue: 1, opacity: 0),
                    VortexSystem.Color(red: 1, green: 1, blue: 0.94, opacity: 0.56),
                    VortexSystem.Color(red: 1, green: 0.84, blue: 0.12, opacity: 0)
                ]
            )
            vortexScatterColors = vortexGatherColors
        case "light_particle":
            isLight = true
            cornerRadius = 34
            material = .ultraThinMaterial
            titleColor = Color(red: 0.12, green: 0.18, blue: 0.25).opacity(0.96)
            bodyColor = Color(red: 0.28, green: 0.36, blue: 0.45).opacity(0.86)
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
