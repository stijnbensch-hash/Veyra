import Foundation

enum AppConfiguration {
    static var aioStreamsBaseURL: URL? {
        guard
            let value = Bundle.main.object(
                forInfoDictionaryKey: "AIOStreamsBaseURL"
            ) as? String,
            !value.isEmpty,
            !value.contains("$(")
        else {
            return nil
        }

        return URL(string: value)
    }

    static var tmdbReadAccessToken: String? {
        guard
            let value = Bundle.main.object(
                forInfoDictionaryKey: "TMDBReadAccessToken"
            ) as? String,
            !value.isEmpty,
            !value.contains("$(")
        else {
            return nil
        }

        return value
    }
}
