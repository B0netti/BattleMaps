local _, BattleMaps = ...
local Options = BattleMaps and BattleMaps.Options
local Callouts = BattleMaps and BattleMaps.Callouts
if not Options or not Options.Widgets or not Callouts then return end

local W = Options.Widgets
local MakeButton = W.MakeButton
local MakeCheckbox = W.MakeCheckbox
local MakePanel = W.MakePanel
local MakeSlider = W.MakeSlider
local MakeDropdown = W.MakeDropdown
local MakeResetIconButton = W.MakeResetIconButton
local SetControlEnabled = W.SetControlEnabled
local AddControlTooltip = W.AddControlTooltip
local GetTemplate = W.GetTemplate

local MOUSE_ATLAS_CANDIDATES = {
    BUTTON1 = {
        "plunderstorm-pickup-mouseclick-left",
    },
    BUTTON2 = {
        "plunderstorm-pickup-mouseclick-right",
    },
    BUTTON3 = {
        "plunderstorm-pickup-mouseclick-middle",
        "plunderstorm-pickup-mouseclick-center",
    },
}

local MODIFIER_LABELS = {
    ALT = "ALT",
    CTRL = "CTRL",
    SHIFT = "SHIFT",
}

local MODIFIER_TEXTURES = {
    ALT = { path = "Interface\\AddOns\\BattleMaps\\Media\\Callouts\\Modifiers\\alt.tga", aspect = 1.50 },
    CTRL = { path = "Interface\\AddOns\\BattleMaps\\Media\\Callouts\\Modifiers\\ctrl.tga", aspect = 2.00 },
    SHIFT = { path = "Interface\\AddOns\\BattleMaps\\Media\\Callouts\\Modifiers\\shift.tga", aspect = 2.50 },
}

local function TrySetAtlas(texture, candidates)
    if not texture or type(texture.SetAtlas) ~= "function" then return false end
    for _, atlas in ipairs(candidates or {}) do
        -- SetAtlas() is permissive on some clients, so verify the atlas exists
        -- first when Blizzard exposes atlas metadata. This prevents a missing
        -- RMB/MMB candidate from being treated as a successful blank texture.
        local exists = true
        if C_Texture and type(C_Texture.GetAtlasInfo) == "function" then
            local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
            exists = ok and info ~= nil
        end
        if exists then
            local ok = pcall(texture.SetAtlas, texture, atlas, false)
            if ok then return true end
        end
    end
    return false
end

local function MakeKeycap(parent)
    local frame = CreateFrame("Frame", nil, parent, GetTemplate())
    frame:SetHeight(20)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        frame:SetBackdropColor(0.018, 0.015, 0.012, 0.98)
        frame:SetBackdropBorderColor(0.66, 0.49, 0.28, 0.92)
    end
    local text = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    text:SetTextColor(1.00, 0.83, 0.47, 1)
    frame.text = text
    return frame
end

