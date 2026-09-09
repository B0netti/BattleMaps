local _, BattleMaps = ...

local WorldMapIntegration = {
    initialized = false,
    worldMapFrame = nil,
    canvasContainer = nil,
    hookedWorldMapFrame = nil,
    callbacksInstalled = false,
    hookedContainers = setmetatable({}, { __mode = "k" }),
    evaluationSerial = 0,
    providerRefreshSerial = 0,
    automaticActivation = true,
}
BattleMaps.WorldMapIntegration = WorldMapIntegration

local function IsUsableFrame(frame)
    return frame ~= nil
        and type(frame.GetSize) == "function"
        and type(frame.SetScript) == "function"
end

local function AddMapID(targets, mapID)
    mapID = tonumber(mapID)
    if mapID and mapID > 0 then targets[mapID] = true end
end

function WorldMapIntegration:GetWorldMapFrame()
    local frame = _G.WorldMapFrame
    if IsUsableFrame(frame) then
        self.worldMapFrame = frame
        return frame
    end
    return nil
end

function WorldMapIntegration:ResolveCanvasContainer(worldMapFrame)
    worldMapFrame = worldMapFrame or self:GetWorldMapFrame()
    if not worldMapFrame then return nil end

    if type(worldMapFrame.GetCanvasContainer) == "function" then
        local ok, container = pcall(worldMapFrame.GetCanvasContainer, worldMapFrame)
        if ok and IsUsableFrame(container) then
            self.canvasContainer = container
            return container
        end
    end

    for _, candidate in ipairs({
        worldMapFrame.ScrollContainer,
        worldMapFrame.Canvas,
        worldMapFrame.canvas,
    }) do
        if IsUsableFrame(candidate) then
            self.canvasContainer = candidate
            return candidate
        end
    end

    self.canvasContainer = nil
    return nil
end

function WorldMapIntegration:GetCanvasContainer()
    local worldMapFrame = self:GetWorldMapFrame()
    if not worldMapFrame then return nil end
    return self:ResolveCanvasContainer(worldMapFrame)
end

function WorldMapIntegration:IsWorldMapShown()
    local worldMapFrame = self:GetWorldMapFrame()
    return worldMapFrame and worldMapFrame:IsShown() == true
end

function WorldMapIntegration:GetDisplayedMapID()
    local worldMapFrame = self:GetWorldMapFrame()
    if not worldMapFrame then return nil end

    if type(worldMapFrame.GetMapID) == "function" then
        local ok, mapID = pcall(worldMapFrame.GetMapID, worldMapFrame)
        mapID = ok and tonumber(mapID) or nil
        if mapID and mapID > 0 then return mapID end
    end

    for _, candidate in ipairs({
        worldMapFrame.mapID,
        worldMapFrame.currentMapID,
        worldMapFrame.ScrollContainer and worldMapFrame.ScrollContainer.mapID,
    }) do
        candidate = tonumber(candidate)
        if candidate and candidate > 0 then return candidate end
    end
    return nil
end

function WorldMapIntegration:GetLiveBattlegroundTargets(configMapID)
    configMapID = tonumber(configMapID)
    if not configMapID then return nil, nil end

    local targets = {}
    local liveUIMapID
    if BattleMaps.GetBattlegroundUIMapID then
        local ok, result = pcall(BattleMaps.GetBattlegroundUIMapID, configMapID, true)
        liveUIMapID = ok and tonumber(result) or nil
        AddMapID(targets, liveUIMapID)
    end

    local info = BattleMaps.GetBattlegroundInfoForConfig
        and BattleMaps.GetBattlegroundInfoForConfig(configMapID)
    if type(info) == "table" then
        AddMapID(targets, info.uiMapID)
        AddMapID(targets, info.mapID)
    end

    -- Most battlegrounds use the same configuration and UI map ID. Only use
    -- the configuration ID as a fallback when no explicit UI map was found;
    -- this avoids the historical AB/EotS collision around map ID 112.
    if not next(targets) then AddMapID(targets, configMapID) end
    return targets, liveUIMapID
end

function WorldMapIntegration:IsDisplayedMapWithinTargets(displayedMapID, targets)
    displayedMapID = tonumber(displayedMapID)
    if not displayedMapID or type(targets) ~= "table" then return false end

    local visited = {}
    local candidate = displayedMapID
    for _ = 1, 8 do
        if not candidate or visited[candidate] then break end
        if targets[candidate] then return true end
        visited[candidate] = true

        if not C_Map or type(C_Map.GetMapInfo) ~= "function" then break end
        local ok, info = pcall(C_Map.GetMapInfo, candidate)
        candidate = ok and info and tonumber(info.parentMapID) or nil
        if candidate == 0 then candidate = nil end
    end
    return false
