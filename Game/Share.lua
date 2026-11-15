-- Export and import strings (ADR 0005): copy a route out, paste one in.
local addonName, ns = ...

local Share = {}
ns.Share = Share

local W = ns.W
local frame, box, status, buttons = nil, nil, nil, {}
local pending -- routes read from the pasted text, waiting for a choice

local function say(text) print("|cff40ff40RouteKeeper:|r " .. text) end

local function setButtons(list)
  for _, b in ipairs(buttons) do b:Hide() end
  local x = -12
  for i = #list, 1, -1 do
    local spec = list[i]
    local b = buttons[i]
    if not b then
      b = W.Button(frame, "", 120, 22)
      buttons[i] = b
    end
    b:SetText(spec[1])
    b:SetWidth(math.max(80, #spec[1] * 7 + 20))
    b:SetScript("OnClick", spec[2])
    b:ClearAllPoints()
    b:SetPoint("BOTTOMRIGHT", x, 12)
    x = x - b:GetWidth() - 4
    b:Show()
  end
end

local function build()
  frame = W.Window("RouteKeeperShare", 560, 380, "RouteKeeper")
  frame:SetFrameStrata("DIALOG")
  tinsert(UISpecialFrames, "RouteKeeperShare")
  frame.help = W.Label(frame, "", "GameFontHighlight")
  frame.help:SetPoint("TOPLEFT", 14, -30)
  frame.help:SetPoint("RIGHT", -14, 0)
  local holder = W.MultiEdit(frame, 532, 220)
  holder:SetPoint("TOPLEFT", 14, -52)
  box = holder.edit
  box:SetMaxLetters(0)
  status = W.Label(frame, "", "GameFontHighlightSmall")
  status:SetPoint("TOPLEFT", 14, -280)
  status:SetPoint("RIGHT", -14, 0)
  status:SetHeight(48)
  status:SetJustifyV("TOP")
  status:SetWordWrap(true)
end

local function describe(r)
  local by = (r.author and r.author ~= "") and (" by " .. W.Escape(r.author)) or ""
  return ("|cffffd100%s|r (%s)%s, %d steps, revision %d"):format(W.Escape(r.name), W.Escape(r.dungeon.name), by, #r.steps, r.rev)
end

local function finished(text)
  pending = nil
  status:SetText(text)
  setButtons({ { "Close", function() frame:Hide() end } })
  if ns.Editor.IsShown() then ns.Editor.Refresh() end
  ns.Run.Refresh()
end

local function save(r, how)
  if how == "copy" then
    return ns.Store.SaveCopy(r, " (imported)")
  end
  ns.Store.Put(r)
  ns.Store.DB().dirty[r.id] = nil
  if ns.Editor.IsShown() then ns.Editor.RouteChanged(r.id) end
  return r
end

local function readPasted()
  local routes, why = ns.Codec.Import(box:GetText())
  if not routes then
    status:SetText("|cffff6060" .. why .. "|r")
    return
  end
  pending = routes
  local saved = ns.Store.All()
  if #routes == 1 then
    local r = routes[1]
    local how = ns.Codec.Compare(r, saved)
    local text = describe(r)
    if how == "new" then
      status:SetText(text)
      setButtons({
        { "Save", function() save(r, "new"); finished("Saved " .. describe(r) .. ".") end },
        { "Cancel", function() frame:Hide() end },
      })
    elseif how == "update" then
      status:SetText(text .. "\nYou have revision " .. saved[r.id].rev .. " of this route. Update it?")
      setButtons({
        { "Update my copy", function() save(r, "replace"); finished("Updated to " .. describe(r) .. ".") end },
        { "Save as copy", function() save(r, "copy"); finished("Saved as a copy.") end },
        { "Cancel", function() frame:Hide() end },
      })
    else
      status:SetText(text .. "\n|cffff9040You already have revision " .. saved[r.id].rev ..
        " of this route (same or newer). Overwriting loses your version.|r")
      setButtons({
        { "Overwrite", function() save(r, "replace"); finished("Overwritten with " .. describe(r) .. ".") end },
        { "Save as copy", function() save(r, "copy"); finished("Saved as a copy.") end },
        { "Cancel", function() frame:Hide() end },
      })
    end
    return
  end
  -- Several routes ("Export all"): new and newer ones are saved, the rest
  -- kept as they are unless saved as copies.
  local counts = { new = 0, update = 0, same = 0 }
  for _, r in ipairs(routes) do
    local how = ns.Codec.Compare(r, saved)
    counts[how] = counts[how] + 1
  end
  status:SetText(("%d routes: %d new, %d newer than yours, %d you already have (same or newer)."):format(
    #routes, counts.new, counts.update, counts.same))
  setButtons({
    { "Import new and newer", function()
      local n = 0
      for _, r in ipairs(routes) do
        local how = ns.Codec.Compare(r, ns.Store.All())
        if how ~= "same" then save(r, "replace"); n = n + 1 end
      end
      finished(("Imported %d routes, kept %d of yours."):format(n, #routes - n))
    end },
    { "All as copies", function()
      for _, r in ipairs(routes) do save(r, "copy") end
      finished(("Saved %d routes as copies."):format(#routes))
    end },
    { "Cancel", function() frame:Hide() end },
  })
end

function Share.Export(routes)
  if #routes == 0 then say("no routes to export.") return end
  if not frame then build() end
  for _, r in ipairs(routes) do ns.Store.BumpIfEdited(r) end
  local text = ns.Codec.Export(routes)
  frame.title:SetText(#routes == 1 and ("Export: " .. W.Escape(routes[1].name)) or ("Export all: " .. #routes .. " routes"))
  frame.help:SetText("Press Ctrl+C to copy, then paste it wherever you share routes.")
  status:SetText(#routes == 1 and describe(routes[1]) or (#routes .. " routes, also handy as a backup."))
  box:SetText(text)
  setButtons({ { "Close", function() frame:Hide() end } })
  frame:Show()
  box:SetFocus()
  box:HighlightText()
end

function Share.Import()
  if not frame then build() end
  pending = nil
  frame.title:SetText("Import routes")
  frame.help:SetText("Paste a RouteKeeper export (Ctrl+V), then click Read.")
  status:SetText("")
  box:SetText("")
  setButtons({
    { "Read", readPasted },
    { "Cancel", function() frame:Hide() end },
  })
  frame:Show()
  box:SetFocus()
end

-- For the smoke test.
function Share._ui() return frame, box, status, buttons end
