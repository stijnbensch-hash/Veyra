import SwiftUI

/// iOS-native "Sport"-tab. Hergebruikt dezelfde Shared `SportsStore`/
/// `SportsModels` als tvOS' Sportcentrum (`SportsView` in
/// `Veyra/App/tvOS/Sports/SportsViews.swift`), met een eenvoudige native
/// iOS-lijst i.p.v. de tvOS-focuservaring: dagnavigatie, filter op
/// live/programma/uitslagen, favorieten en groepering per competitie.
struct SportsView: View {
    @StateObject private var store = SportsStore()
    @Environment(\.scenePhase) private var scenePhase

    @State private var date = Calendar.current.startOfDay(for: Date())
    @State private var filter = SportsFilterIOS.all
    @State private var favoritesOnly = false
    @State private var selectedMatch: SportsMatch?

    private var filtered: [SportsMatch] {
        store.matches.filter {
            (!favoritesOnly || store.isFavorite($0)) && filter.accepts($0)
        }
    }

    private var groupedByLeague: [(league: SportsLeague, matches: [SportsMatch])] {
        let grouped = Dictionary(grouping: filtered) { $0.league.id }
        return grouped.compactMap { _, matches in
            guard let league = matches.first?.league else { return nil }
            return (league, matches.sorted { $0.date < $1.date })
        }
        .sorted { $0.league.name < $1.league.name }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VeyraColors.background.ignoresSafeArea()

                content
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedMatch) { match in
                SportsMatchDetailIOS(match: match)
            }
        }
        .task(id: date) {
            await store.refresh(date: date)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await store.refresh(date: date)
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    return
                }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VeyraSectionHeader(title: "Sport")

                Button {
                    Task { await store.refresh(date: date, force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            dateBar

            Picker("Filter", selection: $filter) {
                ForEach(SportsFilterIOS.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            Toggle("Alleen favorieten", isOn: $favoritesOnly)
                .padding(.horizontal)
                .padding(.top, 8)

            if groupedByLeague.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(groupedByLeague, id: \.league.id) { group in
                            leagueSection(group.league, matches: group.matches)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            if store.isLoading {
                ProgressView("Wedstrijden ophalen…")
            } else if !store.failedLeagues.isEmpty {
                Text("Scores tijdelijk niet beschikbaar.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Geen wedstrijden voor deze dag/filter.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dateBar: some View {
        HStack {
            Button {
                date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(dateLabel)
                .font(.subheadline.weight(.semibold))

            Spacer()

            Button {
                date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var dateLabel: String {
        if Calendar.current.isDateInToday(date) { return "Vandaag" }
        if Calendar.current.isDateInYesterday(date) { return "Gisteren" }
        if Calendar.current.isDateInTomorrow(date) { return "Morgen" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func leagueSection(_ league: SportsLeague, matches: [SportsMatch]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(league.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(matches) { match in
                    Button {
                        selectedMatch = match
                    } label: {
                        SportsMatchRowIOS(
                            match: match,
                            homeFavorite: store.isFavoriteTeam(match.home),
                            awayFavorite: store.isFavoriteTeam(match.away),
                            stale: store.failedLeagues.contains(match.league.id),
                            onToggleHome: { store.toggle(match.home) },
                            onToggleAway: { store.toggle(match.away) }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private enum SportsFilterIOS: String, CaseIterable, Identifiable {
    case all = "Alles"
    case live = "Live"
    case upcoming = "Programma"
    case results = "Uitslagen"

    var id: String { rawValue }

    func accepts(_ match: SportsMatch) -> Bool {
        switch self {
        case .all: return true
        case .live: return match.phase == .live
        case .upcoming: return match.phase == .scheduled
        case .results: return match.phase == .finished
        }
    }
}

private struct SportsMatchRowIOS: View {
    let match: SportsMatch
    let homeFavorite: Bool
    let awayFavorite: Bool
    let stale: Bool
    let onToggleHome: () -> Void
    let onToggleAway: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                teamRow(match.home, score: match.homeScore, favorite: homeFavorite, onToggle: onToggleHome)
                teamRow(match.away, score: match.awayScore, favorite: awayFavorite, onToggle: onToggleAway)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if match.phase == .live {
                    Text("LIVE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(VeyraColors.red)
                }

                Text(match.status)
                    .font(.caption2)
                    .foregroundStyle(stale ? .orange : .secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(12)
        .veyraGlass(radius: 14)
    }

    private func teamRow(_ team: SportsTeam, score: String?, favorite: Bool, onToggle: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: favorite ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundStyle(favorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)

            AsyncImage(url: team.logoURL ?? SportsTeam.fallbackLogoURL(abbreviation: team.abbreviation)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                default:
                    Image(systemName: "sportscourt")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 22, height: 22)

            Text(team.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            if match.showsScore, let score {
                Text(score)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
            }
        }
    }
}

#Preview {
    SportsView()
}
