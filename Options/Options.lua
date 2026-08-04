local _, BattleMaps = ...

local function NormalizeBattlegroundChoiceName(value)
    value = tostring(value or ""):lower()
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return value:gsub("[%s%p%c]", "")
end

local function GetBattlegroundChoiceValue(info)
    if type(info) ~= "table" then return nil end
    return tonumber(info.id)
        or tonumber(info.mapID)
        or tonumber(info.uiMapID)
        or tonumber(info.instanceMapID)
end

local function IsArathiBasinChoice(info)
    if type(info) ~= "table" then return false end

    local name = info.name
    if (not name or name == "") and BattleMaps.Battlegrounds and BattleMaps.Battlegrounds.GetName then
        local value = GetBattlegroundChoiceValue(info)
        if value then
            local ok, resolved = pcall(BattleMaps.Battlegrounds.GetName, BattleMaps.Battlegrounds, value)
            if ok then name = resolved end
        end
    end
    if NormalizeBattlegroundChoiceName(name):find("arathibasin", 1, true) then
        return true
    end

    -- Do not classify raw ID 112 as AB here: modern C_Map data uses 112 for
    -- Eye of the Storm. Current AB metadata uses UI map ID 1366.
    for _, key in ipairs({ "id", "mapID", "uiMapID", "instanceMapID" }) do
        if tonumber(info[key]) == 1366 then return true end
    end
    return false
end


local function IsSeethingShoreSelection(mapID)
    local rules = BattleMaps.ObjectiveRules
    if rules and type(rules.IsSeethingShoreMap) == "function" then
        local ok, result = pcall(rules.IsSeethingShoreMap, mapID)
        if ok then return result == true end
    end

    mapID = tonumber(mapID)
    return mapID == 907 or mapID == 1803
end


local function IsEyeOfTheStormChoice(info)
    if type(info) ~= "table" then return false end
    for _, key in ipairs({ "id", "mapID", "uiMapID", "instanceMapID" }) do
        if tonumber(info[key]) == 210 then return true end
    end

    local name = info.name
    if (not name or name == "") and BattleMaps.Battlegrounds and BattleMaps.Battlegrounds.GetName then
        local value = GetBattlegroundChoiceValue(info)
        if value then
            local ok, resolved = pcall(BattleMaps.Battlegrounds.GetName, BattleMaps.Battlegrounds, value)
            if ok then name = resolved end
        end
    end
    return NormalizeBattlegroundChoiceName(name):find("eyeofthestorm", 1, true) ~= nil
end

local function GetDefaultBattlegroundChoice()
    local maps = BattleMaps.Battlegrounds and BattleMaps.Battlegrounds.MAPS or {}
    for _, info in ipairs(maps) do
        if IsArathiBasinChoice(info) then
            return 112
        end
    end
    local first = maps[1]
    return GetBattlegroundChoiceValue(first) or 112
end

local Options = {
    selectedMapID = GetDefaultBattlegroundChoice(),
    refreshers = {},
    dropdowns = {},
    pages = {},
    activePage = "general",
}
BattleMaps.Options = Options

local OPTIONS_WIDTH = 720

local LEGACY_PAGE_ALIASES = {
    pins = "units",
    playerpins = "units",
    objectives = "bases",
    timers = "bases",
}

local function GetTemplate()
    return BackdropTemplateMixin and "BackdropTemplate" or nil
end

local function RequireWidget(name)
    local widgets = Options.Widgets
    return widgets and widgets[name]
end

local function MakeButton(...)
    local fn = RequireWidget("MakeButton")
    return fn and fn(...)
end

local function MakeDropdown(...)
    local fn = RequireWidget("MakeDropdown")
    return fn and fn(...)
end

local function SetFontColor(...)
    local fn = RequireWidget("SetFontColor")
    if fn then return fn(...) end
end

local function SetControlEnabled(...)
    local fn = RequireWidget("SetControlEnabled")
    if fn then return fn(...) end
end

function Options:NormalizePageKey(key)
    key = tostring(key or "general"):lower()
    return LEGACY_PAGE_ALIASES[key] or key
end

