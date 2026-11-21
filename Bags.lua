-- Adapt supported bag buttons without replacing their native frames/scripts.
-- overlays maps item button -> our input button; inputOwners is the reverse
-- lookup used by hover marking when our input button is the mouse focus.
local _, A = ...
local Bags = { overlays = {}, inputOwners = {}, hooks = {}, combatSlots = setmetatable({}, { __mode = "k" }) }
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
    if not A.IsEnabled() then return end
    local item = self:Read(overlay.owner, A.InCombat())
    local shown = A.Ellesmere and A.Ellesmere.slots[overlay.owner]
    -- The marking gesture takes precedence over a lock guard so the player can
    -- clear a mark. All other captured clicks are warnings, never forwarded uses.
    if A.Interaction:Matches(mouseButton) then
        if item and shown and shown.total then A.Ellesmere:OpenGroup(overlay.owner, item)
        elseif item then A.Interaction:Mark(overlay.owner, item)
        else A.Print("No readable item GUID is available for this slot. No mark was saved.") end
    elseif A.InCombat() then return
    elseif item and shown and shown.total then
        A.Print("This group includes a Locked stack. Use the BagMarks menu to choose an individual stack, or switch to an unmerged bag view.")
    elseif item and A.Store:Get(item.guid) == "locked" then
        A.Print("Locked. Close the merchant, mail, trade, or auction window and finish item targeting to use or equip this item. Clear the mark before selling, mailing, trading, or deleting it.")
    end
end

