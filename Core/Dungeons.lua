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
