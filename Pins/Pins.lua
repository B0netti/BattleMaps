local _, BattleMaps = ...

local Pins = {
    vehiclePins = {},
    flagPins = {},
    flagTrailFrames = {},
    flagTrailHistory = {},
    flagTrailLastSampleByIndex = {},
    poiPins = {},
    scenarioPins = {},
    vignettePins = {},
    unitPingFrames = {},
    objectivePingFrames = {},
    objectiveTexturePulses = {},
    objectiveCaptureTimers = {},
    objectiveBlitzUncapTimers = {},
    captureTimerTestSerial = 0,
    captureTimerTestMapID = nil,
    vehicleElapsed = 1,
    flagElapsed = 1,
    poiElapsed = 1,
    scenarioElapsed = 1,
    vignetteElapsed = 1,
    unitElapsed = 1,
    dummyPins = {},
    dummyTeamPins = {},
    dummyStationaryPins = {},
    previewPOICache = {},
    previewPOINextAttempt = {},
    previewFlagTextures = {},
    previewVehicleArtwork = {},
    objectiveTextureKeys = {},
    customTextureAvailability = {},
    stationaryObjectiveStateCache = {},
    stationaryObjectiveMessages = {},
    ctfFlagFactionByIndex = {},
}
BattleMaps.Pins = Pins

-- Unit pin artwork. Custom assets should be white/grayscale with transparency.
-- Friendly-unit icons are tinted by class; the custom player arrow is tinted by
-- the player's effective battleground faction.
local RAID_PIN_TEXTURE = "WhiteCircle-RaidBlips"
local PARTY_PIN_TEXTURE = "WhiteDotCircle-RaidBlips"
local CUSTOM_TEAM_PIN_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\team_circle_dot.tga"
local CUSTOM_TEAM_COMBAT_PIN_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\team_circle_white.tga"
local DEFAULT_PLAYER_ARROW_TEXTURE = "UI-WorldMapArrow"
local CUSTOM_HEALER_PIN_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\healer.tga"
local CUSTOM_HEALER_COMBAT_PIN_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\healer_dot.tga"
local OBJECTIVE_TEXTURE_ROOT = "Interface\\AddOns\\BattleMaps\\Media\\Objectives\\"
local CUSTOM_PLAYER_ARROW_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\player_arrow.tga"
local PLAYER_RADIUS_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\player_radius.tga"

-- UnitPositionFrame uses native pin sublevels for ordering within the same
-- restricted-position renderer. Teammates are intentionally above the player
-- arrow so stacked friendly markers remain readable around the local player.
local PLAYER_PIN_SUBLEVEL = 5
local GROUP_PIN_SUBLEVEL = 8
local PLAYER_RADIUS_SUBLEVEL = 1
local PLAYER_RADIUS_ALPHA = 0.65

-- Pin sizes respond to map zoom at half strength. At 1.00x zoom the saved
-- slider value is used unchanged; at 2.00x zoom pins use 1.50x size, and at
-- 3.00x zoom they use 2.00x size. This keeps zoom feedback without allowing
-- unit or objective markers to dominate the map.
local PIN_ZOOM_RESPONSE = 0.50

-- Blizzard Area POI pins use a 32 px placement frame but render the POI
-- sprite itself at 16 px. Custom stationary artwork must use the same visual
-- footprint; changing a TGA from 128x128 to 56x56 does not affect its on-map
-- size because WoW stretches the file into the dimensions set here.
local CUSTOM_AREA_POI_VISUAL_SIZE = 16

local FLAG_REFRESH_INTERVAL = 0.20
-- UnitPositionFrame continues to update the restricted player and group
-- positions natively between these passes. BattleMaps only needs to
-- reconcile its extra layers and stack layout at this cadence.
local UNIT_REFRESH_INTERVAL = 0.20

-- VIGNETTES_UPDATED triggers an immediate refresh. This is only a defensive
-- fallback for transitional provider updates; Seething Shore has its own
-- dedicated controller.
local VIGNETTE_REFRESH_INTERVAL = 0.25

local DEEPHAUL_RAVINE_MAP_ID = 2345
local DEEPHAUL_CRYSTAL_PULSE_SECONDS = 2.10

local UNIT_FRAME_LEVEL_OFFSET = 60
local RADIUS_FRAME_LEVEL_OFFSET = 9
local FLAG_PIN_FRAME_LEVEL_OFFSET = 59

-- Modern ping pulses. The same hollow ring texture used by the optional player
-- radius is reused here and tinted by ping type.
local PING_RING_TEXTURE = PLAYER_RADIUS_TEXTURE
local PING_POOL_SIZE = 4
local PING_DURATION = 1.80
local PING_RING_SIZE = 76
local PING_FRAME_LEVEL_OFFSET = 45
local PING_PIN_SUBLEVEL = 7

-- Objective-event pulses need a more polished profile than the generic
-- player/unit ping ring. Use layered rings, a fast ease-out expansion, and a
-- short fade-in so the effect reads like a battleground notification rather
-- than a debug circle being drawn on the map.
local OBJECTIVE_PULSE_PROFILES = {
    generic = {
        totalDuration = 1.00,
        primaryDelay = 0.00,
        primaryDuration = 0.70,
        primaryPeakAlpha = 0.58,
        primaryStartScale = 1.00,
        primaryEndScale = 2.35,
        echoDelay = 0.12,
        echoDuration = 0.82,
        echoPeakAlpha = 0.22,
        echoStartScale = 1.12,
        echoEndScale = 2.90,
        highlightDelay = 0.00,
        highlightDuration = 0.46,
        highlightPeakAlpha = 0.46,
        highlightStartScale = 0.74,
        highlightEndScale = 1.48,
    },
    assault = {
        totalDuration = 1.02,
        primaryDelay = 0.00,
        primaryDuration = 0.72,
        primaryPeakAlpha = 0.68,
        primaryStartScale = 1.05,
        primaryEndScale = 2.55,
        echoDelay = 0.14,
        echoDuration = 0.84,
        echoPeakAlpha = 0.32,
        echoStartScale = 1.18,
        echoEndScale = 3.08,
        highlightDelay = 0.00,
        highlightDuration = 0.42,
        highlightPeakAlpha = 0.52,
        highlightStartScale = 0.76,
        highlightEndScale = 1.52,
    },
    capture = {
        totalDuration = 1.06,
        primaryDelay = 0.00,
        primaryDuration = 0.74,
        primaryPeakAlpha = 0.54,
        primaryStartScale = 1.00,
        primaryEndScale = 2.28,
        echoDelay = 0.13,
        echoDuration = 0.86,
        echoPeakAlpha = 0.18,
        echoStartScale = 1.10,
        echoEndScale = 2.72,
        highlightDelay = 0.00,
        highlightDuration = 0.50,
        highlightPeakAlpha = 0.62,
        highlightStartScale = 0.80,
        highlightEndScale = 1.72,
    },
}

-- Arathi Basin bases normally change ownership 60 seconds after an
-- uninterrupted assault. The value is user-adjustable for testing/localisation
-- differences, while 60 remains the validated default. During that window
-- BattleMaps renders the neutral artwork underneath and reveals the attacking
-- faction's completed artwork using the selected horizontal or vertical fill.
local DEFAULT_ARATHI_BASIN_CAPTURE_DURATION = 60

local PING_COLORS = {
    Attack = { 1.00, 0.18, 0.12 },
    Assist = { 0.18, 0.62, 1.00 },
    Warning = { 1.00, 0.72, 0.10 },
    OnMyWay = { 0.15, 0.95, 0.42 },
    Threat = { 1.00, 0.36, 0.06 },
    NonThreat = { 0.25, 0.90, 1.00 },
    Generic = { 1.00, 1.00, 1.00 },
}

local function MixColor(r, g, b, targetR, targetG, targetB, amount)
    amount = BattleMaps and BattleMaps.Clamp and BattleMaps.Clamp(amount or 0, 0, 1) or 0
    return r + ((targetR - r) * amount),
        g + ((targetG - g) * amount),
        b + ((targetB - b) * amount)
end

local function EaseOutQuad(progress)
    progress = BattleMaps and BattleMaps.Clamp and BattleMaps.Clamp(progress or 0, 0, 1) or 0
    return 1 - ((1 - progress) * (1 - progress))
end

local function PulseLayerAlpha(progress, peakAlpha, fadeInPortion)
    if progress == nil then return 0 end
    progress = BattleMaps and BattleMaps.Clamp and BattleMaps.Clamp(progress or 0, 0, 1) or 0
    peakAlpha = BattleMaps and BattleMaps.Clamp and BattleMaps.Clamp(peakAlpha or 0, 0, 1) or 0
    fadeInPortion = BattleMaps and BattleMaps.Clamp and BattleMaps.Clamp(fadeInPortion or 0.14, 0.05, 0.45) or 0.14

    if progress <= 0 then return 0 end
    if progress < fadeInPortion then
        return (progress / fadeInPortion) * peakAlpha
    end

    local fadeOutProgress = (progress - fadeInPortion) / (1 - fadeInPortion)
    return BattleMaps and BattleMaps.Clamp and BattleMaps.Clamp((1 - fadeOutProgress) * peakAlpha, 0, peakAlpha) or 0
end

local function PulseSegmentProgress(elapsed, delay, duration)
    if elapsed == nil or duration == nil or duration <= 0 or elapsed < delay then return nil end
    return BattleMaps and BattleMaps.Clamp and BattleMaps.Clamp((elapsed - delay) / duration, 0, 1) or 0
end

local ObjectiveRules = BattleMaps.ObjectiveRules or {}

-- Phase-4 prep: objective rules/aliases/API-ID normalisation now live in
-- ObjectiveRules.lua. Keep local aliases here so the tested rendering code
-- continues to call the same helper names.
local NormalizeObjectiveKey = ObjectiveRules.NormalizeObjectiveKey
local NormalizeCompactObjectiveKey = ObjectiveRules.NormalizeCompactObjectiveKey
local AddUniqueObjectiveKey = ObjectiveRules.AddUniqueObjectiveKey
local BuildObjectiveKeys = ObjectiveRules.BuildObjectiveKeys
local InferObjectiveState = ObjectiveRules.InferObjectiveState
local InferStationaryObjectiveState = ObjectiveRules.InferStationaryObjectiveState
local GetObjectiveVisualSignature = ObjectiveRules.GetObjectiveVisualSignature
local ResolveObjectiveAPIMapID = ObjectiveRules.ResolveObjectiveAPIMapID
local GetObjectiveMapNameKey = ObjectiveRules.GetObjectiveMapNameKey
local IsArathiBasinMap = ObjectiveRules.IsArathiBasinMap
local IsCaptureTheFlagMap = ObjectiveRules.IsCaptureTheFlagMap
local IsTempleOfKotmoguMap = ObjectiveRules.IsTempleOfKotmoguMap
local GetObjectiveShortKeys = ObjectiveRules.GetObjectiveShortKeys
local GetObjectiveAliasKeys = ObjectiveRules.GetObjectiveAliasKeys
local GetStationaryMessageCacheKey = ObjectiveRules.GetStationaryMessageCacheKey
local GetCustomObjectiveLayout = ObjectiveRules.GetCustomObjectiveLayout
local GetObjectiveTextureFolderID = ObjectiveRules.GetObjectiveTextureFolderID
local GetAreaPOIIDs = ObjectiveRules.GetAreaPOIIDs
local ObjectiveCategoryEnabled = ObjectiveRules.ObjectiveCategoryEnabled

-- Capture-timer helpers are intentionally still thin wrappers around Core.lua.
-- They were accidentally dropped during the ObjectiveRules extraction, leaving
-- Pins:IsCaptureTimerMap() and Pins:IsCaptureTimerObjective() calling nil locals
-- when the options preview tried to render stationary POIs.
local function GetCaptureTimerProfile(mapID)
    return BattleMaps.GetCaptureTimerProfile and BattleMaps.GetCaptureTimerProfile(mapID) or nil
end

local function IsCaptureTimerMap(mapID)
    return GetCaptureTimerProfile(mapID) ~= nil
end

local function IsCaptureTimerObjective(mapID, info)
    if not IsCaptureTimerMap(mapID) then return false end

    -- Eye of the Storm's centre flag is not a delayed node capture and must
    -- never receive the base timer overlay.
    if tonumber(mapID) == 210 then
        local text = NormalizeObjectiveKey(table.concat({
            tostring(info and info.name or ""),
            tostring(info and info.description or ""),
            tostring(info and info.objectiveKey or ""),
            tostring(info and info.atlasName or info and info.atlas or ""),
        }, " "))
        if text:find("flag", 1, true) or text:find("netherstorm", 1, true) then
            return false
        end
    end

    return true
end

