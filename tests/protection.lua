-- Behavioral regressions for the protection layer. Native API effects here are
-- simulations, not evidence that the Forever client enforces every hold.
return function(M, A, test, eq, mark)
    local function event(name, ...) A.eventFrame:Fire("OnEvent", name, ...) end
    local function message(pattern)
        for _, line in ipairs(M.messages) do if line:find(pattern, 1, true) then return true end end
        return false
    end
    local function openMerchant()
        MerchantFrame:Show()
        event("MERCHANT_SHOW")
        M.tick(0)
    end
    local function forceSale(bag, slot)
        local item = assert(M.bags[bag][slot])
        item.held = nil -- Model an external seller bypassing the native hold.
        M.bags[bag][slot] = nil
        M.buyback[#M.buyback + 1] = item
        M.money = M.money + (item.price or 100)
        return item
    end
    local function offer(item, bag, slot, target, index)
        item.held = nil -- Model an offer that passed the primary hold.
        M.bags[bag][slot] = nil
        target[index or 1] = item
    end

    test("native hold blocks ordinary pickup and use of only the Locked instance", function()
        local locked = mark("Item-L", 0, 1, "locked")
        local normal = M.item("Item-N", 0, 2)
        mark("Item-J", 0, 3, "junk"); mark("Item-M", 0, 4, "mail")
        eq(locked.held, true); eq(normal.held, nil); eq(M.lockCalls, 1)
        C_Container.PickupContainerItem(0, 1); eq(M.cursor, nil)
        C_Container.UseContainerItem(0, 1); eq(#M.sold, 0); eq(M.bags[0][1], locked)
        C_Container.PickupContainerItem(0, 2); eq(M.cursor.item, normal)
        event("CURSOR_CHANGED"); eq(M.clearCalls, 0)
    end)

    test("clearing or changing a Locked mark immediately releases its own hold", function()
        local item = mark("Item-L", 0, 1, "locked")
        for _, state in ipairs({ "junk", "mail", "normal" }) do
            A.Store:Set(A.API:Read(0, 1), state ~= "normal" and state or nil)
            eq(item.held, nil)
            C_Container.PickupContainerItem(0, 1); eq(M.cursor.item, item); ClearCursor()
            A.Store:Set(A.API:Read(0, 1), "locked"); eq(item.held, true)
        end
        eq(#M.unlockCalls, 3)
    end)

    test("disabling releases owned holds, reenabling and reload reapply saved marks", function()
        local item = mark("Item-L", 0, 1, "locked")
        A.SetOption("enabled", false); eq(item.held, nil); eq(A.Store:Get(item.guid), "locked")
        A.SetOption("enabled", true); eq(item.held, true)
        event("PLAYER_LOGOUT"); eq(item.held, nil)
        A.Protection.stopping = nil; A.Store:Initialize()
        event("PLAYER_LOGIN"); M.tick(0); eq(item.held, true)
    end)

    test("preexisting native holds are never acquired or released by BagMarks", function()
        local item = mark("Item-Foreign", 0, 1, "locked", { held = true })
        local busy = mark("Item-Busy", 0, 2, "locked", { busy = true })
        eq(M.lockCalls, 0)
        A.SetOption("enabled", false); event("PLAYER_LOGOUT")
        eq(#M.unlockCalls, 0); eq(item.held, true); eq(busy.busy, true)
    end)

    test("lost holds are reacquired without reentrant lock-event loops", function()
        M.reentrantLocks = true
        local item = mark("Item-L", 0, 1, "locked")
        M.tick(0); eq(M.lockCalls, 1)
        item.held = nil; event("ITEM_LOCK_CHANGED", 0, 1); M.tick(0)
        eq(item.held, true); eq(M.lockCalls, 2)
        A.Store:Set(A.API:Read(0, 1), nil); M.tick(0)
        eq(item.held, nil); eq(#M.unlockCalls, 1); eq(next(M.timers), nil)
    end)

    test("closed-bank marks receive a hold when their exact GUID becomes accessible", function()
        A.bankOpen = true
        local item = mark("Item-Bank", 6, 1, "locked")
        event("PLAYER_LOGOUT"); A.Protection.stopping = nil
        A.bankOpen = false; A.Refresh(); eq(item.held, nil)
        event("BANKFRAME_OPENED"); M.tick(0); eq(item.held, true)
        local replacement = M.item("Item-Other", 6, 1)
        A.Refresh(); eq(replacement.held, nil); eq(A.Store:Get(item.guid), "locked")
    end)

    test("failed native acquisitions warn without claiming ownership or unlocking foreign state", function()
        M.rejectLock = true
        local item = mark("Item-L", 0, 1, "locked")
        eq(A.Protection.held[item.guid], nil); assert(message("Could not hold"))
        A.Refresh(); A.Refresh(); eq(#M.messages, 1)
        M.rejectLock = false; item.held = true
        A.Refresh(); A.SetOption("enabled", false)
        eq(#M.unlockCalls, 0); eq(item.held, true)
    end)

    test("throwing and missing native hold APIs keep marks and do not crash", function()
        M.failLock = true
        local item = mark("Item-L", 0, 1, "locked")
        eq(A.Protection.held[item.guid], nil); eq(item.held, nil)
        M.failLock = false
        local original = C_Item.LockItem
        C_Item.LockItem = nil; A.Refresh(); A.Refresh()
        eq(A.Protection.holdsAvailable, false); assert(message("holds are unavailable"))
        C_Item.LockItem = original; A.Refresh(); eq(item.held, true)
    end)

    test("unknown or secret native locations and lock state never select an identical copy", function()
        M.secretLocation = true
        local item = mark("Item-L", 0, 1, "locked")
        local other = M.item("Item-Other", 0, 2)
        A.Refresh(); eq(M.lockCalls, 0)
        M.secretLocation = false; M.locationFailure = true; A.Refresh(); eq(M.lockCalls, 0)
        M.locationFailure = false; M.secretLock = true; A.Refresh(); eq(M.lockCalls, 0)
        M.secretLock = false; A.Refresh(); eq(item.held, true); eq(other.held, nil)
    end)

    test("a stale GUID lookup cannot hold a replacement item at that location", function()
        local locked = mark("Item-L", 0, 1, "locked")
        local other = M.item("Item-Other", 0, 2)
        locked.held = nil
        local original = C_Item.GetItemLocation
        C_Item.GetItemLocation = function() return { bag = 0, slot = 2 } end
        A.Refresh(); eq(locked.held, nil); eq(other.held, nil); eq(M.lockCalls, 1)
        C_Item.GetItemLocation = original; A.Refresh(); eq(locked.held, true)
    end)

    test("a refused release is retried for the same owned GUID", function()
        local item = mark("Item-L", 0, 1, "locked")
        M.failUnlock = true
        A.Store:Set(A.API:Read(0, 1), nil); eq(item.held, true)
        eq(A.Protection.held[item.guid], true)
        M.failUnlock = false; A.Refresh(); eq(item.held, nil)
        eq(A.Protection.held[item.guid], nil)
    end)

    test("native holds and cursor fallback remain active while marking pauses in combat", function()
        local item = mark("Item-L", 0, 1, "locked")
        M.combat = true; event("PLAYER_REGEN_DISABLED")
        eq(item.held, true); eq(A.CanAct(), false)
        M.forcePickup(0, 1); event("CURSOR_CHANGED"); M.tick(0)
        eq(M.cursor, nil); eq(M.bags[0][1], item)
        item.held = nil; event("ITEM_LOCK_CHANGED"); eq(item.held, true)
        A.Settings:Toggle(); A.Settings:Toggle()
        A.SetOption("enabled", false); eq(item.held, nil)
    end)

    test("cursor fallback returns a known Locked GUID after cursor changes settle without recursion", function()
        local item = mark("Item-L", 0, 1, "locked")
        M.forcePickup(0, 1); M.reentrantCursor = true
        event("CURSOR_CHANGED"); M.tick(0)
        eq(M.cursor, nil); eq(M.bags[0][1], item); eq(M.clearCalls, 1)
    end)

    test("delete event GUID works even when cursor location is unavailable", function()
        local item = mark("Item-L", 0, 1, "locked")
        M.forcePickup(0, 1); M.cursorLocationMissing = true
        event("DELETE_ITEM_CONFIRM", "Test item", 3, 1, 0, item.guid)
        eq(M.cursor, nil); eq(M.clearCalls, 1); eq(M.bags[0][1], item)
    end)

    test("delete with a missing or secret event GUID uses only the readable cursor GUID", function()
        local item = mark("Item-L", 0, 1, "locked")
        for _, secret in ipairs({ false, true }) do
            M.forcePickup(0, 1)
            event("DELETE_ITEM_CONFIRM", "Test item", 3, 1, 0, secret and M.secret or nil)
            eq(M.cursor, nil); eq(M.bags[0][1], item)
        end
    end)

    test("destruction fallback leaves Normal Junk and Mail copies untouched", function()
        mark("Item-L", 0, 1, "locked")
        for index, state in ipairs({ "normal", "junk", "mail" }) do
            local item = M.item("Item-" .. index, 0, index + 1)
            if state ~= "normal" then A.Store:Set(A.API:Read(0, index + 1), state) end
            C_Container.PickupContainerItem(0, index + 1)
            local calls = M.clearCalls
            event("CURSOR_CHANGED"); event("DELETE_ITEM_CONFIRM", "Test item", 3, 1, 0, item.guid)
            eq(M.cursor.item, item); eq(M.clearCalls, calls); ClearCursor()
        end
    end)

    test("unreadable identity and stale deletion events never return an unrelated copy", function()
        local locked = mark("Item-L", 0, 1, "locked")
        local other = M.item("Item-Other", 0, 2)
        C_Container.PickupContainerItem(0, 2)
        event("DELETE_ITEM_CONFIRM", "Test item", 3, 1, 0, locked.guid)
        eq(M.cursor.item, other); eq(M.clearCalls, 0); assert(message("no longer matches"))
        M.cursorLocationMissing = true
        event("DELETE_ITEM_CONFIRM", "Test item", 3, 1, 0, M.secret)
        eq(M.cursor.item, other); eq(M.clearCalls, 0)
    end)

    test("failed or pending cursor returns warn instead of claiming protection", function()
        mark("Item-L", 0, 1, "locked"); M.forcePickup(0, 1)
        M.failClear = true; eq(A.Protection:ReturnCursor(nil, true), false)
        assert(M.cursor); assert(message("Could not return"))
        M.failClear = false; M.keepCursor = true
        eq(A.Protection:ReturnCursor(nil, true), false); assert(M.cursor)
        M.keepCursor = false; eq(A.Protection:ReturnCursor(nil, true), true); eq(M.cursor, nil)
    end)

    test("noncursor and gamepad deletion paths receive explicit limited-protection feedback", function()
        local item = mark("Item-L", 0, 1, "locked")
        event("DELETE_ITEM_CONFIRM", "Test item", 3, 1, 0, item.guid)
        eq(M.clearCalls, 0); assert(message("does not use the cursor"))
        M.gamepad = true; M.forcePickup(0, 1)
        event("DELETE_ITEM_CONFIRM", "Test item", 3, 1, 0, item.guid)
        eq(M.cursor, nil); assert(message("remaining gamepad deletion"))
    end)

    test("disabled protection does not clear cursors, cancel trades or remove attachments", function()
        local item = mark("Item-L", 0, 1, "locked")
        A.SetOption("enabled", false); C_Container.PickupContainerItem(0, 1)
        event("CURSOR_CHANGED"); event("DELETE_ITEM_CONFIRM", "Test item", 3, 1, 0, item.guid)
        eq(M.cursor.item, item); eq(M.clearCalls, 0)
        M.tradeItems[1], M.attachments[1] = item, item
        event("TRADE_SHOW"); event("MAIL_SHOW"); event("MAIL_SEND_INFO_UPDATE")
        eq(M.cancelTradeCalls, 0); eq(#M.removals, 0)
    end)

    test("a Locked outgoing trade cancels on opening, offer changes and acceptance", function()
        local item = mark("Item-L", 0, 1, "locked")
        for index, trigger in ipairs({ "TRADE_SHOW", "TRADE_PLAYER_ITEM_CHANGED", "TRADE_ACCEPT_UPDATE", "TRADE_UPDATE" }) do
            offer(item, 0, 1, M.tradeItems, index == 4 and 7 or 1)
            A.tradeOpen = true; event(trigger)
            eq(M.cancelTradeCalls, index); eq(A.tradeOpen, false)
            eq(M.bags[0][1], item); eq(A.Store:Get(item.guid), "locked")
        end
    end)

    test("normal identical outgoing trade items and unreadable GUIDs are not guessed Locked", function()
        local locked = mark("Item-L", 0, 1, "locked")
        local other = M.item("Item-Other", 0, 2)
        offer(other, 0, 2, M.tradeItems); event("TRADE_SHOW")
        eq(M.cancelTradeCalls, 0)
        M.tradeItems[1] = locked
        for _, key in ipairs({ "secretTooltip", "secretTooltipGUID", "missingTooltipGUID" }) do
            M[key] = true; event("TRADE_PLAYER_ITEM_CHANGED"); eq(M.cancelTradeCalls, 0); M[key] = false
        end
    end)

    test("refused trade cancellation warns and leaves the mark intact", function()
        local item = mark("Item-L", 0, 1, "locked")
        offer(item, 0, 1, M.tradeItems); M.failCancelTrade = true
        event("TRADE_SHOW"); eq(M.cancelTradeCalls, 1); eq(A.tradeOpen, true)
        assert(message("Cancel the trade now")); eq(A.Store:Get(item.guid), "locked")
    end)

    test("outgoing Locked mail is removed without touching an identical Mail item or the cursor", function()
        local locked = mark("Item-L", 0, 1, "locked")
        local mail = mark("Item-M", 0, 2, "mail")
        local cursor = M.item("Item-N", 0, 3); C_Container.PickupContainerItem(0, 3)
        offer(locked, 0, 1, M.attachments, 2); offer(mail, 0, 2, M.attachments, 7)
        A.mailOpen = true; M.reentrantMail = true
        event("MAIL_SEND_INFO_UPDATE")
        eq(M.attachments[2], nil); eq(M.attachments[7], mail); eq(M.cursor.item, cursor)
        eq(#M.removals, 1); eq(M.closeMailCalls, 0); eq(A.Store:Get(locked.guid), "locked")
        M.tick(0); eq(locked.held, true)
    end)

    test("mail with several Locked attachments removes each and retains unsent markings", function()
        for index = 1, 3 do
            local item = mark("Item-L" .. index, 0, index, "locked")
            offer(item, 0, index, M.attachments, index * 3)
        end
        event("MAIL_SHOW"); eq(#M.removals, 3); eq(next(M.attachments), nil)
        for index = 1, 3 do eq(A.Store:Get("Item-L" .. index), "locked") end
    end)

    test("pending mail removal closes the draft without sending any attachments", function()
        local item = mark("Item-L", 0, 1, "locked")
        local normal = M.item("Item-N", 0, 2)
        offer(item, 0, 1, M.attachments); offer(normal, 0, 2, M.attachments, 2)
        M.rejectRemoval = true; A.mailOpen = true
        event("MAIL_SEND_INFO_UPDATE")
        eq(M.closeMailCalls, 1); eq(A.mailOpen, false); eq(next(M.attachments), nil)
        eq(M.bags[0][1], item); eq(M.bags[0][2], normal)
    end)

    test("mail removal and closure refusal produces a clear manual warning", function()
        local item = mark("Item-L", 0, 1, "locked")
        offer(item, 0, 1, M.attachments); M.failRemoval, M.failCloseMail = true, true
        A.mailOpen = true; event("MAIL_SEND_INFO_UPDATE")
        eq(M.attachments[1], item); eq(#M.removals, 1); eq(M.closeMailCalls, 1)
        assert(message("do not send this mail"))
    end)

    test("unknown mail GUIDs never remove another copy by item ID", function()
        local item = mark("Item-L", 0, 1, "locked")
        offer(item, 0, 1, M.attachments); M.secretTooltipGUID = true
        event("MAIL_SHOW"); eq(#M.removals, 0); eq(M.closeMailCalls, 0)
        M.secretTooltipGUID = false; event("MAIL_SEND_INFO_UPDATE"); eq(#M.removals, 1)
    end)

    test("newly sold Locked GUID is recovered once and held again", function()
        local item = mark("Item-L", 0, 1, "locked")
        openMerchant(); local before = M.money
        forceSale(0, 1); M.reentrantBuyback = true; M.reentrantLocks = true
        event("MERCHANT_UPDATE"); M.tick(1)
        eq(#M.buybacks, 1); eq(M.buybacks[1], item.guid); eq(M.bags[0][1], item)
        eq(M.money, before); eq(item.held, true); eq(A.Store:Get(item.guid), "locked")
        assert(message("sold and bought back"))
        eq(A.Protection.buybackPending, nil); eq(next(M.timers), nil)
    end)

    test("buyback recovery never purchases historical entries or identical nonlocked items", function()
        mark("Item-Old", 0, 1, "locked"); local old = forceSale(0, 1)
        local normal = M.item("Item-N", 0, 2)
        openMerchant(); forceSale(0, 2); event("MERCHANT_UPDATE"); M.tick(1)
        eq(#M.buybacks, 0); eq(M.buyback[1], old); eq(M.buyback[2], normal)
        event("MERCHANT_CLOSED"); openMerchant(); event("MERCHANT_UPDATE"); M.tick(1)
        eq(#M.buybacks, 0)
    end)

    test("several Locked buybacks are recovered sequentially despite index shifts", function()
        for index = 1, 3 do mark("Item-L" .. index, 0, index, "locked") end
        openMerchant()
        for index = 1, 3 do forceSale(0, index) end
        event("MERCHANT_UPDATE"); eq(#M.buybacks, 1)
        M.tick(1); eq(#M.buybacks, 3); eq(#M.buyback, 0)
        for index = 1, 3 do assert(A.API:Find("Item-L" .. index)) end
    end)

    test("insufficient money or secret buyback prices cannot purchase another entry", function()
        mark("Item-L1", 0, 1, "locked"); mark("Item-L2", 0, 2, "locked")
        openMerchant(); forceSale(0, 1); M.money = 0
        event("MERCHANT_UPDATE"); M.tick(1); eq(#M.buybacks, 0); assert(message("Buy it back manually"))
        M.money = 10000; M.secretPrice = true; forceSale(0, 2)
        event("MERCHANT_UPDATE"); M.tick(1); eq(#M.buybacks, 0)
    end)

    test("refused buyback times out without retrying or claiming success", function()
        mark("Item-L", 0, 1, "locked"); openMerchant(); forceSale(0, 1)
        M.rejectBuyback = true
        event("MERCHANT_UPDATE"); M.tick(3)
        eq(#M.buybacks, 1); eq(#M.buyback, 1); eq(next(M.timers), nil)
        assert(message("Could not verify")); eq(message("sold and bought back"), false)
        event("MERCHANT_UPDATE"); M.tick(1); eq(#M.buybacks, 1)
    end)

    test("unacknowledged buyback stops the batch before another shifting index is used", function()
        mark("Item-L1", 0, 1, "locked"); mark("Item-L2", 0, 2, "locked")
        openMerchant(); forceSale(0, 1); forceSale(0, 2)
        M.rejectBuyback = true; event("MERCHANT_UPDATE"); M.tick(5)
        eq(#M.buybacks, 1); eq(#M.buyback, 2); eq(next(M.timers), nil)
        M.rejectBuyback = false; event("MERCHANT_UPDATE"); M.tick(1)
        eq(#M.buybacks, 1); assert(message("Could not verify"))
    end)

    test("full bags cause one failed recovery without a false success message", function()
        mark("Item-L", 0, 1, "locked"); openMerchant(); forceSale(0, 1)
        for slot = 1, 32 do M.item("Item-Filler" .. slot, 0, slot) end
        event("MERCHANT_UPDATE"); M.tick(3)
        eq(#M.buybacks, 1); eq(#M.buyback, 1); eq(next(M.timers), nil)
        eq(message("sold and bought back"), false); assert(message("Could not verify"))
    end)

    test("disabling during pending buyback prevents further requests from queued callbacks", function()
        mark("Item-L1", 0, 1, "locked"); mark("Item-L2", 0, 2, "locked")
        openMerchant(); forceSale(0, 1); forceSale(0, 2)
        M.rejectBuyback = true; event("MERCHANT_UPDATE"); eq(#M.buybacks, 1)
        A.SetOption("enabled", false); M.tick(3); eq(#M.buybacks, 1)
        A.SetOption("enabled", true); event("MERCHANT_UPDATE"); M.tick(3)
        eq(#M.buybacks, 1)
    end)

    test("throwing buyback and missing identity do not create a retry loop", function()
        mark("Item-L", 0, 1, "locked"); openMerchant(); forceSale(0, 1)
        M.secretTooltipGUID = true; event("MERCHANT_UPDATE"); M.tick(1); eq(#M.buybacks, 0)
        M.secretTooltipGUID = false; M.failBuyback = true; event("MERCHANT_UPDATE"); M.tick(3)
        eq(#M.buybacks, 1); eq(next(M.timers), nil); assert(message("Buy it back manually"))
    end)

    test("closing the merchant or disabling protection cancels pending recovery", function()
        mark("Item-L1", 0, 1, "locked"); mark("Item-L2", 0, 2, "locked")
        openMerchant(); forceSale(0, 1); forceSale(0, 2)
        M.rejectBuyback = true; event("MERCHANT_UPDATE"); eq(#M.buybacks, 1)
        event("MERCHANT_CLOSED"); M.tick(3); eq(#M.buybacks, 1)
        openMerchant(); event("MERCHANT_UPDATE"); M.tick(1); eq(#M.buybacks, 1)
        A.SetOption("enabled", false); A.SetOption("enabled", true)
        event("MERCHANT_UPDATE"); M.tick(1); eq(#M.buybacks, 1)
    end)

    test("incomplete initial buyback identity is baselined before spending money", function()
        mark("Item-L", 0, 1, "locked"); forceSale(0, 1)
        M.missingTooltipGUID = true; openMerchant(); eq(A.Protection.historicalBuyback, nil)
        M.missingTooltipGUID = false; event("MERCHANT_UPDATE"); M.tick(1)
        eq(#M.buybacks, 0); eq(#M.buyback, 1)
    end)

    test("buyback recovery pauses in combat and resumes only at the open merchant", function()
        local item = mark("Item-L", 0, 1, "locked")
        openMerchant(); M.combat = true; event("PLAYER_REGEN_DISABLED")
        forceSale(0, 1); event("MERCHANT_UPDATE"); M.tick(1); eq(#M.buybacks, 0)
        M.combat = false; event("PLAYER_REGEN_ENABLED"); M.tick(1)
        eq(#M.buybacks, 1); eq(item.held, true)
    end)
end
