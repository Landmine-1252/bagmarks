-- Standalone minimap launcher that yields placement/visibility to collectors.
-- The shared AddOns compartment uses the same actions through named callbacks.
local _, A = ...
local Mini = {}
A.Minimap = Mini

-- Standard radial placement, with common square-minimap shape conventions.
-- Each quadrant flag chooses a curved (true) or square (false) boundary.
local shapes = {
    ["ROUND"] = { true, true, true, true }, ["SQUARE"] = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true }, ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false }, ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true }, ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true }, ["SIDE-BOTTOM"] = { true, true, false, false },
}

function Mini:OwnsPlacement()
    local button = self.button
    if not button or button:GetParent() ~= Minimap then return false end
    if not self.placement then return button:GetNumPoints() == 0 end
    if button:GetNumPoints() ~= 1 or button:GetWidth() ~= 31 or button:GetHeight() ~= 31 then return false end
    local point, relative, relativePoint, x, y = button:GetPoint(1)
    local home = self.placement
    return point == home[1] and relative == home[2] and relativePoint == home[3]
        and math.abs((x or 0) - home[4]) < .01 and math.abs((y or 0) - home[5]) < .01
end

function Mini:Position()
    -- Collectors can keep Minimap as the parent while moving the button into a
    -- row. Check the actual anchor/size as well as the parent before moving it.
    if A.InCombat() or not self:OwnsPlacement() then return end
    local radians = math.rad(A.db.angle)
    local x, y = math.cos(radians), math.sin(radians)
    local radiusX, radiusY = Minimap:GetWidth() / 2 + 8, Minimap:GetHeight() / 2 + 8
    local quadrant = (x < 0 and 1 or 0) + (y > 0 and 2 or 0) + 1
    local shape = shapes[GetMinimapShape and GetMinimapShape() or "ROUND"] or shapes.ROUND
    if not shape[quadrant] then
        -- Project the unit circle direction onto a square edge without changing
        -- its angle. Width/height scaling below also handles rectangular minimaps.
        local divisor = math.max(math.abs(x), math.abs(y))
        x, y = x / divisor, y / divisor
    end
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x * radiusX, y * radiusY)
    self.placement = { self.button:GetPoint(1) }
    self.positionedAngle = A.db.angle
end

function Mini:Activate(mouse)
    if mouse == "LeftButton" then A.Settings:Toggle()
    elseif mouse == "RightButton" then A.ToggleMode() end
end

function Mini:Tooltip(owner, draggable)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText("BagMarks " .. A.version)
    GameTooltip:AddLine("Item Marking Mode: " .. (A.mode and "On" or "Off"), .4, .8, 1)
    GameTooltip:AddLine("Left Click: Settings\nRight Click: Toggle marking mode", 1, 1, 1)
    if draggable then GameTooltip:AddLine("Drag: Move minimap button", 1, 1, 1) end
    GameTooltip:AddLine(A.Interaction:Hint(), 1, .82, .3)
    if A.InCombat() then GameTooltip:AddLine("Marking and bag click guards pause in combat. Native item holds remain requested.", 1, .5, .3, true) end
    GameTooltip:Show()
end

function Mini:StopDrag()
    if not self.dragging then return end
    self.dragging = false
    self.dragFrame:SetScript("OnUpdate", nil)
    self.dragFrame:Hide()
    -- A drag release can also fire OnClick. Keep the suppression flag through
    -- this frame so moving the button does not open settings or toggle mode.
    C_Timer.After(0, function() self.justDragged = false end)
end

function Mini:StartDrag()
    if A.InCombat() or A.readOnly or not self:OwnsPlacement() then return end
    GameTooltip:Hide()
    self.justDragged, self.dragging = true, true
    if not self.dragFrame then self.dragFrame = CreateFrame("Frame", nil, UIParent) end
    -- Keep the drag ticker off the button. Collectors may install their own
    -- OnUpdate scripts for free-move/hover behavior, which BagMarks must preserve.
    self.dragFrame:SetScript("OnUpdate", function()
        if A.InCombat() or not self:OwnsPlacement() then self:StopDrag(); return end
        local x, y = GetCursorPosition()
        local cx, cy = Minimap:GetCenter()
        local scale = Minimap:GetEffectiveScale()
        -- Store an angle rather than screen coordinates so placement survives
        -- resolution/UI-scale changes when BagMarks still owns the button.
        A.db.angle = math.deg(math.atan2(y / scale - cy, x / scale - cx)) % 360
        self:Position()
    end)
    self.dragFrame:Show()
end

function Mini:Create()
    if self.button or not Minimap then return end
    local button = CreateFrame("Button", "BagMarksMinimapButton", Minimap)
    self.button = button
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetAllPoints()
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture("Interface\\AddOns\\" .. A.name .. "\\Media\\BagMarks.tga")
    button.icon:SetSize(20, 20)
    button.icon:SetPoint("CENTER", 0, 1)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    button.mode = button:CreateTexture(nil, "OVERLAY")
    button.mode:SetColorTexture(.15, .75, 1, 1)
    button.mode:SetSize(5, 5)
    button.mode:SetPoint("BOTTOM", 0, 4)
    button:SetScript("OnClick", function(_, mouse)
        if Mini.justDragged then Mini.justDragged = false; return end
        Mini:Activate(mouse)
    end)
    button:SetScript("OnEnter", function(self)
        Mini:Tooltip(self, Mini:OwnsPlacement())
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function() Mini:StartDrag() end)
    button:SetScript("OnDragStop", function() Mini:StopDrag() end)
    button:SetScript("OnHide", function() Mini:StopDrag() end)
    hooksecurefunc(button, "SetAlpha", function(self, alpha)
        -- Some collectors temporarily Show an alpha-zero button on the map.
        -- That invisible button must not eat clicks intended for their menu.
        if A.Safe(alpha) then self:EnableMouse(alpha > 0 and A.db.minimap) end
    end)
    -- Stable named child + ordinary OnClick/OnEnter scripts allow collectors to
    -- discover this button. No collector internals or embedded libraries required.
    self:Position()
    self:Refresh()
end

function Mini:Refresh()
    if not self.button then return end
    self.button.icon:SetDesaturated(not A.IsEnabled())
    self.button.mode:SetShown(A.mode and A.IsEnabled() and not A.InCombat())
    -- Send visibility intent only when the user changes it. Repeated Show calls
    -- resurrect collector-hidden buttons and can mask the group-menu toggle.
    if self.shownPreference ~= A.db.minimap then
        self.shownPreference = A.db.minimap
        self.button:SetShown(A.db.minimap)
        self.button:EnableMouse(A.db.minimap and self.button:GetAlpha() > 0)
    end
    if self.positionedAngle ~= A.db.angle then self:Position() end
end

-- Standard Blizzard AddOns compartment entry; no replacement of its menu/toggle.
function BagMarks_OnAddonCompartmentClick(_, mouse)
    if A.ready then Mini:Activate(mouse) end
end

function BagMarks_OnAddonCompartmentEnter(_, button)
    if A.ready then Mini:Tooltip(button, false) end
end

function BagMarks_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
