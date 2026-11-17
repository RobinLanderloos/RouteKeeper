-- Tests for Model, Serialize, Codec, Geometry, Undo and Progress.
local ns, test, eq = ...
local M, S, C, G, P = ns.Model, ns.Serialize, ns.Codec, ns.Geometry, ns.Progress

local seed = 0
local function rand(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n + 1 end

local function sample()
  local r = M.NewRoute(rand, { instanceID = 36, name = "The Deadmines" }, "Full clear", "Robin", 1763100000)
  local a = M.NewStep(rand, "entrance", 1, 0.1, 0.2); a.title = "Entrance"
  local b = M.NewStep(rand, "boss", 1, 0.4, 0.5); b.title = "Rhahk'Zor"; b.boss = { encounterID = 1081, name = "Rhahk'Zor" }
  b.path = { { 0.2, 0.3, 1 }, { 0.3, 0.4, 1 } }
  local c = M.NewStep(rand, "quest", 2, 0.6, 0.7); c.title = "Turn in"; c.note = "Talk to him | then go"
  c.tasks = { { quest = 166, act = "end", text = "" }, { quest = 214, act = "start", text = "Pick up" } }
  M.AddStep(r, a); M.AddStep(r, b); M.AddStep(r, c)
  r.markers[1] = M.NewMarker(rand, 1, 0.5, 0.5, 8); r.markers[1].text = "Patrol"
  return r
end

local function deepEq(a, b, path)
  path = path or "value"
  if type(a) ~= type(b) then error(path .. ": " .. type(a) .. " vs " .. type(b), 2) end
  if type(a) ~= "table" then
    if a ~= b then error(path .. ": " .. tostring(a) .. " vs " .. tostring(b), 2) end
    return
  end
  for k, v in pairs(a) do deepEq(v, b[k], path .. "." .. tostring(k)) end
  for k in pairs(b) do if a[k] == nil then error(path .. "." .. tostring(k) .. " only on one side", 2) end end
end

-- Serialize ---------------------------------------------------------------

test("serialize round-trips plain data", function()
  local v = { 1, "two", true, false, { x = 0.1234, y = -5 }, name = "a:b{c}s3:", [10] = "gap" }
  local back = S.Read(S.Write(v))
  deepEq(v, back)
end)

test("serialize is stable for the same data", function()
  eq(S.Write({ b = 1, a = 2, 3 }), S.Write({ 3, a = 2, b = 1 }))
end)

test("serialize refuses functions", function()
  eq(pcall(S.Write, { f = print }), false)
end)

test("read rejects broken or hostile text", function()
  for _, bad in ipairs({ "", "{", "s99:abc", "n1e999;", "nabc;", "x", "{n1;}", "TT", "s-1:", ("{"):rep(50) }) do
    local v = S.Read(bad)
    if v ~= nil then error("accepted " .. bad) end
  end
end)

-- Model -------------------------------------------------------------------

test("validate keeps a good route intact", function()
  local r = sample()
  local clean = assert(M.Validate(r))
  deepEq(clean, r)
end)

test("validate drops unknown fields", function()
  local r = sample(); r.evil = "x"; r.steps[1].code = "os.exit()"
  local clean = assert(M.Validate(r))
  eq(clean.evil, nil); eq(clean.steps[1].code, nil)
end)

test("validate rejects bad values", function()
  local cases = {
    function(r) r.steps[1].kind = "trash" end,
    function(r) r.steps[1].floor = 0 end,
    function(r) r.steps[1].floor = 1.5 end,
    function(r) r.steps[1].x = "0.5" end,
    function(r) r.steps[2].path[1] = { 0.1, 0.2, 99 } end,
    function(r) r.steps[3].tasks[1].act = "dance" end,
    function(r) r.steps[2].id = r.steps[1].id end,
    function(r) r.markers[1].icon = 9 end,
    function(r) r.id = "bad id!" end,
    function(r) r.dungeon = nil end,
    function(r) r.name = "" end,
  }
  for i, change in ipairs(cases) do
    local r = sample(); change(r)
    if M.Validate(r) then error("case " .. i .. " accepted") end
  end
end)

test("validate trims long text and clamps coordinates just outside the map", function()
  local r = sample()
  r.steps[1].note = ("x"):rep(5000)
  r.steps[1].x = 1.005
  local clean = assert(M.Validate(r))
  eq(#clean.steps[1].note, M.LIMITS.note); eq(clean.steps[1].x, 1)
end)

test("moving a step carries its path along", function()
  local r = sample()
  local id = r.steps[2].id
  eq(M.MoveStep(r, 2, 3), 3)
  eq(r.steps[3].id, id); eq(#r.steps[3].path, 2)
end)

test("full path runs from the previous step through the points to the step", function()
  local r = sample()
  local pts = M.FullPath(r, 2)
  eq(#pts, 4); eq(pts[1].x, 0.1); eq(pts[2].x, 0.2); eq(pts[4].x, 0.4)
  eq(#M.FullPath(r, 1), 1, "first step has no line")
end)

test("a step's name: its title, else boss, else first quest, else kind", function()
  local qn = function(id) return "Quest #" .. id end
  local kl = function(k) return "Kind " .. k end
  local s = { kind = "boss", title = "", boss = { name = "Rhahk'Zor" }, tasks = {} }
  eq(M.StepName(s, qn, kl), "Rhahk'Zor")
  s.title = "Big ogre"
  eq(M.StepName(s, qn, kl), "Big ogre")
  local q = { kind = "quest", title = "", tasks = { { quest = 166, act = "end" } } }
  eq(M.StepName(q, qn, kl), "Quest #166")
  q.tasks = {}
  eq(M.StepName(q, qn, kl), "Kind quest")
  eq(M.StepName({ kind = "entrance", title = "" }, qn, kl), "Kind entrance")
  eq(M.StepName({ kind = "boss", title = "", boss = { name = "" } }, qn, kl), "Kind boss")
end)

test("floors used by a route are listed once, sorted", function()
  local r = sample()
  local f = M.Floors(r)
  eq(#f, 2); eq(f[1], 1); eq(f[2], 2)
end)

-- Codec -------------------------------------------------------------------

test("export and import round-trip a route", function()
  local r = sample()
  local text = C.Export({ r })
  eq(text:sub(1, 5), "!RK1!")
  local routes = assert(C.Import(text))
  deepEq(routes[1], r)
end)

test("import survives the edit box doubling pipes and added line breaks", function()
  local r = sample()
  local text = C.Export({ r })
  local mangled = text:sub(1, 40) .. "\n  " .. text:sub(41):gsub("|", "||")
  local routes = assert(C.Import(mangled))
  eq(routes[1].steps[3].note, "Talk to him | then go")
end)

test("import explains what is wrong", function()
  local _, why = C.Import("hello")
  assert(why:find("not a RouteKeeper export"), why)
  _, why = C.Import("!RK2!abc")
  assert(why:find("newer RouteKeeper"), why)
  _, why = C.Import("!RK1!@@@@")
  assert(why:find("damaged"), why)
  local text = C.Export({ sample() })
  _, why = C.Import(text:sub(1, #text - 20))
  assert(why and why:find("damaged"), why)
end)

test("import rejects a route that fails the checks", function()
  local r = sample(); r.steps[1].kind = "trash"
  local _, why = C.Import(C.Export({ r }))
  assert(why:find("Route 1 is not valid"), why)
end)

test("export all carries several routes", function()
  local routes = assert(C.Import(C.Export({ sample(), sample() })))
  eq(#routes, 2)
end)

test("compare decides new, update or same", function()
  local r = sample()
  eq(C.Compare(r, {}), "new")
  local saved = { [r.id] = { rev = 1 } }
  eq(C.Compare(r, saved), "same")
  r.rev = 2
  eq(C.Compare(r, saved), "update")
end)

-- Geometry ----------------------------------------------------------------

test("simplify keeps corners and drops points on a straight line", function()
  local pts = {}
  for i = 0, 10 do pts[#pts + 1] = { i / 10, 0 } end
  for i = 1, 10 do pts[#pts + 1] = { 1, i / 10 } end
  local s = G.Simplify(pts, 0.001)
  eq(#s, 3); eq(s[2][1], 1); eq(s[2][2], 0)
end)

test("segment distance and nearest point", function()
  local d, t = G.SegmentDistance(0.5, 0.1, 0, 0, 1, 0)
  assert(math.abs(d - 0.1) < 1e-9); eq(t, 0.5)
  eq(G.NearestPoint({ { 0, 0 }, { 0.5, 0.5 } }, 0.49, 0.5, 0.02), 2)
  eq(G.NearestPoint({ { 0, 0 } }, 0.5, 0.5, 0.02), nil)
end)

-- Undo --------------------------------------------------------------------

test("undo gives back the route as it was", function()
  local u = ns.Undo.New()
  local r = sample()
  u:Push(r)
  r.steps[1].title = "changed"
  eq(u:Pop(r.id).steps[1].title, "Entrance")
  eq(u:Pop(r.id), nil)
end)

-- Progress ----------------------------------------------------------------

local function questsWith(active, complete, turnedIn)
  return {
    active = function(q) return active[q] == true end,
    complete = function(q) return complete[q] == true end,
    turnedIn = function(q) return turnedIn[q] == true end,
  }
end

test("progress starts at the first step and Next moves on", function()
  local r, q = sample(), questsWith({}, {}, {})
  local p = P.New(r.id, 0)
  eq(P.Current(r, p, q), 1)
  P.Next(r, p, q)
  eq(P.Current(r, p, q), 2)
end)

test("a boss kill ticks its step even out of order", function()
  local r, q = sample(), questsWith({}, {}, {})
  local p = P.New(r.id, 0)
  eq(P.OnEncounter(r, p, 1081, "whatever"), 2)
  eq(P.Current(r, p, q), 1, "current stays on the first open step")
  eq(P.StepState(r, p, 2, q), "done")
end)

test("a boss kill matches by name when no encounter id is linked", function()
  local r = sample(); r.steps[2].boss = { name = "Rhahk'Zor" }
  local p = P.New(r.id, 0)
  eq(P.OnEncounter(r, p, 999, " rhahk'zor "), 2)
  eq(P.OnEncounter(r, p, 999, "Someone else"), nil)
end)

test("a quest step with no quest for this character does not apply", function()
  local r = sample()
  local q = questsWith({}, {}, { [214] = false })
  -- task 1 (end 166) does not apply, task 2 (start 214) is open
  local p = P.New(r.id, 0)
  eq(P.StepState(r, p, 3, q), "open")
  r.steps[3].tasks[2] = nil
  eq(P.StepState(r, p, 3, q), "na")
end)

test("a quest step is done when its quests are", function()
  local r = sample()
  local p = P.New(r.id, 0)
  eq(P.StepState(r, p, 3, questsWith({ [166] = true, [214] = true }, {}, {})), "open")
  eq(P.StepState(r, p, 3, questsWith({ [214] = true }, {}, { [166] = true })), "done")
end)

test("objective tasks are done when the quest is ready to turn in", function()
  local t = { quest = 5, act = "objective" }
  eq(P.TaskState(t, questsWith({ [5] = true }, {}, {})), "open")
  eq(P.TaskState(t, questsWith({ [5] = true }, { [5] = true }, {})), "done")
  eq(P.TaskState(t, questsWith({}, {}, {})), "na")
end)

test("back reopens the previous step, skip passes one", function()
  local r, q = sample(), questsWith({}, {}, {})
  local p = P.New(r.id, 0)
  P.Next(r, p, q); P.Skip(r, p, q)
  eq(P.Current(r, p, q), 3)
  eq(P.Back(r, p, q), 2)
  eq(P.Current(r, p, q), 2)
  local done, total = P.Counts(r, p, q)
  eq(done, 1); eq(total, 3)
end)

test("cycling a step goes open, done, skipped, open", function()
  local r, q = sample(), questsWith({}, {}, {})
  local p = P.New(r.id, 0)
  eq(P.Cycle(r, p, 1, q), "done"); eq(P.Cycle(r, p, 1, q), "skipped"); eq(P.Cycle(r, p, 1, q), "open")
end)

test("progress older than 30 minutes is stale", function()
  local p = P.New("x", 1000)
  eq(P.IsStale(p, 1000 + 60), false)
  eq(P.IsStale(p, 1000 + 31 * 60), true)
end)

test("zul'farrak tiles come from file ids in the game's order", function()
  local zf = ns.Dungeons.Find("zf")
  eq(ns.Dungeons.Tile(zf, 1, 1), 449820); eq(ns.Dungeons.Tile(zf, 1, 2), 449824)
  eq(ns.Dungeons.Tile(zf, 1, 9), 449831); eq(ns.Dungeons.Tile(zf, 1, 10), 449821)
  eq(ns.Dungeons.Tile(zf, 1, 12), 449823); eq(ns.Dungeons.Tile(zf, 2, 1), nil)
  eq(ns.Dungeons.ByInstance(36).key, "dm")
end)

test("floor names come from the dungeon table, else Floor n", function()
  local sfk = ns.Dungeons.Find("sfk")
  eq(ns.Dungeons.FloorName(sfk, 6), "Arugal's Chamber")
  eq(ns.Dungeons.FloorName(sfk, 2), "Floor 2")
  eq(ns.Dungeons.FloorName(nil, 3), "Floor 3")
  eq(#sfk.floors, 3)
end)

-- MapView ---------------------------------------------------------------

local V = ns.MapView
local function near(a, b, what) if math.abs(a - b) > 1e-9 then error((what or "") .. ": " .. a .. " vs " .. b, 2) end end

test("the whole map is zoom 1 centred", function()
  local z, x, y = V.Clamp(0.5, 0.1, 0.9)
  eq(z, 1); eq(x, 0.5); eq(y, 0.5)
end)

test("the view never leaves the map", function()
  local z, x, y = V.Clamp(4, 0, 1)
  eq(z, 4); near(x, 0.125); near(y, 0.875)
end)

test("fit frames the points with room around them", function()
  local z, x, y = V.Fit({ { 0.4, 0.4 }, { x = 0.6, y = 0.5 } }, 0.1, 0.1)
  near(z, 1 / 0.4, "zoom")
  near(x, 0.5); near(y, 0.45)
end)

test("fit on one point does not zoom in all the way", function()
  local z = V.Fit({ { 0.5, 0.5 } }, 0.05, 0.2)
  near(z, 1 / 0.3)
end)

test("fit near an edge stays inside the map", function()
  local z, x = V.Fit({ { 0.01, 0.5 } }, 0.05, 0.2)
  near(x, 0.5 / z)
end)

test("zooming keeps the point under the cursor in place", function()
  local z, x, y = V.ZoomAt(2, 0.5, 0.5, 2, 0.6, 0.4)
  eq(z, 4)
  -- the cursor's map point is at the same screen spot before and after
  local before = (0.6 - 0.5) * 2
  local after = (0.6 - x) * 4
  near(before, after); near((0.4 - 0.5) * 2, (0.4 - y) * 4)
end)

test("offset puts the centre in the middle of the canvas", function()
  local ox, oy = V.Offset(2, 0.25, 0.25, 600, 400)
  near(ox, 0); near(oy, 0)
  ox, oy = V.Offset(1, 0.5, 0.5, 600, 400)
  near(ox, 0); near(oy, 0)
end)

test("boss names: dungeon list first, then extras without doubles", function()
  local rfc = ns.Dungeons.Find("rfc")
  local names, known = ns.Dungeons.BossNames(rfc, { "bazzalan", "Zelemar the Wrathful", "" })
  eq(known, 4); eq(#names, 5)
  eq(names[1], "Oggleflint"); eq(names[5], "Zelemar the Wrathful")
  local none, k0 = ns.Dungeons.BossNames({ name = "Blackmaw Hold" }, { "Some Boss" })
  eq(k0, 0); eq(none[1], "Some Boss")
  for _, d in ipairs(ns.Dungeons.list) do
    if not ns.Dungeons.bosses[d.key] then error("no bosses for " .. d.key) end
  end
end)

test("boss spots: known bosses have a floor and a spot on the map", function()
  local wc = ns.Dungeons.Find("wc")
  local s = ns.Dungeons.BossSpot(wc, "lord cobrahn")
  eq(s.floor, 1); eq(s.x, 0.1561); eq(s.y, 0.5851)
  eq(ns.Dungeons.BossSpot(wc, "Somebody"), nil)
  eq(ns.Dungeons.BossSpot({ name = "Blackmaw Hold" }, "Lord Cobrahn"), nil)
  eq(ns.Dungeons.BossSpot(ns.Dungeons.Find("dm"), "Edwin VanCleef").floor, 2)
  eq(ns.Dungeons.BossSpot(ns.Dungeons.Find("sfk"), "Archmage Arugal").floor, 6)
  for key, spots in pairs(ns.Dungeons.bossSpots) do
    local listed = {}
    for _, n in ipairs(ns.Dungeons.bosses[key]) do listed[n] = true end
    for name, p in pairs(spots) do
      if not listed[name] then error(key .. ": " .. name .. " is not in the boss list") end
      if p[2] < 0 or p[2] > 1 or p[3] < 0 or p[3] > 1 then error(key .. ": " .. name .. " is off the map") end
    end
  end
end)
