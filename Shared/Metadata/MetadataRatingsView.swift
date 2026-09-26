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

                if MetadataPreferences.showLetterboxd,
                   let value =
                        ratings.letterboxd
                {
                    ratingItem(
                        provider:
                            .letterboxd,
                        value:
                            String(
                                format:
                                    "%.1f",
                                value
                            )
                    )
                }

                if MetadataPreferences.showMAL,
                   let value =
                        ratings.mal
                {
                    ratingItem(
                        provider:
                            .mal,
                        value:
                            String(
                                format:
                                    "%.1f",
                                value
                            )
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
                    size: valueFontSize,
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

    /// Losstaand van het icoon-formaat, dat op originele grootte staat --
    /// enkel het cijfer zelf is kleiner gemaakt.
    private var valueFontSize: CGFloat {
        #if os(iOS)
        18
        #else
        22
        #endif
    }

    // MARK: - Icon

    @ViewBuilder
    private func providerIcon(
        _ provider:
            MetadataRatingProvider
    ) -> some View {
        if let assetName = provider.assetImageName {
            Image(assetName)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(
                    width: iconSize(for: provider),
                    height: iconSize(for: provider)
                )
        }
    }

    /// Op iOS staan de ratingbadges op een klein telefoonscherm i.p.v. een
    /// tv op afstand, dus mogen de logo's zelf kleiner dan op tvOS.
    private func iconSize(for provider: MetadataRatingProvider) -> CGFloat {
        #if os(iOS)
        provider == .imdb ? 34 : 24
        #else
        provider == .imdb ? 44 : 32
        #endif
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
                    popcornmeter: 83,
                    letterboxd: 3.8,
                    mal: 8.1
                )
        )
    }
}
