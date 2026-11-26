-- ShutUp!
-- Allgemeines Ignore-Addon, accountweit (gilt für alle Charaktere, SavedVariables AAADB).
-- Du trägst einzelne Spieler (/shutup + Vorname Nachname) oder ganze Gilden (/shutup gilde + Name) von Hand ein.
-- Es gibt keine voreingetragenen Gilden mehr (bis 0.2.0 waren es zwei feste).
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
local DB_VERSION = 3
local MANUAL = "manuell"
local MAX_LEVEL = 90
local WHO_LIMIT = 50
local WHO_INTERVAL = 6 -- Sekunden zwischen /who-Abfragen (das Spiel drosselt)

local db

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

-- Rückgabe: true = neu eingetragen, sonst false + Grund ("vorname", "ich", "schon", "leer")
local function mute(name, guild, quiet)
  name = stripRealm(name)
  local k = nameKey(name)
  if not k or k == "" then return false, "leer" end
  if not isFullName(name) then return false, "vorname" end -- nur Vorname: mehrdeutig, kein Ignorieren
  if k == nameKey(fullNameOf("player")) then return false, "ich" end
  if db.muted[k] then return false, "schon" end
  db.muted[k] = { name = name, guild = guild or MANUAL, t = time() }
  local viaGame = blizzIgnore(name)
  if db.announce and not quiet then
    say(string.format("%s (%s) wird ignoriert%s.", name, guild or MANUAL, viaGame and "" or " (nur Chat-Filter)"))
  end
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
  if C_FriendList and C_FriendList.DelIgnore then C_FriendList.DelIgnore(e.name) elseif DelIgnore then DelIgnore(e.name) end
  return e.name
end

-- Name aus dem Befehl, sonst aus dem Ziel
local function nameOrTarget(rest)
  if rest and rest ~= "" then return rest end
  if UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
    return fullNameOf("target")
  end
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

local queue, running, current = {}, false, nil
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

