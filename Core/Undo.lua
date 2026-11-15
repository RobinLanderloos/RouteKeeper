-- Undo for the editor: a copy of the route before each change.
local addonName, ns = ...

local Undo = {}
ns.Undo = Undo
Undo.__index = Undo

local LIMIT = 50

function Undo.New()
  return setmetatable({ stack = {} }, Undo)
end

function Undo:Push(route)
  local s = self.stack
  s[#s + 1] = { id = route.id, copy = ns.Model.Copy(route) }
  if #s > LIMIT then table.remove(s, 1) end
end

-- Returns the saved copy for this route, or nil when there is none.
function Undo:Pop(routeID)
  local s = self.stack
  for i = #s, 1, -1 do
    if s[i].id == routeID then return table.remove(s, i).copy end
  end
end

function Undo:Clear() self.stack = {} end
