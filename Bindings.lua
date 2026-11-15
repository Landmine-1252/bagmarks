local _, A = ...
local Bindings = { action = "BAGMARKS_TOGGLE_MODE" }
A.Bindings = Bindings
BINDING_HEADER_BAGMARKS = "BagMarks"
BINDING_NAME_BAGMARKS_TOGGLE_MODE = "Toggle Item Marking Mode"

function BagMarks_ToggleMarkingMode()
    if A.ready then A.ToggleMode() end
end

function Bindings:Keys()
    return { GetBindingKey(self.action) }
end

function Bindings:Text()
    local keys = self:Keys()
    for i, key in ipairs(keys) do keys[i] = GetBindingText and GetBindingText(key) or key end
    return #keys > 0 and table.concat(keys, ", ") or "Unbound"
end

function Bindings:Apply(keys, restoring)
    if A.InCombat() then return false, "Keybindings cannot change during combat." end
    local set = GetCurrentBindingSet()
    for _, key in ipairs(keys) do
        for _, overrides in ipairs({ false, true }) do
            local action = GetBindingAction(key, overrides)
            if action and action ~= "" and action ~= self.action then
                return false, key .. " is already bound to " .. (GetBindingName and GetBindingName(action) or action) .. ". Choose another key."
            end
        end
    end
    local previous = self:Keys()
    local function restoreOld()
        for _, key in ipairs(self:Keys()) do SetBinding(key) end
        for _, key in ipairs(previous) do SetBinding(key, self.action) end
    end
    for _, key in ipairs(previous) do
        if not SetBinding(key) then restoreOld(); return false, "The client refused the binding change." end
    end
    for _, key in ipairs(keys) do
        if not SetBinding(key, self.action) then restoreOld(); return false, "The client refused this key." end
    end
    SaveBindings(set)
    if not restoring then self.previous, self.previousSet = previous, set end
    A.Settings:Refresh()
    return true
end

function Bindings:Restore()
    if self.previousSet and self.previousSet ~= GetCurrentBindingSet() then
        return false, "The active binding set changed. Switch back before restoring."
    end
    return self:Apply(self.previous or {}, true)
end

function Bindings:StopCapture()
    if self.capture then self.capture:Hide() end
    if A.Settings.frame then A.Settings:Refresh() end
end

function Bindings:StartCapture()
    if A.InCombat() then A.Print("Keybindings cannot change during combat."); return end
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
            local ok, message = self:Apply({ chord })
            if ok then self:StopCapture() else A.Settings:SetBindingMessage(message) end
        end)
        self.capture = frame
    end
    self.capture:Show()
    A.Settings:SetBindingMessage("Press a key or key combination. Escape cancels.")
end
