local _, BattleMaps = ...
local Options = BattleMaps and BattleMaps.Options
if not Options or not Options.Widgets then return end

local W = Options.Widgets
local MakeCheckbox = W.MakeCheckbox
local AddControlTooltip = W.AddControlTooltip
local MakeResetIconButton = W.MakeResetIconButton
local MakePanel = W.MakePanel
local MakePlayerColorSelector = W.MakePlayerColorSelector
local MakeSlider = W.MakeSlider
local MakeDropdown = W.MakeDropdown
local MakeColorSwatchControl = W.MakeColorSwatchControl

local function MakeInformationButton(parent, x, y, title, description)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(20, 20)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local ring = button:CreateTexture(nil, "BACKGROUND")
    ring:SetAllPoints()
    ring:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    ring:SetVertexColor(0.88, 0.58, 0.22, 0.95)

    local text = button:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    text:SetPoint("CENTER", button, "CENTER", 0, 0)
    text:SetText("i")
    text:SetTextColor(1.00, 0.84, 0.45, 1)
    button.iconText = text

    AddControlTooltip(button, title, description)
    return button
end

function Options:CreateUnitsPage(parent)
    local db = BattleMaps.Database:Get()
    local page = CreateFrame("Frame", nil, parent)
    self.pages.units = page
    page:SetAllPoints(parent)

    self.playerPinsGlobalCheck = MakeCheckbox(page, "Use global unit settings", 4, -2,
        function()
            return not BattleMaps.Database.MapUsesGlobalPlayerPinSettings
                or BattleMaps.Database:MapUsesGlobalPlayerPinSettings(self.selectedMapID)
        end,
        function(value)
            if BattleMaps.Database.SetMapUsesGlobalPlayerPinSettings then
                BattleMaps.Database:SetMapUsesGlobalPlayerPinSettings(self.selectedMapID, value)
            end
            self:Refresh()
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end)
    AddControlTooltip(self.playerPinsGlobalCheck, "Use global unit settings",
        "When enabled, the selected battleground uses the shared player, teammate, healer, and stacking settings. Disable it to edit only this battleground.")

    local resetPlayerPins = MakeResetIconButton(page, "Reset units", "Restores the player, teammate, healer, and stacking settings for this page to their defaults.", function()
        BattleMaps.Database:ResetUnits(self.selectedMapID)
        self:Refresh()
        if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
    end)
    resetPlayerPins:SetPoint("TOPRIGHT", page, "TOPRIGHT", -4, -2)

    local player = MakePanel(page, "Player", 0, -34, 684, 102)
    self.customPlayerArrowCheck = MakeCheckbox(player, "Custom player arrow", 10, -30,
        function() return db.useCustomPlayerArrow end,
        function(value)
            db.useCustomPlayerArrow = value
            self:Refresh()
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end)
    self.playerColorSelector = MakePlayerColorSelector(player, 12, -48)
    self.playerArrowSizeSlider = MakeSlider(player, "Player arrow", 342, -42, 12, 128, 1,
        function() return tonumber(self:GetUnitsTarget().playerArrowSize) or 22 end,
        function(value)
            self:GetUnitsTarget().playerArrowSize = value
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end,
        function(value) return string.format("%d px", value) end,
        304)

    local team = MakePanel(page, "Team units", 0, -142, 684, 168)
    self.combatTeamCheck = MakeCheckbox(team, "Solid texture while out of combat", 10, -30,
        function() return db.useSolidTeamPinOutOfCombat ~= false end,
        function(value)
            db.useSolidTeamPinOutOfCombat = value
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end)
    AddControlTooltip(self.combatTeamCheck, "Solid texture while out of combat",
        "Uses the dot-free team fill while a teammate is out of combat. Entering combat switches ordinary teammates to the centre-dot fill. Healers keep their dedicated healer fill in both states.")

    self.teamMemberSizeSlider = MakeSlider(team, "Team members", 12, -58, 3, 32, 1,
        function() return tonumber(self:GetUnitsTarget().teamMemberPinSize) or 12 end,
        function(value)
            self:GetUnitsTarget().teamMemberPinSize = value
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end,
        function(value) return string.format("%d px", value) end,
        202)
    self.healerSizeSlider = MakeSlider(team, "Friendly healers", 241, -58, 0.5, 40, 0.5,
        function() return tonumber(self:GetUnitsTarget().healerPinSize) or 16 end,
        function(value)
            self:GetUnitsTarget().healerPinSize = value
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end,
        function(value)
            if math.abs(value - math.floor(value + 0.5)) < 0.001 then
                return string.format("%d", math.floor(value + 0.5))
            end
            return string.format("%.1f", value)
        end,
        202)
    self.combatScaleSlider = MakeSlider(team, "In-combat scale", 470, -58, 0.50, 3.00, 0.05,
        function() return tonumber(self:GetUnitsTarget().combatTeamPinScale) or 1.25 end,
        function(value)
            self:GetUnitsTarget().combatTeamPinScale = value
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end,
        function(value) return string.format("%.2fx", value) end,
        202)

    self.healerIconCustomColorControl = MakeColorSwatchControl(
        team,
        "Healer icon colour",
        12,
        -108,
        function()
            local target = self:GetUnitsTarget()
            return type(target.healerIconCustomColor) == "table"
                and target.healerIconCustomColor
                or { r = 1, g = 1, b = 1 }
        end,
        function() self:OpenHealerIconColorPicker() end,
        304,
        128,
        "Choose colour"
    )
    AddControlTooltip(self.healerIconCustomColorControl, "Healer icon colour",
        "Sets one custom colour for the healer cross/icon texture. The circular team-pin fill remains class coloured.")

    local stacking = MakePanel(page, "Team pin stacking", 0, -316, 684, 154)
    self.teamStackInfoButton = MakeInformationButton(
        stacking,
        142,
        -5,
        "Approximate live-PvP stacking",
        "Blizzard restricts exact teammate coordinates during active battlegrounds. BattleMaps therefore uses small, bounded offsets based on stable roster slots rather than exact proximity calculations. This keeps pins close to Blizzard's native positions, but isolated pins can move slightly and the result is approximate. The feature remains experimental. Test mode demonstrates this same bounded-offset behaviour."
    )

    self.teamPinStackCheck = MakeCheckbox(stacking, "Separate overlapping team pins", 10, -32,
        function() return self:GetUnitsTarget().stackTeamPins ~= false end,
        function(value)
            self:GetUnitsTarget().stackTeamPins = value
            self:Refresh()
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end)
    AddControlTooltip(self.teamPinStackCheck, "Separate overlapping team pins",
        "Applies small, bounded offsets to friendly team pins. In live PvP this is an approximate separation system because Blizzard does not expose exact teammate coordinates to addon Lua.")

    self.excludePlayerArrowFromStackCheck = MakeCheckbox(stacking, "Exclude player arrow", 10, -66,
        function() return self:GetUnitsTarget().excludePlayerArrowFromStack == true end,
        function(value)
            self:GetUnitsTarget().excludePlayerArrowFromStack = value
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end)
    AddControlTooltip(self.excludePlayerArrowFromStackCheck, "Exclude player arrow from stack",
        "Keeps the player arrow out of the separation pattern. The arrow remains fixed and renders behind team pins so overlaps stay readable.")

    self.teamPinStackOverlapSlider = MakeSlider(stacking, "Pin overlap", 342, -62, 0, 80, 5,
        function() return tonumber(self:GetUnitsTarget().teamPinStackOverlap) or 45 end,
        function(value)
            self:GetUnitsTarget().teamPinStackOverlap = value
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end,
        function(value) return string.format("%d%%", value) end,
        304)
    AddControlTooltip(self.teamPinStackOverlapSlider, "Pin overlap",
        "Controls how much the bounded separation offsets overlap. Higher values keep pins closer together; lower values spread them farther apart within the safety cap.")

    self.teamPinStackDirectionDropdown = MakeDropdown(stacking, "Direction", 12, -108, 220,
        function()
            return {
                { value = "compact", label = "Compact" },
                { value = "diagonal", label = "Diagonal" },
                { value = "horizontal", label = "Horizontal" },
                { value = "vertical", label = "Vertical" },
            }
        end,
        function() return self:GetUnitsTarget().teamPinStackDirection or "compact" end,
        function(value)
            self:GetUnitsTarget().teamPinStackDirection = value
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end)
    AddControlTooltip(self.teamPinStackDirectionDropdown, "Direction",
        "Controls the visual offset pattern used for the approximate separation.")
end

if Options.RegisterPage then
    Options:RegisterPage("units", "Units", 700, "CreateUnitsPage", 20)
end
