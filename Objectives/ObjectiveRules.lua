local _, BattleMaps = ...
BattleMaps = BattleMaps or _G.BattleMaps
if not BattleMaps then return end

local Rules = BattleMaps.ObjectiveRules or {}
BattleMaps.ObjectiveRules = Rules

-- Shared objective classification, alias, folder, and API-ID rules. These are
-- intentionally data/normalisation helpers only; pin rendering and state
-- lifecycle remain in Pins.lua and the split objective modules.
function Rules.NormalizeObjectiveKey(value)
    local ok, text = pcall(tostring, value or "")
    if not ok or not text then return "" end

    ok, text = pcall(string.lower, text)
    if not ok or not text then return "" end

    local function safeGsub(input, pattern, repl)
        local okGsub, output = pcall(string.gsub, input, pattern, repl)
        return okGsub and output or input
    end

    text = safeGsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = safeGsub(text, "|r", "")
    text = safeGsub(text, "&", " and ")
    text = safeGsub(text, "['’]", "")
    text = safeGsub(text, "[^%w]+", "_")
    text = safeGsub(text, "_+", "_")
    text = safeGsub(text, "^_+", "")
    text = safeGsub(text, "_+$", "")
    return text
end

-- Compact objective aliases are deliberately uppercase on disk (BS_A_C,
-- LM_H, etc.). GetFileIDFromPath can be case-sensitive for addon-local files,
-- so compact keys must not pass through NormalizeObjectiveKey(), which lowers
-- everything. Lowercase compact variants are still probed by Pins.lua for
-- compatibility with older local files.
function Rules.NormalizeCompactObjectiveKey(value)
    local ok, text = pcall(tostring, value or "")
    if not ok or not text then return "" end

    ok, text = pcall(string.upper, text)
    if not ok or not text then return "" end

    local function safeGsub(input, pattern, repl)
        local okGsub, output = pcall(string.gsub, input, pattern, repl)
        return okGsub and output or input
    end

    text = safeGsub(text, "|C%x%x%x%x%x%x%x%x", "")
    text = safeGsub(text, "|R", "")
    text = safeGsub(text, "&", "_AND_")
    text = safeGsub(text, "['’]", "")
    text = safeGsub(text, "[^%w]+", "_")
    text = safeGsub(text, "_+", "_")
    text = safeGsub(text, "^_+", "")
    text = safeGsub(text, "_+$", "")
    return text
end

