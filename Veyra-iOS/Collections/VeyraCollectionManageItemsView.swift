// VeyraCollectionManageItemsView.swift — iOS/iPad/macOS
// "Beheer films" (Fase 6, spec §22/§38/§39): films uit een eigen collectie verwijderen en
// herordenen. Spec §38: op touch devices native drag-and-drop/reorder waar betrouwbaar --
// gebruikt hier gewoon `List.onMove`/`.onDelete`, altijd in edit-mode zodat handvaten meteen
// zichtbaar zijn (geen aparte "Bewerken"-toggle nodig).

import SwiftUI

struct VeyraCollectionManageItemsView: View {
    let collectionID: VeyraCollection.ID

    @ObservedObject private var store = VeyraCollectionStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var resolvedItems: [VeyraResolvedCollectionItem] = []
    @State private var isLoading = true

    private var collection: VeyraCollection? { store.collection(collectionID) }

    private var orderedResolved: [VeyraResolvedCollectionItem] {
        resolvedItems.sorted { $0.manualSortIndex < $1.manualSortIndex }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if orderedResolved.isEmpty {
                Text("Nog geen films in deze collectie.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(orderedResolved) { resolved in
                        row(resolved)
                    }
                    .onDelete(perform: deleteItems)
                    .onMove(perform: moveItems)
                }
                .listStyle(.plain)
            #if os(iOS)
                .environment(\.editMode, .constant(.active))
            #endif
            }
        }
        .navigationTitle("Beheer films")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Gereed") { dismiss() }
            }
        }
        .task(id: collectionID) { await load() }
    }

    private func load() async {
        guard let collection else { isLoading = false; return }
        isLoading = true
        resolvedItems = await VeyraCollectionMetadataResolver.resolve(collection.items)
        isLoading = false
    }

    @ViewBuilder
    private func row(_ resolved: VeyraResolvedCollectionItem) -> some View {
        HStack(spacing: 12) {
            VeyraAsyncImage(url: resolved.media.posterURL) { phase in
                if case .success(let image) = phase { image.resizable().scaledToFill() }
                else { VeyraColors.surface }
            }
            .frame(width: 44, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(resolved.media.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let resolved = orderedResolved[index]
            store.removeItem(resolved.collectionItemID, from: collectionID)
            resolvedItems.removeAll { $0.id == resolved.id }
        }
    }

    private func moveItems(from offsets: IndexSet, to destination: Int) {
        var ordered = orderedResolved
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (newIndex, resolved) in ordered.enumerated() {
            store.moveItem(resolved.collectionItemID, in: collectionID, to: newIndex)
        }
        guard let collection = store.collection(collectionID) else { return }
        for item in collection.items {
            if let i = resolvedItems.firstIndex(where: { $0.collectionItemID == item.id }) {
                resolvedItems[i] = VeyraResolvedCollectionItem(collectionItemID: item.id, manualSortIndex: item.manualSortIndex,
                                                                chronologyIndex: item.chronologyIndex,
                                                                addedAt: item.addedAt, media: resolvedItems[i].media)
            }
        }
    }
}
