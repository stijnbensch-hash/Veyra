import SwiftUI

struct MetadataRatingsView: View {
    let ratings:
        MetadataRatings
    var maxItems: Int? = nil
    var compact = false

    var body: some View {
        if !visibleEntries.isEmpty {
            HStack(
                spacing: compact ? 12 : 30
            ) {
                ForEach(visibleEntries) { entry in
                    ratingItem(provider: entry.provider, value: entry.value)
                }
            }
        }
    }

    private struct RatingEntry: Identifiable {
        let provider: MetadataRatingProvider
        let value: String
        var id: String { provider.rawValue }
    }

    private var visibleEntries: [RatingEntry] {
        let candidates: [RatingEntry?] = [
            ratings.imdb.map { RatingEntry(provider: .imdb, value: String(format: "%.1f", $0)) },
            ratings.tmdb.map { RatingEntry(provider: .tmdb, value: String(format: "%.1f", $0)) },
            ratings.tomatometer.map { RatingEntry(provider: .tomatometer, value: "\($0)%") },
            ratings.metacritic.map { RatingEntry(provider: .metacritic, value: "\($0)") },
            ratings.trakt.map { RatingEntry(provider: .trakt, value: String(format: "%.1f", $0)) },
            ratings.popcornmeter.map { RatingEntry(provider: .popcornmeter, value: "\($0)%") },
            ratings.letterboxd.map { RatingEntry(provider: .letterboxd, value: String(format: "%.1f", $0)) },
            ratings.mal.map { RatingEntry(provider: .mal, value: String(format: "%.1f", $0)) }
        ]
        let enabled = candidates.compactMap { $0 }.filter { MetadataPreferences.isEnabled($0.provider) }
        return Array(enabled.prefix(maxItems ?? Int.max))
    }

    // MARK: - Rating Item

    private func ratingItem(
        provider:
            MetadataRatingProvider,
        value:
            String
    ) -> some View {
        HStack(
            spacing: compact ? 5 : 10
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(provider.title) \(value)")
    }

    /// Losstaand van het icoon-formaat, dat op originele grootte staat --
    /// enkel het cijfer zelf is kleiner gemaakt.
    private var valueFontSize: CGFloat {
        if compact {
            #if os(tvOS)
            return 21
            #else
            return 14
            #endif
        }
        #if os(iOS)
        return 18
        #else
        return 22
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
        if compact {
            #if os(tvOS)
            return provider == .imdb ? 36 : 26
            #else
            return provider == .imdb ? 27 : 20
            #endif
        }
        #if os(iOS)
        return provider == .imdb ? 34 : 24
        #else
        return provider == .imdb ? 44 : 32
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
