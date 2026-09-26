// VeyraHeroSourcePickerView.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Kiest één bron (TMDB- of Trakt-lijst) voor de Home-hero. Hergebruikt
// dezelfde brontypes als "Planken" (ShelfSource), maar beperkt tot TMDB en
// Trakt -- de Home-hero toont geen addon-/mediaserver-/IPTV-content.

import SwiftUI

struct VeyraHeroSourcePickerView: View {
    let title: String
    let allowsNone: Bool
    @Binding var source: ShelfSource?

    private enum Kind: String, CaseIterable { case trakt = "Trakt", tmdb = "TMDB" }

    @State private var mediaKind: ShelfMediaKind
    @State private var kind: Kind
    @State private var traktList: TraktShelfList
    @State private var tmdbList: TMDBShelfList
    @State private var traktPersonalLists: [TraktPersonalList] = []
    @State private var isLoadingTraktLists = false

    init(title: String, allowsNone: Bool = false, source: Binding<ShelfSource?>) {
        self.title = title
        self.allowsNone = allowsNone
        self._source = source

        switch source.wrappedValue {
        case .trakt(let list, let mk):
            _mediaKind = State(initialValue: mk)
            _kind = State(initialValue: .trakt)
            _traktList = State(initialValue: list)
            _tmdbList = State(initialValue: .trendingDay)
        case .tmdb(let list, let mk):
            _mediaKind = State(initialValue: mk)
            _kind = State(initialValue: .tmdb)
            _tmdbList = State(initialValue: list)
            _traktList = State(initialValue: .trending)
        default:
            _mediaKind = State(initialValue: .movie)
            _kind = State(initialValue: .tmdb)
            _tmdbList = State(initialValue: .trendingDay)
            _traktList = State(initialValue: .trending)
        }
    }

    var body: some View {
        content
            .navigationTitle(title)
            .task { await loadTraktPersonalLists() }
            .onChange(of: mediaKind) { _, _ in apply() }
            .onChange(of: kind) { _, _ in apply() }
            .onChange(of: traktList) { _, _ in apply() }
            .onChange(of: tmdbList) { _, _ in apply() }
    }

    @ViewBuilder
    private var content: some View {
        #if os(tvOS)
        ZStack {
            VeyraBackground().ignoresSafeArea()
            List {
                Section { picks } footer: { Text("Kies de lijst die deze bron voor de hero levert.") }
            }
            .frame(maxWidth: 1000)
        }
        #else
        Form {
            Section { picks } footer: { Text("Kies de lijst die deze bron voor de hero levert.") }
        }
        #endif
    }

    @ViewBuilder
    private var picks: some View {
        if allowsNone {
            Button("Geen (enkel de primaire bron)") { source = nil }
        }
        Picker("Type", selection: $mediaKind) {
            Text("Films").tag(ShelfMediaKind.movie)
            Text("Series").tag(ShelfMediaKind.series)
        }
        Picker("Bron", selection: $kind) {
            ForEach(Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        if kind == .trakt {
            Picker("Lijst", selection: $traktList) {
                ForEach(TraktShelfList.availableLists(for: mediaKind), id: \.self) { list in
                    Text(list.label(for: mediaKind)).tag(list)
                }
                if !traktPersonalLists.isEmpty {
                    ForEach(traktPersonalLists, id: \.self) { list in
                        Text(list.name)
                            .tag(TraktShelfList.personal(id: list.ids.trakt, slug: list.ids.slug, name: list.name))
                    }
                }
            }
            if isLoadingTraktLists {
                ProgressView()
            } else if traktPersonalLists.isEmpty {
                Text("Log in bij Trakt (Instellingen → Account) om je eigen lijsten hier te kunnen kiezen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            Picker("Lijst", selection: $tmdbList) {
                ForEach(TMDBShelfList.availableLists(for: mediaKind), id: \.self) { list in
                    Text(list.label(for: mediaKind)).tag(list)
                }
            }
        }
    }

    private func apply() {
        source = kind == .trakt
            ? .trakt(list: traktList, kind: mediaKind)
            : .tmdb(list: tmdbList, kind: mediaKind)
    }

    private func loadTraktPersonalLists() async {
        guard traktPersonalLists.isEmpty, !isLoadingTraktLists else { return }
        isLoadingTraktLists = true
        defer { isLoadingTraktLists = false }
        traktPersonalLists = await ShelfCatalogService.fetchTraktPersonalLists()
    }
}
