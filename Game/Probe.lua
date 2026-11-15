-- /rk probe: a diagnostic report of what the client offers for the dungeon
-- you are in and for the map art (see ADR 0002, 0004). Written into
-- RouteKeeperDB so it can be read from the SavedVariables file after /reload.
local addonName, ns = ...

local Probe = {}
ns.Probe = Probe

local Say = function(t) ns.Report.Say(t) end

function Probe.Here()
  local ok, name, instanceType, difficultyID, difficultyName, maxPlayers, _, _, instanceID = pcall(GetInstanceInfo)
  if not ok then Say("GetInstanceInfo failed") return end
  Say(("instance: %s type=%s difficulty=%s (%s) players=%s instanceID=%s"):format(tostring(name),
    tostring(instanceType), tostring(difficultyID), tostring(difficultyName), tostring(maxPlayers),
    tostring(instanceID)))
  local d = ns.Dungeons.ByInstance(instanceID)
  Say("map art for this instance: " .. (d and d.name or "none (blank grid)"))
  local k = ns.lastKill
  Say("last boss kill: " .. (k and (k.name .. " (" .. k.id .. ")") or "none this session"))
  local count = 0
  for _ in pairs(ns.Store.All()) do count = count + 1 end
  Say("saved routes: " .. count)
end

-- Which floors and how many tiles each dungeon has in the game files.
function Probe.ArtDiscovery()
  local found = 0
  for _, d in ipairs(ns.Dungeons.list) do
    local parts = {}
    if d.folder then
      for _, f in ipairs(ns.Dungeons.Discover(d.folder, ns.MapArt.Exists)) do parts[#parts + 1] = f.floor .. ":" .. f.tiles end
    elseif d.fileBase then
      parts[1] = "1:file ids"
    end
    if #parts > 0 then found = found + 1 end
    Say(("art %s (%s): %s"):format(d.key, d.folder or "file ids", #parts > 0 and table.concat(parts, " ") or "none"))
  end
  return found
end

-- Boss-kill events while in an instance, newest last, capped.
local MAX_EVENTS = 100

function Probe.LogEvent(charDB, text)
  charDB.eventLog = type(charDB.eventLog) == "table" and charDB.eventLog or {}
  local log = charDB.eventLog
  log[#log + 1] = (date and date("%H:%M:%S ") or "") .. text
  while #log > MAX_EVENTS do table.remove(log, 1) end
end
