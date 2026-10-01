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
    /// Harde bovengrens op de volledige bronresolutie. Elke individuele
    /// netwerkaanvraag heeft al een eigen timeoutInterval, maar als één
    /// bron (addon/IPTV/Jellyfin) daar toch voorbij hangt (trage server,
    /// hoop accounts na elkaar, ...) dan bleef de "Volgende aflevering"-knop
    /// tot nu toe onbeperkt op "Volgende aflevering zoeken…" staan, omdat
    /// de tuple-await op alle drie wacht. Door hier te racen tegen een
    /// sleep-task nemen we gewoon het eerst klare resultaat (net als de
    /// per-addon-timeout op VeyraHub) i.p.v. voor altijd te wachten.
    private static let overallTimeout: Duration = .seconds(12)

    static func resolve(matching current: PlayableSource, for item: MediaItem) async -> PlayableSource? {
        guard let providerName = current.providerName, !providerName.isEmpty else { return nil }

        let resolver = SourceResolver()

        // Zelfde drie bronnen bevragen als `SourceSelectionViewModel`,
        // maar dan voor de volgende aflevering, en parallel om geen extra
        // netwerk-vertraging op te lopen t.o.v. het bronkeuzescherm.
        let combinedValues: [ResolvedSource] = await withTaskGroup(of: [ResolvedSource]?.self) { group in
            group.addTask {
                async let addonValuesTask = resolver.addonSources(for: item)
                async let iptvValuesTask = resolver.iptvSources(for: item)
                async let jellyfinValuesTask = resolver.jellyfinSources(for: item)
                let (addonValues, iptvValues, jellyfinValues) = await (addonValuesTask, iptvValuesTask, jellyfinValuesTask)
                return addonValues + iptvValues + jellyfinValues
            }
            group.addTask {
                try? await Task.sleep(for: overallTimeout)
                return nil
            }
            // Neem wat het eerst klaar is -- bij een timeout dus een lege
            // lijst (en de nog hangende bron-taak wordt daarna geannuleerd
            // i.p.v. afgewacht).
            let first = (await group.next()) ?? nil
            group.cancelAll()
            return first ?? []
        }

        // Zelfde provider (addon/mediaserver/IPTV) én zelfde soort bron —
        // een gelijknamige provider van een ander type zou toevallig
        // kunnen matchen, maar is nooit "dezelfde bron".
        let candidates = combinedValues
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
