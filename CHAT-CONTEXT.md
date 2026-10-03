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

## Platformafspraak en Home — 3 oktober 2026

De gebruiker vraagt eerdere en toekomstige wijzigingen op tvOS, iPhone, iPad en macOS toe te passen. Deze instructie staat ook in AGENTS.md. Houd dezelfde functionaliteit en stijl aan, met maten en bediening passend bij het scherm.

- Streamingdiensten: compacte horizontale rij bovenaan Home, onder de navigatie; vaste hoogte zodat de inhoud direct aansluit. tvOS gebruikt remote-focus; iPhone/iPad aanraking; Mac hover/toetsenbordfocus. Volledige lokaal gebundelde woordmerken, wit in rust en merkkleur bij interactie. Eigen logo's hebben voorrang.
- Dienstenpagina's: kleinere hero en logo, hogere inhoud, logo's in merkkleur; compacte achtergrond op alle platformen met begrensde decodegrootte. Mac gebruikt het brede posterraster.
- Instellingen → Home → Streamingdiensten: dezelfde woordmerken in lijst, preview en regionale dienstkiezer.
- Home: kleinere zijmarges inclusief Veyra Nu; Verder kijken rangschikt op recente kijkactie of uitgebrachte aflevering, zonder alle progress-items vooraan te groeperen. Afleveringstekst is uit de minikaart verwijderd; de code blijft onder de kaart staan.
- Live sport-zenderkeuze: transparant venster en rijen met alleen een kader op alle platformen, met Sluit op touch/Mac en Terug op tvOS.
- Nachtgloed blijft de gekozen achtergrond; Home-kleur reageert op verticaal scrollen op alle platformen.
- Automatische updaters blijven gepauzeerd tijdens deze sessie; updates worden na geslaagde builds handmatig geïnstalleerd. Dit verzoek wijzigt de ingestelde updaterstatus niet.

Controle: tvOS-, iPhone/iPad- en macOS-targets opnieuw succesvol gebouwd. De compacte dienstenrij is met native SwiftUI gerenderd op 390pt, 1024pt en 1440pt breedte; de inhoud begint direct na respectievelijk 64pt, 72pt en 72pt. Dit is een lay-outcontrole op de Mac, geen fysieke iPad-test. Woonkamer en iPhone zijn handmatig bijgewerkt.

## Films en Series — begrensde hero, 3 oktober 2026

De gebruiker vraagt bij Films en Series in het hoofdmenu de artwork alleen bovenaan binnen de hero te tonen. De vier platformvarianten gebruiken nu Nachtgloed als pagina-achtergrond en `VeyraHeroArtworkBackground` binnen de eerste hero in de verticale scrollinhoud. Alleen die achtergrond wordt afgeknipt, zodat de afbeelding (inclusief zoom/overgang) niet achter filters en posters doorloopt en bij scrollen met de hero verdwijnt. De hero volgt de inhoudshoogte; actieknoppen en tvOS-focus worden niet afgeknipt. Automatische rotatie en bestaande focusselectie blijven behouden.

Controle: de drie platformtargets zijn succesvol gebouwd. Een native SwiftUI-layoutcontrole met lokaal testbeeld op telefoon-, tablet-, Mac- en tv-breedte bevestigt dat artwork buiten de hero niet zichtbaar is en na doorscrollen verdwijnt. Dit is een controle van de gedeelde achtergrondcomponent op de Mac, geen fysieke iPad-test.

Woonkamer en iPhone zijn na deze geslaagde builds handmatig bijgewerkt en opnieuw gestart; updaters blijven gepauzeerd.

## iPhone-dienstenrij — herstel, 3 oktober 2026

De gebruiker meldt ontbrekende Home-dienstenlogo's en een lege zwarte strook boven de hero. Dit is gereproduceerd in een iOS 27/iPhone 17-simulator met de echte woordmerk- en tegelcomponenten, een NavigationStack/TabView en dezelfde asynchroon gevulde horizontale rij: safeAreaInset reserveert de hoogte, maar tekent de logo's niet zichtbaar. De eerdere Mac-layoutcontrole vond dit iOS-probleem niet.

Herstel: de gedeelde iPhone/iPad/Mac-Home plaatst de dienstenrij nu als vaste eerste rij in een VStack naast de verticale ScrollView. Breedte is expliciet; er wordt geen safeAreaInset voor die rij meer gebruikt. Nachtgloed vult ook de root/statusbalkzone. Alleen wanneer de dienstenrij ontbreekt, mag de schermvullende hero onder de statusbalk doorlopen. De zoek-/instellingenknoppen volgen de hero en blijven bereikbaar. tvOS behoudt de bestaande compacte rij.

Controle: dezelfde iPhone-simulator toont na de wijziging Netflix/Prime Video/Disney+ en de volgende dienst op de eerdere lege plek. De beelden van deze layoutcontrole gebruiken een lokale vervangende hero en echte gebundelde logo's; dit is geen screenshot van de volledige app op het fysieke toestel. De tvOS-, iPhone/iPad- en macOS-targets zijn succesvol gebouwd. Updaters blijven gepauzeerd.

De fysieke iPhone is met deze versie handmatig bijgewerkt en succesvol opnieuw gestart.

## Films/Series — rand-tot-rand en stabiele hero, 3 oktober 2026

De gebruiker meldt dat de vorige begrenzing de hero als een ingesprongen kaart toont en dat de pagina beweegt bij een hero-wissel. De begrensde hero is nu rand-tot-rand; alleen header/filters/posters hebben nog zijmarges. Op iOS gaat de artwork ook onder de statusbalk door, met veilige bovenruimte voor de tekst/knoppen. Op tvOS wordt de horizontale safe area voor de hero verwijderd en blijft de bestaande hoofdnavigatie erboven bereikbaar.

`VeyraCatalogHero` reserveert een vaste band (620pt tvOS; 500pt iPhone/iPad/Mac, plus iOS-statusruimte). De modus ClearLogo + tekst heeft vaste extra ruimte voor die tweede titelregel. Via een lokale environment-layout krijgen alleen deze catalogus-heroes vaste titel-, metadata-, rating-, omschrijvings- en actieruimte. Een transparante ratingsrij voorkomt dat SwiftUI een lege ratings-view uit de layout laat verdwijnen. De andere heroes houden hun bestaande layout. Artwork blijft binnen de bovenste band en scrollt met de hero weg; geen foto achter de posterlijst.

Controle: native SwiftUI met de echte hero/clearlogo/achtergrondcode en lokale vervangers voor netwerkdata is gecontroleerd op 390, 1024, 1440 en 1920pt. Positie en grootte van actieknop en raster blijven exact gelijk bij korte/lange titels, ontbrekende metadata, later geladen logo's en scores en titelrotatie. De iPhone 17/iOS 27-layout in een echte simulator toont artwork tot beide zijranden en onder de statusbalk, begrensd boven Films/raster. Dit zijn component/layoutcontroles met testdata, geen fysieke screenshots van het gehele product. De drie platformtargets zijn succesvol gebouwd. Automatische updaters blijven gepauzeerd.

Woonkamer en de fysieke iPhone zijn met deze versie handmatig bijgewerkt en succesvol opnieuw gestart.
