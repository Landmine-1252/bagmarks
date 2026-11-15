local _, A = ...
local Mail = { generation = 0 }
A.Mail = Mail

function Mail:FillRecipient()
    if not A.CanAct() or not A.db.autoFillRecipient or A.db.recipient == "" or not A.mailOpen
        or not SendMailFrame or not SendMailFrame:IsShown() or not SendMailNameEditBox
        or self.touched or SendMailFrame.sendMode == "reply" then return false end
    if A.Settings.recipient and A.Settings.recipient:HasFocus() then return false end
    local edit = SendMailNameEditBox
    if not edit:GetText():match("^%s*$") then return false end
    edit:SetText(A.db.recipient)
    -- Blizzard focuses this field on opening. Select our default so typing a
    -- different recipient replaces it instead of appending to the saved name.
    if edit:HasFocus() then edit:HighlightText() end
    return true
end

function Mail:QueueFill()
    if self.pending then return end
    local token, generation = {}, self.generation
    self.pending = token
    -- Run after Blizzard's tab/reset/reply handlers and preserve any name they set.
    C_Timer.After(0, function()
        if self.pending ~= token then return end
        self.pending = nil
        if generation == self.generation then self:FillRecipient() end
    end)
end

function Mail:NewDraft()
    self.generation = self.generation + 1
    self.pending, self.touched = nil, false
    self:QueueFill()
end

function Mail:Close()
    self.generation = self.generation + 1
    self.pending, self.touched = nil, false
end

function Mail:InstallHooks()
    if self.hooked or not SendMailFrame or not SendMailNameEditBox then return end
    self.hooked = true
    SendMailFrame:HookScript("OnShow", function() self:QueueFill() end)
    SendMailNameEditBox:HookScript("OnTextChanged", function(_, userInput)
        if userInput then self.touched = true end
    end)
    self:QueueFill()
end
