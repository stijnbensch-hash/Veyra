// VeyraBentoLayout.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Het bento-raster van de Veyra-home: een SwiftUI `Layout` waarin elke tegel zijn eigen
// kolom/rij + span krijgt (zoals `grid-column: 1 / span 3` in het ontwerp).
//
//   VeyraBentoGrid(profile: .tv) {
//       verder.bentoCell(profile.cell(.verder))
//       live.bentoCell(profile.cell(.live))
//       ...
//   }
//
// Drie profielen: .tv (6 kolommen, 3 rijen), .tablet (6 kolommen, 4 rijen), .phone (2 kolommen, 7 rijen).
// De rijhoogtes zijn vast: een bento leeft van voorspelbare vlakken, en de tegelinhoud past zich aan.

import SwiftUI

// MARK: - Tegels

nonisolated enum BentoTile: String, CaseIterable, Hashable, Sendable {
    case verder      // Verder kijken (Trakt)
    case live        // Live nu (EPG + bronstatus)
    case vandaag     // Vandaag (Trakt-kalender)
    case tijd        // Tijd voor jou
    case nieuw       // Nieuw toegevoegd
    case bronnen     // Bronnen (Hub · AIOStreams · IPTV)
    case iptvFilms   // IPTV films, nieuw toegevoegd
    case iptvSeries  // IPTV series, nieuw toegevoegd
    case volgende    // De volgende 6 titels van Verder kijken
    case releasesFilms   // Nieuw uitgebrachte films (TMDB)
    case releasesSeries  // Nieuw uitgebrachte series (TMDB)
    case streaming   // Streamingdiensten (logo's)
    case collecties  // Filmcollecties (franchises)
}

extension BentoTile {
    /// De blokken die de gebruiker kan aan- of uitzetten en herschikken.
    static let configurable: [BentoTile] = [
        .verder, .releasesFilms, .releasesSeries, .volgende, .live, .vandaag,
        .iptvFilms, .iptvSeries, .streaming, .collecties
    ]

    var title: String {
        switch self {
        case .verder: return "Verder kijken"
        case .volgende: return "Verder kijken (rij)"
        case .releasesFilms: return "Nieuwe films"
        case .releasesSeries: return "Nieuwe series"
        case .live: return "Live nu"
        case .vandaag: return "Binnenkort"
        case .iptvFilms: return "IPTV films"
        case .iptvSeries: return "IPTV series"
        case .streaming: return "Streamingdiensten"
        case .collecties: return "Filmcollecties"
        case .tijd, .nieuw, .bronnen: return rawValue
        }
    }

    var detail: String {
        switch self {
        case .verder: return "De titel die je nu kijkt, via Trakt"
        case .volgende: return "De rest van Verder kijken als kleine kaders"
        case .releasesFilms: return "Nieuw uitgebrachte films (TMDB)"
        case .releasesSeries: return "Nieuw uitgebrachte series (TMDB)"
        case .live: return "Wat er nu op je IPTV-zenders loopt"
        case .vandaag: return "Aankomende afleveringen en films (Trakt)"
        case .iptvFilms: return "Nieuw toegevoegde films van je IPTV-provider"
        case .iptvSeries: return "Nieuw toegevoegde series van je IPTV-provider"
        case .streaming: return "Netflix, Disney+ en andere diensten"
        case .collecties: return "Franchises en eigen lijsten"
        case .tijd, .nieuw, .bronnen: return ""
        }
    }

    var symbol: String {
        switch self {
        case .verder, .volgende: return "play.circle"
        case .releasesFilms: return "film"
        case .releasesSeries: return "tv"
        case .live: return "dot.radiowaves.left.and.right"
        case .vandaag: return "calendar"
        case .iptvFilms: return "film.stack"
        case .iptvSeries: return "rectangle.stack"
        case .streaming: return "play.rectangle.on.rectangle"
        case .collecties: return "square.stack"
        case .tijd, .nieuw, .bronnen: return "square"
        }
    }
}

// MARK: - Cel

nonisolated struct BentoCell: Equatable {
    var column: Int      // 0-gebaseerd
    var row: Int         // 0-gebaseerd
    var columns: Int = 1
    var rows: Int = 1
}

private nonisolated struct BentoCellKey: LayoutValueKey {
    static let defaultValue = BentoCell(column: 0, row: 0)
}

extension View {
    func bentoCell(_ cell: BentoCell) -> some View {
        layoutValue(key: BentoCellKey.self, value: cell)
    }
}

// MARK: - Profiel

struct BentoProfile {
    let columns: Int
    let rowHeights: [CGFloat]
    let spacing: CGFloat
    let cells: [BentoTile: BentoCell]

    func cell(_ tile: BentoTile) -> BentoCell { cells[tile] ?? BentoCell(column: 0, row: 0) }

