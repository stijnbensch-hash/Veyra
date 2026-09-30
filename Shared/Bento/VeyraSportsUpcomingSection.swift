// VeyraSportsUpcomingSection.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// "Binnenkort" -- toekomstige wedstrijden van gekozen teams/competities, gegroepeerd per dag
// (spec §24/§25, fase 7). Compacte eventkaarten met teamlogo's, geen poster/backdrop nodig.
// Data komt al gefilterd/gesorteerd binnen via `VeyraSportViewModel.upcoming(...)` -- enkel de
// dag-groepering gebeurt hier (zelfde idioom als de eerdere `VeyraCalendarHorizon`).

import SwiftUI

struct VeyraSportsUpcomingSection: View {
    let events: [SportEvent]
    let now: Date
    let onSelect: (SportEvent) -> Void

    private var calendar: Calendar { .current }

    private enum Bucket: Int, CaseIterable {
        case tomorrow, week, later

        var title: String {
            switch self {
            case .tomorrow: return "Morgen"
            case .week: return "Deze week"
            case .later: return "Later"
            }
        }
    }

    private func bucket(for event: SportEvent) -> Bucket {
        let start = calendar.startOfDay(for: now)
        let dayIndex = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: event.start)).day ?? 999
        switch dayIndex {
        case 1: return .tomorrow
        case 2...6: return .week
        default: return .later
        }
    }

    private var groups: [(Bucket, [SportEvent])] {
        var byBucket: [Bucket: [SportEvent]] = [:]
        for event in events { byBucket[bucket(for: event), default: []].append(event) }
        return Bucket.allCases.compactMap { b in
            guard let list = byBucket[b], !list.isEmpty else { return nil }
            return (b, list)
        }
    }

    var body: some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 24) {
                Text("Binnenkort")
                    .font(.system(size: headerSize, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))

                ForEach(groups, id: \.0.rawValue) { bucket, list in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(bucket.title)
                            .font(.system(size: groupHeaderSize, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.65))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: cardGap) {
                                ForEach(list) { event in card(event) }
                            }
                            .padding(.vertical, 4)
                        }
                        .scrollClipDisabled()
                    }
                }
            }
        }
    }

    // Zelfde kaart als "Ontdek meer" (VeyraSportMatchCard) -- consistente maat/stijl door de hele Sport-tab.
    @ViewBuilder
    private func card(_ event: SportEvent) -> some View {
        Button { onSelect(event) } label: { VeyraSportMatchCard(event: event, now: now, reminderOn: false) }
        #if os(tvOS)
        .buttonStyle(VeyraSportCardStyle(isLive: event.isLive(at: now)))
        #else
        .buttonStyle(.plain)
        #endif
    }

    #if os(tvOS)
    private let headerSize: CGFloat = 21
    private let groupHeaderSize: CGFloat = 19
    private let cardGap: CGFloat = 22
    #else
    private let headerSize: CGFloat = 14
    private let groupHeaderSize: CGFloat = 14
    private let cardGap: CGFloat = 14
    #endif
}
