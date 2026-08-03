local addonName, BattleMaps = ...
BattleMaps = BattleMaps or _G.BattleMaps
if not BattleMaps or not BattleMaps.Pins then return end

local Pins = BattleMaps.Pins
local Private = Pins.Private or {}
local Rules = BattleMaps.ObjectiveRules or {}

-- Forward declarations used by carried-objective rendering above the trail
-- implementation. Lua local function declarations are scoped from their
-- declaration point, so these must exist before live/Test Mode orb rendering.
local GetObjectiveFactionColor
local GetObjectiveSettings

--[[
BattleMaps module contract: CarriedObjectives.lua

Owns carried-objective placement and effects: WSG/TP/EotS/Deephaul carried
flags/crystals, carried-objective trail breadcrumbs, and carried-objective
flash overlays.

This module should not own stationary objective discovery, capture-timer
lifecycle, general unit pins, or options UI.
]]

-- Carried-objective placement --------------------------------------------

local function GetLegacyBattlefieldFlagToken(index)
    if type(GetBattlefieldFlagPosition) ~= "function" then return nil end
    local ok, _, _, token = pcall(GetBattlefieldFlagPosition, index)
    if ok then return token end
    return nil
end

local function NormalizeTrailFactionValue(value)
    local ok, text = pcall(tostring, value or "")
    if not ok or type(text) ~= "string" then return nil end
    ok, text = pcall(string.lower, text)
    if not ok or type(text) ~= "string" then return nil end

    text = text:gsub("\\", "/")
    local compact = text:gsub("[^%w]+", "_")

    if compact == "alliance" or compact == "a" or compact == "blue"
        or compact:find("_a_tga", 1, true)
        or compact:find("_a_blp", 1, true)
        or compact:find("_alliance", 1, true)
        or compact:find("alliance_", 1, true)
        or compact:find("blue", 1, true) then
        return "alliance"
    end

    if compact == "horde" or compact == "h" or compact == "red"
        or compact:find("_h_tga", 1, true)
        or compact:find("_h_blp", 1, true)
        or compact:find("_horde", 1, true)
        or compact:find("horde_", 1, true)
        or compact:find("red", 1, true) then
        return "horde"
    end

    return nil
end

local function ResolveTrailFactionFromRenderedFlag(...)
    for index = 1, select("#", ...) do
        local faction = NormalizeTrailFactionValue(select(index, ...))
        if faction then return faction end
    end
    return nil
end


local EOTS_FLAG_CENTER_X = 0.50
local EOTS_FLAG_CENTER_Y = 0.50
local EOTS_FLAG_CENTER_RADIUS = 0.060
local EOTS_FLAG_PLAYER_MATCH_RADIUS = 0.050
local EOTS_DROPPED_NEUTRAL_SECONDS = 8.00
local FALLBACK_CARRIED_FLAG_TEXTURE = "Interface\\Icons\\INV_BannerPVP_01"
local CTF_EFFECT_MOVEMENT_DISTANCE_SQUARED = 0.0000025
local CTF_EFFECT_MOVEMENT_GRACE_SECONDS = 6.00
local CARRIER_CLASS_COLOR_CACHE_SECONDS = 0.50
local CARRIER_CLASS_MATCH_RADIUS_SQUARED = 0.001225 -- 3.5% of the map
local FLAG_TRAIL_TRANSIENT_MISSING_GRACE = 0.85

-- Spawn tether learns CTF flag-room coordinates from Blizzard's stationary
-- flag positions at runtime. These normalized positions are only fallbacks for
-- Test Mode or when BattleMaps is opened after a flag has already left base.
local CTF_FLAG_BASE_FALLBACKS = {
    warsong_gulch = {
        alliance = { 0.50, 0.105 },
        horde = { 0.50, 0.895 },
    },
    twin_peaks = {
        alliance = { 0.705, 0.770 },
        horde = { 0.295, 0.230 },
    },
}

local KOTMOGU_ORB_TRAIL_COLORS = {
    purple = { 0.72, 0.30, 1.00 },
    green = { 0.30, 1.00, 0.30 },
    orange = { 1.00, 0.52, 0.08 },
    blue = { 0.25, 0.78, 1.00 },
}

local function IsTempleOfKotmoguMap(mapID)
    if Rules.IsTempleOfKotmoguMap then
        local ok, result = pcall(Rules.IsTempleOfKotmoguMap, mapID)
        if ok then return result == true end
    end
    if Private.IsTempleOfKotmoguMap then
        local ok, result = pcall(Private.IsTempleOfKotmoguMap, mapID)
        if ok then return result == true end
    end
    mapID = tonumber(mapID)
    return mapID == 417 or mapID == 998
end

local KOTMOGU_ORB_COLORS = { "purple", "green", "orange", "blue" }
local KOTMOGU_ORB_INDEX_BY_COLOR = {
    purple = 1,
    green = 2,
    orange = 3,
    blue = 4,
}

local function GetKotmoguOrbColor(index)
    if Rules.GetTempleOrbColorByCarriedIndex then
        local ok, color = pcall(Rules.GetTempleOrbColorByCarriedIndex, index)
        if ok and color then return color end
    end
    return KOTMOGU_ORB_COLORS[tonumber(index)]
end

local function ExtractKotmoguOrbColor(...)
    local combined = {}
    for valueIndex = 1, select("#", ...) do
        combined[#combined + 1] = tostring(select(valueIndex, ...) or "")
    end
    local text = table.concat(combined, " "):lower():gsub("[^%w]+", "_")
    for _, color in ipairs(KOTMOGU_ORB_COLORS) do
        if text:find(color, 1, true) then return color end
    end
    return nil
end

local function GetKotmoguSlotKey(mapID, index)
    return tostring(tonumber(mapID) or mapID or "unknown")
        .. ":" .. tostring(tonumber(index) or index or 0)
end

local function RememberKotmoguOrbColor(pins, mapID, index, color)
    if not pins or not color then return color end
    pins.templeCarriedOrbColorBySlot = pins.templeCarriedOrbColorBySlot or {}
    pins.templeCarriedOrbColorBySlot[GetKotmoguSlotKey(mapID, index)] = color
    return color
end

local function GetKotmoguOrbTextureKey(color)
    if Rules.GetTempleOrbTextureKey then
        local ok, key = pcall(Rules.GetTempleOrbTextureKey, color)
        if ok and key then return key end
    end
    return color and (tostring(color) .. "_orb") or nil
end

local KOTMOGU_CONTINUITY_MAX_AGE = 3.0
local KOTMOGU_CONTINUITY_MAX_DISTANCE_SQUARED = 0.0400 -- 20% map distance
local KOTMOGU_RECENT_PICKUP_MAX_AGE = 4.0
local KOTMOGU_RECENT_PICKUP_MAX_DISTANCE_SQUARED = 0.0324 -- 18% map distance
local DistanceSquared

local function GetKotmoguMotionRecord(pins, mapID, color)
    local state = pins and pins.templeCarriedOrbMotionByColor
    if type(state) ~= "table" or not color then return nil end
    local key = tostring(tonumber(mapID) or mapID or "unknown") .. ":" .. tostring(color)
    local record = state[key]
    return type(record) == "table" and record or nil
end

local function AssignKotmoguColor(flagInfo, color, pins, mapID, assignedColors)
    if not flagInfo or not color or flagInfo.kotmoguOrbColor then return false end
    if assignedColors[color] then return false end
    flagInfo.kotmoguOrbColor = RememberKotmoguOrbColor(pins, mapID, flagInfo.index, color)
    assignedColors[color] = true
    return true
end

local function AssignKotmoguColorsByContinuity(pins, mapID, visibleFlags, activeColors, assignedColors)
    local now = type(GetTime) == "function" and GetTime() or 0
    local pairsByDistance = {}

    for _, color in ipairs(KOTMOGU_ORB_COLORS) do
        if activeColors[color] and not assignedColors[color] then
            local record = GetKotmoguMotionRecord(pins, mapID, color)
            local age = record and (now - (tonumber(record.time) or now)) or nil
            if record and age and age >= 0 and age <= KOTMOGU_CONTINUITY_MAX_AGE then
                for flagNumber, flagInfo in ipairs(visibleFlags) do
                    if not flagInfo.kotmoguOrbColor and not flagInfo.kotmoguOrbSuppressed then
                        local distance = DistanceSquared(flagInfo.x, flagInfo.y, record.x, record.y)
                        if distance and distance <= KOTMOGU_CONTINUITY_MAX_DISTANCE_SQUARED then
                            pairsByDistance[#pairsByDistance + 1] = {
                                distance = distance,
                                flagNumber = flagNumber,
                                color = color,
                            }
                        end
                    end
                end
            end
        end
    end

    table.sort(pairsByDistance, function(a, b) return a.distance < b.distance end)
    local usedFlags = {}
    for _, candidate in ipairs(pairsByDistance) do
        local flagInfo = visibleFlags[candidate.flagNumber]
        if flagInfo and not usedFlags[candidate.flagNumber]
            and not flagInfo.kotmoguOrbColor
            and not assignedColors[candidate.color] then
            if AssignKotmoguColor(flagInfo, candidate.color, pins, mapID, assignedColors) then
                usedFlags[candidate.flagNumber] = true
            end
        end
    end
end

local function AssignKotmoguColorsByRecentPickup(pins, mapID, visibleFlags, activeColors, assignedColors)
    local messageState = pins and pins.templeOrbMessageStateByColor
    if type(messageState) ~= "table" then return end
    local now = type(GetTime) == "function" and GetTime() or 0
    local pairsByDistance = {}

    for _, color in ipairs(KOTMOGU_ORB_COLORS) do
        local record = messageState[color]
        local pickedAt = type(record) == "table" and tonumber(record.time) or nil
        local age = pickedAt and (now - pickedAt) or nil
        if activeColors[color] and not assignedColors[color]
            and age and age >= 0 and age <= KOTMOGU_RECENT_PICKUP_MAX_AGE then
            local spawnX, spawnY
            if Rules.GetTempleOrbSpawnPosition then
                spawnX, spawnY = Rules.GetTempleOrbSpawnPosition(color)
            end
            if spawnX and spawnY then
                for flagNumber, flagInfo in ipairs(visibleFlags) do
                    if not flagInfo.kotmoguOrbColor and not flagInfo.kotmoguOrbSuppressed then
                        local distance = DistanceSquared(flagInfo.x, flagInfo.y, spawnX, spawnY)
                        if distance and distance <= KOTMOGU_RECENT_PICKUP_MAX_DISTANCE_SQUARED then
                            pairsByDistance[#pairsByDistance + 1] = {
                                distance = distance,
                                flagNumber = flagNumber,
                                color = color,
                            }
                        end
                    end
                end
            end
        end
    end

    table.sort(pairsByDistance, function(a, b) return a.distance < b.distance end)
    local usedFlags = {}
    for _, candidate in ipairs(pairsByDistance) do
        local flagInfo = visibleFlags[candidate.flagNumber]
        if flagInfo and not usedFlags[candidate.flagNumber]
            and not flagInfo.kotmoguOrbColor
            and not assignedColors[candidate.color] then
            if AssignKotmoguColor(flagInfo, candidate.color, pins, mapID, assignedColors) then
                usedFlags[candidate.flagNumber] = true
            end
        end
    end
end


local function IsEyeOfTheStormMap(mapID)
    return tonumber(mapID) == 210
end

local function GetOpposingFaction(faction)
    faction = NormalizeTrailFactionValue(faction)
    if faction == "alliance" then return "horde" end
    if faction == "horde" then return "alliance" end
    return nil
end

local function GetPlayerEffectiveFaction(pins)
    local faction
    if pins and type(pins.GetPlayerFactionColor) == "function" then
        local ok, _, _, _, playerFaction = pcall(pins.GetPlayerFactionColor, pins)
        if ok then faction = playerFaction end
    end
    if not faction and BattleMaps.MapFrame and type(BattleMaps.MapFrame.GetEffectiveFaction) == "function" then
        local ok, mapFaction = pcall(BattleMaps.MapFrame.GetEffectiveFaction, BattleMaps.MapFrame)
        if ok then faction = mapFaction end
    end
    return NormalizeTrailFactionValue(faction)
end

DistanceSquared = function(ax, ay, bx, by)
    ax, ay, bx, by = tonumber(ax), tonumber(ay), tonumber(bx), tonumber(by)
    if not ax or not ay or not bx or not by then return nil end
    local dx = ax - bx
    local dy = ay - by
    return (dx * dx) + (dy * dy)
end

local function IsNearEotSCenter(x, y)
    local distance = DistanceSquared(x, y, EOTS_FLAG_CENTER_X, EOTS_FLAG_CENTER_Y)
    return distance and distance <= (EOTS_FLAG_CENTER_RADIUS * EOTS_FLAG_CENTER_RADIUS)
end

local function QueueEotSStationaryRefresh(pins)
    if not pins then return end
    pins.poiElapsed = 1.00
    pins.scenarioElapsed = 0.50
    pins.vignetteElapsed = 0.10

    if not C_Timer or not C_Timer.After then return end
    C_Timer.After(0, function()
        if not BattleMaps.MapFrame or tonumber(BattleMaps.MapFrame.currentMapID) ~= 210 then return end
        local frame = BattleMaps.MapFrame.frame
        if not frame or not frame:IsShown() then return end
        if pins.RefreshPOIs then pins:RefreshPOIs() end
        if pins.RefreshScenarios then pins:RefreshScenarios() end
        if pins.RefreshVignettes then pins:RefreshVignettes() end
    end)
end

function Pins:SetEotSFlagAwayFromCenter(isAway, source)
    isAway = isAway == true
    local changed = self.eotsFlagAwayFromCenter ~= isAway
    self.eotsFlagAwayFromCenter = isAway
    self.eotsFlagAwaySource = isAway and source or nil
    if changed then
        QueueEotSStationaryRefresh(self)
    end
    return changed
end

function Pins:IsEotSStationaryFlagSuppressed(mapID)
    return tonumber(mapID) == 210 and self.eotsFlagAwayFromCenter == true
end

local function GetPlayerMapPosition(apiMapID)
    if not C_Map or type(C_Map.GetPlayerMapPosition) ~= "function" then return nil, nil end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, apiMapID, "player")
    if not ok or not pos then return nil, nil end

    local x, y
    if type(pos.GetXY) == "function" then
        local okXY, px, py = pcall(pos.GetXY, pos)
        if okXY then x, y = px, py end
    end
    if not x and type(pos.x) == "number" and type(pos.y) == "number" then
        x, y = pos.x, pos.y
    end
    return tonumber(x), tonumber(y)
