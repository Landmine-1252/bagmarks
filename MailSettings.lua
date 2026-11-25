local _, A = ...
local S, UI = A.Settings, A.UI

local function saved(key)
    return key == "recipient" and A.char.recipient or A.db.mailRoutes[key]
end

local function save(key, text)
    if key == "recipient" then A.Store:SetRecipient(text) else A.Store:SetMailRoute(key, text) end
end

local function knownRecipients()
    local choices, byName = {}, {}
    local regional = RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled()
    for address in pairs(A.db.knownCharacters) do
        local name = A.MailRoutes:DisplayName(address)
        if name ~= "" and (not regional or name:find(" ", 1, true)) then
            local key = name:lower()
            local current = byName[key]
            local localAddress = A.MailRoutes:Qualify(name)
            if not current or address == localAddress or (current ~= localAddress and address < current) then byName[key] = address end
        end
    end
    for _, address in pairs(byName) do choices[#choices + 1] = address end
    table.sort(choices, function(a, b) return A.MailRoutes:DisplayName(a):lower() < A.MailRoutes:DisplayName(b):lower() end)
    return choices
end

function S:ChooseButton(parent, x, y, current, selectAddress)
    return UI.Button(parent, "Choose", 68, x, y, function(owner)
        MenuUtil.CreateContextMenu(owner, function(_, root)
            local choices = knownRecipients()
            root:CreateTitle(#choices == 0 and "Log in to a character to add its full name" or "Your characters")
            if #choices > 10 then root:SetScrollMode(300) end
            for _, address in ipairs(choices) do
                local name = A.MailRoutes:DisplayName(address)
                local function selected() return A.MailRoutes:MatchesToField(name, current()) end
                root:CreateRadio(name, selected, function() selectAddress(selected() and current() or address) end)
            end
        end)
    end)
end

function S:EditingRecipient()
    if self.ruleRecipient and self.ruleRecipient:HasFocus() then return self.ruleRecipient end
    for _, field in ipairs(self.addressFields or {}) do if field:HasFocus() then return field end end
end

function S:CreateMailPanel()
    local w, parent = self.width, self.panels.Mail
    self.recipeBack = UI.Button(parent, "Destinations", 122, 0, 0, function() self:ShowMailRecipes(false) end)
    self.recipeButton = UI.Button(parent, "Profession recipes", 146, 128, 0, function() self:ShowMailRecipes(true) end)
    UI.Button(parent, "View item rules", 116, w - 116, 0, function() self:OpenItemRoutes() end)
    local panel, recipes = CreateFrame("Frame", nil, parent), CreateFrame("Frame", nil, parent)
    for _, page in ipairs({ panel, recipes }) do
        page:SetSize(w, 427)
        page:SetPoint("TOPLEFT", 0, -36)
        page.fields = {}
    end
    self.mailMain, self.mailRecipes = panel, recipes
    self.addressFields = {}
    local function row(page, key, label, texture, y, tip, hint)
        local icon = page:CreateTexture(nil, "ARTWORK")
        icon:SetSize(17, 17)
        icon:SetPoint("TOPLEFT", 1, y - 4)
        icon:SetTexture("Interface\\Icons\\" .. texture)
        UI.Label(page, label, 26, y - 6)
        local field = UI.Input(page, 164, y, w - 242, hint or "Use default recipient")
        field:SetFontObject("GameFontHighlight")
        field:SetMaxLetters(100)
        field.key = key
        local fields = page.fields
        fields[#fields + 1] = field
        self.addressFields[#self.addressFields + 1] = field
        local index = #fields
        field:SetScript("OnEnterPressed", function() field:ClearFocus() end)
        field:SetScript("OnEscapePressed", function()
            field:SetText(A.MailRoutes:DisplayName(saved(key)))
            field:ClearFocus()
        end)
        field:SetScript("OnTabPressed", function()
            fields[(index - 1 + (IsShiftKeyDown() and -1 or 1)) % #fields + 1]:SetFocus()
        end)
        field:SetScript("OnEditFocusLost", function()
            if field:GetText() ~= A.MailRoutes:DisplayName(saved(key)) then save(key, field:GetText()) end
            self:RefreshRecipient()
            A.Mail:QueueDraftUpdate()
        end)
        UI.Tip(field, label, tip)
        field.choose = self:ChooseButton(page, w - 68, y - 1, function() return saved(key) end, function(address)
            field:SetText(A.MailRoutes:DisplayName(address))
            save(key, address)
            field:ClearFocus()
            self:RefreshRecipient()
            A.Mail:QueueDraftUpdate()
        end)
        return field
    end
    UI.Label(panel, "Default recipients", 0, -5, "GameFontNormal")
    row(panel, "bank", "Account default", "INV_Misc_Coin_01", -28,
        "Receives Mail items without an item or category recipient. Each character can set its own default below.",
        "Bank alt or other recipient")
    self.recipient = row(panel, "recipient", "Character override", "INV_Letter_15", -57,
        "Replaces the account default for mail from this character. Leave both defaults blank to keep unmatched items in your bags.",
        "Use account default")
    self.usePreviousRecipient = UI.Button(panel, "Use previous recipient", 154, w - 154, 0, function()
        if A.readOnly or A.char.recipient ~= "" or not A.db.previousRecipient then return end
        self.recipient:ClearFocus()
        A.Store:SetRecipient(A.db.previousRecipient)
        A.db.previousRecipient = nil
        self:RefreshRecipient()
        A.Mail:QueueDraftUpdate()
    end)
    UI.Tip(self.usePreviousRecipient, "Previous account recipient", function()
        return "Use " .. A.MailRoutes:DisplayName(A.db.previousRecipient) .. " as the default recipient for this character only."
    end)
    UI.Line(panel, 0, -92, w)
    UI.Label(panel, "Crafting materials", 0, -100, "GameFontNormal")
    for i, material in ipairs(A.MailRoutes.materials) do
        row(panel, material.key, material.label, material.icon, -120 - (i - 1) * 29,
            material.tip or ("Receives " .. material.label:lower() .. " marked for Mail."))
    end

    UI.Line(panel, 0, -272, w)
    UI.Label(panel, "Specialist recipients", 0, -280, "GameFontNormal")
    row(panel, "disenchanter", A.MailRoutes.labels.disenchanter, "Trade_Engraving", -300,
        "Receives items marked Disenchant. Leave blank to keep those items in your bags.", "Keep in bags")
    row(panel, "mageScrolls", "Mage scrolls", "INV_Scroll_03", -329,
        "Receives untranslated scrolls marked for Mail that a mage can decipher with Comprehension.")

    local mailbox = UI.Panel(panel, 0, -368, w, 56)
    UI.Label(mailbox, "At the mailbox", 12, -8, "GameFontNormal")
    local half = w / 2
    local fill = self:Check(mailbox, "autoFillRecipient", "Automatically fill the To field", 8, -24, half - 18)
    UI.Tip(fill, "Fill recipient", "Fill a fresh draft with the next recipient. You can also type a name in the To field.")
    UI.Line(mailbox, half, -28, 1, 19)
    local attach = self:Check(mailbox, "autoAttachMail", "Automatically attach marked items", half + 8, -24, half - 16)
    UI.Tip(attach, "Attach marked items", "Prepare one recipient's stacks at a time. Review each draft and click Send.")

    row(recipes, "recipes", "Recipe default", "INV_Scroll_03", 0,
        "Used when a profession has no override. Clear this field to use a related material recipient or the mail fallback.", "Use related material or fallback")
    UI.Line(recipes, 0, -37, w)
    UI.Label(recipes, "Profession overrides", 0, -48, "GameFontNormal")
    for i, profession in ipairs(A.MailRoutes.professions) do
        local field = row(recipes, profession.key, profession.label, profession.icon, -70 - (i - 1) * 29,
            "Send " .. profession.label .. " recipe items to this player.")
        field.profession = profession
    end
end

function S:ShowMailRecipes(show)
    local field = self:EditingRecipient()
    if field and field.key then field:ClearFocus() end
    self.mailMain:SetShown(not show)
    self.mailRecipes:SetShown(show)
    UI.Select(self.recipeBack, not show)
    UI.Select(self.recipeButton, show)
end

function S:RefreshRecipient()
    local canChoose = not A.readOnly and MenuUtil and MenuUtil.CreateContextMenu and true or false
    for _, field in ipairs(self.addressFields) do
        local address = A.MailRoutes:DisplayName(saved(field.key))
        if not field:HasFocus() and field:GetText() ~= address then field:SetText(address) end
        if field.profession then
            local inherited = A.MailRoutes:RecipeDefault(field.profession)
            local hint = inherited and ("Use " .. A.MailRoutes:DisplayName(inherited)) or "Use default recipient"
            if field.Instructions:GetText() ~= hint then field.Instructions:SetText(hint) end
        end
        field:SetEnabled(not A.readOnly)
        field.choose:SetEnabled(canChoose)
    end
    self.usePreviousRecipient:SetShown(not A.readOnly and A.char.recipient == "" and A.db.previousRecipient ~= nil)
end
