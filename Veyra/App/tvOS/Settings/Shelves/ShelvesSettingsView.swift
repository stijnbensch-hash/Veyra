import SwiftUI

struct ShelvesSettingsView: View {
    @StateObject private var viewModel = ShelvesViewModel()
    @State private var showAddSheet = false
    @State private var editingShelf: Shelf?

    var body: some View {
        Form {
            if viewModel.shelves.isEmpty {
                Section {
                    Text("Nog geen planken. Voeg een plank toe met een lijst van Trakt, TMDB of een addon zoals AIOMetadata.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(viewModel.shelves) { shelf in
                        Button {
                            editingShelf = shelf
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(shelf.title)
                                    Text("\(shelf.source.subtitle) · \(shelf.source.kind.label)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(shelf.isEnabled ? "Aan" : "Uit")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Planken")
                } footer: {
                    Text("Planken verschijnen als rijen op het hoofdmenu, in de volgorde waarin je ze toevoegt.")
                }
            }

            Section {
                Button("Plank toevoegen") { showAddSheet = true }
            }

            if let errorMessage = viewModel.errorMessage {
                Section { Text(errorMessage).foregroundStyle(.orange) }
            }
        }
        .navigationTitle("Planken")
        .sheet(isPresented: $showAddSheet, onDismiss: viewModel.reload) {
            NavigationStack { ShelfEditView(shelf: nil, viewModel: viewModel) }
        }
        .sheet(item: $editingShelf, onDismiss: viewModel.reload) { shelf in
            NavigationStack { ShelfEditView(shelf: shelf, viewModel: viewModel) }
        }
        .onAppear(perform: viewModel.reload)
        .onReceive(NotificationCenter.default.publisher(for: .veyraShelfConfigurationDidChange)) { _ in viewModel.reload() }
    }
}

#Preview {
    NavigationStack { ShelvesSettingsView() }
}
