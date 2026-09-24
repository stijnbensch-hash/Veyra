// VeyraBentoEPGModel.swift — gedeeld door de tvOS- en (latere) iOS-EPG
// Voeg toe aan alle targets. Vereist VeyraBentoHeroModel.swift (HeroMoment).
//
// Mapping naar Veyra:
//   EPGChannel  <- jullie zender/IPTV-bron (+ bronstatus uit Veyra Hub / AIOStreams-check)
//   EPGProgram  <- XMLTV/EPG-programma; backdropURL en isInWatchlist vul je in na een
//                  TMDB-match (titel + jaar) en een Trakt-watchlist-check.

import Foundation

// MARK: - Model

nonisolated enum SourceHealth: Equatable {
    case good, degraded, down

    var label: String {
        switch self {
        case .good: return "Bron stabiel"
        case .degraded: return "Bron traag"
        case .down: return "Bron offline"
        }
    }
}

nonisolated struct EPGProgram: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?        // "S2E4 · Woe's Hollow"
    let description: String?
    let start: Date
    let end: Date
    let backdropURL: URL?        // alleen invullen bij een TMDB-match
    let isSports: Bool
    let isInWatchlist: Bool      // Trakt-watchlist of volgende aflevering van een gevolgde serie
    let canCatchUp: Bool         // provider biedt timeshift / terugkijken

    var durationMinutes: Int { max(1, Int(end.timeIntervalSince(start) / 60)) }

    func isLive(at now: Date) -> Bool { start <= now && now < end }
    func isPast(at now: Date) -> Bool { end <= now }

    func progress(at now: Date) -> Double? {
        guard isLive(at: now) else { return nil }
        return now.timeIntervalSince(start) / end.timeIntervalSince(start)
    }

    func metaLine(at now: Date) -> String {
        func time(_ d: Date) -> String { d.formatted(.dateTime.hour().minute()) }
        if isLive(at: now) {
            let remaining = max(1, Int((end.timeIntervalSince(now) / 60).rounded(.up)))
            return "\(isSports ? "Live" : "Nu") · nog \(remaining) min"
        }
        if isPast(at: now) {
            return "Afgelopen · \(time(start))–\(time(end))"
        }
        return "Begint om \(time(start)) · \(durationMinutes) min"
    }
}

nonisolated struct EPGChannel: Identifiable, Equatable {
    let id: String
    let number: Int
    let name: String
    let logoURL: URL?
    let health: SourceHealth
    let isFavorite: Bool
    /// Plek in "recent bekeken" (0 = laatst bekeken); `nil` = niet recent bekeken.
    var recentRank: Int? = nil
    let programs: [EPGProgram]   // gesorteerd op start

    func currentProgram(at now: Date) -> EPGProgram? {
        programs.first { $0.isLive(at: now) }
    }

    func nextProgram(after now: Date) -> EPGProgram? {
        programs.first { $0.start >= now }
    }

    func program(containing date: Date) -> EPGProgram? {
        programs.first { $0.start <= date && date < $0.end }
    }
}

// MARK: - Mapping naar de hero (zelfde taal als VeyraHeroView)

nonisolated extension EPGProgram {
    func heroMoment(at now: Date, health: SourceHealth) -> HeroMoment {
        let live = isLive(at: now)
        let label: String
        if live { label = isSports ? "NU LIVE" : "NU" }
        else if isPast(at: now) { label = "AFGELOPEN" }
        else { label = "STRAKS" }

        var badges = [health.label]
        if canCatchUp { badges.append("Vanaf begin mogelijk") }

        return HeroMoment(
            id: id,
            label: label,
            title: subtitle.map { "\(title) · \($0)" } ?? title,
            metaLine: metaLine(at: now),
            backdropURL: backdropURL,
            progress: progress(at: now),
            isLive: live && isSports,
            runtimeText: "\(durationMinutes) min",
            badges: badges
        )
    }
}

// MARK: - Voorbeelddata voor previews

