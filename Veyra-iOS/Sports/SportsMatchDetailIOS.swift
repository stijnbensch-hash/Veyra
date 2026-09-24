import SwiftUI

/// Lichte iOS-detailweergave voor een wedstrijd. Gedeeld door de Sport-tab
/// (`SportsView`) en de "Sport vandaag"-rij op Home (`SportsHomeRow`).
struct SportsMatchDetailIOS: View {
    let match: SportsMatch

    @AppStorage(GeneralSettingsDefaults.hideScoreSpoilersKey)
    private var hideScoreSpoilers = false
    @State private var scoreRevealed = false
    @StateObject private var favorites = SportsStore()
    @State private var channelQuery: SportChannelQuery?
    @State private var playing: PlayableSource?

    var body: some View {
        VStack(spacing: 24) {
            Text(match.league.name)
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                matchTeamRow(match.home, score: match.homeScore)
                matchTeamRow(match.away, score: match.awayScore)
            }
            .padding()
            .veyraGlass(radius: VeyraRadius.card)
            .padding(.horizontal)

            Text(match.status)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(match.phase == .live ? VeyraColors.red : .secondary)

            if let venue = match.venue, !venue.isEmpty {
                Text(venue)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if match.phase != .finished {
                Button {
                    channelQuery = SportChannelQuery(
                        title: "\(match.home.name) – \(match.away.name)",
                        teams: [match.home.name, match.away.name],
                        start: match.date
                    )
                } label: {
                    Label("Waar kijken?", systemImage: "play.tv")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(VeyraColors.cyan)
            }

            Spacer()
        }
        .padding(.top, 32)
        .sportChannelSheet($channelQuery) { playing = $0 }
        .navigationDestination(item: $playing) { source in
            PlayerView(source: source, item: MediaItem(title: source.name, type: .liveTV))
        }
        .veyraReadableWidth(720)
        .navigationTitle("Wedstrijd")
        .navigationBarTitleDisplayMode(.inline)
        .background(VeyraBackground())
    }

    private func matchTeamRow(_ team: SportsTeam, score: String?) -> some View {
        HStack {
            Button {
                favorites.toggle(team)
            } label: {
                Image(systemName: favorites.isFavoriteTeam(team) ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(favorites.isFavoriteTeam(team) ? .yellow : .secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(favorites.isFavoriteTeam(team) ? "Verwijder uit favoriete teams" : "Maak favoriet team")

            AsyncImage(url: team.logoURL ?? SportsTeam.fallbackLogoURL(abbreviation: team.abbreviation)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                default:
                    Image(systemName: "sportscourt")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 36, height: 36)

            Text(team.name)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()

            if match.showsScore, let score {
                let hidden = hideScoreSpoilers && !scoreRevealed

                Text(hidden ? "••" : score)
                    .font(.title3.weight(.bold))
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
