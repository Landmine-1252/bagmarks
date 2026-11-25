-- Deliberately explicit Lua 5.1 WoW mock. Unknown UI methods fail loudly.
local M = { time = 0, timers = {}, frames = {}, bags = {}, attachments = {}, messages = {}, sold = {}, bindings = {} }
local Frame = {}
Frame.__index = Frame

local function newFrame(kind, name, parent, template)
    local f = setmetatable({ kind = kind, name = name, parent = parent, template = template, shown = true,
        scripts = {}, hooks = {}, width = 36, height = 36, enabled = true }, Frame)
    M.frames[#M.frames + 1] = f
    if name then _G[name] = f end
    if template == "BasicFrameTemplateWithInset" then f.TitleText = newFrame("FontString", nil, f) end
    if template == "InputBoxInstructionsTemplate" then f.Instructions = newFrame("FontString", nil, f) end
    if template == "PanelTopTabButtonTemplate" then
        f.Text = newFrame("FontString", nil, f)
        for _, part in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive" }) do
            f[part] = newFrame("Texture", nil, f)
        end
    end
    if template == "UIPanelInputScrollFrameTemplate" then
        f.EditBox = newFrame("EditBox", nil, f)
        f.CharCount = newFrame("FontString", nil, f)
        f.EditBox.multiLine = true
    end
    return f
end
function Frame:GetName() return self.name end
function Frame:SetID(id) self.id = id end
function Frame:GetID() return self.id end
function Frame:SetSize(w, h) self.width, self.height = w, h end
function Frame:SetWidth(w) self.width = w end
function Frame:SetHeight(h) self.height = h end
function Frame:GetWidth()
    if self.anchored then return self.anchored:GetWidth() * self.anchored:GetEffectiveScale() / self:GetEffectiveScale() end
    return self.width
end
function Frame:GetHeight()
    if self.anchored then return self.anchored:GetHeight() * self.anchored:GetEffectiveScale() / self:GetEffectiveScale() end
    return self.height
end
function Frame:SetPoint(...) self.point = { ... } end
function Frame:GetPoint() if self.point then return unpack(self.point) end end
function Frame:GetNumPoints() return self.point and 1 or 0 end
function Frame:ClearAllPoints() self.point, self.anchored = nil, nil end
function Frame:SetAllPoints(target) self.anchored = target or self.parent end
function Frame:GetCenter() return 100, 100 end
function Frame:GetEffectiveScale() return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1) end
function Frame:SetScale(scale) self.scale = scale end
function Frame:SetFrameStrata(s) self.strata = s end
function Frame:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM" end
function Frame:SetFrameLevel(l) self.level = l end
function Frame:SetAlpha(alpha) self.alpha = alpha end
function Frame:GetAlpha() return self.alpha or 1 end
function Frame:GetFrameLevel() return self.level or (self.parent and self.parent:GetFrameLevel() + 1) or 1 end
function Frame:SetToplevel(value) self.toplevel = value end
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
function Frame:SetEnabled(value)
    if self.enabled ~= value then self.enabled = value; self:Fire(value and "OnEnable" or "OnDisable") end
end
function Frame:IsEnabled() return self.enabled end
function Frame:Raise() self.raised = true end
function Frame:SetBackdrop(value) self.backdrop = value end
function Frame:SetBackdropColor(...) self.background = { ... } end
function Frame:SetBackdropBorderColor(...) self.borderColor = { ... } end
function Frame:SetTextColor(...) self.textColor = { ... } end
function Frame:SetTextInsets(...) self.insets = { ... } end
function Frame:SetFontObject(value) self.font = value end
function Frame:SetFontString(value) self.caption = value end
function Frame:GetFontString() return self.caption end
function Frame:SetWordWrap(value) self.wordWrap = value end
function Frame:SetTexCoord(...) self.uv = { ... } end
function Frame:SetChecked(value) self.checked = value end
function Frame:GetChecked() return self.checked end
function Frame:SetText(value)
    self.text = value
    if self.caption then self.caption:SetText(value) end
    if self.kind == "EditBox" then self:Fire("OnTextChanged", false) end
end
function Frame:GetText() return self.text or "" end
function Frame:GetStringHeight() return 15 * select(2, self:GetText():gsub("\n", "")) + 15 end
function Frame:SetJustifyH(value) self.justifyH = value end
function Frame:SetJustifyV(value) self.justifyV = value end
function Frame:SetTexture(value) self.texture = value end
function Frame:SetDrawLayer(layer, sublevel) self.layer, self.sublevel = layer, sublevel or 0 end
function Frame:GetDrawLayer() return self.layer, self.sublevel end
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
    if M.keyboardFocus == self then M.keyboardFocus = nil end
    if focused then self:Fire("OnEditFocusLost") end
