-- On-demand, read-only support reports. Keep diagnostic reads separate from
-- refresh/protection code so inspecting a failure cannot silently repair it.
local _, A = ...
local Diagnostics = {}
A.Diagnostics = Diagnostics

local function read(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok and A.Safe(value) then return value end
end

local function value(data)
    if not A.Safe(data) or data == nil then return "unknown" end
    local kind = type(data)
    if kind == "boolean" or kind == "number" then return tostring(data) end
    if kind == "string" then return data:gsub("[%c|]", " "):sub(1, 100) end
    return "unreadable"
end

local function metadata(location)
    local link = location and C_Item and read(C_Item.GetItemLink, location)
    local cached, spellID, consumable
    if type(link) == "string" and link ~= "" then
        cached = read(C_Item.GetItemInfo, link) ~= nil
        consumable = read(C_Item.IsConsumableItem, link)
        if type(C_Item.GetItemSpell) == "function" then
            local ok, _, id = pcall(C_Item.GetItemSpell, link)
            if ok and A.Safe(id) then spellID = id end
        end
    end
    return "cached=" .. value(cached) .. ", spellID=" .. value(spellID) .. ", consumable=" .. value(consumable)
end

function Diagnostics:Report(itemID)
    local mailbox = A.API:MailInteractionActive()
    local risk = read(A.Protection.RiskyContext, A.Protection)
    local lines = {
        "BagMarks " .. A.version .. " diagnostics",
        "ProtectionRevision=" .. value(A.protectionRevision),
        "Client=" .. value(read(GetBuildInfo)) .. "; combat=" .. value(A.InCombat()),
        "Enabled=" .. value(A.IsEnabled()) .. "; readOnly=" .. value(A.readOnly) .. "; itemAPI=" .. value(A.API.available),
        "MarkingMode=" .. value(A.mode) .. "; gestureActive=" .. value(read(A.Interaction.Active, A.Interaction)),
        "Controls=" .. A.Interaction:Hint(),
        "Theme=" .. value(A.db.theme) .. "; markSize=" .. value(A.db.iconSize)
            .. "; icons=" .. value(A.db.overlays) .. "; labels=" .. value(A.db.tooltips),
        "EllesmereRegistered=" .. value(A.Ellesmere.registered ~= nil),
        "EllesmereRefreshEnabled=" .. value(EUI_Bags and EUI_Bags.refreshEnabled),
        "Contexts: merchant=" .. value(A.merchantOpen) .. ", mail=" .. value(A.mailOpen)
            .. ", trade=" .. value(A.tradeOpen) .. ", bank=" .. value(A.bankOpen) .. ", auction=" .. value(A.auctionOpen),
        "LiveMailbox=" .. value(mailbox) .. "; riskyContext=" .. value(risk),
        "Targeting: active=" .. value(read(SpellIsTargeting)) .. ", item=" .. value(read(SpellCanTargetItem))
            .. ", itemID=" .. value(read(SpellCanTargetItemID)),
        "HoldsAvailable=" .. value(A.Protection.holdsAvailable) .. "; syncing=" .. value(A.Protection.syncing == true)
            .. "; stopping=" .. value(A.Protection.stopping == true),
        "CursorProtection: pending=" .. value(A.Protection.cursorCheck ~= nil)
            .. ", checks=" .. value(A.Protection.cursorChecks or 0) .. ", returns=" .. value(A.Protection.cursorReturns or 0),
        "AutoSell=" .. value(A.db.autoSellJunk) .. "; rememberItemTypes=" .. value(A.db.rememberItemTypes)
            .. "; mailAutofill=" .. value(A.db.autoFillRecipient)
            .. "; recipientConfigured=" .. value(A.char.recipient ~= ""),
    }
    if A.mailOpen and mailbox == false then
        lines[#lines + 1] = "Mailbox flag is stale: the client reports that mailing has ended."
    end
    if A.InCombat() then
        lines[#lines + 1] = "Inventory details paused during combat. Refresh after combat ends."
        return table.concat(lines, "\n")
    end
    if not A.API.available then
        lines[#lines + 1] = "Inventory details unavailable: required item APIs are missing."
        return table.concat(lines, "\n")
    end

    local items = {}
    for _, item in pairs(A.API:Scan(true)) do
        if (itemID and item.itemID == itemID) or (not itemID and A.Store:Get(item.guid)) then
            items[#items + 1] = item
        end
    end
    table.sort(items, function(a, b)
        if a.bag == b.bag then return a.slot < b.slot end
        return a.bag < b.bag
    end)
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Readable items" .. (itemID and (" matching " .. itemID) or " with marks") .. ": " .. #items
    -- Bound report length, not identity. Filtering by item ID only chooses what
    -- to describe; marks and hold ownership are still checked per live GUID.
    for index = 1, math.min(#items, 40) do
        local item = items[index]
        local state = A.Store:Get(item.guid)
        local owned = A.Protection.held[item.guid] == true
        local release = A.Protection.releases and A.Protection.releases[item.guid]
        local nativeHeld = C_Item and read(C_Item.IsLocked, item.location)
        local lookup = C_Item and read(C_Item.GetItemLocation, item.guid)
        local matches = lookup and read(C_Item.GetItemGUID, lookup) == item.guid
        local slotReusable = read(A.API.IsReusable, A.API, item.location)
        local lookupReusable
        if matches then lookupReusable = read(A.API.IsReusable, A.API, lookup) end
        local reason
        if release then reason = "Unlock requested; the client has not confirmed the item is free."
        elseif state == "mail" and A.merchantOpen then reason = "Merchant protection reserves this stack for mailing."
        elseif state ~= "locked" then reason = owned and "Owned hold awaiting release." or "This mark permits ordinary item use."
        elseif A.Protection.syncing then reason = "Protection synchronization is active."
        elseif A.mailOpen and mailbox == false then reason = "Stale mailbox flag is blocking reusable use."
        elseif risk ~= false then reason = "Transfer or item-targeting protection is active or unreadable."
        elseif not matches then reason = "The GUID lookup cannot confirm this item."
        elseif owned then reason = "Item has an owned hold awaiting reconciliation."
        elseif nativeHeld == true or item.busy then reason = "Client reports the item busy; BagMarks has no owned hold."
        elseif nativeHeld ~= false then reason = "Client hold status is unavailable."
        else reason = "Ordinary use, equipping, and inventory movement are allowed by protection." end
        lines[#lines + 1] = "Item " .. item.itemID .. "; bag=" .. item.bag .. "; slot=" .. item.slot
            .. "; mark=" .. (A.states[state] or "Normal") .. "; review=" .. value(A.char.review[item.guid] == true)
        lines[#lines + 1] = "  " .. reason
        lines[#lines + 1] = "  reusable: slot=" .. value(slotReusable) .. ", lookup=" .. value(lookupReusable)
            .. "; held: native=" .. value(nativeHeld) .. ", owned=" .. value(owned) .. "; busy=" .. value(item.busy)
        lines[#lines + 1] = "  Lookup data: " .. metadata(matches and lookup or nil)
        lines[#lines + 1] = "  Release: state=" .. (release and release.state or "none")
            .. ", method=" .. (release and release.method or "none")
    end
    if #items > 40 then
        lines[#lines + 1] = "Showing 40 items. Use /bm debug ITEM_ID to narrow the report."
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Report reads state only. Closed-bank items are not scanned."
    return table.concat(lines, "\n")
end

function Diagnostics:Create()
    if self.frame then return end
    local f = A.UI.Window("BagMarksDiagnostics", "BagMarks diagnostics", 500, 390)
    A.UI.Label(f, "Select all, then press Ctrl+C to copy this report.", 20, -42, "GameFontHighlightSmall")
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelInputScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 24, -72)
    scroll:SetSize(450, 260)
    scroll.hideCharCount = true
    scroll.CharCount:Hide()
    local edit = scroll.EditBox
    edit:SetWidth(430)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(0)
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    f:SetScript("OnHide", function() edit:ClearFocus() end)
    self.selectAll = A.UI.Button(f, "Select all", 140, 20, -350, function()
        edit:SetFocus()
        edit:HighlightText()
    end)
    self.refresh = A.UI.Button(f, "Refresh", 140, 180, -350, function() self:Show(self.itemID) end)
    A.UI.Button(f, "Close", 140, 340, -350, function() f:Hide() end)
    self.frame, self.edit, self.scroll = f, edit, scroll
end

function Diagnostics:Show(itemID)
    self:Create()
    self.itemID = itemID
    self.edit:SetText(self:Report(itemID))
    self.frame:Show()
    self.scroll:SetVerticalScroll(0)
end

function Diagnostics:Open(message)
    local text = (message or ""):match("^%s*(.-)%s*$")
    local itemID = text ~= "" and tonumber(text) or nil
    if text ~= "" and (not text:match("^%d+$") or not itemID or itemID < 1 or itemID > 2147483647) then
        A.Print("Use /bm debug or /bmcheck, optionally followed by an item ID (for example, /bm debug 211527).")
        return false
    end
    self:Show(itemID)
    return true
end
