local _, BattleMaps = ...
local Options = BattleMaps and BattleMaps.Options
if not Options or not Options.Widgets then return end

local W = Options.Widgets
local MakePanel = W.MakePanel
local MakeCheckbox = W.MakeCheckbox
local AddControlTooltip = W.AddControlTooltip
local MakeDropdown = W.MakeDropdown
local MakeSlider = W.MakeSlider
local MakeColorSwatchControl = W.MakeColorSwatchControl
local SetControlEnabled = W.SetControlEnabled
local BORDER_STYLE_OPTIONS = Options.Constants.BORDER_STYLE_OPTIONS

function Options:CreateGeneralPage(parent)
    local db = BattleMaps.Database:Get()
    local appearanceHeight = 334
    local page = CreateFrame("Frame", nil, parent)
    self.pages.general = page
    page:SetAllPoints(parent)

    local behaviour = MakePanel(page, "Behaviour", 0, -8, 334, 184)
    MakeCheckbox(behaviour, "Show automatically in battlegrounds", 10, -34,
        function() return db.autoShow end,
        function(value) db.autoShow = value end)
    MakeCheckbox(behaviour, "Hide automatically after leaving", 10, -64,
        function() return db.autoHide end,
        function(value) db.autoHide = value end)
    MakeCheckbox(behaviour, "Show login message", 10, -94,
        function() return db.showLoginMessage end,
        function(value) db.showLoginMessage = value end)

    local minimapButtonCheck = MakeCheckbox(behaviour, "Show minimap button", 10, -124,
        function()
            if BattleMaps.IsMinimapButtonShown then
                return BattleMaps.IsMinimapButtonShown()
            end
            return not (db.minimapButton and db.minimapButton.hide == true)
        end,
        function(value)
            if BattleMaps.SetMinimapButtonShown then
                BattleMaps.SetMinimapButtonShown(value)
            end
        end)
    AddControlTooltip(minimapButtonCheck, "Minimap button",
        "Shows the standard BattleMaps LibDBIcon launcher around the minimap. Left-click opens BattleMaps options. Drag the button to reposition it.")

    local fullMap = MakePanel(page, "Full-screen map", 350, -(appearanceHeight + 24), 334, 156)
    self.worldMapIntegrationCheck = MakeCheckbox(fullMap, "Enable BattleMaps on the full-screen map", 10, -34,
        function() return db.enableWorldMapIntegration ~= false end,
        function(value)
            local integration = BattleMaps.WorldMapIntegration
            if integration and integration.SetEnabled then
                integration:SetEnabled(value)
            else
                db.enableWorldMapIntegration = value
            end
        end)
    AddControlTooltip(self.worldMapIntegrationCheck, "Full-screen BattleMaps",
        "When enabled, pressing M in a supported battleground displays BattleMaps over the battleground page. Browsing to another map reveals Blizzard's normal World Map.")

    self.worldMapPinScale = MakeSlider(fullMap, "Full-screen pin and effect scale", 12, -78, 0.75, 2.00, 0.05,
        function() return tonumber(db.worldMapPinScale) or 1.00 end,
        function(value)
            db.worldMapPinScale = value
            local mapFrame = BattleMaps.MapFrame
            if mapFrame and mapFrame:IsWorldMapMode() and BattleMaps.Pins then
                BattleMaps.Pins:RefreshAll(true)
                mapFrame:LayoutView()
            end
        end,
        function(value) return string.format("%d%%", math.floor((value * 100) + 0.5)) end)
    AddControlTooltip(self.worldMapPinScale, "Full-screen pin and effect scale",
        "Scales player, teammate, objective, timer, trail, pulse, and carried-objective visuals only on the full-screen map. Floating-map sizes are unchanged.")

    fullMap.Refresh = function()
        local enabled = db.enableWorldMapIntegration ~= false
        SetControlEnabled(self.worldMapPinScale, enabled)
    end
    self.refreshers[#self.refreshers + 1] = fullMap

    local appearance = MakePanel(page, "Map appearance", 350, -8, 334, appearanceHeight)
    self.factionSwapAlertCheck = MakeCheckbox(appearance, "Faction swap alert", 10, -30,
        function() return db.factionSwapAlert ~= false end,
        function(value)
            db.factionSwapAlert = value
            db.factionColoredBorder = value -- legacy alias
            BattleMaps.MapFrame:UpdateBorder()
        end)
    AddControlTooltip(self.factionSwapAlertCheck, "Faction swap alert",
        "Colours the map border only when the battleground assigns you to the opposite faction.")

    MakeCheckbox(appearance, "Fade map header when mouse leaves", 10, -56,
        function() return db.fadeMapHeader end,
        function(value)
            db.fadeMapHeader = value
            BattleMaps.MapFrame:UpdateChromeFade(0, true)
        end)

    self.borderStyleDropdown = MakeDropdown(appearance, "Border style", 12, -84, 250, BORDER_STYLE_OPTIONS,
        function() return db.frameBorderStyle or "solid" end,
        function(value)
            db.frameBorderStyle = value == "tooltip" and "tooltip"
                or value == "dialog" and "dialog"
                or "solid"
            BattleMaps.MapFrame:ApplyVisualSettings()
        end,
        true)

    MakeSlider(appearance, "Border thickness", 12, -132, 0, 8, 1,
        function() return tonumber(db.frameBorderSize) or 2 end,
        function(value)
            db.frameBorderSize = value
            BattleMaps.MapFrame:ApplyVisualSettings()
        end,
        function(value) return value == 0 and "Off" or string.format("%d px", value) end)

    MakeSlider(appearance, "Border strength", 12, -180, 0.15, 1.00, 0.05,
        function() return tonumber(db.frameBorderStrength) or 1 end,
        function(value)
            db.frameBorderStrength = value
            BattleMaps.MapFrame:UpdateBorder()
        end,
        function(value) return string.format("%d%%", math.floor((value * 100) + 0.5)) end)

    self.mapTextureAlphaSlider = MakeSlider(
        appearance,
        "Map texture opacity",
        12,
        -228,
        0.20,
        1.00,
        0.05,
        function() return tonumber(db.mapTextureAlpha) or 1 end,
        function(value)
            db.mapTextureAlpha = value
            BattleMaps.MapFrame:ApplyVisualSettings()
        end,
        function(value) return string.format("%d%%", math.floor((value * 100) + 0.5)) end
    )

    self.frameBackgroundColorControl = MakeColorSwatchControl(
        appearance,
        "Frame background",
        12,
        -276,
        function()
            local color = db.frameBackgroundColor
            return type(color) == "table" and color
                or { r = 0.015, g = 0.015, b = 0.015, a = 0.12 }
        end,
        function() self:OpenFrameBackgroundColorPicker() end,
        304
    )
    AddControlTooltip(self.frameBackgroundColorControl, "Frame background",
        "Sets the color behind the map artwork. The color picker's opacity control changes the background opacity independently of Map texture opacity.")
end

if Options.RegisterPage then
    Options:RegisterPage("general", "General", 680, "CreateGeneralPage", 10)
end
