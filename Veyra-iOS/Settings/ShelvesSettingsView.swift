import SwiftUI

struct ShelvesSettingsView: View {
    @StateObject private var viewModel = ShelvesViewModel()
    @State private var showAddSheet = false
    @State private var editingShelf: Shelf?

    // Hero-instellingen (featured banner bovenaan Home). Zie
    // `Shared/Shelves/HeroSettings.swift`.
    @State private var heroStyle: HeroStyle = .fullScreen
    @State private var heroPrimarySource: HeroSourceSelection = .defaultPrimary
    @State private var heroSecondarySource: HeroSourceSelection = .defaultSecondary

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            List {
                Section {
                    Picker("Stijl", selection: $heroStyle) {
                        ForEach(HeroStyle.allCases) { style in
                            Text(style.label).tag(style)
                        }
                    }

                    NavigationLink {
                        HeroSourcePickerView(title: "Primaire bron", selection: $heroPrimarySource)
                    } label: {
                        HStack {
                            Text("Primaire bron")
                            Spacer()
                            Text(heroPrimarySource.label).foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        HeroSourcePickerView(title: "Secundaire bron", selection: $heroSecondarySource)
                    } label: {
                        HStack {
                            Text("Secundaire bron")
                            Spacer()
                            Text(heroSecondarySource.label).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Hero")
                } footer: {
                    Text(heroStyle.description)
                }

                if viewModel.shelves.isEmpty {
                    ContentUnavailableView(
                        "Geen planken",
                        systemImage: "rectangle.grid.1x2",
                        description: Text("Voeg een plank toe met een lijst van Trakt, TMDB of een addon zoals AIOMetadata.")
                    )
                } else {
                    Section {
                        ForEach(viewModel.shelves) { shelf in
                            Button {
                                editingShelf = shelf
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(shelf.title).foregroundStyle(.primary)
                                        Text("\(shelf.source.subtitle) · \(shelf.source.kind.label)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if !shelf.isEnabled {
                                        Text("Uit").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .swipeActions {
                                Button("Verwijderen", role: .destructive) {
                                    viewModel.remove(shelf)
                                }
                            }
                        }
                        .onMove { source, destination in
                            viewModel.move(fromOffsets: source, toOffset: destination)
                        }
                    } header: {
                        Text("Planken")
                    } footer: {
                        Text("Planken verschijnen als rijen op het hoofdmenu, in deze volgorde.")
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Planken")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                if !viewModel.shelves.isEmpty { EditButton() }
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: viewModel.reload) {
            NavigationStack { ShelfEditView(shelf: nil, viewModel: viewModel) }
        }
        .sheet(item: $editingShelf, onDismiss: viewModel.reload) { shelf in
            NavigationStack { ShelfEditView(shelf: shelf, viewModel: viewModel) }
        }
        .onAppear {
            viewModel.reload()
            heroStyle = HeroSettingsStore.loadStyle()
            heroPrimarySource = HeroSettingsStore.loadPrimarySource()
            heroSecondarySource = HeroSettingsStore.loadSecondarySource()
        }
        .onReceive(NotificationCenter.default.publisher(for: .veyraShelfConfigurationDidChange)) { _ in
            viewModel.reload()
            // Ook nodig na een iCloud-sync-pull (CloudSettingsSync) op een
            // ander apparaat, die dezelfde notificatie post.
            heroStyle = HeroSettingsStore.loadStyle()
            heroPrimarySource = HeroSettingsStore.loadPrimarySource()
            heroSecondarySource = HeroSettingsStore.loadSecondarySource()
        }
        .onChange(of: heroStyle) { _, newValue in
            HeroSettingsStore.saveStyle(newValue)
            NotificationCenter.default.post(name: .veyraShelfConfigurationDidChange, object: nil)
        }
        .onChange(of: heroPrimarySource) { _, newValue in
            HeroSettingsStore.savePrimarySource(newValue)
            NotificationCenter.default.post(name: .veyraShelfConfigurationDidChange, object: nil)
        }
        .onChange(of: heroSecondarySource) { _, newValue in
            HeroSettingsStore.saveSecondarySource(newValue)
            NotificationCenter.default.post(name: .veyraShelfConfigurationDidChange, object: nil)
        }
    }
}

#Preview {
    NavigationStack { ShelvesSettingsView() }
}
