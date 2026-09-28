// VeyraFlowEPGView.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// "Flow EPG": alternatieve gids-weergave naast de bestaande grid. Per zender
// staat het huidige programma als grote kaart (met
// voortgangsbalk) plus de eerstvolgende programma's als "Straks/Daarna"-kaarten
// erachter. Bewust GEEN geneste horizontale ScrollView per rij (dat botst op tvOS met de
// verticale focus-navigatie tussen rijen); de "Straks/Daarna"-kaarten zijn een vaste
// rij van maximaal twee, niet zelf scrollbaar. Een tik op een kaart (huidig of komend) speelt
// de zender direct af — geen tussenliggende bevestigingsstap.
//
// Gebruikt dezelfde databron als de bestaande grid (`VeyraEPGStore`/`VeyraGuideChannel`/
// `VeyraEPGProgramme`) -- geen apart datamodel, dus geen risico op afwijkende gegevens tussen
// Grid en Flow. Op iOS/macOS staat het zenderlogo in de rij; tvOS toont in
// Flow de aangepaste kanaalnaam zonder logo.

import SwiftUI

enum VeyraEPGViewMode: String {
    case grid, flow
}

struct VeyraFlowEPGView: View {
    let guide: VeyraEPGStore
    let channels: [VeyraGuideChannel]
    let now: Date
    let selectedChannelID: String?
    let logoOverrideVersion: Int
    let onPlay: (VeyraGuideChannel) -> Void
    let onFocus: (VeyraGuideChannel) -> Void

    private var rowSpacing: CGFloat {
        #if os(tvOS)
        22
        #else
        14
        #endif
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: rowSpacing) {
                ForEach(channels) { row in
                    VeyraFlowEPGRow(
                        guide: guide,
                        row: row,
                        now: now,
                        isSelected: row.id == selectedChannelID,
                        logoOverrideVersion: logoOverrideVersion,
                        onPlay: { onPlay(row) },
                        onFocus: { onFocus(row) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

private struct VeyraFlowEPGRow: View {
    let guide: VeyraEPGStore
    let row: VeyraGuideChannel
    let now: Date
    let isSelected: Bool
    let logoOverrideVersion: Int
    let onPlay: () -> Void
    let onFocus: () -> Void

    private enum FocusTarget: Hashable {
        case channel, current, upcoming(Int)
    }

    @FocusState private var focusedTarget: FocusTarget?

    private var programmes: [VeyraEPGProgramme] { guide.programmes(for: row) }
    private var current: VeyraEPGProgramme? { programmes.first { $0.isOnAir(at: now) } }
    private var upcoming: [VeyraEPGProgramme] {
        Array(programmes.filter { $0.start >= now }.prefix(2))
    }
    private static let upcomingLabels = ["Straks", "Daarna"]

    var body: some View {
        Group {
            #if os(tvOS)
            // De aangepaste zendernaam staat in de programmakaart. Op tvOS
            // gebruiken we in Flow geen losse logo's.
            HStack(alignment: .center, spacing: 20) {
                currentCard
                upcomingCards
            }
            #else
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    channelButton
                    currentCard
                    Button(action: onFocus) {
                        Image(systemName: "play.rectangle")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Voorvertoning van \(row.channel.name)")
                }
                upcomingCards
                    .padding(.leading, 72)
            }
            #endif
        }
        .onChange(of: focusedTarget) { _, target in
            if target != nil { onFocus() }
        }
        .background(
            isSelected ? VeyraHomeStyle.cyan.opacity(0.06) : .clear,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isSelected ? VeyraHomeStyle.cyan.opacity(0.45) : .clear,
                    lineWidth: 1
                )
        }
    }

    private var channelButton: some View {
            Button(action: onPlay) {
                VeyraFlowChannelLogo(channel: row.channel, logoOverrideVersion: logoOverrideVersion)
            }
            .buttonStyle(VeyraGlassButtonStyle())
            .focused($focusedTarget, equals: .channel)
    }

    // De tijdlijn gebruikt vaste kaarten en blijft per zender in dezelfde scrollrij.
    private var upcomingCards: some View {
        #if os(tvOS)
        HStack(spacing: 16) {
            ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, programme in
                Button(action: onPlay) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Self.upcomingLabels[index])
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(VeyraHomeStyle.cyan)
                        Text(programme.title)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(2)
                        Text(programme.start.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(VeyraHomeStyle.faint)
                    }
                    .frame(width: 240, alignment: .leading)
                    .padding(18)
                }
                .buttonStyle(VeyraGlassButtonStyle())
                .focused($focusedTarget, equals: .upcoming(index))
            }
        }
        #else
        HStack(spacing: 10) {
            ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, programme in
                Button(action: onPlay) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Self.upcomingLabels[index])
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(VeyraHomeStyle.cyan)
                        Text(programme.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(2)
                        Text(programme.start.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(VeyraHomeStyle.faint)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                .buttonStyle(VeyraGlassButtonStyle())
                .focused($focusedTarget, equals: .upcoming(index))
            }
        }
        #endif
    }

