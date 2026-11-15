# A new addon instead of extending Dungeon Sweeper

Dungeon Sweeper (v0.4.0, depends on ForeverDungeonJournal) already shows dungeon routes with notes and auto-advancing steps, but its routes are hand-written Lua in `Routes.lua`: there is no in-game editor and no way to share routes. RouteKeeper exists for exactly those two things (an in-game route editor and import/export), so it is built as its own addon around them rather than as a fork or contribution.
