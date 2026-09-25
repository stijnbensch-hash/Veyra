import SwiftUI

struct MetadataRatingsView: View {
    let ratings:
        MetadataRatings

    var body: some View {
        if ratings.hasVisibleRatings {
            HStack(
                spacing: 30
            ) {
                if MetadataPreferences.showIMDb,
                   let value = ratings.imdb
                {
                    ratingItem(
                        provider: .imdb,
                        value:
                            String(
                                format:
                                    "%.1f",
                                value
                            )
                    )
                }

                if MetadataPreferences.showTMDB,
                   let value = ratings.tmdb
                {
                    ratingItem(
                        provider: .tmdb,
                        value:
                            String(
                                format:
                                    "%.1f",
                                value
                            )
                    )
                }

                if MetadataPreferences.showTomatometer,
                   let value =
                        ratings.tomatometer
                {
                    ratingItem(
                        provider:
                            .tomatometer,
                        value:
                            "\(value)%"
                    )
                }

                if MetadataPreferences.showMetacritic,
                   let value =
                        ratings.metacritic
                {
                    ratingItem(
                        provider:
                            .metacritic,
                        value:
                            "\(value)"
                    )
                }

                if MetadataPreferences.showTrakt,
                   let value =
                        ratings.trakt
                {
                    ratingItem(
                        provider:
                            .trakt,
                        value:
                            String(
                                format:
                                    "%.1f",
                                value
                            )
                    )
                }

                if MetadataPreferences.showPopcornmeter,
                   let value =
                        ratings.popcornmeter
                {
                    ratingItem(
                        provider:
                            .popcornmeter,
                        value:
                            "\(value)%"
                    )
                }
            }
        }
    }

    // MARK: - Rating Item

    private func ratingItem(
        provider:
            MetadataRatingProvider,
        value:
            String
    ) -> some View {
        HStack(
            spacing: 10
        ) {
            providerIcon(
                provider
            )

            Text(
                value
            )
            .font(
                .system(
                    size: 26,
                    weight: .bold,
                    design: .rounded
                )
            )
            .monospacedDigit()
            .foregroundStyle(
                .white
            )
        }
    }

    // MARK: - Icon

    @ViewBuilder
    private func providerIcon(
        _ provider:
            MetadataRatingProvider
    ) -> some View {
        switch provider {
        case .imdb:
            Image("rating-imdb")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 22)
                .foregroundStyle(.black)
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
                .background(
                    Color.yellow,
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )

        // TMDB/Tomatometer/Metacritic/Trakt kwamen voorheen uit monochrome
        // silhouet-PDF's (`.renderingMode(.template)` op een puur zwarte vorm), wat
        // enkel een effen gekleurde vlek gaf -- amper te herkennen als het echte
        // logo. Vervangen door tekst/emoji-badges in de eigen merkkleur, net als
        // IMDb hieronder al deed: veel duidelijker, en werkt altijd (geen
        // afbeelding nodig die kan ontbreken of onduidelijk renderen).
        case .tmdb:
            Text("TMDB")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    Color(red: 0.01, green: 0.71, blue: 0.89),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )

        case .tomatometer:
            Text("🍅")
                .font(.system(size: 22))

        case .metacritic:
            Text("M")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 26, height: 22)
                .background(
                    Color(red: 0.10, green: 0.10, blue: 0.11),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )

        case .trakt:
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 26, height: 22)
                .background(
                    Color(red: 0.62, green: 0.18, blue: 0.55),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )

        case .popcornmeter:
            Text("🍿")
                .font(.system(size: 22))
        }
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        MetadataRatingsView(
            ratings:
                MetadataRatings(
                    imdb: 8.7,
                    tmdb: 8.3,
                    tomatometer: 80,
                    metacritic: 64,
                    trakt: 8.4,
                    popcornmeter: 83
                )
        )
    }
}
