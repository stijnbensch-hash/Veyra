# Automatisch bijwerken op Woonkamer

**Huidige status:** INGESCHAKELD. De gebruiker bevestigde op 18 september 2026 dat hij de updater zelf opnieuw had aangezet. De service is hervat; zie status.json voor het actuele bouw- en installatieresultaat.

Actief project: `/Users/stinus/Developer/Veyra`.
Apple TV: **Woonkamer**, apparaat `00008110-000A02290C11801E`.

Een lokale macOS LaunchAgent controleert de opgeslagen appbestanden, assets, Xcode-projectinstellingen en xcconfig-bestanden elke drie seconden. Na acht seconden zonder nieuwe wijzigingen bouwt hij de app voor de fysieke Apple TV. Alleen een geslaagde build waarvan de bronbestanden intussen niet veranderden wordt geïnstalleerd. Daarna wordt Veyra opnieuw gestart, wat een lopende afspeelsessie kan onderbreken.

Dit werkt zolang de Mac aan staat, je bent ingelogd, Xcode kan ondertekenen en Woonkamer bereikbaar is. Het is geen TestFlight- of App Store-publicatie. Niet-opgeslagen editorwijzigingen en instellingen die je alleen binnen de draaiende app aanpast worden niet door deze watcher overgenomen.

Bij een bouwfout wordt pas na een nieuwe bestandswijziging opnieuw gebouwd. Bij een mislukte installatie of start volgt na een minuut een nieuwe poging. Geen andere apps of apparaten worden aangepast. De eerdere app blijft bij een bouwfout geïnstalleerd.

## Status en bediening

Status: `~/Library/Application Support/Veyra/Woonkamer/status.json`.
Ondertekende app: `~/Library/Application Support/Veyra/Woonkamer/Build/Build/Products/Debug-appletvos/Veyra.app`.
Lokale logs staan in dezelfde Woonkamer-map. Buildlogs kunnen lokale configuratie bevatten: niet delen of committen.

Pauzeren: maak het bestand `~/Library/Application Support/Veyra/Woonkamer/PAUSED` aan. Een lopende build kan afronden, maar er volgt geen nieuwe installatie zolang dit bestand bestaat.
Hervatten: verwijder dat PAUSED-bestand. Maak meerdelige codewijzigingen bij voorkeur terwijl de watcher gepauzeerd is.

De agent staat in `~/Library/LaunchAgents/com.veyra.woonkamer.autodeploy.plist` en start opnieuw na aanmelden op deze Mac. Helemaal stoppen kan met `launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.veyra.woonkamer.autodeploy.plist`.

De functionaliteit voor foutafhandeling en het voorkomen van verouderde installaties is lokaal getest in `test_woonkamer_autodeploy.py`.

## Controle na verplaatsing — 17 september 2026

De LaunchAgent start nu correct vanuit Developer en de ondertekende build slaagt. De strenge Background-procesklasse is verwijderd omdat deze Xcode-pakketverwerking ernstig vertraagde. Bestaande vastgelegde pakketversies worden hergebruikt met disableAutomaticPackageResolution en skipPackageUpdates. Vijf lokale workertests slagen. De laatste fysieke installatiepoging voor Sportcentrum kreeg een CoreDevice-verbindingsreset; de service probeert iedere minuut opnieuw. Controleer status.json voor de actuele uitkomst.

**Bevestigd om 23:03:08:** de automatische herpoging is geslaagd: bijgewerkt en gestart op Woonkamer. De bronfingerprint is gelijk aan het opgeslagen actieve project. De service blijft actief voor volgende wijzigingen.

## Zelf aan- en uitzetten

Open in Finder de map `/Users/stinus/Developer/Veyra/Tools` en dubbelklik op `Woonkamer - Aan.command` of `Woonkamer - Uit.command`. Aan activeert de LaunchAgent en heft PAUSED op. Uit pauzeert, stopt en schakelt de service ook voor volgende aanmeldingen uit. De huidige app blijft geïnstalleerd. Terminal toont de bevestiging. Deze bestanden zijn alleen aangemaakt; de updater blijft uit totdat je Aan uitvoert.