end

function WorldMapIntegration:IsEnabled()
    local db = BattleMaps.Database and BattleMaps.Database:Get()
    return self.automaticActivation == true
        and (not db or db.enableWorldMapIntegration ~= false)
end

function WorldMapIntegration:SetEnabled(enabled)
    enabled = enabled ~= false
    local db = BattleMaps.Database and BattleMaps.Database:Get()
    if db then db.enableWorldMapIntegration = enabled end

    local mapFrame = BattleMaps.MapFrame
    if not enabled then
        self.evaluationSerial = (self.evaluationSerial or 0) + 1
        if mapFrame and mapFrame.IsWorldMapMode and mapFrame:IsWorldMapMode() then
            mapFrame:ExitWorldMapMode()
        end
        return true
    end

    self:QueueAutomaticEvaluation({ 0, 0.05, 0.20 })
    return true
end

function WorldMapIntegration:GetAutomaticActivationState()
    if not self:IsEnabled() then
        return false, "disabled"
    end
    if not self:IsWorldMapShown() then
        return false, "world-map-hidden"
    end
    if not BattleMaps.IsInLiveBattleground
        or not BattleMaps.IsInLiveBattleground() then
        return false, "not-in-battleground"
    end

    local configMapID = BattleMaps.ResolveCurrentBattlegroundMapID
        and BattleMaps.ResolveCurrentBattlegroundMapID()
    configMapID = tonumber(configMapID)
    if not configMapID or not BattleMaps.GetBattlegroundInfoForConfig
        or not BattleMaps.GetBattlegroundInfoForConfig(configMapID) then
        return false, "unsupported-battleground"
    end

    local displayedMapID = self:GetDisplayedMapID()
    if not displayedMapID then
        return nil, "displayed-map-unavailable", configMapID
    end

    local targets, liveUIMapID = self:GetLiveBattlegroundTargets(configMapID)
    local matches = self:IsDisplayedMapWithinTargets(displayedMapID, targets)
    return matches, matches and "matching-battleground" or "different-map",
        configMapID, displayedMapID, liveUIMapID
end

function WorldMapIntegration:ApplyAutomaticActivation()
    local mapFrame = BattleMaps.MapFrame
    if not mapFrame then return false end

    local shouldEmbed, reason, configMapID, displayedMapID, liveUIMapID =
        self:GetAutomaticActivationState()

    -- The World Map commonly reports no map for one frame while opening or
    -- changing pages. Keep the current presentation until a scheduled retry
    -- observes a stable ID instead of flashing between native and custom maps.
    if shouldEmbed == nil then return false end

    if shouldEmbed then
        local previousMapID = tonumber(mapFrame.currentMapID)
        if previousMapID ~= tonumber(configMapID) then
            mapFrame:SetLiveBattleground(configMapID, false)
        end

        local container = self:GetCanvasContainer()
        if not container then return false end

        local wasVisible = mapFrame.IsWorldMapPresentationVisible
            and mapFrame:IsWorldMapPresentationVisible()
        local result
        if mapFrame:IsWorldMapMode() then
            result = mapFrame:SetWorldMapPresentationVisible(true, container)
        else
            result = mapFrame:EnterWorldMapMode(container)
        end
        if result and not wasVisible then
            BattleMaps.Debug(
                "World Map auto-embedded",
                "configMapID=", tostring(configMapID),
                "displayedMapID=", tostring(displayedMapID),
                "liveUIMapID=", tostring(liveUIMapID)
            )
        end
        if result and (not wasVisible or previousMapID ~= tonumber(configMapID)) then
            self:QueueProviderRefreshBurst(configMapID)
        end
        return result == true
    end

    if reason == "different-map" and mapFrame:IsWorldMapMode() then
        if mapFrame:IsWorldMapPresentationVisible() then
            BattleMaps.Debug(
                "World Map presentation suspended",
                "displayedMapID=", tostring(displayedMapID),
                "liveUIMapID=", tostring(liveUIMapID)
            )
        end
        self:CancelProviderRefreshBurst()
        mapFrame:SetWorldMapPresentationVisible(false)
        return true
    end

    -- If the player leaves the battleground while M remains open, release the
    -- captured floating-map state rather than retaining an obsolete session.
    if (reason == "disabled"
        or reason == "not-in-battleground"
        or reason == "unsupported-battleground")
        and mapFrame:IsWorldMapMode() then
        self:CancelProviderRefreshBurst()
        mapFrame:ExitWorldMapMode()
        local db = BattleMaps.Database and BattleMaps.Database:Get()
        if db and db.autoHide then mapFrame:Hide() end
        return true
    end

    return false