-- Match a battleground announcement to an objective using both Blizzard's
-- descriptive keys and BattleMaps' canonical short alias. The alias comparison
-- handles wording differences such as "Stable" versus "Stables" and does not
-- require the Area POI list to have updated at the instant the chat event fires.
local function ObjectiveMessageMatchesPOI(mapID, messageKey, poiID, info)
    local objectiveKeys = BuildObjectiveKeys(info, poiID, "stationary")

    local messageAliases = GetObjectiveShortKeys(mapID, { messageKey })
    local objectiveAliases = GetObjectiveShortKeys(mapID, objectiveKeys)
    if #messageAliases > 0 and #objectiveAliases > 0 then
        local aliases = {}
        for _, alias in ipairs(messageAliases) do aliases[alias] = true end
        for _, alias in ipairs(objectiveAliases) do
            if aliases[alias] then return true end
        end
    end

    local nameKey = NormalizeObjectiveKey(info and info.name)
    if nameKey ~= "" and messageKey:find(nameKey, 1, true) then return true end

    for _, key in ipairs(objectiveKeys) do
        if key ~= "objective" and key ~= "stationary" and not key:match("^index_%d+$")
            and messageKey:find(key, 1, true) then
            return true
        end
    end
    return false
end

local function GetObjectiveCaptureTimerKey(mapID, sourceIndex, info, mapX, mapY)
    local objectiveKeys = BuildObjectiveKeys(info, sourceIndex, "stationary")
    local aliases = GetObjectiveShortKeys(mapID, objectiveKeys)
    local objectiveKey = aliases[1] or NormalizeObjectiveKey(info and info.name)

    if not objectiveKey or objectiveKey == "" then
        objectiveKey = string.format("%.4f_%.4f", tonumber(mapX) or 0, tonumber(mapY) or 0)
    end

    return GetStationaryMessageCacheKey(mapID) .. ":" .. objectiveKey
end

-- Blizzard can expose the same objective through different Area POI records
-- while its state changes. Gold Mine is one example: one record can be named
-- "Gold Mine" while another is reduced to "Mine" or uses a different POI ID.
-- Prefer the canonical key, then bind by the objective coordinate so an active
-- timer survives those provider/name changes instead of falling back to the
-- standalone contested texture.
local function FindObjectiveCaptureTimerRecord(pins, mapID, sourceIndex, info, mapX, mapY)
    local exactKey = GetObjectiveCaptureTimerKey(mapID, sourceIndex, info, mapX, mapY)
    local timers = pins and pins.objectiveCaptureTimers
    if type(timers) ~= "table" then return exactKey, nil end

    local exactRecord = timers[exactKey]
    if exactRecord then return exactKey, exactRecord end

    local targetX = tonumber(mapX)
    local targetY = tonumber(mapY)
    if not targetX or not targetY then return exactKey, nil end

    local targetMapKey = GetStationaryMessageCacheKey(mapID)
    local now = type(GetTime) == "function" and GetTime() or 0
    local nearestKey, nearestRecord, nearestDistance

    for timerKey, record in pairs(timers) do
        if type(record) == "table"
            and record.expiresAt and record.expiresAt > now
            and GetStationaryMessageCacheKey(record.mapID) == targetMapKey then
            local recordX = tonumber(record.mapX)
            local recordY = tonumber(record.mapY)
            if recordX and recordY then
                local dx = recordX - targetX
                local dy = recordY - targetY
                local distance = (dx * dx) + (dy * dy)
                if distance <= 0.0004
                    and (not nearestDistance or distance < nearestDistance) then
                    nearestKey = timerKey
                    nearestRecord = record
                    nearestDistance = distance
                end
            end
        end
    end

    return nearestKey or exactKey, nearestRecord
end

-- Private-style helpers exposed for ObjectiveTimers.lua. The implementation
-- remains here because the matching rules depend on local objective-key tables
-- and normalisation helpers used by the rest of the pin renderer.
function Pins:NormalizeObjectiveKey(value)
    return NormalizeObjectiveKey(value)
end

function Pins:GetDefaultObjectiveCaptureDuration()
    return DEFAULT_ARATHI_BASIN_CAPTURE_DURATION
end

function Pins:GetCaptureTimerProfile(mapID)
    return GetCaptureTimerProfile(mapID)
end

function Pins:IsCaptureTimerMap(mapID)
    return IsCaptureTimerMap(mapID)
end

function Pins:IsCaptureTimerObjective(mapID, info)
    return IsCaptureTimerObjective(mapID, info)
end

function Pins:IsSyntheticCaptureTimerSuppressed(mapID)
    mapID = tonumber(mapID)
    if mapID ~= 210 then return false end

    local mapFrame = BattleMaps.MapFrame
    if mapFrame and mapFrame.testMode == true then
        return false
    end

    local battlegrounds = BattleMaps.Battlegrounds
    if battlegrounds and battlegrounds.IsInBattleground then
        local ok, inBG = pcall(battlegrounds.IsInBattleground, battlegrounds)
        if ok and inBG then
            return true
        end
    end

    return false
end

function Pins:GetObjectiveCaptureTimerKey(mapID, sourceIndex, info, mapX, mapY)
    return GetObjectiveCaptureTimerKey(mapID, sourceIndex, info, mapX, mapY)
end

function Pins:FindObjectiveCaptureTimerRecord(mapID, sourceIndex, info, mapX, mapY)
    return FindObjectiveCaptureTimerRecord(self, mapID, sourceIndex, info, mapX, mapY)
end

function Pins:GetRecentObjectiveMessageState(mapID, sourceIndex, info)
    local cacheKey = GetStationaryMessageCacheKey(mapID)
    local messages = self.stationaryObjectiveMessages[cacheKey]
    if type(messages) ~= "table" then return nil end

    local now = type(GetTime) == "function" and GetTime() or 0
    for index = #messages, 1, -1 do
        local messageState = messages[index]
        if not messageState or (messageState.expires or 0) <= now then
            table.remove(messages, index)
        elseif ObjectiveMessageMatchesPOI(mapID, messageState.messageKey, sourceIndex, info) then
            -- A later stable announcement permanently supersedes older assault
            -- messages for the same node. Expire them now so they cannot return
            -- after this record eventually ages out.
            if messageState.stable then
                for olderIndex = index - 1, 1, -1 do
                    local older = messages[olderIndex]
                    if older and ObjectiveMessageMatchesPOI(mapID, older.messageKey, sourceIndex, info) then
                        older.expires = now
                    end
                end
            end
            return messageState
        end
    end
    return nil
end

local function GetCanonicalStateSuffix(state)
    local values = type(state) == "table" and state or { state }
    local found = {}

    for _, value in ipairs(values) do
        value = NormalizeObjectiveKey(value)
        if value ~= "" then found[value] = true end
    end

    -- A_C / H_C mean the faction currently assaulting/capturing the node.
    if found.contested_alliance or found.alliance_contested then return "A_C", "contested_alliance" end
    if found.contested_horde or found.horde_contested then return "H_C", "contested_horde" end

    -- A generic contested state is intentionally not assigned a custom file.
    -- Without a known attacking faction, Blizzard's original artwork is safer
    -- than selecting a misleading Alliance or Horde texture.
    if found.contested then return nil, "contested" end

    if found.alliance then return "A", "alliance" end
    if found.horde then return "H", "horde" end
    if found.neutral or found.uncontrolled then return "N", found.uncontrolled and "uncontrolled" or "neutral" end
    return nil, nil
end

