-- Lifecycle and event routing. Inventory refreshes are delayed and combined;
-- protection checks that must react before the next click run synchronously.
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
    -- One action may emit several bag events. Scan once on the next frame to
    -- let related slot updates settle instead of rescanning for each event.
    if A.pendingRefresh then return end
    A.pendingRefresh = true
    C_Timer.After(0, updateInventory)
end

local function closeMail()
    local wasOpen = A.mailOpen
    A.mailOpen = false
    A.Mail:Close()
    if wasOpen then
        A.Operations:Cancel()
        A.Refresh() -- Release our reusable-item holds only after every risk ends.
    end
end

local function reconcileMail()
    -- The MAIL_SHOW flag can outlive the actual mailbox interaction.
    -- Only an explicit false clears the flag; a hidden custom UI or unavailable
    -- API cannot weaken protection while the mailbox is still active.
    if A.mailOpen and A.API:MailInteractionActive() == false then closeMail() end
end

function A.Slash(message)
    local command = (message or ""):match("^%s*(%S*)"):lower()
    if command == "" then A.Settings:Toggle()
    elseif command == "mode" then A.ToggleMode()
    elseif command == "minimap" then A.SetOption("minimap", not A.db.minimap)
    elseif command == "theme" then A.CycleTheme()
    elseif command == "debug" then A.Diagnostics:Open(message:match("^%s*%S+%s*(.-)%s*$"))
    elseif command == "reset" then
        local shortcut = A.Interaction.modifierLabels[A.defaults.modifier] .. " + " .. A.Interaction.buttonLabels[A.defaults.mouseButton]
        A.UI:Confirm("Reset BagMarks settings", "Restore default preferences?\n\nItem marks and Blizzard keybindings will be kept.\n\nDefault theme: " .. A.defaults.theme .. "\nDefault shortcut: " .. shortcut, "Reset settings", function() A.Store:ResetSettings() end)
    else
        A.Print("/bm or /bagmarks: Settings; /bm mode: Marking mode; /bm minimap: Minimap button; /bm theme: Cycle themes; /bm reset: Reset preferences; /bm debug or /bmcheck: Copyable diagnostics; /bm help: This reference.")
    end
end

local function initialize()
    -- SavedVariables are available at our ADDON_LOADED event. Establish API
    -- capabilities and sanitized state before any UI callback can use them.
    A.API:Initialize()
    A.Store:Initialize()
    A.ready = true
    SLASH_BAGMARKS1, SLASH_BAGMARKS2 = "/bagmarks", "/bm"
    SlashCmdList.BAGMARKS = A.Slash
    SLASH_BAGMARKSCHECK1 = "/bmcheck"
    SlashCmdList.BAGMARKSCHECK = function(message) A.Diagnostics:Open(message) end
    A.Bags:InstallHooks()
    A.Minimap:Create()
    A.Settings:Create() -- Plain, unprotected window can subsequently open in combat.
    A.Diagnostics:Create()
    A.Hover:Create()
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
            -- Blizzard panels and bag addons may load later. These installers
            -- remember their hooks/buttons, so retrying does not duplicate them.
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
        -- The fifth event argument is the optional GUID being deleted. Return
        -- the cursor now rather than waiting for a deferred inventory refresh.
        A.Protection:ReturnCursor(arg5, true)
        A.Protection:SyncHolds()
    elseif event == "PLAYER_LOGOUT" then
        A.Operations:Cancel()
        A.Protection:Stop()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Deliberately exit mode instead of resuming it after combat, when a
        -- player may expect their first ordinary click to use an item again.
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
        -- Start automatic selling once per opening, not on every merchant event.
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
        closeMail()
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local mailType = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.MailInfo
        if A.Safe(arg1) and type(arg1) == "number" and A.Safe(mailType) and type(mailType) == "number"
            and arg1 == mailType and A.mailOpen then
            reconcileMail()
            -- Hide notifications can precede the client's interaction update.
            -- Re-read next frame; a mailbox reopened meanwhile stays protected.
            if A.mailOpen then C_Timer.After(0, reconcileMail) end
        end
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
    elseif event == "CURSOR_CHANGED" then
        A.Protection:QueueCursorCheck()
    elseif event == "MODIFIER_STATE_CHANGED" or event == "CURRENT_SPELL_CAST_CHANGED" then
        if event ~= "MODIFIER_STATE_CHANGED" then A.Protection:SyncHolds() end
        A.Bags:Refresh()
        A.Operations:RefreshButtons()
        A.Hover:Refresh()
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
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
}) do
    -- Event names can differ between client revisions; capability failure is nonfatal.
    pcall(frame.RegisterEvent, frame, event)
end

-- Lightweight visible-UI discovery handles pooled buttons, tab switches, and late
-- load-on-demand frames. No inventory polling while all supported panels are closed.
local elapsed = 0
local lastRisk
frame:SetScript("OnUpdate", function(_, delta)
    if not A.ready then return end
    elapsed = elapsed + delta
    if elapsed < .2 then return end
    elapsed = 0
    -- This is one read-only query only while mail is considered open, including
    -- combat. Marking and inventory discovery still obey the usual combat gate.
    reconcileMail()
    if not A.CanAct() then return end
    A.Bags:Discover()
    -- Some target/context changes have no useful bag event. Resync holds only
    -- when this risk classification changes, not on every discovery tick.
    local risk = A.Bags:RiskyContext() and true or false
    if risk ~= lastRisk then A.Protection:SyncHolds(); A.Bags:Refresh(); lastRisk = risk end
    A.Operations:RefreshButtons()
end)
