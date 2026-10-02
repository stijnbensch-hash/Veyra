// VRTRegionalReleaseProvider.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Fase 12 ("echte Belgische/Vlaamse Regional Release providers"): eerste echte, live-geverifieerde
// `RegionalReleaseProvider`-implementatie (spec §19). Vervangt `MockRegionalReleaseProvider` als
// geregistreerde provider voor regio "BE-VL" -- zie fase 12-researchrapport voor de volledige
// vergelijking van VRT/VTM GO/Play/Streamz.
//
// BRON (live geverifieerd, geen Kodi-addon-gok): `https://www.vrt.be/vrtnu-api/graphql/public/v1`
// -- de publieke, no-auth GraphQL-API die vrtmax.be zelf gebruikt (bevestigd via de uitgeleverde
// JS-bundels incl. introspection-schema, en via echte live requests op 2026-10-02). Vereist enkel
// `X-VRT-CLIENT-NAME`/`X-VRT-CLIENT-VERSION`-headers (willekeurige waarden volstaan, geen echte
// auth/cookies/tokens nodig); zonder die headers antwoordt de API met HTTP 400.
//
// BEPERKING (belangrijk, zie fase 12-rapport): de publieke tile-schema's (`EpisodeTile`,
// `ProgramTile`) leveren GEEN structured releasedatum/seizoen-/episodenummer -- enkel een stabiele
// `whatsonId`, een titel, en een mens-leesbare `description`. De homepage-sectie "Binnenkort op
// VRT MAX" bevat echter wél bruikbare, consistente Nederlandse tekst ("Nieuwe reeks vanaf 5
// oktober", "Nieuw seizoen vanaf 12 oktober") -- dit bestand parseert die tekst naar een
// `releaseDate`. Dat is INHERENT fragieler dan een structured veld (tekstformaat kan wijzigen),
// vandaar een bewust lage `sourceConfidence` (spec §29: "bij lage confidence geen destructieve
// Trakt-sync"). Items zonder herkenbaar "vanaf <dag> <maand>"-patroon (bv. "De Warmste Week") of
// zonder herkende titelsectie worden overgeslagen, nooit gegokt.
import Foundation

