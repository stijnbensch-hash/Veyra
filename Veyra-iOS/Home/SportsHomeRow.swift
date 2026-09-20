import SwiftUI

/// "Sport vandaag" op de iOS Home-tab. Hergebruikt dezelfde Shared
/// `SportsStore`/`SportsModels` als de tvOS-rij (`SportsHomeView`), met een
/// eenvoudige native iOS-rij en een lichte detailweergave i.p.v. de volledige
/// tvOS-focuservaring.
struct SportsHomeRow: View {
    @StateObject private var store = SportsStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedMatch: SportsMatch?

    var body: some View {
        Group {
            if !store.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    VeyraSectionHeader(title: "Sport vandaag")
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(store.highlights) { match in
                                Button {
                                    selectedMatch = match
                                } label: {
                                    SportsMatchCardIOS(
                                        match: match,
                                        stale: store.failedLeagues.contains(match.league.id)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationDestination(item: $selectedMatch) { match in
            SportsMatchDetailIOS(match: match)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await store.refresh(date: Date())
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    return
                }
            }
        }
    }
}

private struct SportsMatchCardIOS: View {
    let match: SportsMatch
    let stale: Bool

    @AppStorage(GeneralSettingsDefaults.hideScoreSpoilersKey)
    private var hideScoreSpoilers = false
    @State private var scoreRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(match.league.name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                if match.phase == .live {
                    Text("LIVE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(VeyraColors.red)
                }
            }

            teamRow(match.home, score: match.homeScore)
            teamRow(match.away, score: match.awayScore)

            Text(match.status)
                .font(.caption2)
                .foregroundStyle(stale ? .orange : .secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(width: 220, alignment: .leading)
        .background(VeyraColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func teamRow(_ team: SportsTeam, score: String?) -> some View {
        HStack {
            AsyncImage(url: team.logoURL ?? SportsTeam.fallbackLogoURL(abbreviation: team.abbreviation)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                default:
                    Image(systemName: "sportscourt")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 20, height: 20)

            Text(team.abbreviation)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            if match.showsScore, let score {
                let hidden = hideScoreSpoilers && !scoreRevealed

                Text(hidden ? "••" : score)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.primary)
                    .blur(radius: hidden ? 6 : 0)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        TapGesture().onEnded { scoreRevealed = true }
                    )
            }
        }
    }
}

