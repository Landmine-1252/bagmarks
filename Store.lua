-- Each character owns its GUID marks, learned item types and default recipient.
-- observed records the last inventory snapshot; review blocks automation for
-- a stack whose contents may have changed until the player reapplies a mark.
local _, A = ...
local Store = {}
A.Store = Store

local function tableOrEmpty(value) return type(value) == "table" and value or {} end
local function validGUID(value) return type(value) == "string" and value:match("^Item%-") end
local function finite(value) return type(value) == "number" and value == value and math.abs(value) < math.huge end
local function validItemID(value) return finite(value) and value > 0 and value % 1 == 0 end
local function recipientName(value)
    if type(value) ~= "string" then return "" end
    return value:gsub("[%c|]", ""):sub(1, 100):match("^%s*(.-)%s*$")
end

function Store:Initialize()
    self.baselineBeforeRules = nil
    local account, character = tableOrEmpty(BagMarksDB), tableOrEmpty(BagMarksCharDB)
    -- Never downgrade unknown future data. Leave the SavedVariables intact for the newer addon.
    A.readOnly = (finite(account.schema) and account.schema > A.schema)
        or (finite(character.schema) and character.schema > A.schema)
    local db = { schema = A.schema }
    for key, default in pairs(A.defaults) do
        local value = account[key]
        -- A saved false is a choice, not a missing value. Do not use "or default".
        if type(value) == type(default) then db[key] = value else db[key] = default end
    end
    if not ({ Classic = true, Minimal = true, Colorful = true })[db.theme] then db.theme = "Colorful" end
    if db.iconSize ~= "corner" and db.iconSize ~= "full" then db.iconSize = A.defaults.iconSize end
    -- Schema 1 already has the single modifier; new input/mail preferences get safe defaults.
    if not A.Interaction.modifierLabels[db.modifier] then db.modifier = A.defaults.modifier end
    if not A.Interaction.buttonLabels[db.mouseButton] then db.mouseButton = A.defaults.mouseButton end
    if not A.Interaction.actionLabels[db.markingAction] then db.markingAction = A.defaults.markingAction end
    db.angle = finite(db.angle) and db.angle % 360 or A.defaults.angle
    -- The old shared address has no recorded sender. Keep it available for explicit import.
    local previousRecipient = recipientName(account.previousRecipient or account.recipient)
    if previousRecipient ~= "" then db.previousRecipient = previousRecipient end
    local char = { schema = A.schema, recipient = recipientName(character.recipient),
        marks = {}, observed = {}, review = {}, itemRules = {} }
    for id, state in pairs(tableOrEmpty(character.itemRules)) do
        if validItemID(id) and (state == "mail" or state == "junk") then char.itemRules[id] = state end
    end
    for guid, record in pairs(tableOrEmpty(character.marks)) do
        -- Schema 0 stored GUID -> state. This migration never introduces an item-ID fallback.
        if type(record) == "string" then record = { state = record } end
        if validGUID(guid) and type(record) == "table" and A.states[record.state] then
            char.marks[guid] = { state = record.state, itemID = finite(record.itemID) and record.itemID or nil }
        end
    end
    for guid, item in pairs(tableOrEmpty(character.observed)) do
        if validGUID(guid) and type(item) == "table" and finite(item.itemID)
            and finite(item.count) and item.count > 0 and finite(item.bag) then
            char.observed[guid] = { itemID = item.itemID, count = item.count, bag = item.bag }
        end
    end
    for guid, value in pairs(tableOrEmpty(character.review)) do
        if validGUID(guid) and value == true then char.review[guid] = true end
    end
    A.db, A.char = db, char
    if not A.readOnly then BagMarksDB, BagMarksCharDB = db, char end
end

function Store:SetRecipient(value)
    if not A.readOnly then A.char.recipient = recipientName(value) end
end

function Store:Get(guid)
    -- No record means Normal; keeping it absent also makes Clear Mark explicit.
    local record = guid and A.char.marks[guid]
    return record and record.state or nil
end

function Store:Set(item, state)
    if not A.CanAct() or not item or (state and not A.states[state]) then return false end
    A.char.marks[item.guid] = state and { state = state, itemID = item.itemID } or nil
    -- An explicit menu/cycle choice acknowledges the current stack contents.
    A.char.review[item.guid] = nil
    A.char.observed[item.guid] = { itemID = item.itemID, count = item.count, bag = item.bag }
    -- Record the other copies already present before teaching a new rule.
    self:RefreshInventory()
    if A.db.rememberItemTypes and state ~= "locked" and validItemID(item.itemID) then
        A.char.itemRules[item.itemID] = state or nil -- Clear Mark also forgets the type.
    end
    A.Refresh()
    return true
end

-- An explicit type rule can mark a new carried stack or newly acquired units.
-- A conflicting split/merge still needs review because the client gives no lineage.
function Store:Reconcile(items, scope)
    if A.readOnly then return end
    local previous, diminished = A.char.observed, {}
    local carried, rules = {}, A.char.itemRules
    if A.db.rememberItemTypes and not self.baselineBeforeRules and next(rules) then
        for _, bag in ipairs(A.API:BagIDs(false)) do carried[bag] = true end
    end
    for guid, old in pairs(previous) do
        local state = self:Get(guid)
        if scope[old.bag] and (state or A.char.review[guid]) then
            local current = items[guid]
            if not current or current.count < old.count then
                local source = diminished[old.itemID]
                -- true records an uncertain or mixed source, even if another source agrees.
                if A.char.review[guid] or (source and source ~= state) then diminished[old.itemID] = true
                else diminished[old.itemID] = state end
            end
        end
    end
    for guid, item in pairs(items) do
        local old = previous[guid]
        local rule = carried[item.bag] and rules[item.itemID]
        local growing = old and item.count > old.count
        if not old or growing or (rule and not carried[old.bag]) then
            local state, source = self:Get(guid), diminished[item.itemID]
            if rule and (not state or state == rule) and (not source or source == rule) then
                if not state and not A.char.review[guid] then
                    A.char.marks[guid] = { state = rule, itemID = item.itemID }
                end
            elseif source or (growing and state) then
                A.char.review[guid] = true
            end
        end
    end
    local nextObserved = {}
    for guid, old in pairs(previous) do
        -- Keep observations for inaccessible bags; closing a bank is not a loss.
        if not scope[old.bag] then nextObserved[guid] = old end
    end
    for guid, item in pairs(items) do
        nextObserved[guid] = { itemID = item.itemID, count = item.count, bag = item.bag }
    end
    A.char.observed = nextObserved
    if next(scope) then self.baselineBeforeRules = nil end
end

function Store:RefreshInventory()
    if not A.CanAct() then return end
    local items, scope = A.API:Scan(true)
    self:Reconcile(items, scope)
    A.inventory = items
end

function Store:Eligible(item, state)
    return item and not item.busy and self:Get(item.guid) == state and not A.char.review[item.guid]
end

function Store:ResetSettings()
    if A.readOnly then return end
    for key, value in pairs(A.defaults) do A.db[key] = value end
    A.char.recipient = ""
    A.mode = false
    A.Operations:Cancel()
    A.Refresh()
end
