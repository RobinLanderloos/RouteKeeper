-- Run progress through a Route (ADR 0004). The game gives no position in
-- dungeons, so progress comes from boss kills, quest state and the player's
-- own Next / Back / Skip. Pure: quest state comes in through `quests`:
--   quests.active(id)    on the quest now
--   quests.complete(id)  objectives done (ready to turn in)
--   quests.turnedIn(id)  turned in already
local addonName, ns = ...

local Progress = {}
ns.Progress = Progress

Progress.RESET_AFTER = 30 * 60 -- seconds away before a run starts over

function Progress.New(routeID, now)
  return { routeID = routeID, status = {}, at = now }
end

function Progress.Touch(progress, now) progress.at = now end

-- True when the saved progress is from an earlier run.
function Progress.IsStale(progress, now)
  return not progress.at or (now - progress.at) > Progress.RESET_AFTER
end

-- "done", "open" or "na" (does not apply to this character right now).
function Progress.TaskState(task, quests)
  local q = task.quest
  local turnedIn = quests.turnedIn(q)
  if task.act == "start" then
    if turnedIn or quests.active(q) then return "done" end
    return "open"
  end
  if turnedIn then return "done" end
  if not quests.active(q) then return "na" end
  if task.act == "objective" and quests.complete(q) then return "done" end
  return "open"
end

-- "done", "skipped", "open" or "na".
function Progress.StepState(route, progress, index, quests)
  local step = route.steps[index]
  local set = progress.status[step.id]
  if set == "done" or set == "skipped" or set == "open" then return set end
  if step.kind == "quest" then
    local relevant, open = 0, 0
    for _, t in ipairs(step.tasks or {}) do
      local s = Progress.TaskState(t, quests)
      if s ~= "na" then relevant = relevant + 1 end
      if s == "open" then open = open + 1 end
    end
    if relevant == 0 then return "na" end
    if open == 0 then return "done" end
  end
  return "open"
end

-- The first step still to do, or nil when the route is finished.
function Progress.Current(route, progress, quests)
  for i = 1, #route.steps do
    if Progress.StepState(route, progress, i, quests) == "open" then return i end
  end
end

function Progress.Next(route, progress, quests)
  local i = Progress.Current(route, progress, quests)
  if i then progress.status[route.steps[i].id] = "done" end
  return i
end

function Progress.Skip(route, progress, quests)
  local i = Progress.Current(route, progress, quests)
  if i then progress.status[route.steps[i].id] = "skipped" end
  return i
end

-- Reopens the last finished step before the current one.
function Progress.Back(route, progress, quests)
  local cur = Progress.Current(route, progress, quests) or (#route.steps + 1)
  for i = cur - 1, 1, -1 do
    local s = Progress.StepState(route, progress, i, quests)
    if s == "done" or s == "skipped" then
      progress.status[route.steps[i].id] = "open"
      return i
    end
  end
end

-- open -> done -> skipped -> open (right-click on a step).
function Progress.Cycle(route, progress, index, quests)
  local s = Progress.StepState(route, progress, index, quests)
  local nextState = (s == "open" or s == "na") and "done" or (s == "done" and "skipped" or "open")
  progress.status[route.steps[index].id] = nextState
  return nextState
end

local function norm(s) return type(s) == "string" and s:lower():gsub("^%s+", ""):gsub("%s+$", "") or "" end

-- A boss died: tick the first boss step for it that isn't done yet, even
-- when it is not the current one. Returns that step's index.
function Progress.OnEncounter(route, progress, encounterID, name)
  local wanted = norm(name)
  for i, step in ipairs(route.steps) do
    local b = step.boss
    if step.kind == "boss" and b and progress.status[step.id] ~= "done"
      and ((b.encounterID and b.encounterID == encounterID) or (wanted ~= "" and norm(b.name) == wanted)) then
      progress.status[step.id] = "done"
      return i
    end
  end
end

-- Done steps and steps that count (everything that applies).
function Progress.Counts(route, progress, quests)
  local done, total = 0, 0
  for i = 1, #route.steps do
    local s = Progress.StepState(route, progress, i, quests)
    if s ~= "na" then total = total + 1 end
    if s == "done" or s == "skipped" then done = done + 1 end
  end
  return done, total
end
