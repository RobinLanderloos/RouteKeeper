-- A dungeon map with a route drawn on it, used by the editor and the Run
-- view. The art is the game's own tiles (ADR 0002); a dungeon without art
-- gets a grid. Positions are 0..1 across the picture, from the top-left.
local addonName, ns = ...

local Canvas = {}
Canvas.__index = Canvas
ns.MapCanvas = Canvas

local COLORS = {
  current = { 0.25, 1, 0.35 },
  open = { 1, 0.82, 0 },
  done = { 0.55, 0.55, 0.55 },
  skipped = { 0.55, 0.55, 0.55 },
  na = { 0.35, 0.35, 0.35 },
  selected = { 0.3, 0.85, 1 },
}
local KIND_COLOR = {
  entrance = { 0.55, 0.75, 1 }, boss = { 0.85, 0.2, 0.2 }, quest = { 1, 0.82, 0 }, note = { 0.75, 0.75, 0.75 },
}

function Canvas.New(parent, width, height)
  local self = setmetatable({}, Canvas)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, height)
  f:SetClipsChildren(true)
  f:EnableMouse(true)
  self.frame, self.width, self.height = f, width, height

  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.06, 0.05, 0.04, 1)

  -- The map picture and everything on it sit on `content`, which is moved
  -- and sized for zoom and pan; the canvas clips it.
  self.content = CreateFrame("Frame", nil, f)
  self.content:SetSize(width, height)
  self.content:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  self.overlay = CreateFrame("Frame", nil, self.content)
  self.overlay:SetAllPoints(self.content)
  self.overlay:SetFrameLevel(f:GetFrameLevel() + 2)
  self.zoom, self.cx, self.cy = 1, 0.5, 0.5
  self.cw, self.ch = width, height

  self.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  self.empty:SetPoint("BOTTOMRIGHT", -6, 6)

  self.tiles, self.grid, self.lines, self.labels = {}, {}, {}, {}
  self.pins, self.marks, self.handles = {}, {}, {}
  self.used = {}
  self.cb = {}

  f:SetScript("OnMouseDown", function(_, button)
    if self.cb.onMapDown then
      local x, y = self:CursorPos()
      self.cb.onMapDown(x, y, button)
    end
  end)
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", ns.W.Guard(function(_, delta)
    local x, y = self:CursorPos()
    self:ZoomBy(delta > 0 and 1.25 or 0.8, x, y)
  end))
  self.driver = CreateFrame("Frame", nil, f)

  -- + / - / Fit, top right.
  local level = f:GetFrameLevel() + 20
  local function corner(text, w, fn, tip)
    local b = ns.W.Button(f, text, w, 18, fn)
    b:SetFrameLevel(level)
    ns.W.Tooltip(b, function() return tip end)
    return b
  end
  self.fitButton = corner("Fit", 34, function() self:ResetView(); self:Redraw() end, "Show the whole floor")
  self.fitButton:SetPoint("TOPRIGHT", -2, -2)
  self.zoomOut = corner("-", 20, function() self:ZoomBy(0.8, self.cx, self.cy) end, "Zoom out (or mouse wheel)")
  self.zoomOut:SetPoint("RIGHT", self.fitButton, "LEFT", -2, 0)
  self.zoomIn = corner("+", 20, function() self:ZoomBy(1.25, self.cx, self.cy) end, "Zoom in (or mouse wheel)")
  self.zoomIn:SetPoint("RIGHT", self.zoomOut, "LEFT", -2, 0)
  return self
end

-- Zoom and pan --------------------------------------------------------------

-- Moves and sizes the content for the current view (no redraw).
function Canvas:ApplyView()
  self.cw, self.ch = self.width * self.zoom, self.height * self.zoom
  local ox, oy = ns.MapView.Offset(self.zoom, self.cx, self.cy, self.width, self.height)
  self.content:SetSize(self.cw, self.ch)
  self.content:ClearAllPoints()
  self.content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", ox, -oy)
end

function Canvas:SetView(zoom, cx, cy)
  self.zoom, self.cx, self.cy = ns.MapView.Clamp(zoom, cx, cy)
  self:ApplyView()
end

function Canvas:ResetView() self:SetView(1, 0.5, 0.5) end

-- Zooms in on the given points ({ x, y } or { x =, y = }).
function Canvas:FitPoints(points, padding, minSpan)
  self:SetView(ns.MapView.Fit(points, padding, minSpan))
end

function Canvas:ZoomBy(factor, mx, my)
  self:SetView(ns.MapView.ZoomAt(self.zoom, self.cx, self.cy, factor, mx, my))
  self:Redraw()
end

-- Draws again what was drawn last, for the current view.
function Canvas:Redraw()
  if self.lastArt then self:DrawArt(self.lastArt[1], self.lastArt[2]) end
  if self.lastRouteView then self:DrawRoute(self.lastRoute, self.lastRouteView) end
