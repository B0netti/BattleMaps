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

local CONTEXT_KEYS = { "TOP", "RIGHT", "BOTTOM", "LEFT" }

local function HasText(value)
    return tostring(value or ""):match("%S") ~= nil
end

function Callouts:HasConfiguredDragContext(actionKey)
    if not actionKey or type(self.GetActionContexts) ~= "function" then return false end
    local contexts = self:GetActionContexts(actionKey)
    if type(contexts) ~= "table" then return false end
    for _, key in ipairs(CONTEXT_KEYS) do
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

-- Build secure drag policy per callout. 0/4 actions never expand the protected
-- button. For 1-4 actions, empty directions are represented by an empty macro
-- rather than silently falling back to the base callout.
local OriginalBuildCallouts = Callouts.BuildCallouts
if type(OriginalBuildCallouts) == "function" then
    function Callouts:BuildCallouts(node)
        local result = OriginalBuildCallouts(self, node)
        local settings = self:GetSettings()

        for _, actionKey in ipairs(self.ACTION_ORDER or {}) do
            local parts = self:GetBindingParts(settings.bindings and settings.bindings[actionKey])
            local prefix = parts and MODE_SECURE_PREFIX[parts.mode]
            local suffix = parts and parts.mouse and parts.mouse.suffix
            if prefix ~= nil and suffix then
                local attr = prefix .. "macrotext" .. suffix
                local contexts = self:GetActionContexts(actionKey) or {}

                if not self:HasConfiguredDragContext(actionKey) then
                    result["drag-action-" .. prefix .. suffix] = ""
                else
                    for _, contextKey in ipairs(CONTEXT_KEYS) do
                        if not HasText(contexts[contextKey]) then
                            result["drag-" .. contextKey:lower() .. "-" .. attr] = ""
                        end
                    end
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

-- Suppress the confirmation animation when the secure release selected the
-- explicit cancel outcome. The protected macro has already been blanked by
-- PreClick; this keeps the visual feedback consistent with what was sent.
local OriginalHandleSecureCalloutClick = Callouts.HandleSecureCalloutClick
if type(OriginalHandleSecureCalloutClick) == "function" then
    function Callouts:HandleSecureCalloutClick(ui, mouseButton)
        local button = ui and ui.button
        local cancelled = button and button.GetAttribute
            and button:GetAttribute("drag-release-cancelled") == 1
        if cancelled then
            ui.suppressUntil = nil
            self:SetBaseHoverSuppressed(ui, false)
            self:HideChoiceVisuals(ui)
            return
        end
        return OriginalHandleSecureCalloutClick(self, ui, mouseButton)
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

        -- Core PreClick already distinguishes a stationary click from a
        -- meaningful drag and records drag-selected-zone. This post-body turns
        -- the third state into a real secure cancel:
        --   nil  = no meaningful drag -> base click
        --   ""   = meaningful drag but no crossed edge -> cancel
        --   edge = crossed edge -> directional macro, unless that edge is blank
        -- This runs inside the secure wrapper, so cancellation works in combat.
        button:WrapScript(button, "PreClick", [[]], [[
            if down then return end
            self:SetAttribute("drag-release-cancelled", nil)
            if self:GetAttribute("drag-expanded") ~= 1 then return end

            local suffix = button == "LeftButton" and "1" or button == "RightButton" and "2" or button == "MiddleButton" and "3" or nil
            if not suffix then return end
            local prefix = SecureCmdOptionParse("[mod:alt,ctrl,shift] alt-ctrl-shift-; [mod:alt,ctrl] alt-ctrl-; [mod:alt,shift] alt-shift-; [mod:ctrl,shift] ctrl-shift-; [mod:alt] alt-; [mod:ctrl] ctrl-; [mod:shift] shift-; [] none") or "none"
            if prefix == "none" then prefix = "" end
            local attr = prefix .. "macrotext" .. suffix
            local zone = self:GetAttribute("drag-selected-zone")

            if zone == "" then
                self:SetAttribute(attr, "")
                self:SetAttribute("drag-release-cancelled", 1)
                return
            end

            if zone and zone ~= "" then
                local selectedMacro = self:GetAttribute(attr) or ""
                if selectedMacro == "" then
                    self:SetAttribute("drag-release-cancelled", 1)
                end
            end
        ]])

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