end

function WorldMapIntegration:QueueAutomaticEvaluation(delays)
    self.evaluationSerial = (self.evaluationSerial or 0) + 1
    local serial = self.evaluationSerial

    local function Evaluate()
        if serial ~= WorldMapIntegration.evaluationSerial then return end
        WorldMapIntegration:RefreshReferences()
        WorldMapIntegration:ApplyAutomaticActivation()
    end

    Evaluate()
    if not C_Timer or not C_Timer.After then return end
    for _, delay in ipairs(delays or { 0 }) do
        if delay > 0 then C_Timer.After(delay, Evaluate) end
    end
end

function WorldMapIntegration:QueueEmbeddedLayoutRefresh()
    local function Refresh()
        local mapFrame = BattleMaps.MapFrame
        if not mapFrame or not mapFrame:IsWorldMapMode()
            or not mapFrame:IsWorldMapPresentationVisible() then return end
        local container = self:GetCanvasContainer()
        if container then mapFrame:ApplyWorldMapPlacement(container) end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, Refresh)
    else
        Refresh()
    end
end

local function CountShownFrames(collection)
    local count = 0
    for _, frame in pairs(type(collection) == "table" and collection or {}) do
        if frame and type(frame.IsShown) == "function" then
            local ok, shown = pcall(frame.IsShown, frame)
            if ok and shown == true then count = count + 1 end
        end
    end
    return count
end

local function CountTableEntries(collection)
    local count = 0
    for _ in pairs(type(collection) == "table" and collection or {}) do
        count = count + 1
    end
    return count
end

function WorldMapIntegration:IsActiveMatchingPresentation(expectedConfigMapID)
    local mapFrame = BattleMaps.MapFrame
    if not mapFrame or not mapFrame.IsWorldMapMode
        or not mapFrame:IsWorldMapMode()
        or not mapFrame:IsWorldMapPresentationVisible()
        or not self:IsWorldMapShown() then
        return false
    end

    local shouldEmbed, _, configMapID = self:GetAutomaticActivationState()
    if shouldEmbed ~= true then return false end
    if expectedConfigMapID and tonumber(configMapID) ~= tonumber(expectedConfigMapID) then
        return false
    end
    return tonumber(mapFrame.currentMapID) == tonumber(configMapID)
end

-- Several battleground providers populate one or more frames after WorldMapFrame
-- becomes visible. A short, cancellable refresh burst ensures late Area POIs,
-- scenario icons, vignettes, vehicles, flags, and restricted unit frames are all
-- rebuilt on the BattleMaps surface without maintaining a second provider loop.
function WorldMapIntegration:QueueProviderRefreshBurst(configMapID, delays)
    self.providerRefreshSerial = (self.providerRefreshSerial or 0) + 1
    local serial = self.providerRefreshSerial
    configMapID = tonumber(configMapID)

    local function Refresh()
        if serial ~= WorldMapIntegration.providerRefreshSerial then return end
        if not WorldMapIntegration:IsActiveMatchingPresentation(configMapID) then return end

        local mapFrame = BattleMaps.MapFrame
        local pins = BattleMaps.Pins
        if mapFrame and mapFrame.LayoutView then mapFrame:LayoutView() end
        if pins then
            if pins.RefreshAll then pins:RefreshAll(true) end
            if pins.LayoutAll then pins:LayoutAll() end
        end
    end

    Refresh()
    if not C_Timer or not C_Timer.After then return end
    for _, delay in ipairs(delays or { 0.10, 0.35, 0.80, 1.50, 3.00 }) do
        delay = tonumber(delay) or 0
        if delay > 0 then C_Timer.After(delay, Refresh) end
    end
end

function WorldMapIntegration:CancelProviderRefreshBurst()
    self.providerRefreshSerial = (self.providerRefreshSerial or 0) + 1
end

