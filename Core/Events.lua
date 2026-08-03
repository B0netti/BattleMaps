local addonName, BattleMaps = ...

local Events = CreateFrame("Frame", "BattleMapsEventFrame")
BattleMaps.Events = Events

local locationRefreshSerial = 0

local function HandleLocationChange(serial)
    if serial and serial ~= locationRefreshSerial then return end

    local inBattleground = BattleMaps.IsInLiveBattleground()
    local mapID = BattleMaps.ResolveCurrentBattlegroundMapID()
    local db = BattleMaps.Database:Get()

    BattleMaps.Debug(
        "location refresh",
        "inBattleground=", tostring(inBattleground),
        "mapID=", tostring(mapID),
        "shownMap=", tostring(BattleMaps.MapFrame.currentMapID),
        "editing=", tostring(BattleMaps.MapFrame.editMode)
    )

    if inBattleground then
        -- The instance can report that it is a battleground a fraction of a
        -- second before its supported UI map is available. Leave the existing
        -- map alone and let the scheduled retries finish the transition.
        local mapInfo = mapID and BattleMaps.GetBattlegroundInfoForConfig
            and BattleMaps.GetBattlegroundInfoForConfig(mapID)
        if not mapID or not mapInfo then
            if BattleMaps.ApplyMinimapVisibility then BattleMaps.ApplyMinimapVisibility() end
            return false
        end

        BattleMaps.MapFrame.selectedMapID = mapID
        BattleMaps.Options.selectedMapID = mapID
        BattleMaps.MapFrame:SetLiveBattleground(mapID, true)

        if BattleMaps.Options.frame and BattleMaps.Options.frame:IsShown() then
            BattleMaps.MapFrame.frame:Show()
            BattleMaps.Options:Refresh()
        elseif db.autoShow then
            BattleMaps.MapFrame.frame:Show()
        end
        if BattleMaps.Notifications then BattleMaps.Notifications:Apply() end
        if BattleMaps.ApplyMinimapVisibility then BattleMaps.ApplyMinimapVisibility() end
        return true
    end

    if db.autoHide and not BattleMaps.MapFrame.previewMode then
        BattleMaps.MapFrame:Hide()
    end
    if BattleMaps.Notifications then BattleMaps.Notifications:Apply() end
    if BattleMaps.ApplyMinimapVisibility then BattleMaps.ApplyMinimapVisibility() end
    return true
end

local function DelayedLocationRefresh()
    locationRefreshSerial = locationRefreshSerial + 1
    local serial = locationRefreshSerial

    HandleLocationChange(serial)
    if C_Timer and C_Timer.After then
        -- The live map ID is not consistently available on the first
        -- PLAYER_ENTERING_WORLD callback. Use a serial so older transitions
        -- cannot overwrite a newer one.
        for _, delay in ipairs({ 0.10, 0.35, 0.80, 1.50, 3.00, 5.00, 8.00 }) do
            C_Timer.After(delay, function() HandleLocationChange(serial) end)
        end
    end
end

Events:RegisterEvent("ADDON_LOADED")
Events:RegisterEvent("PLAYER_LOGIN")
Events:RegisterEvent("PLAYER_ENTERING_WORLD")
Events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
Events:RegisterEvent("PLAYER_MAP_CHANGED")
Events:RegisterEvent("UPDATE_INSTANCE_INFO")
Events:RegisterEvent("GROUP_ROSTER_UPDATE")
Events:RegisterEvent("PLAYER_ROLES_ASSIGNED")
Events:RegisterEvent("ROLE_CHANGED_INFORM")
Events:RegisterEvent("PVP_VEHICLE_INFO_UPDATED")
Events:RegisterEvent("AREA_POIS_UPDATED")
Events:RegisterEvent("VIGNETTES_UPDATED")
Events:RegisterEvent("SCENARIO_UPDATE")
Events:RegisterEvent("ARENA_OPPONENT_UPDATE")
Events:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
Events:RegisterEvent("PLAYER_REGEN_ENABLED")
Events:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
Events:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
Events:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
Events:RegisterEvent("DISPLAY_SIZE_CHANGED")
Events:RegisterEvent("UI_SCALE_CHANGED")

