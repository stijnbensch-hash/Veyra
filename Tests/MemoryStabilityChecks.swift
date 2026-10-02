import Foundation
import CoreGraphics
import ImageIO

// Minimal provider fixtures keep this stress test independent of playback frameworks.
nonisolated struct XtreamConfiguration: Sendable {
    let serverURL: URL
    let username: String
}
nonisolated struct M3UConfiguration: Sendable { let playlistURL: URL }
nonisolated enum IPTVStoredConfiguration: Sendable {
    case xtream(XtreamConfiguration)
    case m3u(M3UConfiguration)
}

nonisolated struct BackgroundDecodedFixture: Codable, Sendable {
    let values: [String]
    init(values: [String]) { self.values = values }
    init(from decoder: Decoder) throws {
        precondition(!Thread.isMainThread, "Large disk decode must stay off the UI thread")
        values = try decoder.singleValueContainer().decode([String].self)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }
}

@main
struct MemoryStabilityChecks {
    static func main() async throws {
        var cache = VeyraBoundedCache<Int, String>(countLimit: 3, costLimit: 10)
        cache.insert("a", for: 1, cost: 4)
        cache.insert("b", for: 2, cost: 4)
        precondition(cache.value(for: 1) == "a")
        cache.insert("c", for: 3, cost: 4)
        precondition(!cache.contains(2) && cache.contains(1) && cache.totalCost == 8)
        cache.insert("too large", for: 4, cost: 11)
        precondition(!cache.contains(4))
        for n in 0..<10_000 {
            cache.insert(String(n), for: n, cost: n % 7)
            precondition(cache.count <= 3 && cache.totalCost <= 10)
        }
        cache.removeAll()
        precondition(cache.count == 0 && cache.totalCost == 0)

        let configuration = IPTVStoredConfiguration.xtream(.init(
            serverURL: URL(string: "https://example.invalid")!, username: UUID().uuidString))
        let prefs = IPTVProviderPreferencesStore()
        DispatchQueue.concurrentPerform(iterations: 4_000) { n in
            if n % 3 == 0 {
                var value = IPTVProviderPreferences()
                value.setSeriesItem(String(n), visible: false)
                try! prefs.save(value, for: configuration)
            } else if n % 7 == 0 { prefs.clear(for: configuration) }
            else { _ = prefs.load(for: configuration) }
        }
        var final = IPTVProviderPreferences()
        final.setSeriesItem("final", visible: false)
        try prefs.save(final, for: configuration)
        precondition(prefs.load(for: configuration) == final)
        prefs.clear(for: configuration)
        let ids = (0..<100).map { _ in UUID() }
        DispatchQueue.concurrentPerform(iterations: ids.count) { n in
            IPTVProviderEnablement.setEnabled(ids[n], false)
        }
        precondition(ids.allSatisfy { !IPTVProviderEnablement.isEnabled($0) }, "Concurrent updates must not lose provider IDs")
        ids.forEach { IPTVProviderEnablement.forget($0) }

        let key = "memory-check-\(UUID().uuidString)"
        let fixture = BackgroundDecodedFixture(values: (0..<20_000).map { "catalogue item \($0)" })
        IPTVDiskCache.write(fixture, key: key)
        await IPTVDiskCache.flush()
        let restored = await IPTVDiskCache.readAsync(BackgroundDecodedFixture.self, key: key)
        precondition(restored?.value.values == fixture.values)
        let cancelled = Task { await IPTVDiskCache.readAsync(BackgroundDecodedFixture.self, key: key) }
        cancelled.cancel()
        let cancelledResult = await cancelled.value
        precondition(cancelledResult == nil)
        IPTVDiskCache.remove(key: key)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = directory.appendingPathComponent("large.jpg")
        autoreleasepool {
            let context = CGContext(data: nil, width: 6000, height: 4000, bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.7, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 6000, height: 4000))
            let destination = CGImageDestinationCreateWithURL(original as CFURL, "public.jpeg" as CFString, 1, nil)!
            CGImageDestinationAddImage(destination, context.makeImage()!, nil)
            precondition(CGImageDestinationFinalize(destination))
        }
        let server = Process()
        server.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        server.arguments = ["-u", "-c", """
        import http.server,sys,os,time
        os.chdir(sys.argv[1])
        class Handler(http.server.SimpleHTTPRequestHandler):
            def do_GET(self):
                with open('requests.txt','a') as f: f.write('request\\n')
                time.sleep(0.15)
                super().do_GET()
        s=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
        print(s.server_port,flush=True)
        s.serve_forever()
        """, directory.path]
        let output = Pipe()
        server.standardOutput = output
        server.standardError = FileHandle.nullDevice
        try server.run()
        defer { server.terminate() }
        var portText = Data()
        while let byte = try output.fileHandleForReading.read(upToCount: 1), !byte.isEmpty {
            if byte == Data([10]) { break }
            portText.append(byte)
        }
        let port = Int(String(decoding: portText, as: UTF8.self))!
        let remote = URL(string: "http://127.0.0.1:\(port)/large.jpg")!
        let loader = VeyraArtworkLoader.shared
        let clock = ContinuousClock()
        let coldStart = clock.now
        let sharedLoads = (0..<20).map { _ in Task { try await loader.load(remote, pixels: 512) } }
        try await Task.sleep(for: .milliseconds(20))
        sharedLoads[0].cancel()
        for task in sharedLoads.dropFirst() {
            let downloaded = try await task.value
            precondition(max(downloaded.image.width, downloaded.image.height) <= 512)
        }
        _ = try? await sharedLoads[0].value
        let coldDuration = coldStart.duration(to: clock.now)
        let countFile = directory.appendingPathComponent("requests.txt")
        func requestCount() throws -> Int {
            try String(contentsOf: countFile, encoding: .utf8).split(separator: "\n").count
        }
        let coldRequests = try requestCount()
        precondition(coldRequests == 1, "identical concurrent images must share one download")
        loader.clearMemory()
        let warmStart = clock.now
        _ = try await loader.load(remote, pixels: 512)
        _ = try await loader.load(remote, pixels: 256)
        let warmDuration = warmStart.duration(to: clock.now)
        let warmRequests = try requestCount()
        precondition(warmRequests == 1, "disk hits must survive RAM eviction and different decode sizes")
        loader.clearAll()
        _ = try await loader.load(remote, pixels: 512)
        let clearedRequests = try requestCount()
        precondition(clearedRequests == 2, "clearAll must invalidate compressed disk images")
        print("Artwork local HTTP: cold=\(coldDuration), disk reloads=\(warmDuration); 20 concurrent consumers shared one request")