local function NormalizeObjectiveStates(state)
    local states, seen = {}, {}
    local function Add(value)
        value = NormalizeObjectiveKey(value)
        if value ~= "" and not seen[value] then
            seen[value] = true
            states[#states + 1] = value
        end
    end

    if type(state) == "table" then
        for _, value in ipairs(state) do Add(value) end
    else
        Add(state)
    end
    return states
end


local function IsStableObjectiveState(state)
    return state == "alliance" or state == "horde"
        or state == "neutral" or state == "uncontrolled"
end

local function ContestedStateForAssaultingFaction(faction)
    if faction == "alliance" then
        return { "contested_alliance", "alliance_contested", "contested" }
    elseif faction == "horde" then
        return { "contested_horde", "horde_contested", "contested" }
    end
    return { "contested" }
end

local function GetOpposingFaction(state)
    if state == "alliance" then return "horde" end
    if state == "horde" then return "alliance" end
    return nil
end

function Pins:GetStationaryObjectiveStateRecord(mapID, sourceIndex, info)
    mapID = tonumber(mapID)
    if not mapID then return nil end

    local mapCache = self.stationaryObjectiveStateCache[mapID]
    if not mapCache then
        mapCache = {}
        self.stationaryObjectiveStateCache[mapID] = mapCache
    end

    local identity = sourceIndex or (type(info) == "table" and info.areaPoiID)
    if identity == nil and type(info) == "table" then
        identity = NormalizeObjectiveKey(info.name)
    end
    identity = tostring(identity or "objective")

    local record = mapCache[identity]
    if not record then
        record = {}
        mapCache[identity] = record
    end
    return record
end

function Pins:ForceStationaryObjectiveState(mapID, sourceIndex, info, state, duration)
    local record = self:GetStationaryObjectiveStateRecord(mapID, sourceIndex, info)
    if not record then return false end

    state = NormalizeObjectiveKey(state)
    if state ~= "alliance" and state ~= "horde"
        and state ~= "neutral" and state ~= "uncontrolled" then
        return false
    end

    local now = type(GetTime) == "function" and GetTime() or 0
    record.overrideState = nil
    record.overrideExpires = nil
    record.forcedState = state
    record.forcedStateExpires = tonumber(duration) and (now + math.max(tonumber(duration), 0.1)) or nil
    record.stableState = state
    record.stableSignature = nil
    return true
end

function Pins:ClearForcedStationaryObjectiveState(mapID, sourceIndex, info)
    local record = self:GetStationaryObjectiveStateRecord(mapID, sourceIndex, info)
    if not record then return false end
    local hadState = record.forcedState ~= nil or record.forcedStateExpires ~= nil
    record.forcedState = nil
    record.forcedStateExpires = nil
    return hadState
end

function Pins:RecordStationaryObjectiveNeutralTransition(mapID, sourceIndex, info, objectiveName)
    local forced = self:ForceStationaryObjectiveState(mapID, sourceIndex, info, "neutral")
    local messageKey = NormalizeObjectiveKey(objectiveName or (type(info) == "table" and info.name))
    if messageKey == "" then return forced end

    local cacheKey = GetStationaryMessageCacheKey(mapID)
    local messages = self.stationaryObjectiveMessages[cacheKey]
    if not messages then
        messages = {}
        self.stationaryObjectiveMessages[cacheKey] = messages
    end

    local now = type(GetTime) == "function" and GetTime() or 0
    messages[#messages + 1] = {
        messageKey = messageKey,
        faction = nil,
        uncontrolled = true,
        contested = false,
        stable = false,
        expires = now + 120,
        syntheticBlitzNeutral = true,
    }
    while #messages > 24 do table.remove(messages, 1) end
    return true
end

function Pins:ResetStationaryObjectiveStateTracking(mapID)
    if mapID then
        self.stationaryObjectiveStateCache[tonumber(mapID) or mapID] = nil
        self.stationaryObjectiveMessages[GetStationaryMessageCacheKey(mapID)] = nil
    else
        wipe(self.stationaryObjectiveStateCache)
        wipe(self.stationaryObjectiveMessages)
    end
    self.lastObjectivePulseKey = nil
    self.lastObjectivePulseAt = nil
    self.carriedObjectiveFactionMessages = nil
    self.eotsCarriedFlagFactionRecord = nil
    self.eotsFlagAwayFromCenter = nil
    self.eotsFlagAwaySource = nil

    -- Kotmogu carried-orb state is match-local. Leaving/re-entering the
    -- battleground without clearing these tables can make the next match begin
    -- with old colours still considered carried, which hides the wrong spawn
    -- pads before any new pickup has occurred.
    self.templeActiveCarriedOrbColors = {}
    self.templeAPICarriedOrbColors = {}
    self.templeOrbMessageStateByColor = {}
    self.templeOrbMessageKnownByColor = {}
    self.templeOrbSuppressedUntilByColor = {}
    self.templeLastPickedOrbColor = nil
    self.templeLastPickedOrbAt = nil
    self.templeCarriedOrbColorBySlot = {}
    self.templeCarriedOrbMotionByColor = {}

    if mapID then
        local mapKey = tostring(tonumber(mapID) or mapID or "unknown")
        if type(self.ctfFlagObjectStateByMap) == "table" then
            self.ctfFlagObjectStateByMap[mapKey] = nil
        end
        if type(self.ctfFlagFactionByIndex) == "table" then
            local prefix = mapKey .. ":"
            for key in pairs(self.ctfFlagFactionByIndex) do
                if tostring(key):sub(1, #prefix) == prefix then
                    self.ctfFlagFactionByIndex[key] = nil
                end
            end
        end
    else
        if type(self.ctfFlagObjectStateByMap) == "table" then wipe(self.ctfFlagObjectStateByMap) end
        if type(self.ctfFlagFactionByIndex) == "table" then wipe(self.ctfFlagFactionByIndex) end
    end
    self.ctfFlagEffectMotionByKey = nil
    if self.ClearFlagCarrierTrails then
        self:ClearFlagCarrierTrails()
    end
    if self.StopAllObjectiveCaptureTimers then
        self:StopAllObjectiveCaptureTimers()
    end
end

function Pins:ResolveStationaryObjectiveState(mapID, sourceIndex, info)
    local record = self:GetStationaryObjectiveStateRecord(mapID, sourceIndex, info)
    if not record then
        return InferStationaryObjectiveState(info, true)
    end

    local now = type(GetTime) == "function" and GetTime() or 0
    local signature = GetObjectiveVisualSignature(info)
    local explicitStates = NormalizeObjectiveStates(InferStationaryObjectiveState(info, false))
    local explicit = explicitStates[1]
    local isLiveEotS = tonumber(mapID) == 210

    -- In normal/live Eye of the Storm, losing control resolves to an
    -- uncontrolled node, not to an assault by the opposite faction. Handle the
    -- raw neutral/uncontrolled POI state before the generic visual-signature
    -- contested inference below.
    if isLiveEotS and (explicit == "neutral" or explicit == "uncontrolled") then
        record.overrideState = nil
        record.overrideExpires = nil
        record.stableState = explicit
        record.stableSignature = signature
        return explicitStates
    end

    -- Battleground announcements are the authoritative source for who is
    -- assaulting a node. They are retained independently of the transient POI
    -- identity so a chat event that arrives before AREA_POIS_UPDATED still
    -- resolves ST_A_C/LM_H_C/etc. on the next objective refresh.
    local messageState = self:GetRecentObjectiveMessageState(mapID, sourceIndex, info)
    if messageState then
        if messageState.uncontrolled then
            local uncontrolledState = isLiveEotS and "uncontrolled" or "neutral"
            record.overrideState = nil
            record.overrideExpires = nil
            record.forcedState = uncontrolledState
            record.forcedStateExpires = nil
            record.stableState = uncontrolledState
            record.stableSignature = signature
            return uncontrolledState
        elseif messageState.contested then
            record.forcedState = nil
            record.forcedStateExpires = nil
            if messageState.faction then
                return ContestedStateForAssaultingFaction(messageState.faction)
            end
            return ContestedStateForAssaultingFaction(nil)
        elseif messageState.stable and messageState.faction then
            record.overrideState = nil
            record.overrideExpires = nil
            record.forcedState = nil
            record.forcedStateExpires = nil
            record.stableState = messageState.faction
            record.stableSignature = signature
            return messageState.faction
        end
    end

    if record.forcedState then
        if record.forcedStateExpires and record.forcedStateExpires <= now then
            record.forcedState = nil
            record.forcedStateExpires = nil
        else
            return record.forcedState
        end
    end

    -- A direct contested signal from Blizzard is authoritative. If Blizzard
    -- does not encode the attacker, infer the opposite of the last stable owner.
    if explicit and explicit:find("contested", 1, true) then
        if explicit == "contested" then
            local attacker = GetOpposingFaction(record.stableState)
            if attacker then return ContestedStateForAssaultingFaction(attacker) end
        end
        return explicitStates
    end

    -- Battleground system messages are checked before stable POI ownership.
    -- During an assault, AB commonly keeps reporting the previous owner (or
    -- neutral), which otherwise causes the contested texture to be skipped.
    if record.overrideState and (not record.overrideExpires or record.overrideExpires > now) then
        return ContestedStateForAssaultingFaction(record.overrideState)
    end
    record.overrideState = nil
    record.overrideExpires = nil

    -- A definite controlled state closes any expired/cleared contested state.
    if explicit == "alliance" or explicit == "horde" then
        record.stableState = explicit
        record.stableSignature = signature
        return explicitStates
    end

    -- Blizzard changes the native POI artwork when a node enters its capture
    -- timer. Compare it with the last stable signature as a secondary signal.
    if record.stableSignature and signature ~= "" and signature ~= record.stableSignature then
        local attacker = GetOpposingFaction(record.stableState)
        return ContestedStateForAssaultingFaction(attacker)
    end

    if explicit == "neutral" or explicit == "uncontrolled" then
        record.stableState = explicit
        record.stableSignature = signature
        return explicitStates
    end

    if IsStableObjectiveState(record.stableState) then
        return record.stableState
    end

    record.stableState = "neutral"
    record.stableSignature = signature
    return "neutral"
end


local function IsDeephaulRavineMap(mapID)
    if tonumber(mapID) == DEEPHAUL_RAVINE_MAP_ID then return true end
    local name = BattleMaps.GetBattlegroundNameForConfig
        and BattleMaps.GetBattlegroundNameForConfig(mapID)
        or (BattleMaps.Battlegrounds and BattleMaps.Battlegrounds.GetName
            and BattleMaps.Battlegrounds:GetName(mapID))
        or ""
    return NormalizeObjectiveKey(name):find("deephaul_ravine", 1, true) ~= nil
end

local function DeephaulMessageIsCrystalPickup(messageKey)
    return messageKey:find("taken_the_crystal", 1, true)
        or messageKey:find("has_taken_the_crystal", 1, true)
        or (messageKey:find("crystal", 1, true) and messageKey:find("taken", 1, true))
end

local function DeephaulMessageIsCrystalSpawn(messageKey)
    return messageKey:find("crystal", 1, true)
        and (messageKey:find("unearthed", 1, true)
            or messageKey:find("center_of_the_ravine", 1, true)
            or messageKey:find("centre_of_the_ravine", 1, true)
            or messageKey:find("respawn", 1, true))
end

local function DeephaulMessageIsCrystalReset(messageKey)
    return messageKey:find("flag_has_been_reset", 1, true)
        or messageKey:find("the_flag_has_been_reset", 1, true)
        or (messageKey:find("crystal", 1, true) and messageKey:find("reset", 1, true))
end

local function ObjectiveMessageIsLosingControl(messageKey)
    return messageKey:find("lost_control", 1, true)
        or messageKey:find("loses_control", 1, true)
        or messageKey:find("loss_of_control", 1, true)
        or messageKey:find("uncontrolled", 1, true)
        or messageKey:find("uncapped", 1, true)
        or messageKey:find("deactivated", 1, true)
        or messageKey:find("has_become_neutral", 1, true)
        or messageKey:find("becomes_neutral", 1, true)
        or messageKey:find("is_now_neutral", 1, true)
end

local function ObjectiveMessageIsContested(messageKey)
    return messageKey:find("assault", 1, true)
        or messageKey:find("under_attack", 1, true)
        or messageKey:find("being_captured", 1, true)
        or messageKey:find("capturing", 1, true)
        or ObjectiveMessageIsLosingControl(messageKey)
end

local function ObjectiveMessageIsStable(messageKey)
    return messageKey:find("has_taken", 1, true)
        or messageKey:find("captured", 1, true)
        or messageKey:find("defended", 1, true)
        or messageKey:find("controls", 1, true)
        or messageKey:find("claimed", 1, true)
end

local InferCarriedFlagFactionFromText

local function HasActiveBlitzUncapTimerForMap(pins, mapID)
    local now = type(GetTime) == "function" and GetTime() or 0
    for _, record in pairs(pins.objectiveBlitzUncapTimers or {}) do
        if record and tonumber(record.mapID) == tonumber(mapID)
            and record.expiresAt and record.expiresAt > now then
            return true
        end
    end
    return false
end

local function IsBlitzUncapNeutralTransition(pins, mapID, isLosingControl)
    if not isLosingControl
        or not BattleMaps.IsObjectiveBlitzUncapMap
        or BattleMaps.IsObjectiveBlitzUncapMap(mapID) ~= true then
        return false
    end

    if BattleMaps.IsBattlegroundBlitz and BattleMaps.IsBattlegroundBlitz() then
        return true
    end

    -- The queue-type API can briefly be unavailable during live map updates.
    -- An active 45-second uncap record is sufficient evidence that this is the
    -- automatic Blitz neutralisation transition rather than an enemy assault.
    return HasActiveBlitzUncapTimerForMap(pins, mapID)
end

-- Base battleground-objective message receiver.
--
-- Ownership note:
-- - This implementation owns stationary objective assault/capture records.
-- - Capture fill timers and final objective pulses are triggered from this path.
-- - Extension modules may add Deephaul/CTF-specific handling by wrapping this
--   method, but they must capture and call the previous implementation first.
--
-- Do not replace this function outright. If this handler is bypassed, maps such
-- as Battle for Gilneas can still show neutral POI textures but lose contested
-- faction textures and capture-fill animation.
function Pins:RecordObjectiveFactionMessage(event, message)
    if type(message) ~= "string" or message == "" then return end

    local faction
    if event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" then
        faction = "alliance"
    elseif event == "CHAT_MSG_BG_SYSTEM_HORDE" then
        faction = "horde"
    elseif event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
        faction = nil
    else
        return
    end

    local mapID = BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID
    if not mapID then return end

    local messageKey = NormalizeObjectiveKey(message)
    if messageKey == "" then return end

    local now = type(GetTime) == "function" and GetTime() or 0

    if IsDeephaulRavineMap(mapID) then
        local deephaulFaction = faction
        if DeephaulMessageIsCrystalPickup(messageKey) then
            if deephaulFaction == "alliance" or deephaulFaction == "horde" then
                self.deephaulCrystalCarried = true
                self.deephaulCrystalPulseUntil = now + DEEPHAUL_CRYSTAL_PULSE_SECONDS + 0.30
                self.deephaulCrystalPulseFaction = deephaulFaction
                self.deephaulCrystalHiddenAfterPulse = true
                if BattleMaps.MapFrame and BattleMaps.MapFrame.frame and BattleMaps.MapFrame.frame:IsShown() then
                    self:RefreshPOIs()
                    self:PulseDeephaulCrystal(deephaulFaction, true)
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0.05, function()
                            if BattleMaps.MapFrame.frame and BattleMaps.MapFrame.frame:IsShown() then
                                self:PulseDeephaulCrystal(deephaulFaction, true)
                            end
                        end)
                        C_Timer.After(DEEPHAUL_CRYSTAL_PULSE_SECONDS + 0.35, function()
                            if BattleMaps.MapFrame.frame and BattleMaps.MapFrame.frame:IsShown() then
                                self:RefreshPOIs()
                            end
                        end)
                    end
                end
            end
        elseif DeephaulMessageIsCrystalSpawn(messageKey) or DeephaulMessageIsCrystalReset(messageKey) then
            self.deephaulCrystalCarried = false
            self.deephaulCrystalPulseUntil = now + DEEPHAUL_CRYSTAL_PULSE_SECONDS + 0.30
            self.deephaulCrystalPulseFaction = nil
            self.deephaulCrystalHiddenAfterPulse = false
            if BattleMaps.MapFrame and BattleMaps.MapFrame.frame and BattleMaps.MapFrame.frame:IsShown() then
                self:RefreshPOIs()
                self:PulseDeephaulCrystal(nil, false)
                if C_Timer and C_Timer.After then
                    C_Timer.After(0.05, function()
                        if BattleMaps.MapFrame.frame and BattleMaps.MapFrame.frame:IsShown() then
                            self:PulseDeephaulCrystal(nil, false)
                        end
                    end)
                end
            end
        end
    end

    local mentionsCarriedFlag = messageKey:find("flag", 1, true)
        or messageKey:find("netherstorm", 1, true)
    if mentionsCarriedFlag then
        local flagObjectFaction = InferCarriedFlagFactionFromText(messageKey)

        if IsCaptureTheFlagMap(mapID) then
            -- In CTF maps, the important texture state is the flag object
            -- faction: Alliance flag versus Horde flag. The CHAT_MSG_* event
            -- faction can describe the team causing the event, so a single
            -- map-level cache can incorrectly recolour both flags. Do not use
            -- the EotS-style carried-faction cache here.
            if flagObjectFaction then
                faction = flagObjectFaction
            end
        elseif not faction then
            faction = flagObjectFaction
        end

        local cacheKey = GetStationaryMessageCacheKey(mapID)
        self.carriedObjectiveFactionMessages = self.carriedObjectiveFactionMessages or {}

        local taken = messageKey:find("has_taken", 1, true)
            or messageKey:find("taken_the_flag", 1, true)
            or messageKey:find("picked", 1, true)
            or messageKey:find("grabbed", 1, true)
        local dropped = messageKey:find("dropped", 1, true)
        local returnedOrCaptured = messageKey:find("returned", 1, true)
            or messageKey:find("reset", 1, true)
            or messageKey:find("captured", 1, true)
        local activeOrDropped = taken or dropped
        local cleared = dropped or returnedOrCaptured

        -- EotS-only carried-flag faction fallback. The flag-position API can
        -- expose the Netherstorm flag position with a neutral/factionless
        -- texture even while the default BG map colours it by the carrier team.
        -- Use BG system message faction only for EotS carried flag colour, and
        -- clear it on dropped/reset/capture so dropped flags can return to NF.tga.
        if tonumber(mapID) == 210 then
            -- Pickup and drop both mean the Netherstorm flag is away from its
            -- central spawn. Only return/reset/capture restores the stationary
            -- centre texture. The live flag-position API later confirms this
            -- state and handles missed announcements or /reloads.
            if self.SetEotSFlagAwayFromCenter then
                if taken or dropped then
                    self:SetEotSFlagAwayFromCenter(true, taken and "pickup-message" or "drop-message")
                elseif returnedOrCaptured then
                    self:SetEotSFlagAwayFromCenter(false, "reset-message")
                end
            else
                if taken or dropped then
                    self.eotsFlagAwayFromCenter = true
                elseif returnedOrCaptured then
                    self.eotsFlagAwayFromCenter = false
                end
            end

            if taken and (faction == "alliance" or faction == "horde") then
                self.eotsCarriedFlagFactionRecord = {
                    faction = faction,
                    time = now,
                    expires = now + 120,
                }
                if self.eotsCarriedFlagMotionByIndex then
                    wipe(self.eotsCarriedFlagMotionByIndex)
                end
            elseif cleared then
                self.eotsCarriedFlagFactionRecord = nil
                if self.eotsCarriedFlagMotionByIndex then
                    wipe(self.eotsCarriedFlagMotionByIndex)
                end
            end
        end

        if IsCaptureTheFlagMap(mapID) then
            -- WSG/Twin Peaks-style CTF maps need the faction of the FLAG OBJECT
            -- being carried, not the carrier faction. This narrow receiver stores
            -- only "The Alliance/Horde flag" state; player names are ignored.
            if self.RecordCTFFlagObjectFactionMessage then
                self:RecordCTFFlagObjectFactionMessage(mapID, flagObjectFaction, taken, dropped, returnedOrCaptured, now)
            end

            if cleared and self.ClearFlagCarrierTrails then
                self:ClearFlagCarrierTrails()
            end
        elseif faction and taken then
            self.carriedObjectiveFactionMessages[cacheKey] = {
                faction = faction,
                expires = now + 45,
            }
        elseif cleared then
            self.carriedObjectiveFactionMessages[cacheKey] = nil
            if self.ClearFlagCarrierTrails then
                self:ClearFlagCarrierTrails()
            end
        end
    end

    local isLosingControl = ObjectiveMessageIsLosingControl(messageKey)
    local isContested = ObjectiveMessageIsContested(messageKey)
    local isStable = ObjectiveMessageIsStable(messageKey)
    local eotsUncontrolledTransition = tonumber(mapID) == 210 and isLosingControl
    local blitzUncapNeutralTransition = IsBlitzUncapNeutralTransition(self, mapID, isLosingControl)
    local uncontrolledTransition = eotsUncontrolledTransition or blitzUncapNeutralTransition
    local uncontrolledState = eotsUncontrolledTransition and "uncontrolled" or "neutral"
    local losingFaction
    local matched = false
    local pulseShown = false
    local captureTimerHandled = false

    -- Save the definitive announcement independently of the current POI list.
    -- In AB the chat event can precede the POI transition, and POI identities
    -- can also change between neutral and contested states. The next refresh
    -- matches this message back to the objective by canonical alias/name.
    if isContested or isStable then
        if not faction then
            if messageKey:find("alliance", 1, true) then
                faction = "alliance"
            elseif messageKey:find("horde", 1, true) then
                faction = "horde"
            end
        end

        -- In normal Eye of the Storm, "lost control" means the tower becomes
        -- uncontrolled/neutral. Do not flip it into the opposite faction's
        -- contested texture. Other maps keep the older assault interpretation.
        if isLosingControl and faction then
            losingFaction = faction
            if uncontrolledTransition then
                faction = nil
            else
                faction = GetOpposingFaction(faction)
            end
        end

        local cacheKey = GetStationaryMessageCacheKey(mapID)
        local messages = self.stationaryObjectiveMessages[cacheKey]
        if not messages then
            messages = {}
            self.stationaryObjectiveMessages[cacheKey] = messages
        end
        messages[#messages + 1] = {
            messageKey = messageKey,
            faction = faction,
            losingFaction = losingFaction,
            uncontrolled = uncontrolledTransition and true or false,
            contested = (isContested and not uncontrolledTransition) and true or false,
            stable = isStable and true or false,
            expires = (type(GetTime) == "function" and GetTime() or 0) + 120,
        }
        while #messages > 24 do table.remove(messages, 1) end
    end

    if C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo then
        local apiMapID = ResolveObjectiveAPIMapID(mapID)
        for _, poiID in ipairs(GetAreaPOIIDs(mapID)) do
            local ok, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, apiMapID, poiID)
            if ok and type(info) == "table" then
                if ObjectiveMessageMatchesPOI(mapID, messageKey, poiID, info) then
                    local record = self:GetStationaryObjectiveStateRecord(mapID, poiID, info)
                    if record then
                        if uncontrolledTransition then
                            record.overrideState = nil
                            record.overrideExpires = nil
                            record.forcedState = uncontrolledState
                            record.forcedStateExpires = nil
                            record.stableState = uncontrolledState
                            record.stableSignature = GetObjectiveVisualSignature(info)
                        elseif faction and isContested then
                            record.forcedState = nil
                            record.forcedStateExpires = nil
                            record.overrideState = faction
                            record.overrideExpires = (type(GetTime) == "function" and GetTime() or 0) + 90
                        elseif faction and isStable then
                            record.overrideState = nil
                            record.overrideExpires = nil
                            record.forcedState = nil
                            record.forcedStateExpires = nil
                            record.stableState = faction
                            record.stableSignature = GetObjectiveVisualSignature(info)
                        elseif not faction then
                            record.overrideState = nil
                            record.overrideExpires = nil
                        else
                            -- Locale/build fallback: a faction message that changes
                            -- away from the currently reported owner is an assault.
                            local explicit = NormalizeObjectiveStates(InferStationaryObjectiveState(info, false))[1]
                            if faction and explicit ~= faction then
                                record.overrideState = faction
                                record.overrideExpires = (type(GetTime) == "function" and GetTime() or 0) + 90
                            end
                        end
                        matched = true

                        -- Play from the battleground announcement, not from the
                        -- periodic POI refresh. This guarantees one pulse for the
                        -- actual assault/capture and none on map load, zoom, pan,
                        -- texture replacement, or ordinary provider refreshes.
                        if info.position and type(info.position.GetXY) == "function" then
                            local pulseX, pulseY = info.position:GetXY()
                            if pulseX and pulseY then
                                if not captureTimerHandled then
                                    if faction and isContested and not uncontrolledTransition then
                                        if self.StopObjectiveBlitzUncapTimer then
                                            self:StopObjectiveBlitzUncapTimer(
                                                mapID,
                                                poiID,
                                                info,
                                                pulseX,
                                                pulseY
                                            )
                                        end
                                        captureTimerHandled = self:StartObjectiveCaptureTimer(
                                            mapID,
                                            poiID,
                                            info,
                                            pulseX,
                                            pulseY,
                                            faction
                                        )
                                    elseif isStable then
                                        self:StopObjectiveCaptureTimer(
                                            mapID,
                                            poiID,
                                            info,
                                            pulseX,
                                            pulseY
                                        )
                                        if faction and self.StartObjectiveBlitzUncapTimer then
                                            self:StartObjectiveBlitzUncapTimer(
                                                mapID,
                                                poiID,
                                                info,
                                                pulseX,
                                                pulseY,
                                                faction
                                            )
                                        elseif self.StopObjectiveBlitzUncapTimer then
                                            self:StopObjectiveBlitzUncapTimer(
                                                mapID,
                                                poiID,
                                                info,
                                                pulseX,
                                                pulseY
                                            )
                                        end
                                        captureTimerHandled = true
                                    elseif self.StopObjectiveBlitzUncapTimer and (isLosingControl or not faction) then
                                        self:StopObjectiveBlitzUncapTimer(
                                            mapID,
                                            poiID,
                                            info,
                                            pulseX,
                                            pulseY,
                                            uncontrolledTransition
                                        )
                                        if uncontrolledTransition and self.ForceStationaryObjectiveState then
                                            self:ForceStationaryObjectiveState(
                                                mapID,
                                                poiID,
                                                info,
                                                uncontrolledState
                                            )
                                        end
                                        captureTimerHandled = uncontrolledTransition and true or captureTimerHandled
                                    end
                                end

                                if not pulseShown and faction and isStable then
                                    pulseShown = self:ShowObjectiveEventPulse(
                                        pulseX,
                                        pulseY,
                                        faction,
                                        messageKey,
                                        "capture"
                                    )
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if (matched or isContested or isStable)
        and BattleMaps.MapFrame.frame and BattleMaps.MapFrame.frame:IsShown() then
        self:RefreshPOIs()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.15, function()
                if BattleMaps.MapFrame.frame and BattleMaps.MapFrame.frame:IsShown() then
                    self:RefreshPOIs()
                end
            end)
        end
    end
