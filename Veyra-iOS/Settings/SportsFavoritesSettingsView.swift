import SwiftUI

/// Instellingen → Algemeen → Sport → Favoriete teams: favorieten bekijken/verwijderen en teams zoeken om toe te voegen.
struct SportsFavoritesSettingsView: View {
    @StateObject private var directory = SportsTeamDirectory()
    @State private var query = ""
    @State private var favoriteIDs = SportsFavorites.ids()
    @State private var info = SportsFavorites.info()

    private var results: [SportsTeam] { directory.search(query) }

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            List {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    favoritesSection
                } else {
                    searchSection
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Favoriete teams")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Zoek een team")
        .task { await directory.load() }
        .onChange(of: directory.teams.count) { _, _ in backfill() }
    }

    /// Favorieten die vroeger zonder naam bewaard werden, krijgen hun naam en logo zodra de teamlijst geladen is.
    private func backfill() {
        for id in favoriteIDs where info[id] == nil {
            if let team = directory.teams.first(where: { $0.id == id }) {
                SportsFavorites.record(team, isFavorite: true)
            }
        }
        refresh()
    }

    @ViewBuilder
    private var favoritesSection: some View {
        Section {
            if favoriteIDs.isEmpty {
                Text("Nog geen favoriete teams. Zoek hierboven een team om toe te voegen.")
                    .foregroundStyle(.secondary)
            }
            ForEach(favoriteIDs.sorted { name(for: $0) < name(for: $1) }, id: \.self) { id in
                HStack(spacing: 12) {
                    logo(info[id]?.logo.flatMap(URL.init(string:)))
                    Text(name(for: id))
                    Spacer()
                    Button {
                        SportsFavorites.remove(id: id)
                        refresh()
                    } label: {
                        Image(systemName: "star.fill").foregroundStyle(.yellow)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Verwijder uit favoriete teams")
                }
            }
        } header: {
            Text("Mijn teams")
        } footer: {
            Text("Favoriete teams krijgen voorrang in het Sport-menu en op Home. Je kunt ook in het Sport-menu op de ster naast een team tikken.")
        }
    }

    @ViewBuilder
    private var searchSection: some View {
        Section {
            if directory.isLoading && results.isEmpty {
                HStack(spacing: 10) { ProgressView(); Text("Teams laden…").foregroundStyle(.secondary) }
            } else if results.isEmpty {
                Text(directory.failed ? "Teams konden niet geladen worden." : "Geen teams gevonden.")
                    .foregroundStyle(.secondary)
            }
            ForEach(results.prefix(60)) { team in
                let isFav = favoriteIDs.contains(team.id)
                Button {
                    SportsFavorites.set(team, favorite: !isFav)
                    refresh()
                } label: {
                    HStack(spacing: 12) {
                        logo(team.logoURL)
                        Text(team.name).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: isFav ? "star.fill" : "star")
                            .foregroundStyle(isFav ? .yellow : .secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Zoekresultaten")
        }
    }

    private func name(for id: String) -> String {
        info[id]?.name ?? "Team \(id.split(separator: ":").last.map(String.init) ?? id)"
    }

    private func logo(_ url: URL?) -> some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit()
            } else {
                Image(systemName: "sportscourt").foregroundStyle(.secondary)
            }
        }
        .frame(width: 30, height: 30)
    }

    private func refresh() {
        favoriteIDs = SportsFavorites.ids()
        info = SportsFavorites.info()
    }
}
