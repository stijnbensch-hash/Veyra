// VeyraSportsTodayTimeline.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// "Vandaag" -- chronologisch sportschema met dunne verticale tijdlijn i.p.v. een posterrij
// (spec §21-23, fase 6). Marker: cyaan = aankomend, rood = live, grijs/gedimd = afgelopen
// (spec §22). Volgorde komt van `VeyraSportViewModel.today(...)` -- tijd primair, persoonlijke
// relevantie enkel als tiebreak, hier enkel weergegeven.

import SwiftUI

struct VeyraSportsTodayTimeline: View {
    let events: [SportEvent]
    let now: Date
    let onSelect: (SportEvent) -> Void

    var body: some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Text("Vandaag")
                        .font(.system(size: headerSize, weight: .heavy, design: .rounded))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))
                    VeyraSectionTitleLine()
                }

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        row(event, isLast: index == events.count - 1)
                    }
                }
            }
        }
    }

    private func row(_ event: SportEvent, isLast: Bool) -> some View {
        let live = event.isLive(at: now)
        let past = event.isPast(at: now)
        let markerColor: Color = live ? VeyraColors.red : (past ? .white.opacity(0.25) : VeyraColors.cyan)

        return Button { onSelect(event) } label: {
            HStack(alignment: .top, spacing: rowGap) {
                Text(event.start.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: timeSize, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(past ? .white.opacity(0.4) : .white)
                    .frame(width: timeWidth, alignment: .leading)

                VStack(spacing: 0) {
                    Circle()
                        .fill(markerColor)
                        .frame(width: dotSize, height: dotSize)
                    if !isLast {
                        Rectangle()
                            .fill(.white.opacity(0.12))
                            .frame(width: 1.5)
                            .frame(minHeight: lineMinHeight)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: titleSize, weight: .semibold))
                        .foregroundStyle(past ? .white.opacity(0.45) : .white)
                        .lineLimit(1)
                    if let competition = event.competition {
                        Text(competition)
                            .font(.system(size: metaSize, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    if live {
                        HStack(spacing: 5) {
                            Circle().fill(VeyraColors.red).frame(width: 5, height: 5)
                            Text(event.score?.text ?? "LIVE")
                                .font(.system(size: metaSize, weight: .bold))
                                .monospacedDigit()
                        }
                        .foregroundStyle(VeyraColors.red)
                        .padding(.top, 2)
                    }
                }
                .padding(.bottom, rowGap)

                Spacer(minLength: 0)
            }
        }
        #if os(tvOS)
        .buttonStyle(VeyraStreamingTileStyle())
        #else
        .buttonStyle(.plain)
        #endif
    }

    #if os(tvOS)
    private let headerSize: CGFloat = 19
    private let rowGap: CGFloat = 18
    private let timeSize: CGFloat = 18
    private let timeWidth: CGFloat = 64
    private let dotSize: CGFloat = 12
    private let lineMinHeight: CGFloat = 26
    private let titleSize: CGFloat = 19
    private let metaSize: CGFloat = 15
    #else
    private let headerSize: CGFloat = 13
    private let rowGap: CGFloat = 12
    private let timeSize: CGFloat = 13
    private let timeWidth: CGFloat = 44
    private let dotSize: CGFloat = 9
    private let lineMinHeight: CGFloat = 18
    private let titleSize: CGFloat = 14
    private let metaSize: CGFloat = 12
    #endif
}
