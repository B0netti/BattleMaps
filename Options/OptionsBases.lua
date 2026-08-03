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
local MakeChoiceSelector = W.MakeChoiceSelector
local MakeRangeSlider = W.MakeRangeSlider
local MakeCompactNumberInput = W.MakeCompactNumberInput
local MakeColorSwatchControl = W.MakeColorSwatchControl

function Options:CreateBasesPage(parent)
    local db = BattleMaps.Database:Get()
    local page = CreateFrame("Frame", nil, parent)
    self.pages.bases = page
    page:SetAllPoints(parent)

    local function ObjectiveSettings()
        return self:GetBasesObjectiveTarget()
    end

    local function TimerSettings()
        return self:GetBasesTimerTarget()
    end

    self.basesGlobalCheck = MakeCheckbox(page, "Use global base pin settings", 4, -2,
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
            if BattleMaps.Pins then BattleMaps.Pins:RefreshAll(true) end
        end)
    AddControlTooltip(self.basesGlobalCheck, "Use global base pin settings",
        "When enabled, the selected battleground uses the shared base/cart/flag pin settings. Disable it to edit only the selected battleground.")

    self.timersGlobalCheck = MakeCheckbox(page, "Use global timer settings", 254, -2,
        function() return db.useGlobalTimerSettings ~= false end,
        function(value)
            db.useGlobalTimerSettings = value
            self:Refresh()
            if BattleMaps.Pins then BattleMaps.Pins:RefreshPOIs() end
        end)
    AddControlTooltip(self.timersGlobalCheck, "Use global timer settings",
        "When enabled, base capture fill, pulse, flash, and countdown text use the shared defaults for every battleground. Disable it to edit the selected battleground only.")

    local resetBases = MakeResetIconButton(page, "Reset bases", "Restores stationary base size, base opacity, capture fill, flash, pulse, and countdown-text settings for this page to their defaults.", function()
        BattleMaps.Database:ResetBasePins(self.selectedMapID)
        BattleMaps.Database:ResetBaseTimers(self.selectedMapID)
        self:Refresh()
        if BattleMaps.Pins then BattleMaps.Pins:RefreshAll(true) end
    end)
    resetBases:SetPoint("TOPRIGHT", page, "TOPRIGHT", -4, -2)

    local function RefreshTimerText()
        if BattleMaps.Pins and BattleMaps.Pins.RefreshObjectiveTimerTextSettings then
            BattleMaps.Pins:RefreshObjectiveTimerTextSettings()
        end
    end

    local basePins = MakePanel(page, "Base pins", 0, -34, 684, 82)
    self.stationaryObjectiveSlider = MakeSlider(basePins, "Stationary bases", 12, -28, 0.50, 2.50, 0.05,
        function() return tonumber(ObjectiveSettings().objectivePinScale) or 1.90 end,
        function(value)
            ObjectiveSettings().objectivePinScale = value
            if BattleMaps.Pins then BattleMaps.Pins:RefreshAll(true) end
        end,
        function(value) return string.format("%.2fx", value) end,
        304)
    AddControlTooltip(self.stationaryObjectiveSlider, "Stationary bases",
        "Scales fixed objectives such as AB bases, EotS towers, Gilneas nodes, Deepwind bases, and Seething Shore azerite nodes.")

    self.stationaryObjectiveAlphaSlider = MakeSlider(basePins, "Base opacity", 354, -28, 0.15, 1.00, 0.05,
        function() return tonumber(ObjectiveSettings().objectivePinAlpha) or 1.00 end,
        function(value)
            ObjectiveSettings().objectivePinAlpha = value
            if BattleMaps.Pins then
                if BattleMaps.Pins.RefreshStationaryObjectiveAlpha then
                    BattleMaps.Pins:RefreshStationaryObjectiveAlpha(self.selectedMapID)
                end
                BattleMaps.Pins:RefreshAll(true)
            end
        end,
        function(value) return string.format("%d%%", math.floor((value * 100) + 0.5)) end,
        304)
    AddControlTooltip(self.stationaryObjectiveAlphaSlider, "Base opacity",
        "Controls the opacity of stationary base/objective pins. Moving carts are configured on the Carts page.")

    -- Capture progress is a three-column grid:
    -- left = feature toggles, centre = primary timing/alpha controls,
    -- right = compact secondary controls. Keep the centre column wider because
    -- alpha/threshold sliders need more travel than dropdowns and count sliders.
    local capture = MakePanel(page, "Capture progress", 0, -126, 684, 216)

    local captureLeftX = 10
    local captureCenterX = 210
    local captureRightX = 500
    local captureCenterWidth = 250
    local captureRightWidth = 160

    self.objectiveCaptureTimerCheck = MakeCheckbox(capture, "Show fill", captureLeftX, -34,
        function() return TimerSettings().showObjectiveCaptureTimers ~= false end,
        function(value)
            TimerSettings().showObjectiveCaptureTimers = value
            if value == false and BattleMaps.Pins then
                BattleMaps.Pins:StopAllObjectiveCaptureTimers()
            elseif BattleMaps.Pins then
                BattleMaps.Pins:RefreshPOIs()
            end
        end)

    self.objectiveCaptureFillDirection = MakeDropdown(capture, "Fill direction", captureRightX, -28, 150,
        function()
            return {
                { value = "horizontal", label = "Horizontal" },
                { value = "vertical", label = "Vertical" },
            }
        end,
        function() return TimerSettings().objectiveCaptureFillDirection or "horizontal" end,
        function(value)
            TimerSettings().objectiveCaptureFillDirection = value == "vertical" and "vertical" or "horizontal"
            if BattleMaps.Pins then BattleMaps.Pins:RefreshPOIs() end
        end)

    self.captureTimerPulseCheck = MakeCheckbox(capture, "Pulse during capture", captureLeftX, -78,
        function() return TimerSettings().pulseObjectiveDuringCaptureTimer ~= false end,
        function(value)
            TimerSettings().pulseObjectiveDuringCaptureTimer = value
            if BattleMaps.Pins and BattleMaps.Pins.RefreshObjectiveCapturePulseSettings then
                BattleMaps.Pins:RefreshObjectiveCapturePulseSettings()
            elseif BattleMaps.Pins then
                BattleMaps.Pins:RefreshPOIs()
            end
        end)

    self.capturePulseAlphaSlider = MakeRangeSlider(capture, "Pulse alpha", captureCenterX, -72, 0.00, 1.00, 0.05,
        function()
            return tonumber(TimerSettings().objectiveCapturePulseMinAlpha) or 0.40,
                tonumber(TimerSettings().objectiveCapturePulseMaxAlpha) or 0.55
        end,
        function(lower, upper)
            TimerSettings().objectiveCapturePulseMinAlpha = lower
            TimerSettings().objectiveCapturePulseMaxAlpha = upper
            if BattleMaps.Pins and BattleMaps.Pins.RefreshObjectiveCapturePulseSettings then
                BattleMaps.Pins:RefreshObjectiveCapturePulseSettings()
            elseif BattleMaps.Pins then
                BattleMaps.Pins:RefreshPOIs()
            end
        end,
        function(lower, upper)
            return string.format("%d%% – %d%%",
                math.floor((lower * 100) + 0.5),
                math.floor((upper * 100) + 0.5))
        end,
        captureCenterWidth)

    self.objectivePreCaptureFlashCheck = MakeCheckbox(capture, "Flash before capture", captureLeftX, -122,
        function() return TimerSettings().flashObjectiveBeforeCapture == true end,
        function(value)
            TimerSettings().flashObjectiveBeforeCapture = value
            if BattleMaps.Pins and BattleMaps.Pins.RefreshObjectiveCapturePulseSettings then
                BattleMaps.Pins:RefreshObjectiveCapturePulseSettings()
            elseif BattleMaps.Pins then
                BattleMaps.Pins:RefreshPOIs()
            end
            self:Refresh()
        end)

    self.objectivePreCaptureFlashThresholdSlider = MakeSlider(capture, "Flash threshold", captureCenterX, -116, 1, 59, 1,
        function() return tonumber(TimerSettings().objectiveCaptureFlashThreshold) or 9 end,
        function(value)
            TimerSettings().objectiveCaptureFlashThreshold = value
            if BattleMaps.Pins and BattleMaps.Pins.RefreshObjectiveCapturePulseSettings then
                BattleMaps.Pins:RefreshObjectiveCapturePulseSettings()
            elseif BattleMaps.Pins then
                BattleMaps.Pins:RefreshPOIs()
            end
        end,
        function(value) return string.format("%d sec", value) end,
        captureCenterWidth)

    self.objectivePreCaptureFlashBrightnessSlider = MakeSlider(capture, "Flash brightness", captureRightX, -116, 0.10, 1.00, 0.05,
        function() return tonumber(TimerSettings().objectiveCaptureFlashBrightness) or 0.25 end,
        function(value)
            TimerSettings().objectiveCaptureFlashBrightness = value
            if BattleMaps.Pins and BattleMaps.Pins.RefreshObjectiveCapturePulseSettings then
                BattleMaps.Pins:RefreshObjectiveCapturePulseSettings()
            elseif BattleMaps.Pins then
                BattleMaps.Pins:RefreshPOIs()
            end
        end,
        function(value) return string.format("%d%%", math.floor((value * 100) + 0.5)) end,
        captureRightWidth)

    self.objectivePulseCheck = MakeCheckbox(capture, "Pulse after capture", captureLeftX, -166,
        function() return TimerSettings().showObjectivePulseAnimations ~= false end,
        function(value)
            TimerSettings().showObjectivePulseAnimations = value
            if value == false and BattleMaps.Pins then
                BattleMaps.Pins:StopAllObjectiveTexturePulses()
            end
        end)

    self.objectiveCaptureAfterPulseAlphaSlider = MakeSlider(capture, "Pulse alpha", captureCenterX, -160, 0.05, 1.00, 0.05,
        function() return tonumber(TimerSettings().objectiveCaptureAfterPulseAlpha) or 0.36 end,
        function(value) TimerSettings().objectiveCaptureAfterPulseAlpha = value end,
        function(value) return string.format("%d%%", math.floor((value * 100) + 0.5)) end,
        captureCenterWidth)

    self.objectiveCapturePulseCountInput = MakeSlider(capture, "Number of pulses", captureRightX, -160, 1, 9, 1,
        function() return tonumber(TimerSettings().objectiveCapturePulseCount) or 3 end,
        function(value) TimerSettings().objectiveCapturePulseCount = value end,
        function(value) return tostring(math.floor((value or 3) + 0.5)) end,
        captureRightWidth)

    -- Countdown text mirrors the capture-progress three-column grid:
    -- left = enable/position controls, centre = primary text timing/size/font,
    -- right = colour/alpha controls. Keep the centre column wider so the font
    -- dropdown and threshold slider have enough room.
    local timerText = MakePanel(page, "Countdown text", 0, -358, 684, 184)
    local textLeftX = captureLeftX
    local textCenterX = captureCenterX
    local textRightX = captureRightX
    local textCenterWidth = captureCenterWidth
    local textSideWidth = captureRightWidth

    self.objectiveTimerTextCheck = MakeCheckbox(timerText, "Cap countdown text", textLeftX, -34,
        function() return TimerSettings().showObjectiveTimerText ~= false end,
        function(value)
            TimerSettings().showObjectiveTimerText = value
            RefreshTimerText()
        end)

    self.objectiveBlitzUncapTextCheck = MakeCheckbox(timerText, "Blitz uncap text", textRightX, -34,
        function() return TimerSettings().showObjectiveBlitzUncapText == true end,
        function(value)
            TimerSettings().showObjectiveBlitzUncapText = value
            RefreshTimerText()
        end)

    self.objectiveTimerTextThresholdSlider = MakeSlider(timerText, "Display threshold", textCenterX, -28, 1, 59, 1,
        function() return tonumber(TimerSettings().objectiveTimerTextThreshold) or 59 end,
        function(value)
            TimerSettings().objectiveTimerTextThreshold = value
            RefreshTimerText()
        end,
        function(value) return string.format("%d sec", value) end,
        textCenterWidth)

    self.objectiveTimerTextOffsetXSlider = MakeSlider(timerText, "X offset", textLeftX, -78, -32, 32, 1,
        function() return tonumber(TimerSettings().objectiveTimerTextOffsetX) or 1 end,
        function(value)
            TimerSettings().objectiveTimerTextOffsetX = value
            RefreshTimerText()
        end,
        function(value) return string.format("%+d px", value) end,
        textSideWidth)

    self.objectiveTimerTextSizeSlider = MakeSlider(timerText, "Text size", textCenterX, -78, 8, 32, 1,
        function() return tonumber(TimerSettings().objectiveTimerTextSize) or 13 end,
        function(value)
            TimerSettings().objectiveTimerTextSize = value
            RefreshTimerText()
        end,
        function(value) return string.format("%d px", value) end,
        textCenterWidth)

    self.objectiveTimerTextColorControl = MakeColorSwatchControl(
        timerText,
        "Text colour",
        textRightX,
        -78,
        function() return TimerSettings().objectiveTimerTextColor or { r = 1, g = 0.8352941870689392, b = 0.3333333432674408 } end,
        function() self:OpenObjectiveTimerTextColorPicker() end,
        150,
        88,
        "Colour"
    )

    self.objectiveTimerTextOffsetYSlider = MakeSlider(timerText, "Y offset", textLeftX, -134, -32, 32, 1,
        function() return tonumber(TimerSettings().objectiveTimerTextOffsetY) or 0 end,
        function(value)
            TimerSettings().objectiveTimerTextOffsetY = value
            RefreshTimerText()
        end,
        function(value) return string.format("%+d px", value) end,
        textSideWidth)

    self.objectiveTimerTextFontDropdown = MakeDropdown(timerText, "Font", textCenterX, -128, textCenterWidth,
        function()
            if BattleMaps.GetObjectiveTimerFontChoices then
                return BattleMaps.GetObjectiveTimerFontChoices()
            end
            return BattleMaps.OBJECTIVE_TIMER_FONT_CHOICES or {
                { value = "friz", label = "Friz Quadrata" },
            }
        end,
        function() return TimerSettings().objectiveTimerTextFont or "Expressway" end,
        function(value)
            TimerSettings().objectiveTimerTextFont = value
            RefreshTimerText()
        end)

    self.objectiveTimerTextAlphaSlider = MakeSlider(timerText, "Text alpha", textRightX, -134, 0.00, 1.00, 0.05,
        function() return tonumber(TimerSettings().objectiveTimerTextAlpha) or 1.00 end,
        function(value)
            TimerSettings().objectiveTimerTextAlpha = value
            RefreshTimerText()
        end,
        function(value) return string.format("%d%%", math.floor((value * 100) + 0.5)) end,
        textSideWidth)

    AddControlTooltip(self.objectiveCaptureTimerCheck, "Show fill",
        "Shows capture progress on supported stationary bases using the neutral and attacking-faction textures.")
    AddControlTooltip(self.captureTimerPulseCheck, "Pulse during capture",
        "Pulses the active progress texture while a capture timer is running.")
    AddControlTooltip(self.objectiveCaptureFillDirection, "Fill direction",
        "Chooses whether capture progress reveals the faction texture horizontally or vertically.")
    AddControlTooltip(self.capturePulseAlphaSlider, "During-capture pulse alpha",
        "Sets the minimum and maximum alpha used while the active capture fill pulses during the timer. Drag either handle.")
    AddControlTooltip(self.objectivePulseCheck, "Pulse after capture",
        "Pulses the completed base texture when the ownership change is announced.")
    AddControlTooltip(self.objectiveCaptureAfterPulseAlphaSlider, "After-capture pulse alpha",
        "Sets the peak brightness of the completed-base pulse after the capture announcement.")
    AddControlTooltip(self.objectiveCapturePulseCountInput, "Number of pulses",
        "Sets how many pulse cycles play after capture. Range: 1 to 9.")
    AddControlTooltip(self.objectivePreCaptureFlashCheck, "Flash before capture",
        "Flashes the full attacking-faction base texture during the final seconds before the base changes ownership.")
    AddControlTooltip(self.objectivePreCaptureFlashThresholdSlider, "Flash threshold",
        "Starts the pre-capture flash when the remaining timer reaches this value.")
    AddControlTooltip(self.objectivePreCaptureFlashBrightnessSlider, "Flash brightness",
        "Controls the peak brightness of the pre-capture flash.")
    AddControlTooltip(self.objectiveTimerTextCheck, "Cap countdown text",
        "Shows the remaining capture time directly over the stationary base texture.")
    AddControlTooltip(self.objectiveBlitzUncapTextCheck, "Blitz uncap text",
        "Shows the Battleground Blitz controlled-base countdown after a base fully captures and before it unlocks/uncaps. Uses the same font, colour, alpha, threshold, and offset settings as the capture countdown.")
    AddControlTooltip(self.objectiveTimerTextThresholdSlider, "Display threshold",
        "The countdown appears only when the remaining time is at or below this value.")
    AddControlTooltip(self.objectiveTimerTextFontDropdown, "Font",
        "Uses fonts registered with LibSharedMedia when available, including Expressway.")
    AddControlTooltip(self.objectiveTimerTextAlphaSlider, "Text alpha",
        "Controls the opacity of the countdown text.")
    AddControlTooltip(self.objectiveTimerTextOffsetXSlider, "X offset",
        "Moves the countdown left or right relative to the base texture. The offset scales with the texture.")
    AddControlTooltip(self.objectiveTimerTextOffsetYSlider, "Y offset",
        "Moves the countdown up or down relative to the base texture. The offset scales with the texture.")
    AddControlTooltip(self.objectiveTimerTextSizeSlider, "Text size",
        "Sets the base countdown size. It scales with the rendered base texture and map zoom.")
    AddControlTooltip(self.objectiveTimerTextColorControl, "Text colour",
        "Chooses the countdown text colour.")
end

if Options.RegisterPage then
    Options:RegisterPage("bases", "Bases", 760, "CreateBasesPage", 30)
end
