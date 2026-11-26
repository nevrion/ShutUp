-- Stub-Test (Lua 5.1): Vor- und Nachname, Ignore, Chat-Filter
local calls = {}
local function obj() return setmetatable({}, { __index = function() return function() return obj() end end }) end
SlashCmdList = {}
C_Timer = { After = function() end }
local filters = {}
function ChatFrame_AddMessageEventFilter(_, fn) filters[#filters + 1] = fn end
local handlers = {}
function CreateFrame() local o = obj() rawset(o, "SetScript", function(_, n, fn) handlers[n] = fn end) rawset(o, "RegisterEvent", function() end) return o end
local IGN = {}
C_FriendList = { AddIgnore = function(n) IGN[#IGN + 1] = n end, GetNumIgnores = function() return #IGN end, IsIgnored = function() return false end }
time = os.time
local UNITS = { player = { "Me", "Me Stonewall-Forever", "Meine Gilde" }, target = { "Anna", "Anna Meyer-Forever", "Alternative für Durotar" } }
function UnitName(u) return UNITS[u] and UNITS[u][1] end
function GetUnitName(u, full) return UNITS[u] and (full and UNITS[u][2] or UNITS[u][2]:match("^[^-]+")) end
function UnitFullName(u) return UNITS[u] and UNITS[u][1] end
function GetGuildInfo(u) return UNITS[u] and UNITS[u][3] end
function UnitExists(u) return UNITS[u] ~= nil end
function UnitIsPlayer() return true end
function UnitIsUnit(a, b) return a == b end
function GetNumGroupMembers() return 0 end
function IsInRaid() return false end
ShutUpDB = { muted = { anna = { name = "Anna", guild = "Alt" } } } -- Altlast aus 0.1.0 (nur Vorname)
local f = assert(loadfile("Core.lua"))
f("ShutUp")
local on = handlers.OnEvent
on(nil, "ADDON_LOADED", "ShutUp")
assert(ShutUpDB.muted["anna"] == nil, "Vornamen-Altlast entfernt")
assert((ShutUpDB.legacyRemoved or 0) == 1)
SlashCmdList.SHUTUP("gilde + Alternative für Durotar")
on(nil, "PLAYER_TARGET_CHANGED")
assert(#IGN == 0, "Standard: Spiel-Ignore-Liste bleibt unberührt")
assert(ShutUpDB.useBlizzIgnore == false)
assert(ShutUpDB.muted["anna meyer"], "voller Name als Schlüssel: " .. tostring(next(ShutUpDB.muted)))
SlashCmdList.SHUTUP("spiel")
SlashCmdList.SHUTUP("+ Clara Schmidt")
assert(IGN[1] == "Clara Schmidt" and ShutUpDB.muted["clara schmidt"].viaGame, "mit /shutup spiel: AddIgnore mit vollem Namen, war " .. tostring(IGN[1]))
SlashCmdList.SHUTUP("spiel")
-- Chat-Absender mit Realm wird erkannt
local hidden = false
for _, fn in ipairs(filters) do if fn(nil, nil, "hallo", "Anna Meyer-Forever") then hidden = true end end
assert(hidden, "Chat-Absender 'Anna Meyer-Forever' wird ausgeblendet")
local other = false
for _, fn in ipairs(filters) do if fn(nil, nil, "hallo", "Anna Schmidt-Forever") then other = true end end
assert(not other, "gleicher Vorname, anderer Nachname bleibt sichtbar")
SlashCmdList.SHUTUP("ziel")
SlashCmdList.SHUTUP("- anna")
assert(ShutUpDB.muted["anna meyer"] == nil, "frei per Namensanfang")
-- 0.3.0: keine Standardgilden, manuell + / Gilde
SlashCmdList.SHUTUP("gilde - Alternative für Durotar")
assert(#ShutUpDB.guilds == 0, "keine voreingetragenen Gilden")
SlashCmdList.SHUTUP("+ Bob Tester-Forever")
assert(ShutUpDB.muted["bob tester"] and ShutUpDB.muted["bob tester"].guild == "manuell", "manuell eingetragen")
SlashCmdList.SHUTUP("+ Bob")
assert(not ShutUpDB.muted["bob"], "nur Vorname wird abgelehnt")
SlashCmdList.SHUTUP("gilde + Testgilde")
assert(ShutUpDB.guilds[1] == "Testgilde")
SlashCmdList.SHUTUP("gilde - testgilde")
assert(#ShutUpDB.guilds == 0)
SlashCmdList.SHUTUP("- bob")
assert(ShutUpDB.muted["bob tester"] == nil)

-- 0.4.2: dieselbe Nachricht erreicht den Filter einmal je Chatfenster, zählt aber nur einmal
for i = 1, 6 do filters[1](nil, "CHAT_MSG_CHANNEL", "jetzt weißt du woher es seinen namen hat :D", "Lyneia Schattenwald-Forever", nil, "1. Allgemein", nil, nil, nil, nil, "Allgemein", nil, 424242, nil) end
assert(ShutUpDB.muted["lyneia schattenwald"] == nil, "eine Nachricht in mehreren Chatfenstern ist kein Spam")
for i = 1, 6 do filters[1](nil, "CHAT_MSG_CHANNEL", "jetzt weißt du woher es seinen namen hat :D", "Lyneia Schattenwald-Forever", nil, "1. Allgemein", nil, nil, nil, nil, "Allgemein", nil, nil, nil) end
assert(ShutUpDB.muted["lyneia schattenwald"] == nil, "ohne Zeilen-ID: Aufrufe im selben Moment zählen nicht")
-- 0.4.0: Spam-Erkennung
local T, LID = 100, 0
function GetTime() return T end
-- jeder Aufruf = neue Nachricht (5 s später, neue Zeilen-ID)
local function say_(ev, msg, sender, chan, guid) T = T + 5; LID = LID + 1 return filters[1](nil, ev, msg, sender, nil, chan, nil, nil, nil, nil, chan, nil, LID, guid) end
local SPAMTXT = "Verkaufe billig Gold bei www.beispiel-gold.de jetzt zugreifen!"
assert(ShutUpDB.spamOn == true and ShutUpDB.inviteOn == false)
assert(not say_("CHAT_MSG_SAY", SPAMTXT, "Gold Seller-Forever"))
assert(not say_("CHAT_MSG_SAY", SPAMTXT .. " 123", "Gold Seller-Forever"), "Zahlen werden normalisiert, zweiter Treffer noch nicht")
assert(say_("CHAT_MSG_SAY", SPAMTXT, "Gold Seller-Forever"), "dritter Treffer: ausgeblendet")
local e = ShutUpDB.muted["gold seller"]
assert(e and e.kind == "spam" and e.guild == "Spam" and e.sample, "Spammer als spam eingetragen")
assert(SlashCmdList.SHUTUP and ShutUp.KindOf(e) == "spam")
for i = 1, 5 do say_("CHAT_MSG_CHANNEL", SPAMTXT, "Handel Typ-Forever", "2. Handel - Stadt") end
assert(ShutUpDB.muted["handel typ"] == nil, "Handelskanal wird nie gezählt")
for i = 1, 5 do say_("CHAT_MSG_SAY", SPAMTXT, "Kurz Freund-Forever", nil, "friendguid") end
assert(ShutUpDB.muted["kurz freund"] ~= nil, "ohne Freundesprüfung wird er eingetragen")
ShutUpDB.muted["kurz freund"] = nil
C_FriendList.IsFriend = function(g) return g == "friendguid" end
for i = 1, 5 do say_("CHAT_MSG_SAY", SPAMTXT, "Kurz Freund-Forever", nil, "friendguid") end
assert(ShutUpDB.muted["kurz freund"] == nil, "Freunde werden nie als Spam eingetragen")
for i = 1, 5 do say_("CHAT_MSG_SAY", "ok gut", "Kurz Text-Forever") end
assert(ShutUpDB.muted["kurz text"] == nil, "zu kurze Texte zählen nicht")
for i = 1, 5 do say_("CHAT_MSG_PARTY", SPAMTXT, "Gruppe Typ-Forever") end
assert(ShutUpDB.muted["gruppe typ"] == nil, "Gruppenchat wird nie gezählt")
-- Ablauf nach Tagen
ShutUpDB.muted["gold seller"].t = os.time() - 8 * 86400
ShutUpDB.muted["alter hase"] = { name = "Alter Hase", guild = "manuell", kind = "manual", t = os.time() - 80 * 86400 }
on(nil, "ADDON_LOADED", "ShutUp")
assert(ShutUpDB.muted["gold seller"] == nil, "Spam läuft nach 7 Tagen ab")
assert(ShutUpDB.muted["alter hase"], "manuelle Einträge laufen nie ab")
-- Bot-Welle
ShutUpDB.spamWave = true
for _, nm in ipairs({ "Bot Eins", "Bot Zwei", "Bot Drei", "Bot Vier" }) do say_("CHAT_MSG_SAY", SPAMTXT .. " welle", nm .. "-Forever") end
assert(ShutUpDB.muted["bot eins"] and ShutUpDB.muted["bot vier"], "Bot-Welle: alle vier eingetragen")
-- Gildeneinladung / Satzung (Gruppen nie)
local declined, closed = 0, 0
function DeclineGuildInvite() declined = declined + 1 end
function StaticPopup_Hide() end
function ClosePetition() closed = closed + 1 end
local PET = { "guild", "Titel", "", 9, "Wer Ander", false }
function GetPetitionInfo() return unpack(PET) end
on(nil, "GUILD_INVITE_REQUEST", "Wer Ander", "Gilde X")
assert(declined == 0, "Standard: aus")
ShutUpDB.inviteOn = true
on(nil, "GUILD_INVITE_REQUEST", "Wer Ander", "Gilde X")
assert(declined == 1, "Einladung abgelehnt")
on(nil, "PETITION_SHOW")
assert(closed == 1, "fremde Satzung geschlossen")
PET[6] = true
on(nil, "PETITION_SHOW")
assert(closed == 1, "eigene Satzung bleibt")
ShutUpDB.inviteMute = true
on(nil, "GUILD_INVITE_REQUEST", "Wer Ander", "Gilde X")
assert(ShutUpDB.muted["wer ander"].kind == "invite", "Einlader auf der Liste")
-- Gruppeneinladung wird nie angefasst: kein Handler dafür
assert(handlers.OnEvent ~= nil)
print("SHUTUP-TEST OK")
