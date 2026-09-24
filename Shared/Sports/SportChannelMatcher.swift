// SportChannelMatcher.swift — gedeeld (iOS + tvOS)
// Koppelt een sportwedstrijd aan IPTV-zenders: zoekt in de EPG (programmagids) naar programma's rond de
// aftrap waarin de teamnamen voorkomen, en geeft die zenders terug (beste match eerst).

import Foundation

/// Eén zender die de wedstrijd (volgens de EPG) uitzendt.
nonisolated struct SportChannelMatch: Identifiable, Hashable, Sendable {
    let id: String
    let channelID: String
    let channelName: String
    let logoURL: URL?
    let programmeTitle: String
    let start: Date
    let end: Date
    let score: Int

    func isLive(at now: Date) -> Bool { start <= now && now < end }
}

/// Zender uit de gids, los van de UI, zodat het zoeken op een achtergrondtaak kan.
nonisolated struct SportGuideChannel: Sendable {
    let id: String
    let name: String
    let logoURL: URL?
    let tvgID: String
}

nonisolated enum SportChannelMatcher {
    private static let stopwords: Set<String> = [
        "fc", "cf", "sc", "ac", "afc", "as", "us", "ss", "sv", "vv", "kv", "kfc", "rsc", "rc",
        "the", "de", "la", "le", "el", "los", "las", "del", "van", "der", "den", "het", "en", "at", "vs", "v",
        "club", "city", "united", "real", "sporting", "athletic", "team", "women", "men"
    ]

    /// Kleine letters, zonder accenten of leestekens, woorden gescheiden door één spatie.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
        var out = ""
        var lastWasSpace = true
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                out.unicodeScalars.append(scalar)
                lastWasSpace = false
            } else if !lastWasSpace {
                out.append(" ")
                lastWasSpace = true
            }
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    /// 2 = volledige naam gevonden, 1 = een onderscheidend woord van de naam gevonden, 0 = niets.
    private static func strength(of team: String, in haystack: String) -> Int {
        let name = normalize(team)
        guard !name.isEmpty else { return 0 }
        if haystack.contains(" \(name) ") { return 2 }
        let words = name.split(separator: " ").map(String.init)
            .filter { $0.count >= 4 && !stopwords.contains($0) }
        return words.contains { haystack.contains(" \($0) ") } ? 1 : 0
    }

    /// `teams`: de namen van de deelnemers (thuis/uit, of de losse titel). `start`: aftrap.
    static func matches(teams: [String],
                        start: Date,
                        now: Date = Date(),
                        index: [String: [VeyraEPGProgramme]],
                        channels: [SportGuideChannel]) -> [SportChannelMatch] {
        let names = teams.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !names.isEmpty else { return [] }

        var channelsByTVG: [String: [SportGuideChannel]] = [:]
        for channel in channels where !channel.tvgID.isEmpty {
            channelsByTVG[channel.tvgID, default: []].append(channel)
        }

        let windowStart = start.addingTimeInterval(-120 * 60)
        let windowEnd = start.addingTimeInterval(60 * 60)
        var found: [SportChannelMatch] = []

        for (tvgID, programmes) in index {
            guard let owners = channelsByTVG[tvgID] else { continue }
            for programme in programmes {
                let startsInWindow = programme.start >= windowStart && programme.start <= windowEnd
                let coversKickoff = programme.start <= start && programme.end > start
                guard startsInWindow || coversKickoff else { continue }

                let haystack = " " + normalize("\(programme.title) \(programme.subtitle) \(String(programme.summary.prefix(300)))") + " "
                let strengths = names.map { strength(of: $0, in: haystack) }
                let matched = strengths.filter { $0 > 0 }.count
                let total = strengths.reduce(0, +)

                // Twee deelnemers: allebei herkend, of één met de volledige naam. Eén deelnemer (titel): volledige naam.
                let ok: Bool
                if names.count >= 2 { ok = matched >= 2 || strengths.contains(2) } else { ok = total >= 2 }
                guard ok else { continue }

                let minutes = abs(programme.start.timeIntervalSince(start)) / 60
                let closeness = max(0, 12 - Int(minutes / 10))
                let score = total * 10 + matched * 10 + closeness + (programme.isOnAir(at: now) ? 5 : 0)

                for channel in owners {
                    found.append(SportChannelMatch(
                        id: "\(channel.id)|\(programme.id)", channelID: channel.id, channelName: channel.name,
                        logoURL: channel.logoURL, programmeTitle: programme.title,
                        start: programme.start, end: programme.end, score: score))
                }
            }
        }

        // Dezelfde zender maar één keer (beste programma), beste match bovenaan.
        var best: [String: SportChannelMatch] = [:]
        for match in found where (best[match.channelID]?.score ?? -1) < match.score { best[match.channelID] = match }
        return best.values.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.channelName.localizedCaseInsensitiveCompare($1.channelName) == .orderedAscending
        }
        .prefix(40)
        .map { $0 }
    }
}
