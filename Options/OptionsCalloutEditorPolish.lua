local _, BattleMaps = ...
local Options = BattleMaps and BattleMaps.Options
local Callouts = BattleMaps and BattleMaps.Callouts
if not Options or not Options.Widgets or not Callouts then return end

local W = Options.Widgets
local MakeButton = W.MakeButton
local AddControlTooltip = W.AddControlTooltip
local GetTemplate = W.GetTemplate

local function FindFontStringByText(root, wanted)
    if not root then return nil end
    if root.GetRegions then
        for _, region in ipairs({ root:GetRegions() }) do
            if region and region.GetText and region:GetText() == wanted then
                return region
            end
        end
    end
    if root.GetChildren then
        for _, child in ipairs({ root:GetChildren() }) do
            local found = FindFontStringByText(child, wanted)
            if found then return found end
        end
    end
end

local function ShowBindingTooltip(owner)
    if not GameTooltip or not owner then return end
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
    GameTooltip:SetText("Current callout binding", 1.00, 0.82, 0.40)
    GameTooltip:AddLine("Click to change this callout's mouse + modifier binding.", 0.90, 0.90, 0.90, true)
    GameTooltip:Show()
end

local function HideBindingTooltip(owner)
    if GameTooltip and GameTooltip:GetOwner() == owner then GameTooltip:Hide() end
end

