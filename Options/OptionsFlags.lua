local _, BattleMaps = ...
local Options = BattleMaps and BattleMaps.Options
if not Options or not Options.Widgets then return end

local W = Options.Widgets
local MakeCheckbox = W.MakeCheckbox
local AddControlTooltip = W.AddControlTooltip
local MakeResetIconButton = W.MakeResetIconButton
local MakePanel = W.MakePanel
local MakeSlider = W.MakeSlider
local MakeDropdown = W.MakeDropdown

function Options:CreateFlagsPage(parent)
    local db = BattleMaps.Database:Get()
    local page = CreateFrame("Frame", nil, parent)
    self.pages.flags = page
    page:SetAllPoints(parent)

    self.flagsGlobalCheck = MakeCheckbox(page, "Use global flag settings", 4, -2,
        function()
            return not BattleMaps.Database.MapUsesGlobalObjectiveSettings
                or BattleMaps.Database:MapUsesGlobalObjectiveSettings(self.selectedMapID)
        end,
        function(value)
            if BattleMaps.Database.SetMapUsesGlobalObjectiveSettings then
                BattleMaps.Database:SetMapUsesGlobalObjectiveSettings(self.selectedMapID, value)
            else
                db.useGlobalObjectiveSettings = value
                db.useGlobalPinSettings = db.useGlobalPlayerPinSettings ~= false and db.useGlobalObjectiveSettings ~= false
            end
            self:Refresh()
            if BattleMaps.Pins then BattleMaps.Pins:RefreshFlags() end
        end)
    AddControlTooltip(self.flagsGlobalCheck, "Use global flag settings",
        "When enabled, the selected battleground uses the shared flag/base/cart pin settings. Disable it to edit only the selected battleground.")

    local resetFlags = MakeResetIconButton(page, "Reset flags", "Restores carried-objective size, flag trail, and flag flash settings for this page to their defaults.", function()
        if BattleMaps.Database.ResetFlags then
            BattleMaps.Database:ResetFlags(self.selectedMapID)
        else
            local target = self:GetFlagsTarget()
            target.carrierObjectivePinScale = 1
            target.showFlagCarrierTrail = true
            target.carriedTrailStyle = "breadcrumbs"
            target.carriedTrailDuration = 20.00
            target.carriedTrailDotScale = 1.25
            target.carriedTrailDetail = 16
            target.factionColorEnemyKotmoguOrbs = true
            target.flashCarriedObjectives = true
            target.carriedObjectiveFlashPeriod = 0.55
            target.carriedObjectiveFlashStrength = 0.40
        end
        self:Refresh()
        if BattleMaps.Pins then
            BattleMaps.Pins:RefreshFlags()
            BattleMaps.Pins:RefreshDummyPins()
        end
    end)
    resetFlags:SetPoint("TOPRIGHT", page, "TOPRIGHT", -4, -2)

    local function RefreshFlagPreview(clearTrail)
        if BattleMaps.Pins then
            if clearTrail and BattleMaps.Pins.ClearFlagCarrierTrails then
                BattleMaps.Pins:ClearFlagCarrierTrails()
            end
            BattleMaps.Pins:RefreshFlags()
            BattleMaps.Pins:RefreshDummyPins()
        end
    end

    local flags = MakePanel(page, "Flag pins", 0, -34, 684, 84)
    self.carriedObjectiveSlider = MakeSlider(flags, "Carried flags", 12, -30, 0.50, 2.50, 0.05,
        function()
            local target = self:GetFlagsTarget()
            return tonumber(target.carrierObjectivePinScale) or tonumber(target.objectivePinScale) or 1
        end,
        function(value)
            self:GetFlagsTarget().carrierObjectivePinScale = value
            RefreshFlagPreview()
        end,
        function(value) return string.format("%.2fx", value) end,
        304)
    AddControlTooltip(self.carriedObjectiveSlider, "Carried flags",
        "Scales carried-objective pins such as CTF flags, the Eye of the Storm flag, and Kotmogu orbs when they are represented as carried objectives.")

    local columnLeftX = 10
    local columnCenterX = 210
    local columnRightX = 500
    local columnLeftWidth = 180
    local columnCenterWidth = 250
    local columnRightWidth = 160

    local trail = MakePanel(page, "Flag trail", 0, -124, 684, 160)
    self.flagTrailCheck = MakeCheckbox(trail, "Show flag trail", columnLeftX, -30,
        function() return self:GetFlagsTarget().showFlagCarrierTrail end,
        function(value)
            self:GetFlagsTarget().showFlagCarrierTrail = value
            RefreshFlagPreview(true)
        end)
    self.flagCarrierTrailCheck = self.flagTrailCheck
    AddControlTooltip(self.flagTrailCheck, "Flag trail",
        "Shows an objective-coloured trail behind carried battleground objectives. Rendering is throttled and resampled to reduce map-update cost.")

    self.flagTrailStyleSelector = MakeDropdown(
        trail,
        "Trail style",
        columnCenterX,
        -30,
        columnCenterWidth,
        {
            { value = "breadcrumbs", label = "Breadcrumbs" },
            { value = "glow", label = "Glow wake" },
            { value = "tether", label = "Spawn tether" },
        },
        function()
            local style = self:GetFlagsTarget().carriedTrailStyle
            if style == "glow" or style == "tether" then return style end
            return "breadcrumbs"
        end,
        function(value)
            if value ~= "glow" and value ~= "tether" then value = "breadcrumbs" end
            self:GetFlagsTarget().carriedTrailStyle = value
            RefreshFlagPreview(true)
        end,
        true
    )
    AddControlTooltip(self.flagTrailStyleSelector, "Trail style",
        "Breadcrumbs uses distinct objective-coloured markers. Glow wake uses a tapered objective-coloured line. Spawn tether draws a direct line from a carried objective to its fixed spawn location on supported maps, including Kotmogu, Warsong Gulch, Twin Peaks, and Eye of the Storm.")

    self.flagTrailSizeSlider = MakeSlider(trail, "Trail size", columnRightX, -30, 0.20, 3.00, 0.05,
        function() return tonumber(self:GetFlagsTarget().carriedTrailDotScale) or 1.25 end,
        function(value)
            self:GetFlagsTarget().carriedTrailDotScale = value
            RefreshFlagPreview()
        end,
        function(value) return string.format("%.2fx", value) end,
        columnRightWidth)
    AddControlTooltip(self.flagTrailSizeSlider, "Trail size",
        "Scales breadcrumb markers, Glow wake thickness, and Spawn tether thickness. The range extends to 3.00x for substantially stronger map visibility.")

    self.flagTrailDurationSlider = MakeSlider(trail, "Length", columnLeftX, -84, 1.00, 30.00, 0.25,
        function() return tonumber(self:GetFlagsTarget().carriedTrailDuration) or 20.00 end,
        function(value)
            self:GetFlagsTarget().carriedTrailDuration = value
            RefreshFlagPreview()
        end,
        function(value) return string.format("%.2fs", value) end,
        columnLeftWidth)
    AddControlTooltip(self.flagTrailDurationSlider, "Trail length",
        "Controls how many seconds of movement history remain visible. Long durations are resampled into the selected points-per-carrier detail budget rather than creating unbounded frames. Spawn tether does not use this setting.")

    self.flagTrailDetailSlider = MakeSlider(trail, "Points per carrier", columnCenterX, -84, 4, 24, 1,
        function() return tonumber(self:GetFlagsTarget().carriedTrailDetail) or 16 end,
        function(value)
            self:GetFlagsTarget().carriedTrailDetail = math.floor(value + 0.5)
            RefreshFlagPreview(true)
        end,
        function(value) return string.format("%d", math.floor(value + 0.5)) end,
        columnCenterWidth)
    AddControlTooltip(self.flagTrailDetailSlider, "Points per carrier",
        "Sets the visual budget for each active carried objective. Four Kotmogu carriers can use up to four times this value, with a hard total ceiling of 96 points. Spawn tether uses only two anchor points per carrier.")

    self.kotmoguEnemyFactionColorCheck = MakeCheckbox(trail, "Faction-color enemy orbs", columnRightX, -88,
        function() return self:GetFlagsTarget().factionColorEnemyKotmoguOrbs ~= false end,
        function(value)
            self:GetFlagsTarget().factionColorEnemyKotmoguOrbs = value
            RefreshFlagPreview()
        end)
    AddControlTooltip(self.kotmoguEnemyFactionColorCheck, "Faction-color enemy orbs",
        "In Temple of Kotmogu, friendly carried orbs retain their original orb colour. Enemy carried orbs are desaturated and tinted to the opposing faction colour. Stationary pads remain orb-coloured.")

    local flash = MakePanel(page, "Flag flash", 0, -290, 684, 84)
    self.flagFlashCheck = MakeCheckbox(flash, "Flash carried flags", columnLeftX, -30,
        function() return self:GetFlagsTarget().flashCarriedObjectives end,
        function(value)
            self:GetFlagsTarget().flashCarriedObjectives = value
            RefreshFlagPreview()
        end)
    self.carriedObjectiveFlashCheck = self.flagFlashCheck
    AddControlTooltip(self.flagFlashCheck, "Flag flash",
        "Adds a brightness flash to carried objective pins so flag carriers are easier to notice without fading the pin itself.")

    self.flagFlashStrengthSlider = MakeSlider(flash, "Strength", columnCenterX, -30, 0.10, 1.00, 0.05,
        function() return tonumber(self:GetFlagsTarget().carriedObjectiveFlashStrength) or 0.40 end,
        function(value)
            self:GetFlagsTarget().carriedObjectiveFlashStrength = value
            RefreshFlagPreview()
        end,
        function(value) return string.format("%.2f", value) end,
        columnCenterWidth)

    self.flagFlashPeriodSlider = MakeSlider(flash, "Period", columnRightX, -30, 0.30, 2.00, 0.05,
        function() return tonumber(self:GetFlagsTarget().carriedObjectiveFlashPeriod) or 0.55 end,
        function(value)
            self:GetFlagsTarget().carriedObjectiveFlashPeriod = value
            RefreshFlagPreview()
        end,
        function(value) return string.format("%.2fs", value) end,
        columnRightWidth)
end

if Options.RegisterPage then
    Options:RegisterPage("flags", "Flags", 600, "CreateFlagsPage", 40)
end
