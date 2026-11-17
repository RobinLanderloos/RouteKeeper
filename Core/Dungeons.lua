-- Dungeons whose map art is in the game files, under
--   Interface\WorldMap\<folder>\<folder><floor>_<tile>
-- The client's map registry (C_Map) has no dungeon maps on Forever, so the
-- art is found by path (ADR 0002). Floors are discovered in-game: they are
-- not always 1, 2, 3. instanceID is GetInstanceInfo()'s 8th return.
-- Dungeons not listed here (Forever-only ones) get a blank grid.
local addonName, ns = ...

local Dungeons = {}
ns.Dungeons = Dungeons

-- floors: the art floors this dungeon uses, in order (default: all found).
-- floorNames: [floor] = name, from the game's own map data.
-- fileBase: for art whose folder name is unknown, the file ID of tile 1 of
-- floor 1 (tiles are numbered in the order _1, _10, _11, _12, _2 ... _9).
Dungeons.list = {
  { key = "rfc", name = "Ragefire Chasm", folder = "Ragefire", instanceID = 389 },
  { key = "wc", name = "Wailing Caverns", folder = "WailingCaverns", instanceID = 43 },
  { key = "dm", name = "The Deadmines", folder = "TheDeadmines", instanceID = 36,
    floorNames = { "The Deadmines", "Ironclad Cove" } },
  { key = "sfk", name = "Shadowfang Keep", folder = "ShadowfangKeep", instanceID = 33,
    -- The game files hold the Cataclysm keep's seven maps; the vanilla
    -- layout uses three of them, in walking order.
    floors = { 1, 7, 6 },
    floorNames = { [1] = "The Courtyard", [7] = "The Wall Walk", [6] = "Arugal's Chamber" } },
  { key = "bfd", name = "Blackfathom Deeps", folder = "BlackFathomDeeps", instanceID = 48,
    floorNames = { "The Pool of Ask'Ar", "Moonshrine Sanctum", "The Forgotten Pool" } },
  { key = "stocks", name = "The Stockade", folder = "TheStockade", instanceID = 34 },
  { key = "gnomer", name = "Gnomeregan", folder = "Gnomeregan", instanceID = 90,
    floorNames = { "The Hall of Gears", "The Dormitory", "Launch Bay", "Tinkers' Court" } },
  { key = "rfk", name = "Razorfen Kraul", folder = "RazorfenKraul", instanceID = 47 },
  { key = "sm", name = "Scarlet Monastery", folder = "ScarletMonastery", instanceID = 189,
    floorNames = { "Graveyard", "Library", "Armory", "Cathedral" } },
  { key = "rfd", name = "Razorfen Downs", folder = "RazorfenDowns", instanceID = 129 },
  { key = "ulda", name = "Uldaman", folder = "Uldaman", instanceID = 70,
    floorNames = { "Hall of the Keepers", "Khaz'Goroth's Seat" } },
  { key = "zf", name = "Zul'Farrak", fileBase = 449820, instanceID = 209 },
  { key = "mara", name = "Maraudon", folder = "Maraudon", instanceID = 349,
    floorNames = { "Caverns of Maraudon", "Zaetar's Grave" } },
  { key = "st", name = "Sunken Temple", folder = "TheTempleOfAtalHakkar", instanceID = 109 },
  { key = "brd", name = "Blackrock Depths", folder = "BlackrockDepths", instanceID = 230,
    floorNames = { "Detention Block", "Shadowforge City" } },
  { key = "brs", name = "Blackrock Spire", folder = "BlackrockSpire", instanceID = 229,
    floorNames = { "Tazz'Alor (Lower)", "Skitterweb Tunnels (Lower)", "Hordemar City (Lower)", "Hall of Blackhand (Lower)", "Halycon's Lair (Lower)", "Chamber of Battle (Lower)", "Upper Blackrock Spire" } },
  { key = "dire", name = "Dire Maul", folder = "DireMaul", instanceID = 429,
    floorNames = { "Gordok Commons (North)", "Capital Gardens (West)", "Court of the Highborne (West)", "Prison of Immol'Thar (West)", "Warpwood Quarter (East)", "The Shrine of Eldretharr (East)" } },
  { key = "scholo", name = "Scholomance", folder = "ScholomanceOLD", instanceID = 289,
    floorNames = { "The Reliquary", "Chamber of Summoning", "The Upper Study", "Headmaster's Study" } },
  { key = "strat", name = "Stratholme", folder = "Stratholme", instanceID = 329,
    floorNames = { "Crusader's Square (Main Gate)", "The Gauntlet (Service Entrance)" } },
}