end

-- Custom objective layout lookup moved to ObjectiveRules.lua.

local function SetFileTexture(pin, texturePath, frameWidth, frameHeight, layout, textureWidth, textureHeight)
    if not pin or not pin.texture or not texturePath then return false end
    frameWidth = tonumber(frameWidth) or 24
    frameHeight = tonumber(frameHeight) or frameWidth
    textureWidth = tonumber(textureWidth) or frameWidth
    textureHeight = tonumber(textureHeight) or textureWidth

    local offsetX, offsetY = 0, 0
    if type(layout) == "table" then
        -- Layout offsets are authored against a 32 px visible objective icon.
        -- Scale them from the rendered texture, not from the larger hit frame.
        offsetX = (tonumber(layout.offsetX) or 0) * (textureWidth / 32)
        offsetY = (tonumber(layout.offsetY) or 0) * (textureHeight / 32)
    end

    pin:SetSize(frameWidth, frameHeight)
    pin.texture:ClearAllPoints()
    pin.texture:SetPoint("CENTER", pin, "CENTER", offsetX, offsetY)
    pin.texture:SetSize(textureWidth, textureHeight)
    pin.texture:SetTexture(texturePath)
    pin.texture:SetTexCoord(0, 1, 0, 1)
    pin.texture:SetVertexColor(1, 1, 1, 1)
    pin.texture:SetRotation(0)
    return true
end

function Pins:CustomTextureExists(texturePath)
    if type(texturePath) ~= "string" or texturePath == "" then return false end
    local cached = self.customTextureAvailability[texturePath]
    if cached ~= nil then return cached == true end

    -- Texture:SetTexture() is not a valid existence test: the client can return
    -- success even when a path is missing. GetFileIDFromPath() resolves both
    -- Blizzard files and addon-local files; local addon files use negative IDs.
    local exists = false
    if type(GetFileIDFromPath) == "function" then
        local lookupPath = texturePath:gsub("\\", "/")
        local ok, fileID = pcall(GetFileIDFromPath, lookupPath)
        fileID = ok and tonumber(fileID) or nil
        exists = fileID ~= nil and fileID ~= 0
    end

    self.customTextureAvailability[texturePath] = exists
    return exists
end

function Pins:RecordObjectiveTextureKeys(mapID, category, keys, state)
    mapID = tonumber(mapID)
    if not mapID or type(category) ~= "string" then return end
    local mapBucket = self.objectiveTextureKeys[mapID]
    if not mapBucket then
        mapBucket = {}
        self.objectiveTextureKeys[mapID] = mapBucket
    end
    local categoryBucket = mapBucket[category]
    if not categoryBucket then
        categoryBucket = { keys = {}, states = {} }
        mapBucket[category] = categoryBucket
    end
    for _, key in ipairs(keys or {}) do
        if key and key ~= "objective" then categoryBucket.keys[key] = true end
    end
    if type(GetObjectiveAliasKeys) == "function" then
        for _, alias in ipairs(GetObjectiveAliasKeys(mapID, keys) or {}) do
            if alias and alias ~= "objective" then categoryBucket.keys[alias] = true end
        end
    end
    for _, stateName in ipairs(NormalizeObjectiveStates(state)) do
        categoryBucket.states[stateName] = true
    end
end

-- Objective texture folder resolution moved to ObjectiveRules.lua.

