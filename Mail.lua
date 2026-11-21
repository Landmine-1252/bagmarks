-- Blizzard initializes the recipient, subject and reply mode when opening a
-- draft. Defer our work until those handlers finish.
local _, A = ...
local Mail = {}
A.Mail = Mail

local function fieldText(edit)
    local value = edit and edit:GetText()
    if A.Safe(value) and type(value) == "string" then return value end
end

local function hasAttachments()
    if not HasSendMailItem or not ATTACHMENTS_MAX_SEND then return true end
    for i = 1, ATTACHMENTS_MAX_SEND do
        local occupied = HasSendMailItem(i)
        if not A.Safe(occupied) or occupied then return true end
    end
    return false
end

local unreadable = {}
local function readAttachment(slot)
    local occupied = HasSendMailItem(slot)
    if not A.Safe(occupied) then return unreadable end
    if occupied then
        local _, id, _, count = GetSendMailItem(slot)
        local guid = C_TooltipInfo and A.Protection:TooltipGUID(C_TooltipInfo.GetSendMailItem, slot)
        -- An occupied slot can briefly have no readable item details.
        return A.Safe(id) and type(id) == "number" and id or true, guid, A.Safe(count) and type(count) == "number" and count or nil
    end
end

local function draftCopper()
    if MoneyInputFrame_GetCopper and SendMailMoney then
        local copper = MoneyInputFrame_GetCopper(SendMailMoney)
        if A.Safe(copper) then return copper end
        return unreadable
    end
end

local function captureSubmission()
    if not A.API:ComposeOpen() or not HasSendMailItem or not GetSendMailItem or not ATTACHMENTS_MAX_SEND then return end
    local sent = { slots = {}, byGUID = {}, to = fieldText(SendMailNameEditBox), subject = fieldText(SendMailSubjectEditBox),
        body = fieldText(SendMailBodyEditBox), copper = draftCopper() }
    if not Mail.subjectEdited and A.Safe(SendMailFrame.previousItem) and sent.subject == SendMailFrame.previousItem then
        sent.generatedSubject = sent.subject
    end
    for slot = 1, ATTACHMENTS_MAX_SEND do
        local id, guid, count = readAttachment(slot)
        if id then
            local marked = Mail.attached and Mail.attached[slot]
            local job = A.Operations.job
            if job and job.kind == "mail" and job.attachment == slot then marked = job.pending or marked end
            local bagGUID = marked and marked.itemID == id and marked.count == count and marked.guid
            local item = { id = id, count = count, guid = guid or bagGUID }
            sent.slots[slot] = item
            if item.guid then sent.byGUID[item.guid] = item end
        end
    end
    return sent
end

local function unchangedField(edit, sent, generated)
    if not edit then return true end
    local text = fieldText(edit)
    return text ~= nil and (text == "" or text == sent or (A.Safe(generated) and text == generated))
end

local function reconcileSentSlots(sent)
    local remaining, exactSlot = {}, nil
    local wholeDraft = not sent.edited and SendMailFrame.sendMode ~= "reply"
    for slot = 1, ATTACHMENTS_MAX_SEND do
        local id, guid, count = readAttachment(slot)
        -- The client can shift surviving attachments down when a slot clears.
        local old = sent.byGUID[guid] or sent.slots[slot]
        if old and id and (id == old.id or type(id) ~= "number" or type(old.id) ~= "number")
            and (not guid or not old.guid or guid == old.guid)
            and (not count or not old.count or count == old.count) then
            remaining[slot] = old
            if guid and guid == old.guid and not old.removalRequested then exactSlot = slot end
            if id == unreadable or old.id == unreadable then wholeDraft = false end
        elseif id then
            wholeDraft = false
        end
    end
    sent.slots = remaining
    if not next(remaining) then return true end
    local elapsed = GetTime() - sent.successTime
    if elapsed < .6 then return false end
    -- A repaint can never release a native attachment. Clear the submitted
    -- envelope once, and leave any subsequently composed letter intact.
    local copper = draftCopper()
    if wholeDraft and not sent.clearRequested and type(ClearSendMail) == "function"
        and unchangedField(SendMailNameEditBox, sent.to) and unchangedField(SendMailBodyEditBox, sent.body)
        and unchangedField(SendMailSubjectEditBox, sent.subject, SendMailFrame.previousItem)
        and copper ~= unreadable and (copper == nil or copper == 0 or copper == sent.copper) then
        sent.clearRequested = true
        pcall(ClearSendMail)
    elseif exactSlot and type(ClickSendMailItemButton) == "function" and not GetCursorInfo() then
        sent.slots[exactSlot].removalRequested = true
        Mail.removingSentSlot = true
        pcall(ClickSendMailItemButton, exactSlot, true)
        Mail.removingSentSlot = nil
    elseif elapsed >= 3 then
        if not sent.warned then
            sent.warned = true
            A.Print("The mailbox still lists an item that was sent. Close and reopen the mailbox to clear it.")
        end
        return false, true
    end
    return false
