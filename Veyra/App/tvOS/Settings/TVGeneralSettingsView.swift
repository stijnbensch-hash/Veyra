import SwiftUI

/// tvOS: Instellingen → Algemeen. Nu: sportvoorkeuren en favoriete teams.
struct TVGeneralSettingsView: View {
    @AppStorage(GeneralSettingsDefaults.hideScoreSpoilersKey)
    private var hideScoreSpoilers = false
    @AppStorage(TMDBCatalogLanguageFilter.key)
    private var catalogLanguages = "nl-en"
    @AppStorage(RecorderSettingsDefaults.autoDeleteAfterWatchedKey)
    private var autoDeleteAfterWatched = false

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    Picker("Oorspronkelijke taal", selection: $catalogLanguages) {
                        Text("Nederlands en Engels").tag("nl-en")
                        Text("Alle talen").tag("all")
                    }
                } header: {
                    Text("TMDB-lijsten")
                } footer: {
                    Text("Filtert automatisch samengestelde lijsten, ook op Home. Zoeken en eigen lijsten blijven volledig beschikbaar.")
                }

                Section {
                    VeyraSettingsToggleRow(icon: "eye.slash", title: "Uitslag verbergen tot tik",
                                           subtitle: "Vervaagt de stand op live en afgelopen wedstrijden",
                                           isOn: $hideScoreSpoilers)

                    NavigationLink {
                        TVFavoriteTeamsSettingsView()
                    } label: {
                        VeyraSettingsCardRowLabel(icon: "star", title: "Favoriete teams",
                                                  subtitle: "Zoek teams en beheer je favorieten") {
                            VeyraSettingsCardRowValue(value: nil)
                        }
                    }
                    .veyraCardRow()
                } header: {
                    Text("Sport")
                }

                Section {
                    VeyraSettingsToggleRow(icon: "record.circle", title: "Verwijder automatisch na kijken",
                                           subtitle: "Verwijdert een VeyraHub-opname zodra je hem hebt uitgekeken",
                                           isOn: $autoDeleteAfterWatched)
                } header: {
                    Text("VeyraHub Recorder")
                }
            }
            .frame(maxWidth: 1000)
        }
        .navigationTitle("Algemeen")
    }
}

/// tvOS: favoriete teams zoeken, toevoegen en verwijderen.
struct TVFavoriteTeamsSettingsView: View {
    @StateObject private var directory = SportsTeamDirectory()
    @State private var query = ""
    @State private var favoriteIDs = SportsFavorites.ids()
    @State private var info = SportsFavorites.info()

    private var results: [SportsTeam] { directory.search(query) }
    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                if isSearching { searchSection } else { favoritesSection }
            }
            .frame(maxWidth: 1000)
        }
        .navigationTitle("Favoriete teams")
        .searchable(text: $query, prompt: "Zoek een team")
        .task { await directory.load() }
        .onChange(of: directory.teams.count) { _, _ in backfill() }
    }

    @ViewBuilder
    private var favoritesSection: some View {
        Section {
            if favoriteIDs.isEmpty {
                Text("Nog geen favoriete teams. Gebruik de zoekbalk om een team toe te voegen.")
                    .foregroundStyle(.secondary)
            }
            ForEach(favoriteIDs.sorted { name(for: $0) < name(for: $1) }, id: \.self) { id in
                Button {
                    SportsFavorites.remove(id: id)
                    refresh()
                } label: {
                    row(name: name(for: id), logo: info[id]?.logo.flatMap(URL.init(string:)), favorite: true)
                }
                .veyraCardRow()
            }
        } header: {
            Text("Mijn teams")
        } footer: {
            Text("Selecteer een team om het te verwijderen. Je kunt ook lang indrukken op een wedstrijd in het Sport-menu.")
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
            ForEach(results.prefix(40)) { team in
                let isFav = favoriteIDs.contains(team.id)
                Button {
                    SportsFavorites.set(team, favorite: !isFav)
                    refresh()
                } label: {
                    row(name: team.name, logo: team.logoURL, favorite: isFav)
                }
                .veyraCardRow()
            }
        } header: {
            Text("Zoekresultaten")
        }
    }

    private func row(name: String, logo: URL?, favorite: Bool) -> some View {
        HStack(spacing: 18) {
            AsyncImage(url: logo) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Image(systemName: "sportscourt").foregroundStyle(.secondary)
                }
            }
            .frame(width: 50, height: 50)

            Text(name)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: favorite ? "star.fill" : "star")
                .foregroundStyle(favorite ? Color.yellow : Color.white.opacity(0.55))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func name(for id: String) -> String {
        info[id]?.name ?? directory.teams.first(where: { $0.id == id })?.name
            ?? "Team \(id.split(separator: ":").last.map(String.init) ?? id)"
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

    private func refresh() {
        favoriteIDs = SportsFavorites.ids()
        info = SportsFavorites.info()
    }
}
