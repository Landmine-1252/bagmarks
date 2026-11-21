-- Shared mouse gesture and mark-cycle rules. Bag frames decide which item is
-- targeted; this module decides whether the gesture matches and how to mark it.
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

local chords = { [0] = "NONE", "ALT", "CTRL", "ALT-CTRL", "SHIFT", "ALT-SHIFT", "CTRL-SHIFT", "ALT-CTRL-SHIFT" }

function Interaction:ChordActive()
    local keys = (IsAltKeyDown() and 1 or 0) + (IsControlKeyDown() and 2 or 0) + (IsShiftKeyDown() and 4 or 0)
    return (A.mode and keys == 0) or A.db.modifier == chords[keys]
end

function Interaction:Active()
    -- A carried item needs the normal drop click, even while marking mode is on.
    if not A.IsEnabled() or GetCursorInfo() then return false end
    if A.InCombat() and ((SpellIsTargeting and SpellIsTargeting())
        or (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())) then return false end
    -- Require an exact chord so extra modifiers remain available to the game.
    -- Mode adds an unmodified click; it does not remove the configured shortcut.
    return self:ChordActive()
end

function Interaction:Matches(button)
    return button == A.db.mouseButton and self:Active()
end

function Interaction:Shortcut()
    local mouse = self.buttonLabels[A.db.mouseButton]
    if A.mode or A.db.modifier == "MODE" or A.db.modifier == "NONE" then return mouse end
    return self.modifierLabels[A.db.modifier] .. " + " .. mouse
end

function Interaction:Hint()
    local shortcut = self:Shortcut()
    if not A.mode and A.db.modifier == "MODE" then return "Enable Item Marking Mode, then " .. shortcut end
    return shortcut .. ": " .. self.actionLabels[A.db.markingAction] .. (A.mode and " (marking mode)" or "")
end

function Interaction:Cycle(owner, item)
    if not A.IsEnabled() or not item then return end
    -- A changed stack deserves an explicit choice even when cycling is enabled.
    if A.char.review[item.guid] then
        A.UI:ItemMenu(owner, item)
        return
    end
    -- Match the menu order: the first marking click protects an unmarked item.
    local nextState = { normal = "locked", locked = "junk", junk = "mail", mail = false }
    A.Store:Set(item, nextState[A.Store:Get(item.guid) or "normal"] or nil)
end

function Interaction:Mark(owner, item)
    if not A.IsEnabled() or not item then return end
    if A.db.markingAction == "menu" then A.UI:ItemMenu(owner, item)
    else self:Cycle(owner, item) end
end
