import SwiftUI

/// Overzicht van de eigen Live TV-mappen: aanmaken, bewerken, herordenen en
/// verwijderen. Bereikbaar vanuit `LiveTVView` (tvOS en iOS/macOS) via een
/// map-knop naast de andere Live TV-acties. Tikken op een map opent
/// `LiveTVFolderChannelsView` met de kanalen erin; bewerken gebeurt via de
/// aparte "Bewerken"-knop, zodat een korte tik altijd naar het afspelen
/// leidt en niet naar het bewerkscherm.
struct LiveTVFoldersListView: View {
    @StateObject private var viewModel = LiveTVFoldersViewModel()
    @State private var showAddSheet = false
    @State private var editingFolder: LiveTVFolder?

    var body: some View {
        VeyraDynamicBackgroundScope {
            platformBody
                .navigationTitle("Mijn mappen")
                .sheet(isPresented: $showAddSheet, onDismiss: viewModel.reload) {
                    NavigationStack { LiveTVFolderEditView(folder: nil, viewModel: viewModel) }
                }
                .sheet(item: $editingFolder, onDismiss: viewModel.reload) { folder in
                    NavigationStack { LiveTVFolderEditView(folder: folder, viewModel: viewModel) }
                }
                .onAppear(perform: viewModel.reload)
                .onReceive(NotificationCenter.default.publisher(for: .veyraLiveTVFoldersDidChange)) { _ in
                    viewModel.reload()
                }

        }
    }

    // Op tvOS wordt dit scherm altijd als `.sheet` getoond, en een tvOS-sheet
    // valt standaard klein/smal uit -- het formaat volgt namelijk de eigen
    // "ideale" grootte van de inhoud, en een kale `List` meldt daarvoor geen
    // brede maat (een `.frame(width:)` er los op plakken dwingt de List zelf
    // wel breder, maar de sheet zelf bleef dan achter zijn oude, kleinere
    // maat -- vandaar de eerder geziene overloop/witte balk). Dezelfde
    // aanpak als `ChannelLogoPickerView`/`SourceOrderView` lost dit wél op:
    // een volledig-schermvullende `VeyraBackground` in een `ZStack` laat de
    // sheet zich naar een groot formaat voegen, en pas daarbinnen krijgt de
    // `List` een `.frame(maxWidth:)` om een leesbare, niet oneindig brede
    // kolom te houden.
    @ViewBuilder
    private var platformBody: some View {
        #if os(tvOS)
        ZStack {
            VeyraBackground().ignoresSafeArea()
            foldersList
                .frame(maxWidth: 1700)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [VeyraColors.ice, VeyraColors.cyan, VeyraColors.red.opacity(0.70)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
        }
        #else
        foldersList
            #if os(macOS)
            // Zonder expliciete maat sizet macOS z'n `.sheet` naar de
            // "ideale" grootte van de inhoud -- en een `List` met maar één
            // rij meldt daarvoor een heel klein formaat, vandaar het krappe,
            // vreemd zwevende kadertje uit het bugreport. Zelfde patroon als
            // `MacPlayerView`'s "Open Subtitles"-sheet: een expliciete
            // `.frame(minWidth:minHeight:)` + effen achtergrond.
            .frame(minWidth: 480, minHeight: 420)
            .background(VeyraBackground())
            #endif
        #endif
    }

    private var foldersList: some View {
        VeyraList {
            if viewModel.folders.isEmpty {
                Section {
                    Text("Nog geen mappen. Maak een map aan (bv. \"Sport\") en voeg er kanalen uit één of meerdere IPTV-providers aan toe.")
                        .foregroundStyle(.secondary)
                        // Kader is breed, maar lange tekst blijft op een
                        // leesbare regellengte i.p.v. edge-to-edge uitgerekt.
                        .frame(maxWidth: 820, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                #if os(tvOS)
                .listRowBackground(Color.clear)
                #endif
            } else {
                Section {
                    ForEach(viewModel.folders) { folder in
                        NavigationLink {
                            LiveTVFolderChannelsView(folder: folder)
                        } label: {
                            HStack(spacing: 14) {
                                folderLogo(folder)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(folder.title)
                                    Text(folder.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    editingFolder = folder
                                } label: {
                                    Image(systemName: "pencil")
                                        .padding(8)
                                }
                                #if os(tvOS)
                                // Op tvOS geeft de standaard `List`-rij-knop
                                // een witte achtergrond zodra hij focus
                                // krijgt; `VeyraFocusButtonStyle` (dezelfde
                                // stijl als de rest van de app) geeft in
                                // plaats daarvan een subtiele cyaan gloed.
                                .buttonStyle(VeyraFocusButtonStyle())
                                .foregroundStyle(VeyraColors.cyan)
                                #else
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                #endif
                            }
                        }
                        #if os(tvOS)
                        // Zelfde reden als de kanalenlijst binnenin een map
                        // (`LiveTVFolderChannelsView`): zonder eigen stijl
                        // toont de rij bij focus een effen witte achtergrond.
                        // `.liveTVFolderRow()` i.p.v. `.veyraCardRow()`: die
                        // laatste toont ook in rust al een subtiele rand,
                        // wat hier als een dubbel kader oogde.
                        .liveTVFolderRow()
                        #endif
                    }
                    .onDelete { offsets in
                        for index in offsets { viewModel.remove(viewModel.folders[index]) }
                    }
                    .onMove { source, destination in
                        viewModel.move(fromOffsets: source, toOffset: destination)
                    }
                    #if os(tvOS)
                    .listRowBackground(Color.clear)
                    #endif
                } footer: {
                    // Geen `header` meer: "Mijn mappen" staat al als
                    // `.navigationTitle` boven de sheet, een tweede keer
                    // hetzelfde ertussen zag er dubbelop uit.
                    Text("Een map kan kanalen uit meerdere providers bevatten, bv. een 'Sport'-map met kanalen van verschillende aanbieders.")
                        .frame(maxWidth: 820, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                #if os(tvOS)
                .listRowBackground(Color.clear)
                #endif
            }

            Section {
                Button {
                    showAddSheet = true
                } label: {
                    #if os(tvOS)
                    HStack(spacing: 18) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 28, weight: .semibold))
                        Text("Map toevoegen")
                            .font(.system(size: 28, weight: .semibold))
                    }
                    .foregroundStyle(VeyraColors.cyan)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    #else
                    Label("Map toevoegen", systemImage: "folder.badge.plus")
                    #endif
                }
                #if os(tvOS)
                .liveTVFolderRow()
                #endif
            }

            if let errorMessage = viewModel.errorMessage {
                Section { Text(errorMessage).foregroundStyle(.orange) }
            }
        }
        // Geen `.scrollContentBackground(.hidden)` hier: die modifier bestaat niet op tvOS
        // ("'scrollContentBackground' is unavailable in tvOS") -- de lichte/witte achtergrond
        // van List wordt daar al app-breed transparant gemaakt via
        // UITableView/UICollectionView.appearance() in VeyraApp.swift.
    }

    private func folderLogo(_ folder: LiveTVFolder) -> some View {
        VeyraAsyncImage(url: folder.effectiveLogoURL) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFit()
            } else {
                Image(systemName: "folder").foregroundStyle(.secondary)
            }
        }
        .frame(width: 44, height: 30)
    }
}

#Preview {
    NavigationStack { LiveTVFoldersListView() }
}