#if DEBUG
nonisolated enum EPGSampleData {
    private struct Slot {
        let title: String
        let minutes: Int
        var subtitle: String? = nil
        var watchlist = false
        var sports = false
        var description: String? = nil
    }

    static func make(now: Date) -> [EPGChannel] {
        let hour: TimeInterval = 3600
        let base = Date(timeIntervalSince1970: (now.timeIntervalSince1970 / hour).rounded(.down) * hour - 3 * hour)
        let horizon = base.addingTimeInterval(40 * hour)

        func schedule(_ channel: String, _ pattern: [Slot], catchUp: Bool) -> [EPGProgram] {
            var out: [EPGProgram] = []
            var t = base
            var i = 0
            while t < horizon {
                let slot = pattern[i % pattern.count]
                let end = t.addingTimeInterval(TimeInterval(slot.minutes * 60))
                out.append(EPGProgram(
                    id: "\(channel)-\(i)",
                    title: slot.title,
                    subtitle: slot.subtitle,
                    description: slot.description,
                    start: t,
                    end: end,
                    backdropURL: nil,
                    isSports: slot.sports,
                    isInWatchlist: slot.watchlist,
                    canCatchUp: catchUp
                ))
                t = end
                i += 1
            }
            return out
        }

        let een = [
            Slot(title: "Het Journaal", minutes: 30, description: "Nieuws, weer en sport."),
            Slot(title: "Thuis", minutes: 30, description: "Dagelijkse Vlaamse soap."),
            Slot(title: "De Slimste Mens", minutes: 60, description: "Quiz met vijf kandidaten."),
            Slot(title: "Terzake", minutes: 45, description: "Actualiteit en duiding."),
            Slot(title: "Severance", minutes: 50, subtitle: "S2E4", watchlist: true,
                 description: "Mark ontdekt wat er achter de gesloten deuren gebeurt."),
            Slot(title: "Reportage", minutes: 55)
        ]
        let canvas = [
            Slot(title: "Dune: Part Two", minutes: 165, watchlist: true,
                 description: "Paul Atreides sluit zich aan bij de Fremen."),
            Slot(title: "Panorama", minutes: 60),
            Slot(title: "Nachtjournaal", minutes: 20),
            Slot(title: "Documentaire", minutes: 70)
        ]
        let vtm = [
            Slot(title: "Nieuws", minutes: 30),
            Slot(title: "Familie", minutes: 30),
            Slot(title: "The Voice", minutes: 90),
            Slot(title: "Film", minutes: 120),
            Slot(title: "Late Night", minutes: 45)
        ]
        let sports = [
            Slot(title: "Voetbal: Club Brugge – Anderlecht", minutes: 120, sports: true,
                 description: "Live vanuit het Jan Breydelstadion."),
            Slot(title: "Studio Sport", minutes: 45, sports: true),
            Slot(title: "Formule 1: Kwalificatie", minutes: 75, sports: true),
            Slot(title: "Analyse", minutes: 30, sports: true)
        ]
        let ketnet = [
            Slot(title: "Karrewiet", minutes: 15),
            Slot(title: "Chicken Little", minutes: 25),
            Slot(title: "Nachtwacht", minutes: 30),
            Slot(title: "Dolfje Weerwolfje", minutes: 40)
        ]
        let bbc = [
            Slot(title: "BBC News", minutes: 30),
            Slot(title: "EastEnders", minutes: 30),
            Slot(title: "Match of the Day", minutes: 75, sports: true),
            Slot(title: "Panorama", minutes: 30)
        ]

        return [
            EPGChannel(id: "een", number: 1, name: "Eén", logoURL: nil, health: .good,
                       isFavorite: true, programs: schedule("een", een, catchUp: true)),
            EPGChannel(id: "canvas", number: 2, name: "Canvas", logoURL: nil, health: .good,
                       isFavorite: true, programs: schedule("canvas", canvas, catchUp: true)),
            EPGChannel(id: "vtm", number: 3, name: "VTM", logoURL: nil, health: .good,
                       isFavorite: false, programs: schedule("vtm", vtm, catchUp: false)),
            EPGChannel(id: "sport1", number: 11, name: "Play Sports 1", logoURL: nil, health: .degraded,
                       isFavorite: false, programs: schedule("sport1", sports, catchUp: false)),
            EPGChannel(id: "ketnet", number: 5, name: "Ketnet", logoURL: nil, health: .good,
                       isFavorite: false, programs: schedule("ketnet", ketnet, catchUp: true)),
            EPGChannel(id: "bbc1", number: 21, name: "BBC One", logoURL: nil, health: .down,
                       isFavorite: false, programs: schedule("bbc1", bbc, catchUp: false))
        ]
    }
}
#endif
