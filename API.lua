-- Client API boundary: turn readable live slots into item records. Callers
-- track the GUID; bag/slot coordinates are only the item's current location.
local _, A = ...
local API = {}
A.API = API

function API:Initialize()
    self.available = C_Container and C_Container.GetContainerItemInfo
        and C_Container.GetContainerNumSlots and C_Item and C_Item.GetItemGUID
        and ItemLocation and ItemLocation.CreateFromBagAndSlot and true or false
end

function API:Location(bag, slot)
    return ItemLocation:CreateFromBagAndSlot(bag, slot)
end

function API:Read(bag, slot, forDisplay)
    -- Passive icons may read a live identity in combat. Operation reads and
    -- scans stay suspended; unreadable data never falls back to a cached mark.
    if not self.available or (A.InCombat() and not forDisplay) or not A.Safe(bag) or not A.Safe(slot)
        or type(bag) ~= "number" or type(slot) ~= "number" then return end
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if not ok or not A.Safe(info) or type(info) ~= "table" then return end
    for _, key in ipairs({ "itemID", "stackCount", "isLocked", "isBound", "hasNoValue", "hyperlink", "quality" }) do
        if not A.Safe(info[key]) then return end
    end
    if type(info.itemID) ~= "number" or type(info.stackCount) ~= "number" or info.stackCount < 1 then return end
    local location = self:Location(bag, slot)
    -- An item ID identifies a type shared by many copies. Only a GUID can
    -- carry one selected copy's mark safely through sorting and movement.
    local guidOK, guid = pcall(C_Item.GetItemGUID, location)
    if not guidOK or not A.Safe(guid) or type(guid) ~= "string" or not guid:match("^Item%-") then return end
    -- Treat an unknown native busy flag as busy, so helpers do not act on it.
    return {
        guid = guid, bag = bag, slot = slot, location = location,
        itemID = info.itemID, count = info.stackCount, link = info.hyperlink,
        busy = info.isLocked ~= false, bound = info.isBound, noValue = info.hasNoValue,
        quality = info.quality,
    }
end

