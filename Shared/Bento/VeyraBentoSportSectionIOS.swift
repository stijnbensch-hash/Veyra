// VeyraBentoSportSectionIOS.swift — iOS 17+ / macOS 14+
// Home-sectie "Sport", gevoed door het Sport-menu (via VeyraSportViewModel / SportMenuProvider).
// Vereist: VeyraBentoSportViews.swift, VeyraBentoSportModel.swift, VeyraBentoStyle.swift, VeyraBentoFocus.swift (VeyraPressStyle).
//
// Indeling:
//   iPhone (compact)   live/eerstvolgende kaart · glazen lijst "Vandaag & straks" · horizontale competitietegels
//   iPad (regular)     kaart | lijst naast elkaar, daaronder de competitietegels
//
// Bediening:
//   tik op wedstrijd    -> live: afspelen · straks: herinnering aan/uit (met haptiek)
//   lang indrukken      -> "Vanaf het begin" (als de zender terugkijken heeft) · herinnering
//   tik op competitie   -> onOpenCompetition

#if !os(tvOS)
import SwiftUI

struct SportSection: View {
    let model: VeyraSportViewModel
    let regular: Bool
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
        let rows = Array(model.fixtures(at: now, limit: 7, excluding: featured?.id).prefix(regular ? 5 : 4))
        let competitions = Array(model.competitions(at: now).prefix(8))

        VStack(alignment: .leading, spacing: 12) {
            VeyraHomeSectionHeader(title: "Sport", trailing: "\(live) live · \(coming) komende", compact: true)

            if regular {
                HStack(alignment: .top, spacing: 12) {
                    if let featured {
                        matchCard(featured, now: now).frame(maxWidth: .infinity).frame(height: 380)
                    }
                    fixturesPanel(rows, live: live, now: now).frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 12) {
                    if let featured {
                        matchCard(featured, now: now).aspectRatio(16.0 / 11.0, contentMode: .fit)
                    }
                    fixturesPanel(rows, live: live, now: now)
                }
            }

            if !competitions.isEmpty {
                if competitions.count <= (regular ? 4 : 2) {
                    // Weinig competities: gelijk verdeeld over de volle breedte.
                    HStack(spacing: 10) {
                        ForEach(competitions) { competition in
                            competitionButton(competition, now: now)
                                .frame(maxWidth: .infinity)
                                .frame(height: 96)
                        }
                    }
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(competitions) { competition in
                                competitionButton(competition, now: now)
                                    .frame(width: 150, height: 96)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    private func competitionButton(_ competition: SportCompetition, now: Date) -> some View {
        Button { onOpenCompetition(competition) } label: {
            VeyraCompetitionContent(competition: competition, now: now, compact: true)
        }
        .buttonStyle(VeyraPressStyle(cornerRadius: 18))
    }

    // MARK: Kaart

    private func matchCard(_ event: SportEvent, now: Date) -> some View {
        Button { primaryAction(event, now: now) } label: {
            VeyraLiveMatchContent(event: event, now: now, reminderOn: model.reminderIDs.contains(event.id), compact: true)
        }
        .buttonStyle(VeyraPressStyle())
        .contextMenu { menu(for: event, now: now) }
        .sensoryFeedback(.selection, trigger: model.reminderIDs.contains(event.id))
    }

    // MARK: Lijst

    private func fixturesPanel(_ rows: [SportEvent], live: Int, now: Date) -> some View {
        VStack(spacing: 0) {
            VeyraFixturesHeader(liveCount: live, compact: true)
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, event in
                if index > 0 { Divider().overlay(Color.white.opacity(0.08)).padding(.horizontal, 14) }
                Button { primaryAction(event, now: now) } label: {
                    VeyraFixtureRowContent(event: event, now: now, reminderOn: model.reminderIDs.contains(event.id), compact: true)
                }
                .buttonStyle(.plain)
                .contextMenu { menu(for: event, now: now) }
                .sensoryFeedback(.selection, trigger: model.reminderIDs.contains(event.id))
            }
            if rows.isEmpty {
                Text("Geen andere wedstrijden de komende 24 uur")
                    .font(.footnote)
                    .foregroundStyle(VeyraHomeStyle.dim)
                    .padding(16)
            }
        }
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(VeyraFrame.fill)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .veyraGlassSurface(cornerRadius: 22)
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

#if DEBUG
#Preview("Sport iPhone") {
    ScrollView {
        SportSection(model: VeyraSportViewModel(provider: MockSportProvider()), regular: false,
                     onPlay: { _, _ in }, onToggleReminder: { _, _ in }, onOpenCompetition: { _ in })
            .padding(16)
    }
    .background(VeyraHomeStyle.ink)
    .preferredColorScheme(.dark)
}
#endif

#endif