local function MakeBindingVisual(parent, width, height, large)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, height)

    holder.modifierTextures = {}
    holder.keycaps = {}
    for index = 1, 3 do
        local modifierTexture = holder:CreateTexture(nil, "ARTWORK")
        modifierTexture:Hide()
        holder.modifierTextures[index] = modifierTexture

        -- Retain the generated keycap as a fallback if a custom texture is unavailable.
        local keycap = MakeKeycap(holder)
        keycap:Hide()
        holder.keycaps[index] = keycap
    end

    local mouse = holder:CreateTexture(nil, "ARTWORK")
    mouse:SetSize(large and 42 or 25, large and 42 or 25)
    holder.mouse = mouse

    local mouseFallback = MakeKeycap(holder)
    mouseFallback:SetHeight(large and 26 or 20)
    holder.mouseFallback = mouseFallback

    local unbound = holder:CreateFontString(nil, "ARTWORK", large and "GameFontNormal" or "GameFontNormalSmall")
    unbound:SetPoint("CENTER", holder, "CENTER", 0, 0)
    unbound:SetText("Unbound")
    unbound:SetTextColor(0.62, 0.62, 0.62, 1)
    holder.unbound = unbound

    holder.RefreshBinding = function(self, binding)
        local parts = Callouts:GetBindingParts(binding)
        for _, texture in ipairs(self.modifierTextures) do texture:Hide() end
        for _, keycap in ipairs(self.keycaps) do keycap:Hide() end
        self.mouse:Hide()
        self.mouseFallback:Hide()
        self.unbound:Hide()

        if not parts.mouseToken then
            self.unbound:Show()
            return
        end

        local x = 0
        local modifierHeight = large and 28 or 18
        local modifierGap = large and 5 or 3
        for index, modifier in ipairs(parts.modifiers or {}) do
            local info = MODIFIER_TEXTURES[modifier]
            local texture = self.modifierTextures[index]
            if info and texture then
                local widthForKey = math.floor((modifierHeight * info.aspect) + 0.5)
                texture:SetTexture(info.path)
                texture:SetSize(widthForKey, modifierHeight)
                texture:ClearAllPoints()
                texture:SetPoint("LEFT", self, "LEFT", x, 0)
                texture:SetVertexColor(1, 1, 1, 1)
                texture:Show()
                x = x + widthForKey + modifierGap
            else
                local keycap = self.keycaps[index]
                if keycap then
                    local text = MODIFIER_LABELS[modifier] or modifier
                    local widthForKey = large and (modifier == "SHIFT" and 54 or 48)
                        or (modifier == "SHIFT" and 45 or modifier == "CTRL" and 36 or 27)
                    keycap:SetWidth(widthForKey)
                    keycap.text:SetText(text)
                    keycap:ClearAllPoints()
                    keycap:SetPoint("LEFT", self, "LEFT", x, 0)
                    keycap:Show()
                    x = x + widthForKey + modifierGap
                end
            end
        end

        local mouseSize = large and 42 or 25
        self.mouse:SetSize(mouseSize, mouseSize)
        self.mouse:ClearAllPoints()
        self.mouse:SetPoint("LEFT", self, "LEFT", x, 0)
        self.mouse:SetTexture(nil)
        local atlasSet = TrySetAtlas(self.mouse, MOUSE_ATLAS_CANDIDATES[parts.mouseToken])
        if atlasSet then
            self.mouse:SetVertexColor(1, 1, 1, 1)
            self.mouse:Show()
        else
            local fallbackWidth = large and 54 or 35
            self.mouseFallback:SetWidth(fallbackWidth)
            self.mouseFallback.text:SetText((parts.mouse and parts.mouse.short) or parts.mouseToken)
            self.mouseFallback:ClearAllPoints()
            self.mouseFallback:SetPoint("LEFT", self, "LEFT", x, 0)
            self.mouseFallback:Show()
        end
    end

    return holder
end