        // Verify both independent disk budgets and expiration without touching the app cache.
        for (name, bytes, count, expected) in [("bytes", 1500, 8, 1), ("count", 10000, 2, 2)] {
            let cacheDirectory = directory.appendingPathComponent(name)
            let disk = VeyraArtworkDiskCache(directory: cacheDirectory, costLimit: bytes, countLimit: count)
            let payload = directory.appendingPathComponent("payload")
            try Data(repeating: 7, count: 1000).write(to: payload)
            for index in 0..<4 { disk.insert(file: payload, for: URL(string: "https://example.test/\(index)")!) }
            let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            precondition(files.count == expected)
            let totalBytes = try files.reduce(0) { try $0 + $1.resourceValues(forKeys: [.fileSizeKey]).fileSize! }
            precondition(totalBytes <= bytes)
            for file in files { precondition(file.lastPathComponent.count == 64) }
            let expiring = URL(string: "https://example.test/expiry")!
            disk.insert(file: payload, for: expiring)
            let cachedFile = disk.file(for: expiring)!
            try FileManager.default.setAttributes([.modificationDate: Date.distantPast], ofItemAtPath: cachedFile.path)
            precondition(disk.file(for: expiring) == nil)
            disk.clear()
            precondition(!FileManager.default.fileExists(atPath: cacheDirectory.path))
        }

        for pixels in [256, 512, 1920] {
            let image = try await loader.load(original, pixels: pixels).image
            precondition(max(image.width, image.height) <= pixels)
        }
        // Several independent large originals must never exceed the decoded cache budget.
        for n in 0..<16 {
            let copy = directory.appendingPathComponent("\(n).jpg")
            try FileManager.default.copyItem(at: original, to: copy)
            _ = try await loader.load(copy, pixels: 1920)
            precondition(loader.cachedBytes <= 48 * 1024 * 1024)
        }
        // Exercise queued cancellation and prove permits are returned for a subsequent load.
        let loads = (0..<32).map { _ in Task { try await loader.load(original, pixels: 1024) } }
        loads.prefix(20).forEach { $0.cancel() }
        for task in loads { _ = try? await task.value }
        _ = try await loader.load(original, pixels: 1024)
        loader.clearMemory()
        precondition(loader.cachedBytes == 0)
        print("PASS: LRU byte limits, 4000 concurrent preference accesses, atomic provider updates, background disk decode, cancellation, 6000×4000 image downsampling and cache purge, shared downloads and bounded persistent artwork cache")
    }
}