local function EnsureBindingDialog()
    if Options.calloutBindingDialog then return Options.calloutBindingDialog end

    local dialog = CreateFrame("Frame", "BattleMapsCalloutBindingDialog", UIParent)
    dialog:SetAllPoints(UIParent)
    dialog:SetFrameStrata("TOOLTIP")
    dialog:SetFrameLevel(1900)
    dialog:EnableMouse(true)
    dialog:Hide()

    local shade = dialog:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.46)

    local panel = CreateFrame("Frame", nil, dialog, GetTemplate())
    panel:SetSize(470, 238)
    panel:SetPoint("CENTER", Options.frame or UIParent, "CENTER", 0, 12)
    panel:SetFrameLevel(dialog:GetFrameLevel() + 2)
    panel:EnableMouse(true)
    if panel.SetBackdrop then
        panel:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        panel:SetBackdropColor(0.018, 0.015, 0.012, 0.99)
        panel:SetBackdropBorderColor(0.68, 0.47, 0.24, 1)
    end
    dialog.panel = panel

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -16)
    title:SetTextColor(1.00, 0.45, 0.24, 1)
    dialog.title = title

    local status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -52)
    status:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, -52)
    status:SetJustifyH("CENTER")
    status:SetTextColor(0.84, 0.82, 0.78, 1)
    dialog.status = status

    local capture = CreateFrame("Button", nil, panel, GetTemplate())
    capture:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -76)
    capture:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, -76)
    capture:SetHeight(74)
    capture:RegisterForClicks("LeftButtonDown", "RightButtonDown", "MiddleButtonDown")
    if capture.SetBackdrop then
        capture:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        capture:SetBackdropColor(0.055, 0.045, 0.035, 0.92)
        capture:SetBackdropBorderColor(0.55, 0.40, 0.23, 0.95)
    end
    dialog.capture = capture

    local bindingText = capture:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    bindingText:SetPoint("CENTER", capture, "CENTER", 0, 10)
    bindingText:SetTextColor(1.00, 0.84, 0.48, 1)
    dialog.bindingText = bindingText

    local hint = capture:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOM", capture, "BOTTOM", 0, 8)
    hint:SetText("PRESS THE DESIRED MOUSE + MODIFIER COMBINATION HERE")
    hint:SetTextColor(0.62, 0.60, 0.56, 1)

    local conflict = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    conflict:SetPoint("TOPLEFT", capture, "BOTTOMLEFT", 2, -6)
    conflict:SetPoint("TOPRIGHT", capture, "BOTTOMRIGHT", -2, -6)
    conflict:SetJustifyH("CENTER")
    conflict:SetTextColor(1.00, 0.34, 0.24, 1)
    dialog.conflict = conflict

    local clear = MakeButton(panel, "Clear Binding", 112, 24)
    clear:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 20, 16)
    dialog.clear = clear

    local cancel = MakeButton(panel, "Cancel", 92, 24)
    cancel:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -118, 16)
    dialog.cancel = cancel

    local save = MakeButton(panel, "Save", 92, 24)
    save:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -20, 16)
    dialog.save = save

    local function Refresh()
        if not dialog.actionKey then return end
        local binding = dialog.pendingBinding or "UNBOUND"
        local label = Callouts:GetBindingLabel(binding)
        bindingText:SetText(label)

        local current = Callouts:GetActionBinding(dialog.actionKey)
        local changed = Callouts:NormalizeBinding(binding) ~= Callouts:NormalizeBinding(current)
        local conflictKey = Callouts:GetBindingConflict(dialog.actionKey, binding)
        if conflictKey then
            conflict:SetText(string.format(
                "%s already uses this gesture. Saving will move it here.",
                Callouts.ACTION_LABELS[conflictKey] or conflictKey
            ))
            status:SetText("Captured: " .. label)
            status:SetTextColor(1.00, 0.62, 0.28, 1)
        elseif binding == "UNBOUND" then
            conflict:SetText("")
            status:SetText(changed and "Binding cleared — Save to apply." or "Unbound")
            status:SetTextColor(1.00, 0.82, 0.40, 1)
        else
            conflict:SetText("")
            status:SetText((changed and "Captured: " or "Current: ") .. label)
            status:SetTextColor(changed and 0.42 or 0.84, changed and 1.00 or 0.82, changed and 0.52 or 0.78, 1)
        end
    end

    capture:SetScript("OnMouseDown", function(_, mouseButton)
        local binding = Callouts:GetBindingFromMouseButton(mouseButton)
        if not binding then return end
        dialog.pendingBinding = binding
        Refresh()
        if capture.SetBackdropBorderColor then
            capture:SetBackdropBorderColor(0.36, 0.88, 0.42, 1)
        end
    end)

    clear:SetScript("OnClick", function()
        dialog.pendingBinding = "UNBOUND"
        Refresh()
    end)
    cancel:SetScript("OnClick", function() dialog:Hide() end)
    save:SetScript("OnClick", function()
        if not dialog.actionKey then return end
        if InCombatLockdown and InCombatLockdown() then
            if BattleMaps.Chat then BattleMaps.Chat("Callout settings can only be changed out of combat.") end
            return
        end
        local binding = dialog.pendingBinding or Callouts:GetActionBinding(dialog.actionKey)
        if not Callouts:SetActionBinding(dialog.actionKey, binding, true) then return end
        Options:Refresh()
        dialog:Hide()
    end)

    dialog:SetScript("OnMouseDown", function(self)
        if panel.IsMouseOver and not panel:IsMouseOver() then self:Hide() end
    end)
    dialog:SetScript("OnHide", function(self)
        self.actionKey = nil
        self.pendingBinding = nil
        if capture.SetBackdropBorderColor then
            capture:SetBackdropBorderColor(0.55, 0.40, 0.23, 0.95)
        end
    end)

    dialog.Open = function(self, actionKey)
        if InCombatLockdown and InCombatLockdown() then
            if BattleMaps.Chat then BattleMaps.Chat("Callout settings can only be changed out of combat.") end
            return
        end
        self.actionKey = actionKey
        self.pendingBinding = Callouts:GetActionBinding(actionKey)
        self.title:SetText("Change binding: " .. (Callouts.ACTION_LABELS[actionKey] or actionKey))
        self.panel:ClearAllPoints()
        self.panel:SetPoint("CENTER", Options.frame or UIParent, "CENTER", 0, 12)
        self:Show()
        if self.Raise then self:Raise() end
        Refresh()
    end

    Options.calloutBindingDialog = dialog
    return dialog
