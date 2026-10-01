// VeyraCollectionManageItemsView.swift — tvOS
// "Beheer films" (Fase 6, spec §22/§37/§39): films uit een eigen collectie verwijderen en
// handmatig herordenen. Spec §37/§62: GEEN fragiele drag-and-drop op tvOS -- Siri Remote-focus
// moet stabiel blijven -- dus expliciete "verplaats naar links/rechts/begin/einde"-knoppen i.p.v.
// een drag-gesture.

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
        ZStack {
            VeyraHomeStyle.ink.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("BEHEER \(collection?.name.uppercased() ?? "")")
                        .font(.system(size: 20, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(VeyraColors.cyan.opacity(0.85))

                    if isLoading {
                        ProgressView()
                    } else if orderedResolved.isEmpty {
                        Text("Nog geen films in deze collectie.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 14) {
                            ForEach(Array(orderedResolved.enumerated()), id: \.element.id) { index, resolved in
                                row(resolved, index: index, total: orderedResolved.count)
                            }
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        VeyraActionLabel(title: "GEREED", symbol: "checkmark", compact: true)
                    }
                    .buttonStyle(VeyraFocusButtonStyle(primary: true))
                    .padding(.top, 8)
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 36)
            }
        }
        .navigationTitle("Beheer films")
        .task(id: collectionID) { await load() }
    }

    private func load() async {
        guard let collection else { isLoading = false; return }
        isLoading = true
        resolvedItems = await VeyraCollectionMetadataResolver.resolve(collection.items)
        isLoading = false
    }

    @ViewBuilder
    private func row(_ resolved: VeyraResolvedCollectionItem, index: Int, total: Int) -> some View {
        HStack(spacing: 16) {
            AsyncImage(url: resolved.media.posterURL) { phase in
                if case .success(let image) = phase { image.resizable().scaledToFill() }
                else { VeyraColors.surface }
            }
            .frame(width: 70, height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(resolved.media.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                moveButton(symbol: "arrow.left.to.line") { move(resolved, to: 0) }
                    .disabled(index == 0)
                moveButton(symbol: "chevron.left") { move(resolved, to: index - 1) }
                    .disabled(index == 0)
                moveButton(symbol: "chevron.right") { move(resolved, to: index + 1) }
                    .disabled(index == total - 1)
                moveButton(symbol: "arrow.right.to.line") { move(resolved, to: total - 1) }
                    .disabled(index == total - 1)
            }

            Button {
                store.removeItem(resolved.collectionItemID, from: collectionID)
                resolvedItems.removeAll { $0.id == resolved.id }
            } label: {
                VeyraActionLabel(title: "VERWIJDER", symbol: "minus.circle", compact: true)
            }
            .buttonStyle(VeyraFocusButtonStyle())
        }
        .padding(10)
        .background(VeyraColors.surface.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(VeyraFrame.resting, lineWidth: 1.5))
    }

    private func moveButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(VeyraFocusButtonStyle())
    }

    private func move(_ resolved: VeyraResolvedCollectionItem, to destinationIndex: Int) {
        store.moveItem(resolved.collectionItemID, in: collectionID, to: destinationIndex)
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
