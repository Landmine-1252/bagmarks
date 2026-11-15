local _, A = ...
local Ellesmere = { slots = {} }
A.Ellesmere = Ellesmere

-- EUI_Bags.RegisterItemOverlayIcon is Ellesmere's public integration point.
-- Its render data is temporary (the bank reuses one table), so keep only our
-- own copy of primitive slot metadata. Never write state or scripts onto EUI.
local function carried(bag)
    for _, id in ipairs(A.API:BagIDs(false)) do
        if bag == id then return true end
    end
    return false
end

function Ellesmere:Paint(button, data)
    if not button or (button.IsForbidden and button:IsForbidden()) then return end
    local shown = { host = button._textOverlay or button }
    if A.Safe(data) and type(data) == "table" and A.Safe(data.info) and type(data.info) == "table" then
        local bag, slot, itemID = data.bag, data.slot, data.info.itemID
        if A.Safe(bag) and A.Safe(slot) and A.Safe(itemID)
            and type(bag) == "number" and type(slot) == "number" and slot > 0 and type(itemID) == "number" then
            shown.bag, shown.slot, shown.itemID = bag, slot, itemID
            if A.Safe(data.itemLink) and type(data.itemLink) == "string" then shown.link = data.itemLink end
            if A.Safe(data._mergedCount) and type(data._mergedCount) == "number" then
                shown.total = data._mergedCount
            end
        end
    end
    self.slots[button] = shown
    if A.InCombat() then return end -- Discovery attaches pending slots after combat.
    if shown.itemID then A.Bags:Attach(button, true)
    elseif A.Bags.overlays[button] then A.Bags:Update(button) end
end

function Ellesmere:Read(button)
    local shown = self.slots[button]
    if not shown or not shown.itemID or (not carried(shown.bag) and not A.bankOpen) then return end
    -- A recycled button may have been reassigned before its next painter call.
    if button.GetBagID and button:GetBagID() ~= shown.bag then return end
    if button.GetID and button:GetID() ~= shown.slot then return end
    local item = A.API:Read(shown.bag, shown.slot)
    if item and item.itemID == shown.itemID and (not shown.link or item.link == shown.link) then return item end
end

function Ellesmere:GroupItems(item, fresh)
    if not item or not item.link then return {} end
    local items = fresh and A.API:Scan(true) or A.inventory or {}
    local inBags, matches = carried(item.bag), {}
    for _, candidate in pairs(items) do
        -- Ellesmere groups matching links, not every variant of an item ID.
        -- Bank groups stay within the represented tab; bag groups span carried bags.
        if candidate.itemID == item.itemID and candidate.link == item.link
            and (candidate.bag == item.bag or (inBags and carried(candidate.bag))) then
            matches[#matches + 1] = candidate
        end
    end
    table.sort(matches, function(a, b)
        if a.bag == b.bag then return a.slot < b.slot end
        return a.bag < b.bag
    end)
    return matches
end

function Ellesmere:GroupState(button, item)
    local items = self:GroupItems(item, false)
    local state, same, total = nil, true, 0
    local hasLocked = item and A.Store:Get(item.guid) == "locked" or false
    for i, candidate in ipairs(items) do
        local mark = A.Store:Get(candidate.guid)
        if i == 1 then state = mark elseif state ~= mark then same = false end
        if mark == "locked" then hasLocked = true end
        total = total + candidate.count
    end
    -- Never paint a whole group Locked because just one of its GUIDs is locked.
    if total ~= self.slots[button].total then same = false end
    return same and state or nil, hasLocked, #items, not same
end

function Ellesmere:OpenGroup(button, item)
    local items = self:GroupItems(item, true)
    if #items == 0 then
        A.Print("Those stacks are no longer available. Reopen the bags and try again.")
        return
    end
    -- Even in cycle mode a combined button needs an explicit per-GUID choice.
    A.UI:ItemMenu(button, item, items)
end

function Ellesmere:Discover()
    for button, shown in pairs(self.slots) do
        if shown.itemID and button:IsVisible() then A.Bags:Attach(button) end
    end
end

function Ellesmere:Install()
    if not EUI_Bags or type(EUI_Bags.RegisterItemOverlayIcon) ~= "function" or self.registered == EUI_Bags then return end
    EUI_Bags.RegisterItemOverlayIcon(A.name, function(button, data) self:Paint(button, data) end)
    self.registered = EUI_Bags
end
