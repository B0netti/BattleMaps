local _, BattleMaps = ...
local Options = BattleMaps and BattleMaps.Options
if not Options then return end


local function GetTemplate()
    return BackdropTemplateMixin and "BackdropTemplate" or nil
end

local function MakeButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 110, height or 24)
    button:SetText(text)

    -- Preserve Blizzard's metal border while using the BattleMaps palette.
    local fill = button:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    fill:SetColorTexture(0.34, 0.035, 0.025, 0.92)
    button.brandFill = fill

    local fontString = button:GetFontString()
    if fontString then
        fontString:SetTextColor(
            BattleMaps.COLORS.buttonText[1],
            BattleMaps.COLORS.buttonText[2],
            BattleMaps.COLORS.buttonText[3],
            1
        )
    end

    button:SetScript("OnEnter", function(self)
        if self:IsEnabled() then self.brandFill:SetColorTexture(0.58, 0.07, 0.045, 0.98) end
    end)
    button:SetScript("OnLeave", function(self)
        self.brandFill:SetColorTexture(0.34, 0.035, 0.025, self:IsEnabled() and 0.92 or 0.42)
    end)
    button:SetScript("OnDisable", function(self)
        self.brandFill:SetColorTexture(0.16, 0.13, 0.10, 0.42)
    end)
    button:SetScript("OnEnable", function(self)
        self.brandFill:SetColorTexture(0.34, 0.035, 0.025, 0.92)
    end)
    return button
end



local function RaiseBattleMapsTooltip(owner)
    if not GameTooltip or not owner then return false end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")

    -- BattleMaps' options window can itself use a high frame level/strata.
    -- Keep GameTooltip on the tooltip strata and explicitly raise it above the
    -- options window so descriptions never render behind the settings panel.
    if GameTooltip.SetFrameStrata then
        GameTooltip:SetFrameStrata("TOOLTIP")
    end
    if GameTooltip.SetFrameLevel then
        local optionsLevel = Options.frame and Options.frame.GetFrameLevel
            and Options.frame:GetFrameLevel()
            or 0
        GameTooltip:SetFrameLevel(math.max(
            tonumber(GameTooltip:GetFrameLevel()) or 0,
            optionsLevel + 200
        ))
    end
    return true
end

local function ShowBattleMapsTooltip(owner, title, description)
    if not RaiseBattleMapsTooltip(owner) then return end
    GameTooltip:SetText(title or "", 1.00, 0.82, 0.40)
    if description and description ~= "" then
        GameTooltip:AddLine(description, 0.90, 0.90, 0.90, true)
    end
    GameTooltip:Show()
    if GameTooltip.Raise then GameTooltip:Raise() end
end

local function HideBattleMapsTooltip(owner)
    if GameTooltip and GameTooltip:GetOwner() == owner then
        GameTooltip:Hide()
    end
end

local function MakeResetIconButton(parent, tooltipTitle, tooltipText, onClick)
    local button = MakeButton(parent, "", 28, 22)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize(15, 15)
    local ok = false
    if icon.SetAtlas then
        ok = pcall(icon.SetAtlas, icon, "transmog-icon-revert")
    end
    if not ok then
        icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
    end
    button.icon = icon
    button:SetScript("OnClick", onClick)
    button:HookScript("OnEnter", function(owner)
        ShowBattleMapsTooltip(
            owner,
            tooltipTitle or "Reset to defaults",
            tooltipText
        )
    end)
    button:HookScript("OnLeave", function(owner)
        HideBattleMapsTooltip(owner)
    end)
    return button
end
local function SetFontColor(fontString, color, alpha)
    if not fontString or not color then return end
    fontString:SetTextColor(color[1], color[2], color[3], alpha or 1)
end

local function SetControlEnabled(control, enabled)
    if not control then return end
    enabled = enabled == true

    if control.SetEnabled then control:SetEnabled(enabled) end
    if control.SetControlEnabled then control:SetControlEnabled(enabled) end
    if control.Text then
        control.Text:SetTextColor(
            enabled and 1 or 0.45,
            enabled and 0.82 or 0.45,
            enabled and 0.40 or 0.45
        )
    end
end

