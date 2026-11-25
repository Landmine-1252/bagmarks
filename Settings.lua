-- Settings, bag menus and the Blizzard launcher all open this same window.
local _, A = ...
local UI = A.UI
local S = { width = 566, tabs = {}, panels = {}, checks = {} }
A.Settings = S
local windowWidth, windowHeight = 772, 592

local function generalDetail()
    if not A.db.enabled then return "Enable BagMarks below to start marking items." end
    if not A.IsEnabled() then return "Item marking is currently unavailable." end
    local shortcut = A.Interaction:Shortcut()
    if A.db.modifier == "MODE" and not A.mode then
        if A.InCombat() then return "You can turn on marking mode after combat." end
        shortcut = "Turn on marking mode, then use " .. shortcut
    end
    local action = A.db.markingAction == "menu" and "open its mark menu." or "cycle its mark."
    return shortcut .. " on a bag item to " .. action
end

local function rulesDetail()
    if not A.db.rememberItemTypes then
        return "Automatic marks are paused. Turn them on in General.\nMail recipients still apply to items you mark for mail."
    end
    return "Manage future marks for this character and mail recipients for your account."
end

local pages = {
    { "General", generalDetail },
    { "Marking", "Choose how to mark an item with your mouse or keyboard." },
    { "Mail", "For Mail marks, item rules come first, then category recipients, then your default." },
    { "Item rules", rulesDetail },
    { "Appearance", "Choose how marks appear on your items." },
}

function S:Check(parent, key, label, x, y, width)
    local button = CreateFrame("CheckButton", nil, parent)
    button:SetSize(width, 28)
    button:SetPoint("TOPLEFT", x, y)
    button.label = UI.Label(button, label, 4, -7)
    local path = "Interface\\AddOns\\" .. A.name .. "\\Media\\Toggle.tga"
    button.track = button:CreateTexture(nil, "ARTWORK")
    button.track:SetTexture(path)
    button.track:SetTexCoord(0, .5, 0, .5)
    button.track:SetSize(30, 15)
    button.track:SetPoint("RIGHT", -4, 0)
    button.thumb = button:CreateTexture(nil, "OVERLAY")
    button.thumb:SetTexture(path)
    button.thumb:SetTexCoord(.5, .75, 0, .5)
    button.thumb:SetSize(11, 11)
    button:SetScript("OnClick", function() A.SetOption(key, button:GetChecked() == true) end)
    self.checks[key] = button
    return button
end

function S:CreateGeneral(panel)
    local w = self.width
    local account = UI.Panel(panel, 0, 0, w, 102)
    UI.Label(account, "Addon controls", 14, -11, "GameFontNormal")
    self:Check(account, "enabled", "Enable BagMarks", 10, -33, w - 20)
    UI.Line(account, 14, -64, w - 28)
    self:Check(account, "minimap", "Show minimap button", 10, -69, w - 20)
    local items = UI.Panel(panel, 0, -118, w, 146)
    UI.Label(items, "Item handling", 14, -11, "GameFontNormal")
    local sell = self:Check(items, "autoSellJunk", "Automatically sell marked junk", 10, -33, w - 20)
    UI.Tip(sell, "Automatic junk selling", "At your next merchant visit, sell eligible stacks marked Junk. You can stop a sale in progress.")
    UI.Line(items, 14, -65, w - 28)
    local remember = self:Check(items, "rememberItemTypes", "Remember Mail, Junk and Disenchant by item type", 10, -70, w - 20)
    UI.Tip(remember, "Future copies", "Remember the marks you choose on this character. Clear Mark forgets an item type.")
    UI.Label(items, "Manage which items receive these marks.", 14, -114, "GameFontHighlightSmall")
    UI.Button(items, "View item rules", 116, w - 130, -107, function() self:OpenItemRoutes() end)
end

