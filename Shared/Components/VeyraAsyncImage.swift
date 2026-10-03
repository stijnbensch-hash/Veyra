import SwiftUI
import ImageIO
import Foundation
import CryptoKit

/// All artwork sources use the same decode limit, including addon and custom URLs.
/// The source is downloaded to disk; ImageIO creates a thumbnail without decoding
/// a full-resolution original into RAM first.
struct VeyraAsyncImage<Content: View>: View {
    let url: URL?
    let scale: CGFloat
    let maxPixelSize: Int
    private let content: (AsyncImagePhase) -> Content
    @State private var phase: AsyncImagePhase = .empty

    init(url: URL?, scale: CGFloat = 1, maxPixelSize: Int = 1024,
         @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.scale = scale
        self.maxPixelSize = maxPixelSize
        self.content = content
    }

    init<I: View, P: View>(url: URL?, scale: CGFloat = 1, maxPixelSize: Int = 1024,
                          @ViewBuilder content: @escaping (Image) -> I,
                          @ViewBuilder placeholder: @escaping () -> P)
    where Content == _ConditionalContent<I, P> {
        self.init(url: url, scale: scale, maxPixelSize: maxPixelSize) { phase in
            if let image = phase.image { content(image) } else { placeholder() }
        }
    }

    var body: some View {
        // Keep task/lifetime attached to a stable container when the phase
        // replaces a placeholder with an image. A branch disappearing is not
        // the image view leaving the screen.
        ZStack { content(phase) }
            .task(id: ArtworkRequest(url: url, pixels: maxPixelSize)) {
                guard let url else { phase = .empty; return }
                // Al gedecodeerd in de gedeelde cache (bv. terugkeren naar Home na een
                // detailscherm, waar `.task` hier opnieuw doorloopt omdat de view opnieuw
                // verschijnt): meteen tonen i.p.v. eerst naar `.empty` te springen -- dat
                // was de zichtbare "backdrop laadt steeds opnieuw"-flits bij elke terugkeer,
                // ook al kwam de herlaad zelf (hieronder) alweer vrijwel ogenblikkelijk uit
                // diezelfde cache.
                if let cached = VeyraArtworkLoader.shared.cachedResult(url, pixels: maxPixelSize) {
                    phase = .success(Image(decorative: cached.image, scale: scale))
                } else {
                    phase = .empty
                }
                do {
                    let decoded = try await VeyraArtworkLoader.shared.load(url, pixels: maxPixelSize)
                    try Task.checkCancellation()
                    phase = .success(Image(decorative: decoded.image, scale: scale))
                } catch {
                    guard !Task.isCancelled else { return }
                    #if DEBUG
                    let failure = error as NSError
                    print("[VeyraArtwork] failed domain=\(failure.domain) code=\(failure.code)")
                    #endif
                    phase = .failure(error)
                }
            }
    }
}

nonisolated private struct ArtworkRequest: Hashable {
    let url: URL?
    let pixels: Int
}

nonisolated struct VeyraDecodedArtwork: @unchecked Sendable {
    let image: CGImage
}

private actor VeyraArtworkGate {
    private var available = 4
    private var waiters: [(UUID, CheckedContinuation<Bool, Never>)] = []

    func acquire(_ id: UUID) async -> Bool {
        guard !Task.isCancelled else { return false }
        if available > 0 { available -= 1; return true }
        return await withCheckedContinuation { waiters.append((id, $0)) }
    }

    func cancel(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.0 == id }) else { return }
        waiters.remove(at: index).1.resume(returning: false)
    }

    func release() {
        if waiters.isEmpty { available += 1 }
        else { waiters.removeFirst().1.resume(returning: true) }
    }
}


private actor VeyraArtworkRequests {
    private struct Entry {
        let task: Task<VeyraDecodedArtwork, Error>
        var consumers: Set<UUID>
    }
    private var entries: [String: Entry] = [:]

    func subscribe(key: String, consumer: UUID,
                   work: @escaping @Sendable () async throws -> VeyraDecodedArtwork) throws -> Task<VeyraDecodedArtwork, Error> {
        try Task.checkCancellation()
        if var entry = entries[key] {
            entry.consumers.insert(consumer)
            entries[key] = entry
            return entry.task
        }
        let task = Task { try await work() }
        entries[key] = Entry(task: task, consumers: [consumer])
        return task
    }

    func release(key: String, consumer: UUID) {
        guard var entry = entries[key], entry.consumers.remove(consumer) != nil else { return }
        if entry.consumers.isEmpty {
            entries.removeValue(forKey: key)
            entry.task.cancel()
        } else { entries[key] = entry }
    }
}

