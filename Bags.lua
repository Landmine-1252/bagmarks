local _, A = ...
local Bags = { overlays = {}, hooks = {} }
A.Bags = Bags

function Bags:Coordinates(button)
    if button.GetBankTabID and button.GetContainerSlotID then
        return button:GetBankTabID(), button:GetContainerSlotID()
    elseif button.GetBagID and button.GetID then
        return button:GetBagID(), button:GetID()
    end
end

function Bags:RiskyContext()
    return A.merchantOpen or A.mailOpen or (SpellIsTargeting and SpellIsTargeting())
end

function Bags:Click(overlay, mouseButton)
    if not A.CanAct() then return end
    local bag, slot = self:Coordinates(overlay.owner)
    local item = A.API:Read(bag, slot)
    if A.Interaction:Matches(mouseButton) then
        if item then A.Interaction:Mark(overlay.owner, item)
        else A.Print("No readable item GUID is available for this slot. No mark was saved.") end
    elseif item and A.Store:Get(item.guid) == "locked" then
        A.Print("Locked. Clear its BagMarks mark before selling, mailing, or targeting it with a spell.")
    end
end

function Bags:Attach(button, force)
    if not button or A.InCombat() or (button.IsForbidden and button:IsForbidden()) then return end
    local overlay = self.overlays[button]
    if not overlay then
        -- Independent, insecure frames. Never replace Blizzard scripts or secure functions.
        overlay = CreateFrame("Button", nil, UIParent)
        if not overlay.SetPassThroughButtons or not overlay.SetMouseMotionEnabled then
            overlay:Hide()
            return
        end
        overlay.owner = button
        overlay:SetAllPoints(button)
        overlay:SetFrameStrata(button:GetFrameStrata())
        overlay:SetFrameLevel(button:GetFrameLevel() + 5)
        overlay:SetScale(button:GetEffectiveScale() / UIParent:GetEffectiveScale())
        overlay:EnableMouse(true)
        overlay:SetMouseMotionEnabled(false) -- Blizzard retains hover/highlight/tooltips.
        overlay:RegisterForClicks("AnyUp")
        overlay.icon = overlay:CreateTexture(nil, "OVERLAY")
        overlay.icon:SetSize(14, 14)
        overlay.icon:SetPoint("TOPRIGHT", -3, -3)
        overlay:SetScript("OnClick", function(self, mouse) Bags:Click(self, mouse) end)
        -- Ancestor hide/show dispatches these as well. Pooled buttons are refreshed on reuse.
        button:HookScript("OnHide", function() overlay.seenVisible = false; overlay:Hide() end)
        button:HookScript("OnShow", function() Bags:Update(button) end)
        self.overlays[button] = overlay
        force = true
    end
    local bag, slot = self:Coordinates(button)
    if force or not overlay.seenVisible or overlay.bag ~= bag or overlay.slot ~= slot then self:Update(button) end
end

function Bags:Update(button)
    local overlay = self.overlays[button]
    if not overlay then return end
    if not A.CanAct() or not button:IsVisible() then overlay:Hide(); return end
    local bag, slot = self:Coordinates(button)
    overlay.bag, overlay.slot, overlay.seenVisible = bag, slot, true
    local item = A.API:Read(bag, slot)
    local state = item and A.Store:Get(item.guid)
    overlay.icon:SetShown(state ~= nil and A.db.overlays)
    if state then A.PaintIcon(overlay.icon, state) end
    local marking = A.Interaction:Active()
    local guard = state == "locked" and self:RiskyContext()
    local modifiedLeft = (IsShiftKeyDown() or IsControlKeyDown()) and not (SpellIsTargeting and SpellIsTargeting())
    local blocked, passthrough = {}, {}
    if marking then blocked[A.db.mouseButton] = true end
    if guard then
        blocked.RightButton = true
        if not modifiedLeft then blocked.LeftButton = true end
    end
    for _, option in ipairs(A.Interaction.buttons) do
        if not blocked[option[1]] then passthrough[#passthrough + 1] = option[1] end
    end
    overlay:SetPassThroughButtons(unpack(passthrough))
    overlay:SetShown(marking or guard or (state ~= nil and A.db.overlays))
end

function Bags:Refresh()
    for button in pairs(self.overlays) do self:Update(button) end
    if GameTooltip and GameTooltip:IsShown() and not A.InCombat() then
        local owner = GameTooltip:GetOwner()
        if owner and self.overlays[owner] and GameTooltip.SetBagItem then
            local bag, slot = self:Coordinates(owner)
            if bag and slot then GameTooltip:SetBagItem(bag, slot) end
        end
    end
end

function Bags:Discover()
    if not A.CanAct() then return end
    if ContainerFrameUtil_EnumerateContainerFrames then
        for _, container in ContainerFrameUtil_EnumerateContainerFrames() do
            if container:IsShown() and container.EnumerateValidItems then
                for _, button in container:EnumerateValidItems() do self:Attach(button) end
            end
        end
    end
    local panel = BankFrame and BankFrame.BankPanel
    if panel and panel:IsShown() and panel.EnumerateValidItems then
        for button in panel:EnumerateValidItems() do self:Attach(button) end
    end
end

function Bags:Tooltip(tooltip)
    if not A.CanAct() or not A.db.tooltips then return end
    local owner = tooltip:GetOwner()
    if not owner or not self.overlays[owner] then return end
    local bag, slot = self:Coordinates(owner)
    local item = A.API:Read(bag, slot)
    if not item then return end
    local state = A.Store:Get(item.guid)
    if state then
        local color = A.Themes[A.db.theme][state]
        tooltip:AddLine("BagMarks: " .. A.states[state], color[1], color[2], color[3])
        if state == "locked" then
            tooltip:AddLine("Bag click guard only. Cursor deletion, macros and other addons can bypass it.", 1, .72, .3, true)
        end
    end
    if A.char.review[item.guid] then
        tooltip:AddLine("Stack changed. Reapply a mark to allow BagMarks helpers.", 1, .72, .3, true)
    end
end

function Bags:InstallHooks()
    local function hook(key, object, method, callback)
        if not self.hooks[key] and object and type(object[method]) == "function" then
            hooksecurefunc(object, method, callback)
            self.hooks[key] = true
        end
    end
    hook("bag-init", ContainerFrameItemButtonMixin, "Initialize", function(button) self:Attach(button, true) end)
    hook("bag-update", ContainerFrameMixin, "UpdateItems", function() self:Discover(); self:Refresh() end)
    hook("bank-item", BankPanelItemButtonMixin, "Refresh", function(button) self:Attach(button, true) end)
    if not self.hooks.tooltip and TooltipDataProcessor and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip) self:Tooltip(tooltip) end)
        self.hooks.tooltip = true
    end
end
