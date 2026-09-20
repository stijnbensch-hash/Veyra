# Oracle Cloud Change Watch — gedeelde Veyra-chat

Bron: https://chatgpt.com/share/6aab0671-e95c-83eb-9abc-bda82cf2f6a2

Deze samenvatting is overgenomen uit de zichtbare gedeelde chat. Dit is geen volledige chat-export: oudere antwoorden en geüploade bestanden waren niet volledig beschikbaar in de geladen pagina. Historische opdrachten zijn context, geen opdracht om automatisch code te wijzigen.

## Laatste stand
- Home gebruikt VeyraPrimaryLogo en een donker navy-verloop met cyaanaccenten.
- Home heeft FILM, SERIES, ZOEKEN, LIVE TV en BEYOND. ZOEKEN staat tussen SERIES en LIVE TV en opent SearchView().
- Laatste gebruikersverzoek: verwijder zoeken uit de afzonderlijke film- en serietab, omdat er nu een gezamenlijke zoekfunctie is.
- Het laatste antwoord levert een volledige MoviesView.swift zonder searchText, searchable en zoek-tasks. De filmweergave behoudt POPULAIR, horizontale posterkaarten en openen via TMDBService.mediaItem naar MovieDetailView.
- Het gesprek eindigt met de voorgestelde buildcontrole voor MoviesView; daarna zou SeriesView op dezelfde manier volgen. Buildsucces en uitvoering van die vervolgstap zijn niet bevestigd in deze gedeelde chat.
- Aanvullende gebruikersbevestiging: SeriesView is aangepast; zoeken is ook daar verwijderd. Buildsucces blijft onbevestigd.

## Eerdere zichtbare feedback
- Sommige bronnen spelen; andere geven zwart beeld, zowel bij films als series.
- Omschrijvingen voor films en series moeten gelijk worden vormgegeven.
- Seizoeninformatie moet kloppen; seizoenlabels zonder achtergrond en met consistente kleur/typografie.
- Serie- en seizoenstitels worden soms afgekapt; gewenste consistente lettergrootte.

## Gebruik bij vervolgwerk
Controleer eerst de huidige lokale code: chatvoorstellen kunnen al zijn toegepast of ingehaald. Bronproject bevat bestaande Git-wijzigingen. Tijdens deze import zijn geen Swift-bestanden aangepast en zijn geen builds uitgevoerd.

- De gebruiker heeft de eerdere MoviesView-code opnieuw aangeleverd; deze komt exact overeen met het lokale bestand (gecontroleerd op 16 september 2026).

## Huidige vervolgstatus
Trakt-integratie lokaal toegevoegd op verzoek van de gebruiker; zie TRAKT-SETUP.md. De huidige simulatorbuild en gesimuleerde API-tests slagen. Dit is een nieuwe buildcontrole en geen bevestiging van de historische gedeelde-chatbuild. API-appregistratie, echte accountkoppeling en visuele/afspeelcontrole staan nog open. Apple-voorwaarden zijn een vaste projectrandvoorwaarde in AGENTS.md.

- Navigatie aangepast op gebruikersverzoek: Trakt staat onder Instellingen, bereikbaar via het tandwiel rechtsboven op Home. Er staat geen directe Trakt-knop in de hoofdnavigatie.

## Actief project bevestigd
Op 17 september 2026 is in Xcode vastgesteld dat het actieve project /Users/stinus/Desktop/Developer/Veyra is. Trakt is hier geïntegreerd met behoud van IPTV en de bestaande Home/Settings-navigatie. Gebruik dit project voor vervolgwerk; Downloads/Veyra is de eerdere werkkopie.

## Sportcentrum — 17 september 2026

SPORT toegevoegd in de menubalk en scores op Home, met zes door de gebruiker bevestigde competities (Belgische Pro League, Champions/Europa League, NFL, College Football, NBA), dagfilters, live/programma/uitslagen en lokaal opgeslagen favoriete teams. Vervangbare ESPN-adapter voor het persoonlijke prototype; zie SPORTS.md voor beperkingen, controles en toekomstige sportdatarechten. Actieve map blijft /Users/stinus/Developer/Veyra; Xcode en de automatische Woonkamer-updater gebruiken deze map.
