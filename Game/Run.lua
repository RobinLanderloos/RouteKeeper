-- The Run view: a compact window shown while going through a dungeon,
-- with the current step, its note and quests, and a small map. Progress
-- follows boss kills and quest events (ADR 0004).
local addonName, ns = ...

local Run = {}
ns.Run = Run

local W, P = ns.W, ns.Progress
local WIDTH = 340
local MAP_W, MAP_H = WIDTH - 24, math.floor((WIDTH - 24) / 1.5)

local frame, canvas
local state = { routeID = nil, viewFloor = nil, autoOpened = false }

local function now() return time() end

function Run.HereDungeon()
  local ok, inInstance, kind = pcall(IsInInstance)
  if not ok or not inInstance or (kind ~= "party" and kind ~= "raid") then return nil end
  local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
  if not instanceID or instanceID == 0 then return nil end
  return { instanceID = instanceID, name = name or ("Instance " .. instanceID) }
end

local function route() return state.routeID and ns.Store.Get(state.routeID) end

local function progress(r) return ns.Store.Progress(r, now()) end

local function stateOf(r, p, current)
  return function(i)
    local s = P.StepState(r, p, i, ns.Quests.state)
    if s == "open" and i == current then return "current" end
    return s
  end
end

local Refresh

local function build()
  frame = W.Window("RouteKeeperRun", WIDTH, 400, "RouteKeeper")
  frame:SetPoint("CENTER", 380, 60)
  frame:SetFrameStrata("MEDIUM")

  frame.routeName = W.Label(frame, "", "GameFontNormal")
  frame.routeName:SetPoint("TOPLEFT", 12, -28)
  frame.routeName:SetPoint("RIGHT", -110, 0)
  frame.routeName:SetWordWrap(false)
  frame.count = W.Label(frame, "", "GameFontHighlightSmall")
  frame.count:SetPoint("TOPRIGHT", -12, -30)
  frame.routePrev = W.Button(frame, "<", 22, 18, function() Run.CycleRoute(-1) end)
  frame.routePrev:SetPoint("TOPRIGHT", -80, -26)
  frame.routeNext = W.Button(frame, ">", 22, 18, function() Run.CycleRoute(1) end)
  frame.routeNext:SetPoint("LEFT", frame.routePrev, "RIGHT", 2, 0)

  canvas = ns.MapCanvas.New(frame, MAP_W, MAP_H)
  canvas.frame:SetPoint("TOPLEFT", 12, -50)
  canvas:SetCallbacks({
    onMapDown = function(_, _, button) canvas:StartPan(button) end,
    onPinDown = function(i, button)
      local r = route()
      if not r or button ~= "RightButton" then return end
      P.Cycle(r, progress(r), i, ns.Quests.state)
      Refresh()
    end,
    pinTooltip = function(i)
      local r = route()
      local s = r and r.steps[i]
      if not s then return end
      return i .. ". " .. W.StepName(s),
        W.Escape(s.note) .. "\n|cff888888Right-click: done / skipped / open|r"
    end,
  })
  frame.floorPrev = W.Button(canvas.frame, "<", 20, 18, function() Run.ChangeFloor(-1) end)
  frame.floorPrev:SetPoint("TOPLEFT", 2, -2)
  frame.floorPrev:SetFrameLevel(canvas.overlay:GetFrameLevel() + 10)
  frame.floorLabel = W.Label(canvas.frame, "", "GameFontHighlightSmall")
  frame.floorLabel:SetPoint("LEFT", frame.floorPrev, "RIGHT", 4, 0)
  frame.floorNext = W.Button(canvas.frame, ">", 20, 18, function() Run.ChangeFloor(1) end)
  frame.floorNext:SetPoint("LEFT", frame.floorLabel, "RIGHT", 4, 0)
  frame.floorNext:SetFrameLevel(canvas.overlay:GetFrameLevel() + 10)

  frame.step = W.Label(frame, "", "GameFontNormalLarge")
  frame.step:SetWidth(WIDTH - 24)
  frame.step:SetWordWrap(true)
  frame.body = W.Label(frame, "", "GameFontHighlight")
  frame.body:SetWidth(WIDTH - 24)
  frame.body:SetWordWrap(true)
  frame.body:SetSpacing(2)
  frame.nextLine = W.Label(frame, "", "GameFontDisableSmall")
  frame.nextLine:SetWidth(WIDTH - 24)
  frame.nextLine:SetWordWrap(false)

  frame.back = W.Button(frame, "< Back", 64, 22, function() Run.Back() end)
  frame.skip = W.Button(frame, "Skip", 52, 22, function() Run.Skip() end)
  frame.nextB = W.Button(frame, "Next >", 64, 22, function() Run.Next() end)
  frame.map = W.Button(frame, "Map+", 50, 22, function() local r = route(); if r then ns.Editor.Open(r) end end)
  frame.collapse = W.Button(frame, "-", 24, 22, function()
    local s = ns.Store.Settings()
    s.collapsed = not s.collapsed
    Refresh()
  end)
  frame.reset = W.Button(frame, "Reset", 52, 22, function(self)
    if not self.armed then
      self.armed = true
      self:SetText("Sure?")
      C_Timer.After(3, function() self.armed = false; self:SetText("Reset") end)
      return
    end
    self.armed = false
    self:SetText("Reset")
    local r = route()
    if r then ns.Store.ResetProgress(r, now()) end
    state.viewFloor = nil
    Refresh()
  end)
  W.Tooltip(frame.collapse, function() return "Show or hide the map" end)
  W.Tooltip(frame.map, function() return "Open the big map (editor)" end)