end

local function repaintAfterSend(request, sent)
    -- Another mail UI may already have placed items in the new draft.
    if hasAttachments() then
        request.attach = nil
    elseif not Mail.subjectEdited and sent.generatedSubject == fieldText(SendMailSubjectEditBox) then
        SendMailFrame.previousItem = sent.generatedSubject
    end
    local subject = Mail.subjectEdited and fieldText(SendMailSubjectEditBox)
    if Mail.subjectEdited then SendMailFrame.previousItem = nil end
    if SendMailFrame_Update then SendMailFrame_Update() end
    if subject and subject ~= fieldText(SendMailSubjectEditBox) then
        SendMailSubjectEditBox:SetText(subject)
        SendMailFrame.previousItem = nil
    end
end

function Mail:AddressMatches(recipient)
    return A.MailRoutes:MatchesToField(fieldText(SendMailNameEditBox), recipient)
end

function Mail:SendPending()
    return self.sending or self.settling ~= nil
end

function Mail:PlanDraft()
    if self:SendPending() or A.Settings:EditingRecipient() or self.reply or SendMailFrame.sendMode == "reply" then return end
    if not next(A.db.mailRoutes) and not next(A.db.itemRecipients) and A.char.recipient == "" then return end
    local edit = SendMailNameEditBox
    local current = fieldText(edit)
    if not current then return end
    local replaceIdle = self.idleRecipient and current == self.idleRecipient and not hasAttachments()
        and A.db.autoFillRecipient
    if current:find("%S") and not replaceIdle then
        -- A player may change To with the previous batch still in the envelope.
        if self.batchRecipient and hasAttachments() then
            if not self:AddressMatches(self.batchRecipient) then return end
            current = self.batchRecipient
        end
        self.recipientHandled = true
        return A.Operations:CollectMail(current)
    end
    if (self.recipientHandled and not replaceIdle) or not A.db.autoFillRecipient or hasAttachments() then return end
    local entries, recipient = A.Operations:CollectMail()
    recipient = recipient or A.MailRoutes:Fallback()
    if recipient then
        self.recipientHandled = true
        local display = A.MailRoutes:DisplayName(recipient)
        self.idleRecipient = #entries == 0 and display or nil
        edit:SetText(display)
        if edit:HasFocus() then edit:HighlightText() end
    end
    return entries, recipient
end

local function attachmentSubject()
    if not GetSendMailItem or not HasSendMailItem or not ATTACHMENTS_MAX_SEND then return end
    for slot = 1, ATTACHMENTS_MAX_SEND do
        local occupied = HasSendMailItem(slot)
        if not A.Safe(occupied) then return end
        if occupied then
            local name, itemID, _, count = GetSendMailItem(slot)
            if not A.Safe(name) or not A.Safe(itemID) or not A.Safe(count) then return end
            local awaitingName = type(name) ~= "string" or name == ""
            if awaitingName then name = type(itemID) == "number" and "Item " .. itemID or "Items" end
            if type(count) == "number" and count > 1 then name = name .. " (" .. count .. ")" end
            return name, awaitingName
        end
    end
    return ""
end

