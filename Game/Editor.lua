-- The route editor: pick a dungeon and a route, place Steps, draw Paths,
-- add Markers, edit the details. Out of combat only.
local addonName, ns = ...

local E = {}
ns.Editor = E

local W, M = ns.W, ns.Model
local MAP_W, MAP_H = 751, 501
local PANEL_X = 12 + MAP_W + 12
local ASPECT = MAP_W / MAP_H

local frame, canvas
local state = { tool = "select", floor = 1 }
local undo = ns.Undo.New()
local ui = {}

local HINTS = {
  select = "Click a step or marker to select it, drag to move it. Mouse wheel zooms, right-drag moves the map.",
  step = "Click the map to add a step after the selected one.",
  path = "Path of the selected step: click to add a point, click on the line to bend it, drag points, right-click a point to remove it.",
  draw = "Draw the selected step's path: hold the left button and draw.",
  marker = "Click to place a marker. Right-click a marker to remove it.",
}

local function route() return state.route end
local function now() return time() end

local Refresh

-- Every change: an undo step first, then the change, then a redraw.
local function change(fn)
  local r = route()
  if not r then return end
  undo:Push(r)
  fn(r)
  ns.Store.Touch(r)
  Refresh()
end

-- Text edits save one undo step when the field gets focus, not per letter.
local function editFocus()
  if route() then undo:Push(route()) end
end
local function edited()
  if route() then ns.Store.Touch(route()) end
end

local function selectedStep()
  local r = route()
  return r and state.selected and r.steps[state.selected]
end

local function selectedMarker()
  local r = route()
  if not (r and state.marker) then return end
  for i, m in ipairs(r.markers) do if m.id == state.marker then return m, i end end
end

