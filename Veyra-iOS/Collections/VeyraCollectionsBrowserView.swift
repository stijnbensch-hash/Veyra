// VeyraCollectionsBrowserView.swift — iOS/iPad/macOS
// "Jouw Collecties"-browserscherm (Fase 4, spec §6/§7/§71) -- iOS-tegenhanger van
// `Veyra/App/tvOS/Collections/VeyraCollectionsBrowserView.swift`. Geopend vanuit `MoviesView`
// (spec §48). Opent voorlopig een eenvoudige detailweergave -- de volledige Collection Stage/
// Journey komt in Fase 5.

import SwiftUI

struct VeyraCollectionsBrowserView: View {
    @ObservedObject private var store = VeyraCollectionStore.shared
    @State private var fallbackArtwork: [VeyraCollection.ID: URL] = [:]
    @State private var showCreate = false
    @State private var editingCollection: VeyraCollection?
    @State private var managingCollection: VeyraCollection?
    @State private var deletingCollection: VeyraCollection?

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPad: Bool { sizeClass == .regular }
    #else
    private var isPad: Bool { false }
    #endif

    private var columns: [GridItem] {
        isPad
            ? [GridItem(.adaptive(minimum: 210, maximum: 260), spacing: 20)]
            : [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)]
    }

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .firstTextBaseline) {
                        VeyraSectionHeader(title: "Collecties", subtitle: collectionsSubtitle)
                        Spacer()
                        Button {
                            showCreate = true
                        } label: {
                            Label("Nieuwe collectie", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(VeyraColors.cyan)
                    }
                    .padding(.horizontal)

                    VeyraContinueCollectionsSection()
                        .padding(.horizontal)

                    if store.collections.isEmpty {
                        emptyState.padding(.horizontal)
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(store.collections) { collection in
                                NavigationLink {
                                    VeyraCollectionDetailView(source: .own(collection.id))
                                } label: {
                                    VeyraCollectionCard(title: collection.name, subtitle: subtitle(for: collection),
                                                        artworkURL: artworkURL(for: collection),
                                                        artworkPosition: collection.artworkPosition,
                                                        clearLogoURL: VeyraCollectionClearLogoResolver.resolvedURL(for: collection))
                                }
                                .buttonStyle(.plain)
                                .contextMenu { cardContextMenu(collection) }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Collecties")
        .task(id: store.collections) { await loadFallbackArtwork() }
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

    // Spec §22: contextmenu per collectie-kaart (long-press op iOS).
    @ViewBuilder
    private func cardContextMenu(_ collection: VeyraCollection) -> some View {
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

    // Herschikken van "Jouw Collecties" zelf -- long-press contextmenu i.p.v. drag-and-drop
    // (zelfde "verplaats naar links/rechts/begin/einde"-opzet als tvOS, blijft zo consistent
    // tussen platformen en werkt ook met een los grid i.p.v. een List met `.onMove`).
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Maak je eerste collectie")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Bundel films zoals jij ze wilt bekijken.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showCreate = true
            } label: {
                Label("Nieuwe collectie", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(VeyraColors.cyan)
        }
        .padding(.top, 8)
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
