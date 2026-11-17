-- Reusable settings window built from unprotected native widgets. Most options
-- refresh through A.SetOption; mail edits and key capture have separate lifecycles.
local _, A = ...
local SettingsUI = {}
A.Settings = SettingsUI

function SettingsUI:Create()
    if self.frame then return end
    local UI = A.UI
    local f = UI.Window("BagMarksSettings", "BagMarks " .. A.version, 420, 530)
    self.frame, self.checks, self.tabs, self.panels = f, {}, {}, {}
    self.bindingAction = A.Bindings.action
    -- Blizzard's tab helpers use this ordered array plus selectedTab to choose
    -- active artwork. Our named panels hold each page's controls separately.
    f.Tabs, f.numTabs, f.minTabWidth, f.maxTabWidth = {}, 3, 112, 112
    for i, name in ipairs({ "General", "Marking", "Appearance" }) do
        local page = name
        local tab = CreateFrame("Button", nil, f, "PanelTopTabButtonTemplate")
        tab:SetPoint("TOPLEFT", 24 + (i - 1) * 130, -35)
        tab:SetText(name)
        tab:SetID(i)
        PanelTemplates_TabResize(tab, 0, 112)
        tab:SetScript("OnClick", function() self:SelectTab(page) end)
        self.tabs[name], f.Tabs[i] = tab, tab
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
    local autoSell = check(general, "autoSellJunk", "Automatically sell marked junk", -60)
    UI.Tip(autoSell, "Automatic junk selling", "Starting with your next merchant visit, sell eligible items you marked as Junk without a confirmation. Locked, Mail, and unmarked items are excluded. Turn this off to stop remaining automatic sales.")
    local remember = check(general, "rememberItemTypes", "Remember Mail and Junk by item type", -90)
    UI.Tip(remember, "Remember item types", "Each character remembers its own Mail and Junk choices. An item you mail to an alt follows that alt's rules when collected. Clear Mark forgets that item type for this character.")
    UI.Label(general, "Mail", 0, -121, "GameFontNormal")
    UI.Label(general, "This character's recipient", 0, -159)
    local recipient = CreateFrame("EditBox", nil, general, "InputBoxTemplate")
    recipient:SetSize(192, 24)
    recipient:SetPoint("TOPLEFT", 178, -152)
    recipient:SetAutoFocus(false)
    recipient:SetMaxLetters(100)
    recipient:SetScript("OnEnterPressed", function(widget) widget:ClearFocus() end)
    recipient:SetScript("OnEscapePressed", function(widget) widget:ClearFocus() end)
    recipient:SetScript("OnTextChanged", function(widget, userInput)
        if userInput then
            A.Store:SetRecipient(widget:GetText())
            self:RefreshRecipient()
        end
    end)
    -- Defer compose autofill until editing finishes, so a partly typed saved
    -- recipient cannot be copied into an already open mail draft.
    recipient:SetScript("OnEditFocusLost", function()
        self:RefreshRecipient()
        A.Mail:QueueDraftUpdate()
    end)
    UI.Tip(recipient, "Default mail recipient", "Enter Character or Character-Realm for this sender. BagMarks fills an empty To field once per fresh draft. You can type over the selected name.")
    self.recipient = recipient
    self.usePreviousRecipient = UI.Button(general, "Use previous recipient", 168, 202, -118, function()
        if A.readOnly or A.char.recipient ~= "" or not A.db.previousRecipient then return end
        recipient:ClearFocus()
        A.SetOption("recipient", A.db.previousRecipient)
        A.db.previousRecipient = nil
    end)
    UI.Tip(self.usePreviousRecipient, "Previous account recipient", function()
        return "Use " .. (A.db.previousRecipient or "") .. " as this character's default To name."
    end)
    check(general, "autoFillRecipient", "Automatically fill mail recipient", -194)
    check(general, "autoAttachMail", "Automatically attach marked items", -224)
    local mailNote = UI.Label(general, "Open Send Mail to attach eligible Mail stacks.\nThe first attachment supplies an empty subject.\nReview the recipient and items, then click Send.", 0, -262, "GameFontHighlightSmall")
    mailNote:SetWidth(370)
    mailNote:SetJustifyH("LEFT")

    self.modifier = choice("modifier", "Modifier keys", 0, A.Interaction.modifiers)
    self.mouseButton = choice("mouseButton", "Mouse button", -32, A.Interaction.buttons)
    self.markingAction = choice("markingAction", "Click action", -64, A.Interaction.actions)
    UI.Tip(self.modifier, "Marking shortcut", "Choose an exact modifier combination to avoid other addons' shortcuts. None captures the selected mouse button without modifiers; Marking Mode only leaves it native until you enable the mode.")
    UI.Tip(self.mouseButton, "Mouse button", "Choose Left, Right, Middle, Mouse Button 4 or 5. Other mouse buttons keep their normal behavior outside Locked-item guards.")
    UI.Tip(self.markingAction, "Click action", "Open the mark menu, or cycle Normal > Locked > Junk > Mail > Normal with each marking click. Changed stacks open the menu for review.")
    self.interactionHint = UI.Label(marking, "", 0, -100, "GameFontHighlightSmall")
    self.interactionHint:SetWidth(370)
    self.interactionHint:SetJustifyH("LEFT")

    UI.Label(marking, "Keyboard shortcut", 0, -150, "GameFontNormal")
    -- This selector chooses which binding to edit; both actions remain usable.
    -- Cancel capture before changing it so a key cannot land on the wrong action.
    self.bindingChoice = UI.Button(marking, "", 200, 172, -144, function(owner)
        A.Bindings:StopCapture()
        MenuUtil.CreateContextMenu(owner, function(_, root)
            for _, option in ipairs({ { A.Bindings.action, "Toggle marking mode" }, { A.Bindings.hoverAction, "Cycle hovered item" } }) do
                local action = option[1]
                root:CreateRadio(option[2], function() return self.bindingAction == action end,
                    function() self.bindingAction = action; self:Refresh() end)
            end
        end)
    end)
    self.binding = UI.Label(marking, "", 0, -174)
    self.bindButton = UI.Button(marking, "Set Key", 110, 0, -198, function() A.Bindings:StartCapture(self.bindingAction) end)
    self.clearButton = UI.Button(marking, "Clear", 110, 126, -198, function()
        A.Bindings:StopCapture()
        local ok, message = A.Bindings:Apply({}, false, self.bindingAction)
        if not ok then self:SetBindingMessage(message) end
    end)
    self.restoreButton = UI.Button(marking, "Restore", 110, 252, -198, function()
        A.Bindings:StopCapture()
        local ok, message = A.Bindings:Restore(self.bindingAction)
        if not ok then self:SetBindingMessage(message) end
    end)
    UI.Tip(self.restoreButton, "Restore shortcut", "Restore the shortcut from before your last change in this session. The default is unbound. Conflicting keys are never overwritten.")
    self.bindingMessage = UI.Label(marking, "", 0, -230, "GameFontHighlightSmall")
    self.bindingMessage:SetWidth(370)
    self.bindingMessage:SetJustifyH("LEFT")
    local modeNote = UI.Label(marking, "Cycle hovered item: point at an item and press your key.\nNormal > Locked > Junk > Mail > Normal.\nWorks with marking mode off; mouse controls stay available.", 0, -288, "GameFontHighlightSmall")
    modeNote:SetWidth(370)
    modeNote:SetJustifyH("LEFT")

    check(appearance, "tooltips", "Show tooltip labels", 0)
    check(appearance, "overlays", "Show item icons", -30)
    UI.Label(appearance, "Mark size", 0, -70)
    self.iconSize = UI.Button(appearance, "", 200, 172, -64, function(owner)
        MenuUtil.CreateContextMenu(owner, function(_, root)
            for _, option in ipairs(A.IconSizes) do
                local value = option[1]
                root:CreateRadio(option[2], function() return A.db.iconSize == value end,
                    function() A.SetOption("iconSize", value) end)
            end
        end)
    end)
    UI.Tip(self.iconSize, "Mark size", "Small corner keeps the usual badge. Full item icon stretches a translucent mark across the item artwork, beneath counts and cooldowns. Changes during combat apply when combat ends.")
    UI.Label(appearance, "Icon themes", 0, -112, "GameFontNormal")
    self.themes = {}
    for i, name in ipairs({ "Classic", "Minimal", "Colorful" }) do
        local theme = name
        local button = UI.Button(appearance, name, 110, (i - 1) * 126, -136, function() A.SetOption("theme", theme) end)
        self.themes[name] = button
        for j, state in ipairs({ "locked", "junk", "mail" }) do
            local icon = button:CreateTexture(nil, "OVERLAY")
            icon:SetSize(16, 16)
            icon:SetPoint("TOPLEFT", 16 + (j - 1) * 30, -32)
            A.PaintIcon(icon, state, theme)
        end
    end
    UI.Label(appearance, "Themes update your bag and bank icons immediately.", 0, -208, "GameFontHighlightSmall")
    self.iconSizeNote = UI.Label(appearance, "", 0, -240, "GameFontHighlightSmall")
    self.iconSizeNote:SetWidth(370)
    self.iconSizeNote:SetJustifyH("LEFT")
    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(.55, .45, .25, .5)
    divider:SetPoint("TOPLEFT", 24, -424)
    divider:SetSize(372, 1)
    self.modeStatus = UI.Label(f, "", 24, -436, "GameFontNormal")
    self.modeHint = UI.Label(f, "", 24, -456, "GameFontHighlightSmall")
    self.modeHint:SetWidth(370)
    self.modeHint:SetJustifyH("LEFT")
    self.modeButton = UI.Button(f, "", 220, 24, -490, function() A.ToggleMode() end)
    UI.Tip(self.modeButton, "Item Marking Mode", "When on, your selected mouse button marks items without holding a modifier. A Marking badge appears beside the pointer over bag items. Turn it off to return to your usual clicks. Combat turns the mode off.")
    UI.Button(f, "Close", 110, 276, -490, function() f:Hide() end)
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
    end
    PanelTemplates_SetTab(self.frame, self.tabs[name]:GetID())
    -- A hidden edit/capture control must not keep consuming the player's input.
    if name ~= "General" then self.recipient:ClearFocus() end
    if name ~= "Marking" then A.Bindings:StopCapture() end
