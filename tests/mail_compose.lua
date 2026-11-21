return function(M, A, test, eq, mark)
    local function event(name) A.eventFrame:Fire("OnEvent", name) end
    local function openSend()
        if A.char.recipient == "" then A.char.recipient = "Bankalt-Realm" end
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

    local function sendWithLateSlots()
        M.playerSending = true; SendMailFrame_SendMail(); M.playerSending = nil
        event("MAIL_SEND_SUCCESS")
        -- Blizzard resets the form while its slot API still reports the sent item.
        SendMailNameEditBox:SetText(""); SendMailSubjectEditBox:SetText(""); SendMailFrame_Update()
        M.tick(0)
    end

    test("a delivered Scroll of Intellect cannot be sent again from a stuck attachment or stale bag slot", function()
        local scroll = stack(1, { itemID = 955, name = "Scroll of Intellect" })
        openSend(); M.tick(1); SendMailFrame_Update()
        local submissions = 0
        local function pressSend()
            if not SendMailMailButton:IsEnabled() then return end
            assert(not M.delivered[M.attachments[1].guid], "Item not found")
            submissions = submissions + 1
            SendMailMailButton:Fire("PreClick")
            M.playerSending = true; SendMailFrame_SendMail(); M.playerSending = nil
        end
        pressSend(); eq(submissions, 1)
        M.delivered[scroll.guid] = true
        M.bags[0][1] = scroll -- The bag cache can outlive the server item too.
        event("MAIL_SEND_SUCCESS"); SendMailFrame_Update()
        SendMailMailButton:SetEnabled(true) -- MAIL_SUCCESS can directly enable the native button.
        pressSend(); M.tick(3)
        eq(submissions, 1); eq(M.clearDraftCalls, 1); eq(next(M.attachments), nil)
        eq(M.mailIcons[1], nil); eq(SendMailSubjectEditBox:GetText(), ""); eq(A.Mail:SendPending() or false, false)
        eq(SendMailMailButton:IsEnabled(), false)
        A.Operations:AttachMail(); M.tick(1); eq(next(M.attachments), nil)
        M.bags[0][1] = nil
        local fresh = stack(2, { itemID = 955, name = "Scroll of Intellect" })
        A.Operations:AttachMail(); M.tick(1); eq(M.attachments[1], fresh)
    end)

    test("sending the last stack repaints the empty slot and clears its generated subject", function()
        local item = stack(1, { name = "Linen Cloth", count = 7 })
        openSend(); M.tick(1); sendWithLateSlots()
        eq(M.mailIcons[1], item.itemID); eq(SendMailSubjectEditBox:GetText(), "Linen Cloth (7)")
        M.attachments = {} -- No additional mail event or tab switch.
        M.tick(1)
        eq(M.mailIcons[1], nil); eq(SendMailSubjectEditBox:GetText(), "")
        eq(SendMailNameEditBox:GetText(), "Bankalt"); eq(A.Operations.job, nil); eq(#M.removals, 0)
        eq(A.Operations.mailButton:IsEnabled(), true)
    end)

    test("the controller Send shortcut respects a pending delivery and a cleaned empty draft", function()
        local scroll = stack(1, { itemID = 955, name = "Scroll of Intellect" })
        openSend(); M.tick(1); SendMailFrame_Update()
        -- Enabling gamepad input after the tab opens creates Blizzard's footer on demand.
        local oldKey, oldLabel = GAMEPAD_FACE_LEFT, SEND_LABEL
        GAMEPAD_FACE_LEFT, SEND_LABEL = "PAD4", "Send"
        local prompt = { conditions = {}, GetFooterBindingLabel = function() return SEND_LABEL end }
        function prompt:AddCondition(condition) table.insert(self.conditions, condition) end
        SendMailFrame.gamepadFooter = { GetPromptedBindingToDisplayForKey = function(_, key)
            if key == GAMEPAD_FACE_LEFT then return prompt end
        end }
        local function pressShortcut()
            for _, condition in ipairs(prompt.conditions) do if not condition() then return false end end
            -- The native binding invokes OnClick directly, bypassing the button's enabled check.
            M.playerSending = true; SendMailFrame_SendMail(); M.playerSending = nil
            return true
        end
        SendMailFrame:FocusGamepad(); SendMailFrame:FocusGamepad()
        eq(pressShortcut(), true); eq(pressShortcut(), false)
        M.delivered[scroll.guid] = true
        event("MAIL_SEND_SUCCESS"); SendMailFrame_Update()
        eq(pressShortcut(), false); M.tick(2); eq(pressShortcut(), false)
        typeText(SendMailNameEditBox, "Another"); typeText(SendMailSubjectEditBox, "New letter")
        SendMailFrame_Update(); eq(pressShortcut(), true); eq(#prompt.conditions, 1)
        SendMailFrame.gamepadFooter, GAMEPAD_FACE_LEFT, SEND_LABEL = nil, oldKey, oldLabel
    end)

    test("an occupied scroll slot with no item details clears and the next real batch loads", function()
        M.missingTooltipGUID = true
        A.Store:SetMailRoute(955, "Bankalt"); A.Store:SetMailRoute(2589, "Tailor")
        local scroll = stack(1, { itemID = 955, name = "Scroll of Intellect" })
        local cloth = stack(2, { itemID = 2589 })
        openSend(); M.tick(1); eq(M.attachments[1], scroll)
        sendWithLateSlots()
        M.delivered[scroll.guid] = true; scroll.missingMailDetails = true; M.bags[0][1] = scroll
        M.tick(2)
        eq(M.clearDraftCalls, 1); eq(SendMailNameEditBox:GetText(), "Tailor"); eq(M.attachments[1], cloth)
        eq(M.attachments[2], nil); eq(M.bags[0][1], scroll)
    end)

    test("stuck sent scroll cleanup preserves new text and other attachments", function()
        local scroll = stack(1, { itemID = 955, name = "Scroll of Intellect" })
        openSend(); M.tick(1); sendWithLateSlots(); M.delivered[scroll.guid] = true
        local other = { guid = "Item-NewLetter", itemID = 955, count = 1 }
        M.attachments[2] = other
        typeText(SendMailNameEditBox, "Another"); typeText(SendMailBodyEditBox, "For tomorrow")
        typeText(SendMailSubjectEditBox, "Supplies"); M.tick(2)
        eq(M.clearDraftCalls, 0); eq(#M.removals, 1); eq(M.removals[1], 1)
        eq(M.attachments[1], nil); eq(M.attachments[2], other)
        eq(SendMailNameEditBox:GetText(), "Another"); eq(SendMailBodyEditBox:GetText(), "For tomorrow")
        eq(SendMailSubjectEditBox:GetText(), "Supplies"); eq(SendMailMailButton:IsEnabled(), true)
    end)

    test("a refused native reset stops retrying and keeps Send blocked until the slot clears", function()
        local scroll = stack(1, { itemID = 955 })
        openSend(); M.tick(1); sendWithLateSlots(); M.delivered[scroll.guid] = true
        M.rejectClearDraft, M.rejectRemoval = true, true
        M.tick(12); eq(M.clearDraftCalls, 1); eq(#M.removals, 1); eq(#M.timers, 0)
        SendMailMailButton:SetEnabled(true); eq(SendMailMailButton:IsEnabled(), false)
        M.attachments = {}; event("BAG_UPDATE_DELAYED"); M.tick(1)
        eq(A.Mail:SendPending(), false); eq(M.mailIcons[1], nil)
    end)

    test("sent stacks are still recognized when the client shifts them into other attachment slots", function()
        local first = stack(1, { itemID = 955 })
        local second = stack(2, { itemID = 955 })
        openSend(); M.tick(1); sendWithLateSlots()
        M.delivered[first.guid], M.delivered[second.guid] = true, true
        local newItem = { guid = "Item-NewLetter", itemID = 955, count = 1 }
        M.attachments[1], M.attachments[2] = second, newItem
        typeText(SendMailNameEditBox, "Another"); typeText(SendMailSubjectEditBox, "Next")
        M.tick(.3); eq(SendMailMailButton:IsEnabled(), false)
        M.tick(2)
        eq(M.attachments[1], nil); eq(M.attachments[2], newItem); eq(M.clearDraftCalls, 0)
        eq(SendMailNameEditBox:GetText(), "Another"); eq(SendMailMailButton:IsEnabled(), true)
    end)

    test("removing a ghost and inserting the same item type before the next update frees the new draft", function()
        M.missingTooltipGUID = true
        local scroll = stack(1, { itemID = 955 })
        openSend(); M.tick(1); sendWithLateSlots(); M.delivered[scroll.guid] = true
        local replacement = stack(2, { itemID = 955 })
        ClickSendMailItemButton(1, true)
        C_Container.PickupContainerItem(0, 2); ClickSendMailItemButton(1)
        typeText(SendMailNameEditBox, "Another"); typeText(SendMailSubjectEditBox, "Another scroll")
        M.tick(4)
        eq(M.attachments[1], replacement); eq(M.clearDraftCalls, 0); eq(#M.removals, 1)
        eq(A.Mail:SendPending(), false); eq(SendMailMailButton:IsEnabled(), true)
    end)

    test("writing the next letter during cleanup pauses automatic batching", function()
        local scroll = stack(1, { itemID = 955 })
        A.Store:SetMailRoute(2589, "Tailor")
        local cloth = stack(2, { itemID = 2589 })
        openSend(); M.tick(1); sendWithLateSlots(); M.delivered[scroll.guid] = true
        typeText(SendMailBodyEditBox, "Player-written letter")
        M.tick(2)
        eq(M.bags[0][2], cloth); eq(next(M.attachments), nil)
        eq(SendMailBodyEditBox:GetText(), "Player-written letter")
        eq(SendMailNameEditBox:GetText(), "")
        eq(A.Operations.mailButton:IsEnabled(), true)
        A.Operations.mailButton:Fire("OnClick"); M.tick(1); eq(M.attachments[1], cloth)
        eq(SendMailNameEditBox:GetText(), "Tailor")
    end)

    test("late clearing of a sent attachment preserves the automatic batch for the next recipient", function()
        A.Store:SetMailRoute(2589, "Tailor"); A.Store:SetMailRoute(2770, "Smith")
        local cloth = stack(1, { itemID = 2589 })
        local ore = stack(2, { itemID = 2770 })
        openSend(); M.tick(1); eq(M.attachments[1], cloth)
        sendWithLateSlots()
        A.Operations:AttachMail() -- Cannot consume the continuation while the old slots are occupied.
        event("MAIL_SEND_INFO_UPDATE"); M.tick(.4)
        eq(M.attachments[2], nil); eq(M.bags[0][2], ore)
        M.attachments = {}; event("MAIL_SEND_INFO_UPDATE"); M.tick(1)
        eq(M.attachments[1], ore); eq(M.attachments[2], nil); eq(SendMailNameEditBox:GetText(), "Smith")
        eq(#M.removals, 0)
    end)

    test("post-send redraw preserves a new attachment and a deliberately blank subject", function()
        stack(1, { itemID = 2589 })
        openSend(); M.tick(1); sendWithLateSlots()
        local replacement = { guid = "Item-NewStack", itemID = 2589, name = "Linen Cloth", count = 2 }
        M.attachments[1] = replacement -- A different mail UI prepared the next draft.
        typeText(SendMailNameEditBox, "Chosen"); typeText(SendMailSubjectEditBox, "")
        M.tick(1)
        eq(M.mailIcons[1], 2589); eq(M.attachments[1], replacement); eq(#M.removals, 0)
        eq(SendMailNameEditBox:GetText(), "Chosen"); eq(SendMailSubjectEditBox:GetText(), "")
        eq(A.Mail.pending, nil)
    end)

    test("a failed send or closed mailbox discards no attachments and cannot repaint a later draft", function()
        local item = stack(1)
        openSend(); M.tick(1); SendMailFrame_Update()
        M.playerSending = true; SendMailFrame_SendMail(); M.playerSending = nil
        event("MAIL_FAILED"); M.tick(1)
        eq(M.mailIcons[1], item.itemID); eq(M.attachments[1], item)
        sendWithLateSlots(); event("MAIL_CLOSED"); M.attachments = {}
        SendMailNameEditBox:SetText("New letter"); M.tick(1)
        eq(M.mailIcons[1], item.itemID, "closed frame should not be repainted")
        eq(SendMailNameEditBox:GetText(), "New letter"); eq(#M.removals, 0)
    end)

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
        eq(SendMailNameEditBox:GetText(), "Bankalt"); eq(SendMailSubjectEditBox:GetText(), "Linen Cloth (7)")
        eq(A.Store:Get(cloth.guid), "mail")
    end)

    test("an already visible compose tab uses free slots and the first existing attachment for the subject", function()
        local marked = stack(1)
        local existing = { name = "Hearthstone", count = 1, itemID = 6948 }
        M.attachments[1] = existing
        for slot = 3, ATTACHMENTS_MAX_SEND do M.attachments[slot] = existing end
        stack(2); SendMailNameEditBox:SetText("Chosen-Realm")
        A.char.recipient = "Chosen-Realm"
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
        eq(M.attachments[1], nil); eq(SendMailNameEditBox:GetText(), "")
        eq(SendMailSubjectEditBox:GetText(), "Crafting supplies")
    end)

    test("an attachment button click cannot rewrite a recipient cleared by another mail UI", function()
        A.char.recipient = "Bankalt-Realm"
        openSend(); M.tick(0); eq(SendMailNameEditBox:GetText(), "Bankalt")
        SendMailNameEditBox:SetText("") -- Programmatic edits have no userInput flag.
        stack(1); A.Operations.mailButton:Fire("OnClick"); event("MAIL_SEND_INFO_UPDATE"); M.tick(1)
        eq(SendMailNameEditBox:GetText(), ""); eq(SendMailSubjectEditBox:GetText(), ""); eq(next(M.attachments), nil)
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
        eq(next(M.attachments), nil); eq(SendMailNameEditBox:GetText(), "")
        typeText(SendMailNameEditBox, "Default-Realm")
        A.Operations.mailButton:Fire("OnClick"); M.tick(1)
        eq(M.attachments[1], marked); eq(SendMailSubjectEditBox:GetText(), "Copper Ore")
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
        eq(SendMailNameEditBox:GetText(), "Default"); eq(next(M.attachments), nil)
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