function WorldMapIntegration:GetValidationSnapshot()
    local mapFrame = BattleMaps.MapFrame
    local pins = BattleMaps.Pins or {}
    local configMapID = mapFrame and tonumber(mapFrame.currentMapID) or nil
    local apiMapID = configMapID and BattleMaps.GetBattlegroundUIMapID
        and BattleMaps.GetBattlegroundUIMapID(configMapID, true) or nil

    return {
        configMapID = configMapID,
        apiMapID = tonumber(apiMapID),
        displayedMapID = self:GetDisplayedMapID(),
        worldMapShown = self:IsWorldMapShown(),
        embedded = mapFrame and mapFrame.IsWorldMapMode and mapFrame:IsWorldMapMode() or false,
        presentationVisible = mapFrame and mapFrame.IsWorldMapPresentationVisible
            and mapFrame:IsWorldMapPresentationVisible() or false,
        vehicles = CountShownFrames(pins.vehiclePins),
        carried = CountShownFrames(pins.flagPins),
        stationaryPOIs = CountShownFrames(pins.poiPins),
        scenarios = CountShownFrames(pins.scenarioPins),
        vignettes = CountShownFrames(pins.vignettePins),
        trails = CountShownFrames(pins.flagTrailFrames),
        captureTimers = CountTableEntries(pins.objectiveCaptureTimers),
        uncapTimers = CountTableEntries(pins.objectiveBlitzUncapTimers),
    }
end

function WorldMapIntegration:PrintValidationSnapshot()
    local snapshot = self:GetValidationSnapshot()
    local mapName = snapshot.configMapID and BattleMaps.GetBattlegroundNameForConfig
        and BattleMaps.GetBattlegroundNameForConfig(snapshot.configMapID) or "Unknown"

    BattleMaps.Chat(string.format(
        "Full-map check: %s | config=%s api=%s displayed=%s | embedded=%s visible=%s",
        tostring(mapName), tostring(snapshot.configMapID), tostring(snapshot.apiMapID),
        tostring(snapshot.displayedMapID), tostring(snapshot.embedded),
        tostring(snapshot.presentationVisible)))
    BattleMaps.Chat(string.format(
        "Providers: team/unit renderer active; stationary=%d scenario=%d vignette=%d vehicle=%d carried=%d trail=%d timers=%d/%d",
        snapshot.stationaryPOIs, snapshot.scenarios, snapshot.vignettes,
        snapshot.vehicles, snapshot.carried, snapshot.trails,
        snapshot.captureTimers, snapshot.uncapTimers))
    return snapshot
end

function WorldMapIntegration:RefreshNotificationOwnership()
    local notifications = BattleMaps.Notifications
    if notifications and type(notifications.Apply) == "function" then
        notifications:Apply()
    end
end

function WorldMapIntegration:OnWorldMapShown()
    self:RefreshReferences()
    -- Restore Blizzard's notification frames immediately, before the custom
    -- map overlay finishes its delayed activation checks.
    self:RefreshNotificationOwnership()
    self:QueueAutomaticEvaluation({ 0.05, 0.20, 0.50, 1.00 })
end

function WorldMapIntegration:OnWorldMapHidden()
    self.evaluationSerial = (self.evaluationSerial or 0) + 1
    self:CancelProviderRefreshBurst()
    local mapFrame = BattleMaps.MapFrame
    if mapFrame and mapFrame:IsWorldMapMode() then
        mapFrame:ExitWorldMapMode()
    end
    -- WorldMapFrame is hidden at this point, so BattleMaps can resume the
    -- configured battleground notification layout immediately.
    self:RefreshNotificationOwnership()
end

function WorldMapIntegration:OnWorldMapChanged()
    self:RefreshReferences()
    self:QueueAutomaticEvaluation({ 0.05, 0.20 })
end

function WorldMapIntegration:OnPlayerLocationChanged()
    if self:IsWorldMapShown() then
        self:QueueAutomaticEvaluation({ 0.10, 0.35, 0.80, 1.50 })
    end
end

function WorldMapIntegration:OnWorldMapResized()
    self:QueueEmbeddedLayoutRefresh()
    if self:IsWorldMapShown() then
        self:QueueAutomaticEvaluation({ 0.05, 0.20 })
    end
end