    private var channelDisplayName: String {
        ChannelNameOverrideStore.effectiveName(channelID: row.channel.id, defaultName: row.channel.name)
    }

    private var currentCard: some View {
        Button(action: onPlay) {
            HStack(spacing: cardMetrics.hSpacing) {
                VStack(alignment: .leading, spacing: cardMetrics.textSpacing) {
                    Text(channelDisplayName)
                        .font(.system(size: cardMetrics.nameSize, weight: .bold))
                        .foregroundStyle(VeyraHomeStyle.faint)
                        .lineLimit(1)

                    if let current {
                        Text(current.title)
                            .font(.system(size: cardMetrics.titleSize, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        HStack(spacing: 10) {
                            Text(timeRange(current))
                                .font(.system(size: cardMetrics.timeSize, weight: .medium))
                                .foregroundStyle(VeyraHomeStyle.cyan)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.14))
                                    Capsule().fill(VeyraHomeStyle.cyan)
                                        .frame(width: geo.size.width * progress(current))
                                }
                            }
                            .frame(height: cardMetrics.barHeight)
                        }
                    } else {
                        Text("Geen gidsgegevens")
                            .font(.system(size: cardMetrics.titleSize - 4, weight: .medium))
                            .foregroundStyle(VeyraHomeStyle.faint)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(cardMetrics.padding)
        }
        // Dezelfde gedeelde glaslook als Instant Peek -- `.plain` liet hier op tvOS het
        // systeem-eigen witte focuskader nog door (zichtbaar als een witte balk bij focus).
        .buttonStyle(VeyraGlassButtonStyle())
        .focused($focusedTarget, equals: .current)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct CardMetrics {
        let hSpacing: CGFloat
        let textSpacing: CGFloat
        let nameSize: CGFloat
        let titleSize: CGFloat
        let timeSize: CGFloat
        let barHeight: CGFloat
        let padding: CGFloat
    }

    private var cardMetrics: CardMetrics {
        #if os(tvOS)
        CardMetrics(hSpacing: 0, textSpacing: 10, nameSize: 20, titleSize: 34,
                    timeSize: 21, barHeight: 7, padding: 24)
        #else
        CardMetrics(hSpacing: 16, textSpacing: 6, nameSize: 13, titleSize: 22,
                    timeSize: 15, barHeight: 4, padding: 16)
        #endif
    }

    private func timeRange(_ p: VeyraEPGProgramme) -> String {
        "\(p.start.formatted(.dateTime.hour().minute()))–\(p.end.formatted(.dateTime.hour().minute()))"
    }

    private func progress(_ p: VeyraEPGProgramme) -> Double {
        guard p.isOnAir(at: now) else { return 0 }
        let total = p.end.timeIntervalSince(p.start)
        guard total > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(p.start) / total))
    }
}

struct VeyraFlowChannelLogo: View {
    let channel: IPTVChannel
    let logoOverrideVersion: Int

    private var effectiveURL: URL? {
        ChannelLogoOverrideStore.effectiveLogoURL(
            channelID: channel.id,
            defaultLogoURL: channel.logoURL
        )
    }

    var body: some View {
        ZStack {
            Color.white.opacity(0.05)
            AsyncImage(url: effectiveURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit().padding(10)
                } else {
                    Text(channel.name.prefix(3))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .id(logoOverrideVersion)
        }
        #if os(tvOS)
        .frame(width: 96, height: 64)
        #else
        .frame(width: 60, height: 56)
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