-- Bosses per dungeon, in the usual walking order, named as the game's
-- encounter events name them, so a step picked from this list ticks itself
-- when the boss dies. Rares and extras are typed by hand.
Dungeons.bosses = {
  rfc = { "Oggleflint", "Taragaman the Hungerer", "Jergosh the Invoker", "Bazzalan" },
  wc = { "Lady Anacondra", "Lord Cobrahn", "Kresh", "Lord Pythas", "Skum", "Lord Serpentis",
    "Verdan the Everliving", "Mutanus the Devourer" },
  dm = { "Rhahk'Zor", "Sneed's Shredder", "Gilnid", "Mr. Smite", "Captain Greenskin",
    "Edwin VanCleef", "Cookie" },
  sfk = { "Rethilgore", "Razorclaw the Butcher", "Baron Silverlaine", "Commander Springvale",
    "Odo the Blindwatcher", "Fenrus the Devourer", "Wolf Master Nandos", "Archmage Arugal" },
  bfd = { "Ghamoo-ra", "Lady Sarevess", "Gelihast", "Lorgus Jett", "Baron Aquanis",
    "Twilight Lord Kelris", "Old Serra'kis", "Aku'mai" },
  stocks = { "Targorr the Dread", "Kam Deepfury", "Hamhock", "Bazil Thredd", "Dextren Ward",
    "Bruegal Ironknuckle" },
  gnomer = { "Grubbis", "Viscous Fallout", "Electrocutioner 6000", "Crowd Pummeler 9-60",
    "Dark Iron Ambassador", "Mekgineer Thermaplugg" },
  rfk = { "Roogug", "Aggem Thorncurse", "Death Speaker Jargba", "Overlord Ramtusk",
    "Agathelos the Raging", "Charlga Razorflank" },
  sm = { "Interrogator Vishas", "Bloodmage Thalnos", "Houndmaster Loksey", "Arcanist Doan",
    "Herod", "High Inquisitor Fairbanks", "Scarlet Commander Mograine", "High Inquisitor Whitemane" },
  rfd = { "Tuten'kash", "Mordresh Fire Eye", "Glutton", "Amnennar the Coldbringer" },
  ulda = { "Revelosh", "The Lost Dwarves", "Ironaya", "Obsidian Sentinel", "Ancient Stone Keeper",
    "Galgann Firehammer", "Grimlok", "Archaedas" },
  zf = { "Antu'sul", "Theka the Martyr", "Witch Doctor Zum'rah", "Nekrum Gutchewer",
    "Shadowpriest Sezz'ziz", "Sergeant Bly", "Hydromancer Velratha", "Ruuzlu", "Gahz'rilla",
    "Chief Ukorz Sandscalp" },
  mara = { "Noxxion", "Razorlash", "Lord Vyletongue", "Celebras the Cursed", "Landslide",
    "Tinkerer Gizlock", "Rotgrip", "Princess Theradras" },
  st = { "Atal'alarion", "Dreamscythe", "Weaver", "Jammal'an the Prophet", "Ogom the Wretched",
    "Morphaz", "Hazzas", "Shade of Eranikus", "Avatar of Hakkar" },
  brd = { "Lord Roccor", "High Interrogator Gerstahn", "Ring of Law", "Houndmaster Grebmar",
    "Pyromancer Loregrain", "Lord Incendius", "Warder Stilgiss", "Fineous Darkvire", "Bael'Gar",
    "General Angerforge", "Golem Lord Argelmach", "Hurley Blackbreath", "Phalanx",
    "Ribbly Screwspigot", "Plugger Spazzring", "Ambassador Flamelash", "The Seven", "Magmus",
    "Emperor Dagran Thaurissan" },
  brs = { "Highlord Omokk", "Shadow Hunter Vosh'gajin", "War Master Voone", "Mother Smolderweb",
    "Urok Doomhowl", "Quartermaster Zigris", "Halycon", "Gizrul the Slavener", "Overlord Wyrmthalak",
    "Pyroguard Emberseer", "Solakar Flamewreath", "Warchief Rend Blackhand", "The Beast",
    "General Drakkisath" },
  dire = { "Guard Mol'dar", "Stomper Kreeg", "Guard Fengus", "Guard Slip'kik", "Captain Kromcrush",
    "King Gordok", "Tendris Warpwood", "Illyanna Ravenoak", "Magister Kalendris", "Immol'thar",
    "Prince Tortheldrin", "Pusillin", "Zevrim Thornhoof", "Hydrospawn", "Lethtendris",
    "Alzzin the Wildshaper" },
  scholo = { "Kirtonos the Herald", "Jandice Barov", "Rattlegore", "Marduk Blackpool", "Vectus",
    "Ras Frostwhisper", "Instructor Malicia", "Doctor Theolen Krastinov", "Lorekeeper Polkelt",
    "The Ravenian", "Lord Alexei Barov", "Lady Illucia Barov", "Darkmaster Gandling" },
  strat = { "Hearthsinger Forresten", "The Unforgiven", "Timmy the Cruel", "Cannon Master Willey",
    "Archivist Galford", "Balnazzar", "Magistrate Barthilas", "Baroness Anastari", "Nerub'enkan",
    "Maleki the Pallid", "Ramstein the Gorger", "Baron Rivendare" },
}

