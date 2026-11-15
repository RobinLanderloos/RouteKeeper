-- Small helpers for building the windows.
local addonName, ns = ...

local W = {}
ns.W = W

-- The game hides Lua errors by default, and the player cannot copy them out
-- of chat. Errors in RouteKeeper's own code are caught, kept in
-- RouteKeeperDB.errors (read from the SavedVariables after /reload) and
-- mentioned once in chat.
local told = {}
function W.Guard(fn)
  return function(...)
    local args, n = { ... }, select("#", ...)
    local ok, err = xpcall(function() return fn(unpack(args, 1, n)) end, function(e)
      return tostring(e) .. "\n" .. (debugstack and debugstack(2, 12, 0) or "")
    end)
    if ok then return end
    if type(RouteKeeperDB) == "table" then
      RouteKeeperDB.errors = type(RouteKeeperDB.errors) == "table" and RouteKeeperDB.errors or {}
      local list = RouteKeeperDB.errors
      list[#list + 1] = (date and date("%Y-%m-%d %H:%M:%S ") or "") .. err
      while #list > 20 do table.remove(list, 1) end
    end
    local first = tostring(err):match("^[^\n]*")
    if not told[first] then
      told[first] = true
      print("|cffff6060RouteKeeper error|r (saved for the developer; /reload to write it): " .. first)
    end
  end
end

-- Text typed by people goes into FontStrings: "|" would start an escape code.
function W.Escape(text) return (tostring(text or ""):gsub("|", "||")) end

-- Edit boxes give "|" back as "||".
function W.Unescape(text) return (tostring(text or ""):gsub("||", "|")) end

function W.Window(name, width, height, title)
  local f = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(width, height)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if not self.locked then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  f:SetFrameStrata("HIGH")
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.title:SetPoint("TOP", 0, -5)
  f.title:SetPoint("LEFT", 30, 0)
  f.title:SetPoint("RIGHT", -30, 0)
  f.title:SetText(title or "")
  f:Hide()
  return f
end

function W.Button(parent, text, width, height, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 80, height or 22)
  b:SetText(text)
  if onClick then b:SetScript("OnClick", W.Guard(onClick)) end
  return b
end

function W.Label(parent, text, font)
  local l = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
  l:SetJustifyH("LEFT")
  l:SetText(text or "")
  return l
end

function W.Tooltip(frame, getText)
  frame:SetScript("OnEnter", function(self)
    local title, body = getText(self)
    if not title then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    if body and body ~= "" then GameTooltip:AddLine(body, 0.9, 0.82, 0.5, true) end
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- One-line edit box. onChange(text) only for what the player typed;
-- onFocus() when they start editing (used to save an undo step).
function W.EditBox(parent, width, onChange, onFocus)
  local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  e:SetSize(width, 20)
  e:SetAutoFocus(false)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  e:SetScript("OnEnterPressed", e.ClearFocus)
  e:SetScript("OnEditFocusGained", function() if onFocus then onFocus() end end)
  e:SetScript("OnTextChanged", W.Guard(function(self, userInput)
    if userInput and onChange then onChange(W.Unescape(self:GetText())) end
  end))
  return e
end

-- Multi-line edit box in a scroll frame.
function W.MultiEdit(parent, width, height, onChange, onFocus)
  local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  holder:SetSize(width, height)
  if holder.SetBackdrop then
    holder:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    holder:SetBackdropColor(0, 0, 0, 0.5)
    holder:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
  end
  local scroll = CreateFrame("ScrollFrame", nil, holder, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 4, -4)
  scroll:SetPoint("BOTTOMRIGHT", -26, 4)
  local e = CreateFrame("EditBox", nil, scroll)
  e:SetMultiLine(true)
  e:SetAutoFocus(false)
  e:SetFontObject("ChatFontNormal")
  e:SetWidth(width - 34)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  e:SetScript("OnEditFocusGained", function() if onFocus then onFocus() end end)
  e:SetScript("OnTextChanged", W.Guard(function(self, userInput)
    if userInput and onChange then onChange(W.Unescape(self:GetText())) end
  end))
  scroll:SetScrollChild(e)
  holder:EnableMouse(true)
  holder:SetScript("OnMouseDown", function() e:SetFocus() end)
  holder.edit = e
  return holder
end

-- A button that steps through a list of values.
function W.Cycle(parent, width, values, labelOf, onChange)
  local b = W.Button(parent, "", width, 22)
  b.values, b.index = values, 1
  function b:SetValue(v)
    for i, x in ipairs(self.values) do if x == v then self.index = i end end
    self:SetText(labelOf(self.values[self.index]))
  end
  function b:GetValue() return self.values[self.index] end
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", W.Guard(function(self, button)
    local n = #self.values
    self.index = button == "RightButton" and ((self.index - 2) % n + 1) or (self.index % n + 1)
    self:SetText(labelOf(self.values[self.index]))
    if onChange then onChange(self.values[self.index]) end
  end))
  b:SetValue(values[1])
  return b
