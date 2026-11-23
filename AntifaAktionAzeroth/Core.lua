-- Antifaschiste Aktion Azeroth
-- Setzt Mitglieder bestimmter Gilden automatisch auf Ignore.
--
-- WoW bietet keine Abfrage "alle Mitglieder einer fremden Gilde". Das Addon sammelt deshalb auf drei Wegen:
--   1. Passiv: jeder Spieler, den du per Maus, Ziel, Namensplakette oder Gruppe "siehst" (GetGuildInfo).
--   2. Aktiv: /who g-"Gildenname" (Befehl /aaa scan, optional einmal pro Anmeldung), bei mehr als 50 Treffern
--      wird nach Stufenbereichen geteilt.
--   3. Chat: wer schon in der eigenen Liste steht, wird im Chat ausgeblendet, auch wenn die Ignore-Liste
--      des Spiels voll ist (Limit des Spiels: 50 Einträge).

local ADDON = ...
local AAA = {}
_G.AntifaAktionAzeroth = AAA

local PREFIX = "|cffe53935[AAA]|r "
local DEFAULT_GUILDS = { "Alternative für Durotar", "Alternative für Azeroth" }
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

-- "Name-Realm" -> "name" (Vergleichsschlüssel)
local function nameKey(name)
  if not name then return nil end
  if Ambiguate then name = Ambiguate(name, "none") end
  name = name:gsub("%-.*$", "")
  return name:lower()
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

-- db.muted[schluessel] = { name = "Vollname", guild = "Gilde", t = Zeit }
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

local function mute(name, guild, quiet)
  local k = nameKey(name)
  if not k or k == "" then return false end
  if k == nameKey(UnitName("player")) then return false end
  if db.muted[k] then return false end
  db.muted[k] = { name = name, guild = guild, t = time() }
  local viaGame = blizzIgnore(name)
  if db.announce and not quiet then
    say(string.format("%s (%s) wird ignoriert%s.", name, guild or "?", viaGame and "" or " (nur Chat-Filter)"))
  end
  return true
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
  local name, realm = UnitName(unit)
  if realm and realm ~= "" then name = name .. "-" .. realm end
  mute(name, hit)
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
  queue = {}
  for _, g in ipairs(db.guilds) do table.insert(queue, { guild = g }) end
  if #queue == 0 then say("Keine Gilden in der Liste.") return end
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
  print("  /aaa scan - Gilden per /who absuchen und Treffer ignorieren")
  print("  /aaa liste - Gilden und Zahl der eingetragenen Spieler")
  print("  /aaa gilde + <Name> / gilde - <Name> - Gilde hinzufügen / entfernen")
  print("  /aaa frei <Spielername> - einen Spieler wieder freigeben")
  print("  /aaa chat - Chat-Filter an/aus (jetzt " .. onOff(db.hideChat) .. ")")
  print("  /aaa spiel - Spiel-Ignore-Liste mitbenutzen (jetzt " .. onOff(db.useBlizzIgnore) .. ")")
  print("  /aaa auto - Suche bei der Anmeldung (jetzt " .. onOff(db.autoScan) .. ")")
  print("  /aaa meldung - Meldungen bei neuen Einträgen (jetzt " .. onOff(db.announce) .. ")")
end

local function slash(msg)
  msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, rest = msg:match("^(%S+)%s*(.-)$")
  cmd = cmd and cmd:lower() or ""
  if cmd == "scan" or cmd == "suche" then
    AAA.Scan()
  elseif cmd == "liste" or cmd == "list" or cmd == "status" then
    local perGuild = {}
    for _, e in pairs(db.muted) do perGuild[e.guild or "?"] = (perGuild[e.guild or "?"] or 0) + 1 end
    say(string.format("%d Spieler eingetragen, %d/50 Plätze der Spiel-Ignore-Liste belegt.", countKeys(db.muted), numBlizzIgnores()))
    for _, g in ipairs(db.guilds) do print(string.format("  %s: %d", g, perGuild[g] or 0)) end
  elseif cmd == "gilde" then
    local op, name = rest:match("^([%+%-])%s*(.+)$")
    if not op then say('Nutzung: /aaa gilde + Name  oder  /aaa gilde - Name') return end
    if op == "+" then
      for _, g in ipairs(db.guilds) do if normGuild(g) == normGuild(name) then say("Die Gilde ist schon in der Liste.") return end end
      table.insert(db.guilds, name)
      say("Gilde hinzugefügt: " .. name)
    else
      for i, g in ipairs(db.guilds) do
        if normGuild(g) == normGuild(name) then table.remove(db.guilds, i) say("Gilde entfernt: " .. g) return end
      end
      say("Diese Gilde steht nicht in der Liste.")
    end
  elseif cmd == "frei" then
    local k = nameKey(rest)
    if k and db.muted[k] then
      local full = db.muted[k].name
      db.muted[k] = nil
      if C_FriendList and C_FriendList.DelIgnore then C_FriendList.DelIgnore(full) elseif DelIgnore then DelIgnore(full) end
      say(full .. " ist wieder frei. Beim nächsten Sehen oder Suchen wird der Spieler erneut eingetragen, solange die Gilde in der Liste steht.")
    else
      say("Unbekannter Spieler.")
    end
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

SLASH_AAA1 = "/aaa"
SlashCmdList["AAA"] = slash

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

f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    AAADB = AAADB or {}
    db = AAADB
    if db.guilds == nil then db.guilds = { unpack(DEFAULT_GUILDS) } end
    db.muted = db.muted or {}
    if db.hideChat == nil then db.hideChat = true end
    if db.useBlizzIgnore == nil then db.useBlizzIgnore = true end
    if db.autoScan == nil then db.autoScan = true end
    if db.announce == nil then db.announce = true end
  elseif event == "PLAYER_LOGIN" then
    -- Eintraege aus der eigenen Liste nachtragen, falls die Spiel-Liste inzwischen Luft hat
    -- (Ignore-Liste wird erst kurz nach dem Login geladen)
    C_Timer.After(10, function()
      if db.useBlizzIgnore and C_FriendList and C_FriendList.IsIgnored then
        for _, e in pairs(db.muted) do
          if numBlizzIgnores() >= 50 then break end
          if not C_FriendList.IsIgnored(e.name) then blizzIgnore(e.name) end
        end
      end
    end)
    if db.autoScan then
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
  end
end)
