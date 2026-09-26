import AVKit
import AetherEngine
import Combine

/// Beheert PiP voor zowel de native AVPlayer-laag als de softwarelaag van
/// AetherEngine. De controller blijft aan de huidige mediasessie gekoppeld.
@MainActor
final class AetherPictureInPictureController: NSObject, ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var isActive = false
    @Published private(set) var isStarting = false

    var keepsPlaybackAlive: Bool { isStarting || isActive }

    private weak var engine: AetherEngine?
    private var controller: AVPictureInPictureController?
    private var possibleObservation: NSKeyValueObservation?
    private var nativeLayer: AVPlayerLayer?
    private var softwareSource: SoftwarePiPSource?

    func attach(engine: AetherEngine) {
        self.engine = engine
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            isAvailable = false
            return
        }

        // Tijdens PiP mag een tijdelijke routewisseling de actieve controller
        // niet vervangen. Aether houdt de videosessie dan zelf in leven.
        if keepsPlaybackAlive { return }

        if let layer = engine.nativePlayerLayer {
            guard nativeLayer !== layer || controller == nil else { return }
            install(AVPictureInPictureController(playerLayer: layer))
            nativeLayer = layer
            softwareSource = nil
        } else if let source = engine.softwarePiPSource {
            guard softwareSource !== source || controller == nil else { return }
            softwareSource = source
            nativeLayer = nil
            let content = AVPictureInPictureController.ContentSource(
                sampleBufferDisplayLayer: source.layer,
                playbackDelegate: self
            )
            install(AVPictureInPictureController(contentSource: content))
        } else {
            possibleObservation = nil
            controller = nil
            nativeLayer = nil
            softwareSource = nil
            isAvailable = false
        }
    }

    private func install(_ newController: AVPictureInPictureController?) {
        possibleObservation = nil
        controller = newController
        guard let newController else {
            isAvailable = false
            return
        }
        newController.delegate = self
        newController.canStartPictureInPictureAutomaticallyFromInline = true
        possibleObservation = newController.observe(\.isPictureInPicturePossible, options: [.initial, .new]) {
            [weak self] controller, _ in
            Task { @MainActor [weak self] in
                guard let self, self.controller === controller else { return }
                self.isAvailable = controller.isPictureInPicturePossible
            }
        }
    }

    func toggle() {
        guard let controller else { return }
        if controller.isPictureInPictureActive {
            controller.stopPictureInPicture()
        } else if controller.isPictureInPicturePossible {
            isStarting = true
            controller.startPictureInPicture()
        }
    }
}

extension AetherPictureInPictureController: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerWillStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor [weak self] in
            self?.isStarting = true
            self?.engine?.pictureInPictureActive = true
        }
    }

    nonisolated func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor [weak self] in
            self?.isStarting = false
            self?.isActive = true
            self?.engine?.pictureInPictureActive = true
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor [weak self] in
            self?.isStarting = false
            self?.isActive = false
            self?.engine?.pictureInPictureActive = false
        }
    }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.isStarting = false
            self?.isActive = false
            self?.engine?.pictureInPictureActive = false
        }
    }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true)
    }
}

extension AetherPictureInPictureController: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        softwareSource?.setPlaying(playing)
    }

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        softwareSource?.timeRange() ?? .invalid
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        softwareSource?.isPaused ?? true
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        didTransitionToRenderSize newRenderSize: CMVideoDimensions
    ) {}

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        skipByInterval skipInterval: CMTime,
        completion: @escaping () -> Void
    ) {
        let seconds = CMTimeGetSeconds(skipInterval)
        if seconds.isFinite { softwareSource?.skip(by: seconds) }
        completion()
    }

    func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> Bool { false }
}
