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
            Text("IMDb")
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    Color(red: 0.96, green: 0.77, blue: 0.09),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )

        case .tmdb:
            Image("rating-tmdb")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 24)
                .foregroundStyle(Color(red: 0.37, green: 0.82, blue: 0.78))

        case .tomatometer:
            Text("🍅")
                .font(.system(size: 22))

        case .metacritic:
            Image("rating-metacritic")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(Color(red: 0.96, green: 0.78, blue: 0.16))

        case .trakt:
            Image("rating-trakt")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(Color(red: 0.79, green: 0.40, blue: 0.76))

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
