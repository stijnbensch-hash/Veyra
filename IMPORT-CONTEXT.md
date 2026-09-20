# Veyra — lokale projectovername

Bron: /Users/stinus/Desktop/Developer/Veyra
Gesprek: https://chatgpt.com/g/g-p-6aa9f626cd988191bd2eb21eca868458-veyra/c/6aa9c2ab-3b9c-83eb-ac34-ffc333fbb46a

De volledige bestaande projectmap is gekopieerd, inclusief Git-historie, lokale configuratie, assets en niet-gecommitte wijzigingen. De bronmap is niet gewijzigd. Dit is geen volledige export van het ChatGPT-gesprek.

## Productcontext
Native tvOS SwiftUI-product, personal-first en commercial-ready. Eigen branding: donker navy/zwart, zilver en icy blue, V/raven/play-embleem zonder runen. Scheid UI, domeinmodellen, providers en playback. UI spreekt via PlaybackEngine; modulaire MediaSourceProvider-connectors. Toekomstige Usenet/debrid/Live TV-uitbreidingen. Geen betalingen, accounts of analytics toevoegen zonder opdracht. Controleer Apple-voorwaarden en dependencylicenties bij verdere ontwikkeling.

## Laatst zichtbare gesprekstatus
Home heeft FILM, SERIES en centrale ZOEKEN-navigatie. Laatste verzoek: zoeken verwijderen uit film- en serietab. Het gesprek leverde een aangepaste MoviesView.swift aan; de bijbehorende build en SeriesView-aanpassing waren daar nog niet bevestigd. De gekopieerde lokale code is leidend; controleer die voordat je verder wijzigt.

Aanvullende gebruikersbevestiging: SeriesView is inmiddels aangepast; zoeken is ook daar verwijderd. Buildsucces blijft onbevestigd.

## Randvoorwaarde voor vervolgwerk
De gebruiker bevestigt op 16 september 2026 dat bij verdere ontwikkeling en builds rekening moet worden gehouden met de Apple App Store-voorwaarden. Controleer relevante actuele regels bij wijzigingen aan accountkoppelingen, privacy, contentbronnen en distributie. Dit is geen bevestiging van App Store-goedkeuring.

## Overnamecontrole
Alle gekopieerde bestanden zijn byte-voor-byte gecontroleerd. Geen build of functionele wijzigingen uitgevoerd tijdens de import. Secrets.xcconfig bevat lokale configuratie: niet delen of committen. Bestaande Git-wijzigingen zijn behouden.

## Trakt-integratie — 16 september 2026
De gebruiker heeft opdracht gegeven tot de volledige integratie: tv-code, kijkgeschiedenis/status, scrobbling, verder kijken, watchlist, eigen lijsten en beoordelingen. De implementatie staat lokaal. De gebruiker heeft nog geen Trakt API-app geregistreerd; de lege instellingen zijn voorbereid in Secrets.xcconfig. Zie TRAKT-SETUP.md. Accountsynchronisatie is nog niet met echte credentials getest. Automatisch delen van voortgang staat standaard uit en vraagt een vrijwillige keuze in de app.

Verificatie: tvOS 27-simulatorbuild geslaagd en alle gesimuleerde Trakt-controles geslaagd. De app is gestart in de simulator. Visuele controle via de bedieningstool was niet mogelijk (Device Hub-time-out); echte account- en afspeeltests blijven open.

## Aanvulling 17 september 2026
Veyra is voorlopig een persoonlijke app voor privégebruik, met een basis voor mogelijke latere commercialisering. TestFlight en App Store-publicatie zijn nu niet aan de orde. Gewenste richting: een eigen unieke app, integratie met de selfhosted Oracle-omgeving en IPTV, en hoge afspeelkwaliteit. Apple-voorwaarden blijven een ontwerp-randvoorwaarde voor de toekomst.

De gebruiker heeft de Trakt-instellingen in Xcode ingevuld. Client ID, Client Secret en Redirect URI zijn lokaal aanwezig; waarden zijn niet getoond. Echte accountkoppeling via de tv-code moet nog worden bevestigd.

## Actief project bevestigd
Op 17 september 2026 is in Xcode vastgesteld dat het actieve project /Users/stinus/Desktop/Developer/Veyra is. Trakt is hier geïntegreerd met behoud van IPTV en de bestaande Home/Settings-navigatie. Gebruik dit project voor vervolgwerk; Downloads/Veyra is de eerdere werkkopie.

## Woonkamer en appicoon
17 september: Trakt en het nieuwe gelaagde Veyra-appicoon zijn in het actieve Desktop-project geïntegreerd. Geslaagde ondertekende tvOS-build is met devicectl op fysieke Apple TV Woonkamer geïnstalleerd en gestart. Automatische updateworker met vijf geslaagde foutafhandelingstests voorbereid. LaunchAgent is uitgeschakeld wegens macOS/TCC-weigering voor Desktop-maptoegang; wacht op gebruikerskeuze voor ~/Developer/Veyra of expliciete maptoegang. Zie Tools/WOONKAMER.md.

## Definitieve projectlocatie
De gebruiker heeft verplaatsing goedgekeurd naar /Users/stinus/Developer/Veyra om automatische achtergrondbuilds mogelijk te maken. De volledige Desktop-projectmap is hierheen verplaatst; code, Git, IPTV en lokale configuratie zijn behouden.

## Sportcentrum — 17 september 2026

SPORT toegevoegd in de menubalk en scores op Home, met zes door de gebruiker bevestigde competities (Belgische Pro League, Champions/Europa League, NFL, College Football, NBA), dagfilters, live/programma/uitslagen en lokaal opgeslagen favoriete teams. Vervangbare ESPN-adapter voor het persoonlijke prototype; zie SPORTS.md voor beperkingen, controles en toekomstige sportdatarechten. Actieve map blijft /Users/stinus/Developer/Veyra; Xcode en de automatische Woonkamer-updater gebruiken deze map.

## Ondertitels tijdens afspelen — 18 september 2026

Een ondertitelknop en zijpaneel toegevoegd aan de bestaande speler, inclusief Uit, actuele taalsporen en eigen tekst-/bitmapoverlay wanneer de backend niet zelf rendert. Wisselen gebruikt dezelfde engine en opent de stream niet opnieuw. Zie PLAYER-SUBTITLES.md voor bediening en de nog te bevestigen echte-streamcontrole.

## Providerlogo’s — 18 september 2026

Bovenaan Film en Series een dynamische TMDB/JustWatch-providerlogorij toegevoegd met Alle, providerfilter en bewaarde landkeuze (standaard BE). Zie WATCH-PROVIDERS.md. Build 4 is lokaal gebouwd; de Swift-decoder is met beide echte Netflix-catalogi gecontroleerd. De opnieuw actieve updater is gepauzeerd en vervolgens uitgeschakeld conform de laatste expliciete voorkeur; deze versie is niet door ons naar Woonkamer geïnstalleerd.

## Postergrid en taal — 18 september 2026

Film en Series gebruiken een verticale LazyVGrid met bestaande posterkaarten; providerlogo’s blijven bovenaan. De gebruiker verduidelijkt dat NL betrekking heeft op metadata, niet op oorspronkelijke productietaal. Films en series blijven behouden; taalvoorkeur centraal nl-NL, ontbrekende Nederlandse beschrijving krijgt een melding. Een onvertaalde eigennaam/titel blijft mogelijk als TMDB geen Nederlandse titel heeft. Buildversie 6.
