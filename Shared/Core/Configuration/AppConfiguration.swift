import Foundation
import Security

enum AppConfiguration {
    static var traktClientID: String? {
        VeyraAPIKeyStore.value(
            for: .traktClientID
        )
        ?? configuredValue(
            "TraktClientID"
        )
    }

    static var traktClientSecret: String? {
        VeyraAPIKeyStore.value(
            for: .traktClientSecret
        )
        ?? configuredValue(
            "TraktClientSecret"
        )
    }

    static var traktRedirectURI: String {
        configuredValue(
            "TraktRedirectURI"
        )
        ?? "urn:ietf:wg:oauth:2.0:oob"
    }

    static var omdbAPIKey: String? {
        VeyraAPIKeyStore.value(
            for: .omdbAPIKey
        )
        ?? configuredValue(
            "OMDbAPIKey"
        )
    }

    static var fanartAPIKey: String? {
        VeyraAPIKeyStore.value(
            for: .fanartAPIKey
        )
        ?? configuredValue(
            "FanartAPIKey"
        )
    }

    static var mdblistAPIKey: String? {
        VeyraAPIKeyStore.value(
            for: .mdblistAPIKey
        )
        ?? configuredValue(
            "MDBListAPIKey"
        )
    }

    static var introDBAPIKey: String? {
        VeyraAPIKeyStore.value(
            for: .introDBAPIKey
        )
        ?? configuredValue(
            "IntroDBAPIKey"
        )
    }

    static var privacyPolicyURL: URL? {
        guard
            let value =
                configuredValue(
                    "PrivacyPolicyURL"
                ),
            let url =
                URL(
                    string: value
                ),
            url.scheme == "https"
        else {
            return nil
        }

        return url
    }

    /// Fase 2 (Request Foundation, TMDB-performance-spec §10 "Request builder"/audit-P0):
    /// elke TMDB-aanroep las voorheen bij ELK verzoek synchroon de Keychain -- nu één keer per
    /// sessie gecached, en ongeldig gemaakt zodra sleutels wijzigen (Instellingen of Hub-sync
    /// posten al `.veyraAPIKeysDidChange`).
    static var tmdbReadAccessToken: String? {
        TMDBTokenCache.shared.cachedOrCompute {
            if let stored = VeyraAPIKeyStore.value(for: .tmdbReadAccessToken) {
                return stored
            }

            guard let configured = configuredValue("TMDBReadAccessToken") else {
                return nil
            }
            // De Top Shelf-extensie kan de appconfiguratie niet lezen. Bewaar de
            // bestaande sleutel lokaal in de gedeelde keychain zodra de app hem
            // gebruikt, zonder hem in de extensiebundel op te nemen.
            try? VeyraAPIKeyStore.set(configured, for: .tmdbReadAccessToken)
            return configured
        }
    }

    static var openSubtitlesAPIKey:
        String?
    {
        VeyraAPIKeyStore.value(
            for:
                .openSubtitlesAPIKey
        )
        ?? configuredValue(
            "OpenSubtitlesAPIKey"
        )
    }

    static func setTMDBReadAccessToken(
        _ value: String?
    ) throws {
        try VeyraAPIKeyStore
            .set(
                value,
                for:
                    .tmdbReadAccessToken
            )
    }

    static func setTraktClientID(
        _ value: String?
    ) throws {
        try VeyraAPIKeyStore
            .set(
                value,
                for:
                    .traktClientID
            )
    }

    static func setTraktClientSecret(
        _ value: String?
    ) throws {
        try VeyraAPIKeyStore
            .set(
                value,
                for:
                    .traktClientSecret
            )
    }

    static func setOMDbAPIKey(
        _ value: String?
    ) throws {
        try VeyraAPIKeyStore
            .set(
                value,
                for:
                    .omdbAPIKey
            )
    }

    static func setFanartAPIKey(
        _ value: String?
    ) throws {
        try VeyraAPIKeyStore
            .set(
                value,
                for:
                    .fanartAPIKey
            )
    }

    static func setMDBListAPIKey(
        _ value: String?
    ) throws {
        try VeyraAPIKeyStore
            .set(
                value,
                for:
                    .mdblistAPIKey
            )
    }

    static func setIntroDBAPIKey(
        _ value: String?
    ) throws {
        try VeyraAPIKeyStore
            .set(
                value,
                for:
                    .introDBAPIKey
            )
    }

    static func setOpenSubtitlesAPIKey(
        _ value: String?
    ) throws {
        try VeyraAPIKeyStore
            .set(
                value,
                for:
                    .openSubtitlesAPIKey
            )
    }

    static func removeTMDBReadAccessToken()
        throws
    {
        try VeyraAPIKeyStore
            .remove(
                .tmdbReadAccessToken
            )
    }

    static func removeOpenSubtitlesAPIKey()
        throws
    {
        try VeyraAPIKeyStore
            .remove(
                .openSubtitlesAPIKey
            )
    }

    static func removeTraktClientID()
        throws
    {
        try VeyraAPIKeyStore
            .remove(
                .traktClientID
            )
    }

    static func removeTraktClientSecret()
        throws
    {
        try VeyraAPIKeyStore
            .remove(
                .traktClientSecret
            )
    }

    static func removeOMDbAPIKey()
        throws
    {
        try VeyraAPIKeyStore
            .remove(
                .omdbAPIKey
            )
    }

    // MARK: - Legacy AIOStreams migration

    static var aioStreamsBaseURL:
        URL?
    {
        guard
            let value =
                configuredValue(
                    "AIOStreamsBaseURL"
                )
        else {
            return nil
        }

        return URL(
            string: value
        )
    }

    // MARK: - Bundle configuration

    private static func configuredValue(
        _ key: String
    ) -> String? {
        guard
            let value =
                Bundle.main
                    .object(
                        forInfoDictionaryKey:
                            key
                    )
                    as? String
        else {
            return nil
        }

        let trimmed =
            value
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !trimmed.isEmpty,
            !trimmed.contains("$(")
        else {
            return nil
        }

        return trimmed
    }
}

/// In-memory cache voor `AppConfiguration.tmdbReadAccessToken` (Fase 2, zie daar). Simpele
/// lock-beveiligde singleton i.p.v. een actor, omdat de token overal als gewone, synchrone
/// `static var` wordt gelezen (geen `await`-punten door de hele TMDB-stack heen).
private final class TMDBTokenCache: @unchecked Sendable {
    static let shared = TMDBTokenCache()

    private let lock = NSLock()
    private var cached: String??
    private var observer: NSObjectProtocol?

    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: .veyraAPIKeysDidChange, object: nil, queue: nil
        ) { [weak self] _ in
            self?.invalidate()
        }
    }

    func cachedOrCompute(_ compute: () -> String?) -> String? {
        lock.lock()
        if let cached {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let value = compute()
        lock.lock()
        cached = value
        lock.unlock()
        return value
    }

    private func invalidate() {
        lock.lock()
        cached = nil
        lock.unlock()
    }
}
