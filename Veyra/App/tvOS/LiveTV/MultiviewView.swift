// MultiviewView.swift — tvOS
// Grid van 2-4 gelijktijdige live-streams, gestart vanuit "Live TV" (zie multiviewButton in
// LiveTVView.swift). Elk vak heeft zijn eigen PlaybackViewModel (MultiviewController); enkel het
// geselecteerde vak heeft geluid. Select op een vak maakt het actief (geluid), de contextmenu-
// optie "Zender wijzigen…" opent dezelfde gidspaneel als bij een afspeelfout (LivePlayerChannelPanel).
//
// Dempen: AetherEngine heeft zelf geen mute/volume-API (bevestigd via docs/api.md) -- dit gebruikt
// `engine.currentAVPlayer?.isMuted`, wat enkel werkt op de native/loopback-afspeelroute. Live-
// kanalen die op tvOS/macOS via de software-decodeerroute lopen (ruwe .ts-streams, geen .m3u8 --
// zie AetherPlaybackEngine.makeLoadOptions) hebben geen `currentAVPlayer` en kunnen dus niet
// individueel gedempt worden; dat is een grens van de engine, geen bug hier.

import SwiftUI
import AetherEngine

struct MultiviewView: View {
    @ObservedObject var guide: VeyraEPGStore
    @StateObject private var controller = MultiviewController()
    @State private var slotCount = 4
    @State private var pickerSlotIndex: Int?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VeyraDynamicBackgroundScope {
            ZStack {
                VeyraPlainBackground().ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {
                    header
                    grid
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 60)
                .padding(.top, 40)
                .padding(.bottom, 40)

                if let pickerSlotIndex {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    LivePlayerChannelPanel(
                        guide: guide,
                        currentSource: nil,
                        initialFilter: .favorites,
                        onSelect: { row in
                            controller.setChannel(row, in: pickerSlotIndex, guide: guide)
                            self.pickerSlotIndex = nil
                        },
                        onClose: { self.pickerSlotIndex = nil }
                    )
                    .focusSection()
                    .onExitCommand { self.pickerSlotIndex = nil }
                }
            }
            .onAppear { start() }
            .onDisappear { controller.stopAll() }
            .onChange(of: slotCount) { _, _ in start() }

        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("MULTIVIEW")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(VeyraColors.cyan)
                Text("Meerdere zenders tegelijk")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
            }

            Spacer()

            ForEach([2, 3, 4], id: \.self) { count in
                Button {
                    slotCount = count
                } label: {
                    Text("\(count)")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 56, height: 48)
                }
                .buttonStyle(VeyraEPGButtonStyle())
                .foregroundStyle(slotCount == count ? VeyraColors.cyan : .white)
            }

            Button("Sluiten") { dismiss() }
                .buttonStyle(VeyraEPGButtonStyle())
        }
    }

    @ViewBuilder
    private var grid: some View {
        switch controller.slots.count {
        case 2:
            HStack(spacing: 20) {
                tile(0)
                tile(1)
            }
        case 3:
            HStack(spacing: 20) {
                tile(0)
                VStack(spacing: 20) {
                    tile(1)
                    tile(2)
                }
            }
        default:
            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    tile(0)
                    tile(1)
                }
                HStack(spacing: 20) {
                    tile(2)
                    tile(3)
                }
            }
        }
    }

    @ViewBuilder
    private func tile(_ index: Int) -> some View {
        if controller.slots.indices.contains(index) {
            MultiviewTileView(
                slot: controller.slots[index],
                isActive: controller.activeIndex == index,
                onSelect: { controller.setActive(index) },
                onChangeChannel: { pickerSlotIndex = index }
            )
        } else {
            Color.clear
        }
    }

    private func start() {
        controller.configure(count: slotCount, favorites: guide.favoriteRows, guide: guide)
    }
}

/// Eén vak: eigen video-oppervlak + naamlabel + focusrand op het actieve vak. Geluid volgt
/// `isActive` (zie `applyMute`), niet de tvOS-remote-focus zelf -- select maakt een vak actief.
private struct MultiviewTileView: View {
    @ObservedObject var slot: MultiviewSlot
    let isActive: Bool
    let onSelect: () -> Void
    let onChangeChannel: () -> Void

    var body: some View {
        Group {
            if let viewModel = slot.viewModel {
                MultiviewPlayingTile(
                    viewModel: viewModel,
                    channelName: slot.channel.map {
                        ChannelNameOverrideStore.effectiveName(channelID: $0.channel.id, defaultName: $0.channel.name)
                    },
                    isActive: isActive,
                    onSelect: onSelect,
                    onChangeChannel: onChangeChannel
                )
            } else {
                emptySlot
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptySlot: some View {
        Button(action: onChangeChannel) {
            ZStack {
                Color.white.opacity(0.05)
                VStack(spacing: 10) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 30))
                    Text("Zender kiezen")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct MultiviewPlayingTile: View {
    @ObservedObject var viewModel: PlaybackViewModel
    let channelName: String?
    let isActive: Bool
    let onSelect: () -> Void
    let onChangeChannel: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                Color.black
                if let engine = viewModel.playbackEngine {
                    AetherPlayerSurface(engine: engine.engine)
                } else {
                    ProgressView()
                }
                if let channelName {
                    Text(channelName)
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6), in: Capsule())
                        .padding(14)
                }
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isActive ? VeyraColors.cyan : Color.clear, lineWidth: 4)
        }
        .contextMenu {
            Button { onChangeChannel() } label: {
                Label("Zender wijzigen…", systemImage: "tv")
            }
        }
        // AetherEngine heeft geen eigen mute/volume-property (zie docs/api.md) -- muten kan enkel
        // via `currentAVPlayer.isMuted`, en die AVPlayer bestaat pas op de native/loopback-route
        // (niet op de software-decodeerroute) en verschijnt bovendien pas ná het laden. Daarom
        // hier herhaaldelijk toepassen i.p.v. één keer, zodat een net verschenen currentAVPlayer
        // alsnog de juiste mute-status krijgt. Vak zonder currentAVPlayer (software-route) kan
        // helaas niet gedempt worden -- gekende beperking van de engine.
        .task(id: "\(isActive)-\(viewModel.playbackEngine != nil)") {
            for _ in 0..<20 {
                applyMute(active: isActive)
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }

    private func applyMute(active: Bool) {
        viewModel.playbackEngine?.engine.currentAVPlayer?.isMuted = !active
    }
}
