// VeyraChronologyEditorView.swift — tvOS
// "Chronologie instellen" (spec §37/§38/§39): de gebruiker bepaalt zelf de verhaal-/universe-
// chronologie van een collectie -- NOOIT automatisch gegokt (spec §36). Zelfde remote-vriendelijke
// verplaats-knoppen als "Beheer films" (`VeyraCollectionManageItemsView`), maar werkt op
// `chronologyIndex` i.p.v. `manualSortIndex`/collection-membership -- puur herordenen, geen
// verwijderen hier.

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
            ZStack {
                VeyraBackground().ignoresSafeArea()
                VeyraScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("CHRONOLOGIE · \(collection?.name.uppercased() ?? "")")
                            .font(.system(size: 20, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(VeyraColors.cyan.opacity(0.85))
                        Text("Bepaal de verhaalvolgorde van deze collectie -- los van releasedatum.")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)

                        if isLoading {
                            ProgressView()
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
            .navigationTitle("Chronologie instellen")
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
    private func row(_ resolved: VeyraResolvedCollectionItem, index: Int, total: Int) -> some View {
        HStack(spacing: 16) {
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(VeyraColors.cyan)
                .frame(width: 44, alignment: .leading)

            VeyraAsyncImage(url: resolved.media.posterURL) { phase in
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
        store.moveChronology(resolved.collectionItemID, in: collectionID, to: destinationIndex)
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
