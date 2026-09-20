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

    static var tmdbReadAccessToken:
        String?
    {
        VeyraAPIKeyStore.value(
            for:
                .tmdbReadAccessToken
        )
        ?? configuredValue(
            "TMDBReadAccessToken"
        )
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
