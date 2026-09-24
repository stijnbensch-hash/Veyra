import Foundation

/// Een door de gebruiker ingestelde "plank" (shelf/rail) op het hoofdmenu,
/// zoals in de Strand-app: een horizontale rij films of series, gevuld
/// vanuit Trakt, TMDB, of een addon-catalogus (bv. AIOMetadata).
struct Shelf: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var title: String
    var isEnabled: Bool
    var source: ShelfSource

    init(
        id: UUID = UUID(),
        title: String,
        isEnabled: Bool = true,
        source: ShelfSource
    ) {
        self.id = id
        self.title = title
        self.isEnabled = isEnabled
        self.source = source
    }
}

enum ShelfMediaKind: String, Codable, CaseIterable, Hashable {
    case movie
    case series

    var label: String { self == .movie ? "Films" : "Series" }
}

enum ShelfSource: Codable, Equatable, Hashable {
    case trakt(list: TraktShelfList, kind: ShelfMediaKind)
    case tmdb(list: TMDBShelfList, kind: ShelfMediaKind)
    case addon(addonID: UUID, addonName: String, catalogType: String, catalogID: String, catalogName: String)
    // Een bibliotheek van een gekoppelde mediaserver (Jellyfin, of een
    // Jellyfin-compatibele VeyraHub-instantie) — dezelfde soort bron als
    // `.addon`, maar de catalogus komt uit `Users/{userID}/Views` /
    // `Users/{userID}/Items` van die server in plaats van een Stremio-addon.
    case mediaServer(serverID: UUID, serverName: String, libraryID: String, libraryName: String, kind: ShelfMediaKind)
    // Zelf gekozen losse IPTV-kanalen (uit een of meerdere providers) — geen
    // "lijst" zoals de andere bronnen, dus een losse snapshot van kanalen
    // i.p.v. een bron die opnieuw bevraagd wordt.
    case iptv(channels: [ShelfIPTVChannel])

    var kind: ShelfMediaKind {
        switch self {
        case .trakt(_, let kind): return kind
        case .tmdb(_, let kind): return kind
        case .addon(_, _, let catalogType, _, _): return catalogType == "series" ? .series : .movie
        case .mediaServer(_, _, _, _, let kind): return kind
        // Niet van toepassing — .iptv-planken tonen hun eigen label via
        // `detailLabel` in plaats van "<bron> · <kind>".
        case .iptv: return .movie
        }
    }

    var defaultTitle: String {
        switch self {
        case .trakt(let list, let kind): return list.label(for: kind)
        case .tmdb(let list, let kind): return list.label(for: kind)
        case .addon(_, let addonName, _, _, let catalogName): return "\(addonName) · \(catalogName)"
        case .mediaServer(_, let serverName, _, let libraryName, _): return "\(serverName) · \(libraryName)"
        case .iptv: return "Mijn zenders"
        }
    }

    var subtitle: String {
        switch self {
        case .trakt: return "Trakt"
        case .tmdb: return "TMDB"
        case .addon(_, let addonName, _, _, _): return addonName
        case .mediaServer(_, let serverName, _, _, _): return serverName
        case .iptv: return "IPTV"
        }
    }

    /// Label voor het planken-overzicht in Instellingen — voor de meeste
    /// bronnen "<bron> · <Films/Series>", maar voor IPTV het aantal
    /// gekozen zenders, want "Films"/"Series" is hier niet van toepassing.
    var detailLabel: String {
        switch self {
        case .iptv(let channels):
            let liveCount = channels.filter { ($0.kind ?? .live) == .live }.count
            let vodCount = channels.filter { $0.kind == .vod }.count
            let seriesCount = channels.filter { $0.kind == .series }.count

            var parts: [String] = []
            if liveCount > 0 { parts.append(liveCount == 1 ? "1 zender" : "\(liveCount) zenders") }
            if vodCount > 0 { parts.append(vodCount == 1 ? "1 film" : "\(vodCount) films") }
            if seriesCount > 0 { parts.append(seriesCount == 1 ? "1 serie" : "\(seriesCount) series") }

            return parts.isEmpty ? "IPTV" : "IPTV · \(parts.joined(separator: ", "))"
        default:
            return "\(subtitle) · \(kind.label)"
        }
    }
}

/// Live zender of VOD-titel (film) uit dezelfde IPTV-provider — beide
/// worden op dezelfde manier gekozen en rechtstreeks afgespeeld.
enum ShelfIPTVItemKind: String, Codable, Equatable, Hashable {
    case live
    case vod
    case series
}

