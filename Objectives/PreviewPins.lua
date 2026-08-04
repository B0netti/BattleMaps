local addonName, BattleMaps = ...
BattleMaps = BattleMaps or _G.BattleMaps
if not BattleMaps or not BattleMaps.Pins then return end

local Pins = BattleMaps.Pins
local Private = Pins.Private or {}

--[[
BattleMaps module contract: PreviewPins.lua

Owns offline/edit/test previews for stationary objectives, carried objectives,
vehicles, cached POI artwork, and objective-preview movement/effects.

UnitPins.lua exclusively owns player arrows, teammate pins, healer overlays,
stacking, death markers, and unit tooltips in both live and Test modes.
]]

local PIN_ZOOM_RESPONSE = 0.50
local CUSTOM_AREA_POI_VISUAL_SIZE = 16
local FLAG_PIN_FRAME_LEVEL_OFFSET = 59

local function MissingPrivate(name)
    return function()
        if BattleMaps and BattleMaps.Debug then
            BattleMaps.Debug("PreviewPins missing private helper: " .. tostring(name))
        end
        return nil
    end
end

local CreateTexturePin = Private.CreateTexturePin or MissingPrivate("CreateTexturePin")
local EnsureObjectiveCaptureTimerTextures = Private.EnsureObjectiveCaptureTimerTextures or function() end
local BuildObjectiveKeys = Private.BuildObjectiveKeys or MissingPrivate("BuildObjectiveKeys")
local ResolveObjectiveAPIMapID = Private.ResolveObjectiveAPIMapID or function(mapID) return mapID end
local InferObjectiveState = Private.InferObjectiveState or function() return nil end
local InferStationaryObjectiveState = Private.InferStationaryObjectiveState or function() return nil end
local SetPOITexture = Private.SetPOITexture or function() return false end
local GetVehicleObjectiveKey = Private.GetVehicleObjectiveKey or function() return "vehicle" end
local GetAreaPOIIDs = Private.GetAreaPOIIDs or function() return {} end
local GetCarriedObjectiveTexture = Private.GetCarriedObjectiveTexture or function() return nil end
local NormalizeObjectiveKey = Private.NormalizeObjectiveKey or function(value)
    local ok, text = pcall(tostring, value or "")
    if not ok or type(text) ~= "string" then return "" end
    ok, text = pcall(string.lower, text)
    if not ok or type(text) ~= "string" then return "" end
    return text:gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
end

-- pin category. These frames are runtime-only and never enter SavedVariables.
local DUMMY_POSITIONS = {
    stationary = { 0.24, 0.74 },
    carried = { 0.50, 0.78 },
    vehicle = { 0.76, 0.74 },
    vehicleAlliance = { 0.36, 0.42 },
    vehicleHorde = { 0.64, 0.58 },
}

-- Test-mode carried objectives should move slowly enough to inspect the trail.
-- The movement portion is four times slower than the original 5.8s loop, then
-- holds briefly at the loop point so the preview is readable rather than busy.
local DUMMY_CARRIED_TEST_MOVE_SECONDS = 23.20
local DUMMY_CARRIED_TEST_PAUSE_SECONDS = 3.00

local function GetDummyCarriedTestPosition()
    if not BattleMaps.MapFrame or BattleMaps.MapFrame.testMode ~= true
        or type(GetTime) ~= "function" then
        return DUMMY_POSITIONS.carried
    end

    -- Linear path, not a loop around the objective.  This keeps the test trail
    -- readable as a wake behind the carried objective rather than a rotating
    -- beacon around it.
    local loopSeconds = DUMMY_CARRIED_TEST_MOVE_SECONDS + (DUMMY_CARRIED_TEST_PAUSE_SECONDS * 2)
    local now = GetTime() or 0
    local loopIndex = math.floor(now / loopSeconds)
    local elapsed = now - (loopIndex * loopSeconds)
    local progress

    if elapsed <= DUMMY_CARRIED_TEST_PAUSE_SECONDS then
        progress = 0
    elseif elapsed >= DUMMY_CARRIED_TEST_PAUSE_SECONDS + DUMMY_CARRIED_TEST_MOVE_SECONDS then
        progress = 1
    else
        progress = (elapsed - DUMMY_CARRIED_TEST_PAUSE_SECONDS) / DUMMY_CARRIED_TEST_MOVE_SECONDS
    end

    local startX, startY = 0.34, 0.74
    local endX, endY = 0.66, 0.74
    local x = startX + ((endX - startX) * progress)
    local y = startY + ((endY - startY) * progress)
    return {
        BattleMaps.Clamp(x, 0.08, 0.92),
        BattleMaps.Clamp(y, 0.12, 0.88),
        loopIndex = loopIndex,
    }
end


local OBJECTIVE_NAME_WORDS = {
    "objective", "base", "flag", "tower", "farm", "stables", "blacksmith",
    "lumber", "mine", "mill", "workshop", "hangar", "docks", "quarry",
    "refinery", "ruins", "shrine", "orb", "cart", "azerite", "crystal",
    "graveyard", "node", "capture",
}

local PREVIEW_FLAG_TEXTURE = "Interface\\Icons\\INV_BannerPVP_01"
local PREVIEW_ORB_TEXTURE = "Interface\\Icons\\INV_Misc_Orb_05"
local PREVIEW_AZERITE_TEXTURE = "Interface\\Icons\\INV_Misc_Azerite_01"
local PREVIEW_RESOURCE_TEXTURE = "Interface\\Icons\\INV_Ore_Arcanite_01"
local PREVIEW_VEHICLE_TEXTURE = "Interface\\Icons\\Ability_Vehicle_SiegeEngineCharge"
local PREVIEW_CART_TEXTURE = "Interface\\Icons\\INV_Misc_EngGizmos_03"
local PREVIEW_OBJECTIVE_TEXTURE = "Interface\\Icons\\INV_Misc_Map_01"

