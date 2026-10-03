// VeyraCollectionsBrowserView.swift — tvOS
// "Jouw Collecties"-browserscherm (Fase 4, spec §6/§7/§71): grid van cyaan/rode
// `VeyraCollectionCard`-tegels + een "+ Nieuw"-tegel. Geopend vanuit `MoviesView` (spec §48).
// Opent voorlopig een eenvoudige detailweergave -- de volledige Collection Stage/Journey komt
// in Fase 5; deze view mag daarbij ongewijzigd blijven (enkel `navigationDestination` wijst dan
// naar de rijkere detailview).

import SwiftUI

struct VeyraCollectionsBrowserView: View {
    @ObservedObject private var store = VeyraCollectionStore.shared
    @State private var fallbackArtwork: [VeyraCollection.ID: URL] = [:]
    @State private var selectedCollection: VeyraCollection?
    @State private var showCreate = false
    @State private var editingCollection: VeyraCollection?
    @State private var managingCollection: VeyraCollection?
    @State private var deletingCollection: VeyraCollection?

    private let columns = [GridItem(.adaptive(minimum: 340, maximum: 380), spacing: 32)]

    var body: some View {
        ZStack {
            VeyraHomeStyle.ink.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(alignment: .firstTextBaseline) {
                        VeyraSectionHeader(title: "Collecties", subtitle: collectionsSubtitle, showChevron: false)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer()
                        Button {
                            showCreate = true
                        } label: {
                            VeyraActionLabel(title: "Nieuwe collectie", symbol: "plus", compact: true)
                        }
                        .buttonStyle(VeyraFocusButtonStyle(primary: true))
                    }

                    VeyraContinueCollectionsSection()

                    if store.collections.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 28) {
                            ForEach(store.collections) { collection in
                                Button {
                                    selectedCollection = collection
                                } label: {
                                    VeyraCollectionCard(title: collection.name, subtitle: subtitle(for: collection),
                                                        artworkURL: artworkURL(for: collection),
                                                        artworkPosition: collection.artworkPosition,
                                                        clearLogoURL: VeyraCollectionClearLogoResolver.resolvedURL(for: collection))
                                }
                                // `.plain` alleen schakelt tvOS' standaard witte focus-kaart niet uit --
                                // `VeyraStreamingTileStyle()` (= plain + `.focusEffectDisabled()`) wel,
                                // zodat alleen VeyraCollectionCard's eigen cyaan focus-kader zichtbaar is.
                                .buttonStyle(VeyraStreamingTileStyle())
                                .contextMenu { cardContextMenu(collection) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 40)
            }
        }
        .navigationTitle("")
        .task(id: store.collections) { await loadFallbackArtwork() }
        .navigationDestination(item: $selectedCollection) { collection in
            VeyraCollectionDetailView(source: .own(collection.id))
        }
        .navigationDestination(item: $managingCollection) { collection in
            VeyraCollectionManageItemsView(collectionID: collection.id)
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack { VeyraCreateCollectionSheet() }
        }
        .sheet(item: $editingCollection) { collection in
            NavigationStack { VeyraCreateCollectionSheet(editing: collection) }
        }
        // Spec §23: verwijderen van een eigen collectie vraagt altijd bevestiging; de films
        // zelf blijven gewoon beschikbaar in Veyra.
        .confirmationDialog(
            "Collectie verwijderen?",
            isPresented: Binding(get: { deletingCollection != nil }, set: { if !$0 { deletingCollection = nil } }),
            titleVisibility: .visible
        ) {
            Button("Verwijderen", role: .destructive) {
                if let deletingCollection { store.delete(deletingCollection.id) }
                deletingCollection = nil
            }
            Button("Annuleren", role: .cancel) { deletingCollection = nil }
        } message: {
            Text("\"\(deletingCollection?.name ?? "")\" wordt verwijderd. De films zelf blijven beschikbaar in Veyra.")
        }
    }

    // Spec §22: contextmenu per collectie-kaart.
    @ViewBuilder
    private func cardContextMenu(_ collection: VeyraCollection) -> some View {
        Button {
            selectedCollection = collection
        } label: {
            Label("Open collectie", systemImage: "rectangle.stack")
        }
        Button {
            editingCollection = collection
        } label: {
            Label("Bewerk collectie", systemImage: "pencil")
        }
        Button {
            managingCollection = collection
        } label: {
            Label("Beheer films", systemImage: "list.bullet")
        }
        reorderMenu(collection)
        Divider()
        Button(role: .destructive) {
            deletingCollection = collection
        } label: {
            Label("Verwijder collectie", systemImage: "trash")
        }
    }

    // Herschikken van "Jouw Collecties" zelf -- zelfde opzet als "Beheer films" (spec §37: geen
    // drag-and-drop op tvOS, enkel expliciete verplaats-acties).
    @ViewBuilder
    private func reorderMenu(_ collection: VeyraCollection) -> some View {
        if let index = store.collections.firstIndex(where: { $0.id == collection.id }) {
            let total = store.collections.count
            Menu {
                Button {
                    store.moveCollection(collection.id, to: 0)
                } label: {
                    Label("Naar begin", systemImage: "arrow.left.to.line")
                }
                .disabled(index == 0)
                Button {
                    store.moveCollection(collection.id, to: index - 1)
                } label: {
                    Label("Naar links", systemImage: "chevron.left")
                }
                .disabled(index == 0)
                Button {
                    store.moveCollection(collection.id, to: index + 1)
                } label: {
                    Label("Naar rechts", systemImage: "chevron.right")
                }
                .disabled(index == total - 1)
                Button {
                    store.moveCollection(collection.id, to: total - 1)
                } label: {
                    Label("Naar einde", systemImage: "arrow.right.to.line")
                }
                .disabled(index == total - 1)
            } label: {
                Label("Herschikken", systemImage: "arrow.left.arrow.right")
            }
        }
    }

    private var emptyState: some View {
        // Spec §7: lege staat voor "Jouw Collecties".
        VStack(alignment: .leading, spacing: 14) {
            Text("Maak je eerste collectie")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
            Text("Bundel films zoals jij ze wilt bekijken.")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
            Button {
                showCreate = true
            } label: {
                VeyraActionLabel(title: "NIEUWE COLLECTIE", symbol: "plus.circle.fill", compact: true)
            }
            .buttonStyle(VeyraFocusButtonStyle(primary: true))
        }
        .padding(.top, 20)
    }

    private func subtitle(for collection: VeyraCollection) -> String {
        collection.items.count == 1 ? "1 film" : "\(collection.items.count) films"
    }

    // Spec §7: één artwork-identiteit per collectie -- zelfde resolver als Home/Detail/Continue.
    private func artworkURL(for collection: VeyraCollection) -> URL? {
        VeyraCollectionArtworkResolver.resolvedURL(for: collection, fallback: fallbackArtwork[collection.id])
    }

    private func loadFallbackArtwork() async {
        var result: [VeyraCollection.ID: URL] = [:]
        await withTaskGroup(of: (VeyraCollection.ID, URL?).self) { group in
            for collection in store.collections where collection.artworkReference == nil && !collection.items.isEmpty {
                group.addTask {
                    let resolved = await VeyraCollectionMetadataResolver.resolve(Array(collection.items.prefix(1)))
                    return (collection.id, resolved.first?.media.backdropURL)
                }
            }
            for await (id, url) in group { if let url { result[id] = url } }
        }
        fallbackArtwork = result
    }

    private var collectionsSubtitle: String? {
        guard !store.collections.isEmpty else { return nil }
        return store.collections.count == 1 ? "1 collectie" : "\(store.collections.count) collecties"
    }
}
