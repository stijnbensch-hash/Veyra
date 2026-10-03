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

## Collectiedetail tvOS — afbeelding en menuknop, 3 oktober 2026

De gebruiker vraagt specifiek op tvOS de collectieafbeelding volledig binnen het kader te tonen en het gefocuste symbool rechtsboven te verwijderen. De gebruiker verduidelijkt "geen vrije ruimtes" en "kader ook zo laten": de bestaande bannerhoogte/breedte blijft behouden. Op tvOS wordt het volledige beeld naar beide kaderafmetingen geschaald, zonder uitsnede, zoom of lege zijstroken (de verhouding volgt dus het kader). De opgeslagen uitsnede blijft beschikbaar voor de collectiekaarten. De ellipsis-menuknop is alleen in de tvOS-detailweergave verwijderd. Bewerken, films beheren en verwijderen blijven beschikbaar via het contextmenu op de collectiekaart in de collectiebrowser.

Controle: de tvOS-, iOS/iPad- en macOS-targets zijn met de definitieve kaderwijziging succesvol gebouwd; diff-controle geslaagd. De tvOS-app is bevestigd geïnstalleerd op Woonkamer. Automatisch opnieuw starten is niet bevestigd: devicectl kon de remoteService/XPC-verbinding niet maken; de herhaling werd geweigerd wegens de device usage assertion (4016). Geen fysieke visuele controle uitgevoerd. Automatische updaters blijven gepauzeerd.

De gebruiker vraagt daarna de afbeeldingwijziging ongedaan te maken: de oorspronkelijke aspect-fill met bewaarde zoom/positie is hersteld. Het verwijderen van het tvOS-symbool rechtsboven blijft behouden.

## Aflevering afgelopen — terug naar lijst, 3 oktober 2026

De gebruiker meldt een achterblijvend "Veyra Player starten"-scherm na een aflevering, met automatisch doorgaan uit. De spelers hadden wel een credits-aftelling maar geen navigatieactie bij de echte `.ended`-status. `VeyraEpisodeCompletion` handelt nu op alle platformen een episode-einde één keer af: autoplay uit of geannuleerde aftelling retourneert direct, onafhankelijk van nog lopende metadata; autoplay aan opent de gevonden volgende aflevering ook zonder aftelling; geen vervolg retourneert na de lookup. Films en Live TV worden niet door deze episode-handler gesloten. De bestaande trackers kunnen het einde verwerken voordat de sessie wordt gestopt.

De oorspronkelijke bronnenkiezer geeft een return-actie door aan alle opeenvolgende spelers en bronkeuzes, zodat afronden de hele spelerbranch sluit en de afleveringenlijst terugkomt. iPhone/iPad/Mac sluiten nu net als tvOS ook de bronkeuze na terugkeer uit een aflevering. Per speler voorkomen guards dubbele vooruit-/terugacties. PiP/fullscreen worden bij afgeronde afleveringen expliciet gestopt; IPTV-plankafleveringen krijgen de ontbrekende seizoen/aflevering-identiteit mee. De oorspronkelijke collectieafbeelding is hersteld op het aanvullende verzoek; de eerder verwijderde tvOS-menuknop blijft verwijderd.

Native SwiftUI-componenttests met gesimuleerde engine-events slagen voor autoplay uit (ook met onopgeloste metadata), werkelijk EOF versus pause/idle, dubbel EOF, later gevonden volgende aflevering, autoplay aan, laatste aflevering, geannuleerde aftelling en uitsluiting van films/Live TV. Deze tests gebruiken de productie-handler; echte streamafloop en volledige navigatie op het toestel zijn nog niet fysiek geverifieerd.

Verificatie: tvOS-, iPhone/iPad- en macOS-targets succesvol gebouwd met de playerfix en herstelde collectieafbeelding. Woonkamer en iPhone zijn bevestigd handmatig geïnstalleerd en succesvol opnieuw gestart. Automatische updaters blijven gepauzeerd. Een echte aflevering volledig laten uitspelen op het toestel blijft de praktische vervolgcontrole.

## Collectiedetail — clearlogo onder menubalk, 3 oktober 2026

De gebruiker meldt dat de collectie-inhoud op tvOS te hoog staat: het clearlogo overlapt de hoofdnavigatie. De negatieve bovenmarge (-24pt) is vervangen door 36pt, zodat de hele inhoud 60pt lager begint en ook een smal clearlogo onder de menubalk blijft. De bestaande afbeeldinguitsnede, bannermaat en verwijderde menuknop blijven behouden. iPhone/iPad/Mac hebben al een positieve bovenmarge en houden hun passende layout.

