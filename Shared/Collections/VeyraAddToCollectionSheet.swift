// VeyraAddToCollectionSheet.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// "Toevoegen aan collectie" (spec §18/§19/§20): lijst van bestaande collecties met vinkjes voor
// waar `item` al in zit (een film mag in meerdere collecties tegelijk zitten, spec §19), plus
// "+ Nieuwe collectie" om er ter plekke een te maken en het huidige item meteen toe te voegen
// (spec §20) -- zonder volledige navigation-reset: dit is een sheet, geen nieuwe schermstack.
// Zelfde Form/Section/ForEach-skelet als VeyraStreamingProviderPickerView
// (VeyraStreamingSettingsView.swift), maar met checkmarks i.p.v. plus-iconen omdat lidmaatschap
// hier aan/uit kan staan i.p.v. een eenmalige toevoeg-actie.

import SwiftUI

struct VeyraAddToCollectionSheet: View {
    let item: MediaItem

    @ObservedObject private var store = VeyraCollectionStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showCreate = false
    @State private var newName = ""

    // tvOS: zie VeyraCreateCollectionSheet.swift -- Form krijgt daar geen eigen donkere
    // achtergrond, dus zonder `VeyraBackground()` erachter blijft de systeem-standaard (wit)
    // zichtbaar.
    @ViewBuilder
    private var content: some View {
        #if os(tvOS)
        ZStack {
            VeyraBackground().ignoresSafeArea()
            form
        }
        #else
        form
        #endif
    }

    private var form: some View {
        VeyraForm {
            Section {
                if store.collections.isEmpty {
                    Text("Nog geen collecties.").foregroundStyle(.secondary)
                }
                ForEach(store.collections) { collection in
                    row(collection)
                }
            } header: {
                Text("Jouw collecties")
            } footer: {
                Text("\(item.title) kan in meerdere collecties tegelijk staan.")
            }

            Section {
                if showCreate {
                    TextField("Naam", text: $newName)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                    Button("Maken en toevoegen") { createAndAdd() }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                } else {
                    Button("+ Nieuwe collectie") { showCreate = true }
                }
            }
        }
    }

    var body: some View {
        VeyraDynamicBackgroundScope {
            content
            .navigationTitle("Toevoegen aan collectie")
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Gereed") { dismiss() } }
            }
            #else
            .toolbar {
                Button("Gereed") { dismiss() }
            }
            #endif
        }
    }

    private func row(_ collection: VeyraCollection) -> some View {
        let included = store.isItem(item, in: collection.id)
        return Button {
            toggle(collection, included: included)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: included ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(included ? VeyraColors.cyan : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.name)
                    Text(collection.items.count == 1 ? "1 film" : "\(collection.items.count) films")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        #if os(iOS)
        .buttonStyle(.plain)
        #endif
    }

    private func toggle(_ collection: VeyraCollection, included: Bool) {
        if included {
            if let itemID = collection.items.first(where: { $0.matches(item) })?.id {
                store.removeItem(itemID, from: collection.id)
            }
        } else {
            store.addItem(item, to: collection.id)
        }
    }

    private func createAndAdd() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let collection = store.create(name: name)
        store.addItem(item, to: collection.id)
        newName = ""
        showCreate = false
    }
}
