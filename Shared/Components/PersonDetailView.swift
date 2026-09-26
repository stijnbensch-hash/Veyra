import SwiftUI

/// Infopagina van een acteur/regisseur/producer -- geopend door op iemand
/// in `CastRow` te tikken. Toont portret, korte bio-info, "Bekend van" en de
/// volledige filmografie (films + series, als acteur of crewlid), op
/// zowel tvOS als iOS.
struct PersonDetailView: View {
    let personID: Int
    let name: String

    @State private var details: TMDBPersonDetails?
    @State private var credits: [TMDBPersonCredit] = []
    @State private var filter: Filter = .all

    private enum Filter: String, CaseIterable {
        case all = "Alle"
        case movies = "Films"
        case series = "Series"
    }

    private var filteredCredits: [TMDBPersonCredit] {
        switch filter {
        case .all: return credits
        case .movies: return credits.filter(\.isMovie)
        case .series: return credits.filter { !$0.isMovie }
        }
    }

    /// Op jaar gegroepeerd, jaar-secties in dezelfde (aflopende) volgorde
    /// als `credits` al staat -- titels zonder jaar (TBA) komen vooraan.
    private var groupedByYear: [(year: String, credits: [TMDBPersonCredit])] {
        var order: [String] = []
        var buckets: [String: [TMDBPersonCredit]] = [:]
        for credit in filteredCredits {
            let key = credit.displayYear ?? "TBA"
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(credit)
        }
        return order.map { (year: $0, credits: buckets[$0] ?? []) }
    }

    private var knownFor: [TMDBPersonCredit] {
        Array(
            credits
                .filter { $0.posterPath != nil }
                .sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
                .prefix(6)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                header

                if !knownFor.isEmpty {
                    knownForSection
                }

                filmographySection
            }
            .padding(.bottom, 50)
            .frame(maxWidth: 1400)
            .frame(maxWidth: .infinity)
        }
        .background(VeyraColors.background.ignoresSafeArea())
        .navigationTitle(name)
        .task(id: personID) { await load() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            AsyncImage(
                url: details?.profilePath.flatMap { URL(string: "https://image.tmdb.org/t/p/h632\($0)") }
            ) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    ZStack {
                        VeyraColors.surface
                        Image(systemName: "person.fill")
                            .foregroundStyle(.white.opacity(0.4))
                            .font(.system(size: photoSize * 0.35))
                    }
                }
            }
            .frame(width: photoSize, height: photoSize * 1.35)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(name)
                .font(titleFont)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if !subtitleParts.isEmpty {
                Text(subtitleParts.joined(separator: " · "))
                    .font(subtitleFont)
                    .foregroundStyle(.secondary)
            }

            if let biography = details?.biography, !biography.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(biography)
                    .font(bodyFont)
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.leading)
                    .lineLimit(8)
                    .frame(maxWidth: 900, alignment: .leading)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.horizontal)
    }

    private var subtitleParts: [String] {
        var parts: [String] = []
        if let department = details?.knownForDepartment { parts.append(department) }
        if let age = details?.age { parts.append("\(age) jaar") }
        if let place = details?.placeOfBirth, !place.isEmpty { parts.append(place) }
        return parts
    }

    // MARK: - Bekend van

    private var knownForSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VeyraSectionHeader(title: "Bekend van")
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: rowSpacing) {
                    ForEach(knownFor, id: \.self) { credit in
                        NavigationLink {
                            ShelfItemDestination(item: credit.mediaItem())
                        } label: {
                            VeyraPosterCard(
                                title: credit.displayTitle,
                                url: credit.mediaItem().posterURL,
                                symbol: credit.isMovie ? "film" : "tv",
                                width: posterWidth,
                                genre: credit.mediaItem().genre,
                                rating: credit.voteAverage
                            )
                        }
#if os(tvOS)
                        .buttonStyle(VeyraPosterFocusStyle(cornerRadius: VeyraRadius.poster))
#else
                        .buttonStyle(.plain)
#endif
                    }
                }
#if os(tvOS)
                .padding(12)
#else
                .padding(.horizontal)
#endif
            }
#if os(tvOS)
            .scrollClipDisabled()
#endif
        }
    }

    // MARK: - Filmografie

    private var filmographySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VeyraSectionHeader(title: "Filmografie")

                Spacer()

                filterControl
            }
            .padding(.horizontal)

            ForEach(groupedByYear, id: \.year) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.year)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    ForEach(group.credits, id: \.self) { credit in
                        NavigationLink {
                            ShelfItemDestination(item: credit.mediaItem())
                        } label: {
                            filmographyRow(credit)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // tvOS heeft geen `.segmented` Picker-stijl -- daar een eigen rijtje
    // knoppen i.p.v. de systeem-Picker, net als de andere filterbalken
    // in de app (bv. `SourceSelectionView`).
    @ViewBuilder
    private var filterControl: some View {
#if os(tvOS)
        HStack(spacing: 12) {
            ForEach(Filter.allCases, id: \.self) { option in
                Button(option.rawValue) { filter = option }
                    .buttonStyle(VeyraFocusButtonStyle())
                    .opacity(filter == option ? 1 : 0.6)
            }
        }
#else
        Picker("Filter", selection: $filter) {
            ForEach(Filter.allCases, id: \.self) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 320)
#endif
    }

    private func filmographyRow(_ credit: TMDBPersonCredit) -> some View {
        HStack(spacing: 14) {
            AsyncImage(url: credit.mediaItem().posterURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    VeyraColors.surface
                }
            }
            .frame(width: 46, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(credit.displayTitle)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let role = credit.roleLabel, !role.isEmpty {
                    Text(role)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Load

    private func load() async {
        async let detailsTask = PersonService.details(id: personID)
        async let creditsTask = PersonService.combinedCredits(id: personID)
        let (loadedDetails, loadedCredits) = await (detailsTask, creditsTask)
        details = loadedDetails
        credits = loadedCredits
    }

    // MARK: - Metrics

    private var photoSize: CGFloat {
#if os(tvOS)
        260
#else
        170
#endif
    }

    private var titleFont: Font {
#if os(tvOS)
        .system(size: 40, weight: .bold, design: .rounded)
#else
        .title2.weight(.bold)
#endif
    }

    private var subtitleFont: Font {
#if os(tvOS)
        .system(size: 20)
#else
        .subheadline
#endif
    }

    private var bodyFont: Font {
#if os(tvOS)
        .system(size: 22)
#else
        .body
#endif
    }

    private var posterWidth: CGFloat {
#if os(tvOS)
        200
#else
        120
#endif
    }

    private var rowSpacing: CGFloat {
#if os(tvOS)
        24
#else
        14
#endif
    }

    private var sectionSpacing: CGFloat {
#if os(tvOS)
        36
#else
        24
#endif
    }
}
