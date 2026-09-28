import SwiftUI
import AetherEngine

@MainActor
struct VeyraFlowLivePreview: View {
    let guide: VeyraEPGStore
    let row: VeyraGuideChannel?
    let now: Date
    let logoOverrideVersion: Int
    @ObservedObject var controller: VeyraFlowPreviewController
    let onPlay: (VeyraGuideChannel) -> Void

    private var current: VeyraEPGProgramme? {
        guard let row else { return nil }
        return guide.programmes(for: row).first { $0.isOnAir(at: now) }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            videoSurface
                .frame(width: 430, height: 242)

            VStack(alignment: .leading, spacing: 10) {
            if let row {
                Text(current?.title ?? "Live TV")
                    .font(.system(size: 32, weight: .bold))
                    .lineLimit(2)

                if let current {
                    Text("\(current.start.formatted(.dateTime.hour().minute()))–\(current.end.formatted(.dateTime.hour().minute()))")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.65))

                    Text(current.summary.isEmpty ? "Geen beschrijving beschikbaar." : current.summary)
                        .font(.system(size: 23))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                }

                HStack(spacing: 14) {
                    Button {
                        if controller.channelID == row.id {
                            controller.stop()
                        } else {
                            controller.start(row)
                        }
                    } label: {
                        Label(
                            controller.channelID == row.id ? "Stop voorbeeld" : "Voorvertoning",
                            systemImage: controller.channelID == row.id ? "stop.fill" : "play.rectangle"
                        )
                        .padding(12)
                    }
                    .buttonStyle(VeyraEPGButtonStyle())

                    Button {
                        controller.stop()
                        onPlay(row)
                    } label: {
                        Label("Kijk live", systemImage: "play.fill")
                            .padding(12)
                    }
                    .buttonStyle(VeyraEPGButtonStyle(selected: true))
                }
            } else {
                Text("Kies een zender in de gids")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let row,
               let logoURL = ChannelLogoOverrideStore.effectiveLogoURL(
                   channelID: row.channel.id,
                   defaultLogoURL: row.channel.logoURL
               ) {
                AsyncImage(url: logoURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    }
                }
                .id(logoOverrideVersion)
                .frame(width: 210, height: 150)
                .accessibilityLabel(ChannelNameOverrideStore.effectiveName(
                    channelID: row.channel.id,
                    defaultName: row.channel.name
                ))
            }
        }
        .padding(18)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var videoSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.black)

            if let row, controller.channelID == row.id,
               let engine = controller.engine {
                AetherPlayerSurface(engine: engine.engine)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            if controller.loading, controller.channelID == row?.id {
                ProgressView("Voorvertoning laden…")
            } else if controller.engine == nil {
                VStack(spacing: 10) {
                    Image(systemName: "play.rectangle")
                        .font(.system(size: 44, weight: .ultraLight))
                    Text(controller.failed ? "Voorvertoning niet beschikbaar" : "Live voorbeeld")
                        .font(.system(size: 17, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.7))
            }
        }
        .overlay(alignment: .topLeading) {
            if controller.channelID == row?.id, !controller.loading {
                Text("LIVE")
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.red, in: Capsule())
                    .padding(14)
            }
        }
    }

}
