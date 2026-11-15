-- Export strings (ADR 0005): "!RK1!" + print-safe(deflate(serialize(payload))).
-- payload = { v = 1, routes = { route, ... } }. Import checks every route
-- with Model.Validate and never runs code.
local addonName, ns = ...

local Codec = {}
ns.Codec = Codec

Codec.PREFIX = "!RK1!"
Codec.MAX_LENGTH = 2000000

local function lib()
  return ns.LibDeflate or (LibStub and LibStub("LibDeflate", true))
end

function Codec.Export(routes)
  local L = lib()
  local payload = { v = 1, routes = {} }
  for i, r in ipairs(routes) do payload.routes[i] = r end
  local text = ns.Serialize.Write(payload)
  return Codec.PREFIX .. L:EncodeForPrint(L:CompressDeflate(text, { level = 9 }))
end

-- Returns a list of clean routes, or nil and a reason a person can read.
function Codec.Import(text)
  if type(text) ~= "string" then return nil, "Nothing to import." end
  -- Edit boxes double "|" and pasting adds spaces or line breaks.
  text = text:gsub("||", "|"):gsub("%s", "")
  if text == "" then return nil, "Nothing to import." end
  if #text > Codec.MAX_LENGTH then return nil, "That text is too long to be a route." end
  if text:sub(1, #Codec.PREFIX) ~= Codec.PREFIX then
    if text:match("^!RK%d+!") then return nil, "This route needs a newer RouteKeeper." end
    return nil, "This is not a RouteKeeper export (it should start with " .. Codec.PREFIX .. ")."
  end
  local L = lib()
  local packed = L:DecodeForPrint(text:sub(#Codec.PREFIX + 1))
  if not packed then return nil, "The text is damaged (was it copied completely?)." end
  local raw = L:DecompressDeflate(packed)
  if not raw then return nil, "The text is damaged (was it copied completely?)." end
  local payload, err = ns.Serialize.Read(raw)
  if type(payload) ~= "table" then return nil, "The text is damaged: " .. tostring(err) end
  if payload.v ~= 1 then return nil, "This route needs a newer RouteKeeper." end
  if type(payload.routes) ~= "table" or #payload.routes == 0 then return nil, "The text holds no routes." end
  local routes = {}
  for i, r in ipairs(payload.routes) do
    local clean, why = ns.Model.Validate(r)
    if not clean then return nil, ("Route %d is not valid (%s)."):format(i, why) end
    routes[i] = clean
  end
  return routes
end

-- What to do with an imported route given the routes already saved:
--   "new"    - no route with this id yet
--   "update" - ours is an older revision
--   "same"   - same or newer revision already saved (ask before overwriting)
function Codec.Compare(incoming, saved)
  local mine = saved[incoming.id]
  if not mine then return "new" end
  if incoming.rev > (mine.rev or 0) then return "update" end
  return "same"
end
