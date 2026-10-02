// VeyraSportsTeamStrip.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// "Jouw Teams" -- eerste persoonlijke sectie van de Sport-redesign (spec §7-10, fase 3).
// GEEN nieuwe favorieten-store: gebruikt rechtstreeks de bestaande `SportsFavorites`
// (Shared/Sports/SportsFavorites.swift) als enige bron van waarheid. Wedstrijddata komt
// uit de al bestaande `VeyraSportViewModel.myTeamEvents(favoriteIDs:)` (geen tweede fetch).
// Kleurregel (spec §1): cyaan = focus/Veyra, rood = uitsluitend LIVE. Teamkleuren blijven
// beperkt tot het logo zelf, nooit de kaart-achtergrond (spec §2/§8).

import SwiftUI

struct VeyraSportsTeamStrip: View {
    let teams: [StoredFavoriteTeam]
    let sportModel: VeyraSportViewModel
    let now: Date
    let onSelect: (StoredFavoriteTeam) -> Void

    var body: some View {
        if !teams.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Jouw teams")
                    .font(.system(size: headerSize, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: cardGap) {
                        ForEach(teams) { team in
                            tile(team)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 12)
                }
                .scrollClipDisabled()
            }
        }
    }

    // MARK: - Eén tegel

    @ViewBuilder
    private func tile(_ team: StoredFavoriteTeam) -> some View {
        Button { onSelect(team) } label: {
            TeamTileContent(team: team, event: nextEvent(for: team), now: now, width: tileWidth, height: tileHeight)
        }
        #if os(tvOS)
        .buttonStyle(VeyraStreamingTileStyle())
        #else
        .buttonStyle(.plain)
        #endif
    }

    /// Live wedstrijd heeft voorrang boven de eerstvolgende (zelfde volgorde als
    /// `myTeamEvents`); geen eigen sorteerlogica hier.
    private func nextEvent(for team: StoredFavoriteTeam) -> SportEvent? {
        sportModel.myTeamEvents(at: now, favoriteIDs: [team.id], limit: 1).first
    }

    // Maten -- tvOS 10-voet-UI, iOS/iPadOS/macOS compacter (zelfde onderscheid als de
    // andere Home/Sport-secties dit seizoen).
    #if os(tvOS)
    private let headerSize: CGFloat = 21
    private let cardGap: CGFloat = 24
    private let tileWidth: CGFloat = 250
    private let tileHeight: CGFloat = 270
    #else
    private let headerSize: CGFloat = 14
    private let cardGap: CGFloat = 14
    private let tileWidth: CGFloat = 136
    private let tileHeight: CGFloat = 150
    #endif
}

/// Eigen view (i.p.v. een losse `@ViewBuilder`-functie) zodat `@Environment(\.isFocused)`
/// en `@Environment(\.accessibilityReduceMotion)` hier gelezen kunnen worden -- nodig voor de
/// cyaan focusrand/glow (spec §8/§48) en om de LIVE-pulse bij Reduce Motion uit te zetten (spec §51).
private struct TeamTileContent: View {
    let team: StoredFavoriteTeam
    let event: SportEvent?
    let now: Date
    let width: CGFloat
    let height: CGFloat

    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseUp = false

    private var isLive: Bool { event?.isLive(at: now) ?? false }

    private var metaLine: String? {
        guard let event else { return nil }
        if isLive { return event.score?.text ?? "Live" }
        if event.start > now { return VeyraHomeFormat.when(event.start, now: now) }
        return nil
    }

    var body: some View {
        VStack(spacing: 10) {
            VeyraAsyncImage(url: team.logo.flatMap(URL.init(string:))) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Image(systemName: "shield")
                        .resizable().scaledToFit()
                        .foregroundStyle(.white.opacity(0.25))
                        .padding(crestPadding)
                }
            }
            .frame(width: crestSize, height: crestSize)

            VStack(spacing: 2) {
                Text(team.name)
                    .font(.system(size: nameSize, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let metaLine {
                    Text(metaLine)
                        .font(.system(size: metaSize, weight: .semibold))
                        // Live blijft rood (status), enkel de eerstvolgende-datum wordt cyaan.
                        .foregroundStyle(isLive ? VeyraColors.red : VeyraColors.cyan)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(width: width, height: height)
        .background(.white.opacity(isFocused ? 0.08 : 0.05), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isFocused ? VeyraColors.cyan.opacity(0.6) : .white.opacity(0.08),
                             lineWidth: isFocused ? 2 : 1)
        )
        .overlay(alignment: .topTrailing) {
            // "● LIVE" blijft een klein rood label -- nooit de volledige kaart (spec §10).
            // Enkel dit label mag pulseren, en enkel zonder Reduce Motion (spec §49/§51).
            if isLive {
                HStack(spacing: 4) {
                    Circle().fill(VeyraColors.red).frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.5)
                }
                .foregroundStyle(VeyraColors.red)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.black.opacity(0.55), in: Capsule())
                .opacity(reduceMotion ? 1 : (pulseUp ? 1 : 0.70))
                .padding(8)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulseUp = true }
                }
            }
        }
        .scaleEffect(isFocused ? 1.05 : 1)
        .shadow(color: isFocused ? VeyraColors.cyan.opacity(0.28) : .clear, radius: 18)
        .animation(.easeOut(duration: 0.16), value: isFocused)
    }

    private var crestSize: CGFloat { width * 0.48 }
    private var crestPadding: CGFloat { crestSize * 0.16 }
    private var nameSize: CGFloat { width > 200 ? 22 : 17 }
    private var metaSize: CGFloat { width > 200 ? 18 : 14 }
}