end

local function GetUnitMapPositionForTrail(pins, apiMapID, unit)
    if pins and type(pins.GetTeamStackUnitMapPosition) == "function" then
        local ok, x, y = pcall(pins.GetTeamStackUnitMapPosition, pins, apiMapID, unit)
        if ok and x and y then return tonumber(x), tonumber(y) end
    end

    if C_Map and type(C_Map.GetPlayerMapPosition) == "function" then
        local ok, pos = pcall(C_Map.GetPlayerMapPosition, apiMapID, unit)
        if ok and pos then
            if type(pos.GetXY) == "function" then
                local okXY, x, y = pcall(pos.GetXY, pos)
                if okXY and x and y then return tonumber(x), tonumber(y) end
            end
            if type(pos.x) == "number" and type(pos.y) == "number" then
                return tonumber(pos.x), tonumber(pos.y)
            end
        end
    end
    return nil, nil
end

local KOTMOGU_DEAD_CARRIER_MATCH_RADIUS_SQUARED = 0.000225 -- 1.5% map distance

local function FindFriendlyUnitAtMapPosition(pins, apiMapID, x, y)
    local bestUnit, bestDistance
    local function Consider(unit)
        if not unit or not UnitExists or not UnitExists(unit) then return end
        local unitX, unitY = GetUnitMapPositionForTrail(pins, apiMapID, unit)
        local distance = DistanceSquared(x, y, unitX, unitY)
        if distance and distance <= KOTMOGU_DEAD_CARRIER_MATCH_RADIUS_SQUARED
            and (not bestDistance or distance < bestDistance) then
            bestUnit, bestDistance = unit, distance
        end
    end

    Consider("player")
    local unitFrame = pins and pins.unitFrame
    if unitFrame and type(unitFrame.GetMemberCountAndUnitTokenPrefix) == "function" then
        local ok, count, prefix = pcall(unitFrame.GetMemberCountAndUnitTokenPrefix, unitFrame)
        count = ok and tonumber(count) or 0
        prefix = ok and prefix or "raid"
        for index = 1, count do Consider(prefix .. index) end
    elseif type(GetNumGroupMembers) == "function" then
        local count = tonumber(GetNumGroupMembers()) or 0
        local prefix = IsInRaid and IsInRaid() and "raid" or "party"
        for index = 1, count do Consider(prefix .. index) end
    end
    return bestUnit
end

local function IsFriendlyKotmoguCarrierDead(pins, apiMapID, x, y)
    local unit = FindFriendlyUnitAtMapPosition(pins, apiMapID, x, y)
    if not unit then return false end
    if type(UnitIsDeadOrGhost) == "function" then
        local ok, dead = pcall(UnitIsDeadOrGhost, unit)
        if ok then return dead == true end
    end
    if type(UnitIsDead) == "function" then
        local ok, dead = pcall(UnitIsDead, unit)
        if ok then return dead == true end
    end
    return false
end

local function UpdateKotmoguCarrierMotion(pins, mapID, color, x, y)
    if not pins or not color or not x or not y then return end
    pins.templeCarriedOrbMotionByColor = pins.templeCarriedOrbMotionByColor or {}
    local key = tostring(tonumber(mapID) or mapID or "unknown") .. ":" .. tostring(color)
    local now = type(GetTime) == "function" and GetTime() or 0
    pins.templeCarriedOrbMotionByColor[key] = { x = x, y = y, time = now }
end

local function GetUnitClassTrailColor(pins, unit, now)
    if not unit or not UnitExists or not UnitExists(unit) then return nil end
    if pins and type(pins.GetUnitClassColor) == "function" then
        local ok, r, g, b = pcall(pins.GetUnitClassColor, pins, unit, now)
        if ok and r and g and b then return r, g, b end
    end

    local ok, _, classFile = pcall(UnitClass, unit)
    if ok and classFile then
        if type(GetClassColor) == "function" then
            local okColor, r, g, b = pcall(GetClassColor, classFile)
            if okColor and r and g and b then return r, g, b end
        end
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
        if color then return color.r, color.g, color.b end
    end
    return nil
end

local CLASS_TEXTURE_TOKENS = {
    DEATHKNIGHT = { "deathknight", "death_knight" },
    DEMONHUNTER = { "demonhunter", "demon_hunter" },
    DRUID = { "druid" },
    EVOKER = { "evoker" },
    HUNTER = { "hunter" },
    MAGE = { "mage" },
    MONK = { "monk" },
    PALADIN = { "paladin" },
    PRIEST = { "priest" },
    ROGUE = { "rogue" },
    SHAMAN = { "shaman" },
    WARLOCK = { "warlock" },
    WARRIOR = { "warrior" },
}

