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

    test("combat keeps all mark icons visible with click capture disabled", function()
        local overlays = {}
        for index, state in ipairs({ "locked", "junk", "mail" }) do
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
        eq(A.Store:Get("Item-2"), "junk"); eq(A.Store:Get("Item-3"), "mail")
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
