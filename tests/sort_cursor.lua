-- Forever's CURSOR_CHANGED is synchronous. Model the pickup/place/clear
-- sequence used by Ellesmere without executing or editing another addon.
return function(M, A, test, eq, mark)
    local function event(name, ...) A.eventFrame:Fire("OnEvent", name, ...) end
    local function pickup(slot)
        local item, cursor = M.bags[0][slot], M.cursor
        if (item and (item.busy or item.held)) then return end
        if cursor then
            M.bags[0][slot] = cursor.item
            M.cursor = item and { item = item, bag = cursor.bag, slot = cursor.slot } or nil
        else
            M.cursor = item and { item = item, bag = 0, slot = slot } or nil
            M.bags[0][slot] = nil
        end
        event("CURSOR_CHANGED")
    end

    test("synchronous sort swaps finish before cursor protection checks a Locked reusable", function()
        local sleeping = mark("Item-Sleep", 0, 1, "locked", { itemID = 211527, spellID = 429961 })
        local other = M.item("Item-Normal", 0, 2, { itemID = 101 })
        pickup(1); pickup(2); ClearCursor()
        eq(M.bags[0][2], sleeping); eq(M.bags[0][1], other)
        eq(M.clearCalls, 1, "only the sorter should have cleared the cursor")
        M.tick(0)
        eq(M.cursor, nil); eq(M.clearCalls, 1)
        eq(A.Store:Get(sleeping.guid), "locked"); eq(A.Store:Get(other.guid), nil)
        eq(sleeping.held, nil); eq(M.lockCalls, 0)
        C_Container.UseContainerItem(0, 2); eq(M.used[1], sleeping.guid)
    end)

    test("an ordinary drag remains available for equipping after a completed sort", function()
        local sleeping = mark("Item-Sleep", 0, 1, "locked", { itemID = 211527, spellID = 429961 })
        pickup(1); pickup(7); ClearCursor(); M.tick(0)
        pickup(7)
        eq(M.cursor.item, sleeping); eq(M.bags[0][7], nil)
        M.tick(0)
        eq(M.cursor.item, sleeping); eq(M.bags[0][7], nil)
        event("DELETE_ITEM_CONFIRM", "Sleeping bag", 1, 1, 0, sleeping.guid)
        eq(M.cursor, nil); eq(M.bags[0][7], sleeping)
        eq(A.Store:Get(sleeping.guid), "locked")
    end)

    test("sorting into a Locked reusable slot does not clear the displaced item mid-swap", function()
        local normal = M.item("Item-Normal", 0, 1, { itemID = 101 })
        local sleeping = mark("Item-Sleep", 0, 2, "locked", { itemID = 211527, spellID = 429961 })
        pickup(1); pickup(2)
        eq(M.cursor.item, sleeping); eq(M.clearCalls, 0)
        ClearCursor(); M.tick(0)
        eq(M.bags[0][1], sleeping); eq(M.bags[0][2], normal)
        eq(M.clearCalls, 1); eq(sleeping.held, nil)
    end)

    test("multiple moves in one sort share one cursor check without returning moved items", function()
        local sleeping = mark("Item-Sleep", 0, 1, "locked", { itemID = 211527, spellID = 429961 })
        pickup(1); pickup(2); ClearCursor()
        pickup(2); pickup(3); ClearCursor()
        pickup(3); pickup(4); ClearCursor()
        eq(M.bags[0][4], sleeping); eq(M.clearCalls, 3)
        M.tick(0)
        eq(A.Protection.cursorChecks, 1); eq(A.Protection.cursorCheck, nil)
        eq(A.Protection.cursorReturns, nil); eq(M.clearCalls, 3)
        eq(A.Store:Get(sleeping.guid), "locked")
    end)

    test("deletion protection remains synchronous before a deferred cursor check", function()
        local sleeping = mark("Item-Sleep", 0, 1, "locked", { itemID = 211527, spellID = 429961 })
        pickup(1)
        event("DELETE_ITEM_CONFIRM", "Cozy Sleeping Bag", 1, 1, 0, sleeping.guid)
        eq(M.cursor, nil); eq(M.bags[0][1], sleeping)
        local calls = M.clearCalls
        M.tick(0); eq(M.clearCalls, calls)
    end)

    test("a queued check never returns an unmarked identical replacement cursor item", function()
        local sleeping = mark("Item-Sleep", 0, 1, "locked", { itemID = 211527, spellID = 429961 })
        local copy = M.item("Item-Copy", 0, 2, { itemID = 211527, spellID = 429961 })
        pickup(1); ClearCursor(); pickup(2)
        local calls = M.clearCalls
        M.tick(0)
        eq(M.cursor.item, copy); eq(M.clearCalls, calls)
        eq(M.bags[0][1], sleeping); eq(A.Store:Get(copy.guid), nil)
    end)

    test("disabling or logging out cancels a pending cursor guard without clearing another item", function()
        mark("Item-Sleep", 0, 1, "locked", { itemID = 211527, spellID = 429961 })
        pickup(1); A.SetOption("enabled", false)
        local calls = M.clearCalls
        M.tick(0); eq(M.clearCalls, calls); assert(M.cursor)
        ClearCursor(); A.SetOption("enabled", true)
        pickup(1); event("PLAYER_LOGOUT")
        calls = M.clearCalls; M.tick(0)
        eq(M.clearCalls, calls); assert(M.cursor)
    end)

    test("combat cursor checks preserve equipment drags without scans or frame creation", function()
        local sleeping = mark("Item-Sleep", 0, 1, "locked", { itemID = 211527, spellID = 429961 })
        M.combat = true; event("PLAYER_REGEN_DISABLED")
        local frames, reads = #M.frames, M.reads
        pickup(1); M.tick(0)
        eq(M.cursor.item, sleeping); eq(M.bags[0][1], nil)
        event("DELETE_ITEM_CONFIRM", "Sleeping bag", 1, 1, 0, sleeping.guid)
        eq(M.cursor, nil); eq(M.bags[0][1], sleeping)
        eq(M.reads, reads); eq(#M.frames, frames)
    end)
end
