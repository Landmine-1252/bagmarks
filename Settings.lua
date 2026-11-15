local _, A = ...
local SettingsUI = {}
A.Settings = SettingsUI

function SettingsUI:Create()
    if self.frame then return end
    local UI = A.UI
    local f = UI.Window("BagMarksSettings", "BagMarks", 420, 530)
    self.frame, self.checks, self.tabs, self.panels = f, {}, {}, {}
    for i, name in ipairs({ "General", "Marking", "Appearance" }) do
        local tab = name
        self.tabs[name] = UI.Button(f, name, 112, 24 + (i - 1) * 130, -40, function() self:SelectTab(tab) end)
        local panel = CreateFrame("Frame", nil, f)
        panel:SetPoint("TOPLEFT", 24, -84)
        panel:SetSize(372, 332)
        self.panels[name] = panel
    end
    local general, marking, appearance = self.panels.General, self.panels.Marking, self.panels.Appearance
    local function check(parent, key, text, y)
        local widget = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        widget:SetSize(24, 24)
        widget:SetPoint("TOPLEFT", -4, y)
        widget.label = UI.Label(widget, text, 28, -5)
        widget:SetScript("OnClick", function(button) A.SetOption(key, button:GetChecked() == true) end)
        self.checks[key] = widget
        return widget
    end
    local function choice(key, label, y, options)
        UI.Label(marking, label, 0, y - 6)
        local button = UI.Button(marking, "", 200, 172, y, function(owner)
            MenuUtil.CreateContextMenu(owner, function(_, root)
                for _, option in ipairs(options) do
                    local value = option[1]
                    root:CreateRadio(option[2], function() return A.db[key] == value end,
                        function() A.SetOption(key, value) end)
                end
            end)
        end)
        return button
    end

    check(general, "enabled", "Enable BagMarks", 0)
    check(general, "minimap", "Show minimap button", -30)
    UI.Label(general, "Mail", 0, -91, "GameFontNormal")
    UI.Label(general, "Default recipient", 0, -129)
    local recipient = CreateFrame("EditBox", nil, general, "InputBoxTemplate")
    recipient:SetSize(192, 24)
    recipient:SetPoint("TOPLEFT", 178, -122)
    recipient:SetAutoFocus(false)
    recipient:SetMaxLetters(100)
    recipient:SetScript("OnEnterPressed", function(widget) widget:ClearFocus() end)
    recipient:SetScript("OnEscapePressed", function(widget) widget:ClearFocus() end)
    recipient:SetScript("OnTextChanged", function(widget, userInput)
        if userInput and not A.readOnly then A.db.recipient = widget:GetText():gsub("[%c|]", ""):match("^%s*(.-)%s*$") end
    end)
    recipient:SetScript("OnEditFocusLost", function() A.Mail:QueueFill() end)
    UI.Tip(recipient, "Mail recipient", "Character or Character-Realm. Auto-fill uses this name only for a new, empty recipient. Replies and names you type are preserved.")
    self.recipient = recipient
    check(general, "autoFillRecipient", "Automatically fill mail recipient", -164)
    local mailNote = UI.Label(general, "Fills when Send Mail opens and after a successful send.\nExisting recipients and your edits are preserved.\n\nReview the recipient before using Blizzard's Send button.", 0, -204, "GameFontHighlightSmall")
    mailNote:SetWidth(370)
    mailNote:SetJustifyH("LEFT")

    self.modifier = choice("modifier", "Modifier keys", 0, A.Interaction.modifiers)
    self.mouseButton = choice("mouseButton", "Mouse button", -32, A.Interaction.buttons)
    self.markingAction = choice("markingAction", "Click action", -64, A.Interaction.actions)
    UI.Tip(self.modifier, "Marking shortcut", "Choose an exact modifier combination to avoid other addons' shortcuts. None captures the selected mouse button without modifiers; Marking Mode only leaves it native until you enable the mode.")
    UI.Tip(self.mouseButton, "Mouse button", "Choose Left, Right, Middle, Mouse Button 4 or 5. Other mouse buttons keep their normal behavior outside Locked-item guards.")
    UI.Tip(self.markingAction, "Click action", "Open the mark menu, or cycle Normal > Junk > Mail > Locked > Normal with each marking click. Changed stacks open the menu for review.")
    self.interactionHint = UI.Label(marking, "", 0, -100, "GameFontHighlightSmall")
    self.interactionHint:SetWidth(370)
    self.interactionHint:SetJustifyH("LEFT")

    UI.Label(marking, "Keyboard shortcut", 0, -150, "GameFontNormal")
    self.binding = UI.Label(marking, "", 0, -174)
    self.bindButton = UI.Button(marking, "Set Key", 110, 0, -198, function() A.Bindings:StartCapture() end)
    self.clearButton = UI.Button(marking, "Clear", 110, 126, -198, function()
        A.Bindings:StopCapture()
        local ok, message = A.Bindings:Apply({})
        if not ok then self:SetBindingMessage(message) end
    end)
    self.restoreButton = UI.Button(marking, "Restore", 110, 252, -198, function()
        A.Bindings:StopCapture()
        local ok, message = A.Bindings:Restore()
        if not ok then self:SetBindingMessage(message) end
    end)
    UI.Tip(self.restoreButton, "Restore shortcut", "Restore the shortcut from before your last change in this session. The default is unbound. Conflicting keys are never overwritten.")
    self.bindingMessage = UI.Label(marking, "", 0, -230, "GameFontHighlightSmall")
    self.bindingMessage:SetWidth(370)
    self.bindingMessage:SetJustifyH("LEFT")
    local modeNote = UI.Label(marking, "Item Marking Mode uses your selected mouse button\nwithout modifiers. Turn it off to use your chosen shortcut.", 0, -288, "GameFontHighlightSmall")
    modeNote:SetWidth(370)
    modeNote:SetJustifyH("LEFT")

    check(appearance, "tooltips", "Show tooltip labels", 0)
    check(appearance, "overlays", "Show item icons", -30)
    UI.Label(appearance, "Icon themes", 0, -90, "GameFontNormal")
    self.themes = {}
    for i, name in ipairs({ "Classic", "Minimal", "Colorful" }) do
        local theme = name
        local button = UI.Button(appearance, name, 110, (i - 1) * 126, -114, function() A.SetOption("theme", theme) end)
        self.themes[name] = button
        for j, state in ipairs({ "locked", "junk", "mail" }) do
            local icon = button:CreateTexture(nil, "OVERLAY")
            icon:SetSize(16, 16)
            icon:SetPoint("TOPLEFT", 16 + (j - 1) * 30, -32)
            A.PaintIcon(icon, state, theme)
        end
    end
    UI.Label(appearance, "Themes update your bag and bank icons immediately.", 0, -190, "GameFontHighlightSmall")
    local note = UI.Label(f, "Lock guards cover supported bag clicks outside combat.\nCursor deletion, macros and other addons can bypass them.", 24, -432, "GameFontHighlightSmall")
    note:SetWidth(370)
    note:SetJustifyH("LEFT")
    self.modeButton = UI.Button(f, "Item Marking Mode: Off", 220, 24, -480, function() A.ToggleMode() end)
    UI.Button(f, "Close", 110, 276, -480, function() f:Hide() end)
    f:SetScript("OnShow", function() self:Refresh() end)
    f:SetScript("OnHide", function() recipient:ClearFocus(); A.Bindings:StopCapture() end)
    self:SelectTab("General")
    self:Refresh()
