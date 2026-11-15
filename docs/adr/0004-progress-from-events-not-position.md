# Run progress is inferred from events, not player position

The game does not report the player's position inside dungeons, so the Run view cannot track location. Boss Steps complete on `ENCOUNTER_END` (success), with a match on the boss's name as a fallback (for steps not linked to an encounter); quest Steps complete when their tasks are done (accept, objectives, turn-in events); entrance and note Steps advance on Next. Manual Next/Back/Skip always overrides, out-of-order kills tick their Step, Steps that don't apply to the character are greyed and skipped, and progress is stored per character.

Verified in-game on 2026-11-15: `ENCOUNTER_START`/`ENCOUNTER_END` fire with encounterID, boss name and success, including in Forever-only dungeons (Ruins of Lordaeron). Since the Encounter Journal is empty, a boss Step stores the encounterID learned from these events (or the boss name typed by the author).

Progress cannot reset "on a new instance ID": `GetInstanceInfo()`'s instance ID is the dungeon's map ID and is the same on every run. A run starts over instead when its progress has not been touched for 30 minutes (the Run view keeps it fresh while open), or with Reset.
