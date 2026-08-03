local _, BattleMaps = ...

-- Custom map texture registration -------------------------------------------------
-- Custom texture definitions are optional. A definition replaces Blizzard map
-- art only inside BattleMaps' independent frame.
--
-- Example for a future WSG texture:
-- BattleMaps.CustomMaps[1339] = {
--     texture = "Interface\\AddOns\\BattleMaps\\Media\\Maps\\WarsongGulch",
--     width = 1024,
--     height = 1024,
-- }

BattleMaps.CustomMaps = BattleMaps.CustomMaps or {}

function BattleMaps.RegisterCustomMapTexture(mapID, texture, width, height)
    mapID = tonumber(mapID)
    if not mapID or type(texture) ~= "string" then return false end

    BattleMaps.CustomMaps[mapID] = {
        texture = texture,
        width = tonumber(width) or 1024,
        height = tonumber(height) or 1024,
    }

    if BattleMaps.MapRenderer and BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID == mapID then
        BattleMaps.MapRenderer:SetMapID(mapID)
    end
    return true
end

-- Map renderer -------------------------------------------------------------------
local Renderer = {
    tiles = {},
    activeTileCount = 0,
    mapID = nil,
    artWidth = 1,
    artHeight = 1,
    serial = 0,
}
BattleMaps.MapRenderer = Renderer

local MAP_ART_ID_OVERRIDES = {
    -- BattleMaps keeps Arathi Basin under its legacy/configuration ID 112,
    -- but WoW's current C_Map art/POI APIs use UI map ID 1366. C_Map ID 112
    -- now resolves to Eye of the Storm, so passing the legacy ID directly
    -- displays the wrong battleground during offline preview.
    [112] = 1366,
    [210] = 112,
}

local function ResolveMapArtID(mapID)
    mapID = tonumber(mapID)
    return MAP_ART_ID_OVERRIDES[mapID] or mapID
end

local function HideTile(tile)
    tile:Hide()
    tile:ClearAllPoints()
    tile:SetTexture(nil)
end

function Renderer:Initialize(canvas, emptyText)
    self.canvas = canvas
    self.emptyText = emptyText
end

function Renderer:GetTextureAlpha()
    local db = BattleMaps.Database and BattleMaps.Database:Get()
    return BattleMaps.Clamp(db and db.mapTextureAlpha or 1, 0.20, 1.00)
end

function Renderer:ApplyTextureAlpha()
    local alpha = self:GetTextureAlpha()
    for index = 1, self.activeTileCount or 0 do
        local tile = self.tiles[index]
        if tile then tile:SetAlpha(alpha) end
    end
end

function Renderer:AcquireTile(index)
    local tile = self.tiles[index]
    if not tile then
        tile = self.canvas:CreateTexture(nil, "ARTWORK")
        tile:SetHorizTile(false)
        tile:SetVertTile(false)
        self.tiles[index] = tile
    end
    tile:SetAlpha(self:GetTextureAlpha())
    tile:Show()
    return tile
end

function Renderer:ReleaseUnusedTiles(firstUnused)
    for index = firstUnused, #self.tiles do
        HideTile(self.tiles[index])
    end
    self.activeTileCount = firstUnused - 1
end

function Renderer:GetAspectRatio()
    if self.artWidth <= 0 or self.artHeight <= 0 then return 1 end
    return self.artWidth / self.artHeight
end

function Renderer:SetEmpty(message)
    self.definition = nil
    self.artWidth = 1
    self.artHeight = 1
    self:ReleaseUnusedTiles(1)
    if self.emptyText then
        self.emptyText:SetText(message or "Map art unavailable")
        self.emptyText:Show()
    end
end

function Renderer:UseCustomDefinition(definition)
    self.definition = {
        kind = "custom",
        texture = definition.texture,
        width = math.max(1, tonumber(definition.width) or 1024),
        height = math.max(1, tonumber(definition.height) or 1024),
    }
    self.artWidth = self.definition.width
    self.artHeight = self.definition.height
    if self.emptyText then self.emptyText:Hide() end
    self:Layout()
end

function Renderer:ChooseBestLayer(layers)
    local bestIndex, bestInfo, bestArea
    for index, info in ipairs(layers or {}) do
        local area = (tonumber(info.layerWidth) or 0) * (tonumber(info.layerHeight) or 0)
        if not bestArea or area > bestArea then
            bestIndex, bestInfo, bestArea = index, info, area
        end
    end
    return bestIndex, bestInfo
end

