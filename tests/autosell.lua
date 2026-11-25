return function(M, A, test, eq, mark)
    local function event(name, ...) A.eventFrame:Fire("OnEvent", name, ...) end
    local function openMerchant()
        MerchantFrame:Show()
        MerchantFrame.selectedTab = 1
        event("MERCHANT_SHOW")
    end
    local function closeMerchant()
        MerchantFrame:Hide()
        event("MERCHANT_CLOSED")
    end
    local function enable() A.SetOption("autoSellJunk", true) end
    local function twoItems()
        mark("Item-J1", 0, 1, "junk")
        return mark("Item-J2", 0, 2, "junk")
    end

    test("opted-in merchant visit automatically sells only eligible marked carried Junk", function()
        enable()
        mark("Item-L", 0, 1, "locked")
        mark("Item-M", 0, 2, "mail")
        M.item("Item-N", 0, 3, { quality = 0 })
        mark("Item-J", 0, 4, "junk", { quality = 3, count = 5 })
        local gear = mark("Item-DE", 0, 5, "disenchant", { quality = 0 })
        A.bankOpen = true; mark("Item-Bank", 6, 1, "junk")
        openMerchant(); eq(#M.sold, 0, "allow the merchant UI to finish opening")
        M.tick(1)
        eq(#M.sold, 1); eq(M.sold[1], "Item-J")
        eq(M.bags[0][5], gear); eq(gear.held, true)
        assert(M.bags[0][1] and M.bags[0][2] and M.bags[0][3] and M.bags[6][1])
        assert(not A.UI.confirm or not A.UI.confirm:IsShown())
        eq(A.Operations.job, nil)
    end)

    test("an unreadable stack cannot confirm a refused sale or advance the queue", function()
        enable(); twoItems()
        M.rejectSale = true
        openMerchant(); M.tick(.2); eq(M.saleAttempts, 1)
        local first = M.bags[0][1]
        first.secretID = M.secret; M.rejectSale = false; M.tick(1)
        eq(M.saleAttempts, 1); eq(#M.sold, 0)
        first.secretID = nil; M.tick(2)
        eq(A.Operations.job, nil); eq(#M.sold, 0); eq(A.Store:Get(first.guid), "junk")
    end)

    test("a sale preview uses the quoted price and rechecks it on confirmation", function()
        local stack = mark("Item-Quote", 0, 1, "junk", { price = 250, count = 3 })
        openMerchant()
        local getInfo, quotes = C_Item.GetItemInfo, 0
        C_Item.GetItemInfo = function(link)
            quotes = quotes + 1
            if quotes == 1 then return getInfo(link) end
        end
        local ok, err = pcall(function()
            A.Operations:PreviewJunk()
            A.UI.confirm.accept:Fire("OnClick")
        end)
        C_Item.GetItemInfo = getInfo
        assert(ok, err); eq(quotes, 2); eq(#M.sold, 0); eq(M.bags[0][1], stack)
    end)

    test("automatic selling defaults off and the preference survives reload and sanitization", function()
        eq(A.db.autoSellJunk, false)
        mark("Item-J", 0, 1, "junk"); openMerchant(); M.tick(1); eq(#M.sold, 0)
        enable(); A.Store:Initialize(); eq(A.db.autoSellJunk, true)
        A.SetOption("autoSellJunk", false); A.Store:Initialize(); eq(A.db.autoSellJunk, false)
        BagMarksDB.autoSellJunk = "true"; A.Store:Initialize(); eq(A.db.autoSellJunk, false)
        BagMarksDB.autoSellJunk = nil; A.Store:Initialize(); eq(A.db.autoSellJunk, false)
        eq(A.Store:Get("Item-J"), "junk")
    end)

    test("General checkbox enables future visits and does not sell at the already-open merchant", function()
        mark("Item-J", 0, 1, "junk"); openMerchant(); M.tick(1)
        local check = assert(A.Settings.checks.autoSellJunk)
        check:SetChecked(true); check:Fire("OnClick"); eq(A.db.autoSellJunk, true)
        event("MERCHANT_UPDATE"); A.Refresh(); M.tick(1); eq(#M.sold, 0)
        closeMerchant(); openMerchant(); M.tick(1); eq(#M.sold, 1)
    end)

    test("automatic selling processes all opening candidates beyond the manual twelve-stack cap", function()
        enable()
        for slot = 1, 20 do mark("Item-J" .. slot, 0, slot, "junk") end
        openMerchant(); M.tick(5)
        eq(#M.sold, 20); eq(A.Operations.job, nil)
        for slot = 1, 20 do eq(M.sold[slot], "Item-J" .. slot) end
    end)

    test("merchant and inventory updates never repeat auto-sale or add newly marked items", function()
        enable(); twoItems(); openMerchant(); M.tick(.2); eq(#M.sold, 1)
        mark("Item-New", 0, 3, "junk")
        event("MERCHANT_SHOW"); event("MERCHANT_UPDATE"); event("BAG_UPDATE_DELAYED"); M.tick(1)
        eq(#M.sold, 2); eq(M.bags[0][3].guid, "Item-New")
        event("MERCHANT_SHOW"); event("MERCHANT_UPDATE"); A.Refresh(); M.tick(1); eq(#M.sold, 2)
        closeMerchant(); openMerchant(); M.tick(1); eq(#M.sold, 3)
    end)

    test("manual preview takes priority over a pending automatic sale", function()
        enable(); twoItems(); openMerchant()
        A.Operations:PreviewJunk(); assert(A.UI.confirm:IsShown())
        M.tick(1); eq(#M.sold, 0)
        A.UI.confirm.accept:Fire("OnClick"); M.tick(1); eq(#M.sold, 2)
    end)

    test("an open BagMarks confirmation prevents a background automatic sale", function()
        enable(); twoItems()
        A.Slash("reset"); openMerchant(); M.tick(1)
        eq(#M.sold, 0); assert(A.UI.confirm:IsShown())
        A.UI:CloseConfirmation(); event("MERCHANT_UPDATE"); M.tick(1); eq(#M.sold, 0)
    end)

    for _, state in ipairs({ "locked", "mail", "disenchant", "normal" }) do
        test("automatic queue rechecks a Junk item changed to " .. state, function()
            enable(); twoItems(); openMerchant(); M.tick(.2); eq(#M.sold, 1)
            A.Store:Set(A.API:Read(0, 2), state ~= "normal" and state or nil)
            M.tick(1); eq(#M.sold, 1); assert(M.bags[0][2]); eq(A.Operations.job, nil)
        end)
    end

    test("automatic queue follows a moved GUID and never sells its replacement", function()
        enable(); local second = twoItems(); openMerchant(); M.tick(.2)
        M.bags[1] = { [4] = second }; M.bags[0][2] = nil
        mark("Item-Replacement", 0, 2, "locked")
        M.tick(1); eq(#M.sold, 2); eq(M.sold[2], second.guid)
        eq(M.bags[0][2].guid, "Item-Replacement")
    end)

    for _, mode in ipairs({ "automatic", "manual" }) do
        test(mode .. " sale skips stacks already taken or held by another seller and continues", function()
            for slot = 1, 4 do mark("Item-Sale" .. slot, 0, slot, "junk", { itemID = 100 + slot }) end
            if mode == "automatic" then enable() end
            openMerchant()
            if mode == "automatic" then M.tick(.2)
            else A.Operations:PreviewJunk(); A.UI.confirm.accept:Fire("OnClick") end
            eq(M.sold[1], "Item-Sale1")
            M.bags[0][2] = nil
            local replacement = M.item("Item-Replacement", 0, 2, { itemID = 102 })
            M.bags[0][3].busy = true
            event("MERCHANT_UPDATE"); event("BAG_UPDATE_DELAYED"); M.tick(1)
            eq(M.saleAttempts, 2); eq(M.sold[2], "Item-Sale4"); eq(M.bags[0][2], replacement)
            eq(M.bags[0][3].busy, true); eq(A.Operations.job, nil)
            assert(M.messages[#M.messages]:find("Skipped 2", 1, true))
        end)
    end

    test("manual and automatic sellers respect Blizzard backpack and bag junk exclusions", function()
        mark("Item-Backpack", 0, 1, "junk"); mark("Item-Bag", 1, 1, "junk")
        mark("Item-Allowed", 2, 1, "junk"); mark("Item-Unknown", 3, 1, "junk")
        M.excludedBags[0], M.excludedBags[1], M.excludedBags[3] = true, true, M.secret
        openMerchant()
        local preview, skipped = A.Operations:CollectJunk(12)
        eq(#preview, 1); eq(preview[1].guid, "Item-Allowed"); eq(skipped, 3)
        A.Operations:PreviewJunk()
        M.excludedBags[2] = true
        A.UI.confirm.accept:Fire("OnClick"); M.tick(1); eq(M.saleAttempts, 0)
        closeMerchant(); M.excludedBags[1] = false
        enable(); openMerchant(); M.tick(1)
        eq(#M.sold, 1); eq(M.sold[1], "Item-Bag"); eq(M.saleAttempts, 1)
    end)

    for _, change in ipairs({ "count", "price" }) do
        test("automatic queue stops when a captured stack's " .. change .. " changes", function()
            enable(); local second = twoItems(); openMerchant(); M.tick(.2)
            second[change] = change == "count" and 3 or 500
            M.tick(1); eq(#M.sold, 1); assert(M.bags[0][2]); eq(A.Operations.job, nil)
        end)
    end

    test("automatic selling skips ineligible and review-needed items without repeated notifications", function()
        enable()
        mark("Item-Quest", 0, 1, "junk", { itemID = 101, quest = true })
        mark("Item-Refund", 0, 2, "junk", { itemID = 102, refundable = true })
        mark("Item-Busy", 0, 3, "junk", { itemID = 103, busy = true })
        mark("Item-NoValue", 0, 4, "junk", { itemID = 104, noValue = true })
        mark("Item-Uncached", 0, 5, "junk", { itemID = 105, uncached = true })
        mark("Item-Review", 0, 6, "junk", { itemID = 106 }); A.char.review["Item-Review"] = true
        openMerchant(); M.tick(1); event("MERCHANT_UPDATE"); M.tick(1)
        eq(#M.sold, 0); eq(#M.messages, 0)
        eq(A.Store:Get("Item-Review"), "junk"); eq(A.char.review["Item-Review"], true)
    end)

    test("closing and reopening invalidates the previous visit's delayed sale", function()
        enable(); twoItems(); openMerchant(); M.tick(.1); closeMerchant()
        openMerchant(); M.tick(.1); eq(#M.sold, 0)
        M.tick(1); eq(#M.sold, 2)
    end)

    for _, phase in ipairs({ "pending", "running" }) do
        for _, stop in ipairs({ "close", "combat", "disable", "option", "reset", "logout", "buyback", "cursor", "targeting" }) do
            test("automatic sale " .. phase .. " is cancelled by " .. stop, function()
                enable(); twoItems(); openMerchant()
                if phase == "running" then M.tick(.2); eq(#M.sold, 1) end
                local sold = #M.sold
                if stop == "close" then closeMerchant()
                elseif stop == "combat" then M.combat = true; event("PLAYER_REGEN_DISABLED")
                elseif stop == "disable" then A.SetOption("enabled", false)
                elseif stop == "option" then A.SetOption("autoSellJunk", false)
                elseif stop == "reset" then A.Store:ResetSettings()
                elseif stop == "buyback" then MerchantFrame.selectedTab = 2
                elseif stop == "cursor" then M.item("Item-Cursor", 0, 5); C_Container.PickupContainerItem(0, 5)
                elseif stop == "targeting" then M.targeting = true
                else event("PLAYER_LOGOUT") end
                M.tick(3); eq(#M.sold, sold); eq(A.Operations.job, nil)
                assert(M.bags[0][2]); eq(A.Store:Get("Item-J2"), "junk")
            end)
        end
    end

    test("automatic sale never starts with a nonempty cursor, Buyback tab or combat", function()
        enable(); mark("Item-J", 0, 1, "junk"); M.item("Item-Cursor", 0, 2)
        C_Container.PickupContainerItem(0, 2); openMerchant(); M.tick(1)
        eq(#M.sold, 0); eq(M.cursor.item.guid, "Item-Cursor")
        ClearCursor(); closeMerchant(); openMerchant(); MerchantFrame.selectedTab = 2; M.tick(1)
        eq(#M.sold, 0)
        closeMerchant(); M.combat = true; openMerchant(); M.tick(1); eq(#M.sold, 0)
        M.combat = false; event("PLAYER_REGEN_ENABLED"); M.tick(1); eq(#M.sold, 0)
    end)

    test("a refused automatic sale stops once and never restarts from updates", function()
        enable(); twoItems(); M.rejectSale = true; openMerchant(); M.tick(3)
        eq(#M.sold, 0); eq(M.saleAttempts, 1); eq(A.Operations.job, nil)
        M.rejectSale = false; event("MERCHANT_UPDATE"); event("BAG_UPDATE_DELAYED"); M.tick(3)
        eq(#M.sold, 0); eq(M.saleAttempts, 1); eq(A.Store:Get("Item-J1"), "junk")
    end)

    test("disabling auto-sale leaves an explicitly confirmed manual sale alone", function()
        enable(); twoItems(); openMerchant(); A.Operations:PreviewJunk()
        A.UI.confirm.accept:Fire("OnClick"); eq(#M.sold, 1)
        A.SetOption("autoSellJunk", false); M.tick(1); eq(#M.sold, 2)
    end)

    test("merchant button can stop an automatic sale and restores its manual preview action", function()
        enable(); twoItems(); openMerchant(); M.tick(.2); eq(#M.sold, 1)
        local button = A.Operations.sellButton
        eq(button:GetText(), "Stop Selling"); eq(button.enabled, true)
        button:Fire("OnClick"); eq(A.Operations.job, nil)
        eq(button:GetText(), "Sell Marked Junk")
        event("MERCHANT_UPDATE"); M.tick(1); eq(#M.sold, 1)
        button:Fire("OnClick"); assert(A.UI.confirm:IsShown())
        A.UI.confirm.accept:Fire("OnClick"); M.tick(1); eq(#M.sold, 2)
    end)
end