De gebruiker verduidelijkt vervolgens "ik build zelf": voortaan alleen de gevraagde bronwijzigingen opslaan en aan de gebruiker overlaten om te bouwen/installeren, totdat die expliciet anders vraagt. De nog lopende builds voor deze bovenmargewijziging zijn gestopt; geen nieuwe versie geïnstalleerd. Updaters blijven gepauzeerd.


## Addons — alleen rechtstreeks toevoegen verwijderen, 3 oktober 2026

Na het afbreken van de brede verwijderopdracht verduidelijkt de gebruiker: alles via VeyraHub behouden, inclusief addonmetadata; alleen rechtstreeks addons toevoegen in Veyra verwijderen. De te brede verwijdering is hersteld voordat deze afgebakende wijziging is gemaakt. De lokale toevoegknop, manifest-invoer voor nieuwe addons en toevoegroute zijn verwijderd op tvOS en in de gedeelde iPhone/iPad/macOS-instellingen. De oude automatische AIOStreams-migratie wordt niet meer aangeroepen vanuit instellingen. Bestaande koppelingen blijven beschikbaar en bewerkbaar; stores, registry, metadata/artwork, catalogi, bronresolutie en VeyraHub-synchronisatie zijn behouden, net als mediaserver en IPTV. De lege addonlijst verwijst voor toevoegen naar VeyraHub.

Controle: Swift-syntaxis en diff gecontroleerd, zonder appbuild of installatie conform "ik build zelf". Functionele controle in de app na de eigen build blijft open.


## Addonwijzigingen volledig teruggezet, 3 oktober 2026

De gebruiker vraagt "zet alles terug voor verwijderen addons". De drie gewijzigde addoninstellingen-/viewmodelbestanden zijn teruggezet naar de toestand vóór de verwijderopdracht: toevoegen, manifest-invoer en oude migratie zijn weer aanwezig op alle platformen. VeyraHub, metadata, addonproviders, mediaserver en IPTV zijn behouden. De eerdere playerfix en collectiemarge blijven ongewijzigd. Aan de gevraagde versnelling van Hub-bronnen waren nog geen codewijzigingen gemaakt. De gemelde startproblemen op Apple TV zijn met deze bronrollback nog niet als opgelost bevestigd. Geen build of installatie uitgevoerd; de gebruiker bouwt zelf.


## Rechtstreekse addonbronnen verwijderd; VeyraHub behouden, 3 oktober 2026

Nieuwe, expliciete opdracht: rechtstreekse addons verwijderen, alles via VeyraHub laten staan, mediaserver en IPTV behouden. De lokale addoninstellingen (toevoegen/bewerken) en navigatie daarnaartoe zijn verwijderd uit tvOS en de gedeelde iPhone/iPad/macOS-instellingen. Oude opgeslagen "addons"-categorieën worden bij laden overgeslagen zonder de opgeslagen volgorde te wissen. AddonRegistry registreert geen rechtstreekse streamproviders meer, ook niet vanuit oude opgeslagen addonrecords; daarmee doen de bestaande bronzoekers geen rechtstreekse addon-streamaanvragen meer. De lokale AIOStreams-statusprobe en automatische instellingsmigratie worden niet meer aangeroepen.

AddonStore, metadata-/artworkresolutie, AIOMetadata-client, addon-/Hub-catalogi, VeyraHub-synchronisatie, native streams/ondertitels/voortgang en Jellyfin/IPTV-bronresolutie zijn behouden. Metadata-uitleg verwijst naar VeyraHub in plaats van het verdwenen lokale addoninstelscherm. Geen opgeslagen providerconfiguratie gewist. De eerdere player- en collectiefixes blijven behouden.

Controle: gerichte geïsoleerde controles met productie-store/registry/Hub-client en een lokale netwerkfixture slagen voor oude addonrecords zonder rechtstreekse providers, behoud van metadata/configuratie, oude categorievolgordes met mediaserver/IPTV, en Hub-streams/addonidentiteit/volgorde/ondertitels/voortgang. De kernbestanden voor Hub, metadata/artwork, catalogi, mediaserver en IPTV zijn byte-voor-byte behouden. Swift-syntaxis en diff gecontroleerd. Geen appbuild of installatie uitgevoerd conform "ik build zelf". Opstarten van de tvOS-app op het fysieke toestel is hiermee nog niet als hersteld bevestigd.

De gebruiker bevestigt vervolgens dat Veyra op Apple TV opnieuw start na het herstarten van de Apple TV. De precieze oorzaak van het eerdere startprobleem is niet vastgesteld.

