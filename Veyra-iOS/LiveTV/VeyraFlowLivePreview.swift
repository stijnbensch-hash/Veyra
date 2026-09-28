import SwiftUI
import AetherEngine

@MainActor
struct VeyraPortableFlowPreview: View {
    let guide: VeyraEPGStore
    let row: VeyraGuideChannel?
    let now: Date
    @ObservedObject var controller: VeyraFlowPreviewController
    let onPlay: (VeyraGuideChannel) -> Void

    private var current: VeyraEPGProgramme? {
        guard let row else { return nil }
        return guide.programmes(for: row).first { $0.isOnAir(at: now) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Color.black

                if let row, controller.channelID == row.id,
                   let engine = controller.engine {
                    AetherPlayerSurface(engine: engine.engine)
                }

                if controller.loading, controller.channelID == row?.id {
                    ProgressView("Live beeld laden…")
                        .tint(.white)
                } else if controller.engine == nil {
                    VStack(spacing: 8) {
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 36, weight: .light))
                        Text(controller.failed ? "Voorvertoning niet beschikbaar" : "Start het live voorbeeld")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .topLeading) {
                if controller.channelID == row?.id, !controller.loading {
                    Text("LIVE")
                        .font(.caption.bold())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.red, in: Capsule())
                        .padding(10)
                }
            }

            if let row {
                Text(ChannelNameOverrideStore.effectiveName(
                    channelID: row.channel.id,
                    defaultName: row.channel.name
                ))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(VeyraHomeStyle.cyan)

                Text(current?.title ?? "Live TV")
                    .font(.title2.bold())
                    .lineLimit(2)

                if let current {
                    Text("\(current.start.formatted(.dateTime.hour().minute()))–\(current.end.formatted(.dateTime.hour().minute()))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack {
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
                    }
                    .buttonStyle(.bordered)

                    Button {
                        controller.stop()
                        onPlay(row)
                    } label: {
                        Label("Kijk live", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text("Kies een zender")
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
        .onDisappear { controller.stop() }
    }
}
