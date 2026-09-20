# Veyra Sportcentrum

Actieve bronmap: `/Users/stinus/Developer/Veyra`.

Home toont maximaal twaalf wedstrijden van vandaag, eerst livewedstrijden, dan het programma en uitslagen. Favorieten krijgen binnen die groepen voorrang. SPORT opent alle wedstrijden met dagkeuze, competitie, Live/Programma/Uitslagen en Mijn teams. Open een wedstrijd om een team te volgen; voorkeuren blijven lokaal bewaard. De Live TV-knop opent het eigen zenderaanbod en koppelt geen uitzending automatisch aan een wedstrijd.

Startcompetities, bevestigd door de gebruiker: Belgische Pro League, Champions League, Europa League, NFL, College Football en NBA. Er zijn geen voorkeuren of accountgegevens uit Strand geïmporteerd. De interface is eigen SwiftUI-code voor Veyra; geen assets of code van Strand.

## Databron en onderhoud

`SportsScoreProvider` scheidt de bron van modellen en schermen. De huidige persoonlijke prototype-adapter leest de openbare ESPN-scoreboardfeed. Dit is geen officiële commerciële API-overeenkomst en biedt geen gegarandeerde beschikbaarheid, actualiteit of volledige dekking. Er zijn geen sleutels, accounts, tracking-SDK's, teamlogo's of streaminglinks toegevoegd.

De zichtbare schermen vernieuwen elke 60 seconden wanneer de app actief is. Dagselectie gebruikt de tijdzone van het apparaat; de adapter haalt overlappende Amerikaanse Eastern-dagen op en filtert lokaal. Een geslaagde lege response betekent geen wedstrijden; netwerkfouten worden apart getoond. Bij uitval blijven bekende scores alleen voor dezelfde dag bewaard met een melding dat ze niet actueel zijn. Geplande wedstrijden tonen geen fictieve 0–0-stand.

Voor commercialisering/publicatie: sluit een passende sportdatalicentie af en vervang de adapter, eventueel via de eigen Oracle-backend. Toegang tot een publiek endpoint op zichzelf bewijst geen hergebruikrechten. Apple vereist toegestane toegang/hergebruik van externe diensten (5.2.2); een geslaagde build is geen App Store-goedkeuring.

Bronnen gecontroleerd op 17 september 2026:
- https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard
- https://developer.apple.com/app-store/review/guidelines/#intellectual-property

## Controle

`Tests/run-sports-checks.sh` controleert gepland/live/afgelopen/uitgesteld, thuis/uit-volgorde, teamidentiteit over competities, lokale favorieten, netwerkuitval en afzonderlijke dagen.

`Tests/run-sports-checks.sh --live` controleert ook alle zes echte feeds en verifieert dat de teruggegeven wedstrijden op de lokale huidige dag vallen. Hiervoor is netwerktoegang nodig; nul wedstrijden is geldig buiten speeldagen/seizoenen.

## Verificatie 17 september 2026

Sporttests en alle zes echte feeds geslaagd. Ondertekende tvOS-build en arm64 Apple TV-simulatorbuild geslaagd. De generieke simulatorbuild voor zowel Intel als Apple Silicon kan niet linken door de bestaande arm64-only LibDovi-bibliotheek; bouw voor de concrete Apple Silicon-simulator. Device Hub geeft een time-out via de UI-bediening, waardoor visuele focuscontrole nog niet is bevestigd.

De definitieve ondertekende build is via de LaunchAgent geslaagd. De bijgewerkte app is geïnstalleerd en gestart in de simulator. Installatie op de fysieke Woonkamer is op 17 september rond 23:02 nog niet bevestigd: zowel de achtergrondservice als een rechtstreekse devicectl-poging kregen een verbroken CoreDevice-verbinding. De updater blijft actief en probeert installatie elke minuut opnieuw.

Update 23:03:08: de automatische herpoging is geslaagd. Build 2 is geïnstalleerd en gestart op Woonkamer; de opgeslagen bronbestanden komen overeen met de gedeployde fingerprint. Visuele focuscontrole blijft onbevestigd door de Device Hub-time-out.
