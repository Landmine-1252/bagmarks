return function(M, A, test, eq, mark)
    local function event(name) A.eventFrame:Fire("OnEvent", name) end

    local function login(character, playerName, realm)
        -- WoW reloads the UI, the shared account save and this character's own save.
        local account = BagMarksDB
        M.reset(A)
        M.playerName, M.realm = playerName, realm
        BagMarksDB, BagMarksCharDB = account, character
        A.Store:Initialize()
        event("PLAYER_LOGIN"); M.tick(0)
    end

    local function saveRecipient(name)
        A.Settings.frame:Show(); A.Settings:SelectTab("Mail")
        local field = A.Settings.recipient
        field:SetFocus(); field:SetText(name); field:Fire("OnTextChanged", true)
        field:Fire("OnEnterPressed"); A.Settings.frame:Hide()
    end

    local function openDraft()
        event("MAIL_SHOW"); SendMailFrame:Show(); M.tick(1)
    end

    test("mail uses the native Forever surname when the display lookup only reports a first name", function()
        M.regionalNames, M.playerName, M.playerSurname = true, "Aster", "Smith"
        local unmodified = UnitNameUnmodified
        UnitNameUnmodified = function() return "Aster" end
        A.char.recipient = "Aster Tailor-Realm"
        A.db.itemRecipients[2770] = "Aster Smith-Realm"
        mark("Item-OwnOre", 0, 1, "mail", { itemID = 2770 })
        local cloth = mark("Item-FallbackCloth", 0, 2, "mail", { itemID = 2589 })
        openDraft()
        local own, other = A.MailRoutes:Tooltip(2770), A.MailRoutes:Tooltip(2589)
        UnitNameUnmodified = unmodified
        eq(own, "Mail (Keep on this character)")
        eq(other, "Mail to Aster Tailor (Character override)")
        eq(SendMailNameEditBox:GetText(), "Aster Tailor"); eq(M.attachments[1], cloth); eq(M.attachments[2], nil)
    end)

    test("regional mail can verify the sender and use a saved destination before realm data arrives", function()
        M.regionalNames, M.playerName, M.realm = true, "Aster Smith", ""
        A.char.recipient = "Aster Tailor"
        A.db.itemRecipients[2770] = "Aster Smith-OldRealm"
        mark("Item-Self", 0, 1, "mail", { itemID = 2770 })
        local cloth = mark("Item-UnqualifiedCloth", 0, 2, "mail", { itemID = 2589 })
        openDraft()
        eq(A.MailRoutes:Tooltip(2770), "Mail (Keep on this character)")
        eq(SendMailNameEditBox:GetText(), "Aster Tailor"); eq(M.attachments[1], cloth); eq(M.attachments[2], nil)
    end)

    test("a fresh draft waits for the player's surname and completes once it is known", function()
        M.regionalNames, M.playerName = true, "Aster"
        A.char.recipient = "Aster Tailor-Realm"
        local item = mark("Item-LateSender", 0, 1, "mail")
        openDraft()
        eq(SendMailNameEditBox:GetText(), ""); eq(next(M.attachments), nil)
        M.playerSurname = "Smith"
        A.eventFrame:Fire("OnEvent", "UNIT_NAME_UPDATE", "player"); M.tick(1)
        eq(SendMailNameEditBox:GetText(), "Aster Tailor"); eq(M.attachments[1], item)
    end)

    test("an incomplete unit name can use a full name verified for this player GUID only", function()
        M.regionalNames, M.playerName = true, "Aster"
        local oldGUID, oldNameFromGUID = UnitGUID, UnitNameFromGUID
        local guid = "Player-1-1"
        UnitGUID = function(unit) assert(unit == "player"); return guid end
        UnitNameFromGUID = function(id) assert(id == guid); return "Aster Smith" end
        event("PLAYER_LOGIN")
        UnitNameFromGUID = function() return "Aster", M.realm or "Realm" end
        A.char.recipient = "Aster Tailor-Realm"
        local item = mark("Item-GuidMail", 0, 1, "mail")
        openDraft()
        eq(SendMailNameEditBox:GetText(), "Aster Tailor"); eq(M.attachments[1], item)
        guid = "Player-1-2"; eq(A.MailRoutes:PlayerAddress(), nil)
        UnitGUID, UnitNameFromGUID = oldGUID, oldNameFromGUID
    end)

    test("a waiting draft respects a player's To edit and mailbox closure", function()
        M.regionalNames, M.playerName = true, "Aster"
        A.char.recipient = "Aster Tailor-Realm"
        mark("Item-PendingMail", 0, 1, "mail")
        openDraft()
        SendMailNameEditBox:SetText("Aster Tailor"); SendMailNameEditBox:Fire("OnTextChanged", true)
        M.playerSurname = "Smith"
        A.eventFrame:Fire("OnEvent", "UNIT_NAME_UPDATE", "player"); M.tick(1)
        eq(next(M.attachments), nil); eq(SendMailNameEditBox:GetText(), "Aster Tailor")
        SendMailFrame:Hide(); SendMailFrame:Show(); M.tick(1); eq(next(M.attachments), nil)
        event("MAIL_CLOSED"); SendMailNameEditBox:SetText(""); M.playerSurname = nil
        openDraft(); event("MAIL_CLOSED"); M.playerSurname = "Smith"; event("BAG_UPDATE_DELAYED"); M.tick(1)
        eq(SendMailNameEditBox:GetText(), ""); eq(next(M.attachments), nil)
    end)

    test("Choose recovers separate Forever surnames and legacy picker rules for multiple senders", function()
        M.regionalNames, M.realm = true, "CAMWOWUS1Realm9RPPvP"
        M.playerName, M.playerSurname = "Landmine", "Ill"
        BagMarksDB = { schema = 7, knownCharacters = {
            ["Landmine-Ill"] = true, ["Landmine-Tailor"] = true, ["Landmine-" .. M.realm] = true,
        }, mailRoutes = { cloth = "Landmine-Tailor" }, itemRecipients = { [17056] = "Landmine-Ill" } }
        BagMarksCharDB = { schema = 7, recipient = "Landmine-Tailor" }
        A.Store:Initialize(); event("PLAYER_LOGIN")
        eq(A.MailRoutes:PlayerAddress(), "Landmine Ill-" .. M.realm)
        eq(A.char.recipient, "Landmine Tailor")
        eq(A.MailRoutes:Tooltip(17056), "Mail (Keep on this character)")
        local settings = A.Settings
        settings:Toggle(); settings:SelectTab("Mail")
        local cloth
        for _, field in ipairs(settings.addressFields) do
            if field.key == "cloth" then cloth = field; break end
        end
        cloth.choose:Fire("OnClick")
        eq(#M.menu.choices, 2)
        eq(M.menu.choices[1].text, "Landmine Ill"); eq(M.menu.choices[2].text, "Landmine Tailor")
        eq(M.menu.choices[2].selected(), true)
        M.menu.choices[1].callback(); eq(cloth:GetText(), "Landmine Ill")
        M.playerSurname = "Miner"; M.realm = "CAMWOWUS1Realm12RPPvP"
        BagMarksCharDB = { schema = 7, recipient = "Landmine-Ill" }
        A.Store:Initialize(); event("PLAYER_ENTERING_WORLD")
        eq(A.char.recipient, "Landmine Ill"); eq(A.db.knownCharacters["Landmine Miner-" .. M.realm], true)
        mark("Item-LegacyRule", 0, 1, "mail", { itemID = 17056 })
        settings.frame:Hide(); openDraft()
        eq(SendMailNameEditBox:GetText(), "Landmine Ill"); eq(M.attachments[1].itemID, 17056)
        M.playerSurname = nil; event("PLAYER_LOGIN")
        eq(A.MailRoutes:PlayerAddress(), nil)
    end)

    test("switching characters keeps the full player name and hides the internal server across mail surfaces", function()
        local realm = "CAMWOWUS1Realm9RPPvP"
        local name = "Landmine Ill"
        local address = name .. "-" .. realm
        login(nil, name, realm)
        A.Store:SetMailRoute("cloth", name)
        A.Store:SetMailRoute(211780, name)
        local receiver = BagMarksCharDB

        login(nil, "Landmine Miner", "CAMWOWUS1Realm12RPPvP")
        A.Settings.frame:Show(); A.Settings:SelectTab("Mail")
        local cloth
        for _, edit in ipairs(A.Settings.addressFields) do
            if edit.key == "cloth" then cloth = edit end
        end
        eq(cloth:GetText(), name)
        cloth.choose:Fire("OnClick"); eq(M.menu.choices[1].text, name)
        M.menu.choices[1].callback(); eq(A.db.mailRoutes.cloth, address)
        A.Settings:OpenItemRoutes(211780); eq(A.Settings.ruleRecipient:GetText(), name)
        A.Settings.ruleSave:Fire("OnClick"); eq(A.db.itemRecipients[211780], address)
        A.Settings.frame:Hide()

        local linen = mark("Item-Linen", 0, 1, "mail", { itemID = 2589, class = 7, subclass = 5 })
        local scroll = mark("Item-Scroll", 0, 2, "mail", { itemID = 211780 })
        eq(A.MailRoutes:Tooltip(linen.itemID), "Mail to Landmine Ill (Cloth)")
        openDraft(); eq(SendMailNameEditBox:GetText(), name)
        eq(M.attachments[1], linen); eq(M.attachments[2], scroll)
        assert(M.messages[#M.messages]:find("attached for Landmine Ill.", 1, true))

        login(receiver, name, "CAMWOWUS1Realm14RPPvP")
        local held = mark("Item-OwnScroll", 0, 1, "mail", { itemID = 211780 })
        openDraft(); eq(next(M.attachments), nil); eq(M.bags[0][1], held)
        eq(SendMailNameEditBox:GetText(), ""); eq(A.MailRoutes:Tooltip(held.itemID), "Mail (Keep on this character)")
    end)

    test("cloth mailed by the blacksmith stays in the tailor's bags and each sender uses its own To", function()
        A.SetOption("rememberItemTypes", true)
        saveRecipient("Tailor-Realm")
        local linen = mark("Item-SmithCloth", 0, 1, "mail", { name = "Linen Cloth", itemID = 2589, count = 8 })
        openDraft()
        eq(SendMailNameEditBox:GetText(), "Tailor"); eq(SendMailSubjectEditBox:GetText(), "Linen Cloth (8)")
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
        eq(SendMailNameEditBox:GetText(), "Blacksmith"); eq(M.attachments[1], ore); eq(M.attachments[2], nil)
        A.Operations.mailButton:Fire("OnClick"); M.tick(1)
        eq(M.bags[0][1], linen); eq(M.bags[0][2], moreCloth); eq(M.attachments[2], nil)

        login(blacksmith)
        local nextCloth = M.item("Item-NextSmithCloth", 0, 1, { name = "Linen Cloth", itemID = 2589 })
        openDraft()
        eq(M.attachments[1], nextCloth); eq(A.char.itemRules[ore.itemID], nil)
        eq(SendMailNameEditBox:GetText(), "Tailor")
    end)

    test("an old shared recipient stays available until the chosen character imports it", function()
        BagMarksDB = { schema = 2, recipient = "  Tailor-Realm|\n " }
        login(nil)
        eq(BagMarksDB.recipient, nil); eq(A.db.previousRecipient, "Tailor-Realm")
        openDraft(); eq(SendMailNameEditBox:GetText(), "")
        local firstCharacter = BagMarksCharDB

        login(nil, "Landmine Miner", "OtherRealm"); A.Settings.frame:Show(); A.Settings:SelectTab("Mail")
        local button = A.Settings.usePreviousRecipient
        eq(button:IsVisible(), true); button:Fire("OnEnter")
        eq(GameTooltip.lines[#GameTooltip.lines], "Use Tailor as the default recipient for this character only."); button:Fire("OnLeave")
        button:Fire("OnClick")
        eq(button:IsShown(), false); eq(A.Settings.recipient:GetText(), "Tailor")
        eq(A.db.previousRecipient, nil); eq(BagMarksDB.recipient, nil)
        login(BagMarksCharDB); openDraft(); eq(SendMailNameEditBox:GetText(), "Tailor")
        login(firstCharacter); openDraft(); eq(SendMailNameEditBox:GetText(), "")
    end)

    test("clearing or resetting one sender's address preserves the other sender's address", function()
        BagMarksDB = { schema = 3, recipient = "Older-Realm" }
        login({ schema = 3, recipient = " Smith-Realm| " })
        eq(A.char.recipient, "Smith-Realm")
        A.Settings.frame:Show(); A.Settings:SelectTab("Mail"); eq(A.Settings.usePreviousRecipient:IsShown(), false)
        A.Settings.usePreviousRecipient:Fire("OnClick")
        eq(A.char.recipient, "Smith-Realm"); eq(A.db.previousRecipient, "Older-Realm")
        local tailor = BagMarksCharDB

        login(nil); saveRecipient("Tailor-Realm"); saveRecipient("")
        login(BagMarksCharDB); openDraft(); eq(SendMailNameEditBox:GetText(), "")
        A.SetOption("recipient", "Tailor-Realm"); A.Store:ResetSettings()
        login(BagMarksCharDB); openDraft(); eq(SendMailNameEditBox:GetText(), "")
        login(tailor); openDraft(); eq(SendMailNameEditBox:GetText(), "Smith")
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