-- Some battleground Area POIs are unavailable while the player is outside the
-- instance. Static entries are used only to complete the offline Edit preview;
-- live Blizzard objective data still takes priority and is de-duplicated by
-- position. Coordinates can be refined independently without affecting live
-- battleground pins.
local STATIC_PREVIEW_POIS_BY_MAP_ID = {
    [210] = { -- Eye of the Storm
        {
            name = "Mage Tower",
            objectiveKey = "mage_tower",
            forceState = "neutral",
            fallbackTexture = PREVIEW_OBJECTIVE_TEXTURE,
            x = 0.39,
            y = 0.40,
        },
        {
            name = "Draenei Ruins",
            objectiveKey = "draenei_ruins",
            forceState = "neutral",
            fallbackTexture = PREVIEW_OBJECTIVE_TEXTURE,
            x = 0.61,
            y = 0.40,
        },
        {
            name = "Fel Reaver Ruins",
            objectiveKey = "fel_reaver_ruins",
            forceState = "neutral",
            fallbackTexture = PREVIEW_OBJECTIVE_TEXTURE,
            x = 0.39,
            y = 0.62,
        },
        {
            name = "Blood Elf Tower",
            objectiveKey = "blood_elf_tower",
            forceState = "neutral",
            fallbackTexture = PREVIEW_OBJECTIVE_TEXTURE,
            x = 0.61,
            y = 0.62,
        },
    },
    [761] = { -- Battle for Gilneas
        {
            name = "Lighthouse",
            objectiveKey = "lighthouse",
            forceState = "neutral",
            fallbackTexture = PREVIEW_OBJECTIVE_TEXTURE,
            x = 0.28,
            y = 0.66,
        },
        {
            name = "Waterworks",
            objectiveKey = "waterworks",
            forceState = "neutral",
            fallbackTexture = PREVIEW_OBJECTIVE_TEXTURE,
            x = 0.58,
            y = 0.63,
        },
        {
            name = "Mines",
            objectiveKey = "mines",
            forceState = "neutral",
            fallbackTexture = PREVIEW_OBJECTIVE_TEXTURE,
            x = 0.73,
            y = 0.38,
        },
    },
    [1576] = { -- Deepwind Gorge
        {
            name = "Quarry",
            objectiveKey = "quarry",
            forceState = "neutral",
            fallbackTexture = PREVIEW_OBJECTIVE_TEXTURE,
            x = 0.27,
            y = 0.30,
        },
        {
            name = "Ruins",
            objectiveKey = "ruins",
            forceState = "neutral",
            fallbackTexture = PREVIEW_OBJECTIVE_TEXTURE,
            x = 0.27,
            y = 0.70,
        },
        {
            name = "Market",
            objectiveKey = "market",
            forceState = "neutral",
            fallbackTexture = PREVIEW_OBJECTIVE_TEXTURE,
            x = 0.50,
            y = 0.50,
        },
        {
            name = "Farm",
            objectiveKey = "farm",
            forceState = "neutral",
            fallbackTexture = PREVIEW_OBJECTIVE_TEXTURE,
            x = 0.73,
            y = 0.30,
        },
        {
            name = "Shrine",
            objectiveKey = "shrine",
            forceState = "neutral",
            fallbackTexture = PREVIEW_OBJECTIVE_TEXTURE,
            x = 0.73,
            y = 0.70,
        },
    },
    [2345] = { -- Deephaul Ravine
        {
            name = "Crystal",
            objectiveKey = "crystal",
            forceState = "neutral",
            fallbackTexture = PREVIEW_OBJECTIVE_TEXTURE,
            x = 0.484,
            y = 0.514,
        },
    },
}


local function NormalizePreviewName(value)
    value = tostring(value or ""):lower()
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return value:gsub("[%s%p%c]", "")
end

local function CopyPreviewPOIInfo(info, x, y, sourceIndex)
    if type(info) ~= "table" then return nil end
    return {
        atlasName = info.atlasName or info.atlas,
        textureKit = info.textureKit,
        uiTextureKit = info.uiTextureKit,
        textureIndex = info.textureIndex,
        name = info.name,
        description = info.description,
        shouldGlow = info.shouldGlow,
        factionID = info.factionID,
        areaPoiID = info.areaPoiID,
        objectiveKey = info.objectiveKey,
        fallbackTexture = info.fallbackTexture,
        forceState = info.forceState,
        sourceIndex = sourceIndex or info.sourceIndex,
        x = x,
        y = y,
    }
end

local function PreviewPositionKey(x, y)
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return nil end
    -- A 0.5% map-grid bucket de-duplicates the same objective when Blizzard
    -- exposes it through both Area POI and Scenario providers.
    return tostring(math.floor((x * 200) + 0.5)) .. ":" .. tostring(math.floor((y * 200) + 0.5))
end

