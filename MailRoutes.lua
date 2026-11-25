local _, A = ...
local Routes = {}
A.MailRoutes = Routes

-- Untranslated Comprehension scrolls in Forever's item data (1.60.1.70959).
-- Ordinary stat scrolls share the consumable subclass, so match exact IDs.
local mageScrolls = {
    [211780] = true, [211784] = true, [211785] = true, [211786] = true, [211787] = true,
    [211853] = true, [211854] = true, [211855] = true,
    [213543] = true, [213544] = true, [213545] = true, [213546] = true, [213547] = true,
    [281015] = true, [281016] = true, [281017] = true, [281018] = true,
}

Routes.materials = {
    { key = "cloth", label = "Cloth", subclass = 5, icon = "INV_Fabric_Linen_01" },
    { key = "cooking", label = "Cooking", subclass = 8, icon = "INV_Misc_Food_15",
        tip = "Meat, fish, eggs and other ingredients used for meals and drinks. Cooking recipes also use this recipient unless you set a recipe destination." },
    { key = "herbs", label = "Herbs", subclass = 9, icon = "INV_Misc_Herb_10" },
    { key = "leather", label = "Leather and hides", subclass = 6, icon = "INV_Misc_LeatherScrap_03" },
    { key = "metal", label = "Ore, bars and stone", subclass = 7, icon = "INV_Ore_Copper_01" },
}

-- Recipe subclasses and teaching items in Forever 1.60.1.70959. The listed
-- item IDs teach a different profession from their subclass, or are filed as Books.
Routes.professions = {
    { key = "recipeAlchemy", label = "Alchemy", subclass = 6, material = "herbs", icon = "Trade_Alchemy" },
    { key = "recipeBlacksmithing", label = "Blacksmithing", subclass = 4, material = "metal", icon = "Trade_BlackSmithing",
        items = { 275598, 275599, 275600, 275601, 275602, 275603 } },
    { key = "recipeCooking", label = "Cooking", subclass = 5, material = "cooking", icon = "INV_Misc_Food_15" },
    { key = "recipeEnchanting", label = "Enchanting", subclass = 8, icon = "Trade_Engraving" },
    { key = "recipeEngineering", label = "Engineering", subclass = 3, icon = "Trade_Engineering" },
    { key = "recipeFirstAid", label = "First Aid", subclass = 7, icon = "Spell_Holy_SealOfSacrifice" },
    { key = "recipeFishing", label = "Fishing", subclass = 9, icon = "Trade_Fishing" },
    { key = "recipeHerbalism", label = "Herbalism", material = "herbs", icon = "Trade_Herbalism", items = { 273106, 273120 } },
    { key = "recipeLeatherworking", label = "Leatherworking", subclass = 1, material = "leather", icon = "Trade_LeatherWorking",
        items = { 275586, 275587 } },
    { key = "recipeMining", label = "Mining", material = "metal", icon = "Trade_Mining", items = { 273097, 273122 } },
    { key = "recipeSkinning", label = "Skinning", material = "leather", icon = "INV_Misc_Pelt_Wolf_01", items = { 273098, 273109 } },
    { key = "recipeTailoring", label = "Tailoring", subclass = 2, material = "cloth", icon = "Trade_Tailoring" },
}

-- Reagents for Forever meals and drinks filed outside the Cooking trade-goods
-- subclass, including spices, Winter Squid and Whimsyfin. Other configured
-- material recipients take priority for shared ingredients such as herbs.
local otherCookingReagents = {
    [159] = true, [785] = true, [1179] = true, [1205] = true, [1475] = true, [1645] = true, [1708] = true,
    [2447] = true, [2452] = true, [2596] = true, [2678] = true, [2692] = true, [2894] = true, [3357] = true,
    [3713] = true, [3818] = true, [3821] = true, [4402] = true, [4536] = true, [5051] = true, [5637] = true,
    [6522] = true, [8146] = true, [8150] = true, [8766] = true, [8838] = true, [9061] = true, [13465] = true,
    [13755] = true, [13890] = true, [13893] = true, [17194] = true, [17196] = true, [18255] = true,
    [249796] = true, [251524] = true, [252948] = true,
}

