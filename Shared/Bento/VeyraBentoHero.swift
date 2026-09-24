// VeyraBentoHero.swift — tvOS 17+ (model staat in VeyraBentoHeroModel.swift)
// Prototype: hero als "levend kijkvenster"
//   rust:   beeld + clearlogo + één metaregel + dunne tijdlijn (nu / straks)
//   focus:  naar beneden -> glaslaag met speelduur, kwaliteit, bronstatus en acties
//
// Vervang de gemarkeerde plekken door jullie eigen types/styles:
//   - HeroChipStyle      -> VeyraFocusButtonStyle
//   - .ultraThinMaterial -> .veyraGlass(...)
//   - Color.cyan / .red  -> Veyra-kleurtokens
//   - HeroMoment / HeroContent -> mapping vanaf MediaItem / PlayableSource

import SwiftUI

#if os(tvOS)

// MARK: - Hero

private enum HeroField: Hashable {
    case moment(Int)
    case play
    case info
}

struct VeyraHeroView: View {
    let content: HeroContent
    var onPlay: (HeroMoment) -> Void
    var onInfo: (HeroMoment) -> Void = { _ in }

    @FocusState private var focus: HeroField?
    @State private var selected = 0

    private var moment: HeroMoment {
        content.moments[min(selected, content.moments.count - 1)]
    }
    private var revealed: Bool { focus == .play || focus == .info }
    private var accent: Color { moment.isLive ? .red : .cyan }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            backdrop
            gradient

            VStack(alignment: .leading, spacing: 20) {
                logo
                Text(moment.metaLine)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .id(moment.id)
                    .transition(.opacity)
                timeline
                detailsLayer
            }
            .animation(.easeInOut(duration: 0.4), value: moment.id)
            .padding(.horizontal, 80)
            .padding(.bottom, 60)
            .focusSection()
        }
        .ignoresSafeArea()
        .defaultFocus($focus, .moment(0))
        .onChange(of: focus) { _, new in
            if case .moment(let i)? = new { selected = i }
        }
        // Menu-knop: eerst terug naar de tijdlijn, pas daarna het scherm verlaten.
        .onExitCommand(perform: revealed ? { focus = .moment(selected) } : nil)
    }

    // MARK: Beeld

    private var backdrop: some View {
        GeometryReader { geo in
            ZStack {
                AsyncImage(url: moment.backdropURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color.black
                    }
                }
                .id(moment.id)
                .transition(.opacity)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .animation(.easeInOut(duration: 0.7), value: moment.id)
        }
    }

    private var gradient: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.45),
                .init(color: .black.opacity(revealed ? 0.92 : 0.7), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .animation(.easeInOut(duration: 0.35), value: revealed)
        .allowsHitTesting(false)
    }

    // MARK: Logo

    private var titleText: some View {
        Text(content.fallbackTitle)
            .font(.system(size: 64, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private var logo: some View {
        Group {
            if let url = content.logoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        titleText
                    }
                }
            } else {
                titleText
            }
        }
        // Vaste afmeting: de layout verspringt niet als het logo later laadt.
        .frame(width: 900, height: 140, alignment: .leading)
        .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
    }

    // MARK: Tijdlijn (nu / straks)

    private var timeline: some View {
        HStack(spacing: 16) {
            ForEach(Array(content.moments.enumerated()), id: \.element.id) { index, m in
                Button {
                    onPlay(m)   // één druk op select = direct afspelen / live kijken
                } label: {
                    chip(m)
                }
                .buttonStyle(HeroChipStyle(accent: m.isLive ? .red : .cyan))
                .focused($focus, equals: .moment(index))
                .frame(maxWidth: index == 0 ? 900 : 420)
            }
        }
    }

    private func chip(_ m: HeroMoment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if m.isLive {
                    Circle().fill(.red).frame(width: 10, height: 10)
                }
                Text(m.label)
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                Text(m.title)
                    .font(.callout)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            ProgressLine(progress: m.progress, accent: m.isLive ? .red : .cyan)
        }
    }

    // MARK: Glaslaag (alleen zichtbaar bij focus op de knoppen)
    // Blijft altijd in de hiërarchie (opacity, geen if), zodat focus er naartoe
    // kan navigeren en de layout niet verspringt.

    private var detailsLayer: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                if let runtime = moment.runtimeText {
                    Text(runtime)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                }
                HStack(spacing: 8) {
                    ForEach(moment.badges, id: \.self) { badge in
                        Text(badge)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.15), in: Capsule())
                    }
                }
            }

            Spacer(minLength: 0)

            Button { onPlay(moment) } label: {
                Label(moment.isLive ? "Kijk live" : "Afspelen", systemImage: "play.fill")
            }
            .buttonStyle(HeroChipStyle(accent: accent))
            .focused($focus, equals: .play)

            Button { onInfo(moment) } label: {
                Label("Info", systemImage: "info.circle")
            }
            .buttonStyle(HeroChipStyle(accent: accent))
            .focused($focus, equals: .info)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 40)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: revealed)
    }
}

// MARK: - Onderdelen

private struct ProgressLine: View {
    let progress: Double?
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25))
                if let p = progress {
                    Capsule()
                        .fill(accent)
                        .frame(width: geo.size.width * min(max(p, 0), 1))
                }
            }
        }
        .frame(height: 4)
    }
}

/// Eigen focusstijl. Vervang door VeyraFocusButtonStyle.
/// Volledig eigen rendering + focusEffectDisabled, zodat tvOS geen witte halo tekent.
private struct HeroChipStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        Inner(configuration: configuration, accent: accent)
            .focusEffectDisabled()
    }

    private struct Inner: View {
        let configuration: ButtonStyleConfiguration
        let accent: Color
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(isFocused ? 1 : 0.35)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(accent.opacity(isFocused ? 0.9 : 0), lineWidth: 2)
                )
                .scaleEffect(isFocused ? 1.04 : 1)
                .animation(.easeOut(duration: 0.18), value: isFocused)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Series") {
    VeyraHeroView(content: .previewSeries, onPlay: { _ in })
}

#Preview("Live TV") {
    VeyraHeroView(content: .previewLive, onPlay: { _ in })
}

#Preview("Film — hervatten") {
    VeyraHeroView(content: .previewMovie, onPlay: { _ in })
}

#Preview("Film — nog niet gestart") {
    VeyraHeroView(content: .previewMovieFresh, onPlay: { _ in })
}
#endif

#endif
