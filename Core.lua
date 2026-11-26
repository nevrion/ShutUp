-- ShutUp!
-- Allgemeines Ignore-Addon, accountweit (gilt für alle Charaktere, SavedVariables ShutUpDB).
-- Du trägst einzelne Spieler (/shutup + Vorname Nachname) oder ganze Gilden (/shutup gilde + Name) von Hand ein.
-- Es gibt keine voreingetragenen Gilden mehr (bis 0.2.0 waren es zwei feste).
-- 0.4.0: Oberfläche (UI.lua), Gildeneinladungen/-satzungen ablehnen (nie Gruppen), Spam automatisch eintragen.
--
-- WoW bietet keine Abfrage "alle Mitglieder einer fremden Gilde". Das Addon sammelt deshalb auf drei Wegen:
--   1. Passiv: jeder Spieler, den du per Maus, Ziel, Namensplakette oder Gruppe "siehst" (GetGuildInfo).
--   2. Aktiv: /who g-"Gildenname" (Befehl /shutup scan, optional einmal pro Anmeldung), bei mehr als 50 Treffern
--      wird nach Stufenbereichen geteilt.
--   3. Chat: wer schon in der eigenen Liste steht, wird im Chat ausgeblendet, auch wenn die Ignore-Liste
--      des Spiels voll ist (Limit des Spiels: 50 Einträge).

local ADDON = ...
local AAA = {}
_G.ShutUp = AAA

local PREFIX = "|cffe53935[ShutUp!]|r "
-- Bis 0.2.0 voreingetragen; wird beim ersten Start von 0.3.0 aus der Gildenliste entfernt (siehe ADDON_LOADED)
local OLD_DEFAULT_GUILDS = { "Alternative für Durotar", "Alternative für Azeroth" }
local DB_VERSION = 5
local MANUAL = "manuell"
local SPAM, INVITE = "Spam", "Einladung"
local MAX_LEVEL = 90
local WHO_LIMIT = 50
local WHO_INTERVAL = 6 -- Sekunden zwischen /who-Abfragen (das Spiel drosselt)

local db

local function changed() if AAA.OnChange then AAA.OnChange() end end

---------------------------------------------------------------------------
-- Hilfen
---------------------------------------------------------------------------

local function say(msg) print(PREFIX .. msg) end

-- Gildennamen vergleichbar machen: Kleinbuchstaben, ü -> u, Leerzeichen am Rand weg
local function normGuild(s)
  if not s then return "" end
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  s = s:gsub("Ü", "ü"):gsub("Ä", "ä"):gsub("Ö", "ö")
  s = s:gsub("ü", "u"):gsub("ä", "a"):gsub("ö", "o"):gsub("ß", "ss")
  return s:lower()
end

-- Charnamen in WoW Forever bestehen aus Vor- und Nachname. UnitName(unit) liefert dort nur den VORNAMEN; der volle Name steht in
-- GetUnitName(unit, true) als "Vorname Nachname-Forever" (Realm hinten), Chat-Absender haben dieselbe Form. Wir arbeiten immer mit
-- dem vollen Namen ohne Realm ("Vorname Nachname"); ein Eintrag nur mit Vornamen ist mehrdeutig und wird weder ignoriert noch gespeichert.
local function stripRealm(n)
  n = (n or ""):gsub("^%s+", ""):gsub("%s+$", "")
  return n:match("^[^-]+") or n
end

local function isFullName(n)
  return n and n:find(" ", 1, true) ~= nil
end

-- Voller Name einer Einheit: der längste Name, den das Spiel kennt und der mit dem Vornamen beginnt
local function fullNameOf(unit)
  local short = (UnitName(unit)) or ""
  if short == "" then return nil end
  local best = short
  local function consider(n)
    n = type(n) == "string" and stripRealm(n) or nil
    if n and #n > #best and n:lower():sub(1, #short) == short:lower() then best = n end
  end
  if GetUnitName then consider(GetUnitName(unit, true)) end
  if UnitFullName then consider((UnitFullName(unit))) end
  return best
end

-- "Vorname Nachname-Realm" -> "vorname nachname" (Vergleichsschlüssel)
local function nameKey(name)
  if not name then return nil end
  return (stripRealm(name):lower():gsub("%s+", " "))
end

local function guildSet()
  local t = {}
  for _, g in ipairs(db.guilds) do t[normGuild(g)] = g end
  return t
end

