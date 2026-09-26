// VeyraBentoSportModel.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Gegevenslaag voor de home-sectie "Sport".
// Vereist: VeyraBentoEPGModel.swift (EPGChannel, EPGProgram, SourceHealth), VeyraBentoHeroModel.swift,
//          VeyraBentoTrakt.swift (VeyraHomeFormat).
//
// Bron van de wedstrijden: het Sport-menu van Veyra zelf (zelfde data als de Sport-tab, geen aparte EPG-afleiding).
//   - SportMenuProvider: één closure die de data van het Sport-menu levert. Vertaal daar jullie
//     bestaande sportmodel naar [SportEvent] (teams, competitie, start/einde, zender, bronstatus, stand).
//   - Nog liever geen tweede fetch? Laat de Sport-tab en de home dezelfde VeyraSportViewModel delen en roep
//     `apply(events:)` aan zodra het Sport-menu nieuwe data heeft.
//   - Live stand/minuut: staan die in het Sport-menu, zet ze dan in SportEvent.score bij het vertalen.
//     Komt de stand uit een aparte bron, koppel dan optioneel een LiveScoreProviding.
//   - EPGSportProvider hieronder blijft alleen als vangnet voor als het Sport-menu leeg of offline is.
//     Die leidt teams/competitie heuristisch af uit EPG-titels (SportTitleParser).

import Foundation
import Observation

// MARK: - Modellen

nonisolated enum SportPlayback: Sendable { case live, fromBeginning, catchUp }

nonisolated struct SportScore: Equatable, Sendable {
    let home: Int
    let away: Int
    let minute: String?          // "63'" · "Rust" · "Einde"
    var text: String { "\(home)–\(away)" }
}

nonisolated struct SportEvent: Identifiable, Equatable, Sendable {
    let id: String               // EPGProgram.id van de gekozen zender
    let title: String            // "Club Brugge – Anderlecht"
    let home: String?
    let away: String?
    let competition: String?     // "Voetbal", "Formule 1", "Pro League", ...
    let start: Date
    let end: Date
    let channelID: String
    let channelNumber: Int
    let channelName: String
    let health: SourceHealth
    let canCatchUp: Bool
    var alternativeSources: Int
    var backdropURL: URL? = nil
    var score: SportScore? = nil
    /// Bron van waarheid over de fase. `.auto` leidt live/afgelopen af uit start en einde (EPG);
    /// het Sport-menu levert de echte fase en gebruikt `.live`, `.scheduled` of `.finished`.
    var phaseHint: PhaseHint = .auto
    var homeLogoURL: URL? = nil
    var awayLogoURL: URL? = nil
    /// Logo van de competitie/federatie (NFL, Champions League, ...), als zachte achtergrond.
    var leagueLogoURL: URL? = nil
    /// SF Symbol van de sport (bv. "american.football", "soccerball") -- gebruikt in de compacte
    /// wedstrijdkaarten ("Mijn teams" / per-competitie) van de iOS-Sport-sectie.
    var leagueSymbol: String? = nil
    /// `SportsTeam.id` van thuis/uit, als de bron een Sport-menu-wedstrijd is (`SportsMatch`).
    /// Gebruikt om "Mijn teams" te bepalen (vergelijking met `SportsFavorites`); `nil` bij EPG-afgeleide events.
    var homeTeamID: String? = nil
    var awayTeamID: String? = nil
    /// Extra live-situatie naast de resterende tijd, indien de bron dit levert
    /// (bv. "Eerste kwart", "3rd & 7", "Rust"). `nil` als onbekend.
    var situation: String? = nil

    enum PhaseHint: Sendable { case auto, live, scheduled, finished }

    var durationMinutes: Int { max(1, Int(end.timeIntervalSince(start) / 60)) }

    func isLive(at now: Date) -> Bool {
        switch phaseHint {
        case .live: return true
        case .scheduled, .finished: return false
        case .auto: return start <= now && now < end
        }
    }

    func isPast(at now: Date) -> Bool {
        switch phaseHint {
        case .finished: return true
        case .live, .scheduled: return false
        case .auto: return end <= now
        }
    }

    func progress(at now: Date) -> Double? {
        guard isLive(at: now) else { return nil }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return nil }
        return min(max(now.timeIntervalSince(start) / total, 0), 0.98)
    }

    func remainingMinutes(at now: Date) -> Int? {
        guard isLive(at: now), end > now else { return nil }
        return max(1, Int((end.timeIntervalSince(now) / 60).rounded(.up)))
    }

    var channelLabel: String? {
        channelName.isEmpty ? nil : (channelNumber > 0 ? "\(channelNumber) \(channelName)" : channelName)
    }

    /// "1–0 · 63' · nog 27 min" · "Live · nog 27 min" · "Vandaag 21:00 · 120 min"
    func metaLine(at now: Date) -> String {
        if isLive(at: now) {
            var parts: [String] = []
            if let score { parts.append(score.text); if let m = score.minute { parts.append(m) } } else { parts.append("Live") }
            if let r = remainingMinutes(at: now) { parts.append("nog \(r) min") }
            return parts.joined(separator: " · ")
        }
        if isPast(at: now) { return "Afgelopen" }
        return "\(VeyraHomeFormat.when(start, now: now)) · \(durationMinutes) min"
    }
}

