-- Shared window and control styles, a reusable confirmation dialog, and item
-- menus. Menu callbacks carry GUIDs so delayed choices survive slot movement.
local _, A = ...
A.UI = {}
local UI = A.UI
local colors = {
    window = { .060, .078, .098 }, rail = { .079, .099, .124 }, panel = { .096, .119, .145 },
    field = { .055, .073, .093 }, button = { .134, .165, .198 }, edge = { .19, .235, .275 },
    hover = { .18, .24, .285 }, selected = { .078, .225, .257 }, accent = { .34, .83, .85 },
    text = { .94, .96, .98 }, muted = { .70, .76, .81 },
}
UI.colors = colors
local white = "Interface\\Buttons\\WHITE8X8"
local backdrop = { bgFile = white, edgeFile = white, edgeSize = 1 }

function UI.Skin(frame, surface, edge)
    frame:SetBackdrop(backdrop)
    frame:SetBackdropColor(unpack(colors[surface]))
    frame:SetBackdropBorderColor(unpack(colors[edge or "edge"]))
end

function UI.Panel(parent, x, y, width, height, surface)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetSize(width, height)
    panel:SetPoint("TOPLEFT", x, y)
    UI.Skin(panel, surface or "panel")
    return panel
end

function UI.Line(parent, x, y, width, height, color)
    local texture = parent:CreateTexture(nil, "ARTWORK")
    texture:SetColorTexture(unpack(colors[color or "edge"]))
    texture:SetPoint("TOPLEFT", x, y)
    texture:SetSize(width, height or 1)
    return texture
end

function UI.Label(parent, text, x, y, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(text)
    label:SetTextColor(unpack(font == "GameFontHighlightSmall" and colors.muted or colors.text))
    label:SetJustifyH("LEFT")
    return label
end

function UI.Select(button, selected)
    button.selected = selected
    local fill = button.hovered and button:IsEnabled() and "hover" or selected and "selected" or button.surface or "button"
    local edge = selected and "accent" or button.surface == "rail" and "rail" or "edge"
    if button.fill ~= fill then button:SetBackdropColor(unpack(colors[fill])); button.fill = fill end
    if button.edge ~= edge then button:SetBackdropBorderColor(unpack(colors[edge])); button.edge = edge end
    if button.indicator then button.indicator:SetShown(selected) end
end

function UI.Button(parent, text, width, x, y, callback)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", x, y)
    UI.Skin(button, "button")
    local caption = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    caption:SetPoint("CENTER")
    button:SetFontString(caption)
    button:SetText(text)
    button:SetScript("OnEnter", function() button.hovered = true; UI.Select(button, button.selected) end)
    button:SetScript("OnLeave", function() button.hovered = false; UI.Select(button, button.selected) end)
    button:SetScript("OnDisable", function() button:SetAlpha(.48) end)
    button:SetScript("OnEnable", function() button:SetAlpha(1) end)
    button:SetScript("OnClick", callback)
    return button
end

function UI.Input(parent, x, y, width, hint)
    local field = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    field:SetSize(width, 26)
    field:SetPoint("TOPLEFT", x, y)
    field:SetFontObject("ChatFontNormal")
    field:SetTextInsets(9, 9, 0, 0)
    field:SetAutoFocus(false)
    UI.Skin(field, "field")
    field.Instructions = UI.Label(field, hint or "", 9, -6, "GameFontHighlightSmall")
    local function placeholder()
        field.Instructions:SetShown(field:GetText() == "" and not field:HasFocus())
    end
    field:HookScript("OnTextChanged", placeholder)
    field:HookScript("OnEditFocusGained", function()
        field:SetBackdropBorderColor(unpack(colors.accent))
        placeholder()
    end)
    field:HookScript("OnEditFocusLost", function()
        field:SetBackdropBorderColor(unpack(colors.edge))
        placeholder()
    end)
    return field
end

function UI.MenuButton(parent, text, width, x, y, callback)
    local button = UI.Button(parent, text, width, x, y, callback)
    local label = button:GetFontString()
    label:ClearAllPoints()
    label:SetPoint("LEFT", 10, 0)
    local caret = button:CreateTexture(nil, "ARTWORK")
    caret:SetTexture("Interface\\AddOns\\" .. A.name .. "\\Media\\Toggle.tga")
    caret:SetTexCoord(.75, 1, 0, .5)
    caret:SetSize(12, 12)
    caret:SetPoint("RIGHT", -8, 0)
    caret:SetVertexColor(unpack(colors.muted))
    return button
end

function UI.Tip(widget, title, body)
    widget:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(type(body) == "function" and body() or body, .9, .9, .9, true)
        GameTooltip:Show()
    end)
    widget:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