-- The native split handler runs on the bag button itself. Capture the selected
-- click above the hovered slot. Prepare fixed mouse masks outside lockdown.
function Bags:CreateCombatInput()
    if self.combatDriver or A.InCombat() then return end
    local driver = CreateFrame("Frame", nil, UIParent)
    driver:Hide()
    self.combatDriver, self.combatInputs = driver, {}
    for _, option in ipairs(A.Interaction.buttons) do
        local mouse = option[1]
        local input = CreateFrame("Button", nil, UIParent)
        input:Hide()
        input:EnableMouse(true)
        input:SetMouseMotionEnabled(false)
        input:RegisterForClicks("AnyUp")
        local pass = {}
        for _, other in ipairs(A.Interaction.buttons) do
            if other[1] ~= mouse then pass[#pass + 1] = other[1] end
        end
        input:SetPassThroughButtons(unpack(pass))
        input:SetScript("OnClick", function(frame, click)
            if A.InCombat() and frame.owner and frame.owner == self:CombatTarget() and A.Interaction:Matches(click) then
                self:Click(frame, click)
            end
        end)
        self.combatInputs[mouse] = input
    end
    driver:SetScript("OnUpdate", function() self:RefreshCombatInput() end)
end

function Bags:CombatTarget()
    local foci = GetMouseFoci and GetMouseFoci()
    local focus = A.Safe(foci) and type(foci) == "table" and foci[1]
    for _ = 1, 16 do
        if not A.Safe(focus) or not focus or (focus.IsForbidden and focus:IsForbidden())
            or not focus.IsVisible or not focus:IsVisible() then return end
        if focus == self.combatInput then
            focus = focus.owner
        elseif self.overlays[focus] or self.combatSlots[focus] or A.Ellesmere.slots[focus] then
            local shown = A.Ellesmere.slots[focus]
            if not shown or (shown.itemID and shown.host:IsVisible()) then return focus end
            return
        else
            focus = focus.GetParent and focus:GetParent()
        end
    end
end

function Bags:RefreshCombatInput()
    local driver = self.combatDriver
    if not driver then return end
    local active = A.InCombat() and A.IsEnabled() and A.Interaction:ChordActive()
    if driver:IsShown() ~= active then driver:SetShown(active) end
    local owner = active and A.Interaction:Active() and self:CombatTarget()
    local input = owner and self.combatInputs[A.db.mouseButton] or nil
    if self.combatInput and self.combatInput ~= input then
        self.combatInput:Hide()
        self.combatInput.owner = nil
    end
    self.combatInput = input
    if input then
        local shown = A.Ellesmere.slots[owner]
        local host = shown and shown.host or owner
        if input.owner ~= owner or input:GetParent() ~= host then
            input.owner = owner
            input:SetParent(host)
            input:ClearAllPoints()
            input:SetAllPoints(owner)
            input:SetFrameLevel(math.max(owner:GetFrameLevel(), host:GetFrameLevel()) + 5)
        end
        if not input:IsShown() then input:Show() end
    end
end

function Bags:IconGeometry(button, size)
    local shown = A.Ellesmere and A.Ellesmere.slots[button]
    local host = shown and shown.host or button
    if size == "full" or size == "medium" then
        -- Paint on the base button, below cooldowns and Ellesmere's text frame.
        -- A list row can be hundreds of pixels wide; its host covers only the icon.
        return button, shown and host or button.icon or button.Icon or button
    end
    return host, host
end

function Bags:WatchIconHost(button, overlay, host)
    overlay.watchedHosts = overlay.watchedHosts or {}
    if overlay.watchedHosts[host] then return end
    overlay.watchedHosts[host] = true
    -- Full-size art is parented below this host so cooldowns remain on top.
    -- Mirror its visibility when Ellesmere hides the icon column or reuses rows.
    local function currentHost()
        local shown = A.Ellesmere and A.Ellesmere.slots[button]
        return shown and shown.host == host
    end
    host:HookScript("OnHide", function() if currentHost() then overlay.icon:Hide() end end)
    host:HookScript("OnShow", function() if currentHost() then self:Update(button) end end)
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
    local size = A.MarkSize()
    local iconHost, target = self:IconGeometry(button, size)
    if overlay.icon:GetParent() ~= iconHost then overlay.icon:SetParent(iconHost) end
    overlay.icon:SetScale(button:GetEffectiveScale() / iconHost:GetEffectiveScale())
    overlay.icon:ClearAllPoints()
    if size == "full" or size == "medium" then
        if size == "medium" then
            local extent = math.min(target:GetWidth(), target:GetHeight()) * target:GetEffectiveScale() / overlay.icon:GetEffectiveScale()
            local side = A.MediumMarkSize(extent)
            overlay.icon:SetSize(side, side)
            overlay.icon:SetPoint("TOPRIGHT", target, "TOPRIGHT", -1, -1)
        else
            overlay.icon:SetAllPoints(target)
        end
        -- Blizzard's icon is BORDER with counts in ARTWORK. Ellesmere paints
        -- its icon in ARTWORK but moves counts to a higher frame.
        overlay.icon:SetDrawLayer("ARTWORK", shown and 1 or -1)
    else
        local iconSize = shown and host:GetWidth() < 28 and 12 or 14
        overlay.icon:SetSize(iconSize, iconSize)
        overlay.icon:SetPoint("TOPRIGHT", iconHost, "TOPRIGHT", -3, -3)
        overlay.icon:SetDrawLayer("OVERLAY", 7)
    end
    if shown then self:WatchIconHost(button, overlay, host) end
    -- Keep the applied layout separately from the saved preference. During
    -- combat, a new size waits for safe reparenting/anchoring after combat ends.
    overlay.iconSize, overlay.iconTarget = size, target
end

function Bags:Attach(button, force)
    if not button or (button.IsForbidden and button:IsForbidden()) then return end
    local overlay = self.overlays[button]
    if A.InCombat() then
        self.combatSlots[button] = true
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
        button:HookScript("OnEnter", function()
            if Bags.combatDriver and Bags.combatDriver:IsShown() then Bags:RefreshCombatInput() end
        end)
        self.overlays[button] = overlay
        self.inputOwners[overlay] = button
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
    local theme = A.db.theme
    local shown = A.Ellesmere and A.Ellesmere.slots[button]
    if shown and not shown.host:IsVisible() then overlay:Hide(); overlay.icon:Hide(); return end
    if inCombat then
        overlay:Hide()
        -- A renderer can replace its icon host mid-combat. Hide the old texture
        -- until it can be reparented safely, rather than drawing on a stale row.
        local iconHost, target = self:IconGeometry(button, overlay.iconSize)
        if overlay.icon:GetParent() ~= iconHost or overlay.iconTarget ~= target then overlay.icon:Hide(); return end
        -- Switching to or from an outline can require new anchors. Keep the
        -- previous theme until the texture can adopt the requested geometry.
        if overlay.iconSize ~= A.MarkSize() and (A.Themes[theme].fullSize or A.Themes[overlay.iconTheme].fullSize) then
            theme = overlay.iconTheme
        end
    else
        self:Layout(button, overlay)
    end
    overlay.iconTheme = theme
    local bag, slot = self:Coordinates(button)
    overlay.bag, overlay.slot, overlay.seenVisible = bag, slot, true
    local item = self:Read(button, inCombat)
    if shown and not item then overlay.icon:Hide(); overlay:Hide(); return end
    local state = item and A.Store:Get(item.guid)
    local hasLocked = state == "locked"
    if shown and shown.total then state, hasLocked = A.Ellesmere:GroupState(button, item) end
    overlay.icon:SetShown(state ~= nil and A.db.overlays)
    if state then
        overlay.icon:SetAlpha(A.MarkAlpha(overlay.iconSize, theme))
        A.PaintIcon(overlay.icon, state, theme)
    end
    if inCombat then return end -- The separate combat receiver handles the marking shortcut.
    local marking = A.Interaction:Active()
    local guard = hasLocked and self:RiskyContext()
    -- Preserve ordinary modified left-click links/previews outside targeting.
    -- Native item holds still apply independently of this visual input guard.
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
    -- A visible mark does not imply click capture: every unblocked button goes
    -- straight to the native item frame through this overlay.
    overlay:SetPassThroughButtons(unpack(passthrough))
    overlay:SetShown(marking or guard or (state ~= nil and A.db.overlays))
end

function Bags:Refresh()
    for button in pairs(self.overlays) do self:Update(button) end
    self:RefreshCombatInput()
    -- Refresh the currently owned bag tooltip as well as the icon so a mark
    -- change is visible without requiring the mouse to leave and reenter.
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
    if not A.CanAct() then return end
    local owner = tooltip:GetOwner()
    if not owner or not self.overlays[owner] then return end
    local item = self:Read(owner)
    if not item then return end
    local state = A.Store:Get(item.guid)
    -- Release an earlier context hold before an ordinary use/equip click, even
    -- with labels disabled. Metadata and consumable status are not prerequisites
    -- for normal gameplay; transfer/targeting contexts still hold Locked GUIDs.
    if state == "locked" and A.Protection.held[item.guid] and not self:RiskyContext() then A.Protection:SyncHolds() end
    if not A.db.tooltips then return end
    local shown = A.Ellesmere and A.Ellesmere.slots[owner]
    if shown and shown.total then
        local hasLocked, count, mixed
        state, hasLocked, count, mixed = A.Ellesmere:GroupState(owner, item)
        local label = state == "mail" and A.MailRoutes:Tooltip(item.itemID) or A.states[state]
        tooltip:AddLine("BagMarks: " .. (mixed and "Mixed marks" or label or "Normal")
            .. " (" .. count .. " stacks)", 1, .82, .3)
        tooltip:AddLine("Use your marking shortcut to choose one stack. Each stack keeps its own mark.", 1, 1, 1, true)
        if hasLocked then tooltip:AddLine("Includes a Locked stack. Use and equip normally. Clear its mark before selling, mailing, trading, or deleting it.", 1, .72, .3, true) end
        return
    end
    if state then
        local color = A.Themes[A.db.theme][state]
        local label = state == "mail" and A.MailRoutes:Tooltip(item.itemID) or A.states[state]
        tooltip:AddLine("BagMarks: " .. label, color[1], color[2], color[3])
        if state == "locked" then
            tooltip:AddLine("Use and equip normally while Locked. Consumables can still be consumed.", 1, .72, .3, true)
            tooltip:AddLine("Clear the mark before selling, mailing, trading, or deleting this item.", 1, .72, .3, true)
            tooltip:AddLine("Some direct game actions can bypass addon protection.", 1, .72, .3, true)
        end
    end
    if A.char.review[item.guid] then
        tooltip:AddLine("Stack changed. Reapply a mark to allow BagMarks helpers.", 1, .72, .3, true)
    end
end

function Bags:InstallHooks()
    self:CreateCombatInput()
    if A.Ellesmere then A.Ellesmere:Install() end
    local function hook(key, object, method, callback)
        -- Loading another addon can retry installation. Register each post-hook
        -- once so repeated load events do not multiply updates or change handlers.
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