function S:CreateMarking(panel)
    local w = self.width
    local mouse = UI.Panel(panel, 0, 0, w, 158)
    UI.Label(mouse, "Mouse shortcut", 14, -11, "GameFontNormal")
    local function choice(key, label, y, options)
        UI.Label(mouse, label, 14, y - 5)
        local button = UI.MenuButton(mouse, "", w - 218, 204, y, function(owner)
            MenuUtil.CreateContextMenu(owner, function(_, root)
                for _, option in ipairs(options) do
                    local value = option[1]
                    root:CreateRadio(option[2], function() return A.db[key] == value end, function() A.SetOption(key, value) end)
                end
            end)
        end)
        return button
    end
    self.modifier = choice("modifier", "Modifier keys", -31, A.Interaction.modifiers)
    self.mouseButton = choice("mouseButton", "Mouse button", -60, A.Interaction.buttons)
    self.markingAction = choice("markingAction", "Click action", -89, A.Interaction.actions)
    UI.Tip(self.modifier, "Modifier keys", "Marking Mode only reserves the mouse button while the mode is on.")
    UI.Tip(self.markingAction, "Click action", "Cycle through Normal, Locked, Junk, Mail and Disenchant, or open a menu with every mark.")
    self.interactionHint = UI.Label(mouse, "", 14, -128, "GameFontHighlightSmall")
    local keys = UI.Panel(panel, 0, -171, w, 175)
    UI.Label(keys, "Keyboard shortcut", 14, -15, "GameFontNormal")
    self.bindingChoice = UI.MenuButton(keys, "", w - 218, 204, -9, function(owner)
        A.Bindings:StopCapture()
        MenuUtil.CreateContextMenu(owner, function(_, root)
            for _, option in ipairs({ { A.Bindings.action, "Toggle marking mode" }, { A.Bindings.hoverAction, "Cycle hovered item" } }) do
                local action = option[1]
                root:CreateRadio(option[2], function() return self.bindingAction == action end,
                    function() self.bindingAction = action; self:Refresh() end)
            end
        end)
    end)
    self.binding = UI.Label(keys, "", 14, -48)
    self.bindButton = UI.Button(keys, "Set Key", 114, 14, -73, function() A.Bindings:StartCapture(self.bindingAction) end)
    self.clearButton = UI.Button(keys, "Clear", 86, 138, -73, function()
        A.Bindings:StopCapture()
        local ok, message = A.Bindings:Apply({}, false, self.bindingAction)
        if not ok then self:SetBindingMessage(message) end
    end)
    self.restoreButton = UI.Button(keys, "Restore", 86, 234, -73, function()
        A.Bindings:StopCapture()
        local ok, message = A.Bindings:Restore(self.bindingAction)
        if not ok then self:SetBindingMessage(message) end
    end)
    UI.Tip(self.restoreButton, "Restore shortcut", "Restore the shortcut from before your last change in this session.")
    self.bindingMessage = UI.Label(keys, "", 14, -113, "GameFontHighlightSmall")
    self.bindingMessage:SetWidth(w - 28)
end

local previewItems = {
    { "locked", "Locked", "INV_Sword_04" }, { "junk", "Junk", "INV_Misc_Bone_01" },
    { "mail", "Mail", "INV_Fabric_Linen_01" }, { "disenchant", "Disenchant", "INV_Staff_13" },
}

function S:CreateAppearance(panel)
    local w = self.width
    local display = UI.Panel(panel, 0, 0, w, 75)
    self:Check(display, "overlays", "Show item icons", 10, -6, w - 20)
    UI.Line(display, 14, -37, w - 28)
    self:Check(display, "tooltips", "Show tooltip labels", 10, -41, w - 20)
    local preview = UI.Panel(panel, 0, -87, w, 87)
    UI.Label(preview, "Mark size", 14, -12, "GameFontNormal")
    self.sizeButtons, self.previewMarks = {}, {}
    for i, option in ipairs(A.IconSizes) do
        local size = option[1]
        local button = UI.Button(preview, option[2], 98, 14 + (i - 1) * 100, -43, function() A.SetOption("iconSize", size) end)
        self.sizeButtons[size] = button
    end
    for i, item in ipairs(previewItems) do
        local frame = UI.Panel(preview, 322 + (i - 1) * 61, -10, 38, 38, "field")
        local artwork = frame:CreateTexture(nil, "ARTWORK")
        artwork:SetTexture("Interface\\Icons\\" .. item[3])
        artwork:SetPoint("TOPLEFT", 1, -1)
        artwork:SetSize(36, 36)
        local mark = frame:CreateTexture(nil, "OVERLAY")
        self.previewMarks[item[1]] = mark
        local label = UI.Label(frame, item[2], -13, -48, "GameFontHighlightSmall")
        label:SetWidth(64)
        label:SetJustifyH("CENTER")
    end
    UI.Label(panel, "Icon theme", 0, -192, "GameFontNormal")
    self.themes = {}
    for i, name in ipairs(A.themeOrder) do
        local theme = name
        local column, row = (i - 1) % 3, math.floor((i - 1) / 3)
        local button = UI.Button(panel, "", 182, column * 192, -210 - row * 36, function() A.SetOption("theme", theme) end)
        button:SetHeight(30)
        button.label = UI.Label(button, name, 10, -9, "GameFontHighlightSmall")
        self.themes[name] = button
        for j, item in ipairs(previewItems) do
            local icon = button:CreateTexture(nil, "OVERLAY")
            icon:SetSize(19, 19)
            icon:SetPoint("TOPLEFT", 90 + (j - 1) * 22, -5)
            A.PaintIcon(icon, item[1], theme)
        end
    end
    self.iconSizeNote = UI.Label(panel, "", 1, -357, "GameFontHighlightSmall")
