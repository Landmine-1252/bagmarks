local addonName, A = ...
local frame = CreateFrame("Frame")
A.eventFrame = frame

local function updateInventory()
    A.pendingRefresh = false
    if not A.ready then return end
    A.Store:RefreshInventory()
    A.Bags:Discover()
    A.Refresh()
end

local function queueRefresh()
    if A.pendingRefresh then return end
    A.pendingRefresh = true
    C_Timer.After(0, updateInventory)
end

function A.Slash(message)
    local command = (message or ""):match("^%s*(%S*)"):lower()
    if command == "" then A.Settings:Toggle()
    elseif command == "mode" then A.ToggleMode()
    elseif command == "minimap" then A.SetOption("minimap", not A.db.minimap)
    elseif command == "theme" then A.CycleTheme()
    elseif command == "reset" then
        A.UI:Confirm("Reset BagMarks settings", "Restore default preferences?\n\nItem marks and Blizzard keybindings will be kept.\n\nDefault theme: Colorful\nDefault modifier: Alt", "Reset settings", function() A.Store:ResetSettings() end)
    else
        A.Print("/bm or /bagmarks: Settings; /bm mode: Marking mode; /bm minimap: Minimap button; /bm theme: Cycle themes; /bm reset: Reset preferences; /bm help: This reference.")
    end
end

local function initialize()
    A.API:Initialize()
    A.Store:Initialize()
    A.ready = true
    SLASH_BAGMARKS1, SLASH_BAGMARKS2 = "/bagmarks", "/bm"
    SlashCmdList.BAGMARKS = A.Slash
    A.Bags:InstallHooks()
    A.Minimap:Create()
    A.Settings:Create() -- Plain, unprotected window can subsequently open in combat.
    A.Settings:RegisterCategory()
    A.Mail:InstallHooks()
    A.Operations:CreateButtons()
    if A.readOnly then A.Print("Saved data belongs to a newer version. BagMarks is inactive and has preserved it.")
    elseif not A.API.available then A.Print("Required modern inventory APIs are missing. Item marking and helpers are inactive.") end
    queueRefresh()
end

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then initialize()
        elseif A.ready then
            A.Bags:InstallHooks()
            A.Mail:InstallHooks()
            A.Operations:CreateButtons()
            A.Settings:RegisterCategory()
            queueRefresh()
        end
        return
    end
    if not A.ready then return end
    if event == "PLAYER_REGEN_DISABLED" then
        A.mode = false
        A.Bindings:StopCapture()
        A.Operations:Cancel()
        A.Minimap:StopDrag()
        A.Refresh()
    elseif event == "PLAYER_REGEN_ENABLED" then
        A.Operations:CreateButtons()
        A.Mail:QueueFill()
        queueRefresh()
    elseif event == "MERCHANT_SHOW" then
        A.merchantOpen = true
        A.Store:RefreshInventory()
        A.Operations:CreateButtons()
        queueRefresh()
    elseif event == "MERCHANT_CLOSED" then
        A.merchantOpen = false
        A.Operations:Cancel()
        A.Refresh()
    elseif event == "MAIL_SHOW" then
        A.mailOpen = true
        A.Mail:InstallHooks()
        A.Mail:NewDraft()
        A.Operations:CreateButtons()
        queueRefresh()
    elseif event == "MAIL_CLOSED" then
        A.mailOpen = false
        A.Mail:Close()
        A.Operations:Cancel()
        A.Refresh()
    elseif event == "MAIL_SEND_SUCCESS" then
        A.Operations:Cancel()
        A.Mail:NewDraft()
    elseif event == "BANKFRAME_OPENED" then
        A.bankOpen = true
        queueRefresh()
    elseif event == "BANKFRAME_CLOSED" then
        A.bankOpen = false
        queueRefresh()
    elseif event == "MODIFIER_STATE_CHANGED" or event == "CURSOR_CHANGED" then
        A.Bags:Refresh()
        A.Operations:RefreshButtons()
    elseif event == "UPDATE_BINDINGS" then A.Settings:Refresh()
    elseif event == "UI_ERROR_MESSAGE" then
        if A.Operations.job then A.Operations:Cancel("The client reported an error. Remaining markings were kept.") end
    else queueRefresh() end
end)

for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "BAG_UPDATE_DELAYED", "BAG_CONTAINER_UPDATE", "BAG_OPEN", "BAG_CLOSED", "ITEM_LOCK_CHANGED",
    "PLAYERBANKSLOTS_CHANGED", "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
    "MERCHANT_SHOW", "MERCHANT_CLOSED", "MERCHANT_UPDATE", "MAIL_SHOW", "MAIL_CLOSED", "MAIL_SEND_INFO_UPDATE", "MAIL_SEND_SUCCESS",
    "MODIFIER_STATE_CHANGED", "CURSOR_CHANGED", "UPDATE_BINDINGS", "UI_ERROR_MESSAGE",
}) do
    -- Event names can differ between client revisions; capability failure is nonfatal.
    pcall(frame.RegisterEvent, frame, event)
end

-- Lightweight visible-UI discovery handles pooled buttons, tab switches, and late
-- load-on-demand frames. No inventory polling while all supported panels are closed.
local elapsed = 0
local lastRisk
frame:SetScript("OnUpdate", function(_, delta)
    if not A.ready or not A.CanAct() then return end
    elapsed = elapsed + delta
    if elapsed < .2 then return end
    elapsed = 0
    A.Bags:Discover()
    local risk = A.Bags:RiskyContext() and true or false
    if risk ~= lastRisk then A.Bags:Refresh(); lastRisk = risk end
    A.Operations:RefreshButtons()
end)
