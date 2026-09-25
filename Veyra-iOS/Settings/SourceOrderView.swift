import SwiftUI

/// Instellingenscherm om de volgorde van addons/mediaservers in "Selecteer
/// bron" te bepalen — zowel voor "Alle" als voor de losse filterknoppen
/// (die worden uit dezelfde, herschikte lijst afgeleid, zie
/// `SourceSelectionViewModel.applyOriginOrder`).
struct SourceOrderView: View {
    @State private var order: [String] = []

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            List {
                Section {
                    ForEach(order, id: \.self) { name in
                        reorderableRow(name)
                    }
                } footer: {
                    Text("Bepaalt in welke volgorde addons en mediaservers verschijnen bij \"Selecteer bron\" — zowel bij \"Alle\" als bij de losse knoppen. Bronnen via VeyraHub staan hier niet tussen: hun volgorde stel je in op VeyraHub zelf (addons verplaatsen), en die volgorde wordt altijd gevolgd.")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Bronvolgorde")
        .onAppear(perform: loadOrder)
    }

    // MARK: - Row

    private func reorderableRow(_ name: String) -> some View {
        HStack(spacing: 10) {
            Text(name)
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 2) {
                Button {
                    move(name, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .disabled(order.first == name)

                Divider().frame(width: 18).overlay(VeyraColors.ice.opacity(0.2))

                Button {
                    move(name, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .disabled(order.last == name)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(VeyraColors.ice)
            .frame(width: 30)
            .background(
                Capsule().fill(VeyraColors.ice.opacity(0.12))
            )
        }
    }

    // MARK: - Order

    private func loadOrder() {
        order = Self.knownOriginNames(savedOrder: SourceOrderDefaults.loadOriginOrder())
    }

    private func move(_ name: String, by offset: Int) {
        guard let index = order.firstIndex(of: name) else { return }
        let destination = index + offset
        guard order.indices.contains(destination) else { return }
        order.swapAt(index, destination)
        SourceOrderDefaults.saveOriginOrder(order)
    }

    /// Combineert de opgeslagen volgorde met alle op dit moment bekende
    /// addon-/mediaservernamen: nieuwe namen (nog niet eerder gezien) komen
    /// achteraan, in ontdekkingsvolgorde; namen die niet meer bestaan (bv.
    /// een verwijderde addon) vallen weg.
    static func knownOriginNames(savedOrder: [String]) -> [String] {
        let addonNames = AddonRegistry().streamProviderNames()
        let mediaServerNames = MediaServerStore().load()
            .filter { $0.kind == .jellyfin }
            .map(\.name)

        var available: [String] = []
        var availableSeen = Set<String>()
        for name in addonNames + mediaServerNames {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !availableSeen.contains(key) else { continue }
            availableSeen.insert(key)
            available.append(trimmed)
        }

        var ordered: [String] = []
        var orderedSeen = Set<String>()
        for name in savedOrder {
            let key = name.lowercased()
            guard availableSeen.contains(key), !orderedSeen.contains(key) else { continue }
            guard let match = available.first(where: { $0.lowercased() == key }) else { continue }
            orderedSeen.insert(key)
            ordered.append(match)
        }

        for name in available {
            let key = name.lowercased()
            guard !orderedSeen.contains(key) else { continue }
            orderedSeen.insert(key)
            ordered.append(name)
        }

        return ordered
    }
}

#Preview {
    NavigationStack { SourceOrderView() }
}
