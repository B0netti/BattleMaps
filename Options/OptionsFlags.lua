local _, BattleMaps = ...
local Options = BattleMaps and BattleMaps.Options
if not Options or not Options.Widgets then return end

local W = Options.Widgets
local MakeCheckbox = W.MakeCheckbox
local AddControlTooltip = W.AddControlTooltip
local MakeResetIconButton = W.MakeResetIconButton
local MakePanel = W.MakePanel
local MakeSlider = W.MakeSlider
local MakeChoiceSelector = W.MakeChoiceSelector

function Options:CreateFlagsPage(parent)
    local db = BattleMaps.Database:Get()
    local page = CreateFrame("Frame", nil, parent)
    self.pages.flags = page
    page:SetAllPoints(parent)

    self.flagsGlobalCheck = MakeCheckbox(page, "Use global flag & cart settings", 4, -2,
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
            if BattleMaps.Pins then
                BattleMaps.Pins:RefreshFlags()
                BattleMaps.Pins:RefreshVehicles()
            end
        end)
    AddControlTooltip(self.flagsGlobalCheck, "Use global flag & cart settings",
        "When enabled, the selected battleground uses the shared flag, cart, and base-objective settings. Disable it to edit only the selected battleground.")

    local resetFlags = MakeResetIconButton(page, "Reset flags",
        "Restores carried-objective size, flag trail, and flag flash settings for this page to their defaults.", function()
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
                target.carriedObjectiveColorMode = "original"
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

    self.carriedObjectiveColorModeDropdown = MakeChoiceSelector(
        flags,
        "Color",
        350,
        -30,
        {
            { value = "original", label = "Original" },
            { value = "faction", label = "Carrier faction" },
        },
        function()
            return self:GetFlagsTarget().carriedObjectiveColorMode == "faction" and "faction" or "original"
        end,
        function(value)
            self:GetFlagsTarget().carriedObjectiveColorMode = value == "faction" and "faction" or "original"
            RefreshFlagPreview(true)
        end,
        126
    )
    AddControlTooltip(self.carriedObjectiveColorModeDropdown, "Carried-objective color",
        "Original preserves each flag object's faction and each Kotmogu orb's color. Carrier faction colors carried flags and orbs for the carrier's team. Spawn tether uses the same displayed color.")

    -- The previous standalone Carts page now lives here as its own subsection.
    if self.AddCartsSection then self:AddCartsSection(page, -124) end

    local trail = MakePanel(page, "Flag trail", 0, -212, 684, 168)
    self.flagTrailCheck = MakeCheckbox(trail, "Show flag trail", 12, -28,
        function() return self:GetFlagsTarget().showFlagCarrierTrail end,
        function(value)
            self:GetFlagsTarget().showFlagCarrierTrail = value
            RefreshFlagPreview(true)
        end)
    self.flagCarrierTrailCheck = self.flagTrailCheck
    AddControlTooltip(self.flagTrailCheck, "Flag trail",
        "Shows an objective-coloured trail behind carried battleground objectives. Rendering is throttled and resampled to reduce map-update cost.")

    self.flagTrailDurationSlider = MakeSlider(trail, "Length", 190, -22, 1.00, 30.00, 0.25,
        function() return tonumber(self:GetFlagsTarget().carriedTrailDuration) or 20.00 end,
        function(value)
            self:GetFlagsTarget().carriedTrailDuration = value
            RefreshFlagPreview()
        end,
        function(value) return string.format("%.2fs", value) end,
        214)
    AddControlTooltip(self.flagTrailDurationSlider, "Trail length",
        "Controls how long the recorded path remains visible. The renderer keeps a fixed visual budget, so longer trails do not create an unbounded number of frames. Spawn tether does not use this setting.")

    self.flagTrailSizeSlider = MakeSlider(trail, "Trail size", 432, -22, 0.20, 3.00, 0.05,
        function() return tonumber(self:GetFlagsTarget().carriedTrailDotScale) or 1.25 end,
        function(value)
            self:GetFlagsTarget().carriedTrailDotScale = value
            RefreshFlagPreview()
        end,
        function(value) return string.format("%.2fx", value) end,
        214)
    AddControlTooltip(self.flagTrailSizeSlider, "Trail size",
        "Scales breadcrumb markers, Glow wake thickness, and Spawn tether thickness. The range extends to 3.00x for a substantially stronger trail.")

    self.flagTrailStyleSelector = MakeChoiceSelector(
        trail,
        "Style",
        12,
        -72,
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
        96
    )
    AddControlTooltip(self.flagTrailStyleSelector, "Trail style",
        "Breadcrumbs uses distinct objective-colored markers. Glow wake uses a tapered objective-colored line. Spawn tether draws a direct line from a carried objective to its fixed spawn location on supported maps, including Kotmogu, Warsong Gulch, Twin Peaks, and Eye of the Storm.")

    self.flagTrailDetailSlider = MakeSlider(trail, "Points per carrier", 350, -72, 4, 24, 1,
        function() return tonumber(self:GetFlagsTarget().carriedTrailDetail) or 16 end,
        function(value)
            self:GetFlagsTarget().carriedTrailDetail = math.floor(value + 0.5)
            RefreshFlagPreview(true)
        end,
        function(value) return string.format("%d", math.floor(value + 0.5)) end,
        296)
    AddControlTooltip(self.flagTrailDetailSlider, "Points per carrier",
        "Sets the visual budget for each active carried objective. Four Kotmogu carriers can use up to four times this value, with a hard total ceiling of 96 points. Spawn tether uses only its bounded anchors and chevrons.")

    local flash = MakePanel(page, "Flag flash", 0, -386, 684, 100)
    self.flagFlashCheck = MakeCheckbox(flash, "Flash carried flags", 12, -28,
        function() return self:GetFlagsTarget().flashCarriedObjectives end,
        function(value)
            self:GetFlagsTarget().flashCarriedObjectives = value
            RefreshFlagPreview()
        end)
    self.carriedObjectiveFlashCheck = self.flagFlashCheck
    AddControlTooltip(self.flagFlashCheck, "Flag flash",
        "Adds a brightness flash to carried objective pins so flag carriers are easier to notice without fading the pin itself.")

    self.flagFlashStrengthSlider = MakeSlider(flash, "Strength", 190, -22, 0.10, 1.00, 0.05,
        function() return tonumber(self:GetFlagsTarget().carriedObjectiveFlashStrength) or 0.40 end,
        function(value)
            self:GetFlagsTarget().carriedObjectiveFlashStrength = value
            RefreshFlagPreview()
        end,
        function(value) return string.format("%.2f", value) end,
        214)

    self.flagFlashPeriodSlider = MakeSlider(flash, "Period", 432, -22, 0.30, 2.00, 0.05,
        function() return tonumber(self:GetFlagsTarget().carriedObjectiveFlashPeriod) or 0.55 end,
        function(value)
            self:GetFlagsTarget().carriedObjectiveFlashPeriod = value
            RefreshFlagPreview()
        end,
        function(value) return string.format("%.2fs", value) end,
        214)
end

if Options.RegisterPage then
    Options:RegisterPage("flags", "Flags & Carts", 600, "CreateFlagsPage", 35)
end
