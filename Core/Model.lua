-- Routes, Steps, Paths and Markers (ADR 0003), and the checks every Route
-- passes when it is imported or loaded (ADR 0005). Pure: no game calls.
--
-- route = {
--   id, rev, name, author, created,
--   dungeon = { instanceID, name },
--   steps = { step, ... }, markers = { marker, ... },
-- }
-- step = {
--   id, kind = "entrance"|"boss"|"quest"|"note", floor, x, y, title, note,
--   boss = { encounterID, name },             -- boss steps
--   tasks = { { quest = id, act = "start"|"objective"|"end", text }, ... },
--   path = { { x, y, floor }, ... },          -- line from the previous step
-- }
-- marker = { id, floor, x, y, icon = 1..8 (raid icons), text }
-- x and y are 0..1 across the map picture, from the top-left.
local addonName, ns = ...

local Model = {}
ns.Model = Model

Model.KINDS = { "entrance", "boss", "quest", "note" }
Model.ACTS = { "start", "objective", "end" }
Model.LIMITS = {
  name = 60, author = 40, title = 80, note = 1000, taskText = 120, markerText = 120,
  steps = 100, markers = 100, tasks = 6, pathPoints = 400, floor = 20,
}

local KIND, ACT = {}, {}
for _, k in ipairs(Model.KINDS) do KIND[k] = true end
for _, a in ipairs(Model.ACTS) do ACT[a] = true end

local ID_CHARS = "abcdefghijklmnopqrstuvwxyz0123456789"