local function fillSubject()
    local edit = SendMailSubjectEditBox
    local current = fieldText(edit)
    if Mail.subjectEdited or not current then return end
    if current ~= Mail.provisionalSubject and current:find("%S") then
        Mail.provisionalSubject = nil
        return
    end
    local title, awaitingName = attachmentSubject()
    if not title then return end
    if current ~= title then
        edit:SetText(title)
        -- Blizzard uses previousItem to update or clear its own generated title
        -- as attachments change. Use the actual text after the edit box's limit.
        SendMailFrame.previousItem = edit:GetText()
    end
    Mail.provisionalSubject = awaitingName and edit:GetText() or nil
end

function Mail:QueueDraftUpdate(opening)
    if not A.mailOpen or not SendMailFrame or not SendMailFrame:IsVisible() then return end
    local request = self.pending or {}
    if opening and A.CanAct() and A.db.autoAttachMail then request.attach = true end
    if self.pending and not request.waitingForSender and not request.waitingForSlots then return end
    request.waitingForSender, request.waitingForSlots = nil, nil
    self.pending = request
    local function update()
        if self.pending ~= request then return end
        self.pending = nil
        if self.sending or not A.API:ComposeOpen() then return end
        -- Returning from Inbox can reset sendMode to "send" while the same
        -- reply recipient and subject are still in the form.
        if SendMailFrame.sendMode == "reply" then self.reply = true end
        if self.settling then
            -- Native clears can synchronously fire MAIL_SEND_INFO_UPDATE.
            self.pending = request
            local settled, waitForEvent = reconcileSentSlots(self.settling)
            if self.pending ~= request then return end
            if not settled then
                if waitForEvent then request.waitingForSlots = true else C_Timer.After(.2, update) end
                return
            end
            local sent = self.settling
            self.settling = nil
            self.manualDraft = sent.edited
            repaintAfterSend(request, sent)
            self.pending = nil
            A.Operations:RefreshButtons()
        end
        if self.reply then return end
        fillSubject()
        if self.manualDraft then return end
        if (request.attach or (A.db.autoFillRecipient and not self.recipientHandled))
            and (A.char.recipient ~= "" or next(A.db.mailRoutes) or next(A.db.itemRecipients))
            and not A.MailRoutes:PlayerAddress() then
            -- Resume this opening when the client supplies the sender. No item
            -- has been picked up, and a new or closed draft discards the request.
            request.waitingForSender = true
            self.pending = request
            return
        end
        if request.attach and not self.attachAttempted and A.db.autoAttachMail then
            A.Operations:AttachMail(true)
        elseif not self.recipientHandled and A.db.autoFillRecipient and not A.Settings:EditingRecipient() then
            self:PlanDraft()
        end
    end
    C_Timer.After(0, update)
end

function Mail:NewDraft(opening)
    self:ResetDraft()
    self:QueueDraftUpdate(opening)
end

function Mail:ResetDraft()
    self.pending, self.provisionalSubject, self.reply = nil, nil, nil
    self.sending, self.submission, self.attached, self.settling = nil, nil, nil, nil
    self.manualDraft = nil
    self.batchRecipient, self.batchComplete, self.continueAfterSend, self.idleRecipient = nil, nil, nil, nil
    self.recipientHandled, self.subjectEdited, self.attachAttempted = false, false, false
end

function Mail:Close()
    self:ResetDraft()
    self.sentGUIDs = nil
end

function Mail:Sent()
    local sent, continue = self.submission, self.continueAfterSend
    if self.settling and not sent then return end
    self:ResetDraft()
    if not sent and A.API:ComposeOpen() then sent = { slots = {}, byGUID = {} } end
    if sent then
        if sent.edited then continue = false end
        self.sentGUIDs = self.sentGUIDs or {}
        for _, item in pairs(sent.slots) do
            if item.guid then self.sentGUIDs[item.guid] = true end
        end
        sent.successTime = GetTime()
        self.settling = sent
        if SendMailMailButton then SendMailMailButton:SetEnabled(false) end
    end
    self:QueueDraftUpdate(continue)
end

