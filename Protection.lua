-- Native holds and transfer checks are best-effort client safeguards. A saved
-- Locked mark is persistent intent; held tracks acquisitions, including those
-- whose release has not yet been verified. releases never grants ownership.
local _, A = ...
local Protection = { held = {} }
A.Protection = Protection
A.protectionRevision = "merchant-mail-4" -- Identifies protection behavior in support reports.

local function guid(value)
    if A.Safe(value) and type(value) == "string" and value:match("^Item%-") then return value end
end

local function read(fn, ...)
    -- Optional APIs may be missing, throw, or return restricted data. Return
    -- only readable results; nil remains distinct from an explicit true/false.
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

function Protection:QueueCursorCheck()
    if self.cursorCheck or self.checkingCursor or self.stopping then return end
    -- CURSOR_CHANGED runs inside PickupContainerItem. Clearing there interrupts
    -- a sort's pickup/place sequence. Inspect the live cursor on the next frame;
    -- never carry a queued GUID forward onto a different cursor item.
    local ticket = {}
    self.cursorCheck = ticket
    C_Timer.After(0, function()
        if self.cursorCheck ~= ticket or self.stopping then return end
        self.cursorCheck, self.checkingCursor = nil, true
        self.cursorChecks = (self.cursorChecks or 0) + 1
        self:ReturnCursor()
        self:SyncHolds()
        A.Bags:Refresh()
        A.Operations:RefreshButtons()
        A.Hover:Refresh()
        self.checkingCursor = false
    end)
end

function Protection:ReturnCursor(requested, deleting)
    if self.returning or not A.IsEnabled() then return false end
    -- Ordinary pickup is also how players drag gear onto their character. Only
    -- return it during a transfer/targeting context or a deletion confirmation.
    -- A Locked mark protects against loss; it must not prevent equipping/use.
    if not deleting and not self:RiskyContext() then return false end
    requested = guid(requested)
    local current = self:CursorGUID()
    -- A deletion event can refer to an older cursor item. Never clear a different
    -- item just because the event's GUID was marked Locked.
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
    -- Clearing the cursor may immediately emit CURSOR_CHANGED and reenter us.
    self.returning = true
    local ok = type(ClearCursor) == "function" and pcall(ClearCursor)
    self.returning = false
    if not ok or read(GetCursorInfo) == "item" then
        A.Print("Could not return the Locked item. Cancel the action and keep the item.")
        return false
    end
    self.cursorReturns = (self.cursorReturns or 0) + 1
    if deleting and InputUtil and read(InputUtil.IsGamepadUIEnabled) == true then
        A.Print("Locked item returned. Cancel any remaining gamepad deletion confirmation.")
    else
        A.Print("Locked item protected. Clear its BagMarks mark before selling, mailing, trading, or deleting it.")
    end
    return true
end

function Protection:VerifyRelease(itemGUID, request)
    if not self.releases or self.releases[itemGUID] ~= request then return false end
    local location = C_Item and read(C_Item.GetItemLocation, itemGUID)
    if location and read(C_Item.DoesItemExist, location) == true
        and guid(read(C_Item.GetItemGUID, location)) == itemGUID
        and read(C_Item.IsLocked, location) == false then
        self.held[itemGUID], self.releases[itemGUID] = nil, nil
        return true
    end
    if request.state ~= "waiting" or request.pending then return false end
    if self.stopping or GetTime() >= request.deadline then
        request.state = "unverified"
        if not self.stopping then
            self:WarnOnce("release:" .. itemGUID, "The client still reports an item busy after BagMarks requested its release. No further unlock requests were sent. Use /bm debug for its status.")
        end
        return false
    end
    -- A successful API call has no acknowledgement result. Observe for at most
    -- two seconds; never spam unlocks while a sort/server move may still be busy.
    request.pending = true
    C_Timer.After(.2, function()
        if not self.releases or self.releases[itemGUID] ~= request then return end
        request.pending = nil
        if self:VerifyRelease(itemGUID, request) then self:SyncHolds() end
    end)
    return false
end

