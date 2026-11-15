-- Deliberately explicit Lua 5.1 WoW mock. Unknown UI methods fail loudly.
local M = { time = 0, timers = {}, frames = {}, bags = {}, attachments = {}, messages = {}, sold = {}, bindings = {} }
local Frame = {}
Frame.__index = Frame

local function newFrame(kind, name, parent, template)
    local f = setmetatable({ kind = kind, name = name, parent = parent, shown = true,
        scripts = {}, hooks = {}, width = 36, height = 36, level = 1, strata = "MEDIUM", enabled = true }, Frame)
    M.frames[#M.frames + 1] = f
    if name then _G[name] = f end
    if template == "BasicFrameTemplateWithInset" then f.TitleText = newFrame("FontString", nil, f) end
    return f
end
function Frame:GetName() return self.name end
function Frame:SetSize(w, h) self.width, self.height = w, h end
function Frame:SetWidth(w) self.width = w end
function Frame:SetHeight(h) self.height = h end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:SetPoint(...) self.point = { ... } end
function Frame:GetPoint() if self.point then return unpack(self.point) end end
function Frame:GetNumPoints() return self.point and 1 or 0 end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetAllPoints(target) self.anchored = target end
function Frame:GetCenter() return 100, 100 end
function Frame:GetEffectiveScale() return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1) end
function Frame:SetScale(scale) self.scale = scale end
function Frame:SetFrameStrata(s) self.strata = s end
function Frame:GetFrameStrata() return self.strata end
function Frame:SetFrameLevel(l) self.level = l end
function Frame:SetAlpha(alpha) self.alpha = alpha end
function Frame:GetAlpha() return self.alpha or 1 end
function Frame:GetFrameLevel() return self.level end
function Frame:SetClampedToScreen(value) self.clamped = value end
function Frame:SetMovable(value) self.movable = value end
function Frame:EnableMouse(value) self.mouse = value end
function Frame:EnableKeyboard(value) self.keyboard = value end
function Frame:SetPropagateKeyboardInput(value) self.propagateKeyboard = value end
function Frame:SetMouseMotionEnabled(value) self.motion = value end
function Frame:SetPassThroughButtons(...) self.passthrough = { ... } end
function Frame:RegisterForClicks(...) self.clicks = { ... } end
function Frame:RegisterForDrag(...) self.drags = { ... } end
function Frame:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
function Frame:SetScript(event, fn) self.scripts[event] = fn end
function Frame:HookScript(event, fn)
    self.hooks[event] = self.hooks[event] or {}
    self.hooks[event][#self.hooks[event] + 1] = fn
end
function Frame:Fire(event, ...)
    if self.scripts[event] then self.scripts[event](self, ...) end
    for _, fn in ipairs(self.hooks[event] or {}) do fn(self, ...) end
end
function Frame:Show()
    self.showCalls = (self.showCalls or 0) + 1
    if not self.shown then self.shown = true; self:Fire("OnShow") end
end
function Frame:Hide()
    if self.shown then self.shown = false; self:Fire("OnHide") end
end
function Frame:SetShown(value) if value then self:Show() else self:Hide() end end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Frame:GetParent() return self.parent end
function Frame:SetParent(parent) self.parent = parent end
function Frame:IsForbidden() return false end
function Frame:SetEnabled(value) self.enabled = value end
function Frame:SetChecked(value) self.checked = value end
function Frame:GetChecked() return self.checked end
function Frame:SetText(value) self.text = value end
function Frame:GetText() return self.text or "" end
function Frame:GetStringHeight() return 15 * select(2, self:GetText():gsub("\n", "")) + 15 end
function Frame:SetJustifyH(value) self.justifyH = value end
function Frame:SetJustifyV(value) self.justifyV = value end
function Frame:SetTexture(value) self.texture = value end
function Frame:SetVertexColor(...) self.color = { ... } end
function Frame:SetColorTexture(...) self.color = { ... } end
function Frame:SetDesaturated(value) self.desaturated = value end
function Frame:SetHighlightTexture(value) self.highlight = value end
function Frame:SetAutoFocus(value) self.autoFocus = value end
function Frame:SetMaxLetters(value) self.maxLetters = value end
function Frame:HasFocus() return self.focus end
function Frame:ClearFocus()
    local focused = self.focus
    self.focus = false
    if focused then self:Fire("OnEditFocusLost") end
end
function Frame:HighlightText() self.highlighted = true end
function Frame:StartMoving() self.moving = true end
function Frame:StopMovingOrSizing() self.moving = false end
function Frame:SetScrollChild(child) self.scrollChild = child end
function Frame:SetVerticalScroll(value) self.verticalScroll = value end
function Frame:CreateTexture() return newFrame("Texture", nil, self) end
function Frame:CreateFontString() return newFrame("FontString", nil, self) end
function Frame:SetOwner(owner) self.owner = owner end
function Frame:GetOwner() return self.owner end
function Frame:AddLine(text) self.lines = self.lines or {}; self.lines[#self.lines + 1] = text end
function Frame:SetBagItem(bag, slot)
    self.lines = {}
    for _, callback in ipairs(M.tooltipCallbacks) do callback(self, { type = 0 }) end
    return M.bags[bag] and M.bags[bag][slot] ~= nil
end

CreateFrame = newFrame
UIParent = newFrame("Frame", "UIParent")
Minimap = newFrame("Frame", "Minimap", UIParent)
Minimap:SetSize(140, 140)
GameTooltip = newFrame("GameTooltip", "GameTooltip", UIParent)
GameTooltip:Hide()
MerchantFrame = newFrame("Frame", "MerchantFrame", UIParent)
MerchantFrame.selectedTab = 1
MerchantFrame:Hide()
MerchantSellAllJunkButton = newFrame("Button", "MerchantSellAllJunkButton", MerchantFrame)
SendMailFrame = newFrame("Frame", "SendMailFrame", UIParent)
SendMailFrame:Hide()
SendMailNameEditBox = newFrame("EditBox", "SendMailNameEditBox", SendMailFrame)
BankFrame = newFrame("Frame", "BankFrame", UIParent)
BankFrame.BankPanel = newFrame("Frame", nil, BankFrame)
BankFrame:Hide()
UISpecialFrames, SlashCmdList = {}, {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) M.messages[#M.messages + 1] = message end }
Enum = { BagIndex = { Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5 },
    BankType = { Character = 0, Account = 2 }, TooltipDataType = { Item = 0 } }
C_Bank = { FetchPurchasedBankTabData = function(bankType)
    return { { ID = bankType == 0 and 6 or 15 } }
end }
ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
local function at(bag, slot) return M.bags[bag] and M.bags[bag][slot] end
C_Container = {
    GetContainerNumSlots = function(bag) return M.bags[bag] and 32 or 0 end,
    GetContainerItemInfo = function(bag, slot)
        M.reads = (M.reads or 0) + 1
        local i = at(bag, slot)
        if not i then return end
        return { itemID = i.secretID or i.itemID, stackCount = i.count, isLocked = i.busy or i.held or false,
            isBound = i.bound or false, hasNoValue = i.noValue or false, hyperlink = i.link, quality = i.quality or 1 }
    end,
    GetContainerItemQuestInfo = function(bag, slot) return { isQuestItem = at(bag, slot).quest or false } end,
    UseContainerItem = function(bag, slot)
        -- Count every invocation so cancellation tests also catch accidental
        -- uses after the merchant closes. Ordinary use has its own result list.
        M.saleAttempts = (M.saleAttempts or 0) + 1
        local i = assert(at(bag, slot), "using empty slot")
        if M.A.merchantOpen then
            if M.rejectSale then return end
        end
        if i.busy or i.held then return end
        if not M.A.merchantOpen then
            assert(not M.A.mailOpen and not M.A.tradeOpen and not M.targeting, "unsafe ordinary use")
            M.used[#M.used + 1] = i.guid
            if i.consumable then
                i.count = i.count - 1
                if i.count == 0 then M.bags[bag][slot] = nil end
            end
            return
        end
        assert(M.A.Store:Get(i.guid) == "junk", "non-junk sale")
        M.sold[#M.sold + 1] = i.guid
        M.bags[bag][slot] = nil
    end,
    PickupContainerItem = function(bag, slot)
        assert(not M.cursor, "nonempty cursor")
        local i = at(bag, slot)
        if not i or i.busy or i.held then return end
        M.cursor = { item = i, bag = bag, slot = slot }
        M.bags[bag][slot] = nil
    end,
}
local function locatedItem(location)
    if location.cursor then return M.cursor and M.cursor.item end
    return at(location.bag, location.slot)
end
C_Cursor = { GetCursorItem = function()
    if M.cursor and not M.cursorLocationMissing then return { cursor = true } end
end }
InputUtil = { IsGamepadUIEnabled = function() return M.gamepad or false end }
C_Item = {
    GetItemGUID = function(location)
        local item = locatedItem(location)
        return item and item.guid
    end,
    GetItemLink = function(location)
        local item = locatedItem(location)
        return item and (item.secretLink or item.link)
    end,
    GetItemSpell = function(link)
        local i = M.info[link]
        if i and not i.uncached and i.spellID then return "Test use effect", i.spellID end
    end,
    IsConsumableItem = function(link)
        local i = M.info[link]
        if i then return i.consumable or false end
    end,
    DoesItemExist = function(location) return locatedItem(location) ~= nil end,
    GetItemLocation = function(guid)
        if M.locationFailure then error("location unavailable") end
        if M.secretLocation then return M.secret end
        for bag, items in pairs(M.bags) do
            if bag < 6 or M.A.bankOpen then
                for slot, item in pairs(items) do
                    if item.guid == guid then return { bag = bag, slot = slot } end
                end
            end
        end
    end,
    IsLocked = function(location)
        local i = locatedItem(location)
        if M.secretLock then return M.secret end
        return i and (i.held or i.busy) or false
    end,
    LockItem = function(location)
        M.lockCalls = M.lockCalls + 1
        if M.failLock then error("hold refused") end
        if M.rejectLock then return end
        local i = assert(locatedItem(location), "holding absent item")
        i.held = true
        if M.reentrantLocks then M.A.eventFrame:Fire("OnEvent", "ITEM_LOCK_CHANGED", location.bag, location.slot) end
    end,
    UnlockItemByGUID = function(guid)
        M.unlockCalls[#M.unlockCalls + 1] = guid
        if M.failUnlock then error("release refused") end
        local location = C_Item.GetItemLocation(guid)
        if location then locatedItem(location).held = nil end
        if M.reentrantLocks then M.A.eventFrame:Fire("OnEvent", "ITEM_LOCK_CHANGED") end
    end,
    CanBeRefunded = function(location) return at(location.bag, location.slot).refundable or false end,
    IsBound = function(location) return at(location.bag, location.slot).bound or false end,
    IsItemBindToAccount = function(link) return M.info[link] and M.info[link].account or false end,
    GetItemInfo = function(link)
        local i = M.info[link]
        if not i or i.uncached then return end
        return i.secretName or "Test item", i.link, 1, 1, 1, "Misc", "Misc", 20, "", 1, i.price or 100
    end,
}
M.secret = {}
function issecretvalue(value) return value == M.secret end
function InCombatLockdown() return M.combat or false end
function IsAltKeyDown() return M.alt or false end
function IsControlKeyDown() return M.ctrl or false end
function IsShiftKeyDown() return M.shift or false end
function SpellIsTargeting() return M.targeting or false end
function SpellCanTargetItem() return M.targeting and not M.groundTarget or false end
function SpellCanTargetItemID() return M.targeting and not M.groundTarget or false end
function GetCursorInfo() if M.cursor then return M.cursorKind or "item" end end
function CursorHasItem() return M.cursor ~= nil end
function ClearCursor()
    M.clearCalls = (M.clearCalls or 0) + 1
    if M.failClear then error("cursor clear rejected") end
    if M.keepCursor then return end
    if M.cursor then M.bags[M.cursor.bag][M.cursor.slot] = M.cursor.item; M.cursor = nil end
    if M.reentrantCursor then M.A.eventFrame:Fire("OnEvent", "CURSOR_CHANGED") end
end

-- These test helpers model paths that bypass an item hold. They do not call any
-- addon logic, so event handling must independently identify the exact GUID.
function M.forcePickup(bag, slot)
    assert(not M.cursor, "nonempty cursor")
    M.cursor = { item = assert(at(bag, slot)), bag = bag, slot = slot }
    M.bags[bag][slot] = nil
end
function M.returnToBags(item)
    M.bags[0] = M.bags[0] or {}
    for slot = 1, 32 do
        if not M.bags[0][slot] then M.bags[0][slot] = item; return true end
    end
    return false
end

ATTACHMENTS_MAX_SEND = 12
function HasSendMailItem(index) return M.attachments[index] ~= nil end
function GetSendMailItem(index)
    local i = M.attachments[index]
    if i then return "Test item", i.itemID, 1, i.count, 1 end
end
function ClickSendMailItemButton(index, clear)
    if clear then
        M.removals[#M.removals + 1] = index
        if M.failRemoval then error("removal refused") end
        if M.rejectRemoval then return end
        local item = M.attachments[index]
        if item and M.returnToBags(item) then M.attachments[index] = nil end
        if M.reentrantMail then M.A.eventFrame:Fire("OnEvent", "MAIL_SEND_INFO_UPDATE") end
        return
    end
    if M.rejectMail then return end
    assert(not M.attachments[index], "occupied attachment")
    assert(M.A.Store:Get(M.cursor.item.guid) == "mail", "non-mail attachment")
    M.attachments[index] = M.cursor.item
    M.cursor = nil
end
function CloseMail()
    M.closeMailCalls = M.closeMailCalls + 1
    if M.failCloseMail then error("mail close refused") end
    for index, item in pairs(M.attachments) do
        if M.returnToBags(item) then M.attachments[index] = nil end
    end
    SendMailFrame:Hide()
    M.A.eventFrame:Fire("OnEvent", "MAIL_CLOSED")
end
MAX_TRADE_ITEMS = 7
function CancelTrade()
    M.cancelTradeCalls = M.cancelTradeCalls + 1
    if M.failCancelTrade then error("trade cancellation refused") end
    for _, item in pairs(M.tradeItems) do M.returnToBags(item) end
    M.tradeItems = {}
    M.A.eventFrame:Fire("OnEvent", "TRADE_CLOSED")
end
local function tooltip(item)
    if M.secretTooltip then return M.secret end
    if item then return { guid = M.secretTooltipGUID and M.secret or (not M.missingTooltipGUID and item.guid or nil) } end
end
C_TooltipInfo = {
    GetSendMailItem = function(index) return tooltip(M.attachments[index]) end,
    GetTradePlayerItem = function(index) return tooltip(M.tradeItems[index]) end,
    GetBuybackItem = function(index) return tooltip(M.buyback[index]) end,
}
function GetNumBuybackItems() return #M.buyback end
function GetBuybackItemInfo(index)
    local i = M.buyback[index]
    if i then return "Test item", 1, M.secretPrice and M.secret or i.price or 100, i.count, 1 end
end
function GetMoney() return M.money end
function BuybackItem(index)
    M.buybacks[#M.buybacks + 1] = M.buyback[index].guid
    if M.failBuyback then error("buyback refused") end
    if M.rejectBuyback then return end
    local item = M.buyback[index]
    local _, _, price = GetBuybackItemInfo(index)
    assert(M.money >= price, "cannot afford buyback")
    if M.returnToBags(item) then
        M.money = M.money - price
        table.remove(M.buyback, index)
        if M.reentrantBuyback then M.A.eventFrame:Fire("OnEvent", "MERCHANT_UPDATE") end
    end
end
function SendMail() error("BagMarks must never send mail") end
function DeleteCursorItem() error("BagMarks must never destroy an item") end
function GetTime() return M.time end
function GetCoinTextureString(value) return value .. " copper" end
function GetCursorPosition() return M.cursorX or 180, M.cursorY or 100 end
function GetBindingKey(action)
    local keys = {}
    for key, value in pairs(M.bindings) do if value == action then keys[#keys + 1] = key end end
    table.sort(keys)
    return unpack(keys)
end
function GetBindingAction(key, overrides) return overrides and M.overrides and M.overrides[key] or M.bindings[key] or "" end
function GetBindingText(key) return key end
function GetCurrentBindingSet() return M.bindingSet or 1 end
function SetBinding(key, action)
    assert(not M.combat, "binding change in combat")
    if M.failKey == key then return false end
    M.bindings[key] = action
    return true
end
function SaveBindings(set) M.savedBindingSet = set end
C_Timer = { After = function(delay, callback) M.timers[#M.timers + 1] = { at = M.time + delay, callback = callback } end }
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name) return { panel = panel, name = name } end,
    RegisterAddOnCategory = function(category) M.category = category end,
}
local function menuDescription(owner)
    local root = { choices = {}, children = {}, owner = owner }
    function root:CreateTitle(text) self.title = text end
    function root:SetScrollMode(height) self.scrollHeight = height end
    function root:CreateRadio(text, selected, callback)
        self.choices[#self.choices + 1] = { text = text, selected = selected, callback = callback }
    end
    function root:CreateButton(text)
        local child = menuDescription(self.owner)
        child.text = text
        self.children[#self.children + 1] = child
        return child
    end
    return root
end
MenuUtil = { CreateContextMenu = function(owner, generator)
    local root = menuDescription(owner)
    generator(owner, root)
    M.menu = root
end }
M.tooltipCallbacks = {}
TooltipDataProcessor = { AddTooltipPostCall = function(_, callback) M.tooltipCallbacks[#M.tooltipCallbacks + 1] = callback end }
function hooksecurefunc(object, method, callback)
    local original = object[method]
    object[method] = function(...)
        local result = { original(...) }
        callback(...)
        return unpack(result)
    end
end
ContainerFrameItemButtonMixin = { Initialize = function(button, _, bag, slot) button.bag, button.slot = bag, slot end }
ContainerFrameMixin = { UpdateItems = function() end }
BankPanelItemButtonMixin = { Refresh = function() end }
M.containers, M.bankButtons = {}, {}
function ContainerFrameUtil_EnumerateContainerFrames() return ipairs(M.containers) end
function BankFrame.BankPanel:EnumerateValidItems() return next, M.bankButtons, nil end

function M.tick(seconds)
    local target, safety = M.time + (seconds or 1), 0
    while true do
        table.sort(M.timers, function(a, b) return a.at < b.at end)
        if not M.timers[1] or M.timers[1].at > target then break end
        local timer = table.remove(M.timers, 1)
        M.time = timer.at
        timer.callback()
        safety = safety + 1
        assert(safety < 1000, "timer loop")
    end
    M.time = target
end

function M.item(guid, bag, slot, options)
    local i = options or {}
    i.guid, i.itemID, i.count = guid, i.itemID or 100, i.count or 1
    i.link = "|Hitem:" .. i.itemID .. "|h[Test item]|h"
    M.bags[bag] = M.bags[bag] or {}
    M.bags[bag][slot] = i
    M.info[i.link] = i
    return i
end

function M.button(bag, slot, bank)
    local button = newFrame("ItemButton", nil, bank and BankFrame.BankPanel or UIParent)
    button.bag, button.slot = bag, slot
    if bank then
        function button:GetBankTabID() return self.bag end
        function button:GetContainerSlotID() return self.slot end
        M.bankButtons[button] = true
    else
        function button:GetBagID() return self.bag end
        function button:GetID() return self.slot end
        local container = newFrame("Frame", nil, UIParent)
        function container:EnumerateValidItems() return ipairs({ button }) end
        M.containers[#M.containers + 1] = container
    end
    return button
end

-- Ellesmere's public painter, not Blizzard's global container pool. Its bank
-- renderer reuses data tables and its list rows have a separate icon-sized host.
function M.ellesmere()
    EUI_Bags = newFrame("Frame", "EUI_Bags", UIParent)
    EUI_Bags.itemOverlayIcons, EUI_Bags.registrations = {}, 0
    function EUI_Bags.RegisterItemOverlayIcon(name, callback)
        EUI_Bags.registrations = EUI_Bags.registrations + 1
        EUI_Bags.itemOverlayIcons[name] = callback
    end
    function EUI_Bags.RunItemOverlays(button, data)
        for _, callback in pairs(EUI_Bags.itemOverlayIcons) do callback(button, data) end
    end
    return EUI_Bags
end

function M.ellesmereButton(bag, slot, list)
    local button = newFrame("ItemButton", nil, EUI_Bags)
    button.bag, button.slot = bag, slot
    function button:GetBagID() return self.bag end
    function button:GetID() return self.slot end
    if list then button:SetSize(400, 24) end
    button._textOverlay = newFrame("Frame", nil, button)
    button._textOverlay:SetSize(list and 20 or 36, list and 20 or 36)
    button._textOverlay:SetFrameLevel(button:GetFrameLevel() + 3)
    button:SetScript("OnClick", function() M.nativeClicks = (M.nativeClicks or 0) + 1 end)
    return button
end

function M.reset(A)
    M.A, M.bags, M.info, M.attachments, M.messages, M.sold, M.timers = A, {}, {}, {}, {}, {}, {}
    M.time, M.bindings, M.overrides, M.bindingSet, M.savedBindingSet = 0, {}, nil, 1, nil
    M.cursor, M.rejectSale, M.rejectMail, M.combat, M.alt, M.ctrl, M.shift, M.targeting, M.failKey = nil, nil, nil, false, false, false, false, false, nil
    M.containers, M.bankButtons, M.reads = {}, {}, 0
    M.saleAttempts = 0
    M.used, M.groundTarget = {}, false
    M.cursorLocationMissing, M.cursorKind, M.gamepad, M.failClear, M.keepCursor, M.clearCalls = nil, nil, false, false, false, 0
    M.lockCalls, M.unlockCalls, M.reentrantLocks, M.reentrantCursor = 0, {}, false, false
    M.locationFailure, M.secretLocation, M.secretLock, M.failLock, M.rejectLock, M.failUnlock = false, false, false, false, false, false
    M.removals, M.closeMailCalls, M.failRemoval, M.rejectRemoval, M.failCloseMail, M.reentrantMail = {}, 0, false, false, false, false
    M.tradeItems, M.cancelTradeCalls, M.failCancelTrade = {}, 0, false
    M.secretTooltip, M.secretTooltipGUID, M.missingTooltipGUID = false, false, false
    M.buyback, M.buybacks, M.money, M.secretPrice, M.failBuyback, M.rejectBuyback, M.reentrantBuyback = {}, {}, 10000, false, false, false, false
    for key, value in pairs(A.Protection) do
        if type(value) ~= "function" then A.Protection[key] = nil end
    end
    A.Protection.held = {}
    BagMarksDB, BagMarksCharDB = nil, nil
    A.Store:Initialize()
    A.mode, A.merchantOpen, A.mailOpen, A.bankOpen, A.tradeOpen, A.pendingRefresh = false, false, false, false, false, false
    A.auctionOpen = false
    A.Mail:Close()
    A.Bags.overlays = {}
    EUI_Bags = nil
    if A.Ellesmere then A.Ellesmere.slots, A.Ellesmere.registered = {}, nil end
    M.nativeClicks, M.menu = 0, nil
    A.inventory = {}
    A.Operations:Cancel()
    A.Bindings.previous, A.Bindings.previousSet = nil, nil
    A.Bindings:StopCapture()
    A.Settings.frame:Hide()
    A.Settings:SelectTab("General")
    MerchantFrame:Hide(); SendMailFrame:Hide(); BankFrame:Hide()
    SendMailNameEditBox:SetText("")
    SendMailFrame.sendMode, SendMailNameEditBox.focus, SendMailNameEditBox.highlighted = nil, false, false
    local mini = A.Minimap
    mini:StopDrag()
    mini.justDragged, mini.placement, mini.shownPreference = false, nil, nil
    mini.button.Show, mini.button.Hide = nil, nil
    mini.button:SetParent(Minimap)
    mini.button:SetSize(31, 31)
    mini.button:ClearAllPoints()
    mini.button:SetAlpha(1)
    mini.button:SetScript("OnUpdate", nil)
    mini:Position()
    mini:Refresh()
end

return M
