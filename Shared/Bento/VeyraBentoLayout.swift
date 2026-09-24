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

enum BentoTile: CaseIterable, Hashable {
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
