return function(M, A, test, eq, mark)
    local feather = 17056
    local function event(name) A.eventFrame:Fire("OnEvent", name) end
    local function bagsChanged()
        event("BAG_UPDATE_DELAYED")
        M.tick(0)
    end
    local function remember(value)
        local check = A.Settings.checks.rememberItemTypes
        check:SetChecked(value)
        check:Fire("OnClick")
    end
    local function item(guid, slot, count)
        return M.item(guid, 0, slot, { itemID = feather, name = "Light Feather", count = count })
    end
    local function choose(slot, label)
        local button = M.button(0, slot)
        A.UI:ItemMenu(button, A.API:Read(0, slot))
        for _, choice in ipairs(M.menu.choices) do
            if choice.text == label then choice.callback(); return end
        end
        error("missing marking choice " .. label)
    end

    test("remembering defaults off and enabling does not learn old marks or change existing copies", function()
        eq(A.db.rememberItemTypes, false)
        item("Item-First", 1); choose(1, "Mark for Mail")
        item("Item-Old", 2); bagsChanged()
        eq(A.Store:Get("Item-Old"), nil); eq(next(A.char.itemRules), nil)
        remember(true); item("Item-BeforeRule", 3); bagsChanged()
        eq(A.Store:Get("Item-BeforeRule"), nil)
        item("Item-Unscanned", 4); choose(1, "Mark for Mail")
        eq(A.char.itemRules[feather], "mail")
        for _, guid in ipairs({ "Item-Old", "Item-BeforeRule", "Item-Unscanned" }) do eq(A.Store:Get(guid), nil) end
        item("Item-After", 5); M.item("Item-DifferentID", 0, 6, { itemID = 123, name = "Light Feather" })
        bagsChanged(); eq(A.Store:Get("Item-After"), "mail"); eq(A.Store:Get("Item-DifferentID"), nil)
    end)

    test("later feathers auto-attach with the saved recipient and subject after a reload", function()
        remember(true); item("Item-Sent", 1); choose(1, "Mark for Mail")
        A.char.recipient = "Bankalt-Realm"
        M.bags[0][1] = nil
        A.Store:Initialize()
        local fresh = item("Item-New", 1, 7)
        event("MAIL_SHOW"); SendMailFrame:Show(); M.tick(1)
        eq(M.attachments[1], fresh); eq(A.Store:Get(fresh.guid), "mail")
        eq(SendMailSubjectEditBox:GetText(), "Light Feather (7)"); eq(SendMailNameEditBox:GetText(), "Bankalt")
        eq(A.char.review[fresh.guid], nil)
    end)

    test("hover changes the future rule, Locked overrides one copy and Clear forgets the type", function()
        remember(true); item("Item-First", 1); item("Item-Second", 2)
        local button = M.button(0, 1)
        A.Bags:Discover(); M.mouseFoci = { button }
        BagMarks_CycleHoveredItem(); eq(A.char.itemRules[feather], nil)
        BagMarks_CycleHoveredItem(); eq(A.char.itemRules[feather], "junk")
        item("Item-Junk", 3); bagsChanged()
        BagMarks_CycleHoveredItem(); eq(A.char.itemRules[feather], "mail"); eq(A.Store:Get("Item-Junk"), "junk")
        choose(2, "Lock Item")
        item("Item-Mail", 4); bagsChanged()
        eq(A.Store:Get("Item-Second"), "locked"); eq(A.Store:Get("Item-Mail"), "mail")
        choose(1, "Mark for Disenchanting"); A.Store:Initialize()
        eq(A.Store:Get("Item-First"), "disenchant"); eq(A.char.itemRules[feather], "disenchant")
        item("Item-Disenchant", 5); bagsChanged(); eq(A.Store:Get("Item-Disenchant"), "disenchant")
        choose(1, "Clear mark and forget future mark"); item("Item-Normal", 6); bagsChanged()
        eq(A.char.itemRules[feather], nil); eq(A.Store:Get("Item-Normal"), nil)
        eq(A.Store:Get("Item-Mail"), "mail"); eq(A.Store:Get("Item-Junk"), "junk")
    end)

    test("Clear Mark keeps the short label when clearing only the selected stack", function()
        remember(true); item("Item-First", 1); choose(1, "Lock Item"); choose(1, "Clear Mark")
        choose(1, "Mark for Mail"); A.Store:SetMailRoute(feather, "Mage")
        remember(false); choose(1, "Clear Mark")
        eq(A.Store:Get("Item-First"), nil); eq(A.char.itemRules[feather], "mail")
        eq(A.MailRoutes:DisplayName(A.db.itemRecipients[feather]), "Mage")
        remember(true); choose(1, "Clear mark and forget future mark")
        eq(A.char.itemRules[feather], nil); eq(A.MailRoutes:DisplayName(A.db.itemRecipients[feather]), "Mage")
    end)

    test("remembered types allow fresh units in existing stacks and matching split or merge sources", function()
        remember(true); local old = item("Item-Old", 1, 4)
        local source = item("Item-Source", 2, 3); choose(2, "Mark for Mail")
        old.count = 6; source.count = 4; bagsChanged()
        eq(A.Store:Get(old.guid), "mail"); assert(A.Store:Eligible(A.API:Read(0, 2), "mail"))
        source.count = 2; local split = item("Item-Split", 3, 2); bagsChanged()
        eq(A.Store:Get(split.guid), "mail"); eq(A.char.review[split.guid], nil)
        M.bags[0][3] = nil; old.count = 8; bagsChanged()
        assert(A.Store:Eligible(A.API:Read(0, 1), "mail"))
    end)

    for _, override in ipairs({ "locked", "junk", "review" }) do
        test("a remembered type still requires review after a merge from " .. override, function()
            remember(true)
            local first = item("Item-First", 1, 4); local second = item("Item-Second", 2, 3)
            if override ~= "review" then A.Store:Set(A.API:Read(0, 1), override) end
            choose(2, "Mark for Mail")
            if override == "review" then A.char.review[first.guid] = true end
            first.count = 1; second.count = 5; local split = item("Item-Split", 3); bagsChanged()
            eq(A.char.review[second.guid], true); eq(A.char.review[split.guid], true)
            eq(A.Store:Get(split.guid), nil); eq(A.Operations:Eligible(A.API:Read(0, 2), "mail"), false)
            second.count = 6; bagsChanged(); eq(A.char.review[second.guid], true)
            choose(2, "Mark for Mail"); eq(A.char.review[second.guid], nil)
        end)
    end

    test("pausing and resetting stop rule application and preserve previously marked stacks", function()
        remember(true); item("Item-First", 1); choose(1, "Mark for Mail")
        remember(false); choose(1, "Mark as Junk"); item("Item-Paused", 2)
        remember(true); bagsChanged()
        eq(A.char.itemRules[feather], "mail"); eq(A.Store:Get("Item-Paused"), nil)
        eq(A.Store:Get("Item-First"), "junk")
        item("Item-Resumed", 3); bagsChanged(); eq(A.Store:Get("Item-Resumed"), "mail")
        A.Store:ResetSettings(); item("Item-Reset", 4); bagsChanged()
        eq(A.db.rememberItemTypes, false); eq(A.Store:Get("Item-Reset"), nil); eq(A.char.itemRules[feather], "mail")
    end)

    test("only carried copies acquire a rule and bank withdrawals are acquisitions", function()
        remember(true); item("Item-First", 1); choose(1, "Mark for Mail")
        local bank = M.item("Item-Bank", 6, 1, { itemID = feather })
        event("BANKFRAME_OPENED"); M.tick(0); eq(A.Store:Get(bank.guid), nil)
        M.bags[6][1] = nil; M.bags[0][2] = bank; bagsChanged()
        eq(A.Store:Get(bank.guid), "mail"); eq(A.char.review[bank.guid], nil)
    end)

    test("resuming memory during combat baselines the first readable inventory", function()
        remember(true); item("Item-First", 1); choose(1, "Mark for Mail"); remember(false)
        M.combat = true; event("PLAYER_REGEN_DISABLED")
        item("Item-Paused", 2); remember(true)
        M.combat = false; event("PLAYER_REGEN_ENABLED"); M.tick(0)
        eq(A.Store:Get("Item-Paused"), nil)
        item("Item-Next", 3); bagsChanged(); eq(A.Store:Get("Item-Next"), "mail")
    end)

    test("remembered types are isolated per character while the checkbox is shared", function()
        remember(true); item("Item-Main", 1); choose(1, "Mark for Mail")
        local main = BagMarksCharDB
        M.bags = {}; BagMarksCharDB = nil; A.Store:Initialize()
        item("Item-Alt", 1); bagsChanged()
        eq(A.db.rememberItemTypes, true); eq(A.Store:Get("Item-Alt"), nil)
        choose(1, "Mark as Junk"); eq(A.char.itemRules[feather], "junk")
        M.bags = {}; BagMarksCharDB = main; A.Store:Initialize()
        item("Item-NewMain", 1); bagsChanged(); eq(A.Store:Get("Item-NewMain"), "mail")
    end)

    test("old saves create no rules and malformed item types cannot teach future marks", function()
        BagMarksDB = { schema = 2, rememberItemTypes = "true", autoSellJunk = true }
        BagMarksCharDB = { schema = 2, marks = { ["Item-Old"] = { itemID = feather, state = "mail" } } }
        A.Store:Initialize(); eq(A.db.rememberItemTypes, false); eq(A.db.autoSellJunk, true)
        eq(next(A.char.itemRules), nil); eq(A.Store:Get("Item-Old"), "mail")
        BagMarksCharDB.itemRules = { [feather] = "mail", [2] = "junk", [3] = "locked",
            [0] = "mail", [-3] = "junk", [1.5] = "mail", ["17056"] = "junk", [math.huge] = "mail" }
        A.Store:Initialize()
        local count = 0; for _ in pairs(A.char.itemRules) do count = count + 1 end
        eq(count, 2); eq(A.char.itemRules[feather], "mail"); eq(A.char.itemRules[2], "junk")
        local future = { schema = A.schema + 1, itemRules = { [feather] = "different" } }
        BagMarksCharDB = future; A.Store:Initialize(); remember(true); bagsChanged()
        eq(BagMarksCharDB, future); eq(future.itemRules[feather], "different")
    end)

    test("remembered Junk follows normal sale settings and eligibility", function()
        remember(true); item("Item-First", 1); choose(1, "Mark as Junk"); M.bags[0][1] = nil
        local fresh = item("Item-Fresh", 1); local quest = item("Item-Quest", 2); quest.quest = true
        MerchantFrame:Show(); event("MERCHANT_SHOW"); M.tick(1)
        eq(A.Store:Get(fresh.guid), "junk"); eq(A.Store:Get(quest.guid), "junk"); eq(#M.sold, 0)
        event("MERCHANT_CLOSED"); A.SetOption("autoSellJunk", true); event("MERCHANT_SHOW"); M.tick(1)
        eq(#M.sold, 1); eq(M.sold[1], fresh.guid); eq(M.bags[0][2], quest)
    end)
end