Routes.labels = { bank = "Account default", mageScrolls = "Mage scrolls", recipes = "Recipe default", disenchanter = "Disenchanter" }
local materialsBySubclass, recipesBySubclass, recipesByItem = {}, {}, {}
for _, material in ipairs(Routes.materials) do
    Routes.labels[material.key] = material.label
    materialsBySubclass[material.subclass] = material
end
for _, profession in ipairs(Routes.professions) do
    Routes.labels[profession.key] = profession.label .. " recipes"
    if profession.subclass then recipesBySubclass[profession.subclass] = profession end
    if profession.items then
        for _, id in ipairs(profession.items) do recipesByItem[id] = profession end
    end
end

local function realmName()
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if A.Safe(realm) and type(realm) == "string" and realm ~= "" then return realm end
end

local function regionalNames()
    return RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled()
end

function Routes:Qualify(name)
    if not name or name == "" then return end
    local character, realm = name:match("^([^-]+)%-(.+)$")
    if not realm then character, realm = name, realmName() end
    if realm then return character .. "-" .. realm:gsub("%s+", "") end
    -- A Forever mail address is regionally unique even before the realm loads.
    if regionalNames() then return character end
end

local function regionalPlayerName(getName, unit)
    if type(getName) ~= "function" then return end
    local ok, first, surname = pcall(getName, unit)
    if not ok or not A.Safe(first) or type(first) ~= "string" or first == "" then return end
    -- Some name APIs return both parts together, others return them separately.
    local separator = Constants and Constants.CharacterNameSeparatorConsts
        and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR
    if separator and separator ~= "" and separator ~= " " then
        local start, finish = first:find(separator, 1, true)
        if start then first = first:sub(1, start - 1) .. " " .. first:sub(finish + 1) end
    end
    if first:match("^%S+ %S") then return first end
    if not first:find("[%s%-]") and A.Safe(surname) and type(surname) == "string" and surname ~= ""
        and not surname:find("[%d%s%-]") and surname ~= realmName() then
        return first .. " " .. surname
    end
end

local function playerGUID()
    local guid = UnitGUID and UnitGUID("player")
    if A.Safe(guid) and type(guid) == "string" and guid ~= "" then return guid end
end

function Routes:PlayerAddress()
    if regionalNames() then
        local name = regionalPlayerName(UnitNameUnmodified, "player") or regionalPlayerName(UnitName, "player")
            or regionalPlayerName(UnitFullName, "player")
        if not name then
            local guid = playerGUID()
            if guid then
                name = regionalPlayerName(UnitNameFromGUID, guid)
                if not name and self.senderGUID == guid then name = self.senderName end
            end
        end
        return self:Qualify(name)
    end
    local formatName = NameUtil and NameUtil.GetUnmodifiedUnitFullName or GetUnitName or UnitName
    if formatName then
        local ok, name = pcall(formatName, "player", true)
        if ok and A.Safe(name) and type(name) == "string" then return self:Qualify(name) end
    end
end

function Routes:RememberPlayer()
    local address = self:PlayerAddress()
    if not address then return end
    local name = self:DisplayName(address)
    -- The unit name can disappear after login. Only reuse a name confirmed
    -- in this session for the same player GUID.
    self.senderGUID, self.senderName = playerGUID(), name
    if not A.readOnly then
        A.db.knownCharacters[name] = nil
        A.db.knownCharacters[address] = true
    end
end

-- Versions through 1.0.9 recorded the two values from UnitFullName as
-- First-Surname. Only repair a saved destination when it matches that roster.
function Routes:LegacyRosterName(address)
    if not RegionalUniqueNamesEnabled or not RegionalUniqueNamesEnabled() then return end
    local first, surname = address:match("^([^%s%-]+)%-([^%s%-]+)$")
    if not surname or surname:find("%d") or surname:lower() == (realmName() or ""):lower() then return end
    return first .. " " .. surname
