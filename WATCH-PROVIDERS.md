# Streamingdiensten in Film en Series

Bovenaan beide catalogi staat een horizontale rij echte providerlogo's met naam en een Alle-knop. De lijst wordt per mediatype en land uit TMDB opgehaald. Aanbod start in België; de gebruiker kan BE, NL, US, GB, FR en DE selecteren. Deze landkeuze blijft lokaal opgeslagen en wordt gedeeld door Film en Series. Bij een ander land wordt de providerselectie gewist.

Een provider selecteren vraagt de populairste titels via `/discover/movie` of `/discover/tv` met `with_watch_providers` en `watch_region`. Alle herstelt de bestaande populaire catalogus. Net als de bestaande catalogus toont dit de eerste pagina (maximaal twintig titels); het is geen volledige export van een providerbibliotheek. Annulering en request-identiteit voorkomen resultaten van een eerdere selectie. De logolijst heeft eigen foutafhandeling; de populaire catalogus blijft bruikbaar bij uitval van de providerservice.

De rij toont beschikbaarheidsmetadata, geen accountkoppeling of afspeelrecht. Abonnementen, huur en koop zijn inbegrepen in de beschikbaarheidsfilter; de interface vermeldt dit. Bestaande detail- en afspeelroutes blijven behouden. Er worden geen logo's of code uit OneTV gekopieerd; logo's komen uit het TMDB-providerantwoord en de bestaande TMDB-image-CDN. Bronvermelding JustWatch via TMDB staat zichtbaar onder de rij.

Gecontroleerde documentatie:
- https://developer.themoviedb.org/reference/watch-providers-movie-list
- https://developer.themoviedb.org/reference/discover-movie
- https://developer.themoviedb.org/reference/tv-series-watch-providers
- https://developer.apple.com/app-store/review/guidelines/#intellectual-property

De bestaande API- en merkvoorwaarden blijven relevant bij toekomstige commerciële distributie; deze wijziging geeft geen licentie of App Store-goedkeuring.

Validatie: echte Belgische providerfeeds voor films (66) en series (46) ontvangen; Netflix, Disney Plus en Prime Video aanwezig. Netflix/Prime-discover levert voor beide mediatypen twintig titels op de eerste pagina. Ondertekende tvOS-build gecontroleerd. Visuele Apple TV-controle nog niet bevestigd.

## Vaste logorij — 18 september 2026

Op expliciet verzoek beperkt tot dertien merken, in deze volgorde: Netflix, Prime Video, Disney+, HBO Max, Apple TV+, Paramount+, Hulu, Peacock, Shudder, Discovery+, Starz, MGM+, AMC+. Alleen logo’s in de rij; namen blijven als toegankelijkheidslabels. Opnieuw op het geselecteerde logo drukken wist de filter. Alle merken blijven zichtbaar; beschikbaarheid van titels wordt nog steeds gefilterd op het gekozen land. Waar TMDB meerdere directe regiovarianten heeft wordt de lokale ID gebruikt. Geen extra Amazon-/Apple-resellerkanalen in deze rij.

Beide echte feeds gecontroleerd: exact dertien diensten met logopad en succesvolle Netflix-discover. Tijdens de build werd een dubbel SourceSelectionView-bestand aangetroffen; de nieuwste resolver-versie is behouden met Trakt-resume. De oude versie staat in Backups/SourceSelectionView-before-resolver.swift buiten het app-target.

## Raster en Nederlandse metadata

Film en Series tonen posters in een verticaal scrollend adaptief raster. De providerlogo’s blijven bovenaan staan. De gebruiker bedoelt met alleen NL Nederlandse titels/beschrijvingen, niet alleen Nederlandstalige producties of alleen aanbod uit Nederland. Daarom is de centrale metadatataal nl-NL en blijft het volledige aanbod behouden. De landkeuze beïnvloedt beschikbaarheid, niet de metadatataal. Bij ontbrekende beschrijvingen staat een Nederlandse melding; er is geen nieuwe Franse/Engelse fallback toegevoegd. Zonder Nederlandse titelvertaling kan TMDB de oorspronkelijke eigennaam/titel teruggeven.