function Options:RegisterPage(key, label, height, createMethod, order)
    key = self:NormalizePageKey(key)
    if key == "" then return nil end

    self.pageDefinitions = self.pageDefinitions or {}
    self.pageDefinitionByKey = self.pageDefinitionByKey or {}

    local definition = self.pageDefinitionByKey[key]
    if not definition then
        definition = { key = key }
        self.pageDefinitionByKey[key] = definition
        self.pageDefinitions[#self.pageDefinitions + 1] = definition
    end

    definition.label = label or definition.label or key
    definition.height = tonumber(height) or definition.height or 550
    definition.createMethod = createMethod or definition.createMethod
    definition.order = tonumber(order) or definition.order or (#self.pageDefinitions * 10)

    table.sort(self.pageDefinitions, function(a, b)
        if (a.order or 0) == (b.order or 0) then
            return tostring(a.key) < tostring(b.key)
        end
        return (a.order or 0) < (b.order or 0)
    end)

    return definition
end

function Options:GetSettingsPageDefinitions()
    if type(self.pageDefinitions) == "table" and #self.pageDefinitions > 0 then
        return self.pageDefinitions
    end

    -- Fallback for unexpected load-order failures. The real definitions are
    -- registered by the page files after OptionsWidgets.lua is loaded.
    return {
        { key = "general", label = "General", height = 680, createMethod = "CreateGeneralPage", order = 10 },
        { key = "units", label = "Units", height = 650, createMethod = "CreateUnitsPage", order = 20 },
        { key = "bases", label = "Bases", height = 800, createMethod = "CreateBasesPage", order = 30 },
        { key = "carts", label = "Carts", height = 220, createMethod = "CreateCartsPage", order = 35 },
        { key = "flags", label = "Flags", height = 542, createMethod = "CreateFlagsPage", order = 40 },
        { key = "notifications", label = "Notifications", height = 650, createMethod = "CreateNotificationsPage", order = 50 },
    }
end

function Options:GetSettingsPageDefinition(key)
    key = self:NormalizePageKey(key)
    local byKey = self.pageDefinitionByKey
    if byKey and byKey[key] then return byKey[key] end

    for _, definition in ipairs(self:GetSettingsPageDefinitions()) do
        if definition.key == key then return definition end
    end
    return nil
end

function Options:GetSettingsPageHeight(key)
    local definition = self:GetSettingsPageDefinition(key)
    return definition and definition.height or 550
end

function Options:GetSettingsPageLabel(key)
    local definition = self:GetSettingsPageDefinition(key)
    return definition and definition.label or tostring(key or "")
end

function Options:CreateRegisteredPages(parent)
    for _, definition in ipairs(self:GetSettingsPageDefinitions()) do
        local method = definition.createMethod and self[definition.createMethod]
        if type(method) == "function" then
            method(self, parent)
        end
    end
end
function Options:GetSelectedInfo()
    return (BattleMaps.GetBattlegroundInfoForConfig
        and BattleMaps.GetBattlegroundInfoForConfig(self.selectedMapID))
        or BattleMaps.Battlegrounds:GetInfo(self.selectedMapID)
        or BattleMaps.Battlegrounds.MAPS[1]
end

function Options:GetPinTarget()
    return self:GetPlayerPinTarget()
end

function Options:GetPlayerPinTarget()
    return BattleMaps.Database:GetUnitsConfig(self.selectedMapID)
end

function Options:GetObjectiveTarget()
    return BattleMaps.Database:GetBasePinConfig(self.selectedMapID)
end

function Options:GetTimerTarget()
    return BattleMaps.Database:GetBaseTimerConfig(self.selectedMapID)
end

function Options:GetNotificationTarget()
    return BattleMaps.Database:GetNotificationConfig(self.selectedMapID)
end

-- Semantic wrappers for the user-facing options pages. These preserve the
-- existing SavedVariables buckets while allowing the UI to be organised as
-- Units / Bases / Flags.
function Options:GetUnitsTarget()
    return self:GetPlayerPinTarget()
end

function Options:GetBasesObjectiveTarget()
    return self:GetObjectiveTarget()
end

function Options:GetBasesTimerTarget()
    return self:GetTimerTarget()
end

function Options:GetCartsObjectiveTarget()
    return self:GetObjectiveTarget()
end

function Options:GetFlagsTarget()
    return BattleMaps.Database:GetFlagConfig(self.selectedMapID)
end

function Options:GetMapChoices()
    local choices = {}
    local seen = {}
    local maps = BattleMaps.Battlegrounds.MAPS or {}

    local function ResolveLabel(info, value, fallback)
        local label = type(info) == "table" and info.name or nil
        if (not label or label == "") and BattleMaps.Battlegrounds.GetName then
            local ok, resolved = pcall(BattleMaps.Battlegrounds.GetName, BattleMaps.Battlegrounds, value)
            if ok and resolved and resolved ~= "" then label = resolved end
        end
        return label or fallback or tostring(value)
    end

    local function AddChoice(info, forcedValue, fallbackLabel)
        local value = tonumber(forcedValue) or GetBattlegroundChoiceValue(info)
        if not value or seen[value] then return false end
        seen[value] = true
        choices[#choices + 1] = {
            value = value,
            label = ResolveLabel(info, value, fallbackLabel),
        }
        return true
    end

    local function FindChoice(predicate)
        for _, info in ipairs(maps) do
            if predicate(info) then return info end
        end
        return nil
    end

    -- Keep the two most frequently edited objective maps visible without
    -- scrolling. Arathi Basin is always first; Eye of the Storm is always
    -- second. Explicit GetInfo fallbacks also restore EotS when an older
    -- Battlegrounds.MAPS table omits it from the selector source list.
    local arathi = FindChoice(IsArathiBasinChoice)
        or (BattleMaps.GetArathiBasinInfo and BattleMaps.GetArathiBasinInfo())
    AddChoice(arathi, 112, "Arathi Basin")

    local eye = FindChoice(IsEyeOfTheStormChoice)
        or (BattleMaps.GetEyeOfTheStormInfo and BattleMaps.GetEyeOfTheStormInfo())
        or (BattleMaps.Battlegrounds.GetInfo and BattleMaps.Battlegrounds:GetInfo(210))
    AddChoice(eye, 210, "Eye of the Storm")

    for _, info in ipairs(maps) do
        if not IsArathiBasinChoice(info) and not IsEyeOfTheStormChoice(info) then
            AddChoice(info)
        end
    end
    return choices
end

function Options:GetAdjacentMapChoice(direction)
    local choices = self:GetMapChoices()
    local count = #choices
    if count == 0 then return nil end

    direction = tonumber(direction) or 1
    direction = direction < 0 and -1 or 1

    local currentIndex = 1
    for index, choice in ipairs(choices) do
        if tonumber(choice.value) == tonumber(self.selectedMapID) then
            currentIndex = index
            break
        end
    end

    local targetIndex = ((currentIndex - 1 + direction) % count) + 1
    return choices[targetIndex]
end

function Options:SelectAdjacentMap(direction)
    local choice = self:GetAdjacentMapChoice(direction)
    if not choice then return end

    self.liveMapSyncSerial = (self.liveMapSyncSerial or 0) + 1
    self.selectedMapID = tonumber(choice.value) or self.selectedMapID

    if self.mapSelector and self.mapSelector.menu then
        self.mapSelector.menu:Hide()
    end

    self:DisplaySelectedMap()
    self:Refresh()
end

function Options:EnsureMapEditMode()
    local mapFrame = BattleMaps.MapFrame
    if not mapFrame or not mapFrame.frame or not mapFrame.frame:IsShown() then return end
    if not mapFrame.editMode then mapFrame:BeginEdit() end
end

function Options:ShowColorPickerAboveOptions(settings, preserveDynamicClassContext)
    if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end

    if not preserveDynamicClassContext then
        ColorPickerFrame.BattleMapsDynamicClassColorContext = nil
        ColorPickerFrame.BattleMapsUseDynamicClassColor = nil
    end
    if ColorPickerFrame.BattleMapsDynamicClassButton then
        ColorPickerFrame.BattleMapsDynamicClassButton:Hide()
    end
    ColorPickerFrame:SetupColorPickerAndShow(settings)

    local function RaisePicker()
        local picker = ColorPickerFrame
        if not picker or not picker:IsShown() then return end

        if not picker.BattleMapsLayerRestoreHooked then
            picker.BattleMapsLayerRestoreHooked = true
            picker:HookScript("OnHide", function(frame)
                frame.BattleMapsDynamicClassColorContext = nil
                frame.BattleMapsUseDynamicClassColor = nil
                if frame.BattleMapsDynamicClassButton then
                    frame.BattleMapsDynamicClassButton:Hide()
                end
                if frame.BattleMapsLayerOwner ~= "BattleMaps" then return end
                frame.BattleMapsLayerOwner = nil

                local previousStrata = frame.BattleMapsPreviousStrata
                local previousLevel = frame.BattleMapsPreviousLevel
                frame.BattleMapsPreviousStrata = nil
                frame.BattleMapsPreviousLevel = nil

                if previousStrata then
                    pcall(frame.SetFrameStrata, frame, previousStrata)
                end
                if previousLevel then
                    pcall(frame.SetFrameLevel, frame, previousLevel)
                end
            end)
        end

        if picker.BattleMapsLayerOwner ~= "BattleMaps" then
            picker.BattleMapsPreviousStrata = picker:GetFrameStrata()
            picker.BattleMapsPreviousLevel = picker:GetFrameLevel()
        end
        picker.BattleMapsLayerOwner = "BattleMaps"

        pcall(picker.SetFrameStrata, picker, "TOOLTIP")
        local optionsLevel = self.frame and self.frame:GetFrameLevel() or 1200
        pcall(picker.SetFrameLevel, picker, optionsLevel + 300)
    end

    RaisePicker()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, RaisePicker)
    end
end

local function GetCurrentPlayerClassColor()
    if BattleMaps.Pins and BattleMaps.Pins.GetPlayerClassColor then
        return BattleMaps.Pins:GetPlayerClassColor()
    end

    local classFile = select(2, UnitClass("player"))
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

local function SetDynamicColorPickerRGB(r, g, b)
    local picker = ColorPickerFrame
    local colorPicker = picker and picker.Content and picker.Content.ColorPicker
    if colorPicker and type(colorPicker.SetColorRGB) == "function" then
        colorPicker:SetColorRGB(r, g, b)
        local swatch = picker.Content.ColorSwatchCurrent
        if swatch and type(swatch.SetColorTexture) == "function" then
            swatch:SetColorTexture(r, g, b)
        end
        return true
    end
    if picker and type(picker.SetColorRGB) == "function" then
        picker:SetColorRGB(r, g, b)
        return true
    end
    return false
end

function Options:GetDynamicColorPickerClassButton()
    -- ElvUI supplies ColorPPClass. With the unmodified Blizzard picker,
    -- provide the same action only for BattleMaps colors that support dynamic
    -- class mode, so the feature behaves consistently with either interface.
    if _G.ColorPPClass then
        return _G.ColorPPClass, false
    end

    local picker = ColorPickerFrame
    if not picker then return nil, false end
    if picker.BattleMapsDynamicClassButton then
        return picker.BattleMapsDynamicClassButton, true
    end

    local button = CreateFrame(
        "Button",
        "BattleMapsDynamicColorPickerClassButton",
        picker,
        "UIPanelButtonTemplate"
    )
    button:SetSize(104, 22)
    button:SetText("Class")

    local hexBox = picker.Content and picker.Content.HexBox
    if hexBox then
        button:SetPoint("BOTTOM", hexBox, "TOP", 0, 8)
    else
        button:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -18, 48)
    end
    button:Hide()
    picker.BattleMapsDynamicClassButton = button
    return button, true
end

