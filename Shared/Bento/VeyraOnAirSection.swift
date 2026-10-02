// VeyraOnAirSection.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// "On Air": de "Nu op tv"-plank uit het Home Visual System-spec (Stap 13) -- GEEN
// volledige EPG op Home (spec §47), enkel een rij zenders met wat er nu op loopt.
// Zelfde focus-promotie-idioom als "Trending" (VeyraDiscoveryFlow.swift): het
// gefocuste/geselecteerde kanaal wordt een grote kaart (logo, huidig programma,
// voortgang, resterende tijd), de rest blijft compact (logo, programmanaam,
// voortgang) -- spec §48/§49.
// Data + voortgang: dezelfde bestaande `BentoLiveRow` (`model.liveRows`, al gebruikt
// door de vroegere "Live nu"-rij) -- `progress`/`remainingMinutes` komen al uit de
// echte EPG-start/eindtijden en worden al periodiek herberekend door de aanroeper
// (TimelineView elke 30s); geen nieuwe timer-engine (spec §50).

import SwiftUI

struct VeyraOnAirSection: View {
    let title: String
    let rows: [BentoLiveRow]
    let onSelect: (BentoLiveRow) -> Void

    #if os(tvOS)
    @FocusState private var focusedID: String?
    #endif
    @State private var tappedID: String?

    private var bigID: String? {
        #if os(tvOS)
        focusedID ?? rows.first?.id
        #else
        tappedID ?? rows.first?.id
        #endif
    }

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: headerSize, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .center, spacing: cardGap) {
                            ForEach(rows) { row in
                                card(row, big: row.id == bigID)
                                    .id(row.id)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 12)
                    }
                    .scrollClipDisabled()
                    .onChange(of: bigID) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.easeOut(duration: 0.35)) { proxy.scrollTo(newValue, anchor: .center) }
                    }
                }
            }
        }
    }

    // MARK: - Eén tegel

    @ViewBuilder
    private func card(_ row: BentoLiveRow, big: Bool) -> some View {
        #if os(tvOS)
        Button { onSelect(row) } label: {
            cardContent(row, big: big)
        }
        .buttonStyle(VeyraStreamingTileStyle())
        .focused($focusedID, equals: row.id)
        #else
        Button {
            tappedID = row.id
            onSelect(row)
        } label: {
            cardContent(row, big: big)
        }
        .buttonStyle(.plain)
        #endif
    }

    private func cardContent(_ row: BentoLiveRow, big: Bool) -> some View {
        VStack(alignment: .leading, spacing: big ? 12 : 8) {
            HStack(alignment: .top) {
                VeyraAsyncImage(url: row.logoURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        Color.white.opacity(0.1)
                    }
                }
                .frame(width: logoSize, height: logoSize)
                .clipShape(RoundedRectangle(cornerRadius: logoSize * 0.22, style: .continuous))

                Spacer(minLength: 0)

                // Rood enkel als klein label, geen volledig rode kaart (spec §54).
                if row.isSports {
                    HStack(spacing: 4) {
                        Circle().fill(VeyraColors.red).frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.system(size: metaSize * 0.8, weight: .bold))
                            .tracking(1)
                    }
                    .foregroundStyle(VeyraColors.red)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(row.channelName)
                    .font(.system(size: metaSize, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                Text(row.title)
                    .font(.system(size: big ? titleSize : metaSize, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(big ? 2 : 1)
            }

            progressBar(row)

            if big {
                Text("Nog \(row.remainingMinutes) min")
                    .font(.system(size: metaSize * 0.85, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer(minLength: 0)
        }
        .padding(cardPaddingH)
        .frame(width: big ? bigWidth : smallWidth, height: cardHeight, alignment: .topLeading)
        .background(VeyraColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(big ? VeyraColors.cyan.opacity(0.6) : .clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(big ? 0.3 : 0), radius: big ? 14 : 0, y: big ? 6 : 0)
        .animation(.easeOut(duration: 0.3), value: big)
    }

    private func progressBar(_ row: BentoLiveRow) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule().fill(VeyraColors.cyan)
                    .frame(width: max(0, min(1, row.progress)) * geo.size.width)
            }
        }
        .frame(height: 4)
    }

    // Maten -- tvOS 10-voet-UI, iOS/iPadOS/macOS compacter van dichtbij bekeken
    // (zelfde onderscheid als `VeyraDiscoveryFlow`).
    #if os(tvOS)
    private let headerSize: CGFloat = 19
    private let cardGap: CGFloat = 20
    private let bigWidth: CGFloat = 480
    private let smallWidth: CGFloat = 260
    private let cardHeight: CGFloat = 200
    private let cardPaddingH: CGFloat = 22
    private let logoSize: CGFloat = 48
    private let titleSize: CGFloat = 26
    private let metaSize: CGFloat = 18
    #else
    private let headerSize: CGFloat = 13
    private let cardGap: CGFloat = 12
    private let bigWidth: CGFloat = 280
    private let smallWidth: CGFloat = 170
    private let cardHeight: CGFloat = 130
    private let cardPaddingH: CGFloat = 14
    private let logoSize: CGFloat = 30
    private let titleSize: CGFloat = 16
    private let metaSize: CGFloat = 12
    #endif
}
