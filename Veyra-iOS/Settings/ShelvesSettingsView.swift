import SwiftUI

struct ShelvesSettingsView: View {
    @StateObject private var viewModel = ShelvesViewModel()
    @State private var showAddSheet = false
    @State private var editingShelf: Shelf?

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            List {
                if viewModel.shelves.isEmpty {
                    ContentUnavailableView(
                        "Geen planken",
                        systemImage: "rectangle.grid.1x2",
                        description: Text("Voeg een plank toe met een lijst van Trakt, TMDB of een addon zoals AIOMetadata.")
                    )
                } else {
                    Section {
                        ForEach(viewModel.shelves) { shelf in
                            Button {
                                editingShelf = shelf
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(shelf.title).foregroundStyle(.primary)
                                        Text(shelf.source.detailLabel)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if !shelf.isEnabled {
                                        Text("Uit").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .swipeActions {
                                Button("Verwijderen", role: .destructive) {
                                    viewModel.remove(shelf)
                                }
                            }
                            .contextMenu {
                                if case .mediaServer = shelf.source {
                                    Menu {
                                        ForEach(ShelfItemOrder.allCases) { order in
                                            Button {
                                                var updated = shelf
                                                updated.itemOrder = order
                                                viewModel.update(updated)
                                            } label: {
                                                if shelf.effectiveItemOrder == order {
                                                    Label(order.label, systemImage: "checkmark")
                                                } else {
                                                    Text(order.label)
                                                }
                                            }
                                        }
                                    } label: {
                                        Label("Item-volgorde", systemImage: "arrow.up.arrow.down")
                                    }

                                    Menu {
                                        ForEach(ShelfSortDirection.allCases) { direction in
                                            Button {
                                                var updated = shelf
                                                updated.sortDirection = direction
                                                viewModel.update(updated)
                                            } label: {
                                                if shelf.effectiveSortDirection == direction {
                                                    Label(direction.label, systemImage: "checkmark")
                                                } else {
                                                    Text(direction.label)
                                                }
                                            }
                                        }
                                    } label: {
                                        Label("Richting", systemImage: "arrow.up.and.down.text.horizontal")
                                    }

                                    Divider()
                                }

                                Button {
                                    editingShelf = shelf
                                } label: {
                                    Label("Bewerken", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    viewModel.remove(shelf)
                                } label: {
                                    Label("Verwijderen", systemImage: "trash")
                                }
                            }
                        }
                        .onMove { source, destination in
                            viewModel.move(fromOffsets: source, toOffset: destination)
                        }
                    } header: {
                        Text("Planken")
                    } footer: {
                        Text("Planken verschijnen als rijen op het hoofdmenu, in deze volgorde.")
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
        .navigationTitle("Planken")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                #if os(iOS)
                if !viewModel.shelves.isEmpty { EditButton() }
                #endif
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: viewModel.reload) {
            NavigationStack { ShelfEditView(shelf: nil, viewModel: viewModel) }
        }
        .sheet(item: $editingShelf, onDismiss: viewModel.reload) { shelf in
            NavigationStack { ShelfEditView(shelf: shelf, viewModel: viewModel) }
        }
        .onAppear {
            viewModel.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .veyraShelfConfigurationDidChange)) { _ in
            viewModel.reload()
        }
    }
}

#Preview {
    NavigationStack { ShelvesSettingsView() }
}
