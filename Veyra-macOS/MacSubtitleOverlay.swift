import SwiftUI
import AetherEngine

struct MacSubtitleOverlay: View {
    @ObservedObject var engine: AetherEngine

    @AppStorage("veyra.subtitle.size") private var subtitleSizeRaw = "normal"
    @AppStorage("veyra.subtitle.position") private var subtitlePositionRaw = "low"
    @AppStorage("veyra.subtitle.background") private var subtitleBackgroundRaw = "subtle"
    @AppStorage("veyra.subtitle.shadow") private var subtitleShadow = true
    @AppStorage("veyra.subtitle.offset") private var subtitleOffset: Double = 0

    private var sizeMultiplier: CGFloat {
        switch subtitleSizeRaw {
        case "small": return 0.82
        case "large": return 1.22
        default: return 1.0
        }
    }

    private func bottomPadding(for height: CGFloat) -> CGFloat {
        switch subtitlePositionRaw {
        case "standard": return max(70, height * 0.075)
        case "high": return max(110, height * 0.13)
        default: return max(42, height * 0.045)
        }
    }

    private var backgroundOpacity: Double {
        switch subtitleBackgroundRaw {
        case "strong": return 0.70
        case "none": return 0
        default: return 0.42
        }
    }

    private var usesNativeRendering: Bool {
        engine.subtitleTracks.first { $0.id == engine.activeSubtitleTrackIndex }?
            .isNativelyRenderedSubtitle == true
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                let adjustedSourceTime = engine.sourceTime - subtitleOffset

                let cues =
                    engine.isSubtitleActive && !usesNativeRendering
                    ? engine.subtitleCues.filter {
                        $0.startTime <= adjustedSourceTime && adjustedSourceTime < $0.endTime
                    } : []

                ZStack {
                    ForEach(cues) { cue in
                        if case .image(let bitmap) = cue.body {
                            bitmapView(bitmap, in: geometry.size)
                        }
                    }

                    VStack {
                        Spacer(minLength: 0)

                        VStack(spacing: 6) {
                            ForEach(cues) { cue in
                                if let text = cue.text, !text.isEmpty {
                                    subtitleText(text, geometry: geometry)
                                }
                            }
                        }
                        .frame(maxWidth: geometry.size.width * 0.9)
                        .padding(.bottom, bottomPadding(for: geometry.size.height))
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .accessibilityHidden(true)
    }

    private func subtitleText(_ text: String, geometry: GeometryProxy) -> some View {
        let baseSize = max(16, geometry.size.height * 0.03)
        let fontSize = baseSize * sizeMultiplier

        return Text(text)
            .font(.system(size: fontSize, weight: .semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .shadow(
                color: subtitleShadow ? .black.opacity(0.95) : .clear,
                radius: subtitleShadow ? 4 : 0, x: 1, y: 2
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(backgroundOpacity))
            )
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bitmapView(_ bitmap: SubtitleImage, in size: CGSize) -> some View {
        let source =
            engine.sourceVideoWidth > 0 && engine.sourceVideoHeight > 0
            ? CGSize(width: CGFloat(engine.sourceVideoWidth), height: CGFloat(engine.sourceVideoHeight))
            : size

        let pixelAspect = CGFloat(engine.sourceVideoPixelAspectRatio)
        let safePixelAspect = pixelAspect > 0 ? pixelAspect : 1

        let videoScale = min(
            size.width / (source.width * safePixelAspect), size.height / source.height)

        let width = source.width * safePixelAspect * videoScale

        let canvas =
            bitmap.canvasSize.width > 0 && bitmap.canvasSize.height > 0 ? bitmap.canvasSize : source

        let height = canvas.height * width / (canvas.width * safePixelAspect)

        return Image(decorative: bitmap.cgImage, scale: 1).resizable()
            .frame(width: bitmap.position.width * width, height: bitmap.position.height * height)
            .position(
                x: (size.width - width) / 2 + bitmap.position.midX * width,
                y: (size.height - height) / 2 + bitmap.position.midY * height
            )
    }
}