nonisolated struct SportCompetition: Identifiable, Equatable, Sendable {
    var id: String { name }
    let name: String
    let liveCount: Int
    let eventCount: Int
    let nextStart: Date?
    var logoURL: URL? = nil
}

// MARK: - Bronnen

nonisolated protocol SportHomeProviding: Sendable {
    func events(from: Date, to: Date) async throws -> [SportEvent]
}

/// Optioneel: live stand en minuut per event-id. Koppel jullie sportdata-API hier.
nonisolated protocol LiveScoreProviding: Sendable {
    func scores(for events: [SportEvent]) async -> [String: SportScore]
}

// MARK: - Titelparser (heuristiek)

nonisolated enum SportTitleParser {
    struct Parsed { let title: String; let competition: String?; let home: String?; let away: String? }

    static func parse(_ raw: String) -> Parsed {
        var text = raw.trimmingCharacters(in: .whitespaces)
        var competition: String?

        // "Voetbal: Club Brugge – Anderlecht" -> competitie "Voetbal"
        if let range = text.range(of: ": "), text.distance(from: text.startIndex, to: range.lowerBound) <= 28 {
            competition = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let rest = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            // Alleen het voorvoegsel afknippen als er daarna twee teams staan.
            if teams(in: rest) != nil { text = rest }
        }
        if let (home, away) = teams(in: text) {
            return Parsed(title: "\(home) – \(away)", competition: competition, home: home, away: away)
        }
        return Parsed(title: raw, competition: competition, home: nil, away: nil)
    }

    private static func teams(in text: String) -> (String, String)? {
        for separator in [" – ", " - ", " vs ", " v ", " tegen "] {
            let parts = text.components(separatedBy: separator)
            if parts.count == 2 {
                let a = parts[0].trimmingCharacters(in: .whitespaces)
                let b = parts[1].trimmingCharacters(in: .whitespaces)
                if !a.isEmpty, !b.isEmpty { return (a, b) }
            }
        }
        return nil
    }
}

// MARK: - Sport-menu-provider (primaire bron)

