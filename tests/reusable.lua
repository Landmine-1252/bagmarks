-- Native use/hold behavior is simulated. Verify the sleeping bag's real item
-- metadata, event timing and click routing in Forever before claiming coverage.
return function(M, A, test, eq, mark)
    local function event(name, ...) A.eventFrame:Fire("OnEvent", name, ...) end
    local function reusable(guid, slot, options)
        options = options or {}
        options.spellID = options.spellID or 12345
        return mark(guid or "Item-Reusable", 0, slot or 1, "locked", options)
    end

    test("a Locked reusable item can be used without clearing its mark", function()
        local item = reusable()
        eq(item.held, nil)
        C_Container.UseContainerItem(0, 1)
        eq(M.used[1], item.guid); eq(M.bags[0][1], item); eq(item.count, 1)
        eq(A.Store:Get(item.guid), "locked")
        eq(#M.sold, 0); eq(M.clearCalls, 0)
    end)

    test("Locked consumables and items without a use effect retain permanent holds", function()
        local consumable = reusable("Item-Consumable", 1, { consumable = true, count = 3 })
        local other = mark("Item-Other", 0, 2, "locked", { itemID = 101 })
        eq(consumable.held, true); eq(other.held, true)
        C_Container.UseContainerItem(0, 1); C_Container.UseContainerItem(0, 2)
        eq(#M.used, 0); eq(consumable.count, 3); eq(M.bags[0][2], other)
    end)

    test("reusable use does not weaken cursor or deletion protection", function()
        local item = reusable()
        C_Container.PickupContainerItem(0, 1)
        eq(M.cursor.item, item)
        event("CURSOR_CHANGED"); M.tick(0)
        eq(M.cursor, nil); eq(M.bags[0][1], item)
        C_Container.PickupContainerItem(0, 1)
        event("DELETE_ITEM_CONFIRM", "Reusable", 1, 1, 0, item.guid)
        eq(M.cursor, nil); eq(M.bags[0][1], item); eq(M.clearCalls, 2)
        eq(A.Store:Get(item.guid), "locked")
    end)

    for _, context in ipairs({
        { "merchant", "MERCHANT_SHOW", "MERCHANT_CLOSED" },
        { "mail", "MAIL_SHOW", "MAIL_CLOSED" },
        { "trade", "TRADE_SHOW", "TRADE_CLOSED" },
        { "bank", "BANKFRAME_OPENED", "BANKFRAME_CLOSED" },
        { "auction", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED" },
    }) do
        test("Locked reusable items are held immediately during " .. context[1], function()
            local item = reusable()
            if context[1] == "merchant" then MerchantFrame:Show() end
            if context[1] == "mail" then SendMailFrame:Show() end
            event(context[2]) -- No timer tick: protection must be synchronous.
            eq(item.held, true)
            C_Container.UseContainerItem(0, 1); C_Container.PickupContainerItem(0, 1)
            eq(#M.used, 0); eq(#M.sold, 0); eq(M.cursor, nil)
            event(context[3])
            eq(item.held, nil); eq(A.Store:Get(item.guid), "locked")
            C_Container.UseContainerItem(0, 1); eq(M.used[1], item.guid)
        end)
    end

    test("item targeting immediately holds reusable items until every risk ends", function()
        local item = reusable()
        M.targeting = true; event("CURRENT_SPELL_CAST_CHANGED", false)
        eq(item.held, true)
        C_Container.UseContainerItem(0, 1); eq(#M.used, 0)
        event("TRADE_SHOW")
        M.targeting = false; event("CURRENT_SPELL_CAST_CHANGED", true)
        eq(item.held, true)
        event("TRADE_CLOSED"); eq(item.held, nil)
        C_Container.UseContainerItem(0, 1); eq(M.used[1], item.guid)
    end)

    test("ground targeting does not hold the reusable item supplying the spell", function()
        local item = reusable()
        M.targeting, M.groundTarget = true, true
        event("CURRENT_SPELL_CAST_CHANGED", false)
        eq(item.held, nil)
        M.groundTarget = false; event("CURRENT_SPELL_CAST_CHANGED", false)
        eq(item.held, true)
    end)

    test("item data loading releases only a verified reusable item's owned hold", function()
        local item = reusable(nil, nil, { uncached = true })
        eq(item.held, true)
        item.uncached = false
        event("GET_ITEM_INFO_RECEIVED", item.itemID, true); M.tick(0)
        eq(item.held, nil); eq(A.Store:Get(item.guid), "locked")
        item.uncached = true; A.Refresh(); eq(item.held, true)
        item.uncached = false
        event("ITEM_DATA_LOAD_RESULT", item.itemID, true); M.tick(0)
        eq(item.held, nil)
    end)

    for _, interface in ipairs({ "Blizzard", "Ellesmere" }) do
        for _, labels in ipairs({ true, false }) do
            test(interface .. " hover releases a late-metadata hold with tooltip labels " .. tostring(labels), function()
                A.SetOption("tooltips", labels)
                M.reentrantLocks = true
                local item = mark("Item-LateUse", 0, 1, "locked", { itemID = 211527 })
                local button
                if interface == "Ellesmere" then
                    M.ellesmere(); A.Bags:InstallHooks()
                    button = M.ellesmereButton(0, 1)
                    EUI_Bags.RunItemOverlays(button, { bag = 0, slot = 1, info = { itemID = item.itemID }, itemLink = item.link })
                else
                    button = M.button(0, 1); A.Bags:Discover()
                end
                M.tick(0); A.eventFrame:Fire("OnUpdate", .3)
                eq(item.held, true)
                -- The item name was already cached, but its use spell becomes
                -- readable later without either item-data event firing.
                item.spellID = 429961
                GameTooltip:SetOwner(button); GameTooltip:SetBagItem(0, 1)
                eq(item.held, nil); eq(A.Protection.held[item.guid], nil)
                M.tick(0)
                eq(item.held, nil); eq(A.Store:Get(item.guid), "locked")
                C_Container.UseContainerItem(0, 1); eq(M.used[1], item.guid)
                eq(item.count, 1)
            end)
        end
    end

    test("late reusable metadata on hover cannot release a hold during a merchant visit", function()
        local item = mark("Item-LateUse", 0, 1, "locked", { itemID = 211527 })
        local button = M.button(0, 1); A.Bags:Discover()
        MerchantFrame:Show(); event("MERCHANT_SHOW")
        item.spellID = 429961
        GameTooltip:SetOwner(button); GameTooltip:SetBagItem(0, 1)
        eq(item.held, true); eq(A.Protection.held[item.guid], true)
        eq(#M.unlockCalls, 0)
        C_Container.UseContainerItem(0, 1); eq(#M.sold, 0)
        event("MERCHANT_CLOSED")
        eq(item.held, nil); eq(A.Store:Get(item.guid), "locked")
    end)

    test("missing, throwing or unreadable reusable metadata keeps the stricter hold", function()
        local item = reusable(nil, nil, { consumable = true })
        item.consumable = false
        for _, api in ipairs({ "GetItemLink", "GetItemInfo", "GetItemSpell", "IsConsumableItem" }) do
            local original = C_Item[api]
            C_Item[api] = nil; A.Refresh(); eq(item.held, true, api .. " absent")
            C_Item[api] = function() error("unavailable metadata") end
            A.Refresh(); eq(item.held, true, api .. " throws")
            C_Item[api] = function() return M.secret, M.secret end
            A.Refresh(); eq(item.held, true, api .. " secret")
            C_Item[api] = function() end
            A.Refresh(); eq(item.held, true, api .. " unknown")
            C_Item[api] = original
        end
        A.Refresh(); eq(item.held, nil)
    end)

    test("reusable detection never releases another owner's hold", function()
        local item = reusable(nil, nil, { held = true })
        local button = M.button(0, 1); A.Bags:Discover()
        GameTooltip:SetOwner(button); GameTooltip:SetBagItem(0, 1)
        eq(item.held, true); eq(M.lockCalls, 0); eq(#M.unlockCalls, 0)
        event("TRADE_SHOW"); event("TRADE_CLOSED")
        eq(item.held, true); eq(#M.unlockCalls, 0)
    end)

    test("reusable risk transitions handle reentrant hold events and refused release", function()
        M.reentrantLocks = true
        local item = reusable()
        event("TRADE_SHOW"); M.tick(0)
        eq(item.held, true); eq(M.lockCalls, 1)
        M.failUnlock = true; event("TRADE_CLOSED")
        eq(item.held, true); eq(A.Protection.held[item.guid], true)
        M.failUnlock = false; A.Refresh(); M.tick(0)
        eq(item.held, nil); eq(A.Protection.held[item.guid], nil)
        eq(next(M.timers), nil)
    end)

    test("reusable use and targeting protection remain separate during combat", function()
        local item = reusable()
        M.combat = true; event("PLAYER_REGEN_DISABLED")
        eq(item.held, nil)
        C_Container.UseContainerItem(0, 1); eq(M.used[1], item.guid)
        M.targeting = true; event("CURRENT_SPELL_CAST_CHANGED", false)
        eq(item.held, true)
        M.targeting = false; event("CURRENT_SPELL_CAST_CHANGED", true)
        eq(item.held, nil)
        C_Container.PickupContainerItem(0, 1); event("CURSOR_CHANGED"); M.tick(0)
        eq(M.cursor, nil); eq(M.bags[0][1], item)
    end)

    test("saved reusable marks stay usable after reload while other items stay held", function()
        local item = reusable()
        local other = mark("Item-Other", 0, 2, "locked", { itemID = 101 })
        event("PLAYER_LOGOUT")
        A.Protection.stopping = nil; A.Store:Initialize()
        event("PLAYER_LOGIN"); M.tick(0)
        eq(item.held, nil); eq(other.held, true)
        eq(A.Store:Get(item.guid), "locked")
        C_Container.UseContainerItem(0, 1); eq(M.used[1], item.guid)
    end)

    test("identical reusable copies retain separate marks and protection", function()
        local item = reusable()
        local normal = M.item("Item-Normal", 0, 2, { spellID = 12345 })
        event("TRADE_SHOW")
        eq(item.held, true); eq(normal.held, nil)
        event("TRADE_CLOSED")
        C_Container.PickupContainerItem(0, 2); event("CURSOR_CHANGED")
        eq(M.cursor.item, normal); eq(M.clearCalls, 0); ClearCursor()
        C_Container.PickupContainerItem(0, 1); event("CURSOR_CHANGED"); M.tick(0)
        eq(M.cursor, nil); eq(M.bags[0][1], item)
        eq(A.Store:Get(normal.guid), nil)
    end)

    for _, interface in ipairs({ "Blizzard", "Ellesmere" }) do
        test(interface .. " allows native reusable use while preserving marks and marking clicks", function()
            local item = reusable()
            local button
            if interface == "Ellesmere" then
                M.ellesmere(); A.Bags:InstallHooks()
                button = M.ellesmereButton(0, 1)
                EUI_Bags.RunItemOverlays(button, { bag = 0, slot = 1, info = { itemID = item.itemID }, itemLink = item.link })
            else
                button = M.button(0, 1); A.Bags:Discover()
            end
            local nativeClick = function() C_Container.UseContainerItem(0, 1) end
            button:SetScript("OnClick", nativeClick)
            local overlay = assert(A.Bags.overlays[button])
            local function passesRight()
                for _, mouse in ipairs(overlay.passthrough) do if mouse == "RightButton" then return true end end
                return false
            end
            A.Refresh(); assert(passesRight()); assert(overlay.icon:IsShown())
            button:Fire("OnClick", "RightButton"); eq(M.used[1], item.guid)
            GameTooltip:SetOwner(button); GameTooltip:SetBagItem(0, 1)
            local labelled
            for _, line in ipairs(GameTooltip.lines) do if line:find("Reusable:", 1, true) then labelled = true end end
            assert(labelled, "tooltip must explain usable Locked items")
            M.ctrl, M.shift = true, true; event("MODIFIER_STATE_CHANGED")
            eq(passesRight(), false)
            overlay:Fire("OnClick", "RightButton"); assert(M.menu); eq(#M.used, 1)
            M.ctrl, M.shift = false, false; event("MODIFIER_STATE_CHANGED"); assert(passesRight())
            event("TRADE_SHOW"); eq(passesRight(), false); eq(item.held, true)
            event("TRADE_CLOSED"); assert(passesRight()); eq(item.held, nil)
            eq(button.scripts.OnClick, nativeClick); eq(A.Store:Get(item.guid), "locked")
        end)
    end

    test("unheld Locked reusable items remain excluded from sale and mail helpers", function()
        local item = reusable()
        mark("Item-Junk", 0, 2, "junk", { itemID = 101 })
        local mailed = mark("Item-Mail", 0, 3, "mail", { itemID = 102 })
        eq(item.held, nil)
        local entries = A.Operations:CollectJunk()
        eq(#entries, 1); eq(entries[1].guid, "Item-Junk")
        -- Deliberately omit the opening event to prove state checks protect the
        -- helpers even if an external action bypasses the native context hold.
        A.mailOpen = true; SendMailFrame:Show()
        A.Operations:AttachMail(); M.tick(1)
        eq(M.attachments[1], mailed); eq(M.attachments[2], nil)
        eq(M.bags[0][1], item); eq(A.Store:Get(item.guid), "locked")
    end)

    test("unknown spell targeting stays held and item-ID targeting is covered", function()
        local item = reusable()
        local targeting, targetItem, targetID = SpellIsTargeting, SpellCanTargetItem, SpellCanTargetItemID
        SpellIsTargeting = function() return M.secret end
        SpellCanTargetItem, SpellCanTargetItemID = nil, nil
        event("CURRENT_SPELL_CAST_CHANGED"); eq(item.held, true)
        SpellIsTargeting = function() return true end
        SpellCanTargetItem = function() return false end
        SpellCanTargetItemID = function() return true end
        event("CURRENT_SPELL_CAST_CHANGED"); eq(item.held, true)
        SpellIsTargeting = function() return false end
        event("CURRENT_SPELL_CAST_CHANGED"); eq(item.held, true, "item targeting takes precedence")
        SpellIsTargeting, SpellCanTargetItem, SpellCanTargetItemID = targeting, targetItem, targetID
        event("CURRENT_SPELL_CAST_CHANGED"); eq(item.held, nil)
    end)
end
