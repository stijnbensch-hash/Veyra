import Foundation

// MARK: - League

// MARK: - Sport category

/// Bredere sport-groepering boven de individuele competities (`SportsLeague`),
/// gebruikt om in Instellingen per sport (i.p.v. per competitie) te kunnen
/// tonen/verbergen. Uitbreidbaar: een nieuwe competitie krijgt gewoon een van
/// deze cases (of een nieuwe case erbij) op `SportsLeague.sport`.
nonisolated enum SportCategory:
    String,
    CaseIterable,
    Identifiable,
    Codable,
    Sendable
{
    case football
    case americanFootball
    case basketball

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .football:
            return "Voetbal"

        case .americanFootball:
            return "American Football"

        case .basketball:
            return "Basketbal"
        }
    }
}

nonisolated struct SportsLeague:
    Identifiable,
    Hashable,
    Sendable
{
    let id: String
    let name: String
    let path: String
    let symbol: String
    let sport: SportCategory
    /// Optionele ESPN "groups"-queryparameter, gebruikt om binnen één ESPN-sport/competitie-pad
    /// (zoals `football/college-football`) te filteren op een specifieke conference.
    var groups: String? = nil

    static let all: [SportsLeague] = [
        .init(
            id: "bel.1",
            name: "Belgische Pro League",
            path: "soccer/bel.1",
            symbol: "soccerball",
            sport: .football
        ),
        .init(
            id: "uefa.champions",
            name: "Champions League",
            path: "soccer/uefa.champions",
            symbol: "soccerball",
            sport: .football
        ),
        .init(
            id: "uefa.europa",
            name: "Europa League",
            path: "soccer/uefa.europa",
            symbol: "soccerball",
            sport: .football
        ),
        .init(
            id: "eng.1",
            name: "Premier League",
            path: "soccer/eng.1",
            symbol: "soccerball",
            sport: .football
        ),
        .init(
            id: "esp.1",
            name: "La Liga",
            path: "soccer/esp.1",
            symbol: "soccerball",
            sport: .football
        ),
        .init(
            id: "ita.1",
            name: "Serie A",
            path: "soccer/ita.1",
            symbol: "soccerball",
            sport: .football
        ),
        .init(
            id: "ger.1",
            name: "Bundesliga",
            path: "soccer/ger.1",
            symbol: "soccerball",
            sport: .football
        ),
        .init(
            id: "fra.1",
            name: "Ligue 1",
            path: "soccer/fra.1",
            symbol: "soccerball",
            sport: .football
        ),
        .init(
            id: "nfl",
            name: "NFL",
            path: "football/nfl",
            symbol: "american.football",
            sport: .americanFootball
        ),
        .init(
            id: "college-football-acc",
            name: "College Football · ACC",
            path: "football/college-football",
            symbol: "american.football",
            sport: .americanFootball,
            groups: "1"
        ),
        .init(
            id: "college-football-big12",
            name: "College Football · Big 12",
            path: "football/college-football",
            symbol: "american.football",
            sport: .americanFootball,
            groups: "4"
        ),
        .init(
            id: "college-football-big-ten",
            name: "College Football · Big Ten (B1G)",
            path: "football/college-football",
            symbol: "american.football",
            sport: .americanFootball,
            groups: "5"
        ),
        .init(
            id: "college-football-sec",
            name: "College Football · SEC",
            path: "football/college-football",
            symbol: "american.football",
            sport: .americanFootball,
            groups: "8"
        ),
        .init(
            id: "college-football-pac12",
            name: "College Football · Pac-12",
            path: "football/college-football",
            symbol: "american.football",
            sport: .americanFootball,
            groups: "9"
        ),
        .init(
            id: "college-football-aac",
            name: "College Football · American (AAC)",
            path: "football/college-football",
            symbol: "american.football",
            sport: .americanFootball,
            groups: "151"
        ),
        .init(
            id: "college-football-cusa",
            name: "College Football · Conference USA",
            path: "football/college-football",
            symbol: "american.football",
            sport: .americanFootball,
            groups: "12"
        ),
        .init(
            id: "college-football-mac",
            name: "College Football · MAC",
            path: "football/college-football",
            symbol: "american.football",
            sport: .americanFootball,
            groups: "15"
        ),
        .init(
            id: "college-football-mwc",
            name: "College Football · Mountain West",
            path: "football/college-football",
            symbol: "american.football",
            sport: .americanFootball,
            groups: "17"
        ),
        .init(
            id: "college-football-sunbelt",
            name: "College Football · Sun Belt",
            path: "football/college-football",
            symbol: "american.football",
            sport: .americanFootball,
            groups: "37"
        ),
        .init(
            id: "nba",
            name: "NBA",
            path: "basketball/nba",
            symbol: "basketball",
            sport: .basketball
        ),
        .init(
            id: "euroleague",
            name: "EuroLeague",
            path: "basketball/euroleague",
            symbol: "basketball",
            sport: .basketball
        )
    ]
}

