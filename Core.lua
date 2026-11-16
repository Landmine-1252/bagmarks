-- WoW passes the same private addon table to each Lua file in TOC order.
-- Modules share state through A; Blizzard's named entry points use globals.
local addonName, A = ...
A.name = addonName
A.version = "1.0.4"
-- SavedVariables format version, independent of the addon release number.
A.schema = 2
A.states = { locked = "Locked", junk = "Junk", mail = "Mail" }
-- Store.lua fills missing/invalid options from these values and keeps valid
-- saved choices, including shortcuts selected before a default changed.
A.defaults = {
    enabled = true, minimap = true, tooltips = true, overlays = true, iconSize = "corner",
    modifier = "CTRL-SHIFT", mouseButton = "RightButton", markingAction = "menu",
    recipient = "", autoFillRecipient = true, autoSellJunk = false, theme = "Colorful", angle = 220,
}
A.mode = false -- Intentionally session-only, to avoid surprising right clicks after login.

function A.Safe(value)
    -- Restricted client values must be rejected before comparison or formatting.
    return not issecretvalue or not issecretvalue(value)
end

function A.InCombat()
    return InCombatLockdown and InCombatLockdown()
end

function A.Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66BagMarks:|r " .. message)
    end
end

-- Native protection uses IsEnabled even in combat. Marking and queued item
-- actions use CanAct, which adds the combat restriction.
function A.IsEnabled()
    return A.db and A.db.enabled and not A.readOnly and A.API.available
end

function A.CanAct()
    return A.IsEnabled() and not A.InCombat()
end

function A.Refresh()
    if not A.ready then return end
    -- Apply holds first so refreshed click guards and indicators reflect the
    -- current marks. Individual modules handle their own combat restrictions.
    A.Protection:Refresh()
    A.Bags:Discover()
    A.Bags:Refresh()
    A.Hover:Refresh()
    A.Minimap:Refresh()
    A.Settings:Refresh()
    A.Operations:RefreshButtons()
end

function A.ToggleMode()
    if not A.IsEnabled() then A.Print("Enable BagMarks in /bm first."); return end
    if A.InCombat() then A.Print("Item Marking Mode is unavailable during combat."); return end
    A.mode = not A.mode
    A.Refresh()
end

function A.SetOption(key, value)
    if A.readOnly then return end
    A.db[key] = value
    if key == "enabled" and not value then
        A.mode = false
        A.Operations:Cancel()
    end
    if key == "autoSellJunk" and not value then A.Operations:CancelAutoSale() end
    if key == "autoFillRecipient" or key == "recipient" then A.Mail:QueueFill() end
    A.Refresh()
end
