local addonName, BattleMaps = ...

_G.BattleMaps = BattleMaps
BattleMaps.addonName = addonName
BattleMaps.VERSION = "3.0.8"
BattleMaps.BUILD = "3.0.8"

BattleMaps.COLORS = {
    red = { 0.77, 0.17, 0.16 },
    parchment = { 0.91, 0.72, 0.45 },
    parchmentLight = { 0.96, 0.85, 0.64 },
    buttonText = { 1.00, 0.68, 0.20 },
    section = { 0.92, 0.38, 0.22 },
    shadow = { 0.05, 0.04, 0.035 },
    alliance = { 0.08, 0.43, 0.86 },
    horde = { 0.75, 0.08, 0.12 },
    neutral = { 0.72, 0.72, 0.72 },
}

-- Built-in client fonts remain available even when LibSharedMedia is not
-- installed. When another addon provides LibSharedMedia-3.0, BattleMaps also
-- exposes every registered font (including fonts such as Expressway) without
-- needing to bundle or redistribute the font file itself.
BattleMaps.OBJECTIVE_TIMER_FONT_CHOICES = {
    { value = "friz", label = "Friz Quadrata" },
    { value = "arial", label = "Arial Narrow" },
    { value = "morpheus", label = "Morpheus" },
    { value = "skurri", label = "Skurri" },
}

BattleMaps.OBJECTIVE_TIMER_FONT_PATHS = {
    friz = STANDARD_TEXT_FONT or [[Fonts\FRIZQT__.TTF]],
    arial = [[Fonts\ARIALN.TTF]],
    morpheus = [[Fonts\MORPHEUS.TTF]],
    skurri = [[Fonts\SKURRI.TTF]],
}

function BattleMaps.GetLibSharedMedia()
    if not _G.LibStub then return nil end
    local ok, media = pcall(function()
        return _G.LibStub("LibSharedMedia-3.0", true)
    end)
    return ok and media or nil
end

