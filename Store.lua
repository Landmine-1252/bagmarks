local _, A = ...
local Store = {}
A.Store = Store

local function tableOrEmpty(value) return type(value) == "table" and value or {} end
local function validGUID(value) return type(value) == "string" and value:match("^Item%-") end
local function finite(value) return type(value) == "number" and value == value and math.abs(value) < math.huge end

function Store:Initialize()
    local account, character = tableOrEmpty(BagMarksDB), tableOrEmpty(BagMarksCharDB)
    -- Never downgrade unknown future data. Leave the SavedVariables intact for the newer addon.
    A.readOnly = (finite(account.schema) and account.schema > A.schema)
        or (finite(character.schema) and character.schema > A.schema)
    local db = { schema = A.schema }
    for key, default in pairs(A.defaults) do
        local value = account[key]
        if type(value) == type(default) then db[key] = value else db[key] = default end
    end
    if not ({ Classic = true, Minimal = true, Colorful = true })[db.theme] then db.theme = "Colorful" end
    -- Schema 1 already has the single modifier; new input/mail preferences get safe defaults.
    if not A.Interaction.modifierLabels[db.modifier] then db.modifier = A.defaults.modifier end
    if not A.Interaction.buttonLabels[db.mouseButton] then db.mouseButton = A.defaults.mouseButton end
    if not A.Interaction.actionLabels[db.markingAction] then db.markingAction = A.defaults.markingAction end
    db.angle = finite(db.angle) and db.angle % 360 or A.defaults.angle
    db.recipient = db.recipient:gsub("[%c|]", ""):sub(1, 100):match("^%s*(.-)%s*$")
    local char = { schema = A.schema, marks = {}, observed = {}, review = {} }
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

function Store:Get(guid)
    local record = guid and A.char.marks[guid]
    return record and record.state or nil
end

function Store:Set(item, state)
    if not A.CanAct() or not item or (state and not A.states[state]) then return false end
    A.char.marks[item.guid] = state and { state = state, itemID = item.itemID } or nil
    A.char.review[item.guid] = nil
    A.char.observed[item.guid] = { itemID = item.itemID, count = item.count, bag = item.bag }
    self:RefreshInventory()
    A.Refresh()
    return true
end

-- GUIDs have no documented split/merge lineage. Never transfer a state by item ID.
-- A growing stack could contain units from a marked stack. Quarantine that GUID
-- from automation until the player explicitly reviews/reapplies its mark.
function Store:Reconcile(items, scope)
    if A.readOnly then return end
    local previous, diminished = A.char.observed, {}
    for guid, old in pairs(previous) do
        if scope[old.bag] and (self:Get(guid) or A.char.review[guid]) then
            local current = items[guid]
            if not current or current.count < old.count then diminished[old.itemID] = true end
        end
    end
    for guid, item in pairs(items) do
        local old = previous[guid]
        -- Also quarantine marked stacks that grew while their source was not observable.
        if (not old or item.count > old.count) and (diminished[item.itemID] or (old and self:Get(guid))) then
            A.char.review[guid] = true
        end
    end
    local nextObserved = {}
    for guid, old in pairs(previous) do
        if not scope[old.bag] then nextObserved[guid] = old end
    end
    for guid, item in pairs(items) do
        nextObserved[guid] = { itemID = item.itemID, count = item.count, bag = item.bag }
    end
    A.char.observed = nextObserved
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
    A.mode = false
    A.Operations:Cancel()
    A.Refresh()
end