-- Map tiles shipped with this addon, used in place of the game's:
-- [dungeon][floor] = path prefix of the 12 tiles.
-- The game's Wailing Caverns art is the patch 4.1 one, with the eastern maze
-- cut out; Forever has the whole cave. Media/Maps/WailingCaverns holds the
-- pre-4.1 tiles (Blizzard's art, see Media/Maps/README.md), same frame as the
-- game's, so positions on the map don't change.
Dungeons.ownArt = {
  wc = { [1] = "Interface\\AddOns\\RouteKeeper\\Media\\Maps\\WailingCaverns\\WailingCaverns1_" },
}

-- Where bosses stand: [boss] = { floor, x, y } on the map art. From the
-- creature spawns in AzerothCore's world database (WC, unchanged since
-- vanilla), turned into map positions with the game's own UiMapAssignment
-- data. Only bosses whose floor is certain are listed; the game data cannot
-- tell the floor of a spot under several floors, so those are left out.
Dungeons.bossSpots = {
  rfc = {
    ["Oggleflint"] = { 1, 0.5605, 0.3800 },
    ["Taragaman the Hungerer"] = { 1, 0.4098, 0.5773 },
    ["Jergosh the Invoker"] = { 1, 0.3298, 0.8454 },
    ["Bazzalan"] = { 1, 0.4153, 0.8618 },
  },
  wc = {
    ["Lady Anacondra"] = { 1, 0.2812, 0.3185 },
    ["Lord Cobrahn"] = { 1, 0.1561, 0.5851 },
    ["Kresh"] = { 1, 0.2578, 0.4462 },
    -- Pythas and Skum stand in the east caves: drawn on our own (pre-4.1)
    -- tiles, missing from the game's patch 4.1 art.
    ["Lord Pythas"] = { 1, 0.8560, 0.2841 },
    ["Skum"] = { 1, 0.9327, 0.8005 },
    ["Lord Serpentis"] = { 1, 0.6248, 0.5355 },
    ["Verdan the Everliving"] = { 1, 0.5641, 0.4742 },
  },
  dm = {
    ["Rhahk'Zor"] = { 1, 0.3770, 0.6122 },
    ["Sneed's Shredder"] = { 1, 0.4929, 0.8711 },
    ["Gilnid"] = { 1, 0.6028, 0.5705 },
    ["Mr. Smite"] = { 2, 0.5607, 0.2649 },
    ["Captain Greenskin"] = { 2, 0.6064, 0.3754 },
    ["Edwin VanCleef"] = { 2, 0.6060, 0.4588 },
    ["Cookie"] = { 2, 0.6738, 0.3993 },
  },
  sfk = {
    ["Archmage Arugal"] = { 6, 0.6390, 0.2003 },
  },
  bfd = {
    ["Lady Sarevess"] = { 1, 0.1008, 0.3601 },
    ["Aku'mai"] = { 2, 0.8559, 0.8665 },
  },
  stocks = {
    ["Targorr the Dread"] = { 1, 0.4987, 0.2422 },
    ["Kam Deepfury"] = { 1, 0.6920, 0.3094 },
    ["Hamhock"] = { 1, 0.7817, 0.4566 },
    ["Bazil Thredd"] = { 1, 0.8641, 0.5200 },
    ["Dextren Ward"] = { 1, 0.1455, 0.2136 },
    ["Bruegal Ironknuckle"] = { 1, 0.3811, 0.2403 },
  },
  rfk = {
    ["Roogug"] = { 1, 0.6482, 0.4209 },
    ["Aggem Thorncurse"] = { 1, 0.8084, 0.5445 },
    ["Death Speaker Jargba"] = { 1, 0.8795, 0.4139 },
    ["Overlord Ramtusk"] = { 1, 0.5688, 0.2984 },
    ["Agathelos the Raging"] = { 1, 0.1120, 0.7236 },
    ["Charlga Razorflank"] = { 1, 0.2643, 0.3243 },
  },
  sm = {
    ["Interrogator Vishas"] = { 1, 0.7154, 0.5894 },
    ["Bloodmage Thalnos"] = { 1, 0.2440, 0.5077 },
    ["Houndmaster Loksey"] = { 2, 0.3079, 0.8780 },
    ["Arcanist Doan"] = { 2, 0.8321, 0.7451 },
    ["Herod"] = { 3, 0.7865, 0.1077 },
    ["High Inquisitor Fairbanks"] = { 4, 0.5541, 0.2611 },
    ["Scarlet Commander Mograine"] = { 4, 0.4914, 0.2718 },
    ["High Inquisitor Whitemane"] = { 4, 0.4904, 0.1688 },
  },
  rfd = {
    ["Mordresh Fire Eye"] = { 1, 0.8582, 0.4568 },
    ["Glutton"] = { 1, 0.3852, 0.4524 },
    ["Amnennar the Coldbringer"] = { 1, 0.4499, 0.5906 },
  },
  ulda = {
    ["Revelosh"] = { 1, 0.5415, 0.7216 },
    ["The Lost Dwarves"] = { 1, 0.5907, 0.9354 },
    ["Ironaya"] = { 1, 0.3754, 0.7385 },
    ["Obsidian Sentinel"] = { 1, 0.2877, 0.6178 },
  },
  zf = {
    ["Antu'sul"] = { 1, 0.6901, 0.2560 },
    ["Theka the Martyr"] = { 1, 0.5532, 0.2970 },
    ["Witch Doctor Zum'rah"] = { 1, 0.4402, 0.1516 },
    ["Sergeant Bly"] = { 1, 0.2355, 0.1833 },
    ["Hydromancer Velratha"] = { 1, 0.2995, 0.3834 },
    ["Ruuzlu"] = { 1, 0.4408, 0.3487 },
    ["Chief Ukorz Sandscalp"] = { 1, 0.4393, 0.3517 },
  },
  mara = {
    ["Noxxion"] = { 1, 0.3475, 0.1071 },
    ["Razorlash"] = { 1, 0.1617, 0.3402 },
    ["Landslide"] = { 2, 0.4056, 0.4824 },
    ["Tinkerer Gizlock"] = { 2, 0.4840, 0.6856 },
    ["Rotgrip"] = { 2, 0.3326, 0.7706 },
    ["Princess Theradras"] = { 2, 0.2416, 0.7836 },
  },
  st = {
    ["Atal'alarion"] = { 1, 0.4981, 0.4861 },
    ["Dreamscythe"] = { 1, 0.4397, 0.4279 },
    ["Weaver"] = { 1, 0.4533, 0.4396 },
    ["Jammal'an the Prophet"] = { 1, 0.7609, 0.3685 },
    ["Ogom the Wretched"] = { 1, 0.7716, 0.3680 },
    ["Morphaz"] = { 1, 0.4887, 0.8901 },
    ["Hazzas"] = { 1, 0.5208, 0.8896 },
    ["Shade of Eranikus"] = { 1, 0.6885, 0.8702 },
  },
  brd = {
    ["High Interrogator Gerstahn"] = { 1, 0.4752, 0.9340 },
    ["The Seven"] = { 2, 0.5670, 0.2178 },
    ["Magmus"] = { 2, 0.8173, 0.1187 },
    ["Emperor Dagran Thaurissan"] = { 2, 0.9316, 0.1193 },
  },
  dire = {
    ["Stomper Kreeg"] = { 2, 0.6197, 0.6574 },
    ["Guard Fengus"] = { 2, 0.4935, 0.8155 },
    ["Guard Slip'kik"] = { 2, 0.2775, 0.5878 },
    ["Captain Kromcrush"] = { 2, 0.3183, 0.4970 },
    ["King Gordok"] = { 2, 0.3190, 0.2611 },
    ["Immol'thar"] = { 5, 0.3501, 0.5762 },
    ["Alzzin the Wildshaper"] = { 7, 0.5536, 0.2695 },
  },
  scholo = {
    ["Ras Frostwhisper"] = { 4, 0.4061, 0.8836 },
  },
  strat = {
    ["Cannon Master Willey"] = { 1, 0.0359, 0.5014 },
    ["Archivist Galford"] = { 1, 0.2713, 0.7513 },
    ["Balnazzar"] = { 1, 0.1879, 0.8366 },
    ["Magistrate Barthilas"] = { 2, 0.6534, 0.7550 },
    ["Baroness Anastari"] = { 2, 0.7495, 0.4685 },
    ["Nerub'enkan"] = { 2, 0.5637, 0.4690 },
    ["Maleki the Pallid"] = { 2, 0.6819, 0.1993 },
    ["Baron Rivendare"] = { 2, 0.3722, 0.1993 },
  },
}