local function countKeys(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

---------------------------------------------------------------------------
-- Eigene Liste + Spiel-Ignore
---------------------------------------------------------------------------

-- db.muted[schluessel] = { name = "Vollname", guild = "Gilde" oder "manuell", t = Zeit }
local function numBlizzIgnores()
  if C_FriendList and C_FriendList.GetNumIgnores then return C_FriendList.GetNumIgnores() end
  if GetNumIgnores then return GetNumIgnores() end
  return 0
end

local function blizzIgnore(name)
  if not db.useBlizzIgnore then return false end
  if numBlizzIgnores() >= 50 then return false end
  if C_FriendList and C_FriendList.AddIgnore then
    C_FriendList.AddIgnore(name)
  elseif AddIgnore then
    AddIgnore(name)
  else
    return false
  end
  return true
end

local function isMuted(name)
  local k = nameKey(name)
  return k and db.muted[k] ~= nil
end

-- Art eines Eintrags: "manual", "guild", "spam" oder "invite" (ältere Einträge ohne kind: aus dem Grund abgeleitet)
local function kindOf(e)
  if e.kind then return e.kind end
  return (not e.guild or e.guild == MANUAL) and "manual" or "guild"
end

-- Rückgabe: true = neu eingetragen, sonst false + Grund ("vorname", "ich", "schon", "leer")
-- reason = Gildenname, MANUAL, SPAM oder INVITE; sample = Beispieltext bei Spam
local function mute(name, reason, quiet, kind, sample)
  name = stripRealm(name)
  local k = nameKey(name)
  if not k or k == "" then return false, "leer" end
  if not isFullName(name) then return false, "vorname" end -- nur Vorname: mehrdeutig, kein Ignorieren
  if k == nameKey(fullNameOf("player")) then return false, "ich" end
  if db.muted[k] then return false, "schon" end
  reason = reason or MANUAL
  kind = kind or ((reason == MANUAL) and "manual" or "guild")
  local viaGame = blizzIgnore(name)
  -- viaGame merken: nur was wir selbst in die Spiel-Liste gesetzt haben, nehmen wir beim Freigeben wieder heraus
  db.muted[k] = { name = name, guild = reason, kind = kind, t = time(), viaGame = viaGame or nil, sample = sample }
  if db.announce and not quiet then
    say(string.format("%s (%s) wird ignoriert%s.", name, reason, viaGame and "" or " (nur Chat-Filter)"))
  end
  changed()
  return true
end

-- Spieler freigeben (Schlüssel oder eindeutiger Namensanfang). Rückgabe: voller Name oder nil
local function unmute(query)
  local k = nameKey(query)
  if not k or k == "" then return nil end
  if not db.muted[k] then
    local hit, n = nil, 0
    for key in pairs(db.muted) do if key:sub(1, #k) == k then hit, n = key, n + 1 end end
    if n == 1 then k = hit end
  end
  local e = db.muted[k]
  if not e then return nil end
  db.muted[k] = nil
  changed()
  if e.viaGame then
    if C_FriendList and C_FriendList.DelIgnore then C_FriendList.DelIgnore(e.name) elseif DelIgnore then DelIgnore(e.name) end
  end
  return e.name
end

-- Name aus dem Befehl, sonst aus dem Ziel
local function nameOrTarget(rest)
  if rest and rest ~= "" then return rest end
  if UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
    return fullNameOf("target")
  end
end

-- Gilde eintragen/entfernen (name leer: Gilde des Ziels)
local function guildOrTarget(name)
  name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" and UnitExists("target") and UnitIsPlayer("target") then name = (GetGuildInfo("target")) or "" end
  return name
end

function AAA.AddGuild(name)
  name = guildOrTarget(name)
  if name == "" then say("Kein Gildenname angegeben und das Ziel hat keine Gilde.") return false end
  for _, g in ipairs(db.guilds) do if normGuild(g) == normGuild(name) then say("Die Gilde ist schon in der Liste.") return false end end
  table.insert(db.guilds, name)
  say("Gilde hinzugefügt: " .. name .. ". Mitglieder werden beim Sehen oder mit /shutup scan eingetragen.")
  changed()
  return true
end

function AAA.RemoveGuild(name)
  name = guildOrTarget(name)
  for i, g in ipairs(db.guilds) do
    if normGuild(g) == normGuild(name) then
      table.remove(db.guilds, i)
      local freed = 0
      for key, e in pairs(db.muted) do
        if kindOf(e) == "guild" and e.guild and normGuild(e.guild) == normGuild(g) then unmute(key) freed = freed + 1 end
      end
      say(string.format("Gilde entfernt: %s (%d Spieler freigegeben).", g, freed))
      changed()
      return true
    end
  end
  say("Diese Gilde steht nicht in der Liste.")
  return false
end

---------------------------------------------------------------------------
-- Bekannte Personen (Freunde, Gilde, Gruppe) werden nie automatisch ignoriert und dürfen Gildeneinladungen schicken
---------------------------------------------------------------------------

local function sameChar(a, b)
  if not a or not b or a == "" or b == "" then return false end
  return a == b or a:sub(1, #b + 1) == b .. " " or b:sub(1, #a + 1) == a .. " "
end

local function isFriendName(name)
  local k = nameKey(name)
  if not k or k == "" then return false end
  if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
    for i = 1, (C_FriendList.GetNumFriends() or 0) do
      local info = C_FriendList.GetFriendInfoByIndex(i)
      if info and info.name and sameChar(nameKey(info.name), k) then return true end
    end
  end
  if C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends then
    for i = 1, (BNGetNumFriends() or 0) do
      local ok, acc = pcall(C_BattleNet.GetFriendAccountInfo, i)
      local ga = ok and acc and acc.gameAccountInfo
      if ga and ga.characterName and sameChar(nameKey(ga.characterName), k) then return true end
    end
  end
  return false
end

local function isKnown(name, guid)
  if not name then return false end
  if guid and guid ~= "" then
    if C_FriendList and C_FriendList.IsFriend and pcall(C_FriendList.IsFriend, guid) and C_FriendList.IsFriend(guid) then return true end
    if IsGuildMember and pcall(IsGuildMember, guid) and IsGuildMember(guid) then return true end
  end
  for _, fname in ipairs({ "UnitIsInMyGuild", "UnitInParty", "UnitInRaid" }) do
    local fn = _G[fname]
    if fn then
      local ok, r = pcall(fn, name)
      if ok and r then return true end
    end
  end
  return isFriendName(name)
end

---------------------------------------------------------------------------
-- Spam-Erkennung: derselbe Text mehrfach in kurzer Zeit -> Absender automatisch auf die Liste
---------------------------------------------------------------------------

local SPAM_EVENTS = { CHAT_MSG_SAY = true, CHAT_MSG_YELL = true, CHAT_MSG_WHISPER = true, CHAT_MSG_CHANNEL = true }
-- Kanäle, in denen Wiederholungen normal sind (Handel, Gruppensuche), werden nie gezählt
local SKIP_CHANNELS = { "handel", "trade", "gruppensuche", "lookingforgroup", "suche nach gruppe", "looking for group" }
local spamLog, waveLog = {}, {}

local function normText(msg)
  msg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "")
  msg = msg:lower():gsub("%d", ""):gsub("[%p%s]", "")
  return msg
end

local function skipChannel(...)
  for i = 1, select("#", ...) do
    local c = select(i, ...)
    if type(c) == "string" then
      c = c:lower()
      for _, w in ipairs(SKIP_CHANNELS) do if c:find(w, 1, true) then return true end end
    end
  end
  return false
end

local function nowT() return GetTime and GetTime() or time() end

local function spamHit(name, text, guid)
  if isKnown(name, guid) then return false end
  local sample = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
  if #sample > 70 then sample = sample:sub(1, 70) .. "..." end
  local ok = mute(name, SPAM, true, "spam", sample)
  if ok then say(string.format('Spam erkannt: %s wird ignoriert ("%s"). Freigeben: /shutup - %s', stripRealm(name), sample, stripRealm(name))) end
  return ok
end

local function spamCheck(event, msg, sender, channelName, baseName, guid)
  if not db.spamOn or not SPAM_EVENTS[event] or type(msg) ~= "string" or not sender then return false end
  local name = stripRealm(sender)
  if not isFullName(name) then return false end
  if event == "CHAT_MSG_CHANNEL" and skipChannel(channelName, baseName) then return false end
  local k = nameKey(name)
  if k == nameKey(fullNameOf("player")) then return false end
  local norm = normText(msg)
  if #norm < (db.spamMinLen or 15) then return false end
  local now, window = nowT(), db.spamWindow or 120
  -- Wiederholungen desselben Absenders
  local per = spamLog[k]
  if not per then per = {} spamLog[k] = per end
  local fresh = {}
  for _, t in ipairs(per[norm] or {}) do if now - t <= window then fresh[#fresh + 1] = t end end
  -- Doppelaufruf derselben Nachricht (andere Chatfenster, ohne Zeilen-ID): weniger als 1 s Abstand zählt nicht
  if #fresh > 0 and now - fresh[#fresh] < 1 then return false end
  fresh[#fresh + 1] = now
  per[norm] = fresh
  if #fresh >= (db.spamCount or 3) then
    spamLog[k] = nil
    return spamHit(name, msg, guid)
  end
  -- Bot-Welle: derselbe Text von mehreren verschiedenen Absendern
  if db.spamWave then
    local w = waveLog[norm] or {}
    local keep, senders, n = {}, {}, 0
    for _, e in ipairs(w) do
      if now - e.t <= window then keep[#keep + 1] = e if not senders[e.key] then senders[e.key] = e.name n = n + 1 end end
    end
    keep[#keep + 1] = { t = now, key = k, name = name }
    if not senders[k] then senders[k] = name n = n + 1 end
    waveLog[norm] = keep
    if n >= (db.waveSenders or 4) then
      waveLog[norm] = nil
      local hit = false
      for _, nm in pairs(senders) do if spamHit(nm, msg, nil) then hit = true end end
      return hit
    end
  end
  return false
end

local function cleanupSpam()
  local now, window = nowT(), db and db.spamWindow or 120
  for k, per in pairs(spamLog) do
    for norm, list in pairs(per) do
      if #list == 0 or now - list[#list] > window then per[norm] = nil end
    end
    if next(per) == nil then spamLog[k] = nil end
  end
  for norm, w in pairs(waveLog) do
    if #w == 0 or now - w[#w].t > window then waveLog[norm] = nil end
  end
end

---------------------------------------------------------------------------
-- Gildeneinladungen und Gildensatzungen ablehnen (nie Gruppen oder Schlachtzüge)
---------------------------------------------------------------------------

local function shouldDecline(who)
  if not db.inviteOn then return false end
  if who and isMuted(who) then return true end
  if db.inviteOnlyUnknown and who and isKnown(who) then return false end
  return true
end

local function onGuildInvite(inviter, guildName)
  if not shouldDecline(inviter) then return end
  if DeclineGuildInvite then DeclineGuildInvite() end
  if StaticPopup_Hide then StaticPopup_Hide("GUILD_INVITE") end
  say(string.format("Gildeneinladung von %s%s abgelehnt.", tostring(inviter or "?"), guildName and (" (" .. guildName .. ")") or ""))
  if db.inviteMute and inviter then mute(inviter, INVITE, true, "invite") end
end

local function onPetition()
  if not db.inviteOn or not GetPetitionInfo then return end
  local ok, _, title, _, _, originator, isOriginator = pcall(GetPetitionInfo)
  if not ok or isOriginator then return end -- eigene Satzung (Gilde gründen) bleibt unberührt
  if originator and not shouldDecline(originator) then return end
  if ClosePetition then ClosePetition() end
  say(string.format("Gildensatzung%s von %s nicht angezeigt.", title and (' "' .. title .. '"') or "", tostring(originator or "?")))
  if db.inviteMute and originator then mute(originator, INVITE, true, "invite") end
end

---------------------------------------------------------------------------
-- 1. Passiv: Einheiten ansehen
---------------------------------------------------------------------------

local function checkUnit(unit)
  if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return end
  if UnitIsUnit(unit, "player") then return end
  local guild = GetGuildInfo(unit)
  if not guild then return end
  local hit = guildSet()[normGuild(guild)]
  if not hit then return end
  local name = fullNameOf(unit)
  if name then mute(name, hit) end
end

---------------------------------------------------------------------------
-- 2. Aktiv: /who
---------------------------------------------------------------------------

local queue, current = {}, nil
local scanStats

local function whoCount()
  if C_FriendList and C_FriendList.GetNumWhoResults then return C_FriendList.GetNumWhoResults() end
  if GetNumWhoResults then return GetNumWhoResults() end
  return 0, 0
end

local function whoInfo(i)
  if C_FriendList and C_FriendList.GetWhoInfo then
    local info = C_FriendList.GetWhoInfo(i)
    if info then return info.fullName, info.fullGuildName or info.guild end
  elseif GetWhoInfo then
    local name, guild = GetWhoInfo(i)
    return name, guild
  end
end

local function sendWho(filter)
  if C_FriendList and C_FriendList.SetWhoToUi then C_FriendList.SetWhoToUi(true) end
  if C_FriendList and C_FriendList.SendWho then
    C_FriendList.SendWho(filter)
  elseif SendWho then
    SendWho(filter)
  end
end

-- WoW Forever erlaubt SendWho nur nach einem echten Klick oder getippten Befehl (nicht aus Timern, sonst ADDON_ACTION_BLOCKED).
-- Deshalb sendet jeder Aufruf von AAA.Scan (Befehl oder Knopf) genau EINE Abfrage; weitere folgen beim nächsten Aufruf.
local function pendingScan() return #queue + (current and 1 or 0) end
AAA.PendingScan = pendingScan

local function startQuery()
  local q = table.remove(queue, 1)
  if not q then
    if scanStats then
      say(string.format("Suche fertig: %d neue Spieler eingetragen, %d Abfragen.", scanStats.new, scanStats.queries))
      scanStats = nil
    end
    changed()
    return
  end
  current = q
  scanStats.queries = scanStats.queries + 1
  local filter = string.format('g-"%s"', q.guild)
  if q.minL and q.maxL then filter = filter .. string.format(" %d-%d", q.minL, q.maxL) end
  local ok, err = pcall(sendWho, filter)
  if not ok then
    say("Die Abfrage wurde abgelehnt: " .. tostring(err))
    current, queue, scanStats = nil, {}, nil
    changed()
    return
  end
  -- Antwortet der Server nicht, nach Zeitüberschreitung wieder freigeben
  local mine = q
  C_Timer.After(WHO_INTERVAL * 2, function()
    if current == mine then
      current = nil
      say("Keine Antwort auf die Abfrage. Mit /shutup scan erneut versuchen.")
      changed()
    end
  end)
end

local function onWhoResult()
  if not current then return end
  local q = current
  current = nil
  local shown, total = whoCount()
  local want = normGuild(q.guild)
  local added = 0
  for i = 1, shown do
    local name, guild = whoInfo(i)
    if name and normGuild(guild) == want then
      if mute(name, q.guild, true) then added = added + 1 end
    end
  end
  scanStats.new = scanStats.new + added
  -- Mehr Treffer als das Spiel anzeigt: Stufenbereich halbieren
  if (total or shown) > shown and shown >= WHO_LIMIT then
    local lo, hi = q.minL or 1, q.maxL or MAX_LEVEL
    if hi > lo then
      local mid = math.floor((lo + hi) / 2)
      table.insert(queue, { guild = q.guild, minL = lo, maxL = mid })
      table.insert(queue, { guild = q.guild, minL = mid + 1, maxL = hi })
    end
  end
  if #queue > 0 then
    say(string.format("%s: %d neu eingetragen. Noch %d Abfragen offen: /shutup scan (oder Knopf im Fenster) für die nächste.", q.guild, added, #queue))
  else
    say(string.format("Suche fertig: %d neue Spieler eingetragen, %d Abfragen.", scanStats.new, scanStats.queries))
    scanStats = nil
  end
  changed()
end

-- Muss aus einem Klick oder getippten Befehl aufgerufen werden
function AAA.Scan()
  if db.whoBlocked then say("Das Spiel blockiert die /who-Suche für Addons. Es bleibt die Erkennung über Maus, Ziel, Namensplakette und Gruppe.") return end
  if current then say("Ich warte noch auf die Antwort des Servers.") return end
  if #queue == 0 then
    for _, g in ipairs(db.guilds) do table.insert(queue, { guild = g }) end
    if #queue == 0 then say("Keine Gilden in der Liste. Eine Gilde trägst du mit /shutup gilde + Name ein.") return end
    scanStats = { new = 0, queries = 0 }
    db.lastScan = time()
  end
  scanStats = scanStats or { new = 0, queries = 0 }
  startQuery()
end

---------------------------------------------------------------------------
-- 3. Chat-Filter
---------------------------------------------------------------------------

-- Der Filter wird für JEDES Chatfenster aufgerufen, in dem die Nachricht erscheint: dieselbe Nachricht kommt mehrfach an
-- (bei drei Tabs dreimal, sonst wäre jeder lange Satz "Spam"). Deshalb pro Zeilen-ID nur einmal zählen.
local lastLine, lastResult
local function chatFilter(_, event, msg, sender, _, channelName, _, _, _, _, baseName, _, lineID, guid)
  if not db or not sender then return end
  if db.hideChat and isMuted(sender) then return true end
  if lineID and lineID == lastLine then return lastResult end
  local r = spamCheck(event, msg, sender, channelName, baseName, guid) or nil
  lastLine, lastResult = lineID, r
  return r
end

local CHAT_EVENTS = {
  "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_WHISPER",
  "CHAT_MSG_CHANNEL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
  "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
}
for _, ev in ipairs(CHAT_EVENTS) do ChatFrame_AddMessageEventFilter(ev, chatFilter) end

---------------------------------------------------------------------------
-- Befehle
---------------------------------------------------------------------------

local function onOff(v) return v and "|cff66bb6aan|r" or "|cffef5350aus|r" end

local function help()
  say("Befehle (ohne Befehl öffnet sich das Fenster):")
  print("  /shutup + <Vorname Nachname> - Spieler ignorieren (ohne Namen: dein Ziel)")
  print("  /shutup - <Vorname Nachname> - Spieler wieder freigeben (Namensanfang genügt, ohne Namen: dein Ziel)")
  print("  /shutup gilde + <Name> - ganze Gilde ignorieren (ohne Namen: Gilde deines Ziels)")
  print("  /shutup gilde - <Name> - Gilde entfernen und ihre Mitglieder freigeben")
  print("  /shutup liste [spieler] - Gilden und Zahl der Einträge, mit \"spieler\" alle Namen")
  print("  /shutup scan - Gilden der Liste per /who absuchen und Treffer ignorieren")
  print("  /shutup ziel - Diagnose: wie der Client Vor- und Nachname des Ziels (sonst deines Chars) liefert")
  print("  /shutup chat - Chat-Filter an/aus (jetzt " .. onOff(db.hideChat) .. ")")
  print("  /shutup spiel - zusätzlich in die Spiel-Ignore-Liste eintragen (jetzt " .. onOff(db.useBlizzIgnore) .. ")")
  print("  /shutup gildeneinladung - Gildeneinladungen und -satzungen ablehnen (jetzt " .. onOff(db.inviteOn) .. ")")
  print("  /shutup spam - Spam automatisch eintragen (jetzt " .. onOff(db.spamOn) .. ")")
  print("  /shutup meldung - Meldungen bei neuen Einträgen (jetzt " .. onOff(db.announce) .. ")")
end

local function slash(msg)
  msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, rest = msg:match("^(%S+)%s*(.-)$")
  cmd = cmd and cmd:lower() or ""
  if cmd == "scan" or cmd == "suche" then
    AAA.Scan()
  elseif cmd == "+" or cmd == "spieler+" or cmd == "ignore" then
    local name = nameOrTarget(rest)
    if not name then say("Nutzung: /shutup + Vorname Nachname (oder Spieler anvisieren und /shutup +)") return end
    local ok, why = mute(name, MANUAL)
    if not ok then
      if why == "vorname" then say("Bitte den vollen Namen angeben (Vorname Nachname), nur der Vorname ist mehrdeutig.")
      elseif why == "ich" then say("Du kannst dich nicht selbst ignorieren.")
      elseif why == "schon" then say(stripRealm(name) .. " steht schon auf der Liste.") end
    end
  elseif cmd == "-" or cmd == "frei" or cmd == "spieler-" then
    local name = nameOrTarget(rest)
    local full = name and unmute(name)
    if full then
      say(full .. " ist wieder frei." .. (db.guilds[1] and " Gehört der Spieler zu einer Gilde der Liste, wird er beim nächsten Sehen oder Suchen erneut eingetragen." or ""))
    else
      say("Unbekannter Spieler.")
    end
  elseif cmd == "liste" or cmd == "list" or cmd == "status" then
    local perGuild, manual = {}, 0
    for _, e in pairs(db.muted) do
      if e.guild == MANUAL or not e.guild then manual = manual + 1 else perGuild[e.guild] = (perGuild[e.guild] or 0) + 1 end
    end
    say(string.format("%d Spieler eingetragen, %d/50 Plätze der Spiel-Ignore-Liste belegt.", countKeys(db.muted), numBlizzIgnores()))
    print(string.format("  Einzeln eingetragen: %d", manual))
    if #db.guilds == 0 then print("  Keine Gilden eingetragen (/shutup gilde + Name).") end
    for _, g in ipairs(db.guilds) do print(string.format("  Gilde %s: %d", g, perGuild[g] or 0)) end
    if rest:lower() == "spieler" then
      local names = {}
      for _, e in pairs(db.muted) do names[#names + 1] = string.format("%s (%s)", e.name, e.guild or MANUAL) end
      table.sort(names)
      for _, n in ipairs(names) do print("  " .. n) end
    end
  elseif cmd == "gilde" then
    local op, name = rest:match("^([%+%-])%s*(.-)$")
    if not op then say('Nutzung: /shutup gilde + Name  oder  /shutup gilde - Name') return end
    if op == "+" then AAA.AddGuild(name) else AAA.RemoveGuild(name) end
  elseif cmd == "ich" or cmd == "ziel" then
    -- Diagnose: wie liefert der Client Vor- und Nachname? (Ziel, sonst du selbst)
    local unit = (UnitExists("target") and UnitIsPlayer("target")) and "target" or "player"
    say("Einheit: " .. unit)
    print("  UnitName: " .. tostring((UnitName(unit))))
    if GetUnitName then print("  GetUnitName(.., true): " .. tostring(GetUnitName(unit, true))) end
    if UnitFullName then print("  UnitFullName: " .. tostring((UnitFullName(unit)))) end
    print("  Gilde: " .. tostring((GetGuildInfo(unit))))
    print("  Addon benutzt: " .. tostring(fullNameOf(unit)) .. " (Schlüssel: " .. tostring(nameKey(fullNameOf(unit))) .. ")")
  elseif cmd == "chat" then
    db.hideChat = not db.hideChat say("Chat-Filter: " .. onOff(db.hideChat))
  elseif cmd == "spiel" then
    db.useBlizzIgnore = not db.useBlizzIgnore say("Spiel-Ignore-Liste mitbenutzen: " .. onOff(db.useBlizzIgnore))
  elseif cmd == "meldung" then
    db.announce = not db.announce say("Meldungen: " .. onOff(db.announce))
  elseif cmd == "gildeneinladung" or cmd == "einladung" then
    db.inviteOn = not db.inviteOn say("Gildeneinladungen und -satzungen ablehnen: " .. onOff(db.inviteOn) .. " (Gruppen bleiben immer unberührt)")
  elseif cmd == "spam" then
    db.spamOn = not db.spamOn say("Spam automatisch eintragen: " .. onOff(db.spamOn))
  elseif cmd == "hilfe" or cmd == "help" or cmd == "?" then
    help()
  elseif cmd == "" or cmd == "fenster" or cmd == "einstellungen" then
    if AAA.Open then AAA.Open(cmd == "einstellungen" and "settings" or "list") else help() end
  else
    help()
  end
end

SLASH_SHUTUP1 = "/shutup"
SlashCmdList["SHUTUP"] = slash

---------------------------------------------------------------------------
-- Ereignisse
---------------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("WHO_LIST_UPDATE")
pcall(f.RegisterEvent, f, "ADDON_ACTION_BLOCKED")
pcall(f.RegisterEvent, f, "GUILD_INVITE_REQUEST")
pcall(f.RegisterEvent, f, "PETITION_SHOW")

f:SetScript("OnEvent", function(_, event, arg1, arg2)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    -- ShutUpDB; Altbestand aus AntifaAktionAzeroth (AAADB) wird übernommen, falls die Datei kopiert wurde
    ShutUpDB = ShutUpDB or AAADB or {}
    db = ShutUpDB
    db.guilds = db.guilds or {}
    db.muted = db.muted or {}
    -- 0.3.0: die zwei früher fest voreingetragenen Gilden raus. Bereits eingetragene Spieler bleiben auf der Liste
    -- (mit /shutup - freigeben), nur neue Treffer über diese Gilden gibt es nicht mehr. Wer sie will, trägt sie wieder von Hand ein.
    if (db.ver or 0) < DB_VERSION then
      -- 0.3.0: die Spiel-Ignore-Liste bleibt für normale Ignores frei, ShutUp! nutzt nur seine Liste + Chat-Filter
      -- (wer sie doch mitbenutzen will: /shutup spiel). Schon in der Spiel-Liste stehende Einträge bleiben dort unberührt.
      db.useBlizzIgnore = false
      db.whoBlocked, db.autoScan = nil, nil -- 0.4.1: Suche nur noch per Klick/Befehl, Sperre neu prüfen
      local old = {}
      for _, g in ipairs(OLD_DEFAULT_GUILDS) do old[normGuild(g)] = true end
      for i = #db.guilds, 1, -1 do
        if old[normGuild(db.guilds[i])] then table.remove(db.guilds, i) end
      end
      db.ver = DB_VERSION
    end
    -- Einträge aus 0.1.0 mit nur dem Vornamen sind mehrdeutig: aus der eigenen Liste entfernen (Spiel-Ignore-Liste bleibt unberührt)
    local legacy = 0
    for k, e in pairs(db.muted) do
      if not isFullName(e.name or k) then db.muted[k] = nil; legacy = legacy + 1 end
    end
    if legacy > 0 then db.legacyRemoved = (db.legacyRemoved or 0) + legacy end
    if db.hideChat == nil then db.hideChat = true end
    if db.useBlizzIgnore == nil then db.useBlizzIgnore = false end
    if db.announce == nil then db.announce = true end
    -- 0.4.0: Spam-Erkennung (Standard an) und Gildeneinladungen ablehnen (Standard aus, nur von Unbekannten)
    if db.spamOn == nil then db.spamOn = true end
    db.spamCount, db.spamWindow, db.spamMinLen = db.spamCount or 3, db.spamWindow or 120, db.spamMinLen or 15
    if db.spamExpireDays == nil then db.spamExpireDays = 7 end
    if db.spamWave == nil then db.spamWave = false end
    db.waveSenders = db.waveSenders or 4
    if db.inviteOn == nil then db.inviteOn = false end
    if db.inviteOnlyUnknown == nil then db.inviteOnlyUnknown = true end
    if db.inviteMute == nil then db.inviteMute = false end
    AAA.db = db
    -- automatisch eingetragener Spam läuft nach spamExpireDays ab (0 = nie)
    if (db.spamExpireDays or 0) > 0 then
      for k, e in pairs(db.muted) do
        if kindOf(e) == "spam" and (time() - (e.t or 0)) > db.spamExpireDays * 86400 then unmute(k) end
      end
    end
  elseif event == "PLAYER_LOGIN" then
    -- Kein Nachtragen in die Spiel-Ignore-Liste beim Login (0.3.0): der Server kennt Offline-Spieler nicht und antwortet
    -- mit gelben Systemmeldungen "Antwort eines unbekannten Freundes vom Server" (Pierre 2026-11-26, Ursache der Meldungen in 0.2.0)
    C_Timer.After(10, function()
      if (db.legacyRemoved or 0) > 0 then
        say(string.format("%d alte Einträge nur mit Vornamen entfernt (zu mehrdeutig). In der Spiel-Ignore-Liste habe ich nichts verändert: bitte dort prüfen, ob falsche Vornamen stehen.", db.legacyRemoved))
        db.legacyRemoved = nil
      end
    end)
    if C_Timer.NewTicker then C_Timer.NewTicker(120, cleanupSpam) end
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    checkUnit("mouseover")
  elseif event == "PLAYER_TARGET_CHANGED" then
    checkUnit("target")
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    checkUnit(arg1)
  elseif event == "GROUP_ROSTER_UPDATE" then
    local n = GetNumGroupMembers()
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, n do checkUnit(prefix .. i) end
  elseif event == "WHO_LIST_UPDATE" then
    onWhoResult()
  elseif event == "GUILD_INVITE_REQUEST" then
    onGuildInvite(arg1, arg2)
  elseif event == "PETITION_SHOW" then
    onPetition()
  elseif event == "ADDON_ACTION_BLOCKED" then
    -- Das Spiel erlaubt die /who-Abfrage aus einem Addon nicht: Suche abschalten, passive Erkennung bleibt
    if arg1 == ADDON and current then
      db.whoBlocked = true
      current, queue, scanStats = nil, {}, nil
      changed()
      say("Das Spiel blockiert die /who-Suche für Addons. Die Suche ist abgeschaltet; es bleibt die Erkennung über Maus, Ziel, Namensplakette und Gruppe.")
    end
  end
end)

-- Schnittstelle für die Oberfläche (UI.lua)
AAA.Say = say
AAA.Mute = function(name) return mute(name, MANUAL) end
AAA.Unmute = unmute
AAA.KindOf = kindOf
AAA.NameOrTarget = nameOrTarget
AAA.NumBlizz = numBlizzIgnores
AAA.MANUAL, AAA.SPAM, AAA.INVITE = MANUAL, SPAM, INVITE
