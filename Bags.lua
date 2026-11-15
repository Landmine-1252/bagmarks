local _, A = ...
local Bags = { overlays = {}, hooks = {} }
A.Bags = Bags

function Bags:Coordinates(button)
    local shown = A.Ellesmere and A.Ellesmere.slots[button]
    if shown then
        return shown.bag, shown.slot
    elseif button.GetBankTabID and button.GetContainerSlotID then
        return button:GetBankTabID(), button:GetContainerSlotID()
    elseif button.GetBagID and button.GetID then
        return button:GetBagID(), button:GetID()
    end
end

function Bags:Read(button, forDisplay)
    if A.Ellesmere and A.Ellesmere.slots[button] then return A.Ellesmere:Read(button, forDisplay) end
    local bag, slot = self:Coordinates(button)
    return A.API:Read(bag, slot, forDisplay)
end

function Bags:RiskyContext()
    return A.Protection:RiskyContext()
end

function Bags:Click(overlay, mouseButton)
    if not A.CanAct() then return end
    local item = self:Read(overlay.owner)
    local shown = A.Ellesmere and A.Ellesmere.slots[overlay.owner]
    if A.Interaction:Matches(mouseButton) then
        if item and shown and shown.total then A.Ellesmere:OpenGroup(overlay.owner, item)
        elseif item then A.Interaction:Mark(overlay.owner, item)
        else A.Print("No readable item GUID is available for this slot. No mark was saved.") end
    elseif item and shown and shown.total then
        A.Print("This group includes a Locked stack. Use the BagMarks menu to choose an individual stack, or switch to an unmerged bag view.")
    elseif item and A.Store:Get(item.guid) == "locked" then
        A.Print("Locked. Close the current merchant, mail, trade, bank, or auction window and finish item targeting to use reusable items. Clear the mark to move or transfer this item.")
    end
end

function Bags:Layout(button, overlay)
    local shown = A.Ellesmere and A.Ellesmere.slots[button]
    local host = shown and shown.host or UIParent
    -- EUI's host inherits scroll clipping and hidden/offline-view visibility.
    -- Its list-row host covers the icon, not the full width of the row.
    if overlay:GetParent() ~= host then overlay:SetParent(host) end
    overlay:SetScale(button:GetEffectiveScale() / host:GetEffectiveScale())
    overlay:SetAllPoints(button)
    overlay:SetFrameStrata(button:GetFrameStrata())
    overlay:SetFrameLevel(math.max(button:GetFrameLevel(), host:GetFrameLevel()) + 5)
    local iconHost = shown and host or button
    if overlay.icon:GetParent() ~= iconHost then overlay.icon:SetParent(iconHost) end
    overlay.icon:SetScale(button:GetEffectiveScale() / iconHost:GetEffectiveScale())
    overlay.icon:ClearAllPoints()
    local iconSize = shown and host:GetWidth() < 28 and 12 or 14
    overlay.icon:SetSize(iconSize, iconSize)
    overlay.icon:SetPoint("TOPRIGHT", iconHost, "TOPRIGHT", -3, -3)
end