end

function S:Create()
    if self.frame then return end
    local f = UI.Window("BagMarksSettings", "BagMarks " .. A.version, windowWidth, windowHeight)
    self.frame, self.bindingAction = f, A.Bindings.action
    local rail = UI.Panel(f, 0, -36, 158, windowHeight - 36, "rail")
    for i, entry in ipairs(pages) do
        local name = entry[1]
        local tab = UI.Button(rail, name, 138, 10, -19 - (i - 1) * 38, function() self:SelectTab(name) end)
        tab.surface = "rail"
        tab:SetHeight(32)
        local caption = tab:GetFontString()
        caption:ClearAllPoints()
        caption:SetPoint("LEFT", 13, 0)
        tab.indicator = UI.Line(tab, 0, -7, 3, 18, "accent")
        self.tabs[name] = tab
        local panel = CreateFrame("Frame", nil, f)
        panel.detail = entry[2]
        panel:SetPoint("TOPLEFT", 182, -111)
        panel:SetSize(self.width, 460)
        self.panels[name] = panel
    end
    UI.Line(rail, 12, -501, 134)
    UI.Button(rail, "Diagnostics", 134, 12, -516, function() A.Diagnostics:Open() end)
    self.pageTitle = UI.Label(f, "", 182, -51, "GameFontNormalLarge")
    self.pageDetail = UI.Label(f, "", 182, -78, "GameFontHighlightSmall")
    self.pageDetail:SetWidth(self.width)
    self:CreateGeneral(self.panels.General)
    self:CreateMarking(self.panels.Marking)
    self:CreateMailPanel()
    self:CreateRuleList(self.panels["Item rules"])
    self:CreateAppearance(self.panels.Appearance)
    local footer = UI.Panel(f, 182, -491, self.width, 79)
    self.modeFooter = footer
    self.modeStatus = UI.Label(footer, "", 14, -12, "GameFontNormal")
    self.modeHint = UI.Label(footer, "", 14, -38, "GameFontHighlightSmall")
    self.modeHint:SetWidth(self.width - 180)
    self.modeButton = UI.Button(footer, "", 154, self.width - 168, -26, function() A.ToggleMode() end)
    f:HookScript("OnShow", function()
        self:Refresh()
        if self.selectedTab == "Item rules" then self:RefreshRules() end
    end)
    f:HookScript("OnHide", function()
        local field = self:EditingRecipient()
        if field then field:ClearFocus() end
        self.ruleSearch:ClearFocus()
        if self.ruleFrame then self.ruleFrame:Hide() end
        A.Bindings:StopCapture()
    end)
    self:SelectTab("General")
    self:Refresh()
end

function S:SelectTab(name)
    if not self.panels[name] then return end
    local field = self:EditingRecipient()
    if field and name ~= self.selectedTab then field:ClearFocus() end
    if name ~= "Item rules" then
        self.ruleSearch:ClearFocus()
        if self.ruleFrame then self.ruleFrame:Hide() end
    end
    if name ~= "Mail" then self:ShowMailRecipes(false) end
    if name ~= "Marking" then A.Bindings:StopCapture() end
    self.selectedTab = name
    for _, page in ipairs(pages) do
        local active = page[1] == name
        self.panels[page[1]]:SetShown(active)
        UI.Select(self.tabs[page[1]], active)
    end
    self.pageTitle:SetText(name)
    self:RefreshPageDetail()
    self.modeFooter:SetShown(name == "General" or name == "Marking" or name == "Appearance")
    if name == "Item rules" then self:RefreshRules() end
end

function S:RefreshPageDetail()
    local panel = self.panels[self.selectedTab]
    if panel then
        self.pageDetail:SetText(type(panel.detail) == "function" and panel.detail() or panel.detail)
    end
end

function S:SetBindingMessage(message)
    if self.bindingMessage then self.bindingMessage:SetText(message) end
end

