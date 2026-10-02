import SwiftUI
import Combine
import AetherEngine

/// One preview session at a time. tvOS opens the selected channel as soon as
/// focus enters its Flow row; other platforms can start it from their preview button.
@MainActor
final class VeyraFlowPreviewController: ObservableObject {
    @Published private(set) var engine: AetherPlaybackEngine?
    @Published private(set) var channelID: String?
    @Published private(set) var loading = false
    @Published private(set) var failed = false

    private var loadTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    func start(_ row: VeyraGuideChannel) {
        stop()
        channelID = row.id
        loading = true

        let source = PlayableSource(
            name: ChannelNameOverrideStore.effectiveName(
                channelID: row.channel.id,
                defaultName: row.channel.name
            ),
            url: row.channel.streamURL,
            kind: .liveTV
        )

        do {
            let player = try AetherPlaybackEngine(isPreview: true)
            engine = player
            loadTask = Task { @MainActor [weak self] in
                do {
                    try await player.play(source)
                    guard !Task.isCancelled, self?.engine === player else {
                        player.stop()
                        return
                    }

                    if !(await Self.waitForVideo(player)),
                       player.engine.playbackBackend == .native {
                        guard !Task.isCancelled, self?.engine === player else { return }
                        try? await player.engine.reloadAtCurrentPosition {
                            $0.preferredDecodePath = .software
                        }
                        guard !Task.isCancelled, self?.engine === player else { return }
                        player.engine.play()
                    }

                    guard !Task.isCancelled, self?.engine === player else {
                        player.stop()
                        return
                    }
                    let ready = await Self.waitForVideo(player)
                    guard !Task.isCancelled, self?.engine === player else { return }
                    guard ready else {
                        self?.stop()
                        self?.failed = true
                        return
                    }
                    self?.loading = false
                } catch {
                    player.stop()
                    guard !Task.isCancelled, self?.engine === player else { return }
                    self?.engine = nil
                    self?.loading = false
                    self?.failed = true
                }
            }
            timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled, let self,
                      self.channelID == row.id, self.loading else { return }
                self.stop()
                self.failed = true
            }
        } catch {
            channelID = nil
            loading = false
            failed = true
        }
    }

    func stop() {
        loadTask?.cancel()
        loadTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        engine?.stop()
        engine = nil
        channelID = nil
        loading = false
        failed = false
    }

    private static func waitForVideo(_ player: AetherPlaybackEngine) async -> Bool {
        for _ in 0..<8 {
            if player.engine.hasFirstFrameReadyForDisplay { return true }
            if Task.isCancelled { return false }
            try? await Task.sleep(for: .seconds(1))
        }
        return player.engine.hasFirstFrameReadyForDisplay
    }
}