-- rand(n) -> integer 1..n (math.random in the game, a fixed one in tests).
function Model.NewID(rand, length)
  local out = {}
  for i = 1, length or 10 do
    local n = rand(#ID_CHARS)
    out[i] = ID_CHARS:sub(n, n)
  end
  return table.concat(out)
end

local function round(v) return math.floor(v * 10000 + 0.5) / 10000 end

function Model.NewRoute(rand, dungeon, name, author, now)
  return {
    id = Model.NewID(rand), rev = 1,
    name = name or "New route", author = author, created = now,
    dungeon = { instanceID = dungeon.instanceID, name = dungeon.name },
    steps = {}, markers = {},
  }
end

function Model.NewStep(rand, kind, floor, x, y)
  return { id = Model.NewID(rand, 6), kind = kind or "note", floor = floor or 1,
    x = round(x or 0.5), y = round(y or 0.5), title = "", note = "", tasks = {}, path = {} }
end

function Model.NewMarker(rand, floor, x, y, icon)
  return { id = Model.NewID(rand, 6), floor = floor or 1, x = round(x), y = round(y), icon = icon or 8, text = "" }
end

function Model.Round(v) return round(v) end

-- Steps -------------------------------------------------------------------

function Model.StepIndex(route, stepID)
  for i, s in ipairs(route.steps) do if s.id == stepID then return i end end
end

-- Inserts after position `after` (nil: at the end). Returns the new index.
function Model.AddStep(route, step, after)
  local at = after and (after + 1) or (#route.steps + 1)
  table.insert(route.steps, at, step)
  return at
end

function Model.RemoveStep(route, index)
  return table.remove(route.steps, index)
end

-- Moves a step; its path moves with it (the path belongs to the step it
-- leads to). Returns the new index.
function Model.MoveStep(route, from, to)
  local n = #route.steps
  if from < 1 or from > n then return from end
  to = math.max(1, math.min(n, to))
  local s = table.remove(route.steps, from)
  table.insert(route.steps, to, s)
  return to
end

-- Where a step's line starts: the previous step, or nothing for the first.
function Model.PathStart(route, index)
  local prev = route.steps[index - 1]
  if prev then return { x = prev.x, y = prev.y, floor = prev.floor } end
end

-- The full line to a step: previous step, path points, the step itself,
-- each as { x, y, floor }.
function Model.FullPath(route, index)
  local step = route.steps[index]
  local pts = {}
  local start = Model.PathStart(route, index)
  if start then pts[#pts + 1] = start end
  for _, p in ipairs(step.path or {}) do pts[#pts + 1] = { x = p[1], y = p[2], floor = p[3] } end
  pts[#pts + 1] = { x = step.x, y = step.y, floor = step.floor }
  return pts
end

-- The name to show for a step: its own title, else the boss's name (boss
-- steps), else the first quest's name (quest steps), else the kind.
-- questName(id) gives a quest's name; kindLabel(kind) the kind's label.
function Model.StepName(step, questName, kindLabel)
  if step.title and step.title ~= "" then return step.title end
  if step.kind == "boss" and step.boss and step.boss.name and step.boss.name ~= "" then return step.boss.name end
  if step.kind == "quest" and step.tasks and step.tasks[1] then return questName(step.tasks[1].quest) end
  return kindLabel(step.kind)
end

-- Floors a route uses, sorted.
function Model.Floors(route)
  local seen, list = {}, {}
  local function add(f) if f and not seen[f] then seen[f] = true; list[#list + 1] = f end end
  for _, s in ipairs(route.steps) do
    add(s.floor)
    for _, p in ipairs(s.path or {}) do add(p[3]) end
  end
  for _, m in ipairs(route.markers) do add(m.floor) end
  table.sort(list)
  return list
end

-- Checks ------------------------------------------------------------------

local function cleanText(v, max)
  if v == nil then return "" end
  if type(v) ~= "string" then return nil end
  v = v:gsub("%z", ""):gsub("[\1-\8\11\12\14-\31]", "")
  if #v > max then v = v:sub(1, max) end
  return v
end

local function cleanNumber(v, lo, hi, integer)
  if type(v) ~= "number" or v ~= v then return nil end
  if integer and v ~= math.floor(v) then return nil end
  if v < lo or v > hi then return nil end
  return v
end

local function cleanFloor(v) return cleanNumber(v, 1, Model.LIMITS.floor, true) end
local function cleanCoord(v)
  v = cleanNumber(v, -0.01, 1.01)
  return v and round(math.max(0, math.min(1, v)))
end
local function cleanID(v, max)
  if type(v) ~= "string" or #v < 1 or #v > (max or 16) or v:find("[^%w]") then return nil end
  return v
end

local function fail(where, what) return nil, where .. ": " .. what end

local function cleanStep(s, where)
  if type(s) ~= "table" then return fail(where, "not a step") end
  local L = Model.LIMITS
  local out = {
    id = cleanID(s.id, 16), kind = KIND[s.kind] and s.kind or nil,
    floor = cleanFloor(s.floor), x = cleanCoord(s.x), y = cleanCoord(s.y),
    title = cleanText(s.title, L.title), note = cleanText(s.note, L.note),
    tasks = {}, path = {},
  }
  for _, f in ipairs({ "id", "kind", "floor", "x", "y", "title", "note" }) do
    if out[f] == nil then return fail(where, "bad " .. f) end
  end
  if s.boss ~= nil then
    if type(s.boss) ~= "table" then return fail(where, "bad boss") end
    local b = { encounterID = s.boss.encounterID ~= nil and cleanNumber(s.boss.encounterID, 1, 1e7, true) or nil,
      name = cleanText(s.boss.name, L.title) }
    if s.boss.encounterID ~= nil and not b.encounterID then return fail(where, "bad boss id") end
    if not b.name then return fail(where, "bad boss name") end
    if b.encounterID or b.name ~= "" then out.boss = b end
  end
  if s.tasks ~= nil then
    if type(s.tasks) ~= "table" or #s.tasks > L.tasks then return fail(where, "bad tasks") end
    for i, t in ipairs(s.tasks) do
      if type(t) ~= "table" then return fail(where, "bad task " .. i) end
      local q = cleanNumber(t.quest, 1, 1e7, true)
      local text = cleanText(t.text, L.taskText)
      if not q or not ACT[t.act] or not text then return fail(where, "bad task " .. i) end
      out.tasks[i] = { quest = q, act = t.act, text = text }
    end
  end
  if s.path ~= nil then
    if type(s.path) ~= "table" or #s.path > L.pathPoints then return fail(where, "bad path") end
    for i, p in ipairs(s.path) do
      if type(p) ~= "table" then return fail(where, "bad path point " .. i) end
      local x, y, f = cleanCoord(p[1]), cleanCoord(p[2]), cleanFloor(p[3])
      if not (x and y and f) then return fail(where, "bad path point " .. i) end
      out.path[i] = { x, y, f }
    end
  end
  return out
end

local function cleanMarker(m, where)
  if type(m) ~= "table" then return fail(where, "not a marker") end
  local out = { id = cleanID(m.id, 16), floor = cleanFloor(m.floor), x = cleanCoord(m.x), y = cleanCoord(m.y),
    icon = cleanNumber(m.icon, 1, 8, true), text = cleanText(m.text, Model.LIMITS.markerText) }
  for _, f in ipairs({ "id", "floor", "x", "y", "icon", "text" }) do
    if out[f] == nil then return fail(where, "bad " .. f) end
  end
  return out
end

-- Returns a clean copy of the route (only known fields, safe values), or
-- nil and the reason. Used for every import and every loaded route.
function Model.Validate(r)
  if type(r) ~= "table" then return nil, "not a route" end
  local L = Model.LIMITS
  local out = {
    id = cleanID(r.id, 16), rev = cleanNumber(r.rev, 1, 1e9, true),
    name = cleanText(r.name, L.name), author = cleanText(r.author, L.author),
    created = r.created ~= nil and cleanNumber(r.created, 0, 1e11, true) or nil,
    steps = {}, markers = {},
  }
  if not out.id then return nil, "bad route id" end
  if not out.rev then return nil, "bad revision" end
  if not out.name or out.name == "" then return nil, "bad name" end
  if not out.author then return nil, "bad author" end
  if type(r.dungeon) ~= "table" then return nil, "bad dungeon" end
  local d = { instanceID = cleanNumber(r.dungeon.instanceID, 1, 1e7, true), name = cleanText(r.dungeon.name, L.name) }
  if not d.instanceID or not d.name then return nil, "bad dungeon" end
  out.dungeon = d
  if type(r.steps) ~= "table" or #r.steps > L.steps then return nil, "bad steps" end
  local ids = {}
  for i, s in ipairs(r.steps) do
    local clean, err = cleanStep(s, "step " .. i)
    if not clean then return nil, err end
    if ids[clean.id] then return nil, "step " .. i .. ": duplicate id" end
    ids[clean.id] = true
    out.steps[i] = clean
  end
  if r.markers ~= nil then
    if type(r.markers) ~= "table" or #r.markers > L.markers then return nil, "bad markers" end
    for i, m in ipairs(r.markers) do
      local clean, err = cleanMarker(m, "marker " .. i)
      if not clean then return nil, err end
      out.markers[i] = clean
    end
  end
  return out
end

function Model.Copy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = Model.Copy(x) end
  return out
end