Events:SetScript("OnEvent", function(_, event, ...)
    local arg1 = ...

    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        BattleMaps.Battlegrounds:RefreshLocalizedAliases()
        local db = BattleMaps.Database:Initialize()
        BattleMaps.MapFrame:Create()
        BattleMaps.Pins:Initialize(BattleMaps.MapFrame.pinLayer)
        BattleMaps.Options:Create()
        if BattleMaps.Notifications then BattleMaps.Notifications:Apply() end
        if BattleMaps.ApplyMinimapVisibility then BattleMaps.ApplyMinimapVisibility() end

        if db.showLoginMessage then
            BattleMaps.Chat("loaded (" .. BattleMaps.BUILD .. "). /bmap opens settings; Shift-M remains Blizzard's native map.")
        end
        DelayedLocationRefresh()
        if C_Timer and C_Timer.After and BattleMaps.Notifications then
            C_Timer.After(0.50, function() BattleMaps.Notifications:Apply() end)
            C_Timer.After(1.50, function() BattleMaps.Notifications:Apply() end)
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        DelayedLocationRefresh()
    elseif event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or event == "CHAT_MSG_BG_SYSTEM_HORDE" or event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
        -- Route all BG objective announcements through the single chained receiver.
        -- Pins.lua owns stationary objective records/timers; ObjectiveTextures.lua
        -- extends that same receiver for Deephaul/CTF/EotS-specific state.
        if BattleMaps.Pins then BattleMaps.Pins:RecordObjectiveFactionMessage(event, arg1) end
        if BattleMaps.Notifications then BattleMaps.Notifications:RecordFactionMessage(event, arg1) end
    elseif event == "PLAYER_ENTERING_WORLD"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "PLAYER_MAP_CHANGED"
        or event == "UPDATE_INSTANCE_INFO" then
        if (event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA") and BattleMaps.Pins then
            BattleMaps.Pins:ResetStationaryObjectiveStateTracking()
        end
        DelayedLocationRefresh()
        if C_Timer and C_Timer.After and BattleMaps.Notifications then
            C_Timer.After(0.50, function() BattleMaps.Notifications:Apply() end)
            C_Timer.After(1.50, function() BattleMaps.Notifications:Apply() end)
        end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" or event == "ROLE_CHANGED_INFORM" then
        if BattleMaps.MapFrame.frame and BattleMaps.MapFrame.frame:IsShown() then
            BattleMaps.Pins:RefreshGroup()
        end
    elseif event == "PVP_VEHICLE_INFO_UPDATED" then
        if BattleMaps.MapFrame.frame and BattleMaps.MapFrame.frame:IsShown() then
            BattleMaps.Pins:RefreshVehicles()
        end
    elseif event == "AREA_POIS_UPDATED" then
        if BattleMaps.MapFrame.frame and BattleMaps.MapFrame.frame:IsShown() then
            BattleMaps.Pins:RefreshPOIs()
        end
    elseif event == "VIGNETTES_UPDATED" then
        if BattleMaps.MapFrame.frame and BattleMaps.MapFrame.frame:IsShown() then
            BattleMaps.Pins:RefreshVignettes()
        end
    elseif event == "SCENARIO_UPDATE" then
        if BattleMaps.MapFrame.frame and BattleMaps.MapFrame.frame:IsShown() then
            BattleMaps.Pins:RefreshScenarios()
        end
    elseif event == "ARENA_OPPONENT_UPDATE" then
        if BattleMaps.MapFrame.frame and BattleMaps.MapFrame.frame:IsShown() then
            BattleMaps.Pins:RefreshFlags()
        end
    elseif event == "UPDATE_BATTLEFIELD_SCORE" then
        BattleMaps.MapFrame:UpdateBorder()

        -- Blitz and mercenary-style assignments may change the player's effective
        -- faction after the map first appears. Rebuild only when the selected
        -- faction-colour mode actually needs updating.
        local db = BattleMaps.Database:Get()
        local faction = BattleMaps.MapFrame:GetEffectiveFaction()
        if (db.useCustomPlayerArrow or db.showPlayerRadius)
            and db.playerArrowColorMode == "faction"
            and BattleMaps.Pins.lastPlayerFaction ~= faction
            and BattleMaps.MapFrame.frame
            and BattleMaps.MapFrame.frame:IsShown() then
            BattleMaps.Pins:RefreshGroup()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Repair any restricted unit renderer update that was deferred while
        -- combat lockdown was active. This is harmless when the map is hidden.
        if BattleMaps.MapFrame.frame and BattleMaps.MapFrame.frame:IsShown()
            and BattleMaps.Pins then
            BattleMaps.Pins:RefreshGroup()
        end
        if BattleMaps.Notifications then BattleMaps.Notifications:Apply() end
        if BattleMaps.ApplyMinimapVisibility then BattleMaps.ApplyMinimapVisibility() end
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        BattleMaps.MapFrame:LayoutView()
        if BattleMaps.Notifications then BattleMaps.Notifications:Apply() end
    end
end)
