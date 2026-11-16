-- The hover key cycles one readable item independently of mouse marking mode.
-- The passive pointer badge describes mode-based mouse clicks only.
local _, A = ...
local Hover = {}
A.Hover = Hover

function Hover:Available()
    -- Never reinterpret a typing key, drag/drop, or spell target as a mark.
    return A.CanAct() and not GetCursorInfo()
        and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
        and not (A.Bindings.capture and A.Bindings.capture:IsShown())
        and not (SpellIsTargeting and SpellIsTargeting())
end

function Hover:Item()
    if not self:Available() or not GetMouseFoci then return end
    local foci = GetMouseFoci()
    if not A.Safe(foci) or type(foci) ~= "table" then return end
    -- Resolve only the foreground focus and its ancestors. Never use a stale
    -- tooltip or search behind a menu/window for an item to change.
    local focus = foci[1]
    -- Bound the parent walk so an unexpected addon frame hierarchy cannot loop.
    for _ = 1, 16 do
        if not A.Safe(focus) or not focus or (focus.IsForbidden and focus:IsForbidden()) then return end
        if not focus.IsVisible or not focus:IsVisible() then return end
        local button = A.Bags.overlays[focus] and focus or A.Bags.inputOwners[focus]
        if button then
            if (button.IsForbidden and button:IsForbidden()) or not button:IsVisible() then return end
            -- Read the live slot every time; pooled buttons can change items.
            local item = A.Bags:Read(button)
            if item then return button, item end
            return
        end
        if not focus.GetParent then return end
        focus = focus:GetParent()
    end
end

function Hover:Cycle()
    local button, item = self:Item()
    if not item then return end
    local shown = A.Ellesmere and A.Ellesmere.slots[button]
    if shown and shown.total then A.Ellesmere:OpenGroup(button, item)
    else A.Interaction:Cycle(button, item) end
end

function Hover:Position()
    local x, y = GetCursorPosition()
    if not A.Safe(x) or not A.Safe(y) then self.badge:Hide(); return end
    -- Cursor coordinates are screen pixels; anchors use scaled UI coordinates.
    local scale = UIParent:GetEffectiveScale()
    self.badge:ClearAllPoints()
    self.badge:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 18, y / scale - 18)
end

function Hover:Update()
    local item
    if A.mode and A.Interaction:Active() then
        local _, hovered = self:Item()
        item = hovered
    end
    self.badge:SetShown(item ~= nil)
    if self.badge:IsShown() then self:Position() end
end

function Hover:Create()
    if self.driver or A.InCombat() then return end
    local driver = CreateFrame("Frame", nil, UIParent)
    driver:EnableMouse(false)
    driver:Hide()
    self.driver = driver
    -- Passive art beside the pointer. Do not replace the game cursor, which
    -- also communicates targeting, dragging, and other native interactions.
    local badge = CreateFrame("Frame", nil, driver)
    badge:SetFrameStrata("TOOLTIP")
    badge:EnableMouse(false)
    badge:SetSize(88, 24)
    badge:SetClampedToScreen(true)
    local background = badge:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(badge)
    background:SetColorTexture(0, 0, 0, .8)
    local icon = badge:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 3, 0)
    icon:SetTexture("Interface\\AddOns\\" .. A.name .. "\\Media\\BagMarks.tga")
    A.UI.Label(badge, "Marking", 26, -6, "GameFontNormalSmall")
    badge:Hide()
    self.badge = badge
    local elapsed = 0
    driver:SetScript("OnUpdate", function(_, delta)
        if not A.mode or not A.CanAct() then self:Refresh(); return end
        elapsed = elapsed + delta
        -- Follow the pointer each frame, but limit this ticker's identity checks
        -- to ten per second. Key presses always perform their own fresh read.
        if elapsed >= .1 then elapsed = 0; self:Update()
        elseif badge:IsShown() then self:Position() end
    end)
end

function Hover:Refresh()
    if not self.driver then self:Create() end
    if not self.driver then return end
    local active = A.mode and A.CanAct()
    -- Hidden frames do not receive OnUpdate, so ordinary play pays no polling
    -- cost for the badge while marking mode is off.
    self.driver:SetShown(active and true or false)
    if active then self:Update() else self.badge:Hide() end
end