-- No legacy bank constants: -1 is Forever's keyring, not the Classic bank.
function API:BagIDs(includeBank)
    local ids, seen = {}, {}
    local function add(id)
        if type(id) == "number" and not seen[id] then
            ids[#ids + 1], seen[id] = id, true
        end
    end
    local enum = Enum and Enum.BagIndex
    if enum then
        add(enum.Backpack)
        for i = 1, 4 do add(enum["Bag_" .. i]) end
        add(enum.ReagentBag)
    end
    if includeBank and A.bankOpen and C_Bank and C_Bank.FetchPurchasedBankTabData and Enum.BankType then
        for _, bankType in ipairs({ Enum.BankType.Character, Enum.BankType.Account }) do
            local ok, tabs = pcall(C_Bank.FetchPurchasedBankTabData, bankType)
            if ok and type(tabs) == "table" then
                for _, tab in ipairs(tabs) do add(tab.ID) end
            end
        end
    end
    return ids
end

function API:Scan(includeBank)
    -- Return both the found GUIDs and the bags we could inspect. Store uses
    -- scope to distinguish a missing item from a bank that is merely closed.
    local items, scope = {}, {}
    if not self.available or A.InCombat() then return items, scope end
    for _, bag in ipairs(self:BagIDs(includeBank)) do
        local ok, count = pcall(C_Container.GetContainerNumSlots, bag)
        if ok and A.Safe(count) and type(count) == "number" then
            scope[bag] = true
            for slot = 1, count do
                local item = self:Read(bag, slot)
                if item then items[item.guid] = item end
            end
        end
    end
    return items, scope
end

function API:Find(guid, includeBank)
    -- Menus and queues can outlive a bag sort. Resolve the GUID again instead
    -- of trusting the location captured when the user started the action.
    local items = self:Scan(includeBank)
    return items[guid]
end

function API:IsReusable(location)
    -- Diagnostic classification only; it never gates ordinary use/equipping.
    -- Read the live item's link and require cached data, a use effect and the
    -- client's explicit nonconsumable result. Unknown/secret data is unclassified.
    if not C_Item or type(C_Item.GetItemLink) ~= "function" or type(C_Item.GetItemInfo) ~= "function"
        or type(C_Item.GetItemSpell) ~= "function" or type(C_Item.IsConsumableItem) ~= "function" then return false end
    local linkOK, link = pcall(C_Item.GetItemLink, location)
    if not linkOK or not A.Safe(link) or type(link) ~= "string" or link == "" then return false end
    local infoOK, name = pcall(C_Item.GetItemInfo, link)
    if not infoOK or not A.Safe(name) or type(name) ~= "string" or name == "" then return false end
    local spellOK, spellName, spellID = pcall(C_Item.GetItemSpell, link)
    if not spellOK or not A.Safe(spellName) or not A.Safe(spellID)
        or type(spellName) ~= "string" or spellName == "" or type(spellID) ~= "number" or spellID <= 0 then return false end
    local consumableOK, consumable = pcall(C_Item.IsConsumableItem, link)
    return consumableOK and A.Safe(consumable) and consumable == false
end

function API:MailInteractionActive()
    -- A closed frame is not proof that mailing has ended. Ask the client;
    -- nil means unknown and must never be treated as permission to release a hold.
    local kind = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.MailInfo
    if not A.Safe(kind) or type(kind) ~= "number" or not C_PlayerInteractionManager
        or type(C_PlayerInteractionManager.IsInteractingWithNpcOfType) ~= "function" then return end
    local ok, active = pcall(C_PlayerInteractionManager.IsInteractingWithNpcOfType, kind)
    if ok and A.Safe(active) and type(active) == "boolean" then return active end
end

-- Unknown quest/refund status excludes an item from automated sale or mail.
function API:IsQuest(item)
    if not C_Container.GetContainerItemQuestInfo then return true end
    local ok, info = pcall(C_Container.GetContainerItemQuestInfo, item.bag, item.slot)
    if not ok or not A.Safe(info) or type(info) ~= "table" then return true end
    if not A.Safe(info.isQuestItem) or not A.Safe(info.questID) then return true end
    return info.isQuestItem or info.questID ~= nil
end

function API:Refundable(item)
    if not C_Item.CanBeRefunded then return true end
    local ok, result = pcall(C_Item.CanBeRefunded, item.location)
    return not ok or not A.Safe(result) or result ~= false
end

function API:SellPrice(item)
    if item.noValue ~= false or not C_Item.GetItemInfo then return end
    -- The eleventh return is the unit vendor price in copper. Sale previews
    -- multiply it by stack count; the queue also checks it again before selling.
    local ok, name, _, _, _, _, _, _, _, _, _, price = pcall(C_Item.GetItemInfo, item.link or item.itemID)
    if ok and A.Safe(name) and A.Safe(price) and name and type(price) == "number" and price > 0 then
        return price
    end
end

function API:CanMail(item)
    -- Conservative: soulbound, account-bound, quest, refundable and unknown items are manual-only.
    if item.bound ~= false or not C_Item.IsBound or not C_Item.IsItemBindToAccount then return false end
    local ok, bound = pcall(C_Item.IsBound, item.location)
    local accountOK, account = pcall(C_Item.IsItemBindToAccount, item.link or item.itemID)
    return ok and accountOK and A.Safe(bound) and A.Safe(account) and bound == false and account == false
        and not self:IsQuest(item) and not self:Refundable(item)
end

function API:MerchantReady()
    -- UseContainerItem sells only in the intended merchant context. The Buy
    -- tab and empty cursor prevent this queue from becoming a different action.
    return A.CanAct() and A.merchantOpen and MerchantFrame and MerchantFrame:IsShown()
        and MerchantFrame.selectedTab == 1 and not GetCursorInfo()
        and not (SpellIsTargeting and SpellIsTargeting())
end

function API:MailReady()
    return A.CanAct() and A.mailOpen and SendMailFrame and SendMailFrame:IsShown()
        and not GetCursorInfo() and type(ClickSendMailItemButton) == "function"
        and type(HasSendMailItem) == "function" and type(ATTACHMENTS_MAX_SEND) == "number"
end

function API:FreeAttachment()
    if not HasSendMailItem or not ATTACHMENTS_MAX_SEND then return end
    for i = 1, ATTACHMENTS_MAX_SEND do
        if not HasSendMailItem(i) then return i end
    end
end