function Mail:InstallHooks()
    if self.hooked or not SendMailFrame or not SendMailNameEditBox or not SendMailSubjectEditBox then return end
    self.hooked = true
    local function stopAttaching()
        if self.pending then self.pending.attach = nil end
        if A.Operations.job and A.Operations.job.kind == "mail" then A.Operations:Cancel() end
    end
    -- The controller footer invokes OnClick directly, even on a disabled button.
    local guardedPrompt
    local function guardControllerSend()
        local footer = SendMailFrame.gamepadFooter
        if not SendMailMailButton or not GAMEPAD_FACE_LEFT or not SEND_LABEL
            or not footer or not footer.GetPromptedBindingToDisplayForKey then return end
        local prompt = footer:GetPromptedBindingToDisplayForKey(GAMEPAD_FACE_LEFT)
        if prompt and prompt ~= guardedPrompt and prompt.AddCondition and prompt.GetFooterBindingLabel
            and prompt:GetFooterBindingLabel() == SEND_LABEL then
            prompt:AddCondition(function() return not A.IsEnabled() or SendMailMailButton:IsEnabled() end)
            guardedPrompt = prompt
        end
    end
    local function composeShown()
        guardControllerSend()
        if not A.mailOpen and A.API:MailInteractionActive() == true then self:OpenMailbox()
        else self:QueueDraftUpdate(true) end
    end
    local function draftEdited()
        local sent = self.settling or self.submission
        if sent then sent.edited = true end
    end
    if SendMailMailButton then
        SendMailMailButton:HookScript("PreClick", function()
            if not self:SendPending() then self.submission = captureSubmission() end
        end)
        SendMailMailButton:HookScript("OnEnable", function(button)
            if A.IsEnabled() and self:SendPending() then button:SetEnabled(false) end
        end)
    end
    if type(SendMailFrame.FocusGamepad) == "function" then hooksecurefunc(SendMailFrame, "FocusGamepad", guardControllerSend) end
    SendMailFrame:HookScript("OnShow", composeShown)
    SendMailFrame:HookScript("OnHide", function()
        self.pending = nil
        stopAttaching()
    end)
    -- Stop on the player's Send click, even while the server reply is pending.
    if type(SendMailFrame_SendMail) == "function" then
        hooksecurefunc(_G, "SendMailFrame_SendMail", function()
            if not A.API:ComposeOpen() or self:SendPending() then return end
            self.submission = self.submission or captureSubmission()
            self.sending = true
            if SendMailMailButton then SendMailMailButton:SetEnabled(false) end
            self.continueAfterSend = self.batchComplete and self:AddressMatches(self.batchRecipient) and not self.reply
            stopAttaching()
            A.Operations:RefreshButtons()
        end)
    end
    -- Removing a stack from a prepared letter is an edit. Do not pick it up
    -- again in a follow-up letter unless the player starts another batch.
    if type(ClickSendMailItemButton) == "function" then
        hooksecurefunc(_G, "ClickSendMailItemButton", function(slot, remove)
            if self.removingSentSlot then return end
            draftEdited()
            if A.Safe(slot) and type(slot) == "number" then
                if self.attached then self.attached[slot] = nil end
                if self.settling and self.settling.slots[slot] then
                    local occupied = HasSendMailItem(slot)
                    if A.Safe(occupied) and not occupied then self.settling.slots[slot] = nil end
                end
            else
                self.attached = nil
            end
            if self.settling and self.pending then self.pending.attach = nil end
            if not self.batchRecipient or not A.Safe(slot) or type(slot) ~= "number" then return end
            local job = A.Operations.job
            if not remove and job and job.kind == "mail" and slot == job.attachment then return end
            local occupied = HasSendMailItem(slot)
            if not A.Safe(occupied) or not occupied then
                self.batchComplete = false
                stopAttaching()
            end
        end)
    end
    SendMailNameEditBox:HookScript("OnTextChanged", function(_, userInput)
        if userInput then
            draftEdited()
            self.recipientHandled, self.idleRecipient, self.batchComplete = true, nil, false
            if self.pending and self.pending.attach then self.attachAttempted = true end
            stopAttaching()
        end
    end)
    SendMailSubjectEditBox:HookScript("OnTextChanged", function(_, userInput)
        if userInput then draftEdited(); self.subjectEdited, self.provisionalSubject = true, nil end
    end)
    if SendMailBodyEditBox then
        SendMailBodyEditBox:HookScript("OnTextChanged", function(_, userInput) if userInput then draftEdited() end end)
    end
    if SendMailFrame:IsVisible() then composeShown() end
end