    /// tvOS 1920 × 1080: 12 kolommen. Bovenaan Verder kijken (6) met nieuwe films (3) en series (3) ernaast,
    /// daaronder de volgende 6 titels, dan Live nu | Binnenkort, de IPTV-planken en de rest.
    static let tv = BentoProfile(
        columns: 12, rowHeights: [240, 240, 206, 520, 450, 168, 372], spacing: 24,
        cells: [
            .verder:         BentoCell(column: 0, row: 0, columns: 6, rows: 2),
            .releasesFilms:  BentoCell(column: 6, row: 0, columns: 3, rows: 2),
            .releasesSeries: BentoCell(column: 9, row: 0, columns: 3, rows: 2),
            .volgende:       BentoCell(column: 0, row: 2, columns: 12, rows: 1),
            .live:           BentoCell(column: 0, row: 3, columns: 6, rows: 1),
            .vandaag:        BentoCell(column: 6, row: 3, columns: 6, rows: 1),
            .iptvFilms:      BentoCell(column: 0, row: 4, columns: 6, rows: 1),
            .iptvSeries:     BentoCell(column: 6, row: 4, columns: 6, rows: 1),
            .streaming:      BentoCell(column: 0, row: 5, columns: 12, rows: 1),
            .collecties:     BentoCell(column: 0, row: 6, columns: 12, rows: 1),
        ])

    /// iPad (regular): zelfde opbouw als tvOS, kleiner.
    static let tablet = BentoProfile(
        columns: 12, rowHeights: [190, 190, 136, 290, 280, 96, 220], spacing: 12,
        cells: [
            .verder:         BentoCell(column: 0, row: 0, columns: 6, rows: 2),
            .releasesFilms:  BentoCell(column: 6, row: 0, columns: 3, rows: 2),
            .releasesSeries: BentoCell(column: 9, row: 0, columns: 3, rows: 2),
            .volgende:       BentoCell(column: 0, row: 2, columns: 12, rows: 1),
            .live:           BentoCell(column: 0, row: 3, columns: 6, rows: 1),
            .vandaag:        BentoCell(column: 6, row: 3, columns: 6, rows: 1),
            .iptvFilms:      BentoCell(column: 0, row: 4, columns: 6, rows: 1),
            .iptvSeries:     BentoCell(column: 6, row: 4, columns: 6, rows: 1),
            .streaming:      BentoCell(column: 0, row: 5, columns: 12, rows: 1),
            .collecties:     BentoCell(column: 0, row: 6, columns: 12, rows: 1),
        ])

    /// iPhone (compact): 2 kolommen.
    static let phone = BentoProfile(
        columns: 2, rowHeights: [140, 140, 112, 300, 300, 140, 140, 270, 270, 76, 210, 150], spacing: 12,
        cells: [
            .verder:         BentoCell(column: 0, row: 0, columns: 2, rows: 2),
            .volgende:       BentoCell(column: 0, row: 2, columns: 2, rows: 1),
            .releasesFilms:  BentoCell(column: 0, row: 3, columns: 2, rows: 1),
            .releasesSeries: BentoCell(column: 0, row: 4, columns: 2, rows: 1),
            .live:           BentoCell(column: 0, row: 5, columns: 2, rows: 2),
            .iptvFilms:      BentoCell(column: 0, row: 7, columns: 2, rows: 1),
            .iptvSeries:     BentoCell(column: 0, row: 8, columns: 2, rows: 1),
            .streaming:      BentoCell(column: 0, row: 9, columns: 2, rows: 1),
            .collecties:     BentoCell(column: 0, row: 10, columns: 2, rows: 1),
            .vandaag:        BentoCell(column: 0, row: 11, columns: 2, rows: 1),
        ])
}

// MARK: - Dynamisch raster (volgorde en zichtbaarheid komen van de gebruiker)

enum BentoDevice { case tv, tablet, phone }

extension BentoTile {
    /// Natuurlijke breedte in kolommen (van 12; op de telefoon altijd de volle 2).
    fileprivate func span(_ device: BentoDevice) -> Int {
        if device == .phone { return 2 }
        switch self {
        case .verder, .live, .vandaag, .iptvFilms, .iptvSeries: return 6
        case .releasesFilms, .releasesSeries: return 3
        default: return 12
        }
    }

