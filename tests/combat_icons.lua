-- Passive marks must stay independent of click capture during combat.
return function(M, A, test, eq, mark)
    local function combat()
        M.combat = true
        A.eventFrame:Fire("OnEvent", "PLAYER_REGEN_DISABLED")
    end
    local function leaveCombat()
        M.combat = false
        A.eventFrame:Fire("OnEvent", "PLAYER_REGEN_ENABLED")
        M.tick(0)
    end
    local function slot(state)
        local item = mark("Item-A", 0, 1, state)
        local button = M.button(0, 1)
        A.Bags:Discover()
        return item, button, A.Bags.overlays[button]
    end
    local function paint(button, total)
        local item = M.bags[button.bag] and M.bags[button.bag][button.slot]
        EUI_Bags.RunItemOverlays(button, { bag = button.bag, slot = button.slot,
            info = item and { itemID = item.itemID }, itemLink = item and item.link, _mergedCount = total })
    end

    test("Shift + Left Click cycles a combat stack and passes other buttons and chords to the game", function()
        local _, button = slot(nil)
        M.bags[0][1].count = 5
        local splits = 0
        button:SetScript("OnClick", function(_, click)
            if M.shift and click == "LeftButton" then splits = splits + 1 end
        end)
        local function click(mouse)
            local input = A.Bags.combatInput
            if input and input:IsVisible() then
                local passes = false
                for _, other in ipairs(input.passthrough) do if other == mouse then passes = true end end
                if not passes then input:Fire("OnClick", mouse); return end
            end
            button:Fire("OnClick", mouse)
        end
        A.db.modifier, A.db.mouseButton, A.db.markingAction = "SHIFT", "LeftButton", "cycle"
        combat(); eq(A.Bags.combatInput, nil)
        M.shift, M.mouseFoci = true, { button }
        A.eventFrame:Fire("OnEvent", "MODIFIER_STATE_CHANGED")
        local input = A.Bags.combatInput
        assert(input:IsVisible()); eq(input.owner, button); eq(input.motion, false)
        M.mouseFoci = { input, button }
        click("RightButton"); eq(A.Store:Get("Item-A"), nil)
        for _, state in ipairs({ "locked", "junk", "mail", "disenchant" }) do
            click("LeftButton"); eq(A.Store:Get("Item-A"), state)
        end
        eq(splits, 0); eq(M.bags[0][1].count, 5)
        M.ctrl = true; A.eventFrame:Fire("OnEvent", "MODIFIER_STATE_CHANGED")
        eq(input:IsShown(), false); click("LeftButton"); eq(splits, 1)
        leaveCombat(); eq(A.Bags.combatInput, nil)
    end)

    test("combat marking follows the foreground slot, ignores typing and rechecks a menu's GUID", function()
        A.db.modifier, A.db.mouseButton, A.db.markingAction = "SHIFT", "LeftButton", "menu"
        local _, button = slot(nil)
        M.shift, M.mouseFoci = true, { button }
        combat()
        local entered = M.button(0, 2)
        M.item("Item-New", 0, 2)
        ContainerFrameItemButtonMixin.Initialize(entered, nil, 0, 2)
        M.mouseFoci = { entered }; A.Bags.combatDriver:Fire("OnUpdate")
        eq(A.Bags.combatInput.owner, entered)
        M.keyboardFocus = SendMailNameEditBox; A.Bags.combatDriver:Fire("OnUpdate"); eq(A.Bags.combatInput, nil)
        M.keyboardFocus, M.targeting = nil, true
        A.Bags.combatDriver:Fire("OnUpdate"); eq(A.Bags.combatInput, nil)
        M.targeting, M.cursor = false, {}; A.eventFrame:Fire("OnEvent", "CURSOR_CHANGED"); eq(A.Bags.combatInput, nil)
        M.cursor = nil; M.mouseFoci = { A.Settings.frame, entered }
        A.Bags.combatDriver:Fire("OnUpdate"); eq(A.Bags.combatInput, nil)
        M.mouseFoci = { entered }; A.Bags.combatDriver:Fire("OnUpdate")
        A.Bags.combatInput:Fire("OnClick", "LeftButton"); eq(M.menu.owner, entered)
        M.bags[0][3] = M.bags[0][2]; M.item("Item-Replacement", 0, 2)
        M.menu.choices[3].callback()
        eq(A.Store:Get("Item-New"), "mail"); eq(A.Store:Get("Item-Replacement"), nil)
        A.SetOption("enabled", false); eq(A.Bags.combatInput, nil)
    end)

    test("teaching a combat mark preserves existing copies and unrelated restricted observations", function()
        local old = mark("Item-Unreadable", 0, 3, "junk", { itemID = 50 })
        A.SetOption("rememberItemTypes", true)
        local stack = M.item("Item-Scroll", 0, 1, { itemID = 211780 })
        local copy = M.item("Item-ExistingScroll", 0, 2, { itemID = 211780 })
        local button = M.button(0, 1); A.Bags:Discover()
        A.db.modifier, A.db.mouseButton = "SHIFT", "LeftButton"
        M.shift, M.mouseFoci = true, { button }; combat()
        old.secretID = M.secret
        A.Bags.combatInput:Fire("OnClick", "LeftButton"); M.menu.choices[3].callback()
        eq(A.Store:Get(stack.guid), "mail"); eq(A.char.itemRules[211780], "mail")
        eq(A.char.observed[old.guid].itemID, 50); eq(A.Store:Get(copy.guid), nil)
        local fresh = M.item("Item-FreshScroll", 0, 4, { itemID = 211780 })
        old.secretID = nil; leaveCombat()
        eq(A.Store:Get(fresh.guid), "mail"); eq(A.Store:Get(copy.guid), nil)
    end)

    test("merged Ellesmere stacks still select one copy on a combat marking click", function()
        M.ellesmere(); A.Bags:InstallHooks()
        M.item("Item-First", 0, 1, { count = 3 }); M.item("Item-Second", 0, 2, { count = 2 })
        local button = M.ellesmereButton(0, 1, true); paint(button, 5)
        A.db.modifier, A.db.mouseButton, A.db.markingAction = "SHIFT", "LeftButton", "cycle"
        M.shift, M.mouseFoci = true, { button }
        combat(); A.Bags.combatInput:Fire("OnClick", "LeftButton")
        eq(#M.menu.children, 2); M.menu.children[2].choices[3].callback()
        eq(A.Store:Get("Item-Second"), "mail"); eq(A.Store:Get("Item-First"), nil)
        button._textOverlay:Hide(); A.Bags.combatDriver:Fire("OnUpdate"); eq(A.Bags.combatInput, nil)
    end)

    test("combat keeps all mark icons visible without an active marking chord", function()
        local overlays = {}
        for index, state in ipairs({ "locked", "junk", "mail", "disenchant" }) do
            mark("Item-" .. index, 0, index, state)
            local button = M.button(0, index)
            A.Bags:Discover()
            overlays[index] = A.Bags.overlays[button]
        end
        A.mode = true; A.Bags:Refresh()
        combat()
        for index, overlay in ipairs(overlays) do
            assert(overlay.icon:IsVisible(), "combat must not hide a readable mark")
            eq(overlay:IsShown(), false)
            overlay:Fire("OnClick", "RightButton")
        end
        eq(A.mode, false); eq(M.menu, nil)
        eq(A.Store:Get("Item-1"), "locked"); eq(M.bags[0][1].held, nil)
        eq(A.Store:Get("Item-2"), "junk"); eq(A.Store:Get("Item-3"), "mail"); eq(A.Store:Get("Item-4"), "disenchant")
    end)

    test("combat repaint follows the live GUID instead of a cached slot mark", function()
        local item, button, overlay = slot("locked")
        M.item("Item-Other", 0, 2)
        local other = M.button(0, 2); A.Bags:Discover()
        combat()
        -- Simulate a client-side move despite the hold, plus an identical copy.
        M.bags[0][2], M.bags[0][1] = item, M.bags[0][2]
        A.eventFrame:Fire("OnEvent", "BAG_UPDATE_DELAYED"); M.tick(0)
        eq(overlay.icon:IsVisible(), false)
        assert(A.Bags.overlays[other].icon:IsVisible())
        eq(A.Store:Get("Item-Other"), nil)
        eq(A.API:Read(0, 2), nil, "normal operation reads still pause in combat")
        local inventory = A.API:Scan(true)
        eq(next(inventory), nil, "automation scans still pause in combat")
    end)

    test("existing bag slots repaint on combat reopen and pooled reuse", function()
        local _, button, overlay = slot("junk")
        mark("Item-Mail", 0, 2, "mail")
        button:Hide(); combat(); button:Show()
        assert(overlay.icon:IsVisible()); eq(overlay:IsShown(), false)
        button.slot = 2
        A.Bags:Attach(button, true)
        assert(overlay.icon.texture:find("Mail.tga", 1, true))
        button:Hide(); eq(overlay.icon:IsVisible(), false)
    end)

    test("combat appearance settings repaint passive icons immediately", function()
        local _, _, overlay = slot("locked")
        combat()
        A.SetOption("theme", "Minimal")
        eq(overlay.icon.color[1], .95); assert(overlay.icon:IsVisible())
        A.SetOption("overlays", false); eq(overlay.icon:IsVisible(), false)
        A.SetOption("overlays", true); assert(overlay.icon:IsVisible())
        A.SetOption("enabled", false); eq(overlay.icon:IsVisible(), false)
        A.SetOption("enabled", true); assert(overlay.icon:IsVisible())
        eq(overlay:IsShown(), false)
    end)

    test("combat unreadable or missing identities hide marks without borrowing another copy", function()
        local item, _, overlay = slot("junk")
        combat()
        item.guid = M.secret; A.Bags:Refresh(); eq(overlay.icon:IsVisible(), false)
        item.guid = "Item-A"; A.Bags:Refresh(); assert(overlay.icon:IsVisible())
        item.secretID = M.secret; A.Bags:Refresh(); eq(overlay.icon:IsVisible(), false)
        item.secretID = nil; A.Bags:Refresh(); assert(overlay.icon:IsVisible())
        M.bags[0][1] = nil; A.Bags:Refresh(); eq(overlay.icon:IsVisible(), false)
        eq(A.Store:Get("Item-A"), "junk")
    end)

    test("combat visuals do not create frames or change layout and mouse routing", function()
        local _, button, overlay = slot("mail")
        local methods = { "SetParent", "SetAllPoints", "SetPoint", "ClearAllPoints", "SetScale",
            "SetSize", "SetFrameStrata", "SetFrameLevel", "SetPassThroughButtons", "EnableMouse", "HookScript" }
        for _, object in ipairs({ button, overlay, overlay.icon }) do
            for _, method in ipairs(methods) do
                object[method] = function() error("combat display changed layout or input: " .. method) end
            end
        end
        local frameCount = #M.frames
        combat(); A.Bags:Attach(button, true); A.Bags:Refresh()
        assert(overlay.icon:IsVisible()); eq(#M.frames, frameCount)
    end)

    test("combat defers newly created Blizzard slots until combat ends", function()
        mark("Item-A", 0, 1, "mail")
        combat()
        local button = M.button(0, 1)
        A.Bags:Attach(button, true); eq(A.Bags.overlays[button], nil)
        leaveCombat()
        assert(A.Bags.overlays[button].icon:IsVisible())
    end)

    test("Ellesmere combat paints retain marks and clear empty or recycled slots", function()
        M.ellesmere(); A.Bags:InstallHooks()
        mark("Item-A", 0, 1, "locked"); mark("Item-B", 0, 2, "mail")
        local button = M.ellesmereButton(0, 1, true); paint(button)
        local overlay = A.Bags.overlays[button]
        combat(); assert(overlay.icon:IsVisible())
        button.slot = 2; paint(button)
        assert(overlay.icon:IsVisible()); assert(overlay.icon.texture:find("Mail.tga", 1, true))
        EUI_Bags.RunItemOverlays(button, { bag = 0, slot = 0 })
        eq(overlay.icon:IsVisible(), false); eq(overlay:IsShown(), false)
        paint(button); assert(overlay.icon:IsVisible())
        button._textOverlay:Hide(); eq(overlay.icon:IsVisible(), false)
    end)

    test("Ellesmere combat host changes wait for safe layout after combat", function()
        M.ellesmere(); A.Bags:InstallHooks()
        mark("Item-A", 0, 1, "junk")
        local button = M.ellesmereButton(0, 1); paint(button)
        local overlay = A.Bags.overlays[button]
        local oldHost = overlay.icon:GetParent()
        combat()
        button._textOverlay = CreateFrame("Frame", nil, button)
        paint(button)
        eq(overlay.icon:IsVisible(), false); eq(overlay.icon:GetParent(), oldHost)
        leaveCombat()
        eq(overlay.icon:GetParent(), button._textOverlay); assert(overlay.icon:IsVisible())
    end)

    test("Ellesmere combat groups revalidate every represented identity", function()
        M.ellesmere(); A.Bags:InstallHooks()
        mark("Item-A", 0, 1, "locked"); mark("Item-B", 0, 2, "locked")
        local button = M.ellesmereButton(0, 1); paint(button, 2)
        local overlay = A.Bags.overlays[button]
        combat(); assert(overlay.icon:IsVisible())
        local second = M.bags[0][2]
        M.item("Item-Replacement", 0, 2)
        paint(button, 2)
        eq(overlay.icon:IsVisible(), false, "same item ID and total must not reuse a whole-group lock")
        M.bags[0][2] = second; paint(button, 2); assert(overlay.icon:IsVisible())
        second.count = 2; paint(button, 3); eq(overlay.icon:IsVisible(), false)
        leaveCombat(); paint(button, 3); assert(overlay.icon:IsVisible())
    end)
end
