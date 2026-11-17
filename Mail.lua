-- Blizzard initializes the recipient, subject and reply mode when opening a
-- draft. Defer our work until those handlers finish.
local _, A = ...
local Mail = {}
A.Mail = Mail

local function fieldText(edit)
    local value = edit and edit:GetText()
    if A.Safe(value) and type(value) == "string" then return value end
end

local function fillRecipient()
    if Mail.recipientHandled or not A.db.autoFillRecipient or A.char.recipient == ""
        or A.Settings.recipient:HasFocus() then return end
    local edit = SendMailNameEditBox
    local current = fieldText(edit)
    if not current then return end
    Mail.recipientHandled = true
    if current:find("%S") then return end
    edit:SetText(A.char.recipient)
    if edit:HasFocus() then edit:HighlightText() end
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
    if self.pending then return end
    self.pending = request
    C_Timer.After(0, function()
        if self.pending ~= request then return end
        self.pending = nil
        if not A.API:ComposeOpen() then return end
        -- Returning from Inbox can reset sendMode to "send" while the same
        -- reply recipient and subject are still in the form.
        if SendMailFrame.sendMode == "reply" then self.reply = true end
        if self.reply then return end
        fillRecipient()
        fillSubject()
        if request.attach and not self.attachAttempted and A.db.autoAttachMail then
            A.Operations:AttachMail(true)
        end
    end)
end

function Mail:NewDraft(opening)
    self:Close()
    self:QueueDraftUpdate(opening)
end

function Mail:Close()
    self.pending, self.provisionalSubject, self.reply = nil, nil, nil
    self.recipientHandled, self.subjectEdited, self.attachAttempted = false, false, false
end

function Mail:InstallHooks()
    if self.hooked or not SendMailFrame or not SendMailNameEditBox or not SendMailSubjectEditBox then return end
    self.hooked = true
    local function stopAttaching()
        if self.pending then self.pending.attach = nil end
        if A.Operations.job and A.Operations.job.kind == "mail" then A.Operations:Cancel() end
    end
    SendMailFrame:HookScript("OnShow", function() self:QueueDraftUpdate(true) end)
    SendMailFrame:HookScript("OnHide", function()
        self.pending = nil
        stopAttaching()
    end)
    -- Stop on the player's Send click, even while the server reply is pending.
    if type(SendMailFrame_SendMail) == "function" then hooksecurefunc(_G, "SendMailFrame_SendMail", stopAttaching) end
    SendMailNameEditBox:HookScript("OnTextChanged", function(_, userInput)
        if userInput then self.recipientHandled = true end
    end)
    SendMailSubjectEditBox:HookScript("OnTextChanged", function(_, userInput)
        if userInput then self.subjectEdited, self.provisionalSubject = true, nil end
    end)
    self:QueueDraftUpdate(true)
end