end

-- Drags the map while `button` is held.
function Canvas:StartPan(button)
  local s = self.frame:GetEffectiveScale()
  local sx, sy = GetCursorPosition()
  local cx0, cy0 = self.cx, self.cy
  self.driver:SetScript("OnUpdate", ns.W.Guard(function()
    if not IsMouseButtonDown(button) then
      self.driver:SetScript("OnUpdate", nil)
      return
    end
    local x, y = GetCursorPosition()
    local dx, dy = (x - sx) / s, (y - sy) / s
    self:SetView(self.zoom, cx0 - dx / self.cw, cy0 + dy / self.ch)
    self:Redraw()
  end))
end

function Canvas:SetCallbacks(cb)
  self.cb = {}
  for k, fn in pairs(cb or {}) do
    -- tooltips return text, so they are not wrapped
    self.cb[k] = (k == "pinTooltip") and fn or ns.W.Guard(fn)
  end
end

function Canvas:SetSize(width, height)
  self.width, self.height = width, height
  self.frame:SetSize(width, height)
end

-- Cursor position on the map (0..1 across the whole picture, whatever the
-- zoom), clamped to the map.
function Canvas:CursorPos()
  local c = self.content
  local cx, cy = GetCursorPosition()
  local s = c:GetEffectiveScale()
  local left, top = c:GetLeft() or 0, c:GetTop() or 0
  local x = (cx / s - left) / self.cw
  local y = (top - cy / s) / self.ch
  return math.max(0, math.min(1, x)), math.max(0, math.min(1, y))
end

-- Calls fn(x, y, finished) every frame while the left button is held.
function Canvas:StartDrag(fn)
  self.driver:SetScript("OnUpdate", ns.W.Guard(function()
    local x, y = self:CursorPos()
    if not IsMouseButtonDown("LeftButton") then
      self.driver:SetScript("OnUpdate", nil)
      fn(x, y, true)
    else
      fn(x, y, false)
    end
  end))
end

function Canvas:Dragging() return self.driver:GetScript("OnUpdate") ~= nil end