// MARK: - Team

nonisolated struct SportsTeam:
    Identifiable,
    Hashable,
    Sendable
{
    let id: String
    let name: String
    let abbreviation: String
    let logoURL: URL?

    init(
        id: String,
        name: String,
        abbreviation: String,
        logoURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.abbreviation = abbreviation
        self.logoURL = logoURL
    }

    // Alleen nood-fallback.
    // Normaal komt het logo rechtstreeks van ESPN.
    static let logoMapping: [String: String] = [
        "AJA":
            "https://upload.wikimedia.org/wikipedia/en/7/79/Ajax_Amsterdam.svg",

        "BAR":
            "https://upload.wikimedia.org/wikipedia/en/4/47/FC_Barcelona_%28crest%29.svg",

        "RMA":
            "https://upload.wikimedia.org/wikipedia/en/5/56/Real_Madrid_CF.svg",

        "PSG":
            "https://upload.wikimedia.org/wikipedia/en/a/a7/Paris_Saint-Germain_F.C..svg",

        "MUN":
            "https://upload.wikimedia.org/wikipedia/en/7/7a/Manchester_United_FC_crest.svg"
    ]

    static func fallbackLogoURL(
        abbreviation: String
    ) -> URL? {
        guard
            let value =
                logoMapping[
                    abbreviation.uppercased()
                ]
        else {
            return nil
        }

        return URL(string: value)
    }
}

// MARK: - Match

struct SportsMatch:
    Identifiable,
    Hashable,
    Sendable
{
    enum Phase:
        Hashable,
        Sendable
    {
        case scheduled
        case live
        case finished
        case postponed
    }

    let id: String
    let league: SportsLeague
    let date: Date
    let home: SportsTeam
    let away: SportsTeam
    let homeScore: String?
    let awayScore: String?
    let phase: Phase
    let detail: String
    let venue: String?
    let tvBroadcast: String?

    var showsScore: Bool {
        phase == .live
            || phase == .finished
    }

    var status: String {
        switch phase {
        case .live:
            return "LIVE · \(detail)"

        case .finished:
            return "AFGELOPEN · \(detail)"

        case .postponed:
            return detail

        case .scheduled:
            return date.formatted(
                date: .omitted,
                time: .shortened
            )
        }
    }
}

// MARK: - ESPN Scoreboard

struct ESPNScoreboard: Decodable {
    let events: [Event]

    // MARK: Event

    struct Event: Decodable {
        let id: String
        let date: String
        let competitions: [Competition]
        let status: Status
    }

    // MARK: Competition

    struct Competition: Decodable {
        let competitors: [Competitor]
        let venue: Venue?
        let broadcasts: [Broadcast]?
        let geoBroadcasts: [GeoBroadcast]?

        var tvBroadcast: String? {
            let television = (geoBroadcasts ?? [])
                .filter { $0.type?.shortName?.caseInsensitiveCompare("TV") == .orderedSame }
                .compactMap { $0.media?.shortName }
            let names = television.isEmpty ? (broadcasts ?? []).flatMap { $0.names ?? [] } : television
            var seen = Set<String>()
            let unique = names.compactMap { name -> String? in
                let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty, seen.insert(clean.lowercased()).inserted else { return nil }
                return clean
            }
            return unique.isEmpty ? nil : unique.prefix(2).joined(separator: " · ")
        }
    }

    struct Broadcast: Decodable {
        let names: [String]?
    }

    struct GeoBroadcast: Decodable {
        let type: BroadcastType?
        let media: BroadcastMedia?
    }

    struct BroadcastType: Decodable { let shortName: String? }
    struct BroadcastMedia: Decodable { let shortName: String? }

    // MARK: Venue

    struct Venue: Decodable {
        let fullName: String?
    }

    // MARK: Competitor

    struct Competitor: Decodable {
        let homeAway: String
        let team: Team
        let score: String?
    }

    // MARK: ESPN Team

    struct Team: Decodable {
        let id: String
        let displayName: String
        let abbreviation: String?

        // DIT is het belangrijke ESPN-scoreboardveld.
        let logo: String?

        // Sommige ESPN-responses kunnen daarnaast
        // een array met logo's bevatten.
        let logos: [Logo]?

        struct Logo: Decodable {
            let href: String?
            let width: Int?
            let height: Int?
            let rel: [String]?
        }
    }

    // MARK: Status