function Protection:Release(guidToRelease)
    if not self.held[guidToRelease] or self.releasing then return end
    self.releases = self.releases or {}
    local request = self.releases[guidToRelease]
    if request and request.state ~= "error" then self:VerifyRelease(guidToRelease, request); return end
    -- The client has no ownership token. Release only a recorded acquisition.
    -- Pair LockItem(location) with the native location-based unlock when the
    -- live GUID matches. A moved/reused slot must never select another copy.
    local location = C_Item and read(C_Item.GetItemLocation, guidToRelease)
    local matches = location and read(C_Item.DoesItemExist, location) == true
        and guid(read(C_Item.GetItemGUID, location)) == guidToRelease
    if matches and read(C_Item.IsLocked, location) == false then
        self.held[guidToRelease], self.releases[guidToRelease] = nil, nil
        return
    end
    request = { state = "waiting", deadline = GetTime() + 2 }
    self.releases[guidToRelease] = request
    self.releasing = true -- Unlock notifications can arrive synchronously.
    local ok
    if matches and type(C_Item.UnlockItem) == "function" then
        request.method = "location"
        ok = pcall(C_Item.UnlockItem, location)
    end
    if not ok and C_Item and type(C_Item.UnlockItemByGUID) == "function" then
        request.method = "GUID"
        ok = pcall(C_Item.UnlockItemByGUID, guidToRelease)
    end
    self.releasing = false
    if not ok then request.state = "error"; return end
    self:VerifyRelease(guidToRelease, request)
end

function Protection:RiskyContext()
    if A.merchantOpen or A.mailOpen or A.tradeOpen or A.auctionOpen then return true end
    -- Match the native container's two item-target paths. Ground targeting from
    -- an item's own spell must not hold that item mid-use. Missing optional
    -- targeting APIs must not turn every normal use/equip into a permanent hold.
    local itemTarget, idTarget = read(SpellCanTargetItem), read(SpellCanTargetItemID)
    if itemTarget == true or idTarget == true then return true end
    if itemTarget == false and idTarget == false then return false end
    return read(SpellIsTargeting) == true
end

-- Locked marks cover every risky context. Mail marks reserve items at vendors.
function Protection:GuardsMark(state)
    return state == "locked" or (state == "mail" and A.merchantOpen)
end

function Protection:SyncHolds()
    -- Lock/unlock calls can emit ITEM_LOCK_CHANGED before they return. This
    -- guard prevents nested synchronization from acquiring/releasing twice.
    if self.syncing or self.releasing then return end
    self.syncing = true
    local enabled = A.IsEnabled() and not self.stopping
    local risk = enabled and self:RiskyContext()
    self.holdsAvailable = C_Item and type(C_Item.GetItemLocation) == "function"
        and type(C_Item.DoesItemExist) == "function" and type(C_Item.IsLocked) == "function"
        and type(C_Item.LockItem) == "function" and type(C_Item.UnlockItemByGUID) == "function" or false
    for heldGUID in pairs(self.held) do
        if not risk or not self:GuardsMark(A.Store:Get(heldGUID)) then self:Release(heldGUID) end
    end
    if enabled and risk then
        for itemGUID, mark in pairs(A.char.marks) do
            if self:GuardsMark(mark.state) and (mark.state == "locked" or (A.inventory and A.inventory[itemGUID])) then
                if self.holdsAvailable then
                    local location = read(C_Item.GetItemLocation, itemGUID)
                    if location and read(C_Item.DoesItemExist, location) == true
                        and guid(read(C_Item.GetItemGUID, location)) == itemGUID then
                        if read(C_Item.IsLocked, location) == false then
                            -- Set ownership before potentially synchronous events.
                            -- Invalidate an earlier release check so its callback
                            -- cannot discard this new hold after a context opens.
                            if self.releases then self.releases[itemGUID] = nil end
                            self.held[itemGUID] = true
                            local ok = pcall(C_Item.LockItem, location)
                            if not ok or read(C_Item.IsLocked, location) ~= true then
                                self.held[itemGUID] = nil
                                self:WarnOnce(itemGUID, "Could not hold an item marked " .. A.states[mark.state] .. ". Check it before completing the action.")
                            end
                        end
                    end
                else
                    self:WarnOnce("holds", "Native item holds are unavailable. Check your protected items before completing the action.")
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
    -- Inspect outgoing slots, including the enchant slot. Cancellation is a
    -- request to the client, not proof that a trade has already been prevented.
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
            -- Use the native attachment's right-click removal path. If it fails
            -- or is still pending, request mailbox closure and warn the player.
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
    return items, count
end

function Protection:ObserveBulkSales()
    if self.observingBulk or not C_MerchantFrame or type(C_MerchantFrame.SellAllJunkItems) ~= "function" then return end
    self.observingBulk = true
    hooksecurefunc(C_MerchantFrame, "SellAllJunkItems", function()
        if not A.IsEnabled() then return end
        -- A seller can repeat this call with a backoff while its earlier sales settle.
        local now = GetTime()
        self.bulkSaleUntil = now + (self.bulkSaleUntil and self.bulkSaleUntil > now and 2 or .6)
    end)
end

function Protection:MerchantOpened()
    local bulkSaleUntil = self.bulkSaleUntil -- Another MERCHANT_SHOW handler may already have sold.
    self:MerchantClosed()
    self.bulkSaleUntil = bulkSaleUntil
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
    self.bulkSaleUntil = nil
