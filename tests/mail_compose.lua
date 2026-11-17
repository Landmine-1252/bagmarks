return function(M, A, test, eq, mark)
    local function event(name) A.eventFrame:Fire("OnEvent", name) end
    local function openSend()
        event("MAIL_SHOW")
        SendMailFrame:Show()
    end
    local function stack(slot, options)
        return mark("Item-Mail" .. slot, 0, slot, "mail", options)
    end
    local function typeText(edit, text)
        edit:SetText(text)
        edit:Fire("OnTextChanged", true)
    end

    test("opening the Send Mail tab fills the fresh draft and attaches only eligible carried marks", function()
        A.char.recipient = "Bankalt-Realm"
        local cloth = stack(1, { name = "Linen Cloth", count = 7 })
        local stone = stack(2, { name = "Rough Stone" })
        stack(3, { bound = true })
        mark("Item-L", 0, 4, "locked"); mark("Item-J", 0, 5, "junk"); M.item("Item-N", 0, 6)
        A.bankOpen = true; mark("Item-Bank", 6, 1, "mail")
        event("MAIL_SHOW"); M.tick(1)
        eq(next(M.attachments), nil); eq(SendMailNameEditBox:GetText(), ""); eq(SendMailSubjectEditBox:GetText(), "")
        SendMailFrame:Show(); M.tick(1)
        eq(M.attachments[1], cloth); eq(M.attachments[2], stone); eq(M.attachments[3], nil)
        eq(SendMailNameEditBox:GetText(), "Bankalt-Realm"); eq(SendMailSubjectEditBox:GetText(), "Linen Cloth (7)")
        eq(A.Store:Get(cloth.guid), "mail")
    end)

    test("an already visible compose tab uses free slots and the first existing attachment for the subject", function()
        local marked = stack(1)
        local existing = { name = "Hearthstone", count = 1, itemID = 6948 }
        M.attachments[1] = existing
        for slot = 3, ATTACHMENTS_MAX_SEND do M.attachments[slot] = existing end
        stack(2); SendMailNameEditBox:SetText("Chosen-Realm")
        A.char.recipient = "Default-Realm"
        SendMailFrame:Show(); event("MAIL_SHOW"); M.tick(1)
        eq(M.attachments[1], existing); eq(M.attachments[2], marked); eq(M.bags[0][2].guid, "Item-Mail2")
        eq(SendMailNameEditBox:GetText(), "Chosen-Realm"); eq(SendMailSubjectEditBox:GetText(), "Hearthstone")
    end)

    test("attachments removed by the player and an edited To survive duplicate events and tab switches", function()
        A.char.recipient = "Bankalt-Realm"
        local marked = stack(1)
        openSend(); M.tick(1)
        eq(M.attachments[1], marked)
        ClickSendMailItemButton(1, true)
        typeText(SendMailNameEditBox, "")
        event("MAIL_SHOW"); event("MAIL_SEND_INFO_UPDATE"); event("BAG_UPDATE_DELAYED")
        SendMailFrame:Hide(); SendMailFrame:Show(); M.tick(1)
        eq(next(M.attachments), nil); eq(M.bags[0][1], marked); eq(SendMailNameEditBox:GetText(), "")
        SendMailSubjectEditBox:SetText("Crafting supplies")
        A.Operations.mailButton:Fire("OnClick"); M.tick(1)
        eq(M.attachments[1], marked); eq(SendMailNameEditBox:GetText(), "")
        eq(SendMailSubjectEditBox:GetText(), "Crafting supplies")
    end)

    test("an attachment button click cannot rewrite a recipient cleared by another mail UI", function()
        A.char.recipient = "Bankalt-Realm"
        openSend(); M.tick(0); eq(SendMailNameEditBox:GetText(), "Bankalt-Realm")
        SendMailNameEditBox:SetText("") -- Programmatic edits have no userInput flag.
        stack(1); A.Operations.mailButton:Fire("OnClick"); event("MAIL_SEND_INFO_UPDATE"); M.tick(1)
        eq(SendMailNameEditBox:GetText(), ""); eq(SendMailSubjectEditBox:GetText(), "Test item")
    end)

    test("deferred opening skips replies even when Blizzard sets reply mode after showing Send Mail", function()
        A.char.recipient = "Default-Realm"
        stack(1); openSend()
        SendMailFrame.sendMode = "reply"
        SendMailNameEditBox:SetText("Sender"); SendMailSubjectEditBox:SetText("Re: Order")
        event("MAIL_SEND_INFO_UPDATE"); M.tick(1)
        eq(next(M.attachments), nil); eq(SendMailNameEditBox:GetText(), "Sender")
        eq(SendMailSubjectEditBox:GetText(), "Re: Order")
        SendMailFrame:Hide(); SendMailFrame.sendMode = "send"; SendMailFrame:Show(); M.tick(1)
        eq(next(M.attachments), nil); eq(SendMailSubjectEditBox:GetText(), "Re: Order")
    end)

    test("automatic and manual attachment settings work independently of recipient autofill", function()
        eq(A.db.autoAttachMail, true)
        local check = A.Settings.checks.autoAttachMail
        check:SetChecked(false); check:Fire("OnClick"); A.Store:Initialize(); eq(A.db.autoAttachMail, false)
        A.db.autoFillRecipient, A.char.recipient = false, "Default-Realm"
        local marked = stack(1, { name = "Copper Ore" })
        openSend(); event("MAIL_SEND_INFO_UPDATE"); M.tick(1)
        eq(next(M.attachments), nil); eq(SendMailSubjectEditBox:GetText(), "")
        A.Operations.mailButton:Fire("OnClick"); M.tick(1)
        eq(M.attachments[1], marked); eq(SendMailNameEditBox:GetText(), "")
        eq(SendMailSubjectEditBox:GetText(), "Copper Ore")
    end)

    test("disabling automatic attachment stops the batch and allows a manual finish", function()
        local first, second = stack(1), stack(2)
        openSend(); M.tick(0); eq(M.attachments[1], first)
        A.SetOption("autoAttachMail", false); eq(A.Operations.job, nil)
        A.SetOption("autoAttachMail", true); event("BAG_UPDATE_DELAYED"); M.tick(1)
        eq(M.attachments[2], nil); eq(M.bags[0][2], second)
        A.Operations.mailButton:Fire("OnClick"); M.tick(1); eq(M.attachments[2], second)
    end)

    test("leaving Send Mail cancels a batch even if the tab reopens before its next poll", function()
        local first, second = stack(1), stack(2)
        openSend(); M.tick(0); eq(M.attachments[1], first)
        SendMailFrame:Hide(); SendMailFrame:Show(); M.tick(1)
        eq(A.Operations.job, nil); eq(M.attachments[2], nil); eq(M.bags[0][2], second)
    end)

    test("closing or sending before the deferred opening discards the pending batch", function()
        A.char.recipient = "Default-Realm"
        local item = stack(1)
        openSend(); event("MAIL_CLOSED"); M.tick(0)
        eq(SendMailNameEditBox:GetText(), ""); eq(next(M.attachments), nil)
        openSend(); event("MAIL_SEND_SUCCESS"); M.tick(1)
        eq(SendMailNameEditBox:GetText(), "Default-Realm"); eq(next(M.attachments), nil)
        eq(SendMailSubjectEditBox:GetText(), ""); eq(M.bags[0][1], item)
    end)

    test("clicking Send stops the pending attachment queue before the server responds", function()
        local first, second = stack(1), stack(2)
        openSend(); M.tick(0); eq(M.attachments[1], first)
        M.playerSending = true; SendMailFrame_SendMail(); M.playerSending = nil
        event("MAIL_SEND_INFO_UPDATE"); M.tick(1)
        eq(A.Operations.job, nil); eq(M.attachments[2], nil); eq(M.bags[0][2], second)
        event("MAIL_SEND_SUCCESS"); M.tick(1); eq(M.attachments[2], nil)
    end)

    test("combat, a carried cursor and a hidden mail parent prevent automatic attachment", function()
        local item = stack(1)
        openSend(); M.combat = true; event("PLAYER_REGEN_DISABLED")
        M.combat = false; event("PLAYER_REGEN_ENABLED"); M.tick(1); eq(next(M.attachments), nil)
        event("MAIL_CLOSED"); openSend(); M.cursor = { item = {} }
        M.tick(1); eq(next(M.attachments), nil); assert(M.cursor)
        M.cursor = nil; event("MAIL_CLOSED")
        local hidden = CreateFrame("Frame", nil, UIParent)
        hidden:Hide(); SendMailFrame:SetParent(hidden)
        openSend(); M.tick(1); SendMailFrame:SetParent(UIParent)
        eq(next(M.attachments), nil); eq(M.bags[0][1], item)
    end)

    test("a manual attachment update repairs a missing subject but respects subsequent user edits", function()
        openSend(); M.tick(0)
        M.attachments[3] = { itemID = 2589, name = "Linen Cloth", count = 5 }
        event("MAIL_SEND_INFO_UPDATE"); M.tick(0)
        eq(SendMailSubjectEditBox:GetText(), "Linen Cloth (5)")
        eq(SendMailFrame.previousItem, "Linen Cloth (5)")
        typeText(SendMailSubjectEditBox, ""); event("MAIL_SEND_INFO_UPDATE"); M.tick(0)
        eq(SendMailSubjectEditBox:GetText(), "")
        typeText(SendMailSubjectEditBox, "Supplies"); stack(1)
        A.Operations.mailButton:Fire("OnClick"); M.tick(1); eq(SendMailSubjectEditBox:GetText(), "Supplies")
    end)

    test("an uncached attachment gets an item-number subject and does not stall the next stack", function()
        local first = stack(1, { itemID = 2589, uncached = true, count = 3 })
        local second = stack(2)
        openSend(); M.tick(1)
        eq(M.attachments[1], first); eq(M.attachments[2], second)
        eq(SendMailSubjectEditBox:GetText(), "Item 2589 (3)")
        first.uncached, first.name = false, "Linen Cloth"
        event("ITEM_DATA_LOAD_RESULT"); M.tick(0)
        eq(SendMailSubjectEditBox:GetText(), "Linen Cloth (3)")
    end)

    test("late attachment details preserve a subject the player typed over the placeholder", function()
        openSend(); M.tick(0)
        M.attachments[1] = { uncached = true }
        event("MAIL_SEND_INFO_UPDATE"); M.tick(0); eq(SendMailSubjectEditBox:GetText(), "Items")
        typeText(SendMailSubjectEditBox, "Materials for tonight")
        M.attachments[1] = { itemID = 2589, name = "Linen Cloth", count = 10 }
        event("GET_ITEM_INFO_RECEIVED"); event("MAIL_SEND_INFO_UPDATE"); M.tick(0)
        eq(SendMailSubjectEditBox:GetText(), "Materials for tonight")
    end)

    test("a refused automatic attachment leaves the subject blank until a manual retry succeeds", function()
        local marked = stack(1, { name = "Copper Ore" })
        M.rejectMail = true; openSend(); M.tick(1)
        eq(next(M.attachments), nil); eq(M.cursor, nil); eq(M.bags[0][1], marked)
        M.rejectMail = false; event("MAIL_SEND_INFO_UPDATE"); M.tick(1)
        eq(next(M.attachments), nil); eq(SendMailSubjectEditBox:GetText(), "")
        A.Operations.mailButton:Fire("OnClick"); M.tick(1)
        eq(M.attachments[1], marked); eq(SendMailSubjectEditBox:GetText(), "Copper Ore")
    end)

    test("the exact attachment GUID confirms a stack still locked in its bag slot", function()
        local first, second = stack(1), stack(2)
        openSend(); M.tick(0); eq(M.attachments[1], first)
        M.bags[0][1] = first; first.busy = true
        M.tick(1); eq(M.attachments[2], second); eq(A.Operations.job, nil)
    end)

    test("a different attachment GUID with the expected item ID and count stops the batch", function()
        stack(1); local second = stack(2)
        openSend(); M.tick(0)
        M.attachments[1] = { guid = "Item-Other", itemID = 100, count = 1 }
        M.tick(3); eq(A.Operations.job, nil); eq(M.bags[0][2], second); eq(M.attachments[2], nil)
    end)
end
