-- Saved data (ADR 0005): routes and settings in the account-wide
-- RouteKeeperDB, run progress per character in RouteKeeperCharDB.
local addonName, ns = ...

local Store = {}
ns.Store = Store

local DEFAULTS = { autoOpen = true, fadeInCombat = true, combatAlpha = 0.45, locked = false, collapsed = false, runScale = 1 }

local db, charDB

function Store.Rand(n) return math.random(n) end

-- Called on ADDON_LOADED. Every saved route passes the same checks as an
-- import; a route that fails is set aside in db.broken, never lost.
function Store.Load()
  RouteKeeperDB = type(RouteKeeperDB) == "table" and RouteKeeperDB or {}
  RouteKeeperCharDB = type(RouteKeeperCharDB) == "table" and RouteKeeperCharDB or {}
  db, charDB = RouteKeeperDB, RouteKeeperCharDB
  db.routes = type(db.routes) == "table" and db.routes or {}
  db.settings = type(db.settings) == "table" and db.settings or {}
  db.lastRoute = type(db.lastRoute) == "table" and db.lastRoute or {}
  db.dirty = type(db.dirty) == "table" and db.dirty or {}
  for k, v in pairs(DEFAULTS) do
    if type(db.settings[k]) ~= type(v) then db.settings[k] = v end
  end
  charDB.progress = type(charDB.progress) == "table" and charDB.progress or {}
  local broken = 0
  for id, r in pairs(db.routes) do
    local clean = ns.Model.Validate(r)
    if clean and clean.id == id then
      db.routes[id] = clean
    else
      db.broken = db.broken or {}
      db.broken[#db.broken + 1] = r
      db.routes[id] = nil
      broken = broken + 1
    end
  end
  return broken
end

function Store.Settings() return db.settings end
function Store.DB() return db end

function Store.Get(id) return db.routes[id] end
function Store.All() return db.routes end

local function byName(a, b)
  if a.name:lower() == b.name:lower() then return a.id < b.id end
  return a.name:lower() < b.name:lower()
end

-- Routes for one dungeon, sorted by name.
function Store.RoutesFor(instanceID)
  local list = {}
  for _, r in pairs(db.routes) do
    if r.dungeon.instanceID == instanceID then list[#list + 1] = r end
  end
  table.sort(list, byName)
  return list
end

function Store.SortedAll()
  local list = {}
  for _, r in pairs(db.routes) do list[#list + 1] = r end
  table.sort(list, function(a, b)
    if a.dungeon.name ~= b.dungeon.name then return a.dungeon.name < b.dungeon.name end
    return byName(a, b)
  end)
  return list
end

-- Dungeons that have a map or a saved route, for the editor's dungeon list.
function Store.Dungeons(extraInstanceID, extraName)
  local list, seen = {}, {}
  for _, d in ipairs(ns.Dungeons.list) do
    list[#list + 1] = { instanceID = d.instanceID, name = d.name }
    seen[d.instanceID] = true
  end
  local function add(id, name)
    if id and not seen[id] then
      seen[id] = true
      list[#list + 1] = { instanceID = id, name = name or ("Instance " .. id) }
    end
  end
  for _, r in pairs(db.routes) do add(r.dungeon.instanceID, r.dungeon.name) end
  add(extraInstanceID, extraName)
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

function Store.Put(route)
  db.routes[route.id] = route
end

-- A route was edited: its revision goes up on the next export.
function Store.Touch(route)
  db.dirty[route.id] = true
end

function Store.Delete(id)
  db.routes[id] = nil
  db.dirty[id] = nil
  charDB.progress[id] = nil
  for k, v in pairs(db.lastRoute) do if v == id then db.lastRoute[k] = nil end end
end

-- Before export: an edited route gets the next revision.
function Store.BumpIfEdited(route)
  if db.dirty[route.id] then
    route.rev = route.rev + 1
    db.dirty[route.id] = nil
  end
end

function Store.SaveCopy(route, suffix)
  local copy = ns.Model.Copy(route)
  copy.id = ns.Model.NewID(Store.Rand)
  copy.rev = 1
  if suffix then copy.name = (copy.name .. suffix):sub(1, ns.Model.LIMITS.name) end
  db.routes[copy.id] = copy
  return copy
end

function Store.LastRoute(instanceID) return db.lastRoute[instanceID] end
function Store.SetLastRoute(instanceID, id) db.lastRoute[instanceID] = id end

-- Progress for a route on this character; a fresh one when stale.
function Store.Progress(route, now)
  local p = charDB.progress[route.id]
  if type(p) ~= "table" or type(p.status) ~= "table" or ns.Progress.IsStale(p, now) then
    p = ns.Progress.New(route.id, now)
    charDB.progress[route.id] = p
  end
  return p
end

function Store.ResetProgress(route, now)
  charDB.progress[route.id] = ns.Progress.New(route.id, now)
  return charDB.progress[route.id]
end

function Store.CharDB() return charDB end
