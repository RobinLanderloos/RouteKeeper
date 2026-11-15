-- Loading, game events and the /rk command.
local addonName, ns = ...

ns.LibDeflate = LibStub and LibStub("LibDeflate", true)

local function say(text) print("|cff40ff40RouteKeeper:|r " .. text) end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")

-- Quest events come in bursts; redraw once shortly after.
local refreshQueued = false
local function queueRefresh()
  if refreshQueued then return end
  refreshQueued = true
  C_Timer.After(0.2, function()
    refreshQueued = false
    ns.Run.Refresh()
    if ns.Editor.IsShown() then ns.Editor.Refresh() end
  end)
end

local handlers = {}

function handlers.ADDON_LOADED(name)
  if name ~= addonName then return end
  events:UnregisterEvent("ADDON_LOADED")
  local broken = ns.Store.Load()
  if broken > 0 then say(broken .. " saved route(s) could not be read and were set aside.") end
  local last = ns.Store.CharDB().lastKill
  if type(last) == "table" and type(last.id) == "number" and type(last.name) == "string" then ns.lastKill = last end
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ENCOUNTER_START", "ENCOUNTER_END", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_LOG_UPDATE",
    "QUEST_DATA_LOAD_RESULT" }) do
    pcall(events.RegisterEvent, events, e)
  end
end

function handlers.PLAYER_ENTERING_WORLD()
  local here = ns.Run.HereDungeon()
  if here then
    ns.Probe.LogEvent(ns.Store.CharDB(), ("entered %s instanceID=%s"):format(here.name, here.instanceID))
  end
  ns.Run.OnEnterWorld()
end

function handlers.ENCOUNTER_START(encounterID, name)
  ns.Probe.LogEvent(ns.Store.CharDB(), ("ENCOUNTER_START %s | %s"):format(tostring(encounterID), tostring(name)))
end

function handlers.ENCOUNTER_END(encounterID, name, _, _, success)
  ns.Probe.LogEvent(ns.Store.CharDB(), ("ENCOUNTER_END %s | %s | %s"):format(tostring(encounterID), tostring(name), tostring(success)))
  if success ~= 1 and success ~= true then return end
  if type(encounterID) ~= "number" or type(name) ~= "string" then return end
  ns.lastKill = { id = encounterID, name = name }
  ns.Store.CharDB().lastKill = ns.lastKill
  ns.Run.OnBossKill(encounterID, name)
  if ns.Editor.IsShown() then ns.Editor.Refresh() end
end

function handlers.PLAYER_REGEN_DISABLED()
  if ns.Editor.IsShown() then
    ns.Editor.Hide()
    say("editor closed for combat.")
  end
  ns.Run.SetCombat(true)
end

function handlers.PLAYER_REGEN_ENABLED() ns.Run.SetCombat(false) end

handlers.QUEST_ACCEPTED = queueRefresh
handlers.QUEST_TURNED_IN = queueRefresh
handlers.QUEST_REMOVED = queueRefresh
handlers.QUEST_LOG_UPDATE = queueRefresh
handlers.QUEST_DATA_LOAD_RESULT = queueRefresh

events:SetScript("OnEvent", ns.W.Guard(function(_, event, ...)
  local h = handlers[event]
  if h then h(...) end
end))

-- /rk ---------------------------------------------------------------------

local function onOff(v) return v and "on" or "off" end

local function help()
  say("commands:")
  print("  /rk  - show or hide the route for this dungeon")
  print("  /rk edit  - open the editor")
  print("  /rk import  - paste a route   /rk export  - all your routes")
  print("  /rk next | back | skip | reset  - move through the route")
  print("  /rk auto  - open by itself in dungeons (" .. onOff(ns.Store.Settings().autoOpen) .. ")")
  print("  /rk fade  - fade the window in combat (" .. onOff(ns.Store.Settings().fadeInCombat) .. ")")
  print("  /rk lock  - lock the window in place (" .. onOff(ns.Store.Settings().locked) .. ")")
  print("  /rk probe  - diagnostic report (for the developer)")
end

local commands = {}

commands[""] = function() ns.Run.Toggle() end
commands.run = commands[""]
commands.edit = function() ns.Editor.Toggle() end
commands.editor = commands.edit
commands.import = function() ns.Share.Import() end
commands.export = function() ns.Share.Export(ns.Store.SortedAll()) end
commands.next = function() ns.Run.Next() end
commands.back = function() ns.Run.Back() end
commands.skip = function() ns.Run.Skip() end
commands.reset = function()
  local state = ns.Run._state()
  local r = state.routeID and ns.Store.Get(state.routeID)
  if r then ns.Store.ResetProgress(r, time()); ns.Run.Refresh(); say("progress reset.") end
end
commands.help = help

local function toggle(key, label)
  return function()
    local s = ns.Store.Settings()
    s[key] = not s[key]
    say(label .. ": " .. onOff(s[key]))
    ns.Run.Refresh()
  end
end
commands.auto = toggle("autoOpen", "open by itself in dungeons")
commands.fade = toggle("fadeInCombat", "fade in combat")
commands.lock = toggle("locked", "window locked")

commands.probe = function()
  ns.Report.Start()
  ns.Probe.Here()
  ns.Report.Finish(RouteKeeperDB, "probe")
  ns.Report.Start(true)
  local found = ns.Probe.ArtDiscovery()
  ns.Report.Finish(RouteKeeperDB, "probeDetail")
  say(("map art found for %d of %d dungeons. Type /reload so the report is written to disk."):format(found, #ns.Dungeons.list))
end

SLASH_ROUTEKEEPER1 = "/rk"
SLASH_ROUTEKEEPER2 = "/routekeeper"
SlashCmdList.ROUTEKEEPER = ns.W.Guard(function(msg)
  local cmd = (msg or ""):match("^%s*(%S*)"):lower()
  local fn = commands[cmd]
  if fn then fn() else help() end
end)