end

local function EnsureCompassGuide(dialog)
    if dialog.contextCompassGuide then return dialog.contextCompassGuide end
    local panel = dialog.panel
    if not panel then return nil end

    local guide = CreateFrame("Frame", nil, panel, GetTemplate())
    guide:SetSize(160, 112)
    guide:SetPoint("TOPLEFT", panel, "TOPLEFT", 225, -300)
    guide:SetFrameLevel(panel:GetFrameLevel() + 1)
    guide:EnableMouse(false)

    local mapShape = CreateFrame("Frame", nil, guide, GetTemplate())
    mapShape:SetSize(96, 58)
    mapShape:SetPoint("CENTER")
    if mapShape.SetBackdrop then
        mapShape:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        mapShape:SetBackdropColor(0.10, 0.085, 0.065, 0.70)
        mapShape:SetBackdropBorderColor(0.58, 0.42, 0.24, 0.85)
    end

    local specs = {
        { text = "↑", point = "TOP", x = 0, y = -3 },
        { text = "→", point = "RIGHT", x = -4, y = 0 },
        { text = "↓", point = "BOTTOM", x = 0, y = 3 },
        { text = "←", point = "LEFT", x = 4, y = 0 },
    }
    for _, spec in ipairs(specs) do
        local arrow = guide:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        arrow:SetPoint(spec.point, guide, spec.point, spec.x, spec.y)
        arrow:SetText(spec.text)
        arrow:SetTextColor(1.00, 0.72, 0.28, 0.92)
    end

    dialog.contextCompassGuide = guide
    return guide
end

local function ApplyMacroEditorLayout()
    local dialog = Options.calloutEditorDialog
    if not dialog or not dialog.panel then return end
    local panel = dialog.panel

    -- Binding now has its own compact editor, opened by clicking the current
    -- binding visual on the Callouts page.
    if dialog.capture then dialog.capture:Hide() end
    if dialog.bindingStatus then dialog.bindingStatus:Hide() end
    if dialog.conflict then dialog.conflict:Hide() end
    if dialog.clearBinding then dialog.clearBinding:Hide() end
    local bindingLabel = FindFontStringByText(panel, "Binding")
    if bindingLabel then bindingLabel:Hide() end

    panel:SetSize(610, 520)

    local macroLabel = FindFontStringByText(panel, "Macro")
    if macroLabel then
        macroLabel:ClearAllPoints()
        macroLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -56)
    end
    if dialog.tokenHelp and macroLabel then
        dialog.tokenHelp:ClearAllPoints()
        dialog.tokenHelp:SetPoint("LEFT", macroLabel, "RIGHT", 8, 0)
    end

    if dialog.editorFrame then
        dialog.editorFrame:ClearAllPoints()
        dialog.editorFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -82)
        dialog.editorFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, -82)
        dialog.editorFrame:SetHeight(122)
    end
    if dialog.count and dialog.editorFrame then
        dialog.count:ClearAllPoints()
        dialog.count:SetPoint("BOTTOMRIGHT", dialog.editorFrame, "TOPRIGHT", -2, 4)
    end

    if dialog.contextLabel then
        dialog.contextLabel:ClearAllPoints()
        dialog.contextLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -224)
    end
    if dialog.contextHint and dialog.contextLabel then
        dialog.contextHint:ClearAllPoints()
        dialog.contextHint:SetPoint("LEFT", dialog.contextLabel, "RIGHT", 10, 0)
    end

    local placements = {
        TOP = { x = 220, y = -267, labelX = 220, labelY = -249 },
        LEFT = { x = 28, y = -350, labelX = 28, labelY = -332 },
        RIGHT = { x = 412, y = -350, labelX = 412, labelY = -332 },
        BOTTOM = { x = 220, y = -433, labelX = 220, labelY = -415 },
    }
    local labelNames = { TOP = "Top", RIGHT = "Right", BOTTOM = "Bottom", LEFT = "Left" }
    for key, edit in pairs(dialog.contextEdits or {}) do
        local placement = placements[key]
        if placement and edit then
            edit:ClearAllPoints()
            edit:SetPoint("TOPLEFT", panel, "TOPLEFT", placement.x, placement.y)
            edit:SetSize(170, 26)
        end
        local label = FindFontStringByText(panel, labelNames[key])
        if placement and label then
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", panel, "TOPLEFT", placement.labelX, placement.labelY)
            label:SetWidth(170)
            label:SetJustifyH("CENTER")
        end
    end

    EnsureCompassGuide(dialog)

    -- Restore Default in this dialog should now affect macro + context only;
    -- bindings have their own editor and should never change as a side effect.
    if dialog.defaults and not dialog.defaults.BattleMapsMacroOnlyDefaults then
        dialog.defaults.BattleMapsMacroOnlyDefaults = true
        dialog.defaults:SetScript("OnClick", function()
            if not dialog.actionKey then return end
            local actionKey = dialog.actionKey
            local label = Callouts.ACTION_LABELS[actionKey] or actionKey
            BattleMaps.ConfirmReset(
                "Restore " .. tostring(label) .. " macro defaults",
                "Replace the pending macro and edge-context strings with the BattleMaps defaults. The binding is unchanged. The change is not applied until you press Save.",
                function()
                    if dialog.actionKey ~= actionKey then return end
                    dialog.editBox:SetText(Callouts.DEFAULTS.macros[actionKey] or "")
                    local defaultsContext = Callouts.DEFAULTS.contexts and Callouts.DEFAULTS.contexts[actionKey] or {}
                    for key, contextEdit in pairs(dialog.contextEdits or {}) do
                        contextEdit:SetText(tostring(defaultsContext[key] or ""))
                    end
                end,
                "Restore"
            )
        end)
    end
