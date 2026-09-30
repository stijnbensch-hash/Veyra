// VeyraCalendarHorizon.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// "Calendar Horizon": de "Binnenkort"-plank uit het Home Visual System-spec (Stap 12).
// Zelfde onderliggende data als voorheen (`UpcomingItem`, Trakt-kalender via
// `model.today`) -- nieuw is de indeling: groeperen op Vandaag/Morgen/Deze week/Later
// (spec §43) i.p.v. één ononderbroken rij, zodat dit iets anders voelt dan Veyra Now.
// Veyra Now toont "wat is NU relevant", Binnenkort toont "wat komt per dag/tijd" (spec §41).
// Geen eigen kaart-/knop-vorm -- de aanroeper geeft die mee via `card`, zodat bestaande
// interactie (herinnering aan/uit, contextmenu, focus) ongewijzigd blijft en hier enkel
// de groepering/lay-out nieuw is.

import SwiftUI

struct VeyraCalendarHorizon<ItemCard: View>: View {
    let title: String
    let items: [UpcomingItem]
    let now: Date
    @ViewBuilder var card: (UpcomingItem) -> ItemCard

    private var calendar: Calendar { .current }

    private enum Bucket: Int, CaseIterable {
        case today, tomorrow, week, later

        var title: String {
            switch self {
            case .today: return "Vandaag"
            case .tomorrow: return "Morgen"
            case .week: return "Deze week"
            case .later: return "Later"
            }
        }
    }

    private func bucket(for item: UpcomingItem) -> Bucket {
        let start = calendar.startOfDay(for: now)
        let dayIndex = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: item.airDate)).day ?? 999
        switch dayIndex {
        case ..<1: return .today
        case 1: return .tomorrow
        case 2...6: return .week
        default: return .later
        }
    }

    /// Volgorde van de groepen zelf blijft vast (Vandaag -> Later); binnen een groep
    /// blijft de volgorde van `items` behouden (de aanroeper sorteert al op tijd).
    private var groups: [(Bucket, [UpcomingItem])] {
        var byBucket: [Bucket: [UpcomingItem]] = [:]
        for item in items { byBucket[bucket(for: item), default: []].append(item) }
        return Bucket.allCases.compactMap { b in
            guard let list = byBucket[b], !list.isEmpty else { return nil }
            return (b, list)
        }
    }

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 24) {
                Text(title)
                    .font(.system(size: headerSize, weight: .bold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))

                ForEach(groups, id: \.0.rawValue) { bucket, list in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(bucket.title)
                            .font(.system(size: groupHeaderSize, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.65))

                        // Zelfde randen als de andere losse secties (Trending/Voor jou/
                        // Nu op tv/Top 10): .horizontal,4 + .vertical,12 i.p.v. een eigen
                        // 12pt-inspringing -- zo lijnen headers en kaarten links mooi uit
                        // (Stap 17, spacing pass).
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 24) {
                                ForEach(list) { item in card(item) }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 12)
                        }
                        .scrollClipDisabled()
                    }
                }
            }
        }
    }

    #if os(tvOS)
    private let headerSize: CGFloat = 20
    private let groupHeaderSize: CGFloat = 17
    #else
    private let headerSize: CGFloat = 13
    private let groupHeaderSize: CGFloat = 13
    #endif
}
