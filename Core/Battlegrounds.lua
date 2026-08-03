local _, BattleMaps = ...

local Battlegrounds = {}
BattleMaps.Battlegrounds = Battlegrounds

-- Current retail UI map IDs. Deepwind Gorge was rebuilt in 8.3 and uses
-- UI map 1576; map 519 is the retired original version.
Battlegrounds.MAPS = {
    { id = 1339, name = "Warsong Gulch", width = 360, height = 460 },
    { id = 1366, name = "Arathi Basin", width = 420, height = 280 },
    { id = 112,  name = "Eye of the Storm", width = 420, height = 280 },
    { id = 206,  name = "Twin Peaks", width = 360, height = 460 },
    { id = 275,  name = "Battle for Gilneas", width = 420, height = 300 },
    { id = 417,  name = "Temple of Kotmogu", width = 420, height = 300 },
    { id = 423,  name = "Silvershard Mines", width = 460, height = 300 },
    { id = 1576, name = "Deepwind Gorge", width = 460, height = 330 },
    { id = 907,  name = "Seething Shore", width = 460, height = 330 },
    { id = 2345, name = "Deephaul Ravine", width = 460, height = 330 },
}

Battlegrounds.LEGACY_MAP_IDS = {
    [519] = 1576,
}

Battlegrounds.byID = {}
Battlegrounds.byName = {}

local function NormalizeName(name)
    if type(name) ~= "string" then return nil end
    return name:lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
end

function Battlegrounds:ResolveMapID(mapID)
    mapID = tonumber(mapID)
    return mapID and (self.LEGACY_MAP_IDS[mapID] or mapID) or nil
end

function Battlegrounds:RegisterAlias(name, info)
    local key = NormalizeName(name)
    if key and key ~= "" then
        self.byName[key] = info
    end
end

for index, info in ipairs(Battlegrounds.MAPS) do
    info.index = index
    Battlegrounds.byID[info.id] = info
    Battlegrounds:RegisterAlias(info.name, info)
end

function Battlegrounds:RefreshLocalizedAliases()
    if not C_Map or not C_Map.GetMapInfo then return end
    for _, info in ipairs(self.MAPS) do
        local mapInfo = C_Map.GetMapInfo(info.id)
        if mapInfo and mapInfo.name then
            self:RegisterAlias(mapInfo.name, info)
        end
    end
end

function Battlegrounds:IsInBattleground()
    if not IsInInstance then return false end
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "pvp"
end

local function GetLivePlayerMapID()
    if MapUtil and type(MapUtil.GetDisplayableMapForPlayer) == "function" then
        local ok, mapID = pcall(MapUtil.GetDisplayableMapForPlayer)
        if ok and mapID then return tonumber(mapID) end
    end

    if C_Map and type(C_Map.GetBestMapForUnit) == "function" then
        local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        if ok and mapID then return tonumber(mapID) end
    end
end

function Battlegrounds:GetCurrentMapID()
    if not self:IsInBattleground() then return nil end

    -- Prefer the actual live UI map. This avoids duplicate battleground names
    -- resolving to retired map IDs, as happened with Deepwind Gorge 519/1576.
    local liveMapID = self:ResolveMapID(GetLivePlayerMapID())
    if liveMapID and self.byID[liveMapID] then
        return liveMapID
    end

    -- Name matching is only a fallback for battlegrounds whose live map API is
    -- temporarily unavailable during loading screens.
    if GetInstanceInfo then
        local instanceName = GetInstanceInfo()
        local info = self.byName[NormalizeName(instanceName)]
        if info then return info.id end
    end

    return nil
end

function Battlegrounds:GetInfo(mapID)
    return self.byID[self:ResolveMapID(mapID)]
end

function Battlegrounds:GetName(mapID)
    mapID = self:ResolveMapID(mapID)
    local fixed = self:GetInfo(mapID)
    if fixed then return fixed.name end
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and info.name or ("Map " .. tostring(mapID or "unknown"))
end

function Battlegrounds:GetRelative(mapID, direction)
    local info = self:GetInfo(mapID) or self.MAPS[1]
    local count = #self.MAPS
    local index = ((info.index - 1 + direction) % count) + 1
    return self.MAPS[index]
end