/// Levert de wedstrijden uit het bestaande Sport-menu. De closure krijgt het gevraagde venster mee
/// en mag ruimer teruggeven; het filteren op venster gebeurt hier.
///
///     let provider = SportMenuProvider { from, to in
///         try await sportMenuStore.fixtures(from: from, to: to).map { fixture in
///             SportEvent(id: fixture.id, title: "\(fixture.home) – \(fixture.away)",
///                        home: fixture.home, away: fixture.away, competition: fixture.league,
///                        start: fixture.kickoff, end: fixture.expectedEnd,
///                        channelID: fixture.channel.id, channelNumber: fixture.channel.number,
///                        channelName: fixture.channel.name, health: fixture.channel.health,
///                        canCatchUp: fixture.hasCatchUp, alternativeSources: fixture.alternatives.count,
///                        backdropURL: fixture.imageURL,
///                        score: fixture.liveScore.map { SportScore(home: $0.home, away: $0.away, minute: $0.minute) })
///         }
///     }
nonisolated struct SportMenuProvider: SportHomeProviding {
    let fetch: @Sendable (_ from: Date, _ to: Date) async throws -> [SportEvent]

    func events(from: Date, to: Date) async throws -> [SportEvent] {
        try await fetch(from, to)
            .filter { $0.end > from && $0.start < to }
            .sorted { ($0.start, $0.channelNumber) < ($1.start, $1.channelNumber) }
    }
}

/// Probeert eerst het Sport-menu; bij een fout of lege lijst valt hij terug op een tweede bron (bijv. EPG).
nonisolated struct FallbackSportProvider: SportHomeProviding {
    let primary: any SportHomeProviding
    let fallback: any SportHomeProviding

    func events(from: Date, to: Date) async throws -> [SportEvent] {
        if let events = try? await primary.events(from: from, to: to), !events.isEmpty { return events }
        return try await fallback.events(from: from, to: to)
    }
}

// MARK: - EPG-provider (vangnet)