function UI.Window(name, title, width, height, parent, strata)
    local frame = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata(strata or "DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    if not parent then
        frame:SetToplevel(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    end
    UI.Skin(frame, "window")
    local mark = frame:CreateTexture(nil, "ARTWORK")
    mark:SetTexture("Interface\\AddOns\\" .. A.name .. "\\Media\\BagMarks.tga")
    mark:SetSize(26, 26)
    mark:SetPoint("TOPLEFT", 12, -6)
    frame.TitleText = UI.Label(frame, title, 44, -12, "GameFontNormal")
    UI.Line(frame, 1, -36, width - 2)
    UI.Button(frame, "Close", 52, width - 62, -6, function() frame:Hide() end)
    local function fit()
        local w, h = UIParent:GetWidth(), UIParent:GetHeight()
        if w > 0 and h > 0 then frame:SetScale(math.min(1, (w - 12) / width, (h - 12) / height)) end
    end
    if not parent then
        frame:HookScript("OnShow", fit)
        frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
        frame:RegisterEvent("UI_SCALE_CHANGED")
        frame:SetScript("OnEvent", function() if frame:IsShown() then fit() end end)
    end
    -- Named windows join Blizzard's Escape-to-close list without key overrides.
    UISpecialFrames[#UISpecialFrames + 1] = name
    frame:Hide()
    return frame
end

function UI:Confirm(title, text, acceptText, callback)
    if not self.confirm then
        local f = self.Window("BagMarksConfirm", "BagMarks", 390, 340, nil, "FULLSCREEN_DIALOG")
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
            -- OnHide clears the stored callback for cancellation. Copy it first
            -- so accepting can close the dialog before running the chosen action.
            local action = f.callback
            f:Hide()
            if action then action() end
        end)
        self.Button(f, "Cancel", 160, 210, -298, function() f:Hide() end)
        -- Escape, Cancel, and programmatic close all discard the pending action.
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
    f:Raise()
end

function UI:CloseConfirmation()
    if self.confirm then self.confirm:Hide() end
end

function UI:ItemChoices(root, item)
    local guid = item.guid
    local rule = A.db.rememberItemTypes and A.char.itemRules[item.itemID]
    if rule then root:CreateTitle("Future copies will be marked " .. A.states[rule]) end
    if A.char.review[guid] then root:CreateTitle("Stack changed. Reapply a mark to review.") end
    local choices = {
        { "Lock Item", "locked" }, { "Mark as Junk", "junk" },
        { "Mark for Mail", "mail" }, { rule and "Clear mark and forget future mark" or "Clear Mark", false },
    }
    for _, choice in ipairs(choices) do
        -- false keeps Clear Mark in the choices table; Store represents Normal
        -- with nil, which removes the saved record for this GUID.
        local state = choice[2] or nil
        local option = root:CreateRadio(choice[1], function() return A.Store:Get(guid) == state end, function()
            if not A.IsEnabled() then return end
            -- Menus bind to identity, never the slot that happened to open them.
            local current = A.API:Find(guid, true, true)
            if current then A.Store:Set(current, state)
            else A.Print("That item is no longer available. Open its menu again.") end
        end)
        if state then
            option:AddInitializer(function(button)
                local icon = button:AttachTexture()
                icon:SetSize(16, 16)
                icon:SetPoint("RIGHT", -4, 0)
                A.PaintIcon(icon, state)
                return button.fontString:GetUnboundedStringWidth() + 48, 20
            end)
        end
    end
    root:CreateButton("Mail recipient for this item...", function() A.Settings:OpenItemRoutes(item.itemID) end)
end

function UI:ItemMenu(owner, item, stacks)
    if not A.IsEnabled() or not item then return end
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
