import SwiftUI

struct IPTVSeriesManagementView: View {
    var providerID: UUID? = nil

    @State private var configuration:
        IPTVStoredConfiguration?

    @State private var categories:
        [IPTVCategory] = []

    @State private var preferences =
        IPTVProviderPreferences()

    @State private var isLoading =
        false

    @State private var errorMessage:
        String?

    @State private var confirmationMessage:
        String?

    @State private var selectedCategoryID:
        String?

    @State private var showSeries =
        false

    @FocusState
    private var focusedControl:
        SeriesManagementFocus?

    private let configurationStore =
        IPTVConfigurationStore()

    private let preferencesStore =
        IPTVProviderPreferencesStore()

    private let service =
        IPTVService()

    var body: some View {
        ZStack {
            background

            VStack(
                alignment: .leading,
                spacing: 30
            ) {
                header

                if configuration != nil,
                   !categories.isEmpty {
                    bulkVisibilityControls
                }

                if let confirmationMessage {
                    Text(confirmationMessage)
                        .font(
                            .system(
                                size: 17,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            .cyan.opacity(0.85)
                        )
                }

                content

                Spacer(minLength: 0)
            }
            .padding(.horizontal, VeyraSpacing.page)
            .padding(.top, 36)
            .padding(.bottom, 50)
        }
        .task {
            await load()
        }
        .onAppear {
            reloadPreferences()
        }
        .navigationDestination(
            isPresented: $showSeries
        ) {
            if let configuration,
               let category =
                selectedCategory
            {
                IPTVSeriesItemManagementView(
                    configuration:
                        configuration,
                    category:
                        category
                )
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        VeyraBackground()
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                Text("Series beheren")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(
                    "CATEGORIEËN & SERIES"
                )
                .font(.caption)
                .tracking(3)
                .foregroundStyle(
                    .cyan.opacity(0.75)
                )
            }

            Spacer()

            Button {
                Task { await load() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 48, height: 48)
            }
            .accessibilityLabel("Categorieën en series nu vernieuwen")
        }
    }

    // MARK: - Bulk controls

    private var bulkVisibilityControls:
        some View
    {
        HStack(spacing: 18) {
            bulkControl(
                focus: .showAll,
                title:
                    "ALLES ZICHTBAAR",
                systemImage:
                    "eye.fill"
            ) {
                setAllSeriesVisible()
            }

            bulkControl(
                focus: .hideAll,
                title:
                    "ALLES ONZICHTBAAR",
                systemImage:
                    "eye.slash.fill"
            ) {
                setAllSeriesHidden()
            }
        }
        .focusSection()
    }

    private func bulkControl(
        focus: SeriesManagementFocus,
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        let isFocused =
            focusedControl ==
                focus

        return Label(
            title,
            systemImage:
                systemImage
        )
        .font(
            .system(
                size: 19,
                weight: .semibold
            )
        )
        .foregroundStyle(
            isFocused
                ? .white
                : .cyan
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .fill(
                isFocused
                    ? Color.cyan.opacity(0.18)
                    : Color.cyan.opacity(0.07)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .strokeBorder(
                isFocused
                    ? Color.cyan
                    : Color.cyan.opacity(0.20),
                lineWidth:
                    isFocused ? 2 : 1
            )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused(
            $focusedControl,
            equals: focus
        )
        .focusEffectDisabled()
        .onTapGesture {
            action()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView(
                "Series laden…"
            )
            .font(.title3)

        } else if let errorMessage {
            VStack(
                alignment: .leading,
                spacing: 16
            ) {
                Text(
                    "Series konden niet worden geladen"
                )
                .font(.title2)

                Text(errorMessage)
                    .foregroundStyle(
                        .secondary
                    )

                retryControl
            }

        } else if categories.isEmpty {
            Text(
                "Geen series-categorieën gevonden."
            )
            .foregroundStyle(
                .secondary
            )

        } else {
            ScrollView(
                .vertical,
                showsIndicators: false
            ) {
                LazyVStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    ForEach(categories) {
                        category in

                        categoryRow(
                            category
                        )
                    }
                }
                .padding(.vertical, 10)
                .focusSection()
            }
        }
    }

    private var retryControl:
        some View
    {
        let isFocused =
            focusedControl == .retry

        return Text("OPNIEUW")
            .font(
                .system(
                    size: 18,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                isFocused
                    ? .white
                    : .cyan
            )
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(
                    cornerRadius: 12
                )
                .fill(
                    isFocused
                        ? Color.cyan.opacity(0.18)
                        : Color.cyan.opacity(0.07)
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 12
                )
                .stroke(
                    isFocused
                        ? Color.cyan
                        : Color.cyan.opacity(0.18),
                    lineWidth:
                        isFocused ? 2 : 1
                )
            )
            .contentShape(Rectangle())
            .focusable(true)
            .focused(
                $focusedControl,
                equals: .retry
            )
            .focusEffectDisabled()
            .onTapGesture {
                Task {
                    await load()
                }
            }
    }

    // MARK: - Category

    private func categoryRow(
        _ category: IPTVCategory
    ) -> some View {
        let visible =
            preferences
                .isSeriesCategoryVisible(
                    category.id
                )

        return HStack(spacing: 14) {
            categoryVisibilityControl(
                category,
                visible: visible
            )

            categorySeriesControl(
                category
            )
        }
        .frame(maxWidth: 1000)
        .opacity(
            visible
                ? 1
                : 0.62
        )
    }

    private func categoryVisibilityControl(
        _ category: IPTVCategory,
        visible: Bool
    ) -> some View {
        let focus =
            SeriesManagementFocus
                .category(
                    category.id
                )

        let isFocused =
            focusedControl ==
                focus

        return HStack(spacing: 24) {
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
                    .foregroundStyle(
                        .white
                    )

                Text("Series-lijst")
                    .font(.body)
                    .foregroundStyle(
                        .secondary
                    )
            }

            Spacer()

            Label(
                visible
                    ? "ZICHTBAAR"
                    : "ONZICHTBAAR",
                systemImage:
                    visible
                    ? "eye.fill"
                    : "eye.slash.fill"
            )
            .font(
                .system(
                    size: 17,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                isFocused
                    ? .white
                    : (
                        visible
                            ? .cyan
                            : .secondary
                    )
            )
        }
        .padding(24)
        .frame(
            maxWidth: .infinity,
            minHeight: 120
        )
        .background(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .fill(
                isFocused
                    ? Color.cyan.opacity(0.16)
                    : Color.white.opacity(0.035)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .strokeBorder(
                isFocused
                    ? Color.cyan
                    : (
                        visible
                            ? Color.cyan.opacity(0.18)
                            : Color.white.opacity(0.07)
                    ),
                lineWidth:
                    isFocused ? 2 : 1
            )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused(
            $focusedControl,
            equals: focus
        )
        .focusEffectDisabled()
        .onTapGesture {
            setCategoryVisibility(
                category,
                visible: !visible
            )
        }
    }

    private func categorySeriesControl(
        _ category: IPTVCategory
    ) -> some View {
        let focus =
            SeriesManagementFocus
                .series(
                    category.id
                )

        let isFocused =
            focusedControl ==
                focus

        return VStack(spacing: 8) {
            Image(
                systemName:
                    "tv.badge.wifi"
            )
            .font(
                .system(
                    size: 24,
                    weight: .semibold
                )
            )

            Text("SERIES")
                .font(
                    .system(
                        size: 15,
                        weight: .semibold
                    )
                )
        }
        .foregroundStyle(
            isFocused
                ? .white
                : .cyan
        )
        .frame(
            width: 130,
            height: 120
        )
        .background(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .fill(
                isFocused
                    ? Color.cyan.opacity(0.16)
                    : Color.cyan.opacity(0.06)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .strokeBorder(
                isFocused
                    ? Color.cyan
                    : Color.cyan.opacity(0.18),
                lineWidth:
                    isFocused ? 2 : 1
            )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused(
            $focusedControl,
            equals: focus
        )
        .focusEffectDisabled()
        .onTapGesture {
            selectedCategoryID =
                category.id

            showSeries =
                true
        }
    }

    private var selectedCategory:
        IPTVCategory?
    {
        guard
            let selectedCategoryID
        else {
            return nil
        }

        return categories.first {
            $0.id ==
                selectedCategoryID
        }
    }

    // MARK: - Visibility

    private func setCategoryVisibility(
        _ category: IPTVCategory,
        visible: Bool
    ) {
        guard
            let configuration
        else {
            return
        }

        var updated =
            preferences

        updated.setSeriesCategory(
            category.id,
            visible: visible
        )

        savePreferences(
            updated,
            configuration:
                configuration
        )
    }

    private func setAllSeriesVisible() {
        guard
            let configuration
        else {
            return
        }

        var updated =
            preferences

        updated
            .hiddenSeriesCategoryIDs
            .removeAll()

        updated
            .hiddenSeriesItemIDs
            .removeAll()

        savePreferences(
            updated,
            configuration:
                configuration
        )

        confirmationMessage =
            "Alle series-categorieën en series zijn zichtbaar."
    }

    private func setAllSeriesHidden() {
        guard
            let configuration
        else {
            return
        }

        var updated =
            preferences

        updated.hiddenSeriesCategoryIDs =
            Set(
                categories.map(\.id)
            )

        updated
            .hiddenSeriesItemIDs
            .removeAll()

        savePreferences(
            updated,
            configuration:
                configuration
        )

        confirmationMessage =
            "Alle series-categorieën zijn verborgen."
    }

    private func savePreferences(
        _ updated:
            IPTVProviderPreferences,
        configuration:
            IPTVStoredConfiguration
    ) {
        do {
            try preferencesStore.save(
                updated,
                for: configuration
            )

            preferences =
                updated

            errorMessage = nil

            NotificationCenter.default.post(
                name:
                    .iptvConfigurationDidChange,
                object: nil
            )

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
        confirmationMessage = nil

        do {
            let configuration: IPTVStoredConfiguration?
            if let providerID {
                configuration = try configurationStore.loadProvider(id: providerID)?.configuration
            } else {
                configuration = try configurationStore.load()
            }
            guard
                let configuration
            else {
                self.configuration =
                    nil

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
                    "Series-beheer is alleen beschikbaar voor Xtream."

                isLoading = false
                return
            }

            categories =
                try await service
                    .loadXtreamSeriesCategories(
                        configuration:
                            xtreamConfiguration
                    )

        } catch is CancellationError {
        } catch {
            categories = []

            errorMessage =
                error.localizedDescription
        }

        isLoading = false
    }

    private func reloadPreferences() {
        guard
            let configuration
        else {
            return
        }

        preferences =
            preferencesStore.load(
                for: configuration
            )
    }
}

// MARK: - Focus

private enum SeriesManagementFocus:
    Hashable
{
    case showAll
    case hideAll
    case retry
    case category(String)
    case series(String)
}

// MARK: - Series items

private struct IPTVSeriesItemManagementView:
    View
{
    let configuration:
        IPTVStoredConfiguration

    let category:
        IPTVCategory

    @State private var items:
        [XtreamSeriesItem] = []

    @State private var preferences =
        IPTVProviderPreferences()

    @State private var isLoading =
        false

    @State private var errorMessage:
        String?

    @FocusState
    private var focusedControl:
        SeriesItemFocus?

    private let service =
        IPTVService()

    private let preferencesStore =
        IPTVProviderPreferencesStore()

    var body: some View {
        ZStack {
            background

            VStack(
                alignment: .leading,
                spacing: 28
            ) {
                header
                content

                Spacer(minLength: 0)
            }
            .padding(.horizontal, VeyraSpacing.page)
            .padding(.top, 36)
            .padding(.bottom, 50)
        }
        .task {
            await loadItems()
        }
    }

    private var background:
        some View
    {
        VeyraBackground()
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                Text(category.name)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("SERIES")
                    .font(.caption)
                    .tracking(3)
                    .foregroundStyle(
                        .cyan.opacity(0.75)
                    )
            }

            Spacer()

            Button {
                Task { await loadItems() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 48, height: 48)
            }
            .accessibilityLabel("Series nu vernieuwen")
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView(
                "Series laden…"
            )

        } else if let errorMessage {
            VStack(
                alignment: .leading,
                spacing: 16
            ) {
                Text(
                    "Series konden niet worden geladen"
                )
                .font(.title2)

                Text(errorMessage)
                    .foregroundStyle(
                        .secondary
                    )
            }

        } else if items.isEmpty {
            Text(
                "Geen series gevonden."
            )
            .foregroundStyle(
                .secondary
            )

        } else {
            ScrollView(
                .vertical,
                showsIndicators: false
            ) {
                LazyVStack(
                    alignment: .leading,
                    spacing: 14
                ) {
                    ForEach(items) {
                        item in

                        itemRow(item)
                    }
                }
                .padding(.vertical, 10)
                .focusSection()
            }
        }
    }

    private func itemRow(
        _ item: XtreamSeriesItem
    ) -> some View {
        let visible =
            preferences
                .isSeriesItemVisible(
                    String(item.id)
                )

        return visibilityControl(
            item,
            visible: visible
        )
        .frame(maxWidth: 1000)
        .opacity(
            visible
                ? 1
                : 0.58
        )
    }

    private func visibilityControl(
        _ item: XtreamSeriesItem,
        visible: Bool
    ) -> some View {
        let focus =
            SeriesItemFocus
                .visibility(
                    item.id
                )

        let isFocused =
            focusedControl ==
                focus

        return HStack(spacing: 20) {
            poster(item)

            Text(item.name)
                .font(
                    .system(
                        size: 22,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .white
                )
                .lineLimit(2)

            Spacer()

            Label(
                visible
                    ? "ZICHTBAAR"
                    : "ONZICHTBAAR",
                systemImage:
                    visible
                    ? "eye.fill"
                    : "eye.slash.fill"
            )
            .font(
                .system(
                    size: 17,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                isFocused
                    ? .white
                    : (
                        visible
                            ? .cyan
                            : .secondary
                    )
            )
        }
        .padding(20)
        .frame(
            maxWidth: .infinity,
            minHeight: 145
        )
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(
                isFocused
                    ? Color.cyan.opacity(0.16)
                    : Color.white.opacity(0.035)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .strokeBorder(
                isFocused
                    ? Color.cyan
                    : Color.clear,
                lineWidth:
                    isFocused ? 2 : 0
            )
        )
        .contentShape(Rectangle())
        .focusable(true)
        .focused(
            $focusedControl,
            equals: focus
        )
        .focusEffectDisabled()
        .onTapGesture {
            setItemVisibility(
                item,
                visible: !visible
            )
        }
    }

    // MARK: - Poster

    @ViewBuilder
    private func poster(
        _ item: XtreamSeriesItem
    ) -> some View {
        VeyraAsyncImage(
            url: item.coverURL
        ) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()

            case .empty:
                ZStack {
                    Color.white.opacity(
                        0.04
                    )

                    ProgressView()
                }

            case .failure:
                posterFallback

            @unknown default:
                posterFallback
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

    private var posterFallback:
        some View
    {
        ZStack {
            Color.white.opacity(
                0.04
            )

            Image(
                systemName: "tv"
            )
            .foregroundStyle(
                .secondary
            )
        }
    }

    // MARK: - Visibility

    private func setItemVisibility(
        _ item: XtreamSeriesItem,
        visible: Bool
    ) {
        var updated =
            preferences

        updated.setSeriesItem(
            String(item.id),
            visible: visible
        )

        do {
            try preferencesStore.save(
                updated,
                for: configuration
            )

            preferences =
                updated

            errorMessage = nil

            NotificationCenter.default.post(
                name:
                    .iptvConfigurationDidChange,
                object: nil
            )

        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    // MARK: - Load

    @MainActor
    private func loadItems()
        async
    {
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
                "Series-beheer is alleen beschikbaar voor Xtream."

            isLoading = false
            return
        }

        do {
            items =
                try await service
                    .loadXtreamSeries(
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

private enum SeriesItemFocus:
    Hashable
{
    case visibility(Int)
}

#Preview {
    NavigationStack {
        IPTVSeriesManagementView()
    }
}
