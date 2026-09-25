import SwiftUI

struct SourceAppearanceView: View {
    @ObservedObject private var store = SourceBadgeStore.shared

    @State private var packURLText = ""
    @State private var showBuiltInPreview = false
    @State private var showPackPreview = false

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            List {
                Section {
                    NavigationLink {
                        SourceOrderView()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "arrow.up.arrow.down")
                                .frame(width: 22)
                                .foregroundStyle(.white.opacity(0.7))

                            Text("Bronvolgorde")
                                .foregroundStyle(.white)
                        }
                    }
                } footer: {
                    Text("Bepaal de volgorde van addons en mediaservers bij \"Selecteer bron\".")
                }

                Section {
                    modeRow(
                        icon: "circle.slash",
                        title: "Geen badges",
                        trailing: "Verberg alle badges",
                        isSelected: store.mode == .off
                    ) {
                        store.setMode(.off)
                    }

                    modeRow(
                        icon: "tag",
                        title: "Ingebouwd",
                        trailing: "Veyra's standaardbadges",
                        isSelected: store.mode == .builtIn
                    ) {
                        store.setMode(.builtIn)
                    }

                    ForEach(store.packs) { pack in
                        packRow(pack)
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "link")
                            .foregroundStyle(.white.opacity(0.45))

                        TextField("Voeg een pakket-URL toe", text: $packURLText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .foregroundStyle(.white)

                        if store.isLoading {
                            ProgressView()
                        } else {
                            Button {
                                addPack()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(VeyraColors.cyan)
                            }
                            .disabled(packURLText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }

                    if let error = store.lastError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(VeyraColors.red)
                    }

                    Button {
                        showBuiltInPreview.toggle()
                    } label: {
                        HStack {
                            Label("Bekijk ingebouwde badges", systemImage: "eye")
                            Spacer()
                            Image(systemName: showBuiltInPreview ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.white)

                    if showBuiltInPreview {
                        badgePreviewRow(SourceBadgeStore.builtIn)
                    }

                    if let activePack {
                        Button {
                            showPackPreview.toggle()
                        } label: {
                            HStack {
                                Label("Bekijk pakketbadges", systemImage: "eye")
                                Spacer()
                                Text("\(activePack.badges.count)")
                                    .foregroundStyle(.white.opacity(0.45))
                                Image(systemName: showPackPreview ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(.white)

                        if showPackPreview {
                            badgePreviewRow(activePack.badges)
                        }
                    }
                } header: {
                    Text("Badges")
                } footer: {
                    Text("Badges verschijnen naast elke bron in het bronkeuzescherm, op basis van trefwoorden in de bronnaam. Een eigen pakket is een JSON-bestand op een URL, bijvoorbeeld https://voorbeeld.app/badges.json, met een lijst van { match, imageURL of label, color }.")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Bronverschijning")
    }

    // MARK: - Rows

    private var activePack: SourceBadgePack? {
        guard case .pack(let id) = store.mode else { return nil }
        return store.packs.first { $0.id == id }
    }

    private func modeRow(
        icon: String,
        title: String,
        trailing: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .frame(width: 22)
                    .foregroundStyle(.white.opacity(0.7))

                Text(title)
                    .foregroundStyle(.white)

                Spacer()

                Text(trailing)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.45))

                Image(systemName: "checkmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(VeyraColors.cyan)
                    .opacity(isSelected ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
    }

    private func packRow(_ pack: SourceBadgePack) -> some View {
        let isSelected = store.mode == .pack(pack.id)

        return HStack(spacing: 14) {
            Image(systemName: "link")
                .frame(width: 22)
                .foregroundStyle(.white.opacity(0.7))

            Button {
                store.setMode(.pack(pack.id))
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.name)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(pack.badges.count) badges")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Image(systemName: "checkmark")
                .font(.footnote.weight(.bold))
                .foregroundStyle(VeyraColors.cyan)
                .opacity(isSelected ? 1 : 0)

            Button {
                store.removePack(pack)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(VeyraColors.red)
            }
            .buttonStyle(.plain)
        }
    }

    private func badgePreviewRow(_ badges: [SourceBadge]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(badges, id: \.self) { badge in
                    badgeChip(badge)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets())
        .padding(.horizontal, 16)
    }

    /// De pil-achtergrond/rand (`tagColor`/`borderColor`) hoort bij de badge
    /// zelf, niet alleen bij de tekst-terugval — een geladen afbeelding komt
    /// dus ook binnenin dezelfde pil te zitten, net als in het bronpakket
    /// bedoeld is (`tagStyle`: "filled and bordered" / "bordered").
    private func badgeChip(_ badge: SourceBadge) -> some View {
        badgeChipContent(badge)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
            .frame(height: 14)
        } else {
            chipFallback(badge)
        }
    }

    private func chipFallback(_ badge: SourceBadge) -> some View {
        Text(badge.name)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color(sourceBadgeHex: badge.textColor) ?? .white)
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
