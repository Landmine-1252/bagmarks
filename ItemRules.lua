-- One item can have an account-wide mail destination and a personal mark for
-- future copies. Editing one field must preserve the other.
local _, A = ...
local S, UI = A.Settings, A.UI
local pageSize = 7
local markChoices = { { false, "No automatic mark" }, { "mail", "Mail" }, { "junk", "Junk" } }
local markFilters = { { "all", "All future marks" }, { "mail", "Mail" }, { "junk", "Junk" }, { "none", "No automatic mark" } }
local recipientFilters = { { "all", "All mail recipients" }, { "custom", "Item-specific recipient" }, { "category", "Use mail settings" } }

local function itemID(text)
    local id = tonumber(text:match("^%s*(%d+)%s*$") or text:match("|Hitem:(%d+)[:|]"))
    if id and id > 0 and id <= 2147483647 then return id end
end

local function itemName(id)
    local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    if A.Safe(name) and type(name) == "string" and name ~= "" then return name end
end

function S:RuleName(id)
    local name = itemName(id)
    if not name and not self.requestedRuleItems[id] and C_Item.RequestLoadItemDataByID then
        self.requestedRuleItems[id] = true
        C_Item.RequestLoadItemDataByID(id)
    end
    return name or ("Item " .. id)
end

function S:RulesChanged()
    -- Several marks or item-data events may arrive in one bag update.
    if self.rulesQueued or not self.frame or not self.panels["Item rules"]:IsVisible() then return end
    self.rulesQueued = true
    C_Timer.After(0, function()
        self.rulesQueued = nil
        if self.panels["Item rules"]:IsVisible() then self:RefreshRules() end
    end)
end

function S:RuleItemLoaded(id, success)
    if not A.Safe(id) or type(id) ~= "number" or not A.Safe(success) or not success then return end
    if self.requestedRuleItems[id] then
        local name = itemName(id)
        if name then self.requestedRuleItems[id] = nil end
        if self.ruleFrame and self.ruleFrame:IsShown() and itemID(self.ruleItem:GetText()) == id then
            self.ruleName:SetText(name or ("Item " .. id))
        end
    elseif not A.char.itemRules[id] and not A.db.itemRecipients[id] then
        return
    end
    self:RulesChanged()
end

