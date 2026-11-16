-- Distinguish local addon holds from the server's independent busy state.
-- Sorting can change slots or keep an item busy while an unlock is processed.
return function(M, A, test, eq, mark)
    local function event(name, ...) A.eventFrame:Fire("OnEvent", name, ...) end
    local function sleeping()
        return mark("Item-Bag", 0, 1, "locked", { itemID = 211527, spellID = 429961 })
    end

    test("a silently refused release retains ownership until the client confirms it", function()
        local item = sleeping()
        event("TRADE_SHOW"); eq(item.held, true)
        M.rejectUnlock = true; event("TRADE_CLOSED")
        eq(item.held, true); eq(A.Protection.held[item.guid], true)
        eq(A.Protection.releases[item.guid].state, "waiting")
        -- An ordinary refresh must not repeatedly issue successful-but-refused
        -- unlock calls, which could release another owner's later hold.
        local calls = #M.unlockCalls
        for _ = 1, 10 do A.Refresh() end
        M.tick(3)
        eq(#M.unlockCalls, calls); eq(A.Protection.held[item.guid], true)
        eq(A.Protection.releases[item.guid].state, "unverified")
        eq(next(M.timers), nil)
    end)

    test("clearing a mark while an independent sort busy flag remains does not lose release state", function()
        local item = mark("Item-Bag", 0, 1, "locked", { itemID = 211527 })
        item.busy = true
        A.Store:Set(A.API:Read(0, 1), nil)
        eq(item.held, nil); eq(item.busy, true)
        eq(A.Protection.held[item.guid], true)
        local calls = #M.unlockCalls
        item.busy = false; M.tick(.25)
        eq(A.Protection.held[item.guid], nil); eq(A.Protection.releases[item.guid], nil)
        eq(#M.unlockCalls, calls); eq(A.Store:Get(item.guid), nil)
    end)

    test("release verification follows a moved GUID and leaves an identical replacement held", function()
        local item = sleeping(); event("TRADE_SHOW")
        item.busy = true; event("TRADE_CLOSED")
        M.bags[0][1] = nil; M.bags[0][7] = item
        local copy = M.item("Item-Copy", 0, 1, { itemID = 211527, spellID = 429961, held = true })
        item.busy = false; M.tick(.25)
        eq(A.Protection.held[item.guid], nil); eq(copy.held, true)
        eq(A.Store:Get(item.guid), "locked"); eq(A.Store:Get(copy.guid), nil)
        C_Container.UseContainerItem(0, 7); eq(M.used[1], item.guid)
    end)

    test("release confirmation cannot discard a newly reacquired protection hold", function()
        local item = sleeping(); event("TRADE_SHOW")
        item.busy = true; event("TRADE_CLOSED")
        local pending = A.Protection.releases[item.guid]
        item.busy = false; event("TRADE_SHOW")
        eq(item.held, true); eq(A.Protection.releases[item.guid], nil)
        M.tick(3); eq(item.held, true); eq(A.Protection.held[item.guid], true)
        assert(pending)
        event("TRADE_CLOSED"); eq(item.held, nil)
    end)

    test("unknown release confirmation retains the record without unlocking a replacement", function()
        local item = sleeping(); event("TRADE_SHOW")
        M.secretLock = true; event("TRADE_CLOSED")
        eq(A.Protection.held[item.guid], true)
        local calls = #M.unlockCalls
        M.secretLocation = true; M.tick(3)
        eq(A.Protection.held[item.guid], true); eq(#M.unlockCalls, calls)
        M.secretLocation, M.secretLock = false, false
        A.Refresh(); eq(A.Protection.held[item.guid], nil)
    end)

    test("preexisting sort busy states never become BagMarks-owned release requests", function()
        local item = mark("Item-Bag", 0, 1, "locked", { itemID = 211527, spellID = 429961, busy = true })
        A.Store:Set(A.API:Read(0, 1), nil); A.Refresh(); M.tick(3)
        eq(item.busy, true); eq(#M.unlockCalls, 0)
        eq(A.Protection.held[item.guid], nil)
        local report = A.Diagnostics:Report(211527)
        assert(report:find("owned=false", 1, true))
    end)

    test("holds acquired by location use the exact location unlock when GUID unlock refuses", function()
        local item = sleeping(); event("TRADE_SHOW")
        local original = C_Item.UnlockItemByGUID
        local guidCalls = 0
        C_Item.UnlockItemByGUID = function() guidCalls = guidCalls + 1 end
        event("TRADE_CLOSED")
        C_Item.UnlockItemByGUID = original
        eq(item.held, nil); eq(A.Protection.held[item.guid], nil)
        eq(M.locationUnlockCalls, 1); eq(guidCalls, 0)
        C_Container.UseContainerItem(0, 1); eq(M.used[1], item.guid)
    end)

    test("missing or throwing location unlock falls back to the exact owned GUID", function()
        local item = sleeping(); event("TRADE_SHOW")
        local original = C_Item.UnlockItem
        C_Item.UnlockItem = nil; event("TRADE_CLOSED")
        eq(item.held, nil); eq(A.Protection.held[item.guid], nil)
        event("TRADE_SHOW")
        C_Item.UnlockItem = function() error("location unlock unavailable") end
        event("TRADE_CLOSED")
        C_Item.UnlockItem = original
        eq(item.held, nil); eq(A.Protection.held[item.guid], nil)
    end)

    test("disabled and combat release verification never scans inventory or resumes item actions", function()
        local item = sleeping(); event("TRADE_SHOW")
        item.busy = true; A.SetOption("enabled", false)
        eq(item.held, nil); eq(A.Protection.held[item.guid], true)
        M.combat = true
        local reads, frames = M.reads, #M.frames
        item.busy = false; M.tick(.25)
        eq(A.Protection.held[item.guid], nil)
        eq(M.reads, reads); eq(#M.frames, frames)
        eq(#M.used, 0); eq(#M.sold, 0); eq(#M.attachments, 0)
    end)

    test("release diagnostics report pending and unverified state without issuing another unlock", function()
        local item = sleeping(); event("TRADE_SHOW")
        M.rejectUnlock = true; event("TRADE_CLOSED")
        local calls = #M.unlockCalls
        local report = A.Diagnostics:Report(211527)
        assert(report:find("ProtectionRevision=" .. A.protectionRevision, 1, true))
        assert(report:find("Release: state=waiting, method=location", 1, true))
        eq(#M.unlockCalls, calls)
        M.tick(3)
        report = A.Diagnostics:Report(211527)
        assert(report:find("Release: state=unverified, method=location", 1, true))
        eq(#M.unlockCalls, calls); eq(A.Protection.held[item.guid], true)
        -- A later genuine free-state event can still finish verification.
        item.held = nil; event("ITEM_LOCK_CHANGED")
        eq(A.Protection.held[item.guid], nil)
    end)
end