    struct Status: Decodable {
        let type: Kind

        struct Kind: Decodable {
            let name: String
            let state: String
            let completed: Bool
            let shortDetail: String?
            let detail: String?
        }
    }

    // MARK: ESPN -> Veyra

    func matches(
        league: SportsLeague
    ) -> [SportsMatch] {
        let parser =
            ISO8601DateFormatter()

        parser.formatOptions = [
            .withInternetDateTime
        ]

        let minuteParser =
            DateFormatter()

        minuteParser.locale =
            Locale(
                identifier: "en_US_POSIX"
            )

        minuteParser.dateFormat =
            "yyyy-MM-dd'T'HH:mmX"

        return events.compactMap { event in
            guard
                let date =
                    parser.date(
                        from: event.date
                    )
                    ?? minuteParser.date(
                        from: event.date
                    ),

                let competition =
                    event.competitions.first,

                let home =
                    competition.competitors.first(
                        where: {
                            $0.homeAway == "home"
                        }
                    ),

                let away =
                    competition.competitors.first(
                        where: {
                            $0.homeAway == "away"
                        }
                    )
            else {
                return nil
            }

            let type =
                event.status.type

            let exceptionalStates = [
                "POSTPONED",
                "CANCELED",
                "CANCELLED",
                "SUSPENDED",
                "DELAYED"
            ]

            let exceptional =
                exceptionalStates.contains {
                    type.name
                        .uppercased()
                        .contains($0)
                }

            let phase:
                SportsMatch.Phase

            if exceptional {
                phase = .postponed
            } else if type.completed {
                phase = .finished
            } else if type.state == "in" {
                phase = .live
            } else {
                phase = .scheduled
            }

            // Voetbalclubs kunnen bij ESPN in meerdere
            // competities hetzelfde team-ID gebruiken. Gebruik `path`
            // (niet `id`) als namespace: meerdere `SportsLeague`-entries
            // (bv. de losse college-football-conferences) delen hetzelfde
            // ESPN-pad en moeten daarom hetzelfde team-ID opleveren.
            let sport =
                league.path.hasPrefix(
                    "soccer/"
                )
                ? "soccer"
                : league.path

            func makeTeam(
                _ source: Team
            ) -> SportsTeam {
                let abbreviation =
                    source.abbreviation
                    ?? String(
                        source.displayName
                            .prefix(3)
                    )
                    .uppercased()

                // 1. Eerst het echte scoreboard-logo.
                let directLogo =
                    validLogoURL(
                        source.logo
                    )

                // 2. Daarna eventueel de logos-array.
                let arrayLogo =
                    bestLogoURL(
                        source.logos
                    )

                // 3. Pas als laatste de handmatige fallback.
                let fallback =
                    SportsTeam
                        .fallbackLogoURL(
                            abbreviation:
                                abbreviation
                        )

                return SportsTeam(
                    id:
                        "\(sport):\(source.id)",
                    name:
                        source.displayName,
                    abbreviation:
                        abbreviation,
                    logoURL:
                        directLogo
                        ?? arrayLogo
                        ?? fallback
                )
            }

            return SportsMatch(
                id:
                    "\(league.id):\(event.id)",
                league:
                    league,
                date:
                    date,
                home:
                    makeTeam(
                        home.team
                    ),
                away:
                    makeTeam(
                        away.team
                    ),
                homeScore:
                    home.score,
                awayScore:
                    away.score,
                phase:
                    phase,
                detail:
                    type.shortDetail
                    ?? type.detail
                    ?? type.name,
                venue:
                    competition
                        .venue?
                        .fullName,
                tvBroadcast:
                    competition
                        .tvBroadcast
            )
        }
    }

    // MARK: - Direct ESPN logo

    private func validLogoURL(
        _ value: String?
    ) -> URL? {
        guard
            let value =
                value?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ),
            !value.isEmpty,
            let url =
                URL(string: value),
            let scheme =
                url.scheme?
                    .lowercased(),
            scheme == "https"
                || scheme == "http"
        else {
            return nil
        }

        return url
    }

    // MARK: - ESPN logos-array fallback

    private func bestLogoURL(
        _ logos:
            [Team.Logo]?
    ) -> URL? {
        guard
            let logos,
            !logos.isEmpty
        else {
            return nil
        }

        let sorted =
            logos.sorted {
                let leftArea =
                    ($0.width ?? 0)
                    * ($0.height ?? 0)

                let rightArea =
                    ($1.width ?? 0)
                    * ($1.height ?? 0)

                return leftArea
                    > rightArea
            }

        for logo in sorted {
            if let url =
                validLogoURL(
                    logo.href
                )
            {
                return url
            }
        }

        return nil
    }
}
