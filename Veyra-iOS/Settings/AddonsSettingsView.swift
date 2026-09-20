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

    @State private var name = ""
    @State private var kind: AddonKind = .aioStreams
    @State private var baseURLString = ""
    @State private var isEnabled = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            Form {
            Section {
                TextField("Naam", text: $name)
                    .textInputAutocapitalization(.words)

                Picker("Type", selection: $kind) {
                    Text("AIOStreams").tag(AddonKind.aioStreams)
                    Text("Torrent").tag(AddonKind.torrent)
                    Text("AIOMetadata").tag(AddonKind.aioMetadata)
                }

                TextField("https://addon.example.com", text: $baseURLString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                Toggle("Ingeschakeld", isOn: $isEnabled)
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
                Button("Opslaan") { save() }
            }
        }
        .onAppear {
            guard let addon else { return }
            name = addon.name
            kind = addon.kind
            baseURLString = addon.baseURL.absoluteString
            isEnabled = addon.isEnabled
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "Geef deze addon een naam."
            return
        }

        guard let url = URL(string: trimmedURL), url.scheme != nil, url.host != nil else {
            errorMessage = "Voer een geldige addon-URL in."
            return
        }

        do {
            if let existing = addon {
                try viewModel.update(
                    AddonManifest(id: existing.id, name: trimmedName, kind: kind, baseURL: url, isEnabled: isEnabled)
                )
            } else {
                try viewModel.add(
                    AddonManifest(name: trimmedName, kind: kind, baseURL: url, isEnabled: isEnabled)
                )
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { AddonsSettingsView() }
}