-- Shows a step's floor and zooms in on the way to it (previous step, its
-- path, the step).
local function focusStep(i)
  local r = route()
  local s = r and r.steps[i]
  if not s then return end
  state.floor = s.floor
  local pts = {}
  for _, p in ipairs(M.FullPath(r, i)) do
    if p.floor == s.floor then pts[#pts + 1] = p end
  end
  canvas:FitPoints(pts, 0.06, 0.15)
end

-- Map clicks --------------------------------------------------------------

local function dragStep(index)
  local pushed = false
  local sx, sy = canvas:CursorPos()
  canvas:StartDrag(function(x, y)
    local s = route() and route().steps[index]
    if not s then return end
    if not pushed then
      if math.abs(x - sx) < 0.003 and math.abs(y - sy) < 0.003 then return end
      undo:Push(route()); ns.Store.Touch(route()); pushed = true
    end
    s.x, s.y, s.floor = M.Round(x), M.Round(y), state.floor
    Refresh(true)
  end)
end

local function dragMarker(id, alreadyPushed)
  local pushed = alreadyPushed
  canvas:StartDrag(function(x, y)
    local m = selectedMarker()
    if not m or m.id ~= id then return end
    if not pushed then undo:Push(route()); ns.Store.Touch(route()); pushed = true end
    m.x, m.y = M.Round(x), M.Round(y)
    Refresh(true)
  end)
end

local function dragPoint(k, alreadyPushed)
  local pushed = alreadyPushed
  canvas:StartDrag(function(x, y)
    local s = selectedStep()
    local p = s and s.path[k]
    if not p then return end
    if not pushed then undo:Push(route()); ns.Store.Touch(route()); pushed = true end
    p[1], p[2] = M.Round(x), M.Round(y)
    Refresh(true)
  end)
end

-- Where a new path point goes: on the line segment under the cursor if
-- there is one (bending the line), else at the end, before the step.
local function pathInsertIndex(s, index, x, y)
  local pts = M.FullPath(route(), index)
  local hasStart = index > 1
  local best, bestD
  for k = 1, #pts - 1 do
    local a, b = pts[k], pts[k + 1]
    if a.floor == state.floor and b.floor == state.floor then
      local d = ns.Geometry.SegmentDistance(x, y, a.x, a.y, b.x, b.y, ASPECT)
      if d < 0.015 and (not bestD or d < bestD) then best, bestD = k, d end
    end
  end
  if best then
    -- Segment k runs from pts[k] to pts[k+1]. With a start point pts[k] is
    -- path point k-1, so the new point becomes path point k; without one
    -- pts[k] is path point k, so it becomes k+1.
    return hasStart and best or best + 1
  end
  return #s.path + 1
end

local function onMapDown(x, y, button)
  if InCombatLockdown() then return end
  if button ~= "LeftButton" then
    -- Right or middle button drags the map.
    canvas:StartPan(button)
    return
  end
  local r = route()
  if not r then return end
  local tool = state.tool
  if tool == "step" then
    change(function()
      local kind = (#r.steps == 0) and "entrance" or "note"
      local s = M.NewStep(ns.Store.Rand, kind, state.floor, x, y)
      state.selected = M.AddStep(r, s, state.selected)
      state.marker = nil
    end)
  elseif tool == "path" then
    local s = selectedStep()
    if not s then return end
    local at = pathInsertIndex(s, state.selected, x, y)
    change(function() table.insert(s.path, at, { M.Round(x), M.Round(y), state.floor }) end)
    dragPoint(at, true)
  elseif tool == "draw" then
    local s = selectedStep()
    if not s then return end
    undo:Push(r); ns.Store.Touch(r)
    local stroke = { { x, y, state.floor } }
    local base = #s.path
    canvas:StartDrag(function(cx, cy, finished)
      local last = stroke[#stroke]
      if math.abs(cx - last[1]) * ASPECT + math.abs(cy - last[2]) > 0.006 then
        stroke[#stroke + 1] = { cx, cy, state.floor }
      end
      if finished then
        stroke = ns.Geometry.Simplify(stroke, 0.004, ASPECT)
      end
      for k = #s.path, base + 1, -1 do s.path[k] = nil end
      for _, p in ipairs(stroke) do
        if #s.path < M.LIMITS.pathPoints then s.path[#s.path + 1] = { M.Round(p[1]), M.Round(p[2]), p[3] } end
      end
      Refresh(not finished)
    end)
  elseif tool == "marker" then
    if #r.markers >= M.LIMITS.markers then return end
    change(function()
      local m = M.NewMarker(ns.Store.Rand, state.floor, x, y, state.lastIcon or 8)
      r.markers[#r.markers + 1] = m
      state.marker, state.selected = m.id, nil
    end)
  else
    state.marker = nil
    Refresh()
  end
end

local function onPinDown(i, button)
  if InCombatLockdown() or button ~= "LeftButton" then return end
  state.selected, state.marker = i, nil
  Refresh()
  if state.tool == "select" or state.tool == "step" then dragStep(i) end
end

local function onMarkerDown(id, button)
  if InCombatLockdown() then return end
  if button == "RightButton" then
    change(function(r)
      for i, m in ipairs(r.markers) do if m.id == id then table.remove(r.markers, i); break end end
      if state.marker == id then state.marker = nil end
    end)
    return
  end
  state.marker, state.selected = id, nil
  Refresh()
  dragMarker(id, false)
end

local function onHandleDown(k, button)
  if InCombatLockdown() then return end
  local s = selectedStep()
  if not s then return end
  if button == "RightButton" then
    change(function() table.remove(s.path, k) end)
  else
    dragPoint(k, false)
  end
end

local function pinTooltip(i)
  local s = route() and route().steps[i]
  if not s then return end
  local name = W.StepName(s)
  local title = i .. ". " .. W.KIND_LABEL[s.kind] .. (name ~= W.KIND_LABEL[s.kind] and (": " .. name) or "")
  return title, W.Escape(s.note)
end

-- Building the window -------------------------------------------------------

local function toolButtons(parent)
  ui.tools = {}
  local x = 12
  for _, t in ipairs({ { "select", "Select" }, { "step", "Step" }, { "path", "Path" }, { "draw", "Draw" }, { "marker", "Marker" } }) do
    local b = W.Button(parent, t[2], 64, 22, function()
      state.tool = t[1]
      Refresh()
    end)
    b:SetPoint("TOPLEFT", x, -58)
    b.tool = t[1]
    ui.tools[#ui.tools + 1] = b
    x = x + 66
  end
  ui.floorPrev = W.Button(parent, "<", 24, 22, function() E.ChangeFloor(-1) end)
  ui.floorPrev:SetPoint("TOPLEFT", x + 10, -58)
  ui.floorLabel = W.Label(parent, "Floor 1", "GameFontHighlight")
  ui.floorLabel:SetPoint("LEFT", ui.floorPrev, "RIGHT", 6, 0)
  ui.floorLabel:SetWidth(150)
  ui.floorLabel:SetWordWrap(false)
  ui.floorLabel:SetJustifyH("CENTER")
  ui.floorNext = W.Button(parent, ">", 24, 22, function() E.ChangeFloor(1) end)
  ui.floorNext:SetPoint("LEFT", ui.floorLabel, "RIGHT", 6, 0)
  ui.undo = W.Button(parent, "Undo", 60, 22, function() E.Undo() end)
  ui.undo:SetPoint("LEFT", ui.floorNext, "RIGHT", 12, 0)
  ui.hint = W.Label(parent, "", "GameFontDisableSmall")
  ui.hint:SetPoint("LEFT", ui.undo, "RIGHT", 10, 0)
  ui.hint:SetPoint("RIGHT", parent, "LEFT", PANEL_X - 8, 0)
  ui.hint:SetWordWrap(true)
  ui.hint:SetHeight(28)
end

local function routeBar(parent)
  ui.dungeon = W.Button(parent, "", 190, 22, function(self) E.DungeonPicker(self) end)
  ui.dungeon:SetPoint("TOPLEFT", 12, -30)
  W.Tooltip(ui.dungeon, function() return "Dungeon", "Click to choose a dungeon from the list." end)

  ui.routePrev = W.Button(parent, "<", 24, 22, function() E.CycleRoute(-1) end)
  ui.routePrev:SetPoint("LEFT", ui.dungeon, "RIGHT", 10, 0)
  ui.name = W.EditBox(parent, 200, function(text)
    local r = route()
    if r and text ~= "" then r.name = text:sub(1, M.LIMITS.name); edited() end
  end, editFocus)
  ui.name:SetPoint("LEFT", ui.routePrev, "RIGHT", 10, 0)
  ui.routeNext = W.Button(parent, ">", 24, 22, function() E.CycleRoute(1) end)
  ui.routeNext:SetPoint("LEFT", ui.name, "RIGHT", 4, 0)
  ui.routeCount = W.Label(parent, "", "GameFontDisableSmall")
  ui.routeCount:SetPoint("LEFT", ui.routeNext, "RIGHT", 6, 0)

  local x = PANEL_X - 120
  local function bar(text, width, fn)
    local b = W.Button(parent, text, width, 22, fn)
    b:SetPoint("TOPLEFT", x, -30)
    x = x + width + 2
    return b
  end
  ui.new = bar("New", 50, function() E.NewRoute() end)
  ui.copy = bar("Copy", 50, function()
    local r = route()
    if r then state.route = ns.Store.SaveCopy(r, " (copy)"); Refresh() end
  end)
  ui.delete = bar("Delete", 60, function(self)
    local r = route()
    if not r then return end
    if not self.armed then
      self.armed = true
      self:SetText("Sure?")
      C_Timer.After(3, function() self.armed = false; self:SetText("Delete") end)
      return
    end
    self.armed = false
    self:SetText("Delete")
    ns.Store.Delete(r.id)
    state.route = ns.Store.RoutesFor(state.dungeon.instanceID)[1]
    state.selected, state.marker = nil, nil
    Refresh()
  end)
  ui.export = bar("Export", 60, function() if route() then ns.Share.Export({ route() }) end end)
  ui.exportAll = bar("Export all", 76, function() ns.Share.Export(ns.Store.SortedAll()) end)
  ui.import = bar("Import", 60, function() ns.Share.Import() end)
  ui.run = bar("Run", 44, function() if route() then ns.Run.Open(route()) end end)
end

local LIST_ROWS = 8

local function stepList(parent)
  local title = W.Label(parent, "Steps", "GameFontNormal")
  title:SetPoint("TOPLEFT", PANEL_X, -88)
  ui.listUp = W.Button(parent, "^", 22, 18, function() state.listTop = math.max(1, (state.listTop or 1) - LIST_ROWS); Refresh() end)
  ui.listUp:SetPoint("TOPLEFT", PANEL_X + 280, -86)
  ui.listDown = W.Button(parent, "v", 22, 18, function() state.listTop = (state.listTop or 1) + LIST_ROWS; Refresh() end)
  ui.listDown:SetPoint("LEFT", ui.listUp, "RIGHT", 2, 0)
  ui.rows = {}
  for i = 1, LIST_ROWS do
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(330, 18)
    b:SetPoint("TOPLEFT", PANEL_X, -106 - (i - 1) * 18)
    b.hl = b:CreateTexture(nil, "BACKGROUND")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(0.3, 0.85, 1, 0.25)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b.text = W.Label(b, "", "GameFontHighlightSmall")
    b.text:SetPoint("LEFT", 4, 0)
    b.text:SetPoint("RIGHT", -4, 0)
    b.text:SetWordWrap(false)
    b:SetScript("OnClick", function(self)
      local s = route() and route().steps[self.index]
      if not s then return end
      state.selected, state.marker = self.index, nil
      focusStep(self.index)
      Refresh()
    end)
    ui.rows[i] = b
  end
end

local function taskRows(parent, top)
  ui.taskLabel = W.Label(parent, "Quests", "GameFontNormal")
  ui.taskLabel:SetPoint("TOPLEFT", PANEL_X, top)
  ui.tasks = {}
  for i = 1, M.LIMITS.tasks do
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(330, 18)
    row:SetPoint("TOPLEFT", PANEL_X, top - 16 - (i - 1) * 18)
    row.text = W.Label(row, "", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 0, 0)
    row.text:SetPoint("RIGHT", -26, 0)
    row.text:SetWordWrap(false)
    row.remove = W.Button(row, "x", 22, 18, function()
      local s = selectedStep()
      if s then change(function() table.remove(s.tasks, i) end) end
    end)
    row.remove:SetPoint("RIGHT", 0, 0)
    ui.tasks[i] = row
  end
  ui.taskAdd = CreateFrame("Frame", nil, parent)
  ui.taskAdd:SetSize(330, 22)
  ui.questID = W.EditBox(ui.taskAdd, 60)
  ui.questID:SetNumeric(true)
  ui.questID:SetPoint("LEFT", 6, 0)
  W.Tooltip(ui.questID, function() return "Quest ID", "Type a quest ID, or pick one from your quest log." end)
  ui.act = W.Cycle(ui.taskAdd, 80, M.ACTS, function(a) return W.ACT_LABEL[a] end)
  ui.act:SetPoint("LEFT", ui.questID, "RIGHT", 6, 0)
  ui.addTask = W.Button(ui.taskAdd, "Add", 48, 22, function()
    local s = selectedStep()
    local id = tonumber(ui.questID:GetText())
    if not s or not id or id < 1 or #s.tasks >= M.LIMITS.tasks then return end
    change(function() s.tasks[#s.tasks + 1] = { quest = id, act = ui.act:GetValue(), text = "" } end)
    ui.questID:SetText("")
  end)
  ui.addTask:SetPoint("LEFT", ui.act, "RIGHT", 4, 0)
  ui.fromLog = W.Button(ui.taskAdd, "From log", 76, 22, function(self) E.QuestPicker(self) end)
  ui.fromLog:SetPoint("LEFT", ui.addTask, "RIGHT", 4, 0)
end

local function stepDetail(parent)
  local top = -260
  local d = CreateFrame("Frame", nil, parent)
  d:SetPoint("TOPLEFT", PANEL_X, top)
  d:SetSize(330, 330)
  ui.detail = d

  ui.kind = W.Cycle(d, 90, M.KINDS, function(k) return W.KIND_LABEL[k] end, function(k)
    local s = selectedStep()
    if s then change(function() s.kind = k end) end
  end)
  local kl = W.Label(d, "Kind", "GameFontNormalSmall")
  kl:SetPoint("TOPLEFT", 0, -5)
  ui.kind:SetPoint("TOPLEFT", 30, 0)
  W.Tooltip(ui.kind, function()
    return "Kind of step", "Click: Entrance, Boss, Quest, Note. Right-click goes back.\nBoss steps get a Boss row to link the boss."
  end)
  ui.up = W.Button(d, "Up", 44, 22, function()
    if state.selected then change(function(r) state.selected = M.MoveStep(r, state.selected, state.selected - 1) end) end
  end)
  ui.up:SetPoint("LEFT", ui.kind, "RIGHT", 6, 0)
  ui.down = W.Button(d, "Down", 50, 22, function()
    if state.selected then change(function(r) state.selected = M.MoveStep(r, state.selected, state.selected + 1) end) end
  end)
  ui.down:SetPoint("LEFT", ui.up, "RIGHT", 2, 0)
  ui.removeStep = W.Button(d, "Remove", 70, 22, function()
    if state.selected then
      change(function(r)
        M.RemoveStep(r, state.selected)
        state.selected = (#r.steps > 0) and math.min(state.selected, #r.steps) or nil
      end)
    end
  end)
  ui.removeStep:SetPoint("LEFT", ui.down, "RIGHT", 10, 0)

  local tl = W.Label(d, "Title", "GameFontNormalSmall")
  tl:SetPoint("TOPLEFT", 0, -30)
  ui.title = W.EditBox(d, 280, function(text)
    local s = selectedStep()
    if s then s.title = text:sub(1, M.LIMITS.title); edited(); Refresh() end
  end, editFocus)
  ui.title:SetPoint("LEFT", tl, "RIGHT", 10, 0)

  local nl = W.Label(d, "Note (shown in the Run view)", "GameFontNormalSmall")
  nl:SetPoint("TOPLEFT", 0, -54)
  ui.note = W.MultiEdit(d, 330, 70, function(text)
    local s = selectedStep()
    if s then s.note = text:sub(1, M.LIMITS.note); edited() end
  end, editFocus)
  ui.note:SetPoint("TOPLEFT", 0, -68)

  ui.bossRow = CreateFrame("Frame", nil, d)
  ui.bossRow:SetSize(330, 22)
  ui.bossRow:SetPoint("TOPLEFT", 0, -144)
  local bl = W.Label(ui.bossRow, "Boss", "GameFontNormalSmall")
  bl:SetPoint("LEFT", 0, 0)
  ui.bossName = W.EditBox(ui.bossRow, 120, function(text)
    local s = selectedStep()
    if not s then return end
    local old = s.boss or {}
    -- typed by hand: match by name
    E.SetBoss(s, text, old.name == text and old.encounterID or nil)
    edited()
    Refresh() -- the step list shows the boss's name
  end, editFocus)
  ui.bossName:SetPoint("LEFT", bl, "RIGHT", 10, 0)
  ui.bossList = W.Button(ui.bossRow, "List", 44, 22, function(self) E.BossPicker(self) end)
  ui.bossList:SetPoint("LEFT", ui.bossName, "RIGHT", 4, 0)
  W.Tooltip(ui.bossList, function()
    return "Pick a boss", "The bosses of this dungeon. Picked bosses tick themselves when they die.\nFor anything else, type a name in the box."
  end)
  ui.lastKill = W.Button(ui.bossRow, "Last kill", 66, 22, function()
    local s, k = selectedStep(), ns.lastKill
    if s and k then
      change(function() E.SetBoss(s, k.name, k.id) end)
    end
  end)
  ui.lastKill:SetPoint("LEFT", ui.bossList, "RIGHT", 4, 0)
  W.Tooltip(ui.lastKill, function()
    local k = ns.lastKill
    if k then return "Link to " .. k.name, "The last boss killed (encounter " .. k.id .. "). The step ticks itself when this boss dies." end
    return "No boss killed yet", "Kill a boss, then click this to link the step to it. Or type the boss's name."
  end)
  ui.bossInfo = W.Label(ui.bossRow, "", "GameFontDisableSmall")
  ui.bossInfo:SetPoint("LEFT", ui.lastKill, "RIGHT", 4, 0)

  taskRows(parent, top - 172)

  ui.pathRow = CreateFrame("Frame", nil, parent)
  ui.pathRow:SetSize(330, 22)
  ui.pathLabel = W.Label(ui.pathRow, "", "GameFontHighlightSmall")
  ui.pathLabel:SetPoint("LEFT", 0, 0)
  ui.clearPath = W.Button(ui.pathRow, "Clear path", 80, 22, function()
    local s = selectedStep()
    if s then change(function() s.path = {} end) end
  end)
  ui.clearPath:SetPoint("RIGHT", 0, 0)
end

local function markerDetail(parent)
  local d = CreateFrame("Frame", nil, parent)
  d:SetPoint("TOPLEFT", PANEL_X, -260)
  d:SetSize(330, 120)
  ui.markerDetail = d
  local t = W.Label(d, "Marker", "GameFontNormal")
  t:SetPoint("TOPLEFT", 0, 0)
  ui.icons = {}
  for n = 1, 8 do
    local b = CreateFrame("Button", nil, d)
    b:SetSize(24, 24)
    b:SetPoint("TOPLEFT", (n - 1) * 28, -20)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.tex:SetTexture(W.RaidIcon(n))
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetPoint("TOPLEFT", -2, 2)
    b.sel:SetPoint("BOTTOMRIGHT", 2, -2)
    b.sel:SetColorTexture(0.3, 0.85, 1, 0.7)
    b:SetScript("OnClick", function()
      local m = selectedMarker()
      state.lastIcon = n
      if m then change(function() m.icon = n end) end
    end)
    ui.icons[n] = b
  end
  local tl = W.Label(d, "Text", "GameFontNormalSmall")
  tl:SetPoint("TOPLEFT", 0, -54)
  ui.markerText = W.EditBox(d, 280, function(text)
    local m = selectedMarker()
    if m then m.text = text:sub(1, M.LIMITS.markerText); edited(); Refresh(true) end
  end, editFocus)
  ui.markerText:SetPoint("LEFT", tl, "RIGHT", 10, 0)
  ui.removeMarker = W.Button(d, "Remove marker", 110, 22, function()
    local _, i = selectedMarker()
    if i then change(function(r) table.remove(r.markers, i); state.marker = nil end) end
  end)
  ui.removeMarker:SetPoint("TOPLEFT", 0, -82)
end

local function build()
  frame = W.Window("RouteKeeperEditor", PANEL_X + 330 + 14, 86 + MAP_H + 50, "RouteKeeper")
  tinsert(UISpecialFrames, "RouteKeeperEditor")
  canvas = ns.MapCanvas.New(frame, MAP_W, MAP_H)
  canvas.frame:SetPoint("TOPLEFT", 12, -86)
  canvas:SetCallbacks({
    onMapDown = onMapDown, onPinDown = onPinDown, onMarkerDown = onMarkerDown,
    onHandleDown = onHandleDown, pinTooltip = pinTooltip,
  })
  frame:HookScript("OnHide", function() W.HidePickList() end)
  routeBar(frame)
  toolButtons(frame)
  stepList(frame)
  stepDetail(frame)
  markerDetail(frame)
  ui.emptyPanel = W.Label(frame, "", "GameFontDisable")
  ui.emptyPanel:SetPoint("TOPLEFT", PANEL_X, -262)
  ui.emptyPanel:SetWidth(330)

  -- Ctrl+Z undoes; every other key goes on to the game.
  frame:EnableKeyboard(true)
  frame:SetScript("OnKeyDown", function(self, key)
    if InCombatLockdown() then return end
    if key == "Z" and IsControlKeyDown() then
      self:SetPropagateKeyboardInput(false)
      E.Undo()
    else
      self:SetPropagateKeyboardInput(true)
    end
  end)
end

-- Refresh -----------------------------------------------------------------

function E.UpdateBossInfo()
  local s = selectedStep()
  local b = s and s.boss
  if b and b.encounterID then
    ui.bossInfo:SetText("linked")
  elseif b and b.name and b.name ~= "" then
    ui.bossInfo:SetText("by name")
  else
    ui.bossInfo:SetText("")
  end
end

local function setText(box, text)
  if not box:HasFocus() then box:SetText(text or "") end
end

local function refreshPanel()
  local r = route()
  local s = selectedStep()
  local m = selectedMarker()

  -- step list
  local n = r and #r.steps or 0
  state.listTop = math.max(1, math.min(state.listTop or 1, math.max(1, n - LIST_ROWS + 1)))
  if state.selected and (state.selected < state.listTop or state.selected >= state.listTop + LIST_ROWS) then
    state.listTop = math.max(1, state.selected - LIST_ROWS + 1)
  end
  for i, row in ipairs(ui.rows) do
    local index = state.listTop + i - 1
    local step = r and r.steps[index]
    row.index = index
    row:SetShown(step ~= nil)
    if step then
      local name = W.StepName(step)
      local kind = W.KIND_LABEL[step.kind]
      local title = (name ~= kind) and ("  " .. name) or ""
      row.text:SetText(("%d. |cffffd100%s|r%s  |cff888888(%s)|r"):format(index, kind, title,
        W.Escape(ns.MapCanvas.FloorName(state.dungeon.instanceID, step.floor))))
      row.hl:SetShown(index == state.selected)
    end
  end
  ui.listUp:SetShown(state.listTop > 1)
  ui.listDown:SetShown(n >= state.listTop + LIST_ROWS)

  ui.detail:SetShown(s ~= nil)
  ui.markerDetail:SetShown(m ~= nil and s == nil)
  for _, row in ipairs(ui.tasks) do row:Hide() end
  ui.taskLabel:SetShown(s ~= nil)
  ui.taskAdd:SetShown(s ~= nil)
  ui.pathRow:SetShown(s ~= nil)
  if not r then
    ui.emptyPanel:SetText("No route for this dungeon yet. Click New to start one.")
  elseif not s and not m then
    ui.emptyPanel:SetText(n == 0 and "Choose the Step tool and click the map to add the first step."
      or "Select a step or a marker to edit it.")
  else
    ui.emptyPanel:SetText("")
  end

  if s then
    ui.kind:SetValue(s.kind)
    setText(ui.title, s.title)
    setText(ui.note.edit, s.note)
    ui.bossRow:SetShown(s.kind == "boss")
    setText(ui.bossName, s.boss and s.boss.name or "")
    E.UpdateBossInfo()
    ui.up:SetEnabled(state.selected > 1)
    ui.down:SetEnabled(state.selected < n)
    local top = -260 - 172 - 16
    for i, t in ipairs(s.tasks) do
      local row = ui.tasks[i]
      row.text:SetText(("|cffffd100%s|r %s |cff888888(%d)|r"):format(W.ACT_LABEL[t.act], W.Escape(ns.Quests.Name(t.quest)), t.quest))
      row:Show()
    end
    ui.taskAdd:ClearAllPoints()
    ui.taskAdd:SetPoint("TOPLEFT", frame, "TOPLEFT", PANEL_X - 6, top - #s.tasks * 18)
    ui.taskAdd:SetShown(#s.tasks < M.LIMITS.tasks)
    ui.pathRow:ClearAllPoints()
    ui.pathRow:SetPoint("TOPLEFT", frame, "TOPLEFT", PANEL_X, top - #s.tasks * 18 - 28)
    ui.pathLabel:SetText(("Path to this step: %d points"):format(#s.path))
  end
  if m and not s then
    for k, b in ipairs(ui.icons) do b.sel:SetShown(m.icon == k) end
    setText(ui.markerText, m.text)
  end
end

-- quick = only the map (while dragging or typing).
local function refreshNow(quick)
  if not frame or not frame:IsShown() then return end
  local r = route()
  local floors = ns.MapCanvas.FloorList(state.dungeon.instanceID, r)
  local known = false
  for _, f in ipairs(floors) do if f == state.floor then known = true end end
  if not known and not quick then state.floor = floors[1] end

  canvas:DrawArt(state.dungeon.instanceID, state.floor)
  canvas:DrawRoute(r, {
    floor = state.floor, selected = state.selected, selectedMarker = state.marker,
    editPath = (state.tool == "path" or state.tool == "draw") and state.selected or nil,
  })
  if quick then return end

  frame.title:SetText("RouteKeeper - " .. W.Escape(state.dungeon.name))
  ui.dungeon:SetText(W.Escape(state.dungeon.name))
  local list = ns.Store.RoutesFor(state.dungeon.instanceID)
  ui.routeCount:SetText(#list > 1 and (#list .. " routes") or "")
  setText(ui.name, r and r.name or "")
  ui.name:SetEnabled(r ~= nil)
  for _, b in ipairs({ ui.copy, ui.delete, ui.export, ui.run }) do b:SetEnabled(r ~= nil) end
  ui.routePrev:SetEnabled(#list > 1)
  ui.routeNext:SetEnabled(#list > 1)
  ui.floorLabel:SetText(ns.MapCanvas.FloorName(state.dungeon.instanceID, state.floor))
  ui.floorPrev:SetEnabled(#floors > 1)
  ui.floorNext:SetEnabled(#floors > 1)
  for _, b in ipairs(ui.tools) do
    b:SetEnabled(r ~= nil)
    if b.tool == state.tool then b:LockHighlight() else b:UnlockHighlight() end
  end
  local hint = HINTS[state.tool]
  if (state.tool == "path" or state.tool == "draw") and not state.selected then hint = "Select the step this path leads to first." end
  ui.hint:SetText(hint)
  refreshPanel()
end

Refresh = ns.W.Guard(refreshNow)
E.Refresh = function() Refresh() end

-- Actions -----------------------------------------------------------------

function E.SetDungeon(d)
  state.dungeon = { instanceID = d.instanceID, name = d.name }
  local last = ns.Store.LastRoute(d.instanceID)
  state.route = (last and ns.Store.Get(last)) or ns.Store.RoutesFor(d.instanceID)[1]
  state.selected, state.marker, state.floor = nil, nil, 1
  if canvas then canvas:ResetView() end
end

function E.CycleRoute(dir)
  local list = ns.Store.RoutesFor(state.dungeon.instanceID)
  if #list == 0 then return end
  local at = 1
  for i, r in ipairs(list) do if r == state.route then at = i end end
  state.route = list[(at - 1 + dir) % #list + 1]
  ns.Store.SetLastRoute(state.dungeon.instanceID, state.route.id)
  state.selected, state.marker = nil, nil
  Refresh()
end

function E.NewRoute()
  local author = UnitName and UnitName("player") or ""
  local r = M.NewRoute(ns.Store.Rand, state.dungeon, state.dungeon.name .. " route", author, now())
  ns.Store.Put(r)
  ns.Store.SetLastRoute(state.dungeon.instanceID, r.id)
  state.route, state.selected, state.marker, state.tool = r, nil, nil, "step"
  canvas:ResetView()
  Refresh()
end

function E.ChangeFloor(dir)
  local floors = ns.MapCanvas.FloorList(state.dungeon.instanceID, route())
  local at = 1
  for i, f in ipairs(floors) do if f == state.floor then at = i end end
  -- Past the last known floor: allow one more, for dungeons without art.
  local nextIndex = at + dir
  if nextIndex > #floors then
    state.floor = (dir > 0 and not ns.MapCanvas.ArtFloors(state.dungeon.instanceID)[1]) and math.min(M.LIMITS.floor, floors[#floors] + 1) or floors[1]
  elseif nextIndex < 1 then
    state.floor = floors[#floors]
  else
    state.floor = floors[nextIndex]
  end
  canvas:ResetView()
  Refresh(true)
  ui.floorLabel:SetText(ns.MapCanvas.FloorName(state.dungeon.instanceID, state.floor))
end

function E.Undo()
  local r = route()
  if not r then return end
  local copy = undo:Pop(r.id)
  if not copy then return end
  for k in pairs(r) do r[k] = nil end
  for k, v in pairs(copy) do r[k] = v end
  if state.selected and not r.steps[state.selected] then state.selected = nil end
  if state.marker and not selectedMarker() then state.marker = nil end
  Refresh()
end

-- Quest picker: the quests in the log, click one to fill in its ID.
function E.QuestPicker(anchor)
  local items = {}
  for _, q in ipairs(ns.Quests.Log()) do
    items[#items + 1] = { text = W.Escape(q.title) .. " |cff888888(" .. q.id .. ")|r", value = q.id }
  end
  W.PickList(anchor, items, function(id) ui.questID:SetText(tostring(id)) end, "Your quest log is empty.")
end

-- Sets a step's boss. The title follows the boss's name while it is empty
-- or still the old boss's name; a title of your own is kept.
function E.SetBoss(s, name, encounterID)
  name = (name or ""):sub(1, M.LIMITS.title)
  local old = s.boss and s.boss.name or ""
  s.boss = { encounterID = encounterID, name = name }
  if (s.title or "") == "" or s.title == old then s.title = name end
end

-- Boss list: the dungeon's bosses, then bosses named in your other routes
-- for this dungeon. Bosses already in this route show their step number.
function E.BossPicker(anchor)
  local s = selectedStep()
  if not s then return end
  local d = state.dungeon
  local known = ns.Dungeons.ByInstance(d.instanceID) or d
  local extra, used = {}, {}
  for _, r in ipairs(ns.Store.RoutesFor(d.instanceID)) do
    for i, st in ipairs(r.steps) do
      local name = st.kind == "boss" and st.boss and st.boss.name
      if name and name ~= "" then
        extra[#extra + 1] = name
        if r == route() and st ~= s then used[name:lower()] = used[name:lower()] or i end
      end
    end
  end
  local names, listed = ns.Dungeons.BossNames(known, extra)
  local current = s.boss and s.boss.name and s.boss.name:lower()
  local items = {}
  for i, name in ipairs(names) do
    local text = W.Escape(name)
    if i > listed then text = text .. " |cff888888(from your routes)|r" end
    if used[name:lower()] then text = text .. " |cff888888- step " .. used[name:lower()] .. "|r" end
    items[#items + 1] = { text = text, value = name, selected = name:lower() == current }
  end
  W.PickList(anchor, items, function(name)
    local step = selectedStep()
    if not step then return end
    change(function()
      local old = step.boss
      -- Keep a link learned from a kill when the same boss is picked again.
      local id = old and old.name and old.name:lower() == name:lower() and old.encounterID or nil
      E.SetBoss(step, name, id)
      -- Known spawn spot: the pin goes there (Ctrl+Z puts it back).
      local spot = ns.Dungeons.BossSpot(known, name)
      if spot then step.floor, step.x, step.y = spot.floor, spot.x, spot.y end
    end)
    if ns.Dungeons.BossSpot(known, name) then focusStep(state.selected); Refresh() end
  end, "No boss list for this dungeon. Type the boss's name in the box.")
end

-- Dungeon list: every dungeon with a map or a saved route, and the one you
-- are in; the number of routes is shown.
function E.DungeonPicker(anchor)
  local here = ns.Run.HereDungeon()
  local items = {}
  for _, d in ipairs(ns.Store.Dungeons(here and here.instanceID, here and here.name)) do
    local n = #ns.Store.RoutesFor(d.instanceID)
    local text = W.Escape(d.name)
    if n > 0 then text = text .. " |cff40ff40(" .. n .. (n == 1 and " route" or " routes") .. ")|r" end
    if here and here.instanceID == d.instanceID then text = text .. " |cff888888- you are here|r" end
    items[#items + 1] = { text = text, value = d, selected = d.instanceID == state.dungeon.instanceID }
  end
  W.PickList(anchor, items, function(d)
    E.SetDungeon(d)
    Refresh()
  end)
end

function E.IsShown() return frame and frame:IsShown() end

-- Opens the editor; on a route, or on the dungeon you are in.
function E.Open(r)
  if InCombatLockdown() then
    print("|cff40ff40RouteKeeper:|r the editor opens out of combat.")
    return
  end
  if not frame then build() end
  if r then
    state.dungeon = { instanceID = r.dungeon.instanceID, name = r.dungeon.name }
    state.route, state.selected, state.marker = r, nil, nil
    state.floor = (r.steps[1] and r.steps[1].floor) or 1
    canvas:ResetView()
  else
    -- In a dungeon: show that one. Elsewhere: whatever was shown last.
    local here = ns.Run.HereDungeon()
    if here and (not state.dungeon or state.dungeon.instanceID ~= here.instanceID) then
      E.SetDungeon(here)
    elseif not state.dungeon then
      E.SetDungeon(ns.Dungeons.list[1])
    end
  end
  frame:Show()
  Refresh()
end

function E.Toggle()
  if frame and frame:IsShown() then frame:Hide() else E.Open() end
end

function E.Hide() if frame then frame:Hide() end end

-- A route was replaced by an import while the editor shows it.
function E.RouteChanged(id)
  if state.route and state.route.id == id then state.route = ns.Store.Get(id) end
  Refresh()
end

-- For the smoke test.
function E._state() return state, canvas, ui end
