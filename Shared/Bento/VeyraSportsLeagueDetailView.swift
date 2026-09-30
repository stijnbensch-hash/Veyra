// VeyraSportsLeagueDetailView.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Competitiedetail bij het selecteren van een competitie in "Jouw Competities" (spec §14,
// fase 4-vervolg). Live/Vandaag/Binnenkort -- geen "Stand": de bestaande ESPN-scoreboard-bron
// levert geen standings, en spec §14 verbiedt die zelf te reconstrueren.

import SwiftUI

struct VeyraSportsLeagueDetailView: View {
    let league: SportsLeague
    let sportModel: VeyraSportViewModel
    let now: Date
    let onPlay: (SportEvent) -> Void

    private var leagueEvents: [SportEvent] {
        sportModel.events.filter { $0.competition == league.name }
    }
    private var live: [SportEvent] { leagueEvents.filter { $0.isLive(at: now) } }
    private var today: [SportEvent] {
        let start = Calendar.current.startOfDay(for: now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? now
        return leagueEvents.filter { $0.start >= start && $0.start < end && !$0.isLive(at: now) }
            .sorted { $0.start < $1.start }
    }
    private var upcoming: [SportEvent] {
        leagueEvents.filter { $0.start >= (Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now) }
            .sorted { $0.start < $1.start }
            .prefix(10).map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                identity

                if let firstLive = live.first {
                    VeyraSportsLiveStage(events: live, now: now, onPlay: onPlay)
                        .id(firstLive.id)
                }

                if !today.isEmpty {
                    section("Vandaag") { ForEach(today) { row($0) } }
                }

                if !upcoming.isEmpty {
                    section("Binnenkort") { ForEach(upcoming) { row($0) } }
                }

                if leagueEvents.isEmpty {
                    Text("Geen wedstrijden gevonden voor deze competitie.")
                        .font(.system(size: rowTitleSize))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(sidePadding)
        }
        .background(VeyraBackground())
        // Zelfde reden als bij het teamdetail: geen dubbele, gecentreerde systeemtitel.
        .navigationTitle("")
    }

    private var identity: some View {
        HStack(spacing: 14) {
            if let logoURL = league.logoURL {
                AsyncImage(url: logoURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        Image(systemName: league.symbol)
                            .resizable().scaledToFit()
                            .foregroundStyle(VeyraColors.cyan)
                    }
                }
                .frame(width: iconSize, height: iconSize)
            } else {
                Image(systemName: league.symbol)
                    .resizable().scaledToFit()
                    .foregroundStyle(VeyraColors.cyan)
                    .frame(width: iconSize, height: iconSize)
            }
            Text(league.name)
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
                Text(VeyraHomeFormat.when(event.start, now: now))
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
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit()
            } else {
                Color.white.opacity(0.08)
            }
        }
        .frame(width: rowLogoSize, height: rowLogoSize)
        .clipShape(Circle())
    }

    // Maten -- tvOS 10-voet-UI (zelfde reden als het teamdetail: vaste kleine maten waren
    // overal even klein als op iOS).
    #if os(tvOS)
    private let iconSize: CGFloat = 80
    private let titleSize: CGFloat = 36
    private let sidePadding: CGFloat = 60
    private let sectionHeaderSize: CGFloat = 19
    private let rowTitleSize: CGFloat = 24
    private let rowMetaSize: CGFloat = 19
    private let rowPadding: CGFloat = 20
    private let rowLogoSize: CGFloat = 36
    #else
    private let iconSize: CGFloat = 44
    private let titleSize: CGFloat = 24
    private let sidePadding: CGFloat = 16
    private let sectionHeaderSize: CGFloat = 13
    private let rowTitleSize: CGFloat = 16
    private let rowMetaSize: CGFloat = 13
    private let rowPadding: CGFloat = 14
    private let rowLogoSize: CGFloat = 24
    #endif
}
