# RouteKeeper

Draw your own dungeon routes for WoW Forever: steps (entrance, bosses, quests, notes), the path between them and markers on the map. Share them as text, and follow them in a small window while you run the dungeon.

Made mainly for me and my friends. It's shared in case it's useful to others too, but expect it to follow our needs first.

## Using it

- `/rk edit` opens the editor on the dungeon you are in (or pick one with the dungeon button).
  - **New** starts a route. Tools: **Step** (click to add a step after the selected one), **Path** (click to add points to the selected step's path, click on the line to bend it, drag points, right-click to remove), **Draw** (freehand), **Marker** (raid icon + text; right-click removes), **Select** (click and drag).
  - On the right: the step list, and the selected step's kind, title, note, boss and quests. **Last kill** links a boss step to the boss you just killed, so it ticks itself when that boss dies. Quests can be picked from your log.
  - **Undo** (or Ctrl+Z) undoes the last change.
- `/rk` shows the route for the dungeon you are in. It opens by itself when you enter a dungeon that has a route (`/rk auto` turns that off).
  - Boss steps tick when the boss dies, quest steps when their quests are done; steps for quests you don't have are greyed out and passed.
  - **Next**, **Skip**, **Back** move by hand; right-click a pin on the map to set a step done / skipped / open.
  - The window fades in combat (`/rk fade`), `/rk lock` locks it in place, `-` hides the map.
  - A run starts over when you come back after 30 minutes or more, or with **Reset**.
- **Sharing:** **Export** gives a `!RK1!...` string to copy; **Import** (or `/rk import`) reads one. A newer revision of a route you have updates it; you're asked before anything is overwritten. **Export all** doubles as a backup.

Maps are the game's own dungeon maps. Dungeons without one in the game files (the new Forever dungeons) get a grid. Wailing Caverns uses the older map from before patch 4.1, which still shows the eastern caves Forever has (Blizzard's art, credited in `Media/Maps/README.md`). Bosses are pinned on the map where they stand.

## Development

- `luajit tests/run.lua` - unit tests for `Core/` (pure Lua, no game calls).
- `luajit tests/smoke_test.lua` - loads every file in the .toc against a stand-in for the game and drives the editor, sharing and Run view.
- Decisions are in `docs/adr/`.

Bundled: LibStub (public domain), LibDeflate (zlib license).