-- Floors with art for a dungeon ({ floor, tiles } list; empty without art).
function Canvas.ArtFloors(instanceID)
  local d = ns.Dungeons.ByInstance(instanceID)
  if not d then return {}, nil end
  if d.folder then
    local found = ns.MapArt.Floors(d)
    if not d.floors then return found, d end
    -- Only the floors this dungeon uses, in its order.
    local byFloor, list = {}, {}
    for _, f in ipairs(found) do byFloor[f.floor] = f end
    for _, n in ipairs(d.floors) do
      if byFloor[n] then list[#list + 1] = byFloor[n] end
    end
    return list, d
  end
  if d.fileBase then return { { floor = 1, tiles = 12 } }, d end
  return {}, d
end

-- Floors to offer: those with art, in the dungeon's order, then any other
-- floor the route uses.
function Canvas.FloorList(instanceID, route)
  local seen, list, extra = {}, {}, {}
  for _, f in ipairs((Canvas.ArtFloors(instanceID))) do
    if not seen[f.floor] then seen[f.floor] = true; list[#list + 1] = f.floor end
  end
  if route then
    for _, f in ipairs(ns.Model.Floors(route)) do
      if not seen[f] then seen[f] = true; extra[#extra + 1] = f end
    end
  end
  table.sort(extra)
  for _, f in ipairs(extra) do list[#list + 1] = f end
  if #list == 0 then list[1] = 1 end
  return list
end

function Canvas.FloorName(instanceID, floor)
  return ns.Dungeons.FloorName(ns.Dungeons.ByInstance(instanceID), floor)
end

local function px(self, x, y) return x * self.cw, -y * self.ch end

function Canvas:DrawArt(instanceID, floor)
  self.lastArt = { instanceID, floor }
  for _, t in ipairs(self.tiles) do t:Hide() end
  for _, t in ipairs(self.grid) do t:Hide() end
  local floors, dungeon = Canvas.ArtFloors(instanceID)
  local art
  for _, f in ipairs(floors) do if f.floor == floor then art = f end end
  if art then
    self.empty:SetText("")
    local _, _, _, tiles = ns.MapTiles.Layout(ns.Dungeons.LAYER, self.cw, self.ch)
    -- Stretch to the content exactly (the canvas keeps the 1002:668 shape).
    local sx = self.cw / ns.Dungeons.LAYER.layerWidth
    local sy = self.ch / ns.Dungeons.LAYER.layerHeight
    for i, tile in ipairs(tiles) do
      local t = self.tiles[i]
      if not t then
        t = self.content:CreateTexture(nil, "ARTWORK")
        self.tiles[i] = t
      end
      local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", self.content, "TOPLEFT", col * 256 * sx, -row * 256 * sy)
      t:SetSize(256 * sx, 256 * sy)
      local tex = tile.index <= art.tiles and ns.Dungeons.Tile(dungeon, floor, tile.index)
      if tex then t:SetTexture(tex); t:Show() end
    end
  else
    -- No map: a grid to place things on.
    self.empty:SetText("No map for this floor")
    local n = 0
    local function gridLine(x1, y1, x2, y2)
      n = n + 1
      local t = self.grid[n]
      if not t then
        t = self.content:CreateTexture(nil, "ARTWORK")
        self.grid[n] = t
      end
      t:ClearAllPoints()
      t:SetColorTexture(1, 1, 1, 0.07)
      local ax, ay = px(self, x1, y1)
      local bx, by = px(self, x2, y2)
      t:SetPoint("TOPLEFT", self.content, "TOPLEFT", ax, ay)
      t:SetSize(math.max(1, bx - ax), math.max(1, ay - by))
      t:Show()
    end
    for i = 1, 11 do gridLine(i / 12, 0, i / 12, 1) end
    for i = 1, 7 do gridLine(0, i / 8, 1, i / 8) end
  end
end

-- Pools ------------------------------------------------------------------

local function take(self, pool, make)
  self.used[pool] = (self.used[pool] or 0) + 1
  local list = self[pool]
  local item = list[self.used[pool]]
  if not item then
    item = make()
    list[self.used[pool]] = item
  end
  item:Show()
  return item
end

local function hideUnused(self)
  for _, pool in ipairs({ "lines", "labels", "pins", "marks", "handles" }) do
    local list, n = self[pool], self.used[pool] or 0
    for i = n + 1, #list do list[i]:Hide() end
    self.used[pool] = 0
  end
end

local function drawLine(self, a, b, color, alpha, thickness)
  local o = self.overlay
  local ax, ay = px(self, a.x, a.y)
  local bx, by = px(self, b.x, b.y)
  if o.CreateLine then
    local l = take(self, "lines", function() return o:CreateLine(nil, "ARTWORK") end)
    l:SetColorTexture(color[1], color[2], color[3], alpha)
    l:SetThickness(thickness)
    l:SetStartPoint("TOPLEFT", o, ax, ay)
    l:SetEndPoint("TOPLEFT", o, bx, by)
  else
    -- No line API: dots along the segment.
    local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
    local steps = math.max(1, math.floor(len / 5))
    for i = 0, steps do
      local d = take(self, "lines", function() return o:CreateTexture(nil, "ARTWORK") end)
      d:SetColorTexture(color[1], color[2], color[3], alpha)
      d:SetSize(thickness, thickness)
      d:ClearAllPoints()
      d:SetPoint("CENTER", o, "TOPLEFT", ax + (bx - ax) * i / steps, ay + (by - ay) * i / steps)
    end
  end
end

local function drawLabel(self, x, y, text, color)
  local l = take(self, "labels", function() return self.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") end)
  l:ClearAllPoints()
  local ax, ay = px(self, x, y)
  l:SetPoint("BOTTOM", self.overlay, "TOPLEFT", ax, ay + 8)
  l:SetText(text)
  l:SetTextColor(color[1], color[2], color[3])
end

local function makePin(self)
  local b = CreateFrame("Button", nil, self.overlay)
  b:SetSize(20, 20)
  b:SetFrameLevel(self.overlay:GetFrameLevel() + 5)
  b.border = b:CreateTexture(nil, "BACKGROUND")
  b.border:SetAllPoints()
  b.border:SetColorTexture(0, 0, 0, 0.9)
  b.fill = b:CreateTexture(nil, "BORDER")
  b.fill:SetPoint("TOPLEFT", 2, -2)
  b.fill:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(14, 14)
  b.icon:SetPoint("BOTTOMLEFT", b, "TOPRIGHT", -8, -6)
  b.glow = b:CreateTexture(nil, "OVERLAY")
  b.glow:SetPoint("TOPLEFT", -5, 5)
  b.glow:SetPoint("BOTTOMRIGHT", 5, -5)
  b.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
  b.glow:SetBlendMode("ADD")
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("CENTER", 0, 0)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnMouseDown", function(pin, button)
    if self.cb.onPinDown then self.cb.onPinDown(pin.index, button) end
  end)
  ns.W.Tooltip(b, function(pin)
    if self.cb.pinTooltip then return self.cb.pinTooltip(pin.index) end
  end)
  return b
end

local function makeMark(self)
  local b = CreateFrame("Button", nil, self.overlay)
  b:SetSize(18, 18)
  b:SetFrameLevel(self.overlay:GetFrameLevel() + 4)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.sel = b:CreateTexture(nil, "BACKGROUND")
  b.sel:SetPoint("TOPLEFT", -3, 3)
  b.sel:SetPoint("BOTTOMRIGHT", 3, -3)
  b.sel:SetColorTexture(COLORS.selected[1], COLORS.selected[2], COLORS.selected[3], 0.6)
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.label:SetPoint("TOP", b, "BOTTOM", 0, -1)
  b.label:SetShadowOffset(1, -1)
  b:SetScript("OnMouseDown", function(mark, button)
    if self.cb.onMarkerDown then self.cb.onMarkerDown(mark.id, button) end
  end)
  ns.W.Tooltip(b, function(mark)
    if mark.text and mark.text ~= "" then return mark.text end
  end)
  return b
end

local function makeHandle(self)
  local b = CreateFrame("Button", nil, self.overlay)
  b:SetSize(10, 10)
  b:SetFrameLevel(self.overlay:GetFrameLevel() + 6)
  b.tex = b:CreateTexture(nil, "OVERLAY")
  b.tex:SetAllPoints()
  b.tex:SetColorTexture(1, 1, 1, 0.9)
  b:SetScript("OnMouseDown", function(h, button)
    if self.cb.onHandleDown then self.cb.onHandleDown(h.index, button) end
  end)
  return b
end

-- Draws the route on the given floor.
-- view = {
--   floor, stateOf = function(i) -> "current"|"open"|"done"|"skipped"|"na",
--   selected = step index, selectedMarker = marker id, editPath = step index,
-- }
function Canvas:DrawRoute(route, view)
  self.lastRoute, self.lastRouteView = route, view
  self.used = {}
  if not route then hideUnused(self); return end
  local floor = view.floor
  local stateOf = view.stateOf or function() return "open" end
  local thick = (self.width > 500 or self.zoom > 1.5) and 3 or 2

  for i = 1, #route.steps do
    local state = stateOf(i)
    local color = (view.selected == i) and COLORS.selected or COLORS[state] or COLORS.open
    local alpha = (state == "na") and 0.5 or 0.95
    local pts = ns.Model.FullPath(route, i)
    for k = 1, #pts - 1 do
      local a, b = pts[k], pts[k + 1]
      if a.floor == floor and b.floor == floor then
        drawLine(self, a, b, color, alpha, (state == "current" or view.selected == i) and thick + 1 or thick)
      elseif a.floor == floor then
        drawLabel(self, a.x, a.y, "to " .. Canvas.FloorName(route.dungeon.instanceID, b.floor), color)
      elseif b.floor == floor then
        drawLabel(self, b.x, b.y, "from " .. Canvas.FloorName(route.dungeon.instanceID, a.floor), color)
      end
    end
  end

  for _, m in ipairs(route.markers) do
    if m.floor == floor then
      local b = take(self, "marks", function() return makeMark(self) end)
      b.id, b.text = m.id, m.text
      b.icon:SetTexture(ns.W.RaidIcon(m.icon))
      local short = m.text or ""
      if #short > 24 then short = short:sub(1, 22) .. "..." end
      b.label:SetText(ns.W.Escape(short))
      b.sel:SetShown(view.selectedMarker == m.id)
      b:ClearAllPoints()
      b:SetPoint("CENTER", self.overlay, "TOPLEFT", px(self, m.x, m.y))
    end
  end

  for i, s in ipairs(route.steps) do
    if s.floor == floor then
      local state = stateOf(i)
      local b = take(self, "pins", function() return makePin(self) end)
      b.index = i
      local c = (state == "done" or state == "skipped" or state == "na") and COLORS.done or KIND_COLOR[s.kind]
      b.fill:SetColorTexture(c[1], c[2], c[3], state == "na" and 0.4 or 1)
      b.text:SetText(state == "done" and "|cff00ff00" .. i .. "|r" or tostring(i))
      b.icon:SetShown(s.kind == "boss")
      if s.kind == "boss" then b.icon:SetTexture(ns.W.RaidIcon(8)) end
      b.glow:SetShown(state == "current" or view.selected == i)
      b.glow:SetVertexColor(unpack(view.selected == i and COLORS.selected or COLORS.current))
      b:ClearAllPoints()
      b:SetPoint("CENTER", self.overlay, "TOPLEFT", px(self, s.x, s.y))
    end
  end

  if view.editPath and route.steps[view.editPath] then
    for k, p in ipairs(route.steps[view.editPath].path) do
      if p[3] == floor then
        local h = take(self, "handles", function() return makeHandle(self) end)
        h.index = k
        h:ClearAllPoints()
        h:SetPoint("CENTER", self.overlay, "TOPLEFT", px(self, p[1], p[2]))
      end
    end
  end
  hideUnused(self)
end
