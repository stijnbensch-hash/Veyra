// VeyraCreateCollectionSheet.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// "Nieuwe collectie"-flow (spec §11/§12): naam (verplicht), beschrijving (optioneel),
// sortering. Gebruikt bestaande Form-primitives i.p.v. een eigen kale lay-out.
// Dient ook als "Bewerk collectie" (Fase 6, spec §22: hernoem + beschrijving) wanneer
// `editing` meegegeven wordt -- zelfde Form, enkel titel/knoptekst en store.update i.p.v. create.

import SwiftUI

struct VeyraCreateCollectionSheet: View {
    /// Bewerk een bestaande collectie i.p.v. een nieuwe aan te maken (Fase 6).
    var editing: VeyraCollection? = nil
    /// Aangeroepen met de nieuw aangemaakte collectie, bv. om meteen een film toe te voegen
    /// (spec §20: "+ Nieuwe collectie" vanuit "Toevoegen aan collectie").
    var onCreated: ((VeyraCollection) -> Void)? = nil

    @ObservedObject private var store = VeyraCollectionStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var sortMode: VeyraCollectionSortMode

    init(editing: VeyraCollection? = nil, onCreated: ((VeyraCollection) -> Void)? = nil) {
        self.editing = editing
        self.onCreated = onCreated
        _name = State(initialValue: editing?.name ?? "")
        _description = State(initialValue: editing?.collectionDescription ?? "")
        _sortMode = State(initialValue: editing?.sortMode ?? .releaseDate)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var isEditing: Bool { editing != nil }

    // tvOS: Form/List hebben zelf geen donkere achtergrond (app-brede
    // UITableView/UICollectionView.appearance()-fix in VeyraApp.swift maakt ze enkel
    // transparant) -- zonder een eigen `VeyraBackground()` erachter blijft de systeem-
    // standaard (wit) zichtbaar, zoals elders in de Settings-schermen opgelost.
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
        Form {
            Section {
                TextField("Naam", text: $name)
            } header: {
                Text("Naam")
            }

            Section {
                TextField("Beschrijving (optioneel)", text: $description, axis: .vertical)
            } header: {
                Text("Beschrijving")
            }

            Section {
                Picker("Sortering", selection: $sortMode) {
                    Text("Handmatig").tag(VeyraCollectionSortMode.manual)
                    Text("Releasedatum").tag(VeyraCollectionSortMode.releaseDate)
                    Text("Chronologische volgorde").tag(VeyraCollectionSortMode.chronological)
                    Text("Titel").tag(VeyraCollectionSortMode.title)
                    Text("Datum toegevoegd").tag(VeyraCollectionSortMode.dateAdded)
                }
            } header: {
                Text("Sortering")
            }

            // Spec §11: fanart hoeft tijdens creatie niet verplicht gekozen te worden -- alleen
            // zichtbaar in bewerk-modus, zodat de collectie al films kan bevatten voor de picker
            // zinvolle keuzes ("Uit collectie") kan tonen.
            if let editing {
                Section {
                    NavigationLink("Wijzig artwork") {
                        VeyraCollectionArtworkPickerView(collectionID: editing.id)
                    }
                } header: {
                    Text("Artwork")
                }
            }
        }
    }

    var body: some View {
        content
        .navigationTitle(isEditing ? "Bewerk collectie" : "Nieuwe collectie")
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuleren") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Bewaar" : "Maken") { save() }.disabled(trimmedName.isEmpty)
            }
        }
        #else
        .toolbar {
            Button("Annuleren") { dismiss() }
            Button(isEditing ? "Bewaar" : "Maken") { save() }.disabled(trimmedName.isEmpty)
        }
        #endif
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if let editing {
            store.update(editing.id, name: trimmedName, description: .some(trimmedDescription.isEmpty ? nil : trimmedDescription),
                         sortMode: sortMode)
        } else {
            let collection = store.create(name: trimmedName, description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                                          sortMode: sortMode)
            onCreated?(collection)
        }
        dismiss()
    }
}
