-- Locked protects against loss while normal native equip/use paths stay free.
-- The mock models equipment locations, consumable use, and deletion separately.
return function(M, A, test, eq, mark)
    local function event(name, ...) A.eventFrame:Fire("OnEvent", name, ...) end

    for _, interface in ipairs({ "Blizzard", "Ellesmere" }) do
        test(interface .. " permits native right-click equip of a Locked item without a use spell", function()
            local gear = mark("Item-Gear", 0, 1, "locked", { itemID = 1001, equipSlot = 16 })
            local button
            if interface == "Ellesmere" then
                M.ellesmere(); A.Bags:InstallHooks()
                button = M.ellesmereButton(0, 1)
                EUI_Bags.RunItemOverlays(button, { bag = 0, slot = 1, info = { itemID = gear.itemID }, itemLink = gear.link })
            else button = M.button(0, 1); A.Bags:Discover() end
            button:SetScript("OnClick", function() C_Container.UseContainerItem(0, 1) end)
            local overlay = A.Bags.overlays[button]
            local pass
            for _, mouse in ipairs(overlay.passthrough) do if mouse == "RightButton" then pass = true end end
            assert(pass); eq(gear.held, nil)
            button:Fire("OnClick", "RightButton")
            event("BAG_UPDATE_DELAYED"); M.tick(0)
            eq(M.equipped[16], gear); eq(M.bags[0][1], nil)
            eq(A.Store:Get(gear.guid), "locked"); eq(M.lockCalls, 0)
        end)
    end

    test("Locked gear can be dragged to equipment and stays marked when returned to a bag", function()
        local gear = mark("Item-Gear", 0, 1, "locked", { itemID = 1001, equipSlot = 16 })
        C_Container.PickupContainerItem(0, 1); event("CURSOR_CHANGED"); M.tick(0)
        eq(M.cursor.item, gear, "equipping must not race a cursor return")
        M.equipped[16], M.cursor = M.cursor.item, nil
        event("CURSOR_CHANGED"); event("BAG_UPDATE_DELAYED"); M.tick(0)
        eq(A.Store:Get(gear.guid), "locked"); eq(M.clearCalls, 0)
        M.equipped[16], M.bags[0][5] = nil, gear
        event("BAG_UPDATE_DELAYED"); M.tick(0)
        eq(A.Store:Get(A.API:Read(0, 5).guid), "locked")
        eq(gear.held, nil)
    end)

    test("intentional use of Locked consumables is allowed and unrelated copies stay unmarked", function()
        local potion = mark("Item-Potion", 0, 1, "locked", { itemID = 1002, consumable = true, count = 2 })
        local copy = M.item("Item-Copy", 0, 2, { itemID = 1002, consumable = true, count = 2 })
        C_Container.UseContainerItem(0, 1)
        eq(potion.count, 1); eq(copy.count, 2)
        eq(M.used[1], potion.guid); eq(A.Store:Get(potion.guid), "locked")
        eq(A.Store:Get(copy.guid), nil); eq(#M.sold, 0)
    end)

    test("uncached or missing use metadata never prevents Locked gear from equipping", function()
        local gear = mark("Item-Gear", 0, 1, "locked", { itemID = 1001, equipSlot = 16, uncached = true })
        local spell, consumable = C_Item.GetItemSpell, C_Item.IsConsumableItem
        C_Item.GetItemSpell, C_Item.IsConsumableItem = nil, nil
        A.Refresh(); C_Container.UseContainerItem(0, 1)
        C_Item.GetItemSpell, C_Item.IsConsumableItem = spell, consumable
        eq(M.equipped[16], gear); eq(M.lockCalls, 0)
    end)

    test("equipped Locked gear gets a native hold during transfer contexts and releases afterward", function()
        local gear = mark("Item-Gear", 0, 1, "locked", { itemID = 1001, equipSlot = 16 })
        C_Container.UseContainerItem(0, 1)
        event("TRADE_SHOW"); eq(gear.held, true)
        event("TRADE_CLOSED"); eq(gear.held, nil)
        eq(M.equipped[16], gear); eq(A.Store:Get(gear.guid), "locked")
    end)

    test("dropping a Locked item still returns it synchronously through deletion confirmation", function()
        local gear = mark("Item-Gear", 0, 1, "locked", { itemID = 1001, equipSlot = 16 })
        C_Container.PickupContainerItem(0, 1); event("CURSOR_CHANGED"); M.tick(0)
        eq(M.cursor.item, gear)
        event("DELETE_ITEM_CONFIRM", "Test gear", 1, 1, 0, gear.guid)
        eq(M.cursor, nil); eq(M.bags[0][1], gear); eq(M.clearCalls, 1)
    end)

    test("a bank visit permits normal use and equipment while destructive contexts still protect", function()
        local gear = mark("Item-Gear", 0, 1, "locked", { itemID = 1001, equipSlot = 16 })
        event("BANKFRAME_OPENED"); eq(gear.held, nil)
        C_Container.UseContainerItem(0, 1); eq(M.equipped[16], gear)
        event("MERCHANT_SHOW"); eq(gear.held, true)
        event("MERCHANT_CLOSED"); eq(gear.held, nil)
    end)

    test("normal-use policy immediately releases older owned permanent holds", function()
        local gear = mark("Item-Gear", 0, 1, "locked", { itemID = 1001, equipSlot = 16 })
        gear.held, A.Protection.held[gear.guid] = true, true
        A.Refresh(); eq(gear.held, nil); eq(A.Protection.held[gear.guid], nil)
        eq(A.Store:Get(gear.guid), "locked")
    end)
end