local function GetCanonicalObjectiveKey(mapID, normalizedKeys)
    local shortKeys = GetObjectiveShortKeys(mapID, normalizedKeys)
    if #shortKeys > 0 then return shortKeys[1] end

    if type(GetObjectiveAliasKeys) == "function" then
        local aliasKeys = GetObjectiveAliasKeys(mapID, normalizedKeys)
        if #aliasKeys > 0 then return aliasKeys[1] end
    end

    -- Maps without a registered abbreviation use one deterministic descriptive
    -- key. Generic and index keys are considered only when no named key exists.
    for _, key in ipairs(normalizedKeys or {}) do
        if key ~= "objective" and key ~= "stationary" and key ~= "carried"
            and key ~= "vehicle" and not key:match("^index_%d+$") then
            return key
        end
    end
    for _, key in ipairs(normalizedKeys or {}) do
        if key:match("^index_%d+$") then return key end
    end
    return nil
end

local function GetCanonicalObjectiveStem(mapID, category, normalizedKeys, state)
    local key = GetCanonicalObjectiveKey(mapID, normalizedKeys)
    if not key then return nil end

    local suffix, canonicalState = GetCanonicalStateSuffix(state)
    if canonicalState == "contested" then
        return nil -- unknown assaulting faction: use Blizzard artwork
    end

    if suffix then return key .. "_" .. suffix end

    -- Carried objectives and vehicles do not always expose an ownership state.
    -- Their single canonical texture is the key itself. Stationary objectives
    -- require an exact state suffix so a generic custom file can never mask a
    -- neutral or contested state.
    if category ~= "stationary" then return key end
    return nil
end

local function ProbeObjectiveTexturePath(pins, folderID, category, stem)
    if not pins or not folderID or not category or not stem then return nil end
    local path = OBJECTIVE_TEXTURE_ROOT .. tostring(folderID) .. "\\" .. category .. "\\" .. stem .. ".tga"
    if pins:CustomTextureExists(path) then
        return path, stem
    end
    return nil
end

