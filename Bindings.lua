local _, A = ...
local Bindings = { action = "BAGMARKS_TOGGLE_MODE", hoverAction = "BAGMARKS_CYCLE_HOVERED", history = {} }
A.Bindings = Bindings
BINDING_HEADER_BAGMARKS = "BagMarks"
BINDING_NAME_BAGMARKS_TOGGLE_MODE = "Toggle Item Marking Mode"
BINDING_NAME_BAGMARKS_CYCLE_HOVERED = "Cycle hovered item's mark"

function BagMarks_ToggleMarkingMode()
    if A.ready then A.ToggleMode() end
end

function BagMarks_CycleHoveredItem()
    if A.ready then A.Hover:Cycle() end
end

function Bindings:Keys(action)
    return { GetBindingKey(action or self.action) }
end

function Bindings:Text(action)
    local keys = self:Keys(action)
    for i, key in ipairs(keys) do keys[i] = GetBindingText and GetBindingText(key) or key end
    return #keys > 0 and table.concat(keys, ", ") or "Unbound"
end

function Bindings:Apply(keys, restoring, action)
    action = action or self.action
    if action ~= self.action and action ~= self.hoverAction then return false, "Unknown BagMarks shortcut." end
    if A.InCombat() then return false, "Keybindings cannot change during combat." end
    local set = GetCurrentBindingSet()
    for _, key in ipairs(keys) do
        for _, overrides in ipairs({ false, true }) do
            local existing = GetBindingAction(key, overrides)
            if existing and existing ~= "" and existing ~= action then
                return false, key .. " is already bound to " .. (GetBindingName and GetBindingName(existing) or existing) .. ". Choose another key."
            end
        end
    end
    local previous = self:Keys(action)
    local function restoreOld()
        for _, key in ipairs(self:Keys(action)) do SetBinding(key) end
        for _, key in ipairs(previous) do SetBinding(key, action) end
    end
    for _, key in ipairs(previous) do
        if not SetBinding(key) then restoreOld(); return false, "The client refused the binding change." end
    end
    for _, key in ipairs(keys) do
        if not SetBinding(key, action) then restoreOld(); return false, "The client refused this key." end
    end
    SaveBindings(set)
    if not restoring then self.history[action] = { keys = previous, set = set } end
    A.Settings:Refresh()
    return true
end

function Bindings:Restore(action)
    action = action or self.action
    local previous = self.history[action]
    if previous and previous.set ~= GetCurrentBindingSet() then
        return false, "The active binding set changed. Switch back before restoring."
    end
    return self:Apply(previous and previous.keys or {}, true, action)
end

function Bindings:StopCapture()
    if self.capture then self.capture:Hide() end
    self.captureAction = nil
    if A.Settings.frame then A.Settings:Refresh() end
end

function Bindings:StartCapture(action)
    if A.InCombat() then A.Print("Keybindings cannot change during combat."); return end
    action = action or self.action
    if action ~= self.action and action ~= self.hoverAction then return end
    self.captureAction = action
    if A.Settings.recipient then A.Settings.recipient:ClearFocus() end
    if not self.capture then
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:EnableKeyboard(true)
        frame:SetPropagateKeyboardInput(false)
        frame:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" then self:StopCapture(); return end
            if key == "LALT" or key == "RALT" or key == "LCTRL" or key == "RCTRL"
                or key == "LSHIFT" or key == "RSHIFT" or key == "LMETA" or key == "RMETA" then return end
            local chord
            if CreateKeyChordStringUsingMetaKeyState then chord = CreateKeyChordStringUsingMetaKeyState(key)
            else chord = (IsControlKeyDown() and "CTRL-" or "") .. (IsAltKeyDown() and "ALT-" or "")
                .. (IsShiftKeyDown() and "SHIFT-" or "") .. key end
            local ok, message = self:Apply({ chord }, false, self.captureAction)
            if ok then self:StopCapture() else A.Settings:SetBindingMessage(message) end
        end)
        self.capture = frame
    end
    self.capture:Show()
    A.Hover:Refresh()
    A.Settings:SetBindingMessage("Press a key or key combination. Escape cancels.")
end
