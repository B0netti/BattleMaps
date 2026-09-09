local addonName, BattleMaps = ...
BattleMaps = BattleMaps or _G.BattleMaps
if not BattleMaps then return end

--[[
BattleMaps module contract: BattlegroundUI.lua

Owns optional changes to battleground HUD/UI elements.
Currently this module only suppresses/restores Blizzard's Objective Tracker.

Do not attach BattleMaps regions directly to secure third-party unit frames.
The 2.8.9-2.8.10 ElvUI flag-carrier unit-frame experiment was removed after
enabling it caused a WoW client crash.
]]


local function GetDB()
    return BattleMaps.Database and BattleMaps.Database.Get and BattleMaps.Database:Get() or nil
end

local function IsLiveBattleground()
    return BattleMaps.IsInLiveBattleground and BattleMaps.IsInLiveBattleground() == true
end

-- Blizzard Objective Tracker -------------------------------------------------

local objectiveTrackerState

local function CaptureObjectiveTrackerState(frame)
    if objectiveTrackerState then return end

    local shown = false
    local alpha = 1
    if frame and type(frame.IsShown) == "function" then
        local ok, value = pcall(frame.IsShown, frame)
        shown = ok and value == true
    end
    if frame and type(frame.GetAlpha) == "function" then
        local ok, value = pcall(frame.GetAlpha, frame)
        if ok and type(value) == "number" then alpha = value end
    end

    objectiveTrackerState = {
        shown = shown,
        alpha = alpha,
        hiddenByBattleMaps = true,
        pendingHide = false,
        pendingRestore = false,
    }
end

local function SuppressObjectiveTracker()
    local frame = _G.ObjectiveTrackerFrame
    if not frame then return false end

    CaptureObjectiveTrackerState(frame)

    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        if type(frame.SetAlpha) == "function" then
            pcall(frame.SetAlpha, frame, 0)
        end
        objectiveTrackerState.pendingHide = true
        objectiveTrackerState.pendingRestore = false
        return true
    end

    if type(frame.Hide) == "function" then
        pcall(frame.Hide, frame)
    end
    if type(frame.SetAlpha) == "function" then
        pcall(frame.SetAlpha, frame, 0)
    end
    objectiveTrackerState.pendingHide = false
    objectiveTrackerState.pendingRestore = false
    return true
end

local function RestoreObjectiveTracker()
    local frame = _G.ObjectiveTrackerFrame
    if not objectiveTrackerState or not objectiveTrackerState.hiddenByBattleMaps then
        return false
    end

    if not frame then
        objectiveTrackerState = nil
        return false
    end

    if type(frame.SetAlpha) == "function" then
        pcall(frame.SetAlpha, frame, objectiveTrackerState.alpha or 1)
    end

    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        objectiveTrackerState.pendingRestore = true
        objectiveTrackerState.pendingHide = false
        return true
    end

    if objectiveTrackerState.shown and type(frame.Show) == "function" then
        pcall(frame.Show, frame)
    elseif not objectiveTrackerState.shown and type(frame.Hide) == "function" then
        pcall(frame.Hide, frame)
    end

    objectiveTrackerState = nil
    return true
end

function BattleMaps.ApplyObjectiveTrackerVisibility()
    local db = GetDB()
    local shouldHide = db
        and db.hideObjectiveTrackerInBattlegrounds == true
        and IsLiveBattleground()

    if shouldHide then
        return SuppressObjectiveTracker()
    end
    return RestoreObjectiveTracker()
end

-- Event ownership stays local so the primary BattleMaps event router remains
-- focused on map/objective rendering.
local eventFrame = CreateFrame("Frame", "BattleMapsBattlegroundUIEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("SCENARIO_UPDATE")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local arg1 = ...

    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_ObjectiveTracker" then
            BattleMaps.ApplyObjectiveTrackerVisibility()
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" or event == "SCENARIO_UPDATE" then
        BattleMaps.ApplyObjectiveTrackerVisibility()
        return
    end

    if event == "PLAYER_LOGIN"
        or event == "PLAYER_ENTERING_WORLD"
        or event == "ZONE_CHANGED_NEW_AREA" then
        BattleMaps.ApplyObjectiveTrackerVisibility()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.25, function()
                BattleMaps.ApplyObjectiveTrackerVisibility()
            end)
        end
    end
end)
