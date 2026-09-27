import SwiftUI
import AVKit
import AetherEngine

struct MacAirPlayButton: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        AVRoutePickerView(frame: .zero)
    }

    func updateNSView(_ view: AVRoutePickerView, context: Context) {}
}

@MainActor
final class MacPictureInPictureController: NSObject, ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var isActive = false
    @Published private(set) var isStarting = false

    var keepsPlaybackAlive: Bool { isStarting || isActive }
    var onEnded: (() -> Void)?

    private weak var engine: AetherEngine?
    private var controller: AVPictureInPictureController?
    private var possibleObservation: NSKeyValueObservation?
    private var nativeLayer: AVPlayerLayer?

    func attach(engine: AetherEngine) {
        self.engine = engine
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            isAvailable = false
            return
        }

        // De actieve PiP-sessie behoudt zijn laag tijdens routewisselingen.
        if keepsPlaybackAlive { return }

        if let layer = engine.nativePlayerLayer {
            guard nativeLayer !== layer || controller == nil else { return }
            nativeLayer = layer
            install(AVPictureInPictureController(playerLayer: layer))
        } else {
            possibleObservation = nil
            controller = nil
            nativeLayer = nil
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

    func stop() {
        if controller?.isPictureInPictureActive == true {
            controller?.stopPictureInPicture()
        }
    }
}

extension MacPictureInPictureController: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            self?.isStarting = true
            self?.engine?.pictureInPictureActive = true
        }
    }

    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            self?.isStarting = false
            self?.isActive = true
            self?.engine?.pictureInPictureActive = true
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            self?.isStarting = false
            self?.isActive = false
            self?.engine?.pictureInPictureActive = false
            self?.onEnded?()
        }
    }

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.isStarting = false
            self?.isActive = false
            self?.engine?.pictureInPictureActive = false
            self?.onEnded?()
        }
    }

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor [weak self] in completionHandler(self?.onEnded == nil) }
    }
}
