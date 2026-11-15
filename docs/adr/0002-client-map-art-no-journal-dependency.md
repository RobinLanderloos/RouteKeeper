# Maps come from the client's own dungeon map art; no ForeverDungeonJournal dependency

Maps are shown from the game client's built-in dungeon maps (by uiMapID and floor via `C_Map`), so RouteKeeper ships no image files and depends on no other addon. Dungeons without a client map (Forever-only ones such as Blackmaw Hold) get a blank grid canvas; community cartography is added only with the cartographer's permission.

## Considered Options

- Require ForeverDungeonJournal (as Dungeon Sweeper does): free maps and pins, but its namespace and map art change between versions (Sunken Temple went from five floors to one in 2.0.49), which would silently break drawn route coordinates.
- Copy community maps: "publicly visible" is not a redistribution licence.

## Consequences

Probed in-game on 2026-11-15 (build 70938): `C_Map` knows only 60 maps (all zones, no dungeons), `GetBestMapForUnit("player")` is nil inside a dungeon, and the Encounter Journal has 0 tiers. The classic dungeon tiles do exist in the game files under `Interface\WorldMap\<Folder>\<Folder><floor>_<tile>` (`GetFileIDFromPath` returns real file IDs, `SetTexture` loads them), so maps are drawn from those paths, with floors discovered per dungeon. Boss Steps therefore cannot use the Encounter Journal and are linked by name or learned from a kill.

Not every map in the game files fits the vanilla layout: Shadowfang Keep has the Cataclysm keep's seven maps, of which the vanilla keep uses three (1 The Courtyard, 7 The Wall Walk, 6 Arugal's Chamber, in that order, as ForeverDungeonJournal also concluded). A dungeon can therefore list the floors it uses (`floors` in `Core/Dungeons.lua`); floor names come from the game's own map data.
