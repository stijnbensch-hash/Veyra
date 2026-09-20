import SwiftUI

struct MetadataSettingsView: View {
    @AppStorage("metadata.source.preference") private var metadataSourceRaw = MetadataSourceOption.tmdb.rawValue

    @AppStorage(MetadataRatingProvider.imdb.storageKey) private var imdb = true
    @AppStorage(MetadataRatingProvider.tmdb.storageKey) private var tmdb = true
    @AppStorage(MetadataRatingProvider.tomatometer.storageKey) private var tomatometer = true
    @AppStorage(MetadataRatingProvider.metacritic.storageKey) private var metacritic = true
    @AppStorage(MetadataRatingProvider.trakt.storageKey) private var trakt = true
    @AppStorage(MetadataRatingProvider.popcornmeter.storageKey) private var popcornmeter = true

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            List {
                Section {
                    Picker("Metadatabron", selection: $metadataSourceRaw) {
                        ForEach(MetadataSourceOption.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                } header: {
                    Text("Metadatabron")
                } footer: {
                    Text("Bepaalt waar poster, achtergrond en omschrijving vandaan komen voor titels zonder eigen afbeeldingen (bv. Trakt-lijsten). AIOMetadata vereist een addon bij Addons.")
                }

                Section {
                    toggleRow(.imdb, isOn: $imdb)
                    toggleRow(.tmdb, isOn: $tmdb)
                    toggleRow(.tomatometer, isOn: $tomatometer)
                    toggleRow(.metacritic, isOn: $metacritic)
                    toggleRow(.trakt, isOn: $trakt)
                    toggleRow(.popcornmeter, isOn: $popcornmeter)
                } header: {
                    Text("Ratings")
                } footer: {
                    Text("Kies welke ratings zichtbaar zijn op film- en seriepagina's. Een titel toont alleen de scores die de bron er daadwerkelijk voor heeft.")
                }

                Section {
                    Button("Alle ratings inschakelen") { setAll(true) }
                    Button("Alle ratings uitschakelen") { setAll(false) }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Metadata")
    }

    // MARK: - Row

    private func toggleRow(_ provider: MetadataRatingProvider, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconBackground(provider))
                        .frame(width: 36, height: 36)

                    Image(systemName: provider.systemImage)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(iconForeground(provider))
                }

                Text(provider.title)
            }
        }
        .tint(VeyraColors.cyan)
    }

    private func iconBackground(_ provider: MetadataRatingProvider) -> Color {
        switch provider {
        case .imdb: return .yellow
        case .tmdb: return .cyan.opacity(0.22)
        case .tomatometer: return .red.opacity(0.22)
        case .metacritic: return .yellow.opacity(0.18)
        case .trakt: return .pink.opacity(0.22)
        case .popcornmeter: return .orange.opacity(0.22)
        }
    }

    private func iconForeground(_ provider: MetadataRatingProvider) -> Color {
        switch provider {
        case .imdb: return .black
        case .tmdb: return .cyan
        case .tomatometer: return .red
        case .metacritic: return .yellow
        case .trakt: return .pink
        case .popcornmeter: return .orange
        }
    }

    // MARK: - Actions

    private func setAll(_ enabled: Bool) {
        imdb = enabled
        tmdb = enabled
        tomatometer = enabled
        metacritic = enabled
        trakt = enabled
        popcornmeter = enabled
    }
}

#Preview {
    NavigationStack { MetadataSettingsView() }
}
