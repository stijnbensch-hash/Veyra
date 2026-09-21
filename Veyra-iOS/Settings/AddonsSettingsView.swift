import SwiftUI

struct AddonsSettingsView: View {
    @StateObject private var viewModel = AddonsViewModel()
    @State private var showAddSheet = false
    @State private var editingAddon: AddonManifest?

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            List {
            if viewModel.addons.isEmpty {
                ContentUnavailableView(
                    "Geen addons",
                    systemImage: "puzzlepiece.extension",
                    description: Text("Voeg een AIOStreams- of torrent-addon toe.")
                )
            } else {
                Section {
                    ForEach(viewModel.addons) { addon in
                        Button {
                            editingAddon = addon
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(addon.name).foregroundStyle(.primary)
                                    Text(viewModel.subtitle(for: addon))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if !addon.isEnabled {
                                    Text("Uit").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions {
                            Button("Verwijderen", role: .destructive) {
                                viewModel.remove(addon)
                            }
                        }
                    }
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
        .navigationTitle("Addons")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: viewModel.reload) {
            NavigationStack { AddonEditView(addon: nil, viewModel: viewModel) }
        }
        .sheet(item: $editingAddon, onDismiss: viewModel.reload) { addon in
            NavigationStack { AddonEditView(addon: addon, viewModel: viewModel) }
        }
        .onAppear(perform: viewModel.reload)
        .onReceive(NotificationCenter.default.publisher(for: .veyraAddonConfigurationDidChange)) { _ in viewModel.reload() }
    }
}

private struct AddonEditView: View {
    @Environment(\.dismiss) private var dismiss

    let addon: AddonManifest?
    let viewModel: AddonsViewModel

    // Geen "Type"-keuze meer: elke Stremio-compatibele addon (AIOStreams,
    // AIOMetadata, ...) beschrijft zelf via zijn manifest.json wat voor
    // addon hij is — zie Shared/Addons/StremioManifestFetcher.swift. De
    // naam wordt automatisch overgenomen uit het manifest; het veld hier
    // blijft enkel voor wie zelf een andere naam wil gebruiken.
    @State private var name = ""
    @State private var baseURLString = ""
    @State private var isEnabled = true
    @State private var errorMessage: String?
    @State private var isFetchingManifest = false
    @State private var manifestNamePlaceholder = ""

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            Form {
            Section {
                TextField(
                    manifestNamePlaceholder.isEmpty ? "Naam (optioneel)" : manifestNamePlaceholder,
                    text: $name
                )
                .textInputAutocapitalization(.words)

                TextField("https://addon.example.com/manifest.json", text: $baseURLString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                Toggle("Ingeschakeld", isOn: $isEnabled)
            } footer: {
                Text("Plak de manifest-URL van de addon. Naam en type (streaming of metadata) worden automatisch uit het manifest gehaald.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(addon == nil ? "Addon toevoegen" : "Addon bewerken")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuleren") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isFetchingManifest {
                    ProgressView()
                } else {
                    Button("Opslaan") { Task { await save() } }
                }
            }
        }
        .onAppear {
            guard let addon else { return }
            name = addon.name
            baseURLString = addon.baseURL.absoluteString
            isEnabled = addon.isEnabled
        }
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmedURL), url.scheme != nil, url.host != nil else {
            errorMessage = "Voer een geldige addon-URL in."
            return
        }

        isFetchingManifest = true
        errorMessage = nil

        let kind: AddonKind
        var finalName = trimmedName

        do {
            let manifest = try await StremioManifestFetcher.fetch(from: url)
            kind = manifest.kind
            manifestNamePlaceholder = manifest.name
            if finalName.isEmpty {
                finalName = manifest.name
            }
        } catch {
            isFetchingManifest = false
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Kon het manifest niet ophalen."
            return
        }

        guard !finalName.isEmpty else {
            isFetchingManifest = false
            errorMessage = "Kon geen naam uit het manifest halen — vul zelf een naam in."
            return
        }

        do {
            if let existing = addon {
                try viewModel.update(
                    AddonManifest(id: existing.id, name: finalName, kind: kind, baseURL: url, isEnabled: isEnabled)
                )
            } else {
                try viewModel.add(
                    AddonManifest(name: finalName, kind: kind, baseURL: url, isEnabled: isEnabled)
                )
            }

            isFetchingManifest = false
            dismiss()
        } catch {
            isFetchingManifest = false
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { AddonsSettingsView() }
}
