import SwiftUI

struct ShelvesSettingsView: View {
    @StateObject private var viewModel = ShelvesViewModel()
    @State private var showAddSheet = false
    @State private var editingShelf: Shelf?
    // Los "submenu" met snelinstellingen per plank (momenteel enkel
    // item-volgorde/richting voor mediaserver-planken) -- zonder eerst het
    // hele "Wijzig plank"-scherm te moeten openen.
    @State private var quickSettingsShelf: Shelf?

    var body: some View {
        Form {
            if viewModel.shelves.isEmpty {
                Section {
                    Text("Nog geen planken. Voeg een plank toe met een lijst van Trakt, TMDB of een addon zoals AIOMetadata.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    // Volgorde bepaal je hier rechtstreeks in de lijst met deze
                    // knoppen, i.p.v. in een apart scherm. De knoppen staan
                    // bewust NAAST de plank-knop (niet erin genest) -- een
                    // Button genest in het label van een andere Button krijgt
                    // op tvOS geen eigen remote-focus.
                    ForEach(Array(viewModel.shelves.enumerated()), id: \.element.id) { index, shelf in
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)
                            Button {
                                editingShelf = shelf
                            } label: {
                                VeyraSettingsCardRowLabel(
                                    icon: "rectangle.grid.1x2",
                                    title: shelf.title,
                                    subtitle: shelf.source.detailLabel
                                ) {
                                    VeyraSettingsCardRowValue(value: shelf.isEnabled ? "Aan" : "Uit")
                                }
                            }
                            VStack(spacing: 6) {
                                Button { moveShelf(index, by: -1) } label: {
                                    Image(systemName: "chevron.up")
                                }.disabled(index == 0)
                                Button { moveShelf(index, by: 1) } label: {
                                    Image(systemName: "chevron.down")
                                }.disabled(index >= viewModel.shelves.count - 1)
                            }
                            .buttonStyle(.plain)

                            if case .mediaServer = shelf.source {
                                Button { quickSettingsShelf = shelf } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .veyraCardRow()
                    }
                } header: {
                    Text("Planken")
                } footer: {
                    Text("Planken verschijnen als rijen op het hoofdmenu, in deze volgorde.")
                }
            }

            Section {
                Button {
                    showAddSheet = true
                } label: {
                    VeyraSettingsCardRowLabel(icon: "plus.circle", title: "Plank toevoegen")
                }
                .veyraCardRow()
            }

            if let errorMessage = viewModel.errorMessage {
                Section { Text(errorMessage).foregroundStyle(.orange) }
            }
        }
        .frame(maxWidth: 1000)
        .navigationTitle("Planken")
        .sheet(isPresented: $showAddSheet, onDismiss: viewModel.reload) {
            NavigationStack { ShelfEditView(shelf: nil, viewModel: viewModel) }
        }
        .sheet(item: $editingShelf, onDismiss: viewModel.reload) { shelf in
            NavigationStack { ShelfEditView(shelf: shelf, viewModel: viewModel) }
        }
        .onAppear(perform: viewModel.reload)
        .onReceive(NotificationCenter.default.publisher(for: .veyraShelfConfigurationDidChange)) { _ in viewModel.reload() }
        .confirmationDialog(
            quickSettingsShelf?.title ?? "Plankinstellingen",
            isPresented: Binding(
                get: { quickSettingsShelf != nil },
                set: { if !$0 { quickSettingsShelf = nil } }
            ),
            titleVisibility: .visible
        ) {
            quickSettingsDialogButtons
        }
    }

    @ViewBuilder
    private var quickSettingsDialogButtons: some View {
        if let shelf = quickSettingsShelf {
            ForEach(ShelfItemOrder.allCases) { order in
                Button(order.label + (shelf.effectiveItemOrder == order ? " ✓" : "")) {
                    var updated = shelf
                    updated.itemOrder = order
                    viewModel.update(updated)
                    quickSettingsShelf = viewModel.shelves.first { $0.id == shelf.id }
                }
            }
            ForEach(ShelfSortDirection.allCases) { direction in
                Button(direction.label + (shelf.effectiveSortDirection == direction ? " ✓" : "")) {
                    var updated = shelf
                    updated.sortDirection = direction
                    viewModel.update(updated)
                    quickSettingsShelf = viewModel.shelves.first { $0.id == shelf.id }
                }
            }
        }
        Button("Sluiten", role: .cancel) {}
    }

    private func moveShelf(_ index: Int, by offset: Int) {
        let target = index + offset
        guard viewModel.shelves.indices.contains(index), viewModel.shelves.indices.contains(target) else { return }
        let destination = offset < 0 ? target : target + 1
        viewModel.move(fromOffsets: IndexSet(integer: index), toOffset: destination)
    }
}

#Preview {
    NavigationStack { ShelvesSettingsView() }
}
