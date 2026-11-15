local _, A = ...
local Interaction = {}
A.Interaction = Interaction

Interaction.modifiers = {
    { "ALT", "Alt" }, { "CTRL", "Ctrl" }, { "SHIFT", "Shift" },
    { "ALT-CTRL", "Alt + Ctrl" }, { "ALT-SHIFT", "Alt + Shift" },
    { "CTRL-SHIFT", "Ctrl + Shift" }, { "ALT-CTRL-SHIFT", "Alt + Ctrl + Shift" },
    { "NONE", "None" }, { "MODE", "Marking Mode only" },
}
Interaction.buttons = {
    { "LeftButton", "Left Click" }, { "RightButton", "Right Click" },
    { "MiddleButton", "Middle Click" }, { "Button4", "Mouse Button 4" }, { "Button5", "Mouse Button 5" },
}
Interaction.actions = { { "menu", "Open mark menu" }, { "cycle", "Cycle marks" } }
Interaction.modifierLabels, Interaction.buttonLabels, Interaction.actionLabels = {}, {}, {}
for _, option in ipairs(Interaction.modifiers) do Interaction.modifierLabels[option[1]] = option[2] end
for _, option in ipairs(Interaction.buttons) do Interaction.buttonLabels[option[1]] = option[2] end
for _, option in ipairs(Interaction.actions) do Interaction.actionLabels[option[1]] = option[2] end

function Interaction:Active()
    if not A.CanAct() or GetCursorInfo() then return false end
    local keys = {}
    if IsAltKeyDown() then keys[#keys + 1] = "ALT" end
    if IsControlKeyDown() then keys[#keys + 1] = "CTRL" end
    if IsShiftKeyDown() then keys[#keys + 1] = "SHIFT" end
    local held = #keys == 0 and "NONE" or table.concat(keys, "-")
    return (A.mode and held == "NONE") or A.db.modifier == held
end

function Interaction:Matches(button)
    return button == A.db.mouseButton and self:Active()
end

function Interaction:Hint()
    local mouse = self.buttonLabels[A.db.mouseButton]
    local action = self.actionLabels[A.db.markingAction]
    if A.mode then return mouse .. ": " .. action .. " (marking mode)" end
    if A.db.modifier == "MODE" then return "Enable Item Marking Mode, then " .. mouse end
    local modifier = A.db.modifier ~= "NONE" and (self.modifierLabels[A.db.modifier] .. " + ") or ""
    return modifier .. mouse .. ": " .. action
end

function Interaction:Mark(owner, item)
    if not A.CanAct() or not item then return end
    -- A changed stack deserves an explicit choice even when cycling is enabled.
    if A.db.markingAction == "menu" or A.char.review[item.guid] then
        A.UI:ItemMenu(owner, item)
        return
    end
    -- Match the menu order: the first marking click protects an unmarked item.
    local nextState = { normal = "locked", locked = "junk", junk = "mail", mail = false }
    A.Store:Set(item, nextState[A.Store:Get(item.guid) or "normal"] or nil)
end
