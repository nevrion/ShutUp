-- ShutUp! - Oberfläche (flaches dunkles Design wie Battle.net Buddies, roter Akzent)
-- Fenster: /shutup oder Minimap-Button. Reiter: Liste (alle geblockten Spieler mit Grund), Gilden, Einstellungen.

local ADDON = ...
local AAA = _G.ShutUp
if not AAA then return end

local WIN_W, ROW_H, LIST_ROWS, GUILD_ROWS = 480, 30, 10, 8
local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local C = {
  bg = { 0.07, 0.06, 0.08, 0.98 }, card = { 0.14, 0.12, 0.15, 1 }, cardHover = { 0.21, 0.15, 0.17, 1 },
  edge = { 0.29, 0.21, 0.23, 1 }, field = { 0.055, 0.05, 0.065, 1 },
  text = { 0.95, 0.93, 0.93 }, dim = { 0.65, 0.6, 0.63 }, accent = { 0.9, 0.22, 0.21 },
  manual = { 0.47, 0.74, 0.98 }, guild = { 1, 0.8, 0.36 }, spam = { 1, 0.5, 0.33 }, invite = { 0.78, 0.62, 1 },
}
local KIND_COLOR = { manual = C.manual, guild = C.guild, spam = C.spam, invite = C.invite }
local KIND_LABEL = { manual = "Manuell", guild = "Gilde", spam = "Spam", invite = "Einladung" }

local function D() return AAA.db end

local win, pages, tabBtns, tabOrder = nil, {}, {}, {}
local listRows, guildRows = {}, {}
local listOffset, guildOffset = 0, 0
local filter = "all"
local items, guildItems = {}, {}
local checks, steppers = {}, {}
local mm

---------------------------------------------------------------------------
-- Bausteine
---------------------------------------------------------------------------

local function Flat(f, bg, edge)
  f:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
  f:SetBackdropColor(unpack(bg))
  f:SetBackdropBorderColor(unpack(edge or C.edge))
end

local function Text(parent, size, color)
  local t = parent:CreateFontString(nil, "OVERLAY")
  t:SetFont(FONT, size, "")
  t:SetTextColor(unpack(color or C.text))
  t:SetJustifyH("LEFT")
  return t
end

local function Button(parent, label, w, h, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h or 22)
  Flat(b, C.card)
  b.label = Text(b, 12, C.text)
  b.label:SetPoint("CENTER", 0, 0)
  b.label:SetText(label)
  b:SetScript("OnEnter", function(self) self:SetBackdropColor(unpack(C.cardHover)); self:SetBackdropBorderColor(unpack(C.accent)) end)
  b:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(C.card)); self:SetBackdropBorderColor(unpack(C.edge)) end)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

local function Edit(parent, w, placeholder)
  local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  e:SetSize(w, 24)
  Flat(e, C.field)
  e:SetFont(FONT, 12, ""); e:SetTextColor(unpack(C.text))
  e:SetAutoFocus(false); e:SetTextInsets(8, 8, 0, 0)
  e:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
  e.hint = Text(e, 12, C.dim)
  e.hint:SetPoint("LEFT", 8, 0)
  e.hint:SetText(placeholder or "")
  local function ph(s) e.hint:SetShown((s:GetText() or "") == "" and not s:HasFocus()) end
  e:SetScript("OnEditFocusGained", function(s) s:SetBackdropBorderColor(unpack(C.accent)); ph(s) end)
  e:SetScript("OnEditFocusLost", function(s) s:SetBackdropBorderColor(unpack(C.edge)); ph(s) end)
  e.ph = ph
  return e
end

