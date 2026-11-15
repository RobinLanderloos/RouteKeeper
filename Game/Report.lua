-- Diagnostic reports the developer can read without the player copying chat.
-- Everything said through ns.Report is printed (unless quiet) AND stored in
-- RouteKeeperDB.report; after /reload it is in
--   WTF\Account\<account>\SavedVariables\RouteKeeper.lua
local addonName, ns = ...

local Report = {}
ns.Report = Report

local lines, quiet

function Report.Start(isQuiet)
  quiet = isQuiet
  local _, build, _, interface = GetBuildInfo()
  lines = { ("build %s, interface %s, %s"):format(tostring(build), tostring(interface),
    date and date("%Y-%m-%d %H:%M") or "") }
end

function Report.Say(text)
  text = tostring(text)
  if not quiet then print("|cff40ff40RouteKeeper:|r " .. text) end
  if lines then lines[#lines + 1] = text end
end

function Report.Finish(db, key)
  db[key or "report"] = lines
  lines = nil
end
