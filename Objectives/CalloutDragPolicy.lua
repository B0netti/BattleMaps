local _, BattleMaps = ...
BattleMaps = BattleMaps or _G.BattleMaps
if not BattleMaps or not BattleMaps.Callouts then return end

local Callouts = BattleMaps.Callouts

-- Edge dragging is an action-level capability. A callout with no configured
-- directional strings should behave exactly like the pre-swipe click: leaving
-- the source node unpresses/cancels it, and releasing away does not commit.
local MODE_SECURE_PREFIX = {
    NONE = "",
    ALT = "alt-",
    SHIFT = "shift-",
    CTRL = "ctrl-",
    ALT_SHIFT = "alt-shift-",
    ALT_CTRL = "alt-ctrl-",
    CTRL_SHIFT = "ctrl-shift-",
    ALT_CTRL_SHIFT = "alt-ctrl-shift-",
}

local function HasText(value)
    return tostring(value or ""):match("%S") ~= nil
end

function Callouts:HasConfiguredDragContext(actionKey)
    if not actionKey or type(self.GetActionContexts) ~= "function" then return false end
    local contexts = self:GetActionContexts(actionKey)
    if type(contexts) ~= "table" then return false end
    for _, key in ipairs({ "TOP", "RIGHT", "BOTTOM", "LEFT" }) do
        if HasText(contexts[key]) then return true end
    end
    return false
end

function Callouts:IsDirectionalDragActive(actionKey)
    return self:GetSettings().dragContextEnabled ~= false
        and self:HasConfiguredDragContext(actionKey)
end

-- Preview presentation follows the same arming rules as the click itself.
-- Swipe-capable callouts remain armed after leaving the source node; classic
-- 0/4 callouts are armed only while the pointer is still over the node.
function Callouts:IsHeldPreviewArmed(ui)
    if not ui or ui.pressActive ~= true then return false end
    if self:IsDirectionalDragActive(ui.pressActionKey) then return true end
    return ui.pressInside == true
end

-- The secure mouse-down snippet expands the protected button to $screen only
-- when drag-action-* contains an action. Clear that marker for 0/4 callouts so
-- the button retains its ordinary node-sized hit area and native click-cancel
-- semantics throughout combat as well.
local OriginalBuildCallouts = Callouts.BuildCallouts
if type(OriginalBuildCallouts) == "function" then
    function Callouts:BuildCallouts(node)
        local result = OriginalBuildCallouts(self, node)
        local settings = self:GetSettings()
        for _, actionKey in ipairs(self.ACTION_ORDER or {}) do
            if not self:HasConfiguredDragContext(actionKey) then
                local parts = self:GetBindingParts(settings.bindings and settings.bindings[actionKey])
                local prefix = parts and MODE_SECURE_PREFIX[parts.mode]
                local suffix = parts and parts.mouse and parts.mouse.suffix
                if prefix ~= nil and suffix then
                    result["drag-action-" .. prefix .. suffix] = ""
                end
            end
        end
        return result
    end
end

-- The core held-state updater intentionally keeps swipe-capable actions armed
-- after OnLeave. For classic actions, force the visible button back to its
-- unpressed/hidden state while the pointer is outside the source node.
local OriginalSetPressedState = Callouts.SetPressedState
if type(OriginalSetPressedState) == "function" then
    function Callouts:SetPressedState(ui, pressed, mouseButton)
        local classicOutside = pressed == true
            and ui
            and ui.pressActive == true
            and ui.pressInside == false
            and not self:IsDirectionalDragActive(ui.pressActionKey)

        if classicOutside then
            OriginalSetPressedState(self, ui, false, mouseButton)
            local visual = ui.visuals and ui.visuals[mouseButton]
            if visual and not visual.animationBusy then visual:Hide() end
            return
        end
        return OriginalSetPressedState(self, ui, pressed, mouseButton)
    end
end

local OriginalSetBaseHoverSuppressed = Callouts.SetBaseHoverSuppressed
if type(OriginalSetBaseHoverSuppressed) == "function" then
    function Callouts:SetBaseHoverSuppressed(ui, suppressed)
        if suppressed == true
            and ui
            and ui.pressActive == true
            and ui.pressInside == false
            and not self:IsDirectionalDragActive(ui.pressActionKey) then
            suppressed = false
        end
        return OriginalSetBaseHoverSuppressed(self, ui, suppressed)
    end
end

-- Track classic leave/re-enter explicitly. Setting pressOriginated=false on
-- leave is the final guard against the existing PostClick path treating an
-- off-node release as a deliberate drag commit. Re-entering while still held
-- restores the original normal-button behavior.
local OriginalCreateNodeUI = Callouts.CreateNodeUI
if type(OriginalCreateNodeUI) == "function" then
    function Callouts:CreateNodeUI(node, index)
        local ui = OriginalCreateNodeUI(self, node, index)
        local button = ui and ui.button
        if not button then return ui end

        button:HookScript("OnLeave", function()
            if not ui.pressActive or self:IsDirectionalDragActive(ui.pressActionKey) then return end
            ui.pressInside = false
            ui.pressOriginated = false
            self:SetPressedState(ui, false, ui.pressButton)
            self:SetBaseHoverSuppressed(ui, false)
            self:HideChoiceVisuals(ui)
            self:HideHeldPreview()
            self:HideDragContextOverlay()
            if type(self.HideSelectedPreview) == "function" then self:HideSelectedPreview() end
        end)

        button:HookScript("OnEnter", function()
            if not ui.pressActive or self:IsDirectionalDragActive(ui.pressActionKey) then return end
            ui.pressInside = true
            ui.pressOriginated = true
            local visual = ui.visuals and ui.visuals[ui.pressButton]
            if visual and ui.pressActionKey then
                self:SetChoiceAction(visual, ui.pressActionKey)
                self:HideChoiceVisuals(ui, visual)
                self:SetBaseHoverSuppressed(ui, true)
                self:SetPressedState(ui, true, ui.pressButton)
            end
            if type(self.ShowSelectedPreview) == "function" then self:ShowSelectedPreview(ui) end
        end)

        return ui
    end
end
