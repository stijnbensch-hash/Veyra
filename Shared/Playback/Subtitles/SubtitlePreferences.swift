import Foundation

enum SubtitleLanguage: String, CaseIterable, Identifiable {
    case nl, en, fr, de, es, it, pt, pl, tr, ar, sv, da, no, fi, el
    var id: String { rawValue }
    var title: String {
        switch self {
        case .nl: "Nederlands"
        case .en: "Engels"
        case .fr: "Frans"
        case .de: "Duits"
        case .es: "Spaans"
        case .it: "Italiaans"
        case .pt: "Portugees"
        case .pl: "Pools"
        case .tr: "Turks"
        case .ar: "Arabisch"
        case .sv: "Zweeds"
        case .da: "Deens"
        case .no: "Noors"
        case .fi: "Fins"
        case .el: "Grieks"
        }
    }
    var codes: [String] {
        switch self {
        case .nl: ["nl", "nld", "dut"]
        case .en: ["en", "eng"]
        case .fr: ["fr", "fra", "fre"]
        case .de: ["de", "deu", "ger"]
        case .es: ["es", "spa"]
        case .it: ["it", "ita"]
        case .pt: ["pt", "por", "pt-br", "pob"]
        case .pl: ["pl", "pol"]
        case .tr: ["tr", "tur"]
        case .ar: ["ar", "ara"]
        case .sv: ["sv", "swe"]
        case .da: ["da", "dan"]
        case .no: ["no", "nor", "nb", "nob", "nn", "nno"]
        case .fi: ["fi", "fin"]
        case .el: ["el", "ell", "gre"]
        }
    }
    func matches(_ code: String?) -> Bool {
        guard let code else { return false }
        return codes.contains(code.lowercased().replacingOccurrences(of: "_", with: "-"))
    }
}

enum SubtitlePreferences {
    static let languageKey = "veyra.subtitle.defaultLanguage"
    static func language(defaults: UserDefaults = .standard) -> SubtitleLanguage {
        SubtitleLanguage(rawValue: defaults.string(forKey: languageKey) ?? "nl") ?? .nl
    }
}
