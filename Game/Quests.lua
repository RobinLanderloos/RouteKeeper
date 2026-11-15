-- Quest state and names from the game. Names are always fetched by ID,
-- never stored, so they show in the player's own language (ADR 0005).
local addonName, ns = ...

local Quests = {}
ns.Quests = Quests

local function call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a = pcall(fn, ...)
  if ok then return a end
end

local QL = C_QuestLog or {}

-- The `quests` table Core/Progress.lua expects.
Quests.state = {
  active = function(id)
    if QL.IsOnQuest then return call(QL.IsOnQuest, id) == true end
    return call(QL.GetLogIndexForQuestID, id) ~= nil
  end,
  complete = function(id) return call(QL.IsComplete, id) == true end,
  turnedIn = function(id) return call(QL.IsQuestFlaggedCompleted, id) == true end,
}

local requested = {}

-- Quest title, or "Quest <id>" until the game has loaded it (then
-- QUEST_DATA_LOAD_RESULT fires and the views redraw).
function Quests.Name(id)
  local title = call(QL.GetTitleForQuestID, id)
  if type(title) == "string" and title ~= "" then return title end
  if not requested[id] and QL.RequestLoadQuestByID then
    requested[id] = true
    call(QL.RequestLoadQuestByID, id)
  end
  return "Quest " .. id
end

-- Quests in the log: { { id, title }, ... }, headers left out.
function Quests.Log()
  local list = {}
  local n = call(QL.GetNumQuestLogEntries) or 0
  for i = 1, n do
    local info = call(QL.GetInfo, i)
    if type(info) == "table" and not info.isHeader and info.questID and info.questID > 0 then
      list[#list + 1] = { id = info.questID, title = info.title or Quests.Name(info.questID) }
    end
  end
  return list
end
