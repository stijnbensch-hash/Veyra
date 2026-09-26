import Foundation

/// Zoekt, voor de "Volgende aflevering"-knop in de player, automatisch
/// dezelfde bron (addon/provider) met zoveel mogelijk dezelfde
/// streameigenschappen (resolutie, kwaliteit, audio, codec, HDR) als de
/// zojuist afgespeelde aflevering — zodat de speler gewoon blijft doorspelen
/// i.p.v. terug te vallen op het bronkeuzescherm.
///
/// `PlayerView` gebruikt dit om, ná `NextEpisodeResolver` de volgende
/// `MediaItem` heeft bepaald, meteen een passende `PlayableSource` te
/// vinden en direct door te spelen. Wordt hier niets (goed genoeg)
/// gevonden bij dezelfde provider, dan valt de aanroeper terug op
/// `SourceSelectionView`.
enum NextEpisodeSourceResolver {
    static func resolve(matching current: PlayableSource, for item: MediaItem) async -> PlayableSource? {
        guard let providerName = current.providerName, !providerName.isEmpty else { return nil }

        let resolver = SourceResolver()

        // Zelfde drie bronnen bevragen als `SourceSelectionViewModel`,
        // maar dan voor de volgende aflevering, en parallel om geen extra
        // netwerk-vertraging op te lopen t.o.v. het bronkeuzescherm.
        async let addonValuesTask = resolver.addonSources(for: item)
        async let iptvValuesTask = resolver.iptvSources(for: item)
        async let jellyfinValuesTask = resolver.jellyfinSources(for: item)
        let (addonValues, iptvValues, jellyfinValues) = await (addonValuesTask, iptvValuesTask, jellyfinValuesTask)

        // Zelfde provider (addon/mediaserver/IPTV) én zelfde soort bron —
        // een gelijknamige provider van een ander type zou toevallig
        // kunnen matchen, maar is nooit "dezelfde bron".
        let candidates = (addonValues + iptvValues + jellyfinValues)
            .map(\.source)
            .filter {
                $0.kind == current.kind
                    && $0.providerName?.caseInsensitiveCompare(providerName) == .orderedSame
            }

        guard !candidates.isEmpty else { return nil }

        // Onder de streams van diezelfde provider de stream kiezen die qua
        // resolutie/kwaliteit/audio/codec/HDR het meest lijkt op wat er
        // net speelde (bv. exact dezelfde releasegroep geeft voor de
        // volgende aflevering meestal weer dezelfde kenmerken).
        return candidates.max { score($0, matching: current) < score($1, matching: current) }
    }

    private static func score(_ candidate: PlayableSource, matching current: PlayableSource) -> Int {
        guard let candidateMeta = candidate.metadata, let currentMeta = current.metadata else { return 0 }

        var score = 0
        if let a = candidateMeta.resolution, let b = currentMeta.resolution, a == b { score += 4 }
        if let a = candidateMeta.quality, let b = currentMeta.quality, a == b { score += 3 }
        if let a = candidateMeta.videoCodec, let b = currentMeta.videoCodec, a == b { score += 1 }
        if !Set(candidateMeta.audio).isDisjoint(with: Set(currentMeta.audio)) { score += 2 }
        if !Set(candidateMeta.languages).isDisjoint(with: Set(currentMeta.languages)) { score += 2 }
        if !Set(candidateMeta.dynamicRange).isDisjoint(with: Set(currentMeta.dynamicRange)) { score += 1 }
        return score
    }
}
