-- A small, safe serializer for plain data (tables, strings, numbers,
-- booleans). Deserializing parses text only; it never runs code (ADR 0005).
--   number  n<text>;     string  s<length>:<bytes>
--   true T   false F     table   { key value key value ... }
local addonName, ns = ...

local Serialize = {}
ns.Serialize = Serialize

local format, concat, floor = string.format, table.concat, math.floor

local function numberText(v)
  if v == floor(v) and v > -1e15 and v < 1e15 then return format("%d", v) end
  return format("%.6g", v)
end

local function write(v, out, depth)
  if depth > 20 then error("data nested too deeply") end
  local t = type(v)
  if t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then error("not a finite number") end
    out[#out + 1] = "n" .. numberText(v) .. ";"
  elseif t == "string" then
    out[#out + 1] = "s" .. #v .. ":" .. v
  elseif t == "boolean" then
    out[#out + 1] = v and "T" or "F"
  elseif t == "table" then
    out[#out + 1] = "{"
    -- Array part first, in order, then the other keys sorted, so the same
    -- data always gives the same text.
    local n = #v
    for i = 1, n do
      write(i, out, depth + 1)
      write(v[i], out, depth + 1)
    end
    local keys = {}
    for k in pairs(v) do
      if not (type(k) == "number" and k >= 1 and k <= n and k == floor(k)) then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b)
      if type(a) == type(b) then return a < b end
      return type(a) == "number"
    end)
    for _, k in ipairs(keys) do
      local kt = type(k)
      if kt ~= "string" and kt ~= "number" then error("unsupported key type " .. kt) end
      write(k, out, depth + 1)
      write(v[k], out, depth + 1)
    end
    out[#out + 1] = "}"
  else
    error("unsupported type " .. t)
  end
end

function Serialize.Write(value)
  local out = {}
  write(value, out, 0)
  return concat(out)
end

-- Returns value, or nil and a reason. Limits guard against huge input.
function Serialize.Read(text, maxItems)
  if type(text) ~= "string" then return nil, "not text" end
  maxItems = maxItems or 200000
  local pos, items, len = 1, 0, #text
  local read

  read = function(depth)
    if depth > 20 then error("nested too deeply", 0) end
    items = items + 1
    if items > maxItems then error("too much data", 0) end
    local c = text:sub(pos, pos)
    if c == "n" then
      local stop = text:find(";", pos + 1, true)
      if not stop or stop - pos > 40 then error("bad number", 0) end
      local v = tonumber(text:sub(pos + 1, stop - 1))
      if not v or v ~= v or v == math.huge or v == -math.huge then error("bad number", 0) end
      pos = stop + 1
      return v
    elseif c == "s" then
      local colon = text:find(":", pos + 1, true)
      if not colon or colon - pos > 10 then error("bad string", 0) end
      local n = tonumber(text:sub(pos + 1, colon - 1))
      if not n or n < 0 or n ~= floor(n) or colon + n > len then error("bad string", 0) end
      local v = text:sub(colon + 1, colon + n)
      pos = colon + n + 1
      return v
    elseif c == "T" then pos = pos + 1; return true
    elseif c == "F" then pos = pos + 1; return false
    elseif c == "{" then
      pos = pos + 1
      local t = {}
      while true do
        if pos > len then error("unfinished table", 0) end
        if text:sub(pos, pos) == "}" then pos = pos + 1; return t end
        local k = read(depth + 1)
        if type(k) ~= "string" and type(k) ~= "number" then error("bad key", 0) end
        if pos > len then error("unfinished table", 0) end
        t[k] = read(depth + 1)
      end
    end
    error("unexpected data at " .. pos, 0)
  end

  local ok, value = pcall(read, 0)
  if not ok then return nil, value end
  if pos <= len then return nil, "extra data at the end" end
  return value
end
