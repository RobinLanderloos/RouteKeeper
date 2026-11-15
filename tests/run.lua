-- Unit tests for the pure Core files, outside the game.
--   luajit tests/run.lua
local ADDON = "RouteKeeper"
local ns = {}
dofile("Libs/LibStub/LibStub.lua")
dofile("Libs/LibDeflate/LibDeflate.lua")
for _, file in ipairs({ "Core/MapTiles.lua", "Core/Dungeons.lua", "Core/Serialize.lua", "Core/Model.lua",
  "Core/Codec.lua", "Core/Geometry.lua", "Core/Undo.lua", "Core/Progress.lua", "Core/MapView.lua" }) do
  assert(loadfile(file))(ADDON, ns)
end

local passed, failed = 0, 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL  " .. name .. "\n      " .. tostring(err))
  end
end

local function eq(actual, expected, what)
  if actual ~= expected then
    error((what or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

assert(loadfile("tests/core_test.lua"))(ns, test, eq)

local L = ns.MapTiles.Layout

test("a 1002x668 layer of 256 tiles is 4 columns by 3 rows", function()
  local cols, rows, _, tiles = L({ layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 }, 1002, 668)
  eq(cols, 4, "cols"); eq(rows, 3, "rows"); eq(#tiles, 12, "tiles")
end)

test("tiles are numbered row by row, left to right", function()
  local _, _, _, tiles = L({ layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 }, 1002, 668)
  eq(tiles[2].index, 2); eq(tiles[2].x, 256); eq(tiles[2].y, 0)
  eq(tiles[5].index, 5); eq(tiles[5].x, 0); eq(tiles[5].y, 256)
end)

test("scale fits the layer inside the area, keeping its shape", function()
  local _, _, scale = L({ layerWidth = 1000, layerHeight = 500, tileWidth = 250, tileHeight = 250 }, 500, 500)
  eq(scale, 0.5, "width limits")
  local _, _, scale2 = L({ layerWidth = 1000, layerHeight = 500, tileWidth = 250, tileHeight = 250 }, 1000, 100)
  eq(scale2, 0.2, "height limits")
end)

test("tile sizes are scaled", function()
  local _, _, _, tiles = L({ layerWidth = 1000, layerHeight = 500, tileWidth = 250, tileHeight = 250 }, 500, 500)
  eq(tiles[1].width, 125); eq(tiles[4].x, 375)
end)

test("missing or zero sizes give nothing", function()
  eq(L({ layerWidth = 0, layerHeight = 10, tileWidth = 5, tileHeight = 5 }, 10, 10), nil)
  eq(L({}, 10, 10), nil)
end)

local D = ns.Dungeons

test("tile paths use the game's folder layout", function()
  eq(D.TilePath("TheDeadmines", 2, 12), "Interface\\WorldMap\\TheDeadmines\\TheDeadmines2_12")
end)

test("dungeons are found by key, name or folder, ignoring case and punctuation", function()
  eq(D.Find("dm").folder, "TheDeadmines")
  eq(D.Find("The Deadmines").key, "dm")
  eq(D.Find("zul'farrak").key, "zf")
  eq(D.Find("SHADOWFANGKEEP").key, "sfk")
  eq(D.Find("nope"), nil)
  eq(D.Find(""), nil)
end)

test("discover finds floors with gaps and counts their tiles", function()
  local have = {}
  for _, f in ipairs({ 1, 6, 7 }) do
    for t = 1, 12 do have[D.TilePath("ShadowfangKeep", f, t)] = true end
  end
  local floors = D.Discover("ShadowfangKeep", function(p) return have[p] end)
  eq(#floors, 3, "floors")
  eq(floors[2].floor, 6); eq(floors[3].floor, 7); eq(floors[1].tiles, 12)
end)

test("discover finds nothing for a dungeon without art", function()
  eq(#D.Discover("Nowhere", function() return false end), 0)
end)

test("the classic layer is 4 by 3 tiles", function()
  local cols, rows = ns.MapTiles.Layout(D.LAYER, 1002, 668)
  eq(cols, 4); eq(rows, 3)
end)

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