local function MakeTokenHelpButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(22, 22)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    local atlasSet = TrySetAtlas(icon, { "common-icon-alert" })
    if not atlasSet then
        icon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
    end
    button.icon = icon

    button:SetScript("OnEnter", function(owner)
        if not GameTooltip then return end
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText("Macro substitutions", 1.00, 0.82, 0.40)
        GameTooltip:AddLine("[node]", 1, 1, 1)
        GameTooltip:AddLine("Uses the abbreviated objective name, for example BS.", 0.86, 0.86, 0.86, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("[node_full]", 1, 1, 1)
        GameTooltip:AddLine("Uses the full objective name, for example Blacksmith.", 0.86, 0.86, 0.86, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("[context]", 1, 1, 1)
        GameTooltip:AddLine("Uses the text configured for the triggered edge on this callout. If omitted, BattleMaps automatically appends that edge context to the first chat line.", 0.86, 0.86, 0.86, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("/instance INC [node]  ->  /instance INC BS", 0.72, 0.92, 1.00, true)
        GameTooltip:AddLine("/instance INC [node_full]  ->  /instance INC Blacksmith", 0.72, 0.92, 1.00, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(owner)
        if GameTooltip and GameTooltip:GetOwner() == owner then GameTooltip:Hide() end
    end)
    return button
end

local function EnsureCalloutEditorDialog()
    if Options.calloutEditorDialog then return Options.calloutEditorDialog end

    local dialog = CreateFrame("Frame", "BattleMapsCalloutEditorDialog", UIParent)
    dialog:SetAllPoints(UIParent)
    dialog:SetFrameStrata("TOOLTIP")
    dialog:SetFrameLevel(1800)
    dialog:EnableMouse(true)
    dialog:Hide()

    local shade = dialog:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.46)

    local panel = CreateFrame("Frame", nil, dialog, GetTemplate())
    panel:SetSize(610, 520)
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

    local bindingLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    bindingLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -56)
    bindingLabel:SetText("Binding")
    bindingLabel:SetTextColor(1.00, 0.82, 0.40, 1)

    local bindingStatus = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bindingStatus:SetPoint("LEFT", bindingLabel, "RIGHT", 12, 0)
    bindingStatus:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
    bindingStatus:SetJustifyH("LEFT")
    bindingStatus:SetTextColor(0.84, 0.82, 0.78, 1)
    dialog.bindingStatus = bindingStatus

    local capture = CreateFrame("Button", nil, panel, GetTemplate())
    capture:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -82)
    capture:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, -82)
    capture:SetHeight(76)
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

    local bindingVisual = MakeBindingVisual(capture, 360, 50, true)
    bindingVisual:SetPoint("CENTER", capture, "CENTER", 0, 5)
    dialog.bindingVisual = bindingVisual

    local captureHint = capture:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    captureHint:SetPoint("BOTTOM", capture, "BOTTOM", 0, 6)
    captureHint:SetText("PRESS THE DESIRED MOUSE + MODIFIER COMBINATION HERE")
    captureHint:SetTextColor(0.62, 0.60, 0.56, 1)

    local conflict = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    conflict:SetPoint("TOPLEFT", capture, "BOTTOMLEFT", 2, -6)
    conflict:SetPoint("TOPRIGHT", capture, "BOTTOMRIGHT", -2, -6)
    conflict:SetJustifyH("CENTER")
    conflict:SetTextColor(1.00, 0.34, 0.24, 1)
    conflict:SetText("")
    dialog.conflict = conflict

    local macroLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    macroLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -184)
    macroLabel:SetText("Macro")
    macroLabel:SetTextColor(1.00, 0.82, 0.40, 1)

    local tokenHelp = MakeTokenHelpButton(panel)
    tokenHelp:SetPoint("LEFT", macroLabel, "RIGHT", 8, 0)
    dialog.tokenHelp = tokenHelp

    local editorFrame = CreateFrame("Frame", nil, panel, GetTemplate())
    editorFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -210)
    editorFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, -210)
    editorFrame:SetHeight(122)
    if editorFrame.SetBackdrop then
        editorFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        editorFrame:SetBackdropColor(0.035, 0.030, 0.025, 0.96)
        editorFrame:SetBackdropBorderColor(0.48, 0.36, 0.23, 0.95)
    end
    dialog.editorFrame = editorFrame

    local scroll = CreateFrame("ScrollFrame", nil, editorFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", editorFrame, "TOPLEFT", 10, -10)
    scroll:SetPoint("BOTTOMRIGHT", editorFrame, "BOTTOMRIGHT", -28, 10)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    editBox:SetTextInsets(2, 2, 2, 2)
    editBox:SetWidth(520)
    editBox:SetHeight(104)
    editBox:SetMaxLetters(Callouts:GetMaxMacroTemplateLength())
    editBox:SetJustifyH("LEFT")
    editBox:SetJustifyV("TOP")
    scroll:SetScrollChild(editBox)
    dialog.editBox = editBox

    local count = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    count:SetPoint("BOTTOMRIGHT", editorFrame, "TOPRIGHT", -2, 4)
    count:SetTextColor(0.64, 0.62, 0.58, 1)
    dialog.count = count

    local contextLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    contextLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -348)
    contextLabel:SetText("Edge context")
    contextLabel:SetTextColor(1.00, 0.82, 0.40, 1)
    dialog.contextLabel = contextLabel

    local contextHint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    contextHint:SetPoint("LEFT", contextLabel, "RIGHT", 10, 0)
    contextHint:SetText("Per-callout text added by each edge swipe. Blank = no context.")
    contextHint:SetTextColor(0.62, 0.60, 0.56, 1)
    dialog.contextHint = contextHint

    local function MakeContextInput(labelText, x, y)
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y - 3)
        label:SetWidth(50)
        label:SetJustifyH("LEFT")
        label:SetText(labelText)
        label:SetTextColor(0.86, 0.84, 0.80, 1)

        local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        edit:SetPoint("TOPLEFT", panel, "TOPLEFT", x + 54, y + 2)
        edit:SetSize(198, 26)
        edit:SetAutoFocus(false)
        edit:SetMaxLetters(Callouts:GetMaxContextStringLength())
        edit:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
        edit:SetTextInsets(5, 5, 0, 0)
        edit:SetJustifyH("LEFT")
        edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        AddControlTooltip(edit, labelText .. " edge context",
            "This text is used only for this callout when the held gesture crosses the " .. labelText:lower() .. " edge. Leave it blank to add nothing for that edge.")
        return edit
    end

    dialog.contextEdits = {
        TOP = MakeContextInput("Top", 22, -376),
        RIGHT = MakeContextInput("Right", 307, -376),
        BOTTOM = MakeContextInput("Bottom", 22, -414),
        LEFT = MakeContextInput("Left", 307, -414),
    }

    local clearBinding = MakeButton(panel, "Clear Binding", 112, 24)
    clearBinding:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 20, 16)
    dialog.clearBinding = clearBinding

    local defaults = MakeButton(panel, "Restore Default", 118, 24)
    defaults:SetPoint("LEFT", clearBinding, "RIGHT", 8, 0)
    dialog.defaults = defaults

    local cancel = MakeButton(panel, "Cancel", 92, 24)
    cancel:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -118, 16)
    dialog.cancel = cancel

    local save = MakeButton(panel, "Save", 92, 24)
    save:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -20, 16)
    dialog.save = save

    local function RefreshCount()
        local text = editBox:GetText() or ""
        local maximum = Callouts:GetMaxMacroTemplateLength()
        count:SetText(string.format("%d / %d", #text, maximum))
    end

    local function RefreshBinding()
        if not dialog.actionKey then return end
        local binding = dialog.pendingBinding or "UNBOUND"
        bindingVisual:RefreshBinding(binding)
        local conflictKey = Callouts:GetBindingConflict(dialog.actionKey, binding)
        dialog.conflictKey = conflictKey
        local currentBinding = Callouts:GetActionBinding(dialog.actionKey)
        local changed = Callouts:NormalizeBinding(binding) ~= Callouts:NormalizeBinding(currentBinding)

        if conflictKey then
            conflict:SetText(string.format(
                "%s already uses this gesture. Saving will move the binding to this callout.",
                Callouts.ACTION_LABELS[conflictKey] or conflictKey
            ))
            bindingStatus:SetText("Captured: " .. Callouts:GetBindingLabel(binding))
            bindingStatus:SetTextColor(1.00, 0.62, 0.28, 1)
            save:SetText("Save")
        elseif binding == "UNBOUND" then
            conflict:SetText("")
            bindingStatus:SetText(changed and "Binding cleared — Save to apply." or "Unbound")
            bindingStatus:SetTextColor(1.00, 0.82, 0.40, 1)
            save:SetText("Save")
        else
            conflict:SetText("")
            bindingStatus:SetText((changed and "Captured: " or "Current: ") .. Callouts:GetBindingLabel(binding))
            bindingStatus:SetTextColor(changed and 0.42 or 0.84, changed and 1.00 or 0.82, changed and 0.52 or 0.78, 1)
            save:SetText("Save")
        end
    end
    dialog.RefreshBinding = RefreshBinding

    capture:SetScript("OnMouseDown", function(_, mouseButton)
        local binding = Callouts:GetBindingFromMouseButton(mouseButton)
        if not binding then return end
        dialog.pendingBinding = binding
        RefreshBinding()
        if capture.SetBackdropBorderColor then
            capture:SetBackdropBorderColor(0.36, 0.88, 0.42, 1)
        end
    end)

    editBox:SetScript("OnTextChanged", RefreshCount)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        dialog:Hide()
    end)

    clearBinding:SetScript("OnClick", function()
        dialog.pendingBinding = "UNBOUND"
        RefreshBinding()
    end)

    defaults:SetScript("OnClick", function()
        if not dialog.actionKey then return end
        local actionKey = dialog.actionKey
        local label = Callouts.ACTION_LABELS[actionKey] or actionKey
        BattleMaps.ConfirmReset(
            "Restore " .. tostring(label) .. " defaults",
            "Replace the pending binding, macro, and edge-context strings with the BattleMaps defaults. The change is not applied until you press Save.",
            function()
                if dialog.actionKey ~= actionKey then return end
                dialog.pendingBinding = Callouts.DEFAULTS.bindings[actionKey] or "UNBOUND"
                editBox:SetText(Callouts.DEFAULTS.macros[actionKey] or "")
                local defaultsContext = Callouts.DEFAULTS.contexts and Callouts.DEFAULTS.contexts[actionKey] or {}
                for key, contextEdit in pairs(dialog.contextEdits or {}) do
                    contextEdit:SetText(tostring(defaultsContext[key] or ""))
                end
                RefreshBinding()
                RefreshCount()
            end,
            "Restore"
        )
    end)

    cancel:SetScript("OnClick", function() dialog:Hide() end)

    save:SetScript("OnClick", function()
        if not dialog.actionKey then return end
        local actionKey = dialog.actionKey
        if InCombatLockdown and InCombatLockdown() then
            if BattleMaps.Chat then BattleMaps.Chat("Callout settings can only be changed out of combat.") end
            return
        end

        local binding = dialog.pendingBinding or Callouts:GetActionBinding(actionKey)
        local ok = Callouts:SetActionBinding(actionKey, binding, true)
        if not ok then return end
        if not Callouts:SetMacroTemplate(actionKey, editBox:GetText()) then return end
        local contextValues = {}
        for key, contextEdit in pairs(dialog.contextEdits or {}) do
            contextValues[key] = contextEdit:GetText() or ""
        end
        if not Callouts:SetActionContexts(actionKey, contextValues) then return end

        Options:Refresh()
        if BattleMaps.Chat then
            BattleMaps.Chat(string.format(
                "%s saved: %s.",
                Callouts.ACTION_LABELS[actionKey] or actionKey,
                Callouts:GetBindingLabel(binding)
            ))
        end
        dialog:Hide()
    end)

    dialog:SetScript("OnMouseDown", function(self)
        if panel.IsMouseOver and not panel:IsMouseOver() then self:Hide() end
    end)
    dialog:SetScript("OnHide", function(self)
        self.actionKey = nil
        self.pendingBinding = nil
        self.conflictKey = nil
        editBox:ClearFocus()
        for _, contextEdit in pairs(self.contextEdits or {}) do contextEdit:ClearFocus() end
        if capture.SetBackdropBorderColor then
            capture:SetBackdropBorderColor(0.55, 0.40, 0.23, 0.95)
        end
    end)

    if type(UISpecialFrames) == "table" then
        local found = false
        for _, name in ipairs(UISpecialFrames) do
            if name == "BattleMapsCalloutEditorDialog" then found = true; break end
        end
        if not found then table.insert(UISpecialFrames, "BattleMapsCalloutEditorDialog") end
    end

    dialog.Open = function(self, actionKey)
        if InCombatLockdown and InCombatLockdown() then
            if BattleMaps.Chat then BattleMaps.Chat("Callout settings can only be changed out of combat.") end
            return
        end

        self.actionKey = actionKey
        self.pendingBinding = Callouts:GetActionBinding(actionKey)
        self.title:SetText("Edit callout: " .. (Callouts.ACTION_LABELS[actionKey] or actionKey))
        self.editBox:SetText(Callouts:GetMacroTemplate(actionKey))
        self.editBox:SetCursorPosition(0)
        self.editBox:HighlightText(0, 0)
        local contexts = Callouts:GetActionContexts(actionKey) or {}
        for key, contextEdit in pairs(self.contextEdits or {}) do
            contextEdit:SetText(tostring(contexts[key] or ""))
            contextEdit:SetCursorPosition(0)
            contextEdit:HighlightText(0, 0)
        end
        self.panel:ClearAllPoints()
        self.panel:SetPoint("CENTER", Options.frame or UIParent, "CENTER", 0, 12)

        local optionsLevel = Options.frame and Options.frame.GetFrameLevel and Options.frame:GetFrameLevel() or 1200
        self:SetFrameStrata("TOOLTIP")
        self:SetFrameLevel(optionsLevel + 500)
        self.panel:SetFrameLevel(self:GetFrameLevel() + 2)
        self.capture:SetFrameLevel(self.panel:GetFrameLevel() + 2)
        self.editorFrame:SetFrameLevel(self.panel:GetFrameLevel() + 2)

        if self.capture.SetBackdropBorderColor then
            self.capture:SetBackdropBorderColor(0.55, 0.40, 0.23, 0.95)
        end

        self:Show()
        if type(self.Raise) == "function" then self:Raise() end
        if type(self.panel.Raise) == "function" then self.panel:Raise() end
        RefreshBinding()
        RefreshCount()
    end

    Options.calloutEditorDialog = dialog
    return dialog
end

local function MakeCalloutCog(parent, actionKey)
    local button = MakeButton(parent, "", 28, 24)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize(17, 17)
    if not TrySetAtlas(icon, { "common-icon-settings", "communities-icon-settings" }) then
        icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    end
    button.icon = icon
    button:SetScript("OnClick", function()
        EnsureCalloutEditorDialog():Open(actionKey)
    end)
    AddControlTooltip(button, "Edit callout",
        "Change this callout's mouse binding, secure macro, and edge-context strings in one place.")
    return button
end

local function MakeCalloutRow(parent, actionKey, x, y)
    local cell = CreateFrame("Frame", nil, parent)
    cell:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cell:SetSize(320, 54)
    cell.actionKey = actionKey

    local calloutCog = MakeCalloutCog(cell, actionKey)
    calloutCog:SetPoint("LEFT", cell, "LEFT", 0, 0)
    cell.calloutCog = calloutCog

    local icon = cell:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", calloutCog, "RIGHT", 8, 0)
    icon:SetSize(34, 34)
    icon:SetTexture(Callouts:GetActionTexture(actionKey))
    cell.icon = icon

    local label = cell:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    label:SetText(Callouts.ACTION_LABELS[actionKey] or actionKey)
    label:SetTextColor(1.00, 0.82, 0.40, 1)
    cell.label = label

    local bindingVisual = MakeBindingVisual(cell, 170, 28, false)
    bindingVisual:SetPoint("LEFT", label, "RIGHT", 10, 0)
    cell.bindingVisual = bindingVisual
    AddControlTooltip(bindingVisual, "Current callout binding",
        "The mouse graphic and modifier keycaps show the current quick-callout gesture. Use the cog to edit the binding and macro.")

    local function Refresh()
        icon:SetTexture(Callouts:GetActionTexture(actionKey))
        bindingVisual:RefreshBinding(Callouts:GetActionBinding(actionKey))
    end

    cell.Refresh = Refresh
    cell.SetControlEnabled = function(self, enabled)
        enabled = enabled == true
        calloutCog:SetEnabled(enabled)
        bindingVisual:SetAlpha(enabled and 1 or 0.40)
        icon:SetDesaturated(not enabled)
        icon:SetAlpha(enabled and 1 or 0.40)
        label:SetTextColor(enabled and 1.00 or 0.45, enabled and 0.82 or 0.45, enabled and 0.40 or 0.45, 1)
    end

    Options.refreshers[#Options.refreshers + 1] = cell
    Refresh()
    return cell
end

function Options:CreateCalloutsPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    self.pages.callouts = page
    page:SetAllPoints(parent)

    self.calloutsEnabledCheck = MakeCheckbox(page, "Enable objective callouts", 4, -2,
        function() return Callouts:GetSettings().enabled ~= false end,
        function(value)
            Callouts:GetSettings().enabled = value == true
            Callouts:RequestSecureRefresh()
            self:Refresh()
        end)

    local iconsPanel = MakePanel(page, "Callout icon", 0, -38, 684, 122)

    self.calloutIconSizeSlider = MakeSlider(iconsPanel, "Icon size", 12, -30, 0.25, 1.50, 0.025,
        function() return tonumber(Callouts:GetSettings().iconScale) or Callouts.DEFAULTS.iconScale end,
        function(value)
            Callouts:GetSettings().iconScale = value
            Callouts:RequestSecureRefresh()
        end,
        function(value) return string.format("%d%%", math.floor((value * 100) + 0.5)) end,
        276)
    if AddControlTooltip then
        AddControlTooltip(self.calloutIconSizeSlider, "Icon size",
            "Sizes the callout icon as a percentage of the visible base pin. For example, 50% is half the rendered base size on every supported battleground.")
    end

    self.calloutIconXOffsetSlider = MakeSlider(iconsPanel, "X offset", 316, -30, -60, 60, 1,
        function() return tonumber(Callouts:GetSettings().iconOffsetX) or 0 end,
        function(value)
            Callouts:GetSettings().iconOffsetX = value
            Callouts:RequestSecureRefresh()
        end,
        function(value) return string.format("%d", math.floor(value + (value >= 0 and 0.5 or -0.5))) end,
        164)

    self.calloutIconYOffsetSlider = MakeSlider(iconsPanel, "Y offset", 508, -30, -60, 60, 1,
        function() return tonumber(Callouts:GetSettings().iconOffsetY) or 0 end,
        function(value)
            Callouts:GetSettings().iconOffsetY = value
            Callouts:RequestSecureRefresh()
        end,
        function(value) return string.format("%d", math.floor(value + (value >= 0 and 0.5 or -0.5))) end,
        164)

    self.calloutDragContextCheck = MakeCheckbox(iconsPanel, "Edge drag context", 12, -91,
        function() return Callouts:GetSettings().dragContextEnabled ~= false end,
        function(value)
            Callouts:GetSettings().dragContextEnabled = value == true
            Callouts:RequestSecureRefresh()
        end)
    AddControlTooltip(self.calloutDragContextCheck, "Edge drag context",
        "Hold a callout and swipe through a BattleMaps edge to add tactical context. The trigger is a fixed 1-pixel boundary: top = stealth, right = 2, bottom = 1, left = 3. When an edge is triggered, the inside of that map edge glows in the active callout's animation color. Releasing without crossing an edge sends the normal callout.")

    local actionsPanel = MakePanel(page, "Callout actions", 0, -168, 684, 224)

    local subtitle = actionsPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    subtitle:SetPoint("TOPLEFT", actionsPanel, "TOPLEFT", 12, -30)
    subtitle:SetText("Callout icons stay fixed in place. Use the cog to edit the binding and secure macro.")
    subtitle:SetTextColor(0.66, 0.64, 0.60, 1)

    local resetMacros = MakeResetIconButton(actionsPanel, "Reset callout macros",
        "Restores all six callout macros to their defaults.", function()
            if Callouts:ResetMacros() then self:Refresh() end
        end)
    resetMacros:SetPoint("TOPRIGHT", actionsPanel, "TOPRIGHT", -8, -7)

    self.calloutActionRows = {
        MakeCalloutRow(actionsPanel, "incoming", 12, -52),
        MakeCalloutRow(actionsPanel, "attack", 348, -52),
        MakeCalloutRow(actionsPanel, "defend", 12, -106),
        MakeCalloutRow(actionsPanel, "clear", 348, -106),
        MakeCalloutRow(actionsPanel, "custom1", 12, -160),
        MakeCalloutRow(actionsPanel, "custom2", 348, -160),
    }

    local stateRefresher = CreateFrame("Frame", nil, page)
    stateRefresher.Refresh = function()
        local enabled = Callouts:GetSettings().enabled ~= false
        SetControlEnabled(self.calloutIconSizeSlider, enabled)
        SetControlEnabled(self.calloutIconXOffsetSlider, enabled)
        SetControlEnabled(self.calloutIconYOffsetSlider, enabled)
        SetControlEnabled(self.calloutDragContextCheck, enabled)
        for _, row in ipairs(self.calloutActionRows or {}) do
            if row.SetControlEnabled then row:SetControlEnabled(enabled) end
        end
    end
    self.refreshers[#self.refreshers + 1] = stateRefresher
end

if Options.RegisterPage then
    Options:RegisterPage("callouts", "Callouts", 640, "CreateCalloutsPage", 40)
end
