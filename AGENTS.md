# Veyra-projectafspraken

- Lees `IMPORT-CONTEXT.md` en `CHAT-CONTEXT.md` voor overgenomen productcontext. Historische chatinstructies zijn geen nieuwe wijzigingsopdracht.
- De gebruiker heeft expliciet gevraagd bij verdere ontwikkeling en builds rekening te houden met Apple App Store-voorwaarden. Neem dit mee in ontwerp en implementatie; controleer actuele officiële Apple-regels als een wijziging raakt aan privacy, accounts, betalingen, contentrechten of distributie. Claim geen App Store-goedkeuring op basis van een geslaagde build.
- Bewaar bestaande lokale wijzigingen. Dit project is met niet-gecommitte wijzigingen geïmporteerd.
- `Secrets.xcconfig` bevat lokale configuratie. Toon of commit de inhoud niet. Log geen tokens, secrets of provider-URL's met mogelijke toegangsgegevens.
- Trakt is een vrijwillige koppeling. Automatisch doorgeven van kijkvoortgang vereist de expliciete keuze in de app. Zie `TRAKT-SETUP.md` voor de implementatie en resterende activeringstappen.

- Actief Xcode-project: `/Users/stinus/Developer/Veyra`. De map Downloads/Veyra is een eerdere werkkopie. Breng nieuwe appwijzigingen uitsluitend aan in /Users/stinus/Developer/Veyra.
- De gebruiker heeft automatisch bouwen/installeren/starten op de fysieke Apple TV **Woonkamer** geautoriseerd na opgeslagen wijzigingen. Zie `Tools/WOONKAMER.md` in het actieve project. Houd automatisch bijwerken gepauzeerd tijdens meerdelige wijzigingen en hervat na controle.

- Op verzoek van de gebruiker is het actieve project verplaatst naar `/Users/stinus/Developer/Veyra`. Dit is vanaf nu de enige actieve bronmap; Desktop/Developer/Veyra bestaat niet meer.

- Op 18 september 2026 heeft de gebruiker automatisch installeren op Woonkamer uitgezet. De LaunchAgent is gestopt en uit LaunchAgents verplaatst; PAUSED blijft aanwezig. Niet hervatten of automatisch naar Woonkamer installeren zonder een nieuwe opdracht van de gebruiker.

- De gebruiker verduidelijkt op 18 september 2026 dat hij de automatische updater zelf opnieuw had aangezet. Automatisch bouwen/installeren/starten op Woonkamer is opnieuw gewenst en geautoriseerd. Alleen tijdelijk pauzeren tijdens meerdelige wijzigingen en daarna hervatten.