## Nieuw uitgebracht — passende backdrops, 3 oktober 2026

De gebruiker vraagt de backdrops in Nieuw uitgebracht passend te maken zoals bij Verder kijken. De gedeelde release-decoder leest nu ook backdrop_path uit de bestaande TMDB-respons en gebruikt een begrensde w780-landschapafbeelding. Voorheen werd die waarde niet ingelezen en viel de kaart altijd terug op een staande poster. Release-kaarten gebruiken nu dezelfde VeyraArt-weergave met aspect-fit als de kleine Verder kijken-kaarten; ook de posterterugval wordt niet meer ingezoomd afgesneden. De bestaande kaartafmetingen blijven behouden. Dit geldt voor tvOS en de gedeelde iPhone/iPad/macOS-weergave.

Swift-syntaxis en diff-controle geslaagd. Geen appbuild of installatie uitgevoerd; de gebruiker bouwt zelf. Visuele controle op het toestel volgt na die build.

## Collectiebrowser — kop en nieuwe collectie, 3 oktober 2026

De gebruiker meldt dat op iPhone Collecties en de telling (52 collecties) worden opgesplitst door de naastgelegen toevoegknop. De pijl bij de kop is verwijderd op alle platformen; titel en telling hebben één tekstregel. De gedeelde iPhone/iPad/macOS-browser kiest met ViewThatFits een horizontale indeling wanneer alles past en anders een indeling met Nieuwe collectie onder de kop. tvOS houdt de ruime horizontale indeling en reserveert voldoende breedte voor de kop. De macOS-target gebruikt bevestigd dezelfde browser als iPhone/iPad.

Swift-syntaxis en diff-controle geslaagd. Geen appbuild, installatie of nieuwe visuele toestelcontrole uitgevoerd conform de voorkeur dat de gebruiker zelf bouwt.

## Home-hero — vloeiende transparante overgang, 3 oktober 2026

De gebruiker vraagt de overgang van de Home-hero naar de achtergrond zoals in de Strand-voorbeelden, zonder de zwarte balk uit het Veyra-screenshot. De gedeelde schermvullende hero gebruikt nu één doorlopende beeldlaag met een geleidelijk transparant masker. De donkere leesbaarheidslaag is binnen hetzelfde masker geplaatst, zodat ook die onderaan verdwijnt in plaats van op zwart te eindigen. De iPhone/iPad/macOS-backdrop loopt visueel 220pt voorbij de hero door onder de stippen/het begin van de eerste rij, met behoud van de bestaande layoutmaat. De tvOS-variant gebruikt dezelfde gedeelde achtergrond. De gekozen Nachtgloed-achtergrond en scrollkleuren blijven zichtbaar onder de vervaging; geen extra afbeelding, blur of netwerkverzoek toegevoegd. De kaartstijl houdt zijn bestaande donkere tekstoverlay.

Swift-syntaxis en diff-controle geslaagd. Geen appbuild of installatie uitgevoerd; de gebruiker bouwt zelf. Het definitieve uiterlijk op het toestel moet na die build worden gecontroleerd.

## Hero-inhoud lager; Films/Series dezelfde overgang, 3 oktober 2026

De gebruiker toont dat logo en tekst op Home na de vorige achtergrondwijziging te hoog/midden in de hero staan. Zonder de oude beeldvullende gradient centreerde het buitenste frame de intrinsieke inhoud. Het frame lijnt nu expliciet bottomLeading uit: clearlogo, scores en tekst staan samen onderaan de bestaande hero-band, met de bestaande 22pt onderruimte. Herohoogte en positie van stippen/rijen blijven gelijk.

De Films- en Series-heroes in het hoofdmenu gebruiken nu via VeyraHeroArtworkBackground dezelfde gedeelde transparante backdrop/leesbaarheidslaag als Home. De overgang loopt in de bestaande 160pt-band onder de catalogus-hero door en eindigt transparant boven de pagina-achtergrond. De vaste catalogus-layout en veilige bovenruimte blijven behouden. De tvOS- en iPhone/iPad-varianten zijn gecontroleerd op gebruik van deze gedeelde component; macOS gebruikt dezelfde iOS-catalogusviews. Swift-syntaxis en diff-controle geslaagd. Geen appbuild of installatie uitgevoerd; de gebruiker bouwt zelf. Visuele toestelcontrole volgt na de eigen build.

## Film-/seriedetail — dezelfde achtergrondovergang, 3 oktober 2026

