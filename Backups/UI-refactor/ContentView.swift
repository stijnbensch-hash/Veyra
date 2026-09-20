import SwiftUI

struct ContentView: View {
    @State private var destination: MenuDestination?

    @FocusState
    private var focusedItem: MenuDestination?

    private let contentMargin: CGFloat = 28

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 0) {
                    menu

                    ScrollView(
                        .vertical,
                        showsIndicators: false
                    ) {
                        VStack(
                            alignment: .leading,
                            spacing: 48
                        ) {
                            TraktContinueWatchingView()

                            TraktUpcomingView()

                            SportsHomeView()

                            IPTVRecentlyAddedVODRow()
                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .padding(
                            .horizontal,
                            contentMargin
                        )
                        .padding(
                            .top,
                            36
                        )
                        .padding(
                            .bottom,
                            50
                        )
                    }
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .top
                )
            }

            // Alleen de grote horizontale tvOS-safe-area verwijderen.
            // Boven en onder blijven intact voor goede focusnavigatie.
            .ignoresSafeArea(
                .container,
                edges: .horizontal
            )
            .navigationDestination(
                item: $destination
            ) { destination in
                switch destination {
                case .film:
                    MoviesView()

                case .series:
                    SeriesView()

                case .liveTV:
                    LiveTVView()

                case .sport:
                    SportsView()

                case .search:
                    SearchView()

                case .settings:
                    SettingsView()
                }
            }
        }
    }

    // MARK: - Background

    private var background: some View {
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
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Menu

    private var menu: some View {
        HStack(spacing: 26) {
            menuItem(
                title: "FILM",
                item: .film
            )

            menuItem(
                title: "SERIES",
                item: .series
            )

            menuItem(
                title: "LIVE TV",
                item: .liveTV
            )

            menuItem(
                title: "SPORT",
                item: .sport
            )

            menuItem(
                title: "ZOEKEN",
                item: .search
            )

            menuItem(
                title: "INSTELLINGEN",
                item: .settings
            )
        }
        .padding(
            .horizontal,
            contentMargin
        )
        .padding(
            .top,
            8
        )
        .padding(
            .bottom,
            12
        )
        .frame(
            maxWidth: .infinity
        )
        .focusSection()
    }

    // MARK: - Menu item

    private func menuItem(
        title: String,
        item: MenuDestination
    ) -> some View {
        let isFocused =
            focusedItem == item

        return Text(title)
            .font(
                .system(
                    size: 23,
                    weight: .semibold
                )
            )
            .tracking(3)
            .foregroundStyle(
                isFocused
                    ? .white
                    : .cyan
            )
            .padding(
                .horizontal,
                17
            )
            .padding(
                .vertical,
                7
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(
                    isFocused
                        ? Color.cyan.opacity(0.32)
                        : Color.clear
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    isFocused
                        ? Color.cyan.opacity(0.55)
                        : Color.clear,
                    lineWidth: 1
                )
            )
            .contentShape(
                Rectangle()
            )
            .focusable(true)
            .focused(
                $focusedItem,
                equals: item
            )
            .focusEffectDisabled()
            .onTapGesture {
                destination = item
            }
    }
}

private enum MenuDestination:
    String,
    Identifiable
{
    case film
    case series
    case liveTV
    case sport
    case search
    case settings

    var id: String {
        rawValue
    }
}

#Preview {
    ContentView()
}
