// VeyraBentoSportSectionIOS.swift — iOS 17+ / macOS 14+
// Home-sectie "Sport", gevoed door het Sport-menu (via VeyraSportViewModel / SportMenuProvider).
// Vereist: VeyraSportMatchCard.swift, VeyraBentoSportModel.swift, VeyraBentoStyle.swift, VeyraBentoFocus.swift (VeyraPressStyle),
//          SportsFavorites.swift (favoriete teams voor "Mijn teams").
//
// Indeling (naar het voorbeeld van een "gidsachtige" sport-widget uit een andere app):
//   "Favorieten"        wedstrijden van favoriete teams, over alle competities heen -- 2 kaarten
//                        naast elkaar (iPhone) of 4 (iPad), zelfde kaartstijl als hieronder.
//   per sport           (bv. "College Football") één rij per hoofdsport: de losse competitie-
//                        entries die tot dezelfde sport horen (bv. alle "College Football · <conference>")
//                        worden samengevoegd (zie `VeyraSportViewModel.sportGroupSections`), één
//                        subsectie per sport met minstens 1 relevante wedstrijd in een aangezette
//                        competitie.
//   kaart                klok+tijdstip linksboven, de twee teams (logo + naam) daaronder,
//                        onderaan een sport-icoon + competitie-label -- zie VeyraSportMatchCard.
//
// Bediening:
//   tik op wedstrijd    -> live: afspelen · straks: herinnering aan/uit (met haptiek)
//   lang indrukken      -> "Vanaf het begin" (als de zender terugkijken heeft) · herinnering
//
// tvOS blijft ongewijzigd bij de oude stijl (losse uitgelichte kaart + "Vandaag & straks"-lijst
// + competitietegels): zie VeyraBentoSportSection.swift, een apart bestand achter #if os(tvOS).

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
        // "Mijn teams": wedstrijden van favoriete teams, over alle competities heen -- daarna per
        // competitie ("College Football", ...) dezelfde kaartstijl. Vervangt de oude combinatie van
        // één losse uitgelichte kaart + een glazen "Vandaag & straks"-lijst.
        let favoriteIDs = SportsFavorites.ids()
        let myTeams = model.myTeamEvents(at: now, favoriteIDs: favoriteIDs, limit: regular ? 8 : 6)
        let sportGroups = model.sportGroupSections(at: now, limitPerGroup: regular ? 8 : 6)

        VStack(alignment: .leading, spacing: 20) {
            VeyraHomeSectionHeader(title: "Sport", trailing: "\(live) live · \(coming) komende", compact: true)

            if !myTeams.isEmpty {
                matchSection(title: "Favorieten", events: myTeams, now: now)
            }

            ForEach(sportGroups, id: \.name) { section in
                matchSection(title: section.name, events: section.events, now: now)
            }

            if myTeams.isEmpty && sportGroups.isEmpty {
                Text("Geen wedstrijden gevonden")
                    .font(.footnote)
                    .foregroundStyle(VeyraHomeStyle.dim)
            }
        }
    }

    // MARK: Subsectie: kop + horizontale rij van wedstrijdkaarten (één rij, opzij scrollen)

    private func matchSection(title: String, events: [SportEvent], now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(events) { event in
                        Button { primaryAction(event, now: now) } label: {
                            VeyraSportMatchCard(event: event, now: now, reminderOn: model.reminderIDs.contains(event.id))
                        }
                        .frame(width: regular ? 300 : 240)
                        .buttonStyle(VeyraPressStyle(cornerRadius: 16))
                        .contextMenu { menu(for: event, now: now) }
                        .sensoryFeedback(.selection, trigger: model.reminderIDs.contains(event.id))
                    }
                }
            }
        }
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
