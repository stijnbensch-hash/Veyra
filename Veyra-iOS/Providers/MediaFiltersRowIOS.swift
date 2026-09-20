import SwiftUI

/// Uitklapbare filterknoppen voor Genre, Decennium en Beoordeling, onder de
/// streamingdiensten-rij (`WatchProviderRowIOS`) op Films/Series. Zelfde
/// menu-opbouw en pilvormgeving als `WatchProviderRowIOS`' regiokiezer,
/// zodat de rij er als één geheel uitziet.
struct MediaFiltersRowIOS: View {
    let kind: ProviderMediaKind

    @Binding var selectedGenreID: Int?
    @Binding var selectedDecade: VeyraDecadeFilter?
    @Binding var selectedRating: VeyraRatingFilter?

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
            HStack(spacing: 10) {
                genreMenu
                decadeMenu
                ratingMenu
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    // MARK: - Genre

    private var genreMenu: some View {
        Menu {
            resetButton(title: "Alle genres") { selectedGenreID = nil }

            Divider()

            ForEach(genreOptions, id: \.id) { option in
                optionButton(title: option.name, selected: selectedGenreID == option.id) {
                    selectedGenreID = option.id
                }
            }
        } label: {
            filterPillLabel(
                systemImage: "square.stack.3d.up",
                title: genreName ?? "Genre",
                isActive: selectedGenreID != nil
            )
        }
    }

    // MARK: - Decennium

    private var decadeMenu: some View {
        Menu {
            resetButton(title: "Alle jaren") { selectedDecade = nil }

            Divider()

            ForEach(VeyraDecadeFilter.all) { decade in
                optionButton(title: decade.title, selected: selectedDecade == decade) {
                    selectedDecade = decade
                }
            }
        } label: {
            filterPillLabel(
                systemImage: "calendar",
                title: selectedDecade?.title ?? "Decennium",
                isActive: selectedDecade != nil
            )
        }
    }

    // MARK: - Beoordeling

    private var ratingMenu: some View {
        Menu {
            resetButton(title: "Alle beoordelingen") { selectedRating = nil }

            Divider()

            ForEach(VeyraRatingFilter.allCases) { rating in
                optionButton(title: rating.title, selected: selectedRating == rating) {
                    selectedRating = rating
                }
            }
        } label: {
            filterPillLabel(
                systemImage: "star.fill",
                title: selectedRating?.title ?? "Beoordeling",
                isActive: selectedRating != nil
            )
        }
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

    // MARK: - Pil

    private func filterPillLabel(systemImage: String, title: String, isActive: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(isActive ? VeyraColors.cyan : .white.opacity(0.7))

            Text(title)
                .lineLimit(1)

            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(
            isActive ? VeyraColors.cyan.opacity(0.18) : Color.white.opacity(0.10),
            in: Capsule()
        )
        .overlay(
            Capsule().strokeBorder(isActive ? VeyraColors.cyan.opacity(0.6) : .clear, lineWidth: 1.2)
        )
    }
}
