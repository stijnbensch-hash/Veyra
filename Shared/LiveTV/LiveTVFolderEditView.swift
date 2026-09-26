import SwiftUI

/// Aanmaken/bewerken van een eigen Live TV-map (`LiveTVFolder`) -- kanalen
/// uit één of meerdere IPTV-providers samen in een map zetten (bv.
/// "Sport"), met een eigen naam en logo. Werkt op tvOS, iOS en macOS: dit
/// scherm gebruikt alleen platformonafhankelijke SwiftUI-onderdelen (net
/// als `ShelfIPTVChannelPickerView`), in tegenstelling tot de Planken-editor
/// die per platform een eigen, uitgebreider gestileerde versie heeft.
struct LiveTVFolderEditView: View {
    @Environment(\.dismiss) private var dismiss

    let folder: LiveTVFolder?
    let viewModel: LiveTVFoldersViewModel

    @State private var title = ""
    @State private var channels: [ShelfIPTVChannel] = []
    @State private var errorMessage: String?
    @State private var hasLoadedExisting = false

    /// Voor een nieuwe map al vast een id kiezen (i.p.v. pas bij het
    /// opslaan) -- zo kan het logo, dat via `ChannelLogoOverrideStore`
    /// wordt opgeslagen onder een sleutel gebaseerd op dit id, meteen
    /// gekozen worden vóór de eerste keer opslaan.
    @State private var workingID: UUID

    init(folder: LiveTVFolder?, viewModel: LiveTVFoldersViewModel) {
        self.folder = folder
        self.viewModel = viewModel
        _workingID = State(initialValue: folder?.id ?? UUID())
    }

    private var logoOverrideKey: String { "folder:\(workingID.uuidString)" }

    var body: some View {
        platformBody
            .navigationTitle(folder == nil ? "Map toevoegen" : "Map bewerken")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleren") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Opslaan") { save() } }
            }
            .onAppear(perform: setupFromExisting)
    }

    // Zelfde reden/patroon als `LiveTVFoldersListView`: op tvOS wordt dit
    // scherm als `.sheet` getoond, en een kaal `Form` laat die sheet klein
    // blijven. Pas een schermvullende `VeyraBackground` in een `ZStack`
    // (zoals `ChannelLogoPickerView`/`SourceOrderView`) laat de sheet zich
    // naar een groot formaat voegen; de `Form` krijgt daarbinnen een
    // `.frame(maxWidth:)` om leesbaar te blijven i.p.v. eindeloos breed.
    @ViewBuilder
    private var platformBody: some View {
        #if os(tvOS)
        ZStack {
            VeyraBackground().ignoresSafeArea()
            form
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
        form
        #endif
    }

    private var form: some View {
        Form {
            Section("Naam") {
                TextField("bv. Sport", text: $title)
            }

            Section {
                NavigationLink {
                    ShelfIPTVChannelPickerView(selectedChannels: $channels)
                } label: {
                    HStack {
                        Text("Kanalen kiezen")
                        Spacer()
                        Text(channels.isEmpty ? "Geen" : "\(channels.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                if !channels.isEmpty {
                    let providerCount = Set(channels.map(\.providerName)).count
                    if providerCount > 1 {
                        Text("Kanalen uit \(providerCount) providers.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Kies zelf welke kanalen in deze map moeten staan -- uit één of meerdere IPTV-providers.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Kanalen")
            }

            Section {
                NavigationLink {
                    ChannelLogoPickerView(
                        channelID: logoOverrideKey,
                        channelName: title.isEmpty ? "Map" : title,
                        currentOverrideURL: ChannelLogoOverrideStore.logoURL(forChannelID: logoOverrideKey),
                        currentNameOverride: nil
                    )
                } label: {
                    HStack {
                        Text("Logo kiezen")
                        Spacer()
                        logoPreview
                    }
                }
            } header: {
                Text("Logo")
            } footer: {
                Text("Optioneel -- zonder eigen logo wordt het logo van het eerste kanaal in de map getoond.")
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.orange) }
            }

            if folder != nil {
                Section {
                    Button(role: .destructive) {
                        if let folder { viewModel.remove(folder) }
                        dismiss()
                    } label: {
                        Text("Map verwijderen")
                            #if os(tvOS)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            #endif
                    }
                    #if os(tvOS)
                    .liveTVFolderRow()
                    .foregroundStyle(VeyraColors.red)
                    #endif
                }
            }
        }
        // Geen `.scrollContentBackground(.hidden)` hier: die modifier bestaat niet op tvOS
        // (bouwfout "'scrollContentBackground' is unavailable in tvOS") -- de lichte/witte
        // achtergrond van Form/List wordt daar al app-breed transparant gemaakt via
        // UITableView/UICollectionView.appearance() in VeyraApp.swift.
    }

    private var logoPreview: some View {
        AsyncImage(url: ChannelLogoOverrideStore.logoURL(forChannelID: logoOverrideKey) ?? channels.first?.logoURL) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFit()
            } else {
                Image(systemName: "tv").foregroundStyle(.secondary)
            }
        }
        .frame(width: 60, height: 40)
    }

    private func setupFromExisting() {
        // Zonder deze wacht zette elke terugkeer naar dit scherm (bv. na
        // het pushen naar "Kanalen kiezen" en weer terugkomen) `channels`
        // via een nieuwe `.onAppear` terug naar de oorspronkelijk
        // opgeslagen map -- waardoor een net toegevoegd tweede kanaal meteen
        // weer verdween en een map dus nooit meer dan 1 kanaal leek te
        // kunnen bevatten.
        guard !hasLoadedExisting else { return }
        hasLoadedExisting = true

        guard let folder else { return }
        title = folder.title
        channels = folder.channels
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Geef deze map een naam."
            return
        }
        guard !channels.isEmpty else {
            errorMessage = "Kies minstens één kanaal."
            return
        }

        let updated = LiveTVFolder(id: workingID, title: trimmedTitle, channels: channels)
        if folder != nil {
            viewModel.update(updated)
        } else {
            viewModel.add(updated)
        }
        dismiss()
    }
}

/// Lichte focusstijl voor de rijen in de Live TV-mappen. De stijl staat bij
/// de editor zodat alle doelen die de editor compileren deze ook zien.
struct LiveTVFolderRowButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 18

    @Environment(\.isFocused) private var focused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(focused ? VeyraColors.cyan.opacity(0.16) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        focused
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [VeyraColors.ice, VeyraColors.cyan, VeyraColors.red.opacity(0.70)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            : AnyShapeStyle(Color.clear),
                        lineWidth: focused ? 2 : 0
                    )
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

extension View {
    func liveTVFolderRow() -> some View {
        self
            .buttonStyle(LiveTVFolderRowButtonStyle())
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowBackground(Color.clear)
    }
}
