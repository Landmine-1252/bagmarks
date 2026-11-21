-- Reports must observe failures without releasing holds, changing marks,
-- sending items, or exposing recipient names and raw per-item GUIDs.
return function(M, A, test, eq, mark)
    local function contains(report, text) assert(report:find(text, 1, true), text .. " missing from report") end
    local function sleeping(options)
        options = options or {}
        options.itemID, options.spellID = 211527, 429961
        return mark("Item-PrivateSleepingBag", 0, 1, "locked", options)
    end

    test("diagnostics identify a stale mailbox flag without repairing or changing it", function()
        local item = sleeping()
        A.mailOpen = true; M.mailActive = false; A.Protection:SyncHolds()
        local locks, unlocks, clears = M.lockCalls, #M.unlockCalls, M.clearCalls
        local report = A.Diagnostics:Report(211527)
        contains(report, "BagMarks " .. A.version .. " diagnostics")
        contains(report, "Stale mailbox flag is blocking reusable use.")
        contains(report, "LiveMailbox=false")
        contains(report, "reusable: slot=true, lookup=true; held: native=true, owned=true; busy=true")
        eq(A.mailOpen, true); eq(item.held, true); eq(A.Store:Get(item.guid), "locked")
        eq(M.lockCalls, locks); eq(#M.unlockCalls, unlocks); eq(M.clearCalls, clears)
        eq(#M.used, 0); eq(#M.sold, 0); eq(#M.attachments, 0)
    end)

    test("diagnostic commands open a copyable report and preserve typing behavior", function()
        local item = sleeping()
        local button = M.button(0, 1); A.Bags:Discover(); M.mouseFoci = { button }
        eq(SLASH_BAGMARKSCHECK1, "/bmcheck")
        SlashCmdList.BAGMARKSCHECK("211527")
        assert(A.Diagnostics.frame:IsShown()); eq(A.Diagnostics.itemID, 211527)
        contains(A.Diagnostics.edit:GetText(), "Item 211527;")
        A.Diagnostics.selectAll:Fire("OnClick")
        assert(A.Diagnostics.edit:HasFocus()); assert(A.Diagnostics.edit.highlighted)
        BagMarks_CycleHoveredItem(); eq(A.Store:Get(item.guid), "locked")
        A.Diagnostics.edit:Fire("OnEscapePressed")
        eq(A.Diagnostics.frame:IsShown(), false); eq(M.keyboardFocus, nil)
        A.Slash("debug")
        assert(A.Diagnostics.frame:IsShown()); eq(A.Diagnostics.itemID, nil)
        A.Slash("help"); contains(M.messages[#M.messages], "/bmcheck")
    end)

    test("diagnostic filters describe identical copies independently and omit private fields", function()
        sleeping()
        M.item("Item-PrivateNormalCopy", 0, 2, { itemID = 211527, spellID = 429961 })
        mark("Item-PrivateOther", 0, 3, "mail", { itemID = 6948, spellID = 8690 })
        A.char.recipient = "PrivateRecipient-PrivateRealm"
        local report = A.Diagnostics:Report(211527)
        contains(report, "Readable items matching 211527: 2")
        contains(report, "slot=1; mark=Locked"); contains(report, "slot=2; mark=Normal")
        assert(not report:find("Item 6948;", 1, true)); assert(not report:find("Private", 1, true))
        report = A.Diagnostics:Report()
        contains(report, "Readable items with marks: 2")
        assert(not report:find("slot=2; mark=Normal", 1, true))
    end)

    test("opening diagnostics raises the entire window above settings and its editor", function()
        local s, d = A.Settings, A.Diagnostics
        s:OpenItemRoutes(211527)
        A.UI:Confirm("Pending confirmation", "Keep this open", "Accept", function() error("unexpected acceptance") end)
        eq(A.UI.confirm:GetFrameStrata(), "FULLSCREEN_DIALOG"); eq(A.UI.confirm.raised, true)
        A.Slash("debug")
        eq(s.ruleFrame:IsVisible(), true); eq(s.ruleFrame:GetFrameStrata(), "DIALOG")
        eq(d.frame:GetFrameStrata(), "TOOLTIP"); eq(d.frame.toplevel, true); eq(d.frame.raised, true)
        assert(d.frame.backdrop.bgFile and d.frame.mouse)
        for _, child in ipairs({ d.scroll, d.edit, d.selectAll, d.refresh }) do
            eq(child:GetFrameStrata(), d.frame:GetFrameStrata())
            assert(child:GetFrameLevel() > d.frame:GetFrameLevel())
        end
        d.frame.raised = false
        SlashCmdList.BAGMARKSCHECK("")
        eq(d.frame.raised, true)
        d.selectAll:Fire("OnClick"); d.edit:Fire("OnEscapePressed")
        eq(d.frame:IsShown(), false); eq(s.ruleFrame:IsVisible(), true)
        eq(A.UI.confirm:IsVisible(), true); A.UI:CloseConfirmation()
        s:SelectTab("Marking"); s.bindButton:Fire("OnClick")
        d:Open(); eq(A.Bindings.capture:IsShown(), false)
    end)

    test("diagnostics remain available in combat without scanning or changing holds", function()
        local item = sleeping({ held = true })
        M.combat = true
        local reads, frames, unlocks = M.reads, #M.frames, #M.unlockCalls
        A.Slash("debug 211527")
        contains(A.Diagnostics.edit:GetText(), "Inventory details paused during combat")
        eq(M.reads, reads); eq(#M.frames, frames); eq(#M.unlockCalls, unlocks)
        eq(item.held, true); eq(A.Store:Get(item.guid), "locked")
    end)

    test("diagnostic refresh updates the snapshot and rejects malformed filters", function()
        sleeping()
        A.Slash("debug 211527")
        local original = A.Diagnostics.edit:GetText()
        A.mailOpen = true; M.mailActive = false
        eq(A.Diagnostics.edit:GetText(), original, "report is an explicit snapshot")
        A.Diagnostics.refresh:Fire("OnClick")
        contains(A.Diagnostics.edit:GetText(), "Mailbox flag is stale")
        eq(A.mailOpen, true)
        local reads = M.reads
        for _, input in ipairs({ "0", "-1", "1.5", "1e3", "211527 extra", "999999999999999999999999999999" }) do
            eq(A.Diagnostics:Open(input), false)
        end
        eq(M.reads, reads); eq(A.Diagnostics.itemID, 211527)
    end)

    test("diagnostics handle unavailable client data and do not release foreign holds", function()
        local item = sleeping({ held = true })
        local manager = C_PlayerInteractionManager
        C_PlayerInteractionManager = nil
        local report = A.Diagnostics:Report()
        contains(report, "LiveMailbox=unknown")
        contains(report, "Client reports the item busy; BagMarks has no owned hold.")
        M.secretLocation = true
        report = A.Diagnostics:Report(); contains(report, "The GUID lookup cannot confirm this item.")
        eq(item.held, true); eq(#M.unlockCalls, 0)
        C_PlayerInteractionManager = manager
        A.API.available = false
        report = A.Diagnostics:Report(); contains(report, "required item APIs are missing")
        A.API:Initialize()
    end)

    test("large diagnostic reports disclose their limit and allow a focused item check", function()
        for i = 1, 45 do
            local bag, slot = math.floor((i - 1) / 32), (i - 1) % 32 + 1
            mark("Item-Report" .. i, bag, slot, "junk", { itemID = 1000 + i })
        end
        local report = A.Diagnostics:Report()
        contains(report, "Readable items with marks: 45"); contains(report, "Showing 40 items.")
        local _, count = report:gsub("\nItem %d+;", "")
        eq(count, 40)
        report = A.Diagnostics:Report(1045)
        contains(report, "Readable items matching 1045: 1"); contains(report, "Item 1045;")
    end)
end
