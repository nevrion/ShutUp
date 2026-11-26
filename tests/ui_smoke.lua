-- Smoke-Test der Oberfläche: baut alle Fenster mit Stub-Frames und ruft die Aktualisierung auf (Lua 5.1)
local DEFAULTS = { GetText = "", HasFocus = false, IsShown = false, GetHeight = 100, GetWidth = 140, GetCenter = 0, GetParent = false }
local function obj()
  local o = {}
  return setmetatable(o, { __index = function(_, k)
    return function(self, ...)
      local d = DEFAULTS[k]
      if d ~= nil then return d end
      return obj()
    end
  end })
end
SlashCmdList = {}
C_Timer = { After = function() end }
function ChatFrame_AddMessageEventFilter() end
local handlers = {}
function CreateFrame() local o = obj() rawset(o, "SetScript", function(_, n, fn) handlers[#handlers + 1] = { n, fn } end) return o end
C_FriendList = { GetNumIgnores = function() return 0 end }
time = os.time
date = os.date
Minimap, GameTooltip, UIParent = obj(), obj(), obj()
UISpecialFrames = {}
STANDARD_TEXT_FONT = "x"
function UnitName() return "Me" end
function GetUnitName() return "Me Stonewall-Forever" end
function UnitExists() return false end
function GetCursorPosition() return 0, 0 end
ShutUpDB = { muted = { ["anna meyer"] = { name = "Anna Meyer", guild = "Testgilde", kind = "guild", t = os.time(), sample = nil },
  ["bot eins"] = { name = "Bot Eins", guild = "Spam", kind = "spam", t = os.time(), sample = "Gold kaufen" } }, guilds = { "Testgilde" } }
assert(loadfile("Core.lua"))("ShutUp")
assert(loadfile("UI.lua"))("ShutUp")
local on
for _, h in ipairs(handlers) do if h[1] == "OnEvent" and not on then on = h[2] end end
-- Core-Handler ist der erste registrierte OnEvent
on(nil, "ADDON_LOADED", "ShutUp")
for _, h in ipairs(handlers) do if h[1] == "OnEvent" then pcall(h[2], nil, "PLAYER_LOGIN") end end
ShutUp.Open("list")
ShutUp.Open("guilds")
ShutUp.Open("settings")
ShutUp.Open("list")
ShutUp.OnChange()
ShutUp.Toggle()
print("UI-SMOKE-OK")
