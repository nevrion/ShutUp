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
AAADB = { muted = { anna = { name = "Anna", guild = "Alt" } } } -- Altlast aus 0.1.0 (nur Vorname)
local f = assert(loadfile("AntifaAktionAzeroth/Core.lua"))
f("AntifaAktionAzeroth")
local on = handlers.OnEvent
on(nil, "ADDON_LOADED", "AntifaAktionAzeroth")
assert(AAADB.muted["anna"] == nil, "Vornamen-Altlast entfernt")
assert((AAADB.legacyRemoved or 0) == 1)
on(nil, "PLAYER_TARGET_CHANGED")
assert(AAADB.muted["anna meyer"], "voller Name als Schlüssel: " .. tostring(next(AAADB.muted)))
assert(IGN[1] == "Anna Meyer", "AddIgnore mit vollem Namen ohne Realm, war " .. tostring(IGN[1]))
-- Chat-Absender mit Realm wird erkannt
local hidden = false
for _, fn in ipairs(filters) do if fn(nil, nil, "hallo", "Anna Meyer-Forever") then hidden = true end end
assert(hidden, "Chat-Absender 'Anna Meyer-Forever' wird ausgeblendet")
local other = false
for _, fn in ipairs(filters) do if fn(nil, nil, "hallo", "Anna Schmidt-Forever") then other = true end end
assert(not other, "gleicher Vorname, anderer Nachname bleibt sichtbar")
SlashCmdList.AAA("ziel")
SlashCmdList.AAA("frei anna")
assert(AAADB.muted["anna meyer"] == nil, "frei per Namensanfang")
print("AAA-NAME-TEST OK")
