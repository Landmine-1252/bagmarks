local _, A = ...
A.UI = {}
local UI = A.UI

function UI.Label(parent, text, x, y, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(text)
    return label
end

function UI.Button(parent, text, width, x, y, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

function UI.Tip(widget, title, body)
    widget:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(body, .9, .9, .9, true)
        GameTooltip:Show()
    end)
    widget:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

function UI.Window(name, title, width, height)
    local frame = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame.TitleText:SetText(title)
    UISpecialFrames[#UISpecialFrames + 1] = name
    frame:Hide()
    return frame
end

function UI:Confirm(title, text, acceptText, callback)
    if not self.confirm then
        local f = self.Window("BagMarksConfirm", "BagMarks", 390, 340)
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 20, -42)
        scroll:SetPoint("BOTTOMRIGHT", -38, 52)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(330, 240)
        scroll:SetScrollChild(content)
        f.scroll, f.content = scroll, content
        f.body = self.Label(content, "", 0, 0)
        f.body:SetWidth(330)
        f.body:SetJustifyH("LEFT")
        f.body:SetJustifyV("TOP")
        f.accept = self.Button(f, "Confirm", 160, 20, -298, function()
            local action = f.callback
            f:Hide()
            if action then action() end
        end)
        self.Button(f, "Cancel", 160, 210, -298, function() f:Hide() end)
        f:SetScript("OnHide", function() f.callback = nil end)
        self.confirm = f
    end
    local f = self.confirm
    f.TitleText:SetText(title)
    f.body:SetText(text)
    f.content:SetHeight(math.max(240, f.body:GetStringHeight() + 10))
    f.scroll:SetVerticalScroll(0)
    f.accept:SetText(acceptText)
    f.callback = callback
    f:Show()
end

function UI:CloseConfirmation()
    if self.confirm then self.confirm:Hide() end
end

function UI:ItemChoices(root, item)
    local guid = item.guid
    if A.char.review[guid] then root:CreateTitle("Stack changed. Reapply a mark to review.") end
    local choices = {
        { "Lock Item", "locked" }, { "Mark as Junk", "junk" },
        { "Mark for Mail", "mail" }, { "Clear Mark", false },
    }
    for _, choice in ipairs(choices) do
        local state = choice[2] or nil
        root:CreateRadio(choice[1], function() return A.Store:Get(guid) == state end, function()
            if not A.CanAct() then return end
            -- Menus bind to identity, never the slot that happened to open them.
            local current = A.API:Find(guid, true)
            if current then A.Store:Set(current, state)
            else A.Print("That item is no longer available. Open its menu again.") end
        end)
    end
end

function UI:ItemMenu(owner, item, stacks)
    if not A.CanAct() or not item then return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        A.Print("This client does not expose Blizzard's context menu API.")
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("BagMarks")
        if stacks then
            root:CreateTitle("Choose one stack")
            if #stacks > 10 then root:SetScrollMode(300) end
            for _, stack in ipairs(stacks) do
                local location = stack.bag == 0 and "Backpack" or ("Bag " .. stack.bag)
                local state = A.Store:Get(stack.guid)
                local label = location .. ", slot " .. stack.slot .. " (" .. stack.count .. ") - " .. (A.states[state] or "Normal")
                self:ItemChoices(root:CreateButton(label), stack)
            end
        else
            self:ItemChoices(root, item)
        end
    end)
end