end

local function taskLine(t)
  local s = P.TaskState(t, ns.Quests.state)
  local icon = s == "done" and W.CHECK or (s == "na" and W.DOT or W.CROSS)
  local name = W.Escape(ns.Quests.Name(t.quest))
  local text = (t.text and t.text ~= "") and (" - " .. W.Escape(t.text)) or ""
  local line = ("%s %s: %s%s"):format(icon, W.ACT_LABEL[t.act], name, text)
  if s == "na" then line = "|cff777777" .. line .. " (not on this quest)|r" end
  return line
end

local function refreshNow()
  if not frame or not frame:IsShown() then return end
  local r = route()
  if not r then frame:Hide() return end
  local p = progress(r)
  -- While the window is open the run goes on; it only goes stale (and
  -- starts over) after 30 minutes away from it.
  ns.Progress.Touch(p, now())
  local q = ns.Quests.state
  local current = P.Current(r, p, q)
  local done, total = P.Counts(r, p, q)
  local settings = ns.Store.Settings()
  frame.locked = settings.locked

  frame.title:SetText(W.Escape(r.dungeon.name))
  frame.routeName:SetText(W.Escape(r.name))
  frame.count:SetText(done .. "/" .. total)
  local siblings = #ns.Store.RoutesFor(r.dungeon.instanceID)
  frame.routePrev:SetShown(siblings > 1)
  frame.routeNext:SetShown(siblings > 1)

  local step = current and r.steps[current]
  local floors = ns.MapCanvas.FloorList(r.dungeon.instanceID, r)
  local floor = state.viewFloor or (step and step.floor) or floors[1]

  local y = -50
  canvas.frame:SetShown(not settings.collapsed)
  frame.collapse:SetText(settings.collapsed and "+" or "-")
  if not settings.collapsed then
    -- Zoom in on the way to the current step when it changes; the whole
    -- floor when looking at another floor or when the route is done.
    local key = r.id .. ":" .. tostring(current) .. ":" .. floor .. ":" .. tostring(state.viewFloor)
    if key ~= state.fitKey then
      state.fitKey = key
      if step and not state.viewFloor then
        local pts = {}
        for _, pt in ipairs(ns.Model.FullPath(r, current)) do
          if pt.floor == floor then pts[#pts + 1] = pt end
        end
        canvas:FitPoints(pts, 0.06, 0.2)
      else
        canvas:ResetView()
      end
    end
    canvas:DrawArt(r.dungeon.instanceID, floor)
    canvas:DrawRoute(r, { floor = floor, stateOf = stateOf(r, p, current) })
    frame.floorLabel:SetText(ns.MapCanvas.FloorName(r.dungeon.instanceID, floor))
    local many = #floors > 1
    frame.floorPrev:SetShown(many); frame.floorNext:SetShown(many); frame.floorLabel:SetShown(many)
    y = y - MAP_H - 8
  end

  frame.step:ClearAllPoints()
  frame.step:SetPoint("TOPLEFT", 12, y)
  local lines = {}
  if step then
    local title = W.StepName(step)
    frame.step:SetText(("%d. %s |cff888888(%s)|r"):format(current, title, W.KIND_LABEL[step.kind]:lower()))
    if step.note ~= "" then lines[#lines + 1] = W.Escape(step.note) end
    if step.kind == "boss" and step.boss and step.boss.name ~= "" and W.StepName(step) ~= W.Escape(step.boss.name) then
      lines[#lines + 1] = "|cffff6060Kill " .. W.Escape(step.boss.name) .. "|r"
    end
    for _, t in ipairs(step.tasks) do lines[#lines + 1] = taskLine(t) end
  elseif #r.steps == 0 then
    frame.step:SetText("This route has no steps yet.")
  else
    frame.step:SetText("|cff40ff40Route finished!|r")
    lines[1] = "Reset to start again."
  end
  frame.body:SetText(table.concat(lines, "\n"))
  y = y - frame.step:GetStringHeight() - 6
  frame.body:ClearAllPoints()
  frame.body:SetPoint("TOPLEFT", 12, y)
  if #lines > 0 then y = y - frame.body:GetStringHeight() - 6 end

  local nextIndex
  if current then
    for i = current + 1, #r.steps do
      if P.StepState(r, p, i, q) == "open" then nextIndex = i; break end
    end
  end
  if nextIndex then
    local s = r.steps[nextIndex]
    frame.nextLine:SetText(("Next: %d. %s"):format(nextIndex, W.StepName(s)))
  else
    frame.nextLine:SetText("")
  end
  frame.nextLine:ClearAllPoints()
  frame.nextLine:SetPoint("TOPLEFT", 12, y)
  y = y - 16

  frame.back:ClearAllPoints()
  frame.back:SetPoint("TOPLEFT", 10, y - 4)
  frame.skip:SetPoint("LEFT", frame.back, "RIGHT", 2, 0)
  frame.nextB:SetPoint("LEFT", frame.skip, "RIGHT", 2, 0)
  frame.map:SetPoint("LEFT", frame.nextB, "RIGHT", 8, 0)
  frame.collapse:SetPoint("LEFT", frame.map, "RIGHT", 2, 0)
  frame.reset:SetPoint("LEFT", frame.collapse, "RIGHT", 2, 0)
  frame.nextB:SetEnabled(current ~= nil)
  frame.skip:SetEnabled(current ~= nil)
  frame:SetHeight(-(y - 4) + 22 + 12)
end

Refresh = ns.W.Guard(refreshNow)
Run.Refresh = function() Refresh() end

function Run.Open(r, auto)
  if not frame then build() end
  state.routeID = r.id
  state.viewFloor = nil
  state.autoOpened = auto and true or false
  ns.Store.SetLastRoute(r.dungeon.instanceID, r.id)
  ns.Progress.Touch(progress(r), now())
  frame:Show()
  Refresh()
end

function Run.Hide() if frame then frame:Hide() end end
function Run.IsShown() return frame and frame:IsShown() end

function Run.Toggle()
  if frame and frame:IsShown() then frame:Hide(); return end
  local r = route()
  local here = Run.HereDungeon()
  if here then
    local list = ns.Store.RoutesFor(here.instanceID)
    if not r or r.dungeon.instanceID ~= here.instanceID then
      local last = ns.Store.LastRoute(here.instanceID)
      r = (last and ns.Store.Get(last)) or list[1]
    end
  end
  if r then Run.Open(r) else
    print("|cff40ff40RouteKeeper:|r no route to show. /rk edit to make one, /rk import to paste one.")
  end
end

function Run.CycleRoute(dir)
  local r = route()
  if not r then return end
  local list = ns.Store.RoutesFor(r.dungeon.instanceID)
  local at = 1
  for i, x in ipairs(list) do if x.id == r.id then at = i end end
  Run.Open(list[(at - 1 + dir) % #list + 1], state.autoOpened)
end

function Run.ChangeFloor(dir)
  local r = route()
  if not r then return end
  local floors = ns.MapCanvas.FloorList(r.dungeon.instanceID, r)
  local p = progress(r)
  local current = P.Current(r, p, ns.Quests.state)
  local floor = state.viewFloor or (current and r.steps[current].floor) or floors[1]
  local at = 1
  for i, f in ipairs(floors) do if f == floor then at = i end end
  state.viewFloor = floors[(at - 1 + dir) % #floors + 1]
  Refresh()
end

local function act(fn)
  local r = route()
  if not r then return end
  local p = progress(r)
  fn(r, p, ns.Quests.state)
  ns.Progress.Touch(p, now())
  state.viewFloor = nil
  Refresh()
end

function Run.Next() act(P.Next) end
function Run.Skip() act(P.Skip) end
function Run.Back() act(P.Back) end

-- A boss died in the dungeon of the shown route (or of any route for here).
function Run.OnBossKill(encounterID, name)
  local here = Run.HereDungeon()
  local routes = {}
  local r = route()
  if r then routes[1] = r end
  if here then
    for _, x in ipairs(ns.Store.RoutesFor(here.instanceID)) do
      if not r or x.id ~= r.id then routes[#routes + 1] = x end
    end
  end
  for _, x in ipairs(routes) do
    local p = progress(x)
    if P.OnEncounter(x, p, encounterID, name) then ns.Progress.Touch(p, now()) end
  end
  state.viewFloor = nil
  Refresh()
end

-- Entering the world: open on a dungeon that has a route; close again on
-- leaving if it opened by itself.
function Run.OnEnterWorld()
  local here = Run.HereDungeon()
  if not here then
    if state.autoOpened then Run.Hide(); state.autoOpened = false end
    return
  end
  local list = ns.Store.RoutesFor(here.instanceID)
  if #list == 0 then return end
  local last = ns.Store.LastRoute(here.instanceID)
  local r = (last and ns.Store.Get(last)) or list[1]
  if ns.Store.Settings().autoOpen then Run.Open(r, true) end
end

function Run.SetCombat(inCombat)
  if not frame then return end
  local s = ns.Store.Settings()
  frame:SetAlpha((inCombat and s.fadeInCombat) and s.combatAlpha or 1)
end

function Run._state() return state, frame, canvas end
