import Combine
import Foundation
import SwiftUI

nonisolated enum IPTVChannelHealthStatus: Sendable {
    case online
    case offline
    case unknown
}

/// Checks only channels that are shown in the EPG favourites view. Results
/// stay in memory; stream URLs can contain provider credentials.
@MainActor
final class IPTVChannelHealthStore: ObservableObject {
    static let shared = IPTVChannelHealthStore()

    @Published private var statuses: [URL: IPTVChannelHealthStatus] = [:]

    private var checkedAt: [URL: Date] = [:]
    private var checking: Set<URL> = []
    private let probe = IPTVChannelHealthProbe()
    private let cacheDuration: TimeInterval = 5 * 60

    private init() {}

    func status(for channel: IPTVChannel) -> IPTVChannelHealthStatus? {
        statuses[channel.streamURL]
    }

    func refreshIfNeeded(_ channel: IPTVChannel) {
        let url = channel.streamURL
        guard !checking.contains(url) else { return }
        if let lastCheck = checkedAt[url], Date().timeIntervalSince(lastCheck) < cacheDuration {
            return
        }

        checking.insert(url)
        Task { [weak self] in
            guard let self else { return }
            let result = await self.probe.check(url)
            self.statuses[url] = result
            self.checkedAt[url] = Date()
            self.checking.remove(url)
        }
    }
}

/// Limits simultaneous requests so opening a long favourites list does not
/// start a stream check for every channel at once.
private actor IPTVChannelHealthProbe {
    private let maxConcurrent = 3
    private var active = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 6
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
    }

    func check(_ url: URL) async -> IPTVChannelHealthStatus {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return .unknown
        }

        await acquire()
        defer { release() }

        if let headStatus = await responseCode(for: url, method: "HEAD"),
           (200...299).contains(headStatus) {
            return .online
        }

        // Stream servers often reject HEAD even when playback works. Read
        // only the GET response headers, then cancel the transfer.
        guard let getStatus = await responseCode(for: url, method: "GET") else {
            return .offline
        }
        return (200...299).contains(getStatus) ? .online : .offline
    }

    private func responseCode(for url: URL, method: String) async -> Int? {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 5
        do {
            let (bytes, response) = try await session.bytes(for: request)
            bytes.task.cancel()
            return (response as? HTTPURLResponse)?.statusCode
        } catch {
            return nil
        }
    }

    private func acquire() async {
        if active < maxConcurrent {
            active += 1
            return
        }
        await withCheckedContinuation { continuation in
            waiting.append(continuation)
        }
    }

    private func release() {
        if waiting.isEmpty {
            active -= 1
        } else {
            waiting.removeFirst().resume()
        }
    }
}

struct IPTVChannelHealthDot: View {
    let status: IPTVChannelHealthStatus?
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .accessibilityLabel(accessibilityText)
    }

    private var color: Color {
        switch status {
        case .online: .green
        case .offline: .red
        case .unknown, .none: .gray
        }
    }

    private var accessibilityText: String {
        switch status {
        case .online: "Zender bereikbaar"
        case .offline: "Zender niet bereikbaar"
        case .unknown, .none: "Zenderstatus onbekend"
        }
    }
}
