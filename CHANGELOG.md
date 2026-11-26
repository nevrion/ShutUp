# Changelog

## 0.3.0
- **EN:** Renamed from *Antifaschiste Aktion Azeroth* to **ShutUp!** and turned into a general ignore addon: no guilds are pre-filled any more, you add single players (`/shutup + First Last`, or your target) and whole guilds (`/shutup gilde + Name`) yourself. The list is shared by all characters of the account. ShutUp! no longer fills the game's ignore list (50 slots stay free for normal ignores); it uses its own list and the chat filter (`/shutup spiel` switches the game list back on). The command is now `/shutup` (`/aaa` is gone). The two old default guilds are removed from the guild list on first start; players already on the list stay (free them with `/shutup -`). To carry your old list over, copy `SavedVariables/AntifaAktionAzeroth.lua` to `ShutUp.lua`.
- **DE:** Umbenannt von *Antifaschiste Aktion Azeroth* in **ShutUp!** und zu einem allgemeinen Ignore-Addon umgebaut: keine voreingetragenen Gilden mehr, du trägst einzelne Spieler (`/shutup + Vorname Nachname`, oder dein Ziel) und ganze Gilden (`/shutup gilde + Name`) selbst ein. Die Liste gilt für alle Charaktere des Kontos. ShutUp! füllt die Ignore-Liste des Spiels nicht mehr (die 50 Plätze bleiben für normale Ignores frei), sondern nutzt eine eigene Liste und den Chat-Filter (`/shutup spiel` schaltet die Spiel-Liste wieder zu). Der Befehl heißt jetzt `/shutup` (`/aaa` entfällt). Die zwei alten Standardgilden fliegen beim ersten Start aus der Gildenliste; schon eingetragene Spieler bleiben (freigeben mit `/shutup -`). Um die alte Liste zu übernehmen, `SavedVariables/AntifaAktionAzeroth.lua` nach `ShutUp.lua` kopieren.

## 0.2.0
- **EN:** Uses the full first and last name of characters (WoW Forever names), never the first name alone. New diagnostic `/aaa ziel`; blocked `/who` searches are detected.
- **DE:** Nutzt den vollen Vor- und Nachnamen der Charaktere (WoW-Forever-Namen), nie den Vornamen allein. Neue Diagnose `/aaa ziel`; blockierte `/who`-Suche wird erkannt.

## 0.1.0
- **EN:** First version: ignores members of two fixed guilds (passive detection, `/who` search, chat filter).
- **DE:** Erste Version: ignoriert Mitglieder von zwei festen Gilden (passive Erkennung, `/who`-Suche, Chat-Filter).
