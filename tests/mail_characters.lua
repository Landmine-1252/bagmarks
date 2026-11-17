return function(M, A, test, eq, mark)
    local function event(name) A.eventFrame:Fire("OnEvent", name) end

    local function login(character)
        -- WoW reloads the UI, the shared account save and this character's own save.
        local account = BagMarksDB
        M.reset(A)
        BagMarksDB, BagMarksCharDB = account, character
        A.Store:Initialize()
        event("PLAYER_LOGIN"); M.tick(0)
    end

    local function saveRecipient(name)
        A.Settings.frame:Show()
        local field = A.Settings.recipient
        field:SetFocus(); field:SetText(name); field:Fire("OnTextChanged", true)
        field:Fire("OnEnterPressed"); A.Settings.frame:Hide()
    end

    local function openDraft()
        event("MAIL_SHOW"); SendMailFrame:Show(); M.tick(1)
    end

    test("cloth mailed by the blacksmith stays in the tailor's bags and each sender uses its own To", function()
        A.SetOption("rememberItemTypes", true)
        saveRecipient("Tailor-Realm")
        local linen = mark("Item-SmithCloth", 0, 1, "mail", { name = "Linen Cloth", itemID = 2589, count = 8 })
        openDraft()
        eq(SendMailNameEditBox:GetText(), "Tailor-Realm"); eq(SendMailSubjectEditBox:GetText(), "Linen Cloth (8)")
        eq(M.attachments[1], linen)
        M.playerSending = true; SendMailFrame_SendMail(); M.playerSending = nil
        M.attachments[1] = nil; event("MAIL_SEND_SUCCESS"); event("MAIL_CLOSED")
        local blacksmith = BagMarksCharDB

        login(nil)
        eq(A.char.recipient, ""); eq(A.db.rememberItemTypes, true)
        saveRecipient("Blacksmith-Realm")
        assert(M.returnToBags(linen)) -- Delivery retains the sender's exact GUID in this test.
        local moreCloth = M.item("Item-TailorCloth", 0, 2, { name = "Linen Cloth", itemID = 2589 })
        local ore = mark("Item-TailorOre", 0, 3, "mail", { name = "Copper Ore", itemID = 2770 })
        event("BAG_UPDATE_DELAYED"); openDraft()
        eq(A.Store:Get(linen.guid), nil); eq(A.Store:Get(moreCloth.guid), nil)
        eq(SendMailNameEditBox:GetText(), "Blacksmith-Realm"); eq(M.attachments[1], ore); eq(M.attachments[2], nil)
        A.Operations.mailButton:Fire("OnClick"); M.tick(1)
        eq(M.bags[0][1], linen); eq(M.bags[0][2], moreCloth); eq(M.attachments[2], nil)

        login(blacksmith)
        local nextCloth = M.item("Item-NextSmithCloth", 0, 1, { name = "Linen Cloth", itemID = 2589 })
        openDraft()
        eq(M.attachments[1], nextCloth); eq(A.char.itemRules[ore.itemID], nil)
        eq(SendMailNameEditBox:GetText(), "Tailor-Realm")
    end)

    test("an old shared recipient stays available until the chosen character imports it", function()
        BagMarksDB = { schema = 2, recipient = "  Tailor-Realm|\n " }
        login(nil)
        eq(BagMarksDB.recipient, nil); eq(A.db.previousRecipient, "Tailor-Realm")
        openDraft(); eq(SendMailNameEditBox:GetText(), "")
        local firstCharacter = BagMarksCharDB

        login(nil); A.Settings.frame:Show()
        local button = A.Settings.usePreviousRecipient
        eq(button:IsVisible(), true); button:Fire("OnEnter")
        assert(GameTooltip.lines[#GameTooltip.lines]:find("Tailor-Realm", 1, true)); button:Fire("OnLeave")
        button:Fire("OnClick")
        eq(button:IsShown(), false); eq(A.Settings.recipient:GetText(), "Tailor-Realm")
        eq(A.db.previousRecipient, nil); eq(BagMarksDB.recipient, nil)
        login(BagMarksCharDB); openDraft(); eq(SendMailNameEditBox:GetText(), "Tailor-Realm")
        login(firstCharacter); openDraft(); eq(SendMailNameEditBox:GetText(), "")
    end)

    test("clearing or resetting one sender's address preserves the other sender's address", function()
        BagMarksDB = { schema = 3, recipient = "Older-Realm" }
        login({ schema = 3, recipient = " Smith-Realm| " })
        eq(A.char.recipient, "Smith-Realm")
        A.Settings.frame:Show(); eq(A.Settings.usePreviousRecipient:IsShown(), false)
        A.Settings.usePreviousRecipient:Fire("OnClick")
        eq(A.char.recipient, "Smith-Realm"); eq(A.db.previousRecipient, "Older-Realm")
        local tailor = BagMarksCharDB

        login(nil); saveRecipient("Tailor-Realm"); saveRecipient("")
        login(BagMarksCharDB); openDraft(); eq(SendMailNameEditBox:GetText(), "")
        A.SetOption("recipient", "Tailor-Realm"); A.Store:ResetSettings()
        login(BagMarksCharDB); openDraft(); eq(SendMailNameEditBox:GetText(), "")
        login(tailor); openDraft(); eq(SendMailNameEditBox:GetText(), "Smith-Realm")
    end)

    test("a future save blocks recipient edits, import and reset", function()
        local account = { schema = A.schema + 1, previousRecipient = "Previous-Realm" }
        local character = { recipient = "Saved-Realm" }
        BagMarksDB = account; login(character)
        saveRecipient("Other-Realm"); A.SetOption("recipient", "Other-Realm")
        A.Settings.usePreviousRecipient:Fire("OnClick"); A.Store:ResetSettings()
        eq(BagMarksDB, account); eq(BagMarksCharDB, character)
        eq(account.previousRecipient, "Previous-Realm"); eq(character.recipient, "Saved-Realm")
    end)
end