function Options:ConfigureDynamicColorPickerClassButton()
    local classButton, battleMapsOwned = self:GetDynamicColorPickerClassButton()
    if not classButton or type(classButton.HookScript) ~= "function" then return end
    if battleMapsOwned then
        classButton:SetFrameLevel(ColorPickerFrame:GetFrameLevel() + 5)
        classButton:Show()
    end
    if classButton.BattleMapsDynamicClassHooked then return end
    classButton.BattleMapsDynamicClassHooked = true

    -- Mark the Class action before the picker updates its RGB value so the
    -- shared swatch callback does not turn the choice into a saved snapshot.
    classButton:HookScript("OnMouseDown", function()
        local picker = ColorPickerFrame
        if picker and picker.BattleMapsDynamicClassColorContext then
            picker.BattleMapsUseDynamicClassColor = true
        end
    end)
    classButton:HookScript("OnClick", function()
        local picker = ColorPickerFrame
        local context = picker and picker.BattleMapsDynamicClassColorContext
        if not context then return end

        picker.BattleMapsUseDynamicClassColor = true
        local r, g, b = GetCurrentPlayerClassColor()
        SetDynamicColorPickerRGB(r, g, b)

        context.setMode("class")
        context.refresh()
    end)
end

function Options:OpenDynamicClassColorPicker(context)
    local previousMode = context.getMode() == "class" and "class" or "custom"
    local savedColor = context.getColor()
    local color = type(savedColor) == "table" and savedColor or {}
    local previous = {
        r = BattleMaps.Clamp(tonumber(color.r or color[1]) or 1, 0, 1),
        g = BattleMaps.Clamp(tonumber(color.g or color[2]) or 0.82, 0, 1),
        b = BattleMaps.Clamp(tonumber(color.b or color[3]) or 0.22, 0, 1),
    }
    local initial = previous
    if previousMode == "class" then
        local r, g, b = GetCurrentPlayerClassColor()
        initial = { r = r, g = g, b = b }
    end

    if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then
        context.setMode(previousMode)
        self:Refresh()
        BattleMaps.Chat("The Blizzard color picker is unavailable.")
        return
    end

    local pickerContext = {
        setMode = context.setMode,
        refresh = context.refresh,
    }
    local function ApplyColor()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        local classR, classG, classB = GetCurrentPlayerClassColor()
        local matchesCurrentClass = math.abs(r - classR) < 0.004
            and math.abs(g - classG) < 0.004
            and math.abs(b - classB) < 0.004
        if ColorPickerFrame.BattleMapsUseDynamicClassColor and matchesCurrentClass then
            context.setMode("class")
        else
            ColorPickerFrame.BattleMapsUseDynamicClassColor = nil
            context.setColor({ r = r, g = g, b = b })
            context.setMode("custom")
        end
        context.refresh()
    end

    ColorPickerFrame.BattleMapsDynamicClassColorContext = pickerContext
    ColorPickerFrame.BattleMapsUseDynamicClassColor = previousMode == "class"
    self:ShowColorPickerAboveOptions({
        r = initial.r,
        g = initial.g,
        b = initial.b,
        hasOpacity = false,
        swatchFunc = ApplyColor,
        cancelFunc = function()
            context.setColor(previous)
            context.setMode(previousMode)
            context.refresh()
        end,
    }, true)
    ColorPickerFrame.BattleMapsDynamicClassColorContext = pickerContext
    ColorPickerFrame.BattleMapsUseDynamicClassColor = previousMode == "class"
    self:ConfigureDynamicColorPickerClassButton()
end

function Options:OpenPlayerArrowColorPicker()
    local db = BattleMaps.Database:Get()
    self:OpenDynamicClassColorPicker({
        getMode = function() return db.playerArrowColorMode end,
        setMode = function(mode) db.playerArrowColorMode = mode end,
        getColor = function() return db.playerArrowCustomColor end,
        setColor = function(color) db.playerArrowCustomColor = color end,
        refresh = function()
            self:Refresh()
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end,
    })
end

function Options:OpenHealerIconColorPicker()
    local target = self:GetUnitsTarget()
    self:OpenDynamicClassColorPicker({
        getMode = function() return target.healerIconColorMode end,
        setMode = function(mode) target.healerIconColorMode = mode end,
        getColor = function() return target.healerIconCustomColor end,
        setColor = function(color) target.healerIconCustomColor = color end,
        refresh = function()
            self:Refresh()
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end,
    })
end


function Options:OpenObjectivePulseColorPicker()
    local db = BattleMaps.Database:Get()
    local color = type(db.objectivePulseCustomColor) == "table" and db.objectivePulseCustomColor or {}
    local previous = {
        r = BattleMaps.Clamp(tonumber(color.r or color[1]) or 1, 0, 1),
        g = BattleMaps.Clamp(tonumber(color.g or color[2]) or 0.82, 0, 1),
        b = BattleMaps.Clamp(tonumber(color.b or color[3]) or 0.22, 0, 1),
    }

    if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then
        BattleMaps.Chat("The Blizzard colour picker is unavailable.")
        return
    end

    local function ApplyColor()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        db.objectivePulseCustomColor = { r = r, g = g, b = b }
        self:Refresh()
        if BattleMaps.Pins and BattleMaps.Pins.RefreshObjectivePulseColors then
            BattleMaps.Pins:RefreshObjectivePulseColors()
        end
    end

    self:ShowColorPickerAboveOptions({
        r = previous.r,
        g = previous.g,
        b = previous.b,
        hasOpacity = false,
        swatchFunc = ApplyColor,
        cancelFunc = function()
            db.objectivePulseCustomColor = previous
            self:Refresh()
            if BattleMaps.Pins and BattleMaps.Pins.RefreshObjectivePulseColors then
                BattleMaps.Pins:RefreshObjectivePulseColors()
            end
        end,
    })
end

function Options:OpenObjectiveTimerTextColorPicker()
    local settings = self:GetTimerTarget()
    self:OpenDynamicClassColorPicker({
        getMode = function() return settings.objectiveTimerTextColorMode end,
        setMode = function(mode) settings.objectiveTimerTextColorMode = mode end,
        getColor = function() return settings.objectiveTimerTextColor end,
        setColor = function(color) settings.objectiveTimerTextColor = color end,
        refresh = function()
            self:Refresh()
            if BattleMaps.Pins and BattleMaps.Pins.RefreshObjectiveTimerTextSettings then
                BattleMaps.Pins:RefreshObjectiveTimerTextSettings()
            end
        end,
    })
end

function Options:OpenFrameBackgroundColorPicker()
    local db = BattleMaps.Database:Get()
    local savedColor = type(db.frameBackgroundColor) == "table" and db.frameBackgroundColor or {}
    local previous = {
        r = BattleMaps.Clamp(tonumber(savedColor.r or savedColor[1]) or 0.015, 0, 1),
        g = BattleMaps.Clamp(tonumber(savedColor.g or savedColor[2]) or 0.015, 0, 1),
        b = BattleMaps.Clamp(tonumber(savedColor.b or savedColor[3]) or 0.015, 0, 1),
        a = BattleMaps.Clamp(tonumber(savedColor.a or savedColor[4]) or 0.12, 0, 1),
    }

    if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then
        BattleMaps.Chat("The Blizzard color picker is unavailable.")
        return
    end

    local function RefreshBackground()
        self:Refresh()
        if BattleMaps.MapFrame then BattleMaps.MapFrame:ApplyVisualSettings() end
    end
    local function ApplyColor()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        local a = type(ColorPickerFrame.GetColorAlpha) == "function"
            and ColorPickerFrame:GetColorAlpha() or previous.a
        db.frameBackgroundColor = {
            r = BattleMaps.Clamp(tonumber(r) or previous.r, 0, 1),
            g = BattleMaps.Clamp(tonumber(g) or previous.g, 0, 1),
            b = BattleMaps.Clamp(tonumber(b) or previous.b, 0, 1),
            a = BattleMaps.Clamp(tonumber(a) or previous.a, 0, 1),
        }
        RefreshBackground()
    end

    self:ShowColorPickerAboveOptions({
        r = previous.r,
        g = previous.g,
        b = previous.b,
        opacity = previous.a,
        hasOpacity = true,
        swatchFunc = ApplyColor,
        opacityFunc = ApplyColor,
        cancelFunc = function()
            db.frameBackgroundColor = previous
            RefreshBackground()
        end,
    })