end

local OriginalCreateCalloutsPage = Options.CreateCalloutsPage
if type(OriginalCreateCalloutsPage) ~= "function" then return end

function Options:CreateCalloutsPage(parent)
    OriginalCreateCalloutsPage(self, parent)

    for _, row in ipairs(self.calloutActionRows or {}) do
        local actionKey = row.actionKey
        local visual = row.bindingVisual
        if actionKey and visual then
            visual:EnableMouse(true)
            visual:SetScript("OnMouseUp", function(_, button)
                if button ~= "LeftButton" or visual.BattleMapsEnabled == false then return end
                HideBindingTooltip(visual)
                EnsureBindingDialog():Open(actionKey)
            end)
            visual:SetScript("OnEnter", ShowBindingTooltip)
            visual:SetScript("OnLeave", HideBindingTooltip)

            local oldSetControlEnabled = row.SetControlEnabled
            row.SetControlEnabled = function(self, enabled)
                if oldSetControlEnabled then oldSetControlEnabled(self, enabled) end
                enabled = enabled == true
                visual.BattleMapsEnabled = enabled
                visual:EnableMouse(enabled)
            end
            visual.BattleMapsEnabled = Callouts:GetSettings().enabled ~= false

            local cog = row.calloutCog
            if cog then
                local oldCogClick = cog:GetScript("OnClick")
                cog:SetScript("OnClick", function(...)
                    if oldCogClick then oldCogClick(...) end
                    ApplyMacroEditorLayout()
                end)
                cog:SetScript("OnEnter", function(owner)
                    if not GameTooltip then return end
                    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Edit callout", 1.00, 0.82, 0.40)
                    GameTooltip:AddLine("Edit this callout's macro and directional edge-context text.", 0.90, 0.90, 0.90, true)
                    GameTooltip:Show()
                end)
                cog:SetScript("OnLeave", function(owner)
                    if GameTooltip and GameTooltip:GetOwner() == owner then GameTooltip:Hide() end
                end)
            end
        end
    end
end
