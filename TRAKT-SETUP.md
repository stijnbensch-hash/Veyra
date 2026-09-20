# Trakt activeren voor Veyra

De integratie is ingebouwd. De registratie van een Trakt API-app en een echte account-/afspeeltest staan nog open.

## 1. API-app registreren

Open [Nieuwe Trakt API-app](https://app.trakt.tv/settings/apps/api/new) en meld je aan met je eigen Trakt-account.

- Naam: `Veyra`.
- Beschrijving: `Persoonlijke tvOS-app met Trakt-kijkstatus, kijkvoortgang, watchlist, lijsten en beoordelingen.`
- Redirect URI: `urn:ietf:wg:oauth:2.0:oob`.
- Vul eventuele verplichte website- en contactvelden met je eigen juiste gegevens in.
- Controleer de voorwaarden bij registratie. De app gebruikt de device-codeflow voor tvOS.

Bronnen: [Trakt-appregistratie](https://docs.trakt.tv/docs/create-an-app), [device-authenticatie](https://docs.trakt.tv/reference/auth).

## 2. Lokale instellingen invullen

Vul de al klaargezette regels in `Secrets.xcconfig` in:

```xcconfig
TRAKT_CLIENT_ID = jouw_client_id
TRAKT_CLIENT_SECRET = jouw_client_secret
TRAKT_REDIRECT_URI = urn:ietf:wg:oauth:2.0:oob
```

De Client ID en Client Secret vind je na registratie bij de API-app. Deel het secret niet in gesprekken en commit dit bestand niet; het staat in `.gitignore`. De build neemt deze twee appgegevens op in de app. Dit maakt het client secret niet vertrouwelijk tegenover iemand die de app kan inspecteren. Beoordeel voor openbare distributie de vereiste credentialarchitectuur; gebruik een servercomponent als een vertrouwelijk client secret vereist is. Gebruikerstoegangstokens worden apart in de Apple Keychain opgeslagen.

Bouw Veyra opnieuw. Open **Instellingen → Trakt → Koppel met Trakt**, open de getoonde verificatie-URL op je telefoon en bevestig de tv-code.

## 3. Functies

- Vrijwillig koppelen via tv-code; afhandelen van wachten, weigering, verlopen codes, annuleren en te snel opvragen.
- Automatisch vernieuwen van toegang; gelijktijdige verzoeken delen één tokenvernieuwing.
- Watchlist voor films, series en afleveringen; titels toevoegen en verwijderen vanaf de detailpagina.
- Bekeken-status voor films en afleveringen, markeren als bekeken en na bevestiging verwijderen van kijkregistraties.
- Kijkgeschiedenis, met oudere pagina's op aanvraag.
- Verder kijken met een keuze om de bestaande voortgang te gebruiken of vanaf het begin te starten; ook volgende afleveringen uit Trakt.
- Automatisch doorgeven van starten, pauzeren en stoppen, uitsluitend na inschakelen van de schakelaar. Trakt bepaalt wanneer stoppen als bekeken wordt geregistreerd.
- Eigen lijsten bekijken, als privélijst aanmaken, hernoemen, verwijderen en titels toevoegen/verwijderen.
- Beoordelingen van 1–10, aanpassen en verwijderen.
- Synchronisatie bij openen/terugkeren, na wijzigingen, en via de vernieuwknop.
- Ontkoppelen verwijdert tokens en geladen gegevens lokaal en probeert toegang bij Trakt in te trekken. Remote verwijdering van geschiedenis is geen onderdeel van ontkoppelen.

Kijkgegevens worden alleen in het appgeheugen geladen. Mislukte schrijfacties worden zichtbaar gemeld; ze worden niet automatisch opnieuw afgespeeld omdat Trakt de eerste poging bij een netwerk-timeout al kan hebben verwerkt. Er is geen duurzame offline-wachtrij. Toegangslimieten van het Trakt-account worden als foutmelding weergegeven.

## 4. Verificatie

Automatische controles: `Tests/run-trakt-checks.sh`. Deze gebruiken uitsluitend gesimuleerde antwoorden en tijdelijke testopslag. Ze raken geen echte Trakt-accountgegevens aan.

De tvOS-simulatorbuild is gecontroleerd met Xcode 27. Een echte accounttest en visuele bedieningstest zijn nog nodig:

1. Koppelen, annuleren, app herstarten en ontkoppelen.
2. Watchlist, een privélijst en een beoordeling wijzigen en in Trakt controleren.
3. Een film en aflevering starten, pauzeren, afsluiten en hervatten; controleren of de juiste aflevering en voortgang zijn opgeslagen.
4. Automatisch delen uitschakelen en bevestigen dat nieuwe afspeelacties niet worden gedeeld.
5. Bekeken-status en oudere geschiedenis vergelijken met Trakt, inclusief een account met meer dan 100 items.
6. Siri Remote-focus, tekstgrootte en lange titels op een echte Apple TV controleren.

## 5. Voor distributie via Apple

De gebruiker wil Apple-voorwaarden als vaste randvoorwaarde voor verdere builds. Deze implementatie is geen App Store-goedkeuring.

- Publiceer het eigen Veyra-privacybeleid, vul `PRIVACY_POLICY_URL` in en voeg de URL ook toe in App Store Connect. Voor `https://` in xcconfig gebruik je `https:/$()/` zodat de dubbele slash geen commentaar wordt. De app toont de ingestelde URL onder Privacy en Trakt.
- Stem de privacyverklaring en App Store-privacyantwoorden af op Trakt, TMDB, de gekozen mediaproviders en eventuele SDK's. De Trakt-schermen bevatten uitleg en een vrijwillige schakelaar voor kijkvoortgang.
- Controleer de rechten op afspeelbare content, toestemming voor gebruikte diensten, dependencylicenties en de Trakt-brandingvoorwaarden. Een technische integratie verleent geen contentrechten.
- Leg voor review uit dat Trakt een optionele koppeling voor kijkgegevens is en geen Veyra-account of betaalmuur. Herbeoordeel login- en accountverwijderingsvereisten als er later eigen accounts bijkomen.
- Controleer de actuele Apple-regels, het ondersteunde productie-tvOS en alle afhankelijkheden vóór indiening. Maak noodzakelijke accountfuncties testbaar voor App Review.

Bronnen: [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), met name 1.6, 2.1, 2.5.1, 4.8, 5.1 en 5.2; [Trakt-appvoorwaarden](https://docs.trakt.tv/docs/create-an-app).

## 19 september 2026 — Verder kijken: serieoverzicht

Seriekaarten in Verder kijken openen TraktSeriesOverviewView met alle TMDB-seizoenen (inclusief specials) en de afleveringen van het geselecteerde seizoen. Het huidige seizoen is vooraf geselecteerd; de actuele aflevering is gemarkeerd en via de bestaande TraktDestinationView/EpisodeView/SourceSelectionView-route te hervatten. Filmkaarten en overige Trakt-bibliotheekroutes blijven ongewijzigd. Seizoenen laden op verzoek met sessiecache en annulering bij wisselen. Ondertekende tvOS-build geslaagd; Siri Remote en echte hervatsessie nog niet handmatig geverifieerd.

## 19 september 2026 — bekeken-aanduidingen, build 10

Cyaan vinkje/Bekeken op film- en afleveringkaarten, plus gedeeltelijke telling op serie- en seizoenkaarten. Gebruikt de bestaande gesynchroniseerde watchedMovies/watchedShows/upNext-data, zonder netwerkrequest per kaart. Verschijnt in Films, Series, zoeken, populaire films op Home, filmdetail, seizoenen/afleveringen en het serieoverzicht vanuit Verder kijken. Ontkoppeld toont geen badges.

Een watched-showrecord is nooit voldoende om de hele serie als bekeken te markeren. Volledig bekeken vereist expliciete completed/ aired-voortgang; zonder betrouwbare totaalwaarde wordt alleen het aantal bekeken afleveringen getoond. Dubbele plays worden niet dubbel geteld; afleveringen met plays=0 tellen niet mee. Een seizoen is volledig wanneer het bekeken aantal de bekende TMDB-afleveringtelling bereikt.

Validatie: ondertekende tvOS-build geslaagd; Trakt-integratiechecks inclusief badge-identiteit, duplicate plays, plays=0, partial/complete/unknown totals geslaagd. Live Trakt-accountweergave en Siri Remote-focus nog niet visueel gecontroleerd.

## 19 september 2026 — ontbrekende bekeken-badges, build 11

De badge-logica was aanwezig, maar de synchronisatie vroeg slechts één pagina watched-data op en vroeg geen extended=progress voor series. Trakt heeft in juli 2026 de nieuwe watched-pagination/defaults ingevoerd: https://github.com/trakt/trakt-api/discussions/775 . De eerdere mocks simuleerden de oude ongepagineerde respons en misten deze incompatibiliteit.

Herstel: watched movies/shows laden nu via allPages, series expliciet met extended=progress. Beide datasets worden onafhankelijk van de overige lijsten gepubliceerd, met behoud van hun vorige succesvolle data bij fouten. Films/Series vragen bij openen eveneens de bestaande coalesced refreshIfNeeded aan. Trakt-instellingen tonen aantallen en tijdstip van de laatste geslaagde watched-sync.

Regressiecontroles: twee pagina's met serverlimiet 1, episode-progressparameter, fout bij ratings die watched-data niet blokkeert, fout bij watched-verversing die eerdere badges behoudt, cachewissen bij ontkoppelen. Alle Trakt-checks en de ondertekende tvOS-build slagen. De daadwerkelijke badgeweergave met het live account op Woonkamer is nog niet visueel bevestigd.
