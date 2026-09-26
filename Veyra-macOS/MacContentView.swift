import SwiftUI

private enum MacSection: String, Hashable, CaseIterable {
    case home = "Home"
    case movies = "Films"
    case series = "Series"
    case search = "Zoeken"
    case live = "Live"
    case sports = "Sport"
    case settings = "Instellingen"

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .movies: "film.fill"
        case .series: "tv.fill"
        case .search: "magnifyingglass"
        case .live: "antenna.radiowaves.left.and.right"
        case .sports: "trophy"
        case .settings: "gearshape.fill"
        }
    }
}

struct MacContentView: View {
    @State private var selection: MacSection? = .home
    @ObservedObject private var homeNavigation = HomeNavigationState.shared

    var body: some View {
        NavigationSplitView {
            List(MacSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationTitle("Veyra")
            .listStyle(.sidebar)
        } detail: {
            Group {
                switch selection ?? .home {
                case .home: HomeView(onSearch: { selection = .search }, onSettings: { selection = .settings })
                case .movies: MoviesView()
                case .series: SeriesView()
                case .search: SearchView()
                case .live: LiveTVView()
                case .sports: SportsView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .tint(VeyraColors.cyan)
        .onChange(of: homeNavigation.requestedTab) { _, tab in
            guard let tab else { return }
            selection = tab == .live ? .live : .sports
            homeNavigation.requestedTab = nil
        }
    }
}

extension MacSection: Identifiable {
    var id: String { rawValue }
}