end

function Options:IsSelectedMapTestActive()
    local mapFrame = BattleMaps.MapFrame
    return mapFrame ~= nil
        and mapFrame.testMode == true
        and tonumber(mapFrame.currentMapID) == tonumber(self.selectedMapID)
end

function Options:RefreshMapTestButton()
    if not self.mapTestButton then return end
    self.mapTestButton:SetText(self:IsSelectedMapTestActive() and "Stop" or "Test")
end

function Options:StopSelectedMapTest()
    local mapFrame = BattleMaps.MapFrame
    local wasActive = mapFrame and mapFrame.testMode == true

    if BattleMaps.Pins and BattleMaps.Pins.StopCaptureTimerTest then
        BattleMaps.Pins:StopCaptureTimerTest()
    end

    if mapFrame then
        if type(mapFrame.SetTestMode) == "function" then
            mapFrame:SetTestMode(false)
        else
            mapFrame.testMode = false
            if wasActive and BattleMaps.Pins and BattleMaps.Pins.RefreshAll then
                BattleMaps.Pins:RefreshAll(true)
            end
        end
    end

    if BattleMaps.ApplyMinimapVisibility then
        BattleMaps.ApplyMinimapVisibility()
    end
    self:RefreshMapTestButton()
end

function Options:DisplaySelectedMap(enterEditMode)
    if enterEditMode ~= false then
        self:StopSelectedMapTest()
    end

    local currentMapID = BattleMaps.ResolveCurrentBattlegroundMapID()
    local preview = not BattleMaps.IsInLiveBattleground()
        or currentMapID ~= self.selectedMapID
    if BattleMaps.MapFrame:ShowMap(self.selectedMapID, preview)
        and self.frame and self.frame:IsShown()
        and enterEditMode ~= false then
        self:EnsureMapEditMode()
    end
end

-- Synchronise the selector and map to the real battleground. This is kept
-- separate from DisplaySelectedMap so the dropdown can still preview another
-- battleground deliberately while the options window is open.
function Options:SyncToCurrentBattleground(mapID)
    if not BattleMaps.IsInLiveBattleground() then return false end

    mapID = tonumber(mapID) or BattleMaps.ResolveCurrentBattlegroundMapID()
    local mapInfo = mapID and BattleMaps.GetBattlegroundInfoForConfig
        and BattleMaps.GetBattlegroundInfoForConfig(mapID)
    if not mapID or not mapInfo then
        return false
    end

    self.selectedMapID = mapID
    BattleMaps.MapFrame.selectedMapID = mapID
    BattleMaps.MapFrame:SetLiveBattleground(mapID, true)

    if self.frame and self.frame:IsShown() then
        BattleMaps.MapFrame.frame:Show()
        self:EnsureMapEditMode()
        self:Refresh()
    end
    return true
end

function Options:ScheduleLiveMapSync()
    self.liveMapSyncSerial = (self.liveMapSyncSerial or 0) + 1
    local serial = self.liveMapSyncSerial
    local frame = self.frame

    local function TrySync()
        if serial ~= self.liveMapSyncSerial or not frame or not frame:IsShown() then return end
        self:SyncToCurrentBattleground()
    end

    TrySync()
    if C_Timer and C_Timer.After then
        for _, delay in ipairs({ 0.10, 0.35, 0.80, 1.50, 3.00, 5.00, 8.00 }) do
            C_Timer.After(delay, TrySync)
        end
    end
end

function Options:CreateHeader(frame)
    local header = CreateFrame("Frame", nil, frame, GetTemplate())
    self.header = header
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    header:SetHeight(82)
    header:SetFrameLevel(frame:GetFrameLevel() + 4)
    header:EnableMouse(true)
    if header.SetBackdrop then
        header:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        header:SetBackdropColor(0.018, 0.014, 0.010, 0.52)
        header:SetBackdropBorderColor(0.64, 0.45, 0.23, 0.58)
    end

    local banner = header:CreateTexture(nil, "ARTWORK")
    self.banner = banner
    banner:SetPoint("TOPLEFT", header, "TOPLEFT", 2, -2)
    banner:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -2, 2)
    banner:SetTexture("Interface\\AddOns\\BattleMaps\\Media\\banner.tga")
    banner:SetTexCoord(0, 1, 0, 1)

    local shade = header:CreateTexture(nil, "ARTWORK", nil, 1)
    shade:SetAllPoints(banner)
    shade:SetColorTexture(0.015, 0.010, 0.008, 0.30)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", header, "TOPLEFT", 20, -10)
    title:SetText(
        BattleMaps.ColorText(BattleMaps.COLORS.red, "Battle") ..
        BattleMaps.ColorText(BattleMaps.COLORS.parchmentLight, "Maps")
    )

    local subtitle = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -5)
    subtitle:SetPoint("RIGHT", header, "RIGHT", -116, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Independent battleground map, tactical pins, and notifications")
    subtitle:SetTextColor(0.90, 0.82, 0.68, 1)

    local version = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    version:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -10, 7)
    version:SetText(BattleMaps.VERSION or "")
    version:SetTextColor(0.72, 0.69, 0.64, 1)

    header:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then frame:StartMoving() end
    end)
    header:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint(1)
        local db = BattleMaps.Database:Get()
        db.optionsWindow.point = point
        db.optionsWindow.relativePoint = relativePoint
        db.optionsWindow.x = x
        db.optionsWindow.y = y
    end)
end