local function MakePanel(parent, title, x, y, width, height)
    local panel = CreateFrame("Frame", nil, parent, GetTemplate())
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    panel:SetSize(width, height)
    if panel.SetBackdrop then
        panel:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        panel:SetBackdropColor(0.020, 0.017, 0.014, 0.34)
        panel:SetBackdropBorderColor(0.56, 0.39, 0.19, 0.46)
    end

    local accent = panel:CreateTexture(nil, "BORDER")
    accent:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
    accent:SetHeight(1)
    accent:SetColorTexture(0.88, 0.30, 0.18, 0.42)

    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
    heading:SetText(title)
    SetFontColor(heading, BattleMaps.COLORS.section or BattleMaps.COLORS.red)
    panel.heading = heading
    return panel
end
local function MakeCheckbox(parent, label, x, y, getter, setter)
    local check = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if check.Text then
        check.Text:SetText(label)
        check.Text:ClearAllPoints()
        check.Text:SetPoint("LEFT", check, "RIGHT", 6, 1)
        SetFontColor(check.Text, BattleMaps.COLORS.parchmentLight)
    end
    check:SetScript("OnClick", function(self)
        setter(self:GetChecked() == true)
        Options:Refresh()
    end)
    check.Refresh = function(self)
        self:SetChecked(getter() == true)
    end
    Options.refreshers[#Options.refreshers + 1] = check
    return check
end

local function MakeSlider(parent, label, x, y, minimum, maximum, step, getter, setter, formatter, holderWidth)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(holderWidth or 250, 52)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    -- The holder covers the label, value text, and slider. Making it mouse
    -- enabled lets AddControlTooltip work over the complete control rather
    -- than only over the narrow Slider child.
    holder:EnableMouse(true)

    local title = holder:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    title:SetText(label)
    SetFontColor(title, BattleMaps.COLORS.parchmentLight)
    holder.title = title

    local valueText = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valueText:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)

    local slider = CreateFrame("Slider", nil, holder, "OptionsSliderTemplate")
    holder.slider = slider
    slider:SetPoint("TOPLEFT", holder, "TOPLEFT", 4, -20)
    slider:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -4, -20)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    if slider.Low then slider.Low:SetText("") end
    if slider.High then slider.High:SetText("") end
    if slider.Text then slider.Text:SetText("") end

    slider:SetScript("OnValueChanged", function(self, value)
        if self.refreshing then return end
        value = BattleMaps.Round(value, step)
        setter(value)
        valueText:SetText(formatter(value))
    end)

    holder.Refresh = function(self)
        slider.refreshing = true
        local value = getter()
        slider:SetValue(value)
        valueText:SetText(formatter(value))
        slider.refreshing = false
    end

    holder.SetControlEnabled = function(self, enabled)
        enabled = enabled == true
        slider:SetEnabled(enabled)
        title:SetTextColor(enabled and 1 or 0.45, enabled and 0.82 or 0.45, enabled and 0.40 or 0.45)
        valueText:SetTextColor(enabled and 1 or 0.45, enabled and 1 or 0.45, enabled and 1 or 0.45)
    end

    Options.refreshers[#Options.refreshers + 1] = holder
    return holder
end


-- Blizzard's Slider widget exposes one thumb. This compact range control uses
-- the native slider bar artwork with two independently draggable thumbs.
local function MakeRangeSlider(parent, label, x, y, minimum, maximum, step,
        getter, setter, formatter, holderWidth)
    local width = holderWidth or 250
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, 52)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    holder:EnableMouse(true)

    local title = holder:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    title:SetText(label)
    SetFontColor(title, BattleMaps.COLORS.parchmentLight)
    holder.title = title

    local valueText = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valueText:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    holder.valueText = valueText

    local track = CreateFrame("Slider", nil, holder, "OptionsSliderTemplate")
    track:SetPoint("TOPLEFT", holder, "TOPLEFT", 4, -20)
    track:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -4, -20)
    track:SetHeight(17)
    track:SetMinMaxValues(minimum, maximum)
    track:SetValueStep(step)
    track:EnableMouse(false)
    if track.Low then track.Low:SetText("") end
    if track.High then track.High:SetText("") end
    if track.Text then track.Text:SetText("") end
    local nativeThumb = track.GetThumbTexture and track:GetThumbTexture()
    if nativeThumb then nativeThumb:SetAlpha(0) end
    holder.track = track

    local hit = CreateFrame("Frame", nil, holder)
    hit:SetAllPoints(track)
    hit:SetFrameLevel(track:GetFrameLevel() + 4)
    hit:EnableMouse(true)
    holder.hit = hit

    local selected = hit:CreateTexture(nil, "ARTWORK")
    selected:SetHeight(3)
    selected:SetColorTexture(0.95, 0.62, 0.18, 0.85)
    holder.selected = selected

    local lowerThumb = hit:CreateTexture(nil, "OVERLAY")
    lowerThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    lowerThumb:SetSize(14, 22)
    holder.lowerThumb = lowerThumb

    local upperThumb = hit:CreateTexture(nil, "OVERLAY")
    upperThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    upperThumb:SetSize(14, 22)
    holder.upperThumb = upperThumb

    holder.lowerValue = minimum
    holder.upperValue = maximum
    holder.controlEnabled = true

    local function ClampRange(lower, upper)
        lower = BattleMaps.Clamp(BattleMaps.Round(tonumber(lower) or minimum, step), minimum, maximum)
        upper = BattleMaps.Clamp(BattleMaps.Round(tonumber(upper) or maximum, step), minimum, maximum)
        if lower > upper then lower, upper = upper, lower end
        return lower, upper
    end

    local function ToFraction(value)
        if maximum <= minimum then return 0 end
        return BattleMaps.Clamp((value - minimum) / (maximum - minimum), 0, 1)
    end

    local function UpdateVisuals()
        local trackWidth = math.max(width - 8, 1)
        local lowerX = ToFraction(holder.lowerValue) * trackWidth
        local upperX = ToFraction(holder.upperValue) * trackWidth

        lowerThumb:ClearAllPoints()
        lowerThumb:SetPoint("CENTER", hit, "LEFT", lowerX, 0)
        upperThumb:ClearAllPoints()
        upperThumb:SetPoint("CENTER", hit, "LEFT", upperX, 0)

        selected:ClearAllPoints()
        selected:SetPoint("LEFT", hit, "LEFT", lowerX, 0)
        selected:SetWidth(math.max(upperX - lowerX, 1))
        valueText:SetText(formatter(holder.lowerValue, holder.upperValue))
    end

    local function CursorValue()
        local effectiveScale = hit:GetEffectiveScale()
        if not effectiveScale or effectiveScale <= 0 then effectiveScale = 1 end
        local cursorX = select(1, GetCursorPosition()) / effectiveScale
        local left = hit:GetLeft()
        local trackWidth = hit:GetWidth()
        if not left or not trackWidth or trackWidth <= 0 then
            return holder.lowerValue
        end
        local fraction = BattleMaps.Clamp((cursorX - left) / trackWidth, 0, 1)
        return BattleMaps.Round(minimum + ((maximum - minimum) * fraction), step)
    end

    local function ApplyCursorValue()
        if not hit.dragging or not holder.controlEnabled then return end
        local value = CursorValue()
        local lower, upper = holder.lowerValue, holder.upperValue
        if hit.dragging == "lower" then
            lower = math.min(value, upper)
        else
            upper = math.max(value, lower)
        end
        lower, upper = ClampRange(lower, upper)
        if lower == holder.lowerValue and upper == holder.upperValue then return end
        holder.lowerValue, holder.upperValue = lower, upper
        UpdateVisuals()
        setter(lower, upper)
    end

    hit:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or not holder.controlEnabled then return end
        local value = CursorValue()
        local lowerDistance = math.abs(value - holder.lowerValue)
        local upperDistance = math.abs(value - holder.upperValue)
        self.dragging = lowerDistance <= upperDistance and "lower" or "upper"
        ApplyCursorValue()
    end)
    hit:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then self.dragging = nil end
    end)
    hit:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        if type(IsMouseButtonDown) == "function" and not IsMouseButtonDown("LeftButton") then
            self.dragging = nil
            return
        end
        ApplyCursorValue()
    end)

    holder.Refresh = function(self)
        local lower, upper = getter()
        self.lowerValue, self.upperValue = ClampRange(lower, upper)
        UpdateVisuals()
    end

    holder.SetControlEnabled = function(self, enabled)
        enabled = enabled == true
        self.controlEnabled = enabled
        hit:EnableMouse(enabled)
        track:SetAlpha(enabled and 1 or 0.45)
        selected:SetAlpha(enabled and 0.85 or 0.30)
        lowerThumb:SetVertexColor(enabled and 1 or 0.45, enabled and 1 or 0.45, enabled and 1 or 0.45)
        upperThumb:SetVertexColor(enabled and 1 or 0.45, enabled and 1 or 0.45, enabled and 1 or 0.45)
        title:SetTextColor(enabled and 1 or 0.45, enabled and 0.82 or 0.45, enabled and 0.40 or 0.45)
        valueText:SetTextColor(enabled and 1 or 0.45, enabled and 1 or 0.45, enabled and 1 or 0.45)
    end

    Options.refreshers[#Options.refreshers + 1] = holder
    return holder
end

local function MakeChoiceSelector(parent, label, x, y, choices, getter, setter, buttonWidth)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    holder:SetSize(520, 42)

    local title = holder:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    title:SetText(label)
    SetFontColor(title, BattleMaps.COLORS.parchmentLight)
    holder.title = title

    local buttons = {}
    holder.buttons = buttons
    local spacing = 5
    buttonWidth = buttonWidth or 82
    for index, choice in ipairs(choices) do
        local button = MakeButton(holder, choice.label, buttonWidth, 22)
        button:SetPoint("TOPLEFT", holder, "TOPLEFT", (index - 1) * (buttonWidth + spacing), -17)
        button:SetScript("OnClick", function()
            setter(choice.value)
            Options:Refresh()
        end)
        buttons[choice.value] = button
    end

    holder.Refresh = function(self)
        local selected = getter()
        for value, button in pairs(buttons) do
            if value == selected then
                button:LockHighlight()
                button:SetButtonState("PUSHED", true)
            else
                button:UnlockHighlight()
                button:SetButtonState("NORMAL", false)
            end
        end
    end

    holder.SetControlEnabled = function(self, enabled)
        enabled = enabled == true
        title:SetTextColor(enabled and 1 or 0.45, enabled and 0.82 or 0.45, enabled and 0.40 or 0.45)
        for _, button in pairs(buttons) do button:SetEnabled(enabled) end
    end

    Options.refreshers[#Options.refreshers + 1] = holder
    return holder
end


local function MakeDropdown(parent, label, x, y, width, itemsGetter, getter, setter)
    width = width or 280
    local hasLabel = type(label) == "string" and label ~= ""
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    holder:SetSize(width, hasLabel and 44 or 24)

    local title = holder:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    title:SetText(hasLabel and label or "")
    title:SetShown(hasLabel)
    SetFontColor(title, BattleMaps.COLORS.parchmentLight)
    holder.title = title

    local button = MakeButton(holder, "", width, 24)
    holder.button = button
    button:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, hasLabel and -17 or 0)

    local arrow = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", button, "RIGHT", -10, 1)
    arrow:SetText("v")
    SetFontColor(arrow, BattleMaps.COLORS.buttonText)
    holder.arrow = arrow

    local menu = CreateFrame("Frame", nil, UIParent, GetTemplate())
    holder.menu = menu
    menu:SetFrameStrata("TOOLTIP")
    menu:SetFrameLevel(((Options.frame and Options.frame:GetFrameLevel()) or 1200) + 100)
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:EnableMouseWheel(true)
    menu:SetWidth(width)
    menu:Hide()
    if menu.SetBackdrop then
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        menu:SetBackdropColor(0.018, 0.015, 0.012, 0.98)
        menu:SetBackdropBorderColor(0.64, 0.45, 0.23, 0.95)
    end

    local rows = {}
    local offset = 0
    local maxVisible = 10

    local function GetItems()
        local items = type(itemsGetter) == "function" and itemsGetter() or itemsGetter
        return type(items) == "table" and items or {}
    end

    local function EnsureRow(index)
        if rows[index] then return rows[index] end
        local row = CreateFrame("Button", nil, menu)
        row:SetHeight(22)
        row:SetPoint("LEFT", menu, "LEFT", 5, 0)
        row:SetPoint("RIGHT", menu, "RIGHT", -5, 0)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.10, 0.075, 0.045, 0.30)
        row.bg = bg

        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.68, 0.11, 0.06, 0.62)

        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        text:SetPoint("LEFT", row, "LEFT", 8, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        text:SetJustifyH("LEFT")
        row.text = text
        rows[index] = row
        return row
    end

    local function RenderMenu()
        local items = GetItems()
        local visible = math.min(maxVisible, #items)
        local maximumOffset = math.max(0, #items - visible)
        offset = BattleMaps.Clamp(offset, 0, maximumOffset)
        menu:SetHeight(math.max(30, (visible * 22) + 10))

        for rowIndex = 1, maxVisible do
            local row = EnsureRow(rowIndex)
            local item = items[offset + rowIndex]
            if item and rowIndex <= visible then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", menu, "TOPLEFT", 5, -5 - ((rowIndex - 1) * 22))
                row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -5, -5 - ((rowIndex - 1) * 22))
                row.text:SetText(item.label or tostring(item.value))
                local selected = getter()
                row.bg:SetColorTexture(
                    selected == item.value and 0.50 or 0.10,
                    selected == item.value and 0.055 or 0.075,
                    selected == item.value and 0.035 or 0.045,
                    selected == item.value and 0.80 or 0.30
                )
                row:SetScript("OnClick", function()
                    setter(item.value)
                    menu:Hide()
                    Options:Refresh()
                end)
                row:Show()
            else
                row:Hide()
            end
        end
    end

    menu:SetScript("OnMouseWheel", function(_, delta)
        local items = GetItems()
        local visible = math.min(maxVisible, #items)
        local maximumOffset = math.max(0, #items - visible)
        offset = BattleMaps.Clamp(offset - delta, 0, maximumOffset)
        RenderMenu()
    end)

    button:SetScript("OnClick", function()
        if menu:IsShown() then
            menu:Hide()
            return
        end
        for _, dropdown in ipairs(Options.dropdowns) do
            if dropdown ~= holder and dropdown.menu then dropdown.menu:Hide() end
        end
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
        offset = 0
        RenderMenu()
        menu:Show()
    end)

    holder.Refresh = function(self)
        local selected = getter()
        local selectedLabel = tostring(selected or "")
        for _, item in ipairs(GetItems()) do
            if item.value == selected then
                selectedLabel = item.label or selectedLabel
                break
            end
        end
        button:SetText(selectedLabel)
    end

    holder.SetControlEnabled = function(self, enabled)
        enabled = enabled == true
        button:SetEnabled(enabled)
        title:SetTextColor(
            enabled and BattleMaps.COLORS.buttonText[1] or 0.45,
            enabled and BattleMaps.COLORS.buttonText[2] or 0.45,
            enabled and BattleMaps.COLORS.buttonText[3] or 0.45,
            1
        )
        if not enabled then menu:Hide() end
    end

    Options.dropdowns[#Options.dropdowns + 1] = holder
    Options.refreshers[#Options.refreshers + 1] = holder
    return holder
end

local function MakeColorSwatchControl(parent, label, x, y, getter, clickHandler, holderWidth, buttonWidth, buttonText)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    holderWidth = holderWidth or 304
    buttonWidth = buttonWidth or 128
    holder:SetSize(holderWidth, 44)

    local title = holder:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    title:SetText(label)
    SetFontColor(title, BattleMaps.COLORS.parchmentLight)
    holder.title = title

    local button = MakeButton(holder, buttonText or "Choose colour", buttonWidth, 24)
    button:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -17)
    button:SetScript("OnClick", clickHandler)
    holder.button = button

    local swatch = CreateFrame("Button", nil, holder)
    swatch:SetSize(34, 24)
    swatch:SetPoint("LEFT", button, "RIGHT", 8, 0)
    swatch:SetScript("OnClick", clickHandler)
    holder.swatch = swatch

    local border = swatch:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 1)
    local fill = swatch:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    holder.fill = fill

    holder.Refresh = function(self)
        local color = type(getter) == "function" and getter() or {}
        fill:SetColorTexture(
            BattleMaps.Clamp(tonumber(color.r or color[1]) or 1, 0, 1),
            BattleMaps.Clamp(tonumber(color.g or color[2]) or 1, 0, 1),
            BattleMaps.Clamp(tonumber(color.b or color[3]) or 1, 0, 1),
            1
        )
    end

    holder.SetControlEnabled = function(self, enabled)
        enabled = enabled == true
        button:SetEnabled(enabled)
        swatch:SetEnabled(enabled)
        title:SetTextColor(enabled and 1 or 0.45, enabled and 0.82 or 0.45, enabled and 0.40 or 0.45)
        fill:SetAlpha(enabled and 1 or 0.45)
    end

    Options.refreshers[#Options.refreshers + 1] = holder
    return holder
end

local function AddControlTooltip(control, title, description)
    if not control or not title then return end

    local targets = {}
    local seen = {}
    local function AddTarget(target)
        if not target or seen[target] or type(target.HookScript) ~= "function" then return end
        seen[target] = true
        targets[#targets + 1] = target
    end

    AddTarget(control)
    AddTarget(control.slider)
    AddTarget(control.hit)
    AddTarget(control.button)
    AddTarget(control.swatch)
    AddTarget(control.editBox)
    if type(control.buttons) == "table" then
        for _, button in pairs(control.buttons) do AddTarget(button) end
    end

    for _, target in ipairs(targets) do
        target:HookScript("OnEnter", function(anchor)
            ShowBattleMapsTooltip(anchor, title, description)
        end)
        target:HookScript("OnLeave", function(anchor)
            HideBattleMapsTooltip(anchor)
        end)
    end
end

local function MakeCompactNumberInput(parent, x, y, minimum, maximum, getter, setter, width)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    holder:SetSize(width or 42, 24)

    local editBox = CreateFrame("EditBox", nil, holder, "InputBoxTemplate")
    holder.editBox = editBox
    editBox:SetAllPoints(holder)
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(true)
    editBox:SetMaxLetters(2)
    editBox:SetJustifyH("CENTER")

    local function Normalise(value)
        return BattleMaps.Clamp(math.floor((tonumber(value) or getter() or minimum) + 0.5), minimum, maximum)
    end

    local function Commit()
        if editBox.refreshing then return end
        local value = Normalise(editBox:GetText())
        setter(value)
        editBox:SetText(tostring(value))
        editBox:ClearFocus()
        Options:Refresh()
    end

    editBox:SetScript("OnEnterPressed", Commit)
    editBox:SetScript("OnEditFocusLost", Commit)
    editBox:SetScript("OnEscapePressed", function(self)
        self.refreshing = true
        self:SetText(tostring(Normalise(getter())))
        self.refreshing = false
        self:ClearFocus()
    end)

    holder.Refresh = function(self)
        editBox.refreshing = true
        editBox:SetText(tostring(Normalise(getter())))
        editBox.refreshing = false
    end

    holder.SetControlEnabled = function(self, enabled)
        enabled = enabled == true
        editBox:SetEnabled(enabled)
        editBox:SetTextColor(enabled and 1 or 0.45, enabled and 1 or 0.45, enabled and 1 or 0.45)
    end

    Options.refreshers[#Options.refreshers + 1] = holder
    return holder
end

local PLAYER_ARROW_COLOR_CHOICES = {
    { value = "faction", label = "Faction" },
    { value = "class", label = "Class" },
    { value = "custom", label = "Custom" },
}

local BORDER_STYLE_OPTIONS = {
    { value = "solid", label = "Solid" },
    { value = "tooltip", label = "Tooltip" },
    { value = "dialog", label = "Dialog" },
}

local function MakePlayerColorSelector(parent, x, y)
    local db = BattleMaps.Database:Get()
    local holder = MakeChoiceSelector(
        parent,
        "Player arrow / radius colour",
        x,
        y,
        PLAYER_ARROW_COLOR_CHOICES,
        function() return db.playerArrowColorMode end,
        function(value)
            db.playerArrowColorMode = value
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
            if value == "custom" then C_Timer.After(0, function() Options:OpenPlayerArrowColorPicker() end) end
        end,
        76
    )

    local swatch = CreateFrame("Button", nil, holder)
    swatch:SetSize(27, 22)
    swatch:SetPoint("TOPLEFT", holder, "TOPLEFT", 244, -17)
    local border = swatch:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 1)
    local fill = swatch:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    swatch.fill = fill
    swatch:SetScript("OnClick", function() Options:OpenPlayerArrowColorPicker() end)

    local oldRefresh = holder.Refresh
    holder.Refresh = function(self)
        oldRefresh(self)
        local custom = db.playerArrowColorMode == "custom"
        swatch:SetShown(custom)
        if custom then
            local c = db.playerArrowCustomColor or {}
            fill:SetColorTexture(tonumber(c.r) or 1, tonumber(c.g) or 0.82, tonumber(c.b) or 0.22, 1)
        end
    end

    local oldEnable = holder.SetControlEnabled
    holder.SetControlEnabled = function(self, enabled)
        oldEnable(self, enabled)
        swatch:SetEnabled(enabled)
    end

    return holder
end


local OBJECTIVE_PULSE_COLOR_CHOICES = {
    { value = "white", label = "White" },
    { value = "faction", label = "Faction" },
    { value = "class", label = "Class" },
    { value = "custom", label = "Custom" },
}

local function MakeObjectivePulseColorSelector(parent, x, y)
    local db = BattleMaps.Database:Get()
    local holder = MakeChoiceSelector(
        parent,
        "Pulse colour",
        x,
        y,
        OBJECTIVE_PULSE_COLOR_CHOICES,
        function() return db.objectivePulseColorMode or "white" end,
        function(value)
            db.objectivePulseColorMode = value
            if BattleMaps.Pins and BattleMaps.Pins.RefreshObjectivePulseColors then
                BattleMaps.Pins:RefreshObjectivePulseColors()
            end
            if value == "custom" and C_Timer and C_Timer.After then
                C_Timer.After(0, function() Options:OpenObjectivePulseColorPicker() end)
            end
        end,
        72
    )

    local swatch = CreateFrame("Button", nil, holder)
    swatch:SetSize(27, 22)
    swatch:SetPoint("TOPLEFT", holder, "TOPLEFT", 310, -17)
    local border = swatch:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 1)
    local fill = swatch:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    swatch.fill = fill
    swatch:SetScript("OnClick", function() Options:OpenObjectivePulseColorPicker() end)

    local oldRefresh = holder.Refresh
    holder.Refresh = function(self)
        oldRefresh(self)
        local custom = db.objectivePulseColorMode == "custom"
        swatch:SetShown(custom)
        if custom then
            local c = db.objectivePulseCustomColor or {}
            fill:SetColorTexture(tonumber(c.r) or 1, tonumber(c.g) or 0.82, tonumber(c.b) or 0.22, 1)
        end
    end

    local oldEnable = holder.SetControlEnabled
    holder.SetControlEnabled = function(self, enabled)
        oldEnable(self, enabled)
        swatch:SetEnabled(enabled)
    end

    return holder
end


Options.Widgets = {
    MakeButton = MakeButton,
    MakeResetIconButton = MakeResetIconButton,
    MakePanel = MakePanel,
    MakeCheckbox = MakeCheckbox,
    MakeSlider = MakeSlider,
    MakeRangeSlider = MakeRangeSlider,
    MakeChoiceSelector = MakeChoiceSelector,
    MakeDropdown = MakeDropdown,
    MakeColorSwatchControl = MakeColorSwatchControl,
    MakeCompactNumberInput = MakeCompactNumberInput,
    AddControlTooltip = AddControlTooltip,
    MakePlayerColorSelector = MakePlayerColorSelector,
    MakeObjectivePulseColorSelector = MakeObjectivePulseColorSelector,
    SetFontColor = SetFontColor,
    SetControlEnabled = SetControlEnabled,
    GetTemplate = GetTemplate,
}

Options.Constants = {
    BORDER_STYLE_OPTIONS = BORDER_STYLE_OPTIONS,
    PLAYER_ARROW_COLOR_CHOICES = PLAYER_ARROW_COLOR_CHOICES,
}

