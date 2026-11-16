-- Rendering contracts are checked here; actual texture layering still needs WoW.
return function(M, A, test, eq, mark)
    local function nativeSlot(bag, slot)
        local bank = bag == 6
        if bank then A.bankOpen = true; BankFrame:Show() end
        local button = M.button(bag, slot, bank)
        button.icon = button:CreateTexture(nil, "BORDER")
        button.icon:SetSize(32, 32)
        button.Count = button:CreateFontString(nil, "ARTWORK")
        button.IconBorder = button:CreateTexture(nil, "OVERLAY")
        button.Cooldown = CreateFrame("Cooldown", nil, button)
        button.Cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
        A.Bags:Discover()
        return button, A.Bags.overlays[button]
    end

    local function paint(button, total)
        local item = M.bags[button.bag][button.slot]
        EUI_Bags.RunItemOverlays(button, { bag = button.bag, slot = button.slot,
            info = { itemID = item.itemID }, itemLink = item.link, _mergedCount = total })
    end

    local function combat()
        M.combat = true
        A.eventFrame:Fire("OnEvent", "PLAYER_REGEN_DISABLED")
    end

    local function leaveCombat()
        M.combat = false
        A.eventFrame:Fire("OnEvent", "PLAYER_REGEN_ENABLED")
        M.tick(0)
    end

    test("mark size defaults, persistence, invalid data and reset preserve marks", function()
        eq(A.db.iconSize, "corner")
        mark("Item-A", 0, 1, "mail")
        A.SetOption("iconSize", "full"); A.Store:Initialize()
        eq(A.db.iconSize, "full"); eq(A.Store:Get("Item-A"), "mail")
        for _, bad in ipairs({ "huge", false, 50 }) do
            A.db.iconSize = bad; A.Store:Initialize(); eq(A.db.iconSize, "corner")
        end
        A.db.iconSize = nil; A.Store:Initialize(); eq(A.db.iconSize, "corner")
        A.SetOption("iconSize", "full"); A.Store:ResetSettings()
        eq(A.db.iconSize, "corner"); eq(A.Store:Get("Item-A"), "mail")
    end)

    test("Appearance changes mark size immediately in open bags and banks", function()
        mark("Item-Bag", 0, 1, "junk"); mark("Item-Bank", 6, 1, "mail")
        local bag, bagOverlay = nativeSlot(0, 1)
        local bank, bankOverlay = nativeSlot(6, 1)
        A.Settings:Toggle(); A.Settings:SelectTab("Appearance")
        A.Settings.iconSize:Fire("OnClick")
        eq(M.menu.choices[1].selected(), true)
        M.menu.choices[2].callback()
        eq(A.db.iconSize, "full"); eq(A.Settings.iconSize:GetText(), "Full item icon")
        for _, entry in ipairs({ { bag, bagOverlay }, { bank, bankOverlay } }) do
            local button, overlay = entry[1], entry[2]
            eq(overlay.icon.anchored, button.icon)
            eq(overlay.icon:GetWidth(), 32); eq(overlay.icon:GetHeight(), 32)
            eq(overlay.icon:GetAlpha(), .6); assert(overlay.icon:IsVisible())
        end
        A.Settings.iconSize:Fire("OnClick"); M.menu.choices[1].callback()
        eq(bagOverlay.icon:GetWidth(), 14); eq(bankOverlay.icon:GetWidth(), 14)
        eq(bagOverlay.icon.anchored, nil); eq(bagOverlay.icon:GetAlpha(), 1)
    end)

    test("full marks stay below native counts, borders and cooldown frames", function()
        mark("Item-A", 0, 1, "locked")
        local button, overlay = nativeSlot(0, 1)
        A.SetOption("iconSize", "full")
        eq(overlay.icon:GetParent(), button)
        eq(overlay.icon.layer, "ARTWORK"); eq(overlay.icon.sublevel, -1)
        eq(button.icon.layer, "BORDER"); eq(button.Count.layer, "ARTWORK")
        eq(button.Count.sublevel, 0); eq(button.IconBorder.layer, "OVERLAY")
        assert(button.Cooldown:GetFrameLevel() > button:GetFrameLevel())
        eq(button.icon:GetAlpha(), 1); eq(button.Count:GetAlpha(), 1)
        eq(button.IconBorder:GetAlpha(), 1)
    end)

    test("full marks follow icon dimensions, scale and all themes", function()
        mark("Item-A", 0, 1, "locked")
        local button, overlay = nativeSlot(0, 1)
        A.SetOption("iconSize", "full")
        button:SetScale(.75); button.icon:SetSize(48, 48)
        eq(overlay.icon:GetWidth(), 48)
        eq(overlay.icon:GetEffectiveScale(), button.icon:GetEffectiveScale())
        for _, theme in ipairs({ "Classic", "Minimal", "Colorful" }) do
            A.SetOption("theme", theme)
            for _, state in ipairs({ "locked", "junk", "mail" }) do
                A.Store:Set(A.API:Read(0, 1), state)
                eq(overlay.icon.color[1], A.Themes[theme][state][1])
                eq(overlay.icon:GetAlpha(), .6); eq(overlay.icon:GetWidth(), 48)
            end
        end
        A.Store:Set(A.API:Read(0, 1), nil); eq(overlay.icon:IsVisible(), false)
    end)

    test("Ellesmere full marks fill only the icon and mirror column visibility", function()
        M.ellesmere(); A.Ellesmere:Install()
        mark("Item-A", 0, 1, "mail")
        local row = M.ellesmereButton(0, 1, true); paint(row)
        local overlay, host = A.Bags.overlays[row], row._textOverlay
        A.SetOption("iconSize", "full")
        eq(row:GetWidth(), 400); eq(overlay.icon:GetWidth(), 20)
        eq(overlay.icon:GetParent(), row); eq(overlay.icon.anchored, host)
        eq(overlay.icon.layer, "ARTWORK"); eq(overlay.icon.sublevel, 1)
        assert(host:GetFrameLevel() > row:GetFrameLevel())
        host:Hide(); eq(overlay.icon:IsVisible(), false)
        A.Refresh(); eq(overlay.icon:IsVisible(), false)
        host:Show(); assert(overlay.icon:IsVisible())
        A.SetOption("iconSize", "corner")
        eq(overlay.icon:GetParent(), host); eq(overlay.icon:GetWidth(), 12)
        eq(overlay.icon.layer, "OVERLAY"); eq(overlay.icon:GetAlpha(), 1)
        for _ = 1, 5 do A.SetOption("iconSize", "full"); A.SetOption("iconSize", "corner") end
        eq(#host.hooks.OnHide, 1); eq(#host.hooks.OnShow, 1)
    end)

    test("combat size changes wait without mutating layout or hiding readable marks", function()
        mark("Item-A", 0, 1, "junk")
        local button, overlay = nativeSlot(0, 1)
        local methods = { "SetParent", "SetAllPoints", "SetPoint", "ClearAllPoints", "SetScale",
            "SetSize", "SetDrawLayer", "SetFrameStrata", "SetFrameLevel", "HookScript" }
        local saved = {}
        for _, object in ipairs({ button, overlay, overlay.icon }) do
            saved[object] = {}
            for _, method in ipairs(methods) do
                saved[object][method] = object[method]
                object[method] = function() error("combat relayout: " .. method) end
            end
        end
        local frames = #M.frames
        combat(); A.SetOption("iconSize", "full")
        eq(A.db.iconSize, "full"); eq(overlay.iconSize, "corner")
        eq(overlay.icon:GetWidth(), 14); assert(overlay.icon:IsVisible())
        assert(A.Settings.iconSizeNote:GetText():find("combat ends", 1, true))
        eq(#M.frames, frames); eq(overlay:IsShown(), false)
        for object, original in pairs(saved) do for method, fn in pairs(original) do object[method] = fn end end
        leaveCombat()
        eq(overlay.iconSize, "full"); eq(overlay.icon:GetWidth(), 32)
        combat(); A.SetOption("iconSize", "corner")
        eq(overlay.iconSize, "full"); assert(overlay.icon:IsVisible())
        leaveCombat(); eq(overlay.iconSize, "corner"); eq(overlay.icon:GetWidth(), 14)
    end)

    test("full combat icons reject stale GUIDs and changed icon targets", function()
        mark("Item-A", 0, 1, "junk")
        local button, overlay = nativeSlot(0, 1)
        A.SetOption("iconSize", "full"); combat()
        M.item("Item-New", 0, 1); A.Bags:Refresh(); eq(overlay.icon:IsVisible(), false)
        M.item("Item-A", 0, 1); A.Bags:Refresh(); assert(overlay.icon:IsVisible())
        button.icon = button:CreateTexture(nil, "BORDER"); button.icon:SetSize(30, 30)
        A.Bags:Refresh(); eq(overlay.icon:IsVisible(), false)
        leaveCombat(); eq(overlay.icon.anchored, button.icon); assert(overlay.icon:IsVisible())
    end)

    test("Ellesmere host changes and combat hide/show cannot leave stray full marks", function()
        M.ellesmere(); A.Ellesmere:Install()
        mark("Item-A", 0, 1, "locked")
        local row = M.ellesmereButton(0, 1, true); paint(row)
        local overlay, old = A.Bags.overlays[row], row._textOverlay
        A.SetOption("iconSize", "full"); combat()
        old:Hide(); eq(overlay.icon:IsVisible(), false)
        old:Show(); assert(overlay.icon:IsVisible())
        row._textOverlay = CreateFrame("Frame", nil, row)
        row._textOverlay:SetSize(24, 24); paint(row)
        eq(overlay.icon:IsVisible(), false)
        leaveCombat(); assert(overlay.icon:IsVisible()); eq(overlay.icon:GetWidth(), 24)
        old:Hide(); assert(overlay.icon:IsVisible(), "old host must not affect the new render")
    end)

    test("full grouped icons preserve per-stack marks and uncertain-group suppression", function()
        M.ellesmere(); A.Ellesmere:Install()
        mark("Item-A", 0, 1, "locked"); M.item("Item-B", 0, 2)
        local button = M.ellesmereButton(0, 1); paint(button, 2)
        A.SetOption("iconSize", "full")
        local overlay = A.Bags.overlays[button]
        eq(overlay.icon:IsVisible(), false); eq(A.Store:Get("Item-B"), nil)
        A.Store:Set(A.API:Read(0, 2), "locked"); assert(overlay.icon:IsVisible())
        combat(); M.item("Item-Other", 0, 2); A.Bags:Refresh()
        eq(overlay.icon:IsVisible(), false); eq(A.Store:Get("Item-Other"), nil)
    end)

    test("full-size art keeps icon visibility settings and native mouse pass-through", function()
        mark("Item-A", 0, 1, "mail")
        local _, overlay = nativeSlot(0, 1)
        A.SetOption("iconSize", "full")
        eq(#overlay.passthrough, #A.Interaction.buttons)
        A.SetOption("overlays", false); eq(overlay.icon:IsVisible(), false)
        A.SetOption("overlays", true); assert(overlay.icon:IsVisible())
        A.SetOption("enabled", false); eq(overlay.icon:IsVisible(), false)
        A.SetOption("enabled", true); assert(overlay.icon:IsVisible())
        eq(A.Store:Get("Item-A"), "mail")
    end)
end