function Options:CreateMapSelector(frame)
    local selector = CreateFrame("Frame", nil, frame, GetTemplate())
    self.mapSelectorBar = selector
    selector:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -100)
    selector:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -100)
    selector:SetHeight(48)
    selector:SetFrameLevel(frame:GetFrameLevel() + 3)
    if selector.SetBackdrop then
        selector:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        selector:SetBackdropColor(0.028, 0.021, 0.016, 0.40)
        selector:SetBackdropBorderColor(0.64, 0.45, 0.23, 0.48)
    end

    local accent = selector:CreateTexture(nil, "BORDER")
    accent:SetPoint("TOPLEFT", selector, "TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", selector, "TOPRIGHT", -1, -1)
    accent:SetHeight(2)
    accent:SetColorTexture(0.70, 0.10, 0.055, 0.66)

    local label = selector:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", selector, "LEFT", 14, 0)
    label:SetText("Select Battleground")
    SetFontColor(label, BattleMaps.COLORS.parchmentLight)

    self.mapSelector = MakeDropdown(
        selector,
        "",
        168,
        -12,
        250,
        function() return self:GetMapChoices() end,
        function() return self.selectedMapID end,
        function(value)
            self.liveMapSyncSerial = (self.liveMapSyncSerial or 0) + 1
            self.selectedMapID = tonumber(value) or self.selectedMapID
            self:DisplaySelectedMap()
            self:Refresh()
        end
    )

    local function MakeMapCycleButton(direction)
        local button = MakeButton(selector, "", 28, 24)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("CENTER")
        icon:SetSize(18, 18)
        icon:SetTexture(direction < 0
            and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up"
            or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
        button.icon = icon

        button:SetScript("OnClick", function()
            self:SelectAdjacentMap(direction)
        end)

        button:HookScript("OnEnter", function(owner)
            local choice = self:GetAdjacentMapChoice(direction)
            GameTooltip:SetOwner(owner, "ANCHOR_TOP")
            GameTooltip:SetText(direction < 0 and "Previous battleground" or "Next battleground")
            if choice and choice.label then
                GameTooltip:AddLine(choice.label, 1.00, 0.68, 0.20)
            end
            GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function(owner)
            if GameTooltip:GetOwner() == owner then GameTooltip:Hide() end
        end)

        return button
    end

    local previous = MakeMapCycleButton(-1)
    previous:SetPoint("LEFT", self.mapSelector, "RIGHT", 8, 0)
    self.previousMapButton = previous

    local nextButton = MakeMapCycleButton(1)
    nextButton:SetPoint("LEFT", previous, "RIGHT", 4, 0)
    self.nextMapButton = nextButton

    local reset = MakeButton(selector, "", 30, 24)
    reset:SetPoint("RIGHT", selector, "RIGHT", -12, 0)

    local resetIcon = reset:CreateTexture(nil, "ARTWORK")
    resetIcon:SetPoint("CENTER")
    resetIcon:SetSize(17, 17)
    local atlasApplied = false
    if resetIcon.SetAtlas then
        atlasApplied = pcall(resetIcon.SetAtlas, resetIcon, "transmog-icon-revert")
    end
    if not atlasApplied then
        resetIcon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
    end
    reset.icon = resetIcon

    reset:HookScript("OnEnter", function(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText("Reset Map Settings")
        GameTooltip:AddLine(
            "Restore the selected battleground's authored size, zoom, pan, unit, objective, flag, cart, and timer defaults. The current screen position is preserved.",
            0.90, 0.90, 0.90, true)
        GameTooltip:AddLine("Global pin settings are not changed.", 0.62, 0.62, 0.62, true)
        GameTooltip:Show()
    end)
    reset:HookScript("OnLeave", function(owner)
        if GameTooltip:GetOwner() == owner then GameTooltip:Hide() end
    end)
    reset:SetScript("OnClick", function()
        local mapID = tonumber(self.selectedMapID)
        local mapFrame = BattleMaps.MapFrame
        local wasEditing = mapFrame and mapFrame.editMode == true
            and tonumber(mapFrame.currentMapID) == mapID

        self:StopSelectedMapTest()
        if wasEditing then
            -- End the old edit snapshot before replacing the selected map's
            -- saved settings, then resume editing from the reset defaults.
            mapFrame:CancelEdit()
        end

        if not BattleMaps.Database:ResetMapSettings(mapID) then
            BattleMaps.Chat("The selected battleground could not be reset.")
            return
        end

        if mapFrame and tonumber(mapFrame.currentMapID) == mapID then
            mapFrame:SetMapID(mapID, true)
            if wasEditing then mapFrame:BeginEdit() end
        end

        self:Refresh()
        if BattleMaps.Pins then BattleMaps.Pins:RefreshAll(true) end

        local mapName = BattleMaps.GetBattlegroundNameForConfig
            and BattleMaps.GetBattlegroundNameForConfig(mapID)
            or BattleMaps.Battlegrounds:GetName(mapID)
        BattleMaps.Chat("Reset all map settings for " .. tostring(mapName) .. ".")
    end)

    local test = MakeButton(selector, "Test", 58, 24)
    self.mapTestButton = test
    test:SetPoint("RIGHT", reset, "LEFT", -6, 0)
    test:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    test:SetScript("OnClick", function(_, mouseButton)
        if self:IsSelectedMapTestActive() then
            self:StopSelectedMapTest()
            self:Refresh()
            return
        end
        self:StartSelectedMapTest(mouseButton == "RightButton" and "horde" or "alliance")
    end)
    test:HookScript("OnEnter", function(button)
        local mapName = BattleMaps.GetBattlegroundNameForConfig
            and BattleMaps.GetBattlegroundNameForConfig(self.selectedMapID)
            or "selected battleground"
        local hasTimer = BattleMaps.GetCaptureTimerProfile
            and BattleMaps.GetCaptureTimerProfile(self.selectedMapID)
        local hasAzeriteSpawnPreview = IsSeethingShoreSelection(self.selectedMapID)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        if self:IsSelectedMapTestActive() then
            GameTooltip:SetText("Stop Test", 1, 0.82, 0.40)
            GameTooltip:AddLine("Stops the current map preview, including dummy units, objective previews, flag effects, and looping capture timers.", 0.82, 0.82, 0.82, true)
            GameTooltip:Show()
            return
        end

        GameTooltip:SetText("Test " .. tostring(mapName), 1, 0.82, 0.40)
        GameTooltip:AddLine("Shows dummy player, team, base, flag, and vehicle pins without entering a battleground.", 0.82, 0.82, 0.82, true)
        if hasTimer then
            GameTooltip:AddLine("Starts staggered timers at every capturable base.", 0.90, 0.90, 0.90, true)
            GameTooltip:AddLine("Alliance and Horde alternate continuously.", 0.90, 0.90, 0.90, true)
            GameTooltip:AddLine("The carried-objective preview uses the selected test faction.", 0.90, 0.90, 0.90, true)
            GameTooltip:AddLine("Left-click: Alliance carried flag / first base", 0.72, 0.82, 1.00)
            GameTooltip:AddLine("Right-click: Horde carried flag / first base", 1.00, 0.54, 0.48)
        elseif hasAzeriteSpawnPreview then
            GameTooltip:AddLine("Starts two independent Azerite spawning cycles.", 0.90, 0.90, 0.90, true)
            GameTooltip:AddLine("The Base Assault progress and countdown settings apply to both previews.", 0.90, 0.90, 0.90, true)
        else
            GameTooltip:AddLine("This map has no delayed capture timer.", 0.62, 0.62, 0.62, true)
        end
        GameTooltip:Show()
    end)
    test:HookScript("OnLeave", function(button)
        if GameTooltip:GetOwner() == button then GameTooltip:Hide() end
    end)
end


local function ApplyPageNavButtonStyle(button, selected, hovered)
    if not button then return end
    selected = selected == true
    hovered = hovered == true

    if button.brandFill then
        if selected then
            button.brandFill:SetColorTexture(0.72, 0.095, 0.045, 0.98)
        elseif hovered then
            button.brandFill:SetColorTexture(0.44, 0.055, 0.034, 0.96)
        else
            button.brandFill:SetColorTexture(0.18, 0.030, 0.024, 0.82)
        end
    end

    local fontString = button.GetFontString and button:GetFontString()
    if fontString then
        if selected then
            fontString:SetTextColor(1.00, 0.88, 0.36, 1)
        else
            fontString:SetTextColor(1.00, 0.68, 0.20, 1)
        end
    end

    if button.pageNavActiveBar then
        button.pageNavActiveBar:SetShown(selected)
    end
    if button.pageNavTopLine then
        button.pageNavTopLine:SetAlpha(selected and 0.95 or 0.34)
    end
    if button.pageNavSideGlow then
        button.pageNavSideGlow:SetShown(selected)
    end
end

local function DecoratePageNavButton(button)
    if not button or button.BattleMapsPageNavDecorated then return button end
    button.BattleMapsPageNavDecorated = true

    local topLine = button:CreateTexture(nil, "BORDER")
    topLine:SetPoint("TOPLEFT", button, "TOPLEFT", 5, -4)
    topLine:SetPoint("TOPRIGHT", button, "TOPRIGHT", -5, -4)
    topLine:SetHeight(1)
    topLine:SetColorTexture(1.00, 0.54, 0.12, 0.34)
    button.pageNavTopLine = topLine

    local activeBar = button:CreateTexture(nil, "OVERLAY")
    activeBar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 5, 4)
    activeBar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 4)
    activeBar:SetHeight(3)
    activeBar:SetColorTexture(1.00, 0.64, 0.10, 0.95)
    activeBar:Hide()
    button.pageNavActiveBar = activeBar

    local sideGlow = button:CreateTexture(nil, "ARTWORK")
    sideGlow:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    sideGlow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    sideGlow:SetColorTexture(1.00, 0.16, 0.05, 0.18)
    sideGlow:Hide()
    button.pageNavSideGlow = sideGlow

    button:HookScript("OnEnter", function(self)
        ApplyPageNavButtonStyle(self, self.BattleMapsPageNavSelected == true, true)
    end)
    button:HookScript("OnLeave", function(self)
        ApplyPageNavButtonStyle(self, self.BattleMapsPageNavSelected == true, false)
    end)
    ApplyPageNavButtonStyle(button, false, false)
    return button
end