end
function Frame:SetFocus()
    if M.keyboardFocus and M.keyboardFocus ~= self then M.keyboardFocus:ClearFocus() end
    self.focus, M.keyboardFocus = true, self
    self:Fire("OnEditFocusGained")
end
function Frame:HighlightText() self.highlighted = true end
function Frame:StartMoving() self.moving = true end
function Frame:StopMovingOrSizing() self.moving = false end
function Frame:SetScrollChild(child) self.scrollChild = child end
function Frame:SetVerticalScroll(value) self.verticalScroll = value end
function Frame:CreateTexture(name, layer, _, sublevel)
    local texture = newFrame("Texture", name, self)
    texture:SetDrawLayer(layer or "ARTWORK", sublevel)
    return texture
end
function Frame:CreateFontString(name, layer)
    local text = newFrame("FontString", name, self)
    text:SetDrawLayer(layer or "OVERLAY")
    return text
end
function Frame:SetOwner(owner) self.owner = owner end
function Frame:GetOwner() return self.owner end
function Frame:AddLine(text) self.lines = self.lines or {}; self.lines[#self.lines + 1] = text end
function Frame:SetBagItem(bag, slot)
    self.lines = {}
    for _, callback in ipairs(M.tooltipCallbacks) do callback(self, { type = 0 }) end
    return M.bags[bag] and M.bags[bag][slot] ~= nil
end

CreateFrame = newFrame
function PanelTemplates_TabResize(tab, _, width) tab:SetWidth(width) end
function PanelTemplates_SetTab(frame, id)
    frame.selectedTab = id
    for i = 1, frame.numTabs do
        local tab = frame.Tabs[i]
        tab:SetEnabled(i ~= id)
        for _, part in ipairs({ "Left", "Middle", "Right" }) do
            tab[part]:SetShown(i ~= id)
            tab[part .. "Active"]:SetShown(i == id)
        end
    end
end
UIParent = newFrame("Frame", "UIParent")
UIParent:SetSize(1280, 720)
Minimap = newFrame("Frame", "Minimap", UIParent)
Minimap:SetSize(140, 140)
GameTooltip = newFrame("GameTooltip", "GameTooltip", UIParent)
GameTooltip:Hide()
MerchantFrame = newFrame("Frame", "MerchantFrame", UIParent)
MerchantFrame.selectedTab = 1
MerchantFrame:Hide()
MerchantSellAllJunkButton = newFrame("Button", "MerchantSellAllJunkButton", MerchantFrame)
SendMailFrame = newFrame("Frame", "SendMailFrame", UIParent)
function SendMailFrame:FocusGamepad() end
SendMailFrame:Hide()
SendMailNameEditBox = newFrame("EditBox", "SendMailNameEditBox", SendMailFrame)
SendMailSubjectEditBox = newFrame("EditBox", "SendMailSubjectEditBox", SendMailFrame)
SendMailBodyEditBox = newFrame("EditBox", "SendMailBodyEditBox", SendMailFrame)
SendMailMailButton = newFrame("Button", "SendMailMailButton", SendMailFrame)
BankFrame = newFrame("Frame", "BankFrame", UIParent)
BankFrame.BankPanel = newFrame("Frame", nil, BankFrame)
BankFrame:Hide()
UISpecialFrames, SlashCmdList = {}, {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) M.messages[#M.messages + 1] = message end }
Enum = { BagIndex = { Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5 },
    ItemClass = { Tradegoods = 7, Recipe = 9 },
    BagSlotFlags = { ExcludeJunkSell = 64 },
    BankType = { Character = 0, Account = 2 }, TooltipDataType = { Item = 0 },
    PlayerInteractionType = { MailInfo = 17 } }
C_PlayerInteractionManager = { IsInteractingWithNpcOfType = function(kind)
    assert(kind == Enum.PlayerInteractionType.MailInfo)
    M.mailQueries = (M.mailQueries or 0) + 1
    -- Tests can override the server state independently of BagMarks' event flag.
    if M.mailActive ~= nil then return M.mailActive end
    return M.A and M.A.mailOpen == true or false
end }
C_Bank = { FetchPurchasedBankTabData = function(bankType)
    return { { ID = bankType == 0 and 6 or 15 } }
end }
C_MerchantFrame = { SellAllJunkItems = function() if M.bulkSale then M.bulkSale() end end }
ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
local function at(bag, slot) return M.bags[bag] and M.bags[bag][slot] end
C_Container = {
    GetBackpackSellJunkDisabled = function() return M.excludedBags[0] or false end,
    GetBagSlotFlag = function(bag, flag)
        assert(bag ~= 0 and flag == Enum.BagSlotFlags.ExcludeJunkSell)
        return M.excludedBags[bag] or false
    end,
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
            if i.equipSlot then
                local previous = M.equipped[i.equipSlot]
                M.equipped[i.equipSlot], M.bags[bag][slot] = i, previous
                return
            end
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
    if location.equipmentSlot then return M.equipped[location.equipmentSlot] end
    return at(location.bag, location.slot)
end
C_Cursor = { GetCursorItem = function()
    if M.cursor and not M.cursorLocationMissing then return { cursor = true } end
end }
InputUtil = { IsGamepadUIEnabled = function() return M.gamepad or false end }
C_Item = {
    GetItemNameByID = function(id)
        local item = M.info and M.info[id]
        return item and not item.uncached and (item.secretName or item.name) or nil
    end,
    GetItemIconByID = function(id) return M.info[id] and M.info[id].texture end,
    RequestLoadItemDataByID = function(id) M.requestedItems[id] = (M.requestedItems[id] or 0) + 1 end,
    GetItemInfoInstant = function(id)
        local item = M.info[id]
        if item and not item.missingClass then
            return id, "Type", "Subtype", "", 1, item.class or 15, item.subclass or 0
        end
    end,
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
        for slot, item in pairs(M.equipped or {}) do
            if item.guid == guid then return { equipmentSlot = slot } end
        end
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
        if location and not M.rejectUnlock then locatedItem(location).held = nil end
        if M.reentrantLocks then M.A.eventFrame:Fire("OnEvent", "ITEM_LOCK_CHANGED") end
    end,
    UnlockItem = function(location)
        local item = assert(locatedItem(location), "unlocking absent item")
        M.locationUnlockCalls = (M.locationUnlockCalls or 0) + 1
        -- Keep a single call log for both supported native release paths.
        M.unlockCalls[#M.unlockCalls + 1] = item.guid
        if M.failUnlock then error("release refused") end
        if not M.rejectUnlock then item.held = nil end
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
function UnitFullName(unit)
    assert(unit == "player")
    local name = M.playerName or "Sender"
    local first, surname = name:match("^(%S+) (.+)$")
    return first or name, M.playerSurname or surname
end
UnitNameUnmodified = UnitFullName
function RegionalUniqueNamesEnabled() return M.regionalNames == true end
NameUtil = { GetUnmodifiedUnitFullName = function(unit)
    local first, surname = UnitNameUnmodified(unit)
    return surname and (first .. " " .. surname) or first
end }
function GetNormalizedRealmName() return M.realm or "Realm" end
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
    if i and not i.missingMailDetails then
        local name = i.name or "Test item"
        if i.uncached then name = nil end
        return name, i.itemID, 1, i.count, 1
    end
end
function SendMailFrame_CanSend()
    SendMailMailButton:SetEnabled(SendMailNameEditBox:GetText() ~= "" and SendMailSubjectEditBox:GetText() ~= "")
end
function SendMailFrame_Update()
    -- The buttons retain their last paint even when the server-side slots clear.
    M.mailIcons = {}
    local title
    for slot = 1, ATTACHMENTS_MAX_SEND do
        local name, id, _, count = GetSendMailItem(slot)
        M.mailIcons[slot] = id
        if name and not title then title = count > 1 and (name .. " (" .. count .. ")") or name end
    end
    local subject = SendMailSubjectEditBox:GetText()
    if subject == SendMailFrame.previousItem or (title and subject == "") then
        SendMailSubjectEditBox:SetText(title or "")
        SendMailFrame.previousItem = title or ""
    end
    if not next(M.mailIcons) then SendMailFrame.previousItem = "" end
    SendMailFrame_CanSend()
end
function ClearSendMail()
    M.clearDraftCalls = M.clearDraftCalls + 1
    if M.rejectClearDraft then return end
    for slot, item in pairs(M.attachments) do
        if not (item.guid and M.delivered[item.guid]) then M.returnToBags(item) end
        M.attachments[slot] = nil
    end
    SendMailNameEditBox:SetText(""); SendMailSubjectEditBox:SetText(""); SendMailBodyEditBox:SetText("")
    M.A.eventFrame:Fire("OnEvent", "MAIL_SEND_INFO_UPDATE")
end
function ClickSendMailItemButton(index, clear)
    if clear then
        M.removals[#M.removals + 1] = index
        if M.failRemoval then error("removal refused") end
        if M.rejectRemoval then return end
        local item = M.attachments[index]
        if item and (M.delivered[item.guid] or M.returnToBags(item)) then M.attachments[index] = nil end
        if M.reentrantMail then M.A.eventFrame:Fire("OnEvent", "MAIL_SEND_INFO_UPDATE") end
        return
    end
    if M.rejectMail then return end
    assert(not M.attachments[index], "occupied attachment")
    local mark = M.A.Store:Get(M.cursor.item.guid)
    assert(mark == "mail" or mark == "disenchant", "non-mail attachment")
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
function SendMailFrame_SendMail() assert(M.playerSending, "Send requires a player click") end
function DeleteCursorItem() error("BagMarks must never destroy an item") end
function GetTime() return M.time end
function GetCoinTextureString(value) return value .. " copper" end
function GetCursorPosition() return M.cursorX or 180, M.cursorY or 100 end
function GetMouseFoci() return M.mouseFoci or {} end
function GetCurrentKeyBoardFocus() return M.keyboardFocus end
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
        local option = { text = text, selected = selected, callback = callback }
        function option:AddInitializer(fn) self.initializer = fn end
        self.choices[#self.choices + 1] = option
        return option
    end
    function root:CreateButton(text, callback)
        local child = menuDescription(self.owner)
        child.text, child.callback = text, callback
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
    M.info[i.itemID] = i
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
    M.playerName, M.playerSurname, M.regionalNames, M.realm = nil, nil, nil, nil
    M.requestedItems = {}
    M.A, M.bags, M.info, M.attachments, M.messages, M.sold, M.timers = A, {}, {}, {}, {}, {}, {}
    M.equipped, M.excludedBags = {}, {}
    M.time, M.bindings, M.overrides, M.bindingSet, M.savedBindingSet = 0, {}, nil, 1, nil
    M.cursor, M.rejectSale, M.rejectMail, M.combat, M.alt, M.ctrl, M.shift, M.targeting, M.failKey = nil, nil, nil, false, false, false, false, false, nil
    M.containers, M.bankButtons, M.reads = {}, {}, 0
    M.mouseFoci, M.keyboardFocus = {}, nil
    M.saleAttempts = 0
    M.used, M.groundTarget = {}, false
    M.mailActive, M.mailQueries = nil, 0
    M.mailIcons = {}
    M.clearDraftCalls, M.delivered, M.rejectClearDraft = 0, {}, false
    M.cursorLocationMissing, M.cursorKind, M.gamepad, M.failClear, M.keepCursor, M.clearCalls = nil, nil, false, false, false, 0
    M.lockCalls, M.unlockCalls, M.reentrantLocks, M.reentrantCursor = 0, {}, false, false
    M.locationFailure, M.secretLocation, M.secretLock, M.failLock, M.rejectLock, M.failUnlock = false, false, false, false, false, false
    M.rejectUnlock, M.locationUnlockCalls = false, 0
    M.removals, M.closeMailCalls, M.failRemoval, M.rejectRemoval, M.failCloseMail, M.reentrantMail = {}, 0, false, false, false, false
    M.tradeItems, M.cancelTradeCalls, M.failCancelTrade = {}, 0, false
    M.secretTooltip, M.secretTooltipGUID, M.missingTooltipGUID = false, false, false
    M.buyback, M.buybacks, M.money, M.secretPrice, M.failBuyback, M.rejectBuyback, M.reentrantBuyback = {}, {}, 10000, false, false, false, false
    M.bulkSale = nil
    for key, value in pairs(A.Protection) do
        if type(value) ~= "function" then A.Protection[key] = nil end
    end
    A.Protection.held = {}
    BagMarksDB, BagMarksCharDB = nil, nil
    A.Store:Initialize()
    A.mode, A.merchantOpen, A.mailOpen, A.bankOpen, A.tradeOpen, A.pendingRefresh = false, false, false, false, false, false
    A.auctionOpen = false
    A.Mail:Close()
    A.Bags.overlays, A.Bags.inputOwners = {}, {}
    A.Bags:RefreshCombatInput()
    A.Hover:Refresh()
    EUI_Bags = nil
    if A.Ellesmere then A.Ellesmere.slots, A.Ellesmere.registered = {}, nil end
    M.nativeClicks, M.menu = 0, nil
    A.inventory = {}
    A.Operations:Cancel()
    A.Bindings.history = {}
    A.Settings.bindingAction = A.Bindings.action
    A.Bindings:StopCapture()
    A.Settings.frame:Hide()
    if A.Settings.ruleFrame then A.Settings.ruleFrame:Hide() end
    A.Settings.rulesQueued, A.Settings.requestedRuleItems = nil, {}
    A.Settings.clearRuleFilters:Fire("OnClick")
    A.Settings:SelectTab("General")
    if A.Diagnostics.frame then A.Diagnostics.frame:Hide() end
    MerchantFrame:Hide(); SendMailFrame:Hide(); BankFrame:Hide()
    SendMailNameEditBox:SetText("")
    SendMailSubjectEditBox:SetText("")
    SendMailBodyEditBox:SetText(""); SendMailMailButton:SetEnabled(false)
    SendMailFrame.previousItem = nil
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
