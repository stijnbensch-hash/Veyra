import SwiftUI

/// Weergave-instellingen voor tekstondertitels tijdens het afspelen:
/// grootte, plaatsing, achtergrond, schaduw en tijdcorrectie (sync).
///
/// Dit zat eerder verstopt in het tvOS-afspeelscherm (aparte "Weergave"- en
/// "Synchronisatie"-tabs naast de bronkeuze) en was op iOS nergens
/// instelbaar. Nu heeft Instellingen → Ondertitels op beide platforms een
/// eigen sectie hiervoor, en toont het afspeelscherm alleen nog de keuze
/// van ondertitelbron (sporen uit de stream + OpenSubtitles-zoekresultaten).
///
/// De AppStorage-sleutels zijn ongewijzigd t.o.v. de oorspronkelijke,
/// tvOS-only implementatie, zodat bestaande waarden op toestellen die al
/// een keuze gemaakt hadden gewoon blijven gelden.
enum SubtitleAppearanceDefaults {
    static let sizeKey = "veyra.subtitle.size"
    static let positionKey = "veyra.subtitle.position"
    static let backgroundKey = "veyra.subtitle.background"
    static let shadowKey = "veyra.subtitle.shadow"
    static let offsetKey = "veyra.subtitle.offset"
}

enum VeyraSubtitleSize: String, CaseIterable, Identifiable {
    case small
    case normal
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "Klein"
        case .normal: return "Normaal"
        case .large: return "Groot"
        }
    }

    var multiplier: CGFloat {
        switch self {
        case .small: return 0.82
        case .normal: return 1.0
        case .large: return 1.22
        }
    }
}

enum VeyraSubtitlePosition: String, CaseIterable, Identifiable {
    case low
    case standard
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: return "Laag"
        case .standard: return "Standaard"
        case .high: return "Hoog"
        }
    }

    func bottomPadding(for height: CGFloat) -> CGFloat {
        switch self {
        case .low: return max(42, height * 0.045)
        case .standard: return max(70, height * 0.075)
        case .high: return max(110, height * 0.13)
        }
    }
}

enum VeyraSubtitleBackground: String, CaseIterable, Identifiable {
    case none
    case subtle
    case strong

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Geen"
        case .subtle: return "Subtiel"
        case .strong: return "Donker"
        }
    }

    var opacity: Double {
        switch self {
        case .none: return 0
        case .subtle: return 0.42
        case .strong: return 0.70
        }
    }
}