function WorldMapIntegration:InstallWorldMapCallbacks()
    if self.callbacksInstalled then return true end
    local registry = _G.EventRegistry
    if not registry or type(registry.RegisterCallback) ~= "function" then return false end

    -- Blizzard fires these callbacks at the end of WorldMapMixin:OnShow/OnHide.
    -- Registering here keeps BattleMaps out of the WorldMapFrame script chain,
    -- so Blizzard's protected PerformEmote("READ") runs before BattleMaps code.
    registry:RegisterCallback("WorldMapOnShow", self.OnWorldMapShown, self)
    registry:RegisterCallback("WorldMapOnHide", self.OnWorldMapHidden, self)
    registry:RegisterCallback("WorldMapMaximized", self.OnWorldMapResized, self)
    registry:RegisterCallback("WorldMapMinimized", self.OnWorldMapResized, self)
    self.callbacksInstalled = true
    BattleMaps.Debug("World Map EventRegistry callbacks installed")
    return true
end

function WorldMapIntegration:HookCanvasContainer(container)
    if not IsUsableFrame(container) or self.hookedContainers[container] then return end
    self.hookedContainers[container] = true
    container:HookScript("OnSizeChanged", function()
        WorldMapIntegration:QueueEmbeddedLayoutRefresh()
    end)
end

function WorldMapIntegration:InstallWorldMapHooks(worldMapFrame)
    if not IsUsableFrame(worldMapFrame) then return false end

    -- Never HookScript WorldMapFrame:OnShow/OnHide.  Blizzard's OnShow performs
    -- a protected C_ChatInfo.PerformEmote call before firing WorldMapOnShow; a
    -- direct addon script hook can participate in that tainted execution chain.
    -- Use EventRegistry for lifecycle and only a secure post-hook for map-ID
    -- changes, which are needed while the map remains open.
    if self.hookedWorldMapFrame ~= worldMapFrame then
        self.hookedWorldMapFrame = worldMapFrame
        if type(hooksecurefunc) == "function" and type(worldMapFrame.SetMapID) == "function" then
            pcall(hooksecurefunc, worldMapFrame, "SetMapID", function()
                WorldMapIntegration:OnWorldMapChanged()
            end)
        end
    end

    self:HookCanvasContainer(self:ResolveCanvasContainer(worldMapFrame))
    return true
end

function WorldMapIntegration:RefreshReferences()
    self:InstallWorldMapCallbacks()
    local worldMapFrame = self:GetWorldMapFrame()
    if not worldMapFrame then return false end
    self:ResolveCanvasContainer(worldMapFrame)
    self:InstallWorldMapHooks(worldMapFrame)
    return self.canvasContainer ~= nil
end

-- Manual entry points remain available for diagnostics, but normal use is now
-- controlled by the automatic activation evaluation above.
function WorldMapIntegration:EnterEmbeddedMode()
    local worldMapFrame = self:GetWorldMapFrame()
    if not worldMapFrame or not worldMapFrame:IsShown() then return false end

    local container = self:GetCanvasContainer()
    if not container or not BattleMaps.MapFrame then return false end
    return BattleMaps.MapFrame:EnterWorldMapMode(container)
end

function WorldMapIntegration:ExitEmbeddedMode()
    self:CancelProviderRefreshBurst()
    local mapFrame = BattleMaps.MapFrame
    return mapFrame and mapFrame:ExitWorldMapMode() or false
end

function WorldMapIntegration:Initialize()
    if self.initialized then return end
    self.initialized = true

    local eventFrame = CreateFrame("Frame")
    self.eventFrame = eventFrame
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("PLAYER_MAP_CHANGED")
    eventFrame:RegisterEvent("UPDATE_INSTANCE_INFO")
    eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    eventFrame:RegisterEvent("UI_SCALE_CHANGED")
    eventFrame:SetScript("OnEvent", function(_, event, loadedAddon)
        if event == "ADDON_LOADED" then
            if loadedAddon == "Blizzard_WorldMap" or loadedAddon == BattleMaps.addonName then
                WorldMapIntegration:RefreshReferences()
            end
        elseif event == "PLAYER_LOGIN" then
            WorldMapIntegration:RefreshReferences()
            WorldMapIntegration:OnPlayerLocationChanged()
        elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
            WorldMapIntegration:QueueEmbeddedLayoutRefresh()
            WorldMapIntegration:OnPlayerLocationChanged()
        else
            WorldMapIntegration:OnPlayerLocationChanged()
        end
    end)

    self:InstallWorldMapCallbacks()
    self:RefreshReferences()
end

WorldMapIntegration:Initialize()
