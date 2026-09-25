import SwiftUI

/// Instellingenscherm om de volgorde van addons/mediaservers in "Selecteer
/// bron" te bepalen — zowel voor "Alle" als voor de losse filterknoppen
/// (die worden uit dezelfde, herschikte lijst afgeleid, zie
/// `SourceSelectionView.applyOriginOrder`).
///
/// Zelfde achtergrond (`VeyraBackground`) en rij-"kaart"-look als
/// `SourceAppearanceView` (via `VeyraSettingsCardRowLabel`), zodat dit
/// scherm niet meer afwijkt van de rest van Instellingen.
struct SourceOrderView: View {
    @State private var order: [String] = []

    @FocusState private var focusedUpID: String?
    @FocusState private var focusedDownID: String?

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    ForEach(order, id: \.self) { name in
                        reorderableRow(name)
                    }
                } header: {
                    Text("Bronvolgorde")
                } footer: {
                    Text("Bepaalt in welke volgorde addons en mediaservers verschijnen bij \"Selecteer bron\" — zowel bij \"Alle\" als bij de losse knoppen. Bronnen via VeyraHub staan hier niet tussen: hun volgorde stel je in op VeyraHub zelf (addons verplaatsen), en die volgorde wordt altijd gevolgd.")
                }
            }
            .frame(maxWidth: 1000)
        }
        .navigationTitle("Bronvolgorde")
        .onAppear(perform: loadOrder)
    }

    // MARK: - Row

    private func reorderableRow(_ name: String) -> some View {
        VeyraSettingsCardRowLabel(icon: "line.3.horizontal", title: name) {
            reorderColumn(name)
        }
        .veyraStaticCardRow()
    }

    private func reorderColumn(_ name: String) -> some View {
        HStack(spacing: 10) {
            reorderButton(
                systemImage: "chevron.up",
                isFocused: focusedUpID == name,
                disabled: order.first == name
            ) {
                move(name, by: -1)
            }
            .focused($focusedUpID, equals: name)

            reorderButton(
                systemImage: "chevron.down",
                isFocused: focusedDownID == name,
                disabled: order.last == name
            ) {
                move(name, by: 1)
            }
            .focused($focusedDownID, equals: name)
        }
    }

    private func reorderButton(
        systemImage: String,
        isFocused: Bool,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(disabled ? .white.opacity(0.2) : (isFocused ? .white : VeyraColors.cyan.opacity(0.85)))
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(
                        isFocused && !disabled
                            ? VeyraColors.cyan.opacity(0.20)
                            : Color.white.opacity(0.06)
                    )
            )
            .overlay(
                Circle()
                    .strokeBorder(
                        isFocused && !disabled ? VeyraColors.cyan : Color.white.opacity(0.12),
                        lineWidth: isFocused && !disabled ? 2 : 1
                    )
            )
            .contentShape(Rectangle())
            .focusable(!disabled)
            .focusEffectDisabled()
            .onTapGesture {
                guard !disabled else { return }
                action()
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