end

function SettingsUI:SetBindingMessage(message)
    if self.bindingMessage then self.bindingMessage:SetText(message) end
end

function SettingsUI:RefreshRecipient()
    -- Preserve the caret and any partially typed name during bag and UI refreshes.
    if not self.recipient:HasFocus() then self.recipient:SetText(A.char.recipient) end
    self.usePreviousRecipient:SetShown(not A.readOnly and A.char.recipient == "" and A.db.previousRecipient ~= nil)
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
    self.iconSize:SetText(A.iconSizeLabels[A.db.iconSize])
    self.iconSize:SetEnabled(menuEnabled)
    self.iconSizeNote:SetText(A.InCombat() and "Size changes will apply when combat ends."
        or "Full item icon uses a translucent mark so the item\nartwork stays visible. Small corner is the default.")
    self.interactionHint:SetText(A.Interaction:Hint() .. (A.db.markingAction == "cycle"
        and "\nNormal > Locked > Junk > Mail > Normal" or "\nChoose a mark from the compact item menu."))
    self:RefreshRecipient()
    local hovering = self.bindingAction == A.Bindings.hoverAction
    self.bindingChoice:SetText(hovering and "Cycle hovered item" or "Toggle marking mode")
    self.bindingChoice:SetEnabled(menuEnabled)
    self.binding:SetText("Assigned key: " .. A.Bindings:Text(self.bindingAction))
    local bindingAllowed = not A.InCombat()
    self.bindButton:SetEnabled(bindingAllowed)
    self.clearButton:SetEnabled(bindingAllowed)
    self.restoreButton:SetEnabled(bindingAllowed)
    if not A.Bindings.capture or not A.Bindings.capture:IsShown() then
        self:SetBindingMessage(bindingAllowed and (hovering
            and "Starts unbound. Space is usually Jump; choose a free key.\nTo use Space, first change Jump in WoW's Key Bindings."
            or "Starts unbound. Uses your active Blizzard binding set.\nExisting shortcuts are never replaced.")
            or "Keybinding changes are unavailable during combat.")
    end
    for theme, button in pairs(self.themes) do
        button:SetText((A.db.theme == theme and "|cffffd100" or "") .. theme .. (A.db.theme == theme and "|r" or ""))
        button:SetEnabled(not A.readOnly)
    end
    self.modeStatus:SetText("Item Marking Mode: " .. (A.mode and "|cff66ccffON|r" or "|cffbbbbbbOFF|r"))
    local hint
    if not A.IsEnabled() then hint = "Enable BagMarks in General to start marking items."
    elseif A.InCombat() then hint = "Marking is paused during combat. Turn the mode on afterward."
    elseif A.mode then
        hint = A.Interaction.buttonLabels[A.db.mouseButton] .. " marks items without modifiers.\nTurn the mode off to return to your usual clicks."
    else hint = "Turn on to mark with " .. A.Interaction.buttonLabels[A.db.mouseButton] .. " alone.\nThe hover key works independently, if assigned." end
    self.modeHint:SetText(hint)
    self.modeButton:SetText(A.mode and "Turn marking mode off" or "Turn marking mode on")
    self.modeButton:SetEnabled(A.CanAct() and true or false)
end

function SettingsUI:Toggle()
    self:Create()
    self.frame:SetShown(not self.frame:IsShown())
end

function SettingsUI:RegisterCategory()
    -- Register a small launcher in Blizzard settings; reuse the same compact
    -- window opened by slash commands and the minimap instead of a second UI.
    if self.category or not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then return end
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:Hide()
    A.UI.Label(panel, "BagMarks " .. A.version, 20, -20, "GameFontNormalLarge")
    A.UI.Label(panel, "Mark items to keep, sell, or mail. Use /bm to open settings.", 20, -55)
    A.UI.Button(panel, "Open BagMarks Settings", 220, 20, -90, function()
        self:Create()
        self.frame:Show()
    end)
    self.category = Settings.RegisterCanvasLayoutCategory(panel, "BagMarks")
    Settings.RegisterAddOnCategory(self.category)
end
