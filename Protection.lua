local _, A = ...
local Protection = { held = {} }
A.Protection = Protection

local function guid(value)
    if A.Safe(value) and type(value) == "string" and value:match("^Item%-") then return value end
end

local function read(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok and A.Safe(value) then return value end
end

function Protection:WarnOnce(key, message)
    self.warnings = self.warnings or {}
    if self.warnings[key] then return end
    self.warnings[key] = true
    A.Print(message)
end

function Protection:CursorGUID()
    local location = C_Cursor and read(C_Cursor.GetCursorItem)
    if location and C_Item and read(C_Item.DoesItemExist, location) == true then
        return guid(read(C_Item.GetItemGUID, location))
    end
end

function Protection:ReturnCursor(requested, deleting)
    if self.returning or not A.IsEnabled() then return false end
    requested = guid(requested)
    local current = self:CursorGUID()
    if requested and current and requested ~= current then
        if A.Store:Get(requested) == "locked" then A.Print("Locked item: cancel this deletion. The cursor no longer matches.") end
        return false
    end
    local target = requested or current
    if not target or A.Store:Get(target) ~= "locked" then return false end
    if read(GetCursorInfo) ~= "item" then
        if deleting then A.Print("Locked item: cancel this deletion. This path does not use the cursor.") end
        return false
    end
    self.returning = true
    local ok = type(ClearCursor) == "function" and pcall(ClearCursor)
    self.returning = false
    if not ok or read(GetCursorInfo) == "item" then
        A.Print("Could not return the Locked item. Cancel the action and keep the item.")
        return false
    end
    if deleting and InputUtil and read(InputUtil.IsGamepadUIEnabled) == true then
        A.Print("Locked item returned. Cancel any remaining gamepad deletion confirmation.")
    else
        A.Print("Locked item protected. Clear its BagMarks mark before moving or transferring it.")
    end
    return true
end

function Protection:Release(guidToRelease)
    if not self.held[guidToRelease] then return end
    -- The client has no ownership token. Never unlock an item that was already
    -- held when BagMarks inspected it; release only our successful acquisitions.
    if C_Item and type(C_Item.UnlockItemByGUID) == "function" then
        self.held[guidToRelease] = nil
        local ok = pcall(C_Item.UnlockItemByGUID, guidToRelease)
        if not ok then self.held[guidToRelease] = true end
    end
end

function Protection:RiskyContext()
    if A.merchantOpen or A.mailOpen or A.tradeOpen or A.bankOpen or A.auctionOpen then return true end
    -- Match the native container's two item-target paths. Ground targeting from
    -- a reusable item's own spell must not hold that item mid-use. Unknown
    -- targeting data stays conservative, including on older client revisions.
    local itemTarget, idTarget = read(SpellCanTargetItem), read(SpellCanTargetItemID)
    if itemTarget == true or idTarget == true then return true end
    if itemTarget == false and idTarget == false then return false end
    return read(SpellIsTargeting) ~= false
end

function Protection:SyncHolds()
    if self.syncing then return end
    self.syncing = true
    local enabled = A.IsEnabled() and not self.stopping
    self.holdsAvailable = C_Item and type(C_Item.GetItemLocation) == "function"
        and type(C_Item.DoesItemExist) == "function" and type(C_Item.IsLocked) == "function"
        and type(C_Item.LockItem) == "function" and type(C_Item.UnlockItemByGUID) == "function" or false
    for heldGUID in pairs(self.held) do
        if not enabled or A.Store:Get(heldGUID) ~= "locked" then self:Release(heldGUID) end
    end
    if enabled then
        local risk = self:RiskyContext()
        for itemGUID, mark in pairs(A.char.marks) do
            if mark.state == "locked" then
                if self.holdsAvailable then
                    local location = read(C_Item.GetItemLocation, itemGUID)
                    if location and read(C_Item.DoesItemExist, location) == true
                        and guid(read(C_Item.GetItemGUID, location)) == itemGUID then
                        if not risk and A.API:IsReusable(location) then
                            -- Release only our own native hold, never the saved
                            -- Locked mark. Cursor/deletion guards remain active.
                            self:Release(itemGUID)
                        elseif read(C_Item.IsLocked, location) == false then
                            -- Set ownership before potentially synchronous events.
                            self.held[itemGUID] = true
                            local ok = pcall(C_Item.LockItem, location)
                            if not ok or read(C_Item.IsLocked, location) ~= true then
                                self.held[itemGUID] = nil
                                self:WarnOnce(itemGUID, "Could not hold a Locked item. Avoid transferring or destroying it until the client allows protection.")
                            end
                        end
                    end
                else
                    self:WarnOnce("holds", "Native item holds are unavailable. Locked-item protection is limited on this client.")
                end
            end
        end
    end
    self.syncing = false
end

function Protection:TooltipGUID(fn, index)
    local data = read(fn, index)
    return type(data) == "table" and guid(data.guid) or nil
end

function Protection:CheckTrade()
    if self.checkingTrade or not A.IsEnabled() or not A.tradeOpen or not C_TooltipInfo then return end
    for slot = 1, (MAX_TRADE_ITEMS or 7) do
        local itemGUID = self:TooltipGUID(C_TooltipInfo.GetTradePlayerItem, slot)
        if itemGUID and A.Store:Get(itemGUID) == "locked" then
            self.checkingTrade = true
            local ok = type(CancelTrade) == "function" and pcall(CancelTrade)
            self.checkingTrade = false
            A.Print(ok and "Trade cancellation requested to protect a Locked item. Clear its mark before trading it."
                or "Locked item in the trade. Cancel the trade now; the client refused automatic cancellation.")
            return
        end
    end
end

function Protection:CheckMail()
    if self.checkingMail or not A.IsEnabled() or not A.mailOpen or not C_TooltipInfo then return end
    self.checkingMail = true
    local limit = ATTACHMENTS_MAX_SEND or 12
    -- Rescan after each removal in case the client shifts attachment indexes.
    for _ = 1, limit do
        local slot
        for index = 1, limit do
            local itemGUID = self:TooltipGUID(C_TooltipInfo.GetSendMailItem, index)
            if itemGUID and A.Store:Get(itemGUID) == "locked" then slot = index; break end
        end
        if slot then
            -- This is the native attachment's right-click removal path. A failed
            -- or still-pending removal closes the mailbox before a user can send.
            local ok = type(ClickSendMailItemButton) == "function" and pcall(ClickSendMailItemButton, slot, true)
            if ok and read(HasSendMailItem, slot) == false then
                A.Print("Locked attachment removed. Clear its mark before mailing it.")
            else
                local closed = type(CloseMail) == "function" and pcall(CloseMail)
                A.Print(closed and "Mailbox closure requested to protect a Locked attachment. Check that your items returned."
                    or "Locked attachment: do not send this mail. Remove the item or close the mailbox.")
                break
            end
        else break end
    end
    self.checkingMail = false
end

function Protection:BuybackItems()
    local items = {}
    local count = read(GetNumBuybackItems)
    if not C_TooltipInfo or type(count) ~= "number" then return end
    for index = 1, count do
        local itemGUID = self:TooltipGUID(C_TooltipInfo.GetBuybackItem, index)
        if not itemGUID then return end -- Cannot distinguish old entries from new ones yet.
        items[itemGUID] = index
    end
    return items
end

function Protection:MerchantOpened()
    self:MerchantClosed()
    self.enabled = A.IsEnabled()
    self.buybackAttempts = {}
    -- Existing buyback entries may predate this session. Never spend money to
    -- retrieve historical items just because their old GUID mark still exists.
    self.historicalBuyback = self:BuybackItems()
end

function Protection:MerchantClosed()
    self.buybackTimer, self.buybackPending, self.historicalBuyback = nil, nil, nil
    self.buybackAttempts = {}
    self.buybackStopped = false
end

function Protection:QueueBuybackCheck()
    if self.buybackTimer then return end
    local ticket = {}
    self.buybackTimer = ticket
    C_Timer.After(.1, function()
        if self.buybackTimer ~= ticket then return end
        self.buybackTimer = nil
        self:CheckBuyback()
    end)
end

function Protection:CheckBuyback()
    if self.restoring or self.buybackStopped or self.stopping or not A.CanAct() or not A.merchantOpen then return end
    local items = self:BuybackItems()
    if not items then
        if self.buybackPending then
            if GetTime() < self.buybackPending.deadline then self:QueueBuybackCheck()
            else
                self.buybackPending = nil
                self.buybackStopped = true
                A.Print("Could not verify a Locked item's return. Check your bags and buyback before leaving the merchant.")
            end
        end
        return
    end
    if not self.historicalBuyback then self.historicalBuyback = items; return end
    local pending = self.buybackPending
    if pending then
        local location = not items[pending.guid] and C_Item and read(C_Item.GetItemLocation, pending.guid)
        local returned = location and read(C_Item.DoesItemExist, location) == true
            and guid(read(C_Item.GetItemGUID, location)) == pending.guid
        if returned then
            self.buybackPending = nil
            self:SyncHolds()
            A.Print("A Locked item was sold and bought back. Check your bags before leaving the merchant.")
        elseif GetTime() < pending.deadline then
            self:QueueBuybackCheck()
            return -- One request at a time; a changing list must never select another item.
        else
            self.buybackPending = nil
            self.buybackStopped = true
            A.Print("Could not verify a Locked item's return. Buy it back manually before leaving the merchant.")
            return -- An unacknowledged request could still shift the server's list later.
        end
    end
    self.buybackAttempts = self.buybackAttempts or {}
    for itemGUID in pairs(self.buybackAttempts) do
        if not items[itemGUID] then self.buybackAttempts[itemGUID] = nil end
    end
    for itemGUID in pairs(self.historicalBuyback) do
        if not items[itemGUID] then self.historicalBuyback[itemGUID] = nil end
    end
    for itemGUID, index in pairs(items) do
        if A.Store:Get(itemGUID) == "locked" and not (self.historicalBuyback and self.historicalBuyback[itemGUID])
            and not self.buybackAttempts[itemGUID] then
            self.buybackAttempts[itemGUID] = true -- No automatic retry after a refusal.
            local ok, price
            if type(GetBuybackItemInfo) == "function" then
                local success, name, texture, value = pcall(GetBuybackItemInfo, index)
                ok, price = success, value
            end
            local money = read(GetMoney)
            if ok and A.Safe(price) and type(price) == "number" and price >= 0
                and type(money) == "number" and money >= price and type(BuybackItem) == "function"
                and self:TooltipGUID(C_TooltipInfo.GetBuybackItem, index) == itemGUID then
                self.restoring = true
                self.buybackPending = { guid = itemGUID, deadline = GetTime() + 2 }
                local restored = pcall(BuybackItem, index)
                self.restoring = false
                if not restored then
                    self.buybackPending = nil
                    self.buybackStopped = true
                    A.Print("A Locked item was sold. Buy it back manually before leaving the merchant.")
                end
            else
                A.Print("A Locked item was sold. Buy it back manually before leaving the merchant.")
            end
            self:QueueBuybackCheck()
            return -- Resolve shifts in the buyback list on its next update.
        end
    end
end

function Protection:Refresh()
    if self.refreshing then return end
    self.refreshing = true
    local enabled = A.IsEnabled()
    if self.enabled ~= enabled then
        self.enabled = enabled
        if enabled and A.merchantOpen then self:MerchantOpened() else self:MerchantClosed() end
    end
    if enabled then
        self:ReturnCursor()
        self:CheckTrade()
        self:CheckMail()
        self:CheckBuyback()
    end
    self:SyncHolds()
    self.refreshing = false
end

function Protection:Stop()
    self.stopping = true
    self:MerchantClosed()
    self:SyncHolds()
end