-- Where a boss stands: { floor, x, y } from Dungeons.bossSpots, or nil.
function Dungeons.BossSpot(dungeon, name)
  local spots = dungeon and Dungeons.bossSpots and Dungeons.bossSpots[dungeon.key or ""]
  if not spots or type(name) ~= "string" then return nil end
  local want = name:lower()
  for boss, s in pairs(spots) do
    if boss:lower() == want then return { floor = s[1], x = s[2], y = s[3] } end
  end
end

-- The boss names to offer for a dungeon: its own list, then any other names
-- given in `extra` (bosses typed or learned in your routes), without doubles.
function Dungeons.BossNames(dungeon, extra)
  local names, seen = {}, {}
  local function add(name)
    if type(name) == "string" and name ~= "" and not seen[name:lower()] then
      seen[name:lower()] = true
      names[#names + 1] = name
    end
  end
  for _, name in ipairs(dungeon and Dungeons.bosses[dungeon.key or ""] or {}) do add(name) end
  local known = #names
  for _, name in ipairs(extra or {}) do add(name) end
  return names, known
end

local function norm(s) return (s:lower():gsub("[^%w]", "")) end

function Dungeons.Find(text)
  if type(text) ~= "string" or text == "" then return nil end
  local want = norm(text)
  if want == "" then return nil end
  for _, d in ipairs(Dungeons.list) do
    if d.key == want or norm(d.name) == want or (d.folder and d.folder:lower() == want) then
      return d
    end
  end
end

function Dungeons.ByInstance(instanceID)
  for _, d in ipairs(Dungeons.list) do
    if d.instanceID == instanceID then return d end
  end
end

-- A floor's name from the game's map data, or "Floor <n>".
function Dungeons.FloorName(dungeon, floor)
  local name = dungeon and dungeon.floorNames and dungeon.floorNames[floor]
  return name or ("Floor " .. floor)
end

-- Path of one tile, without the extension. Backslashes as the game wants.
function Dungeons.TilePath(folder, floor, tile)
  return "Interface\\WorldMap\\" .. folder .. "\\" .. folder .. floor .. "_" .. tile
end

-- Texture (path or file ID) for a tile of a dungeon's floor.
function Dungeons.Tile(dungeon, floor, tile)
  local own = Dungeons.ownArt[dungeon.key or ""]
  if own and own[floor] then return own[floor] .. tile end
  if dungeon.folder then return Dungeons.TilePath(dungeon.folder, floor, tile) end
  if dungeon.fileBase and floor == 1 then
    if tile == 1 then return dungeon.fileBase end
    if tile <= 9 then return dungeon.fileBase + tile + 2 end
    return dungeon.fileBase + tile - 9
  end
end

-- Classic dungeon maps are 1002x668 drawn from 256x256 tiles (4 x 3 = 12).
Dungeons.LAYER = { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 }

-- exists(path) -> bool. Returns the floor numbers that have a first tile,
-- and for each the number of consecutive tiles found.
function Dungeons.Discover(folder, exists, maxFloor, maxTile)
  local floors = {}
  for floor = 1, maxFloor or 12 do
    if exists(Dungeons.TilePath(folder, floor, 1)) then
      local tiles = 1
      while tiles < (maxTile or 20) and exists(Dungeons.TilePath(folder, floor, tiles + 1)) do
        tiles = tiles + 1
      end
      floors[#floors + 1] = { floor = floor, tiles = tiles }
    end
  end
  return floors
end
