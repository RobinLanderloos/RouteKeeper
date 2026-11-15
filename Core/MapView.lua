-- Zoom and pan for the map: which part of the map picture is in view.
-- A view is zoom (1 = whole map) and the centre (cx, cy) in map units 0..1.
-- The canvas has the map's own shape, so one unit means the same on both axes.
local addonName, ns = ...

local MapView = {}
ns.MapView = MapView

MapView.MAX_ZOOM = 8

local function clampZoom(z) return math.max(1, math.min(MapView.MAX_ZOOM, z)) end

-- Keeps the view inside the map.
function MapView.Clamp(zoom, cx, cy)
  zoom = clampZoom(zoom)
  local half = 0.5 / zoom
  cx = math.max(half, math.min(1 - half, cx))
  cy = math.max(half, math.min(1 - half, cy))
  return zoom, cx, cy
end

-- The view that shows all points with some room around them.
-- points: { { x, y }, ... } or { { x = , y = }, ... }.
-- minSpan stops a single point from zooming in all the way.
function MapView.Fit(points, padding, minSpan, maxZoom)
  if #points == 0 then return 1, 0.5, 0.5 end
  padding, minSpan = padding or 0.08, minSpan or 0.2
  local minX, minY, maxX, maxY = 1, 1, 0, 0
  for _, p in ipairs(points) do
    local x, y = p.x or p[1], p.y or p[2]
    minX, maxX = math.min(minX, x), math.max(maxX, x)
    minY, maxY = math.min(minY, y), math.max(maxY, y)
  end
  local spanX = math.max(maxX - minX, minSpan) + 2 * padding
  local spanY = math.max(maxY - minY, minSpan) + 2 * padding
  local zoom = math.min(1 / spanX, 1 / spanY, maxZoom or MapView.MAX_ZOOM)
  return MapView.Clamp(zoom, (minX + maxX) / 2, (minY + maxY) / 2)
end

-- Zooms by factor keeping the map point (mx, my) under the cursor.
function MapView.ZoomAt(zoom, cx, cy, factor, mx, my)
  local nz = clampZoom(zoom * factor)
  local ncx = mx - (mx - cx) * zoom / nz
  local ncy = my - (my - cy) * zoom / nz
  return MapView.Clamp(nz, ncx, ncy)
end

-- Where the map's top-left corner goes, in pixels from the canvas's
-- top-left (y down), for a canvas of width x height.
function MapView.Offset(zoom, cx, cy, width, height)
  return width / 2 - cx * width * zoom, height / 2 - cy * height * zoom
end
