-- Small geometry helpers for drawing paths. Points are { x, y } in map
-- units; aspect scales x so distances match what is seen on screen.
local addonName, ns = ...

local Geometry = {}
ns.Geometry = Geometry

local sqrt = math.sqrt

-- Distance from p to the segment a-b, and the position t (0..1) along it.
function Geometry.SegmentDistance(px, py, ax, ay, bx, by, aspect)
  aspect = aspect or 1
  px, ax, bx = px * aspect, ax * aspect, bx * aspect
  local dx, dy = bx - ax, by - ay
  local len2 = dx * dx + dy * dy
  local t = 0
  if len2 > 0 then t = math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / len2)) end
  local cx, cy = ax + t * dx, ay + t * dy
  return sqrt((px - cx) ^ 2 + (py - cy) ^ 2), t
end

-- Douglas-Peucker: keeps the points that matter for the shape.
-- points: list of { x, y, ... }; returns a new list (same point tables).
function Geometry.Simplify(points, tolerance, aspect)
  local n = #points
  if n <= 2 then
    local out = {}
    for i = 1, n do out[i] = points[i] end
    return out
  end
  local keep = { [1] = true, [n] = true }
  local stack = { { 1, n } }
  while #stack > 0 do
    local range = table.remove(stack)
    local first, last = range[1], range[2]
    local maxDist, index = 0, nil
    local a, b = points[first], points[last]
    for i = first + 1, last - 1 do
      local p = points[i]
      local d = Geometry.SegmentDistance(p[1], p[2], a[1], a[2], b[1], b[2], aspect)
      if d > maxDist then maxDist, index = d, i end
    end
    if index and maxDist > tolerance then
      keep[index] = true
      stack[#stack + 1] = { first, index }
      stack[#stack + 1] = { index, last }
    end
  end
  local out = {}
  for i = 1, n do if keep[i] then out[#out + 1] = points[i] end end
  return out
end

-- Index of the nearest point within radius, or nil.
function Geometry.NearestPoint(points, x, y, radius, aspect)
  aspect = aspect or 1
  local best, bestD
  for i, p in ipairs(points) do
    local d = sqrt(((p[1] - x) * aspect) ^ 2 + (p[2] - y) ^ 2)
    if d <= radius and (not bestD or d < bestD) then best, bestD = i, d end
  end
  return best
end