function Bags:Attach(button, force)
    if not button or (button.IsForbidden and button:IsForbidden()) then return end
    local overlay = self.overlays[button]
    if A.InCombat() then
        if overlay then self:Update(button) end
        return -- New textures, scripts, and layout wait until combat ends.
    end
    if not overlay then
        -- Independent, insecure frames. Never replace Blizzard scripts or secure functions.
        overlay = CreateFrame("Button", nil, UIParent)
        if not overlay.SetPassThroughButtons or not overlay.SetMouseMotionEnabled then
            overlay:Hide()
            return
        end
        overlay.owner = button
        overlay:EnableMouse(true)
        overlay:SetMouseMotionEnabled(false) -- Blizzard retains hover/highlight/tooltips.
        overlay:RegisterForClicks("AnyUp")
        -- The passive texture belongs to the item icon host, independently of
        -- this input button. Hiding click capture must not hide the mark.
        local shown = A.Ellesmere and A.Ellesmere.slots[button]
        local iconHost = shown and shown.host or button
        overlay.icon = iconHost:CreateTexture(nil, "OVERLAY", nil, 7)
        overlay:SetScript("OnClick", function(self, mouse) Bags:Click(self, mouse) end)
        -- Ancestor hide/show dispatches these as well. Pooled buttons are refreshed on reuse.
        button:HookScript("OnHide", function() overlay.seenVisible = false; overlay:Hide(); overlay.icon:Hide() end)
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
    if not A.IsEnabled() or not button:IsVisible() then overlay:Hide(); overlay.icon:Hide(); return end
    local inCombat = A.InCombat()
    local shown = A.Ellesmere and A.Ellesmere.slots[button]
    if inCombat then
        overlay:Hide()
        -- A renderer can replace its icon host mid-combat. Hide the old texture
        -- until it can be reparented safely, rather than drawing on a stale row.
        if overlay.icon:GetParent() ~= (shown and shown.host or button) then overlay.icon:Hide(); return end
    else
        self:Layout(button, overlay)
    end
    local bag, slot = self:Coordinates(button)
    overlay.bag, overlay.slot, overlay.seenVisible = bag, slot, true
    local item = self:Read(button, inCombat)
    if shown and not item then overlay.icon:Hide(); overlay:Hide(); return end
    local state = item and A.Store:Get(item.guid)
    local hasLocked = state == "locked"
    if shown and shown.total then state, hasLocked = A.Ellesmere:GroupState(button, item) end
    overlay.icon:SetShown(state ~= nil and A.db.overlays)
    if state then A.PaintIcon(overlay.icon, state) end
    if inCombat then return end -- No marking, click guards, or mouse changes.
    local marking = A.Interaction:Active()
    local guard = hasLocked and self:RiskyContext()
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
    if A.Ellesmere then A.Ellesmere:Discover() end
end

function Bags:Tooltip(tooltip)
    if not A.CanAct() or not A.db.tooltips then return end
    local owner = tooltip:GetOwner()
    if not owner or not self.overlays[owner] then return end
    local item = self:Read(owner)
    if not item then return end
    local state = A.Store:Get(item.guid)
    local shown = A.Ellesmere and A.Ellesmere.slots[owner]
    if shown and shown.total then
        local hasLocked, count, mixed
        state, hasLocked, count, mixed = A.Ellesmere:GroupState(owner, item)
        tooltip:AddLine("BagMarks: " .. (mixed and "Mixed marks" or (state and A.states[state] or "Normal"))
            .. " (" .. count .. " stacks)", 1, .82, .3)
        tooltip:AddLine("Use your marking shortcut to choose one stack. Each stack keeps its own mark.", 1, 1, 1, true)
        if hasLocked then tooltip:AddLine("Includes a Locked stack. Clear that stack's mark before moving or transferring it. Reusable items can still be used.", 1, .72, .3, true) end
        return
    end
    if state then
        local color = A.Themes[A.db.theme][state]
        tooltip:AddLine("BagMarks: " .. A.states[state], color[1], color[2], color[3])
        if state == "locked" then
            if A.API:IsReusable(item.location) then
                tooltip:AddLine("Reusable: can be used while Locked. Close merchant, mail, trade, bank, and auction windows and finish item targeting first.", 1, .72, .3, true)
                tooltip:AddLine("Clear this mark before moving or transferring the item.", 1, .72, .3, true)
            else
                tooltip:AddLine("Clear this mark before moving, using, or transferring the item.", 1, .72, .3, true)
            end
            tooltip:AddLine("Some direct game actions can bypass addon protection.", 1, .72, .3, true)
        end
    end
    if A.char.review[item.guid] then
        tooltip:AddLine("Stack changed. Reapply a mark to allow BagMarks helpers.", 1, .72, .3, true)
    end
end

function Bags:InstallHooks()
    if A.Ellesmere then A.Ellesmere:Install() end
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