nonisolated final class VeyraArtworkLoader: @unchecked Sendable {
    static let shared = VeyraArtworkLoader()
    private let cache = ArtworkMemoryCache()
    private let decodeQueue = DispatchQueue(label: "veyra.artwork.decode", qos: .userInitiated)
    private let gate = VeyraArtworkGate()
    private let requests = VeyraArtworkRequests()
    private let diskCache = VeyraArtworkDiskCache()
    private let session: URLSession
    private var pressureObserver: NSObjectProtocol?

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 0, diskCapacity: 100 * 1024 * 1024)
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.httpMaximumConnectionsPerHost = 4
        session = URLSession(configuration: configuration)
        #if os(iOS) || os(tvOS)
        pressureObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UIApplicationDidReceiveMemoryWarningNotification"),
            object: nil, queue: nil
        ) { [weak self] _ in self?.clearMemory() }
        #endif
    }

    func clearMemory() { cache.clear() }
    var cachedBytes: Int { cache.totalCost }
    func clearAll() {
        clearMemory()
        session.configuration.urlCache?.removeAllCachedResponses()
        decodeQueue.async { self.diskCache.clear() }
    }

    /// Synchrone cache-check, puur om een al-gedecodeerde afbeelding meteen te kunnen tonen
    /// (zie `VeyraAsyncImage`) zonder eerst even leeg te flitsen -- bv. bij terugkeren naar
    /// Home na een detailscherm, waar de backdrop al in deze cache zit maar de view opnieuw
    /// verschijnt (en dus opnieuw door `.task` loopt).
    func cachedResult(_ url: URL, pixels: Int) -> VeyraDecodedArtwork? {
        let pixels = min(1920, max(64, pixels))
        return cache.value(for: "\(pixels)|\(url.absoluteString)")
    }

    func load(_ url: URL, pixels: Int) async throws -> VeyraDecodedArtwork {
        let pixels = min(1920, max(64, pixels))
        let key = "\(pixels)|\(url.absoluteString)" 
        if let hit = cache.value(for: key) { return hit }
        let consumer = UUID()
        return try await withTaskCancellationHandler {
            let task = try await requests.subscribe(key: key, consumer: consumer) {
                try await self.loadUnshared(url, pixels: pixels, key: key)
            }
            do {
                let result = try await task.value
                await requests.release(key: key, consumer: consumer)
                try Task.checkCancellation()
                return result
            } catch {
                await requests.release(key: key, consumer: consumer)
                throw error
            }
        } onCancel: {
            Task { await self.requests.release(key: key, consumer: consumer) }
        }
    }

    private func loadUnshared(_ url: URL, pixels: Int, key: String) async throws -> VeyraDecodedArtwork {
        let cacheGeneration = cache.generation
        if !url.isFileURL {
            let cached: VeyraDecodedArtwork? = await withCheckedContinuation { continuation in
                decodeQueue.async {
                    guard let file = self.diskCache.file(for: url) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let result = try? Self.decode(file: file, pixels: pixels)
                    if result == nil { self.diskCache.remove(url) }
                    continuation.resume(returning: result)
                }
            }
            try Task.checkCancellation()
            if let cached {
                cache.insert(cached, for: key, generation: cacheGeneration)
                return cached
            }
        }
        let id = UUID()
        let admitted = await withTaskCancellationHandler {
            await gate.acquire(id)
        } onCancel: {
            Task { await self.gate.cancel(id) }
        }
        guard admitted else { throw CancellationError() }
        do {
            try Task.checkCancellation()
            // A preceding request may have filled the cache while this request waited.
            if let hit = cache.value(for: key) {
                await gate.release()
                return hit
            }
            let file: URL
            var downloadedFile: URL?
            defer { if let downloadedFile { try? FileManager.default.removeItem(at: downloadedFile) } }
            if url.isFileURL { file = url }
            else {
                let (temporary, response) = try await session.download(from: url)
                downloadedFile = temporary
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                file = temporary
            }
            try Task.checkCancellation()
            let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 20 * 1024 * 1024 else { throw URLError(.dataLengthExceedsMaximum) }
            let decoded: VeyraDecodedArtwork = try await withCheckedThrowingContinuation { continuation in
                decodeQueue.async {
                    continuation.resume(with: Result {
                        let result = try Self.decode(file: file, pixels: pixels)
                        if !url.isFileURL, self.cache.generation == cacheGeneration {
                            self.diskCache.insert(file: file, for: url)
                        }
                        return result
                    })
                }
            }
            try Task.checkCancellation()
            cache.insert(decoded, for: key, generation: cacheGeneration)
            await gate.release()
            return decoded
        } catch {
            await gate.release()
            throw error
        }
    }
    private static func decode(file: URL, pixels: Int) throws -> VeyraDecodedArtwork {
        try autoreleasepool {
            let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: pixels,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let source = CGImageSourceCreateWithURL(file as CFURL, sourceOptions as CFDictionary),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
            else { throw URLError(.cannotDecodeContentData) }
            return VeyraDecodedArtwork(image: image)
        }
    }
}