function S:CreateRuleList(panel)
    local w = self.width
    self.requestedRuleItems, self.ruleRows, self.rulePage = {}, {}, 1
    local search = UI.Input(panel, 0, 0, w - 126, "Search by item, ID, mark or recipient")
    self.ruleSearch = search
    search:SetScript("OnTextChanged", function() self.rulePage = 1; self:RefreshRules() end)
    search:SetScript("OnEnterPressed", function() search:ClearFocus() end)
    search:SetScript("OnEscapePressed", function() search:SetText(""); search:ClearFocus() end)
    self.addRule = UI.Button(panel, "Add rule", 114, w - 114, -1, function() self:EditItemRule() end)
    UI.Select(self.addRule, true)

    local function filterMenu(x, width, choices, includeRecipients)
        local button = UI.MenuButton(panel, choices[1][2], width, x, -37, function(owner)
            search:ClearFocus()
            MenuUtil.CreateContextMenu(owner, function(_, root)
                local function addChoice(value, label)
                    root:CreateRadio(label, function() return owner.value == value end, function()
                        owner.value = value
                        owner:SetText(label)
                        self.rulePage = 1
                        self:RefreshRules()
                    end)
                end
                for _, choice in ipairs(choices) do addChoice(unpack(choice)) end
                if includeRecipients then
                    local names = {}
                    for _, name in pairs(self.ruleRecipientNames) do names[#names + 1] = name end
                    table.sort(names, function(a, b) return a:lower() < b:lower() end)
                    if #names > 0 then root:CreateTitle("Recipients") end
                    if #names > 7 then root:SetScrollMode(300) end
                    for _, name in ipairs(names) do addChoice("name:" .. name:lower(), name) end
                end
            end)
        end)
        local caption = button:GetFontString()
        caption:SetSize(width - 32, 18)
        caption:SetJustifyH("LEFT")
        caption:SetWordWrap(false)
        button.value = "all"
        button:SetEnabled(MenuUtil and type(MenuUtil.CreateContextMenu) == "function" or false)
        return button
    end
    self.markFilter = filterMenu(0, 201, markFilters)
    self.recipientFilter = filterMenu(210, 230, recipientFilters, true)
    self.clearRuleFilters = UI.Button(panel, "Clear filters", 114, w - 114, -37, function()
        self.markFilter.value, self.recipientFilter.value = "all", "all"
        self.markFilter:SetText(markFilters[1][2])
        self.recipientFilter:SetText(recipientFilters[1][2])
        self.rulePage = 1
        if search:GetText() ~= "" then search:SetText("") else self:RefreshRules() end
    end)
    UI.Label(panel, "Item", 12, -83, "GameFontHighlightSmall")
    UI.Label(panel, "Future copies", 262, -83, "GameFontHighlightSmall")
    UI.Label(panel, "Mail recipient", 363, -83, "GameFontHighlightSmall")
    for i = 1, pageSize do
        local row = UI.Button(panel, "", w, 0, -103 - (i - 1) * 44, function(owner) self:EditItemRule(owner.itemID) end)
        row:SetHeight(42)
        row.surface = "panel"
        UI.Select(row, false)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetPoint("TOPLEFT", 9, -6)
        row.icon:SetSize(30, 30)
        row.item = UI.Label(row, "", 49, -6)
        row.item:SetSize(204, 16)
        row.item:SetWordWrap(false)
        row.id = UI.Label(row, "", 49, -23, "GameFontHighlightSmall")
        row.mark = UI.Label(row, "", 262, -14, "GameFontHighlightSmall")
        row.address = UI.Label(row, "", 363, -6)
        row.source = UI.Label(row, "", 363, -23, "GameFontHighlightSmall")
        for _, label in ipairs({ row.address, row.source }) do
            label:SetSize(w - 413, 16)
            label:SetWordWrap(false)
        end
        local edit = UI.Label(row, "Edit", w - 40, -14, "GameFontHighlightSmall")
        edit:SetTextColor(unpack(UI.colors.accent))
        UI.Tip(row, "Edit item rule", function()
            return row.item:GetText() .. "\nFuture copies   " .. row.mark:GetText() .. "\n" .. A.MailRoutes:Tooltip(row.itemID)
        end)
        self.ruleRows[i] = row
    end
    self.ruleEmpty = UI.Label(panel, "", 12, -136)
    self.ruleEmpty:SetWidth(w - 24)
    self.ruleEmpty:SetJustifyH("CENTER")
    self.ruleCount = UI.Label(panel, "", 2, -431, "GameFontHighlightSmall")
    self.prevRules = UI.Button(panel, "Previous", 80, w - 166, -424, function() self.rulePage = self.rulePage - 1; self:RefreshRules() end)
    self.nextRules = UI.Button(panel, "Next", 78, w - 78, -424, function() self.rulePage = self.rulePage + 1; self:RefreshRules() end)
end

function S:RefreshRules(revealID)
    local search = self.ruleSearch:GetText():match("^%s*(.-)%s*$"):lower()
    local markFilter, recipientFilter = self.markFilter.value, self.recipientFilter.value
    local filtered = markFilter ~= "all" or recipientFilter ~= "all"
    local ids, rows, recipientNames = {}, {}, {}
    for id in pairs(A.db.itemRecipients) do ids[id] = true end
    for id in pairs(A.char.itemRules) do ids[id] = true end
    for id in pairs(ids) do
        local state, recipient = A.char.itemRules[id], A.db.itemRecipients[id]
        local to, reason = A.MailRoutes:Resolve(id)
        -- A saved item recipient can still be edited and found by name when
        -- the resolver keeps the item on this character.
        local filterName = A.MailRoutes:DisplayName(to or recipient)
        local nameKey = filterName:lower()
        if filterName ~= "" then recipientNames[nameKey] = filterName end
        local recipientMatches = recipientFilter == "all" or recipientFilter == (recipient and "custom" or "category")
            or recipientFilter == "name:" .. nameKey
        if (markFilter == "all" or markFilter == (state or "none"))
            and recipientMatches then
            local name = self:RuleName(id)
            local mark = A.states[state] or "None"
            local searchable = name .. " " .. id .. " " .. mark .. " " .. filterName .. " " .. reason
            if search == "" or searchable:lower():find(search, 1, true) then
                rows[#rows + 1] = { id = id, name = name, mark = mark, address = to and filterName or reason,
                    source = to and ("(" .. reason .. ")") or "", sortName = name:lower() }
            end
        end
    end
    self.ruleRecipientNames = recipientNames
    table.sort(rows, function(a, b)
        if a.sortName ~= b.sortName then return a.sortName < b.sortName end
        return a.id < b.id
    end)
    if revealID then
        local position
        for i, row in ipairs(rows) do
            if row.id == revealID then position = i; break end
        end
        if position then
            self.rulePage = math.ceil(position / pageSize)
        elseif not filtered and search ~= "" then
            self.ruleSearch:SetText("")
            return self:RefreshRules(revealID)
        end
    end
    local pages = math.max(1, math.ceil(#rows / pageSize))
    self.rulePage = math.max(1, math.min(self.rulePage, pages))
    local first = (self.rulePage - 1) * pageSize
    for i, row in ipairs(self.ruleRows) do
        local data = rows[first + i]
        row.itemID = data and data.id
        row:SetShown(data ~= nil)
        if data then
            row.item:SetText(data.name)
            row.id:SetText("ID " .. data.id)
            row.mark:SetText(data.mark)
            row.address:SetText(data.address)
            row.source:SetText(data.source)
            local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(data.id)
            row.icon:SetTexture(A.Safe(icon) and icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        end
    end
    self.ruleEmpty:SetShown(#rows == 0)
    self.ruleEmpty:SetText(next(ids) and "No rules match. Clear filters to see all rules."
        or "No item rules yet.\nAdd a rule or choose a mail recipient from a bag item's menu.")
    self.clearRuleFilters:SetEnabled(filtered or self.ruleSearch:GetText() ~= "")
    self.ruleCount:SetText(#rows > 0 and string.format("%d to %d of %d", first + 1, math.min(first + pageSize, #rows), #rows) or "")
    self.prevRules:SetShown(pages > 1)
    self.nextRules:SetShown(pages > 1)
    self.prevRules:SetEnabled(self.rulePage > 1)
    self.nextRules:SetEnabled(self.rulePage < pages)
    self.addRule:SetEnabled(not A.readOnly)
end

function S:CreateRuleEditor()
    local shade = CreateFrame("Frame", nil, self.frame)
    shade:SetAllPoints(self.frame)
    shade:SetFrameLevel(self.frame:GetFrameLevel() + 16)
    shade:EnableMouse(true)
    local dim = shade:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints(shade)
    dim:SetColorTexture(.02, .03, .04, .7)
    shade:Hide()
    local f = UI.Window("BagMarksItemRecipients", "Item rule", 470, 312, shade)
    f:SetFrameLevel(shade:GetFrameLevel() + 1)
    self.ruleFrame = f
    local item = UI.Input(f, 16, -66, 438, "Enter an item ID or paste an item link")
    local recipient = UI.Input(f, 16, -211, 362, "Use mail settings")
    self.ruleItem, self.ruleRecipient = item, recipient
    recipient:SetMaxLetters(100)
    UI.Label(f, "Item ID or link", 16, -46, "GameFontHighlightSmall")
    self.ruleName = UI.Label(f, "", 16, -98, "GameFontHighlightSmall")
    self.ruleName:SetWidth(438)
    UI.Label(f, "Future copies on this character", 16, -130, "GameFontHighlightSmall")
    self.ruleMark = UI.MenuButton(f, "", 206, 16, -148, function(owner)
        MenuUtil.CreateContextMenu(owner, function(_, root)
            for _, option in ipairs(markChoices) do
                local value, label = option[1] or nil, option[2]
                root:CreateRadio(label, function() return self.editMark == value end, function()
                    self.editMark = value
                    self.ruleMark:SetText(label)
                end)
            end
        end)
    end)
    self.rulePaused = UI.Label(f, "Remembering is off in General.", 233, -155, "GameFontHighlightSmall")
    UI.Label(f, "Mail recipient across your account", 16, -191, "GameFontHighlightSmall")
    self.ruleChoose = self:ChooseButton(f, 386, -212, function() return recipient:GetText() end, function(address)
        self.pickedRuleAddress = address
        recipient:SetText(A.MailRoutes:DisplayName(address))
    end)
    self.ruleStatus = UI.Label(f, "", 16, -244, "GameFontHighlightSmall")
    self.ruleStatus:SetWidth(438)
    local function loadRule()
        local id = itemID(item:GetText())
        local saved = id and A.db.itemRecipients[id]
        self.pickedRuleAddress = nil
        self.editMark = id and A.char.itemRules[id]
        self.ruleMark:SetText(A.states[self.editMark] or "No automatic mark")
        recipient:SetText(A.MailRoutes:DisplayName(saved))
        self.ruleName:SetText(id and self:RuleName(id) or "")
        self.ruleStatus:SetText("")
        self.ruleRemove:SetShown(saved ~= nil or self.editMark ~= nil)
        f.TitleText:SetText((saved or self.editMark) and "Edit item rule" or "Add item rule")
    end
    item:SetScript("OnTextChanged", loadRule)
    item:SetScript("OnTabPressed", function() recipient:SetFocus() end)
    item:SetScript("OnEnterPressed", function() recipient:SetFocus() end)
    item:SetScript("OnEscapePressed", function() f:Hide() end)
    recipient:SetScript("OnEscapePressed", function() f:Hide() end)
    local function finish(revealID)
        f:Hide()
        self:RefreshRules(revealID)
        A.Mail:QueueDraftUpdate()
        A.Refresh()
    end
    local function saveRule()
        if A.readOnly then return end
        local id = itemID(item:GetText())
        if not id then self.ruleStatus:SetText("Enter an item ID or paste an item link."); item:SetFocus(); return end
        local address = recipient:GetText():gsub("[%c|]", ""):match("^%s*(.-)%s*$")
        if address == "" and not self.editMark then
            self.ruleStatus:SetText("Choose a future mark or enter a mail recipient.")
            return
        end
        if self.pickedRuleAddress and A.MailRoutes:MatchesToField(address, self.pickedRuleAddress) then address = self.pickedRuleAddress end
        if not A.Store:SetMailRoute(id, address) then self.ruleStatus:SetText("Your character name is loading. Try again in a moment."); return end
        A.Store:SetTypeRule(id, self.editMark)
        finish(id)
    end
    self.ruleRemove = UI.Button(f, "Remove rule", 106, 16, -274, function()
        local id = itemID(item:GetText())
        if not id or A.readOnly then return end
        A.Store:SetMailRoute(id, "")
        A.Store:SetTypeRule(id, nil)
        finish()
    end)
    UI.Tip(self.ruleRemove, "Remove rule", "Clear this character's future mark and the account's mail recipient for this item. Existing stacks keep their marks.")
    UI.Button(f, "Cancel", 78, 268, -274, function() f:Hide() end)
    self.ruleSave = UI.Button(f, "Save rule", 98, 356, -274, saveRule)
    UI.Select(self.ruleSave, true)
    recipient:SetScript("OnEnterPressed", saveRule)
    f:HookScript("OnHide", function()
        item:ClearFocus()
        recipient:ClearFocus()
        shade:Hide()
        A.Mail:QueueDraftUpdate()
    end)
end

function S:EditItemRule(id)
    if A.readOnly then return end
    if not self.ruleFrame then self:CreateRuleEditor() end
    self.ruleSearch:ClearFocus()
    self.ruleItem:SetEnabled(not id)
    self.ruleItem:SetText(id and tostring(id) or "")
    self.rulePaused:SetShown(not A.db.rememberItemTypes)
    local hasMenu = MenuUtil and type(MenuUtil.CreateContextMenu) == "function" or false
    self.ruleMark:SetEnabled(hasMenu)
    self.ruleChoose:SetEnabled(hasMenu)
    self.ruleFrame:GetParent():Show()
    self.ruleFrame:Show()
    self.ruleFrame:Raise()
    if id then self.ruleRecipient:SetFocus() else self.ruleItem:SetFocus() end
end

function S:OpenItemRoutes(id)
    self:Create()
    self.frame:Show()
    self:SelectTab("Item rules")
    if id then self:EditItemRule(id) end
end