local function Check(parent, label, get, set)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(WIN_W - 24, 20)
  b.box = CreateFrame("Frame", nil, b, "BackdropTemplate")
  b.box:SetSize(16, 16); b.box:SetPoint("LEFT", 0, 0)
  Flat(b.box, C.field)
  b.mark = b.box:CreateTexture(nil, "OVERLAY")
  b.mark:SetSize(8, 8); b.mark:SetPoint("CENTER", 0, 0)
  b.mark:SetColorTexture(unpack(C.accent))
  b.text = Text(b, 12)
  b.text:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
  b.text:SetText(label)
  function b:Refresh() self.mark:SetShown(get() and true or false) end
  b:SetScript("OnClick", function(self) set(not get()); self:Refresh() end)
  b:SetScript("OnEnter", function(self) self.box:SetBackdropBorderColor(unpack(C.accent)) end)
  b:SetScript("OnLeave", function(self) self.box:SetBackdropBorderColor(unpack(C.edge)) end)
  checks[#checks + 1] = b
  return b
end

-- Zahlenwert mit [-] und [+]
local function Stepper(parent, label, get, set, lo, hi, step, fmt)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(WIN_W - 24, 22)
  f.label = Text(f, 12)
  f.label:SetPoint("LEFT", 0, 0); f.label:SetText(label)
  local plus = Button(f, "+", 22, 22)
  plus:SetPoint("RIGHT", 0, 0)
  f.value = Text(f, 12, C.accent)
  f.value:SetJustifyH("CENTER"); f.value:SetWidth(70)
  f.value:SetPoint("RIGHT", plus, "LEFT", -2, 0)
  local minus = Button(f, "-", 22, 22)
  minus:SetPoint("RIGHT", f.value, "LEFT", -2, 0)
  function f:Refresh()
    local v = get() or lo
    f.value:SetText(fmt and fmt(v) or tostring(v))
  end
  minus:SetScript("OnClick", function() set(math.max(lo, (get() or lo) - step)); f:Refresh() end)
  plus:SetScript("OnClick", function() set(math.min(hi, (get() or lo) + step)); f:Refresh() end)
  steppers[#steppers + 1] = f
  return f
end

local function Scrollbar(holder)
  local track = CreateFrame("Frame", nil, holder)
  track:SetWidth(4); track:SetPoint("TOPRIGHT", -5, -2); track:SetPoint("BOTTOMRIGHT", -5, 2)
  local bg = track:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(unpack(C.field))
  local thumb = track:CreateTexture(nil, "ARTWORK")
  thumb:SetWidth(4); thumb:SetColorTexture(unpack(C.edge))
  return track, thumb
end

local function setThumb(track, thumb, offset, total, shown)
  local h = track:GetHeight() or 100
  if total <= shown then thumb:Hide() return end
  local thumbH = math.max(18, h * shown / total)
  thumb:SetHeight(thumbH)
  thumb:ClearAllPoints()
  thumb:SetPoint("TOP", track, "TOP", 0, -((h - thumbH) * offset / math.max(1, total - shown)))
  thumb:Show()
end

local function fmtDate(t)
  if not t then return "" end
  return date("%d.%m.%Y", t)
end

---------------------------------------------------------------------------
-- Reiter Liste
---------------------------------------------------------------------------

local function buildItems()
  local db = D()
  items = {}
  if not db then return end
  local q = (win.search:GetText() or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  for key, e in pairs(db.muted) do
    local kind = AAA.KindOf(e)
    if filter == "all" or filter == kind then
      local hay = ((e.name or key) .. " " .. (e.guild or "")):lower()
      if q == "" or hay:find(q, 1, true) then items[#items + 1] = { key = key, e = e, kind = kind } end
    end
  end
  table.sort(items, function(a, b)
    if (a.e.t or 0) ~= (b.e.t or 0) then return (a.e.t or 0) > (b.e.t or 0) end
    return (a.e.name or "") < (b.e.name or "")
  end)
end

local function refreshList()
  if not win or not D() then return end
  buildItems()
  local total = #items
  local maxOff = math.max(0, total - LIST_ROWS)
  if listOffset > maxOff then listOffset = maxOff end
  if listOffset < 0 then listOffset = 0 end
  for i = 1, LIST_ROWS do
    local it, r = items[listOffset + i], listRows[i]
    if it then
      r.it = it
      local col = KIND_COLOR[it.kind] or C.text
      r.stripe:SetColorTexture(unpack(col))
      r.name:SetText(it.e.name or it.key)
      r.reason:SetTextColor(unpack(col))
      local reason = it.kind == "guild" and (it.e.guild or "") or (KIND_LABEL[it.kind] or "")
      r.reason:SetText(reason)
      r.date:SetText(fmtDate(it.e.t))
      r:Show()
    else
      r.it = nil
      r:Hide()
    end
  end
  win.empty:SetShown(total == 0)
  win.count:SetText(string.format("%d Spieler auf der Liste, %d/50 Plätze der Spiel-Ignore-Liste belegt", (function() local n = 0 for _ in pairs(D().muted) do n = n + 1 end return n end)(), AAA.NumBlizz()))
  setThumb(win.track, win.thumb, listOffset, total, LIST_ROWS)
  for k, b in pairs(win.chips) do
    if k == filter then b:SetBackdropBorderColor(unpack(C.accent)); b.label:SetTextColor(unpack(C.accent))
    else b:SetBackdropBorderColor(unpack(C.edge)); b.label:SetTextColor(unpack(C.text)) end
  end
end

local function makeListRow(parent, i)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetHeight(ROW_H - 2)
  b:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -(i - 1) * ROW_H)
  b:SetPoint("RIGHT", parent, "RIGHT", -13, 0)
  Flat(b, C.card, C.card)
  b.stripe = b:CreateTexture(nil, "OVERLAY")
  b.stripe:SetWidth(3)
  b.stripe:SetPoint("TOPLEFT", 0, 0); b.stripe:SetPoint("BOTTOMLEFT", 0, 0)
  b.del = Button(b, "x", 20, 20, function(self)
    local r = self:GetParent()
    if r.it then AAA.Unmute(r.it.key) end
  end)
  b.del:SetPoint("RIGHT", -4, 0)
  b.date = Text(b, 10, C.dim)
  b.date:SetJustifyH("RIGHT"); b.date:SetPoint("RIGHT", b.del, "LEFT", -8, 0); b.date:SetWidth(64)
  b.reason = Text(b, 11)
  b.reason:SetPoint("RIGHT", b.date, "LEFT", -8, 0); b.reason:SetWidth(130); b.reason:SetWordWrap(false)
  b.name = Text(b, 13)
  b.name:SetPoint("LEFT", 12, 0); b.name:SetPoint("RIGHT", b.reason, "LEFT", -6, 0); b.name:SetWordWrap(false)
  b:SetScript("OnEnter", function(self)
    self:SetBackdropColor(unpack(C.cardHover)); self:SetBackdropBorderColor(unpack(C.edge))
    local it = self.it
    if not it then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(it.e.name or it.key, 1, 1, 1)
    local reason = KIND_LABEL[it.kind] or ""
    if it.kind == "guild" then reason = reason .. ": " .. (it.e.guild or "?") end
    GameTooltip:AddLine("Grund: " .. reason, unpack(KIND_COLOR[it.kind] or C.text))
    if it.e.t then GameTooltip:AddLine("Eingetragen am " .. date("%d.%m.%Y %H:%M", it.e.t), 0.65, 0.6, 0.63) end
    if it.e.sample then GameTooltip:AddLine("Text: " .. it.e.sample, 1, 1, 1, true) end
    GameTooltip:AddLine(it.e.viaGame and "Steht auch in der Spiel-Ignore-Liste" or "Nur ShutUp!-Liste und Chat-Filter", 0.65, 0.6, 0.63)
    GameTooltip:AddLine("x rechts = freigeben", 0.65, 0.6, 0.63)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(C.card)); self:SetBackdropBorderColor(unpack(C.card)); GameTooltip:Hide() end)
  return b
end

local function buildListPage(pg)
  local search = Edit(pg, 10, "Name oder Gilde suchen ...")
  search:ClearAllPoints()
  search:SetPoint("TOPLEFT", 8, -6); search:SetPoint("TOPRIGHT", -8, -6)
  search:SetScript("OnTextChanged", function(s) s.ph(s); listOffset = 0; refreshList() end)
  win.search = search

  -- Filter-Chips
  win.chips = {}
  local defs = { { "all", "Alle" }, { "manual", "Manuell" }, { "guild", "Gilde" }, { "spam", "Spam" }, { "invite", "Einladung" } }
  local x = 8
  for _, d in ipairs(defs) do
    local b = Button(pg, d[2], 70, 20, function() filter = d[1]; listOffset = 0; refreshList() end)
    b:SetPoint("TOPLEFT", x, -36)
    b:SetScript("OnEnter", nil); b:SetScript("OnLeave", nil)
    b.label:SetFont(FONT, 11, "")
    win.chips[d[1]] = b
    x = x + 74
  end

  local holder = CreateFrame("Frame", nil, pg)
  holder:SetPoint("TOPLEFT", 0, -62); holder:SetPoint("TOPRIGHT", 0, -62)
  holder:SetHeight(LIST_ROWS * ROW_H)
  for i = 1, LIST_ROWS do listRows[i] = makeListRow(holder, i) end
  win.empty = Text(holder, 12, C.dim)
  win.empty:SetPoint("TOP", 0, -40); win.empty:SetJustifyH("CENTER")
  win.empty:SetText("Noch niemand auf der Liste.\nSpieler mit /shutup + Name oder dem Feld unten eintragen.")
  win.track, win.thumb = Scrollbar(holder)

  -- Spieler hinzufügen
  local add = Edit(pg, 10, "Vorname Nachname")
  add:SetPoint("TOPLEFT", 8, -(62 + LIST_ROWS * ROW_H + 10)); add:SetWidth(WIN_W - 8 - 8 - 190)
  local function doAdd()
    local name = add:GetText() or ""
    if name ~= "" then
      local ok, why = AAA.Mute(name)
      if not ok then
        if why == "vorname" then AAA.Say("Bitte den vollen Namen angeben (Vorname Nachname).")
        elseif why == "schon" then AAA.Say("Der Spieler steht schon auf der Liste.")
        elseif why == "ich" then AAA.Say("Du kannst dich nicht selbst ignorieren.") end
      else add:SetText("") end
    end
    add:ClearFocus()
  end
  add:SetScript("OnEnterPressed", doAdd)
  local addBtn = Button(pg, "Ignorieren", 90, 24, doAdd)
  addBtn:SetPoint("LEFT", add, "RIGHT", 6, 0)
  local tgtBtn = Button(pg, "Ziel ignorieren", 90, 24, function()
    local name = AAA.NameOrTarget("")
    if not name then AAA.Say("Kein Spieler als Ziel ausgewählt.") return end
    local ok, why = AAA.Mute(name)
    if not ok and why == "schon" then AAA.Say("Der Spieler steht schon auf der Liste.") end
  end)
  tgtBtn:SetPoint("LEFT", addBtn, "RIGHT", 6, 0)

  win.count = Text(pg, 10, C.dim)
  win.count:SetPoint("BOTTOMLEFT", 12, 10)

  pg:EnableMouseWheel(true)
  pg:SetScript("OnMouseWheel", function(_, d) listOffset = listOffset - d * 3; refreshList() end)
end

---------------------------------------------------------------------------
-- Reiter Gilden
---------------------------------------------------------------------------

local function refreshGuilds()
  if not win or not D() or not win.gcount then return end
  local db = D()
  guildItems = {}
  local counts = {}
  for _, e in pairs(db.muted) do
    if AAA.KindOf(e) == "guild" and e.guild then
      local k = e.guild:lower()
      counts[k] = (counts[k] or 0) + 1
    end
  end
  for _, g in ipairs(db.guilds) do guildItems[#guildItems + 1] = { name = g, n = counts[g:lower()] or 0 } end
  local total = #guildItems
  local maxOff = math.max(0, total - GUILD_ROWS)
  if guildOffset > maxOff then guildOffset = maxOff end
  if guildOffset < 0 then guildOffset = 0 end
  for i = 1, GUILD_ROWS do
    local it, r = guildItems[guildOffset + i], guildRows[i]
    if it then
      r.it = it
      r.name:SetText(it.name)
      r.n:SetText(it.n .. " Spieler")
      r:Show()
    else r.it = nil; r:Hide() end
  end
  win.gempty:SetShown(total == 0)
  win.gcount:SetText(total .. " Gilden eingetragen")
  if win.scanBtn then
    local n = AAA.PendingScan and AAA.PendingScan() or 0
    win.scanBtn.label:SetText(n > 0 and string.format("Nächste Abfrage (%d offen)", n) or "Per /who suchen")
  end
  setThumb(win.gtrack, win.gthumb, guildOffset, total, GUILD_ROWS)
end

local function makeGuildRow(parent, i)
  local b = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  b:SetHeight(ROW_H - 2)
  b:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -(i - 1) * ROW_H)
  b:SetPoint("RIGHT", parent, "RIGHT", -13, 0)
  Flat(b, C.card, C.card)
  local stripe = b:CreateTexture(nil, "OVERLAY")
  stripe:SetColorTexture(unpack(C.guild)); stripe:SetWidth(3)
  stripe:SetPoint("TOPLEFT", 0, 0); stripe:SetPoint("BOTTOMLEFT", 0, 0)
  b.del = Button(b, "x", 20, 20, function(self)
    local r = self:GetParent()
    if r.it then AAA.RemoveGuild(r.it.name) end
  end)
  b.del:SetPoint("RIGHT", -4, 0)
  b.n = Text(b, 11, C.dim)
  b.n:SetJustifyH("RIGHT"); b.n:SetPoint("RIGHT", b.del, "LEFT", -8, 0); b.n:SetWidth(90)
  b.name = Text(b, 13)
  b.name:SetPoint("LEFT", 12, 0); b.name:SetPoint("RIGHT", b.n, "LEFT", -6, 0); b.name:SetWordWrap(false)
  return b
end

local function buildGuildPage(pg)
  local info = Text(pg, 11, C.dim)
  info:SetPoint("TOPLEFT", 12, -8); info:SetWidth(WIN_W - 24); info:SetJustifyV("TOP")
  info:SetText("Ganze Gilden ignorieren. Mitglieder werden aufgenommen, sobald du sie siehst (Maus, Ziel, Namensplakette, Gruppe) oder mit der /who-Suche.")

  local holder = CreateFrame("Frame", nil, pg)
  holder:SetPoint("TOPLEFT", 0, -50); holder:SetPoint("TOPRIGHT", 0, -50)
  holder:SetHeight(GUILD_ROWS * ROW_H)
  for i = 1, GUILD_ROWS do guildRows[i] = makeGuildRow(holder, i) end
  win.gempty = Text(holder, 12, C.dim)
  win.gempty:SetPoint("TOP", 0, -40); win.gempty:SetJustifyH("CENTER")
  win.gempty:SetText("Noch keine Gilde eingetragen.")
  win.gtrack, win.gthumb = Scrollbar(holder)

  local y = -(50 + GUILD_ROWS * ROW_H + 10)
  local add = Edit(pg, 10, "Gildenname")
  add:SetPoint("TOPLEFT", 8, y); add:SetWidth(WIN_W - 8 - 8 - 190)
  local function doAdd()
    local name = add:GetText() or ""
    if name ~= "" and AAA.AddGuild(name) then add:SetText("") end
    add:ClearFocus()
  end
  add:SetScript("OnEnterPressed", doAdd)
  local addBtn = Button(pg, "Hinzufügen", 90, 24, doAdd)
  addBtn:SetPoint("LEFT", add, "RIGHT", 6, 0)
  local tgt = Button(pg, "Gilde des Ziels", 90, 24, function() AAA.AddGuild("") end)
  tgt:SetPoint("LEFT", addBtn, "RIGHT", 6, 0)

  local scan = Button(pg, "Per /who suchen", 180, 24, function() AAA.Scan(); refreshGuilds() end)
  scan:SetPoint("TOPLEFT", 8, y - 34)
  win.scanBtn = scan
  local note = Text(pg, 10, C.dim)
  note:SetPoint("LEFT", scan, "RIGHT", 10, 0); note:SetWidth(WIN_W - 220)
  note:SetText("Eine Abfrage pro Klick (Sperre des Spiels). Bei großen Gilden mehrfach klicken.")

  win.gcount = Text(pg, 10, C.dim)
  win.gcount:SetPoint("BOTTOMLEFT", 12, 10)
  pg:EnableMouseWheel(true)
  pg:SetScript("OnMouseWheel", function(_, d) guildOffset = guildOffset - d * 3; refreshGuilds() end)
end

---------------------------------------------------------------------------
-- Reiter Einstellungen
---------------------------------------------------------------------------

local function buildSettingsPage(pg)
  local function head(text, y)
    local t = Text(pg, 12, C.accent)
    t:SetPoint("TOPLEFT", 12, y); t:SetText(text)
    local line = pg:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(C.edge)); line:SetHeight(1)
    line:SetPoint("TOPLEFT", 12, y - 16); line:SetPoint("TOPRIGHT", -12, y - 16)
  end
  local function sub(text, y)
    local t = Text(pg, 10, C.dim)
    t:SetPoint("TOPLEFT", 36, y); t:SetWidth(WIN_W - 48); t:SetText(text)
  end
  local function put(w, y) w:SetPoint("TOPLEFT", 12, y) end
  local function flag(label, key, y, after)
    put(Check(pg, label, function() return D()[key] and true or false end, function(v) D()[key] = v; if after then after(v) end end), y)
  end

  head("Allgemein", -8)
  flag("Chat der Spieler auf der Liste ausblenden", "hideChat", -30)
  flag("Zusätzlich in die Spiel-Ignore-Liste eintragen", "useBlizzIgnore", -52)
  sub("Blockt dann auch Einladungen und Handel, belegt aber die 50 Plätze des Spiels. Standard: aus.", -70)
  flag("Meldung im Chat, wenn jemand eingetragen wird", "announce", -92)
  put(Check(pg, "Minimap-Button anzeigen", function() return not D().mmHide end, function(v) D().mmHide = (not v) or nil; if mm then mm:SetShown(v) end end), -114)

  head("Gildeneinladungen und Gildensatzungen", -144)
  flag("Automatisch ablehnen (Gruppen und Schlachtzüge nie)", "inviteOn", -166)
  flag("Nur von Unbekannten (Freunde, Gildenmitglieder, Gruppe durchlassen)", "inviteOnlyUnknown", -188)
  flag("Einlader zusätzlich auf die Liste setzen", "inviteMute", -210)

  head("Spam-Erkennung", -240)
  flag("Spam automatisch eintragen", "spamOn", -262)
  sub("Derselbe Text mehrfach in kurzer Zeit (Say, Yell, Flüstern, öffentliche Kanäle ohne Handel und Gruppensuche). Freunde, Gilde und Gruppe nie.", -280)
  local s1 = Stepper(pg, "Wiederholungen bis zum Eintrag", function() return D().spamCount end, function(v) D().spamCount = v end, 2, 10, 1)
  put(s1, -312)
  local s2 = Stepper(pg, "Zeitraum", function() return D().spamWindow end, function(v) D().spamWindow = v end, 30, 600, 30,
    function(v) return v .. " s" end)
  put(s2, -338)
  local s3 = Stepper(pg, "Einträge laufen ab nach (0 = nie)", function() return D().spamExpireDays end, function(v) D().spamExpireDays = v end, 0, 90, 1,
    function(v) return v == 0 and "nie" or (v .. " Tage") end)
  put(s3, -364)
  flag("Auch Bot-Wellen: derselbe Text von mehreren Absendern", "spamWave", -394)
  local s4 = Stepper(pg, "Absender für eine Welle", function() return D().waveSenders end, function(v) D().waveSenders = v end, 2, 10, 1)
  put(s4, -418)
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------

local function selectTab(which)
  if not win then return end
  win.tab = which
  for k, pg in pairs(pages) do pg:SetShown(k == which) end
  for k, b in pairs(tabBtns) do
    if k == which then
      b:SetBackdropBorderColor(unpack(C.accent)); b:SetBackdropColor(unpack(C.cardHover)); b.label:SetTextColor(unpack(C.accent))
    else
      b:SetBackdropBorderColor(unpack(C.edge)); b:SetBackdropColor(unpack(C.card)); b.label:SetTextColor(unpack(C.text))
    end
  end
  if which == "list" then refreshList()
  elseif which == "guilds" then refreshGuilds()
  else
    for _, c in ipairs(checks) do c:Refresh() end
    for _, s in ipairs(steppers) do s:Refresh() end
  end
end

local function build()
  if win then return end
  local H = 62 + 478
  win = CreateFrame("Frame", "ShutUpWindow", UIParent, "BackdropTemplate")
  Flat(win, C.bg)
  win:SetFrameStrata("DIALOG")
  win:SetSize(WIN_W, H)
  win:SetMovable(true); win:EnableMouse(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", function(s) s:StartMoving() end)
  win:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local p, _, rp, x, y = s:GetPoint()
    D().winPos = { p, rp, x, y }
  end)
  win:Hide()
  if UISpecialFrames then table.insert(UISpecialFrames, "ShutUpWindow") end

  local logo = win:CreateTexture(nil, "ARTWORK")
  logo:SetSize(22, 22); logo:SetPoint("TOPLEFT", 10, -8)
  logo:SetTexture("Interface\\AddOns\\ShutUp\\media\\icon.tga")
  local title = Text(win, 15, C.accent)
  title:SetPoint("LEFT", logo, "RIGHT", 8, 0); title:SetText("ShutUp!")
  local sub = Text(win, 10, C.dim)
  sub:SetPoint("LEFT", title, "RIGHT", 8, -1); sub:SetText("Eine Ignore-Liste für alle Charaktere")
  local close = Button(win, "x", 22, 22, function() win:Hide() end)
  close:SetPoint("TOPRIGHT", -8, -8)

  local defs = { { "list", "Liste" }, { "guilds", "Gilden" }, { "settings", "Einstellungen" } }
  for i, d in ipairs(defs) do
    local b = Button(win, d[2], 120, 22, function() selectTab(d[1]) end)
    b:SetScript("OnEnter", nil); b:SetScript("OnLeave", nil)
    b:SetPoint("TOPLEFT", 12 + (i - 1) * 126, -36)
    tabBtns[d[1]] = b
    local pg = CreateFrame("Frame", nil, win)
    pg:SetPoint("TOPLEFT", 0, -62); pg:SetPoint("BOTTOMRIGHT", 0, 0)
    pg:Hide()
    pages[d[1]] = pg
  end
  buildListPage(pages.list)
  buildGuildPage(pages.guilds)
  buildSettingsPage(pages.settings)
end

local function place()
  win:ClearAllPoints()
  local w = D() and D().winPos
  if w and w[1] then win:SetPoint(w[1], UIParent, w[2], w[3], w[4])
  else win:SetPoint("CENTER", UIParent, "CENTER", 0, 20) end
end

function AAA.Open(tab)
  if not D() then return end
  build()
  if not win:IsShown() then place() end
  win:Show()
  selectTab(tab or win.tab or "list")
end

function AAA.Toggle()
  if win and win:IsShown() then win:Hide() else AAA.Open() end
end

-- Änderungen am Datenbestand (neuer Eintrag, freigegeben, Gilde) aktualisieren das offene Fenster
function AAA.OnChange()
  if not win or not win:IsShown() then return end
  if win.tab == "list" then refreshList() elseif win.tab == "guilds" then refreshGuilds() end
end

---------------------------------------------------------------------------
-- Minimap-Button: Linksklick Fenster, Rechtsklick Einstellungen, Ziehen verschiebt ihn
---------------------------------------------------------------------------

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local function placeMinimap()
  if not mm then return end
  local a = math.rad((D() and D().mmAngle) or 235)
  local r = (Minimap:GetWidth() / 2) + 5
  mm:ClearAllPoints()
  mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function buildMinimap()
  if mm or not Minimap then return end
  mm = CreateFrame("Button", "ShutUpMinimapButton", Minimap)
  mm:SetSize(31, 31); mm:SetFrameStrata("MEDIUM"); mm:SetFrameLevel(8)
  mm:RegisterForClicks("LeftButtonUp", "RightButtonUp"); mm:RegisterForDrag("LeftButton")
  local bg = mm:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20); bg:SetPoint("TOPLEFT", 7, -5); bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  local icon = mm:CreateTexture(nil, "ARTWORK")
  icon:SetSize(21, 21); icon:SetPoint("TOPLEFT", 5, -4)
  icon:SetTexture("Interface\\AddOns\\ShutUp\\media\\icon.tga")
  local border = mm:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53); border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  mm:SetScript("OnClick", function(_, button)
    if button == "RightButton" then AAA.Open("settings") else AAA.Toggle() end
  end)
  mm:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      D().mmAngle = math.deg(atan2(py / s - my, px / s - mx))
      placeMinimap()
    end)
  end)
  mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  mm:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("ShutUp!", unpack(C.accent))
    local n = 0
    for _ in pairs(D().muted) do n = n + 1 end
    GameTooltip:AddLine(n .. " Spieler auf der Liste", 0.65, 0.6, 0.63)
    GameTooltip:AddLine("Linksklick: Liste", 1, 1, 1)
    GameTooltip:AddLine("Rechtsklick: Einstellungen", 1, 1, 1)
    GameTooltip:AddLine("Ziehen: Button verschieben", 0.65, 0.6, 0.63)
    GameTooltip:Show()
  end)
  mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
  placeMinimap()
  mm:SetShown(not D().mmHide)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() if D() then buildMinimap() end end)