    /// Hoogte van het blok in punten. Rijen sluiten aan op hun inhoud, zodat de afstand tussen alle blokken
    /// overal gelijk is (het raster-`spacing`) en er geen lege stroken tussen blokken vallen.
    fileprivate func height(_ device: BentoDevice) -> CGFloat {
        // Naam onder de collectiebanners (Instellingen → Home → Filmcollecties) kost een extra regel.
        let names = (UserDefaults.standard.object(forKey: "veyra.bento.collectionNames") as? Bool) ?? true
        switch device {
        case .tv:
            switch self {
            case .verder, .releasesFilms, .releasesSeries: return 504
            case .volgende: return 202
            case .live, .vandaag: return 520
            case .iptvFilms, .iptvSeries: return 450
            case .streaming: return 156
            case .collecties: return names ? 260 : 226
            default: return 300
            }
        case .tablet:
            switch self {
            case .verder, .releasesFilms, .releasesSeries: return 392
            case .volgende: return 116
            case .live: return 300
            case .vandaag: return 308
            case .iptvFilms, .iptvSeries: return 280
            case .streaming: return 76
            case .collecties: return names ? 152 : 130
            default: return 200
            }
        case .phone:
            switch self {
            case .verder: return 292
            case .live: return 300
            case .volgende: return 92
            case .releasesFilms, .releasesSeries: return 300
            case .iptvFilms, .iptvSeries: return 270
            case .streaming: return 60
            case .collecties: return names ? 128 : 106
            case .vandaag: return 308
            default: return 200
            }
        }
    }
}

extension BentoProfile {
    /// Legt de opgegeven blokken op volgorde in rijen: blokken die samen in 12 kolommen passen delen een rij,
    /// en de overgebleven kolommen worden over de blokken van die rij verdeeld (zodat er geen gaten vallen).
    static func make(_ device: BentoDevice, order requested: [BentoTile]) -> BentoProfile {
        var order = requested
        // Op tv en iPad staan Nieuwe films en Nieuwe series naast het grote Verder kijken (6 + 3 + 3 kolommen),
        // ook als de volgorde (bv. via iPhone gesynchroniseerd) ze ergens anders heeft gezet.
        if device != .phone, order.contains(.verder) {
            let pair = order.filter { $0 == .releasesFilms || $0 == .releasesSeries }
            order.removeAll { pair.contains($0) }
            if let verder = order.firstIndex(of: .verder) {
                order.insert(contentsOf: pair, at: verder + 1)
            }
        }
        let columns = device == .phone ? 2 : 12
        let spacing: CGFloat = device == .tv ? 24 : 12

        var rows: [[(tile: BentoTile, span: Int)]] = []
        var current: [(tile: BentoTile, span: Int)] = []
        var used = 0
        for tile in order {
            let span = min(tile.span(device), columns)
            if used + span > columns, !current.isEmpty {
                rows.append(current)
                current = []
                used = 0
            }
            current.append((tile, span))
            used += span
        }
        if !current.isEmpty { rows.append(current) }

        var heights: [CGFloat] = []
        var cells: [BentoTile: BentoCell] = [:]
        for (rowIndex, row) in rows.enumerated() {
            var spans = row.map(\.span)
            var extra = columns - spans.reduce(0, +)
            var i = 0
            while extra > 0, !spans.isEmpty {
                spans[i % spans.count] += 1
                extra -= 1
                i += 1
            }
            var column = 0
            for (index, entry) in row.enumerated() {
                cells[entry.tile] = BentoCell(column: column, row: rowIndex, columns: spans[index], rows: 1)
                column += spans[index]
            }
            heights.append(row.map { $0.tile.height(device) }.max() ?? 0)
        }
        return BentoProfile(columns: columns, rowHeights: heights, spacing: spacing, cells: cells)
    }
}

// MARK: - Layout

struct VeyraBentoGrid: Layout {
    let profile: BentoProfile

    private var totalHeight: CGFloat {
        profile.rowHeights.reduce(0, +) + profile.spacing * CGFloat(max(profile.rowHeights.count - 1, 0))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 1000, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let gap = profile.spacing
        let columns = max(profile.columns, 1)
        let columnWidth = (bounds.width - gap * CGFloat(columns - 1)) / CGFloat(columns)

        var rowTop: [CGFloat] = []
        var y = bounds.minY
        for height in profile.rowHeights { rowTop.append(y); y += height + gap }

        for subview in subviews {
            let cell = subview[BentoCellKey.self]
            guard cell.row >= 0, cell.row < profile.rowHeights.count, cell.columns > 0, cell.rows > 0 else { continue }

            let lastRow = min(cell.row + cell.rows, profile.rowHeights.count) - 1
            let top = rowTop[cell.row]
            let bottom = rowTop[lastRow] + profile.rowHeights[lastRow]
            let x = bounds.minX + CGFloat(cell.column) * (columnWidth + gap)
            let width = CGFloat(cell.columns) * columnWidth + CGFloat(cell.columns - 1) * gap

            subview.place(at: CGPoint(x: x, y: top), anchor: .topLeading,
                          proposal: ProposedViewSize(width: width, height: bottom - top))
        }
    }
}