end

W.KIND_LABEL = { entrance = "Entrance", boss = "Boss", quest = "Quest", note = "Note" }
W.ACT_LABEL = { start = "Pick up", objective = "Do", ["end"] = "Turn in" }

-- A list that drops down under a button; click an entry to pick it.
-- items = { { text = "...", value = x, selected = bool }, ... }.
-- Clicking the same anchor again, or picking, closes it.
local pick
function W.PickList(anchor, items, onPick, emptyText)
  if not pick then
    pick = CreateFrame("Frame", "RouteKeeperPickList", UIParent, "BackdropTemplate")
    pick:SetFrameStrata("FULLSCREEN_DIALOG")
    if pick.SetBackdrop then
      pick:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
      pick:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
      pick:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end
    pick:EnableMouse(true)
    pick:SetClampedToScreen(true)
    pick.rows = {}
    pick.empty = W.Label(pick, "", "GameFontDisableSmall")
    pick.empty:SetPoint("TOPLEFT", 8, -8)
    tinsert(UISpecialFrames, "RouteKeeperPickList")
    pick:Hide() -- new frames start shown
  end
  if pick:IsShown() and pick.anchor == anchor then pick:Hide(); return end
  pick.anchor = anchor
  local width = math.max(anchor:GetWidth(), 240)
  for _, r in ipairs(pick.rows) do r:Hide() end
  for i, item in ipairs(items) do
    local row = pick.rows[i]
    if not row then
      row = CreateFrame("Button", nil, pick)
      row:SetHeight(18)
      row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
      row.sel = row:CreateTexture(nil, "BACKGROUND")
      row.sel:SetAllPoints()
      row.sel:SetColorTexture(0.3, 0.85, 1, 0.25)
      row.text = W.Label(row, "", "GameFontHighlightSmall")
      row.text:SetPoint("LEFT", 6, 0)
      row.text:SetPoint("RIGHT", -6, 0)
      row.text:SetWordWrap(false)
      pick.rows[i] = row
    end
    row:SetWidth(width - 8)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 18)
    row.text:SetText(item.text)
    row.sel:SetShown(item.selected == true)
    row:SetScript("OnClick", W.Guard(function()
      pick:Hide()
      onPick(item.value)
    end))
    row:Show()
  end
  pick.empty:SetText(emptyText or "")
  pick.empty:SetShown(#items == 0)
  pick:SetSize(width, math.max(28, #items * 18 + 8))
  pick:ClearAllPoints()
  pick:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  pick:Show()
end

function W.HidePickList() if pick then pick:Hide() end end

-- A step's name for display (escaped for FontStrings).
function W.StepName(step)
  return W.Escape(ns.Model.StepName(step, function(id) return ns.Quests.Name(id) end,
    function(k) return W.KIND_LABEL[k] end))
end

function W.RaidIcon(n) return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. n end
W.CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
W.CROSS = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14|t"
W.DOT = "|cff888888-|r"
