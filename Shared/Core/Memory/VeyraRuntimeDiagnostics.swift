import Foundation
import OSLog
import Darwin
#if os(iOS) || os(tvOS)
import UIKit
#endif

/// Local diagnostics only: no titles, credentials, provider URLs, or account IDs.
@MainActor
final class VeyraRuntimeDiagnostics {
    static let shared = VeyraRuntimeDiagnostics()
    private let logger = Logger(subsystem: "com.veyra.runtime", category: "Memory")
    private var task: Task<Void, Never>?
    private var observer: NSObjectProtocol?

    func start() {
        guard task == nil else { return }
        #if os(iOS) || os(tvOS)
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.record(event: "memoryWarning")
                await Self.clearMetadataCaches()
            }
        }
        #endif
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.record(event: "sample")
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    static func clearMetadataCaches() async {
        await MetadataRepository.shared.clearCache()
        await ArtworkResolver.shared.clearCache()
        await TMDBMetadataCache.shared.clearCache()
    }

    func record(event: String) async {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let footprint = info.phys_footprint / 1024 / 1024
        let images = VeyraArtworkLoader.shared.cachedBytes / 1024 / 1024
        let aio = await MetadataRepository.shared.cachedCount
        let logos = await ArtworkResolver.shared.cachedCount
        let tmdb = await TMDBMetadataCache.shared.cachedCount
        let owners = AetherPlaybackEngine.activeSessionCount
        let source: String
        switch MetadataSourcePolicy.activeSource() {
        case .tmdb: source = "tmdb"
        case .aioMetadata: source = "aioMetadata"
        }
        #if DEBUG
        print("[VeyraMemory] event=\(event) footprintMiB=\(footprint) decodedCacheMiB=\(images) aioItems=\(aio) logoItems=\(logos) tmdbItems=\(tmdb) playerOwners=\(owners) metadataSource=\(source)")
        #endif
        logger.info("event=\(event, privacy: .public) footprintMiB=\(footprint) decodedCacheMiB=\(images) aioItems=\(aio) logoItems=\(logos) tmdbItems=\(tmdb) playerOwners=\(owners) metadataSource=\(source, privacy: .public)")
    }
}