function Rules.AddUniqueObjectiveKey(keys, seen, value)
    local key = Rules.NormalizeObjectiveKey(value)
    if key ~= "" and not seen[key] then
        seen[key] = true
        keys[#keys + 1] = key
    end
end

function Rules.BuildObjectiveKeys(info, index, fallbackKey)
    local keys, seen = {}, {}
    if type(info) == "table" then
        Rules.AddUniqueObjectiveKey(keys, seen, info.name)
        Rules.AddUniqueObjectiveKey(keys, seen, info.atlasName)
        Rules.AddUniqueObjectiveKey(keys, seen, info.atlas)
        Rules.AddUniqueObjectiveKey(keys, seen, info.textureKit)
        Rules.AddUniqueObjectiveKey(keys, seen, info.uiTextureKit)
    end
    if index then Rules.AddUniqueObjectiveKey(keys, seen, "index_" .. tostring(index)) end
    Rules.AddUniqueObjectiveKey(keys, seen, fallbackKey)
    Rules.AddUniqueObjectiveKey(keys, seen, "objective")
    return keys
end

function Rules.InferObjectiveStateWithHints(hints, ...)
    hints = type(hints) == "table" and hints or nil

    local combined = {}
    for index = 1, select("#", ...) do
        combined[#combined + 1] = Rules.NormalizeObjectiveKey(select(index, ...))
    end
    local text = table.concat(combined, "_")

    local hasAlliance = text:find("alliance", 1, true) or text:find("blue", 1, true)
    local hasHorde = text:find("horde", 1, true) or text:find("red", 1, true)
    local hasContested = (hints and hints.contested == true)
        or text:find("contested", 1, true)
        or text:find("assault", 1, true)
        or text:find("under_attack", 1, true)
        or text:find("being_captured", 1, true)
        or text:find("capturing", 1, true)
    local hasUncontrolled = text:find("uncontrolled", 1, true)
        or text:find("uncontrolled_node", 1, true)
        or text:find("unowned", 1, true)

    if hasContested then
        local states = {}
        if hasAlliance then
            states[#states + 1] = "contested_alliance"
            states[#states + 1] = "alliance_contested"
        end
        if hasHorde then
            states[#states + 1] = "contested_horde"
            states[#states + 1] = "horde_contested"
        end
        states[#states + 1] = "contested"
        return states
    end

    if hasAlliance then return "alliance" end
    if hasHorde then return "horde" end
    if text:find("neutral", 1, true) or text:find("available", 1, true) then return "neutral" end
    if hasUncontrolled then return "uncontrolled" end

    if hints and hints.defaultNeutral == true then return "neutral" end
    return nil
end

function Rules.InferObjectiveState(...)
    return Rules.InferObjectiveStateWithHints(nil, ...)
end

function Rules.InferStationaryObjectiveState(info, defaultNeutral)
    info = type(info) == "table" and info or nil

    local factionID = info and tonumber(info.factionID) or nil
    local hordeFaction = Enum and Enum.PvPFaction and Enum.PvPFaction.Horde or 0
    local allianceFaction = Enum and Enum.PvPFaction and Enum.PvPFaction.Alliance or 1

    local factionHint
    if factionID == allianceFaction then
        factionHint = "alliance"
    elseif factionID == hordeFaction then
        factionHint = "horde"
    end

    local contested = info and (info.shouldGlow == true or info.shouldGlow == 1) or false

    return Rules.InferObjectiveStateWithHints({
        contested = contested,
        defaultNeutral = defaultNeutral == true,
    },
        info and info.name,
        info and info.description,
        info and info.atlasName,
        info and info.atlas,
        info and info.textureKit,
        info and info.uiTextureKit,
        factionHint
    )
end

function Rules.GetObjectiveVisualSignature(info)
    if type(info) ~= "table" then return "" end
    return table.concat({
        tostring(info.textureIndex or ""),
        Rules.NormalizeObjectiveKey(info.atlasName or info.atlas),
        Rules.NormalizeObjectiveKey(info.textureKit or info.uiTextureKit),
    }, "|")
end

-- Custom objective artwork is centred on Blizzard's objective coordinate by
-- default. Individual files can receive a small visual correction without
-- changing the underlying map coordinate. Offsets are expressed in pixels at
-- the standard 32 px objective size and scale with the objective-size slider.
local ARATHI_BASIN_OBJECTIVE_LAYOUTS = {
    stationary = {
        -- The supplied Lumber Mill artwork is slightly bottom-weighted.
        -- Raise the artwork while leaving the actual POI coordinate intact.
        lumber_mill = { offsetX = 0, offsetY = 4 },
        lm = { offsetX = 0, offsetY = 4 },
    },
}

local CUSTOM_OBJECTIVE_LAYOUTS_BY_MAP_ID = {
    [112] = ARATHI_BASIN_OBJECTIVE_LAYOUTS,  -- legacy/internal AB identifier
    [1366] = ARATHI_BASIN_OBJECTIVE_LAYOUTS, -- live Arathi Basin UI map ID
}

local CUSTOM_OBJECTIVE_LAYOUTS_BY_MAP_NAME = {
    arathi_basin = ARATHI_BASIN_OBJECTIVE_LAYOUTS,
}

local CANONICAL_OBJECTIVE_SUFFIXES = {
    -- Ordered longest-first for layout-key stripping.
    "a_c", "h_c", "a", "h", "n",
}

local OBJECTIVE_TEXTURE_FOLDER_BY_MAP_NAME = {
    arathi_basin = 1366,
    eye_of_the_storm = 210,
    battle_for_gilneas = 275,
    temple_of_kotmogu = 417,
    silvershard_mines = 423,
    deephaul_ravine = 2345,
    seething_shore = 907,
}

local OBJECTIVE_TEXTURE_FOLDER_BY_MAP_ID = {
    [112] = 1366,
    [1366] = 1366,
    [210] = 210,
    [275] = 275,
    [417] = 417,
    [423] = 423,
    [727] = 423,
    [761] = 275,
    [998] = 417,
    [907] = 907,
    [1803] = 907,
    [2345] = 2345,
}

local OBJECTIVE_API_MAP_ID_BY_MAP_ID = {
    -- BattleMaps configuration ID -> current WoW UI map ID.
    [112] = 1366, -- Arathi Basin
    [210] = 112,  -- Eye of the Storm
    [761] = 275,  -- Battle for Gilneas historical/instance ID -> configured UI map ID
    [907] = 1803, -- Seething Shore configuration ID -> live UI map ID
}

function Rules.ResolveObjectiveAPIMapID(mapID)
    mapID = tonumber(mapID)
    return OBJECTIVE_API_MAP_ID_BY_MAP_ID[mapID] or mapID
end

local ARATHI_BASIN_SHORT_KEYS = {
    { patterns = { "blacksmith" }, aliases = { "BS" } },
    { patterns = { "lumber_mill", "lumbermill" }, aliases = { "LM" } },
    { patterns = { "gold_mine", "goldmine", "mine", "mines" }, aliases = { "GM" } },
    { patterns = { "stables", "stable" }, aliases = { "ST" } },
    { patterns = { "farm" }, aliases = { "FM" } },
}

local EYE_OF_THE_STORM_SHORT_KEYS = {
    { patterns = { "mage_tower", "magetower" }, aliases = { "MT" } },
    { patterns = { "draenei_ruins", "draeneiruins" }, aliases = { "DR" } },
    { patterns = { "fel_reaver_ruins", "felreaverruins" }, aliases = { "FRR", "FR" } },
    { patterns = { "blood_elf_tower", "bloodelftower" }, aliases = { "BET", "BE" } },
    { patterns = { "netherstorm_flag", "netherstormflag" }, aliases = { "NF" } },
}

local TEMPLE_OF_KOTMOGU_OBJECTIVE_ALIASES = {
    -- Blizzard exposes Kotmogu stationary orb icons through Area POI IDs and
    -- generic orb atlases instead of stable colour names. These aliases let
    -- addon-local files use readable names such as purple_orb_N.tga.
    --
    -- Carried Kotmogu orbs also arrive through the battlefield-flag API as
    -- index_1..index_4 without a stable faction state. They use the same colour
    -- identity but intentionally do not use _A/_H/_N suffixes on disk:
    -- carried/purple_orb.tga, carried/green_orb.tga, etc.
    --
    -- If Blizzard changes the icon/order, only this mapping should need
    -- correction; do not rename user-facing texture files back to index_####.
    -- Stationary orb identity is deliberately not inferred from AreaPOI index
    -- or atlas order. Those values have changed between client builds and can
    -- map the blue location to green artwork. ObjectiveTextures.lua resolves
    -- stationary orb colour from its fixed map quadrant and applies the exact
    -- colour file directly.

    -- Carried-orb indexes are kept independent from stationary AreaPOI indexes.
    -- If live testing proves these differ too, adjust only these four lines.
    { patterns = { "index_1" }, aliases = { "purple_orb" } },
    { patterns = { "index_2" }, aliases = { "green_orb" } },
    { patterns = { "index_3" }, aliases = { "orange_orb" } },
    { patterns = { "index_4" }, aliases = { "blue_orb" } },
}


local SEETHING_SHORE_OBJECTIVE_ALIASES = {
    -- Seething Shore exposes every possible Azerite spawn through generic and
    -- build-dependent POI identifiers. All of those locations use the same
    -- stationary artwork, so the always-present "objective" key is an
    -- intentional catch-all for this battleground. Keep several readable
    -- aliases so existing user texture names continue to resolve.
    {
        patterns = {
            "objective", "stationary", "azerite", "azerite_node",
            "azerite_spawn", "azerite_deposit", "seething_shore",
        },
        aliases = {
            "azerite", "azerite_node", "azerite_spawn", "azerite_deposit",
            "node", "objective", "seething_shore", "az", "ss",
        },
    },
}

local TEMPLE_OF_KOTMOGU_CARRIED_ORB_COLORS = {
    [1] = "purple",
    [2] = "green",
    [3] = "orange",
    [4] = "blue",
}

local TEMPLE_OF_KOTMOGU_ORB_TEXTURE_KEYS = {
    purple = "purple_orb",
    green = "green_orb",
    orange = "orange_orb",
    blue = "blue_orb",
}

local TEMPLE_OF_KOTMOGU_ORB_SPAWN_POSITIONS = {
    -- BattleMaps map coordinates for the four fixed Kotmogu orb pads. These
    -- are also used by PreviewPins.lua. Keeping them available in the shared
    -- rules module lets the carried-objective resolver identify a newly picked
    -- orb without relying on Blizzard's compact/reordered flag-slot index.
    purple = { 0.392, 0.408 },
    orange = { 0.608, 0.408 },
    green = { 0.392, 0.658 },
    blue = { 0.608, 0.658 },
}

local DEEPHAUL_RAVINE_SHORT_KEYS = {
    { patterns = { "crystal", "earthen_crystal", "center_crystal", "ravine_crystal" }, aliases = { "CR" } },
}

local OBJECTIVE_SHORT_KEYS_BY_MAP_ID = {
    [112] = ARATHI_BASIN_SHORT_KEYS,   -- legacy/internal AB identifier
    [1366] = ARATHI_BASIN_SHORT_KEYS,  -- live Arathi Basin UI map ID
    [210] = EYE_OF_THE_STORM_SHORT_KEYS,
    [2345] = DEEPHAUL_RAVINE_SHORT_KEYS,
}

local OBJECTIVE_SHORT_KEYS_BY_MAP_NAME = {
    arathi_basin = ARATHI_BASIN_SHORT_KEYS,
    eye_of_the_storm = EYE_OF_THE_STORM_SHORT_KEYS,
    deephaul_ravine = DEEPHAUL_RAVINE_SHORT_KEYS,
}

local OBJECTIVE_ALIAS_KEYS_BY_MAP_ID = {
    [417] = TEMPLE_OF_KOTMOGU_OBJECTIVE_ALIASES,
    [998] = TEMPLE_OF_KOTMOGU_OBJECTIVE_ALIASES,
    [907] = SEETHING_SHORE_OBJECTIVE_ALIASES,
    [1803] = SEETHING_SHORE_OBJECTIVE_ALIASES,
}

local OBJECTIVE_ALIAS_KEYS_BY_MAP_NAME = {
    temple_of_kotmogu = TEMPLE_OF_KOTMOGU_OBJECTIVE_ALIASES,
    seething_shore = SEETHING_SHORE_OBJECTIVE_ALIASES,
}

function Rules.GetObjectiveMapNameKey(mapID)
    mapID = tonumber(mapID)
    if not mapID then return "" end

    -- ID 112 is BattleMaps' legacy/configuration ID for Arathi Basin, but the
    -- modern C_Map namespace uses 112 for Eye of the Storm. Resolve the addon
    -- identity before consulting C_Map so objective aliases do not cross maps.
    if mapID == 112 then return "arathi_basin" end

    local battlegrounds = BattleMaps.Battlegrounds
    if battlegrounds and battlegrounds.GetName then
        local ok, name = pcall(battlegrounds.GetName, battlegrounds, mapID)
        if ok then
            local key = Rules.NormalizeObjectiveKey(name)
            if key ~= "" then return key end
        end
    end

    local apiMapID = Rules.ResolveObjectiveAPIMapID(mapID)
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, apiMapID)
        if ok and type(info) == "table" and info.name then
            local key = Rules.NormalizeObjectiveKey(info.name)
            if key ~= "" then return key end
        end
    end
    return ""
end

function Rules.IsArathiBasinMap(mapID)
    local mapNameKey = Rules.GetObjectiveMapNameKey(mapID)
    if mapNameKey == "arathi_basin" then return true end

    mapID = tonumber(mapID)
    return mapID == 112 or mapID == 1366
end

function Rules.IsCaptureTheFlagMap(mapID)
    local mapNameKey = Rules.GetObjectiveMapNameKey(mapID)
    return mapNameKey == "warsong_gulch"
        or mapNameKey == "twin_peaks"
end

function Rules.IsTempleOfKotmoguMap(mapID)
    local mapNameKey = Rules.GetObjectiveMapNameKey(mapID)
    return mapNameKey == "temple_of_kotmogu"
        or tonumber(mapID) == 417
        or tonumber(mapID) == 998
end

function Rules.IsSeethingShoreMap(mapID)
    local mapNameKey = Rules.GetObjectiveMapNameKey(mapID)
    return mapNameKey == "seething_shore"
        or tonumber(mapID) == 907
        or tonumber(mapID) == 1803
end

local function SafePublicNumber(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if ok and secret then return nil end
    end
    local ok, numberValue = pcall(tonumber, value)
    if not ok then return nil end
    return numberValue
end

local function ReadVectorXY(position)
    if not position then return nil, nil end
    if type(position.GetXY) == "function" then
        local ok, x, y = pcall(position.GetXY, position)
        if ok then return SafePublicNumber(x), SafePublicNumber(y) end
    end
    return SafePublicNumber(position.x), SafePublicNumber(position.y)
end

local function GetSeethingShoreAzeriteAreaPOIs(mapID)
    if not Rules.IsSeethingShoreMap(mapID) or not C_AreaPoiInfo then return {} end

    -- Seething Shore has used more than one UI map ID across client builds.
    -- Prefer the live player's map, then probe the configured/API aliases. The
    -- POI ID must always be queried against the same map ID that supplied it.
    local candidateMapIDs, seenMapIDs = {}, {}
    local function AddCandidate(value)
        value = SafePublicNumber(value)
        if value and value > 0 and not seenMapIDs[value] then
            seenMapIDs[value] = true
            candidateMapIDs[#candidateMapIDs + 1] = value
        end
    end

    if BattleMaps.GetBattlegroundUIMapID then
        local ok, liveMapID = pcall(BattleMaps.GetBattlegroundUIMapID, mapID, true)
        if ok then AddCandidate(liveMapID) end
    end
    AddCandidate(Rules.ResolveObjectiveAPIMapID(mapID))
    AddCandidate(mapID)
    AddCandidate(1803)
    AddCandidate(907)

    local records = {}
    local seenRecord = {}

    for _, apiMapID in ipairs(candidateMapIDs) do
        local eventPOIs, ordinaryPOIs = {}, {}
        local orderedIDs, seenIDs = {}, {}
        local function AddIDs(ids, source)
            if type(ids) ~= "table" then return end
            for _, areaPoiID in ipairs(ids) do
                if areaPoiID then
                    if source == "event" then
                        eventPOIs[areaPoiID] = true
                    else
                        ordinaryPOIs[areaPoiID] = true
                    end
                    if not seenIDs[areaPoiID] then
                        seenIDs[areaPoiID] = true
                        orderedIDs[#orderedIDs + 1] = areaPoiID
                    end
                end
            end
        end

        if type(GetAreaPOIsForPlayerByMapIDCached) == "function" then
            local ok, ids = pcall(GetAreaPOIsForPlayerByMapIDCached, apiMapID)
            if ok then AddIDs(ids, "ordinary") end
        end
        if type(C_AreaPoiInfo.GetAreaPOIForMap) == "function" then
            local ok, ids = pcall(C_AreaPoiInfo.GetAreaPOIForMap, apiMapID)
            if ok then AddIDs(ids, "ordinary") end
        end
        if type(C_AreaPoiInfo.GetEventsForMap) == "function" then
            local ok, ids = pcall(C_AreaPoiInfo.GetEventsForMap, apiMapID)
            if ok then AddIDs(ids, "event") end
        end

        for _, areaPoiID in ipairs(orderedIDs) do
            local okInfo, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, apiMapID, areaPoiID)
            if okInfo and type(info) == "table" then
                local x, y = ReadVectorXY(info.position)
                if x and y then
                    local timed, hideTimerInTooltip, secondsLeft = false, false, nil
                    if type(C_AreaPoiInfo.IsAreaPOITimed) == "function" then
                        local okTimed, isTimed, hideTimer = pcall(C_AreaPoiInfo.IsAreaPOITimed, areaPoiID)
                        timed = okTimed and isTimed == true
                        hideTimerInTooltip = okTimed and hideTimer == true
                    end

                    -- Do not gate GetAreaPOISecondsLeft behind IsAreaPOITimed.
                    -- Seething Shore's geyser POIs can expose a live seconds-left
                    -- value while the generic timed flag is false/hidden. That
                    -- was causing every visible fissure to be classified as a
                    -- fully spawned Azerite node, so the neutral spawning art,
                    -- progress reveal, and countdown never ran in live matches.
                    if type(C_AreaPoiInfo.GetAreaPOISecondsLeft) == "function" then
                        local okSeconds, value = pcall(C_AreaPoiInfo.GetAreaPOISecondsLeft, areaPoiID)
                        if okSeconds then secondsLeft = SafePublicNumber(value) end
                    end

                    local text = Rules.NormalizeObjectiveKey(
                        tostring(info.name or "") .. " " .. tostring(info.description or "")
                    )
                    local textSaysSpawning = text:find("spawn", 1, true)
                        or text:find("incoming", 1, true)
                        or text:find("arriv", 1, true)
                    local locked = info.isLocked == true
                    local hasSpawnCountdown = secondsLeft and secondsLeft > 0

                    -- IDs returned by GetAreaPOIForMap are already the POIs
                    -- Blizzard considers visible on that map. A locked POI or
                    -- one with seconds remaining is the pre-spawn/geyser phase;
                    -- only an unlocked, untimed visible POI is collectible.
                    local current = ordinaryPOIs[areaPoiID] == true
                        or eventPOIs[areaPoiID] == true
                        or info.isCurrentEvent == true
                        or info.shouldGlow == true
                        or textSaysSpawning ~= nil
                        or hasSpawnCountdown
                    local state = "dormant"
                    if locked or timed or textSaysSpawning or hasSpawnCountdown then
                        state = "spawning"
                    elseif current then
                        state = "active"
                    end

                    local recordKey = tostring(areaPoiID)
                        .. ":" .. tostring(math.floor((x * 10000) + 0.5))
                        .. ":" .. tostring(math.floor((y * 10000) + 0.5))
                    if not seenRecord[recordKey] then
                        seenRecord[recordKey] = true
                        records[#records + 1] = {
                            areaPoiID = areaPoiID,
                            apiMapID = apiMapID,
                            x = x,
                            y = y,
                            name = info.name,
                            description = info.description,
                            state = state,
                            timed = timed,
                            hideTimerInTooltip = hideTimerInTooltip,
                            secondsLeft = secondsLeft,
                            isLocked = locked,
                            shouldGlow = info.shouldGlow == true,
                            isCurrentEvent = info.isCurrentEvent == true,
                            isEventPOI = eventPOIs[areaPoiID] == true,
                            isOrdinaryPOI = ordinaryPOIs[areaPoiID] == true,
                        }
                    end
                end
            end
        end
    end

    return records
end


function Rules.GetSeethingShoreAzeritePOIs(mapID)
    if not Rules.IsSeethingShoreMap(mapID) then return {} end

    -- Live Seething Shore does not currently expose Azerite nodes through
    -- C_AreaPoiInfo. Blizzard's battlefield map instead publishes them as
    -- vignettes. The atlas is an explicit state signal:
    --   AzeriteSpawning = geyser / not yet collectible
    --   AzeriteReady    = collectible Azerite node
    -- Prefer that source and retain the AreaPOI path only as a compatibility
    -- fallback for client builds that expose the older data again.
    if C_VignetteInfo
        and type(C_VignetteInfo.GetVignettes) == "function"
        and type(C_VignetteInfo.GetVignetteInfo) == "function"
        and type(C_VignetteInfo.GetVignettePosition) == "function" then

        local candidateMapIDs, seenMapIDs = {}, {}
        local function AddCandidate(value)
            value = SafePublicNumber(value)
            if value and value > 0 and not seenMapIDs[value] then
                seenMapIDs[value] = true
                candidateMapIDs[#candidateMapIDs + 1] = value
            end
        end

        if BattleMaps.GetBattlegroundUIMapID then
            local ok, liveMapID = pcall(BattleMaps.GetBattlegroundUIMapID, mapID, true)
            if ok then AddCandidate(liveMapID) end
        end
        AddCandidate(Rules.ResolveObjectiveAPIMapID(mapID))
        AddCandidate(mapID)
        AddCandidate(1803)
        AddCandidate(907)

        local okVignettes, vignetteGUIDs = pcall(C_VignetteInfo.GetVignettes)
        if okVignettes and type(vignetteGUIDs) == "table" then
            local records = {}
            for _, vignetteGUID in ipairs(vignetteGUIDs) do
                local okInfo, info = pcall(C_VignetteInfo.GetVignetteInfo, vignetteGUID)
                if okInfo and type(info) == "table" then
                    local atlas = string.lower(tostring(info.atlasName or ""))
                    local state
                    if atlas == "azeritespawning" then
                        state = "spawning"
                    elseif atlas == "azeriteready" then
                        state = "active"
                    end

                    if state then
                        local x, y, positionMapID
                        for _, apiMapID in ipairs(candidateMapIDs) do
                            local okPosition, position = pcall(
                                C_VignetteInfo.GetVignettePosition,
                                vignetteGUID,
                                apiMapID
                            )
                            if okPosition and position then
                                x, y = ReadVectorXY(position)
                                if x and y then
                                    positionMapID = apiMapID
                                    break
                                end
                            end
                        end

                        if x and y then
                            records[#records + 1] = {
                                -- Keep the legacy field name because the live pin/timer
                                -- renderer only needs a stable record identity here.
                                areaPoiID = vignetteGUID,
                                vignetteGUID = vignetteGUID,
                                vignetteID = SafePublicNumber(info.vignetteID),
                                apiMapID = positionMapID,
                                x = x,
                                y = y,
                                name = info.name,
                                description = state == "spawning"
                                    and "Azerite geyser is forming."
                                    or "Azerite is available.",
                                atlasName = info.atlasName,
                                state = state,
                                timed = state == "spawning",
                                secondsLeft = nil,
                                isLocked = state == "spawning",
                                isCurrentEvent = true,
                                isVignette = true,
                            }
                        end
                    end
                end
            end

            if #records > 0 then
                return records
            end
        end
    end

    return GetSeethingShoreAzeriteAreaPOIs(mapID)
end


function Rules.GetTempleOrbColorByCarriedIndex(index)
    return TEMPLE_OF_KOTMOGU_CARRIED_ORB_COLORS[tonumber(index)]
end

function Rules.GetTempleOrbTextureKey(color)
    color = Rules.NormalizeObjectiveKey(color)
    return TEMPLE_OF_KOTMOGU_ORB_TEXTURE_KEYS[color]
end

function Rules.GetTempleOrbSpawnPosition(color)
    color = Rules.NormalizeObjectiveKey(color)
    local position = TEMPLE_OF_KOTMOGU_ORB_SPAWN_POSITIONS[color]
    if not position then return nil, nil end
    return position[1], position[2]
end

function Rules.GetTempleOrbTexturePath(mapID, category, color)
    color = Rules.NormalizeObjectiveKey(color)
    category = Rules.NormalizeObjectiveKey(category)
    local stem = TEMPLE_OF_KOTMOGU_ORB_TEXTURE_KEYS[color]
    if not stem or (category ~= "stationary" and category ~= "carried") then
        return nil
    end

    local folderID = Rules.GetObjectiveTextureFolderID(mapID) or 417
    local suffix = category == "stationary" and "_N" or ""
    return string.format(
        "Interface\\AddOns\\BattleMaps\\Media\\Objectives\\%s\\%s\\%s%s.tga",
        tostring(folderID),
        category,
        stem,
        suffix
    )
end

function Rules.GetTempleOrbColorByPosition(x, y)
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return nil end

    -- Match stationary Kotmogu POIs to the nearest fixed orb pad instead of
    -- dividing the map with a broad centre dead-zone. The authored purple and
    -- orange pads sit at y=0.408, only 0.092 from map centre; the old 0.10
    -- dead-zone therefore rejected both upper pads and prevented them from
    -- being hidden while those orbs were carried. A tight pad-radius keeps
    -- centre-room carried markers and unrelated POIs unclassified.
    local bestColor, bestDistanceSquared
    for color, position in pairs(TEMPLE_OF_KOTMOGU_ORB_SPAWN_POSITIONS) do
        local dx = x - position[1]
        local dy = y - position[2]
        local distanceSquared = (dx * dx) + (dy * dy)
        if not bestDistanceSquared or distanceSquared < bestDistanceSquared then
            bestColor = color
            bestDistanceSquared = distanceSquared
        end
    end

    -- Ten percent of map width is generous enough for provider-coordinate
    -- variation but remains below the roughly fourteen-percent distance from
    -- any pad to the centre of the arena.
    if bestDistanceSquared and bestDistanceSquared <= 0.0100 then
        return bestColor
    end
    return nil
end

function Rules.GetObjectiveShortRules(mapID)
    local mapNameKey = Rules.GetObjectiveMapNameKey(mapID)
    local byName = OBJECTIVE_SHORT_KEYS_BY_MAP_NAME[mapNameKey]
    if byName then return byName end
    return OBJECTIVE_SHORT_KEYS_BY_MAP_ID[tonumber(mapID)]
end

function Rules.GetObjectiveShortKeys(mapID, keys)
    local rules = Rules.GetObjectiveShortRules(mapID)
    if not rules then return {} end

    local haystack = "_" .. table.concat(keys or {}, "_") .. "_"
    local result, seen = {}, {}
    for _, rule in ipairs(rules) do
        local matched = false
        for _, pattern in ipairs(rule.patterns or {}) do
            pattern = Rules.NormalizeObjectiveKey(pattern)
            if pattern ~= "" and haystack:find(pattern, 1, true) then
                matched = true
                break
            end
        end
        if matched then
            for _, alias in ipairs(rule.aliases or {}) do
                local normalized = Rules.NormalizeCompactObjectiveKey(alias)
                if normalized ~= "" and not seen[normalized] then
                    seen[normalized] = true
                    result[#result + 1] = normalized
                end
            end
        end
    end
    return result
end

local function GetObjectiveAliasRules(mapID)
    local mapNameKey = Rules.GetObjectiveMapNameKey(mapID)
    local byName = OBJECTIVE_ALIAS_KEYS_BY_MAP_NAME[mapNameKey]
    if byName then return byName end
    return OBJECTIVE_ALIAS_KEYS_BY_MAP_ID[tonumber(mapID)]
end

function Rules.GetObjectiveAliasKeys(mapID, keys)
    local rules = GetObjectiveAliasRules(mapID)
    if not rules then return {} end

    local haystack = "_" .. table.concat(keys or {}, "_") .. "_"
    local result, seen = {}, {}
    for _, rule in ipairs(rules) do
        local matched = false
        for _, pattern in ipairs(rule.patterns or {}) do
            pattern = Rules.NormalizeObjectiveKey(pattern)
            if pattern ~= "" and haystack:find("_" .. pattern .. "_", 1, true) then
                matched = true
                break
            end
        end
        if matched then
            for _, alias in ipairs(rule.aliases or {}) do
                local normalized = Rules.NormalizeObjectiveKey(alias)
                if normalized ~= "" and not seen[normalized] then
                    seen[normalized] = true
                    result[#result + 1] = normalized
                end
            end
        end
    end
    return result
end

function Rules.GetStationaryMessageCacheKey(mapID)
    local mapNameKey = Rules.GetObjectiveMapNameKey(mapID)
    if mapNameKey ~= "" then return mapNameKey end
    return tostring(tonumber(mapID) or mapID or "")
end

function Rules.StripObjectiveStateSuffix(stem)
    stem = Rules.NormalizeObjectiveKey(stem)
    for _, suffixName in ipairs(CANONICAL_OBJECTIVE_SUFFIXES) do
        local suffix = "_" .. suffixName
        if #stem > #suffix and stem:sub(-#suffix) == suffix then
            return stem:sub(1, #stem - #suffix)
        end
    end
    return stem
end

function Rules.GetCustomObjectiveLayout(mapID, category, stem)
    local mapNameKey = Rules.GetObjectiveMapNameKey(mapID)
    local mapLayouts = CUSTOM_OBJECTIVE_LAYOUTS_BY_MAP_NAME[mapNameKey]
        or CUSTOM_OBJECTIVE_LAYOUTS_BY_MAP_ID[tonumber(mapID)]
    local categoryLayouts = mapLayouts and mapLayouts[Rules.NormalizeObjectiveKey(category)]
    if not categoryLayouts then return nil end

    stem = Rules.NormalizeObjectiveKey(stem)
    return categoryLayouts[stem]
        or categoryLayouts[Rules.StripObjectiveStateSuffix(stem)]
        or categoryLayouts.default
end

function Rules.GetObjectiveTextureFolderID(mapID)
    local mapNameKey = Rules.GetObjectiveMapNameKey(mapID)
    return OBJECTIVE_TEXTURE_FOLDER_BY_MAP_NAME[mapNameKey]
        or OBJECTIVE_TEXTURE_FOLDER_BY_MAP_ID[tonumber(mapID)]
        or tonumber(mapID)
end

function Rules.ObjectiveCategoryEnabled(mapID, category)
    if not mapID or type(category) ~= "string" then return false end
    if not BattleMaps.GetObjectiveCapabilities then return true end
    local capabilities = BattleMaps.GetObjectiveCapabilities(mapID)
    return type(capabilities) ~= "table" or capabilities[category] == true
end

function Rules.GetAreaPOIIDs(mapID)
    -- BattlefieldMap installs both AreaPOIDataProvider and
    -- AreaPOIEventDataProvider. Merge every public source and de-duplicate it.
    mapID = Rules.ResolveObjectiveAPIMapID(mapID)
    local result, seen = {}, {}

    local function AddIDs(ids)
        if type(ids) ~= "table" then return end
        for _, poiID in ipairs(ids) do
            if poiID and not seen[poiID] then
                seen[poiID] = true
                result[#result + 1] = poiID
            end
        end
    end

    if type(GetAreaPOIsForPlayerByMapIDCached) == "function" then
        local ok, ids = pcall(GetAreaPOIsForPlayerByMapIDCached, mapID)
        if ok then AddIDs(ids) end
    end

    if C_AreaPoiInfo then
        if C_AreaPoiInfo.GetAreaPOIForMap then
            local ok, ids = pcall(C_AreaPoiInfo.GetAreaPOIForMap, mapID)
            if ok then AddIDs(ids) end
        end
        if C_AreaPoiInfo.GetEventsForMap then
            local ok, ids = pcall(C_AreaPoiInfo.GetEventsForMap, mapID)
            if ok then AddIDs(ids) end
        end
    end

    return result
end
