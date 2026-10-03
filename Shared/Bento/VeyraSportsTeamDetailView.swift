// VeyraSportsTeamDetailView.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Teamdetail bij het selecteren van een team in "Jouw Teams" (spec §13, fase 3-vervolg).
// Enkel bestaande data (`VeyraSportViewModel.events`, al geladen) -- geen nieuwe externe
// sport-API. Toont enkel onderdelen waarvoor data bestaat (spec §13: "Bouw alleen onderdelen
// waarvoor bestaande data bestaat").

import SwiftUI

struct VeyraSportsTeamDetailView: View {
    let team: StoredFavoriteTeam
    let sportModel: VeyraSportViewModel
    let now: Date
    let onPlay: (SportEvent) -> Void

    private var teamEvents: [SportEvent] {
        sportModel.events.filter { $0.homeTeamID == team.id || $0.awayTeamID == team.id }
    }
    private var live: SportEvent? { teamEvents.first { $0.isLive(at: now) } }
    private var next: SportEvent? {
        teamEvents.filter { $0.start > now }.sorted { $0.start < $1.start }.first
    }
    private var upcoming: [SportEvent] {
        teamEvents.filter { $0.start > now && $0.id != next?.id }.sorted { $0.start < $1.start }.prefix(6).map { $0 }
    }
    private var recent: [SportEvent] {
        teamEvents.filter { $0.isPast(at: now) }.sorted { $0.start > $1.start }.prefix(5).map { $0 }
    }
    private var competitions: [String] {
        Array(Set(teamEvents.compactMap(\.competition))).sorted()
    }

    var body: some View {
        VeyraDynamicBackgroundScope {
            VeyraScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    identity

                    if let live {
                        VeyraSportsStage(event: live, now: now) { onPlay(live) }
                    } else if let next {
                        VeyraSportsStage(event: next, now: now) { onPlay(next) }
                    }

                    if !upcoming.isEmpty {
                        section("Binnenkort") {
                            ForEach(upcoming) { event in row(event) }
                        }
                    }

                    if !recent.isEmpty {
                        section("Recente resultaten") {
                            ForEach(recent) { event in row(event) }
                        }
                    }

                    if !competitions.isEmpty {
                        section("Competities") {
                            ForEach(competitions, id: \.self) { name in
                                Text(name)
                                    .font(.system(size: rowTitleSize, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                        }
                    }
                }
                .padding(sidePadding)
            }
            .background(VeyraBackground())
            // Geen `.navigationTitle(team.name)` -- op tvOS toont dat een grote, gecentreerde
            // titel middenin het scherm, dubbel op met de eigen `identity`-rij hieronder.
            .navigationTitle("")

        }
    }

    private var identity: some View {
        HStack(spacing: 18) {
            VeyraAsyncImage(url: team.logo.flatMap(URL.init(string:))) { phase in
                if let image = phase.image { image.resizable().scaledToFit() }
                else { Image(systemName: "shield").resizable().scaledToFit().foregroundStyle(.white.opacity(0.25)) }
            }
            .frame(width: crestSize, height: crestSize)

            Text(team.name)
                .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: sectionHeaderSize, weight: .bold))
                .tracking(2)
                .foregroundStyle(VeyraColors.cyan.opacity(0.85))
            VStack(alignment: .leading, spacing: 10) { content() }
        }
    }

    private func row(_ event: SportEvent) -> some View {
        Button { onPlay(event) } label: {
            HStack(spacing: 10) {
                rowLogo(event.homeLogoURL)
                Text(event.home ?? event.title)
                    .font(.system(size: rowTitleSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if event.away != nil {
                    Text("–")
                        .font(.system(size: rowTitleSize, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                    rowLogo(event.awayLogoURL)
                    Text(event.away ?? "")
                        .font(.system(size: rowTitleSize, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer(minLength: 12)
                Text(event.isPast(at: now) ? (event.score?.text ?? "—") : VeyraHomeFormat.when(event.start, now: now))
                    .font(.system(size: rowMetaSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(rowPadding)
            .background(VeyraColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        #if os(tvOS)
        .buttonStyle(VeyraStreamingTileStyle())
        #else
        .buttonStyle(.plain)
        #endif
    }

    @ViewBuilder
    private func rowLogo(_ url: URL?) -> some View {
        VeyraAsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit()
            } else {
                Color.white.opacity(0.08)
            }
        }
        .frame(width: rowLogoSize, height: rowLogoSize)
        .clipShape(Circle())
    }

    // Maten -- tvOS 10-voet-UI: de rij-/sectieteksten waren met vaste kleine maten (14-16pt)
    // overal even groot als op iOS, veel te klein om van op de bank te lezen.
    #if os(tvOS)
    private let crestSize: CGFloat = 96
    private let titleSize: CGFloat = 36
    private let sidePadding: CGFloat = 60
    private let sectionHeaderSize: CGFloat = 19
    private let rowTitleSize: CGFloat = 24
    private let rowMetaSize: CGFloat = 19
    private let rowPadding: CGFloat = 20
    private let rowLogoSize: CGFloat = 36
    #else
    private let crestSize: CGFloat = 56
    private let titleSize: CGFloat = 24
    private let sidePadding: CGFloat = 16
    private let sectionHeaderSize: CGFloat = 13
    private let rowTitleSize: CGFloat = 16
    private let rowMetaSize: CGFloat = 13
    private let rowPadding: CGFloat = 14
    private let rowLogoSize: CGFloat = 24
    #endif
}
