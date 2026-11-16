local addonName, A = ...
A.name = addonName
A.version = "1.0.2"
A.schema = 2
A.states = { locked = "Locked", junk = "Junk", mail = "Mail" }
A.defaults = {
    enabled = true, minimap = true, tooltips = true, overlays = true,
    modifier = "CTRL-SHIFT", mouseButton = "RightButton", markingAction = "menu",
    recipient = "", autoFillRecipient = true, autoSellJunk = false, theme = "Colorful", angle = 220,
}
A.mode = false -- Intentionally session-only, to avoid surprising right clicks after login.

function A.Safe(value)
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

function A.IsEnabled()
    return A.db and A.db.enabled and not A.readOnly and A.API.available
end

function A.CanAct()
    return A.IsEnabled() and not A.InCombat()
end

function A.Refresh()
    if not A.ready then return end
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
