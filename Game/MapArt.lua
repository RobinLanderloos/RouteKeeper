-- Reads dungeon map art from the game files by path (ADR 0002).
local addonName, ns = ...

local MapArt = {}
ns.MapArt = MapArt

-- True when the game files have this texture.
function MapArt.Exists(path)
  if type(GetFileIDFromPath) ~= "function" then return false end
  local ok, id = pcall(GetFileIDFromPath, path)
  return ok and type(id) == "number" and id > 0
end

local cache = {}

-- Floors of a dungeon ({ floor, tiles } list), discovered once per session.
function MapArt.Floors(dungeon)
  local floors = cache[dungeon.folder]
  if not floors then
    floors = ns.Dungeons.Discover(dungeon.folder, MapArt.Exists)
    cache[dungeon.folder] = floors
  end
  return floors
end
