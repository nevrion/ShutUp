<p align="center"><img src="docs/logo.png" alt="ShutUp!" width="160"></p>

# ShutUp!

Ein allgemeines Ignore-Addon für **WoW Forever** (Interface 16001). Du trägst einzelne Spieler oder ganze Gilden von Hand ein, ShutUp! setzt sie auf Ignore und blendet ihren Chat aus. Die Liste gilt **für alle deine Charaktere** (accountweit). Es gibt keine voreingetragenen Gilden.

Das Addon wirkt nur auf deinem Client. Niemand wird benachrichtigt.

## Installation

1. Zip aus dem [neuesten Release](../../releases/latest) herunterladen.
2. Den Ordner `ShutUp` in den AddOns-Ordner von WoW Forever kopieren (`Interface/AddOns/`).
3. Spiel starten, im Charakterauswahl-Bildschirm unter "AddOns" prüfen, dass es aktiviert ist.

Kommst du von der Vorversion "Antifaschiste Aktion Azeroth": den alten Ordner `AntifaAktionAzeroth` löschen. Deine alte Liste liegt in `WTF/Account/<Konto>/SavedVariables/AntifaAktionAzeroth.lua`; kopierst du diese Datei nach `ShutUp.lua` (gleicher Ordner), übernimmt ShutUp! sie beim ersten Start. Die zwei früher fest eingetragenen Gilden entfernt es dabei aus der Gildenliste, die schon eingetragenen Spieler bleiben.

## Befehle

| Befehl | Wirkung |
|---|---|
| `/shutup + Vorname Nachname` | Spieler ignorieren (ohne Namen: dein Ziel) |
| `/shutup - Vorname Nachname` | Spieler wieder freigeben (der Anfang des Namens genügt, ohne Namen: dein Ziel) |
| `/shutup gilde + Name` | ganze Gilde ignorieren (ohne Namen: die Gilde deines Ziels) |
| `/shutup gilde - Name` | Gilde entfernen und ihre Mitglieder freigeben |
| `/shutup liste` | Gilden und Zahl der Einträge; `/shutup liste spieler` zeigt alle Namen |
| `/shutup scan` | Gilden der Liste per `/who` absuchen |
| `/shutup ziel` | Diagnose: zeigt, wie der Client Vor- und Nachname deines Ziels (sonst deines Chars) liefert |
| `/shutup chat` | Chat-Filter an/aus |
| `/shutup spiel` | Spiel-Ignore-Liste mitbenutzen an/aus |
| `/shutup auto` | Gildensuche bei der Anmeldung an/aus (nur wenn Gilden eingetragen sind) |
| `/shutup meldung` | Meldungen bei neuen Einträgen an/aus |

Bei den Gildennamen ist Groß- und Kleinschreibung egal, und ü, ä, ö gelten als u, a, o.

## So funktioniert es

- **Einzelne Spieler:** stehen sofort auf der Liste und, solange dort Platz ist, zusätzlich in der normalen Ignore-Liste des Spiels (Limit des Spiels: 50 Einträge). Darüber hinaus blendet der Chat-Filter sie weiter aus (Say, Yell, Flüstern, Kanäle, Gruppe, Schlachtzug, Gilde).
- **Ganze Gilden:** WoW kann keine Mitglieder einer fremden Gilde auflisten. ShutUp! sammelt deshalb passiv: jeder Spieler, den du per Maus, Ziel, Namensplakette oder Gruppe siehst, wird auf seine Gilde geprüft. Zusätzlich fragt `/shutup scan` per `/who g-"Gildenname"` nach (bei mehr als 50 Treffern nach Stufenbereichen geteilt, einmal pro Anmeldung automatisch).

## Namen in WoW Forever

Charaktere haben in Forever Vor- und Nachnamen. ShutUp! arbeitet immer mit dem **vollen Namen** ("Vorname Nachname", ohne Realm) und ignoriert nie nur anhand des Vornamens, damit keine Unbeteiligten mit demselben Vornamen betroffen sind.

## Bekannte Einschränkungen

- Offen ist, ob WoW Forever die `/who`-Abfrage aus einem Addon erlaubt und ob die Gildenspalte im Ergebnis gefüllt ist. Wenn nicht, bleibt der passive Weg (Maus, Ziel, Gruppe).
- Wer seine Gilde wechselt, bleibt auf der Liste, bis du ihn mit `/shutup -` freigibst.
- ShutUp! kennt nur Spieler, die es gesehen oder per `/who` gefunden hat.

## Fehler melden

Bitte als Issue hier im Repo. Hilfreich ist die Ausgabe von `/console scriptErrors 1`, wenn eine Lua-Fehlermeldung erscheint.
