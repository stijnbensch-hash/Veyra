// VeyraBentoHeroIOS.swift — iOS 17+ / macOS 14+
// Zelfde API als de tvOS-versie: VeyraHeroView(content:onPlay:onInfo:)
//
// Geen focus-engine, dus:
//   rust:      beeld + clearlogo + één metaregel + dunne tijdlijn (nu / straks)
//   tik op het beeld:  glaslaag met speelduur, kwaliteit, bronstatus en acties
//                      (klapt na 6 s vanzelf weer in; bij VoiceOver altijd zichtbaar)
//   tik op een chip:   niet-geselecteerd moment -> selecteren (crossfade)
//                      geselecteerd moment      -> direct afspelen / live kijken
//
// Vervang bij het inpassen:
//   - HeroChipStyle      -> jullie eigen knopstijl
//   - .ultraThinMaterial -> .veyraGlass(...)
//   - Color.cyan / .red  -> Veyra-kleurtokens

#if !os(tvOS)
import SwiftUI

struct VeyraHeroView: View {
    let content: HeroContent
    var height: CGFloat = 520
    var onPlay: (HeroMoment) -> Void
    var onInfo: (HeroMoment) -> Void = { _ in }

    @State private var selected = 0
    @State private var detailsShown = false
    @State private var collapseTask: Task<Void, Never>? = nil
    #if os(iOS)
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    #else
    private let voiceOver = false
    #endif

    private var moment: HeroMoment {
        content.moments[min(selected, content.moments.count - 1)]
    }
    private var revealed: Bool { detailsShown || voiceOver }
    private var accent: Color { moment.isLive ? .red : .cyan }
    private var playLabel: String {
        moment.isLive ? "Kijk live" : (moment.progress != nil ? "Verder kijken" : "Afspelen")
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            backdrop
            gradient

            VStack(alignment: .leading, spacing: 14) {
                logo
                Text(moment.metaLine)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .id(moment.id)
                    .transition(.opacity)
                timeline
                if revealed {
                    detailsLayer
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.4), value: moment.id)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { setDetails(!detailsShown) }
        .sensoryFeedback(.selection, trigger: selected)
        .onDisappear { collapseTask?.cancel() }
    }

    // MARK: Details tonen / verbergen

    private func setDetails(_ on: Bool) {
        collapseTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { detailsShown = on }
        guard on else { return }
        collapseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { detailsShown = false }
        }
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
                .init(color: .clear, location: 0.4),
                .init(color: .black.opacity(revealed ? 0.92 : 0.75), location: 1)
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
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(2)
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
        // Vaste hoogte: de layout verspringt niet als het logo later laadt.
        .frame(maxWidth: 280, minHeight: 72, maxHeight: 72, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .shadow(color: .black.opacity(0.5), radius: 10, y: 3)
    }

    // MARK: Tijdlijn (nu / straks)

    private var timeline: some View {
        HStack(spacing: 10) {
            ForEach(Array(content.moments.enumerated()), id: \.element.id) { index, m in
                Button {
                    if index == selected {
                        onPlay(m)
                    } else {
                        withAnimation(.easeInOut(duration: 0.4)) { selected = index }
                    }
                } label: {
                    chip(m)
                }
                .buttonStyle(HeroChipStyle(accent: m.isLive ? .red : .cyan,
                                           isSelected: index == selected))
                .frame(maxWidth: index == 0 ? CGFloat.infinity : 150)
                .accessibilityHint(index == selected ? "Speelt af" : "Toont dit moment")
            }
        }
    }

    private func chip(_ m: HeroMoment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if m.isLive {
                    Circle().fill(.red).frame(width: 8, height: 8)
                }
                Text(m.label)
                    .font(.caption2.weight(.bold))
                    .tracking(1)
            }
            Text(m.title)
                .font(.footnote)
                .lineLimit(1)
            ProgressLine(progress: m.progress, accent: m.isLive ? .red : .cyan)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Glaslaag

    private var detailsLayer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let runtime = moment.runtimeText {
                    Text(runtime)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                }
                ForEach(moment.badges, id: \.self) { badge in
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.15), in: Capsule())
                }
            }

            HStack(spacing: 10) {
                Button { onPlay(moment) } label: {
                    Label(playLabel, systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)

                Button { onInfo(moment) } label: {
                    Label("Info", systemImage: "info.circle")
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
            .controlSize(.large)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
        .frame(height: 3)
    }
}

private struct HeroChipStyle: ButtonStyle {
    let accent: Color
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(isSelected ? 1 : 0.4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(accent.opacity(isSelected ? 0.9 : 0), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
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
