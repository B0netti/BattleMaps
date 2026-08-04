local _, BattleMaps = ...
local Options = BattleMaps and BattleMaps.Options
if not Options or not Options.Widgets then return end

local W = Options.Widgets
local MakeCheckbox = W.MakeCheckbox
local AddControlTooltip = W.AddControlTooltip
local MakeResetIconButton = W.MakeResetIconButton
local MakePanel = W.MakePanel
local MakeChoiceSelector = W.MakeChoiceSelector
local MakeSlider = W.MakeSlider
local MakeDropdown = W.MakeDropdown
local MakeButton = W.MakeButton

function Options:CreateNotificationsPage(parent)
    local db = BattleMaps.Database:Get()
    local page = CreateFrame("Frame", nil, parent)
    self.pages.notifications = page
    page:SetAllPoints(parent)

    local function Settings()
        return self:GetNotificationTarget()
    end

    self.notificationsGlobalCheck = MakeCheckbox(page, "Use global settings", 4, -2,
        function() return db.useGlobalNotificationSettings ~= false end,
        function(value)
            db.useGlobalNotificationSettings = value
            self:Refresh()
            if BattleMaps.Notifications then BattleMaps.Notifications:ApplyAndShowGuide() end
        end)
    AddControlTooltip(self.notificationsGlobalCheck, "Use global settings",
        "When enabled, notification placement and appearance use the shared defaults for every battleground. Disable it to edit the selected battleground only.")

    local resetNotifications = MakeResetIconButton(page, "Reset notifications", "Restores notification placement and appearance settings for this page to their defaults.", function()
        BattleMaps.Database:ResetNotifications(self.selectedMapID)
        self:Refresh()
        if BattleMaps.Notifications then BattleMaps.Notifications:ApplyAndShowGuide() end
    end)
    resetNotifications:SetPoint("TOPRIGHT", page, "TOPRIGHT", -4, -2)

    local main = MakePanel(page, "Battleground notifications", 0, -34, 684, 136)
    self.notificationEnabledCheck = MakeCheckbox(main, "Manage Blizzard battleground and raid-warning notifications", 10, -30,
        function() return Settings().enabled end,
        function(value)
            Settings().enabled = value
            BattleMaps.Notifications:Apply()
        end)
    self.notificationFactionCheck = MakeCheckbox(main, "Colour faction-related announcements", 10, -56,
        function() return Settings().colorByFaction end,
        function(value) Settings().colorByFaction = value end)

    self.notificationWorldMapBlizzardCheck = MakeCheckbox(main,
        "Use Blizzard notifications while the full-screen map is open", 10, -82,
        function() return Settings().useBlizzardOnWorldMap ~= false end,
        function(value)
            Settings().useBlizzardOnWorldMap = value
            if BattleMaps.Notifications then BattleMaps.Notifications:Apply() end
        end)
    AddControlTooltip(self.notificationWorldMapBlizzardCheck,
        "Full-screen map notification ownership",
        "When enabled, opening the full-screen World Map restores Blizzard's native notification position, style, and filtering. Disable this to keep BattleMaps notification handling active while the full-screen map is open.")

    local description = main:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    description:SetPoint("TOPLEFT", main, "TOPLEFT", 14, -110)
    description:SetPoint("TOPRIGHT", main, "TOPRIGHT", -14, -110)
    description:SetJustifyH("LEFT")
    description:SetText("Controls RaidBossEmoteFrame and RaidWarningFrame; disabling restores Blizzard's captured settings.")

    local placement = MakePanel(page, "Placement", 0, -176, 684, 170)
    self.notificationAnchorMode = MakeDropdown(placement, "Position mode", 12, -30, 250, {
        { value = "INDEPENDENT", label = "Screen" },
        { value = "MAP", label = "Attach to map" },
    }, function() return Settings().anchorMode end, function(value)
        Settings().anchorMode = value
        BattleMaps.Notifications:ApplyAndShowGuide()
    end, true)

    self.notificationMapSide = MakeDropdown(placement, "Map attachment", 342, -30, 250, {
        { value = "TOP", label = "Top centre" },
        { value = "TOPLEFT", label = "Top left" },
        { value = "TOPRIGHT", label = "Top right" },
        { value = "BOTTOM", label = "Bottom centre" },
        { value = "LEFT", label = "Left side" },
        { value = "RIGHT", label = "Right side" },
    }, function() return Settings().mapAnchorSide end, function(value)
        -- Changing attachment sides must not overwrite the user's offsets.
        -- Reset Position remains available when the defaults are desired.
        Settings().mapAnchorSide = value
        BattleMaps.Notifications:ApplyAndShowGuide()
    end, true)

    self.notificationAlignment = MakeChoiceSelector(placement, "Text alignment", 12, -78, {
        { value = "LEFT", label = "Left" },
        { value = "CENTER", label = "Centre" },
        { value = "RIGHT", label = "Right" },
    }, function() return Settings().justifyH end, function(value)
        Settings().justifyH = value
        BattleMaps.Notifications:ApplyAndShowGuide()
    end, 82)

    self.notificationX = MakeSlider(placement, "Horizontal offset", 12, -120, -300, 300, 1,
        function() local settings = Settings(); return settings.anchorMode == "MAP" and settings.mapX or settings.x end,
        function(value)
            local settings = Settings(); if settings.anchorMode == "MAP" then settings.mapX = value else settings.x = value end
            BattleMaps.Notifications:ApplyAndShowGuide()
        end,
        function(value) return string.format("%d px", value) end)
    self.notificationY = MakeSlider(placement, "Vertical offset", 342, -120, -300, 300, 1,
        function() local settings = Settings(); return settings.anchorMode == "MAP" and settings.mapY or settings.y end,
        function(value)
            local settings = Settings(); if settings.anchorMode == "MAP" then settings.mapY = value else settings.y = value end
            BattleMaps.Notifications:ApplyAndShowGuide()
        end,
        function(value) return string.format("%d px", value) end)

    local appearance = MakePanel(page, "Appearance", 0, -352, 684, 128)
    self.notificationScale = MakeSlider(appearance, "Notification scale", 12, -34, 0.50, 2.00, 0.05,
        function() return tonumber(Settings().scale) or 1 end,
        function(value)
            Settings().scale = value
            BattleMaps.Notifications:ApplyAndShowGuide()
        end,
        function(value) return string.format("%.2fx", value) end)
    self.notificationWidth = MakeSlider(appearance, "Text area width", 342, -34, 240, 900, 10,
        function() return tonumber(Settings().width) or 520 end,
        function(value)
            Settings().width = value
            BattleMaps.Notifications:ApplyAndShowGuide()
        end,
        function(value) return string.format("%d px", value) end)

    local move = MakeButton(appearance, "Move Notifications", 142)
    self.notificationMoveButton = move
    move:SetPoint("BOTTOMLEFT", appearance, "BOTTOMLEFT", 14, 12)
    move:SetScript("OnClick", function()
        BattleMaps.Notifications:ToggleMover()
        self:Refresh()
    end)

    local preview = MakeButton(appearance, "Preview", 90)
    preview:SetPoint("LEFT", move, "RIGHT", 8, 0)
    preview:SetScript("OnClick", function() BattleMaps.Notifications:Preview() end)

    local reset = MakeButton(appearance, "Reset Position", 112)
    reset:SetPoint("LEFT", preview, "RIGHT", 8, 0)
    reset:SetScript("OnClick", function()
        BattleMaps.Notifications:ResetPosition()
        self:Refresh()
    end)
end

if Options.RegisterPage then
    Options:RegisterPage("notifications", "Notifications", 650, "CreateNotificationsPage", 50)
end