local function FindSoleVehicleVariantTexture(pins, folderID, category, key)
    -- Some vehicle APIs, especially Silvershard Mines carts, can expose a live
    -- cart without a reliable Alliance/Horde/neutral state. If the author has
    -- provided exactly one state-specific vehicle file, allow that as the
    -- fallback instead of forcing Blizzard's cart artwork. If multiple variants
    -- exist, do not guess.
    local matches = {}
    for _, suffix in ipairs({ "H", "A", "N" }) do
        local path, stem = ProbeObjectiveTexturePath(pins, folderID, category, key .. "_" .. suffix)
        if path then
            matches[#matches + 1] = { path = path, stem = stem }
        end
    end

    if #matches == 1 then
        return matches[1].path, matches[1].stem
    end
    return nil
end

function Pins:FindObjectiveTexture(mapID, category, keys, state)
    mapID = tonumber(mapID)
    if not mapID or type(category) ~= "string" then return nil end
    category = NormalizeObjectiveKey(category)
    if category == "" then return nil end

    local normalizedKeys, seen = {}, {}
    for _, value in ipairs(keys or {}) do
        AddUniqueObjectiveKey(normalizedKeys, seen, value)
    end
    self:RecordObjectiveTextureKeys(mapID, category, normalizedKeys, state)

    local folderID = GetObjectiveTextureFolderID(mapID)
    local stem = GetCanonicalObjectiveStem(mapID, category, normalizedKeys, state)
    if stem then
        local path, selectedStem = ProbeObjectiveTexturePath(self, folderID, category, stem)
        if path then return path, selectedStem end
    end

    if category == "vehicle" and not GetCanonicalStateSuffix(state) then
        local key = GetCanonicalObjectiveKey(mapID, normalizedKeys)
        if key then
            return FindSoleVehicleVariantTexture(self, folderID, category, key)
        end
    end

    return nil
end

function Pins:PrintObjectiveTextureKeys(mapID)
    mapID = tonumber(mapID)
    if not mapID then
        BattleMaps.Chat("No battleground is currently selected.")
        return
    end

    local mapName = BattleMaps.GetBattlegroundNameForConfig
        and BattleMaps.GetBattlegroundNameForConfig(mapID)
        or (BattleMaps.Battlegrounds and BattleMaps.Battlegrounds:GetName(mapID))
        or tostring(mapID)
    BattleMaps.Chat("Objective texture keys for " .. tostring(mapName) .. " (map " .. tostring(mapID) .. "):")

    local records = self.objectiveTextureKeys[mapID] or {}
    local foundAny = false
    for _, category in ipairs({ "stationary", "carried", "vehicle" }) do
        local bucket = records[category]
        local keys = {}
        if bucket and bucket.keys then
            for key in pairs(bucket.keys) do keys[#keys + 1] = key end
            table.sort(keys)
        end

        if #keys > 0 then
            foundAny = true
            local shown = {}
            for index = 1, math.min(#keys, 12) do shown[#shown + 1] = keys[index] .. ".tga" end
            local suffix = #keys > #shown and " ..." or ""
            BattleMaps.Chat(category .. ": " .. table.concat(shown, ", ") .. suffix)
        end
    end

    if not foundAny then
        BattleMaps.Chat("No objective keys have been observed yet. Open this map in Edit mode or run the command during the battleground.")
    end
    local folderID = GetObjectiveTextureFolderID(mapID)
    BattleMaps.Chat("Folder: Interface\\AddOns\\BattleMaps\\Media\\Objectives\\" .. tostring(folderID) .. "\\<category>\\")
    BattleMaps.Chat("Canonical stationary files: <KEY>_N, <KEY>_A, <KEY>_H, <KEY>_A_C, <KEY>_H_C. Missing exact files use Blizzard artwork.")
    if IsTempleOfKotmoguMap and IsTempleOfKotmoguMap(mapID) then
        BattleMaps.Chat("Kotmogu carried orbs: carried\\purple_orb.tga, green_orb.tga, orange_orb.tga, blue_orb.tga.")
    end
end


local function GetCarriedObjectiveKey(mapID)
    local mapName = BattleMaps.GetBattlegroundNameForConfig
        and BattleMaps.GetBattlegroundNameForConfig(mapID)
        or (BattleMaps.Battlegrounds and BattleMaps.Battlegrounds:GetName(mapID))
        or ""
    local normalized = NormalizeObjectiveKey(mapName)
    if tonumber(mapID) == 210 or normalized:find("eye_of_the_storm", 1, true) then
        return "netherstorm_flag"
    end
    if normalized:find("kotmogu", 1, true) then return "orb" end
    return "flag"
end

local function GetStableFactionFromState(state)
    for _, value in ipairs(NormalizeObjectiveStates(state)) do
        if value == "alliance" or value == "contested_alliance" or value == "alliance_contested" then
            return "alliance"
        elseif value == "horde" or value == "contested_horde" or value == "horde_contested" then
            return "horde"
        end
    end
    return nil
end

InferCarriedFlagFactionFromText = function(...)
    local combined = {}
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil then
            combined[#combined + 1] = NormalizeObjectiveKey(value)
        end
    end
    local text = table.concat(combined, "_")
    if text == "" then return nil end

    -- WSG/Twin Peaks flag APIs may expose either direct faction names
    -- (AllianceFlag/HordeFlag), colour names, or battleground-specific faction
    -- tokens such as Silverwing/Warsong. Treat these as the flag object's
    -- faction, not the carrier's faction.
    local alliance = text:find("alliance", 1, true)
        or text:find("blue", 1, true)
        or text:find("silverwing", 1, true)
        or text:find("wildhammer", 1, true)
        or text:find("stormpike", 1, true)
    local horde = text:find("horde", 1, true)
        or text:find("red", 1, true)
        or text:find("warsong", 1, true)
        or text:find("dragonmaw", 1, true)
        or text:find("frostwolf", 1, true)

    if alliance and not horde then return "alliance" end
    if horde and not alliance then return "horde" end
    return nil
end

local function InferCTFFlagObjectFactionFromToken(...)
    local combined = {}
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil then
            combined[#combined + 1] = NormalizeObjectiveKey(value)
        end
    end
    local text = table.concat(combined, "_")
    if text == "" then return nil end

    -- CTF maps need the flag object's faction, not the carrier's faction. The
    -- older GetBattlefieldFlagPosition token is the most reliable source when
    -- available because it is usually AllianceFlag/HordeFlag.
    local alliance = text:find("alliance_flag", 1, true)
        or text:find("allianceflag", 1, true)
        or text:find("silverwing", 1, true)
        or text:find("wildhammer", 1, true)
        or text:find("stormpike", 1, true)
    local horde = text:find("horde_flag", 1, true)
        or text:find("hordeflag", 1, true)
        or text:find("warsong", 1, true)
        or text:find("dragonmaw", 1, true)
        or text:find("frostwolf", 1, true)

    if alliance and not horde then return "alliance" end
    if horde and not alliance then return "horde" end
    return nil
end

local function GetCTFFlagFactionCacheKey(mapID, index)
    return tostring(tonumber(mapID) or mapID or "unknown") .. "/" .. tostring(tonumber(index) or index or 0)
end

local function GetFallbackCTFFlagFactionByIndex(mapID, index)
    if not IsCaptureTheFlagMap(mapID) then return nil end

    -- The C_PvP texture can be factionless, or worse, can temporarily look like
    -- the same faction for both flags. Keep CTF flags split by their stable API
    -- slot so WSG/Twin Peaks/Deephaul always render one Alliance flag and one
    -- Horde flag when both flag positions are present.
    index = tonumber(index)
    if index == 1 then return "alliance" end
    if index == 2 then return "horde" end
    return nil
end

local function GetObjectiveFactionColor(faction)
    faction = NormalizeObjectiveKey(faction)
    local color = faction == "alliance" and BattleMaps.COLORS.alliance
        or faction == "horde" and BattleMaps.COLORS.horde
        or BattleMaps.COLORS.neutral
    return color[1] or 1, color[2] or 1, color[3] or 1
end

local function GetObjectiveSettings(mapID)
    mapID = tonumber(mapID)
        or tonumber(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    if BattleMaps.Database and BattleMaps.Database.GetBasePinConfig then
        return BattleMaps.Database:GetBasePinConfig(mapID)
    end
    return BattleMaps.Database and BattleMaps.Database:Get() or nil
end

local function GetTimerSettings(mapID)
    mapID = tonumber(mapID)
        or tonumber(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    if BattleMaps.Database and BattleMaps.Database.GetBaseTimerConfig then
        return BattleMaps.Database:GetBaseTimerConfig(mapID)
    end
    return BattleMaps.Database and BattleMaps.Database:Get() or nil
end

-- Carried-objective flash overlays are implemented in CarriedObjectives.lua.
local function GetCarriedObjectiveTexture(pins, mapID, index, texture, explicitState)
    local carriedKey = GetCarriedObjectiveKey(mapID)
    local isKotmogu = IsTempleOfKotmoguMap and IsTempleOfKotmoguMap(mapID)

    -- Kotmogu orb colour is the objective identity. It is not a faction or
    -- ownership state, so carried orb files are intentionally state-less:
    -- 417\carried\purple_orb.tga, green_orb.tga, orange_orb.tga, blue_orb.tga.
    -- The index_<n> key is mapped to the readable colour names by
    -- ObjectiveRules.lua, then falls back to generic carried/orb.tga.
    local state = isKotmogu and nil or (explicitState or InferObjectiveState(texture))
    local keySets = {
        { "index_" .. tostring(index), carriedKey, "objective" },
        { carriedKey, "objective" },
    }

    -- EotS uses NF as the canonical map-specific name, but allow the simpler
    -- generic carried/flag_A.tga, flag_H.tga, and flag.tga files as fallbacks.
    -- Kotmogu deliberately does not fall back to flag.tga; its generic fallback
    -- is carried/orb.tga.
    if not isKotmogu and carriedKey ~= "flag" then
        keySets[#keySets + 1] = { "flag", "objective" }
    end
    keySets[#keySets + 1] = { "objective" }

    if state then
        for _, keys in ipairs(keySets) do
            local path = pins:FindObjectiveTexture(mapID, "carried", keys, state)
            if path then return path end
        end
    end

    for _, keys in ipairs(keySets) do
        local path = pins:FindObjectiveTexture(mapID, "carried", keys, nil)
        if path then return path end
    end
    return nil
end

local function GetVehicleObjectiveKey(mapID)
    mapID = tonumber(mapID)
    local mapName = BattleMaps.GetBattlegroundNameForConfig
        and BattleMaps.GetBattlegroundNameForConfig(mapID)
        or (BattleMaps.Battlegrounds and BattleMaps.Battlegrounds:GetName(mapID))
        or ""
    local normalized = NormalizeObjectiveKey(mapName)
    if mapID == 423 or mapID == 727
        or normalized:find("silvershard", 1, true)
        or normalized:find("deephaul", 1, true) then
        return "mine_cart"
    end
    return "vehicle"
end

local function IsEyeOfTheStormMapID(mapID)
    mapID = tonumber(mapID)
    if mapID == 210 then return true end
    local name = BattleMaps.GetBattlegroundNameForConfig
        and BattleMaps.GetBattlegroundNameForConfig(mapID)
        or (BattleMaps.Battlegrounds and BattleMaps.Battlegrounds.GetName
            and BattleMaps.Battlegrounds:GetName(mapID))
        or ""
    return NormalizeObjectiveKey(name):find("eyeofthestorm", 1, true) ~= nil
end

-- Objective tooltip helpers are implemented in ObjectiveTimers.lua.

local function CreateTexturePin(parent, width, height)
    local pin = CreateFrame("Frame", nil, parent)
    pin:SetSize(width or 22, height or width or 22)

    local texture = pin:CreateTexture(nil, "ARTWORK")
    pin.texture = texture
    texture:SetAllPoints()

    if Pins.InstallTooltip then
        Pins:InstallTooltip(pin)
    end
    return pin
end

-- Area POI ID collection moved to ObjectiveRules.lua.

function Pins:PrintObjectiveTextureDebug(mapID)
    mapID = tonumber(mapID)
    if not mapID then
        BattleMaps.Chat("No battleground is currently selected.")
        return
    end

    local mapNameKey = GetObjectiveMapNameKey(mapID)
    BattleMaps.Chat("Objective texture debug for map " .. tostring(mapID)
        .. (mapNameKey ~= "" and (" (" .. mapNameKey .. ")") or "") .. ":")

    if not C_AreaPoiInfo or not C_AreaPoiInfo.GetAreaPOIInfo then
        BattleMaps.Chat("C_AreaPoiInfo.GetAreaPOIInfo is unavailable.")
    else
        local apiMapID = ResolveObjectiveAPIMapID(mapID)
        local poiIDs = GetAreaPOIIDs(mapID)
        if type(poiIDs) ~= "table" or #poiIDs == 0 then
            BattleMaps.Chat("No Area POIs were returned for this map.")
        else
            for _, poiID in ipairs(poiIDs) do
                local ok, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, apiMapID, poiID)
                if ok and type(info) == "table" then
                    local keys = BuildObjectiveKeys(info, poiID, "stationary")
                    local states = NormalizeObjectiveStates(self:ResolveStationaryObjectiveState(mapID, poiID, info))
                    local shortKeys = GetObjectiveShortKeys(mapID, keys)
                    local path, stem = self:FindObjectiveTexture(mapID, "stationary", keys, states)
                    BattleMaps.Chat(string.format(
                        "POI %s | %s | desc=%s | atlas=%s | textureIndex=%s | glow=%s | factionID=%s | aliases=%s | state=%s | selected=%s",
                        tostring(poiID),
                        tostring(info.name or "?"),
                        tostring(info.description or "-"),
                        tostring(info.atlasName or info.atlas or "-"),
                        tostring(info.textureIndex or "-"),
                        tostring(info.shouldGlow),
                        tostring(info.factionID or "-"),
                        #shortKeys > 0 and table.concat(shortKeys, ",") or "-",
                        #states > 0 and table.concat(states, ",") or "-",
                        tostring(stem or path or "Blizzard")
                    ))
                end
            end
        end
    end

    if C_VignetteInfo and C_VignetteInfo.GetVignettes
        and C_VignetteInfo.GetVignetteInfo and C_VignetteInfo.GetVignettePosition then
        local okVignettes, vignetteGUIDs = pcall(C_VignetteInfo.GetVignettes)
        local positioned = 0
        if okVignettes and type(vignetteGUIDs) == "table" then
            for _, vignetteGUID in ipairs(vignetteGUIDs) do
                local okInfo, info = pcall(C_VignetteInfo.GetVignetteInfo, vignetteGUID)
                if okInfo and type(info) == "table" then
                    local position, sourceMapID
                    if type(self.GetVignettePositionForMap) == "function" then
                        position, sourceMapID = self:GetVignettePositionForMap(vignetteGUID, mapID)
                    else
                        local fallbackMapID = BattleMaps.GetBattlegroundUIMapID
                            and BattleMaps.GetBattlegroundUIMapID(mapID, true) or mapID
                        local okPosition, result = pcall(C_VignetteInfo.GetVignettePosition, vignetteGUID, fallbackMapID)
                        if okPosition then position, sourceMapID = result, fallbackMapID end
                    end

                    if position and type(position.GetXY) == "function" then
                        local xyOK, x, y = pcall(position.GetXY, position)
                        if xyOK and x and y then
                            positioned = positioned + 1
                            local sourceIndex = vignetteGUID
                            local keys = BuildObjectiveKeys(info, sourceIndex, "stationary")
                            local states = NormalizeObjectiveStates(self:ResolveStationaryObjectiveState(mapID, sourceIndex, info))
                            local path, stem = self:FindObjectiveTexture(mapID, "stationary", keys, states)
                            BattleMaps.Chat(string.format(
                                "Vignette %s | %s | map=%s | atlas=%s | world=%s dead=%s fog=%s unique=%s | xy=%.3f,%.3f | state=%s | selected=%s",
                                tostring(info.vignetteID or "?"),
                                tostring(info.name or "?"),
                                tostring(sourceMapID or "?"),
                                tostring(info.atlasName or "-"),
                                tostring(info.onWorldMap),
                                tostring(info.isDead),
                                tostring(info.inFogOfWar),
                                tostring(info.isUnique),
                                tonumber(x) or 0, tonumber(y) or 0,
                                #states > 0 and table.concat(states, ",") or "-",
                                tostring(stem or path or "Blizzard")
                            ))
                        end
                    end
                end
            end
        end
        if positioned == 0 then
            BattleMaps.Chat("No positioned Vignettes were returned for this map.")
        end
    end

    if C_PvP and C_PvP.GetBattlefieldVehicles and C_PvP.GetBattlefieldVehicleInfo then
        local vehicleMapID = BattleMaps.GetBattlegroundUIMapID
            and BattleMaps.GetBattlegroundUIMapID(mapID, true)
            or mapID
        local okVehicles, vehicles = pcall(C_PvP.GetBattlefieldVehicles, vehicleMapID)
        if okVehicles and type(vehicles) == "table" then
            for index = 1, #vehicles do
                local okVehicle, info = pcall(C_PvP.GetBattlefieldVehicleInfo, index, vehicleMapID)
                if okVehicle and type(info) == "table" then
                    local preferred = GetVehicleObjectiveKey(mapID)
                    local keys = BuildObjectiveKeys(info, index, preferred)
                    local states = NormalizeObjectiveStates(InferObjectiveState(
                        info.name,
                        info.atlas,
                        info.atlasName,
                        info.textureKit,
                        info.uiTextureKit,
                        info.faction,
                        info.team,
                        info.texture
                    ))
                    local path, stem = self:FindObjectiveTexture(mapID, "vehicle", keys, states)
                    BattleMaps.Chat(string.format(
                        "Vehicle %s | %s | atlas=%s | faction=%s | team=%s | alive=%s | player=%s | state=%s | selected=%s",
                        tostring(index),
                        tostring(info.name or "?"),
                        tostring(info.atlasName or info.atlas or "-"),
                        tostring(info.faction or info.factionID or "-"),
                        tostring(info.team or "-"),
                        tostring(info.isAlive),
                        tostring(info.isPlayer),
                        #states > 0 and table.concat(states, ",") or "-",
                        tostring(stem or path or "Blizzard")
                    ))
                end
            end
        end
    end
end


local function SetPOITexture(pin, info, pinScale, mapID, sourceIndex)
    local texture = pin.texture
    pinScale = BattleMaps.Clamp(tonumber(pinScale) or 1, 0.5, 5.0)

    texture:SetRotation(0)
    texture:SetVertexColor(1, 1, 1, 1)
    texture:SetTexCoord(0, 1, 0, 1)

    local customKeys = BuildObjectiveKeys(info, sourceIndex, "stationary")
    local customState = info.forceState or Pins:ResolveStationaryObjectiveState(mapID, sourceIndex, info)
    local _, canonicalState = GetCanonicalStateSuffix(customState)
    pin.BattleMapsStationaryObjectiveState = canonicalState
    local customPath, customStem = Pins:FindObjectiveTexture(mapID, "stationary", customKeys, customState)
    if customPath then
        local layout = GetCustomObjectiveLayout(mapID, "stationary", customStem)
        local frameSize = 32 * pinScale
        local visualSize = CUSTOM_AREA_POI_VISUAL_SIZE * pinScale
        return SetFileTexture(pin, customPath, frameSize, frameSize, layout, visualSize, visualSize)
    end

    local atlasName = type(info.atlasName) == "string" and info.atlasName ~= "" and info.atlasName or nil
    if atlasName then
        local textureKit = info.textureKit or info.uiTextureKit
        if type(textureKit) == "string" and textureKit ~= "" then
            atlasName = textureKit .. "-" .. atlasName
        end

        texture:ClearAllPoints()
        texture:SetPoint("CENTER", pin, "CENTER")

        local ok = pcall(texture.SetAtlas, texture, atlasName, true)
        if ok and (not texture.GetAtlas or texture:GetAtlas()) then
            local width, height = texture:GetSize()
            width = BattleMaps.Clamp(tonumber(width) or 22, 12, 48)
            height = BattleMaps.Clamp(tonumber(height) or 22, 12, 48)

            pin:SetSize(width * pinScale, height * pinScale)
            texture:SetSize(width * pinScale, height * pinScale)
            return true
        end
    end

    -- textureIndex is not a file ID. It selects a cell from Blizzard's
    -- Interface/Minimap/POIIcons sprite sheet.
    if type(info.textureIndex) == "number" and C_Minimap and C_Minimap.GetPOITextureCoords then
        local ok, x1, x2, y1, y2 = pcall(C_Minimap.GetPOITextureCoords, info.textureIndex)
        if ok and x1 and x2 and y1 and y2 then
            pin:SetSize(32 * pinScale, 32 * pinScale)
            texture:ClearAllPoints()
            texture:SetPoint("CENTER", pin, "CENTER")
            texture:SetSize(16 * pinScale, 16 * pinScale)
            texture:SetTexture("Interface\\Minimap\\POIIcons")
            texture:SetTexCoord(x1, x2, y1, y2)
            return true
        end
    end

    texture:SetTexture(nil)
    pin.BattleMapsStationaryObjectiveState = nil
    return false
end

-- Offline edit previews -------------------------------------------------------
-- Blizzard does not expose live battleground unit, flag, or vehicle positions
-- while the player is elsewhere. During an out-of-instance edit session,
-- BattleMaps therefore renders one representative marker for each configurable
-- Edit/test-mode preview pins are implemented in PreviewPins.lua.

-- Unit/player pin helpers are implemented in UnitPins.lua.

function Pins:Initialize(parent)
    self.parent = parent

    if self.InitializeUnitFrames then
        self:InitializeUnitFrames(parent)
    end

    -- Modern CHAT_MSG_PING reception is retired because its payload becomes
    -- secret during active PvP. Objective-event pulses are ordinary map frames,
    -- however, so they can be created up front and safely animated in combat.
    wipe(self.objectivePingFrames)
    for index = 1, PING_POOL_SIZE do
        local pulse = CreateTexturePin(parent, 22, 22)
        pulse:SetFrameLevel(parent:GetFrameLevel() + PING_FRAME_LEVEL_OFFSET)
        pulse:EnableMouse(false)

        pulse.echoRing = pulse:CreateTexture(nil, "BACKGROUND")
        pulse.echoRing:SetPoint("CENTER", pulse, "CENTER")
        pulse.echoRing:SetTexture(PING_RING_TEXTURE)
        pulse.echoRing:SetBlendMode("ADD")
        pulse.echoRing:SetVertexColor(1, 1, 1, 1)

        pulse.texture:ClearAllPoints()
        pulse.texture:SetPoint("CENTER", pulse, "CENTER")
        pulse.texture:SetTexture(PING_RING_TEXTURE)
        pulse.texture:SetBlendMode("BLEND")
        pulse.texture:SetVertexColor(1, 1, 1, 1)

        pulse.highlightRing = pulse:CreateTexture(nil, "OVERLAY")
        pulse.highlightRing:SetPoint("CENTER", pulse, "CENTER")
        pulse.highlightRing:SetTexture(PING_RING_TEXTURE)
        pulse.highlightRing:SetBlendMode("ADD")
        pulse.highlightRing:SetVertexColor(1, 1, 1, 1)

        pulse:Hide()
        self.objectivePingFrames[index] = pulse
    end

end

-- Carried-objective trail rendering is implemented in CarriedObjectives.lua.

function Pins:GetVehiclePin(index)
    local pin = self.vehiclePins[index]
    if not pin then
        pin = CreateTexturePin(self.parent, 24, 24)
        self.vehiclePins[index] = pin
    end
    return pin
end

-- Carried flag pin creation is implemented in CarriedObjectives.lua.

function Pins:GetPOIPin(index)
    local pin = self.poiPins[index]
    if not pin then
        pin = CreateTexturePin(self.parent, 22, 22)
        self:InstallObjectiveCaptureReportClick(pin)

        local glow = pin:CreateTexture(nil, "BACKGROUND")
        pin.glow = glow
        glow:SetPoint("TOPLEFT", -3, 3)
        glow:SetPoint("BOTTOMRIGHT", 3, -3)
        glow:SetColorTexture(1, 0.82, 0.22, 0.18)
        glow:Hide()

        if self.InstallObjectiveEventPulseTexture then
            self:InstallObjectiveEventPulseTexture(pin)
        end

        -- Capture timers use layered copies of the objective artwork rather
        -- than a generic cooldown wedge. The attacking faction's completed
        -- texture sits underneath, while a neutral copy above it is cropped
        -- over time to reveal the faction colour beneath.
        local captureBaseTexture = pin:CreateTexture(nil, "OVERLAY", nil, 4)
        pin.objectiveCaptureBaseTexture = captureBaseTexture
        captureBaseTexture:SetAlpha(1)
        captureBaseTexture:Hide()

        local captureFillTexture = pin:CreateTexture(nil, "OVERLAY", nil, 5)
        pin.objectiveCaptureFillTexture = captureFillTexture
        captureFillTexture:SetAlpha(1)
        captureFillTexture:Hide()

        -- Legacy helper layers retained for compatibility with earlier test
        -- builds. The current AB timer presentation uses only the base and
        -- fill textures, with the fill texture itself animated.
        local captureHoldTexture = pin:CreateTexture(nil, "OVERLAY", nil, 6)
        pin.objectiveCaptureHoldTexture = captureHoldTexture
        captureHoldTexture:SetAlpha(1)
        captureHoldTexture:Hide()

        local captureFlashTexture = pin:CreateTexture(nil, "OVERLAY", nil, 7)
        pin.objectiveCaptureFlashTexture = captureFlashTexture
        captureFlashTexture:SetBlendMode("ADD")
        captureFlashTexture:SetVertexColor(1, 1, 1, 1)
        captureFlashTexture:SetAlpha(0)
        captureFlashTexture:Hide()

        if self.EnsureObjectiveCaptureTimerTextures then
            self:EnsureObjectiveCaptureTimerTextures(pin)
        end
        self.poiPins[index] = pin
    end
    return pin
end

function Pins:GetScenarioPin(index)
    local pin = self.scenarioPins[index]
    if not pin then
        pin = CreateTexturePin(self.parent, 24, 24)
        self.scenarioPins[index] = pin
    end
    return pin
end

function Pins:GetVignettePin(index)
    local pin = self.vignettePins[index]
    if not pin then
        pin = CreateTexturePin(self.parent, 22, 22)
        self.vignettePins[index] = pin
    end
    return pin
end

function Pins:Place(pin, x, y)
    local mapFrame = BattleMaps.MapFrame
    if not x or not y or not mapFrame:IsMapPointVisible(x, y, 40) then
        pin:Hide()
        return
    end

    local screenX, screenY = mapFrame:MapToViewport(x, y)
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", mapFrame.viewport, "TOPLEFT", screenX, -screenY)
    pin.mapX, pin.mapY = x, y
    pin:Show()
end


local function NormalizePingSearchText(value)
    if type(value) ~= "string" then return nil end

    -- Remove common chat formatting without attempting to inspect protected
    -- hyperlinks or other unavailable values.
    value = value:gsub("|c%x%x%x%x%x%x%x%x", "")
    value = value:gsub("|r", "")
    value = value:gsub("|T.-|t", "")
    value = value:gsub("|H.-|h(.-)|h", "%1")
    value = value:lower():match("^%s*(.-)%s*$")
    if value == "" then return nil end
    return value
end

function Pins:GetPingColor(pingType)
    local color = PING_COLORS[pingType] or PING_COLORS.Generic
    return color[1], color[2], color[3]
end

-- Objective event pulse and Deephaul synthetic objective helpers are implemented in ObjectivePins.lua.

function Pins:FindObjectiveByName(targetName)
    local wanted = NormalizePingSearchText(targetName)
    if not wanted or #wanted < 3 then return nil end

    local collections = {
        self.poiPins,
        self.flagPins,
        self.vehiclePins,
        self.scenarioPins,
        self.vignettePins,
    }

    local partialMatch
    for _, collection in ipairs(collections) do
        for _, pin in ipairs(collection) do
            if pin and pin:IsShown() and pin.mapX and pin.mapY then
                local title = NormalizePingSearchText(pin.tooltipTitle)
                if title then
                    if title == wanted then
                        return pin
                    end
                    if wanted:find(title, 1, true) or title:find(wanted, 1, true) then
                        partialMatch = partialMatch or pin
                    end
                end
            end
        end
    end

    return partialMatch
end

function Pins:UpdatePingUnitFrameFull(frame)
    -- Restricted battleground unit positions are most reliable when the unit
    -- list already exists before a ping is received. Keep every friendly unit
    -- registered in each pooled frame with alpha 0, then reveal only the
    -- selected unit through SetUnitColor() during the pulse.
    frame:ClearUnits()
    frame.trackedUnits = frame.trackedUnits or {}
    wipe(frame.trackedUnits)

    local function AddTrackedUnit(unit)
        if not unit or not UnitExists(unit) then return end
        frame:AddUnit(
            unit,
            PING_RING_TEXTURE,
            PING_RING_SIZE,
            PING_RING_SIZE,
            1, 1, 1, 0,
            PING_PIN_SUBLEVEL,
            false
        )
        frame.trackedUnits[unit] = true
    end

    AddTrackedUnit("player")

    local memberCount, unitBase = frame:GetMemberCountAndUnitTokenPrefix()
    for index = 1, memberCount do
        local unit = unitBase .. index
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            AddTrackedUnit(unit)
        end
    end

    frame:FinalizeUnits()
    frame.needsFullUpdate = false
end

function Pins:UpdatePingUnitFramePeriodic(frame)
    if frame.active and frame.unitToken and frame.trackedUnits
        and frame.trackedUnits[frame.unitToken] and UnitExists(frame.unitToken) then
        frame:SetUnitColor(
            frame.unitToken,
            frame.pingR or 1,
            frame.pingG or 1,
            frame.pingB or 1,
            frame.currentAlpha or 0.95
        )
    end
end

function Pins:DeactivateUnitPing(frame)
    if not frame then return end

    -- Do not clear the preloaded unit list. Removing and re-adding units on
    -- demand is the part that becomes unreliable while a battleground is
    -- active. Only make the selected unit transparent.
    if frame.unitToken and frame.trackedUnits and frame.trackedUnits[frame.unitToken] then
        pcall(frame.SetUnitColor, frame, frame.unitToken, 1, 1, 1, 0)
    end

    frame.active = false
    frame.unitToken = nil
    frame.startedAt = nil
    frame.expiresAt = nil
    frame.currentAlpha = nil

    -- A legacy/older build may have left this pool member hidden. Repair that
    -- state only when secure frame changes are currently allowed.
    if not frame:IsShown() and not InCombatLockdown() then
        frame:Show()
    end
end

function Pins:DeactivateObjectivePing(frame)
    if not frame then return end
    frame.active = false
    frame.mapX = nil
    frame.mapY = nil
    frame.startedAt = nil
    frame.expiresAt = nil
    frame.pulseDuration = nil
    frame.pulseKind = nil
    frame.pulseBaseSize = nil
    if frame.echoRing then frame.echoRing:SetAlpha(0) end
    if frame.texture then frame.texture:SetAlpha(0) end
    if frame.highlightRing then frame.highlightRing:SetAlpha(0) end
    frame:Hide()
end

function Pins:StopAllPings()
    for _, frame in ipairs(self.unitPingFrames) do
        self:DeactivateUnitPing(frame)
    end
    for _, frame in ipairs(self.objectivePingFrames) do
        self:DeactivateObjectivePing(frame)
    end
    if self.StopAllObjectiveTexturePulses then
        self:StopAllObjectiveTexturePulses()
    else
        wipe(self.objectiveTexturePulses)
    end
end

function Pins:GetAvailablePingFrame(collection)
    local oldest
    for _, frame in ipairs(collection) do
        if not frame.active then
            return frame
        end
        if not oldest or (frame.startedAt or 0) < (oldest.startedAt or 0) then
            oldest = frame
        end
    end
    return oldest
end

function Pins:LayoutPingUnitFrame(frame)
    local mapFrame = BattleMaps.MapFrame
    if not frame or not mapFrame or not mapFrame.canvas then return false end

    local width, height = mapFrame.canvas:GetSize()
    if not width or width <= 0 or not height or height <= 0 then
        -- Keep the secure UnitPositionFrame in its pre-shown state. The parent
        -- map frame provides visibility clipping when BattleMaps is hidden.
        return false
    end

    if not frame.BattleMapsAnchored then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", mapFrame.canvas, "TOPLEFT", 0, 0)
        frame:SetFrameLevel(self.parent:GetFrameLevel() + PING_FRAME_LEVEL_OFFSET)
        frame.BattleMapsAnchored = true
    end

    frame:SetSize(width, height)
    local configMapID = mapFrame.currentMapID
    local unitMapID = configMapID and (
        BattleMaps.GetBattlegroundUIMapID
            and BattleMaps.GetBattlegroundUIMapID(configMapID, true)
            or configMapID
    )
    if unitMapID and frame.BattleMapsMapID ~= unitMapID then
        frame.BattleMapsMapID = unitMapID
        frame:SetUiMapID(unitMapID)
        frame:SetNeedsFullUpdate()
    end
    return unitMapID ~= nil
end

function Pins:UpdateUnitPingFrame(frame, now)
    if not frame or not frame.active then return end

    if not frame.unitToken or not UnitExists(frame.unitToken)
        or not frame.expiresAt or now >= frame.expiresAt then
        self:DeactivateUnitPing(frame)
        return
    end

    if not self:LayoutPingUnitFrame(frame) then
        self:DeactivateUnitPing(frame)
        return
    end

    local progress = BattleMaps.Clamp((now - frame.startedAt) / PING_DURATION, 0, 1)

    -- The unit list and ring size are preloaded. Animate opacity only so the
    -- restricted position renderer never has to acquire a new unit during the
    -- active match. A smooth sine pulse fades in and then out.
    frame.currentAlpha = BattleMaps.Clamp(math.sin(progress * math.pi) * 0.95, 0, 0.95)

    if not frame:IsShown() then
        if InCombatLockdown() then
            BattleMaps.Debug("ping unit frame is hidden during lockdown; visual unavailable")
            return
        end
        frame:Show()
    end

    if not frame.trackedUnits or not frame.trackedUnits[frame.unitToken] then
        frame:SetNeedsFullUpdate()
        frame:UpdatePlayerPins()
    end

    if frame.trackedUnits and frame.trackedUnits[frame.unitToken] then
        frame:SetUnitColor(
            frame.unitToken,
            frame.pingR or 1,
            frame.pingG or 1,
            frame.pingB or 1,
            frame.currentAlpha
        )
    end
end

function Pins:UpdateObjectivePingFrame(frame, now)
    if not frame or not frame.active then return end

    if not frame.expiresAt or now >= frame.expiresAt or not frame.mapX or not frame.mapY then
        self:DeactivateObjectivePing(frame)
        return
    end

    local elapsed = BattleMaps.Clamp((now or 0) - (frame.startedAt or 0), 0, frame.pulseDuration or 1.25)
    local profile = OBJECTIVE_PULSE_PROFILES[frame.pulseKind] or OBJECTIVE_PULSE_PROFILES.generic
    local baseSize = BattleMaps.Clamp(tonumber(frame.pulseBaseSize) or 24, 16, 96)

    local baseR, baseG, baseB = frame.pingR or 1, frame.pingG or 1, frame.pingB or 1
    local primaryR, primaryG, primaryB = MixColor(baseR, baseG, baseB, 1, 1, 1, 0.18)
    local highlightR, highlightG, highlightB = MixColor(baseR, baseG, baseB, 1, 1, 1, 0.55)
    local echoR, echoG, echoB = MixColor(baseR, baseG, baseB, 1, 1, 1, 0.06)

    local primaryProgress = PulseSegmentProgress(elapsed, profile.primaryDelay, profile.primaryDuration)
    local primaryEase = EaseOutQuad(primaryProgress or 0)
    local primarySize = baseSize * (profile.primaryStartScale + ((profile.primaryEndScale - profile.primaryStartScale) * primaryEase))
    local primaryAlpha = PulseLayerAlpha(primaryProgress, profile.primaryPeakAlpha, 0.14)

    local echoProgress = PulseSegmentProgress(elapsed, profile.echoDelay, profile.echoDuration)
    local echoEase = EaseOutQuad(echoProgress or 0)
    local echoSize = baseSize * (profile.echoStartScale + ((profile.echoEndScale - profile.echoStartScale) * echoEase))
    local echoAlpha = PulseLayerAlpha(echoProgress, profile.echoPeakAlpha, 0.12)

    local highlightProgress = PulseSegmentProgress(elapsed, profile.highlightDelay, profile.highlightDuration)
    local highlightEase = EaseOutQuad(highlightProgress or 0)
    local highlightSize = baseSize * (profile.highlightStartScale + ((profile.highlightEndScale - profile.highlightStartScale) * highlightEase))
    local highlightAlpha = PulseLayerAlpha(highlightProgress, profile.highlightPeakAlpha, 0.18)

    local maxSize = math.max(primarySize or 0, echoSize or 0, highlightSize or 0, baseSize * 1.5)
    frame:SetSize(maxSize, maxSize)
    frame:SetAlpha(1)

    if frame.echoRing then
        frame.echoRing:SetSize(echoSize, echoSize)
        frame.echoRing:SetVertexColor(echoR, echoG, echoB, 1)
        frame.echoRing:SetAlpha(echoAlpha)
    end

    if frame.texture then
        frame.texture:SetSize(primarySize, primarySize)
        frame.texture:SetVertexColor(primaryR, primaryG, primaryB, 1)
        frame.texture:SetAlpha(primaryAlpha)
    end

    if frame.highlightRing then
        frame.highlightRing:SetSize(highlightSize, highlightSize)
        frame.highlightRing:SetVertexColor(highlightR, highlightG, highlightB, 1)
        frame.highlightRing:SetAlpha(highlightAlpha)
    end

    self:Place(frame, frame.mapX, frame.mapY)
end

function Pins:UpdatePingAnimations()
    local now = GetTime()
    for _, frame in ipairs(self.unitPingFrames) do
        self:UpdateUnitPingFrame(frame, now)
    end
    for _, frame in ipairs(self.objectivePingFrames) do
        self:UpdateObjectivePingFrame(frame, now)
    end
end

function Pins:ShowPingAtUnit(unit, pingType)
    local db = BattleMaps.Database:Get()
    local mapFrame = BattleMaps.MapFrame
    if db.showPingPulses ~= true or not unit or not UnitExists(unit)
        or not mapFrame or not mapFrame.currentMapID
        or not mapFrame.frame or not mapFrame.frame:IsShown() then
        return false
    end

    local frame = self:GetAvailablePingFrame(self.unitPingFrames)
    if not frame then return false end

    self:DeactivateUnitPing(frame)
    local now = GetTime()
    frame.active = true
    frame.unitToken = unit
    frame.startedAt = now
    frame.expiresAt = now + PING_DURATION
    frame.pingR, frame.pingG, frame.pingB = self:GetPingColor(pingType)
    self:UpdateUnitPingFrame(frame, now)
    return true
end

function Pins:ShowPingAtObjective(pin, pingType)
    local db = BattleMaps.Database:Get()
    local mapFrame = BattleMaps.MapFrame
    if db.showPingPulses ~= true or not pin or not pin.mapX or not pin.mapY
        or not mapFrame or not mapFrame.currentMapID
        or not mapFrame.frame or not mapFrame.frame:IsShown() then
        return false
    end

    local frame = self:GetAvailablePingFrame(self.objectivePingFrames)
    if not frame then return false end

    local pinConfig = BattleMaps.Database:GetBasePinConfig(mapFrame.currentMapID)
    local baseScale = BattleMaps.Clamp(tonumber(pinConfig and pinConfig.objectivePinScale) or 1, 0.5, 2.5)
    local zoomScale = self:GetPinZoomScale()
    local baseSize = BattleMaps.Clamp(24 * baseScale * zoomScale, 18, 72)
    local profile = OBJECTIVE_PULSE_PROFILES.generic

    self:DeactivateObjectivePing(frame)
    local now = GetTime()
    frame.active = true
    frame.mapX = pin.mapX
    frame.mapY = pin.mapY
    frame.startedAt = now
    frame.pulseKind = "generic"
    frame.pulseBaseSize = baseSize
    frame.pulseDuration = profile.totalDuration
    frame.expiresAt = now + profile.totalDuration
    frame.pingR, frame.pingG, frame.pingB = self:GetPingColor(pingType)
    self:UpdateObjectivePingFrame(frame, now)
    return true
end

-- Unit/player pin layout and refresh methods are implemented in UnitPins.lua.

local function HidePinCollection(collection)
    for _, pin in ipairs(collection or {}) do
        pin:Hide()
    end
end

-- Objective category capability lookup moved to ObjectiveRules.lua.

function Pins:GetRecentCarriedObjectiveFaction(mapID)
    local cache = self.carriedObjectiveFactionMessages
    if type(cache) ~= "table" then return nil end
    local key = GetStationaryMessageCacheKey(mapID)
    local record = cache[key]
    if type(record) ~= "table" then return nil end

    local now = type(GetTime) == "function" and GetTime() or 0
    if record.expires and record.expires <= now then
        cache[key] = nil
        return nil
    end
    return record.faction
end

-- Carried objective faction/texture-state helpers are implemented in ObjectiveTextures.lua.

-- Unit refresh wrappers are implemented in UnitPins.lua.

-- Vehicle objective rendering is implemented in ObjectivePins.lua.

-- Shared helpers for split pin modules. These intentionally expose only the
-- small local helpers that the carried/stationary objective renderers need, while
-- keeping the public Pins API unchanged.
Pins.Private = Pins.Private or {}
Pins.Private.CreateTexturePin = CreateTexturePin
Pins.Private.HidePinCollection = HidePinCollection
Pins.Private.ObjectiveCategoryEnabled = ObjectiveCategoryEnabled
Pins.Private.IsCaptureTheFlagMap = IsCaptureTheFlagMap
Pins.Private.ResolveObjectiveAPIMapID = ResolveObjectiveAPIMapID
Pins.Private.InferObjectiveState = InferObjectiveState
Pins.Private.InferStationaryObjectiveState = InferStationaryObjectiveState
Pins.Private.GetCarriedObjectiveTexture = GetCarriedObjectiveTexture
Pins.Private.NormalizeObjectiveKey = NormalizeObjectiveKey
Pins.Private.InferCarriedFlagFactionFromText = InferCarriedFlagFactionFromText
Pins.Private.InferCTFFlagObjectFactionFromToken = InferCTFFlagObjectFactionFromToken
Pins.Private.GetStableFactionFromState = GetStableFactionFromState
Pins.Private.GetFallbackCTFFlagFactionByIndex = GetFallbackCTFFlagFactionByIndex
-- Pins.Private.SetTooltip is installed by ObjectiveTimers.lua.
Pins.Private.GetAreaPOIIDs = GetAreaPOIIDs
Pins.Private.SetPOITexture = SetPOITexture
Pins.Private.SetFileTexture = SetFileTexture
Pins.Private.BuildObjectiveKeys = BuildObjectiveKeys
Pins.Private.GetVehicleObjectiveKey = GetVehicleObjectiveKey
-- Pins.Private.EnsureObjectiveCaptureTimerTextures is installed by ObjectiveTimers.lua.
Pins.Private.IsDeephaulRavineMap = IsDeephaulRavineMap

-- Carried objective / CTF flag rendering is implemented in CarriedObjectives.lua.

-- Stationary objective provider rendering is implemented in ObjectivePins.lua.


function Pins:LayoutAll()
    if self:ShouldShowDummyPins() then
        self:RefreshDummyPins()
        return
    end
    self:HideDummyPins()

    local zoomScale = self:GetPinZoomScale()
    local mapFrame = BattleMaps.MapFrame
    local canvas = mapFrame and mapFrame.canvas
    local canvasWidth, canvasHeight = canvas and canvas:GetSize()
    local zoomChanged = not self.lastPinZoomScale
        or math.abs(self.lastPinZoomScale - zoomScale) > 0.0001
    local unitLayoutChanged = zoomChanged
        or self.lastUnitLayoutCanvasWidth ~= canvasWidth
        or self.lastUnitLayoutCanvasHeight ~= canvasHeight

    -- Unit frames are anchored to the canvas, so panning moves them with the
    -- map automatically. Reconcile only when zoom or canvas size changes;
    -- normal live position updates remain Blizzard-owned.
    if unitLayoutChanged then
        self.lastUnitLayoutCanvasWidth = canvasWidth
        self.lastUnitLayoutCanvasHeight = canvasHeight
        self:RefreshUnits(false)
    end

    -- Objective providers run on timers, but zoom changes should resize them
    -- immediately. Avoid repeating their API work during ordinary panning by
    -- refreshing only when the half-strength zoom multiplier changes.
    if zoomChanged then
        self.lastPinZoomScale = zoomScale
        self:RefreshVehicles()
        self:RefreshFlags()
        self:RefreshPOIs()
        self:RefreshScenarios()
        self:RefreshVignettes()
    end

    local collections = { self.vehiclePins, self.flagPins, self.poiPins, self.scenarioPins, self.vignettePins }
    for _, collection in ipairs(collections) do
        for _, pin in ipairs(collection) do
            if pin:IsShown() and pin.mapX and pin.mapY then
                self:Place(pin, pin.mapX, pin.mapY)
            end
        end
    end

    self:UpdatePingAnimations()
end

function Pins:RefreshAll(forceObjectives)
    if self:ShouldShowDummyPins() then
        self:RefreshDummyPins()
        return
    end
    self:HideDummyPins()

    self:RefreshUnits(true)
    self:UpdatePingAnimations()

    if forceObjectives then
        self:RefreshVehicles()
        self:RefreshFlags()
        self:RefreshPOIs()
        self:RefreshScenarios()
        self:RefreshVignettes()
        self.vehicleElapsed = 0
        self.flagElapsed = 0
        self.poiElapsed = 0
        self.scenarioElapsed = 0
        self.vignetteElapsed = 0
        self.unitElapsed = 0
    end
end

function Pins:OnUpdate()
    if self:ShouldShowDummyPins() then
        self:RefreshDummyPins()
        if self.UpdateObjectiveCaptureTimerVisuals
            and ((self.HasActiveObjectiveTimerVisuals and self:HasActiveObjectiveTimerVisuals())
                or next(self.objectiveCaptureTimers or {})) then
            self:UpdateObjectiveCaptureTimerVisuals()
        end
        return
    end
    self:HideDummyPins()

    self:UpdatePingAnimations()
    if self.UpdateObjectiveCaptureTimerVisuals
        and ((self.HasActiveObjectiveTimerVisuals and self:HasActiveObjectiveTimerVisuals())
            or next(self.objectiveCaptureTimers or {})) then
        self:UpdateObjectiveCaptureTimerVisuals()
    end
    if #self.objectiveTexturePulses > 0 and type(GetTime) == "function" then
        self:UpdatePendingObjectiveTexturePulses(GetTime())
    end

    self.vehicleElapsed = self.vehicleElapsed + 0.10
    self.flagElapsed = self.flagElapsed + 0.10
    self.poiElapsed = self.poiElapsed + 0.10
    self.scenarioElapsed = self.scenarioElapsed + 0.10
    self.vignetteElapsed = self.vignetteElapsed + 0.10
    self.unitElapsed = self.unitElapsed + 0.10

    if self.unitElapsed >= UNIT_REFRESH_INTERVAL then
        self.unitElapsed = 0
        self:RefreshUnits(false)
    end

    if self.vehicleElapsed >= 0.25 then
        self.vehicleElapsed = 0
        self:RefreshVehicles()
    end

    if self.flagElapsed >= FLAG_REFRESH_INTERVAL then
        self.flagElapsed = 0
        self:RefreshFlags()
    elseif GetObjectiveSettings(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID).showFlagCarrierTrail == true then
        self:RenderFlagCarrierTrails(#(self.flagPins or {}))
    end

    if self.poiElapsed >= 1.00 then
        self.poiElapsed = 0
        self:RefreshPOIs()
    end

    if self.scenarioElapsed >= 0.50 then
        self.scenarioElapsed = 0
        self:RefreshScenarios()
    end

    if self.vignetteElapsed >= VIGNETTE_REFRESH_INTERVAL then
        self.vignetteElapsed = 0
        self:RefreshVignettes()
    end
end
