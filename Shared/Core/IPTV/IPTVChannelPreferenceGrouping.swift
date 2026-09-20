import Foundation

// MARK: - M3U preference grouping helpers
//
// Shared between tvOS and iOS: used by VeyraEPGStore to group M3U channels
// by their playlist "group-title" for per-group preferences.

extension IPTVChannel {
    var iptvPreferenceGroupName: String {
        let value = group?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let value, !value.isEmpty else {
            return "Overig"
        }

        return value
    }

    static func iptvPreferenceGroupID(_ groupName: String) -> String {
        "m3u-group:\(groupName)"
    }
}