end

local function namesEqual(left, right)
    if not left or left == "" or not right or right == "" then return false end
    if strcmputf8i then return strcmputf8i(left, right) == 0 end
    return left:lower() == right:lower()
end

function Routes:SameRecipient(left, right)
    if regionalNames() then
        -- Two characters can save the same regional mailbox with different realm suffixes.
        return namesEqual(self:DisplayName(left), self:DisplayName(right))
    end
    return namesEqual(self:Qualify(left), self:Qualify(right))
end

function Routes:DisplayName(address)
    -- Forever's first name and surname are both before the server separator.
    return address and address:match("^[^-]*") or ""
end

function Routes:MatchesToField(text, address)
    if text and text:find("-", 1, true) then return self:SameRecipient(text, address) end
    return namesEqual(text, self:DisplayName(address))
end

local function deliverable(name, label)
    if not name then return nil, "No recipient set" end
    local player = Routes:PlayerAddress()
    if not player then return nil, "Character unavailable", name end
    if namesEqual(Routes:DisplayName(name), Routes:DisplayName(player)) then return nil, "Keep on this character", name end
    return name, label
end

function Routes:Fallback()
    if A.char.recipient ~= "" then return deliverable(A.char.recipient, "Character override") end
    return deliverable(A.db.mailRoutes.bank, self.labels.bank)
end

function Routes:RecipeDefault(profession)
    local routes = A.db.mailRoutes
    local key = routes.recipes and "recipes" or profession.material
    return routes[key], self.labels[key]
end

local function recipeDestination(profession)
    local recipient = A.db.mailRoutes[profession.key]
    if recipient then return deliverable(recipient, Routes.labels[profession.key]) end
    local inherited, source = Routes:RecipeDefault(profession)
    if inherited then return deliverable(inherited, source) end
    return Routes:Fallback()
end

local function hasClassRoutes(routes)
    for key in pairs(routes) do
        if key ~= "bank" and key ~= "mageScrolls" and key ~= "disenchanter" then return true end
    end
    return false
end

function Routes:Resolve(itemID, state)
    local routes = A.db.mailRoutes
    if state == "disenchant" then
        if not routes.disenchanter then return nil, "No disenchanter set" end
        return deliverable(routes.disenchanter, self.labels.disenchanter)
    end
    if A.db.itemRecipients[itemID] then return deliverable(A.db.itemRecipients[itemID], "Item rule") end
    if mageScrolls[itemID] then
        if routes.mageScrolls then return deliverable(routes.mageScrolls, self.labels.mageScrolls) end
        return self:Fallback()
    end
    local profession = recipesByItem[itemID]
    if profession then return recipeDestination(profession) end
    if not hasClassRoutes(routes) then return self:Fallback() end

    local classes = Enum and Enum.ItemClass
    local ok, _, _, _, _, _, class, subclass = pcall(C_Item and C_Item.GetItemInfoInstant, itemID)
    if not classes or not classes.Tradegoods or not classes.Recipe or not ok or not A.Safe(class) or type(class) ~= "number"
        or not A.Safe(subclass) or type(subclass) ~= "number" then return nil, "Item category unknown" end
    if class == classes.Recipe and recipesBySubclass[subclass] then
        return recipeDestination(recipesBySubclass[subclass])
    end
    if class == classes.Tradegoods then
        local material = materialsBySubclass[subclass]
        if material and routes[material.key] then return deliverable(routes[material.key], material.label) end
    end
    if routes.cooking and otherCookingReagents[itemID] then
        return deliverable(routes.cooking, "Cooking")
    end
    return self:Fallback()
end

function Routes:Tooltip(itemID, state)
    local recipient, reason = self:Resolve(itemID, state)
    if state == "disenchant" then
        return "Disenchant (" .. (recipient and ("Mail to " .. self:DisplayName(recipient)) or reason) .. ")"
    end
    if recipient then return "Mail to " .. self:DisplayName(recipient) .. " (" .. reason .. ")" end
    return "Mail (" .. reason .. ")"
end
