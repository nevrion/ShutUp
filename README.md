<p align="center"><img src="docs/logo.png" alt="Antifaschiste Aktion Azeroth" width="160"></p>

# Antifaschiste Aktion Azeroth

Ein Addon für **WoW Forever** (Interface 16001), das Mitglieder bestimmter Gilden automatisch auf Ignore setzt und ihren Chat ausblendet. Standardmäßig sind das die Gilden **"Alternative für Durotar"** und **"Alternative für Azeroth"**. Weitere Gilden lassen sich im Spiel hinzufügen.

Das Addon wirkt nur auf deinem Client. Niemand wird benachrichtigt.

## Installation

1. Zip aus dem [neuesten Release](../../releases/latest) herunterladen.
2. Den Ordner `AntifaAktionAzeroth` in den AddOns-Ordner von WoW Forever kopieren (`Interface/AddOns/`).
3. Spiel starten, im Charakterauswahl-Bildschirm unter "AddOns" prüfen, dass es aktiviert ist.

## So funktioniert es

WoW kann keine Mitglieder einer fremden Gilde auflisten. Das Addon sammelt deshalb auf drei Wegen:

1. **Passiv:** Jeder Spieler, den du mit Maus, Ziel, Namensplakette oder in deiner Gruppe siehst, wird auf seine Gilde geprüft. Steht die Gilde in der Liste, kommt er auf Ignore.
2. **Aktiv:** `/aaa scan` fragt per `/who g-"Gildenname"` nach Mitgliedern. Gibt es mehr als 50 Treffer (Grenze des Spiels), teilt das Addon die Suche nach Stufenbereichen auf. Einmal pro Anmeldung läuft die Suche automatisch, 30 Sekunden nach dem Login und höchstens alle 12 Stunden. Wegen der Abfrage-Sperre des Spiels dauert sie eine Weile.
3. **Chat-Filter:** Wer in der eigenen Liste steht, wird im Chat ausgeblendet (Say, Yell, Flüstern, Kanäle, Gruppe, Schlachtzug, Gilde). Das funktioniert auch, wenn die Ignore-Liste des Spiels voll ist (Limit des Spiels: 50 Einträge). Solange dort Platz ist, trägt das Addon die Spieler zusätzlich in die normale Ignore-Liste ein.

## Befehle

| Befehl | Wirkung |
|---|---|
| `/aaa scan` | Gilden per `/who` absuchen |
| `/aaa liste` | Gilden und Zahl der eingetragenen Spieler anzeigen |
| `/aaa gilde + Name` | Gilde hinzufügen |
| `/aaa gilde - Name` | Gilde entfernen |
| `/aaa frei Spielername` | Spieler wieder freigeben |
| `/aaa chat` | Chat-Filter an/aus |
| `/aaa spiel` | Spiel-Ignore-Liste mitbenutzen an/aus |
| `/aaa auto` | Suche bei der Anmeldung an/aus |
| `/aaa meldung` | Meldungen bei neuen Einträgen an/aus |

Bei den Gildennamen ist Groß- und Kleinschreibung egal, und ü, ä, ö gelten als u, a, o.

## Bekannte Einschränkungen

- **Im Spiel noch nicht getestet.** Offen ist vor allem, ob WoW Forever die `/who`-Abfrage aus einem Addon erlaubt und ob die Gildenspalte im Ergebnis gefüllt ist. Wenn nicht, bleibt der passive Weg (Mouseover, Ziel, Gruppe).
- Wer seine Gilde wechselt, bleibt in der Liste, bis du ihn mit `/aaa frei` freigibst.
- Das Addon kennt nur Spieler, die es gesehen oder per `/who` gefunden hat.

## Fehler melden

Bitte als Issue hier im Repo. Hilfreich ist die Ausgabe von `/console scriptErrors 1`, wenn eine Lua-Fehlermeldung erscheint.
