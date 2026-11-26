<p align="center"><img src="docs/logo.png" alt="ShutUp!" width="160"></p>

# ShutUp!

**Deutsch** · [English](#english)

*Früher "Antifaschiste Aktion Azeroth". Befehl jetzt `/shutup`.*

Ein allgemeines Ignore-Addon für **WoW Forever** (Interface 16001). Du trägst einzelne Spieler oder ganze Gilden von Hand ein, ShutUp! setzt sie auf Ignore und blendet ihren Chat aus. Die Liste gilt **für alle deine Charaktere** (accountweit). Es gibt keine voreingetragenen Gilden.

Das Addon wirkt nur auf deinem Client. Niemand wird benachrichtigt.

Und dann gibt es die Edgy-Gilden, die es lustig finden, populistische Klischees auszupacken, nur um andere zu triggern. Dafür musst du dich weder aufregen noch diskutieren: Gilde einmal mit `/shutup gilde + Name` eintragen, und sie hält für dich die Klappe, ganz ohne Anstrengung.

## Installation

1. Zip aus dem [neuesten Release](../../releases/latest) herunterladen (oder über CurseForge/WoWUp installieren).
2. Den Ordner `ShutUp` in den AddOns-Ordner von WoW Forever kopieren (`Interface/AddOns/`).
3. Spiel starten, im Charakterauswahl-Bildschirm unter "AddOns" prüfen, dass es aktiviert ist.

Kommst du von der Vorversion "Antifaschiste Aktion Azeroth": den alten Ordner `AntifaAktionAzeroth` löschen. Über WoWUp oder die CurseForge-App geht es per "Von URL installieren" mit der Repo-Adresse bzw. über die CurseForge-Suche nach "ShutUp!". Deine alte Liste liegt in `WTF/Account/<Konto>/SavedVariables/AntifaAktionAzeroth.lua`; kopierst du diese Datei nach `ShutUp.lua` (gleicher Ordner), übernimmt ShutUp! sie beim ersten Start. Die zwei früher fest eingetragenen Gilden entfernt es dabei aus der Gildenliste, die schon eingetragenen Spieler bleiben.

## Befehle

| Befehl | Wirkung |
|---|---|
| `/shutup` | Fenster öffnen (Liste mit Grund, Gilden, Einstellungen); auch per Minimap-Button |
| `/shutup + Vorname Nachname` | Spieler ignorieren (ohne Namen: dein Ziel) |
| `/shutup - Vorname Nachname` | Spieler wieder freigeben (der Anfang des Namens genügt, ohne Namen: dein Ziel) |
| `/shutup gilde + Name` | ganze Gilde ignorieren (ohne Namen: die Gilde deines Ziels) |
| `/shutup gilde - Name` | Gilde entfernen und ihre Mitglieder freigeben |
| `/shutup liste` | Gilden und Zahl der Einträge; `/shutup liste spieler` zeigt alle Namen |
| `/shutup scan` | Gilden der Liste per `/who` absuchen |
| `/shutup ziel` | Diagnose: zeigt, wie der Client Vor- und Nachname deines Ziels (sonst deines Chars) liefert |
| `/shutup gildeneinladung` | Gildeneinladungen und -satzungen automatisch ablehnen an/aus (Gruppen nie) |
| `/shutup spam` | Spam automatisch eintragen an/aus |
| `/shutup chat` | Chat-Filter an/aus |
| `/shutup spiel` | Spieler zusätzlich in die Ignore-Liste des Spiels eintragen an/aus (Standard: aus) |
| `/shutup meldung` | Meldungen bei neuen Einträgen an/aus |

Bei den Gildennamen ist Groß- und Kleinschreibung egal, und ü, ä, ö gelten als u, a, o.

## Oberfläche

`/shutup` öffnet ein Fenster mit drei Reitern: **Liste** (alle Geblockten mit Grund *Manuell*, *Gilde*, *Spam* oder *Einladung*, Datum, Suche, Filter, Freigeben-Knopf und Felder zum Eintragen), **Gilden** (eingetragene Gilden mit Zahl der Mitglieder, hinzufügen, entfernen, per `/who` suchen) und **Einstellungen**. Der Minimap-Button öffnet es ebenfalls (Rechtsklick: Einstellungen, Ziehen: verschieben).

## Spam und Gildeneinladungen

- **Spam automatisch eintragen:** Wiederholt jemand denselben Text (Links, Zahlen und Satzzeichen werden herausgerechnet) mehrfach in kurzer Zeit, kommt er als "Spam" auf die Liste. Standard: 3 Wiederholungen in 120 Sekunden, mindestens 15 Zeichen, in Say, Yell, Flüstern und öffentlichen Kanälen. **Handel und Gruppensuche zählen nie**, ebenso nie Gruppen-, Schlachtzugs- oder Gildenchat. **Freunde, Gildenmitglieder und Gruppenmitglieder werden nie automatisch eingetragen.** Jeder Eintrag meldet sich mit dem Befehl zum Freigeben und läuft nach 7 Tagen ab (einstellbar, 0 = nie). Optional erkennt es auch Bot-Wellen: derselbe Text von mehreren verschiedenen Absendern.
- **Gildeneinladungen und Gildensatzungen ablehnen:** lehnt Einladungen in eine Gilde und angebotene Gildensatzungen zum Unterschreiben ab, **Gruppen- und Schlachtzugseinladungen nie**. Standard: aus; im Einstellungs-Reiter einschaltbar, wahlweise nur von Unbekannten (Freunde, Gildenmitglieder, Gruppe werden durchgelassen) und mit der Option, den Einlader auf die Liste zu setzen. Deine eigene Satzung beim Gründen einer Gilde bleibt unberührt.

## So funktioniert es

- **Einzelne Spieler:** stehen sofort auf ShutUps eigener Liste, ohne Limit. Ihr Chat wird ausgeblendet (Say, Yell, Flüstern, Kanäle, Gruppe, Schlachtzug, Gilde). **Die Ignore-Liste des Spiels (50 Plätze) bleibt für deine normalen Ignores frei.** Wer zusätzlich will, dass das Spiel auch Einladungen und Handel dieser Spieler blockt, schaltet `/shutup spiel` ein; dann trägt ShutUp! sie dort ein, solange Platz ist, und nimmt beim Freigeben nur wieder heraus, was es selbst eingetragen hat.
- **Ganze Gilden:** WoW kann keine Mitglieder einer fremden Gilde auflisten. ShutUp! sammelt deshalb passiv: jeder Spieler, den du per Maus, Ziel, Namensplakette oder Gruppe siehst, wird auf seine Gilde geprüft. Zusätzlich fragt `/shutup scan` per `/who g-"Gildenname"` nach (bei mehr als 50 Treffern nach Stufenbereichen geteilt). **WoW Forever erlaubt diese Abfrage nur nach einem Klick oder getippten Befehl, deshalb sendet jeder Aufruf genau eine Abfrage;** bei großen Gilden den Knopf "Nächste Abfrage" im Gilden-Reiter oder `/shutup scan` mehrfach auslösen. Eine automatische Suche beim Anmelden gibt es nicht.

## Namen in WoW Forever

Charaktere haben in Forever Vor- und Nachnamen. ShutUp! arbeitet immer mit dem **vollen Namen** ("Vorname Nachname", ohne Realm) und ignoriert nie nur anhand des Vornamens, damit keine Unbeteiligten mit demselben Vornamen betroffen sind.

## Bekannte Einschränkungen

- Offen ist, ob WoW Forever die `/who`-Abfrage aus einem Addon erlaubt und ob die Gildenspalte im Ergebnis gefüllt ist. Wenn nicht, bleibt der passive Weg (Maus, Ziel, Gruppe).
- Wer seine Gilde wechselt, bleibt auf der Liste, bis du ihn mit `/shutup -` freigibst.
- ShutUp! kennt nur Spieler, die es gesehen oder per `/who` gefunden hat.

## Fehler melden

Bitte als Issue hier im Repo. Hilfreich ist die Ausgabe von `/console scriptErrors 1`, wenn eine Lua-Fehlermeldung erscheint.

---

## English

**A general ignore addon for WoW Forever** (interface 16001). You add single players or whole guilds by hand, ShutUp! puts them on ignore and hides their chat. The list is **shared by all your characters** (account-wide). No guilds are pre-filled. It only affects your own client, nobody is notified.

And then there are the edgy guilds that think it is hilarious to throw around populist clichés just to trigger people. You do not have to argue with them or get worked up: put the guild on the list once with `/shutup gilde + Name` and it shuts up for you, with zero effort.

*Formerly "Antifaschiste Aktion Azeroth". The command is now `/shutup`.*

### Installation
Copy the `ShutUp` folder to `Interface/AddOns/` (or install with the CurseForge app / WoWUp, game version Forever). Coming from the old version? Delete the folder `AntifaAktionAzeroth`. To carry your old list over, copy `WTF/Account/<account>/SavedVariables/AntifaAktionAzeroth.lua` to `ShutUp.lua` in the same folder. The two guilds that used to be hard-wired are removed from the guild list on first start, players already on the list stay.

### Window, spam and guild invites
`/shutup` opens a window with three tabs: **List** (everyone you blocked, with reason *Manual*, *Guild*, *Spam* or *Invite*, date, search, filter, free button and fields to add), **Guilds** and **Settings**; the minimap button opens it too.
**Auto-block spam:** the same text (links, numbers and punctuation ignored) repeated in a short time puts the sender on the list as "Spam". Default: 3 times in 120 seconds, at least 15 characters, in say, yell, whispers and public channels. Trade and Looking for Group never count, nor party, raid or guild chat. **Friends, guild members and group members are never added automatically.** Entries expire after 7 days (adjustable, 0 = never). Optional: bot waves (the same text from several senders).
**Decline guild invites and guild charters:** off by default; switch on in the settings tab, optionally only from unknown people, optionally with the inviter added to the list. **Group and raid invites are never touched.**

### Commands
| Command | Effect |
|---|---|
| `/shutup` | open the window (list with reasons, guilds, settings) |
| `/shutup + First Last` | ignore a player (no name: your target) |
| `/shutup - First Last` | free a player again (the start of the name is enough, no name: your target) |
| `/shutup gilde + Name` | ignore a whole guild (no name: your target's guild) |
| `/shutup gilde - Name` | remove a guild and free its members |
| `/shutup liste` | guilds and number of entries; `/shutup liste spieler` shows all names |
| `/shutup scan` | search the listed guilds with `/who` |
| `/shutup ziel` | diagnostic: how the client reports your target's first and last name |
| `/shutup gildeneinladung` / `spam` | decline guild invites and charters / auto-block spam on or off |
| `/shutup chat` / `spiel` / `meldung` | switch chat filter / also use the game ignore list (default off) / messages on or off |

Guild names are case-insensitive, and ü, ä, ö count as u, a, o.

### How it works
- **Single players:** on ShutUp!'s own list at once, without a limit, and their chat is hidden (say, yell, whispers, channels, party, raid, guild). **The game's own ignore list (50 slots) stays free for your normal ignores.** If you also want the game to block invites and trades from them, switch on `/shutup spiel`: ShutUp! then adds them there while there is room, and on freeing only removes what it added itself.
- **Whole guilds:** WoW cannot list the members of a foreign guild. ShutUp! collects them passively (everyone you see by mouseover, target, nameplate or group is checked for their guild) and with `/shutup scan` (`/who g-"Guild"`, split by level range above 50 results). **WoW Forever only allows this query after a click or a typed command, so every call sends exactly one query;** for big guilds press "Next query" in the Guilds tab or type `/shutup scan` several times. There is no automatic search at login.
- **Names in WoW Forever:** characters have first and last names. ShutUp! always works with the **full name** (without realm) and never ignores by first name alone, so unrelated players with the same first name are not hit.

### Known limitations
- Whether WoW Forever allows the `/who` search from an addon, and whether the guild column is filled, is untested. If not, passive detection still works.
- Someone who changes guild stays on the list until you free them with `/shutup -`.
- ShutUp! only knows players it has seen or found with `/who`.

### Reporting bugs
Please open an issue in this repo. The output of `/console scriptErrors 1` helps when a Lua error shows up.

License: MIT
Lizenz: MIT