end

function Protection:QueueBuybackCheck(delay)
    if self.buybackTimer then return end
    -- Clearing this ticket on merchant close invalidates an already queued
    -- timer, so a callback from an old visit cannot restore items in a new one.
    local ticket = {}
    self.buybackTimer = ticket
    C_Timer.After(delay or .1, function()
        if self.buybackTimer ~= ticket then return end
        self.buybackTimer = nil
        self:CheckBuyback()
    end)
end

function Protection:CheckBuyback()
    if self.restoring or self.buybackStopped or self.stopping or not A.CanAct() or not A.merchantOpen then return end
    local items, count = self:BuybackItems()
    if not items then
        if self.buybackPending then
            if GetTime() < self.buybackPending.deadline then self:QueueBuybackCheck()
            else
                self.buybackPending = nil
                self.buybackStopped = true
                A.Print("Could not verify the protected item's return. Check your bags and buyback before leaving the merchant.")
            end
        end
        return
    end
    if not self.historicalBuyback then self.historicalBuyback = items; return end
    local pending = self.buybackPending
    if pending then
        -- A disappearing buyback row alone is not success. Verify that the same
        -- GUID is now accessible to the player before reporting its return.
        local location = not items[pending.guid] and C_Item and read(C_Item.GetItemLocation, pending.guid)
        local returned = location and read(C_Item.DoesItemExist, location) == true
            and guid(read(C_Item.GetItemGUID, location)) == pending.guid
        if returned then
            self.buybackPending = nil
            self.buybackAttempts[pending.guid] = "returned"
            A.Store:RefreshInventory()
            self:SyncHolds()
            A.Print("An item marked " .. pending.label .. " was sold and bought back. Check your bags before leaving the merchant.")
        elseif GetTime() < pending.deadline then
            self:QueueBuybackCheck()
            return -- One request at a time; a changing list must never select another item.
        else
            self.buybackPending = nil
            self.buybackStopped = true
            A.Print("Could not verify the protected item's return. Buy it back manually before leaving the merchant.")
            return -- An unacknowledged request could still shift the server's list later.
        end
    end
    self.buybackAttempts = self.buybackAttempts or {}
    for itemGUID in pairs(self.historicalBuyback) do
        if not items[itemGUID] then self.historicalBuyback[itemGUID] = nil end
    end
    local bulkDelay = (self.bulkSaleUntil or 0) - GetTime()
    local deferred = false
    for itemGUID, index in pairs(items) do
        local state = A.Store:Get(itemGUID)
        local protected = self:GuardsMark(state) and not self.historicalBuyback[itemGUID]
        local attempt = self.buybackAttempts[itemGUID]
        if protected and attempt == "returned" then
            -- A competing seller took it again. Do not start a sale/buyback loop.
            self.buybackAttempts[itemGUID] = "warned"
            A.Print("An item marked " .. A.states[state] .. " was sold again. Pause the other junk seller and buy it back manually.")
        elseif protected and not attempt and bulkDelay > 0 and count - index < (BUYBACK_ITEMS_PER_PAGE or 12) - 3 then
            -- The newest entry is at index count. Recover older items promptly if
            -- further sales could push them off the list during the bulk sweep.
            deferred = true
        elseif protected and not attempt then
            self.buybackAttempts[itemGUID] = "requested"
            local warning = "An item marked " .. A.states[state] .. " was sold. Buy it back manually before leaving the merchant."
            local ok, price
            if type(GetBuybackItemInfo) == "function" then
                local success, name, texture, value = pcall(GetBuybackItemInfo, index)
                ok, price = success, value
            end
            local money = read(GetMoney)
            -- Buyback indexes shift after purchases. Recheck the GUID at the
            -- chosen index immediately before spending the verified amount.
            if ok and A.Safe(price) and type(price) == "number" and price >= 0
                and type(money) == "number" and money >= price and type(BuybackItem) == "function"
                and self:TooltipGUID(C_TooltipInfo.GetBuybackItem, index) == itemGUID then
                self.restoring = true
                self.buybackPending = { guid = itemGUID, label = A.states[state], deadline = GetTime() + 2 }
                local restored = pcall(BuybackItem, index)
                self.restoring = false
                if not restored then
                    self.buybackPending = nil
                    self.buybackStopped = true
                    A.Print(warning)
                end
            else
                A.Print(warning)
            end
            self:QueueBuybackCheck()
            return -- Resolve shifts in the buyback list on its next update.
        end
    end
    if deferred then self:QueueBuybackCheck(bulkDelay) end
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
    -- Logout releases our native holds while keeping saved marks for next login.
    self.stopping = true
    self.cursorCheck = nil
    self:MerchantClosed()
    self:SyncHolds()
end