nonisolated struct EPGSportProvider: SportHomeProviding {
    /// Geef de actuele zenders + programma's terug (bijv. uit jullie EPG-store).
    let channels: @Sendable () async -> [EPGChannel]

    func events(from: Date, to: Date) async throws -> [SportEvent] {
        let all = await channels()
        var raw: [SportEvent] = []
        for channel in all {
            for program in channel.programs where program.isSports && program.end > from && program.start < to {
                let parsed = SportTitleParser.parse(program.title)
                raw.append(SportEvent(
                    id: program.id, title: parsed.title, home: parsed.home, away: parsed.away,
                    competition: parsed.competition, start: program.start, end: program.end,
                    channelID: channel.id, channelNumber: channel.number, channelName: channel.name,
                    health: channel.health, canCatchUp: program.canCatchUp, alternativeSources: 0,
                    backdropURL: program.backdropURL))
            }
        }

        // Dezelfde wedstrijd op meerdere zenders -> één event met de gezondste zender.
        let grouped = Dictionary(grouping: raw) { "\($0.title.lowercased())|\(Int($0.start.timeIntervalSince1970))" }
        var out: [SportEvent] = grouped.values.map { group in
            let ranked = group.sorted {
                if Self.rank($0.health) != Self.rank($1.health) { return Self.rank($0.health) < Self.rank($1.health) }
                return $0.channelNumber < $1.channelNumber
            }
            var best = ranked[0]
            best.alternativeSources = group.dropFirst().filter { $0.health != .down }.count
            return best
        }
        out.sort { ($0.start, $0.channelNumber) < ($1.start, $1.channelNumber) }
        return out
    }

    private static func rank(_ health: SourceHealth) -> Int {
        switch health { case .good: return 0; case .degraded: return 1; case .down: return 2 }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class VeyraSportViewModel {
    enum Phase: Equatable { case idle, loading, loaded, failed(String) }

    private(set) var events: [SportEvent] = []
    private(set) var phase: Phase = .idle
    private(set) var reminderIDs: Set<String> = []

    @ObservationIgnored private let provider: any SportHomeProviding
    @ObservationIgnored private let scoreProvider: (any LiveScoreProviding)?

    init(provider: any SportHomeProviding, scores: (any LiveScoreProviding)? = nil, reminders: Set<String> = []) {
        self.provider = provider
        self.scoreProvider = scores
        self.reminderIDs = reminders
    }

    func load(now: Date = .now) async {
        phase = .loading
        do {
            events = try await provider.events(from: now.addingTimeInterval(-4 * 3600),
                                               to: now.addingTimeInterval(48 * 3600))
            phase = .loaded
            await refreshScores(now: now)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Neem data over die het Sport-menu al geladen heeft (geen tweede fetch nodig).
    func apply(events newEvents: [SportEvent], now: Date = .now) {
        events = newEvents.sorted { ($0.start, $0.channelNumber) < ($1.start, $1.channelNumber) }
        phase = .loaded
    }

    /// Vernieuwt de wedstrijden zonder de sectie te laten knipperen; bij een fout blijven de vorige data staan.
    func reload(now: Date = .now) async {
        guard let fresh = try? await provider.events(from: now.addingTimeInterval(-4 * 3600),
                                                     to: now.addingTimeInterval(48 * 3600)) else { return }
        events = fresh
        phase = .loaded
        await refreshScores(now: now)
    }

    func refreshScores(now: Date = .now) async {
        guard let scoreProvider else { return }
        let live = events.filter { $0.isLive(at: now) }
        guard !live.isEmpty else { return }
        let scores = await scoreProvider.scores(for: live)
        for index in events.indices { if let s = scores[events[index].id] { events[index].score = s } }
    }

    /// Loopt zolang de sectie zichtbaar is (aanroepen vanuit `.task`, stopt bij annuleren).
    func runScoreRefresh(every seconds: Double = 60) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(seconds))
            if Task.isCancelled { break }
            await reload()
        }
    }

    @discardableResult
    func toggleReminder(_ event: SportEvent) -> Bool {
        if reminderIDs.remove(event.id) != nil { return false }
        reminderIDs.insert(event.id)
        return true
    }

    // MARK: Afgeleide lijsten

    func liveEvents(at now: Date) -> [SportEvent] { events.filter { $0.isLive(at: now) } }

    func upcomingCount(at now: Date) -> Int { events.filter { $0.start > now }.count }

    /// Live eerst (met stand, dan gezondste bron), anders de eerstvolgende wedstrijd.
    func featured(at now: Date) -> SportEvent? {
        let live = liveEvents(at: now).sorted {
            if ($0.score != nil) != ($1.score != nil) { return $0.score != nil }
            return $0.start < $1.start
        }
        return live.first ?? events.first { $0.start > now } ?? events.last { $0.isPast(at: now) }
    }

    /// Live + komende 24 uur, live eerst. Zonder de uitgelichte wedstrijd; is er dan niets, dan de eerstvolgende
    /// wedstrijden (ook na 24 uur), en pas daarna de laatste uitslagen.
    func fixtures(at now: Date, limit: Int, excluding excludedID: String? = nil) -> [SportEvent] {
        let horizon = now.addingTimeInterval(24 * 3600)
        let pool = events.filter { $0.id != excludedID }
        let live = pool.filter { $0.isLive(at: now) }
        let soon = pool.filter { $0.start > now && $0.start < horizon }
        let coming = Array((live + soon).prefix(limit))
        if !coming.isEmpty { return coming }
        let later = pool.filter { $0.start > now }.prefix(limit)
        if !later.isEmpty { return Array(later) }
        return Array(pool.filter { $0.isPast(at: now) }.suffix(limit).reversed())
    }

    func competitions(at now: Date) -> [SportCompetition] {
        let relevant = events.filter { !$0.isPast(at: now) }
        let grouped = Dictionary(grouping: relevant) { $0.competition ?? "Overig" }
        return grouped.map { name, group in
            SportCompetition(name: name,
                             liveCount: group.filter { $0.isLive(at: now) }.count,
                             eventCount: group.count,
                             nextStart: group.filter { $0.start > now }.map(\.start).min(),
                             logoURL: group.compactMap { $0.leagueLogoURL }.first)
        }
        .sorted {
            if $0.liveCount != $1.liveCount { return $0.liveCount > $1.liveCount }
            return ($0.nextStart ?? .distantFuture) < ($1.nextStart ?? .distantFuture)
        }
    }

    /// Wedstrijden van favoriete teams (over alle competities heen), voor de "Mijn teams"-subsectie
    /// van de iOS-Sport-sectie. Live + komende eerst (zelfde volgorde als `fixtures`), anders de
    /// meest recente afgelopen wedstrijden van die teams.
    func myTeamEvents(at now: Date, favoriteIDs: Set<String>, limit: Int = 8) -> [SportEvent] {
        guard !favoriteIDs.isEmpty else { return [] }
        let mine = events.filter { event in
            (event.homeTeamID.map(favoriteIDs.contains) ?? false)
                || (event.awayTeamID.map(favoriteIDs.contains) ?? false)
        }
        let live = mine.filter { $0.isLive(at: now) }
        let soon = mine.filter { $0.start > now }.sorted { $0.start < $1.start }
        let coming = Array((live + soon).prefix(limit))
        if !coming.isEmpty { return coming }
        return Array(mine.filter { $0.isPast(at: now) }.suffix(limit).reversed())
    }

    /// Per-competitie-subsecties (bv. "College Football") voor de iOS-Sport-sectie: elke competitie
    /// met minstens 1 relevante wedstrijd krijgt een rij kaarten, live/soonste competitie eerst.
    func leagueSections(at now: Date, limitPerLeague: Int = 6) -> [(name: String, events: [SportEvent])] {
        let grouped = Dictionary(grouping: events) { $0.competition ?? "Overig" }
        return grouped.compactMap { name, group -> (String, [SportEvent], Int, Date)? in
            let live = group.filter { $0.isLive(at: now) }
            let soon = group.filter { $0.start > now }.sorted { $0.start < $1.start }
            var picks = Array((live + soon).prefix(limitPerLeague))
            if picks.isEmpty {
                picks = Array(group.filter { $0.isPast(at: now) }.suffix(limitPerLeague).reversed())
            }
            guard !picks.isEmpty else { return nil }
            let nextStart = group.filter { $0.start > now }.map(\.start).min() ?? .distantFuture
            return (name, picks, live.count, nextStart)
        }
        .sorted {
            if $0.2 != $1.2 { return $0.2 > $1.2 }
            return $0.3 < $1.3
        }
        .map { (name: $0.0, events: $0.1) }
    }

    /// Groepeert per "hoofdsport"-naam in plaats van per exacte `SportsLeague`-entry: het deel van de
    /// competitienaam VOOR een "·"-scheidingsteken is de groepsnaam (bv. "College Football · SEC" en
    /// "College Football · ACC" vallen samen onder "College Football"); een naam zonder "·" (bv. "NFL",
    /// "Belgische Pro League") is zijn eigen groep. De wedstrijden van alle onderliggende, aangezette
    /// competities (de filtering op `SportsDisplayPreferences.isLeagueEnabled` gebeurt al upstream in
    /// `SportsStore`/de adapters, dus `events` bevat alleen aangezette competities) komen door elkaar in
    /// dezelfde rij, gesorteerd op tijd (live/soonste eerst) -- net als `leagueSections`, maar dan één rij
    /// per hoofdsport i.p.v. één rij per losse competitie-entry.
    func sportGroupSections(at now: Date, limitPerGroup: Int = 6) -> [(name: String, events: [SportEvent])] {
        let grouped = Dictionary(grouping: events) { Self.sportGroupName(for: $0.competition ?? "Overig") }
        return grouped.compactMap { name, group -> (String, [SportEvent], Int, Date)? in
            let live = group.filter { $0.isLive(at: now) }
            let soon = group.filter { $0.start > now }.sorted { $0.start < $1.start }
            var picks = Array((live + soon).prefix(limitPerGroup))
            if picks.isEmpty {
                picks = Array(group.filter { $0.isPast(at: now) }.suffix(limitPerGroup).reversed())
            }
            guard !picks.isEmpty else { return nil }
            let nextStart = group.filter { $0.start > now }.map(\.start).min() ?? .distantFuture
            return (name, picks, live.count, nextStart)
        }
        .sorted {
            if $0.2 != $1.2 { return $0.2 > $1.2 }
            return $0.3 < $1.3
        }
        .map { (name: $0.0, events: $0.1) }
    }

    /// "College Football · SEC" -> "College Football" · "NFL" -> "NFL" (geen "·": eigen groep).
    private static func sportGroupName(for competition: String) -> String {
        guard let range = competition.range(of: " · ") else { return competition }
        return String(competition[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
    }

    // MARK: Hero-mapping

    func heroContent(for event: SportEvent, now: Date = .now) -> HeroContent {
        let live = event.isLive(at: now)
        var badges: [String] = event.channelName.isEmpty ? [] : [event.health.label]
        if event.alternativeSources > 0 { badges.append("\(event.alternativeSources)× alternatief") }

        var moments = [HeroMoment(
            id: event.id,
            label: live ? "NU LIVE" : "STRAKS",
            title: [event.competition, event.channelName.isEmpty ? nil : event.channelName].compactMap { $0 }.joined(separator: " · "),
            metaLine: event.metaLine(at: now),
            backdropURL: event.backdropURL,
            progress: event.progress(at: now),
            isLive: live,
            runtimeText: "\(event.durationMinutes) min",
            badges: badges)]

        if let next = events.first(where: { $0.channelID == event.channelID && $0.start >= event.end }) {
            moments.append(HeroMoment(
                id: next.id, label: "STRAKS", title: next.title,
                metaLine: VeyraHomeFormat.when(next.start, now: now), backdropURL: next.backdropURL,
                progress: nil, isLive: false, runtimeText: "\(next.durationMinutes) min",
                badges: [next.health.label]))
        }
        return HeroContent(logoURL: nil, fallbackTitle: event.title, moments: moments)
    }
}

// MARK: - Voorbeelddata (previews)

#if DEBUG
nonisolated struct MockSportProvider: SportHomeProviding {
    func events(from: Date, to: Date) async throws -> [SportEvent] {
        let now = Date()
        func at(_ minutes: Double) -> Date { now.addingTimeInterval(minutes * 60) }
        func make(_ id: String, _ title: String, _ competition: String, start: Double, minutes: Double,
                  channel: (String, Int, String, SourceHealth), alt: Int = 0, catchUp: Bool = false) -> SportEvent {
            let p = SportTitleParser.parse(title)
            return SportEvent(id: id, title: p.title, home: p.home, away: p.away, competition: competition,
                              start: at(start), end: at(start + minutes), channelID: channel.0, channelNumber: channel.1,
                              channelName: channel.2, health: channel.3, canCatchUp: catchUp, alternativeSources: alt)
        }
        let play1 = ("sport1", 11, "Play Sports 1", SourceHealth.degraded)
        let play2 = ("sport2", 12, "Play Sports 2", SourceHealth.good)
        var live = make("e1", "Club Brugge – Anderlecht", "Pro League", start: -63, minutes: 110, channel: play1, alt: 1, catchUp: true)
        live.score = SportScore(home: 1, away: 0, minute: "63'")
        return [
            live,
            make("e2", "Genk – Antwerp", "Pro League", start: 20, minutes: 110, channel: play1),
            make("e3", "Formule 1: Kwalificatie", "Formule 1", start: 80, minutes: 75, channel: play2),
            make("e4", "Lakers – Celtics", "NBA", start: 110, minutes: 150, channel: play2),
            make("e5", "Gent – Bologna", "Europa League", start: 24 * 60, minutes: 120, channel: play1),
            make("e6", "Club Brugge – Benfica", "Champions League", start: 2 * 24 * 60, minutes: 120, channel: play2)
        ]
    }
}
#endif
