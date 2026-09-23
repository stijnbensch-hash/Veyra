import Foundation

/// Uses another provider already configured by the user for live playback.
/// Video still travels directly to this device.
@MainActor
final class VeyraLocalLiveFallback {
    static let shared = VeyraLocalLiveFallback()

    private var loaded: [String: [IPTVChannel]] = [:]
    private var loading: [String: Task<[IPTVChannel], Error>] = [:]

    private init() {}

    func source(
        for channel: IPTVChannel,
        original: PlayableSource
    ) async -> PlayableSource {
        guard channel.sourceType == .xtream,
              let providers = try? IPTVConfigurationStore().loadProviders(),
              let activeID = try? IPTVConfigurationStore().activeProviderID()
        else { return original }

        for provider in providers where provider.id != activeID {
            guard case .xtream(let configuration) = provider.configuration else { continue }
            let key = provider.configuration.providerIdentifier
            let candidates: [IPTVChannel]
            do {
                candidates = try await channels(for: configuration, key: key)
            } catch {
                continue
            }

            let tvgID = channel.tvgID?.trimmingCharacters(in: .whitespacesAndNewlines)
            let idMatch = tvgID.flatMap { id in
                id.isEmpty ? nil : candidates.first {
                    $0.tvgID?.trimmingCharacters(in: .whitespacesAndNewlines)
                        .caseInsensitiveCompare(id) == .orderedSame
                        && Self.sameRegion(channel.name, $0.name)
                }
            }
            // Provider EPG IDs are occasionally attached to the wrong station.
            // A unique name in the same region is more reliable (e.g. PLAY and ID).
            let match = uniqueNameMatch(for: channel, in: candidates) ?? idMatch
            guard let match else { continue }

            return PlayableSource(
                name: original.name,
                description: original.description,
                metadata: original.metadata,
                url: match.streamURL,
                kind: original.kind,
                providerName: provider.displayName,
                requiresSoftwareVideo: original.requiresSoftwareVideo
            )
        }

        return original
    }

    private func uniqueNameMatch(
        for channel: IPTVChannel,
        in candidates: [IPTVChannel]
    ) -> IPTVChannel? {
        let target = Self.normalizedName(channel.name)
        guard !target.isEmpty else { return nil }
        var found: IPTVChannel?
        for candidate in candidates where Self.normalizedName(candidate.name) == target {
            // A name shared by multiple channels cannot identify a safe fallback.
            guard found == nil else { return nil }
            found = candidate
        }
        return found
    }

    private static func normalizedName(_ name: String) -> String {
        var value = name.replacingOccurrences(
            of: #"^\s*┃([A-Za-z]{2})┃\s*"#,
            with: "$1: ",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"^\s*(NL|BE)-VIP:"#,
            with: "$1:",
            options: [.regularExpression, .caseInsensitive]
        )
        for marker in ["⏺ʳᵉᶜ", "ᴿᴬᵂ", "ᴴᴰ", "ᵁᴴᴰ", "◉"] {
            value = value.replacingOccurrences(of: marker, with: " ")
        }
        value = value.replacingOccurrences(of: "+", with: " plus ")
        value = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let words = value.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let normalized = words.filter {
            !["hd", "fhd", "uhd", "sd", "raw", "rec", "ts"].contains($0)
        }.joined(separator: " ")
        return normalized == "nl investigation discovery" ? "nl id" : normalized
    }

    private static func sameRegion(_ first: String, _ second: String) -> Bool {
        let left = normalizedName(first).split(separator: " ").first
        let right = normalizedName(second).split(separator: " ").first
        return left == right && (left == "nl" || left == "be")
    }

    private func channels(
        for configuration: XtreamConfiguration,
        key: String
    ) async throws -> [IPTVChannel] {
        if let loaded = loaded[key] { return loaded }
        if let cached = IPTVDiskCache.read(
            [IPTVChannel].self, key: "local-live-fallback-v1-\(key)"
        )?.value {
            loaded[key] = cached
            return cached
        }
        if let loading = loading[key] { return try await loading.value }

        let task = Task {
            try await IPTVService().loadXtreamLiveChannels(configuration: configuration)
        }
        loading[key] = task
        defer { loading[key] = nil }
        let result = try await task.value
        loaded[key] = result
        IPTVDiskCache.write(result, key: "local-live-fallback-v1-\(key)")
        return result
    }
}