function Renderer:TryLoadBlizzardArt(mapID, serial)
    if serial ~= self.serial or mapID ~= self.mapID then return false end
    if not C_Map or not C_Map.GetMapArtLayers or not C_Map.GetMapArtLayerTextures then
        self:SetEmpty("C_Map map-art APIs are unavailable")
        return false
    end

    local layers = C_Map.GetMapArtLayers(mapID)
    local layerIndex, layerInfo = self:ChooseBestLayer(layers)
    if not layerIndex or not layerInfo then
        return false
    end

    local textures = C_Map.GetMapArtLayerTextures(mapID, layerIndex)
    if type(textures) ~= "table" or #textures == 0 then
        return false
    end

    self.definition = {
        kind = "tiles",
        textures = textures,
        width = math.max(1, tonumber(layerInfo.layerWidth) or 1),
        height = math.max(1, tonumber(layerInfo.layerHeight) or 1),
        tileWidth = math.max(1, tonumber(layerInfo.tileWidth) or 256),
        tileHeight = math.max(1, tonumber(layerInfo.tileHeight) or 256),
    }
    self.artWidth = self.definition.width
    self.artHeight = self.definition.height
    if self.emptyText then self.emptyText:Hide() end
    self:Layout()
    return true
end

function Renderer:SetMapID(mapID)
    self.requestedMapID = tonumber(mapID)
    self.mapID = ResolveMapArtID(self.requestedMapID)
    self.serial = self.serial + 1
    local serial = self.serial

    self:ReleaseUnusedTiles(1)
    if not self.mapID then
        self:SetEmpty("No battleground selected")
        return
    end

    -- Custom definitions remain keyed by BattleMaps' configuration ID, while
    -- Blizzard art is requested with the current C_Map UI map ID.
    local custom = BattleMaps.CustomMaps[self.requestedMapID]
        or BattleMaps.CustomMaps[self.mapID]
    if custom then
        self:UseCustomDefinition(custom)
        return
    end

    if C_Map and C_Map.RequestPreloadMap then
        pcall(C_Map.RequestPreloadMap, self.mapID)
    end

    if self:TryLoadBlizzardArt(self.mapID, serial) then
        return
    end

    self:SetEmpty("Loading map art…")
    if C_Timer and C_Timer.After then
        C_Timer.After(0.20, function()
            if self:TryLoadBlizzardArt(self.mapID, serial) and BattleMaps.MapFrame then
                BattleMaps.MapFrame:LayoutView()
            end
        end)
        C_Timer.After(1.00, function()
            if self:TryLoadBlizzardArt(self.mapID, serial) and BattleMaps.MapFrame then
                BattleMaps.MapFrame:LayoutView()
            elseif serial == self.serial and self.definition == nil then
                local displayMapID = self.requestedMapID or self.mapID
                self:SetEmpty("Map art unavailable for " .. BattleMaps.Battlegrounds:GetName(displayMapID))
            end
        end)
    end
end

function Renderer:Layout()
    if not self.canvas or not self.definition then return end
    local width, height = self.canvas:GetSize()
    if not width or width <= 0 or not height or height <= 0 then return end

    if self.definition.kind == "custom" then
        local tile = self:AcquireTile(1)
        tile:ClearAllPoints()
        tile:SetAllPoints(self.canvas)
        tile:SetTexture(self.definition.texture)
        tile:SetTexCoord(0, 1, 0, 1)
        self:ReleaseUnusedTiles(2)
        self:ApplyTextureAlpha()
        return
    end

    local definition = self.definition
    local columns = math.ceil(definition.width / definition.tileWidth)
    local used = 0

    for index, fileID in ipairs(definition.textures) do
        used = used + 1
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        local logicalX = column * definition.tileWidth
        local logicalY = row * definition.tileHeight
        local logicalWidth = math.min(definition.tileWidth, definition.width - logicalX)
        local logicalHeight = math.min(definition.tileHeight, definition.height - logicalY)

        local tile = self:AcquireTile(used)
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", self.canvas, "TOPLEFT",
            (logicalX / definition.width) * width,
            -(logicalY / definition.height) * height)
        tile:SetSize(
            (logicalWidth / definition.width) * width,
            (logicalHeight / definition.height) * height)
        tile:SetTexture(fileID)
        tile:SetTexCoord(0, logicalWidth / definition.tileWidth, 0, logicalHeight / definition.tileHeight)
    end

    self:ReleaseUnusedTiles(used + 1)
    self:ApplyTextureAlpha()
end
