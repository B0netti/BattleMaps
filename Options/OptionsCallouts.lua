local _, BattleMaps = ...
local Options = BattleMaps and BattleMaps.Options
local Callouts = BattleMaps and BattleMaps.Callouts
if not Options or not Options.Widgets or not Callouts then return end

local W = Options.Widgets
local MakeCheckbox = W.MakeCheckbox
local MakePanel = W.MakePanel
local MakeSlider = W.MakeSlider
local MakeResetIconButton = W.MakeResetIconButton
local SetControlEnabled = W.SetControlEnabled
local AddControlTooltip = W.AddControlTooltip

local function MakeTokenHelpButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(22, 22)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    local atlasSet = false
    if icon.SetAtlas then
        atlasSet = pcall(icon.SetAtlas, icon, "common-icon-alert")
    end
    if not atlasSet then
        icon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
    end
    button.icon = icon

    button:SetScript("OnEnter", function(owner)
        if not GameTooltip then return end
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText("Message substitutions", 1.00, 0.82, 0.40)
        GameTooltip:AddLine("[node]", 1, 1, 1)
        GameTooltip:AddLine("Uses the abbreviated objective name, for example BS.", 0.86, 0.86, 0.86, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("[node_full]", 1, 1, 1)
        GameTooltip:AddLine("Uses the full objective name, for example Blacksmith.", 0.86, 0.86, 0.86, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("INC [node]  ->  INC BS", 0.72, 0.92, 1.00, true)
        GameTooltip:AddLine("INC [node_full]  ->  INC Blacksmith", 0.72, 0.92, 1.00, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(owner)
        if GameTooltip and GameTooltip:GetOwner() == owner then GameTooltip:Hide() end
    end)
    return button
end

local function MakeMessageEditor(parent, actionKey, x, y)
    local cell = CreateFrame("Frame", nil, parent)
    cell:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cell:SetSize(320, 72)

    local icon = cell:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", cell, "TOPLEFT", 2, -2)
    icon:SetSize(32, 32)
    icon:SetTexture(Callouts:GetActionTexture(actionKey))
    cell.icon = icon

    local label = cell:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -1)
    label:SetText(Callouts.ACTION_LABELS[actionKey] or actionKey)
    label:SetTextColor(1.00, 0.82, 0.40, 1)
    cell.label = label

    local editBox = CreateFrame("EditBox", nil, cell, "InputBoxTemplate")
    editBox:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
    editBox:SetPoint("RIGHT", cell, "RIGHT", -120, 0)
    editBox:SetHeight(24)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(120)
    editBox:SetJustifyH("LEFT")
    cell.editBox = editBox

    local bindingLabel = cell:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bindingLabel:SetPoint("LEFT", editBox, "RIGHT", 8, 0)
    bindingLabel:SetPoint("RIGHT", cell, "RIGHT", -8, 0)
    bindingLabel:SetJustifyH("LEFT")
    bindingLabel:SetTextColor(0.72, 0.92, 1.00, 1)
    cell.bindingLabel = bindingLabel

    local function Refresh()
        editBox.refreshing = true
        editBox:SetText(Callouts:GetMessageTemplate(actionKey))
        editBox.refreshing = false
        icon:SetTexture(Callouts:GetActionTexture(actionKey))
        bindingLabel:SetText(Callouts:GetActionBindingLabel(actionKey))
    end

    local function Commit()
        if editBox.refreshing then return end
        Callouts:SetMessageTemplate(actionKey, editBox:GetText())
        Refresh()
        editBox:ClearFocus()
    end

    editBox:SetScript("OnEnterPressed", Commit)
    editBox:SetScript("OnEditFocusLost", Commit)
    editBox:SetScript("OnEscapePressed", function(self)
        Refresh()
        self:ClearFocus()
    end)

    cell.Refresh = Refresh
    cell.SetControlEnabled = function(self, enabled)
        enabled = enabled == true
        editBox:SetEnabled(enabled)
        icon:SetDesaturated(not enabled)
        icon:SetAlpha(enabled and 1 or 0.40)
        label:SetTextColor(enabled and 1.00 or 0.45, enabled and 0.82 or 0.45, enabled and 0.40 or 0.45, 1)
        editBox:SetTextColor(enabled and 1 or 0.45, enabled and 1 or 0.45, enabled and 1 or 0.45)
        bindingLabel:SetTextColor(enabled and 0.72 or 0.45, enabled and 0.92 or 0.45, enabled and 1.00 or 0.45, 1)
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

    local iconsPanel = MakePanel(page, "Callout icon", 0, -38, 684, 94)

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

    local messagesPanel = MakePanel(page, "Callout messages", 0, -140, 684, 202)

    local help = MakeTokenHelpButton(messagesPanel)
    help:SetPoint("TOPRIGHT", messagesPanel, "TOPRIGHT", -42, -6)
    self.calloutTokenHelp = help

    local resetMessages = MakeResetIconButton(messagesPanel, "Reset callout messages",
        "Restores the four callout message templates to their defaults.", function()
            Callouts:ResetMessages()
            self:Refresh()
        end)
    resetMessages:SetPoint("TOPRIGHT", messagesPanel, "TOPRIGHT", -8, -7)

    self.calloutMessageEditors = {
        MakeMessageEditor(messagesPanel, "incoming", 12, -38),
        MakeMessageEditor(messagesPanel, "attack", 348, -38),
        MakeMessageEditor(messagesPanel, "defend", 12, -116),
        MakeMessageEditor(messagesPanel, "clear", 348, -116),
    }

    local stateRefresher = CreateFrame("Frame", nil, page)
    stateRefresher.Refresh = function()
        local enabled = Callouts:GetSettings().enabled ~= false
        SetControlEnabled(self.calloutIconSizeSlider, enabled)
        SetControlEnabled(self.calloutIconXOffsetSlider, enabled)
        SetControlEnabled(self.calloutIconYOffsetSlider, enabled)
        for _, editor in ipairs(self.calloutMessageEditors or {}) do
            if editor.SetControlEnabled then editor:SetControlEnabled(enabled) end
        end
    end
    self.refreshers[#self.refreshers + 1] = stateRefresher
end

if Options.RegisterPage then
    Options:RegisterPage("callouts", "Callouts", 560, "CreateCalloutsPage", 40)
end