nonisolated struct VRTRegionalReleaseProvider: RegionalReleaseProvider {
    let id = "vrt"
    let displayName = "VRT MAX"
    let supportedRegions: Set<String> = [RegionalReleaseContext.defaultRegion]

    /// De homepagesectie die als bron dient. Fragiel aan een titelwijziging door VRT zelf -- als
    /// deze sectie verdwijnt/hernoemd wordt, levert `releases(context:)` gewoon `[]` terug (geen
    /// crash).
    private static let soonListTitle = "Binnenkort op VRT MAX"
    private static let endpoint = URL(string: "https://www.vrt.be/vrtnu-api/graphql/public/v1")!
    private static let homePageID = "/vrtmax"

    private static let query = """
    query Home($id: ID!){ page(id:$id){ __typename ... on HomePage{ title paginatedComponents(first:40){ edges{ node{ __typename ... on PaginatedTileList{ title paginatedItems(first:12){ edges{ node{ __typename ... on ITile{ title } ... on EpisodeTile{ whatsonId description image{ templateUrl } } } } } } } } } } } }
    """

    private let session: URLSession

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    func releases(context: RegionalReleaseContext) async throws -> [RegionalReleaseEvent] {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Willekeurige-maar-stabiele clientnaam/-versie -- live geverifieerd dat de API enkel de
        // AANWEZIGHEID van deze headers controleert, niet een specifieke whitelisted waarde.
        request.setValue("veyra-app", forHTTPHeaderField: "X-VRT-CLIENT-NAME")
        request.setValue("1.0.0", forHTTPHeaderField: "X-VRT-CLIENT-VERSION")
        let body = GraphQLRequestBody(query: Self.query, variables: ["id": Self.homePageID])
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw VRTRegionalReleaseError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw VRTRegionalReleaseError.http(http.statusCode) }

        let decoded = try JSONDecoder().decode(GraphQLResponse.self, from: data)
        guard let components = decoded.data?.page?.paginatedComponents?.edges else { return [] }

        guard let soonList = components
            .compactMap({ $0.node })
            .first(where: { $0.title == Self.soonListTitle })
        else { return [] }

        let items = soonList.paginatedItems?.edges.compactMap { $0.node } ?? []
        return items.compactMap { tile in
            event(from: tile, context: context)
        }
    }

    // MARK: - Mapping

    private func event(from tile: TileNode, context: RegionalReleaseContext) -> RegionalReleaseEvent? {
        guard let whatsonId = tile.whatsonId, let title = tile.title else { return nil }
        guard let parsed = Self.parseDescription(tile.description) else { return nil }
        return RegionalReleaseEvent(
            id: "vrt:\(whatsonId)",
            providerID: id,
            channelID: nil,
            region: context.region,
            countryCode: context.countryCode,
            languageCode: context.languageCode,
            title: title,
            releaseType: parsed.type,
            releaseDate: parsed.date,
            airDate: nil,
            season: nil,
            episode: nil,
            sourceConfidence: 0.5
        )
    }

    private static let dutchMonths: [String: Int] = [
        "januari": 1, "februari": 2, "maart": 3, "april": 4, "mei": 5, "juni": 6,
        "juli": 7, "augustus": 8, "september": 9, "oktober": 10, "november": 11, "december": 12
    ]

    private static let newSeriesRegex = try! NSRegularExpression(
        pattern: #"(?i)nieuwe?\s+(?:reeks|serie)\s+vanaf\s+(\d{1,2})\s+([a-zéû]+)"#
    )
    private static let newSeasonRegex = try! NSRegularExpression(
        pattern: #"(?i)nieuw\s+seizoen\s+vanaf\s+(\d{1,2})\s+([a-zéû]+)"#
    )

    private static func parseDescription(_ description: String?) -> (type: RegionalReleaseType, date: Date)? {
        guard let description else { return nil }
        let range = NSRange(description.startIndex..<description.endIndex, in: description)

        if let match = newSeriesRegex.firstMatch(in: description, range: range),
           let date = date(fromMatch: match, in: description) {
            return (.newSeries, date)
        }
        if let match = newSeasonRegex.firstMatch(in: description, range: range),
           let date = date(fromMatch: match, in: description) {
            return (.newSeason, date)
        }
        return nil
    }

    private static func date(fromMatch match: NSTextCheckingResult, in text: String) -> Date? {
        guard match.numberOfRanges == 3,
              let dayRange = Range(match.range(at: 1), in: text),
              let monthRange = Range(match.range(at: 2), in: text),
              let day = Int(text[dayRange]),
              let month = dutchMonths[text[monthRange].lowercased()]
        else { return nil }

        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)

        func candidate(year: Int) -> Date? {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 0, minute: 0))
        }

        guard let thisYear = candidate(year: currentYear) else { return nil }
        // "Binnenkort"-items liggen per definitie in de (nabije) toekomst -- als de datum met het
        // huidige jaar meer dan een week in het verleden valt, is het jaar al omgeslagen
        // (bv. in december naar een releasedatum in januari).
        if thisYear < calendar.date(byAdding: .day, value: -7, to: now) ?? now {
            return candidate(year: currentYear + 1) ?? thisYear
        }
        return thisYear
    }
}

private struct GraphQLRequestBody: Encodable {
    let query: String
    let variables: [String: String]
}

private struct GraphQLResponse: Decodable {
    let data: HomeData?
}

private struct HomeData: Decodable {
    let page: PageNode?
}

private struct PageNode: Decodable {
    let title: String?
    let paginatedComponents: ComponentConnection?
}

private struct ComponentConnection: Decodable {
    let edges: [ComponentEdge]
}

private struct ComponentEdge: Decodable {
    let node: ComponentNode?
}

private struct ComponentNode: Decodable {
    let __typename: String
    let title: String?
    let paginatedItems: TileConnection?
}

private struct TileConnection: Decodable {
    let edges: [TileEdge]
}

private struct TileEdge: Decodable {
    let node: TileNode?
}

private struct TileNode: Decodable {
    let __typename: String
    let title: String?
    let whatsonId: String?
    let description: String?
    let image: TileImage?
}

private struct TileImage: Decodable {
    let templateUrl: String?
}

nonisolated enum VRTRegionalReleaseError: LocalizedError {
    case invalidResponse
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "VRT MAX gaf een onverwacht antwoord."
        case .http(let code): return "VRT MAX kon de releases niet ophalen (\(code))."
        }
    }
}