function BattleMaps.GetObjectiveTimerFontChoices()
    local result, seen = {}, {}

    for _, choice in ipairs(BattleMaps.OBJECTIVE_TIMER_FONT_CHOICES or {}) do
        result[#result + 1] = choice
        seen[tostring(choice.value)] = true
    end

    local media = BattleMaps.GetLibSharedMedia()
    if media and type(media.List) == "function" then
        local ok, names = pcall(media.List, media, "font")
        if ok and type(names) == "table" then
            for _, name in ipairs(names) do
                name = tostring(name or "")
                if name ~= "" and not seen[name] then
                    seen[name] = true
                    result[#result + 1] = { value = name, label = name }
                end
            end
        end
    end

    table.sort(result, function(a, b)
        return tostring(a.label or a.value):lower() < tostring(b.label or b.value):lower()
    end)
    return result
end

function BattleMaps.GetObjectiveTimerFontPath(fontKey)
    fontKey = tostring(fontKey or "friz")
    local paths = BattleMaps.OBJECTIVE_TIMER_FONT_PATHS
    if paths[fontKey] then return paths[fontKey] end

    local media = BattleMaps.GetLibSharedMedia()
    if media and type(media.Fetch) == "function" then
        local ok, path = pcall(media.Fetch, media, "font", fontKey, true)
        if ok and type(path) == "string" and path ~= "" then
            return path
        end
    end

    return paths.friz
end

local function HexByte(value)
    value = math.max(0, math.min(255, math.floor((tonumber(value) or 0) * 255 + 0.5)))
    return string.format("%02x", value)
end

function BattleMaps.ColorText(color, text)
    color = color or BattleMaps.COLORS.parchment
    return "|cff" .. HexByte(color[1]) .. HexByte(color[2]) .. HexByte(color[3]) .. tostring(text) .. "|r"
end

function BattleMaps.Chat(...)
    local prefix = BattleMaps.ColorText(BattleMaps.COLORS.parchment, "BattleMaps:")
    print(prefix, ...)
end

function BattleMaps.Debug(...)
    if BattleMapsDB and BattleMapsDB.debug then
        BattleMaps.Chat(BattleMaps.ColorText(BattleMaps.COLORS.neutral, "[debug]"), ...)
    end
end

function BattleMaps.Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function BattleMaps.Round(value, step)
    step = tonumber(step) or 1
    value = tonumber(value) or 0
    return math.floor((value / step) + 0.5) * step
end

function BattleMaps.IsFrame(value)
    return type(value) == "table" and type(value.SetPoint) == "function"
end

function BattleMaps.GetSafeGlobalFrame(name)
    local frame = name and _G[name]
    if BattleMaps.IsFrame(frame) then
        return frame
    end
    return UIParent
end

local function NormalizeLocationName(value)
    value = tostring(value or ""):lower()
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:gsub("[%s%p%c]", "")
    return value
end

local function CopyBattlegroundInfo(source, forcedID, forcedName)
    local copy = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            copy[key] = value
        end
    end
    copy.id = tonumber(forcedID) or tonumber(copy.id) or tonumber(copy.mapID) or tonumber(copy.uiMapID)
    if forcedName and forcedName ~= "" then copy.name = forcedName end
    return copy
end

-- BattleMaps historically stores Arathi Basin under configuration ID 112.
-- Modern C_Map data also uses 112 for Eye of the Storm, so direct lookups by
-- that ID can return EotS metadata. Resolve AB by its name/current UI map ID,
-- then expose a copy keyed to the legacy configuration ID.
function BattleMaps.GetArathiBasinInfo()
    local battlegrounds = BattleMaps.Battlegrounds
    local maps = battlegrounds and battlegrounds.MAPS or {}

    for _, info in ipairs(maps) do
        if NormalizeLocationName(info and info.name):find("arathibasin", 1, true) then
            local copy = CopyBattlegroundInfo(info, 112, "Arathi Basin")
            copy.uiMapID = tonumber(copy.uiMapID) or tonumber(copy.mapID) or 1366
            return copy
        end
    end

    for _, info in ipairs(maps) do
        if tonumber(info and info.id) == 1366
            or tonumber(info and info.mapID) == 1366
            or tonumber(info and info.uiMapID) == 1366
            or tonumber(info and info.instanceMapID) == 1366 then
            local copy = CopyBattlegroundInfo(info, 112, "Arathi Basin")
            copy.uiMapID = 1366
            return copy
        end
    end

    if battlegrounds and battlegrounds.GetInfo then
        local ok, info = pcall(battlegrounds.GetInfo, battlegrounds, 1366)
        if ok and type(info) == "table" then
            local copy = CopyBattlegroundInfo(info, 112, "Arathi Basin")
            copy.uiMapID = 1366
            return copy
        end
    end

    return {
        id = 112,
        mapID = 1366,
        uiMapID = 1366,
        name = "Arathi Basin",
        width = 560,
        height = 420,
    }
end

function BattleMaps.GetEyeOfTheStormInfo()
    local battlegrounds = BattleMaps.Battlegrounds
    local maps = battlegrounds and battlegrounds.MAPS or {}

    for _, info in ipairs(maps) do
        if NormalizeLocationName(info and info.name):find("eyeofthestorm", 1, true) then
            local copy = CopyBattlegroundInfo(info, 210, "Eye of the Storm")
            copy.mapID = 112
            copy.uiMapID = 112
            return copy
        end
    end

    for _, info in ipairs(maps) do
        if tonumber(info and info.uiMapID) == 112
            or tonumber(info and info.mapID) == 112 then
            local normalized = NormalizeLocationName(info and info.name)
            if not normalized:find("arathibasin", 1, true) then
                local copy = CopyBattlegroundInfo(info, 210, "Eye of the Storm")
                copy.mapID = 112
                copy.uiMapID = 112
                return copy
            end
        end
    end

    if battlegrounds and battlegrounds.GetInfo then
        local ok, info = pcall(battlegrounds.GetInfo, battlegrounds, 112)
        if ok and type(info) == "table" then
            local normalized = NormalizeLocationName(info.name)
            if not normalized:find("arathibasin", 1, true) then
                local copy = CopyBattlegroundInfo(info, 210, "Eye of the Storm")
                copy.mapID = 112
                copy.uiMapID = 112
                return copy
            end
        end
    end

    return {
        id = 210,
        mapID = 112,
        uiMapID = 112,
        name = "Eye of the Storm",
        width = 560,
        height = 420,
    }
end

function BattleMaps.GetBattlegroundInfoForConfig(mapID)
    mapID = tonumber(mapID)
    if mapID == 112 then
        return BattleMaps.GetArathiBasinInfo()
    elseif mapID == 210 then
        return BattleMaps.GetEyeOfTheStormInfo()
    end

    local battlegrounds = BattleMaps.Battlegrounds
    if battlegrounds and battlegrounds.GetInfo then
        local ok, info = pcall(battlegrounds.GetInfo, battlegrounds, mapID)
        if ok then return info end
    end
    return nil
end

function BattleMaps.GetBattlegroundNameForConfig(mapID)
    local info = BattleMaps.GetBattlegroundInfoForConfig(mapID)
    if info and info.name and info.name ~= "" then return info.name end

    local battlegrounds = BattleMaps.Battlegrounds
    if battlegrounds and battlegrounds.GetName then
        local ok, name = pcall(battlegrounds.GetName, battlegrounds, mapID)
        if ok and name then return name end
    end
    return ""
end

-- Node-control battlegrounds whose assault announcements begin a delayed
-- ownership transition. Capture durations are defined here per battleground;
-- they are not exposed as user-editable settings.
local CAPTURE_TIMER_PROFILES = {
    [112] = { id = 112, name = "Arathi Basin", defaultDuration = 60, blitzDuration = 30, blitzUncapDuration = 45, blitzRecapDuration = 5, blitzAssaultCastDuration = 4, testObjective = "stables", testObjectiveName = "Stables" },
    [210] = { id = 210, name = "Eye of the Storm", defaultDuration = 60, blitzDuration = 30, testObjective = "mage_tower", testObjectiveName = "Mage Tower" },
    [275] = { id = 275, name = "Battle for Gilneas", defaultDuration = 60, blitzDuration = 30, testObjective = "waterworks", testObjectiveName = "Waterworks" },
    [761] = { id = 761, name = "Battle for Gilneas", defaultDuration = 60, blitzDuration = 30, testObjective = "waterworks", testObjectiveName = "Waterworks" },
    [1576] = { id = 1576, name = "Deepwind Gorge", defaultDuration = 60, blitzDuration = 30, blitzUncapDuration = 45, blitzRecapDuration = 5, blitzAssaultCastDuration = 4, testObjective = "market", testObjectiveName = "Market" },
}

local CAPTURE_TIMER_PROFILE_BY_NAME = {
    arathibasin = CAPTURE_TIMER_PROFILES[112],
    eyeofthestorm = CAPTURE_TIMER_PROFILES[210],
    battleforgilneas = CAPTURE_TIMER_PROFILES[275],
    deepwindgorge = CAPTURE_TIMER_PROFILES[1576],
}

local function GetCaptureTimerProfileByName(value)
    local normalizedName = NormalizeLocationName(value)
    if normalizedName == "" then return nil end

    -- Accept both full battleground names and the shorter names returned by
    -- some map/instance APIs. This is especially important for Battle for
    -- Gilneas, whose selector ID varies between client data sources.
    if normalizedName:find("arathibasin", 1, true) then
        return CAPTURE_TIMER_PROFILES[112]
    elseif normalizedName:find("eyeofthestorm", 1, true) then
        return CAPTURE_TIMER_PROFILES[210]
    elseif normalizedName:find("battleforgilneas", 1, true)
        or normalizedName:find("gilneas", 1, true) then
        return CAPTURE_TIMER_PROFILES[275]
    elseif normalizedName:find("deepwindgorge", 1, true)
        or normalizedName:find("deepwind", 1, true) then
        return CAPTURE_TIMER_PROFILES[1576]
    end

    for key, profile in pairs(CAPTURE_TIMER_PROFILE_BY_NAME) do
        if normalizedName:find(key, 1, true) then
            return profile
        end
    end
    return nil
end

function BattleMaps.GetCaptureTimerProfile(mapID)
    mapID = tonumber(mapID)
    if mapID == 1366 then mapID = 112 end

    local direct = mapID and CAPTURE_TIMER_PROFILES[mapID] or nil
    if direct then return direct end

    -- Battleground selectors can expose a UI map ID, instance map ID, or
    -- BattleMaps configuration ID. Resolve every available metadata source
    -- before deciding that a supported map has no delayed capture timer.
    local info = mapID and BattleMaps.GetBattlegroundInfoForConfig
        and BattleMaps.GetBattlegroundInfoForConfig(mapID)
    local profile = GetCaptureTimerProfileByName(info and info.name)
    if profile then return profile end

    local battlegrounds = BattleMaps.Battlegrounds
    if battlegrounds and battlegrounds.GetName and mapID then
        local ok, name = pcall(battlegrounds.GetName, battlegrounds, mapID)
        if ok then
            profile = GetCaptureTimerProfileByName(name)
            if profile then return profile end
        end
    end

    -- Find the selector record that owns this ID and resolve by its name. This
    -- catches Battle for Gilneas builds where `info.id` is not the historical
    -- 761 value used by BattleMaps for timer storage.
    for _, candidate in ipairs(battlegrounds and battlegrounds.MAPS or {}) do
        if tonumber(candidate and candidate.id) == mapID
            or tonumber(candidate and candidate.mapID) == mapID
            or tonumber(candidate and candidate.uiMapID) == mapID
            or tonumber(candidate and candidate.instanceMapID) == mapID then
            profile = GetCaptureTimerProfileByName(candidate.name)
            if profile then return profile end
        end
    end

    if C_Map and C_Map.GetMapInfo and mapID then
        local ok, mapInfo = pcall(C_Map.GetMapInfo, mapID)
        if ok and mapInfo then
            profile = GetCaptureTimerProfileByName(mapInfo.name)
            if profile then return profile end
        end
    end

    return nil
end

function BattleMaps.IsCaptureTimerMap(mapID)
    return BattleMaps.GetCaptureTimerProfile(mapID) ~= nil
end

function BattleMaps.IsBattlegroundBlitz()
    -- Battleground Blitz is exposed by current clients as Solo RBG / Rated Solo
    -- RBG. Keep the checks defensive so older or future clients simply fall
    -- back to ordinary battleground timings.
    local pvp = C_PvP
    if type(pvp) == "table" then
        for _, methodName in ipairs({
            "IsRatedSoloRBG",
            "IsSoloRBG",
            "IsBrawlSoloRBG",
        }) do
            local method = pvp[methodName]
            if type(method) == "function" then
                local ok, result = pcall(method)
                if ok and result == true then return true end
            end
        end

        if type(pvp.GetActiveBrawlInfo) == "function" then
            local ok, info = pcall(pvp.GetActiveBrawlInfo)
            if ok and type(info) == "table" then
                local name = NormalizeLocationName(info.name or info.shortName or info.description)
                if name:find("battlegroundblitz", 1, true)
                    or name:find("blitz", 1, true) then
                    return true
                end
            end
        end
    end

    return false
end

function BattleMaps.GetObjectiveCaptureDuration(mapID, forceBlitz)
    local profile = BattleMaps.GetCaptureTimerProfile(mapID)
    if not profile then return nil end

    if forceBlitz == true
        or (BattleMaps.IsBattlegroundBlitz and BattleMaps.IsBattlegroundBlitz()) then
        return BattleMaps.Clamp(tonumber(profile.blitzDuration) or tonumber(profile.defaultDuration) or 60, 1, 300)
    end

    return BattleMaps.Clamp(tonumber(profile.defaultDuration) or 60, 1, 300)
end

function BattleMaps.IsObjectiveBlitzUncapMap(mapID)
    local profile = BattleMaps.GetCaptureTimerProfile(mapID)
    return tonumber(profile and profile.blitzUncapDuration) ~= nil
end

function BattleMaps.GetObjectiveBlitzUncapDuration(mapID, forceBlitz)
    if forceBlitz ~= true
        and not (BattleMaps.IsBattlegroundBlitz and BattleMaps.IsBattlegroundBlitz()) then return nil end

    local profile = BattleMaps.GetCaptureTimerProfile(mapID)
    local duration = tonumber(profile and profile.blitzUncapDuration)
    if not duration then return nil end
    return BattleMaps.Clamp(duration, 1, 300)
end

function BattleMaps.GetObjectiveBlitzRecapDuration(mapID, forceBlitz)
    if forceBlitz ~= true
        and not (BattleMaps.IsBattlegroundBlitz and BattleMaps.IsBattlegroundBlitz()) then return nil end

    local profile = BattleMaps.GetCaptureTimerProfile(mapID)
    if not tonumber(profile and profile.blitzUncapDuration) then return nil end
    return BattleMaps.Clamp(tonumber(profile.blitzRecapDuration) or 5, 0, 30)
end

-- Objective categories used by the offline Edit-mode preview and the Map Pins
-- options page. Battleground metadata may override these defaults by exposing
-- an `objectiveTypes` or `objectives` table with stationary/carried/vehicle
-- boolean fields. Name matching keeps this compatible with localized map IDs
-- and with battleground entries supplied by older BattleMaps builds.
local OBJECTIVE_CAPABILITY_RULES = {
    { names = { "warsonggulch", "twinpeaks" }, carried = true },
    { names = { "eyeofthestorm" }, stationary = true, carried = true },
    { names = { "templeofkotmogu" }, stationary = true, carried = true },

    { names = {
        "arathibasin",
        "battleforgilneas",
        "deepwindgorge",
        "seethingshore",
        "alteracvalley",
    }, stationary = true },

    { names = { "silvershardmines" }, vehicle = true },
    { names = { "deephaulravine" }, stationary = true, vehicle = true },
    { names = {
        "wintergrasp",
        "battleforwintergrasp",
        "isleofconquest",
        "strandoftheancients",
        "ashran",
    }, stationary = true, vehicle = true },

    -- Team-deathmatch battlegrounds do not use objective pins.
    { names = { "southshorevstarrenmill" } },
}

local OBJECTIVE_CAPABILITY_BY_MAP_ID = {
    [91] = { stationary = true },                    -- Alterac Valley
    [112] = { stationary = true },                   -- Arathi Basin
    [118] = { stationary = true, vehicle = true },   -- Wintergrasp
    [169] = { stationary = true, vehicle = true },   -- Isle of Conquest
    [206] = { carried = true },                      -- Warsong Gulch
    [210] = { stationary = true, carried = true },   -- Eye of the Storm
    [275] = { stationary = true },                   -- Battle for Gilneas
    [417] = { stationary = true, carried = true },   -- Temple of Kotmogu
    [726] = { carried = true },                      -- Twin Peaks
    [423] = { vehicle = true },                      -- Silvershard Mines
    [727] = { vehicle = true },                      -- Silvershard Mines historical/API alias
    [761] = { stationary = true },                   -- Battle for Gilneas
    [998] = { stationary = true, carried = true },   -- Temple of Kotmogu
    [1478] = { stationary = true, vehicle = true },  -- Ashran
    [1576] = { stationary = true },                  -- Deepwind Gorge
    [1803] = { stationary = true },                  -- Seething Shore
    [2345] = { stationary = true, vehicle = true },   -- Deephaul Ravine
}

local function ReadObjectiveCapabilityTable(source)
    if type(source) ~= "table" then return nil end
    return {
        stationary = source.stationary == true,
        carried = source.carried == true,
        vehicle = source.vehicle == true,
    }
end

function BattleMaps.GetObjectiveCapabilities(mapID)
    mapID = tonumber(mapID)
    local battlegrounds = BattleMaps.Battlegrounds
    local info = mapID and BattleMaps.GetBattlegroundInfoForConfig
        and BattleMaps.GetBattlegroundInfoForConfig(mapID)
        or (mapID and battlegrounds and battlegrounds.GetInfo
            and battlegrounds:GetInfo(mapID) or nil)

    local explicit = info and ReadObjectiveCapabilityTable(info.objectiveTypes or info.objectives)
    if explicit then return explicit end

    local byID = mapID and OBJECTIVE_CAPABILITY_BY_MAP_ID[mapID]
    if byID then
        return {
            stationary = byID.stationary == true,
            carried = byID.carried == true,
            vehicle = byID.vehicle == true,
        }
    end

    local mapName = info and info.name
        or (battlegrounds and battlegrounds.GetName and battlegrounds:GetName(mapID))
        or ""
    local normalized = NormalizeLocationName(mapName)
    for _, rule in ipairs(OBJECTIVE_CAPABILITY_RULES) do
        for _, name in ipairs(rule.names) do
            if normalized:find(name, 1, true) then
                return {
                    stationary = rule.stationary == true,
                    carried = rule.carried == true,
                    vehicle = rule.vehicle == true,
                }
            end
        end
    end

    -- Unknown battlegrounds default to stationary objectives only. This avoids
    -- presenting carried/vehicle controls without evidence while still leaving
    -- ordinary POI objectives configurable for newly added maps.
    return { stationary = true, carried = false, vehicle = false }
end

local function GetSupportedBattlegroundMapID(candidate)
    candidate = tonumber(candidate)
    local battlegrounds = BattleMaps.Battlegrounds
    if not candidate or not battlegrounds then return nil end

    -- Canonicalize the modern C_Map IDs into BattleMaps' legacy configuration
    -- IDs before the generic alias lookup. Modern 112 is Eye of the Storm;
    -- modern 1366 is Arathi Basin.
    if candidate == 1366 then return 112 end
    if candidate == 112 then return 210 end

    if battlegrounds.GetInfo then
        local ok, info = pcall(battlegrounds.GetInfo, battlegrounds, candidate)
        if ok and info then return candidate end
    end

    for _, info in ipairs(battlegrounds.MAPS or {}) do
        if tonumber(info.id) == candidate
            or tonumber(info.mapID) == candidate
            or tonumber(info.uiMapID) == candidate
            or tonumber(info.instanceMapID) == candidate then
            return tonumber(info.id)
        end
    end
    return nil
end

function BattleMaps.IsInLiveBattleground()
    local battlegrounds = BattleMaps.Battlegrounds
    if battlegrounds and battlegrounds.IsInBattleground then
        local ok, result = pcall(battlegrounds.IsInBattleground, battlegrounds)
        if ok and result == true then return true end
    end

    if type(IsInInstance) == "function" then
        local ok, inInstance, instanceType = pcall(IsInInstance)
        if ok and inInstance == true and instanceType == "pvp" then
            return true
        end
    end
    return false
end


local NON_EPIC_BATTLEGROUND_IDS = {
    [112] = true,   -- Arathi Basin legacy configuration ID
    [206] = true,   -- Warsong Gulch legacy/API alias
    [210] = true,   -- Eye of the Storm configuration ID
    [275] = true,   -- Battle for Gilneas
    [417] = true,   -- Temple of Kotmogu
    [423] = true,   -- Silvershard Mines
    [726] = true,   -- Twin Peaks historical/API alias
    [727] = true,   -- Silvershard Mines historical/API alias
    [761] = true,   -- Battle for Gilneas historical/API alias
    [907] = true,   -- Seething Shore
    [998] = true,   -- Temple of Kotmogu historical/API alias
    [1339] = true,  -- Warsong Gulch modern UI map ID
    [1366] = true,  -- Arathi Basin modern UI map ID
    [1576] = true,  -- Deepwind Gorge
    [1803] = true,  -- Seething Shore historical/API alias
    [2345] = true,  -- Deephaul Ravine
}

function BattleMaps.IsNonEpicBattlegroundMapID(mapID)
    mapID = tonumber(mapID)
    if not mapID then return false end
    if NON_EPIC_BATTLEGROUND_IDS[mapID] then return true end

    local supported = GetSupportedBattlegroundMapID(mapID)
    return supported ~= nil and NON_EPIC_BATTLEGROUND_IDS[supported] == true
end

function BattleMaps.GetCurrentBattlegroundEpicState()
    if not BattleMaps.IsInLiveBattleground() then return false end

    local mapID = BattleMaps.ResolveCurrentBattlegroundMapID
        and BattleMaps.ResolveCurrentBattlegroundMapID()
        or nil
    if BattleMaps.IsNonEpicBattlegroundMapID(mapID) then return false end

    -- During instance loading the UI map can briefly be unavailable. Use the
    -- instance/map names as a fallback so the minimap option still behaves
    -- correctly in the ordinary battlegrounds BattleMaps supports.
    local observedNames = {}
    local function AddObserved(value)
        local normalized = NormalizeLocationName(value)
        if normalized ~= "" then observedNames[normalized] = true end
    end

    if type(GetInstanceInfo) == "function" then
        local results = { pcall(GetInstanceInfo) }
        if results[1] then AddObserved(results[2]) end
    end
    if type(GetRealZoneText) == "function" then
        local ok, value = pcall(GetRealZoneText)
        if ok then AddObserved(value) end
    end
    if type(GetZoneText) == "function" then
        local ok, value = pcall(GetZoneText)
        if ok then AddObserved(value) end
    end
    if type(GetMinimapZoneText) == "function" then
        local ok, value = pcall(GetMinimapZoneText)
        if ok then AddObserved(value) end
    end

    local battlegrounds = BattleMaps.Battlegrounds
    for _, info in ipairs(battlegrounds and battlegrounds.MAPS or {}) do
        local normalized = NormalizeLocationName(info and info.name)
        if normalized ~= "" and observedNames[normalized] then
            return false
        end
    end

    -- Unknown pvp battlegrounds are treated as epic/unsupported. This prevents
    -- the personal minimap-hiding option from affecting AV/IoC/Ashran/Wintergrasp
    -- or future large maps until they are explicitly added above.
    return true
end

function BattleMaps.ShouldHideMinimapNow()
    local db = BattleMaps.Database and BattleMaps.Database.Get and BattleMaps.Database:Get() or nil
    if not db or db.hideMinimapInNonEpicBattlegrounds ~= true then return false end

    -- Test mode is outside a live battleground, but it is deliberately using
    -- BattleMaps as the active map surface. Honour the same personal minimap
    -- preference there, limited to configured non-epic battleground maps.
    local mapFrame = BattleMaps.MapFrame
    if mapFrame and mapFrame.testMode == true then
        local testMapID = tonumber(mapFrame.currentMapID)
            or tonumber(mapFrame.selectedMapID)
            or (BattleMaps.Options and tonumber(BattleMaps.Options.selectedMapID))
        return BattleMaps.IsNonEpicBattlegroundMapID(testMapID) == true
    end

    local epicState = BattleMaps.GetCurrentBattlegroundEpicState()
    if epicState == false and BattleMaps.IsInLiveBattleground() then return true end
    if epicState == true then return false end

    -- Unknown transient state: if BattleMaps already hid the minimap in the
    -- current transition, keep it hidden until the next resolved refresh.
    return BattleMaps.minimapHiddenByBattleMaps == true and BattleMaps.IsInLiveBattleground()
end

local function GetMinimapHideTargets()
    local targets, seen = {}, {}
    local function Add(frame)
        if BattleMaps.IsFrame(frame) and not seen[frame] then
            seen[frame] = true
            targets[#targets + 1] = frame
        end
    end

    -- Hide the complete minimap surface. No minimap children are reparented:
    -- native pins and addon buttons disappear through ordinary parent visibility.
    Add(_G.MinimapCluster)
    Add(_G.Minimap)
    return targets
end

-- Blizzard's MailFrame and CraftingOrderFrame call self:GetParent():Layout()
-- from their own event handlers. Some minimap replacements (including layouts
-- used by ElvUI) can move those indicators to a plain/hidden holder that has no
-- Layout method. Do not move the Blizzard frames again; instead give only such
-- parent holders the no-op layout contract Blizzard expects. This is the same
-- compatibility pattern used by established minimap addons after reparenting
-- these indicators.
local function EnsureMinimapIndicatorParentLayout()
    local cluster = _G.MinimapCluster
    local indicatorFrame = cluster and cluster.IndicatorFrame
    if not BattleMaps.IsFrame(indicatorFrame) then return end

    local candidates = {
        indicatorFrame.MailFrame,
        indicatorFrame.CraftingOrderFrame,
    }

    for _, frame in ipairs(candidates) do
        if BattleMaps.IsFrame(frame) and type(frame.GetParent) == "function" then
            local okParent, parent = pcall(frame.GetParent, frame)
            if okParent and BattleMaps.IsFrame(parent) and parent ~= indicatorFrame
                and type(parent.Layout) ~= "function" then
                -- UI frames support addon-owned Lua fields. A plain hidden/mover
                -- parent has no layout work to perform, but Blizzard requires the
                -- method to exist when mail/crafting events fire.
                parent.Layout = function() end
                parent.BattleMapsMinimapLayoutShim = true
            end
        end
    end
end

local function SetFrameMouseEnabled(frame, enabled)
    if BattleMaps.IsFrame(frame) and type(frame.EnableMouse) == "function" then
        pcall(frame.EnableMouse, frame, enabled == true)
    end
end

function BattleMaps.SetMinimapHiddenByBattleMaps(hidden)
    hidden = hidden == true

    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        BattleMaps.pendingMinimapVisibilityRefresh = true
        return false
    end

    if hidden then
        local targets = GetMinimapHideTargets()
        if #targets == 0 then return false end

        -- Do not reparent addon minimap buttons. Hiding MinimapCluster naturally
        -- hides them with the rest of the minimap and avoids ownership conflicts
        -- with ElvUI/LibDBIcon. Supply the Layout contract required by Blizzard
        -- if another minimap implementation has already moved its indicators.
        EnsureMinimapIndicatorParentLayout()

        if BattleMaps.minimapHiddenByBattleMaps then
            -- Another UI addon may have shown the minimap again during a zone/UI
            -- refresh. Reassert visibility without replacing the original state.
            for _, frame in ipairs(targets) do
                if type(frame.SetAlpha) == "function" then pcall(frame.SetAlpha, frame, 0) end
                SetFrameMouseEnabled(frame, false)
                if type(frame.Hide) == "function" then pcall(frame.Hide, frame) end
            end
            return true
        end

        local states = {}
        for _, frame in ipairs(targets) do
            local state = {
                alpha = type(frame.GetAlpha) == "function" and frame:GetAlpha() or 1,
                mouseEnabled = type(frame.IsMouseEnabled) == "function" and frame:IsMouseEnabled() == true or false,
            }
            states[frame] = state

            if type(frame.SetAlpha) == "function" then
                pcall(frame.SetAlpha, frame, 0)
            end
            SetFrameMouseEnabled(frame, false)

            -- Native/engine minimap pins are not reliably enumerable as Lua
            -- descendants. Hide the actual minimap/cluster instead of trying to
            -- walk or reparent their children. Visibility hides ignore-parent-
            -- alpha regions as well.
            if type(frame.Hide) == "function" then
                state.shown = type(frame.IsShown) == "function" and frame:IsShown() == true or false
                pcall(frame.Hide, frame)
            end
        end

        BattleMaps.minimapHiddenFrameStates = states
        BattleMaps.minimapHiddenByBattleMaps = true
        return true
    end

    if not BattleMaps.minimapHiddenByBattleMaps then return true end

    local states = BattleMaps.minimapHiddenFrameStates or {}
    for frame, state in pairs(states) do
        if BattleMaps.IsFrame(frame) and type(state) == "table" then
            if type(frame.SetAlpha) == "function" then
                pcall(frame.SetAlpha, frame, tonumber(state.alpha) or 1)
            end
            SetFrameMouseEnabled(frame, state.mouseEnabled == true)
            if state.shown == true and type(frame.Show) == "function" then
                pcall(frame.Show, frame)
            end
        end
    end

    BattleMaps.minimapHiddenFrameStates = nil
    BattleMaps.minimapHiddenByBattleMaps = false
    return true
end

function BattleMaps.ApplyMinimapVisibility()
    BattleMaps.pendingMinimapVisibilityRefresh = nil
    local result = BattleMaps.SetMinimapHiddenByBattleMaps(BattleMaps.ShouldHideMinimapNow())
    if BattleMaps.ApplyBattlegroundAuraLayout then
        BattleMaps.ApplyBattlegroundAuraLayout()
    end
    return result
end

function BattleMaps.ResolveCurrentBattlegroundMapID()
    if not BattleMaps.IsInLiveBattleground() then return nil end

    local battlegrounds = BattleMaps.Battlegrounds
    if not battlegrounds then return nil end

    local bestMapID
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, candidate = pcall(C_Map.GetBestMapForUnit, "player")
        if ok then bestMapID = tonumber(candidate) end
    end

    -- Prefer the map reported by the live player unit. A battleground may
    -- report a child map first, so walk upward until a configured map is found.
    local visited = {}
    local candidate = bestMapID
    for _ = 1, 8 do
        if not candidate or visited[candidate] then break end
        visited[candidate] = true

        local supported = GetSupportedBattlegroundMapID(candidate)
        if supported then return supported end

        if not C_Map or not C_Map.GetMapInfo then break end
        local ok, mapInfo = pcall(C_Map.GetMapInfo, candidate)
        candidate = ok and mapInfo and tonumber(mapInfo.parentMapID) or nil
        if candidate == 0 then candidate = nil end
    end

    -- Match the live instance/zone name against the configured battleground
    -- names before consulting any cached addon state. This prevents a stale
    -- selector value such as Warsong Gulch from winning inside another match.
    local observedNames = {}
    local liveInstanceID
    local function AddObserved(value)
        local normalized = NormalizeLocationName(value)
        if normalized ~= "" then observedNames[normalized] = true end
    end

    if type(GetInstanceInfo) == "function" then
        local results = { pcall(GetInstanceInfo) }
        if results[1] then
            AddObserved(results[2])
            liveInstanceID = tonumber(results[9])
        end
    end
    if type(GetRealZoneText) == "function" then
        local ok, value = pcall(GetRealZoneText)
        if ok then AddObserved(value) end
    end
    if type(GetZoneText) == "function" then
        local ok, value = pcall(GetZoneText)
        if ok then AddObserved(value) end
    end
    if type(GetMinimapZoneText) == "function" then
        local ok, value = pcall(GetMinimapZoneText)
        if ok then AddObserved(value) end
    end
    if bestMapID and C_Map and C_Map.GetMapInfo then
        local ok, mapInfo = pcall(C_Map.GetMapInfo, bestMapID)
        if ok and mapInfo then AddObserved(mapInfo.name) end
    end

    local function NameMatches(value)
        local normalized = NormalizeLocationName(value)
        if normalized == "" then return false end
        if observedNames[normalized] then return true end
        if #normalized >= 6 then
            for observed in pairs(observedNames) do
                if #observed >= 6
                    and (observed:find(normalized, 1, true) or normalized:find(observed, 1, true)) then
                    return true
                end
            end
        end
        return false
    end

    local function ReturnSupportedConfigID(candidate)
        local supported = GetSupportedBattlegroundMapID(candidate)
        return supported or tonumber(candidate)
    end

    for _, info in ipairs(battlegrounds.MAPS or {}) do
        if liveInstanceID and tonumber(info.instanceID) == liveInstanceID then
            return ReturnSupportedConfigID(info.id)
        end

        local matched = NameMatches(info.name)
        if not matched and battlegrounds.GetName then
            local ok, localizedName = pcall(battlegrounds.GetName, battlegrounds, info.id)
            matched = ok and NameMatches(localizedName) or false
        end
        if not matched and type(info.aliases) == "table" then
            for _, alias in pairs(info.aliases) do
                if NameMatches(alias) then
                    matched = true
                    break
                end
            end
        end
        if matched then return ReturnSupportedConfigID(info.id) end
    end

    -- Fall back to the addon's resolver only after checking the live unit and
    -- instance name, because older resolver paths may retain the prior map.
    if battlegrounds.GetCurrentMapID then
        local ok, addonCandidate = pcall(battlegrounds.GetCurrentMapID, battlegrounds)
        local supported = ok and GetSupportedBattlegroundMapID(addonCandidate) or nil
        if supported then return supported end
    end

    -- Final fallback: probe the player's own position against the supported
    -- maps. Teammate positions can be restricted, but the local player is
    -- normally still available to the map API.
    if C_Map and C_Map.GetPlayerMapPosition then
        for _, info in ipairs(battlegrounds.MAPS or {}) do
            local ok, position = pcall(C_Map.GetPlayerMapPosition, info.id, "player")
            if ok and position ~= nil then
                return ReturnSupportedConfigID(info.id)
            end
        end
    end

    return nil
end

-- BattleMaps stores per-battleground settings under stable configuration IDs,
-- but Blizzard's restricted UnitPositionFrame requires the current C_Map UI
-- map ID. These IDs are not always the same (notably for maps whose client IDs
-- changed over time), so unit pins must never receive the configuration ID
-- directly. In a live battleground, the player's current best map is the most
-- authoritative source. Offline callers fall back to the resolved battleground
-- metadata used by the selector and renderer.
function BattleMaps.GetBattlegroundUIMapID(configMapID, preferLive)
    configMapID = tonumber(configMapID)
    if not configMapID then return nil end

    if preferLive ~= false
        and BattleMaps.IsInLiveBattleground()
        and C_Map and C_Map.GetBestMapForUnit then
        local ok, liveMapID = pcall(C_Map.GetBestMapForUnit, "player")
        liveMapID = ok and tonumber(liveMapID) or nil
        if liveMapID then
            -- Use the live unit map only for the battleground actually being
            -- played. The options window may deliberately preview a different
            -- map while the player remains inside a match.
            local resolvedConfigID = BattleMaps.ResolveCurrentBattlegroundMapID()
            if tonumber(resolvedConfigID) == configMapID then
                return liveMapID
            end
        end
    end

    local info = BattleMaps.GetBattlegroundInfoForConfig(configMapID)
    if type(info) == "table" then
        for _, key in ipairs({ "uiMapID", "mapID" }) do
            local candidate = tonumber(info[key])
            if candidate and candidate > 0 then
                return candidate
            end
        end
    end

    return configMapID
end


-------------------------------------------------
-- Addon Compartment + minimap launcher (LibDBIcon)
-------------------------------------------------

function BattleMaps_OnAddonCompartmentClick()
    if BattleMaps.Options and BattleMaps.Options.Open then
        BattleMaps.Options:Open()
    end
end

local MINIMAP_BUTTON_NAME = "BattleMaps"
local MINIMAP_BUTTON_ICON = "Interface\\AddOns\\BattleMaps\\Media\\Icon.tga"

local function GetMinimapButtonDB()
    if not BattleMaps.Database or type(BattleMaps.Database.Get) ~= "function" then
        return nil
    end

    local db = BattleMaps.Database:Get()
    if not db then return nil end

    -- Migrate the temporary custom minimap implementation used by the previous
    -- test build into LibDBIcon's standard table.
    if type(db.minimapButton) ~= "table" then
        db.minimapButton = {
            hide = db.showMinimapButton == false,
            minimapPos = tonumber(db.minimapButtonAngle) or 225,
        }
    else
        if db.minimapButton.hide == nil and db.showMinimapButton ~= nil then
            db.minimapButton.hide = db.showMinimapButton == false
        end
        if db.minimapButton.minimapPos == nil then
            db.minimapButton.minimapPos = tonumber(db.minimapButtonAngle) or 225
        end
    end

    db.showMinimapButton = nil
    db.minimapButtonAngle = nil

    return db.minimapButton
end

local function GetMinimapLibraries()
    local libStub = _G.LibStub
    if not libStub then return nil, nil end

    local LDB = libStub("LibDataBroker-1.1", true)
    local DBIcon = libStub("LibDBIcon-1.0", true)
    return LDB, DBIcon
end

function BattleMaps.InitializeMinimapButton()
    local LDB, DBIcon = GetMinimapLibraries()
    local db = GetMinimapButtonDB()
    if not LDB or not DBIcon or not db then
        return false
    end

    local launcher = LDB:GetDataObjectByName(MINIMAP_BUTTON_NAME)
    if not launcher then
        launcher = LDB:NewDataObject(MINIMAP_BUTTON_NAME, {
            type = "launcher",
            text = "BattleMaps",
            icon = MINIMAP_BUTTON_ICON,

            OnClick = function(_, button)
                if button == "LeftButton"
                    and BattleMaps.Options
                    and BattleMaps.Options.Open then
                    BattleMaps.Options:Open()
                end
            end,

            OnTooltipShow = function(tooltip)
                tooltip:AddLine("BattleMaps")
                tooltip:AddLine("Left-click to open options.", 1, 1, 1)
                tooltip:AddLine("Drag to reposition.", 0.72, 0.72, 0.72)
            end,
        })
    end

    if not DBIcon:IsRegistered(MINIMAP_BUTTON_NAME) then
        DBIcon:Register(MINIMAP_BUTTON_NAME, launcher, db)
    else
        DBIcon:Refresh(MINIMAP_BUTTON_NAME, db)
    end

    BattleMaps.MinimapLauncher = launcher
    BattleMaps.DBIcon = DBIcon

    if db.hide then
        DBIcon:Hide(MINIMAP_BUTTON_NAME)
    else
        DBIcon:Show(MINIMAP_BUTTON_NAME)
    end

    return true
end

function BattleMaps.SetMinimapButtonShown(shown)
    local db = GetMinimapButtonDB()
    if not db then return end

    db.hide = shown ~= true

    if not BattleMaps.InitializeMinimapButton() then
        return
    end

    if db.hide then
        BattleMaps.DBIcon:Hide(MINIMAP_BUTTON_NAME)
    else
        BattleMaps.DBIcon:Show(MINIMAP_BUTTON_NAME)
    end
end

function BattleMaps.IsMinimapButtonShown()
    local db = GetMinimapButtonDB()
    return not (db and db.hide == true)
end

function BattleMaps.RefreshMinimapButton()
    return BattleMaps.InitializeMinimapButton()
end

-- Core.lua loads before Database.lua. PLAYER_LOGIN is late enough that the
-- database and options modules are available.
local minimapButtonInitializer = CreateFrame("Frame")
minimapButtonInitializer:RegisterEvent("PLAYER_LOGIN")
minimapButtonInitializer:SetScript("OnEvent", function(self)
    BattleMaps.RefreshMinimapButton()
    self:UnregisterEvent("PLAYER_LOGIN")
end)

function BattleMaps_ToggleMap()
    if BattleMaps.MapFrame then
        BattleMaps.MapFrame:Toggle()
    end
end

BINDING_HEADER_BATTLEMAPS = "BattleMaps"
BINDING_NAME_BATTLEMAPS_TOGGLE = "Toggle BattleMaps"

SLASH_BATTLEMAPS1 = "/bmap"
SlashCmdList.BATTLEMAPS = function(message)
    message = tostring(message or ""):lower():match("^%s*(.-)%s*$")
    local command, argument = message:match("^(%S+)%s*(.-)$")

    if command == "corealpha" or command == "core" then
        local value = tonumber(argument)
        if not value then
            BattleMaps.Chat("Usage: /bmap corealpha <0-100> (or 0-1).")
            return
        end
        if value > 1 then value = value / 100 end
        if value < 0 or value > 1 then
            BattleMaps.Chat("Core alpha must be between 0% and 100%.")
            return
        end

        local mapID = BattleMaps.ResolveCurrentBattlegroundMapID()
            or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
            or (BattleMaps.Options and BattleMaps.Options.selectedMapID)
        local settings = BattleMaps.Database and BattleMaps.Database:GetUnitsConfig(mapID)
        if not settings then
            BattleMaps.Chat("Core alpha could not be saved because unit settings are unavailable.")
            return
        end

        settings.playerFovBeamAlpha = value
        if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        if BattleMaps.Options and BattleMaps.Options.frame and BattleMaps.Options.frame:IsShown() then
            BattleMaps.Options:Refresh()
        end
        BattleMaps.Chat(string.format("Core alpha set to %d%%.", math.floor((value * 100) + 0.5)))
    elseif command == "boundary" or command == "boundarypreview" then
        local db = BattleMaps.Database and BattleMaps.Database:Get()
        if not db then
            BattleMaps.Chat("Boundary preview could not be changed because settings are unavailable.")
            return
        end
        db.fovBoundaryPreview = not (db.fovBoundaryPreview == true)
        if BattleMaps.MapFrame and BattleMaps.MapFrame.UpdateFovBoundaryPreview then
            BattleMaps.MapFrame:UpdateFovBoundaryPreview()
        end
        BattleMaps.Chat("FoV boundary alignment preview " .. (db.fovBoundaryPreview and "enabled." or "disabled."))
    elseif command == "fovmask" or command == "boundarymask" then
        local db = BattleMaps.Database and BattleMaps.Database:Get()
        if not db then
            BattleMaps.Chat("FoV boundary mask could not be changed because settings are unavailable.")
            return
        end
        local target, state = argument:match("^(%S*)%s*(.-)$")
        target = tostring(target or ""):lower()
        state = tostring(state or ""):lower()
        local enabled
        if state == "on" or state == "enable" or state == "enabled" then
            enabled = true
        elseif state == "off" or state == "disable" or state == "disabled" then
            enabled = false
        elseif state ~= "" and state ~= "toggle" then
            BattleMaps.Chat("Usage: /bmap fovmask [all|core|terrain] [on|off].")
            return
        end

        local boundary = target == "core" or target == "boundary" or target == "cone"
        local beam = target == "terrain" or target == "beam" or target == "detail"
        local all = target == "" or target == "all"
        if not boundary and not beam and not all then
            BattleMaps.Chat("Usage: /bmap fovmask [all|core|terrain] [on|off].")
            return
        end
        if all or boundary then
            db.fovBoundaryMask = enabled ~= nil and enabled or not (db.fovBoundaryMask == true)
        end
        if all or beam then
            db.fovBeamMask = enabled ~= nil and enabled or not (db.fovBeamMask ~= false)
        end
        if BattleMaps.Pins then BattleMaps.Pins:RefreshGroup() end
        local mapID = BattleMaps.ResolveCurrentBattlegroundMapID()
            or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
            or (BattleMaps.Options and BattleMaps.Options.selectedMapID)
        local mapName = BattleMaps.Battlegrounds and BattleMaps.Battlegrounds:GetName(mapID)
            or "Current map"
        BattleMaps.Chat(string.format(
            "%s FoV masks: core %s, terrain %s.",
            mapName,
            db.fovBoundaryMask and "on" or "off",
            db.fovBeamMask ~= false and "on" or "off"
        ))
    elseif message == "show" or message == "map" then
        BattleMaps.MapFrame:ShowCurrentOrSelected()
    elseif message == "hide" then
        BattleMaps.MapFrame:Hide()
    elseif message == "toggle" then
        BattleMaps.MapFrame:Toggle()
    elseif message == "save" or message == "lock" then
        BattleMaps.MapFrame:CommitEdit()
    elseif message == "cancel" then
        BattleMaps.MapFrame:CancelEdit()
    elseif message == "unlock" or message == "edit" then
        BattleMaps.MapFrame:ShowCurrentOrSelected()
        BattleMaps.MapFrame:BeginEdit()
    elseif message == "reset" then
        local mapID = BattleMaps.ResolveCurrentBattlegroundMapID() or BattleMaps.MapFrame.currentMapID
        if mapID then
            BattleMaps.Database:ResetMapSettings(mapID)
            if BattleMaps.Pins then
                BattleMaps.Pins:StopAllObjectiveCaptureTimers()
                BattleMaps.Pins:RefreshAll(true)
            end
            BattleMaps.MapFrame:SetMapID(mapID, true)
        end
    elseif message == "textures" or message == "texturekeys" then
        local mapID = BattleMaps.ResolveCurrentBattlegroundMapID()
            or BattleMaps.MapFrame.currentMapID
            or BattleMaps.Options.selectedMapID
        if BattleMaps.Pins and BattleMaps.Pins.PrintObjectiveTextureKeys then
            BattleMaps.Pins:PrintObjectiveTextureKeys(mapID)
        end
    elseif message == "texturedebug" or message == "texturesdebug" then
        local mapID = BattleMaps.ResolveCurrentBattlegroundMapID()
            or BattleMaps.MapFrame.currentMapID
            or BattleMaps.Options.selectedMapID
        if BattleMaps.Pins and BattleMaps.Pins.PrintObjectiveTextureDebug then
            BattleMaps.Pins:PrintObjectiveTextureDebug(mapID)
        end
    elseif message == "fullmapcheck" or message == "worldmapcheck" or message == "wmcheck" then
        if BattleMaps.WorldMapIntegration
            and BattleMaps.WorldMapIntegration.PrintValidationSnapshot then
            BattleMaps.WorldMapIntegration:PrintValidationSnapshot()
        end
    elseif message == "rostercheck" or message == "teamcheck" then
        if BattleMaps.Pins and BattleMaps.Pins.PrintTeamRosterDebug then
            BattleMaps.Pins:PrintTeamRosterDebug()
        end
    elseif message == "stackcheck" or message == "stackingcheck" then
        if BattleMaps.Pins and BattleMaps.Pins.PrintTeamStackDebug then
            BattleMaps.Pins:PrintTeamStackDebug()
        end
    elseif message == "healercheck" or message == "healerdiag" then
        if BattleMaps.Pins and BattleMaps.Pins.PrintHealerDebug then
            BattleMaps.Pins:PrintHealerDebug()
        else
            BattleMaps.Chat("Healer diagnostics are unavailable.")
        end
    elseif message == "carriercheck" or message == "elvcarriercheck" or message == "classificationcheck" then
        if BattleMaps.PrintElvUIPvPClassificationStatus then
            BattleMaps.PrintElvUIPvPClassificationStatus()
        else
            BattleMaps.Chat("ElvUI PvP classification diagnostics are unavailable.")
        end
    elseif message == "fovdiag" or message == "fovcheck" then
        if BattleMaps.Pins and BattleMaps.Pins.PrintFovDiagnostics then
            BattleMaps.Pins:PrintFovDiagnostics()
        else
            BattleMaps.Chat("FoV diagnostics are unavailable.")
        end
    elseif command == "fovcliptest" or command == "fovstripetest" then
        local requested
        if argument == "on" or argument == "enable" or argument == "enabled" then
            requested = true
        elseif argument == "off" or argument == "disable" or argument == "disabled" then
            requested = false
        elseif argument == "" or argument == "toggle" then
            requested = not (BattleMaps.Pins and BattleMaps.Pins.fovClipDiagnosticEnabled == true)
        else
            BattleMaps.Chat("Usage: /bmap fovcliptest [on|off].")
            return
        end

        if BattleMaps.Pins and BattleMaps.Pins.SetFovClipDiagnosticEnabled then
            BattleMaps.Pins:SetFovClipDiagnosticEnabled(requested)
        else
            BattleMaps.Chat("FoV clip test is unavailable.")
        end
    elseif message == "deathmarkertest" or message == "deathtest" then
        local shown = BattleMaps.Pins and BattleMaps.Pins.ShowTeamDeathMarkerTest
            and BattleMaps.Pins:ShowTeamDeathMarkerTest()
        if shown then
            BattleMaps.Chat("Death marker test shown at the player position for 10 seconds.")
        else
            BattleMaps.Chat("Death marker test requires an active battleground map and a valid player position.")
        end
    elseif message == "native" then
        BattleMaps.Chat("The Blizzard Zone Map remains unchanged. Use Shift-M for the native map.")
    else
        BattleMaps.Options:Open()
    end
end

-------------------------------------------------
-- Battleground notifications
-------------------------------------------------

local Notifications = {
    nativeStates = {},
    recentFactionByMessage = {},
    recentClassByPlayerName = {},
    -- WoW 12.x taint-hardening: BattleMaps may reposition/scale the native
    -- RaidWarningFrame, but it deliberately does not inspect or mutate its
    -- pooled FontStrings and never replaces RaidNotice_AddMessage.
    nativeFramePlacementEnabled = true,
    nativeTextStylingEnabled = false,
    customPresentationEnabled = true,
    displaySerial = 0,
}
BattleMaps.Notifications = Notifications

local function NotificationTemplate()
    return BackdropTemplateMixin and "BackdropTemplate" or nil
end

local function SafeString(value)
    local ok, text = pcall(tostring, value or "")
    if not ok or type(text) ~= "string" then return "" end
    return text
end

local function SafeGsub(text, pattern, replacement)
    local ok, result = pcall(string.gsub, text, pattern, replacement)
    return ok and result or text
end

local function SafeMatch(text, pattern)
    local ok, result = pcall(string.match, text, pattern)
    return ok and result or nil
end

local function SafeLower(text)
    local ok, result = pcall(string.lower, text)
    return ok and result or ""
end

local function NormalizeNotificationText(text)
    text = SafeString(text)
    text = SafeGsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = SafeGsub(text, "|r", "")
    text = SafeGsub(text, "%s+", " ")
    text = SafeMatch(text, "^%s*(.-)%s*$") or ""
    return SafeLower(text)
end

local DEEPHAUL_REDUNDANT_CRYSTAL_INSTRUCTION = "the crystal can be captured outside an earthen cart building"

local function IsRedundantCrystalInstructionMessage(message)
    local text = NormalizeNotificationText(message)
    if text == "" or not text:find("crystal", 1, true) then return false end

    -- Only suppress the standalone tutorial/instruction warning.  Do not alter
    -- real pickup, drop, return, or capture notifications that happen to include
    -- crystal text.
    text = SafeGsub(text, "[!%.]+", "")
    text = SafeGsub(text, "%s+", " ")
    text = SafeMatch(text, "^%s*(.-)%s*$") or text
    return text == DEEPHAUL_REDUNDANT_CRYSTAL_INSTRUCTION
end

local function GetNotificationSettings()
    if not BattleMaps.Database then return nil end
    local mapID = BattleMaps.ResolveCurrentBattlegroundMapID()
        or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
        or (BattleMaps.Options and BattleMaps.Options.selectedMapID)
    if BattleMaps.Database.GetNotificationConfig then
        return BattleMaps.Database:GetNotificationConfig(mapID)
    end
    local db = BattleMaps.Database:Get()
    return db and db.notifications
end

function Notifications:IsBattlegroundContext()
    if not BattleMaps.IsInLiveBattleground() then return false end
    local mapID = BattleMaps.ResolveCurrentBattlegroundMapID()
    return mapID ~= nil and BattleMaps.GetBattlegroundInfoForConfig(mapID) ~= nil
end

function Notifications:IsWorldMapDelegatingToBlizzard()
    -- While Blizzard's full-screen map is open, leave the native raid-warning
    -- frames, message formatting, and chat filtering entirely under Blizzard's
    -- control. This applies even when BattleMaps is temporarily suspended
    -- because the player is browsing another World Map page.
    local integration = BattleMaps.WorldMapIntegration
    if integration and type(integration.IsWorldMapShown) == "function" then
        local ok, shown = pcall(integration.IsWorldMapShown, integration)
        if ok and shown == true then return true end
    end

    local worldMapFrame = _G.WorldMapFrame
    return worldMapFrame ~= nil
        and type(worldMapFrame.IsShown) == "function"
        and worldMapFrame:IsShown() == true
end

function Notifications:ShouldManage()
    local settings = GetNotificationSettings()
    if settings == nil or settings.enabled ~= true then return false end

    -- An explicit options preview remains available for configuration. By
    -- default, ordinary live battleground notifications revert to Blizzard
    -- ownership while the full-screen World Map is shown; users can disable
    -- that handoff from the Notifications page.
    if self.previewOverride ~= true
        and settings.useBlizzardOnWorldMap ~= false
        and self:IsWorldMapDelegatingToBlizzard() then
        return false
    end

    return self.previewOverride == true or self:IsBattlegroundContext()
end

function Notifications:IsRedundantCrystalNotification(message)
    return IsRedundantCrystalInstructionMessage(message)
end

function Notifications:InstallChatFilters()
    if self.chatFiltersInstalled or type(ChatFrame_AddMessageEventFilter) ~= "function" then return end
    self.chatFiltersInstalled = true

    local function FilterCrystalInstruction(_, _, message, ...)
        if Notifications:ShouldManage() and Notifications:IsRedundantCrystalNotification(message) then
            return true
        end
        return false, message, ...
    end

    ChatFrame_AddMessageEventFilter("CHAT_MSG_BG_SYSTEM_ALLIANCE", FilterCrystalInstruction)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_BG_SYSTEM_HORDE", FilterCrystalInstruction)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_BG_SYSTEM_NEUTRAL", FilterCrystalInstruction)
end

function Notifications:GetManagedFrames()
    -- Retail 12.1 routes standard raid warnings, battleground-system notices,
    -- and boss-emote messages through the single global RaidWarningFrame.
    -- Private boss-emote text is anchored to it by Blizzard, so moving this
    -- outer frame is sufficient and avoids touching any private/text objects.
    local frames = {}
    if _G.RaidWarningFrame then frames[#frames + 1] = _G.RaidWarningFrame end
    return frames
end

function Notifications:IsManagedFrame(frame)
    return frame and frame == _G.RaidWarningFrame
end

function Notifications:CaptureNativeState(frame)
    if not frame or self.nativeStates[frame] then return end

    local state = {
        points = {},
        scale = frame.GetScale and frame:GetScale() or 1,
    }

    local pointCount = frame.GetNumPoints and frame:GetNumPoints() or 0
    for index = 1, pointCount do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(index)
        state.points[#state.points + 1] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end

    self.nativeStates[frame] = state
end

function Notifications:RestoreNativeState(frame)
    local state = frame and self.nativeStates[frame]
    if not frame or not state then return end

    if frame.ClearAllPoints and frame.SetPoint then
        pcall(frame.ClearAllPoints, frame)
        for _, pointInfo in ipairs(state.points) do
            pcall(
                frame.SetPoint,
                frame,
                pointInfo.point,
                pointInfo.relativeTo,
                pointInfo.relativePoint,
                pointInfo.x,
                pointInfo.y
            )
        end
    end

    if state.scale and frame.SetScale then
        pcall(frame.SetScale, frame, state.scale)
    end

    -- Capture a fresh baseline the next time BattleMaps enters a supported
    -- battleground, allowing Blizzard/Edit Mode/another addon to change the
    -- warning position while BattleMaps is inactive.
    self.nativeStates[frame] = nil
end

function Notifications:GetMapAnchorDefaults(side)
    if side == "BOTTOM" then return 0, -28 end
    if side == "LEFT" then return -28, 0 end
    if side == "RIGHT" then return 28, 0 end
    if side == "TOPLEFT" or side == "TOPRIGHT" then return 0, 0 end
    return 0, 28
end

function Notifications:GetDefaultNotificationAnchorPoint(mapSide)
    if mapSide == "BOTTOM" then return "TOP" end
    if mapSide == "LEFT" then return "RIGHT" end
    if mapSide == "RIGHT" then return "LEFT" end
    if mapSide == "TOPLEFT" then return "TOPRIGHT" end
    if mapSide == "TOPRIGHT" then return "TOPLEFT" end
    return "BOTTOM"
end

function Notifications:GetMapAttachment(mapSide, notificationAnchorPoint)
    mapSide = ({
        TOP = true,
        TOPLEFT = true,
        TOPRIGHT = true,
        BOTTOM = true,
        LEFT = true,
        RIGHT = true,
    })[mapSide] and mapSide or "TOP"

    local validNotificationPoints = {
        TOP = true,
        TOPLEFT = true,
        TOPRIGHT = true,
        BOTTOM = true,
        BOTTOMLEFT = true,
        BOTTOMRIGHT = true,
        LEFT = true,
        RIGHT = true,
    }
    if notificationAnchorPoint == "AUTO" or not validNotificationPoints[notificationAnchorPoint] then
        notificationAnchorPoint = self:GetDefaultNotificationAnchorPoint(mapSide)
    end

    -- mapSide names the point on BattleMaps. notificationAnchorPoint names the
    -- independent point on the notification rectangle that joins it. Text
    -- justification is deliberately not involved in this geometry.
    return notificationAnchorPoint, mapSide
end

function Notifications:GetFramePointCoordinates(frame, point)
    if not frame then return nil, nil end
    local left = frame.GetLeft and frame:GetLeft()
    local right = frame.GetRight and frame:GetRight()
    local top = frame.GetTop and frame:GetTop()
    local bottom = frame.GetBottom and frame:GetBottom()
    if not left or not right or not top or not bottom then return nil, nil end

    point = point or "CENTER"
    local x = point:find("LEFT", 1, true) and left
        or point:find("RIGHT", 1, true) and right
        or ((left + right) * 0.5)
    local y = point:find("TOP", 1, true) and top
        or point:find("BOTTOM", 1, true) and bottom
        or ((top + bottom) * 0.5)
    return x, y
end

function Notifications:ApplyTextLayout(owner, justifyH, width, visited)
    if not owner then return end
    visited = visited or {}
    if visited[owner] then return end
    visited[owner] = true

    if owner.SetJustifyH then pcall(owner.SetJustifyH, owner, justifyH) end
    if owner.SetWidth then pcall(owner.SetWidth, owner, width) end

    if owner.GetRegions then
        local regions = { owner:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                if region.SetJustifyH then pcall(region.SetJustifyH, region, justifyH) end
                if region.SetWidth then pcall(region.SetWidth, region, width) end
            end
        end
    end

    if owner.GetChildren then
        local children = { owner:GetChildren() }
        for _, child in ipairs(children) do
            self:ApplyTextLayout(child, justifyH, width, visited)
        end
    end
end

function Notifications:GetFactionColor(faction)
    if faction == "ALLIANCE" then
        local c = BattleMaps.COLORS.alliance
        return c[1], c[2], c[3]
    elseif faction == "HORDE" then
        local c = BattleMaps.COLORS.horde
        return c[1], c[2], c[3]
    end
    return nil
end

local function StripNotificationFormatting(text)
    text = SafeString(text)
    text = SafeGsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = SafeGsub(text, "|r", "")
    text = SafeGsub(text, "|H.-|h(.-)|h", "%1")
    text = SafeGsub(text, "%[(.-)%]", "%1")
    return text
end

local function EscapePattern(text)
    text = SafeString(text)
    return SafeGsub(text, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

local function TrimText(text)
    return SafeMatch(SafeString(text), "^%s*(.-)%s*$") or ""
end

local function ColorEscapeRGB(r, g, b, text)
    if not r or not g or not b then return tostring(text or "") end
    r = math.floor(BattleMaps.Clamp((tonumber(r) or 1) * 255, 0, 255) + 0.5)
    g = math.floor(BattleMaps.Clamp((tonumber(g) or 1) * 255, 0, 255) + 0.5)
    b = math.floor(BattleMaps.Clamp((tonumber(b) or 1) * 255, 0, 255) + 0.5)
    return string.format("|cff%02x%02x%02x%s|r", r, g, b, tostring(text or ""))
end

function Notifications:GetDefaultNotificationTextColor()
    if ChatTypeInfo and ChatTypeInfo.RAID_WARNING then
        local c = ChatTypeInfo.RAID_WARNING
        return c.r or 1, c.g or 0.82, c.b or 0, 1
    end
    if NORMAL_FONT_COLOR and NORMAL_FONT_COLOR.GetRGB then
        local r, g, b = NORMAL_FONT_COLOR:GetRGB()
        return r or 1, g or 0.82, b or 0, 1
    end
    return 1, 0.82, 0, 1
end

local function NormalizePlayerNameForCompare(name)
    name = StripNotificationFormatting(name)
    name = name:gsub("%-", "-")
    name = name:gsub("%s+", "")
    name = name:gsub("%-[^%-]+$", function(realm)
        return realm:gsub("%s+", "")
    end)
    return name:lower()
end

local function UnitNameMatches(unit, target)
    if not unit or not UnitExists or not UnitExists(unit) then return false end
    local name, realm = UnitFullName and UnitFullName(unit)
    if not name or name == "" then
        name, realm = UnitName(unit)
    end
    if not name or name == "" then return false end

    local full = realm and realm ~= "" and (name .. "-" .. realm) or name
    local normalizedFull = NormalizePlayerNameForCompare(full)
    local normalizedShort = NormalizePlayerNameForCompare(name)
    return target == normalizedFull or target == normalizedShort
end

function Notifications:GetClassFileForPlayerName(playerName)
    -- Instanced PvP can expose player names as secret strings. Comparing,
    -- lowercasing, or pattern-matching those values can taint/error, so BattleMaps
    -- no longer attempts name-to-unit class lookup for notification text.
    return nil
end

function Notifications:ColorPlayerName(name)
    local classFile = self:GetClassFileForPlayerName(name)
    local classColor = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if not classColor then return nil end
    if classColor.colorStr then
        return "|c" .. classColor.colorStr .. tostring(name or "") .. "|r"
    end
    return ColorEscapeRGB(classColor.r, classColor.g, classColor.b, name)
end

function Notifications:IsFlagObjectiveMessage(message)
    local text = StripNotificationFormatting(message)
    if text == "" then return false end
    text = text:lower()
    if not text:find("flag", 1, true) then return false end
    return text:find("alliance", 1, true) ~= nil
        or text:find("horde", 1, true) ~= nil
        or text:find("picked up", 1, true) ~= nil
        or text:find("dropped", 1, true) ~= nil
        or text:find("captured", 1, true) ~= nil
        or text:find("returned", 1, true) ~= nil
end

function Notifications:IsEotSFlagPickupMessage(message)
    local mapID = BattleMaps.ResolveCurrentBattlegroundMapID()
        or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    if tonumber(mapID) ~= 210 then return false end

    local text = NormalizeNotificationText(message)
    if text == "" or not text:find("flag", 1, true) then return false end
    return text:find("picked up", 1, true) ~= nil
        or text:find("taken", 1, true) ~= nil
        or text:find("grabbed", 1, true) ~= nil
end

function Notifications:BuildFlagNotificationText(message)
    local text = StripNotificationFormatting(message)
    if text == "" or not text:lower():find("flag", 1, true) then return nil end

    local changed = false

    -- For CTF notifications, keep Blizzard's default notification colour for
    -- the sentence and only colour the faction phrase.  The event faction is
    -- the acting team, which is the wrong colour for strings such as
    -- "The Alliance flag was picked up by HordePlayer".
    local function ColourFactionPhrase(match, faction)
        local r, g, b = self:GetFactionColor(faction)
        changed = true
        return ColorEscapeRGB(r, g, b, match)
    end

    text = text:gsub("([Tt]he%s+[Aa]lliance)(%s+[Ff]lag)", function(factionText, suffix)
        return ColourFactionPhrase(factionText, "ALLIANCE") .. suffix
    end)
    text = text:gsub("([Tt]he%s+[Hh]orde)(%s+[Ff]lag)", function(factionText, suffix)
        return ColourFactionPhrase(factionText, "HORDE") .. suffix
    end)

    -- Some locales/client strings omit "The". Keep this after the explicit
    -- "The Alliance/Horde flag" replacements so the same phrase is not double
    -- processed.
    text = text:gsub("^([Aa]lliance)(%s+[Ff]lag)", function(factionText, suffix)
        return ColourFactionPhrase(factionText, "ALLIANCE") .. suffix
    end)
    text = text:gsub("^([Hh]orde)(%s+[Ff]lag)", function(factionText, suffix)
        return ColourFactionPhrase(factionText, "HORDE") .. suffix
    end)
    text = text:gsub("([^|%a])([Aa]lliance)(%s+[Ff]lag)", function(prefix, factionText, suffix)
        return prefix .. ColourFactionPhrase(factionText, "ALLIANCE") .. suffix
    end)
    text = text:gsub("([^|%a])([Hh]orde)(%s+[Ff]lag)", function(prefix, factionText, suffix)
        return prefix .. ColourFactionPhrase(factionText, "HORDE") .. suffix
    end)

    -- Common CTF strings use "... by Player!". Keep the rest of the sentence
    -- in the base notification colour and only class-colour the carrier name.
    local rawText = StripNotificationFormatting(message)
    local playerName = TrimText(rawText:match("%sby%s+([^!%.]+)") or "")

    -- Some capture strings are phrased as "Player captured the Horde flag".
    if playerName == "" then
        playerName = TrimText(rawText:match("^([^!%.]+)%s+[Cc]aptured%s+the%s+[Aa]lliance%s+[Ff]lag") or "")
    end
    if playerName == "" then
        playerName = TrimText(rawText:match("^([^!%.]+)%s+[Cc]aptured%s+the%s+[Hh]orde%s+[Ff]lag") or "")
    end

    if playerName ~= "" then
        local colouredName = self:ColorPlayerName(playerName)
        if colouredName then
            text = text:gsub(EscapePattern(playerName), colouredName, 1)
            changed = true
        end
    end

    return changed and text or nil
end


function Notifications:BuildCrystalNotificationText(message)
    local text = StripNotificationFormatting(message)
    if text == "" then return nil end

    local lower = text:lower()
    if not lower:find("crystal", 1, true) then return nil end

    local shortened = text
    shortened = shortened:gsub("%s*[Tt]he%s+[Cc]rystal%s+can%s+be%s+captured%s+outside%s+an%s+[Ee]arthen%s+cart%s+building!%s*", "")
    shortened = shortened:gsub("%s*[Tt]he%s+[Cc]rystal%s+can%s+be%s+captured%s+outside%s+an%s+[Ee]arthen%s+cart%s+building%.%s*", "")
    shortened = shortened:gsub("%s+", " "):match("^%s*(.-)%s*$") or shortened

    if shortened == "" or shortened == text then return nil end
    return shortened
end

function Notifications:ApplyCrystalNotificationText(owner, message, visited)
    local settings = GetNotificationSettings()
    if not settings or not settings.enabled then return false end

    local formatted = self:BuildCrystalNotificationText(message)
    if not formatted then return false end

    local target = NormalizeNotificationText(message)
    local applied = false
    visited = visited or {}
    if not owner or visited[owner] then return false end
    visited[owner] = true

    local function MaybeApply(fontString)
        local text = fontString and fontString.GetText and fontString:GetText()
        local normalized = NormalizeNotificationText(text)
        if normalized ~= "" and (target == "" or normalized:find(target, 1, true) or target:find(normalized, 1, true)) then
            if fontString.SetText then pcall(fontString.SetText, fontString, formatted) end
            applied = true
        end
    end

    if owner.GetObjectType and owner:GetObjectType() == "FontString" then
        MaybeApply(owner)
    end

    if owner.GetRegions then
        local regions = { owner:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                MaybeApply(region)
            end
        end
    end

    if owner.GetChildren then
        local children = { owner:GetChildren() }
        for _, child in ipairs(children) do
            if self:ApplyCrystalNotificationText(child, message, visited) then
                applied = true
            end
        end
    end

    return applied
end

function Notifications:ApplyFlagNotificationText(owner, message, visited)
    local settings = GetNotificationSettings()
    if not settings or not settings.enabled or not settings.colorByFaction then return false end

    local formatted = self:BuildFlagNotificationText(message)
    if not formatted then return false end

    local target = NormalizeNotificationText(message)
    local applied = false
    visited = visited or {}
    if not owner or visited[owner] then return false end
    visited[owner] = true

    local function MaybeApply(fontString)
        local text = fontString and fontString.GetText and fontString:GetText()
        local normalized = NormalizeNotificationText(text)
        if normalized ~= "" and (target == "" or normalized:find(target, 1, true) or target:find(normalized, 1, true)) then
            local r, g, b, a = self:GetDefaultNotificationTextColor()
            if fontString.SetTextColor then pcall(fontString.SetTextColor, fontString, r, g, b, a or 1) end
            if fontString.SetText then pcall(fontString.SetText, fontString, formatted) end
            applied = true
        end
    end

    if owner.GetObjectType and owner:GetObjectType() == "FontString" then
        MaybeApply(owner)
    end

    if owner.GetRegions then
        local regions = { owner:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                MaybeApply(region)
            end
        end
    end

    if owner.GetChildren then
        local children = { owner:GetChildren() }
        for _, child in ipairs(children) do
            if self:ApplyFlagNotificationText(child, message, visited) then
                applied = true
            end
        end
    end

    return applied
end

function Notifications:GetFactionFromColorInfo(colorInfo)
    if not colorInfo or not ChatTypeInfo then return nil end
    if colorInfo == ChatTypeInfo.BG_SYSTEM_ALLIANCE then return "ALLIANCE" end
    if colorInfo == ChatTypeInfo.BG_SYSTEM_HORDE then return "HORDE" end
    return nil
end

function Notifications:RecordFactionMessage(event, message)
    local faction
    if event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" then
        faction = "ALLIANCE"
    elseif event == "CHAT_MSG_BG_SYSTEM_HORDE" then
        faction = "HORDE"
    end
    if not faction then return end

    local key = NormalizeNotificationText(message)
    if key == "" then return end
    self.recentFactionByMessage[key] = { faction = faction, expires = GetTime() + 4 }
end

function Notifications:GetRecordedFaction(message)
    local now = GetTime()
    for key, info in pairs(self.recentFactionByMessage) do
        if not info or (info.expires or 0) < now then
            self.recentFactionByMessage[key] = nil
        end
    end

    local key = NormalizeNotificationText(message)
    local info = self.recentFactionByMessage[key]
    return info and info.faction or nil
end

function Notifications:ColorMatchingText(owner, message, faction, visited)
    local settings = GetNotificationSettings()
    if not settings or not settings.enabled or not settings.colorByFaction then return end

    local r, g, b = self:GetFactionColor(faction)
    if not r then return end

    local target = NormalizeNotificationText(message)
    visited = visited or {}
    if not owner or visited[owner] then return end
    visited[owner] = true

    local function MaybeColor(fontString)
        local text = fontString and fontString.GetText and fontString:GetText()
        local normalized = NormalizeNotificationText(text)
        if normalized ~= "" and (target == "" or normalized:find(target, 1, true) or target:find(normalized, 1, true)) then
            pcall(fontString.SetTextColor, fontString, r, g, b, 1)
        end
    end

    if owner.GetObjectType and owner:GetObjectType() == "FontString" then
        MaybeColor(owner)
    end

    if owner.GetRegions then
        local regions = { owner:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                MaybeColor(region)
            end
        end
    end

    if owner.GetChildren then
        local children = { owner:GetChildren() }
        for _, child in ipairs(children) do
            self:ColorMatchingText(child, message, faction, visited)
        end
    end
end


function Notifications:EnsureDisplayFrame()
    if self.displayFrame then return self.displayFrame end

    local frame = CreateFrame("Frame", "BattleMapsNotificationDisplay", UIParent)
    self.displayFrame = frame
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(false)
    frame:Hide()

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.text = text
    text:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    text:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(true)

    return frame
end

function Notifications:ApplyDisplayLayout()
    local settings = GetNotificationSettings()
    if not settings then return end

    local mover = self:EnsureMover()
    self:AnchorMover()
    local frame = self:EnsureDisplayFrame()
    local width = BattleMaps.Clamp(tonumber(settings.width) or 520, 240, 900)
    local scale = BattleMaps.Clamp(tonumber(settings.scale) or 1, 0.50, 2.00)
    local justifyH = (settings.justifyH == "LEFT" or settings.justifyH == "RIGHT")
        and settings.justifyH or "CENTER"

    frame:SetScale(scale)
    frame:SetSize(width, 70)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", mover, "CENTER", 0, 0)
    if frame.text then
        frame.text:SetJustifyH(justifyH)
    end
end

function Notifications:SuppressNativeForDisplay(duration)
    local frame = _G.RaidWarningFrame
    if not frame or not frame.GetAlpha or not frame.SetAlpha then return end

    if self.nativeDisplayAlpha == nil then
        local ok, alpha = pcall(frame.GetAlpha, frame)
        self.nativeDisplayAlpha = ok and alpha or 1
    end
    pcall(frame.SetAlpha, frame, 0)

    self.nativeSuppressSerial = (self.nativeSuppressSerial or 0) + 1
    local serial = self.nativeSuppressSerial
    if C_Timer and C_Timer.After then
        C_Timer.After(tonumber(duration) or 3.2, function()
            if Notifications.nativeSuppressSerial ~= serial then return end
            local native = _G.RaidWarningFrame
            if native and native.SetAlpha then
                pcall(native.SetAlpha, native, Notifications.nativeDisplayAlpha or 1)
            end
            Notifications.nativeDisplayAlpha = nil
        end)
    end
end

function Notifications:RestoreNativeDisplayAlpha()
    self.nativeSuppressSerial = (self.nativeSuppressSerial or 0) + 1
    local frame = _G.RaidWarningFrame
    if frame and frame.SetAlpha and self.nativeDisplayAlpha ~= nil then
        pcall(frame.SetAlpha, frame, self.nativeDisplayAlpha or 1)
    end
    self.nativeDisplayAlpha = nil
end

function Notifications:GetBattlegroundMessageFaction(event, message)
    local faction
    if event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" then
        faction = "ALLIANCE"
    elseif event == "CHAT_MSG_BG_SYSTEM_HORDE" then
        faction = "HORDE"
    end

    -- In CTF battlegrounds Blizzard can route a flag notice through the flag's
    -- faction channel rather than the acting team's faction. For action text
    -- such as "The Alliance Flag was picked up...", the team performing the
    -- action is necessarily the opposite faction. Derive that colour from the
    -- named flag object instead of trusting the event channel.
    local mapID = (BattleMaps.ResolveCurrentBattlegroundMapID
            and BattleMaps.ResolveCurrentBattlegroundMapID())
        or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local isCTF = BattleMaps.Pins and BattleMaps.Pins.Private
        and BattleMaps.Pins.Private.IsCaptureTheFlagMap
        and BattleMaps.Pins.Private.IsCaptureTheFlagMap(mapID)
    if not isCTF then return faction end

    local text = NormalizeNotificationText(message)
    if text == "" or not text:find("flag", 1, true) then return faction end

    local flagFaction
    if text:find("alliance flag", 1, true) then
        flagFaction = "ALLIANCE"
    elseif text:find("horde flag", 1, true) then
        flagFaction = "HORDE"
    end
    if not flagFaction then return faction end

    local opposingAction = text:find("picked up", 1, true)
        or text:find("taken", 1, true)
        or text:find("grabbed", 1, true)
        or text:find("dropped", 1, true)
        or text:find("captured", 1, true)
    if opposingAction then
        return flagFaction == "ALLIANCE" and "HORDE" or "ALLIANCE"
    end

    local owningAction = text:find("returned", 1, true)
        or text:find("reset", 1, true)
        or text:find("recovered", 1, true)
    if owningAction then
        return flagFaction
    end

    return faction
end

function Notifications:ShowBattlegroundMessage(event, message)
    local settings = GetNotificationSettings()
    if self.customPresentationEnabled ~= true or not settings or settings.enabled ~= true then return end
    if not self:ShouldManage() then return end
    if self:IsRedundantCrystalNotification(message) then return end

    if message == nil then return end

    self:ApplyDisplayLayout()
    local frame = self:EnsureDisplayFrame()
    local r, g, b = self:GetDefaultNotificationTextColor()
    if settings.colorByFaction ~= false then
        local messageFaction = self:GetBattlegroundMessageFaction(event, message)
        if messageFaction then
            r, g, b = self:GetFactionColor(messageFaction)
        end
    end

    local ok = pcall(frame.text.SetText, frame.text, message)
    if not ok then return end
    frame.text:SetTextColor(r or 1, g or 0.82, b or 0, 1)
    frame:Show()
    frame:Raise()
    self:SuppressNativeForDisplay(3.2)

    self.displaySerial = (self.displaySerial or 0) + 1
    local serial = self.displaySerial
    if C_Timer and C_Timer.After then
        C_Timer.After(3.2, function()
            if Notifications.displaySerial ~= serial then return end
            if Notifications.displayFrame then Notifications.displayFrame:Hide() end
        end)
    end
end

function Notifications:EnsureMover()
    if self.mover then return self.mover end

    local mover = CreateFrame("Frame", "BattleMapsNotificationMover", UIParent, NotificationTemplate())
    self.mover = mover
    mover:SetSize(420, 44)
    mover:SetFrameStrata("DIALOG")
    mover:SetClampedToScreen(true)
    mover:SetMovable(true)
    mover:RegisterForDrag("LeftButton")
    mover:EnableMouse(false)

    if mover.SetBackdrop then
        mover:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        mover:SetBackdropColor(0.03, 0.025, 0.02, 0.90)
        mover:SetBackdropBorderColor(0.91, 0.72, 0.45, 0.95)
    end

    mover.text = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mover.text:SetPoint("CENTER")
    mover.text:SetText("BattleMaps notifications\nDrag to reposition")
    mover.text:SetTextColor(0.96, 0.85, 0.64, 1)

    mover:SetScript("OnDragStart", function(frame)
        if InCombatLockdown and InCombatLockdown() then return end
        frame:StartMoving()
    end)
    mover:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        Notifications:CaptureMoverPosition()
        Notifications:Apply()
        if Notifications.moverUnlocked then Notifications:ShowMover() end
    end)

    mover:SetAlpha(0)
    mover:Show()
    return mover
end

function Notifications:EnsureGuide()
    if self.guide then return self.guide end

    local guide = CreateFrame("Frame", "BattleMapsNotificationGuide", UIParent, NotificationTemplate())
    self.guide = guide
    guide:SetFrameStrata("TOOLTIP")
    guide:EnableMouse(false)
    guide:Hide()

    if guide.SetBackdrop then
        guide:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
        })
        guide:SetBackdropColor(0.08, 0.72, 0.20, 0.09)
        guide:SetBackdropBorderColor(0.18, 1.00, 0.34, 0.95)
    end
    return guide
end

function Notifications:ShowGuide(duration)
    local mover = self:EnsureMover()
    self:AnchorMover()

    local guide = self:EnsureGuide()
    guide:ClearAllPoints()
    guide:SetSize(mover:GetWidth(), mover:GetHeight())
    guide:SetPoint("CENTER", mover, "CENTER", 0, 0)
    guide:Show()
    guide:Raise()

    self.guideSerial = (self.guideSerial or 0) + 1
    local serial = self.guideSerial
    if C_Timer and C_Timer.After then
        C_Timer.After(tonumber(duration) or 0.75, function()
            if Notifications.guideSerial == serial and Notifications.guide then
                Notifications.guide:Hide()
            end
        end)
    end
end

function Notifications:ApplyAndShowGuide(duration)
    if self.nativeFramePlacementEnabled ~= true then
        self.previewOverride = false
        self:Apply()
        return
    end
    self.previewOverride = true
    self:Apply()
    self:ShowGuide(duration)

    local serial = (self.previewOverrideSerial or 0) + 1
    self.previewOverrideSerial = serial
    if C_Timer and C_Timer.After then
        C_Timer.After(tonumber(duration) or 0.75, function()
            if Notifications.previewOverrideSerial ~= serial or Notifications.moverUnlocked then return end
            Notifications.previewOverride = false
            Notifications:Apply()
        end)
    end
end

function Notifications:AnchorMover()
    local settings = GetNotificationSettings()
    if not settings then return end

    local mover = self:EnsureMover()
    -- The mover/guide should represent the actual BattleMaps notification
    -- text region, not Blizzard's much wider RaidWarningFrame.  The custom
    -- display frame uses settings.width before applying notification scale,
    -- so mirror its final on-screen footprint here.
    local width = BattleMaps.Clamp(tonumber(settings.width) or 520, 240, 900)
    local scale = BattleMaps.Clamp(tonumber(settings.scale) or 1, 0.50, 2.00)
    -- Match the exact final on-screen footprint of BattleMapsNotificationDisplay:
    -- the display frame is width x 70 before scale is applied.
    mover:SetSize(math.max(120, width * scale), math.max(44, 70 * scale))
    mover:ClearAllPoints()

    if settings.anchorMode == "MAP" and BattleMaps.MapFrame and BattleMaps.MapFrame.frame then
        local side = settings.mapAnchorSide
        local defaultX, defaultY = self:GetMapAnchorDefaults(side)
        local moverPoint, mapPoint = self:GetMapAttachment(side, settings.notificationAnchorPoint)
        mover:SetClampedToScreen(false)
        mover:SetPoint(
            moverPoint,
            BattleMaps.MapFrame.frame,
            mapPoint,
            tonumber(settings.mapX) or defaultX,
            tonumber(settings.mapY) or defaultY
        )
    else
        mover:SetClampedToScreen(true)
        mover:SetPoint(
            settings.point or "TOP",
            UIParent,
            settings.relativePoint or settings.point or "TOP",
            tonumber(settings.x) or 0,
            tonumber(settings.y) or -100
        )
    end
end

function Notifications:CaptureMoverPosition()
    local settings = GetNotificationSettings()
    local mover = self.mover
    if not settings or not mover then return end

    if settings.anchorMode == "MAP" and BattleMaps.MapFrame and BattleMaps.MapFrame.frame then
        local side = settings.mapAnchorSide
        local moverPoint, mapPoint = self:GetMapAttachment(side, settings.notificationAnchorPoint)
        local moverX, moverY = self:GetFramePointCoordinates(mover, moverPoint)
        local mapX, mapY = self:GetFramePointCoordinates(BattleMaps.MapFrame.frame, mapPoint)
        if moverX and moverY and mapX and mapY then
            settings.mapX = BattleMaps.Clamp(moverX - mapX, -300, 300)
            settings.mapY = BattleMaps.Clamp(moverY - mapY, -300, 300)
        end
    else
        local point, _, relativePoint, x, y = mover:GetPoint(1)
        settings.point = point or "TOP"
        settings.relativePoint = relativePoint or settings.point
        settings.x = BattleMaps.Clamp(tonumber(x) or 0, -300, 300)
        settings.y = BattleMaps.Clamp(tonumber(y) or -100, -300, 300)
    end
end

function Notifications:ApplyFrame(frame)
    if self.nativeFramePlacementEnabled ~= true then return false end
    local settings = GetNotificationSettings()
    if not frame or not settings or not self:ShouldManage() then return false end

    -- Placement-only mode intentionally touches only the outer frame. The
    -- current Blizzard RaidWarningFrame owns pooled FontStrings whose line
    -- counts can become secret in instanced PvP. Do not change their width,
    -- justification, colour, text, scripts, or pool state here.
    self:CaptureNativeState(frame)
    local mover = self:EnsureMover()
    local scale = BattleMaps.Clamp(tonumber(settings.scale) or 1, 0.50, 2.00)

    if frame.SetScale then pcall(frame.SetScale, frame, scale) end
    if frame.ClearAllPoints and frame.SetPoint then
        pcall(frame.ClearAllPoints, frame)
        pcall(frame.SetPoint, frame, "CENTER", mover, "CENTER", 0, 0)
    end
    return true
end

function Notifications:RecordObjectiveStateFromRaidNotice(message)
    -- Current clients can display Kotmogu return/reset notices through the
    -- raid-notice path without consistently firing CHAT_MSG_BG_SYSTEM_*.
    -- Pickup messages already reach the normal battleground-event receiver,
    -- so only replay release-style notices here.
    local text = NormalizeNotificationText(message)
    if text == "" or not text:find("orb", 1, true) then return false end

    local released = text:find("returned", 1, true)
        or text:find("dropped", 1, true)
        or text:find("has reset", 1, true)
        or text:find("was reset", 1, true)
        or text:find("respawned", 1, true)
        or text:find("available", 1, true)
        or text:find("released", 1, true)
    if not released then return false end

    local pins = BattleMaps.Pins
    if not pins or type(pins.RecordTempleOrbMessage) ~= "function" then return false end
    local mapID = (BattleMaps.ResolveCurrentBattlegroundMapID
            and BattleMaps.ResolveCurrentBattlegroundMapID())
        or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    if not mapID then return false end

    local ok, changed = pcall(pins.RecordTempleOrbMessage, pins, mapID, message)
    return ok and changed == true
end

function Notifications:HandleRaidNoticeMessage(frame, message, colorInfo)
    if self.nativeTextStylingEnabled ~= true then return end
    if not self:IsManagedFrame(frame) then return end
    if not self:ShouldManage() then return end

    local safeMessageKey = NormalizeNotificationText(message)
    local messageIsReadable = safeMessageKey ~= ""
    local faction = self:GetFactionFromColorInfo(colorInfo)
    if messageIsReadable then
        faction = faction or self:GetRecordedFaction(message)
    end

    local function ApplyMessageFormatting()
        self:ApplyFrame(frame)

        -- In rated PvP some raid-warning strings are secret values.  Do not
        -- pattern-match, trim, or recolour those strings from this hook;
        -- layout-only notification handling remains safe.
        if not messageIsReadable then return end

        -- Deephaul's standalone crystal instruction is filtered before it
        -- reaches the raid-warning frame.  Do not substitute or shorten useful
        -- crystal notifications here; let Blizzard's text stand unchanged.
        if self:IsRedundantCrystalNotification(message) then return end

        -- EotS has one neutral flag, so the battleground event faction always
        -- describes its current carrier. Colour the whole pickup notice by that
        -- faction before the CTF flag-object safety rule below can suppress it.
        if self:IsEotSFlagPickupMessage(message) then
            -- The BG-system event can be dispatched after Blizzard queues the
            -- raid notice, so re-read the short-lived event cache here.
            local carrierFaction = faction or self:GetRecordedFaction(message)
            if carrierFaction then
                self:ColorMatchingText(frame, message, carrierFaction)
                return
            end
        end

        if self:ApplyFlagNotificationText(frame, message) then return end
        -- Do not fall back to colouring the whole CTF notification by the event
        -- faction. For flag strings the event faction is usually the actor, not
        -- the flag being referenced.
        if self:IsFlagObjectiveMessage(message) then return end
        if faction then self:ColorMatchingText(frame, message, faction) end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, ApplyMessageFormatting)
    else
        ApplyMessageFormatting()
    end
end

function Notifications:InstallHooks()
    -- WoW 12.x can propagate secret values through Blizzard's raid-warning
    -- FontStrings.  Do not hook the native warning frames or replace the global
    -- RaidNotice_AddMessage function: either action puts BattleMaps into a
    -- sensitive Blizzard execution path and can amplify taint from other addons.
    -- Objective tracking is handled directly from CHAT_MSG_BG_SYSTEM_* and
    -- RAID_BOSS_EMOTE/CHAT_MSG_RAID_BOSS_EMOTE in Core/Events.lua.
    self:InstallChatFilters()
end

function Notifications:Apply()
    local settings = GetNotificationSettings()
    if not settings then return end

    local mover = self:EnsureMover()
    self:InstallHooks()
    self:AnchorMover()

    local shouldManage = self:ShouldManage()
    local shouldPlace = self.customPresentationEnabled ~= true
        and self.nativeFramePlacementEnabled == true
        and shouldManage
    for _, frame in ipairs(self:GetManagedFrames()) do
        if shouldPlace then
            self:ApplyFrame(frame)
        else
            self:RestoreNativeState(frame)
        end
    end
    if self.customPresentationEnabled == true then
        self:ApplyDisplayLayout()
        if not shouldManage then
            if self.displayFrame then self.displayFrame:Hide() end
            self:RestoreNativeDisplayAlpha()
        end
    end

    if not self.moverUnlocked then
        mover:EnableMouse(false)
        mover:SetAlpha(0)
    end
    if self.guide and not self.moverUnlocked then self.guide:Hide() end
end

function Notifications:ShowMover()
    if self.nativeFramePlacementEnabled ~= true then return end
    local settings = GetNotificationSettings()
    if not settings or not settings.enabled then return end
    self.previewOverride = true
    self:Apply()
    local mover = self:EnsureMover()
    self:AnchorMover()
    self.moverUnlocked = true
    mover:EnableMouse(true)
    mover:SetAlpha(1)
    mover:Raise()
end

function Notifications:HideMover()
    self.moverUnlocked = false
    self.previewOverride = false
    if self.mover then
        self.mover:EnableMouse(false)
        self.mover:SetAlpha(0)
    end
    if self.guide then self.guide:Hide() end
    self:Apply()
end

function Notifications:ToggleMover()
    if self.moverUnlocked then self:HideMover() else self:ShowMover() end
end

function Notifications:ResetPosition()
    local settings = GetNotificationSettings()
    if not settings then return end

    if settings.anchorMode == "MAP" then
        settings.mapX, settings.mapY = self:GetMapAnchorDefaults(settings.mapAnchorSide)
    else
        settings.point = "TOP"
        settings.relativePoint = "TOP"
        settings.x = 0
        settings.y = -100
    end
    self:Apply()
    if self.moverUnlocked then self:ShowMover() end
end

function Notifications:Preview()
    self.previewOverride = true
    self:ApplyDisplayLayout()
    local frame = self:EnsureDisplayFrame()
    local settings = GetNotificationSettings()
    local r, g, b = self:GetDefaultNotificationTextColor()
    if settings and settings.colorByFaction ~= false then
        r, g, b = self:GetFactionColor("ALLIANCE")
    end
    frame.text:SetText("BattleMaps battleground notification preview")
    frame.text:SetTextColor(r or 1, g or 0.82, b or 0, 1)
    frame:Show()
    frame:Raise()

    local serial = (self.previewOverrideSerial or 0) + 1
    self.previewOverrideSerial = serial
    if C_Timer and C_Timer.After then
        C_Timer.After(2.5, function()
            if Notifications.previewOverrideSerial ~= serial or Notifications.moverUnlocked then return end
            Notifications.previewOverride = false
            if Notifications.displayFrame then Notifications.displayFrame:Hide() end
            Notifications:Apply()
        end)
    end
end


-- Faction-border lifecycle guard --------------------------------------------
-- The score API can retain the battleground-assigned faction after a match or
-- after leaving the instance. MapFrame owns border rendering; this guard only
-- supplies the missing lifecycle invalidation and restores the ordinary neutral
-- frame border once the match has completed.
local function InstallFactionBorderLifecycleGuard()
    local mapFrame = BattleMaps.MapFrame
    if not mapFrame or type(mapFrame.UpdateBorder) ~= "function" then return false end
    if mapFrame.BattleMapsFactionBorderLifecycleGuardInstalled then return true end
    mapFrame.BattleMapsFactionBorderLifecycleGuardInstalled = true

    local originalUpdateBorder = mapFrame.UpdateBorder
    mapFrame.UpdateBorder = function(self, ...)
        local results = { originalUpdateBorder(self, ...) }
        local inLiveBattleground = BattleMaps.IsInLiveBattleground
            and BattleMaps.IsInLiveBattleground()
        local forceNeutral = self.testMode ~= true
            and not (self.IsWorldMapMode and self:IsWorldMapMode())
            and (not inLiveBattleground or BattleMaps.factionBorderMatchComplete == true)

        if forceNeutral and self.frame and self.frame.SetBackdropBorderColor then
            local db = BattleMaps.Database and BattleMaps.Database.Get
                and BattleMaps.Database:Get() or {}
            local borderSize = BattleMaps.Clamp(tonumber(db.frameBorderSize) or 2, 0, 8)
            self.frame:SetBackdropBorderColor(0.25, 0.20, 0.15, borderSize > 0 and 1 or 0)
        end
        return unpack(results)
    end

    local eventFrame = CreateFrame("Frame")
    BattleMaps.factionBorderLifecycleFrame = eventFrame
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD",
        "ZONE_CHANGED_NEW_AREA",
        "UPDATE_BATTLEFIELD_STATUS",
        "PVP_MATCH_ACTIVE",
        "PVP_MATCH_COMPLETE",
        "PVP_MATCH_INACTIVE",
    }) do
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end

    local refreshSerial = 0
    local function QueueBorderRefresh(delay)
        refreshSerial = refreshSerial + 1
        local serial = refreshSerial
        local function Refresh()
            if serial ~= refreshSerial then return end
            local current = BattleMaps.MapFrame
            if current and current.UpdateBorder then current:UpdateBorder() end
        end
        if C_Timer and C_Timer.After then C_Timer.After(delay or 0, Refresh) else Refresh() end
    end

    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PVP_MATCH_COMPLETE" or event == "PVP_MATCH_INACTIVE" then
            BattleMaps.factionBorderMatchComplete = true
        elseif event == "PVP_MATCH_ACTIVE" then
            BattleMaps.factionBorderMatchComplete = false
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- A world load identifies a fresh instance/session. Do not carry a
            -- completed-match border state into the next battleground.
            BattleMaps.factionBorderMatchComplete = false
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            if not (BattleMaps.IsInLiveBattleground and BattleMaps.IsInLiveBattleground()) then
                BattleMaps.factionBorderMatchComplete = false
            end
        end
        QueueBorderRefresh(0.10)
    end)

    mapFrame:UpdateBorder()
    return true
end

if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
        if not InstallFactionBorderLifecycleGuard() then
            C_Timer.After(0.10, InstallFactionBorderLifecycleGuard)
        end
    end)
else
    InstallFactionBorderLifecycleGuard()
end
