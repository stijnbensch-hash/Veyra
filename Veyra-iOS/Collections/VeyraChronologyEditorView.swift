// VeyraChronologyEditorView.swift — iOS/iPad/macOS
// "Chronologie instellen" (spec §37/§38/§39): native drag-reorder (spec §39: "iPhone/iPad: native
// drag/reorder mag gebruikt worden"), werkt op `chronologyIndex` i.p.v. `manualSortIndex` -- puur
// herordenen, geen verwijderen hier (dat blijft "Beheer films").

import SwiftUI

struct VeyraChronologyEditorView: View {
    let collectionID: VeyraCollection.ID

    @ObservedObject private var store = VeyraCollectionStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var resolvedItems: [VeyraResolvedCollectionItem] = []
    @State private var isLoading = true

    private var collection: VeyraCollection? { store.collection(collectionID) }

    private var orderedResolved: [VeyraResolvedCollectionItem] {
        resolvedItems.sorted { ($0.chronologyIndex ?? $0.manualSortIndex) < ($1.chronologyIndex ?? $1.manualSortIndex) }
    }

    var body: some View {
        VeyraDynamicBackgroundScope {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    VeyraList {
                        Section {
                            Text("Bepaal de verhaalvolgorde van deze collectie -- los van releasedatum.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Section {
                            ForEach(Array(orderedResolved.enumerated()), id: \.element.id) { index, resolved in
                                row(resolved, index: index)
                            }
                            .onMove(perform: moveItems)
                        }
                    }
                    .listStyle(.plain)
                #if os(iOS)
                    .environment(\.editMode, .constant(.active))
                #endif
                }
            }
            .navigationTitle("Chronologie instellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gereed") { dismiss() }
                }
            }
            .task(id: collectionID) { await load() }
        }
    }

    private func load() async {
        guard let collection else { isLoading = false; return }
        isLoading = true
        resolvedItems = await VeyraCollectionMetadataResolver.resolve(collection.items)
        isLoading = false
    }

    @ViewBuilder
    private func row(_ resolved: VeyraResolvedCollectionItem, index: Int) -> some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index + 1))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(VeyraColors.cyan)
                .frame(width: 28, alignment: .leading)

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

    private func moveItems(from offsets: IndexSet, to destination: Int) {
        var ordered = orderedResolved
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (newIndex, resolved) in ordered.enumerated() {
            store.moveChronology(resolved.collectionItemID, in: collectionID, to: newIndex)
        }
        guard let collection = store.collection(collectionID) else { return }
        for item in collection.items {
            if let i = resolvedItems.firstIndex(where: { $0.collectionItemID == item.id }) {
                resolvedItems[i] = VeyraResolvedCollectionItem(collectionItemID: item.id, manualSortIndex: item.manualSortIndex,
                                                                chronologyIndex: item.chronologyIndex, addedAt: item.addedAt,
                                                                media: resolvedItems[i].media)
            }
        }
    }
}