local function nextQuery()
  local q = table.remove(queue, 1)
  if not q then
    running, current = false, nil
    if scanStats then
      say(string.format("Suche fertig: %d neue Spieler eingetragen, %d Abfragen.", scanStats.new, scanStats.queries))
      scanStats = nil
    end
    return
  end
  current = q
  scanStats.queries = scanStats.queries + 1
  local filter = string.format('g-"%s"', q.guild)
  if q.minL and q.maxL then filter = filter .. string.format(" %d-%d", q.minL, q.maxL) end
  local ok, err = pcall(sendWho, filter)
  if not ok then
    say("Die Abfrage wurde abgelehnt: " .. tostring(err))
    running, current, queue = false, nil, {}
    scanStats = nil
    return
  end
  -- Falls keine Antwort kommt (Spiel drosselt), nach Zeitüberschreitung weitermachen
  local mine = q
  C_Timer.After(WHO_INTERVAL * 2, function()
    if current == mine then
      current = nil
      C_Timer.After(1, nextQuery)
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
  C_Timer.After(WHO_INTERVAL, nextQuery)
end

function AAA.Scan()
  if running then say("Es läuft schon eine Suche.") return end
  if db.whoBlocked then say("Das Spiel blockiert die /who-Suche für Addons (siehe frühere Meldung). Nur die passive Erkennung ist aktiv.") return end
  queue = {}
  for _, g in ipairs(db.guilds) do table.insert(queue, { guild = g }) end
  if #queue == 0 then say("Keine Gilden in der Liste. Eine Gilde trägst du mit /shutup gilde + Name ein.") return end
  scanStats = { new = 0, queries = 0 }
  running = true
  db.lastScan = time()
  say(string.format("Suche gestartet (%d Gilden). Das dauert wegen der Abfrage-Sperre eine Weile.", #queue))
  nextQuery()
end

---------------------------------------------------------------------------
-- 3. Chat-Filter
---------------------------------------------------------------------------

local function chatFilter(_, _, _, sender)
  if db and db.hideChat and sender and isMuted(sender) then return true end
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
  say("Befehle:")
  print("  /shutup + <Vorname Nachname> - Spieler ignorieren (ohne Namen: dein Ziel)")
  print("  /shutup - <Vorname Nachname> - Spieler wieder freigeben (Namensanfang genügt, ohne Namen: dein Ziel)")
  print("  /shutup gilde + <Name> - ganze Gilde ignorieren (ohne Namen: Gilde deines Ziels)")
  print("  /shutup gilde - <Name> - Gilde entfernen und ihre Mitglieder freigeben")
  print("  /shutup liste [spieler] - Gilden und Zahl der Einträge, mit \"spieler\" alle Namen")
  print("  /shutup scan - Gilden der Liste per /who absuchen und Treffer ignorieren")
  print("  /shutup ziel - Diagnose: wie der Client Vor- und Nachname des Ziels (sonst deines Chars) liefert")
  print("  /shutup chat - Chat-Filter an/aus (jetzt " .. onOff(db.hideChat) .. ")")
  print("  /shutup spiel - Spiel-Ignore-Liste mitbenutzen (jetzt " .. onOff(db.useBlizzIgnore) .. ")")
  print("  /shutup auto - Suche bei der Anmeldung (jetzt " .. onOff(db.autoScan) .. ")")
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
    if name == "" then
      -- Gilde des Ziels
      if UnitExists("target") and UnitIsPlayer("target") then name = (GetGuildInfo("target")) or "" end
      if name == "" then say("Kein Gildenname angegeben und das Ziel hat keine Gilde.") return end
    end
    if op == "+" then
      for _, g in ipairs(db.guilds) do if normGuild(g) == normGuild(name) then say("Die Gilde ist schon in der Liste.") return end end
      table.insert(db.guilds, name)
      say("Gilde hinzugefügt: " .. name .. ". Mitglieder werden beim Sehen oder mit /shutup scan eingetragen.")
    else
      for i, g in ipairs(db.guilds) do
        if normGuild(g) == normGuild(name) then
          table.remove(db.guilds, i)
          local freed = 0
          for key, e in pairs(db.muted) do
            if e.guild and normGuild(e.guild) == normGuild(g) then unmute(key) freed = freed + 1 end
          end
          say(string.format("Gilde entfernt: %s (%d Spieler freigegeben).", g, freed))
          return
        end
      end
      say("Diese Gilde steht nicht in der Liste.")
    end
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
  elseif cmd == "auto" then
    db.autoScan = not db.autoScan say("Suche bei der Anmeldung: " .. onOff(db.autoScan))
  elseif cmd == "meldung" then
    db.announce = not db.announce say("Meldungen: " .. onOff(db.announce))
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

f:SetScript("OnEvent", function(_, event, arg1)
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
    if db.useBlizzIgnore == nil then db.useBlizzIgnore = true end
    if db.autoScan == nil then db.autoScan = true end
    if db.announce == nil then db.announce = true end
  elseif event == "PLAYER_LOGIN" then
    -- Eintraege aus der eigenen Liste nachtragen, falls die Spiel-Liste inzwischen Luft hat
    -- (Ignore-Liste wird erst kurz nach dem Login geladen)
    C_Timer.After(10, function()
      if (db.legacyRemoved or 0) > 0 then
        say(string.format("%d alte Einträge nur mit Vornamen entfernt (zu mehrdeutig). In der Spiel-Ignore-Liste habe ich nichts verändert: bitte dort prüfen, ob falsche Vornamen stehen.", db.legacyRemoved))
        db.legacyRemoved = nil
      end
      if db.useBlizzIgnore and C_FriendList and C_FriendList.IsIgnored then
        for _, e in pairs(db.muted) do
          if numBlizzIgnores() >= 50 then break end
          if not C_FriendList.IsIgnored(e.name) then blizzIgnore(e.name) end
        end
      end
    end)
    if db.autoScan and not db.whoBlocked and #db.guilds > 0 then
      local last = db.lastScan or 0
      if time() - last > 12 * 3600 then
        C_Timer.After(30, function() if not running then AAA.Scan() end end)
      end
    end
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
  elseif event == "ADDON_ACTION_BLOCKED" then
    -- Das Spiel erlaubt die /who-Abfrage aus einem Addon nicht: Suche abschalten, passive Erkennung bleibt
    if arg1 == ADDON and running then
      db.whoBlocked, db.autoScan = true, false
      running, current, queue, scanStats = false, nil, {}, nil
      say("Das Spiel blockiert die /who-Suche für Addons. Die Suche ist abgeschaltet; es bleibt die Erkennung über Maus, Ziel, Namensplakette und Gruppe.")
    end
  end
end)
