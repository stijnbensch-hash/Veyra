// VeyraBentoSportSection.swift — tvOS 17+
// Home-sectie "Sport", gevoed door het Sport-menu (via VeyraSportViewModel / SportMenuProvider).
// Vereist: VeyraSportMatchCard.swift (kaart, cross-platform met tvOS-maten), VeyraBentoSportModel.swift,
//          VeyraBentoStyle.swift, VeyraBentoFocus.swift (VeyraHomeFocus).
//
// Indeling (dezelfde structuur als de iOS-Sport-sectie, zie VeyraBentoSportSectionIOS.swift, maar met
// tvOS-conventies: grotere 10-foot-kaarten + focus-navigatie i.p.v. een grid):
//   "Favorieten"        wedstrijden van favoriete teams, over alle competities heen -- horizontaal
//                        scrollbare rij focusbare kaarten, net als de andere tvOS bento-shelves
//                        (bv. "Nieuwe films" in VeyraBentoHome.swift).
//   per sport           (bv. "College Football") één horizontale rij per hoofdsport: de losse
//                        competitie-entries die tot dezelfde sport horen (bv. alle
//                        "College Football · <conference>") worden samengevoegd (zie
//                        `VeyraSportViewModel.sportGroupSections`), één subsectie per sport met
//                        minstens 1 relevante wedstrijd in een aangezette competitie.
//   kaart                klok+tijdstip linksboven, de twee teams (logo + naam) daaronder,
//                        onderaan een sport-icoon + competitie-label -- zie VeyraSportMatchCard,
//                        als Button met VeyraSportCardStyle (cyaan/rood focus-kader, net als voorheen).
//
// Focus: elke kaart krijgt `.focused(focus, equals: .sport(section: <rijtitel>, id: event.id))` --
// de rijtitel is nodig als onderdeel van de focus-identiteit, anders claimen twee kaarten in
// verschillende rijen dezelfde `.sport`-waarde zodra hetzelfde event-id in meerdere rijen voorkomt
// (interconference-wedstrijden, of ook in "Favorieten"), wat de Siri Remote-focus liet vastlopen.
//
// Bediening (ongewijzigd):
//   select op wedstrijd      -> live: afspelen · straks: herinnering aan/uit
//   lang indrukken           -> "Vanaf het begin" (als de zender terugkijken heeft) · herinnering

#if os(tvOS)
import SwiftUI

private enum TVSport {
    static let gap: CGFloat = 24
    static let rowSpacing: CGFloat = 32
}

// MARK: - Rijstijl (cyaan focus in het glazen paneel) -- ook gebruikt door VeyraBentoHome.swift

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

// MARK: - Kaartstijl (altijd zichtbaar cyaan/rood kader) -- gebruikt door de wedstrijdkaarten hieronder

struct VeyraSportCardStyle: ButtonStyle {
    var isLive: Bool
    var cornerRadius: CGFloat = 18

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        Inner(configuration: configuration, isLive: isLive, cornerRadius: cornerRadius)
            .focusEffectDisabled()
    }

    private struct Inner: View {
        let configuration: ButtonStyleConfiguration
        let isLive: Bool
        let cornerRadius: CGFloat
        @Environment(\.isFocused) private var isFocused

        private var tint: Color { isLive ? VeyraHomeStyle.live : VeyraHomeStyle.cyan }

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            configuration.label
                .background(isFocused ? tint.opacity(0.18) : Color.clear, in: shape)
                .overlay(shape.strokeBorder(tint.opacity(isFocused ? 1 : 0.85), lineWidth: isFocused ? 3 : 2))
                .shadow(color: isFocused ? tint.opacity(0.35) : .clear, radius: 16)
                .opacity(configuration.isPressed ? 0.85 : 1)
                .animation(.easeOut(duration: 0.15), value: isFocused)
                .scaleEffect(isFocused ? 1.04 : 1)
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
        // "Mijn teams": wedstrijden van favoriete teams, over alle competities heen -- daarna per
        // competitie ("College Football", ...) dezelfde kaartstijl, elk in een horizontaal scrollbare
        // rij focusbare kaarten. Vervangt de oude combinatie van één losse uitgelichte kaart + een
        // glazen "Vandaag & straks"-lijst + competitietegels.
        let favoriteIDs = SportsFavorites.ids()
        let myTeams = model.myTeamEvents(at: now, favoriteIDs: favoriteIDs, limit: 10)
        let sportGroups = model.sportGroupSections(at: now, limitPerGroup: 10)

        VStack(alignment: .leading, spacing: 18) {
            VeyraHomeSectionHeader(title: "Sport", trailing: "\(live) live · \(coming) komende")

            VStack(alignment: .leading, spacing: TVSport.rowSpacing) {
                if !myTeams.isEmpty {
                    matchRow(title: "Favorieten", events: myTeams, now: now)
                }

                ForEach(sportGroups, id: \.name) { section in
                    matchRow(title: section.name, events: section.events, now: now)
                }

                if myTeams.isEmpty && sportGroups.isEmpty {
                    Text("Geen wedstrijden gevonden")
                        .font(.title3)
                        .foregroundStyle(VeyraHomeStyle.dim)
                }
            }
        }
    }

    // MARK: Subsectie: kop + horizontaal scrollbare rij wedstrijdkaarten

    private func matchRow(title: String, events: [SportEvent], now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Zelfde stijl als "Filmcollecties" op Home: cyaan, dezelfde grootte.
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TVSport.gap) {
                    ForEach(events) { event in
                        Button { primaryAction(event, now: now) } label: {
                            VeyraSportMatchCard(event: event, now: now, reminderOn: model.reminderIDs.contains(event.id))
                        }
                        .buttonStyle(VeyraSportCardStyle(isLive: event.isLive(at: now)))
                        .focused(focus, equals: .sport(section: title, id: event.id))
                        .contextMenu { menu(for: event, now: now) }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
            .scrollClipDisabled()
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
