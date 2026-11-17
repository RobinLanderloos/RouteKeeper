-- Load check: runs every file the .toc lists, in order, against a small
-- stand-in for the game, then drives the editor, sharing and the Run view.
-- It does not prove the real client behaves the same.
--   luajit tests/smoke_test.lua
local ADDON = "RouteKeeper"

local files = {}
for line in io.lines(ADDON .. ".toc") do
  line = line:gsub("%s+$", "")
  if line ~= "" and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
end

-- Widgets: remember scripts, events, text, textures, size and shown state.
-- Unknown capitalised methods do nothing; unset lowercase fields are nil.
local widgets = {}
local function newWidget(parent)
  local w = { shown = true, scripts = {}, events = {}, parentWidget = parent }
  widgets[#widgets + 1] = w
  return setmetatable(w, { __index = function(self, key)
    if key == "SetScript" then return function(s, name, fn) s.scripts[name] = fn end end
    if key == "GetScript" then return function(s, name) return s.scripts[name] end end
    if key == "RegisterEvent" or key == "RegisterUnitEvent" then return function(s, name) s.events[name] = true end end
    if key == "UnregisterEvent" then return function(s, name) s.events[name] = nil end end
    if key == "SetText" then return function(s, text) rawset(s, "text", text) end end
    if key == "GetText" then return function(s) return rawget(s, "text") end end
    if key == "SetTexture" then return function(s, tex) rawset(s, "texture", tex); return true end end
    if key == "IsShown" then return function(s) return s.shown end end
    if key == "Show" then return function(s) s.shown = true; if s.scripts.OnShow then s.scripts.OnShow(s) end end end
    if key == "Hide" then return function(s) s.shown = false end end
    if key == "SetShown" then return function(s, v) if v then s:Show() else s:Hide() end end end
    if key == "SetEnabled" then return function(s, v) rawset(s, "disabled", not v) end end
    if key == "SetSize" then return function(s, w2, h) rawset(s, "width", w2); rawset(s, "height", h) end end
    if key == "SetWidth" then return function(s, w2) rawset(s, "width", w2) end end
    if key == "SetHeight" then return function(s, h) rawset(s, "height", h) end end
    if key == "GetWidth" then return function(s) return rawget(s, "width") or 0 end end
    if key == "GetHeight" then return function(s) return rawget(s, "height") or 0 end end
    if key == "GetLeft" then return function() return 0 end end
    if key == "GetTop" then return function(s) return rawget(s, "height") or 0 end end
    if key == "GetEffectiveScale" then return function() return 1 end end
    if key == "GetStringHeight" then return function() return 14 end end
    if key == "GetFrameLevel" then return function() return 1 end end
    if key == "HasFocus" then return function() return false end end
    if key == "SetAlpha" then return function(s, a) rawset(s, "alpha", a) end end
    if type(key) == "string" and key:match("^Create") then
      return function(s, name) local c = newWidget(s); if type(name) == "string" then rawset(c, "name", name) end; return c end
    end
    if type(key) == "string" and key:match("^%u") then return function() end end
    return nil
  end })
end

local function fire(event, ...)
  for _, w in ipairs(widgets) do
    if w.events[event] and w.scripts.OnEvent then w.scripts.OnEvent(w, event, ...) end
  end
end

local function visible(w)
  while w do
    if not rawget(w, "shown") then return false end
    w = rawget(w, "parentWidget")
  end
  return true
end

local function shownTexts()
  local texts = {}
  for _, w in ipairs(widgets) do
    local text = rawget(w, "text")
    if visible(w) and type(text) == "string" then texts[#texts + 1] = text end
  end
  return table.concat(texts, "\n")
end

local timers = {}
local function runTimers()
  local guard = 0
  while #timers > 0 and guard < 1000 do
    table.remove(timers, 1)()
    guard = guard + 1
  end
end

-- Game stand-in ------------------------------------------------------------

local cursor = { 375, 250 }
local mouseDown = false
local inCombat = false
local instance = { "The Deadmines", "party", 1, "Normal", 5, 0, false, 36 }
local inInstance = true
local quests = { active = {}, complete = {}, turnedIn = {} }

_G.CreateFrame = function(_, name, parent)
  local w = newWidget(parent)
  rawset(w, "name", name)
  if name then _G[name] = w end
  return w
end
_G.UIParent = newWidget()
_G.GameTooltip = newWidget()
_G.UISpecialFrames = {}
_G.tinsert = table.insert
_G.unpack = unpack
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
_G.InCombatLockdown = function() return inCombat end
_G.SlashCmdList = {}
_G.GetBuildInfo = function() return "1.60.1", "70938", "Nov 1 2026", 16001 end
local clock = 1763100000
_G.time = function() return clock end
_G.date = function() return "2026-11-15 12:00" end
_G.GetCursorPosition = function() return cursor[1], cursor[2] end
_G.IsMouseButtonDown = function() return mouseDown end
_G.IsControlKeyDown = function() return false end
_G.UnitName = function() return "Ragmuul" end
_G.IsInInstance = function() return inInstance, inInstance and "party" or "none" end
_G.GetInstanceInfo = function() if inInstance then return unpack(instance) end return "Kalimdor", "none", 0, "", 0, 0, false, 1 end
_G.GetFileIDFromPath = function(path)
  local sf, st = path:match("ShadowfangKeep\\ShadowfangKeep(%d+)_(%d+)$")
  if sf and tonumber(sf) <= 7 and tonumber(st) <= 12 then return 448000 + sf * 100 + st end
  local floor, tile = path:match("TheDeadmines\\TheDeadmines(%d+)_(%d+)$")
  floor, tile = tonumber(floor), tonumber(tile)
  if floor and floor <= 2 and tile <= 12 then return 449000 + floor * 100 + tile end
end
_G.C_QuestLog = {
  IsOnQuest = function(id) return quests.active[id] == true end,
  IsComplete = function(id) return quests.complete[id] == true end,
  IsQuestFlaggedCompleted = function(id) return quests.turnedIn[id] == true end,
  GetTitleForQuestID = function(id) if id == 166 then return "The Defias Brotherhood" end end,
  RequestLoadQuestByID = function() end,
  GetNumQuestLogEntries = function() return 2 end,
  GetInfo = function(i)
    if i == 1 then return { title = "Westfall", isHeader = true } end
    return { title = "The Defias Brotherhood", questID = 166 }
  end,
}
_G.RouteKeeperDB = nil

-- Load the addon like the client does.
local ns = {}
for _, file in ipairs(files) do
  local chunk, err = loadfile(file)
  if not chunk then error("the .toc lists a file that does not load: " .. tostring(err)) end
  chunk(ADDON, ns)
end
fire("ADDON_LOADED", ADDON)
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")

local failed = 0
local function check(name, condition, detail)
  if not condition then
    failed = failed + 1
    print("FAIL  " .. name .. (detail and ("\n      " .. tostring(detail)) or ""))
  end
end

local said = {}
local realPrint = print
local function slash(message)
  said = {}
  _G.print = function(text) said[#said + 1] = tostring(text) end
  local ok, err = pcall(SlashCmdList.ROUTEKEEPER, message)
  _G.print = realPrint
  return ok, ok and table.concat(said, "\n") or tostring(err)
end

local function click(button, which)
  assert(button and button.scripts.OnClick, "not a button")
  button.scripts.OnClick(button, which or "LeftButton")
end

local function typeIn(box, text)
  box:SetText(text)
  if box.scripts.OnEditFocusGained then box.scripts.OnEditFocusGained(box) end
  box.scripts.OnTextChanged(box, true)
end

-- Click the map at a 0..1 position (and release at once).
local function mapClick(canvas, x, y, which)
  cursor = { x * canvas.cw, canvas.ch - y * canvas.ch }
  mouseDown = true
  canvas.frame.scripts.OnMouseDown(canvas.frame, which or "LeftButton")
  mouseDown = false
  local upd = canvas.driver.scripts.OnUpdate
  if upd then upd(canvas.driver) end
end

local function pickRow(text)
  for _, w in ipairs(widgets) do
    local t = rawget(w, "text")
    if t and visible(w) and rawget(w, "parentWidget") == _G.RouteKeeperPickList and type(t.GetText) == "function" and (t:GetText() or ""):find(text, 1, true) and w.scripts.OnClick then return w end
  end
end

-- Checks -------------------------------------------------------------------

local ok, out = slash("help")
check("/rk help lists the commands", ok and out:find("/rk edit", 1, true) ~= nil, out)

ok, out = slash("")
check("/rk without routes says how to make one", ok and out:find("no route to show", 1, true) ~= nil, out)

ok, out = slash("edit")
check("/rk edit opens", ok, out)
local st, canvas, ui = ns.Editor._state()
check("editor starts on the dungeon you are in", st.dungeon and st.dungeon.instanceID == 36, st.dungeon and st.dungeon.name)
check("editor offers to make a route", shownTexts():find("Click New", 1, true) ~= nil)

click(ui.new)
local r = st.route
check("New makes a route for this dungeon", r and r.dungeon.instanceID == 36 and r.author == "Ragmuul")
check("New switches to the Step tool", st.tool == "step")

mapClick(canvas, 0.1, 0.1)
mapClick(canvas, 0.4, 0.5)
mapClick(canvas, 0.8, 0.8)
check("three clicks place three steps", #r.steps == 3, #r.steps)
check("the first step is the entrance", r.steps[1].kind == "entrance")
check("steps sit where clicked", math.abs(r.steps[2].x - 0.4) < 0.001 and math.abs(r.steps[2].y - 0.5) < 0.001,
  r.steps[2].x .. "," .. r.steps[2].y)
check("map tiles drawn from game paths", (function()
  for _, w in ipairs(widgets) do
    if rawget(w, "texture") == "Interface\\WorldMap\\TheDeadmines\\TheDeadmines1_1" then return true end
  end
end)())

-- the dungeon button opens a list to pick from
click(ui.dungeon)
local rfcRow = pickRow("Ragefire Chasm")
check("dungeon list shows the dungeons", rfcRow ~= nil)
local hereRow = pickRow("you are here")
check("dungeon list marks where you are", hereRow ~= nil and hereRow.text:GetText():find("The Deadmines", 1, true) ~= nil)
if rfcRow then click(rfcRow) end
check("picking a dungeon switches to it", st.dungeon.instanceID == 389, st.dungeon.name)
click(ui.dungeon)
click(pickRow("The Deadmines"))
check("and back", st.dungeon.instanceID == 36 and st.route == r)

-- Shadowfang Keep: only the three floors the vanilla keep uses, in order
local sfk = ns.MapCanvas.FloorList(33)
check("shadowfang keep offers floors 1, 7, 6", #sfk == 3 and sfk[1] == 1 and sfk[2] == 7 and sfk[3] == 6,
  table.concat(sfk, ","))
check("floors have names", ns.MapCanvas.FloorName(33, 7) == "The Wall Walk" and ns.MapCanvas.FloorName(36, 2) == "Ironclad Cove"
  and ns.MapCanvas.FloorName(389, 1) == "Floor 1")


-- select step 2 in the list, make it a boss linked to a kill
click(ui.rows[2])
check("list click selects", st.selected == 2)
check("list click zooms in on the way to the step", canvas.zoom > 1.5, canvas.zoom)
check("the selected step is the editor map's focus", canvas.focus == st.selected, tostring(canvas.focus))
check("the view is centred between step 1 and step 2 (kept inside the map)", math.abs(canvas.cx - 0.25) < 0.02 and math.abs(canvas.cy - 0.3) < 0.01,
  canvas.cx .. "," .. canvas.cy)
local zoomed = canvas.zoom
canvas.frame.scripts.OnMouseWheel(canvas.frame, -1)
check("mouse wheel zooms out", canvas.zoom < zoomed, canvas.zoom)
click(canvas.fitButton)
check("Fit shows the whole floor", canvas.zoom == 1 and canvas.cx == 0.5)
local kindClicks = 0
while ui.kind:GetValue() ~= "boss" and kindClicks < 5 do click(ui.kind); kindClicks = kindClicks + 1 end
check("kind becomes boss", r.steps[2].kind == "boss")
fire("ENCOUNTER_END", 1081, "Rhahk'Zor", 1, 5, 1)
check("a kill is remembered", ns.lastKill and ns.lastKill.id == 1081)
click(ui.lastKill)
check("Last kill links the boss", r.steps[2].boss and r.steps[2].boss.encounterID == 1081 and r.steps[2].title == "Rhahk'Zor")
click(ui.bossList)
local bossRow = pickRow("Rhahk'Zor")
check("boss list shows the dungeon's bosses", bossRow ~= nil and pickRow("Edwin VanCleef") ~= nil)
if bossRow then click(bossRow) end
check("picking the same boss keeps the kill link", r.steps[2].boss.name == "Rhahk'Zor" and r.steps[2].boss.encounterID == 1081)
click(ui.bossList)
bossRow = pickRow("Gilnid")
if bossRow then click(bossRow) end
check("picking another boss names it, unlinked", r.steps[2].boss.name == "Gilnid" and r.steps[2].boss.encounterID == nil,
  tostring(r.steps[2].boss.name))
local gs = ns.Dungeons.BossSpot(ns.Dungeons.Find("dm"), "Gilnid")
check("picking a boss moves the pin to where the boss stands", gs ~= nil and r.steps[2].x == gs.x and r.steps[2].y == gs.y
  and r.steps[2].floor == gs.floor, tostring(r.steps[2].x) .. "," .. tostring(r.steps[2].y))
check("the name box shows the picked boss", ui.bossName:GetText() == "Gilnid", ui.bossName:GetText())
check("the title follows the picked boss", r.steps[2].title == "Gilnid" and ui.title:GetText() == "Gilnid", tostring(r.steps[2].title))
typeIn(ui.bossName, "Mr. Smite")
check("the title follows a typed boss", r.steps[2].title == "Mr. Smite", tostring(r.steps[2].title))
typeIn(ui.title, "Kill the ogre first")
typeIn(ui.bossName, "Gilnid")
check("a title of your own is kept", r.steps[2].title == "Kill the ogre first", tostring(r.steps[2].title))
typeIn(ui.title, "Rhahk'Zor")
click(ui.lastKill)
check("Last kill links again", r.steps[2].boss.encounterID == 1081)

typeIn(ui.note.edit, "Pull him | to the door")
check("note typed", r.steps[2].note == "Pull him | to the door", r.steps[2].note)

-- path tool: click adds a point, bending the line
click(ui.tools[3])
check("path tool selected", st.tool == "path")
mapClick(canvas, 0.3, 0.2)
check("path click adds a point", #r.steps[2].path == 1 and r.steps[2].path[1][3] == 1)
mapClick(canvas, 0.35, 0.35) -- near the segment from point to step: inserted
check("second path point", #r.steps[2].path == 2)

-- quest task on step 3
click(ui.rows[3])
click(ui.fromLog)
local pickerRow = pickRow("The Defias Brotherhood |cff888888(166)")
check("quest picker lists the log without headers", pickerRow ~= nil)
if pickerRow then click(pickerRow) end
check("picker fills the quest id", ui.questID:GetText() == "166", ui.questID:GetText())
while ui.act:GetValue() ~= "end" do click(ui.act) end
click(ui.addTask)
check("task added", #r.steps[3].tasks == 1 and r.steps[3].tasks[1].act == "end" and r.steps[3].tasks[1].quest == 166)
local kc = 0
while ui.kind:GetValue() ~= "quest" and kc < 5 do click(ui.kind); kc = kc + 1 end
check("task shows the quest name", shownTexts():find("The Defias Brotherhood", 1, true) ~= nil)
check("a quest step without a title is listed by its quest", ui.rows[3].text:GetText():find("Quest|r  The Defias Brotherhood", 1, true) ~= nil,
  ui.rows[3].text:GetText())
click(ui.rows[1])
check("an entrance step is listed as Entrance", ui.rows[1].text:GetText():find("1. |cffffd100Entrance|r  |cff888888(The Deadmines)", 1, true) ~= nil,
  ui.rows[1].text:GetText())
click(ui.rows[2])
typeIn(ui.title, "")
typeIn(ui.bossName, "Rhahk'Zor")
check("a boss step without a title is listed by the boss, live while typing", ui.rows[2].text:GetText():find("Boss|r  Rhahk'Zor", 1, true) ~= nil,
  ui.rows[2].text:GetText())
click(ui.lastKill)

-- marker
click(ui.tools[5])
mapClick(canvas, 0.6, 0.3)
check("marker placed", #r.markers == 1 and r.markers[1].icon == 8)
typeIn(ui.markerText, "Patrol here")
check("marker text", r.markers[1].text == "Patrol here")

-- undo
click(ui.removeMarker)
check("marker removed", #r.markers == 0)
click(ui.undo)
check("undo brings it back", #st.route.markers == 1, #st.route.markers)

-- the route passes the import checks
check("edited route is valid", ns.Model.Validate(r) ~= nil, select(2, ns.Model.Validate(r)))

-- export
local revBefore = r.rev
click(ui.export)
local shareFrame, box, status, buttons = ns.Share._ui()
local exported = box:GetText()
check("export gives a string", type(exported) == "string" and exported:sub(1, 5) == "!RK1!", exported)
check("an edited route gets the next revision on export", r.rev == revBefore + 1, r.rev)

-- import into an empty collection
local id = r.id
ns.Store.Delete(id)
ns.Share.Import()
box:SetText(exported)
click(buttons[1]) -- Read
check("import shows what it read", status:GetText():find("3 steps", 1, true) ~= nil, status:GetText())
click(buttons[1]) -- Save
check("import saves the route", ns.Store.Get(id) ~= nil and #ns.Store.Get(id).steps == 3)

-- importing the same again asks before overwriting
ns.Share.Import()
box:SetText(exported)
click(buttons[1])
check("same revision asks", status:GetText():find("same or newer", 1, true) ~= nil, status:GetText())
click(buttons[2]) -- Save as copy
check("save as copy makes a second route", #ns.Store.RoutesFor(36) == 2)

ns.Share.Import()
box:SetText("not a route")
click(buttons[1])
check("garbage gets a clear message", status:GetText():find("not a RouteKeeper export", 1, true) ~= nil, status:GetText())
shareFrame:Hide()

-- Run view
r = ns.Store.Get(id)
ns.Store.SetLastRoute(36, id)
ok, out = slash("")
check("/rk opens the run view", ok and ns.Run.IsShown(), out)
check("run view shows step 1", shownTexts():find("1. Entrance", 1, true) ~= nil, shownTexts())
local _, _, runCanvas = ns.Run._state()
check("run map zooms in on the first step", runCanvas.zoom > 1, runCanvas.zoom)
slash("next")
check("next moves to the boss", shownTexts():find("2. Rhahk'Zor", 1, true) ~= nil, shownTexts())
check("the run map puts the current step in focus", runCanvas.focus == 2, tostring(runCanvas.focus))
check("note shown, pipe kept", shownTexts():find("Pull him || to the door", 1, true) ~= nil)
fire("ENCOUNTER_END", 1081, "Rhahk'Zor", 1, 5, 1)
check("boss kill ticks the step", shownTexts():find("3. ", 1, true) ~= nil, shownTexts())
local runState, runFrame = ns.Run._state()
-- quest step: not on the quest -> does not apply -> route finished
check("quest step without the quest does not apply", shownTexts():find("Route finished", 1, true) ~= nil, shownTexts())
quests.active[166] = true
fire("QUEST_ACCEPTED", 166)
runTimers()
check("quest step applies once on the quest", shownTexts():find("3. The Defias Brotherhood", 1, true) ~= nil, shownTexts())
quests.active[166] = nil; quests.turnedIn[166] = true
fire("QUEST_TURNED_IN", 166)
runTimers()
check("turning in finishes the route", shownTexts():find("Route finished", 1, true) ~= nil)
check("counter counts what applies", runFrame.count:GetText() == "3/3", runFrame.count:GetText())
slash("back")
check("back reopens the last step", shownTexts():find("3. ", 1, true) ~= nil)

-- combat
ns.Editor.Open(r)
fire("PLAYER_REGEN_DISABLED")
check("editor closes in combat", not ns.Editor.IsShown())
check("run view fades in combat", rawget(runFrame, "alpha") and rawget(runFrame, "alpha") < 1)
fire("PLAYER_REGEN_ENABLED")
check("run view back to full", rawget(runFrame, "alpha") == 1)

-- auto-open
ns.Run.Hide()
inInstance = false
fire("PLAYER_ENTERING_WORLD")
inInstance = true
fire("PLAYER_ENTERING_WORLD")
check("entering a dungeon with a route opens the run view", ns.Run.IsShown())
inInstance = false
fire("PLAYER_ENTERING_WORLD")
check("leaving closes what opened by itself", not ns.Run.IsShown())

-- progress resets after 30 minutes away
inInstance = true
clock = clock + 31 * 60
fire("PLAYER_ENTERING_WORLD")
check("a new run starts at step 1", shownTexts():find("1. Entrance", 1, true) ~= nil)

-- a dungeon without art gets a grid
instance = { "Ruins of Lordaeron", "party", 1, "Normal", 5, 0, false, 2999 }
ns.Run.Hide()
ok, out = slash("edit")
check("editor on a Forever-only dungeon", ns.Editor._state().dungeon.instanceID == 2999, ns.Editor._state().dungeon.name)
check("no-art dungeon shows the grid notice", shownTexts():find("No map for this floor", 1, true) ~= nil)

ok, out = slash("probe")
check("/rk probe still works", ok and RouteKeeperDB.probe ~= nil, out)

-- errors are caught and kept for the developer, not lost
_G.debugstack = function() return "stack" end
said = {}
_G.print = function(text) said[#said + 1] = tostring(text) end
local failing = ns.W.Guard(function() error("boom") end)
failing(); failing()
_G.print = realPrint
check("an error is saved", RouteKeeperDB.errors and #RouteKeeperDB.errors == 2 and RouteKeeperDB.errors[1]:find("boom", 1, true) ~= nil)
check("an error is mentioned once in chat", #said == 1 and said[1]:find("boom", 1, true) ~= nil, table.concat(said, " / "))

-- saved routes survive a reload through the checks
local saved = RouteKeeperDB
RouteKeeperDB = saved
check("store reloads cleanly", ns.Store.Load() == 0)

io.write(failed == 0 and "load check passed\n" or (failed .. " load checks failed\n"))
os.exit(failed == 0 and 0 or 1)
