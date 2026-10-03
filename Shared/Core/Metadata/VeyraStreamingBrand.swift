import Foundation

/// Bundled wordmarks for Home. Exact aliases prevent similarly named channels or
/// user-created addon catalogues from being given an unrelated streaming logo.
nonisolated struct VeyraStreamingBrand: Sendable {
    let assetName: String
    let color: UInt32

    static func named(_ name: String) -> Self? {
        let key = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .filter { $0.isLetter || $0.isNumber || $0 == "+" }
        switch key {
        case "netflix": return brand("Netflix", 0xE50914)
        case "amazonprimevideo", "primevideo": return brand("PrimeVideo", 0x00A8E1)
        case "disneyplus", "disney+": return brand("DisneyPlus", 0x02D6E8)
        case "hbomax": return brand("HBOMax", 0xA475FF)
        case "appletv", "appletv+", "appletvplus": return brand("AppleTV", 0xFFFFFF)
        case "shudder": return brand("Shudder", 0xEF1923)
        case "vrtmax": return brand("VRTMax", 0xFF5149)
        case "telenet": return brand("Telenet", 0xFFC421)
        case "vtmgo": return brand("VTMGo", 0xFF00C9)
        case "justwatchtv", "justwatch": return brand("JustWatch", 0xFBC500)
        case "discovery+", "discoveryplus": return brand("DiscoveryPlus", 0x29B6F6)
        case "hulu": return brand("Hulu", 0x1CE783)
        case "thecw", "cw": return brand("TheCW", 0xFF4B00)
        case "amc+", "amcplus": return brand("AMCPlus", 0x00C7C9)
        case "fxnow": return brand("FXNow", 0xFFFFFF)
        case "mgmplus", "mgm+": return brand("MGMPlus", 0xD0B36E)
        case "britbox": return brand("BritBox", 0xA6E2F5)
        case "starz": return brand("Starz", 0xB5EEE4)
        case "nationalgeographic": return brand("NationalGeographic", 0xFFCC00)
        case "skyshowtime": return brand("SkyShowtime", 0xDDA7FF)
        case "videoland": return brand("Videoland", 0xFF334B)
        case "pathethuis": return brand("PatheThuis", 0xFFC426)
        case "npostart": return brand("NPOStart", 0xFC6C00)
        case "nlziet": return brand("NLZiet", 0xFF3880)
        default: return nil
        }
    }

    private static func brand(_ asset: String, _ color: UInt32) -> Self {
        Self(assetName: "StreamingLogo" + asset, color: color)
    }
}
