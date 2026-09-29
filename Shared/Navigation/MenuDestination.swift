import SwiftUI

enum MenuDestination: String, Identifiable, CaseIterable {
    case home, film, series, watchlist, sport, liveTV, recordings, account, search, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: "Home"
        case .film: "Films"
        case .series: "Series"
        case .watchlist: "Kijklijst"
        case .sport: "Sport"
        case .liveTV: "Live TV"
        case .recordings: "Opnames"
        case .account: "Account"
        case .search: "Zoeken"
        case .settings: "Instellingen"
        }
    }
    var symbol: String {
        switch self {
        case .home: "house"
        case .film: "film"
        case .series: "tv"
        case .watchlist: "bookmark.fill"
        case .sport: "trophy"
        case .liveTV: "antenna.radiowaves.left.and.right"
        case .recordings: "record.circle"
        case .account: "person.crop.circle"
        case .search: "magnifyingglass"
        case .settings: "gearshape"
        }
    }
}

private struct VeyraPlayerVisibilityKey: EnvironmentKey {
    static let defaultValue: (Bool) -> Void = { _ in }
}
extension EnvironmentValues {
    var veyraPlayerVisibility: (Bool) -> Void {
        get { self[VeyraPlayerVisibilityKey.self] }
        set { self[VeyraPlayerVisibilityKey.self] = newValue }
    }
}