De gebruiker vraagt de hero-overgang ook bij het openen van film/serie toe te passen. De transparante overgang en leesbaarheidslaag zijn samengebracht in veyraHeroBackdropBlend, gebruikt door Home, catalogus en nu beide detailpagina's. Op iPhone/iPad/macOS loopt de beeld-/trailerlaag visueel 120pt onder de oorspronkelijke backdrop door en vervaagt boven de Nachtgloed-pagina-achtergrond; titel, acties en lijsten houden hun layoutpositie. De details volgen nu dezelfde bestaande scrollkleuren als Home. Op tvOS vervaagt de bestaande schermvullende detailbackdrop (inclusief filmtrailer en donkere overlays) naar de Nachtgloed-basislaag. Trailerselectie, timing en lifecycle zijn ongewijzigd.

De vier platformdetailbestanden en beide gedeelde componenten zijn op Swift-syntaxis gecontroleerd; diff-controle geslaagd. macOS gebruikt dezelfde detailviews als iPhone/iPad. Geen appbuild of installatie uitgevoerd; visuele controle volgt na de eigen build van de gebruiker.

## iPhone-catalogus — drie posters per rij, 3 oktober 2026

De gebruiker vraagt op iPhone drie posters naast elkaar in plaats van twee, met behoud van de postermaat. Films en Series meten nu de werkelijke beschikbare breedte en gebruiken op iPhone drie vaste kolommen. De bestaande 124pt posterbreedte blijft bij 390pt/402pt schermbreedte behouden; de tussenruimte is 8pt en de zijmarges worden respectievelijk 1pt/7pt. Alleen bij minder dan 380pt beschikbare breedte wordt de poster minimaal verkleind om drie kolommen met minstens 4pt tussenruimte binnen het scherm te houden. Titels, badges en beeldverhouding gebruiken de bestaande postercomponent. De filter-/headermarges blijven 16pt. iPad en macOS houden hun adaptieve raster; tvOS is voor dit specifiek iPhone-verzoek ongewijzigd.

Swift-syntaxis van de twee catalogusviews en iOS/macOS-layoutvarianten gecontroleerd; diff-controle geslaagd. Geen appbuild of installatie uitgevoerd. Visuele toestelcontrole volgt na de eigen build van de gebruiker.

## Dynamische achtergrond in de hele app, 3 oktober 2026

De gebruiker vraagt dezelfde scrollkleur als Home bij Films en Series en alle overige appachtergronden, op alle platformen. VeyraBackground leest nu de verticale scrollpositie uit een lokale paginaomgeving. VeyraDynamicBackgroundScope is aangesloten op catalogi, details, collecties, instellingen, sport, zoeken, kijklijst, Trakt, mediaserver- en IPTV-pagina's en losse navigatiesheets. macOS deelt de iOS-pagina's en heeft dezelfde achtergrond in de eigen navigatie. De oude Home/Plain-achtergrondnamen verwijzen ook naar Nachtgloed. Artwork-overgangen vervagen naar deze dynamische basis. De TV-guide behoudt gekozen kleur/grijs/donker-thema's boven dezelfde scrollgestuurde basis.

VeyraScrollView, VeyraList en VeyraForm meten elke verticale container afzonderlijk. Horizontale rijen blijven native en beïnvloeden de kleur niet. De paginaomgeving houdt detailpagina's/sheets gescheiden van hun vorige pagina. Er zijn geen achtergrondtimers, extra afbeeldingen of netwerkverzoeken. Verminder beweging houdt de kleur stil. De videoachtergrond en player-controls blijven hun bestaande zwarte/transparante weergave gebruiken; zelfstandige iOS-audio/ondertitelsheets gebruiken de dynamische paginaachtergrond. Nieuwe scrollpagina's gebruiken dezelfde gedeelde wrappers en paginaomgeving.

Controle: Tests/run-dynamic-background-checks.sh compileert uitsluitend de actuele gedeelde component in een geïsoleerde SwiftUI-harness. Native scrolltests slagen voor kleurverandering bij verticale scroll, terugscrollen naar de oorspronkelijke kleur, horizontale uitsluiting, List/Form en isolatie van geneste pagina's. Het publieke AppKit-notificatiepad voor macOS 14-lijsten is apart met een native clipview getest, inclusief het verwijderen van de observer. De macOS-14-compatibiliteit van de component is getypecheckt; geen werkelijk macOS-14-toestel getest. Swift-syntaxis en diff zijn gecontroleerd. Geen Veyra-appbuild, installatie of visuele toestelcontrole uitgevoerd conform "ik build zelf".