/// Eén losstaand IPTV-kanaal of VOD-titel zoals het gekozen is voor een
/// plank — een snapshot van naam, logo en afspeel-URL op het moment van
/// kiezen, zodat het item direct afgespeeld kan worden zonder de (mogelijk
/// niet actieve) provider opnieuw te hoeven bevragen. `kind` is optioneel om
/// planken die al bestonden vóór VOD-ondersteuning geldig te laten inlezen
/// (ontbrekend = `.live`).
struct ShelfIPTVChannel: Codable, Equatable, Hashable, Identifiable {
    var channelID: String
    var providerName: String
    var name: String
    // `nil` voor `.series`-items: een serie heeft geen eigen afspeel-URL,
    // je kiest eerst een seizoen/aflevering (zie `ShelfIPTVSeriesEpisodesView`).
    var streamURL: URL?
    var logoURL: URL?
    var group: String?
    var kind: ShelfIPTVItemKind?
    // Wanneer de provider deze titel heeft toegevoegd (Xtream "added") — voor
    // het sorteren van de plank op nieuwste eerst. `nil` bij oudere planken
    // (van vóór dit veld), bij zenders en bij M3U (geen "added"-datum
    // beschikbaar). Standaard `nil` zodat bestaande aanroepen van het
    // memberwise `init` (zonder dit veld) blijven compileren.
    var addedAt: Date? = nil

    var id: String { "\((kind ?? .live).rawValue):\(providerName):\(channelID)" }
}

/// Openbare Trakt-lijsten die als plank gebruikt kunnen worden, of een
/// persoonlijke lijst van de gekoppelde gebruiker. `watchlist` en `personal`
/// vereisen een gekoppeld Trakt-account; de rest is publiek beschikbaar.
enum TraktShelfList: Codable, Equatable, Hashable {
    case trending
    case popular
    case anticipated
    case boxOffice
    case watchlist
    case personal(id: Int, slug: String, name: String)

    var path: String {
        switch self {
        case .trending: return "trending"
        case .popular: return "popular"
        case .anticipated: return "anticipated"
        case .boxOffice: return "boxoffice"
        case .watchlist, .personal: return "" // afzonderlijk afgehandeld
        }
    }

    var requiresAuthentication: Bool {
        switch self {
        case .watchlist, .personal: return true
        case .trending, .popular, .anticipated, .boxOffice: return false
        }
    }

    func label(for kind: ShelfMediaKind) -> String {
        switch self {
        case .trending: return "Trakt trending"
        case .popular: return "Trakt populair"
        case .anticipated: return "Trakt meest verwacht"
        case .boxOffice: return "Trakt box office"
        case .watchlist: return "Mijn Trakt-watchlist"
        case .personal(_, _, let name): return name
        }
    }

    static func availableLists(for kind: ShelfMediaKind) -> [TraktShelfList] {
        kind == .movie
            ? [.trending, .popular, .anticipated, .boxOffice, .watchlist]
            : [.trending, .popular, .anticipated, .watchlist]
    }
}

/// Eén van de persoonlijke lijsten van de gekoppelde Trakt-gebruiker
/// (`GET /users/me/lists`).
struct TraktPersonalList: Decodable, Hashable {
    var name: String
    var ids: TraktPersonalListIDs

    struct TraktPersonalListIDs: Decodable, Hashable {
        var trakt: Int
        var slug: String
    }
}

/// TMDB-lijsten die als plank gebruikt kunnen worden, of een eigen (publieke)
/// TMDB-lijst, opgegeven via het numerieke lijst-ID.
enum TMDBShelfList: Codable, Equatable, Hashable {
    case popular
    case topRated
    case trendingDay
    case trendingWeek
    case nowPlayingOrOnTheAir
    case upcoming
    case personal(id: Int, name: String)

    func label(for kind: ShelfMediaKind) -> String {
        switch self {
        case .popular: return "TMDB populair"
        case .topRated: return "TMDB best beoordeeld"
        case .trendingDay: return "TMDB trending (vandaag)"
        case .trendingWeek: return "TMDB trending (deze week)"
        case .nowPlayingOrOnTheAir: return kind == .movie ? "TMDB nu in de bioscoop" : "TMDB nu op tv"
        case .upcoming: return "TMDB binnenkort"
        case .personal(_, let name): return name
        }
    }

    static func availableLists(for kind: ShelfMediaKind) -> [TMDBShelfList] {
        kind == .movie
            ? [.popular, .topRated, .trendingDay, .trendingWeek, .nowPlayingOrOnTheAir, .upcoming]
            : [.popular, .topRated, .trendingDay, .trendingWeek, .nowPlayingOrOnTheAir]
    }
}
