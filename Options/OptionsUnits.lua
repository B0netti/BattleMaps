local _, BattleMaps = ...
local Options = BattleMaps and BattleMaps.Options
if not Options or not Options.Widgets then return end

local W = Options.Widgets
local MakeCheckbox = W.MakeCheckbox
local AddControlTooltip = W.AddControlTooltip
local MakeResetIconButton = W.MakeResetIconButton
local MakePanel = W.MakePanel
local MakePlayerColorControl = W.MakePlayerColorControl
local MakeSlider = W.MakeSlider
local MakeDropdown = W.MakeDropdown
local MakeColorSwatchControl = W.MakeColorSwatchControl

local function ApplyFovPresetPresentation()
    local db = BattleMaps.Database:Get()
    db.mapTextureAlpha = 0.80
    db.frameBackgroundColor = { r = 0, g = 0, b = 0, a = 1 }
    if BattleMaps.MapFrame then BattleMaps.MapFrame:ApplyVisualSettings() end
end

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
    local playerPanelHeight = 160
    local teamPanelY = -(42 + playerPanelHeight)
    local stackingPanelY = teamPanelY - 166
    local page = CreateFrame("Frame", nil, parent)
    self.pages.units = page
    page:SetAllPoints(parent)

    self.playerPinsGlobalCheck = MakeCheckbox(page, "Use Global Unit Settings", 4, -2,
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
    AddControlTooltip(self.playerPinsGlobalCheck, "Use Global Unit Settings",
        "When enabled, the selected battleground uses the shared player, teammate, healer, and stacking settings. Disable it to edit only this battleground.")

    local resetPlayerPins = MakeResetIconButton(page, "Reset Units", "Restores the player, teammate, healer, and stacking settings for this page to their defaults.", function()
        BattleMaps.Database:ResetUnits(self.selectedMapID)
        self:Refresh()
        if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
    end)
    resetPlayerPins:SetPoint("TOPRIGHT", page, "TOPRIGHT", -4, -2)

    -- Keep the player-marker controls first and the FoV preset controls
    -- directly beneath them in the same three-column arrangement.
    local player = MakePanel(page, "Player Arrow", 0, -34, 684, playerPanelHeight)
    self.playerColorControl = MakePlayerColorControl(player, 500, -30, 160)
    AddControlTooltip(self.playerColorControl, "Pin color",
        "Click the color swatch to open the picker for player arrows and team pins. Class follows the currently logged-in character.")

    self.playerArrowSizeSlider = MakeSlider(player, "Pin size", 210, -30, 12, 128, 1,
        function() return tonumber(self:GetUnitsTarget().playerArrowSize) or 22 end,
        function(value)
            self:GetUnitsTarget().playerArrowSize = value
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end,
        function(value) return string.format("%d px", value) end,
        250)
    self.playerTeamPinSizeNote = player:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    self.playerTeamPinSizeNote:SetPoint("TOPLEFT", player, "TOPLEFT", 210, -30)
    self.playerTeamPinSizeNote:SetPoint("TOPRIGHT", player, "TOPLEFT", 460, -30)
    self.playerTeamPinSizeNote:SetJustifyH("LEFT")
    self.playerTeamPinSizeNote:SetTextColor(0.96, 0.85, 0.64, 1)
    self.playerTeamPinSizeNote:Hide()

    self.playerPinStyleDropdown = MakeDropdown(player, "Pin style", 10, -30, 180,
        function()
            return {
                { value = "default", label = "Blizzard" },
                { value = "arrow", label = "Arrow" },
                { value = "compass", label = "Compass" },
                { value = "team", label = "Team" },
            }
        end,
        function() return self:GetUnitsTarget().playerPinStyle or "arrow" end,
        function(value)
            self:GetUnitsTarget().playerPinStyle = ({
                default = true,
                arrow = true,
                compass = true,
                team = true,
            })[value] and value or "arrow"
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end,
        true)
    AddControlTooltip(self.playerPinStyleDropdown, "Pin style",
        "Selects the player marker artwork: Blizzard's default arrow, the BattleMaps arrow or compass, or the layered team-pin treatment.")

    self.playerFovStyleDropdown = MakeDropdown(player, "FoV", 10, -84, 180,
        function()
            return {
                { value = "none", label = "None" },
                { value = "simple", label = "Simple" },
                { value = "coldRays", label = "Cold Rays" },
                { value = "sunbeam", label = "Sunbeam" },
            }
        end,
        function() return self:GetUnitsTarget().playerFovStyle or "none" end,
        function(value)
            self:GetUnitsTarget().playerFovStyle = ({
                none = true,
                simple = true,
                coldRays = true,
                sunbeam = true,
            })[value] and value or "none"
            if value == "simple" then
                self:GetUnitsTarget().playerFovAlpha = 1.00
            elseif value == "coldRays" then
                self:GetUnitsTarget().playerFovAlpha = 1.00
                self:GetUnitsTarget().playerFovBeamAlpha = 0.25
            elseif value == "sunbeam" then
                self:GetUnitsTarget().playerFovBeamAlpha = 0.25
            end
            if value ~= "none" then ApplyFovPresetPresentation() end
            self:Refresh()
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end,
        true)
    self.playerFovStyleDropdown.button:SetWidth(96)
    self.playerFovStyleDropdown.menu:SetWidth(96)
    AddControlTooltip(self.playerFovStyleDropdown, "FoV",
        "Selects a field-of-view preset. Each preset uses one to three authored texture layers. Selecting a preset sets map texture opacity to 80% with an opaque black background. All FoV artwork retains its authored colors and does not receive mouse input.")

    self.playerFovScaleSlider = MakeSlider(player, "FoV scale", 210, -84, 0.25, 5.00, 0.05,
        function() return tonumber(self:GetUnitsTarget().playerFovScale) or 1.00 end,
        function(value)
            self:GetUnitsTarget().playerFovScale = value
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end,
        function(value) return string.format("%.2fx", value) end,
        250)
    AddControlTooltip(self.playerFovScaleSlider, "FoV scale",
        "Scales the FoV independently of the player-pin size. Larger values are useful for checking the boundary feather.")

    self.playerFovAlphaSlider = MakeSlider(player, "FoV alpha", 500, -84, 0.10, 1.00, 0.05,
        function() return tonumber(self:GetUnitsTarget().playerFovAlpha) or 0.65 end,
        function(value)
            self:GetUnitsTarget().playerFovAlpha = value
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end,
        function(value) return string.format("%d%%", math.floor((value * 100) + 0.5)) end,
        160)
    AddControlTooltip(self.playerFovAlphaSlider, "FoV alpha",
        "Changes only the FoV transparency. The artwork always retains its authored color.")

    local team = MakePanel(page, "Team Units", 0, teamPanelY, 684, 160)
    self.combatTeamCheck = MakeCheckbox(team, "Solid out of combat", 10, -30,
        function() return db.useSolidTeamPinOutOfCombat ~= false end,
        function(value)
            db.useSolidTeamPinOutOfCombat = value
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end)
    AddControlTooltip(self.combatTeamCheck, "Solid out of combat",
        "Uses the dot-free team fill while a teammate is out of combat. Entering combat switches ordinary teammates to the centre-dot fill. Healers keep their dedicated healer fill in both states.")

    self.teamMemberSizeSlider = MakeSlider(team, "Team Members", 210, -30, 3, 32, 1,
        function() return tonumber(self:GetUnitsTarget().teamMemberPinSize) or 12 end,
        function(value)
            self:GetUnitsTarget().teamMemberPinSize = value
            if self:GetUnitsTarget().playerPinStyle == "team" and self.playerTeamPinSizeNote then
                self.playerTeamPinSizeNote:SetText(string.format(
                    "Team Pin Size\nUses Team Members Size: %d px",
                    value
                ))
            end
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end,
        function(value) return string.format("%d px", value) end,
        250)
    self.healerSizeSlider = MakeSlider(team, "Healer icon size", 500, -30, 0.5, 40, 0.5,
        function() return tonumber(self:GetUnitsTarget().healerPinSize) or 16 end,
        function(value)
            self:GetUnitsTarget().healerPinSize = value
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end,
        function(value) return string.format("%d%%", math.floor(((value / 16) * 100) + 0.5)) end,
        160)
    AddControlTooltip(self.healerSizeSlider, "Healer icon size",
        "Scales the healer icon relative to its standard size. 100% is the default size.")

    self.healerPinStyleDropdown = MakeDropdown(team, "Healer icon style", 10, -84, 180,
        function()
            return {
                { value = "circle", label = "Icon inside circle" },
                { value = "icon", label = "Icon only" },
                { value = "ignore", label = "Ignore" },
            }
        end,
        function() return self:GetUnitsTarget().healerPinStyle or "icon" end,
        function(value)
            self:GetUnitsTarget().healerPinStyle = ({
                circle = true,
                icon = true,
                ignore = true,
            })[value] and value or "icon"
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end,
        false)
    AddControlTooltip(self.healerPinStyleDropdown, "Healer icon style",
        "Icon inside circle keeps the normal team pin beneath the healer glyph. Icon only shows only the healer glyph. Ignore renders healers as ordinary teammates.")

    self.healerIconCustomColorControl = MakeColorSwatchControl(
        team,
        "Healer icon color",
        500,
        -84,
        function()
            local target = self:GetUnitsTarget()
            if (target.healerIconColorMode or "class") == "class" then
                -- Class is resolved separately for every healer, so there is
                -- no single class colour for this shared option swatch.
                return { r = 1, g = 1, b = 1 }
            end
            return type(target.healerIconCustomColor) == "table"
                and target.healerIconCustomColor
                or { r = 1, g = 1, b = 1 }
        end,
        function() self:OpenHealerIconColorPicker() end,
        160
    )
    AddControlTooltip(self.healerIconCustomColorControl, "Healer icon color",
        "Click the color swatch to choose the healer cross/icon color. Class colours each healer icon using that healer's own class; the shared swatch stays neutral because a group can contain multiple healer classes.")

    local stacking = MakePanel(page, "Team Pin Stacking", 0, stackingPanelY, 684, 118)
    self.teamStackInfoButton = MakeInformationButton(
        stacking,
        142,
        -5,
        "Approximate live-PvP stacking",
        "Blizzard restricts exact teammate coordinates during active battlegrounds. BattleMaps therefore uses small, bounded offsets based on stable roster slots rather than exact proximity calculations. This keeps pins close to Blizzard's native positions, but isolated pins can move slightly and the result is approximate. The feature remains experimental. Test mode demonstrates this same bounded-offset behaviour."
    )

    self.teamPinStackCheck = MakeCheckbox(stacking, "Enable", 10, -30,
        function() return self:GetUnitsTarget().stackTeamPins ~= false end,
        function(value)
            self:GetUnitsTarget().stackTeamPins = value
            self:Refresh()
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end)
    AddControlTooltip(self.teamPinStackCheck, "Enable team pin stacking",
        "Applies small, bounded offsets to friendly team pins. In live PvP this is an approximate separation system because Blizzard does not expose exact teammate coordinates to addon Lua.")

    self.excludePlayerArrowFromStackCheck = MakeCheckbox(stacking, "Exclude player pin", 10, -78,
        function() return self:GetUnitsTarget().excludePlayerArrowFromStack == true end,
        function(value)
            self:GetUnitsTarget().excludePlayerArrowFromStack = value
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end)
    AddControlTooltip(self.excludePlayerArrowFromStackCheck, "Exclude player pin from stack",
        "Keeps the player pin out of the separation pattern. The pin remains fixed and renders behind team pins so overlaps stay readable.")

    self.teamPinStackOverlapSlider = MakeSlider(stacking, "Pin overlap", 210, -30, 0, 80, 5,
        function() return tonumber(self:GetUnitsTarget().teamPinStackOverlap) or 45 end,
        function(value)
            self:GetUnitsTarget().teamPinStackOverlap = value
            if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        end,
        function(value) return string.format("%d%%", value) end,
        250)
    AddControlTooltip(self.teamPinStackOverlapSlider, "Pin overlap",
        "Controls how much the bounded separation offsets overlap. Higher values keep pins closer together; lower values spread them farther apart within the safety cap.")

    self.teamPinStackDirectionDropdown = MakeDropdown(stacking, "Direction", 500, -30, 160,
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
        end,
        true)
    AddControlTooltip(self.teamPinStackDirectionDropdown, "Direction",
        "Controls the visual offset pattern used for the approximate separation.")
end

if Options.RegisterPage then
    Options:RegisterPage("units", "Units", 700, "CreateUnitsPage", 20)
end