local function AddPreviewPOI(list, info)
    if type(list) ~= "table" or type(info) ~= "table" or not info.x or not info.y then return false end
    local key = PreviewPositionKey(info.x, info.y)
    if not key then return false end

    for index, existing in ipairs(list) do
        if PreviewPositionKey(existing.x, existing.y) == key then
            -- Prefer the most recently observed version so ownership/state
            -- artwork follows what was last seen in the live battleground.
            list[index] = info
            return true
        end
    end

    list[#list + 1] = info
    return true
end

local function ResetPreviewTexture(pin)
    local texture = pin and pin.texture
    if not texture then return end
    texture:ClearAllPoints()
    texture:SetAllPoints(pin)
    if texture.SetAtlas then
        pcall(texture.SetAtlas, texture, nil)
    end
    texture:SetTexture(nil)
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetRotation(0)
    texture:SetVertexColor(1, 1, 1, 1)
    pin.BattleMapsPreviewTexturePath = nil
    pin.BattleMapsPreviewAtlas = nil
    pin.BattleMapsPreviewUsesAtlas = nil
    pin.BattleMapsObjectiveTexturePath = nil
    pin.BattleMapsObjectiveFaction = nil
    pin.BattleMapsCarriedObjectiveFaction = nil
    pin.BattleMapsPreviewFaction = nil
    pin.BattleMapsStationaryObjectiveState = nil
end

local function SetPreviewTexture(pin, texturePath, width, height, r, g, b, a)
    if not pin then return end
    pin:SetSize(width, height or width)
    pin:SetAlpha(a or 1)
    ResetPreviewTexture(pin)

    local usedAtlas = false
    if type(texturePath) == "string"
        and texturePath ~= ""
        and not texturePath:find("\\", 1, true)
        and pin.texture.SetAtlas then
        local ok = pcall(pin.texture.SetAtlas, pin.texture, texturePath, false)
        usedAtlas = ok and (not pin.texture.GetAtlas or pin.texture:GetAtlas() ~= nil)
    end
    if not usedAtlas then
        pin.texture:SetTexture(texturePath)
    end
    pin.texture:SetVertexColor(r or 1, g or 1, b or 1, 1)
    pin.BattleMapsPreviewTexturePath = texturePath
    pin.BattleMapsPreviewAtlas = usedAtlas and texturePath or nil
    pin.BattleMapsPreviewUsesAtlas = usedAtlas or nil
    pin.BattleMapsObjectiveTexturePath = texturePath
end

local function SetPreviewAtlas(pin, atlasName, width, height)
    if not pin or type(atlasName) ~= "string" or atlasName == "" then return false end
    pin:SetSize(width, height or width)
    pin:SetAlpha(1)
    ResetPreviewTexture(pin)
    local ok = pcall(pin.texture.SetAtlas, pin.texture, atlasName, false)
    local usedAtlas = ok and (not pin.texture.GetAtlas or pin.texture:GetAtlas() ~= nil)
    if usedAtlas then
        pin.BattleMapsPreviewAtlas = atlasName
        pin.BattleMapsPreviewUsesAtlas = true
        pin.BattleMapsObjectiveTexturePath = atlasName
    end
    return usedAtlas
end

local function GetPreviewObjectiveProfile(mapID)
    local mapName = BattleMaps.GetBattlegroundNameForConfig
        and BattleMaps.GetBattlegroundNameForConfig(mapID)
        or (BattleMaps.Battlegrounds and BattleMaps.Battlegrounds:GetName(mapID))
        or ""
    local normalized = NormalizePreviewName(mapName)
    local profile = {
        stationaryTexture = PREVIEW_OBJECTIVE_TEXTURE,
        stationaryTitle = "Stationary objective preview",
        stationaryKey = "stationary",
        carriedTexture = PREVIEW_FLAG_TEXTURE,
        carriedTitle = "Carried objective preview",
        carriedKey = "flag",
        vehicleTexture = PREVIEW_VEHICLE_TEXTURE,
        vehicleTitle = "Vehicle objective preview",
        vehicleKey = "vehicle",
    }

    if normalized:find("eyeofthestorm", 1, true) then
        profile.stationaryTexture = PREVIEW_FLAG_TEXTURE
        profile.stationaryTitle = "Netherstorm flag preview"
        profile.stationaryKey = "netherstorm_flag"
        profile.carriedTexture = PREVIEW_FLAG_TEXTURE
        profile.carriedTitle = "Carried Netherstorm flag preview"
        profile.carriedKey = "netherstorm_flag"
    elseif normalized:find("kotmogu", 1, true) then
        profile.stationaryTexture = PREVIEW_ORB_TEXTURE
        profile.stationaryTitle = "Power-orb spawn preview"
        profile.stationaryKey = "orb_spawn"
        profile.carriedTexture = PREVIEW_ORB_TEXTURE
        profile.carriedTitle = "Carried power orb preview"
        profile.carriedKey = "orb"
    elseif normalized:find("seethingshore", 1, true) then
        profile.stationaryTexture = PREVIEW_AZERITE_TEXTURE
        profile.stationaryTitle = "Azerite objective preview"
        profile.stationaryKey = "azerite"
    elseif normalized:find("silvershard", 1, true)
        or normalized:find("deephaul", 1, true) then
        profile.vehicleTexture = PREVIEW_CART_TEXTURE
        profile.vehicleTitle = "Mine-cart objective preview"
        profile.vehicleKey = "mine_cart"
        if normalized:find("deephaul", 1, true) then
            profile.carriedTexture = PREVIEW_RESOURCE_TEXTURE
            profile.carriedTitle = "Carried crystal test preview"
            profile.carriedKey = "crystal"
        end
    elseif normalized:find("wintergrasp", 1, true)
        or normalized:find("isleofconquest", 1, true)
        or normalized:find("strand", 1, true)
        or normalized:find("ashran", 1, true) then
        profile.vehicleTexture = PREVIEW_VEHICLE_TEXTURE
        profile.vehicleTitle = "Siege vehicle preview"
        profile.vehicleKey = "siege_vehicle"
    end

    return profile
end

local function IsDeephaulPreviewMap(mapID)
    local mapName = BattleMaps.GetBattlegroundNameForConfig
        and BattleMaps.GetBattlegroundNameForConfig(mapID)
        or (BattleMaps.Battlegrounds and BattleMaps.Battlegrounds:GetName(mapID))
        or ""
    return tonumber(mapID) == 2345
        or NormalizePreviewName(mapName):find("deephaul", 1, true) ~= nil
end

local function IsTempleOfKotmoguPreviewMap(mapID)
    mapID = tonumber(mapID)
    if mapID == 417 or mapID == 998 then return true end
    local mapName = BattleMaps.GetBattlegroundNameForConfig
        and BattleMaps.GetBattlegroundNameForConfig(mapID)
        or (BattleMaps.Battlegrounds and BattleMaps.Battlegrounds:GetName(mapID))
        or ""
    return NormalizePreviewName(mapName):find("templeofkotmogu", 1, true) ~= nil
end

local KOTMOGU_STATIC_PREVIEW_POIS = {
    -- Authored against the coloured floor pads in BattleMaps' Kotmogu map.
    -- These are map coordinates, not viewport coordinates, so they remain
    -- attached to the pads while the user zooms or pans the map.
    { name = "Purple Orb", objectiveKey = "purple_orb", forceState = "neutral", fallbackTexture = PREVIEW_ORB_TEXTURE, x = 0.392, y = 0.408 },
    { name = "Orange Orb", objectiveKey = "orange_orb", forceState = "neutral", fallbackTexture = PREVIEW_ORB_TEXTURE, x = 0.608, y = 0.408 },
    { name = "Green Orb", objectiveKey = "green_orb", forceState = "neutral", fallbackTexture = PREVIEW_ORB_TEXTURE, x = 0.392, y = 0.658 },
    { name = "Blue Orb", objectiveKey = "blue_orb", forceState = "neutral", fallbackTexture = PREVIEW_ORB_TEXTURE, x = 0.608, y = 0.658 },
}

local function IsSeethingShorePreviewMap(mapID)
    local mapName = BattleMaps.GetBattlegroundNameForConfig
        and BattleMaps.GetBattlegroundNameForConfig(mapID)
        or (BattleMaps.Battlegrounds and BattleMaps.Battlegrounds:GetName(mapID))
        or ""
    local normalized = NormalizePreviewName(mapName)
    return tonumber(mapID) == 907
        or tonumber(mapID) == 1803
        or normalized:find("seethingshore", 1, true) ~= nil
end

local SEETHING_SHORE_TEST_POIS = {
    {
        name = "Azerite Spawn A",
        description = "Synthetic spawning Azerite with an 18-second cycle.",
        objectiveKey = "azerite",
        forceState = "spawning",
        sourceIndex = 1,
        x = 0.37,
        y = 0.43,
    },
    {
        name = "Azerite Spawn B",
        description = "Synthetic spawning Azerite with a separate 29-second cycle.",
        objectiveKey = "azerite",
        forceState = "spawning",
        sourceIndex = 2,
        x = 0.65,
        y = 0.60,
    },
}

local SEETHING_SHORE_SPAWNING_TEXTURE =
    "Interface\\AddOns\\BattleMaps\\Media\\Objectives\\907\\stationary\\azerite_spawning_N.tga"

function Pins:ShouldShowDummyPins()
    local mapFrame = BattleMaps.MapFrame
    return mapFrame ~= nil
        and (mapFrame.editMode == true or mapFrame.testMode == true)
        and mapFrame.currentMapID ~= nil
        and mapFrame.frame ~= nil
        and mapFrame.frame:IsShown()
        and not BattleMaps.IsInLiveBattleground()
end

function Pins:EnsureDummyPins()
    -- PreviewPins owns objective previews only. UnitPins owns the player arrow,
    -- teammate pins, healer overlays, stacking, and unit tooltips.
    if self.dummyPins.stationary or not self.parent then return end

    local function NewPin(key, level)
        local pin = CreateTexturePin(self.parent, 24, 24)
        pin:SetFrameLevel(self.parent:GetFrameLevel() + (level or 30))
        pin:Hide()
        self.dummyPins[key] = pin
        return pin
    end

    local stationary = NewPin("stationary", 34)
    EnsureObjectiveCaptureTimerTextures(stationary)
    self:InstallObjectiveCaptureReportClick(stationary)
    self.dummyStationaryPins[1] = stationary
    NewPin("carried", FLAG_PIN_FRAME_LEVEL_OFFSET)
    NewPin("vehicle", 36)
    NewPin("vehicleAlliance", 36)
    NewPin("vehicleHorde", 36)
end

function Pins:GetDummyStationaryPin(index)
    local pin = self.dummyStationaryPins[index]
    if not pin then
        pin = CreateTexturePin(self.parent, 22, 22)
        pin:SetFrameLevel(self.parent:GetFrameLevel() + 34)
        EnsureObjectiveCaptureTimerTextures(pin)
        self:InstallObjectiveCaptureReportClick(pin)
        self.dummyStationaryPins[index] = pin
    else
        EnsureObjectiveCaptureTimerTextures(pin)
        self:InstallObjectiveCaptureReportClick(pin)
    end
    return pin
end

function Pins:HideDummyPins()
    for _, pin in pairs(self.dummyPins) do
        if pin then pin:Hide() end
    end
    for _, pin in ipairs(self.dummyStationaryPins) do
        if pin then pin:Hide() end
    end
    if self.StopSeethingShoreAzeriteTestPreview then
        self:StopSeethingShoreAzeriteTestPreview()
    end
    if self.HideUnitTestPreview then
        self:HideUnitTestPreview()
    end
    self.dummyActive = false
end

function Pins:HideLivePins()
    -- PreviewPins suppresses only live objective pins. UnitPins owns all live
    -- and test unit-frame visibility.
    for _, collection in ipairs({
        self.vehiclePins,
        self.flagPins,
        self.poiPins,
        self.scenarioPins,
        self.vignettePins,
    }) do
        for _, pin in ipairs(collection) do
            pin:Hide()
        end
    end
end

function Pins:GetDummyMapPoint(viewportX, viewportY)
    local mapFrame = BattleMaps.MapFrame
    if not mapFrame or not mapFrame.viewport or not mapFrame.viewWidth or not mapFrame.viewHeight then
        return viewportX, viewportY
    end

    local width, height = mapFrame.viewport:GetSize()
    if not width or width <= 1 or not height or height <= 1 then
        return viewportX, viewportY
    end

    local mapX = ((width * viewportX) - (mapFrame.viewLeft or 0)) / mapFrame.viewWidth
    local mapY = ((height * viewportY) - (mapFrame.viewTop or 0)) / mapFrame.viewHeight
    return BattleMaps.Clamp(mapX, 0.02, 0.98), BattleMaps.Clamp(mapY, 0.02, 0.98)
end

function Pins:PlaceDummyPin(pin, position)
    local x, y = self:GetDummyMapPoint(position[1], position[2])
    self:Place(pin, x, y)
end

function Pins:CachePreviewPOIInfo(mapID, info, x, y, sourceIndex)
    mapID = tonumber(mapID)
    if not mapID then return end
    local copy = CopyPreviewPOIInfo(info, x, y, sourceIndex)
    if not copy then return end

    local bucket = self.previewPOICache[mapID]
    if type(bucket) ~= "table" or bucket.x ~= nil then
        bucket = {}
        self.previewPOICache[mapID] = bucket
    end
    AddPreviewPOI(bucket, copy)
end

function Pins:GetPreviewPOIInfos(mapID)
    mapID = tonumber(mapID)
    if not mapID then return {} end

    -- Kotmogu's four stationary orb locations are fixed. Outside a live match,
    -- return the complete authored set instead of accepting a partial cached API
    -- list, which previously produced one stationary orb plus a generic carried
    -- preview when merely opening the options window.
    if IsTempleOfKotmoguPreviewMap(mapID) then
        local result = {}
        for _, info in ipairs(KOTMOGU_STATIC_PREVIEW_POIS) do
            result[#result + 1] = CopyPreviewPOIInfo(info, info.x, info.y, info.objectiveKey)
        end
        return result
    end

    local apiMapID = ResolveObjectiveAPIMapID(mapID)

    local now = type(GetTime) == "function" and GetTime() or 0
    local canRefresh = (self.previewPOINextAttempt[mapID] or 0) <= now
    local fresh = {}

    if canRefresh then
        self.previewPOINextAttempt[mapID] = now + 1.5

        if C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo then
            for _, poiID in ipairs(GetAreaPOIIDs(mapID)) do
                local ok, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, apiMapID, poiID)
                if ok and info and info.position and (info.atlasName or info.textureIndex) then
                    local x, y = info.position:GetXY()
                    if x and y then
                        AddPreviewPOI(fresh, CopyPreviewPOIInfo(info, x, y, poiID))
                    end
                end
            end
        end

        -- Some battlegrounds publish stationary markers through the Scenario
        -- provider rather than Area POIs. Query it for previews even while the
        -- player is outside the instance; unsupported maps simply return nil.
        if C_ScenarioInfo and C_ScenarioInfo.GetScenarioIconInfo then
            local ok, iconInfos = pcall(C_ScenarioInfo.GetScenarioIconInfo, apiMapID)
            if ok and type(iconInfos) == "table" then
                for index, info in ipairs(iconInfos) do
                    if info and info.x and info.y and info.atlas then
                        AddPreviewPOI(fresh, CopyPreviewPOIInfo(info, info.x, info.y, index))
                    end
                end
            end
        end

        if #fresh > 0 then
            self.previewPOICache[mapID] = fresh
        end
    end

    local cached = self.previewPOICache[mapID]
    local result = type(cached) == "table" and cached.x == nil and cached or fresh
    if type(result) ~= "table" then result = {} end

    local staticMapID = mapID
    local captureProfile = self:GetCaptureTimerProfile(mapID)
    if captureProfile and captureProfile.id then
        staticMapID = tonumber(captureProfile.id) or staticMapID
    end
    local staticPOIs = STATIC_PREVIEW_POIS_BY_MAP_ID[staticMapID]
    if staticPOIs then
        local merged = {}
        for _, info in ipairs(result) do merged[#merged + 1] = info end
        for _, staticInfo in ipairs(staticPOIs) do
            local staticKey = NormalizeObjectiveKey(
                tostring(staticInfo.objectiveKey or "") .. " " .. tostring(staticInfo.name or "")
            )
            local alreadyPresent = false
            for _, existing in ipairs(merged) do
                local existingKey = NormalizeObjectiveKey(
                    tostring(existing.objectiveKey or "") .. " " .. tostring(existing.name or "")
                )
                if staticKey ~= "" and existingKey ~= ""
                    and (existingKey:find(staticKey, 1, true)
                        or staticKey:find(existingKey, 1, true)) then
                    alreadyPresent = true
                    break
                end
            end
            if not alreadyPresent then AddPreviewPOI(merged, staticInfo) end
        end
        result = merged
    end

    -- Eye of the Storm has a neutral Netherstorm flag at the map centre. The
    -- four bases are stationary capture objectives, while this central flag
    -- changes to a carried-objective marker only after a player picks it up.
    -- Some client states omit the neutral flag from Area POI results, so add a
    -- precise fallback without replacing any Blizzard-provided base markers.
    if mapID == 210 then
        local hasCentreFlag = false
        for _, info in ipairs(result) do
            local text = NormalizeObjectiveKey((info.name or "") .. " " .. (info.atlasName or ""))
            local nearCentre = math.abs((tonumber(info.x) or 0) - 0.5) <= 0.08
                and math.abs((tonumber(info.y) or 0) - 0.5) <= 0.08
            if nearCentre and (text:find("flag", 1, true) or text:find("netherstorm", 1, true)) then
                hasCentreFlag = true
                break
            end
        end

        if not hasCentreFlag then
            local withFlag = {}
            for _, info in ipairs(result) do withFlag[#withFlag + 1] = info end
            AddPreviewPOI(withFlag, {
                name = "Netherstorm Flag",
                description = "Stationary at the centre until picked up; the carrier then uses the carried-objective pin.",
                objectiveKey = "netherstorm_flag",
                fallbackTexture = PREVIEW_FLAG_TEXTURE,
                forceState = "neutral",
                x = 0.50,
                y = 0.50,
            })
            result = withFlag
        end
    end

    return result
end

function Pins:GetPinZoomScale()
    local mapFrame = BattleMaps.MapFrame
    local view = mapFrame and mapFrame.GetActiveView and mapFrame:GetActiveView()
    local zoom = BattleMaps.Clamp(tonumber(view and view.customZoom) or 1, 1, 3)
    local scale = 1 + ((zoom - 1) * PIN_ZOOM_RESPONSE)

    -- The full-screen surface has its own readability multiplier. Keeping this
    -- in the central pin scale path applies consistently to unit pins,
    -- objectives, timers, pulses, carried-objective effects, and trails while
    -- leaving the floating map's configured sizes untouched.
    if mapFrame and mapFrame.IsWorldMapMode and mapFrame:IsWorldMapMode() then
        local db = BattleMaps.Database and BattleMaps.Database:Get()
        scale = scale * BattleMaps.Clamp(
            tonumber(db and db.worldMapPinScale) or 1.00, 0.75, 2.00)
    end
    return scale
end

function Pins:RefreshDummyPins()
    if not self:ShouldShowDummyPins() then
        self:HideDummyPins()
        return false
    end

    self:EnsureDummyPins()
    self:HideLivePins()
    if self.SuppressLiveUnitFramesForPreview then
        self:SuppressLiveUnitFramesForPreview()
    end

    local mapID = BattleMaps.MapFrame.currentMapID
    local mapFrame = BattleMaps.MapFrame
    local testModeActive = mapFrame and mapFrame.testMode == true

    -- Opening Kotmogu in the options/editor represents the match-start state,
    -- not stale carried-orb state inherited from a previous live match. Test
    -- mode sets its own single carried blue orb after the stationary refresh.
    if IsTempleOfKotmoguPreviewMap(mapID) and not testModeActive then
        self.templeActiveCarriedOrbColors = {}
        self.templeAPICarriedOrbColors = {}
        self.templeOrbMessageStateByColor = {}
        self.templeOrbMessageKnownByColor = {}
        self.templeOrbSuppressedUntilByColor = {}
    end

    local objectivePinConfig = BattleMaps.Database:GetBasePinConfig(mapID)
    local zoomScale = self:GetPinZoomScale()
    local stationaryBaseScale = BattleMaps.Clamp(tonumber(objectivePinConfig.objectivePinScale) or 1, 0.50, 2.50)
    local carriedBaseScale = BattleMaps.Clamp(
        tonumber(objectivePinConfig.carrierObjectivePinScale) or stationaryBaseScale,
        0.50,
        2.50
    )
    local vehicleBaseScale = BattleMaps.Clamp(
        tonumber(objectivePinConfig.vehicleObjectivePinScale) or stationaryBaseScale,
        0.50,
        2.50
    )
    local stationaryScale = stationaryBaseScale * zoomScale
    local carriedScale = carriedBaseScale * zoomScale
    local vehicleScale = vehicleBaseScale * zoomScale

    local capabilities = BattleMaps.GetObjectiveCapabilities
        and BattleMaps.GetObjectiveCapabilities(mapID)
        or { stationary = true, carried = true, vehicle = true }
    -- Deephaul Ravine does not expose a live carried-crystal map position.
    -- Do not show a moving carried crystal in Test mode because it implies
    -- functionality that is not available during real matches.
    local showCarriedPreview = capabilities.carried == true and not IsTempleOfKotmoguPreviewMap(mapID)
    local profile = GetPreviewObjectiveProfile(mapID)
    local carried = self.dummyPins.carried
    local vehicle = self.dummyPins.vehicle
    local vehicleAlliance = self.dummyPins.vehicleAlliance
    local vehicleHorde = self.dummyPins.vehicleHorde
    local isDeephaulPreview = IsDeephaulPreviewMap(mapID)

    -- A selector change can reuse the same preview frames. Hide all objective
    -- categories first so pins from the previous battleground cannot remain.
    for _, pin in ipairs(self.dummyStationaryPins) do pin:Hide() end
    carried:Hide()
    vehicle:Hide()
    if vehicleAlliance then vehicleAlliance:Hide() end
    if vehicleHorde then vehicleHorde:Hide() end

    local stationaryUsed = 0
    if capabilities.stationary then
        local seethingTestMode = testModeActive and IsSeethingShorePreviewMap(mapID)
        local poiInfos
        if seethingTestMode then
            -- Test mode intentionally shows exactly two synthetic Azerite
            -- spawns.  Their independent countdowns are updated by the
            -- Seething Shore timer controller rather than by offline POI data.
            poiInfos = SEETHING_SHORE_TEST_POIS
        else
            poiInfos = self:GetPreviewPOIInfos(mapID)
        end

        -- If Blizzard exposes no stationary locations at all, retain one
        -- representative pin so the stationary-size control remains testable.
        if #poiInfos == 0 then
            poiInfos = {{
                name = profile.stationaryTitle,
                objectiveKey = profile.stationaryKey,
                fallbackTexture = profile.stationaryTexture,
            }}
        end

        for index, poiInfo in ipairs(poiInfos) do
            local pin = self:GetDummyStationaryPin(index)
            pin:SetAlpha(1)

            if seethingTestMode then
                SetPreviewTexture(
                    pin,
                    SEETHING_SHORE_SPAWNING_TEXTURE,
                    CUSTOM_AREA_POI_VISUAL_SIZE * stationaryScale,
                    CUSTOM_AREA_POI_VISUAL_SIZE * stationaryScale,
                    1, 1, 1, 1
                )
                pin.BattleMapsSeethingAzeriteTestIndex = index
            else
                local hasPOIArtwork = (poiInfo.atlasName or poiInfo.textureIndex)
                    and SetPOITexture(pin, poiInfo, stationaryScale, mapID, poiInfo.sourceIndex or index)
                if not hasPOIArtwork then
                    local stationaryKeys = BuildObjectiveKeys(
                        poiInfo,
                        poiInfo.sourceIndex or index,
                        poiInfo.objectiveKey or profile.stationaryKey
                    )
                    local stationaryState = poiInfo.forceState or InferStationaryObjectiveState(poiInfo, true)
                    local customStationary = self:FindObjectiveTexture(
                        mapID,
                        "stationary",
                        stationaryKeys,
                        stationaryState
                    )
                    SetPreviewTexture(
                        pin,
                        customStationary or poiInfo.fallbackTexture or profile.stationaryTexture,
                        (customStationary and CUSTOM_AREA_POI_VISUAL_SIZE or 24) * stationaryScale,
                        (customStationary and CUSTOM_AREA_POI_VISUAL_SIZE or 24) * stationaryScale,
                        1, 1, 1, 1
                    )
                end
            end

            self:SetTooltip(
                pin,
                "Stationary objective: " .. tostring(poiInfo.name or "Objective"),
                poiInfo.description
                    or "Uses the objective's map location and Blizzard artwork unless a matching custom texture is present."
            )

            pin.previewObjectiveInfo = poiInfo
            pin.previewObjectiveSourceIndex = poiInfo.sourceIndex or index
            pin.previewObjectiveMapID = mapID

            if poiInfo.x and poiInfo.y then
                self:Place(pin, poiInfo.x, poiInfo.y)
            else
                self:PlaceDummyPin(pin, DUMMY_POSITIONS.stationary)
            end

            if not seethingTestMode then
                local timerInfo = pin.captureTimerTestInfo or poiInfo
                local timerSourceIndex = pin.captureTimerTestSourceIndex or pin.previewObjectiveSourceIndex
                local timerKey = self:GetObjectiveCaptureTimerKey(
                    mapID,
                    timerSourceIndex,
                    timerInfo,
                    pin.mapX,
                    pin.mapY
                )
                if self.objectiveCaptureTimers[timerKey] then
                    self:ApplyObjectiveCaptureTimerToPin(
                        pin,
                        mapID,
                        timerSourceIndex,
                        timerInfo,
                        pin.mapX,
                        pin.mapY
                    )
                elseif self.objectiveBlitzUncapTimers
                    and self.objectiveBlitzUncapTimers[timerKey] then
                    -- RefreshDummyPins first restores the authored neutral
                    -- preview texture. Reapply the active captured/lockout
                    -- state in the same refresh pass so no neutral-white frame
                    -- is visible between timer-controller updates.
                    self:ApplyObjectiveBlitzUncapTimerToPin(
                        pin,
                        mapID,
                        timerSourceIndex,
                        timerInfo,
                        pin.mapX,
                        pin.mapY
                    )
                elseif pin.objectiveCaptureTimerKey then
                    self:ClearObjectiveCaptureTimerPin(pin)
                elseif pin.objectiveBlitzUncapTimerKey then
                    self:ClearObjectiveBlitzUncapTimerPin(pin)
                end
            end

            stationaryUsed = stationaryUsed + 1
        end
    end

    if testModeActive and IsSeethingShorePreviewMap(mapID)
        and self.RefreshSeethingShoreAzeriteTestPreview then
        self:RefreshSeethingShoreAzeriteTestPreview(mapID)
        if self.EnsureSeethingShoreAzeriteController then
            self:EnsureSeethingShoreAzeriteController():Show()
        end
    elseif self.StopSeethingShoreAzeriteTestPreview then
        self:StopSeethingShoreAzeriteTestPreview()
    end

    for index = stationaryUsed + 1, #self.dummyStationaryPins do
        local pin = self.dummyStationaryPins[index]
        if pin then
            pin.BattleMapsSeethingAzeriteTestIndex = nil
            if self.ClearSeethingShoreAzeriteTimer then
                self:ClearSeethingShoreAzeriteTimer(pin)
            end
            pin:Hide()
        end
    end

    if showCarriedPreview then
        local cachedFlag = self.previewFlagTextures[mapID]
        local carriedFaction = self.captureTimerTestFaction == "horde" and "horde" or "alliance"
        local carriedCustom = GetCarriedObjectiveTexture(self, mapID, 1, cachedFlag, carriedFaction)
        SetPreviewTexture(carried, carriedCustom or cachedFlag or profile.carriedTexture,
            24 * carriedScale, 24 * carriedScale, 1, 1, 1, 1)
        carried.BattleMapsObjectiveFaction = carriedFaction
        self:SetTooltip(carried, profile.carriedTitle,
            carriedCustom and "Uses the map-specific custom carried-objective texture for the selected test faction."
                or cachedFlag and "Uses objective artwork observed for this battleground."
                or "Uses a battleground-related Blizzard fallback.")
    end

    local function ConfigureVehiclePreviewPin(pin, faction, position)
        if not pin then return false end

        local vehicleArtwork = self.previewVehicleArtwork[mapID]
        local vehicleWidth = 24 * vehicleScale
        local vehicleHeight = 24 * vehicleScale
        local preferredVehicleKey = profile.vehicleKey or GetVehicleObjectiveKey(mapID)
        local vehicleInfo = vehicleArtwork or {
            name = profile.vehicleTitle,
            objectiveKey = preferredVehicleKey,
        }
        local vehicleKeys = { preferredVehicleKey }
        for _, key in ipairs(BuildObjectiveKeys(vehicleInfo, nil, preferredVehicleKey)) do
            vehicleKeys[#vehicleKeys + 1] = key
        end

        faction = faction == "horde" and "horde" or "alliance"
        local vehicleState = vehicleArtwork
            and InferObjectiveState(vehicleArtwork.name, vehicleArtwork.atlas, vehicleArtwork.textureKit)
            or faction
        if not vehicleState or vehicleState == "" then
            vehicleState = faction
        end

        local vehicleCustom = self:FindObjectiveTexture(mapID, "vehicle", vehicleKeys, vehicleState)
        local usedVehicleAtlas = false
        if vehicleCustom then
            SetPreviewTexture(pin, vehicleCustom, vehicleWidth, vehicleHeight, 1, 1, 1, 1)
        else
            usedVehicleAtlas = vehicleArtwork and vehicleArtwork.atlas
                and SetPreviewAtlas(pin, vehicleArtwork.atlas,
                    (vehicleArtwork.width or 24) * vehicleScale,
                    (vehicleArtwork.height or 24) * vehicleScale)
            if not usedVehicleAtlas then
                SetPreviewTexture(pin, profile.vehicleTexture, vehicleWidth, vehicleHeight, 1, 1, 1, 1)
            end
        end

        self:SetTooltip(pin,
            vehicleArtwork and (vehicleArtwork.name or "Vehicle objective preview") or profile.vehicleTitle,
            vehicleCustom and "Uses the map-specific custom vehicle texture."
                or vehicleArtwork and "Uses vehicle artwork observed for this battleground."
                or "Uses a battleground-related Blizzard fallback.")
        self:PlaceDummyPin(pin, position or DUMMY_POSITIONS.vehicle)
        return true
    end

    if capabilities.vehicle then
        if isDeephaulPreview then
            -- Deephaul has a synthetic centre crystal in the normal options
            -- preview.  Show both faction carts only in Test mode so the user
            -- can inspect mine_cart_A/H without implying carts are stationary
            -- base pins on the normal configuration preview.
            vehicle:Hide()
            if testModeActive then
                ConfigureVehiclePreviewPin(vehicleAlliance, "alliance", DUMMY_POSITIONS.vehicleAlliance)
                ConfigureVehiclePreviewPin(vehicleHorde, "horde", DUMMY_POSITIONS.vehicleHorde)
            end
        else
            local previewVehicleFaction = self.captureTimerTestFaction == "horde" and "horde" or "alliance"
            ConfigureVehiclePreviewPin(vehicle, previewVehicleFaction, DUMMY_POSITIONS.vehicle)
        end
    end

    if showCarriedPreview then
        local carriedPosition = testModeActive and GetDummyCarriedTestPosition() or DUMMY_POSITIONS.carried
        self:PlaceDummyPin(carried, carriedPosition)
        carried.BattleMapsObjectiveMapID = mapID
        carried.BattleMapsForceManualCarriedFlash = nil

        -- Edit mode shows the carried-objective preview for scale/texture
        -- feedback, but it should not animate as though Test mode is running.
        -- Test mode moves the carried objective and draws a trail behind it so
        -- the flag/orb trail settings can be tested outside a live battleground.
        if testModeActive then
            local carriedFaction = self.captureTimerTestFaction == "horde" and "horde" or "alliance"
            self:ApplyCarriedObjectiveFlash(carried)
            if carriedPosition and carriedPosition.loopIndex ~= nil
                and carried.BattleMapsLastTestTrailLoop ~= carriedPosition.loopIndex then
                carried.BattleMapsLastTestTrailLoop = carriedPosition.loopIndex
                if self.ClearFlagCarrierTrails then self:ClearFlagCarrierTrails() end
            end
            if self.RecordFlagCarrierTrailPoint and self.RenderFlagCarrierTrails then
                self:RecordFlagCarrierTrailPoint(1, mapID, carried.mapX, carried.mapY, carriedFaction, carriedScale)
                self:RenderFlagCarrierTrails(1)
            else
                self:ShowDummyFlagCarrierTrail(carriedFaction, carriedScale, carried.mapX, carried.mapY)
            end
        else
            self:StopCarriedObjectiveFlash(carried)
            self:HideFlagCarrierTrailFrames()
        end
    else
        if carried then
            carried.BattleMapsForceManualCarriedFlash = nil
            carried.BattleMapsObjectiveFaction = nil
            carried.BattleMapsObjectiveMapID = nil
        end
        self:StopCarriedObjectiveFlash(carried)

        -- Kotmogu Test mode deliberately has no generic PreviewPins carried
        -- objective. CarriedObjectives owns one moving coloured orb and its
        -- trail. Do not hide that dedicated trail during the objective-preview
        -- refresh, otherwise RefreshDummyPins and the trail controller fight
        -- each other and the wake flashes on and off.
        local keepKotmoguTestTrail = testModeActive
            and IsTempleOfKotmoguPreviewMap(mapID)
        if not keepKotmoguTestTrail then
            self:HideFlagCarrierTrailFrames()
        end
    end
    -- UnitPins is the sole owner of the Test-mode player/team preview. Keep
    -- objective preview refreshes and unit preview refreshes coordinated without
    -- recreating legacy player or teammate frames in this module.
    if testModeActive and self.RefreshUnitTestPreview then
        self:RefreshUnitTestPreview()
    elseif self.HideUnitTestPreview then
        self:HideUnitTestPreview()
    end

    self.dummyActive = true
    return true
end
