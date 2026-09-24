// VeyraHomeLayoutSettingsView.swift
// Keuze van een preset (eerste start en Instellingen) en het aanpassen van de Home-indeling.

import SwiftUI

/// Getoond bij de eerste start: kies waar Home mee begint.
struct VeyraHomePresetPickerView: View {
    var onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Wat wil je op Home zien?")
                    .font(.largeTitle.bold())
                Text("Kies een start. Je kunt alles altijd aanpassen bij Instellingen > Home.")
                    .foregroundStyle(.secondary)
                ForEach(VeyraHomePreset.all) { preset in
                    Button {
                        VeyraHomeLayoutStore.save(preset.layout)
                        onDone()
                    } label: {
                        HStack(spacing: 20) {
                            Image(systemName: preset.symbol)
                                .font(.title)
                                .frame(width: 56)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.title).font(.title3.bold())
                                Text(preset.detail).font(.callout).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
                Button("Later beslissen") {
                    VeyraHomeLayoutStore.markChosen()
                    onDone()
                }
            }
            .padding(32)
        }
    }
}

/// Instellingen > Home > Indeling.
struct VeyraHomeLayoutSettingsView: View {
    @State private var layout = VeyraHomeLayoutStore.load()

    var body: some View {
        Form {
            Section {
                ForEach(VeyraHomePreset.all) { preset in
                    Button {
                        layout = preset.layout
                        VeyraHomeLayoutStore.save(layout)
                    } label: {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.title)
                                    Text(preset.detail).font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: preset.symbol)
                            }
                            Spacer()
                            if layout.preset == preset.id { Image(systemName: "checkmark").foregroundStyle(VeyraColors.cyan) }
                        }
                    }
                }
            } header: {
                Text("Start met")
            } footer: {
                Text("Een preset zet alle blokken in één keer; daarna pas je ze hieronder aan.")
            }

            Section {
                // Volgorde bepaal je hier rechtstreeks in de lijst (sleepbalkje
                // op iOS via "Bewerken", knoppen op tvOS) i.p.v. in het
                // deelmenu van een los blok. Op tvOS staan de op/neer-knoppen
                // bewust NAAST de NavigationLink (niet erin genest) -- een
                // Button genest in het label van een NavigationLink krijgt op
                // tvOS geen eigen remote-focus.
                ForEach(Array(layout.orderedTiles.enumerated()), id: \.element) { index, tile in
                    HStack {
                        #if !os(iOS)
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                        #endif
                        NavigationLink {
                            VeyraHomeTileEditorView(tile: tile, layout: $layout)
                        } label: {
                            HStack {
                                Label(tile.title, systemImage: tile.symbol)
                                Spacer()
                                Text(layout.isVisible(tile) ? "Aan" : "Uit").foregroundStyle(.secondary)
                            }
                        }
                        #if !os(iOS)
                        VStack(spacing: 6) {
                            Button { moveTile(index, by: -1) } label: {
                                Image(systemName: "chevron.up")
                            }.disabled(index == 0)
                            Button { moveTile(index, by: 1) } label: {
                                Image(systemName: "chevron.down")
                            }.disabled(index >= layout.orderedTiles.count - 1)
                        }
                        .buttonStyle(.plain)
                        #endif
                    }
                }
                .onMove { offsets, destination in
                    layout.move(fromOffsets: offsets, toOffset: destination)
                    persist()
                }
            } header: {
                Text("Blokken op Home (in volgorde)")
            } footer: {
                Text("Blokken zonder inhoud (bijvoorbeeld Live nu zonder IPTV) verschijnen vanzelf niet.")
            }

            Section {
                Toggle("Sport", isOn: Binding(get: { layout.showSport }, set: { layout.showSport = $0; layout.preset = nil; persist() }))
                Toggle("Eigen planken", isOn: Binding(get: { layout.showShelves }, set: { layout.showShelves = $0; layout.preset = nil; persist() }))
            } header: {
                Text("Overig")
            }

            Section {
                Button("Standaardindeling herstellen") {
                    layout = .standard
                    persist()
                }
            }
        }
        .navigationTitle("Indeling")
        #if os(iOS)
        .toolbar { EditButton() }
        #endif
        .onReceive(NotificationCenter.default.publisher(for: .veyraHomeLayoutDidChange)) { _ in
            let fresh = VeyraHomeLayoutStore.load()
            if fresh != layout { layout = fresh }
        }
    }

    private func persist() { VeyraHomeLayoutStore.save(layout) }

    #if !os(iOS)
    private func moveTile(_ index: Int, by offset: Int) {
        let tiles = layout.orderedTiles
        guard tiles.indices.contains(index) else { return }
        layout.move(tiles[index], by: offset)
        persist()
    }
    #endif
}

struct VeyraHomeTileEditorView: View {
    let tile: BentoTile
    @Binding var layout: VeyraHomeLayout

    var body: some View {
        Form {
            Section {
                Toggle("Tonen op Home", isOn: Binding(
                    get: { layout.isVisible(tile) },
                    set: { layout.setVisible($0, tile); VeyraHomeLayoutStore.save(layout) }))
            } footer: {
                Text(tile.detail)
            }
        }
        .navigationTitle(tile.title)
    }
}