function S:Refresh()
    if not self.frame then return end
    self:RefreshPageDetail()
    for key, check in pairs(self.checks) do
        local on = A.db[key]
        check:SetChecked(on)
        check:SetEnabled(not A.readOnly)
        if check.painted ~= on then
            check.track:SetVertexColor(unpack(on and UI.colors.accent or UI.colors.edge))
            check.thumb:ClearAllPoints()
            check.thumb:SetPoint(on and "RIGHT" or "LEFT", check.track, on and "RIGHT" or "LEFT", on and -2 or 2, 0)
            check.painted = on
        end
    end
    self.modifier:SetText(A.Interaction.modifierLabels[A.db.modifier])
    self.mouseButton:SetText(A.Interaction.buttonLabels[A.db.mouseButton])
    self.markingAction:SetText(A.Interaction.actionLabels[A.db.markingAction])
    local menuEnabled = not A.readOnly and MenuUtil and MenuUtil.CreateContextMenu and true or false
    for _, button in ipairs({ self.modifier, self.mouseButton, self.markingAction, self.bindingChoice }) do button:SetEnabled(menuEnabled) end
    self.interactionHint:SetText(A.Interaction:Hint())
    self:RefreshRecipient()
    local hovering = self.bindingAction == A.Bindings.hoverAction
    self.bindingChoice:SetText(hovering and "Cycle hovered item" or "Toggle marking mode")
    self.binding:SetText("Assigned key: " .. A.Bindings:Text(self.bindingAction))
    local bindingAllowed = not A.InCombat()
    self.bindButton:SetEnabled(bindingAllowed)
    self.clearButton:SetEnabled(bindingAllowed)
    self.restoreButton:SetEnabled(bindingAllowed)
    if not A.Bindings.capture or not A.Bindings.capture:IsShown() then
        self:SetBindingMessage(bindingAllowed and (hovering
            and "Point at a stack and press the assigned key to cycle its mark.\nChoose a free key or move its existing binding in WoW settings."
            or "Press the assigned key to turn marking mode on or off.")
            or "Keybinding changes are available after combat.")
    end
    local size, theme = A.MarkSize(), A.db.theme
    local fullSize = A.Themes[theme].fullSize
    for choice, button in pairs(self.sizeButtons) do
        UI.Select(button, choice == size)
        button:SetEnabled(not A.readOnly and not fullSize)
    end
    for name, button in pairs(self.themes) do
        UI.Select(button, A.db.theme == name)
        button:SetEnabled(not A.readOnly)
    end
    if self.previewSize ~= size or self.previewTheme ~= theme then
        local side = size == "full" and 36 or size == "medium" and A.MediumMarkSize(36) or 14
        local inset = size == "corner" and 3 or 1
        for state, mark in pairs(self.previewMarks) do
            mark:SetPoint("TOPRIGHT", -inset, -inset)
            mark:SetSize(side, side)
            mark:SetAlpha(A.MarkAlpha(size, theme))
            A.PaintIcon(mark, state)
        end
        self.previewSize, self.previewTheme = size, theme
    end
    local note = fullSize and "Border outlines the full item icon." or ""
    if A.InCombat() then
        note = (fullSize and note .. " " or "") .. "Bag and bank size changes apply when combat ends."
    end
    self.iconSizeNote:SetText(note)
    self.modeStatus:SetText("Marking mode  " .. (A.mode and "ON" or "OFF"))
    local hint
    if not A.IsEnabled() then hint = "Enable BagMarks in General to start marking items."
    elseif A.InCombat() then hint = A.db.modifier == "MODE" and "Marking mode is available after combat." or "Use your marking shortcut during combat."
    elseif A.mode then hint = A.Interaction.buttonLabels[A.db.mouseButton] .. " marks items without modifiers."
    elseif A.db.modifier == "NONE" then hint = "Your mouse shortcut already works without modifiers."
    else hint = "Turn on marking mode to use " .. A.Interaction.buttonLabels[A.db.mouseButton] .. " alone." end
    self.modeHint:SetText(hint)
    self.modeButton:SetText(A.mode and "Turn marking mode off" or "Turn marking mode on")
    self.modeButton:SetEnabled(A.CanAct() and true or false)
end

function S:Toggle()
    self:Create()
    self.frame:SetShown(not self.frame:IsShown())
end

function S:RegisterCategory()
    if self.category or not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then return end
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:Hide()
    UI.Label(panel, "BagMarks " .. A.version, 20, -20, "GameFontNormalLarge")
    UI.Label(panel, "Mark items to keep, sell, mail, or disenchant. Open settings with /bm.", 20, -55)
    UI.Button(panel, "Open BagMarks Settings", 220, 20, -90, function() self:Create(); self.frame:Show() end)
    self.category = Settings.RegisterCanvasLayoutCategory(panel, "BagMarks")
    Settings.RegisterAddOnCategory(self.category)
end
