return function(M, A, test, eq, mark)
    local function hover(bag, slot, bank)
        local button = M.button(bag or 0, slot or 1, bank)
        A.Bags:Discover()
        M.mouseFoci = { button }
        return button
    end

    local function paint(button, total)
        local item = M.bags[button.bag][button.slot]
        EUI_Bags.RunItemOverlays(button, { bag = button.bag, slot = button.slot,
            info = { itemID = item.itemID }, itemLink = item.link, _mergedCount = total })
    end

    test("hover shortcut locks first and cycles all marks without marking mode", function()
        M.item("Item-A", 0, 1); M.item("Item-Copy", 0, 2)
        local button = hover()
        for _, state in ipairs({ "locked", "junk", "mail", false }) do
            BagMarks_CycleHoveredItem()
            eq(A.Store:Get("Item-A"), state or nil)
            eq(A.Store:Get("Item-Copy"), nil)
            eq(A.Bags.overlays[button].icon:IsShown(), state ~= false)
        end
        eq(A.mode, false); eq(A.db.markingAction, "menu"); eq(M.menu, nil)
    end)

    test("hover shortcut rereads pooled slots and leaves moved copies alone", function()
        mark("Item-Moved", 0, 1, "mail")
        hover()
        M.bags[0][2], M.bags[0][1] = M.bags[0][1], nil
        M.item("Item-New", 0, 1)
        BagMarks_CycleHoveredItem()
        eq(A.Store:Get("Item-Moved"), "mail"); eq(A.Store:Get("Item-New"), "locked")
    end)

    test("hover resolves item children and owned overlays without trusting arbitrary owners", function()
        M.item("Item-A", 0, 1)
        local button = hover()
        M.mouseFoci = { CreateFrame("Frame", nil, button) }
        BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-A"), "locked")
        M.mouseFoci = { A.Bags.overlays[button] }
        BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-A"), "junk")
        local foreign = CreateFrame("Button", nil, UIParent)
        foreign.owner = button
        M.mouseFoci = { foreign }
        BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-A"), "junk")
    end)

    test("hover never marks behind a window or through a stale tooltip", function()
        M.item("Item-A", 0, 1)
        local button = hover()
        GameTooltip:SetOwner(button); GameTooltip:Show()
        M.mouseFoci = { CreateFrame("Frame", nil, UIParent), button }
        BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-A"), nil)
        M.mouseFoci = {}
        BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-A"), nil)
    end)

    test("hover rejects hidden, forbidden, empty and unidentified slots", function()
        local item = M.item("Item-A", 0, 1)
        local button = hover()
        button:Hide(); BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-A"), nil)
        button:Show()
        button.IsForbidden = function() return true end
        BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-A"), nil)
        M.mouseFoci = { A.Bags.overlays[button] }
        BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-A"), nil)
        M.mouseFoci = { button }
        button.IsForbidden = nil
        M.bags[0][1] = nil
        BagMarks_CycleHoveredItem(); eq(next(A.char.marks), nil)
        M.bags[0][1] = item; item.guid = nil
        BagMarks_CycleHoveredItem(); eq(next(A.char.marks), nil)
    end)

    test("hover waits during combat, typing, capture, cursor carry and spell targeting", function()
        M.item("Item-A", 0, 1); hover()
        M.combat = true; BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-A"), nil)
        M.combat = false; M.keyboardFocus = CreateFrame("EditBox", nil, UIParent)
        BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-A"), nil)
        M.keyboardFocus = nil; A.Bindings:StartCapture()
        BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-A"), nil)
        A.Bindings:StopCapture(); M.cursor = { item = {} }
        BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-A"), nil)
        M.cursor = nil; M.targeting = true
        BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-A"), nil)
        M.targeting = false; A.SetOption("enabled", false)
        BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-A"), nil)
    end)

    test("hover marks live bank items and refuses a hidden bank", function()
        M.item("Item-Bank", 6, 1); A.bankOpen = true; BankFrame:Show()
        hover(6, 1, true)
        BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-Bank"), "locked")
        A.bankOpen = false; BankFrame:Hide()
        BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-Bank"), "locked")
    end)

    test("hover asks for explicit review of changed stacks", function()
        mark("Item-Stack", 0, 1, "junk"); A.char.review["Item-Stack"] = true
        hover(); BagMarks_CycleHoveredItem()
        eq(A.Store:Get("Item-Stack"), "junk"); assert(M.menu)
        M.menu.choices[1].callback(); eq(A.Store:Get("Item-Stack"), "locked")
        eq(A.char.review["Item-Stack"], nil)
    end)

    test("hover works in Ellesmere list view and revalidates recycled data", function()
        M.ellesmere(); A.Ellesmere:Install()
        M.item("Item-A", 0, 1)
        local button = M.ellesmereButton(0, 1, true)
        paint(button); M.mouseFoci = { button._textOverlay }
        BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-A"), "locked")
        M.item("Item-NewType", 0, 1, { itemID = 200 })
        BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-NewType"), nil)
        paint(button); BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-NewType"), "locked")
        EUI_Bags:Hide(); BagMarks_CycleHoveredItem(); eq(A.Store:Get("Item-NewType"), "locked")
    end)

    test("hover opens an Ellesmere stack selector without changing all copies", function()
        M.ellesmere(); A.Ellesmere:Install()
        M.item("Item-A", 0, 1); M.item("Item-B", 0, 2)
        local button = M.ellesmereButton(0, 1)
        paint(button, 2); M.mouseFoci = { button }
        BagMarks_CycleHoveredItem()
        eq(next(A.char.marks), nil); eq(#M.menu.children, 2)
        M.menu.children[2].choices[1].callback()
        eq(A.Store:Get("Item-A"), nil); eq(A.Store:Get("Item-B"), "locked")
    end)

    test("hover and mode shortcuts have independent capture, clear and restore", function()
        eq(A.Bindings:Text(A.Bindings.hoverAction), "Unbound")
        assert(A.Bindings:Apply({ "F7" }))
        A.Settings:Toggle(); A.Settings:SelectTab("Marking")
        A.Settings.bindingChoice:Fire("OnClick"); M.menu.choices[2].callback()
        A.Settings.bindButton:Fire("OnClick")
        M.ctrl = true; A.Bindings.capture:Fire("OnKeyDown", "H")
        eq(M.bindings["CTRL-H"], A.Bindings.hoverAction)
        eq(M.bindings.F7, A.Bindings.action); eq(M.savedBindingSet, 1)
        eq(A.Settings.binding:GetText(), "Assigned key: CTRL-H")
        A.Settings.clearButton:Fire("OnClick"); eq(M.bindings["CTRL-H"], nil)
        A.Settings.restoreButton:Fire("OnClick"); eq(M.bindings["CTRL-H"], A.Bindings.hoverAction)
        assert(A.Bindings:Apply({ "F8" }))
        assert(A.Bindings:Restore()); eq(M.bindings.F7, A.Bindings.action)
        eq(M.bindings["CTRL-H"], A.Bindings.hoverAction)
    end)

    test("hover binding never takes Jump, overrides or the mode shortcut", function()
        M.bindings.SPACE = "JUMP"
        assert(A.Bindings:Apply({ "F7" }))
        assert(A.Bindings:Apply({ "F8" }, false, A.Bindings.hoverAction))
        for _, key in ipairs({ "SPACE", "F7" }) do
            eq(A.Bindings:Apply({ key }, false, A.Bindings.hoverAction), false)
        end
        M.overrides = { F9 = "OTHER_ADDON" }
        eq(A.Bindings:Apply({ "F9" }, false, A.Bindings.hoverAction), false)
        eq(M.bindings.SPACE, "JUMP"); eq(M.bindings.F7, A.Bindings.action)
        eq(M.bindings.F8, A.Bindings.hoverAction)
        -- Space is usable only after the player explicitly frees it.
        M.bindings.SPACE = nil
        assert(A.Bindings:Apply({ "SPACE" }, false, A.Bindings.hoverAction))
        eq(M.bindings.SPACE, A.Bindings.hoverAction)
    end)

    test("hover binding rollback and binding-set restore leave the other action intact", function()
        assert(A.Bindings:Apply({ "F7" }))
        assert(A.Bindings:Apply({ "F8" }, false, A.Bindings.hoverAction))
        M.failKey = "F9"
        eq(A.Bindings:Apply({ "F9" }, false, A.Bindings.hoverAction), false)
        eq(M.bindings.F8, A.Bindings.hoverAction); eq(M.bindings.F7, A.Bindings.action)
        M.failKey = nil
        assert(A.Bindings:Apply({ "F9" }, false, A.Bindings.hoverAction))
        M.bindingSet = 2
        eq(A.Bindings:Restore(A.Bindings.hoverAction), false)
        eq(M.bindings.F9, A.Bindings.hoverAction)
    end)

    test("native tabs show only the selected page and its active tab art", function()
        A.Settings:Toggle()
        for i, name in ipairs({ "General", "Marking", "Appearance" }) do
            A.Settings.tabs[name]:Fire("OnClick")
            eq(A.Settings.frame.selectedTab, i)
            eq(A.Settings.selectedTab, name)
            for page, tab in pairs(A.Settings.tabs) do
                eq(tab.template, "PanelTopTabButtonTemplate")
                eq(tab.MiddleActive:IsShown(), page == name)
                eq(tab.enabled, page ~= name)
                eq(A.Settings.panels[page]:IsShown(), page == name)
            end
        end
    end)

    test("changing binding selection, tabs or closing settings cancels capture", function()
        A.Settings:Toggle(); A.Settings:SelectTab("Marking")
        A.Settings.bindButton:Fire("OnClick")
        A.Settings.bindingChoice:Fire("OnClick"); M.menu.choices[2].callback()
        eq(A.Bindings.capture:IsShown(), false)
        A.Settings.bindButton:Fire("OnClick"); A.Settings:SelectTab("General")
        eq(A.Bindings.capture:IsShown(), false)
        A.Settings:SelectTab("Marking"); A.Settings.bindButton:Fire("OnClick")
        A.Settings:Toggle(); eq(A.Bindings.capture:IsShown(), false)
        eq(next(M.bindings), nil)
    end)

    test("mode footer explains on, off, disabled and combat states", function()
        A.Settings:Refresh()
        eq(A.Settings.modeButton:GetText(), "Turn marking mode on")
        assert(A.Settings.modeStatus:GetText():find("OFF", 1, true))
        A.Settings.modeButton:Fire("OnClick")
        assert(A.Settings.modeStatus:GetText():find("ON", 1, true))
        assert(A.Settings.modeHint:GetText():find("Right Click marks items without modifiers", 1, true))
        A.SetOption("mouseButton", "MiddleButton")
        assert(A.Settings.modeHint:GetText():find("Middle Click marks items", 1, true))
        A.SetOption("enabled", false)
        eq(A.Settings.modeButton.enabled, false)
        assert(A.Settings.modeHint:GetText():find("Enable BagMarks", 1, true))
        A.SetOption("enabled", true); M.combat = true
        A.eventFrame:Fire("OnEvent", "PLAYER_REGEN_DISABLED")
        assert(A.Settings.modeHint:GetText():find("combat", 1, true))
        A.Settings:Toggle(); A.Settings.tabs.Appearance:Fire("OnClick")
        eq(A.Settings.panels.Appearance:IsVisible(), true)
        A.Settings:Toggle(); eq(A.Settings.frame:IsShown(), false)
    end)

    test("mode badge tracks pointer scale and hides immediately when mode ends", function()
        M.item("Item-A", 0, 1); hover()
        M.cursorX, M.cursorY = 300, 200
        UIParent:SetScale(.8)
        A.ToggleMode()
        eq(A.Hover.badge:IsVisible(), true); eq(A.Hover.badge.mouse, false)
        eq(A.Hover.badge.point[4], 393); eq(A.Hover.badge.point[5], 232)
        M.cursorX = 400; A.Hover.driver:Fire("OnUpdate", .01)
        eq(A.Hover.badge.point[4], 518)
        UIParent:SetScale(1)
        A.ToggleMode()
        eq(A.Hover.driver:IsShown(), false); eq(A.Hover.badge:IsShown(), false)
    end)

    test("mode badge hides for nonitems, typing, cursor carry, targeting and combat", function()
        M.item("Item-A", 0, 1); local button = hover(); A.ToggleMode()
        M.mouseFoci = {}; A.Hover.driver:Fire("OnUpdate", .1)
        eq(A.Hover.badge:IsShown(), false)
        M.mouseFoci = { button }; A.Hover:Refresh(); eq(A.Hover.badge:IsShown(), true)
        M.keyboardFocus = {}; A.Hover.driver:Fire("OnUpdate", .1); eq(A.Hover.badge:IsShown(), false)
        M.keyboardFocus = nil; M.cursor = { item = {} }; A.Hover:Refresh(); eq(A.Hover.badge:IsShown(), false)
        M.cursor = nil; M.targeting = true; A.Hover:Refresh(); eq(A.Hover.badge:IsShown(), false)
        M.targeting = false; A.Hover:Refresh(); eq(A.Hover.badge:IsShown(), true)
        M.ctrl = true; A.eventFrame:Fire("OnEvent", "MODIFIER_STATE_CHANGED")
        eq(A.Hover.badge:IsShown(), false)
        M.ctrl = false; A.eventFrame:Fire("OnEvent", "MODIFIER_STATE_CHANGED")
        eq(A.Hover.badge:IsShown(), true)
        M.combat = true; A.eventFrame:Fire("OnEvent", "PLAYER_REGEN_DISABLED")
        eq(A.Hover.driver:IsShown(), false); eq(A.Hover.badge:IsShown(), false)
        M.combat = false; A.eventFrame:Fire("OnEvent", "PLAYER_REGEN_ENABLED"); M.tick(0)
        eq(A.Hover.driver:IsShown(), false)
    end)

    test("mode badge does not poll item identities while mode is off", function()
        M.item("Item-A", 0, 1); hover()
        A.Hover:Refresh()
        local reads = M.reads
        A.Hover.driver:Fire("OnUpdate", 1)
        eq(A.Hover.driver:IsShown(), false); eq(M.reads, reads)
    end)
end
