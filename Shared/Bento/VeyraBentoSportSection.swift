// VeyraBentoSportSection.swift — tvOS 17+
// Home-sectie "Sport", gevoed door het Sport-menu (via VeyraSportViewModel / SportMenuProvider).
// Vereist: VeyraBentoSportViews.swift, VeyraBentoSportModel.swift, VeyraBentoStyle.swift, VeyraBentoFocus.swift
//          (VeyraHomeFocus, VeyraTileStyle).
//
// Indeling (raster van 6 kolommen, 273 pt breed, 24 pt tussenruimte):
//   SPORT   uitgelichte wedstrijd (4 kol. x 472)  |  glazen lijst "Vandaag & straks" (2 kol.)
//           daaronder tot 6 competitietegels (1 kol. x 184)
//
// Bediening:
//   select op wedstrijd      -> live: afspelen · straks: herinnering aan/uit
//   lang indrukken           -> "Vanaf het begin" (als de zender terugkijken heeft) · herinnering
//   select op competitie     -> onOpenCompetition (spring naar het Sport-menu, gefilterd)
//
// Vervang bij het inpassen: VeyraTileStyle/VeyraRowStyle -> VeyraFocusButtonStyle, veyraGlassSurface -> .veyraGlass(...).

#if os(tvOS)
import SwiftUI

private enum TVSport {
    static let col: CGFloat = 273
    static let gap: CGFloat = 24
    static func span(_ n: Int) -> CGFloat { CGFloat(n) * col + CGFloat(n - 1) * gap }
    static let mainHeight: CGFloat = 472
}

// MARK: - Rijstijl (cyaan focus in het glazen paneel)

struct VeyraRowStyle: ButtonStyle {
    var cornerRadius: CGFloat = 20

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        Inner(configuration: configuration, cornerRadius: cornerRadius)
            .focusEffectDisabled()
    }

    private struct Inner: View {
        let configuration: ButtonStyleConfiguration
        let cornerRadius: CGFloat
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            configuration.label
                .background(isFocused ? VeyraHomeStyle.cyan.opacity(0.16) : Color.clear, in: shape)
                .overlay(shape.strokeBorder(VeyraFrame.active, lineWidth: 3).opacity(isFocused ? 1 : 0))
                .shadow(color: isFocused ? VeyraHomeStyle.cyan.opacity(0.3) : .clear, radius: 18)
                .opacity(configuration.isPressed ? 0.8 : 1)
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }
    }
}

// MARK: - Sport

struct SportSection: View {
    let model: VeyraSportViewModel
    var focus: FocusState<VeyraHomeFocus?>.Binding
    var onPlay: (SportEvent, SportPlayback) -> Void
    var onToggleReminder: (SportEvent, Bool) -> Void
    var onOpenCompetition: (SportCompetition) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(now: context.date)
        }
        .task { await model.runScoreRefresh() }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let live = model.liveEvents(at: now).count
        let coming = model.upcomingCount(at: now)
        let featured = model.featured(at: now)
        let rows = Array(model.fixtures(at: now, limit: 7, excluding: featured?.id).prefix(5))
        let competitions = Array(model.competitions(at: now).prefix(6))

        VStack(alignment: .leading, spacing: 18) {
            VeyraHomeSectionHeader(title: "Sport", trailing: "\(live) live · \(coming) komende")

            VStack(alignment: .leading, spacing: TVSport.gap) {
                HStack(alignment: .top, spacing: TVSport.gap) {
                    if let featured {
                        matchTile(featured, now: now)
                            .frame(width: TVSport.span(4), height: TVSport.mainHeight)
                    }
                    fixturesPanel(rows, live: live, now: now)
                        .frame(width: TVSport.span(2), height: TVSport.mainHeight)
                }

                if !competitions.isEmpty {
                    HStack(spacing: TVSport.gap) {
                        ForEach(competitions) { competition in
                            Button { onOpenCompetition(competition) } label: {
                                VeyraCompetitionContent(competition: competition, now: now)
                            }
                            .buttonStyle(VeyraTileStyle())
                            .focused(focus, equals: .competition(competition.id))
                            .frame(width: TVSport.span(1), height: 184)
                        }
                    }
                }
            }
        }
    }

    // MARK: Uitgelichte wedstrijd

    private func matchTile(_ event: SportEvent, now: Date) -> some View {
        Button { primaryAction(event, now: now) } label: {
            VeyraLiveMatchContent(event: event, now: now, reminderOn: model.reminderIDs.contains(event.id))
        }
        .buttonStyle(VeyraTileStyle())
        .focused(focus, equals: .sport(event.id))
        .contextMenu { menu(for: event, now: now) }
    }

    // MARK: Lijst

    private func fixturesPanel(_ rows: [SportEvent], live: Int, now: Date) -> some View {
        VStack(spacing: 0) {
            VeyraFixturesHeader(liveCount: live)
            VStack(spacing: 4) {
                ForEach(rows) { event in
                    Button { primaryAction(event, now: now) } label: {
                        VeyraFixtureRowContent(event: event, now: now, reminderOn: model.reminderIDs.contains(event.id))
                    }
                    .buttonStyle(VeyraRowStyle())
                    .focused(focus, equals: .sport(event.id))
                    .contextMenu { menu(for: event, now: now) }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(VeyraFrame.fill)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .veyraGlassSurface()
    }

    // MARK: Acties

    private func primaryAction(_ event: SportEvent, now: Date) {
        if event.isLive(at: now) {
            onPlay(event, .live)
        } else {
            let on = model.toggleReminder(event)
            onToggleReminder(event, on)
        }
    }

    @ViewBuilder
    private func menu(for event: SportEvent, now: Date) -> some View {
        if event.isLive(at: now) {
            Button { onPlay(event, .live) } label: { Label("Kijk live", systemImage: "play.fill") }
            if event.canCatchUp {
                Button { onPlay(event, .fromBeginning) } label: { Label("Vanaf het begin", systemImage: "backward.end.fill") }
            }
        } else if event.isPast(at: now) {
            if event.canCatchUp {
                Button { onPlay(event, .catchUp) } label: { Label("Terugkijken", systemImage: "clock.arrow.circlepath") }
            }
        } else {
            let on = model.reminderIDs.contains(event.id)
            Button {
                let enabled = model.toggleReminder(event)
                onToggleReminder(event, enabled)
            } label: {
                Label(on ? "Herinnering uit" : "Herinner mij", systemImage: on ? "bell.slash" : "bell")
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
private struct SportPreview: View {
    @State private var model = VeyraSportViewModel(provider: MockSportProvider())
    @FocusState private var focus: VeyraHomeFocus?

    var body: some View {
        SportSection(model: model, focus: $focus, onPlay: { _, _ in }, onToggleReminder: { _, _ in }, onOpenCompetition: { _ in })
            .padding(80)
            .background(VeyraHomeStyle.ink)
            .task { await model.load() }
    }
}

#Preview("Sport") { SportPreview() }
#endif

#endif
