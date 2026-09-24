# Veyra commercieel maken: checklist

Dit is een technische en praktische checklist, geen juridisch advies. Laat licenties en voorwaarden controleren
voordat je iets verkoopt. Voorwaarden veranderen; controleer altijd de actuele tekst bij de aanbieder.

## 1. Home per gebruiker (gebouwd)

- `Shared/Bento/VeyraHomeLayout.swift`: indeling (volgorde, aan/uit, Sport, planken, preset) als één JSON-document
  in `UserDefaults` (`veyra.home.layout`). Synct via VeyraHub (`VeyraHubSyncService`, sleutels `veyra.home.layout`,
  `veyra.home.presetChosen`, `veyra.bento.streaming`, `veyra.bento.collections`).
- `BentoProfile.make(_:order:)` (`VeyraBentoLayout.swift`): legt de zichtbare blokken op volgorde in rijen; er vallen
  geen gaten als een blok ontbreekt of verborgen is.
- Blokken zonder inhoud verschijnen niet (bv. Live nu zonder IPTV, Verder kijken zonder Trakt).
- Presets bij de eerste start (`VeyraHomePresetPickerView`) en in Instellingen > Home > Indeling.
- Lang indrukken op een blok (iOS): eerder, later of verbergen. Op tvOS via Instellingen.
- Streamingdiensten en filmcollecties: eigen lijst, volgorde, namen, logo's en banners.

Nog te doen: dagdeel- of gezinsprofielen (een layout per profiel), en herschikken door slepen op Home zelf.

## 1b. Gateway-naad (gebouwd)

`Shared/Core/Configuration/VeyraEndpoints.swift` bevat de basisadressen van TMDB, fanart.tv en de sportbron. Standaard
gaat de app rechtstreeks naar de bron; vul `veyra.gateway.url` (https) in en alles loopt via één gateway
(`<gateway>/tmdb/3/...`, `<gateway>/fanart/v3/...`, `<gateway>/sports/...`). Nog rechtstreeks: `TMDBClient`,
`SeriesService` (host-gebaseerd), Trakt en afbeeldingsadressen (`image.tmdb.org`).

## 2. Licenties en voorwaarden per gegevensbron

| Bron | Gebruik in Veyra | Aandachtspunt voor een betaald product |
|---|---|---|
| TMDB | Posters, releases, streamingaanbieders, collecties | Gratis API is bedoeld voor niet-commercieel gebruik. Voor een betaalde app een commerciële overeenkomst regelen en de verplichte vermelding (attribution) tonen. |
| fanart.tv | Banners en clearlogo's | Gratis voor persoonlijk gebruik; voor commercieel gebruik betaald abonnement of toestemming nodig. |
| Trakt | Verder kijken, kalender, lijsten, bekeken-status | Voorwaarden voor commerciële apps nalezen. Limiet: 1000 GET-aanvragen per 5 minuten per IP/app; bij veel gebruikers aanvragen bundelen of cachen op VeyraHub. |
| ESPN scoreboard | Sport (wedstrijden, logo's) | Niet-officiële, ongedocumenteerde API zonder licentie voor product. Vervangen door een gelicenseerde sportdata-bron. De app gebruikt al een aparte provider (`SportsScoreProvider` / `SportHomeProviding`), dus de UI hoeft niet te veranderen. |
| IPTV / addons | Zenders, VOD, streams | De app levert zelf geen content of zenderlijsten; de gebruiker voegt alles zelf toe. Geen voorgeconfigureerde providers of addons meeleveren. |
| Team- en competitielogo's | Sportkaders | Merkrechten liggen bij de organisaties; bij een gelicenseerde sportbron zitten logo's meestal in de licentie. |
| Fonts, iconen (SF Symbols) | UI | SF Symbols alleen op Apple-platformen en volgens Apple-voorwaarden. |

## 3. Techniek voor schaal

1. **Eén Hub-endpoint voor gedeelde data.** Logo's, catalogi en sportprogramma's via VeyraHub in plaats van dat elke
   app apart TMDB, ESPN en fanart aanroept: één plek voor sleutels, caching, limieten en licentiebeheer.
2. **API-sleutels niet in de app.** De TMDB- en fanart-sleutel nu uit `Secrets.xcconfig`; bij een product achter de Hub
   zetten, zodat ze niet uit de app te halen zijn.
3. **Remote config.** Presets of nieuwe blokken zonder app-update aanzetten (een kleine JSON van de Hub).
4. **Taal.** Alle teksten staan nu vast in het Nederlands. Naar `String Catalog` (`Localizable.xcstrings`) verhuizen
   voordat je buiten NL/BE verkoopt.
5. **Privacy.** Trakt-tokens, IPTV-gegevens en kijkgedrag: privacybeleid, dataverwerking en verwijderen op verzoek
   regelen (AVG). Wat via VeyraHub synct, staat op jouw server.
6. **Toegankelijkheid.** VoiceOver-labels en Dynamic Type controleren op de nieuwe blokken.
7. **App Store.** Een app die zelf geen content levert, maar streams van de gebruiker afspeelt, wordt strenger
   beoordeeld; formuleer de omschrijving als mediaspeler en organizer, en beschrijf duidelijk dat de gebruiker
   zijn eigen bronnen toevoegt.

## 4. Volgorde

1. Home-indeling per gebruiker (klaar) en testen met echte gebruikers.
2. Licenties voor TMDB, fanart.tv en een sportdata-bron regelen.
3. Gedeelde data achter VeyraHub zetten.
4. Localisatie en privacybeleid.