nonisolated private final class ArtworkMemoryCache: @unchecked Sendable {
    private let lock = NSLock()
    private var cache = VeyraBoundedCache<String, VeyraDecodedArtwork>(countLimit: 100, costLimit: 48 * 1024 * 1024)
    private var revision: UInt64 = 0
    var generation: UInt64 { lock.lock(); defer { lock.unlock() }; return revision }
    var totalCost: Int { lock.lock(); defer { lock.unlock() }; return cache.totalCost }
    func value(for key: String) -> VeyraDecodedArtwork? {
        lock.lock(); defer { lock.unlock() }
        return cache.value(for: key)
    }
    func insert(_ value: VeyraDecodedArtwork, for key: String, generation: UInt64) {
        lock.lock(); defer { lock.unlock() }
        guard revision == generation else { return }
        cache.insert(value, for: key, cost: value.image.bytesPerRow * value.image.height)
    }
    func clear() {
        lock.lock(); defer { lock.unlock() }
        revision &+= 1
        cache.removeAll()
    }
}


/// Compressed originals survive memory eviction and relaunch. Filenames contain
/// only URL hashes. Access/expiry and the byte/count budgets are managed on the
/// loader's serial decode queue, so reads, writes and clear cannot race.
nonisolated final class VeyraArtworkDiskCache {
    private let directory: URL
    private let costLimit: Int
    private let countLimit: Int
    private let lifetime: TimeInterval = 24 * 60 * 60

    init(directory: URL? = nil, costLimit: Int = 128 * 1024 * 1024, countLimit: Int = 512) {
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VeyraArtwork-v1", isDirectory: true)
        self.costLimit = costLimit
        self.countLimit = countLimit
    }

    private func location(_ url: URL) -> URL {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(hash)
    }

    func file(for url: URL) -> URL? {
        var file = location(url)
        guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
              let modified = values.contentModificationDate,
              Date().timeIntervalSince(modified) < lifetime else {
            remove(url)
            return nil
        }
        var access = URLResourceValues()
        access.contentAccessDate = Date()
        try? file.setResourceValues(access)
        return file
    }

    func insert(file: URL, for url: URL) {
        let destination = location(url)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) { return }
            try FileManager.default.copyItem(at: file, to: destination)
            try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: destination.path)
            trim()
        } catch { try? FileManager.default.removeItem(at: destination) }
    }

    func remove(_ url: URL) { try? FileManager.default.removeItem(at: location(url)) }
    func clear() { try? FileManager.default.removeItem(at: directory) }

    private func trim() {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentAccessDateKey, .contentModificationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])) ?? []
        var entries = files.compactMap { file -> (URL, Int, Date)? in
            guard let values = try? file.resourceValues(forKeys: keys) else { return nil }
            return (file, values.fileSize ?? 0, values.contentAccessDate ?? values.contentModificationDate ?? .distantPast)
        }
        entries.sort { $0.2 < $1.2 }
        var bytes = entries.reduce(0) { $0 + $1.1 }
        var count = entries.count
        for (file, size, _) in entries {
            guard bytes > costLimit || count > countLimit else { break }
            try? FileManager.default.removeItem(at: file)
            bytes -= size
            count -= 1
        }
    }
}
