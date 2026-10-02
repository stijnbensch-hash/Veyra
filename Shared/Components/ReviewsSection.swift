// ReviewsSection.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// "Recensies" -- door kijkers geschreven TMDB-recensies onderaan een film-/
// seriedetailscherm, na Cast/Trailer/Vergelijkbaar. Uit te zetten via
// Instellingen → Algemeen ("Recensies tonen", `GeneralSettingsDefaults`).
// TMDB-recensies zijn altijd Engelstalig; geen eigen vertaling hier.
import SwiftUI

struct ReviewsSection: View {
    let item: MediaItem
    /// Fase 4 (TMDB-spec, append_to_response): hergebruikt een al opgehaalde `reviews`-respons
    /// i.p.v. zelf nog een `/reviews`-aanvraag te doen. `nil` (default) = niet meegegeven, dus
    /// zelf ophalen zoals voorheen -- een lege array is een geldige, bevestigde "geen reviews".
    var preloadedReviews: TMDBPreload<[TMDBReview]> = .none

    @AppStorage(GeneralSettingsDefaults.showReviewsKey)
    private var showReviews = true

    @State private var reviews: [TMDBReview] = []
    @State private var expandedIDs: Set<String> = []

    var body: some View {
        if showReviews, !reviews.isEmpty {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                VeyraSectionHeader(title: "Recensies")
#if !os(tvOS)
                    .padding(.horizontal)
#endif

                VStack(spacing: cardSpacing) {
                    ForEach(reviews.prefix(6)) { review in
                        reviewCard(review)
                    }
                }
#if !os(tvOS)
                .padding(.horizontal)
#endif
            }
            .task(id: taskID) { await load() }
        } else if showReviews {
            Color.clear.frame(width: 0, height: 0)
                .task(id: taskID) { await load() }
        }
    }

    private var taskID: String { "\(item.type.rawValue)|\(item.tmdbID ?? 0)|\(preloadedReviews.stageKey)" }

    private func reviewCard(_ review: TMDBReview) -> some View {
        let isExpanded = expandedIDs.contains(review.id)
        let content = review.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let isLong = content.count > contentPreviewLimit

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                avatar(for: review)

                VStack(alignment: .leading, spacing: 2) {
                    Text(review.displayName)
                        .font(.system(size: nameSize, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if let rating = review.rating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: ratingSize * 0.8))
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: ratingSize, weight: .semibold))
                    }
                    .foregroundStyle(VeyraColors.cyan)
                }
            }

            Text(content)
                .font(.system(size: bodySize))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(isExpanded ? nil : 5)
                .fixedSize(horizontal: false, vertical: true)

            if isLong {
                Button(isExpanded ? "Minder tonen" : "Meer tonen") {
                    if isExpanded { expandedIDs.remove(review.id) } else { expandedIDs.insert(review.id) }
                }
                .font(.system(size: bodySize, weight: .semibold))
                .foregroundStyle(VeyraColors.cyan)
#if os(tvOS)
                .buttonStyle(.plain)
#else
                .buttonStyle(.plain)
#endif
            }
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func avatar(for review: TMDBReview) -> some View {
        ZStack {
            Circle().fill(VeyraColors.surface)
            if let url = review.avatarURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    }
                }
            } else {
                Text(review.displayName.prefix(1).uppercased())
                    .font(.system(size: nameSize, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
    }

    private func load() async {
        switch preloadedReviews {
        case .value(let preloaded):
            reviews = preloaded
        case .pending:
            break // de aanroeper is bezig met een gecombineerde aanvraag -- even wachten.
        case .none:
            reviews = await MetadataReviewsService.reviews(for: item)
        }
    }

    private var contentPreviewLimit: Int { 320 }

    private var sectionSpacing: CGFloat {
#if os(tvOS)
        20
#else
        12
#endif
    }
    private var cardSpacing: CGFloat {
#if os(tvOS)
        16
#else
        10
#endif
    }
    private var cardPadding: CGFloat {
#if os(tvOS)
        22
#else
        14
#endif
    }
    private var avatarSize: CGFloat {
#if os(tvOS)
        44
#else
        32
#endif
    }
    private var nameSize: CGFloat {
#if os(tvOS)
        20
#else
        14
#endif
    }
    private var bodySize: CGFloat {
#if os(tvOS)
        19
#else
        14
#endif
    }
    private var ratingSize: CGFloat {
#if os(tvOS)
        18
#else
        13
#endif
    }
}
