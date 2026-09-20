import SwiftUI

/// Lichte iOS-detailweergave voor een wedstrijd. Gedeeld door de Sport-tab
/// (`SportsView`) en de "Sport vandaag"-rij op Home (`SportsHomeRow`).
struct SportsMatchDetailIOS: View {
    let match: SportsMatch

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

            Spacer()
        }
        .padding(.top, 32)
        .navigationTitle("Wedstrijd")
        .navigationBarTitleDisplayMode(.inline)
        .background(VeyraBackground())
    }

    private func matchTeamRow(_ team: SportsTeam, score: String?) -> some View {
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
            .frame(width: 36, height: 36)

            Text(team.name)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()

            if match.showsScore, let score {
                Text(score)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
            }
        }
    }
}
