# Automatisch bijwerken op iPad en iPhone

Zelfde principe als Woonkamer (zie `WOONKAMER.md`), maar dan voor de iOS-app
(`Veyra-iOS`) op je persoonlijke toestellen.

Actief project: `/Users/stinus/Developer/Veyra`.
- iPad (10e generatie), apparaat `00008101-000618C4220A601E`.
- iPhone van Stijn (iPhone 17), apparaat `00008150-001A62D8218A401C`.

Beide gebruiken hetzelfde script (`Tools/ios_autodeploy.py`), elk als eigen
LaunchAgent met eigen status- en logbestanden, zodat een build voor het ene
toestel het andere niet blokkeert.

Een lokale macOS LaunchAgent per toestel controleert `Veyra-iOS/`, `Shared/`,
de Xcode-projectinstellingen en xcconfig-bestanden elke drie seconden. Na acht
seconden zonder nieuwe wijzigingen bouwt hij de iOS-app voor dat fysieke
toestel. Alleen een geslaagde build waarvan de bronbestanden intussen niet
veranderden wordt geinstalleerd. Daarna wordt Veyra opnieuw gestart, wat een
lopende afspeelsessie kan onderbreken.

Dit werkt zolang de Mac aan staat, je bent ingelogd, Xcode kan ondertekenen
en het toestel bereikbaar is (WiFi-ontwikkeling of aangesloten). Het is geen
TestFlight- of App Store-publicatie.

## Status en bediening

- iPad status: `~/Library/Application Support/Veyra/iPad/status.json`
- iPhone status: `~/Library/Application Support/Veyra/iPhone/status.json`
- Ondertekende apps: `.../Build/Build/Products/Debug-iphoneos/Veyra-iOS.app`
  in de map van het betreffende toestel.
- Logs staan in dezelfde toestel-map. Buildlogs kunnen lokale configuratie
  bevatten: niet delen of committen.

Pauzeren: maak `PAUSED` aan in de statusmap van dat toestel. Hervatten:
verwijder dat bestand.

De agents staan in `~/Library/LaunchAgents/com.veyra.ipad.autodeploy.plist`
en `~/Library/LaunchAgents/com.veyra.iphone.autodeploy.plist`, en starten
opnieuw na aanmelden op deze Mac. Helemaal stoppen kan met:
```
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.veyra.ipad.autodeploy.plist
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.veyra.iphone.autodeploy.plist
```

## Zelf aan- en uitzetten

Open in Finder de map `/Users/stinus/Developer/Veyra/Tools` en dubbelklik op
`iPad - Aan.command` / `iPad - Uit.command` of `iPhone - Aan.command` /
`iPhone - Uit.command`. Aan activeert de LaunchAgent van dat toestel en heft
PAUSED op. Uit pauzeert, stopt en schakelt de service ook voor volgende
aanmeldingen uit. De huidige app blijft geinstalleerd.

Deze bestanden zijn alleen aangemaakt; elke updater blijft uit totdat je
"Aan" voor dat toestel uitvoert.

## Opmerking: draadloze installatie

`xcrun devicectl device install app` werkt zowel via kabel als via WiFi-
ontwikkeling, zolang het toestel in Xcode al eens over WiFi is gekoppeld
(Window > Devices and Simulators > "Connect via network" aangevinkt) en op
hetzelfde netwerk zit als de Mac. Is dat niet ingesteld, dan moet het toestel
aangesloten zijn op het moment dat de watcher wil installeren.

## Bugfix in de Woonkamer-watcher (19 september 2026)

De vingerafdruk (fingerprint) van `woonkamer_autodeploy.py` controleerde tot
nu toe alleen de map `Veyra/` en het Xcode-project, niet `Shared/`. Aangezien
veel logica (IPTV, Trakt, Jellyfin, Sport) in `Shared/` staat, werden
wijzigingen daar niet automatisch naar Woonkamer uitgerold. Dit is gecorrigeerd
door `Shared/` aan de fingerprint toe te voegen. Herstart de Woonkamer-watcher
(Uit dan Aan) zodat de gecorrigeerde versie wordt geladen.
