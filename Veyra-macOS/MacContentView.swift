import SwiftUI

struct MacContentView: View {
    @State private var selection: MenuDestination = .home
    @ObservedObject private var homeNavigation = HomeNavigationState.shared

    // Zijbalk of menubalk boven, net als op iPad (Instellingen → Algemeen →
    // Navigatie) -- dezelfde instelling, want tot nu toe las macOS deze
    // sleutel helemaal niet uit en gebruikte altijd een vaste zijbalk,
    // ongeacht wat hier stond.
    @AppStorage(GeneralSettingsDefaults.ipadNavigationStyleKey)
    private var navigationStyleRaw = IPadNavigationStyle.sidebar.rawValue

    private var navigationStyle: IPadNavigationStyle {
        IPadNavigationStyle(rawValue: navigationStyleRaw) ?? .sidebar
    }

    // De lijst verwacht een optionele binding; de getoonde bestemming blijft
    // altijd geldig, ook wanneer macOS de selectie tijdelijk leegt.
    private var sidebarSelection: Binding<MenuDestination?> {
        Binding(
            get: { selection },
            set: { newValue in
                if let newValue { selection = newValue }
            }
        )
    }

    var body: some View {
        Group {
            switch navigationStyle {
            case .sidebar:
                sidebarLayout
            case .topBar:
                topBarLayout
            }
        }
        .tint(VeyraColors.cyan)
        .onChange(of: homeNavigation.requestedTab) { _, tab in
            guard let tab else { return }
            selection = tab == .live ? .liveTV : .sport
            homeNavigation.requestedTab = nil
        }
    }

    // MARK: - Zijbalk

    private var sidebarLayout: some View {
        NavigationSplitView {
            List(selection: sidebarSelection) {
                ForEach(sidebarSections) { destination in
                    Label(destination.title, systemImage: destination.symbol)
                        .tag(destination)
                        .foregroundStyle(selection == destination ? VeyraColors.cyan : .primary)
                }
            }
            .scrollContentBackground(.hidden)
            .veyraScrollingBackground(legacyList: true)
            .navigationTitle("Veyra")
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(VeyraBackground())
        } detail: {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Zelfde items en volgorde als de menubalk hieronder en als tvOS'
    /// `VeyraTopNavigation` -- alleen als verticale lijst i.p.v. horizontale
    /// pillen.
    private var sidebarSections: [MenuDestination] {
        [.home, .film, .series, .watchlist, .sport, .liveTV, .recordings, .search, .account, .settings]
    }

    // MARK: - Menubalk boven

    private var topBarLayout: some View {
        VStack(spacing: 0) {
            MacTopNavigation(selected: selection) { selection = $0 }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(VeyraBackground())
    }

    // MARK: - Inhoud

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .home:
            HomeView(onSearch: { selection = .search }, onSettings: { selection = .settings })
        case .film:
            MoviesView()
        case .series:
            SeriesView()
        case .watchlist:
            WatchlistView()
        case .search:
            SearchView()
        case .liveTV:
            LiveTVView()
        case .sport:
            SportsView()
        case .recordings:
            VeyraRecordingsView()
        case .account:
            AccountView()
        case .settings:
            SettingsView()
        }
    }
}