local function DecoratePageCycleButton(button)
    if not button or button.BattleMapsPageCycleDecorated then return button end
    button.BattleMapsPageCycleDecorated = true
    if button.brandFill then
        button.brandFill:SetColorTexture(0.13, 0.030, 0.024, 0.86)
    end
    local ring = button:CreateTexture(nil, "BORDER")
    ring:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    ring:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
    ring:SetColorTexture(1.00, 0.56, 0.10, 0.12)
    button.pageCycleRing = ring
    button:HookScript("OnEnter", function(self)
        if self.brandFill and self:IsEnabled() then
            self.brandFill:SetColorTexture(0.38, 0.050, 0.030, 0.96)
        end
        if self.pageCycleRing then self.pageCycleRing:SetAlpha(0.38) end
    end)
    button:HookScript("OnLeave", function(self)
        if self.brandFill then
            self.brandFill:SetColorTexture(0.13, 0.030, 0.024, self:IsEnabled() and 0.86 or 0.42)
        end
        if self.pageCycleRing then self.pageCycleRing:SetAlpha(1) end
    end)
    return button
end

function Options:CreateTabs(frame)
    local tabs = self:GetSettingsPageDefinitions()

    local rowY = -156
    local navButtonSize = 28
    local navGap = 8
    local tabGap = 4
    local outerPad = 18
    local firstTabX = outerPad + navButtonSize + navGap
    local nextButtonX = OPTIONS_WIDTH - outerPad - navButtonSize
    local availableTabWidth = math.max(1, (nextButtonX - navGap) - firstTabX)
    local tabCount = math.max(1, #tabs)
    local tabWidth = math.floor((availableTabWidth - ((tabCount - 1) * tabGap)) / tabCount)
    tabWidth = math.max(78, math.min(112, tabWidth))

    local tabStrip = CreateFrame("Frame", nil, frame, GetTemplate())
    self.settingsPageTabStrip = tabStrip
    tabStrip:SetFrameLevel(frame:GetFrameLevel() + 1)
    tabStrip:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, rowY + 6)
    tabStrip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -48, rowY + 6)
    tabStrip:SetHeight(34)
    if tabStrip.SetBackdrop then
        tabStrip:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        tabStrip:SetBackdropColor(0.035, 0.020, 0.016, 0.30)
        tabStrip:SetBackdropBorderColor(0.55, 0.36, 0.16, 0.36)
    end
    local stripAccent = tabStrip:CreateTexture(nil, "BORDER")
    stripAccent:SetPoint("TOPLEFT", tabStrip, "TOPLEFT", 1, -1)
    stripAccent:SetPoint("TOPRIGHT", tabStrip, "TOPRIGHT", -1, -1)
    stripAccent:SetHeight(1)
    stripAccent:SetColorTexture(1.00, 0.46, 0.10, 0.22)

    self.tabButtons = {}
    for index, info in ipairs(tabs) do
        local button = DecoratePageNavButton(MakeButton(frame, info.label, tabWidth, 24))
        button:SetFrameLevel(frame:GetFrameLevel() + 3)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", firstTabX + ((index - 1) * (tabWidth + tabGap)), rowY)
        button:SetScript("OnClick", function() self:ShowPage(info.key) end)
        self.tabButtons[info.key] = button
    end

    local function MakeSettingsCycleButton(direction)
        local button = DecoratePageCycleButton(MakeButton(frame, "", 28, 24))
        button:SetFrameLevel(frame:GetFrameLevel() + 8)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("CENTER")
        icon:SetSize(18, 18)
        icon:SetTexture(direction < 0
            and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up"
            or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
        button.icon = icon
        button:SetScript("OnClick", function() self:SelectAdjacentSettingsPage(direction) end)
        button:HookScript("OnEnter", function(owner)
            GameTooltip:SetOwner(owner, direction < 0 and "ANCHOR_RIGHT" or "ANCHOR_LEFT")
            GameTooltip:SetText(direction < 0 and "Previous settings page" or "Next settings page")
            local nextKey = self:GetAdjacentSettingsPage(direction)
            if nextKey then
                local nextButton = self.tabButtons and self.tabButtons[nextKey]
                local label = nextButton and nextButton:GetText() or nextKey
                GameTooltip:AddLine(tostring(label), 1.00, 0.68, 0.20)
            end
            GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function(owner)
            if GameTooltip:GetOwner() == owner then GameTooltip:Hide() end
        end)
        return button
    end

    self.previousSettingsPageButton = MakeSettingsCycleButton(-1)
    self.previousSettingsPageButton:SetPoint("TOPLEFT", frame, "TOPLEFT", outerPad, rowY)

    self.nextSettingsPageButton = MakeSettingsCycleButton(1)
    self.nextSettingsPageButton:SetPoint("TOPLEFT", frame, "TOPLEFT", nextButtonX, rowY)
end

function Options:StartSelectedMapTest(faction)
    if BattleMaps.IsInLiveBattleground() then
        BattleMaps.Chat("The map test is available only outside a live battleground.")
        return
    end

    local mapID = tonumber(self.selectedMapID)
    if not mapID then
        BattleMaps.Chat("Select a battleground before starting the test.")
        return
    end

    faction = faction == "horde" and "horde" or "alliance"

    local mapFrame = BattleMaps.MapFrame

    self:StopSelectedMapTest()
    if BattleMaps.Pins then
        BattleMaps.Pins.previewPOICache[mapID] = nil
        BattleMaps.Pins.previewPOINextAttempt[mapID] = nil
        BattleMaps.Pins.captureTimerTestFaction = faction
    end

    if self.mapSelector and self.mapSelector.menu then
        self.mapSelector.menu:Hide()
    end

    -- The selector already displays the chosen battleground. Test mode must
    -- not reapply frame placement, reset zoom/pan, or change Edit-mode state.
    if not mapFrame or tonumber(mapFrame.currentMapID) ~= mapID then
        BattleMaps.Chat("The selected battleground is not currently displayed. Select it again before testing.")
        return
    end

    mapFrame.selectedMapID = mapID
    mapFrame.previewMode = true
    if mapFrame.frame then mapFrame.frame:Show() end
    mapFrame:SetTestMode(true)
    if BattleMaps.ApplyMinimapVisibility then
        BattleMaps.ApplyMinimapVisibility()
    end
    self:Refresh()

    local attempts = 0
    local started = false
    local function TryStart()
        if started then return end
        attempts = attempts + 1

        local pins = BattleMaps.Pins
        if pins then
            pins:RefreshDummyPins()
            local profile = BattleMaps.GetCaptureTimerProfile
                and BattleMaps.GetCaptureTimerProfile(mapID)
            local mapName = BattleMaps.GetBattlegroundNameForConfig
                and BattleMaps.GetBattlegroundNameForConfig(mapID)
                or tostring(mapID)

            if profile then
                local ok, detail = pins:StartCaptureTimerTest(mapID, faction)
                if ok then
                    started = true
                    BattleMaps.Debug("Test mode", tostring(mapName), tostring(detail))
                    return
                end

                if attempts >= 8 then
                    BattleMaps.Chat(detail or "The capture-timer preview could not be started.")
                    return
                end
            else
                started = true
                BattleMaps.Debug(
                    "Test mode",
                    tostring(mapName),
                    IsSeethingShoreSelection(mapID) and "two Azerite spawn cycles"
                        or "no delayed capture timer"
                )
                return
            end
        elseif attempts >= 8 then
            BattleMaps.Chat("BattleMaps pin rendering is unavailable.")
            return
        end

        if C_Timer and C_Timer.After then
            C_Timer.After(0.10, TryStart)
        end
    end

    TryStart()
end

function Options:GetAdjacentSettingsPage(direction)
    local definitions = self:GetSettingsPageDefinitions()
    local active = self:NormalizePageKey(self.activePage or "general")
    local currentIndex = 1
    for index, definition in ipairs(definitions) do
        if definition.key == active then
            currentIndex = index
            break
        end
    end

    local nextIndex = currentIndex + (direction < 0 and -1 or 1)
    if nextIndex < 1 then nextIndex = #definitions end
    if nextIndex > #definitions then nextIndex = 1 end
    return definitions[nextIndex] and definitions[nextIndex].key or "general"
end

function Options:SelectAdjacentSettingsPage(direction)
    local key = self:GetAdjacentSettingsPage(direction)
    if key then self:ShowPage(key) end
end

function Options:ShowPage(key)
    for _, dropdown in ipairs(self.dropdowns or {}) do
        if dropdown.menu then dropdown.menu:Hide() end
    end
    key = self:NormalizePageKey(key)
    if not self.pages[key] then key = "general" end
    self.activePage = key
    for pageKey, page in pairs(self.pages) do page:SetShown(pageKey == key) end
    for tabKey, button in pairs(self.tabButtons or {}) do
        local selected = tabKey == key
        button.BattleMapsPageNavSelected = selected
        if selected then
            button:LockHighlight()
            button:SetButtonState("PUSHED", true)
        else
            button:UnlockHighlight()
            button:SetButtonState("NORMAL", false)
        end
        ApplyPageNavButtonStyle(button, selected, false)
    end

    local targetHeight = self:GetSettingsPageHeight(key)
    if self.frame and targetHeight and math.abs(self.frame:GetHeight() - targetHeight) > 0.5 then
        self.frame:SetHeight(targetHeight)
    end
end

function Options:Create()
    if self.frame then return self.frame end

    -- Use a plain backdrop frame instead of BasicFrameTemplateWithInset.
    -- Blizzard's template contains opaque art layers that remain dark even
    -- after Bg/Inset are hidden, which made alpha changes appear ineffective.
    local frame = CreateFrame("Frame", "BattleMapsOptionsWindow", UIParent, GetTemplate())
    self.frame = frame
    frame:SetSize(OPTIONS_WIDTH, self:GetSettingsPageHeight(self.activePage))
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(1200)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0.018, 0.014, 0.011, 0.56)
        frame:SetBackdropBorderColor(0.60, 0.43, 0.24, 0.92)
    end
    table.insert(UISpecialFrames, "BattleMapsOptionsWindow")

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    self.closeButton = closeButton
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 3, 3)
    closeButton:SetFrameLevel(frame:GetFrameLevel() + 20)
    closeButton:SetScript("OnClick", function() frame:Hide() end)

    local body = CreateFrame("Frame", nil, frame, GetTemplate())
    self.body = body
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -92)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    body:SetFrameLevel(frame:GetFrameLevel() + 1)
    if body.SetBackdrop then
        body:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        body:SetBackdropColor(0.020, 0.016, 0.013, 0.78)
        body:SetBackdropBorderColor(0.53, 0.37, 0.18, 0.30)
    end

    -- Keep only a faint default-UI texture so the world remains visible.
    local bodyTexture = body:CreateTexture(nil, "BACKGROUND", nil, 1)
    bodyTexture:SetAllPoints()
    bodyTexture:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
    bodyTexture:SetVertexColor(0.20, 0.16, 0.12, 0.12)
    self.bodyTexture = bodyTexture

    frame:SetScript("OnShow", function()
        -- BattleMaps' full-screen map uses an addon-owned TOOLTIP-strata overlay
        -- so it can sit above Blizzard's World Map without entering the protected
        -- MapCanvas hierarchy. Keep the options window above that overlay.
        frame:SetFrameStrata("TOOLTIP")
        frame:SetFrameLevel(1200)
        frame:Raise()

        local mapFrame = BattleMaps.MapFrame
        -- Loading screens can hide and re-show a custom window. Do not replace
        -- the original pre-open state every time that happens.
        if not self.mapStateBeforeOpen then
            self.mapStateBeforeOpen = {
                shown = mapFrame.frame and mapFrame.frame:IsShown() == true,
                mapID = mapFrame.currentMapID,
                previewMode = mapFrame.previewMode == true,
            }
        end

        if not self:SyncToCurrentBattleground() then
            if BattleMaps.IsInLiveBattleground() then
                -- Do not paint the previous selector value (usually Warsong
                -- Gulch) while the live map is still resolving after a load.
                -- The scheduled sync below will show the real map as soon as
                -- its UI map ID or localized instance name is available.
                if mapFrame.previewMode then
                    mapFrame:Hide()
                end
                self:Refresh()
            else
                self:DisplaySelectedMap()
                self:Refresh()
            end
        end
        self:EnsureMapEditMode()
        self:ScheduleLiveMapSync()
    end)
    frame:SetScript("OnHide", function()
        self.liveMapSyncSerial = (self.liveMapSyncSerial or 0) + 1
        self:StopSelectedMapTest()
        if BattleMaps.Notifications then BattleMaps.Notifications:HideMover() end
        for _, dropdown in ipairs(self.dropdowns or {}) do
            if dropdown.menu then dropdown.menu:Hide() end
        end

        local mapFrame = BattleMaps.MapFrame

        -- Closing the options window also ends map editing. Saving remains an
        -- explicit action; closing without Save restores the pre-edit layout.
        if mapFrame and mapFrame.editMode then
            mapFrame:CancelEdit()
        end

        local currentMapID = BattleMaps.ResolveCurrentBattlegroundMapID()

        -- Never restore an out-of-instance preview after the player has entered
        -- a battleground. The live battleground owns the visible map.
        if BattleMaps.IsInLiveBattleground() and currentMapID then
            self.selectedMapID = currentMapID
            mapFrame.selectedMapID = currentMapID
            mapFrame:SetLiveBattleground(currentMapID, true)

            local previous = self.mapStateBeforeOpen
            local db = BattleMaps.Database:Get()
            if not mapFrame.editMode
                and not db.autoShow
                and previous
                and not previous.shown then
                mapFrame:Hide()
            else
                mapFrame.frame:Show()
            end
        elseif mapFrame and not mapFrame.editMode then
            local previous = self.mapStateBeforeOpen
            if previous and previous.shown and previous.mapID then
                mapFrame:ShowMap(previous.mapID, previous.previewMode)
            elseif previous and not previous.shown then
                mapFrame:Hide()
            end
        end
        self.mapStateBeforeOpen = nil
    end)

    self:CreateHeader(frame)
    self:CreateMapSelector(frame)
    self:CreateTabs(frame)

    local pageHolder = CreateFrame("Frame", nil, frame)
    self.pageHolder = pageHolder
    pageHolder:SetFrameLevel(frame:GetFrameLevel() + 3)
    pageHolder:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -190)
    pageHolder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 22)

    self:CreateRegisteredPages(pageHolder)
    self:ShowPage(self.activePage)
    return frame
