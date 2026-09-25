import SwiftUI

struct SourceAppearanceView: View {
    @ObservedObject private var store = SourceBadgeStore.shared

    @State private var packURLText = ""
    @State private var showBuiltInPreview = false
    @State private var showPackPreview = false

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    NavigationLink {
                        SourceOrderView()
                    } label: {
                        VeyraSettingsCardRowLabel(icon: "arrow.up.arrow.down", title: "Bronvolgorde") {
                            EmptyView()
                        }
                    }
                    .veyraCardRow()
                } footer: {
                    Text("Bepaal de volgorde van addons en mediaservers bij \"Selecteer bron\".")
                }

                Section {
                modeRow(icon: "circle.slash", title: "Geen badges", subtitle: "Verberg alle badges", isSelected: store.mode == .off) {
                    store.setMode(.off)
                }

                modeRow(icon: "tag", title: "Ingebouwd", subtitle: "Veyra's standaardbadges", isSelected: store.mode == .builtIn) {
                    store.setMode(.builtIn)
                }

                ForEach(store.packs) { pack in
                    packRow(pack)
                }
            } header: {
                Text("Badges")
            }

            Section {
                inputSection(title: "PAKKET-URL") {
                    HStack(spacing: 16) {
                        TextField("https://voorbeeld.app/badges.json", text: $packURLText)

                        if store.isLoading {
                            ProgressView()
                        } else {
                            Button {
                                addPack()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            .disabled(packURLText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }

                if let error = store.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(VeyraColors.red)
                }
            } footer: {
                Text("Badges verschijnen naast elke bron in het bronkeuzescherm, op basis van trefwoorden in de bronnaam. Een eigen pakket is een JSON-bestand op een URL met een lijst van { match, imageURL of label, color }.")
            }

            Section {
                Button {
                    showBuiltInPreview.toggle()
                } label: {
                    VeyraSettingsCardRowLabel(icon: "eye", title: "Bekijk ingebouwde badges") {
                        Image(systemName: showBuiltInPreview ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .veyraCardRow()

                if showBuiltInPreview {
                    badgePreviewRow(SourceBadgeStore.builtIn)
                }

                if let activePack {
                    Button {
                        showPackPreview.toggle()
                    } label: {
                        VeyraSettingsCardRowLabel(icon: "eye", title: "Bekijk pakketbadges", subtitle: "\(activePack.badges.count) badges") {
                            Image(systemName: showPackPreview ? "chevron.up" : "chevron.down")
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    .veyraCardRow()

                    if showPackPreview {
                        badgePreviewRow(activePack.badges)
                    }
                }
            }
            }
            .frame(maxWidth: 1000)
        }
        .navigationTitle("Bronverschijning")
    }

    // MARK: - Rows

    private var activePack: SourceBadgePack? {
        guard case .pack(let id) = store.mode else { return nil }
        return store.packs.first { $0.id == id }
    }

    private func modeRow(icon: String, title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VeyraSettingsCardRowLabel(icon: icon, title: title, subtitle: subtitle) {
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VeyraColors.cyan)
                    .opacity(isSelected ? 1 : 0)
            }
        }
        .veyraCardRow()
    }

    private func packRow(_ pack: SourceBadgePack) -> some View {
        let isSelected = store.mode == .pack(pack.id)

        return HStack(spacing: 10) {
            Button {
                store.setMode(.pack(pack.id))
            } label: {
                VeyraSettingsCardRowLabel(icon: "link", title: pack.name, subtitle: "\(pack.badges.count) badges") {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(VeyraColors.cyan)
                        .opacity(isSelected ? 1 : 0)
                }
            }
            .veyraCardRow()

            Button {
                store.removePack(pack)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(VeyraColors.red)
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.plain)
        }
    }

    private func badgePreviewRow(_ badges: [SourceBadge]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(badges, id: \.self) { badge in
                    badgeChip(badge)
                }
            }
            .padding(.vertical, 6)
        }
        .listRowBackground(Color.clear)
    }

    /// De pil-achtergrond/rand (`tagColor`/`borderColor`) hoort bij de badge
    /// zelf, niet alleen bij de tekst-terugval — een geladen afbeelding komt
    /// dus ook binnenin dezelfde pil te zitten, net als in het bronpakket
    /// bedoeld is (`tagStyle`: "filled and bordered" / "bordered").
    private func badgeChip(_ badge: SourceBadge) -> some View {
        badgeChipContent(badge)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color(sourceBadgeHex: badge.tagColor) ?? VeyraColors.cyan.opacity(0.6))
            )
            .overlay(
                Capsule().strokeBorder(Color(sourceBadgeHex: badge.borderColor) ?? .clear, lineWidth: 1)
            )
    }

    @ViewBuilder
    private func badgeChipContent(_ badge: SourceBadge) -> some View {
        if let imageURL = badge.imageURL {
            AsyncImage(url: imageURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    chipFallback(badge)
                }
            }
            .frame(height: 20)
        } else {
            chipFallback(badge)
        }
    }

    private func chipFallback(_ badge: SourceBadge) -> some View {
        Text(badge.name)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Color(sourceBadgeHex: badge.textColor) ?? .white)
    }

    // MARK: - Input helper

    @ViewBuilder
    private func inputSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.55))
            content()
        }
    }

    // MARK: - Actions

    private func addPack() {
        let url = packURLText
        packURLText = ""
        Task { await store.addPack(fromURLString: url) }
    }
}

#Preview {
    NavigationStack { SourceAppearanceView() }
}
