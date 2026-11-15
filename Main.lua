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

frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4, arg5)
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
    if event == "DELETE_ITEM_CONFIRM" then
        A.Protection:ReturnCursor(arg5, true)
        A.Protection:SyncHolds()
    elseif event == "PLAYER_LOGOUT" then
        A.Operations:Cancel()
        A.Protection:Stop()
    elseif event == "PLAYER_REGEN_DISABLED" then
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
        local opening = not A.merchantOpen
        A.merchantOpen = true
        A.Protection:SyncHolds() -- Protect reusable items before deferred UI/sale work.
        if opening then A.Protection:MerchantOpened() end
        A.Store:RefreshInventory()
        A.Operations:CreateButtons()
        queueRefresh()
        if opening then A.Operations:AutoSellJunk() end
    elseif event == "MERCHANT_CLOSED" then
        A.merchantOpen = false
        A.Protection:MerchantClosed()
        A.Operations:Cancel()
        A.Refresh()
    elseif event == "MERCHANT_UPDATE" then
        A.Protection:CheckBuyback()
        queueRefresh()
    elseif event == "TRADE_SHOW" then
        A.tradeOpen = true
        A.Protection:Refresh()
        A.Bags:Refresh()
    elseif event == "TRADE_CLOSED" then
        A.tradeOpen = false
        A.Protection:SyncHolds()
        A.Bags:Refresh()
    elseif event == "TRADE_PLAYER_ITEM_CHANGED" or event == "TRADE_ACCEPT_UPDATE" or event == "TRADE_UPDATE" then
        A.Protection:CheckTrade()
    elseif event == "MAIL_SHOW" then
        A.mailOpen = true
        A.Protection:Refresh()
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
    elseif event == "MAIL_SEND_INFO_UPDATE" then
        A.Protection:CheckMail()
        queueRefresh()
    elseif event == "BANKFRAME_OPENED" then
        A.bankOpen = true
        A.Protection:SyncHolds()
        queueRefresh()
    elseif event == "BANKFRAME_CLOSED" then
        A.bankOpen = false
        A.Protection:SyncHolds()
        queueRefresh()
    elseif event == "AUCTION_HOUSE_SHOW" or event == "AUCTION_HOUSE_CLOSED" then
        A.auctionOpen = event == "AUCTION_HOUSE_SHOW"
        A.Protection:SyncHolds()
        queueRefresh()
    elseif event == "MODIFIER_STATE_CHANGED" or event == "CURSOR_CHANGED" or event == "CURRENT_SPELL_CAST_CHANGED" then
        if event == "CURSOR_CHANGED" then A.Protection:ReturnCursor() end
        if event ~= "MODIFIER_STATE_CHANGED" then A.Protection:SyncHolds() end
        A.Bags:Refresh()
        A.Operations:RefreshButtons()
    elseif event == "UPDATE_BINDINGS" then A.Settings:Refresh()
    elseif event == "UI_ERROR_MESSAGE" then
        if A.Operations.job then A.Operations:Cancel("The client reported an error. Remaining markings were kept.") end
    else
        if event == "ITEM_LOCK_CHANGED" or event == "BAG_UPDATE_DELAYED" then A.Protection:SyncHolds() end
        if event == "BAG_UPDATE_DELAYED" then A.Protection:CheckBuyback() end
        queueRefresh()
    end
end)

for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "BAG_UPDATE_DELAYED", "BAG_CONTAINER_UPDATE", "BAG_OPEN", "BAG_CLOSED", "ITEM_LOCK_CHANGED",
    "PLAYERBANKSLOTS_CHANGED", "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
    "MERCHANT_SHOW", "MERCHANT_CLOSED", "MERCHANT_UPDATE", "MAIL_SHOW", "MAIL_CLOSED", "MAIL_SEND_INFO_UPDATE", "MAIL_SEND_SUCCESS",
    "MODIFIER_STATE_CHANGED", "CURSOR_CHANGED", "UPDATE_BINDINGS", "UI_ERROR_MESSAGE",
    "DELETE_ITEM_CONFIRM", "TRADE_SHOW", "TRADE_CLOSED", "TRADE_PLAYER_ITEM_CHANGED", "TRADE_ACCEPT_UPDATE", "TRADE_UPDATE",
    "CURRENT_SPELL_CAST_CHANGED", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT",
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
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
    if risk ~= lastRisk then A.Protection:SyncHolds(); A.Bags:Refresh(); lastRisk = risk end
    A.Operations:RefreshButtons()
end)
