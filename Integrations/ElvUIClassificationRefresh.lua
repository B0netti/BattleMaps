local addonName, BattleMaps = ...
BattleMaps = BattleMaps or _G.BattleMaps
if not BattleMaps then return end

--[[
BattleMaps module contract: ElvUIClassificationRefresh.lua

Compatibility shim for ElvUI/oUF's existing PvPClassificationIndicator.

WoW 12.1 can expose UnitPvpClassification() correctly for raid/party units while
not reliably driving the UNIT_CLASSIFICATION_CHANGED refresh that oUF expects.
BattleMaps does NOT create, anchor, reparent, resize, or otherwise modify secure
ElvUI unit frames here. It only asks ElvUI's already-enabled classification
element to ForceUpdate when battleground objective state is likely to have
changed.
]]

local function GetElvUIUnitFrames()
    local elvui = _G.ElvUI
    if type(elvui) ~= "table" then return nil, nil end

    local E = type(elvui[1]) == "table" and elvui[1] or nil
    if not E and type(unpack) == "function" then
        local ok, engine = pcall(function() return unpack(elvui) end)
        if ok then E = engine end
    end
    if not E or type(E.GetModule) ~= "function" then return nil, nil end

    local ok, UF = pcall(E.GetModule, E, "UnitFrames")
    if not ok or type(UF) ~= "table" then return E, nil end
    return E, UF
end

local function IsElementEnabled(frame)
    if not frame or type(frame.IsElementEnabled) ~= "function" then return false end
    local ok, enabled = pcall(frame.IsElementEnabled, frame, "PvPClassificationIndicator")
    return ok and enabled == true
end

-- ElvUI's raid/party frames are secure-header children. The visible children
-- are not reliably addressable through UF["raidN"], but oUF registers its
-- actual clickable unit frames in ClickCastFrames. Iterate that existing
-- registry and touch only ElvUI frames that already own the classification
-- element. We deliberately do NOT call SecureButton_GetUnit here.
local function IsElvUIUnitFrame(frame)
    if not frame or type(frame.GetName) ~= "function" then return false end
    local ok, name = pcall(frame.GetName, frame)
    if not ok or type(name) ~= "string" or not name:match("^ElvUF_") then
        return false
    end
    return frame.PvPClassificationIndicator ~= nil
end

local function IterateClassificationFrames(callback)
    local registry = _G.ClickCastFrames
    if type(registry) ~= "table" or type(callback) ~= "function" then return 0 end

    local count = 0
    for frame in pairs(registry) do
        if IsElvUIUnitFrame(frame) then
            count = count + 1
            callback(frame)
        end
    end
    return count
end

local function RefreshFrame(frame)
    if not IsElementEnabled(frame) then return false end

    local indicator = frame.PvPClassificationIndicator
    if not indicator or type(indicator.ForceUpdate) ~= "function" then return false end

    local ok = pcall(indicator.ForceUpdate, indicator)
    return ok == true
end

function BattleMaps.RefreshElvUIPvPClassificationIndicators()
    local E, UF = GetElvUIUnitFrames()
    if not E or not UF then return 0 end

    local refreshed = 0
    IterateClassificationFrames(function(frame)
        if RefreshFrame(frame) then
            refreshed = refreshed + 1
        end
    end)
    return refreshed
end

function BattleMaps.PrintElvUIPvPClassificationStatus()
    local E, UF = GetElvUIUnitFrames()
    if not E or not UF then
        BattleMaps.Chat("ElvUI UnitFrames are unavailable.")
        return
    end

    local carriers = {}
    local foundCount = 0
    local enabledCount = 0
    local refreshedCount = 0

    IterateClassificationFrames(function(frame)
        foundCount = foundCount + 1
        if IsElementEnabled(frame) then
            enabledCount = enabledCount + 1
        end
        if RefreshFrame(frame) then
            refreshedCount = refreshedCount + 1
        end
    end)

    local function CheckClassification(unit)
        if not UnitExists or not UnitExists(unit) then return end
        if type(UnitPvpClassification) ~= "function" then return end

        local ok, classification = pcall(UnitPvpClassification, unit)
        local secret = type(issecretvalue) == "function" and issecretvalue(classification) or false
        if ok and classification ~= nil and not secret then
            carriers[#carriers + 1] = unit .. "=" .. tostring(classification)
        end
    end

    CheckClassification("player")
    for i = 1, 4 do CheckClassification("party" .. i) end
    for i = 1, 40 do CheckClassification("raid" .. i) end

    local carrierText = #carriers > 0 and table.concat(carriers, ", ") or "none"
    BattleMaps.Chat(string.format(
        "ElvUI PvP classification: frames=%d, enabled=%d, refreshed=%d, classified=%s.",
        foundCount,
        enabledCount,
        refreshedCount,
        carrierText
    ))
end

local refreshSerial = 0

function BattleMaps.QueueElvUIPvPClassificationRefresh(delays)
    local _, UF = GetElvUIUnitFrames()
    if not UF then return end

    refreshSerial = refreshSerial + 1
    local serial = refreshSerial
    delays = type(delays) == "table" and delays or { 0, 0.08, 0.25, 0.60 }

    local function Refresh()
        if serial ~= refreshSerial then return end
        BattleMaps.RefreshElvUIPvPClassificationIndicators()
    end

    if C_Timer and C_Timer.After then
        for _, delay in ipairs(delays) do
            C_Timer.After(tonumber(delay) or 0, Refresh)
        end
    else
        Refresh()
    end
end

local eventFrame = CreateFrame("Frame", "BattleMapsElvUIClassificationRefreshFrame")
BattleMaps.ElvUIClassificationRefreshFrame = eventFrame

local events = {
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
    "GROUP_ROSTER_UPDATE",
    "SCENARIO_UPDATE",
    "UPDATE_BATTLEFIELD_SCORE",
    "UNIT_CLASSIFICATION_CHANGED",
    "CHAT_MSG_BG_SYSTEM_ALLIANCE",
    "CHAT_MSG_BG_SYSTEM_HORDE",
    "CHAT_MSG_BG_SYSTEM_NEUTRAL",
    "CHAT_MSG_RAID_BOSS_EMOTE",
    "RAID_BOSS_EMOTE",
}

for _, event in ipairs(events) do
    pcall(eventFrame.RegisterEvent, eventFrame, event)
end

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        BattleMaps.QueueElvUIPvPClassificationRefresh({ 0.15, 0.50, 1.25 })
    elseif event == "GROUP_ROSTER_UPDATE" then
        BattleMaps.QueueElvUIPvPClassificationRefresh({ 0.10, 0.35 })
    elseif event == "UNIT_CLASSIFICATION_CHANGED" then
        -- Keep Blizzard/oUF's intended event useful when it does fire.
        BattleMaps.QueueElvUIPvPClassificationRefresh({ 0 })
    else
        -- Objective announcements and scenario/score updates can precede the
        -- UnitPvpClassification value by a frame or two, so retry briefly.
        BattleMaps.QueueElvUIPvPClassificationRefresh({ 0, 0.08, 0.25, 0.60 })
    end
end)
