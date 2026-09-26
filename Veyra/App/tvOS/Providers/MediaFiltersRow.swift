import SwiftUI

/// tvOS-tegenhanger van `MediaFiltersRowIOS`: uitklapbare filterknoppen voor
/// Genre, Decennium en Beoordeling, in dezelfde stijl als de regiokiezer in
/// `WatchProviderRow` (menu-knop met pictogram, label en waarde).
struct MediaFiltersRow: View {
    let kind: ProviderMediaKind

    @Binding var selectedGenreID: Int?
    @Binding var selectedDecade: VeyraDecadeFilter?
    @Binding var selectedRating: VeyraRatingFilter?
    @Binding var selectedSort: VeyraSortOption

    private var genreOptions: [(id: Int, name: String)] {
        let source = kind == .movie ? TMDBGenreNames.movie : TMDBGenreNames.tv
        return source.map { (id: $0.key, name: $0.value) }.sorted { $0.name < $1.name }
    }

    private var genreName: String? {
        guard let selectedGenreID else { return nil }
        return kind == .movie
            ? TMDBGenreNames.movieName(for: selectedGenreID)
            : TMDBGenreNames.tvName(for: selectedGenreID)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 22) {
                // Sorteren staat vooraan (i.p.v. na de andere filters), anders dan
                // de andere filters hieronder heeft het altijd een actieve waarde
                // (default "Populair") — dus geen resetButton naar "geen sortering".
                filterMenu(
                    symbol: "arrow.up.arrow.down",
                    label: "Sorteren",
                    value: selectedSort.displayName,
                    isActive: selectedSort != .newest
                ) {
                    ForEach(VeyraSortOption.allCases) { option in
                        optionButton(title: option.displayName, selected: selectedSort == option) {
                            selectedSort = option
                        }
                    }
                }

                filterMenu(
                    symbol: "square.stack.3d.up",
                    label: "Genre",
                    value: genreName,
                    isActive: selectedGenreID != nil
                ) {
                    resetButton(title: "Alle genres") { selectedGenreID = nil }

                    Divider()

                    ForEach(genreOptions, id: \.id) { option in
                        optionButton(title: option.name, selected: selectedGenreID == option.id) {
                            selectedGenreID = option.id
                        }
                    }
                }

                filterMenu(
                    symbol: "calendar",
                    label: "Decennium",
                    value: selectedDecade?.title,
                    isActive: selectedDecade != nil
                ) {
                    resetButton(title: "Alle jaren") { selectedDecade = nil }

                    Divider()

                    ForEach(VeyraDecadeFilter.all) { decade in
                        optionButton(title: decade.title, selected: selectedDecade == decade) {
                            selectedDecade = decade
                        }
                    }
                }

                filterMenu(
                    symbol: "star.fill",
                    label: "Beoordeling",
                    value: selectedRating?.title,
                    isActive: selectedRating != nil
                ) {
                    resetButton(title: "Alle beoordelingen") { selectedRating = nil }

                    Divider()

                    ForEach(VeyraRatingFilter.allCases) { rating in
                        optionButton(title: rating.title, selected: selectedRating == rating) {
                            selectedRating = rating
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }

    // MARK: - Menu-knop

    private func filterMenu<Content: View>(
        symbol: String,
        label: String,
        value: String?,
        isActive: Bool,
        @ViewBuilder items: () -> Content
    ) -> some View {
        Menu {
            items()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isActive ? VeyraColors.cyan : .white.opacity(0.8))

                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VeyraColors.secondary)

                    Text(value ?? "Alle")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 20)
            .frame(width: 270, height: 92)
        }
        .buttonStyle(VeyraFocusButtonStyle(radius: 28))
    }

    // MARK: - Menu-items

    private func resetButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
        }
    }

    private func optionButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if selected {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}
