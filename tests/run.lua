assert(_VERSION == "Lua 5.1", "Run the mocked suite with Lua 5.1")
local M = dofile("tests/mock.lua")
local A = {}
for line in io.lines("BagMarks.toc") do
    if line:match("%.lua$") then assert(loadfile(line))("BagMarks", A) end
end
A.eventFrame:Fire("OnEvent", "ADDON_LOADED", "BagMarks")
M.tick(0)
local passed = 0
local function eq(actual, expected, message)
    assert(actual == expected, (message or "mismatch") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function test(name, fn)
    M.reset(A)
    local ok, err = pcall(fn)
    if not ok then io.stderr:write("FAIL: " .. name .. "\n" .. tostring(err) .. "\n"); os.exit(1) end
    passed = passed + 1
    print("PASS: " .. name)
end
local function mark(guid, bag, slot, state, options)
    local item = M.item(guid, bag, slot, options)
    assert(A.Store:Set(A.API:Read(bag, slot), state))
    return item
end
local function merchant()
    MerchantFrame:Show()
    MerchantFrame.selectedTab = 1
    A.merchantOpen = true
end
local function mail()
    SendMailFrame:Show()
    A.mailOpen = true
end
local function confirm()
    assert(A.UI.confirm and A.UI.confirm:IsShown(), "expected confirmation")
    A.UI.confirm.accept:Fire("OnClick")
end
local function contains(list, value)
    for _, entry in ipairs(list) do if entry == value then return true end end
    return false
end

test("clean login, defaults and Blizzard settings registration", function()
    eq(A.db.theme, "Colorful"); eq(A.db.modifier, "ALT"); eq(A.Bindings:Text(), "Unbound")
    eq(A.mode, false); eq(M.category.name, "BagMarks")
    eq(SLASH_BAGMARKS1, "/bagmarks"); eq(SLASH_BAGMARKS2, "/bm")
end)

test("all four mutually exclusive states", function()
    local item = M.item("Item-A", 0, 1)
    for _, state in ipairs({ "locked", "junk", "mail" }) do
        assert(A.Store:Set(A.API:Read(0, 1), state)); eq(A.Store:Get(item.guid), state)
    end
    A.Store:Set(A.API:Read(0, 1), nil); eq(A.Store:Get(item.guid), nil)
end)

test("identical copies have independent marks", function()
    mark("Item-A", 0, 1, "locked")
    M.item("Item-B", 0, 2)
    eq(A.Store:Get("Item-B"), nil)
    mark("Item-C", 0, 3, "junk")
    eq(A.Store:Get("Item-A"), "locked"); eq(A.Store:Get("Item-C"), "junk")
end)

test("missing and secret identities never fall back to item IDs", function()
    M.item("Item-A", 0, 1, { secretID = M.secret }); eq(A.API:Read(0, 1), nil)
    local item = M.item("Item-B", 0, 2); item.guid = nil; eq(A.API:Read(0, 2), nil)
    item.guid = M.secret; eq(A.API:Read(0, 2), nil)
end)

test("marks follow GUID across bags, bank, and settings reload", function()
    local item = mark("Item-A", 0, 1, "locked")
    M.bags[0][1] = nil; M.bags[1] = { [4] = item }
    A.Store:RefreshInventory(); eq(A.Store:Get(A.API:Read(1, 4).guid), "locked")
    M.bags[1][4] = nil; M.bags[6] = { [2] = item }; A.bankOpen = true
    A.Store:RefreshInventory(); A.db.theme = "Classic"; A.db.angle = 115
    A.Store:Initialize()
    eq(A.Store:Get(A.API:Read(6, 2).guid), "locked"); eq(A.db.theme, "Classic"); eq(A.db.angle, 115)
    A.bankOpen = false; A.Store:RefreshInventory(); eq(A.char.observed["Item-A"].bag, 6)
end)

test("per-character data stays separate from account preferences", function()
    mark("Item-A", 0, 1, "locked"); A.db.theme = "Minimal"
    local first = BagMarksCharDB
    BagMarksCharDB = nil; A.Store:Initialize()
    eq(A.Store:Get("Item-A"), nil); eq(A.db.theme, "Minimal")
    BagMarksCharDB = first; A.Store:Initialize(); eq(A.Store:Get("Item-A"), "locked")
end)

test("split child is not silently locked and merged destination requires review", function()
    local source = mark("Item-A", 0, 1, "locked", { count = 10 })
    source.count = 6
    M.item("Item-B", 0, 2, { count = 4 })
    A.Store:RefreshInventory()
    eq(A.Store:Get("Item-A"), "locked"); eq(A.Store:Get("Item-B"), nil)
    eq(A.char.review["Item-B"], true)
    A.Store:Set(A.API:Read(0, 2), "junk")
    source.count = 4; M.bags[0][2].count = 6
    A.Store:RefreshInventory()
    eq(A.char.review["Item-B"], true); eq(A.Store:Eligible(A.API:Read(0, 2), "junk"), false)
    A.Store:Set(A.API:Read(0, 2), "junk"); eq(A.char.review["Item-B"], nil)
end)

test("increased marked stack is quarantined even when source was not observable", function()
    local item = mark("Item-J", 0, 1, "junk", { count = 5 })
    item.count = 8; A.Store:RefreshInventory()
    eq(A.char.review["Item-J"], true)
end)

test("corrupt settings sanitize and schema zero migrates", function()
    BagMarksDB = { theme = "wrong", enabled = "yes", angle = 0/0, recipient = "  Name|\n  " }
    BagMarksCharDB = { marks = { [123] = "locked", ["Item-A"] = "locked", ["Item-X"] = { state = "bad" } }, observed = "broken" }
    A.Store:Initialize()
    eq(A.db.theme, "Colorful"); eq(A.db.enabled, true); eq(A.db.angle, 220); eq(A.db.recipient, "Name")
    eq(A.Store:Get("Item-A"), "locked"); eq(A.Store:Get("Item-X"), nil); eq(A.char.marks[123], nil)
end)

test("unknown future schema is preserved and disables actions", function()
    BagMarksDB = { schema = 99, future = "keep" }; local original = BagMarksDB
    A.Store:Initialize()
    eq(A.readOnly, true); eq(BagMarksDB, original); eq(BagMarksDB.future, "keep"); eq(A.CanAct(), false)
end)

test("missing modern APIs disable item features without throwing", function()
    local original = C_Item.GetItemGUID
    C_Item.GetItemGUID = nil; A.API:Initialize(); eq(A.API.available, false)
    eq(A.API:Read(0, 1), nil)
    C_Item.GetItemGUID = original; A.API:Initialize()
end)

test("theme changes repaint open bags and disabling icons removes overlays", function()
    mark("Item-A", 0, 1, "locked")
    local button = M.button(0, 1)
    A.Bags:Discover()
    local icon = A.Bags.overlays[button].icon
    eq(icon.color[2], .82)
    A.SetOption("theme", "Minimal"); eq(icon.color[2], .95)
    A.SetOption("theme", "Classic"); eq(icon.color[2], .78)
    A.SetOption("overlays", false); eq(icon:IsShown(), false)
    A.SetOption("overlays", true); eq(icon:IsShown(), true)
end)

test("native bank pool and reused bag buttons read their current coordinates", function()
    mark("Item-A", 6, 2, "mail"); A.bankOpen = true; BankFrame:Show()
    local bankButton = M.button(6, 2, true)
    A.Bags:Discover(); assert(A.Bags.overlays[bankButton].icon:IsShown())
    local bagButton = M.button(0, 1)
    M.item("Item-B", 0, 1); mark("Item-C", 0, 2, "junk")
    A.Bags:Discover(); eq(A.Bags.overlays[bagButton].icon:IsShown(), false)
    bagButton.slot = 2; A.Bags:Discover(); eq(A.Bags.overlays[bagButton].icon:IsShown(), true)
end)

test("modifier and mode capture only intended clicks, with immediate restoration", function()
    M.item("Item-A", 0, 1)
    local button = M.button(0, 1); A.Bags:Discover()
    local overlay = A.Bags.overlays[button]
    eq(overlay:IsShown(), false)
    M.alt = true; A.Bags:Refresh()
    eq(contains(overlay.passthrough, "LeftButton"), true); eq(contains(overlay.passthrough, "RightButton"), false)
    M.shift = true; A.Bags:Refresh(); eq(contains(overlay.passthrough, "RightButton"), true)
    M.alt, M.shift = false, false; A.ToggleMode(); eq(contains(overlay.passthrough, "RightButton"), false)
    A.ToggleMode(); eq(contains(overlay.passthrough, "RightButton"), true)
    A.SetOption("modifier", "CTRL"); M.ctrl = true; A.Bags:Refresh()
    eq(contains(overlay.passthrough, "RightButton"), false)
end)

test("context selection follows GUID instead of a stale menu slot", function()
    local item = M.item("Item-A", 0, 1)
    local button = M.button(0, 1); A.Bags:Discover(); M.alt = true
    local overlay = A.Bags.overlays[button]
    A.Bags:Click(overlay, "RightButton")
    eq(M.menu.owner, button, "menu must survive release of the modifier")
    eq(M.menu.choices[4].selected(), true)
    M.bags[0][2] = item; M.item("Item-B", 0, 1)
    M.menu.choices[1].callback()
    eq(A.Store:Get("Item-A"), "locked"); eq(A.Store:Get("Item-B"), nil)
end)

test("tooltips show only the actual instance and obey the toggle", function()
    mark("Item-A", 0, 1, "locked"); M.item("Item-B", 0, 2)
    local button = M.button(0, 1); A.Bags:Discover(); GameTooltip:SetOwner(button)
    GameTooltip:SetBagItem(0, 1); eq(GameTooltip.lines[1], "BagMarks: Locked")
    button.slot = 2; GameTooltip:SetBagItem(0, 2); eq(#GameTooltip.lines, 0)
    button.slot = 1; A.SetOption("tooltips", false); GameTooltip:SetBagItem(0, 1); eq(#GameTooltip.lines, 0)
end)

test("locked click guards cover merchant, mail and spell targets; normal drag remains native", function()
    mark("Item-A", 0, 1, "locked")
    local button = M.button(0, 1); A.Bags:Discover(); local overlay = A.Bags.overlays[button]
    eq(contains(overlay.passthrough, "LeftButton"), true)
    for _, context in ipairs({ "merchantOpen", "mailOpen" }) do
        A[context] = true; A.Bags:Refresh(); eq(contains(overlay.passthrough, "LeftButton"), false)
        A[context] = false
    end
    M.targeting = true; A.Bags:Refresh(); eq(contains(overlay.passthrough, "RightButton"), false)
    M.targeting = false; A.Bags:Refresh(); eq(contains(overlay.passthrough, "LeftButton"), true)
end)

test("sale requires confirmation and includes only explicit eligible Junk", function()
    merchant()
    mark("Item-L", 0, 1, "locked"); mark("Item-M", 0, 2, "mail"); mark("Item-J", 0, 3, "junk")
    M.item("Item-N", 0, 4)
    A.Operations:PreviewJunk(); eq(#M.sold, 0)
    confirm(); M.tick(1); eq(#M.sold, 1); eq(M.sold[1], "Item-J")
    assert(M.bags[0][1] and M.bags[0][2] and M.bags[0][4])
end)

test("native Sell All Junk click guard covers locked poor-quality items", function()
    merchant(); mark("Item-L", 0, 1, "locked", { quality = 0 })
    A.Operations:RefreshButtons(); eq(A.Operations.nativeJunkGuard:IsShown(), true)
    A.Store:Set(A.API:Read(0, 1), nil); eq(A.Operations.nativeJunkGuard:IsShown(), false)
end)

test("shift and control left clicks retain native linking and preview behavior", function()
    merchant(); mark("Item-L", 0, 1, "locked")
    local button = M.button(0, 1); A.Bags:Discover()
    M.shift = true; A.Bags:Refresh(); eq(contains(A.Bags.overlays[button].passthrough, "LeftButton"), true)
    M.shift = false; M.ctrl = true; A.Bags:Refresh(); eq(contains(A.Bags.overlays[button].passthrough, "LeftButton"), true)
    M.targeting = true; A.Bags:Refresh(); eq(contains(A.Bags.overlays[button].passthrough, "LeftButton"), false)
end)

test("stale sale preview cannot sell an item newly marked Locked", function()
    merchant(); mark("Item-J", 0, 1, "junk"); A.Operations:PreviewJunk()
    A.Store:Set(A.API:Read(0, 1), "locked"); confirm(); M.tick(1)
    eq(#M.sold, 0); eq(A.Operations.job, nil)
end)

test("sale preview follows moved GUID and never sells its replacement", function()
    merchant(); local item = mark("Item-J", 0, 1, "junk"); A.Operations:PreviewJunk()
    M.bags[0][2] = item; M.item("Item-L", 0, 1)
    A.Store:Set(A.API:Read(0, 1), "locked")
    confirm(); M.tick(1); eq(M.sold[1], "Item-J"); eq(M.bags[0][1].guid, "Item-L")
end)

test("stale stack count and price invalidate sales", function()
    merchant(); local item = mark("Item-J", 0, 1, "junk", { count = 4 })
    A.Operations:PreviewJunk(); item.count = 5; confirm(); eq(#M.sold, 0)
    A.Store:Set(A.API:Read(0, 1), "junk"); A.Operations:PreviewJunk()
    item.price = 200; confirm(); eq(#M.sold, 0)
end)

test("junk queue is capped at twelve stacks per confirmation", function()
    merchant()
    for i = 1, 15 do mark("Item-J" .. i, 0, i, "junk") end
    A.Operations:PreviewJunk(); confirm(); M.tick(3)
    eq(#M.sold, 12); assert(M.bags[0][13])
end)

test("junk excludes unsellable, quest, refundable, busy and uncached items", function()
    merchant()
    mark("Item-N", 0, 1, "junk", { itemID = 101, noValue = true })
    mark("Item-Q", 0, 2, "junk", { itemID = 102, quest = true })
    mark("Item-R", 0, 3, "junk", { itemID = 103, refundable = true })
    mark("Item-B", 0, 4, "junk", { itemID = 104, busy = true })
    mark("Item-U", 0, 5, "junk", { itemID = 105, uncached = true })
    A.Operations:PreviewJunk(); eq(A.UI.confirm:IsShown(), false); eq(#M.sold, 0)
end)

test("rejected sale stops on timeout without retrying", function()
    merchant(); mark("Item-J", 0, 1, "junk"); M.rejectSale = true
    A.Operations:PreviewJunk(); confirm(); M.tick(3)
    eq(A.Operations.job, nil); eq(A.Store:Get("Item-J"), "junk"); eq(#M.sold, 0)
end)

test("closing merchant invalidates an old preview", function()
    merchant(); mark("Item-J", 0, 1, "junk"); A.Operations:PreviewJunk()
    local callback = A.UI.confirm.callback
    A.eventFrame:Fire("OnEvent", "MERCHANT_CLOSED"); merchant(); callback(); M.tick(1)
    eq(#M.sold, 0)
end)

test("mail helper attaches only eligible Mail, keeps marks, and fills empty recipient", function()
    mail(); A.db.recipient = "Alt-Realm"
    mark("Item-L", 0, 1, "locked"); mark("Item-J", 0, 2, "junk")
    mark("Item-M", 0, 3, "mail"); mark("Item-B", 0, 4, "mail", { itemID = 102, bound = true })
    mark("Item-A", 0, 5, "mail", { itemID = 103, account = true })
    A.Operations:AttachMail(); M.tick(1)
    eq(M.attachments[1].guid, "Item-M"); eq(M.attachments[2], nil)
    eq(A.Store:Get("Item-M"), "mail"); eq(SendMailNameEditBox:GetText(), "Alt-Realm")
    M.bags[0][3] = M.attachments[1]; M.attachments[1] = nil
    A.Store:RefreshInventory(); eq(A.Store:Get("Item-M"), "mail")
end)

test("mail attachment limit preserves existing attachments and remaining marked items", function()
    mail(); SendMailNameEditBox:SetText("Chosen-Realm"); A.db.recipient = "Default"
    for i = 1, 11 do M.attachments[i] = { itemID = 99, count = 1 } end
    mark("Item-A", 0, 1, "mail"); mark("Item-B", 0, 2, "mail")
    A.Operations:AttachMail(); M.tick(1)
    eq(M.attachments[12].guid, "Item-A"); eq(M.bags[0][2].guid, "Item-B")
    eq(SendMailNameEditBox:GetText(), "Chosen-Realm")
end)

test("mail action rejection returns its cursor item and retains the mark", function()
    mail(); mark("Item-M", 0, 1, "mail"); M.rejectMail = true
    A.Operations:AttachMail(); M.tick(1)
    eq(M.cursor, nil); eq(M.bags[0][1].guid, "Item-M"); eq(A.Store:Get("Item-M"), "mail")
end)

test("mail rechecks each queued state and stops before a newly Locked item", function()
    mail(); mark("Item-A", 0, 1, "mail"); mark("Item-B", 0, 2, "mail")
    A.Operations:AttachMail(); A.Store:Set(A.API:Read(0, 2), "locked"); M.tick(1)
    eq(M.attachments[1].guid, "Item-A"); eq(M.attachments[2], nil); eq(M.bags[0][2].guid, "Item-B")
end)

test("helpers refuse a preexisting cursor and merchant buyback tab", function()
    merchant(); mark("Item-J", 0, 1, "junk"); MerchantFrame.selectedTab = 2
    A.Operations:PreviewJunk(); eq(A.UI.confirm:IsShown(), false)
    mail(); M.cursor = { item = {} }; A.Operations:AttachMail(); assert(M.cursor); eq(A.Operations.job, nil)
end)

test("key capture, modifiers, persistence, clear and restore", function()
    A.Bindings:StartCapture(); M.ctrl = true; M.shift = true
    A.Bindings.capture:Fire("OnKeyDown", "LCTRL"); eq(A.Bindings.capture:IsShown(), true)
    A.Bindings.capture:Fire("OnKeyDown", "B")
    eq(M.bindings["CTRL-SHIFT-B"], A.Bindings.action); eq(M.savedBindingSet, 1)
    eq(A.Bindings.capture:IsShown(), false)
    assert(A.Bindings:Apply({})); eq(A.Bindings:Text(), "Unbound")
    assert(A.Bindings:Restore()); eq(M.bindings["CTRL-SHIFT-B"], A.Bindings.action)
end)

test("existing keybindings and override bindings are never overwritten", function()
    assert(A.Bindings:Apply({ "F8" }))
    M.bindings.B = "OPENALLBAGS"
    eq(A.Bindings:Apply({ "B" }), false); eq(M.bindings.B, "OPENALLBAGS"); eq(M.bindings.F8, A.Bindings.action)
    M.overrides = { F9 = "SOME_ACTION" }
    eq(A.Bindings:Apply({ "F9" }), false); eq(M.bindings.F8, A.Bindings.action)
    M.overrides.B = A.Bindings.action
    eq(A.Bindings:Apply({ "B" }), false); eq(M.bindings.B, "OPENALLBAGS")
end)

test("restore refuses a conflicting shortcut or a different binding set", function()
    assert(A.Bindings:Apply({ "F8" })); assert(A.Bindings:Apply({ "F9" }))
    M.bindings.F8 = "SOME_ACTION"; eq(A.Bindings:Restore(), false); eq(M.bindings.F9, A.Bindings.action)
    M.bindingSet = 2; eq(A.Bindings:Restore(), false)
end)

test("failed SetBinding rolls back the previous shortcut", function()
    assert(A.Bindings:Apply({ "F8" })); M.failKey = "F9"
    eq(A.Bindings:Apply({ "F9" }), false); eq(M.bindings.F8, A.Bindings.action)
end)

test("combat stops operations and capture, while settings open and close safely", function()
    merchant(); mark("Item-A", 0, 1, "junk"); mark("Item-B", 0, 2, "junk")
    local button = M.button(0, 2); A.Bags:Discover()
    A.Bindings:StartCapture(); A.mode = true
    A.Operations:PreviewJunk(); confirm(); M.combat = true
    A.eventFrame:Fire("OnEvent", "PLAYER_REGEN_DISABLED"); M.tick(1)
    eq(#M.sold, 1); eq(A.Operations.job, nil); eq(A.mode, false)
    eq(A.Bindings.capture:IsShown(), false); eq(A.Bags.overlays[button]:IsShown(), false)
    A.Settings:Toggle(); eq(A.Settings.frame:IsShown(), true)
    A.Settings:Toggle(); eq(A.Settings.frame:IsShown(), false)
    eq(A.Bindings:Apply({ "F8" }), false)
    M.combat = false; A.eventFrame:Fire("OnEvent", "PLAYER_REGEN_ENABLED"); M.tick(0)
    assert(A.Bags.overlays[button]:IsShown())
end)

test("minimap drag persists radial angle and hide/show is immediate", function()
    local button = A.Minimap.button
    M.cursorX, M.cursorY = 100, 180
    button:Fire("OnDragStart"); A.Minimap.dragFrame:Fire("OnUpdate", .1); button:Fire("OnDragStop")
    eq(math.floor(A.db.angle + .5), 90); A.Store:Initialize(); eq(math.floor(A.db.angle + .5), 90)
    A.SetOption("minimap", false); eq(button:IsShown(), false)
    A.SetOption("minimap", true); eq(button:IsShown(), true)
end)

test("disabled addon and reset preserve marks and existing bindings", function()
    mark("Item-A", 0, 1, "locked"); A.db.theme = "Minimal"; A.Bindings:Apply({ "F8" })
    A.SetOption("enabled", false); eq(A.CanAct(), false)
    A.Slash("reset"); eq(A.db.theme, "Minimal"); confirm()
    eq(A.db.theme, "Colorful"); eq(A.Store:Get("Item-A"), "locked"); eq(M.bindings.F8, A.Bindings.action)
end)

test("idle visible-bag discovery avoids repeated GUID queries", function()
    mark("Item-A", 0, 1, "junk"); M.button(0, 1); A.Bags:Discover()
    local reads = M.reads
    for _ = 1, 10 do A.Bags:Discover() end
    eq(M.reads, reads)
end)

test("schema one migration preserves disabled settings and supplies new defaults", function()
    BagMarksDB = { schema = 1, enabled = false, minimap = false, tooltips = false, overlays = false,
        modifier = "SHIFT", recipient = "Bankalt-Realm", theme = "Minimal" }
    BagMarksCharDB = { schema = 1, marks = { ["Item-L"] = { state = "locked", itemID = 100 } } }
    A.Store:Initialize()
    eq(A.db.schema, 2); eq(A.char.schema, 2)
    eq(A.db.enabled, false); eq(A.db.minimap, false); eq(A.db.tooltips, false); eq(A.db.overlays, false)
    eq(A.db.mouseButton, "RightButton"); eq(A.db.markingAction, "menu"); eq(A.db.autoFillRecipient, true)
    eq(A.db.modifier, "SHIFT"); eq(A.db.recipient, "Bankalt-Realm"); eq(A.Store:Get("Item-L"), "locked")
end)

test("new options persist and invalid input preferences recover safely", function()
    A.db.modifier, A.db.mouseButton, A.db.markingAction, A.db.autoFillRecipient = "ALT-CTRL", "Button5", "cycle", false
    A.Store:Initialize()
    eq(A.db.modifier, "ALT-CTRL"); eq(A.db.mouseButton, "Button5"); eq(A.db.markingAction, "cycle")
    eq(A.db.autoFillRecipient, false)
    A.db.modifier, A.db.mouseButton, A.db.markingAction = "invalid", "invalid", "invalid"
    A.Store:Initialize()
    eq(A.db.modifier, "ALT"); eq(A.db.mouseButton, "RightButton"); eq(A.db.markingAction, "menu")
end)

test("each mouse button captures only its selected exact modifier chord", function()
    M.item("Item-A", 0, 1)
    local button = M.button(0, 1); A.Bags:Discover()
    local overlay = A.Bags.overlays[button]
    eq(overlay.clicks[1], "AnyUp")
    for _, modifier in ipairs(A.Interaction.modifiers) do
        if modifier[1] ~= "MODE" then
            A.SetOption("modifier", modifier[1])
            M.alt = modifier[1]:find("ALT", 1, true) ~= nil
            M.ctrl = modifier[1]:find("CTRL", 1, true) ~= nil
            M.shift = modifier[1]:find("SHIFT", 1, true) ~= nil
            for _, selected in ipairs(A.Interaction.buttons) do
                A.SetOption("mouseButton", selected[1])
                eq(A.Interaction:Active(), true)
                for _, other in ipairs(A.Interaction.buttons) do
                    eq(contains(overlay.passthrough, other[1]), other[1] ~= selected[1])
                end
                M.menu = nil
                overlay:Fire("OnClick", selected[1])
                assert(M.menu and M.menu.choices[4].selected(), "configured click must open the menu")
            end
        end
    end
    A.SetOption("modifier", "ALT-CTRL"); M.alt, M.ctrl, M.shift = true, true, true
    A.Bags:Refresh(); eq(A.Interaction:Active(), false)
    eq(contains(overlay.passthrough, "Button5"), true)
end)

test("Marking Mode only leaves shortcuts alone until enabled", function()
    M.item("Item-A", 0, 1); local button = M.button(0, 1)
    A.SetOption("modifier", "MODE"); A.SetOption("mouseButton", "MiddleButton")
    eq(A.Interaction:Active(), false)
    M.ctrl = true; eq(A.Interaction:Active(), false)
    M.ctrl = false; A.ToggleMode()
    eq(A.Interaction:Matches("MiddleButton"), true)
    eq(contains(A.Bags.overlays[button].passthrough, "RightButton"), true)
    A.ToggleMode(); eq(A.Interaction:Active(), false)
    eq(contains(A.Bags.overlays[button].passthrough, "MiddleButton"), true)
end)

test("cycling rotates the selected instance through all marks without opening a menu", function()
    M.item("Item-A", 0, 1); M.item("Item-B", 0, 2)
    local button = M.button(0, 1)
    A.SetOption("mouseButton", "Button4"); A.SetOption("markingAction", "cycle")
    M.alt = true; A.Bags:Refresh(); local overlay = A.Bags.overlays[button]
    M.menu = nil
    for _, state in ipairs({ "junk", "mail", "locked", false }) do
        overlay:Fire("OnClick", "Button4")
        eq(A.Store:Get("Item-A"), state or nil); eq(A.Store:Get("Item-B"), nil)
    end
    eq(M.menu, nil); eq(overlay.icon:IsShown(), false)
end)

test("cycling a changed stack opens a review menu without changing its state", function()
    local item = mark("Item-A", 0, 1, "locked", { count = 5 })
    item.count = 7; A.Store:RefreshInventory(); eq(A.char.review["Item-A"], true)
    local button = M.button(0, 1)
    A.SetOption("markingAction", "cycle"); M.alt = true; A.Bags:Refresh()
    A.Bags.overlays[button]:Fire("OnClick", "RightButton")
    eq(A.Store:Get("Item-A"), "locked"); eq(A.char.review["Item-A"], true)
    assert(M.menu); M.menu.choices[1].callback(); eq(A.char.review["Item-A"], nil)
end)

test("custom marking buttons do not remove the Locked item guards", function()
    merchant(); mark("Item-A", 0, 1, "locked")
    local button = M.button(0, 1)
    A.SetOption("mouseButton", "MiddleButton"); A.SetOption("markingAction", "cycle")
    M.alt = true; A.Bags:Refresh(); local overlay = A.Bags.overlays[button]
    eq(contains(overlay.passthrough, "RightButton"), false)
    eq(contains(overlay.passthrough, "LeftButton"), false)
    overlay:Fire("OnClick", "RightButton"); eq(A.Store:Get("Item-A"), "locked")
    overlay:Fire("OnClick", "MiddleButton"); eq(A.Store:Get("Item-A"), nil)
end)

test("marking does not consume the selected drop click when the cursor holds an item", function()
    M.item("Item-A", 0, 1); local button = M.button(0, 1)
    A.SetOption("mouseButton", "LeftButton"); A.SetOption("modifier", "NONE")
    M.cursor = { item = {} }; A.Bags:Refresh()
    eq(A.Interaction:Active(), false)
    eq(contains(A.Bags.overlays[button].passthrough, "LeftButton"), true)
end)

test("tabbed settings expose input choices and cancel hidden key capture", function()
    A.Settings:Toggle(); A.Settings:SelectTab("Marking")
    A.Settings.mouseButton:Fire("OnClick"); M.menu.choices[3].callback()
    eq(A.db.mouseButton, "MiddleButton")
    A.Settings.markingAction:Fire("OnClick"); M.menu.choices[2].callback()
    eq(A.db.markingAction, "cycle")
    A.Settings.modifier:Fire("OnClick"); M.menu.choices[4].callback()
    eq(A.db.modifier, "ALT-CTRL")
    assert(A.Settings.interactionHint:GetText():find("Cycle marks", 1, true))
    A.Bindings:StartCapture(); A.Settings:SelectTab("Appearance")
    eq(A.Bindings.capture:IsShown(), false)
    eq(A.Settings.panels.Marking:IsShown(), false); eq(A.Settings.panels.Appearance:IsShown(), true)
end)

test("recipient fills on opening Send Mail before attaching anything", function()
    A.db.recipient = "Bankalt-Realm"
    A.eventFrame:Fire("OnEvent", "MAIL_SHOW"); M.tick(0)
    eq(SendMailNameEditBox:GetText(), "")
    SendMailNameEditBox.focus = true; SendMailFrame:Show(); M.tick(0)
    eq(SendMailNameEditBox:GetText(), "Bankalt-Realm"); eq(SendMailNameEditBox.highlighted, true)
    eq(next(M.attachments), nil)
end)

test("automatic recipient fill preserves an existing name and replies", function()
    A.db.recipient = "Default-Realm"
    A.eventFrame:Fire("OnEvent", "MAIL_SHOW"); SendMailNameEditBox:SetText("Chosen-Realm")
    SendMailFrame:Show(); M.tick(0); eq(SendMailNameEditBox:GetText(), "Chosen-Realm")
    SendMailFrame:Hide(); SendMailNameEditBox:SetText(""); SendMailFrame.sendMode = "reply"
    SendMailFrame:Show(); M.tick(0); eq(SendMailNameEditBox:GetText(), "")
end)

test("recipient typing before deferred autofill and deliberate clearing are respected", function()
    A.db.recipient = "Default-Realm"
    A.eventFrame:Fire("OnEvent", "MAIL_SHOW"); SendMailFrame:Show()
    SendMailNameEditBox:SetText("Manual"); SendMailNameEditBox:Fire("OnTextChanged", true)
    M.tick(0); eq(SendMailNameEditBox:GetText(), "Manual")
    SendMailNameEditBox:SetText(""); SendMailNameEditBox:Fire("OnTextChanged", true)
    SendMailFrame:Hide(); SendMailFrame:Show(); M.tick(0)
    eq(SendMailNameEditBox:GetText(), "")
    mark("Item-M", 0, 1, "mail"); A.Operations:AttachMail(); M.tick(1)
    eq(SendMailNameEditBox:GetText(), ""); eq(M.attachments[1].guid, "Item-M")
end)

test("successful send starts a new default recipient after Blizzard resets the form", function()
    A.db.recipient = "Default-Realm"; mail()
    SendMailNameEditBox:SetText("Manual"); SendMailNameEditBox:Fire("OnTextChanged", true)
    A.eventFrame:Fire("OnEvent", "MAIL_SEND_SUCCESS")
    SendMailNameEditBox:SetText(""); SendMailNameEditBox.focus = true -- Blizzard's event handler may run after ours.
    M.tick(0); eq(SendMailNameEditBox:GetText(), "Default-Realm")
    A.eventFrame:Fire("OnEvent", "MAIL_SEND_SUCCESS")
    SendMailNameEditBox:SetText(""); SendMailNameEditBox:Fire("OnTextChanged", true)
    M.tick(0); eq(SendMailNameEditBox:GetText(), "")
end)

test("autofill can be disabled and queued fills cannot outlive the mailbox", function()
    A.db.recipient, A.db.autoFillRecipient = "Default-Realm", false
    A.eventFrame:Fire("OnEvent", "MAIL_SHOW"); SendMailFrame:Show(); M.tick(0)
    eq(SendMailNameEditBox:GetText(), "")
    A.SetOption("autoFillRecipient", true)
    A.eventFrame:Fire("OnEvent", "MAIL_CLOSED"); M.tick(0)
    eq(SendMailNameEditBox:GetText(), "")
    A.eventFrame:Fire("OnEvent", "MAIL_SHOW"); M.tick(0)
    eq(SendMailNameEditBox:GetText(), "Default-Realm")
end)

test("changing the default only fills an empty unedited compose field after editing ends", function()
    mail(); A.Settings:Toggle()
    local field = A.Settings.recipient
    field.focus = true; field:SetText("Newdefault-Realm"); field:Fire("OnTextChanged", true)
    M.tick(0) -- An earlier OnShow callback must not use a partly edited default.
    eq(SendMailNameEditBox:GetText(), "")
    field:ClearFocus(); M.tick(0); eq(SendMailNameEditBox:GetText(), "Newdefault-Realm")
    field.focus = true; field:SetText("Another-Realm"); field:Fire("OnTextChanged", true)
    field:ClearFocus(); M.tick(0); eq(SendMailNameEditBox:GetText(), "Newdefault-Realm")
end)

test("sending during an attachment queue does not attach leftovers to the next draft", function()
    mail(); A.db.recipient = "Bankalt-Realm"
    mark("Item-A", 0, 1, "mail"); mark("Item-B", 0, 2, "mail")
    A.Operations:AttachMail(); eq(M.attachments[1].guid, "Item-A")
    A.eventFrame:Fire("OnEvent", "MAIL_SEND_SUCCESS")
    M.attachments = {}; SendMailNameEditBox:SetText(""); M.tick(1)
    eq(A.Operations.job, nil); eq(next(M.attachments), nil)
    eq(M.bags[0][2].guid, "Item-B"); eq(A.Store:Get("Item-B"), "mail")
    eq(SendMailNameEditBox:GetText(), "Bankalt-Realm")
end)

test("Ellesmere-style hidden buttons stay hidden through inventory and theme refreshes", function()
    -- EUI tracks the addon's Show/Hide intent separately from its closed flyout.
    local button = A.Minimap.button
    button:Hide(); button:SetAlpha(0)
    local shows, point = button.showCalls, button.point
    for _ = 1, 5 do A.eventFrame:Fire("OnEvent", "BAG_UPDATE_DELAYED"); M.tick(0) end
    A.CycleTheme(); A.ToggleMode()
    eq(button:IsShown(), false); eq(button.showCalls, shows); eq(button.point, point)
    eq(button.mouse, false, "transparent collected button must not cover the menu toggle")
end)

test("collected flyout button keeps its cell, size, and collector update script", function()
    local button = A.Minimap.button
    local flyout = CreateFrame("Frame", nil, UIParent)
    button:SetParent(flyout); button:SetSize(24, 24)
    button:ClearAllPoints(); button:SetPoint("TOPLEFT", flyout, "TOPLEFT", 4, -4)
    button:SetAlpha(1); button:Show()
    local update = function() end
    button:SetScript("OnUpdate", update)
    local point, angle = button.point, A.db.angle
    A.CycleTheme(); button:Fire("OnDragStart"); button:Fire("OnDragStop"); button:Hide()
    eq(button:GetParent(), flyout); eq(button.point, point); eq(button:GetWidth(), 24)
    eq(A.db.angle, angle); eq(button.scripts.OnUpdate, update)
    button:Show(); button:Fire("OnClick", "LeftButton")
    eq(A.Settings.frame:IsShown(), true)
    button:Fire("OnClick", "RightButton"); eq(A.mode, true)
    eq(button.point, point)
    flyout:Hide(); A.Refresh(); eq(button:IsVisible(), false)
end)

test("a collector row that retains Minimap parenting still owns the button layout", function()
    local button = A.Minimap.button
    button:ClearAllPoints(); button:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 40, -4)
    local point, angle = button.point, A.db.angle
    eq(A.Minimap:OwnsPlacement(), false)
    button:Fire("OnDragStart"); A.Refresh(); A.Minimap:Position()
    eq(button.point, point); eq(A.db.angle, angle); eq(A.Minimap.dragging, false)
end)

test("only explicit minimap visibility changes notify a collector", function()
    local button, shows = A.Minimap.button, 0
    hooksecurefunc(button, "Show", function(self)
        shows = shows + 1
        self:SetAlpha(0) -- EUI hides a grouped button on the map until its flyout opens.
    end)
    A.SetOption("minimap", false); A.SetOption("minimap", true)
    eq(shows, 1); eq(button.mouse, false)
    A.Refresh(); A.Refresh(); eq(shows, 1)
    button:SetAlpha(1); eq(button.mouse, true)
end)

test("combat and hide do not clear a collector's OnUpdate handler", function()
    local button = A.Minimap.button
    local update = function() end
    button:SetScript("OnUpdate", update)
    M.combat = true; A.eventFrame:Fire("OnEvent", "PLAYER_REGEN_DISABLED")
    eq(button.scripts.OnUpdate, update)
    button:Hide(); eq(button.scripts.OnUpdate, update)
end)

test("standard AddOns menu callbacks operate even when the minimap button is hidden", function()
    A.SetOption("minimap", false)
    BagMarks_OnAddonCompartmentClick("BagMarks", "LeftButton"); eq(A.Settings.frame:IsShown(), true)
    BagMarks_OnAddonCompartmentClick("BagMarks", "RightButton"); eq(A.mode, true)
    BagMarks_OnAddonCompartmentEnter("BagMarks", UIParent); eq(GameTooltip:GetOwner(), UIParent)
    BagMarks_OnAddonCompartmentLeave(); eq(GameTooltip:IsShown(), false)
    eq(A.Minimap.button:IsShown(), false)
end)

print(string.format("%d mocked tests passed under %s. No in-game or taint testing was performed.", passed, _VERSION))
