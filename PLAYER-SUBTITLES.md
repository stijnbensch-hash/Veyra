# Ondertitels in de speler

Tijdens afspelen: klik of veeg op de Siri Remote om **Ondertitels** te tonen. Open de knop, kies een beschikbaar spoor of **Uit**. Terug sluit eerst het ondertitelpaneel. Het paneel staat boven dezelfde videosurface; wisselen heropent de stream niet. De knop verdwijnt na zes seconden. Play/Pause bedient de bestaande engine.

De lijst observeert de actuele `subtitleTracks` van de geladen AetherEngine en selecteert met `track.id` (niet de positie in de lijst). De taal wordt waar mogelijk in het Nederlands getoond, naast spoortitel, codec en forced/SDH-informatie. Een stream zonder sporen krijgt een expliciete lege melding.

Voor sporen die de backend zelf rendert, tekent Veyra geen tweede ondertitel. De overige tekst- en bitmapcues worden getoond op basis van `sourceTime`, met een halfopen begin-/eindtijdinterval. Bitmapondertitels houden rekening met het bronformaat, niet-vierkante pixels en de ondertitelcanvas. Tekst gebruikt een leesbare witte stijl; volledige ASS-typesetting/animaties en oorspronkelijke rich-textkleuren zijn in deze eerste overlay niet gereproduceerd. Er is geen externe zoek- of downloaddienst toegevoegd.

De selectie geldt voor de lopende afspeelsessie. De uit-knop wist ook eventuele secundaire ondertitels. Beschikbare sporen en decodeerbare codecs zijn afhankelijk van de stream en AetherEngine.

Validatie: compileer de tvOS-app; controleer op Woonkamer een stream met meerdere talen, Uit, opnieuw inschakelen, verder afspelen tijdens het paneel en een stream zonder ondertitels. De praktijkcontrole met een echte stream is nog niet bevestigd.

## 19 september 2026 — standaardtaal en OpenSubtitles

Instellingen → Ondertitels bevat een opgeslagen standaardtaal (Nederlands bij eerste gebruik), de bestaande opt-in voor OpenSubtitles en veilige API-sleutelopslag via VeyraAPIKeyStore. De speler geeft de gekozen taal plus ISO-aliases aan Aether door. De andere ingebedde sporen blijven selecteerbaar.

Als de voorkeurstaal ontbreekt in de stream en OpenSubtitles ingeschakeld/geconfigureerd is, wordt één passend resultaat automatisch opgehaald. In de speler kan de gebruiker per taal zoeken en een resultaat downloaden/selecteren zonder de opgeslagen voorkeur te wijzigen. Handmatige selectie/Uit wordt niet door een lopende automatische download overschreven. Nieuwe afspeelsessies wissen de registratie; geannuleerde verzoeken kunnen geen sporen aan een volgende sessie toevoegen.

De instellingen lichten toe welke metadata naar OpenSubtitles gaat (IMDb, seizoen/aflevering en taal); de bestaande vrijwillige schakelaar blijft behouden. Apple privacyrichtlijn gecontroleerd: https://developer.apple.com/app-store/user-privacy-and-data-use/ . Geen claim van App Store-goedkeuring.

Validatie: ondertekende tvOS-build en Tests/run-subtitle-checks.sh (voorkeur/opslag/ISO-aliases/fallback plus OpenSubtitles-taalrequest en resultaat via mock netwerk). Echte OpenSubtitles-download, timing van ondertitels en Siri Remote-focus moeten nog met een stream op de Apple TV worden bevestigd.

Ook de dubbele AddonStore-verwijzing uit de Xcode-build verwijderd. De alternatieve versie met andere opslagnaam is bewaard in Backups/AddonStore-duplicate-20260918; de oorspronkelijke addonopslag bleef ongewijzigd.