end

function Options:Refresh()
    self:Create()
    for _, widget in ipairs(self.refreshers) do
        if widget.Refresh then widget:Refresh() end
    end

    local db = BattleMaps.Database:Get()
    local objectiveSettings = self:GetObjectiveTarget()
    local timerSettings = self:GetTimerTarget()
    local notificationSettings = self:GetNotificationTarget()
    SetControlEnabled(self.combatTeamCheck, true)
    local unitsSettings = self:GetUnitsTarget()
    local playerStyleUsesColor = unitsSettings.playerPinStyle == "arrow"
        or unitsSettings.playerPinStyle == "team"
    local playerStyleUsesTeamSize = unitsSettings.playerPinStyle == "team"
    SetControlEnabled(self.playerColorControl, playerStyleUsesColor)
    if self.playerArrowSizeSlider then self.playerArrowSizeSlider:SetShown(not playerStyleUsesTeamSize) end
    if self.playerTeamPinSizeNote then
        self.playerTeamPinSizeNote:SetShown(playerStyleUsesTeamSize)
        self.playerTeamPinSizeNote:SetText(string.format(
            "Team Pin Size\nUses Team Members Size: %d px",
            tonumber(unitsSettings.teamMemberPinSize) or 12
        ))
    end
    local fovEnabled = unitsSettings.playerFovStyle == "soft"
        or unitsSettings.playerFovStyle == "waves"
        or unitsSettings.playerFovStyle == "spotlight"
    SetControlEnabled(self.playerFovScaleSlider, fovEnabled)
    SetControlEnabled(self.playerFovAlphaSlider, fovEnabled)
    local spotlightEnabled = unitsSettings.playerFovStyle == "spotlight"
    SetControlEnabled(self.playerFovSpotlightAlphaSlider, spotlightEnabled)
    SetControlEnabled(self.playerFovBeamAlphaSlider, spotlightEnabled)
    SetControlEnabled(self.playerFovArcAlphaSlider, spotlightEnabled)
    local teamStackingEnabled = unitsSettings.stackTeamPins ~= false
    SetControlEnabled(self.excludePlayerArrowFromStackCheck, teamStackingEnabled)
    SetControlEnabled(self.teamPinStackOverlapSlider, teamStackingEnabled)
    SetControlEnabled(self.teamPinStackDirectionDropdown, teamStackingEnabled)

    local objectiveTypes = BattleMaps.GetObjectiveCapabilities
        and BattleMaps.GetObjectiveCapabilities(self.selectedMapID)
        or { stationary = true, carried = true, vehicle = true }
    SetControlEnabled(self.stationaryObjectiveSlider, objectiveTypes.stationary)
    SetControlEnabled(self.carriedObjectiveSlider, objectiveTypes.carried)
    local trailEnabled = objectiveTypes.carried and objectiveSettings.showFlagCarrierTrail == true
    local trailStyle = objectiveSettings.carriedTrailStyle
    local isKotmoguSelection = BattleMaps.ObjectiveRules
        and BattleMaps.ObjectiveRules.IsTempleOfKotmoguMap
        and BattleMaps.ObjectiveRules.IsTempleOfKotmoguMap(self.selectedMapID)
    local trailUsesHistory = trailStyle ~= "tether"
    SetControlEnabled(self.flagCarrierTrailCheck, objectiveTypes.carried)
    SetControlEnabled(self.flagTrailStyleSelector, trailEnabled)
    SetControlEnabled(self.carriedObjectiveFlashCheck, objectiveTypes.carried)
    SetControlEnabled(self.flagTrailDurationSlider, trailEnabled and trailUsesHistory)
    SetControlEnabled(self.flagTrailSizeSlider, trailEnabled)
    SetControlEnabled(self.flagTrailDetailSlider, trailEnabled and trailUsesHistory)
    SetControlEnabled(self.kotmoguEnemyFactionColorCheck, objectiveTypes.carried and isKotmoguSelection == true)
    SetControlEnabled(self.flagFlashStrengthSlider, objectiveTypes.carried and objectiveSettings.flashCarriedObjectives == true)
    SetControlEnabled(self.flagFlashPeriodSlider, objectiveTypes.carried and objectiveSettings.flashCarriedObjectives == true)
    SetControlEnabled(self.vehicleObjectiveSlider, objectiveTypes.vehicle)

    local pulseEnabled = timerSettings.showObjectivePulseAnimations ~= false
    local captureTimerEnabled = timerSettings.showObjectiveCaptureTimers ~= false
    local captureProfile = BattleMaps.GetCaptureTimerProfile
        and BattleMaps.GetCaptureTimerProfile(self.selectedMapID)
    local captureMapSupported = captureProfile ~= nil
    local seethingSpawnProgressSupported = IsSeethingShoreSelection(self.selectedMapID)
    local progressMapSupported = captureMapSupported or seethingSpawnProgressSupported
    local captureTimerControlsEnabled = progressMapSupported and captureTimerEnabled
    local capturePulseEnabled = captureTimerControlsEnabled
        and timerSettings.pulseObjectiveDuringCaptureTimer ~= false

    -- Seething Shore reuses the Base Assault progress and countdown controls
    -- for timed Azerite spawning.  Completion-only base pulse controls remain
    -- disabled there because Azerite collection has a separate lifecycle.
    SetControlEnabled(self.objectiveCaptureTimerCheck, progressMapSupported)
    SetControlEnabled(self.captureTimerPulseCheck, captureTimerControlsEnabled)
    SetControlEnabled(self.objectiveCaptureFillDirection, captureTimerControlsEnabled)
    SetControlEnabled(self.capturePulseAlphaSlider, capturePulseEnabled)
    SetControlEnabled(self.objectivePreCaptureFlashCheck, captureTimerControlsEnabled)
    SetControlEnabled(self.objectivePreCaptureFlashThresholdSlider,
        captureTimerControlsEnabled and timerSettings.flashObjectiveBeforeCapture == true)
    SetControlEnabled(self.objectivePreCaptureFlashBrightnessSlider,
        captureTimerControlsEnabled and timerSettings.flashObjectiveBeforeCapture == true)
    local blitzUncapMapSupported = captureMapSupported
        and BattleMaps.IsObjectiveBlitzUncapMap
        and BattleMaps.IsObjectiveBlitzUncapMap(self.selectedMapID)
    local capCountdownTextEnabled = captureTimerControlsEnabled and timerSettings.showObjectiveTimerText ~= false
    local blitzUncapTextEnabled = captureTimerControlsEnabled
        and blitzUncapMapSupported
        and timerSettings.showObjectiveBlitzUncapText == true
    local objectiveTimerTextSettingsEnabled = capCountdownTextEnabled or blitzUncapTextEnabled
    SetControlEnabled(self.objectiveTimerTextCheck, captureTimerControlsEnabled)
    SetControlEnabled(self.objectiveBlitzUncapTextCheck, captureTimerControlsEnabled and blitzUncapMapSupported)
    SetControlEnabled(self.objectiveTimerTextThresholdSlider, objectiveTimerTextSettingsEnabled)
    SetControlEnabled(self.objectiveTimerTextSizeSlider, objectiveTimerTextSettingsEnabled)
    SetControlEnabled(self.objectiveTimerTextAlphaSlider, objectiveTimerTextSettingsEnabled)
    SetControlEnabled(self.objectiveTimerTextFontDropdown, objectiveTimerTextSettingsEnabled)
    SetControlEnabled(self.objectiveTimerTextOffsetXSlider, objectiveTimerTextSettingsEnabled)
    SetControlEnabled(self.objectiveTimerTextOffsetYSlider, objectiveTimerTextSettingsEnabled)
    SetControlEnabled(self.objectiveTimerTextColorControl, objectiveTimerTextSettingsEnabled)
    self:RefreshMapTestButton()
    SetControlEnabled(self.mapTestButton, not BattleMaps.IsInLiveBattleground())
    SetControlEnabled(self.objectivePulseCheck, captureMapSupported and captureTimerEnabled)
    SetControlEnabled(self.objectiveCaptureAfterPulseAlphaSlider,
        captureMapSupported and captureTimerEnabled and pulseEnabled)
    SetControlEnabled(self.objectiveCapturePulseCountInput,
        captureMapSupported and captureTimerEnabled and pulseEnabled)

    local notificationsEnabled = notificationSettings.enabled == true
    SetControlEnabled(self.notificationFactionCheck, notificationsEnabled)
    SetControlEnabled(self.notificationWorldMapBlizzardCheck, notificationsEnabled)
    SetControlEnabled(self.notificationAnchorMode, notificationsEnabled)
    SetControlEnabled(self.notificationMapSide, notificationsEnabled and notificationSettings.anchorMode == "MAP")
    SetControlEnabled(self.notificationAlignment, notificationsEnabled)
    SetControlEnabled(self.notificationX, notificationsEnabled)
    SetControlEnabled(self.notificationY, notificationsEnabled)
    SetControlEnabled(self.notificationScale, notificationsEnabled)
    SetControlEnabled(self.notificationWidth, notificationsEnabled)

    if self.notificationMoveButton then
        self.notificationMoveButton:SetEnabled(notificationsEnabled)
        self.notificationMoveButton:SetText(
            BattleMaps.Notifications and BattleMaps.Notifications.moverUnlocked
                and "Lock Position" or "Move Notifications"
        )
    end

    self:ShowPage(self.activePage)
end

function Options:Open()
    local frame = self:Create()
    local db = BattleMaps.Database:Get()
    frame:ClearAllPoints()
    frame:SetPoint(
        db.optionsWindow.point or "CENTER",
        UIParent,
        db.optionsWindow.relativePoint or "CENTER",
        tonumber(db.optionsWindow.x) or 0,
        tonumber(db.optionsWindow.y) or 0
    )
    frame:Show()
    frame:Raise()
    self:EnsureMapEditMode()
end
