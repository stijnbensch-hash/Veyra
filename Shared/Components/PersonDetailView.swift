import SwiftUI

/// Infopagina van een acteur/regisseur/producer -- geopend door op iemand
/// in `CastRow` te tikken. Toont portret, biografie, "Bekend van" en de
/// volledige filmografie (films + series, als acteur of crewlid), op
/// tvOS, iOS, iPadOS en macOS.
struct PersonDetailView: View {
    let personID: Int
    let name: String

    @State private var details: TMDBPersonDetails?
    @State private var credits: [TMDBPersonCredit] = []
    @State private var filter: Filter = .all
    @State private var isLoading = true
    @State private var biographyExpanded = false

#if os(tvOS)
    @Environment(\.dismiss) private var dismiss
    @FocusState private var backFocused: Bool
#endif

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
        let actingCredits = credits.filter { $0.job == nil }
        let candidates = actingCredits.isEmpty ? credits : actingCredits
        return Array(candidates
            .filter { ($0.isMovie || $0.mediaType == "tv") && $0.posterPath != nil }
            .sorted {
                if ($0.voteCount ?? 0) != ($1.voteCount ?? 0) {
                    return ($0.voteCount ?? 0) > ($1.voteCount ?? 0)
                }
                return ($0.popularity ?? 0) > ($1.popularity ?? 0)
            }
            .prefix(8))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
#if os(tvOS)
                Button { dismiss() } label: {
                    Label("Terug", systemImage: "chevron.left")
                }
                .buttonStyle(VeyraFocusButtonStyle())
                .focused($backFocused)
#endif

                header

                if !knownFor.isEmpty {
                    knownForSection
                }

                biographySection

                filmographySection
            }
            .padding(.bottom, 80)
#if os(tvOS)
            .padding(.horizontal, 40)
            .padding(.top, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
#else
            .frame(maxWidth: 1400)
            .frame(maxWidth: .infinity)
#endif
        }
#if os(tvOS)
        // De scrollweergave zelf begint onder de navigatie. Dit blijft ook zo
        // wanneer tvOS automatisch naar een gefocust element scrolt.
        .padding(.top, 120)
        // Zonder focusbaar element boven de posterstrip kiest tvOS meteen de
        // eerste film en scrolt het portret deels uit beeld. Begin bovenaan.
        .defaultFocus($backFocused, true)
#endif
        .background(VeyraColors.background.ignoresSafeArea())
#if !os(tvOS)
        .navigationTitle(name)
#endif
        .task(id: personID) { await load() }
    }

    // MARK: - Header

    private var header: some View {
#if os(tvOS)
        HStack(alignment: .center, spacing: 48) {
            portrait
            VStack(alignment: .leading, spacing: 14) {
                Text(name)
                    .font(titleFont)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                if !subtitleParts.isEmpty {
                    Text(subtitleParts.joined(separator: " · "))
                        .font(subtitleFont)
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
#else
        VStack(spacing: 14) {
            portrait

            Text(name)
                .font(titleFont)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if !subtitleParts.isEmpty {
                Text(subtitleParts.joined(separator: " · "))
                    .font(subtitleFont)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.horizontal)
#endif
    }

    private var portrait: some View {
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
    }

    private var biographySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VeyraSectionHeader(title: "Biografie")

            if let biography = details?.biography,
               !biography.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(biography)
                    .font(bodyFont)
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(5)
                    .lineLimit(biographyExpanded ? nil : 5)
                    .frame(maxWidth: 1100, alignment: .leading)

                if biography.count > 350 {
                    Button(biographyExpanded ? "Minder tonen" : "Volledige biografie") {
                        biographyExpanded.toggle()
                    }
#if os(tvOS)
                    .buttonStyle(VeyraFocusButtonStyle())
#endif
                }
            } else if isLoading {
                ProgressView()
            } else {
                Text("Geen biografie beschikbaar.")
                    .foregroundStyle(.secondary)
            }
        }
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

            if isLoading {
                ProgressView("Filmografie laden…")
                    .padding(.horizontal)
            } else if groupedByYear.isEmpty {
                Text("Geen filmografie beschikbaar.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            ForEach(groupedByYear, id: \.year) { group in
                VStack(alignment: .leading, spacing: 14) {
                    Text(group.year)
                        .font(yearFont)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

#if os(tvOS)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)], spacing: 18) {
                        ForEach(group.credits, id: \.self) { credit in
                            filmographyLink(credit)
                        }
                    }
#else
                    ForEach(group.credits, id: \.self) { credit in
                        filmographyLink(credit)
                    }
#endif
                }
            }
        }
    }

    private func filmographyLink(_ credit: TMDBPersonCredit) -> some View {
        NavigationLink {
            ShelfItemDestination(item: credit.mediaItem())
        } label: {
            filmographyRow(credit)
        }
#if os(tvOS)
        .buttonStyle(PersonFilmographyFocusStyle())
#else
        .buttonStyle(.plain)
#endif
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
            .frame(width: filmographyPosterWidth, height: filmographyPosterHeight)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(credit.displayTitle)
                    .font(filmographyTitleFont)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let role = credit.roleLabel, !role.isEmpty {
                    Text(role)
                        .font(filmographyRoleFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
#if os(tvOS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VeyraColors.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
#endif
    }

    // MARK: - Load

    private func load() async {
        async let detailsTask = PersonService.details(id: personID)
        async let creditsTask = PersonService.combinedCredits(id: personID)
        let (loadedDetails, loadedCredits) = await (detailsTask, creditsTask)
        details = loadedDetails
        credits = loadedCredits
        isLoading = false
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

    private var yearFont: Font {
#if os(tvOS)
        .system(size: 24, weight: .semibold)
#else
        .system(size: 16, weight: .semibold)
#endif
    }

    private var filmographyPosterWidth: CGFloat {
#if os(tvOS)
        80
#else
        46
#endif
    }

    private var filmographyPosterHeight: CGFloat {
#if os(tvOS)
        112
#else
        64
#endif
    }

    private var filmographyTitleFont: Font {
#if os(tvOS)
        .system(size: 24, weight: .semibold)
#else
        .system(size: 17, weight: .medium)
#endif
    }

    private var filmographyRoleFont: Font {
#if os(tvOS)
        .system(size: 19)
#else
        .system(size: 14)
#endif
    }
}

#if os(tvOS)
private struct PersonFilmographyFocusStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        FocusedRow(configuration: configuration)
            .focusEffectDisabled()
    }

    private struct FocusedRow: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(VeyraColors.cyan.opacity(isFocused ? 1 : 0), lineWidth: 3)
                }
                .scaleEffect(isFocused ? 1.03 : 1)
                .animation(.easeOut(duration: 0.16), value: isFocused)
        }
    }
}
#endif