local function InferClassTrailColorFromText(...)
    local values = {}
    for index = 1, select("#", ...) do
        local ok, value = pcall(tostring, select(index, ...) or "")
        value = ok and value or ""
        values[#values + 1] = value:lower():gsub("[^%w]+", "_")
    end
    local textValue = table.concat(values, "_")
    for classFile, tokens in pairs(CLASS_TEXTURE_TOKENS) do
        for _, token in ipairs(tokens) do
            if textValue:find(token, 1, true) then
                if type(GetClassColor) == "function" then
                    local ok, r, g, b = pcall(GetClassColor, classFile)
                    if ok and r and g and b then return r, g, b end
                end
                local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
                if color then return color.r, color.g, color.b end
            end
        end
    end
    return nil
end

function Pins:ResolveCarriedObjectiveClassTrailColor(mapID, apiMapID, flagIndex, x, y, texture, legacyToken)
    local now = type(GetTime) == "function" and GetTime() or 0
    self.carriedTrailClassColorCache = self.carriedTrailClassColorCache or {}
    local key = tostring(tonumber(mapID) or mapID or "unknown") .. ":" .. tostring(tonumber(flagIndex) or flagIndex or 1)
    local cached = self.carriedTrailClassColorCache[key]
    if type(cached) == "table" and tonumber(cached.expires or 0) > now then
        local dx = (tonumber(cached.x) or tonumber(x) or 0) - (tonumber(x) or 0)
        local dy = (tonumber(cached.y) or tonumber(y) or 0) - (tonumber(y) or 0)
        if (dx * dx) + (dy * dy) <= CARRIER_CLASS_MATCH_RADIUS_SQUARED then
            if cached.miss == true then return nil end
            return cached.r, cached.g, cached.b
        end
    end

    local bestUnit, bestDistance
    local function Consider(unit)
        if not unit or not UnitExists or not UnitExists(unit) then return end
        local unitX, unitY = GetUnitMapPositionForTrail(self, apiMapID, unit)
        local distance = DistanceSquared(x, y, unitX, unitY)
        if distance and distance <= CARRIER_CLASS_MATCH_RADIUS_SQUARED
            and (not bestDistance or distance < bestDistance) then
            bestUnit, bestDistance = unit, distance
        end
    end

    Consider("player")
    local unitFrame = self.unitFrame
    if unitFrame and type(unitFrame.GetMemberCountAndUnitTokenPrefix) == "function" then
        local ok, memberCount, unitBase = pcall(unitFrame.GetMemberCountAndUnitTokenPrefix, unitFrame)
        memberCount = ok and tonumber(memberCount) or 0
        unitBase = ok and unitBase or "raid"
        for index = 1, memberCount do Consider(unitBase .. index) end
    elseif type(GetNumGroupMembers) == "function" then
        local count = tonumber(GetNumGroupMembers()) or 0
        local prefix = IsInRaid and IsInRaid() and "raid" or "party"
        for index = 1, count do Consider(prefix .. index) end
    end

    local r, g, b = GetUnitClassTrailColor(self, bestUnit, now)
    if not r then r, g, b = InferClassTrailColorFromText(texture, legacyToken) end
    if r and g and b then
        self.carriedTrailClassColorCache[key] = {
            r = r, g = g, b = b,
            x = tonumber(x), y = tonumber(y),
            expires = now + CARRIER_CLASS_COLOR_CACHE_SECONDS,
        }
        return r, g, b
    end

    -- Cache misses briefly as well. Enemy carriers usually cannot be resolved
    -- through friendly unit tokens; without a negative cache, every map refresh
    -- would rescan the entire raid roster.
    self.carriedTrailClassColorCache[key] = {
        miss = true,
        x = tonumber(x), y = tonumber(y),
        expires = now + CARRIER_CLASS_COLOR_CACHE_SECONDS,
    }
    return nil
end

local function GetCTFEffectMotionKey(mapID, index, flagObjectFaction)
    return table.concat({
        tostring(tonumber(mapID) or mapID or "unknown"),
        tostring(flagObjectFaction or "unknown"),
        tostring(tonumber(index) or index or 1),
    }, ":")
end

local function CTFPositionSuggestsActive(pins, mapID, index, x, y, flagObjectFaction)
    if not pins or not x or not y then return false end

    local now = type(GetTime) == "function" and GetTime() or 0
    pins.ctfFlagEffectMotionByKey = pins.ctfFlagEffectMotionByKey or {}
    local key = GetCTFEffectMotionKey(mapID, index, flagObjectFaction)
    local record = pins.ctfFlagEffectMotionByKey[key]
    if type(record) ~= "table" then
        pins.ctfFlagEffectMotionByKey[key] = {
            x = tonumber(x),
            y = tonumber(y),
            movedUntil = 0,
        }
        return false
    end

    local currentX = tonumber(x)
    local currentY = tonumber(y)
    local previousX = tonumber(record.x)
    local previousY = tonumber(record.y)
    local dx = previousX and currentX and (currentX - previousX) or 0
    local dy = previousY and currentY and (currentY - previousY) or 0
    record.x = currentX
    record.y = currentY

    local distance = (dx * dx) + (dy * dy)
    if distance > CTF_EFFECT_MOVEMENT_DISTANCE_SQUARED then
        record.movedUntil = now + CTF_EFFECT_MOVEMENT_GRACE_SECONDS
        return true
    end

    return tonumber(record.movedUntil or 0) > now
end

local function ShouldRunCTFCarriedEffects(pins, mapID, index, x, y, flagObjectFaction)
    if not pins then return false end
    if flagObjectFaction and type(pins.IsCTFFlagObjectActive) == "function" then
        local ok, active = pcall(pins.IsCTFFlagObjectActive, pins, mapID, flagObjectFaction)
        if ok and active == true then return true end
    end
    return CTFPositionSuggestsActive(pins, mapID, index, x, y, flagObjectFaction)
end

local function GetCTFFlagBaseFallback(mapID, flagObjectFaction)
    flagObjectFaction = NormalizeTrailFactionValue(flagObjectFaction)
    if not flagObjectFaction then return nil, nil end

    local mapNameKey = Rules.GetObjectiveMapNameKey
        and Rules.GetObjectiveMapNameKey(mapID)
        or ""
    local positions = CTF_FLAG_BASE_FALLBACKS[mapNameKey]
    local position = positions and positions[flagObjectFaction]
    if not position then return nil, nil end
    return tonumber(position[1]), tonumber(position[2])
end

function Pins:RememberCTFFlagBasePosition(mapID, flagObjectFaction, x, y)
    if not Rules.IsCaptureTheFlagMap or not Rules.IsCaptureTheFlagMap(mapID) then return false end
    flagObjectFaction = NormalizeTrailFactionValue(flagObjectFaction)
    x, y = tonumber(x), tonumber(y)
    if not flagObjectFaction or not x or not y then return false end

    -- Reject an inactive-looking carrier position that is nowhere near the
    -- expected flag room. This matters when the addon is loaded mid-match and
    -- the pickup notification/movement history has not been observed yet.
    local fallbackX, fallbackY = GetCTFFlagBaseFallback(mapID, flagObjectFaction)
    local fallbackDistance = fallbackX and fallbackY
        and DistanceSquared(x, y, fallbackX, fallbackY)
        or nil
    if fallbackDistance and fallbackDistance > 0.0400 then return false end

    self.ctfFlagBasePositionByMap = self.ctfFlagBasePositionByMap or {}
    local mapKey = tostring(tonumber(mapID) or mapID or "unknown")
    local positions = self.ctfFlagBasePositionByMap[mapKey]
    if type(positions) ~= "table" then
        positions = {}
        self.ctfFlagBasePositionByMap[mapKey] = positions
    end

    -- The first inactive position observed in a match is normally the flag
    -- room. Do not let a later ambiguous API refresh overwrite that stable
    -- origin with a carrier or dropped-flag position.
    if type(positions[flagObjectFaction]) ~= "table" then
        positions[flagObjectFaction] = { x = x, y = y }
    end
    return true
end

function Pins:GetCTFFlagBasePosition(mapID, flagObjectFaction)
    flagObjectFaction = NormalizeTrailFactionValue(flagObjectFaction)
    if not flagObjectFaction then return nil, nil end

    local mapKey = tostring(tonumber(mapID) or mapID or "unknown")
    local positions = self.ctfFlagBasePositionByMap
        and self.ctfFlagBasePositionByMap[mapKey]
    local position = type(positions) == "table" and positions[flagObjectFaction] or nil
    if type(position) == "table" then
        local x, y = tonumber(position.x), tonumber(position.y)
        if x and y then return x, y end
    end
    return GetCTFFlagBaseFallback(mapID, flagObjectFaction)
end

local function ResolveEotSCarrierFaction(pins, mapID, apiMapID, index, x, y, texture, carriedState, legacyToken, currentFaction)
    if not IsEyeOfTheStormMap(mapID) then return currentFaction end

    local nearCenter = IsNearEotSCenter(x, y)
    if nearCenter then
        if pins then
            pins.eotsCarriedFlagMotionByIndex = pins.eotsCarriedFlagMotionByIndex or {}
            pins.eotsCarriedFlagMotionByIndex[tostring(tonumber(index) or index or 1)] = nil
        end
        return nil
    end

    local now = type(GetTime) == "function" and GetTime() or 0
    pins.eotsCarriedFlagMotionByIndex = pins.eotsCarriedFlagMotionByIndex or {}
    local key = tostring(tonumber(index) or index or 1)
    local record = pins.eotsCarriedFlagMotionByIndex[key]
    if type(record) ~= "table" then
        record = { x = tonumber(x), y = tonumber(y), firstSeen = now, lastMove = now }
        pins.eotsCarriedFlagMotionByIndex[key] = record
    end

    local movedDistance = DistanceSquared(x, y, record.x, record.y)
    if movedDistance and movedDistance > 0.000003 then
        record.lastMove = now
        record.x, record.y = tonumber(x), tonumber(y)
    end

    -- Message faction is the most stable EotS source once the flag has been
    -- picked up. Prefer it over transient API/texture state so the flag does not
    -- randomly switch colour while the same carrier is still holding it.
    if pins and type(pins.GetRecentEotSCarriedFlagFaction) == "function" then
        local ok, messageFaction = pcall(pins.GetRecentEotSCarriedFlagFaction, pins, mapID)
        if ok and (messageFaction == "alliance" or messageFaction == "horde") then
            record.faction = messageFaction
            record.lockedByMessage = true
            record.lockedAt = now
            return messageFaction
        end
    end

    -- If a recent message locked the faction, keep it until the message layer
    -- clears on dropped/reset/capture. This avoids flip-flopping when Blizzard
    -- briefly exposes neutral or carrier-looking texture data.
    if record.lockedByMessage and (record.faction == "alliance" or record.faction == "horde") then
        return record.faction
    end

    -- If Blizzard/custom texture data already exposes a real faction, keep it
    -- and remember it. This is useful after /reload when the pickup message was
    -- missed, but it is deliberately lower priority than the EotS message cache.
    local fromTexture = ResolveTrailFactionFromRenderedFlag(currentFaction, texture, legacyToken, carriedState)
    if fromTexture == "alliance" or fromTexture == "horde" then
        record.faction = fromTexture
        return fromTexture
    end

    -- Own-carrier fallback only. Do not infer "opposing faction" merely because
    -- the flag is not near the player; that caused random colour changes and can
    -- miscolour dropped flags.
    local playerFaction = GetPlayerEffectiveFaction(pins)
    local playerX, playerY = GetPlayerMapPosition(apiMapID)
    local playerDistance = DistanceSquared(x, y, playerX, playerY)
    if playerDistance and playerDistance <= (EOTS_FLAG_PLAYER_MATCH_RADIUS * EOTS_FLAG_PLAYER_MATCH_RADIUS) and playerFaction then
        record.faction = playerFaction
        return playerFaction
    end

    -- If the flag was recently moving and we have a remembered non-neutral
    -- faction, keep it briefly. If it remains stationary away from centre, treat
    -- it as dropped and allow the neutral texture.
    local activeRecently = (now - (record.lastMove or now)) <= EOTS_DROPPED_NEUTRAL_SECONDS
        or (now - (record.firstSeen or now)) <= EOTS_DROPPED_NEUTRAL_SECONDS
    if activeRecently and (record.faction == "alliance" or record.faction == "horde") then
        return record.faction
    end

    return nil
end

function Pins:GetFlagPin(index)
    local pin = self.flagPins[index]
    if not pin then
        if not Private.CreateTexturePin then return nil end
        pin = Private.CreateTexturePin(self.parent, 24, 24)
        self.flagPins[index] = pin
    end
    if self.parent then
        pin:SetFrameLevel(self.parent:GetFrameLevel() + (self.FLAG_PIN_FRAME_LEVEL_OFFSET or 59))
    end
    return pin
end

local KOTMOGU_TEST_CARRIED_COLOR = "blue"
local KOTMOGU_TEST_CARRIED_INDEX = 4
local KOTMOGU_LEGACY_DUMMY_CARRIED_COLLECTIONS = {
    "dummyFlagPins",
    "dummyCarriedPins",
    "dummyCarrierPins",
    "dummyObjectiveCarrierPins",
    "previewFlagPins",
    "previewCarriedPins",
    "dummyPins",
}

local function AddPinsToSet(set, collection)
    if type(collection) ~= "table" then return end
    for _, pin in ipairs(collection) do
        if pin then set[pin] = true end
    end
end

local function GetKotmoguProtectedDummyPins(pins)
    local protected = {}
    AddPinsToSet(protected, pins and pins.dummyStationaryPins)
    if pins and pins.templeTestCarriedOrbOwnedPin then
        protected[pins.templeTestCarriedOrbOwnedPin] = true
    end
    return protected
end

local function NormalizeKotmoguPreviewText(value)
    local ok, text = pcall(tostring, value or "")
    if not ok or type(text) ~= "string" then return "" end
    text = text:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("[^%w]+", "_"):gsub("_+", "_")
    return text:gsub("^_+", ""):gsub("_+$", "")
end

local function ScoreKotmoguDummyCarriedPin(pin)
    if not pin or not pin.mapX or not pin.mapY or not pin.texture then return -100 end
    local values = {
        pin.tooltipTitle,
        pin.tooltipDescription,
        pin.BattleMapsObjectiveTexturePath,
        pin.BattleMapsPreviewTexturePath,
        pin.BattleMapsPreviewAtlas,
    }
    if pin.texture.GetTexture then
        local ok, value = pcall(pin.texture.GetTexture, pin.texture)
        if ok then values[#values + 1] = value end
    end
    local text = NormalizeKotmoguPreviewText(table.concat((function()
        local out = {}
        for _, value in ipairs(values) do out[#out + 1] = tostring(value or "") end
        return out
    end)(), " "))

    local score = 0
    if text:find("orb", 1, true) then score = score + 12 end
    if text:find("carried", 1, true) or text:find("carrier", 1, true) then score = score + 10 end
    if text:find("flag", 1, true) then score = score + 8 end
    if text:find("objective", 1, true) then score = score + 3 end
    if text:find("player", 1, true) or text:find("healer", 1, true) then score = score - 20 end
    return score
end

local function HideLegacyKotmoguDummyCarriedPins(pins, keepPin)
    local protected = GetKotmoguProtectedDummyPins(pins)
    local seen = {}
    for _, collectionName in ipairs(KOTMOGU_LEGACY_DUMMY_CARRIED_COLLECTIONS) do
        local collection = pins and pins[collectionName]
        if type(collection) == "table" then
            for _, pin in ipairs(collection) do
                if pin and not seen[pin] then
                    seen[pin] = true
                    local explicitCarriedCollection = collectionName ~= "dummyPins"
                    local looksCarried = explicitCarriedCollection
                        or ScoreKotmoguDummyCarriedPin(pin) > 0
                    if looksCarried and pin ~= keepPin
                        and pin ~= pins.templeTestCarriedOrbOwnedPin
                        and not protected[pin] and pin.Hide then
                        pin:Hide()
                    end
                end
            end
        end
    end
end

function Pins:HideTempleTestCarriedOrbPreview()
    local pin = self.templeTestCarriedOrbPin
    if pin then
        if self.StopCarriedObjectiveFlash then
            self:StopCarriedObjectiveFlash(pin)
        end
        pin:Hide()
    end
    if self.templeTestCarriedOrbController then
        self.templeTestCarriedOrbController:Hide()
    end
    if self.templeTestCarriedOrbPreviewActive then
        self.templeTestCarriedOrbPreviewActive = nil
        self.templeActiveCarriedOrbColors = {}

        -- Restore the normal match-start state immediately: all four
        -- stationary orbs visible.
        local mapFrame = BattleMaps.MapFrame
        local mapID = tonumber(mapFrame and (mapFrame.currentMapID or mapFrame.selectedMapID))
        if IsTempleOfKotmoguMap(mapID) and self.ApplyTempleOrbStationaryState then
            self:ApplyTempleOrbStationaryState(mapID)
        end

        if self.ClearFlagCarrierTrails then
            self:ClearFlagCarrierTrails()
        end
    end
end

function Pins:EnsureTempleTestCarriedOrbController()
    if self.templeTestCarriedOrbController then
        return self.templeTestCarriedOrbController
    end

    local controller = CreateFrame("Frame")
    controller:Hide()
    controller.elapsed = 0
    controller:SetScript("OnUpdate", function(frame, elapsed)
        frame.elapsed = (frame.elapsed or 0) + (tonumber(elapsed) or 0)
        if frame.elapsed < 0.08 then return end
        frame.elapsed = 0

        local mapFrame = BattleMaps.MapFrame
        local mapID = tonumber(mapFrame and (mapFrame.currentMapID or mapFrame.selectedMapID))
        if not mapFrame or mapFrame.testMode ~= true or not IsTempleOfKotmoguMap(mapID) then
            frame:Hide()
            return
        end
        self:RefreshTempleTestCarriedOrbPreview(mapID, true)
    end)
    self.templeTestCarriedOrbController = controller
    return controller
end

function Pins:RefreshTempleTestCarriedOrbPreview(mapID, fromController)
    local mapFrame = BattleMaps.MapFrame
    mapID = tonumber(mapID) or tonumber(mapFrame and (mapFrame.currentMapID or mapFrame.selectedMapID))
    if not mapFrame or mapFrame.testMode ~= true or not IsTempleOfKotmoguMap(mapID) then
        self:HideTempleTestCarriedOrbPreview()
        return false
    end

    local pin = self.templeTestCarriedOrbOwnedPin
    if not pin then
        if not Private.CreateTexturePin then return false end
        pin = Private.CreateTexturePin(self.parent, 24, 24)
        pin.BattleMapsTempleOwnedPreview = true
        self.templeTestCarriedOrbOwnedPin = pin
    end
    self.templeTestCarriedOrbPin = pin

    -- PreviewPins can rebuild its generic carried marker from several Test-mode
    -- refresh paths. Hide it on every controller tick and after every dummy
    -- refresh; the owned marker below is the only carried orb that remains.
    HideLegacyKotmoguDummyCarriedPins(self, pin)

    if IsEyeOfTheStormMap(mapID) then
        local hasAwayPosition = false
        local hasCenterPosition = false
        for _, flagInfo in ipairs(visibleFlags) do
            if IsNearEotSCenter(flagInfo.x, flagInfo.y) then
                hasCenterPosition = true
            else
                hasAwayPosition = true
            end
        end

        -- The flag-position API is authoritative for whether the central
        -- stationary flag should exist. It can briefly expose both the old
        -- centre position and the live carrier position during pickup; any
        -- away position wins so the two textures are never drawn together.
        if hasAwayPosition then
            self:SetEotSFlagAwayFromCenter(true, "flag-position")
        elseif hasCenterPosition then
            self:SetEotSFlagAwayFromCenter(false, "flag-position")
        end
    end

    local pinConfig = BattleMaps.Database and BattleMaps.Database.GetFlagConfig
        and BattleMaps.Database:GetFlagConfig(mapID)
        or {}
    local baseScale = BattleMaps.Clamp(
        tonumber(pinConfig.carrierObjectivePinScale)
            or tonumber(pinConfig.objectivePinScale)
            or 1,
        0.5,
        2.5
    )
    local pinScale = baseScale * self:GetPinZoomScale()
    pin:SetSize(24 * pinScale, 24 * pinScale)
    if self.parent then
        pin:SetFrameLevel(self.parent:GetFrameLevel() + (self.FLAG_PIN_FRAME_LEVEL_OFFSET or 59))
    end

    local orbKey = GetKotmoguOrbTextureKey(KOTMOGU_TEST_CARRIED_COLOR)
    local texturePath = Rules.GetTempleOrbTexturePath
        and Rules.GetTempleOrbTexturePath(mapID, "carried", KOTMOGU_TEST_CARRIED_COLOR)
        or nil

    -- The colour is known in Test mode. Prefer the exact blue file and only
    -- fall back to the generic resolver for older texture layouts.
    if (type(texturePath) ~= "string" or texturePath == "") and self.FindObjectiveTexture then
        local ok, resolved = pcall(
            self.FindObjectiveTexture,
            self,
            mapID,
            "carried",
            { orbKey, KOTMOGU_TEST_CARRIED_COLOR .. "_orb", KOTMOGU_TEST_CARRIED_COLOR },
            nil
        )
        if ok then texturePath = resolved end
    end
    if (type(texturePath) ~= "string" or texturePath == "") and Private.GetCarriedObjectiveTexture then
        texturePath = Private.GetCarriedObjectiveTexture(
            self,
            mapID,
            KOTMOGU_TEST_CARRIED_INDEX,
            orbKey,
            orbKey
        )
    end
    if type(texturePath) ~= "string" or texturePath == "" then
        return false
    end

    if pin.texture.SetAtlas then pcall(pin.texture.SetAtlas, pin.texture, nil) end
    pin.texture:SetTexture(texturePath)
    pin.texture:SetTexCoord(0, 1, 0, 1)
    local testCarrierFaction = GetOpposingFaction(GetPlayerEffectiveFaction(self)) or "horde"
    local testSettings = GetObjectiveSettings(mapID) or {}
    local tintTestOrb = testSettings.factionColorEnemyKotmoguOrbs ~= false
    local tintR, tintG, tintB = 1, 1, 1
    if tintTestOrb then
        tintR, tintG, tintB = GetObjectiveFactionColor(testCarrierFaction)
    end
    if pin.texture.SetDesaturated then
        pin.texture:SetDesaturated(tintTestOrb)
    end
    pin.texture:SetVertexColor(tintR, tintG, tintB, 1)
    pin.texture:SetAlpha(1)
    pin.texture:SetBlendMode("BLEND")
    pin.texture:SetRotation(0)
    pin.BattleMapsObjectiveTexturePath = texturePath
    pin.BattleMapsObjectiveMapID = mapID
    pin.BattleMapsObjectiveOrbColor = KOTMOGU_TEST_CARRIED_COLOR
    pin.BattleMapsObjectiveCarrierFaction = testCarrierFaction
    pin.BattleMapsObjectiveDesaturated = tintTestOrb
    pin.BattleMapsObjectiveTintR = tintR
    pin.BattleMapsObjectiveTintG = tintG
    pin.BattleMapsObjectiveTintB = tintB

    if Private.SetTooltip then
        Private.SetTooltip(pin, "Blue orb carrier (test)")
    end

    local now = type(GetTime) == "function" and GetTime() or 0
    local phase = ((now % 8.0) / 8.0) * (math.pi * 2)
    local x = 0.50 + (math.cos(phase) * 0.115)
    local y = 0.53 + (math.sin(phase) * 0.082)
    self:Place(pin, x, y)
    pin:Show()
    self.flagTrailFlashSourceByIndex = self.flagTrailFlashSourceByIndex or {}
    self.flagTrailFlashSourceByIndex[KOTMOGU_TEST_CARRIED_INDEX] = pin

    local firstActivation = self.templeTestCarriedOrbPreviewActive ~= true
    self.templeTestCarriedOrbPreviewActive = true

    -- The stationary set only changes when the preview begins or is restored.
    -- Reapplying it every movement tick needlessly rebuilds textures and can
    -- compete with the normal dummy refresh path.
    if firstActivation and self.SetTempleActiveCarriedOrbColors then
        self:SetTempleActiveCarriedOrbColors(mapID, {
            [KOTMOGU_TEST_CARRIED_COLOR] = true,
        })
    end

    if firstActivation and self.ApplyCarriedObjectiveFlash then
        self:ApplyCarriedObjectiveFlash(pin)
    end

    if self.RecordFlagCarrierTrailPoint then
        local color = KOTMOGU_ORB_TRAIL_COLORS[KOTMOGU_TEST_CARRIED_COLOR]
        self:RecordFlagCarrierTrailPoint(
            KOTMOGU_TEST_CARRIED_INDEX, mapID, x, y,
            testCarrierFaction, pinScale,
            color and color[1], color and color[2], color and color[3],
            KOTMOGU_TEST_CARRIED_COLOR
        )

        -- Record positions here, but let the single shared trail controller
        -- perform the render pass. The previous explicit render plus the
        -- controller render produced two unsynchronised rebuilds per update,
        -- which was visible as rapid flashing. Render once immediately when
        -- the preview starts so the first segment does not wait for a tick.
        if firstActivation and self.RenderFlagCarrierTrails then
            self:RenderFlagCarrierTrails(KOTMOGU_TEST_CARRIED_INDEX, true)
        end
    end

    if not fromController then
        local controller = self:EnsureTempleTestCarriedOrbController()
        controller:Show()
    end
    return true
end

function Pins:RefreshFlags()
    if self:ShouldShowDummyPins() then
        self:RefreshDummyPins()
        local mapID = BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID
        if IsTempleOfKotmoguMap(mapID) then
            self:RefreshTempleTestCarriedOrbPreview(mapID)
        else
            self:HideTempleTestCarriedOrbPreview()
        end
        return
    end
    self:HideTempleTestCarriedOrbPreview()
    self:HideDummyPins()

    local mapID = BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID
    local objectiveCategoryEnabled = Private.ObjectiveCategoryEnabled
    local hidePinCollection = Private.HidePinCollection

    if not mapID
        or not objectiveCategoryEnabled
        or not objectiveCategoryEnabled(mapID, "carried")
        or type(GetNumBattlefieldFlagPositions) ~= "function"
        or not C_PvP or not C_PvP.GetBattlefieldFlagPosition then
        if hidePinCollection then
            hidePinCollection(self.flagPins)
        end
        if self.ClearFlagCarrierTrails then
            self:ClearFlagCarrierTrails()
        end
        return
    end

    local resolveObjectiveAPIMapID = Private.ResolveObjectiveAPIMapID
    local inferObjectiveState = Private.InferObjectiveState
    local getCarriedObjectiveTexture = Private.GetCarriedObjectiveTexture
    local isCaptureTheFlagMap = Private.IsCaptureTheFlagMap
    local setTooltip = Private.SetTooltip

    local apiMapID = resolveObjectiveAPIMapID and resolveObjectiveAPIMapID(mapID) or mapID
    local count = tonumber(GetNumBattlefieldFlagPositions()) or 0
    local visibleFlags = {}
    for index = 1, count do
        local ok, x, y, texture = pcall(C_PvP.GetBattlefieldFlagPosition, index, apiMapID)
        if ok and x and y then
            visibleFlags[#visibleFlags + 1] = {
                index = index,
                x = x,
                y = y,
                texture = texture,
            }
            if texture and not self.previewFlagTextures[mapID] then
                self.previewFlagTextures[mapID] = texture
            end
        end
    end

    local pinConfig = BattleMaps.Database and BattleMaps.Database.GetFlagConfig
        and BattleMaps.Database:GetFlagConfig(mapID)
        or {}
    local baseScale = BattleMaps.Clamp(
        tonumber(pinConfig.carrierObjectivePinScale)
            or tonumber(pinConfig.objectivePinScale)
            or 1,
        0.5,
        2.5
    )
    local pinScale = baseScale * self:GetPinZoomScale()
    local used = 0
    local maxFlagIndex = 0
    local isKotmogu = IsTempleOfKotmoguMap(mapID)
    local playerEffectiveFaction = isKotmogu and GetPlayerEffectiveFaction(self) or nil
    local activeKotmoguOrbColors = isKotmogu and {} or nil
    local messageKotmoguOrbColors = isKotmogu
        and self.GetTempleMessageActiveOrbColors
        and self:GetTempleMessageActiveOrbColors(mapID)
        or {}
    local knownKotmoguOrbMessageColors = isKotmogu
        and type(self.templeOrbMessageKnownByColor) == "table"
        and self.templeOrbMessageKnownByColor
        or {}
    local assignedKotmoguOrbColors = {}

    if isKotmogu then
        -- Resolve explicit colour-bearing texture/token data first. Blizzard's
        -- visible flag list is compact, so slot 1 is not necessarily purple.
        for _, flagInfo in ipairs(visibleFlags) do
            local index = flagInfo.index
            local legacyToken = GetLegacyBattlefieldFlagToken(index)
            local carriedState = inferObjectiveState
                and inferObjectiveState(flagInfo.texture, legacyToken) or nil
            local explicit = ExtractKotmoguOrbColor(
                flagInfo.texture, legacyToken, carriedState
            )
            local messageSaysReturned = explicit
                and knownKotmoguOrbMessageColors[explicit] == true
                and messageKotmoguOrbColors[explicit] ~= true
            if explicit and not messageSaysReturned
                and not (self.IsTempleOrbCarriedSuppressed
                    and self:IsTempleOrbCarriedSuppressed(mapID, explicit)) then
                flagInfo.kotmoguOrbColor = RememberKotmoguOrbColor(
                    self, mapID, index, explicit
                )
                assignedKotmoguOrbColors[explicit] = true
            elseif explicit then
                -- The flag APIs can retain an old compact slot after the orb
                -- has returned. Never let that stale token override a
                -- colour-specific return notification.
                flagInfo.kotmoguOrbSuppressed = true
            end
        end

        -- Blizzard compacts/reorders the returned flag slots whenever another
        -- orb is picked up. Never carry a colour forward by raw slot index: in
        -- a 1->2->3->4 pickup sequence that makes the existing colours jump to
        -- different players and can suppress them as false teleports. Match
        -- existing colours to their previous map positions instead.
        AssignKotmoguColorsByContinuity(
            self, mapID, visibleFlags, messageKotmoguOrbColors, assignedKotmoguOrbColors
        )

        -- If several pickups happen between two 0.2-second flag refreshes there
        -- may be more than one new colour with no motion history yet. A fresh
        -- pickup must still be close to its fixed orb pad, so use that geometry
        -- as a second stable identity source before considering any fallback.
        AssignKotmoguColorsByRecentPickup(
            self, mapID, visibleFlags, messageKotmoguOrbColors, assignedKotmoguOrbColors
        )

        -- Colour-specific system messages are authoritative when the API token
        -- is generic. At this point use them only when exactly one unresolved
        -- active colour remains; assigning an arbitrary colour while two or more
        -- are unresolved would reintroduce the compact-slot swap bug.
        for _, flagInfo in ipairs(visibleFlags) do
            if not flagInfo.kotmoguOrbColor then
                local candidate
                for _, color in ipairs(KOTMOGU_ORB_COLORS) do
                    if messageKotmoguOrbColors[color]
                        and not assignedKotmoguOrbColors[color]
                        and not (self.IsTempleOrbCarriedSuppressed
                            and self:IsTempleOrbCarriedSuppressed(mapID, color)) then
                        if candidate then
                            candidate = nil
                            break
                        end
                        candidate = color
                    end
                end
                if candidate then
                    AssignKotmoguColor(
                        flagInfo, candidate, self, mapID, assignedKotmoguOrbColors
                    )
                end
            end
        end

        -- Last-resort compatibility for reloads where a colour has no message
        -- history in this session. A colour that has received a return message
        -- is known inactive even when the active-message table is empty; raw
        -- compact-slot fallback must never resurrect it.
        for _, flagInfo in ipairs(visibleFlags) do
            if not flagInfo.kotmoguOrbColor then
                local fallback = GetKotmoguOrbColor(flagInfo.index)
                local messageKnowsColor = fallback
                    and knownKotmoguOrbMessageColors[fallback] == true
                if fallback and not messageKnowsColor
                    and not assignedKotmoguOrbColors[fallback]
                    and not (self.IsTempleOrbCarriedSuppressed
                        and self:IsTempleOrbCarriedSuppressed(mapID, fallback)) then
                    AssignKotmoguColor(
                        flagInfo, fallback, self, mapID, assignedKotmoguOrbColors
                    )
                end
            end
        end
    end

    -- This count means visible/renderable carried positions, not raw API slots.
    -- In Blitz CTF an enemy carrier can exist without a map location; treating
    -- that hidden API slot as visible lets its message state recolour the
    -- still-visible friendly carrier.
    self.BattleMapsRawCarriedFlagCount = count
    self.BattleMapsActiveCarriedFlagCount = #visibleFlags

    for _, flagInfo in ipairs(visibleFlags) do
        local index = flagInfo.index
        local x = flagInfo.x
        local y = flagInfo.y
        local texture = flagInfo.texture
        local legacyToken = GetLegacyBattlefieldFlagToken(index)
        local carriedState = inferObjectiveState and inferObjectiveState(texture, legacyToken) or nil
        local kotmoguOrbColor = isKotmogu and flagInfo.kotmoguOrbColor or nil
        local suppressKotmoguCarrier = false
        if isKotmogu then
            suppressKotmoguCarrier = flagInfo.kotmoguOrbSuppressed == true
                or not kotmoguOrbColor
                or (self.IsTempleOrbCarriedSuppressed
                    and self:IsTempleOrbCarriedSuppressed(mapID, kotmoguOrbColor))
            local matchedCarrierDead = kotmoguOrbColor
                and IsFriendlyKotmoguCarrierDead(self, apiMapID, x, y)
            -- Keep the per-colour motion history current for the next compact
            -- slot matching pass. A large movement is no longer itself grounds
            -- for suppressing the orb: legitimate movement abilities and, more
            -- importantly, Blizzard's slot reordering could previously make a
            -- healthy carrier disappear for ten seconds.
            if kotmoguOrbColor then
                UpdateKotmoguCarrierMotion(self, mapID, kotmoguOrbColor, x, y)
            end
            suppressKotmoguCarrier = suppressKotmoguCarrier
                or matchedCarrierDead == true
            if suppressKotmoguCarrier then
                if matchedCarrierDead and self.SuppressTempleCarriedOrbColor then
                    self:SuppressTempleCarriedOrbColor(mapID, kotmoguOrbColor, 10)
                elseif kotmoguOrbColor and self.ClearTempleCarriedOrbVisual then
                    self:ClearTempleCarriedOrbVisual(kotmoguOrbColor)
                end
            else
                activeKotmoguOrbColors[kotmoguOrbColor] = true
            end
        end

        if not suppressKotmoguCarrier then
        used = used + 1
        local stableObjectiveIndex = kotmoguOrbColor
            and KOTMOGU_ORB_INDEX_BY_COLOR[kotmoguOrbColor]
            or tonumber(index)
            or used
        maxFlagIndex = math.max(maxFlagIndex, stableObjectiveIndex)
        local pin = self:GetFlagPin(used)
        if pin then
            pin:SetSize(24 * pinScale, 24 * pinScale)

            local flagObjectFaction = self:ResolveCarriedObjectiveFaction(mapID, texture, carriedState, index, x, y, legacyToken)
            flagObjectFaction = ResolveEotSCarrierFaction(self, mapID, apiMapID, index, x, y, texture, carriedState, legacyToken, flagObjectFaction)
            local kotmoguCarrierFaction = kotmoguOrbColor
                and self.GetTempleOrbCarrierFaction
                and self:GetTempleOrbCarrierFaction(mapID, kotmoguOrbColor)
                or nil
            local carrierFaction = kotmoguCarrierFaction or flagObjectFaction
            local isCTF = isCaptureTheFlagMap and isCaptureTheFlagMap(mapID)
            local allowCarriedEffects = not isCTF
                or ShouldRunCTFCarriedEffects(self, mapID, index, x, y, flagObjectFaction)
            if isCTF and not allowCarriedEffects and flagObjectFaction
                and self.RememberCTFFlagBasePosition then
                self:RememberCTFFlagBasePosition(mapID, flagObjectFaction, x, y)
            end

            -- For WSG/Twin Peaks-style CTF maps, never let a neutral or
            -- unknown inferred state select the generic custom carried flag
            -- (flag.tga). If BattleMaps cannot prove whether the object is
            -- the Alliance or Horde flag, preserve Blizzard's own coloured
            -- carried-flag texture instead of replacing it with a white
            -- neutral custom texture.
            local customState = flagObjectFaction or carriedState
            if isCTF and not flagObjectFaction then
                customState = nil
            end

            local customCarried
            if kotmoguOrbColor then
                customCarried = Rules.GetTempleOrbTexturePath
                    and Rules.GetTempleOrbTexturePath(mapID, "carried", kotmoguOrbColor)
                    or nil
                if (type(customCarried) ~= "string" or customCarried == "")
                    and getCarriedObjectiveTexture then
                    local orbKey = GetKotmoguOrbTextureKey(kotmoguOrbColor)
                    customCarried = getCarriedObjectiveTexture(self, mapID, index, orbKey, nil)
                        or getCarriedObjectiveTexture(self, mapID, index, orbKey, orbKey)
                end
            elseif getCarriedObjectiveTexture and (not isCTF or flagObjectFaction) then
                customCarried = getCarriedObjectiveTexture(
                    self, mapID, index, texture or legacyToken, customState
                )
            end

            -- Breadcrumbs and Glow wake preserve objective colour. Spawn
            -- tether uses carrier faction for Kotmogu and flag-object faction
            -- for CTF maps, so its colour matches the fixed origin it points to.
            local trailFaction = carrierFaction
                or ResolveTrailFactionFromRenderedFlag(
                    customCarried,
                    carriedState,
                    texture,
                    legacyToken
                )
            local trailR, trailG, trailB
            if kotmoguOrbColor then
                local color = KOTMOGU_ORB_TRAIL_COLORS[kotmoguOrbColor]
                if color then trailR, trailG, trailB = color[1], color[2], color[3] end
            end

            pin.BattleMapsObjectiveFaction = flagObjectFaction
            pin.BattleMapsObjectiveCarrierFaction = carrierFaction or trailFaction
            pin.BattleMapsObjectiveOrbColor = kotmoguOrbColor
            pin.BattleMapsObjectiveMapID = mapID
            pin.BattleMapsObjectiveTexturePath = customCarried or texture or legacyToken or FALLBACK_CARRIED_FLAG_TEXTURE
            pin.BattleMapsPreviewTexturePath = nil
            pin.BattleMapsPreviewAtlas = nil
            pin.BattleMapsPreviewUsesAtlas = nil
            if pin.texture.SetAtlas then
                pcall(pin.texture.SetAtlas, pin.texture, nil)
            end
            pin.texture:SetTexture(pin.BattleMapsObjectiveTexturePath)
            pin.texture:SetTexCoord(0, 1, 0, 1)

            local settings = GetObjectiveSettings(mapID) or {}
            local tintEnemyOrb = kotmoguOrbColor
                and settings.factionColorEnemyKotmoguOrbs ~= false
                and carrierFaction
                and playerEffectiveFaction
                and carrierFaction ~= playerEffectiveFaction
            local tintR, tintG, tintB = 1, 1, 1
            if tintEnemyOrb then
                tintR, tintG, tintB = GetObjectiveFactionColor(carrierFaction)
            end
            if pin.texture.SetDesaturated then
                pin.texture:SetDesaturated(tintEnemyOrb == true)
            end
            pin.texture:SetVertexColor(tintR, tintG, tintB, 1)
            pin.BattleMapsObjectiveDesaturated = tintEnemyOrb == true
            pin.BattleMapsObjectiveTintR = tintR
            pin.BattleMapsObjectiveTintG = tintG
            pin.BattleMapsObjectiveTintB = tintB
            pin.texture:SetAlpha(1)
            pin.texture:SetBlendMode("BLEND")
            pin.texture:SetRotation(0)
            if setTooltip then
                if kotmoguOrbColor then
                    local label = kotmoguOrbColor:sub(1, 1):upper() .. kotmoguOrbColor:sub(2)
                    setTooltip(pin, label .. " orb carrier")
                else
                    setTooltip(pin, flagObjectFaction and ("Battleground objective: " .. flagObjectFaction .. " flag") or "Battleground objective")
                end
            end
            self:Place(pin, x, y)
            self.flagTrailFlashSourceByIndex = self.flagTrailFlashSourceByIndex or {}
            self.flagTrailFlashSourceByIndex[stableObjectiveIndex] = pin

            if self.ApplyCarriedObjectiveFlash then
                if allowCarriedEffects then
                    self:ApplyCarriedObjectiveFlash(pin)
                elseif self.StopCarriedObjectiveFlash then
                    self:StopCarriedObjectiveFlash(pin)
                end
            end
            if allowCarriedEffects and self.RecordFlagCarrierTrailPoint then
                -- Key trail history by Blizzard's flag slot rather than the
                -- compact rendered-pin index. This keeps the two CTF trails
                -- separate and preserves trails for friendly carriers even if
                -- the visible carried flag pin is later suppressed/reused.
                self:RecordFlagCarrierTrailPoint(stableObjectiveIndex, mapID, x, y, carrierFaction or trailFaction, pinScale, trailR, trailG, trailB, kotmoguOrbColor)
            end
        end
        end
    end

    for index = used + 1, #(self.flagPins or {}) do
        local pin = self.flagPins[index]
        if pin then
            if self.StopCarriedObjectiveFlash then
                self:StopCarriedObjectiveFlash(pin)
            end
            pin.BattleMapsObjectiveFaction = nil
            pin.BattleMapsObjectiveCarrierFaction = nil
            pin.BattleMapsObjectiveOrbColor = nil
            pin.BattleMapsObjectiveDesaturated = nil
            pin.BattleMapsObjectiveTintR = nil
            pin.BattleMapsObjectiveTintG = nil
            pin.BattleMapsObjectiveTintB = nil
            if pin.texture and pin.texture.SetDesaturated then
                pin.texture:SetDesaturated(false)
            end
            pin:Hide()
        end
    end

    if isKotmogu and self.SetTempleActiveCarriedOrbColors then
        self:SetTempleActiveCarriedOrbColors(mapID, activeKotmoguOrbColors)
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID == mapID
                    and self.ApplyTempleOrbStationaryState then
                    self:ApplyTempleOrbStationaryState(mapID)
                end
            end)
        end
    end

    local trailNow = type(GetTime) == "function" and GetTime() or 0
    if used > 0 then
        self.flagTrailLastCarrierSeenAt = trailNow
        self.flagTrailNoCarrierSince = nil
        self.flagTrailActiveCount = maxFlagIndex > 0 and maxFlagIndex or used
        if self.RenderFlagCarrierTrails then
            self:RenderFlagCarrierTrails(self.flagTrailActiveCount)
        end
    else
        -- Blizzard can briefly return zero positioned flag slots during an API
        -- refresh. Keep the existing path for a short grace period instead of
        -- clearing and recreating it, which caused constant on/off flicker.
        self.flagTrailNoCarrierSince = self.flagTrailNoCarrierSince or trailNow
        local activeCount = tonumber(self.flagTrailActiveCount)
        if activeCount and activeCount > 0
            and (trailNow - self.flagTrailNoCarrierSince) <= FLAG_TRAIL_TRANSIENT_MISSING_GRACE then
            self:EnsureFlagTrailController():Show()
            if self.RenderFlagCarrierTrails then
                self:RenderFlagCarrierTrails(activeCount, true)
            end
        elseif self.ClearFlagCarrierTrails then
            self:ClearFlagCarrierTrails()
        end
    end

    self.BattleMapsActiveCarriedFlagCount = nil
    self.BattleMapsRawCarriedFlagCount = nil
end

-- Carried-objective trail -------------------------------------------------
--
-- Paths are stored in normalized map coordinates, simplified into a small set
-- of anchors, and rendered through a bounded, lazily-created pool. Breadcrumbs
-- are discrete markers, Glow wake is tapered, and Kotmogu Spawn tether uses one
-- faction-coloured line from the fixed orb pad to the live carrier.

local FLAG_TRAIL_FRAME_LEVEL_OFFSET = 58
local FLAG_TRAIL_MAX_TOTAL_POINTS = 96
local FLAG_TRAIL_DEFAULT_POINTS_PER_CARRIER = 16
local FLAG_TRAIL_MAX_KEYFRAMES = 48
local FLAG_TRAIL_DEFAULT_MAX_AGE = 12.00
local FLAG_TRAIL_RENDER_INTERVAL = 0.10
local FLAG_TRAIL_MIN_MOVE_PIXELS = 1.25
local FLAG_TRAIL_TURN_MOVE_PIXELS = 2.50
local FLAG_TRAIL_TURN_DOT_THRESHOLD = 0.955
local FLAG_TRAIL_MAX_SEGMENT_PIXELS = 10.00
local FLAG_TRAIL_TEXTURE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local FLAG_TRAIL_STYLE_BREADCRUMBS = "breadcrumbs"
local FLAG_TRAIL_STYLE_GLOW = "glow"
local FLAG_TRAIL_STYLE_TETHER = "tether"

local DUMMY_CARRIED_POSITION = { 0.50, 0.78 }

local function SafeNormalize(value)
    local ok, text = pcall(tostring, value or "")
    if not ok or type(text) ~= "string" then return "" end
    ok, text = pcall(string.lower, text)
    if not ok or type(text) ~= "string" then return "" end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("[^%w]+", "_")
    text = text:gsub("^_+", ""):gsub("_+$", "")
    return text
end

GetObjectiveFactionColor = function(faction)
    faction = SafeNormalize(faction)
    local color = faction == "alliance" and BattleMaps.COLORS.alliance
        or faction == "horde" and BattleMaps.COLORS.horde
        or BattleMaps.COLORS.neutral
    return color[1] or 1, color[2] or 1, color[3] or 1
end

GetObjectiveSettings = function(mapID)
    mapID = tonumber(mapID)
        or tonumber(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    if BattleMaps.Database and BattleMaps.Database.GetFlagConfig then
        return BattleMaps.Database:GetFlagConfig(mapID)
    end
    return BattleMaps.Database and BattleMaps.Database:Get() or nil
end

local function GetCarriedTrailDuration(mapID)
    local db = GetObjectiveSettings(mapID)
    return BattleMaps.Clamp(tonumber(db and db.carriedTrailDuration) or FLAG_TRAIL_DEFAULT_MAX_AGE, 1.00, 30.00)
end

local function GetCarriedTrailDotScale(mapID)
    local db = GetObjectiveSettings(mapID)
    return BattleMaps.Clamp(tonumber(db and db.carriedTrailDotScale) or 0.70, 0.20, 3.00)
end

local function GetCarriedTrailDetail(mapID)
    local db = GetObjectiveSettings(mapID)
    return math.floor(BattleMaps.Clamp(
        tonumber(db and db.carriedTrailDetail) or FLAG_TRAIL_DEFAULT_POINTS_PER_CARRIER,
        4,
        24
    ) + 0.5)
end

local function GetCarriedTrailStyle(mapID)
    local db = GetObjectiveSettings(mapID)
    local style = db and db.carriedTrailStyle
    if style == FLAG_TRAIL_STYLE_GLOW then return FLAG_TRAIL_STYLE_GLOW end
    if style == FLAG_TRAIL_STYLE_TETHER then
        return IsTempleOfKotmoguMap(mapID)
            and FLAG_TRAIL_STYLE_TETHER
            or FLAG_TRAIL_STYLE_GLOW
    end
    return FLAG_TRAIL_STYLE_BREADCRUMBS
end

-- The trail and carried-objective overlay share the same flash settings.
-- Keeping this pulse helper above both renderers lets the trail reuse the exact
-- configured period and strength without introducing another option family.
local CARRIED_OBJECTIVE_FLASH_DEFAULT_PERIOD = 0.72
local CARRIED_OBJECTIVE_FLASH_MIN_BRIGHTNESS = 0.10
local CARRIED_OBJECTIVE_FLASH_DEFAULT_STRENGTH = 0.88

local function GetCarriedObjectiveFlashPeriod(mapID)
    local db = GetObjectiveSettings(mapID)
    return BattleMaps.Clamp(tonumber(db and db.carriedObjectiveFlashPeriod) or CARRIED_OBJECTIVE_FLASH_DEFAULT_PERIOD, 0.30, 2.00)
end

local function GetCarriedObjectiveFlashStrength(mapID)
    local db = GetObjectiveSettings(mapID)
    return BattleMaps.Clamp(tonumber(db and db.carriedObjectiveFlashStrength) or CARRIED_OBJECTIVE_FLASH_DEFAULT_STRENGTH, 0.10, 1.00)
end

local function GetCarriedObjectiveFlashBrightness(mapID)
    local db = GetObjectiveSettings(mapID)
    if not db or db.flashCarriedObjectives ~= true then return nil end

    local now = type(GetTime) == "function" and GetTime() or 0
    local period = GetCarriedObjectiveFlashPeriod(mapID)
    local strength = GetCarriedObjectiveFlashStrength(mapID)
    local phase = (now / period) * (math.pi * 2)
    local wave = (math.sin(phase) + 1) * 0.5
    local flash = wave * wave * wave
    return CARRIED_OBJECTIVE_FLASH_MIN_BRIGHTNESS
        + ((strength - CARRIED_OBJECTIVE_FLASH_MIN_BRIGHTNESS) * flash)
end

local function GetTrailCanvasSize(pins)
    local canvas = BattleMaps.MapFrame and BattleMaps.MapFrame.canvas
    local width, height = canvas and canvas:GetSize()
    width = tonumber(width) or 1
    height = tonumber(height) or 1
    if width <= 0 then width = 1 end
    if height <= 0 then height = 1 end

    -- The viewport can magnify normalized map distances without changing the
    -- canvas frame's physical size. GetPinZoomScale follows the same live zoom
    -- transform used by the pin renderer, so use it for spacing calculations.
    local zoom = pins and pins.GetPinZoomScale and tonumber(pins:GetPinZoomScale()) or 1
    zoom = BattleMaps.Clamp(zoom or 1, 0.25, 6)
    return width * zoom, height * zoom
end

local function PixelVector(ax, ay, bx, by, width, height)
    return ((tonumber(bx) or 0) - (tonumber(ax) or 0)) * width,
        ((tonumber(by) or 0) - (tonumber(ay) or 0)) * height
end

local function PixelDistance(ax, ay, bx, by, width, height)
    local dx, dy = PixelVector(ax, ay, bx, by, width, height)
    return math.sqrt((dx * dx) + (dy * dy))
end

local function PreferDefined(value, fallback)
    return value ~= nil and value or fallback
end

local function InterpolateTrailPoint(older, newer, fraction, forcedTime)
    fraction = BattleMaps.Clamp(tonumber(fraction) or 0, 0, 1)
    return {
        x = (tonumber(older.x) or 0) + (((tonumber(newer.x) or 0) - (tonumber(older.x) or 0)) * fraction),
        y = (tonumber(older.y) or 0) + (((tonumber(newer.y) or 0) - (tonumber(older.y) or 0)) * fraction),
        time = forcedTime or ((tonumber(older.time) or 0) + (((tonumber(newer.time) or 0) - (tonumber(older.time) or 0)) * fraction)),
        faction = PreferDefined(newer.faction, older.faction),
        pinScale = PreferDefined(newer.pinScale, older.pinScale),
        mapID = PreferDefined(newer.mapID, older.mapID),
        r = PreferDefined(newer.r, older.r),
        g = PreferDefined(newer.g, older.g),
        b = PreferDefined(newer.b, older.b),
        colorKey = PreferDefined(newer.colorKey, older.colorKey),
    }
end

local function TrimTrailHistory(history, now, duration)
    if type(history) ~= "table" then return end
    local cutoff = now - duration

    if history.live and (tonumber(history.live.time) or 0) < cutoff then
        history.live = nil
    end

    while #history >= 2 and (tonumber(history[2].time) or 0) <= cutoff do
        table.remove(history, 1)
    end

    if #history >= 2 then
        local older, newer = history[1], history[2]
        local olderTime = tonumber(older.time) or 0
        local newerTime = tonumber(newer.time) or olderTime
        if olderTime < cutoff and newerTime > olderTime then
            history[1] = InterpolateTrailPoint(
                older,
                newer,
                (cutoff - olderTime) / (newerTime - olderTime),
                cutoff
            )
        end
    elseif #history == 1 and (tonumber(history[1].time) or 0) < cutoff then
        local live = history.live
        local older = history[1]
        local olderTime = tonumber(older.time) or 0
        local liveTime = tonumber(live and live.time) or olderTime
        if live and liveTime > cutoff and liveTime > olderTime then
            history[1] = InterpolateTrailPoint(
                older,
                live,
                (cutoff - olderTime) / (liveTime - olderTime),
                cutoff
            )
        else
            history[1] = nil
        end
    end
end

local function CreateTrailTexturePin(parent, width, height)
    local pin = CreateFrame("Frame", nil, parent)
    pin:SetSize(width or 10, height or width or 10)
    pin:EnableMouse(false)

    local glow = pin:CreateTexture(nil, "BACKGROUND")
    pin.glowTexture = glow
    glow:SetPoint("CENTER")
    glow:SetBlendMode("ADD")

    local texture = pin:CreateTexture(nil, "ARTWORK")
    pin.texture = texture
    texture:SetPoint("CENTER")
    texture:SetBlendMode("BLEND")

    pin:Hide()
    return pin
end

local function HideFlagTrailFrame(frame)
    if not frame then return end
    if frame.texture then frame.texture:Hide() end
    if frame.glowTexture then frame.glowTexture:Hide() end
    frame:Hide()
end

local function ConfigureFlagTrailDotTexture(frame)
    if not frame or not frame.texture or frame.BattleMapsTrailTextureConfigured then return end
    frame.texture:SetTexture(FLAG_TRAIL_TEXTURE)
    frame.texture:SetTexCoord(0, 1, 0, 1)
    frame.texture:SetRotation(0)
    if frame.glowTexture then
        frame.glowTexture:SetTexture(FLAG_TRAIL_TEXTURE)
        frame.glowTexture:SetTexCoord(0, 1, 0, 1)
        frame.glowTexture:SetRotation(0)
    end
    frame.BattleMapsTrailTextureConfigured = true
end

function Pins:GetFlagTrailFrame(index)
    self.flagTrailFrames = self.flagTrailFrames or {}
    local frame = self.flagTrailFrames[index]
    if not frame then
        frame = CreateTrailTexturePin(self.parent, 10, 10)
        self.flagTrailFrames[index] = frame
    end
    if self.parent and frame.SetFrameLevel then
        frame:SetFrameLevel(self.parent:GetFrameLevel() + FLAG_TRAIL_FRAME_LEVEL_OFFSET)
    end
    return frame
end

function Pins:GetFlagTrailLine(index)
    self.flagTrailLines = self.flagTrailLines or {}
    local pair = self.flagTrailLines[index]
    if pair then return pair end
    if not self.parent or type(self.parent.CreateLine) ~= "function" then return nil end

    local core = self.parent:CreateLine(nil, "ARTWORK", nil, 6)
    core:SetThickness(2)
    if core.SetBlendMode then core:SetBlendMode("ADD") end
    core:Hide()

    pair = { core = core }
    self.flagTrailLines[index] = pair
    return pair
end

local function EnsureFlagTrailGlow(pins, pair)
    if not pins or not pair or pair.glow then return pair and pair.glow or nil end
    if not pins.parent or type(pins.parent.CreateLine) ~= "function" then return nil end
    local glow = pins.parent:CreateLine(nil, "ARTWORK", nil, 5)
    glow:SetThickness(4)
    if glow.SetBlendMode then glow:SetBlendMode("ADD") end
    glow:Hide()
    pair.glow = glow
    return glow
end

function Pins:HideFlagCarrierTrailFrames()
    for _, frame in ipairs(self.flagTrailFrames or {}) do
        HideFlagTrailFrame(frame)
    end
    for _, pair in ipairs(self.flagTrailLines or {}) do
        if pair.glow then pair.glow:Hide() end
        if pair.core then pair.core:Hide() end
    end
end

local function EnsureTrailViewportProbe(pins, key)
    local probe = pins[key]
    if probe then return probe end
    probe = CreateFrame("Frame", nil, pins.parent)
    probe:SetSize(1, 1)
    probe:SetAlpha(0)
    probe:EnableMouse(false)
    probe:Show()
    pins[key] = probe
    return probe
end

local function GetTrailViewportSignature(pins)
    if not pins or not pins.parent or not pins.Place then return "" end
    local first = EnsureTrailViewportProbe(pins, "flagTrailViewportProbeA")
    local second = EnsureTrailViewportProbe(pins, "flagTrailViewportProbeB")
    pins:Place(first, 0.17, 0.21)
    pins:Place(second, 0.83, 0.79)
    local ax, ay = first:GetCenter()
    local bx, by = second:GetCenter()
    local zoom = pins.GetPinZoomScale and pins:GetPinZoomScale() or 1
    return string.format(
        "%.1f:%.1f:%.1f:%.1f:%.3f",
        tonumber(ax) or 0,
        tonumber(ay) or 0,
        tonumber(bx) or 0,
        tonumber(by) or 0,
        tonumber(zoom) or 1
    )
end

function Pins:EnsureFlagTrailController()
    if self.flagTrailController then return self.flagTrailController end
    local controller = CreateFrame("Frame")
    controller:Hide()
    controller.elapsed = 0
    controller:SetScript("OnUpdate", function(frame, elapsed)
        frame.elapsed = (frame.elapsed or 0) + (tonumber(elapsed) or 0)
        if frame.elapsed < FLAG_TRAIL_RENDER_INTERVAL then return end
        frame.elapsed = 0

        local activeCount = tonumber(self.flagTrailActiveCount)
        if not activeCount or activeCount <= 0 then
            frame:Hide()
            return
        end

        local now = type(GetTime) == "function" and GetTime() or 0
        if self.flagTrailNoCarrierSince
            and (now - self.flagTrailNoCarrierSince) > FLAG_TRAIL_TRANSIENT_MISSING_GRACE then
            self:ClearFlagCarrierTrails()
            return
        end

        local signature = GetTrailViewportSignature(self)
        if self.flagTrailDirty
            or signature ~= self.flagTrailViewportSignature
            or now >= (tonumber(self.flagTrailNextFadeRenderAt) or 0) then
            self.flagTrailViewportSignature = signature
            local currentMapID = tonumber(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
            local style = GetCarriedTrailStyle(currentMapID)
            -- Historical trails remain capped at 5 Hz even when carried pins
            -- flash. Spawn tether is only four lines at most, so it can follow
            -- viewport/flash changes at 10 Hz without multiplying a large path.
            self.flagTrailNextFadeRenderAt = now
                + (style == FLAG_TRAIL_STYLE_TETHER and 0.10 or 0.20)
            self:RenderFlagCarrierTrails(activeCount, true)
        end
    end)
    self.flagTrailController = controller
    return controller
end

function Pins:ClearFlagCarrierTrails()
    self.flagTrailHistory = self.flagTrailHistory or {}
    self.flagTrailLastSampleByIndex = self.flagTrailLastSampleByIndex or {}
    wipe(self.flagTrailHistory)
    wipe(self.flagTrailLastSampleByIndex)
    self.flagTrailNextRenderAt = nil
    self.flagTrailDirty = nil
    self.flagTrailActiveCount = nil
    self.flagTrailViewportSignature = nil
    self.flagTrailNoCarrierSince = nil
    self.flagTrailLastCarrierSeenAt = nil
    self.flagTrailNextFadeRenderAt = nil
    if type(self.flagTrailFlashSourceByIndex) == "table" then
        wipe(self.flagTrailFlashSourceByIndex)
    end
    if self.flagTrailController then self.flagTrailController:Hide() end
    self:HideFlagCarrierTrailFrames()
end

function Pins:ClearTempleCarriedOrbVisual(color)
    color = SafeNormalize(color)
    if color == "" then return false end
    local changed = false

    if type(self.templeCarriedOrbColorBySlot) == "table" then
        for key, remembered in pairs(self.templeCarriedOrbColorBySlot) do
            if SafeNormalize(remembered) == color then
                self.templeCarriedOrbColorBySlot[key] = nil
                changed = true
            end
        end
    end
    if type(self.templeCarriedOrbMotionByColor) == "table" then
        for key in pairs(self.templeCarriedOrbMotionByColor) do
            if tostring(key):match(":" .. color .. "$") then
                self.templeCarriedOrbMotionByColor[key] = nil
            end
        end
    end

    for _, pin in ipairs(self.flagPins or {}) do
        if pin and SafeNormalize(pin.BattleMapsObjectiveOrbColor) == color then
            if self.StopCarriedObjectiveFlash then self:StopCarriedObjectiveFlash(pin) end
            pin.BattleMapsObjectiveOrbColor = nil
            pin.BattleMapsObjectiveCarrierFaction = nil
            pin:Hide()
            changed = true
        end
    end

    self.flagTrailHistory = self.flagTrailHistory or {}
    self.flagTrailLastSampleByIndex = self.flagTrailLastSampleByIndex or {}
    for index, history in pairs(self.flagTrailHistory) do
        local matches = false
        if type(history) == "table" then
            if history.live and SafeNormalize(history.live.colorKey) == color then
                matches = true
            else
                for _, point in ipairs(history) do
                    if SafeNormalize(point and point.colorKey) == color then
                        matches = true
                        break
                    end
                end
            end
        end
        if matches then
            self.flagTrailHistory[index] = nil
            self.flagTrailLastSampleByIndex[index] = nil
            changed = true
        end
    end

    if changed then
        self.flagTrailDirty = true
        local active = 0
        for index in pairs(self.flagTrailHistory) do
            active = math.max(active, tonumber(index) or 0)
        end
        self.flagTrailActiveCount = active > 0 and active or nil
        if not self.flagTrailActiveCount then
            self:HideFlagCarrierTrailFrames()
            if self.flagTrailController then self.flagTrailController:Hide() end
        elseif self.RenderFlagCarrierTrails then
            self:RenderFlagCarrierTrails(self.flagTrailActiveCount, true)
        end
    end
    return changed
end

local function GetTrailBaseSize(pins, mapID)
    local flagConfig = GetObjectiveSettings(mapID) or {}
    local carriedScale = BattleMaps.Clamp(
        tonumber(flagConfig.carrierObjectivePinScale)
            or tonumber(flagConfig.objectivePinScale)
            or 1,
        0.50,
        2.50
    )
    local zoomScale = pins and pins.GetPinZoomScale and tonumber(pins:GetPinZoomScale()) or 1
    zoomScale = BattleMaps.Clamp(zoomScale or 1, 0.25, 6.00)
    local carriedPinSize = 24 * carriedScale * zoomScale

    -- Trail size follows the carried objective rather than the unrelated
    -- teammate-pin setting. A slightly stronger base ratio keeps Glow wake
    -- visible at ordinary settings, while the expanded 3.00x option can scale
    -- both the line core and halo without immediately hitting a low hard cap.
    return BattleMaps.Clamp(
        carriedPinSize * 0.22 * GetCarriedTrailDotScale(mapID),
        2.50,
        36.00
    )
end

local function GetTrailFlashLevel(pins, flagIndex, mapID)
    local db = GetObjectiveSettings(mapID)
    if not db or db.flashCarriedObjectives ~= true then return nil end

    -- Prefer the live overlay alpha. This keeps the trail visually locked to
    -- the actual carried-objective flash AnimationGroup rather than running an
    -- independent pulse that can drift out of phase.
    local source = pins and pins.flagTrailFlashSourceByIndex
        and pins.flagTrailFlashSourceByIndex[flagIndex]
    local overlay = source and source.carriedFlashOverlay
    if overlay and overlay.GetAlpha and overlay.IsShown and overlay:IsShown() then
        return BattleMaps.Clamp(tonumber(overlay:GetAlpha()) or 0, 0, 1)
    end

    return GetCarriedObjectiveFlashBrightness(mapID)
end

local function ResolveTrailPointColor(point)
    local r, g, b = tonumber(point and point.r), tonumber(point and point.g), tonumber(point and point.b)
    if r and g and b then return r, g, b end
    local orbColor = KOTMOGU_ORB_TRAIL_COLORS[SafeNormalize(point and point.colorKey)]
    if orbColor then return orbColor[1], orbColor[2], orbColor[3] end
    return GetObjectiveFactionColor(point and point.faction)
end

local function ShowBreadcrumbPoint(pins, frame, point, life, mapID, flashLevel)
    local r, g, b = ResolveTrailPointColor(point)
    local baseSize = GetTrailBaseSize(pins, mapID)
    local taper = BattleMaps.Clamp(tonumber(point and point.taper) or 1, 0, 1)
    local taperShape = 0.30 + (0.70 * (taper ^ 1.45))
    local size = BattleMaps.Clamp(baseSize * (0.46 + (0.48 * taperShape)), 3, 30)
    local glowSize = BattleMaps.Clamp(size * (1.48 + (0.26 * taperShape)), size + 2, 46)
    local coreFlash = flashLevel and (0.66 + (0.78 * flashLevel)) or 1
    local glowFlash = flashLevel and (0.48 + (1.18 * flashLevel)) or 1

    ConfigureFlagTrailDotTexture(frame)
    frame:SetSize(glowSize, glowSize)
    frame.texture:ClearAllPoints()
    frame.texture:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.texture:SetSize(size, size)
    frame.texture:SetBlendMode("BLEND")
    frame.texture:SetVertexColor(r, g, b, 1)
    frame.texture:SetAlpha(BattleMaps.Clamp((0.24 + (0.70 * life)) * taperShape * coreFlash, 0.12, 0.98))
    frame.texture:Show()

    if frame.glowTexture then
        frame.glowTexture:ClearAllPoints()
        frame.glowTexture:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.glowTexture:SetSize(glowSize, glowSize)
        frame.glowTexture:SetBlendMode("ADD")
        frame.glowTexture:SetVertexColor(r, g, b, 1)
        frame.glowTexture:SetAlpha(BattleMaps.Clamp((0.04 + (0.22 * life)) * taperShape * glowFlash, 0.02, 0.36))
        frame.glowTexture:Show()
    end
    pins:Place(frame, point.x, point.y)
    frame:Show()
end

local function ShowTrailAnchor(pins, frame, point)
    if frame.texture then frame.texture:Hide() end
    if frame.glowTexture then frame.glowTexture:Hide() end
    frame:SetSize(1, 1)
    pins:Place(frame, point.x, point.y)
    frame:Show()
end

local function ConfigureTrailLine(pair, startFrame, endFrame, point, life, taper, mapID, style, pins, flashLevel)
    if style ~= FLAG_TRAIL_STYLE_GLOW or not pair or not pair.core then return false end
    if pair.glow then pair.glow:Hide() end
    local r, g, b = ResolveTrailPointColor(point)
    local baseSize = GetTrailBaseSize(pins, mapID)
    life = BattleMaps.Clamp(tonumber(life) or 0, 0, 1)
    taper = BattleMaps.Clamp(tonumber(taper) or life, 0, 1)

    local coreFlash = flashLevel and (0.66 + (0.78 * flashLevel)) or 1
    local thicknessFlash = flashLevel and (0.94 + (0.12 * flashLevel)) or 1

    -- One additive tapered line only. The former wider halo line was removed
    -- because it softened the wake into a broad translucent band.
    local taperShape = taper ^ 1.55
    local ageFade = 0.58 + (0.42 * life)
    local coreThickness = BattleMaps.Clamp(
        baseSize * (0.18 + (0.72 * taperShape)) * thicknessFlash,
        1.35,
        16.0
    )
    local coreAlpha = BattleMaps.Clamp(
        (0.14 + (0.90 * taperShape)) * ageFade * coreFlash,
        0.06,
        1.00
    )

    pair.core:ClearAllPoints()
    pair.core:SetStartPoint("CENTER", startFrame, 0, 0)
    pair.core:SetEndPoint("CENTER", endFrame, 0, 0)
    pair.core:SetThickness(coreThickness)
    if pair.core.SetBlendMode then pair.core:SetBlendMode("ADD") end
    pair.core:SetColorTexture(r, g, b, coreAlpha)
    pair.core:Show()
    return true
end

local function ConfigureSpawnTetherLine(pair, startFrame, endFrame, point, mapID, pins, flashLevel)
    if not pair or not pair.core then return false end
    local faction = NormalizeTrailFactionValue(point and point.faction)
    local r, g, b = GetObjectiveFactionColor(faction)
    local baseSize = GetTrailBaseSize(pins, mapID)
    local glow = EnsureFlagTrailGlow(pins, pair)
    local pulse = flashLevel and (0.86 + (0.28 * flashLevel)) or 1
    local thickness = BattleMaps.Clamp(baseSize * 0.42, 1.75, 12.0)
    local alpha = BattleMaps.Clamp(0.52 * pulse, 0.38, 0.82)

    if glow then
        glow:ClearAllPoints()
        glow:SetStartPoint("CENTER", startFrame, 0, 0)
        glow:SetEndPoint("CENTER", endFrame, 0, 0)
        glow:SetThickness(BattleMaps.Clamp(thickness * 2.35, thickness + 2, 26))
        if glow.SetBlendMode then glow:SetBlendMode("ADD") end
        glow:SetColorTexture(r, g, b, BattleMaps.Clamp(alpha * 0.22, 0.08, 0.22))
        glow:Show()
    end

    pair.core:ClearAllPoints()
    pair.core:SetStartPoint("CENTER", startFrame, 0, 0)
    pair.core:SetEndPoint("CENTER", endFrame, 0, 0)
    pair.core:SetThickness(thickness)
    if pair.core.SetBlendMode then pair.core:SetBlendMode("BLEND") end
    pair.core:SetColorTexture(r, g, b, alpha)
    pair.core:Show()
    return true
end

function Pins:RecordFlagCarrierTrailPoint(flagIndex, mapID, x, y, faction, pinScale, r, g, b, colorKey)
    local db = GetObjectiveSettings(mapID)
    if not db or db.showFlagCarrierTrail ~= true or not x or not y then return end

    self.flagTrailHistory = self.flagTrailHistory or {}
    mapID = tonumber(mapID) or tonumber(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    flagIndex = tonumber(flagIndex) or 1
    local now = type(GetTime) == "function" and GetTime() or 0
    local history = self.flagTrailHistory[flagIndex]
    if not history then
        history = {}
        self.flagTrailHistory[flagIndex] = history
    end

    local duration = GetCarriedTrailDuration(mapID)
    TrimTrailHistory(history, now, duration)

    local live = history.live or {}
    live.x, live.y, live.time = x, y, now
    live.faction = faction or "neutral"
    live.pinScale = pinScale or 1
    live.mapID = mapID
    live.r, live.g, live.b = r, g, b
    live.colorKey = colorKey
    history.live = live

    if GetCarriedTrailStyle(mapID) == FLAG_TRAIL_STYLE_TETHER then
        history[1] = InterpolateTrailPoint(live, live, 0, now)
        for index = #history, 2, -1 do
            history[index] = nil
        end
        self.flagTrailDirty = true
        self.flagTrailActiveCount = math.max(tonumber(self.flagTrailActiveCount) or 0, flagIndex)
        self:EnsureFlagTrailController():Show()
        return
    end

    local width, height = GetTrailCanvasSize(self)
    local last = history[#history]
    if not last then
        history[1] = InterpolateTrailPoint(live, live, 0, now)
    else
        local moved = PixelDistance(last.x, last.y, x, y, width, height)
        if moved >= FLAG_TRAIL_MIN_MOVE_PIXELS then
            local elapsed = now - (tonumber(last.time) or now)
            local anchorInterval = BattleMaps.Clamp(
                duration / math.max(FLAG_TRAIL_MAX_KEYFRAMES - 2, 1),
                0.30,
                0.85
            )
            local isTurn = false
            local previous = history[#history - 1]
            if previous then
                local ax, ay = PixelVector(previous.x, previous.y, last.x, last.y, width, height)
                local bx, by = PixelVector(last.x, last.y, x, y, width, height)
                local aLength = math.sqrt((ax * ax) + (ay * ay))
                local bLength = math.sqrt((bx * bx) + (by * by))
                if aLength > 0.001 and bLength > 0.001 then
                    local directionDot = ((ax * bx) + (ay * by)) / (aLength * bLength)
                    isTurn = moved >= FLAG_TRAIL_TURN_MOVE_PIXELS
                        and directionDot < FLAG_TRAIL_TURN_DOT_THRESHOLD
                end
            end
            if isTurn or moved >= FLAG_TRAIL_MAX_SEGMENT_PIXELS or elapsed >= anchorInterval then
                history[#history + 1] = InterpolateTrailPoint(live, live, 0, now)
                while #history > FLAG_TRAIL_MAX_KEYFRAMES do table.remove(history, 1) end
            end
        end
    end

    self.flagTrailDirty = true
    self.flagTrailActiveCount = math.max(tonumber(self.flagTrailActiveCount) or 0, flagIndex)
    self:EnsureFlagTrailController():Show()
end

local function BuildTrailPointList(history)
    local points = {}
    for index = 1, #history do points[#points + 1] = history[index] end
    local live = history.live
    local last = points[#points]
    if live and (not last
        or tonumber(live.time) ~= tonumber(last.time)
        or tonumber(live.x) ~= tonumber(last.x)
        or tonumber(live.y) ~= tonumber(last.y)) then
        points[#points + 1] = live
    end
    return points
end

local function BuildTrailSegments(points, width, height)
    local segments = {}
    local totalLength = 0
    for index = #points, 2, -1 do
        local newer = points[index]
        local older = points[index - 1]
        local length = PixelDistance(older.x, older.y, newer.x, newer.y, width, height)
        if length > 0.05 then
            segments[#segments + 1] = { newer = newer, older = older, length = length }
            totalLength = totalLength + length
        end
    end
    return segments, totalLength
end

local function SampleTrailAtDistance(segments, targetDistance)
    local remaining = math.max(tonumber(targetDistance) or 0, 0)
    for _, segment in ipairs(segments) do
        if remaining <= segment.length then
            local ratio = segment.length > 0 and (remaining / segment.length) or 0
            return InterpolateTrailPoint(segment.newer, segment.older, ratio)
        end
        remaining = remaining - segment.length
    end
    local last = segments[#segments]
    return last and last.older or nil
end

local function GetTrailCurrentPoint(history)
    if type(history) ~= "table" then return nil end
    return history.live or history[#history]
end

local function GetSpawnTetherOrigin(pins, mapID, point)
    if IsTempleOfKotmoguMap(mapID) then
        local colorKey = SafeNormalize(point and point.colorKey)
        if colorKey == "" or not Rules.GetTempleOrbSpawnPosition then return nil, nil end
        local ok, x, y = pcall(Rules.GetTempleOrbSpawnPosition, colorKey)
        if not ok then return nil, nil end
        return tonumber(x), tonumber(y)
    end

    if IsEyeOfTheStormMap(mapID) then
        return EOTS_FLAG_CENTER_X, EOTS_FLAG_CENTER_Y
    end

    if Rules.IsCaptureTheFlagMap and Rules.IsCaptureTheFlagMap(mapID) then
        local flagObjectFaction = NormalizeTrailFactionValue(point and point.faction)
        if pins and pins.GetCTFFlagBasePosition then
            return pins:GetCTFFlagBasePosition(mapID, flagObjectFaction)
        end
        return GetCTFFlagBaseFallback(mapID, flagObjectFaction)
    end

    return nil, nil
end

local function BuildResampledTrail(pins, history, now, duration, mapID, style, budget)
    if type(history) ~= "table" or #history == 0 or budget <= 0 then return {} end
    local width, height = GetTrailCanvasSize(pins)
    local points = BuildTrailPointList(history)
    local segments, totalLength = BuildTrailSegments(points, width, height)
    local newest = points[#points]
    if #segments == 0 or totalLength <= 0.05 then
        local life = 1 - ((now - (tonumber(newest.time) or now)) / duration)
        if life <= 0 then return {} end
        local point = InterpolateTrailPoint(newest, newest, 0)
        point.life = BattleMaps.Clamp(life, 0, 1)
        point.taper = 1
        return { point }
    end

    local baseSize = GetTrailBaseSize(pins, mapID)
    local spacing = style == FLAG_TRAIL_STYLE_GLOW
        and BattleMaps.Clamp(baseSize * 1.30, 6.0, 15.0)
        or BattleMaps.Clamp(baseSize * 0.92, 4.0, 11.0)
    local count = BattleMaps.Clamp(math.floor((totalLength / spacing) + 1.5), 2, budget)
    local step = count > 1 and (totalLength / (count - 1)) or 0
    local samples = {}
    for index = 0, count - 1 do
        local point = SampleTrailAtDistance(segments, step * index)
        if point then
            local life = 1 - ((now - (tonumber(point.time) or now)) / duration)
            if life > 0.02 then
                point.life = BattleMaps.Clamp(life, 0, 1)
                local distanceFraction = count > 1 and (index / (count - 1)) or 0
                local headFraction = 1 - distanceFraction
                -- Smoothstep avoids a blunt change near the flag while still
                -- allowing the old end to collapse to a narrow filament.
                local smooth = headFraction * headFraction * (3 - (2 * headFraction))
                point.taper = 0.055 + (0.945 * smooth)
                samples[#samples + 1] = point
            end
        end
    end
    return samples
end

function Pins:RenderFlagCarrierTrails(activeFlagCount, forceRender)
    local currentMapID = tonumber(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local db = GetObjectiveSettings(currentMapID)
    if not db or db.showFlagCarrierTrail ~= true or not activeFlagCount or activeFlagCount <= 0 then
        self:ClearFlagCarrierTrails()
        return
    end

    local now = type(GetTime) == "function" and GetTime() or 0
    if not forceRender and self.flagTrailNextRenderAt and now < self.flagTrailNextRenderAt then return end
    self.flagTrailNextRenderAt = now + FLAG_TRAIL_RENDER_INTERVAL
    self.flagTrailActiveCount = activeFlagCount
    self:EnsureFlagTrailController():Show()

    self.flagTrailHistory = self.flagTrailHistory or {}
    local activeHistories = {}
    for flagIndex = 1, activeFlagCount do
        local history = self.flagTrailHistory[flagIndex]
        if type(history) == "table" and #history > 0 then
            local mapID = tonumber(history[#history] and history[#history].mapID) or currentMapID
            local duration = GetCarriedTrailDuration(mapID)
            TrimTrailHistory(history, now, duration)
            if #history > 0 then
                activeHistories[#activeHistories + 1] = {
                    flagIndex = flagIndex,
                    history = history,
                    mapID = mapID,
                    duration = duration,
                }
            end
        end
    end

    if #activeHistories == 0 then
        self:HideFlagCarrierTrailFrames()
        return
    end

    local style = GetCarriedTrailStyle(currentMapID)
    local requestedPerTrail = GetCarriedTrailDetail(currentMapID)
    local perTrailBudget = math.max(math.min(
        requestedPerTrail,
        math.floor(FLAG_TRAIL_MAX_TOTAL_POINTS / #activeHistories)
    ), 2)

    local usedAnchors, usedLines = 0, 0
    for _, entry in ipairs(activeHistories) do
        local flashLevel = GetTrailFlashLevel(self, entry.flagIndex, entry.mapID)

        if style == FLAG_TRAIL_STYLE_TETHER then
            local point = GetTrailCurrentPoint(entry.history)
            local spawnX, spawnY = GetSpawnTetherOrigin(self, entry.mapID, point)
            if point and spawnX and spawnY
                and usedAnchors + 2 <= FLAG_TRAIL_MAX_TOTAL_POINTS then
                usedAnchors = usedAnchors + 1
                local spawnFrame = self:GetFlagTrailFrame(usedAnchors)
                ShowTrailAnchor(self, spawnFrame, { x = spawnX, y = spawnY })

                usedAnchors = usedAnchors + 1
                local carrierFrame = self:GetFlagTrailFrame(usedAnchors)
                ShowTrailAnchor(self, carrierFrame, point)

                usedLines = usedLines + 1
                local pair = self:GetFlagTrailLine(usedLines)
                if pair then
                    ConfigureSpawnTetherLine(
                        pair,
                        spawnFrame,
                        carrierFrame,
                        point,
                        entry.mapID,
                        self,
                        flashLevel
                    )
                end
            end
        else
            local samples = BuildResampledTrail(
                self,
                entry.history,
                now,
                entry.duration,
                entry.mapID,
                style,
                perTrailBudget
            )

            -- Samples arrive newest -> oldest. Render oldest -> newest so brighter
            -- points and line segments naturally sit above the fading tail.
            local previousFrame, previousPoint
            for index = #samples, 1, -1 do
                if usedAnchors >= FLAG_TRAIL_MAX_TOTAL_POINTS then break end
                usedAnchors = usedAnchors + 1
                local point = samples[index]
                local frame = self:GetFlagTrailFrame(usedAnchors)
                if style == FLAG_TRAIL_STYLE_BREADCRUMBS then
                    ShowBreadcrumbPoint(self, frame, point, point.life or 0.5, entry.mapID, flashLevel)
                else
                    ShowTrailAnchor(self, frame, point)
                end

                -- Breadcrumbs are intentionally unconnected. Only Glow wake uses
                -- line regions between successive path anchors.
                if previousFrame and style == FLAG_TRAIL_STYLE_GLOW then
                    usedLines = usedLines + 1
                    local pair = self:GetFlagTrailLine(usedLines)
                    if pair then
                        local segmentLife = math.max(
                            tonumber(point.life) or 0,
                            tonumber(previousPoint and previousPoint.life) or 0
                        )
                        local segmentTaper = (
                            (tonumber(point.taper) or 1)
                            + (tonumber(previousPoint and previousPoint.taper) or 1)
                        ) * 0.5
                        ConfigureTrailLine(
                            pair,
                            previousFrame,
                            frame,
                            point,
                            segmentLife,
                            segmentTaper,
                            entry.mapID,
                            style,
                            self,
                            flashLevel
                        )
                    end
                end
                previousFrame, previousPoint = frame, point
            end
        end
    end

    for index = usedAnchors + 1, #(self.flagTrailFrames or {}) do
        HideFlagTrailFrame(self.flagTrailFrames[index])
    end
    for index = usedLines + 1, #(self.flagTrailLines or {}) do
        local pair = self.flagTrailLines[index]
        if pair.glow then pair.glow:Hide() end
        if pair.core then pair.core:Hide() end
    end
    self.flagTrailDirty = nil
    self.flagTrailViewportSignature = GetTrailViewportSignature(self)
end

function Pins:ShowDummyFlagCarrierTrail(faction, pinScale, anchorX, anchorY, colorKey)
    local mapID = tonumber(self.captureTimerTestMapID)
        or tonumber(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local mapFrame = BattleMaps.MapFrame
    if mapFrame and mapFrame.testMode == true and IsTempleOfKotmoguMap(mapID) then
        -- The dedicated moving orb controller owns Kotmogu's Test-mode path.
        -- Ignore PreviewPins' generic straight trail so it cannot overwrite or
        -- flicker against the blue-orb history.
        return
    end
    local db = GetObjectiveSettings(mapID)
    if not db or db.showFlagCarrierTrail ~= true then
        self:HideFlagCarrierTrailFrames()
        return
    end

    anchorX = BattleMaps.Clamp(tonumber(anchorX) or DUMMY_CARRIED_POSITION[1], 0.02, 0.98)
    anchorY = BattleMaps.Clamp(tonumber(anchorY) or DUMMY_CARRIED_POSITION[2], 0.02, 0.98)
    local now = type(GetTime) == "function" and GetTime() or 0
    local duration = GetCarriedTrailDuration(mapID)
    local history = {}
    local count = 10
    for index = 1, count do
        local t = (index - 1) / math.max(count - 1, 1)
        history[#history + 1] = {
            x = BattleMaps.Clamp(anchorX - (0.15 * (1 - t)), 0.02, 0.98),
            y = anchorY,
            time = now - (duration * 0.68 * (1 - t)),
            faction = faction or "neutral",
            pinScale = pinScale or 1,
            mapID = mapID,
            colorKey = colorKey,
        }
    end
    history.live = history[#history]
    self.flagTrailHistory = self.flagTrailHistory or {}
    self.flagTrailHistory[1] = history
    self.flagTrailDirty = true
    self.flagTrailActiveCount = 1
    self:RenderFlagCarrierTrails(1, true)
end

-- Carried-objective flash overlay ----------------------------------------

local function CopyPinTextureToCarriedFlashOverlay(pin, overlay)
    if not pin or not overlay then return false end

    if overlay.SetAtlas then
        pcall(overlay.SetAtlas, overlay, nil)
    end
    overlay:SetTexture(nil)

    local atlas = pin.BattleMapsPreviewAtlas
    if type(atlas) == "string" and atlas ~= "" and overlay.SetAtlas then
        local ok = pcall(overlay.SetAtlas, overlay, atlas, false)
        if ok then
            if overlay.SetTexCoord then
                overlay:SetTexCoord(0, 1, 0, 1)
            end
            return true
        end
    end

    local texturePath = pin.BattleMapsObjectiveTexturePath
        or pin.BattleMapsPreviewTexturePath
    if texturePath then
        overlay:SetTexture(texturePath)
        if overlay.SetTexCoord then
            overlay:SetTexCoord(0, 1, 0, 1)
        end
        return true
    end

    local source = pin.texture
    if source then
        local sourceAtlas = source.GetAtlas and source:GetAtlas()
        if type(sourceAtlas) == "string" and sourceAtlas ~= "" and overlay.SetAtlas then
            local ok = pcall(overlay.SetAtlas, overlay, sourceAtlas, false)
            if ok then
                return true
            end
        end

        local sourceTexture = source.GetTexture and source:GetTexture()
        if sourceTexture then
            overlay:SetTexture(sourceTexture)
            if overlay.SetTexCoord and source.GetTexCoord then
                local ok, left, right, top, bottom, ulx, uly, llx, lly, urx, ury, lrx, lry = pcall(source.GetTexCoord, source)
                if ok then
                    if ulx ~= nil then
                        overlay:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
                    else
                        overlay:SetTexCoord(left or 0, right or 1, top or 0, bottom or 1)
                    end
                else
                    overlay:SetTexCoord(0, 1, 0, 1)
                end
            end
            return true
        end
    end

    return false
end

local function SyncCarriedObjectiveFlashOverlay(pin)
    if not pin then return nil end

    local overlay = pin.carriedFlashOverlay
    if not overlay then
        overlay = pin:CreateTexture(nil, "OVERLAY", nil, 7)
        overlay:SetBlendMode("ADD")
        overlay:SetAlpha(0)
        overlay:Hide()
        pin.carriedFlashOverlay = overlay
    end

    overlay:ClearAllPoints()
    overlay:SetAllPoints(pin)

    if overlay.SetRotation then
        overlay:SetRotation(0)
    end
    overlay:SetBlendMode("ADD")

    if not CopyPinTextureToCarriedFlashOverlay(pin, overlay) then
        overlay:SetAlpha(0)
        overlay:Hide()
        return nil
    end

    if overlay.SetDesaturated then
        overlay:SetDesaturated(pin.BattleMapsObjectiveDesaturated == true)
    end
    overlay:SetVertexColor(
        tonumber(pin.BattleMapsObjectiveTintR) or 1,
        tonumber(pin.BattleMapsObjectiveTintG) or 1,
        tonumber(pin.BattleMapsObjectiveTintB) or 1,
        1
    )
    return overlay
end

local function EnsureCarriedObjectiveFlashAnimation(overlay)
    if not overlay then return nil end
    local group = overlay.BattleMapsCarriedFlashGroup
    if group then return group end

    group = overlay:CreateAnimationGroup()
    group:SetLooping("REPEAT")
    group.BattleMapsOverlay = overlay

    local brighten = group:CreateAnimation("Alpha")
    brighten:SetOrder(1)
    brighten:SetSmoothing("IN_OUT")

    local fade = group:CreateAnimation("Alpha")
    fade:SetOrder(2)
    fade:SetSmoothing("IN_OUT")

    group.brighten = brighten
    group.fade = fade
    group:SetScript("OnPlay", function(animationGroup)
        local texture = animationGroup.BattleMapsOverlay
        if texture then
            texture:SetAlpha(animationGroup.minimumAlpha or CARRIED_OBJECTIVE_FLASH_MIN_BRIGHTNESS)
            texture:Show()
        end
    end)
    group:SetScript("OnStop", function(animationGroup)
        local texture = animationGroup.BattleMapsOverlay
        if texture then
            texture:SetAlpha(0)
            texture:Hide()
        end
    end)

    overlay.BattleMapsCarriedFlashGroup = group
    return group
end

function Pins:StopCarriedObjectiveFlash(pin)
    local overlay = pin and pin.carriedFlashOverlay
    if not overlay then return end

    local group = overlay.BattleMapsCarriedFlashGroup
    if group and group:IsPlaying() then group:Stop() end
    overlay:SetAlpha(0)
    overlay:Hide()
end

function Pins:ApplyCarriedObjectiveFlash(pin)
    if not pin then return end

    pin:SetAlpha(1)
    if pin.texture and pin.texture.SetAlpha then pin.texture:SetAlpha(1) end

    local mapID = tonumber(pin.BattleMapsObjectiveMapID)
        or tonumber(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local db = GetObjectiveSettings(mapID)
    if not db or db.flashCarriedObjectives ~= true then
        self:StopCarriedObjectiveFlash(pin)
        return
    end

    local period = GetCarriedObjectiveFlashPeriod(mapID)
    local maximumAlpha = GetCarriedObjectiveFlashStrength(mapID)
    local textureKey = pin.BattleMapsObjectiveTexturePath
        or pin.BattleMapsPreviewTexturePath
        or pin.BattleMapsPreviewAtlas
        or "source"
    local signature = string.format("%.3f:%.3f:%s", period, maximumAlpha, tostring(textureKey))

    local existingOverlay = pin.carriedFlashOverlay
    local existingGroup = existingOverlay and existingOverlay.BattleMapsCarriedFlashGroup
    if existingGroup and existingGroup:IsPlaying()
        and existingGroup.BattleMapsConfigSignature == signature then
        return
    end

    local overlay = SyncCarriedObjectiveFlashOverlay(pin)
    if not overlay then return end

    local minimumAlpha = math.min(maximumAlpha, CARRIED_OBJECTIVE_FLASH_MIN_BRIGHTNESS)
    local halfPeriod = period * 0.5
    local group = EnsureCarriedObjectiveFlashAnimation(overlay)
    if not group then return end

    group.BattleMapsConfigSignature = signature
    group.minimumAlpha = minimumAlpha
    group.maximumAlpha = maximumAlpha
    group.brighten:SetFromAlpha(minimumAlpha)
    group.brighten:SetToAlpha(maximumAlpha)
    group.brighten:SetDuration(halfPeriod)
    group.fade:SetFromAlpha(maximumAlpha)
    group.fade:SetToAlpha(minimumAlpha)
    group.fade:SetDuration(halfPeriod)

    if group:IsPlaying() then group:Stop() end
    overlay:SetBlendMode("ADD")
    if overlay.SetDesaturated then
        overlay:SetDesaturated(pin.BattleMapsObjectiveDesaturated == true)
    end
    overlay:SetVertexColor(
        tonumber(pin.BattleMapsObjectiveTintR) or 1,
        tonumber(pin.BattleMapsObjectiveTintG) or 1,
        tonumber(pin.BattleMapsObjectiveTintB) or 1,
        1
    )
    group:Play()
end

-- PreviewPins.lua is loaded immediately before this module. Keep the Kotmogu
-- Test-mode objective set deterministic after every dummy rebuild: three
-- stationary orbs and one carried blue orb.
local function InstallKotmoguTestPreviewRefreshGuard()
    if Pins.BattleMapsKotmoguTestPreviewRefreshGuardInstalled then return true end
    local originalRefreshDummyPins = Pins.RefreshDummyPins
    if type(originalRefreshDummyPins) ~= "function" then return false end

    Pins.BattleMapsKotmoguTestPreviewRefreshGuardInstalled = true
    Pins.RefreshDummyPins = function(self, ...)
        originalRefreshDummyPins(self, ...)
        local mapFrame = BattleMaps.MapFrame
        local mapID = tonumber(mapFrame and (mapFrame.currentMapID or mapFrame.selectedMapID))
        if mapFrame and mapFrame.testMode == true and IsTempleOfKotmoguMap(mapID) then
            self:RefreshTempleTestCarriedOrbPreview(mapID)
        elseif self.templeTestCarriedOrbPreviewActive then
            self:HideTempleTestCarriedOrbPreview()
        end
    end
    return true
end

InstallKotmoguTestPreviewRefreshGuard()