end

function SettingsUI:SelectTab(name)
    if not self.panels[name] then return end
    self.selectedTab = name
    for tab, panel in pairs(self.panels) do
        panel:SetShown(tab == name)
        self.tabs[tab]:SetText(tab == name and ("|cffffd100" .. tab .. "|r") or tab)
    end
    if name ~= "General" then self.recipient:ClearFocus() end
    if name ~= "Marking" then A.Bindings:StopCapture() end
end

function SettingsUI:SetBindingMessage(message)
    if self.bindingMessage then self.bindingMessage:SetText(message) end
end

function SettingsUI:Refresh()
    if not self.frame then return end
    for key, check in pairs(self.checks) do check:SetChecked(A.db[key]); check:SetEnabled(not A.readOnly) end
    self.modifier:SetText(A.Interaction.modifierLabels[A.db.modifier])
    self.mouseButton:SetText(A.Interaction.buttonLabels[A.db.mouseButton])
    self.markingAction:SetText(A.Interaction.actionLabels[A.db.markingAction])
    local menuEnabled = not A.readOnly and MenuUtil and MenuUtil.CreateContextMenu and true or false
    self.modifier:SetEnabled(menuEnabled)
    self.mouseButton:SetEnabled(menuEnabled)
    self.markingAction:SetEnabled(menuEnabled)
    self.interactionHint:SetText(A.Interaction:Hint() .. (A.db.markingAction == "cycle"
        and "\nNormal > Junk > Mail > Locked > Normal" or "\nChoose a mark from the compact item menu."))
    if not self.recipient:HasFocus() then self.recipient:SetText(A.db.recipient) end
    self.binding:SetText("Toggle marking mode: " .. A.Bindings:Text())
    local bindingAllowed = not A.InCombat()
    self.bindButton:SetEnabled(bindingAllowed)
    self.clearButton:SetEnabled(bindingAllowed)
    self.restoreButton:SetEnabled(bindingAllowed)
    if not A.Bindings.capture or not A.Bindings.capture:IsShown() then
        self:SetBindingMessage(bindingAllowed and "Uses your active Blizzard binding set. Default: Unbound." or "Keybinding changes are unavailable during combat.")
    end
    for theme, button in pairs(self.themes) do
        button:SetText((A.db.theme == theme and "|cffffd100" or "") .. theme .. (A.db.theme == theme and "|r" or ""))
        button:SetEnabled(not A.readOnly)
    end
    self.modeButton:SetText("Item Marking Mode: " .. (A.mode and "On" or "Off"))
    self.modeButton:SetEnabled(A.CanAct() and true or false)
end

function SettingsUI:Toggle()
    self:Create()
    self.frame:SetShown(not self.frame:IsShown())
end

function SettingsUI:RegisterCategory()
    if self.category or not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then return end
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:Hide()
    A.UI.Label(panel, "BagMarks", 20, -20, "GameFontNormalLarge")
    A.UI.Label(panel, "Small item marks for Blizzard bags. Use /bm to open settings.", 20, -55)
    A.UI.Button(panel, "Open BagMarks Settings", 220, 20, -90, function()
        self:Create()
        self.frame:Show()
    end)
    self.category = Settings.RegisterCanvasLayoutCategory(panel, "BagMarks")
    Settings.RegisterAddOnCategory(self.category)
end
