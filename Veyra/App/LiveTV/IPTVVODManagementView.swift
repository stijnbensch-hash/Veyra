import SwiftUI

struct IPTVVODManagementView: View {
    @State private var configuration:
        IPTVStoredConfiguration?

    @State private var categories:
        [IPTVCategory] = []

    @State private var preferences =
        IPTVProviderPreferences()

    @State private var isLoading = false
    @State private var errorMessage: String?

    private let configurationStore =
        IPTVConfigurationStore()

    private let preferencesStore =
        IPTVProviderPreferencesStore()

    private let service =
        IPTVService()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(
                        red: 0.01,
                        green: 0.04,
                        blue: 0.07
                    ),
                    Color(
                        red: 0.02,
                        green: 0.10,
                        blue: 0.16
                    )
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(
                alignment: .leading,
                spacing: 30
            ) {
                header

                content

                Spacer()
            }
            .padding(70)
        }
        .task {
            await load()
        }
        .onAppear {
            reloadPreferences()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text("VOD BEHEREN")
                .font(
                    .system(
                        size: 50,
                        weight: .light
                    )
                )
                .tracking(8)
                .foregroundStyle(.white)

            Text(
                "CATEGORIEËN & TITELS"
            )
            .font(.caption)
            .tracking(3)
            .foregroundStyle(
                .cyan.opacity(0.75)
            )
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView(
                "VOD laden…"
            )
            .font(.title3)

        } else if let errorMessage {
            VStack(
                alignment: .leading,
                spacing: 16
            ) {
                Text(
                    "VOD kon niet worden geladen"
                )
                .font(.title2)

                Text(errorMessage)
                    .foregroundStyle(
                        .secondary
                    )

                Button("OPNIEUW") {
                    Task {
                        await load()
                    }
                }
            }

        } else if categories.isEmpty {
            Text(
                "Geen VOD-categorieën gevonden."
            )
            .foregroundStyle(.secondary)

        } else {
            ScrollView(.vertical) {
                LazyVStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    ForEach(categories) { category in
                        categoryRow(category)
                    }
                }
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Category

    private func categoryRow(
        _ category: IPTVCategory
    ) -> some View {
        HStack(spacing: 24) {
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                Text(category.name)
                    .font(
                        .system(
                            size: 24,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)

                Text("VOD-lijst")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle(
                "Zichtbaar",
                isOn:
                    categoryVisibilityBinding(
                        category
                    )
            )
            .labelsHidden()

            if let configuration {
                NavigationLink {
                    IPTVVODItemManagementView(
                        configuration:
                            configuration,
                        category:
                            category
                    )
                } label: {
                    Text("TITELS")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(
            maxWidth: 1000,
            minHeight: 120
        )
        .background(
            RoundedRectangle(
                cornerRadius: 20
            )
            .fill(
                Color.white.opacity(0.06)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 20
            )
            .stroke(
                preferences
                    .isVODCategoryVisible(
                        category.id
                    )
                    ? Color.cyan.opacity(0.22)
                    : Color.white.opacity(0.08),
                lineWidth: 1
            )
        )
        .opacity(
            preferences
                .isVODCategoryVisible(
                    category.id
                )
                ? 1.0
                : 0.55
        )
    }

    // MARK: - Visibility

    private func categoryVisibilityBinding(
        _ category: IPTVCategory
    ) -> Binding<Bool> {
        Binding(
            get: {
                preferences
                    .isVODCategoryVisible(
                        category.id
                    )
            },
            set: { visible in
                setCategoryVisibility(
                    category,
                    visible: visible
                )
            }
        )
    }

    private func setCategoryVisibility(
        _ category: IPTVCategory,
        visible: Bool
    ) {
        guard let configuration else {
            return
        }

        preferences.setVODCategory(
            category.id,
            visible: visible
        )

        do {
            try preferencesStore.save(
                preferences,
                for: configuration
            )

            errorMessage = nil
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    // MARK: - Load

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            guard
                let configuration =
                    try configurationStore.load()
            else {
                self.configuration = nil
                categories = []
                isLoading = false
                return
            }

            self.configuration =
                configuration

            preferences =
                preferencesStore.load(
                    for: configuration
                )

            guard
                case .xtream(
                    let xtreamConfiguration
                ) = configuration
            else {
                categories = []

                errorMessage =
                    "VOD-beheer is alleen beschikbaar voor Xtream."

                isLoading = false
                return
            }

            categories =
                try await service
                    .loadXtreamVODCategories(
                        configuration:
                            xtreamConfiguration
                    )
        } catch {
            categories = []

            errorMessage =
                error.localizedDescription
        }

        isLoading = false
    }

    private func reloadPreferences() {
        guard let configuration else {
            return
        }

        preferences =
            preferencesStore.load(
                for: configuration
            )
    }
}

// MARK: - VOD Item Management

private struct IPTVVODItemManagementView:
    View
{
    let configuration:
        IPTVStoredConfiguration

    let category:
        IPTVCategory

    @State private var items:
        [IPTVVODItem] = []

    @State private var preferences =
        IPTVProviderPreferences()

    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service =
        IPTVService()

    private let preferencesStore =
        IPTVProviderPreferencesStore()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(
                        red: 0.01,
                        green: 0.04,
                        blue: 0.07
                    ),
                    Color(
                        red: 0.02,
                        green: 0.10,
                        blue: 0.16
                    )
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(
                alignment: .leading,
                spacing: 28
            ) {
                header

                content

                Spacer()
            }
            .padding(70)
        }
        .task {
            await loadItems()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text(category.name)
                .font(
                    .system(
                        size: 46,
                        weight: .light
                    )
                )
                .foregroundStyle(.white)

            Text("VOD TITELS")
                .font(.caption)
                .tracking(3)
                .foregroundStyle(
                    .cyan.opacity(0.75)
                )
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView(
                "VOD-titels laden…"
            )

        } else if let errorMessage {
            VStack(
                alignment: .leading,
                spacing: 16
            ) {
                Text(
                    "VOD-titels konden niet worden geladen"
                )
                .font(.title2)

                Text(errorMessage)
                    .foregroundStyle(
                        .secondary
                    )
            }

        } else if items.isEmpty {
            Text(
                "Geen VOD-titels gevonden."
            )
            .foregroundStyle(.secondary)

        } else {
            ScrollView(.vertical) {
                LazyVStack(
                    alignment: .leading,
                    spacing: 14
                ) {
                    ForEach(items) { item in
                        itemRow(item)
                    }
                }
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Row

    private func itemRow(
        _ item: IPTVVODItem
    ) -> some View {
        HStack(spacing: 20) {
            poster(item)

            Text(item.name)
                .font(
                    .system(
                        size: 22,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer()

            Toggle(
                "Zichtbaar",
                isOn:
                    itemVisibilityBinding(
                        item
                    )
            )
            .labelsHidden()
        }
        .padding(20)
        .frame(
            maxWidth: 1000,
            minHeight: 120
        )
        .background(
            RoundedRectangle(
                cornerRadius: 18
            )
            .fill(
                Color.white.opacity(0.05)
            )
        )
        .opacity(
            preferences
                .isVODItemVisible(
                    item.id
                )
                ? 1.0
                : 0.50
        )
    }

    // MARK: - Poster

    @ViewBuilder
    private func poster(
        _ item: IPTVVODItem
    ) -> some View {
        AsyncImage(
            url: item.posterURL
        ) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()

            case .empty:
                ZStack {
                    Color.white.opacity(0.05)
                    ProgressView()
                }

            case .failure:
                ZStack {
                    Color.white.opacity(0.05)

                    Image(
                        systemName: "film"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

            @unknown default:
                ZStack {
                    Color.white.opacity(0.05)

                    Image(
                        systemName: "film"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
        }
        .frame(
            width: 85,
            height: 125
        )
        .clipped()
        .clipShape(
            RoundedRectangle(
                cornerRadius: 12
            )
        )
    }

    // MARK: - Visibility

    private func itemVisibilityBinding(
        _ item: IPTVVODItem
    ) -> Binding<Bool> {
        Binding(
            get: {
                preferences
                    .isVODItemVisible(
                        item.id
                    )
            },
            set: { visible in
                setItemVisibility(
                    item,
                    visible: visible
                )
            }
        )
    }

    private func setItemVisibility(
        _ item: IPTVVODItem,
        visible: Bool
    ) {
        preferences.setVODItem(
            item.id,
            visible: visible
        )

        do {
            try preferencesStore.save(
                preferences,
                for: configuration
            )

            errorMessage = nil
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    // MARK: - Load

    @MainActor
    private func loadItems() async {
        isLoading = true
        errorMessage = nil

        preferences =
            preferencesStore.load(
                for: configuration
            )

        guard
            case .xtream(
                let xtreamConfiguration
            ) = configuration
        else {
            items = []

            errorMessage =
                "VOD-beheer is alleen beschikbaar voor Xtream."

            isLoading = false
            return
        }

        do {
            items =
                try await service
                    .loadXtreamVOD(
                        configuration:
                            xtreamConfiguration,
                        categoryID:
                            category.id
                    )
        } catch {
            items = []

            errorMessage =
                error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        IPTVVODManagementView()
    }
}
