local addonName, BattleMaps = ...

local Pins = BattleMaps and BattleMaps.Pins
if not Pins then return end

local ObjectiveRules = BattleMaps.ObjectiveRules or {}

--[[
BattleMaps module contract: ObjectivePins.lua

Owns stationary objective-like pins: vehicles, POIs, scenario pins, vignettes,
Deephaul synthetic crystal, fallback objective markers, and objective-event
texture pulse overlays attached to stationary objective pins.

This module may create objective pin textures and animations. It should not own
capture-timer lifecycle, carried-objective placement, unit pins, or event
registration.
]]

local Private = Pins.Private or {}

local HidePinCollection = Private.HidePinCollection
local ObjectiveCategoryEnabled = Private.ObjectiveCategoryEnabled
local ResolveObjectiveAPIMapID = Private.ResolveObjectiveAPIMapID
local InferObjectiveState = Private.InferObjectiveState
local SetTooltip = Private.SetTooltip
local GetAreaPOIIDs = Private.GetAreaPOIIDs
local SetPOITexture = Private.SetPOITexture
local SetFileTexture = Private.SetFileTexture
local BuildObjectiveKeys = Private.BuildObjectiveKeys
local GetVehicleObjectiveKey = Private.GetVehicleObjectiveKey
local function IsDeephaulRavineMap(mapID)
    if Private.IsDeephaulRavineMap then
        local ok, result = pcall(Private.IsDeephaulRavineMap, mapID)
        if ok then return result == true end
    end
    return tonumber(mapID) == 2345
end

local function IsSeethingShoreMap(mapID)
    local rules = BattleMaps.ObjectiveRules
    if rules and type(rules.IsSeethingShoreMap) == "function" then
        local ok, result = pcall(rules.IsSeethingShoreMap, mapID)
        if ok then return result == true end
    end
    mapID = tonumber(mapID)
    return mapID == 907 or mapID == 1803
end

local function IsTempleOfKotmoguMap(mapID)
    local rules = BattleMaps.ObjectiveRules
    if rules and type(rules.IsTempleOfKotmoguMap) == "function" then
        local ok, result = pcall(rules.IsTempleOfKotmoguMap, mapID)
        if ok then return result == true end
    end
    mapID = tonumber(mapID)
    return mapID == 417 or mapID == 998
end

local function GetVignetteMapCandidates(mapID)
    local result, seen = {}, {}
    local function Add(candidate)
        candidate = tonumber(candidate)
        if candidate and candidate > 0 and not seen[candidate] then
            seen[candidate] = true
            result[#result + 1] = candidate
        end
    end

    -- Vignette positions must be requested against the map ID used by the
    -- live Battlefield Map. Seething Shore has alternated between 907 and
    -- 1803 across client builds, so a static objective API alias is not
    -- authoritative for this provider.
    if BattleMaps.GetBattlegroundUIMapID then
        local ok, liveMapID = pcall(BattleMaps.GetBattlegroundUIMapID, mapID, true)
        if ok then Add(liveMapID) end
    end
    if BattleMaps.IsInLiveBattleground and BattleMaps.IsInLiveBattleground()
        and C_Map and type(C_Map.GetBestMapForUnit) == "function" then
        local ok, liveMapID = pcall(C_Map.GetBestMapForUnit, "player")
        if ok then Add(liveMapID) end
    end

    Add(mapID)
    Add(ResolveObjectiveAPIMapID and ResolveObjectiveAPIMapID(mapID))

    if IsSeethingShoreMap(mapID) then
        Add(907)
        Add(1803)
    end
    return result
end

function Pins:GetVignettePositionForMap(vignetteGUID, mapID)
    if not vignetteGUID or not C_VignetteInfo
        or type(C_VignetteInfo.GetVignettePosition) ~= "function" then
        return nil, nil
    end

    for _, apiMapID in ipairs(GetVignetteMapCandidates(mapID)) do
        local ok, position = pcall(C_VignetteInfo.GetVignettePosition, vignetteGUID, apiMapID)
        if ok and position then
            local valid = true
            if type(position.GetXY) == "function" then
                local xyOK, x, y = pcall(position.GetXY, position)
                valid = xyOK and tonumber(x) ~= nil and tonumber(y) ~= nil
            end
            if valid then return position, apiMapID end
        end
    end
    return nil, nil
end

local DEEPHAUL_CRYSTAL_FALLBACK_TEXTURE = "Interface\\Icons\\INV_Misc_Gem_Amethyst_01"

local DEEPHAUL_CRYSTAL_X = 0.484
local DEEPHAUL_CRYSTAL_Y = 0.514
local DEEPHAUL_CRYSTAL_SOURCE_INDEX = "synthetic_crystal"
local DEEPHAUL_CRYSTAL_PULSE_SECONDS = 2.10

local EOTS_CENTER_X = 0.50
local EOTS_CENTER_Y = 0.50
local EOTS_STATIONARY_FLAG_HIDE_RADIUS = 0.075

local function ShouldSuppressEotSStationaryFlag(pins, mapID, x, y)
    if tonumber(mapID) ~= 210 or not pins then return false end
    if not pins.IsEotSStationaryFlagSuppressed
        or not pins:IsEotSStationaryFlagSuppressed(mapID) then
        return false
    end

    x, y = tonumber(x), tonumber(y)
    if not x or not y then return false end
    local dx, dy = x - EOTS_CENTER_X, y - EOTS_CENTER_Y
    return ((dx * dx) + (dy * dy))
        <= (EOTS_STATIONARY_FLAG_HIDE_RADIUS * EOTS_STATIONARY_FLAG_HIDE_RADIUS)
end

local OBJECTIVE_TEXTURE_PULSE_PROFILES = {
    -- Native AnimationGroups interpolate the fixed-size overlay at the
    -- renderer's cadence. Each loop is one smooth brighten-and-fade cycle.
    generic = {
        initialDelay = 0.16,
        pulsePeriod = 0.78,
        loopCount = 7,
        overlayPeakAlpha = 0.34,
    },
    assault = {
        initialDelay = 0.12,
        pulsePeriod = 0.70,
        loopCount = 8,
        overlayPeakAlpha = 0.42,
    },
    capture = {
        initialDelay = 0.18,
        pulsePeriod = 0.80,
        loopCount = 1,
        overlayPeakAlpha = 0.36,
    },
}

local function NormalizeObjectiveKey(value)
    if Private.NormalizeObjectiveKey then
        return Private.NormalizeObjectiveKey(value)
    end
    local ok, text = pcall(tostring, value or "")
    if not ok or type(text) ~= "string" then return "" end
    text = text:lower()
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("[^%w]+", "")
    return text
end

local function GetObjectiveFactionColor(faction)
    faction = NormalizeObjectiveKey(faction)
    local color = faction == "alliance" and BattleMaps.COLORS.alliance
        or faction == "horde" and BattleMaps.COLORS.horde
        or BattleMaps.COLORS.neutral
    return color[1] or 1, color[2] or 1, color[3] or 1
end

local function GetTimerSettings(mapID)
    mapID = tonumber(mapID)
        or tonumber(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    if BattleMaps.Database and BattleMaps.Database.GetBaseTimerConfig then
        return BattleMaps.Database:GetBaseTimerConfig(mapID)
    end
    return BattleMaps.Database and BattleMaps.Database:Get() or nil
end


local function GetStationaryObjectiveAlpha(mapID)
    local config = BattleMaps.Database and BattleMaps.Database.GetBasePinConfig
        and BattleMaps.Database:GetBasePinConfig(mapID)
        or nil
    return BattleMaps.Clamp(tonumber(config and config.objectivePinAlpha) or 1.00, 0.15, 1.00)
end

local function ApplyStationaryObjectiveAlpha(pin, mapID)
    if not pin then return end
    local alpha = GetStationaryObjectiveAlpha(mapID)

    -- Apply base opacity to the pin frame so the final composed stationary
    -- objective visual is faded as one unit.  The objective may contain several
    -- child layers (base texture, capture-fill texture, pre-capture flash, and
    -- event-pulse overlay).  Keeping child texture alpha local to each effect
    -- and multiplying through the parent frame avoids only one layer responding
    -- to the Base opacity slider, and avoids double-fading stacked progress
    -- textures.
    pin.BattleMapsStationaryObjectiveAlpha = alpha
    if pin.SetAlpha then pin:SetAlpha(alpha) end

    -- The main artwork should remain fully opaque within the pin frame.
    -- Animation layers still use their own alpha values for pulse/flash timing;
    -- the parent alpha multiplies the final result.
    if pin.texture then pin.texture:SetAlpha(1) end
    if pin.objectiveCaptureBaseTexture then pin.objectiveCaptureBaseTexture:SetAlpha(1) end
    if pin.objectiveCaptureHoldTexture then pin.objectiveCaptureHoldTexture:SetAlpha(1) end
    if pin.objectiveCaptureFillTexture and not (pin.objectiveCaptureFillTexture.BattleMapsCaptureFlashGroup
        and pin.objectiveCaptureFillTexture.BattleMapsCaptureFlashGroup:IsPlaying()) then
        pin.objectiveCaptureFillTexture:SetAlpha(1)
    end
end

function Pins:GetStationaryObjectiveVisualAlpha(mapID)
    return GetStationaryObjectiveAlpha(mapID)
end

function Pins:ApplyStationaryObjectiveVisualAlpha(pin, mapID)
    return ApplyStationaryObjectiveAlpha(pin, mapID)
end

function Pins:RefreshStationaryObjectiveAlpha(mapID)
    mapID = tonumber(mapID) or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    for _, collection in ipairs({
        self.poiPins or {},
        self.scenarioPins or {},
        self.vignettePins or {},
        self.dummyStationaryPins or {},
    }) do
        for _, pin in ipairs(collection) do
            if pin and pin:IsShown() then
                ApplyStationaryObjectiveAlpha(pin, mapID)
            end
        end
    end
end



-- Objective-event texture pulse overlays -----------------------------------


function Pins:InstallObjectiveEventPulseTexture(pin)
    if not pin or pin.eventPulseTexture then return end

    -- A duplicate of the live objective artwork is used only while an
    -- objective-event animation is active. Pulsing the duplicate avoids
    -- permanently changing the actual POI texture while still making the
    -- objective itself appear to brighten and breathe.
    local eventPulseTexture = pin:CreateTexture(nil, "OVERLAY", nil, 7)
    pin.eventPulseTexture = eventPulseTexture
    eventPulseTexture:SetBlendMode("ADD")
    eventPulseTexture:SetAlpha(0)
    eventPulseTexture:Hide()
end

function Pins:GetObjectivePulseColor(faction)
    -- Objective flashes intentionally remain white. Tinting an additive copy
    -- of already-coloured objective artwork produces muddy mixed colours.
    return 1, 1, 1
end

function Pins:RefreshObjectivePulseColors()
    for _, pin in ipairs(self.poiPins or {}) do
        if pin and pin.eventPulseTexture and pin.objectivePulseMapX then
            local r, g, b = self:GetObjectivePulseColor(pin.objectivePulseFaction)
            pin.eventPulseTexture:SetVertexColor(r, g, b, 1)
        end
    end
end

function Pins:SyncObjectivePulseTexture(pin)
    if not pin or not pin.texture or not pin.eventPulseTexture then return false end

    local source = pin.texture
    local overlay = pin.eventPulseTexture
    local width, height = source:GetSize()
    width = tonumber(width) or 16
    height = tonumber(height) or width

    overlay:ClearAllPoints()
    local point, relativeTo, relativePoint, offsetX, offsetY = source:GetPoint(1)
    if point then
        overlay:SetPoint(point, relativeTo or pin, relativePoint or point, offsetX or 0, offsetY or 0)
    else
        overlay:SetPoint("CENTER", pin, "CENTER", 0, 0)
    end

    local atlas = source.GetAtlas and source:GetAtlas() or nil
    if atlas and atlas ~= "" then
        overlay:SetAtlas(atlas, false)
    else
        overlay:SetTexture(source:GetTexture())
    end

    local left, right, top, bottom, ulx, uly, llx, lly = source:GetTexCoord()
    if ulx ~= nil then
        overlay:SetTexCoord(left, right, top, bottom, ulx, uly, llx, lly)
    elseif left ~= nil then
        overlay:SetTexCoord(left, right, top, bottom)
    else
        overlay:SetTexCoord(0, 1, 0, 1)
    end

    if source.GetRotation then
        overlay:SetRotation(source:GetRotation() or 0)
    else
        overlay:SetRotation(0)
    end

    overlay:SetSize(width, height)
    overlay:SetBlendMode("ADD")
    pin.objectivePulseBaseWidth = width
    pin.objectivePulseBaseHeight = height
    pin.objectivePulseSourceTexture = source:GetTexture()
    pin.objectivePulseSourceAtlas = atlas
    return true
end

function Pins:FindStationaryObjectivePinAt(mapX, mapY)
    if not mapX or not mapY then return nil end

    local nearest, nearestDistance
    for _, collection in ipairs({ self.poiPins or {}, self.dummyStationaryPins or {} }) do
        for _, pin in ipairs(collection) do
            if pin and pin:IsShown() and pin.mapX and pin.mapY then
                local dx = pin.mapX - mapX
                local dy = pin.mapY - mapY
                local distance = (dx * dx) + (dy * dy)
                if not nearestDistance or distance < nearestDistance then
                    nearest = pin
                    nearestDistance = distance
                end
            end
        end
    end

    -- Objective coordinates returned by the event and by RefreshPOIs should be
    -- effectively identical. The small tolerance prevents accidentally
    -- pulsing a neighbouring base on compact maps.
    if nearestDistance and nearestDistance <= 0.0004 then
        return nearest
    end
    return nil
end

function Pins:EnsureObjectiveTexturePulseAnimations(pin)
    if not pin or not pin.eventPulseTexture then return nil, nil end

    local overlay = pin.eventPulseTexture
    if overlay.BattleMapsPulseGroup and overlay.BattleMapsDelayGroup then
        return overlay.BattleMapsDelayGroup, overlay.BattleMapsPulseGroup
    end

    local pulseGroup = overlay:CreateAnimationGroup()
    pulseGroup:SetLooping("REPEAT")
    pulseGroup.BattleMapsOverlay = overlay
    pulseGroup.BattleMapsPin = pin

    local fadeIn = pulseGroup:CreateAnimation("Alpha")
    fadeIn:SetOrder(1)
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(0.36)
    fadeIn:SetDuration(0.40)
    fadeIn:SetSmoothing("IN_OUT")

    local fadeOut = pulseGroup:CreateAnimation("Alpha")
    fadeOut:SetOrder(2)
    fadeOut:SetFromAlpha(0.36)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.40)
    fadeOut:SetSmoothing("IN_OUT")

    pulseGroup.fadeIn = fadeIn
    pulseGroup.fadeOut = fadeOut

    pulseGroup:SetScript("OnPlay", function(group)
        local texture = group.BattleMapsOverlay
        group.completedLoops = 0
        if texture then
            texture:SetAlpha(0)
            texture:Show()
        end
    end)

    pulseGroup:SetScript("OnLoop", function(group)
        group.completedLoops = (group.completedLoops or 0) + 1
        if group.completedLoops >= (group.targetLoops or 1) then
            group:Stop()
        end
    end)

    pulseGroup:SetScript("OnStop", function(group)
        local texture = group.BattleMapsOverlay
        if texture then
            texture:SetAlpha(0)
            texture:Hide()
        end
        local pulsePin = group.BattleMapsPin
        if pulsePin then
            pulsePin.objectivePulseMapX = nil
            pulsePin.objectivePulseMapY = nil
            pulsePin.objectivePulseFaction = nil
            if pulsePin.BattleMapsHideAfterObjectivePulse then
                pulsePin.BattleMapsHideAfterObjectivePulse = nil
                pulsePin:Hide()
            end
        end
    end)

    local delayGroup = overlay:CreateAnimationGroup()
    delayGroup.BattleMapsOverlay = overlay
    delayGroup.BattleMapsPulseGroup = pulseGroup

    local delay = delayGroup:CreateAnimation("Alpha")
    delay:SetOrder(1)
    delay:SetFromAlpha(0)
    delay:SetToAlpha(0)
    delay:SetDuration(0.01)
    delayGroup.delayAnimation = delay

    delayGroup:SetScript("OnPlay", function(group)
        local texture = group.BattleMapsOverlay
        if texture then
            texture:SetAlpha(0)
            texture:Show()
        end
    end)

    delayGroup:SetScript("OnFinished", function(group)
        local groupPulse = group.BattleMapsPulseGroup
        if groupPulse and group.BattleMapsToken == groupPulse.BattleMapsToken then
            groupPulse:Play()
        end
    end)

    overlay.BattleMapsPulseGroup = pulseGroup
    overlay.BattleMapsDelayGroup = delayGroup
    return delayGroup, pulseGroup
end

function Pins:RestoreObjectiveTexturePulsePin(pin)
    if not pin then return end

    pin.objectivePulseToken = (pin.objectivePulseToken or 0) + 1

    local overlay = pin.eventPulseTexture
    if overlay then
        local delayGroup = overlay.BattleMapsDelayGroup
        local pulseGroup = overlay.BattleMapsPulseGroup
        if delayGroup then delayGroup:Stop() end
        if pulseGroup then pulseGroup:Stop() end
        overlay:SetAlpha(0)
        overlay:Hide()
    end

    pin.objectivePulseMapX = nil
    pin.objectivePulseMapY = nil
    pin.objectivePulseFaction = nil
    if pin.texture then pin.texture:SetAlpha(1) end
end

function Pins:StopAllObjectiveTexturePulses()
    for _, pin in ipairs(self.poiPins or {}) do
        self:RestoreObjectiveTexturePulsePin(pin)
    end
    wipe(self.objectiveTexturePulses)
end

function Pins:PlayObjectiveTexturePulse(pin, eventKind, faction, durationOverride)
    if not pin or not pin.texture or not pin.eventPulseTexture then return false end
    if not self:SyncObjectivePulseTexture(pin) then return false end

    eventKind = NormalizeObjectiveKey(eventKind)
    if eventKind ~= "assault" and eventKind ~= "capture" then
        eventKind = "generic"
    end

    local db = GetTimerSettings(pin.objectivePulseMapID or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID))
    local profile = OBJECTIVE_TEXTURE_PULSE_PROFILES[eventKind]
        or OBJECTIVE_TEXTURE_PULSE_PROFILES.generic
    local delayGroup, pulseGroup = self:EnsureObjectiveTexturePulseAnimations(pin)
    if not delayGroup or not pulseGroup then return false end

    pin.objectivePulseToken = (pin.objectivePulseToken or 0) + 1
    local token = pin.objectivePulseToken

    delayGroup:Stop()
    pulseGroup:Stop()

    local profilePeakAlpha = tonumber(profile.overlayPeakAlpha) or 0.36
    local peakAlpha = BattleMaps.Clamp(profilePeakAlpha, 0.05, 1.00)
    if eventKind == "capture" then
        peakAlpha = BattleMaps.Clamp(tonumber(db and db.objectiveCaptureAfterPulseAlpha) or profilePeakAlpha, 0.05, 1.00)
    end
    local preferredPeriod = BattleMaps.Clamp(tonumber(profile.pulsePeriod) or 0.80, 0.30, 2.00)
    local loopCount
    local period = preferredPeriod

    durationOverride = tonumber(durationOverride)
    if durationOverride and durationOverride > 0 then
        durationOverride = BattleMaps.Clamp(durationOverride, 0.5, 60)
        loopCount = math.max(math.floor((durationOverride / preferredPeriod) + 0.5), 1)
        period = durationOverride / loopCount
    elseif eventKind == "assault" then
        loopCount = math.max(math.floor(tonumber(profile.loopCount) or 8), 1)
    elseif eventKind == "capture" then
        loopCount = BattleMaps.Clamp(
            math.floor((tonumber((db or GetTimerSettings(pin and pin.objectivePulseMapID)).objectiveCapturePulseCount) or profile.loopCount or 1) + 0.5),
            1,
            20
        )
    else
        loopCount = math.max(math.floor(tonumber(profile.loopCount) or 7), 1)
    end

    local halfPeriod = period * 0.5
    local pulseR, pulseG, pulseB
    if pin.BattleMapsUseFactionPulseColor == true then
        pulseR, pulseG, pulseB = GetObjectiveFactionColor(faction)
    else
        pulseR, pulseG, pulseB = self:GetObjectivePulseColor(faction)
    end

    pulseGroup.fadeIn:SetFromAlpha(0)
    pulseGroup.fadeIn:SetToAlpha(peakAlpha)
    pulseGroup.fadeIn:SetDuration(halfPeriod)
    pulseGroup.fadeOut:SetFromAlpha(peakAlpha)
    pulseGroup.fadeOut:SetToAlpha(0)
    pulseGroup.fadeOut:SetDuration(halfPeriod)
    pulseGroup.targetLoops = loopCount
    pulseGroup.completedLoops = 0
    pulseGroup.BattleMapsToken = token

    delayGroup.delayAnimation:SetDuration(math.max(tonumber(profile.initialDelay) or 0.01, 0.01))
    delayGroup.BattleMapsToken = token

    pin.texture:SetAlpha(1)
    pin.eventPulseTexture:SetVertexColor(pulseR, pulseG, pulseB, 1)
    pin.eventPulseTexture:SetAlpha(0)
    pin.eventPulseTexture:Show()
    pin.objectivePulseMapX = pin.mapX
    pin.objectivePulseMapY = pin.mapY
    pin.objectivePulseFaction = NormalizeObjectiveKey(faction)

    delayGroup:Play()
    return true
end

function Pins:StartObjectiveTexturePulse(mapX, mapY, faction, eventKind, messageKey, now, durationOverride)
    eventKind = NormalizeObjectiveKey(eventKind)
    if eventKind ~= "assault" and eventKind ~= "capture" then
        eventKind = "generic"
    end

    local pin = self:FindStationaryObjectivePinAt(mapX, mapY)
    if pin and self:PlayObjectiveTexturePulse(pin, eventKind, faction, durationOverride) then
        return true
    end

    -- The battleground announcement can arrive just before the POI provider
    -- exposes the changed marker. Keep a short-lived binding request; once the
    -- pin appears, the native animation starts and no per-frame Lua work is
    -- required for the visual itself.
    self.objectiveTexturePulses[#self.objectiveTexturePulses + 1] = {
        mapID = BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID,
        mapX = mapX,
        mapY = mapY,
        faction = faction,
        eventKind = eventKind,
        messageKey = NormalizeObjectiveKey(messageKey),
        durationOverride = tonumber(durationOverride),
        expiresAt = now + 2.00,
    }
    return true
end

function Pins:UpdatePendingObjectiveTexturePulses(now)
    local mapFrame = BattleMaps.MapFrame
    local currentMapID = mapFrame and mapFrame.currentMapID
    if GetTimerSettings(currentMapID).showObjectivePulseAnimations == false then
        self:StopAllObjectiveTexturePulses()
        return
    end


    for index = #self.objectiveTexturePulses, 1, -1 do
        local record = self.objectiveTexturePulses[index]
        if not currentMapID or record.mapID ~= currentMapID
            or not record.expiresAt or now >= record.expiresAt then
            table.remove(self.objectiveTexturePulses, index)
        else
            local pin = self:FindStationaryObjectivePinAt(record.mapX, record.mapY)
            if pin and self:PlayObjectiveTexturePulse(
                pin,
                record.eventKind,
                record.faction,
                record.durationOverride
            ) then
                table.remove(self.objectiveTexturePulses, index)
            end
        end
    end
end

function Pins:ShowObjectiveEventPulse(mapX, mapY, faction, messageKey, eventKind, durationOverride)
    local mapFrame = BattleMaps.MapFrame
    if GetTimerSettings(mapFrame and mapFrame.currentMapID).showObjectivePulseAnimations == false then
        return false
    end

    if not mapX or not mapY
        or not mapFrame or not mapFrame.currentMapID
        or not mapFrame.frame or not mapFrame.frame:IsShown() then
        return false
    end

    faction = NormalizeObjectiveKey(faction)
    local color = faction == "alliance" and BattleMaps.COLORS.alliance
        or faction == "horde" and BattleMaps.COLORS.horde
        or nil
    if not color then return false end

    eventKind = NormalizeObjectiveKey(eventKind)
    if eventKind ~= "assault" and eventKind ~= "capture" then
        eventKind = "generic"
    end

    local now = type(GetTime) == "function" and GetTime() or 0
    local dedupeKey = table.concat({
        tostring(mapFrame.currentMapID),
        faction,
        eventKind,
        NormalizeObjectiveKey(messageKey),
    }, ":")

    -- Some battleground events can be echoed by more than one provider in the
    -- same frame. Treat them as one transition so a single assault does not
    -- consume several pooled rings.
    if self.lastObjectivePulseKey == dedupeKey
        and (now - (self.lastObjectivePulseAt or 0)) < 0.75 then
        return false
    end
    self.lastObjectivePulseKey = dedupeKey
    self.lastObjectivePulseAt = now

    local texturePulseShown = self:StartObjectiveTexturePulse(
        mapX,
        mapY,
        faction,
        eventKind,
        messageKey,
        now,
        durationOverride
    )

    -- The circular objective-event ripple is intentionally retired. Keep its
    -- implementation available for a possible future feature, but objective
    -- state announcements now animate only the objective artwork itself.
    self:UpdatePendingObjectiveTexturePulses(now)
    return texturePulseShown
end


-- ObjectiveTextures.lua loads before this module and owns the current
-- Deephaul lifecycle state. Do not overwrite that implementation here. The
-- fallback below exists only for compatibility with partial/older installs.
if type(Pins.IsDeephaulCrystalVisible) ~= "function" then
    function Pins:IsDeephaulCrystalVisible()
        if not self.deephaulCrystalCarried then return true end
        local now = type(GetTime) == "function" and GetTime() or 0
        return self.deephaulCrystalPulseUntil and now < self.deephaulCrystalPulseUntil
    end
end

function Pins:PulseDeephaulCrystal(faction, hideAfter)
    local mapID = BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID
    if not IsDeephaulRavineMap(mapID) then
        return false
    end

    -- A pickup makes the stationary crystal logically absent immediately.
    -- Older pickup code can still have a delayed pulse queued; never allow that
    -- animation to Show() the pin again after ObjectiveTextures has hidden it.
    if type(self.IsDeephaulCrystalVisible) == "function" then
        local ok, visible = pcall(self.IsDeephaulCrystalVisible, self, mapID)
        if ok and visible == false then
            local hiddenPin = self:FindStationaryObjectivePinAt(DEEPHAUL_CRYSTAL_X, DEEPHAUL_CRYSTAL_Y)
            if hiddenPin then
                if self.RestoreObjectiveTexturePulsePin then
                    self:RestoreObjectiveTexturePulsePin(hiddenPin)
                end
                hiddenPin:Hide()
            end
            return false
        end
    end

    local pin = self:FindStationaryObjectivePinAt(DEEPHAUL_CRYSTAL_X, DEEPHAUL_CRYSTAL_Y)
    if not pin then return false end

    pin.BattleMapsUseFactionPulseColor = faction == "alliance" or faction == "horde"
    pin.BattleMapsHideAfterObjectivePulse = nil
    pin:Show()
    local started = self:PlayObjectiveTexturePulse(
        pin,
        faction and "assault" or "generic",
        faction or "neutral",
        DEEPHAUL_CRYSTAL_PULSE_SECONDS
    )
    if started then
        pin.BattleMapsHideAfterObjectivePulse = hideAfter == true
        pin:Show()
    end
    return started
end

function Pins:GetDeephaulCrystalSyntheticInfo()
    return {
        name = "Crystal",
        description = "Central Deephaul Ravine crystal",
        objectiveKey = "crystal",
        forceState = "neutral",
    }, DEEPHAUL_CRYSTAL_X, DEEPHAUL_CRYSTAL_Y, DEEPHAUL_CRYSTAL_SOURCE_INDEX
end


local function BuildPreferredVehicleKeys(mapID, info, index)
    local preferredKey = GetVehicleObjectiveKey(mapID)
    local keys = { preferredKey }
    for _, key in ipairs(BuildObjectiveKeys(info, index, preferredKey)) do
        keys[#keys + 1] = key
    end
    return keys
end

local function ResolveVehicleObjectiveState(info)
    if type(info) ~= "table" then return nil end

    local state = InferObjectiveState(
        info.name,
        info.atlas,
        info.atlasName,
        info.textureKit,
        info.uiTextureKit,
        info.faction,
        info.team,
        info.texture
    )
    if state then return state end

    local factionID = tonumber(info.factionID or info.faction)
    local hordeFaction = Enum and Enum.PvPFaction and Enum.PvPFaction.Horde or 0
    local allianceFaction = Enum and Enum.PvPFaction and Enum.PvPFaction.Alliance or 1
    if factionID == allianceFaction then return "alliance" end
    if factionID == hordeFaction then return "horde" end

    if info.isAlliance == true then return "alliance" end
    if info.isHorde == true then return "horde" end
    return nil
end

function Pins:RefreshVehicles()
    if self:ShouldShowDummyPins() then
        self:RefreshDummyPins()
        return
    end
    self:HideDummyPins()

    local mapID = BattleMaps.MapFrame.currentMapID
    if not mapID or not ObjectiveCategoryEnabled(mapID, "vehicle")
        or not C_PvP or not C_PvP.GetBattlefieldVehicles or not C_PvP.GetBattlefieldVehicleInfo then
        HidePinCollection(self.vehiclePins)
        return
    end

    local vehicleMapID = BattleMaps.GetBattlegroundUIMapID
        and BattleMaps.GetBattlegroundUIMapID(mapID, true)
        or mapID
    local ok, vehicles = pcall(C_PvP.GetBattlefieldVehicles, vehicleMapID)
    if not ok or type(vehicles) ~= "table" then
        for _, pin in ipairs(self.vehiclePins) do pin:Hide() end
        return
    end

    local pinConfig = BattleMaps.Database:GetBasePinConfig(mapID)
    local baseScale = BattleMaps.Clamp(
        tonumber(pinConfig.vehicleObjectivePinScale)
            or tonumber(pinConfig.objectivePinScale)
            or 1,
        0.5,
        2.5
    )
    local pinScale = baseScale * self:GetPinZoomScale()
    local used = 0

    for index = 1, #vehicles do
        local infoOK, info = pcall(C_PvP.GetBattlefieldVehicleInfo, index, vehicleMapID)
        if infoOK and info and info.x and info.y and info.isAlive and not info.isPlayer then
            used = used + 1
            local pin = self:GetVehiclePin(used)
            local baseWidth = BattleMaps.Clamp(tonumber(info.textureWidth) or 24, 14, 40)
            local baseHeight = BattleMaps.Clamp(tonumber(info.textureHeight) or 24, 14, 40)
            pin:SetSize(baseWidth * pinScale, baseHeight * pinScale)

            if info.atlas and not self.previewVehicleArtwork[mapID] then
                self.previewVehicleArtwork[mapID] = {
                    atlas = info.atlas,
                    width = baseWidth,
                    height = baseHeight,
                    name = info.name,
                }
            end

            local vehicleKeys = BuildPreferredVehicleKeys(mapID, info, index)
            local vehicleState = ResolveVehicleObjectiveState(info)
            local customVehicle = self:FindObjectiveTexture(mapID, "vehicle", vehicleKeys, vehicleState)

            if customVehicle then
                SetFileTexture(pin, customVehicle, baseWidth * pinScale, baseHeight * pinScale)
            elseif info.atlas then
                pin.texture:SetAtlas(info.atlas, false)
                pin.texture:SetVertexColor(1, 1, 1, 1)
            else
                pin.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
                pin.texture:SetVertexColor(1, 0.75, 0.15, 1)
            end

            if info.facing and pin.texture.SetRotation then
                pin.texture:SetRotation(info.facing)
            else
                pin.texture:SetRotation(0)
            end

            SetTooltip(pin, info.name or "Battleground vehicle")
            self:Place(pin, info.x, info.y)
        end
    end

    for index = used + 1, #self.vehiclePins do
        self.vehiclePins[index]:Hide()
    end
end


local function AddFallbackStationaryPOIs(pins, mapID, used, pinScale)
    if used > 0 or not pins or type(pins.GetPreviewPOIInfos) ~= "function" then return used end

    -- Seething Shore's live stationary objectives are vignettes on current
    -- clients. Never feed its preview/cache records back through the Area-POI
    -- fallback renderer while inside the battleground: doing so creates a
    -- second objective layer which can outlive the real vignette and mask its
    -- spawning artwork. Test mode continues to use its authored dummy pins.
    if IsSeethingShoreMap(mapID)
        and BattleMaps.IsInLiveBattleground
        and BattleMaps.IsInLiveBattleground() then
        return used
    end

    local fallbackInfos = pins:GetPreviewPOIInfos(mapID)
    if type(fallbackInfos) ~= "table" or #fallbackInfos == 0 then return used end

    for index, info in ipairs(fallbackInfos) do
        local x, y = tonumber(info and info.x), tonumber(info and info.y)
        if x and y and not ShouldSuppressEotSStationaryFlag(pins, mapID, x, y) then
            local sourceIndex = info.sourceIndex or info.areaPoiID or info.objectiveKey or index
            local pin = pins:GetPOIPin(used + 1)
            local shown = SetPOITexture(pin, info, pinScale, mapID, sourceIndex)
            if not shown and info.fallbackTexture then
                shown = SetFileTexture(pin, info.fallbackTexture, 32 * pinScale, 32 * pinScale, nil, 16 * pinScale, 16 * pinScale)
                pin.BattleMapsStationaryObjectiveState = info.forceState or "neutral"
            end
            if shown then
                used = used + 1
                ApplyStationaryObjectiveAlpha(pin, mapID)
                pins:SyncObjectivePulseTexture(pin)
                if pin.glow then pin.glow:SetShown(info.shouldGlow == true) end
                SetTooltip(pin, info.name or "Objective", info.description or "Fallback objective marker")
                pins:Place(pin, x, y)
                pins:ApplyObjectiveCaptureTimerToPin(pin, mapID, sourceIndex, info, x, y)
            end
        end
    end

    return used
end

local function AddSyntheticDeephaulCrystal(pins, mapID, used, pinScale)
    if not pins or not mapID or not IsDeephaulRavineMap(mapID) then return used end
    if type(pins.GetDeephaulCrystalSyntheticInfo) ~= "function" then return used end
    if type(pins.IsDeephaulCrystalVisible) == "function" and not pins:IsDeephaulCrystalVisible(mapID) then
        return used
    end

    local info, x, y, sourceIndex = pins:GetDeephaulCrystalSyntheticInfo()
    if not info or not x or not y then return used end

    local pin = pins:GetPOIPin(used + 1)
    local shown = SetPOITexture(pin, info, pinScale, mapID, sourceIndex)
    if not shown then
        local frameSize = 32 * pinScale
        local visualSize = 16 * pinScale
        shown = SetFileTexture(pin, DEEPHAUL_CRYSTAL_FALLBACK_TEXTURE, frameSize, frameSize, nil, visualSize, visualSize)
        pin.BattleMapsStationaryObjectiveState = "neutral"
    end

    if shown then
        used = used + 1
        ApplyStationaryObjectiveAlpha(pin, mapID)
        pins:SyncObjectivePulseTexture(pin)
        if pin.glow then pin.glow:SetShown(false) end
        SetTooltip(pin, info.name or "Crystal", info.description)
        pins:Place(pin, x, y)
    end
    return used
end

local function ReapplyTempleOrbStationaryState(pins, mapID)
    -- Kotmogu orb colour is defined by its fixed map quadrant. Generic POI,
    -- scenario, and vignette refreshes may restore Blizzard artwork; finish
    -- every provider pass by reasserting the authoritative custom texture and
    -- carried-orb visibility state. Lua provider refreshes are synchronous, so
    -- the default texture never becomes the final rendered frame.
    if not pins or type(pins.ApplyTempleOrbStationaryState) ~= "function" then
        return false
    end
    local ok, changed = pcall(pins.ApplyTempleOrbStationaryState, pins, mapID)
    return ok and changed == true
end

local function RefreshAuthoredTempleOrbPOIs(pins, mapID, pinScale)
    if not pins or not IsTempleOfKotmoguMap(mapID)
        or type(pins.GetPreviewPOIInfos) ~= "function" then
        return nil
    end

    -- Temple's four spawn pads never move. Current clients can split the
    -- stationary orbs across providers and, in some states, return only one
    -- colour through Area POIs. Rendering the complete authored set from one
    -- owner avoids a mixture of one BattleMaps texture plus three Blizzard
    -- textures, and lets carried state simply hide/show the relevant pad.
    local infos = pins:GetPreviewPOIInfos(mapID)
    if type(infos) ~= "table" or #infos == 0 then return nil end

    -- Keep one stable, always-resident pin for each fixed pad. A carried orb is
    -- hidden, not removed from the pool. Compacting the pool around carried
    -- colours meant a later return message had no pin at that pad to show; over
    -- several pickup/return cycles every stationary marker could disappear.
    local used = #infos
    for index, info in ipairs(infos) do
        local pin = pins:GetPOIPin(index)
        local x, y = tonumber(info and info.x), tonumber(info and info.y)
        local shown = false

        if x and y then
            local sourceIndex = info.sourceIndex or info.areaPoiID or info.objectiveKey or index
            shown = SetPOITexture(pin, info, pinScale, mapID, sourceIndex)
            if not shown and info.fallbackTexture then
                shown = SetFileTexture(
                    pin,
                    info.fallbackTexture,
                    32 * pinScale,
                    32 * pinScale,
                    nil,
                    16 * pinScale,
                    16 * pinScale
                )
                pin.BattleMapsStationaryObjectiveState = info.forceState or "neutral"
            end
        end

        if shown and x and y then
            ApplyStationaryObjectiveAlpha(pin, mapID)
            pins:SyncObjectivePulseTexture(pin)
            if pin.glow then pin.glow:SetShown(false) end
            SetTooltip(pin, info.name or "Orb", info.description)
            pins:Place(pin, x, y)
        else
            pin:Hide()
        end
    end

    for index = used + 1, #(pins.poiPins or {}) do
        local pin = pins.poiPins[index]
        if pin then
            pins:RestoreObjectiveTexturePulsePin(pin)
            pins:ClearObjectiveCaptureTimerPin(pin)
            if pins.ClearObjectiveBlitzUncapTimerPin then
                pins:ClearObjectiveBlitzUncapTimerPin(pin)
            end
            pin:Hide()
        end
    end

    ReapplyTempleOrbStationaryState(pins, mapID)
    return used
end

function Pins:RefreshPOIs()
    if self:ShouldShowDummyPins() then
        self:RefreshDummyPins()
        return
    end
    self:HideDummyPins()

    local mapID = BattleMaps.MapFrame.currentMapID
    if not mapID or not ObjectiveCategoryEnabled(mapID, "stationary") then
        HidePinCollection(self.poiPins)
        return
    end

    local apiMapID = ResolveObjectiveAPIMapID(mapID)
    local poiIDs = (C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo) and GetAreaPOIIDs(mapID) or {}
    if type(poiIDs) ~= "table" then
        poiIDs = {}
    end

    local baseScale = BattleMaps.Clamp(tonumber(BattleMaps.Database:GetBasePinConfig(mapID).objectivePinScale) or 1, 0.5, 2.5)
    local pinScale = baseScale * self:GetPinZoomScale()
    local used = 0

    if IsTempleOfKotmoguMap(mapID) then
        RefreshAuthoredTempleOrbPOIs(self, mapID, pinScale)
        return
    end

    for _, poiID in ipairs(poiIDs) do
        local infoOK, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, apiMapID, poiID)
        if infoOK and info and info.position then
            local x, y = info.position:GetXY()
            if x and y and not ShouldSuppressEotSStationaryFlag(self, mapID, x, y) then
                local pin = self:GetPOIPin(used + 1)
                if SetPOITexture(pin, info, pinScale, mapID, poiID) then
                    self:CachePreviewPOIInfo(mapID, info, x, y, poiID)
                    used = used + 1
                    ApplyStationaryObjectiveAlpha(pin, mapID)
                    self:SyncObjectivePulseTexture(pin)
                    pin.glow:SetShown(info.shouldGlow == true)
                    SetTooltip(pin, info.name or "Objective", info.description)
                    self:Place(pin, x, y)
                    self:ApplyObjectiveCaptureTimerToPin(pin, mapID, poiID, info, x, y)
                end
            end
        end
    end

    -- Some live battleground states briefly return no Area POI records.  Keep
    -- the base layer visible by falling back to the same static/cached preview
    -- objective list used by Test mode, but only when the live provider gave us
    -- nothing at all.
    used = AddFallbackStationaryPOIs(self, mapID, used, pinScale)
    used = AddSyntheticDeephaulCrystal(self, mapID, used, pinScale)

    for index = used + 1, #self.poiPins do
        self:RestoreObjectiveTexturePulsePin(self.poiPins[index])
        self:ClearObjectiveCaptureTimerPin(self.poiPins[index])
        if self.ClearObjectiveBlitzUncapTimerPin then
            self:ClearObjectiveBlitzUncapTimerPin(self.poiPins[index])
        end
        self.poiPins[index]:Hide()
    end

    if #self.objectiveTexturePulses > 0 and type(GetTime) == "function" then
        self:UpdatePendingObjectiveTexturePulses(GetTime())
    end

    ReapplyTempleOrbStationaryState(self, mapID)
end

function Pins:RefreshScenarios()
    if self:ShouldShowDummyPins() then
        self:RefreshDummyPins()
        return
    end
    self:HideDummyPins()

    local mapID = BattleMaps.MapFrame.currentMapID
    if not mapID or not ObjectiveCategoryEnabled(mapID, "stationary")
        or not C_ScenarioInfo or not C_ScenarioInfo.GetScenarioIconInfo then
        HidePinCollection(self.scenarioPins)
        return
    end

    if IsTempleOfKotmoguMap(mapID) then
        -- Kotmogu stationary orbs are owned exclusively by RefreshPOIs()'s
        -- authored four-pad set. Suppress duplicate/default scenario artwork.
        HidePinCollection(self.scenarioPins)
        return
    end

    -- Blizzard's ScenarioDataProvider supplies several battleground objective
    -- icons, including maps where Area POIs and battlefield flags both return 0.
    if C_Scenario and C_Scenario.IsInScenario and not C_Scenario.IsInScenario() then
        for _, pin in ipairs(self.scenarioPins) do pin:Hide() end
        return
    end

    local apiMapID = ResolveObjectiveAPIMapID(mapID)
    local ok, iconInfos = pcall(C_ScenarioInfo.GetScenarioIconInfo, apiMapID)
    if not ok or type(iconInfos) ~= "table" then
        for _, pin in ipairs(self.scenarioPins) do pin:Hide() end
        return
    end

    local baseScale = BattleMaps.Clamp(tonumber(BattleMaps.Database:GetBasePinConfig(mapID).objectivePinScale) or 1, 0.5, 2.5)
    local pinScale = baseScale * self:GetPinZoomScale()
    local used = 0

    for _, info in ipairs(iconInfos) do
        if info and info.x and info.y and info.atlas
            and not ShouldSuppressEotSStationaryFlag(self, mapID, info.x, info.y) then
            self:CachePreviewPOIInfo(mapID, {
                atlasName = info.atlas,
                name = info.name,
                description = info.description,
            }, info.x, info.y, used + 1)
            used = used + 1
            local pin = self:GetScenarioPin(used)
            pin:SetSize(24 * pinScale, 24 * pinScale)
            local scenarioKeys = BuildObjectiveKeys(info, used, "stationary")
            local scenarioState = self:ResolveStationaryObjectiveState(mapID, used, info)
            local customScenario = self:FindObjectiveTexture(mapID, "stationary", scenarioKeys, scenarioState)
            if customScenario then
                SetFileTexture(pin, customScenario, 24 * pinScale, 24 * pinScale)
            else
                pin.texture:SetAtlas(info.atlas, false)
                pin.texture:SetVertexColor(1, 1, 1, 1)
                pin.texture:SetRotation(0)
            end
            ApplyStationaryObjectiveAlpha(pin, mapID)
            SetTooltip(pin, info.name or "Battleground objective", info.description)
            self:Place(pin, info.x, info.y)
        end
    end

    for index = used + 1, #self.scenarioPins do
        self.scenarioPins[index]:Hide()
    end

    ReapplyTempleOrbStationaryState(self, mapID)
end

function Pins:RefreshVignettes()
    if self:ShouldShowDummyPins() then
        self:RefreshDummyPins()
        return
    end
    self:HideDummyPins()

    local mapID = BattleMaps.MapFrame.currentMapID
    if not mapID or not ObjectiveCategoryEnabled(mapID, "stationary")
        or not C_VignetteInfo or not C_VignetteInfo.GetVignettes
        or not C_VignetteInfo.GetVignetteInfo or not C_VignetteInfo.GetVignettePosition then
        HidePinCollection(self.vignettePins)
        return
    end

    if IsTempleOfKotmoguMap(mapID) then
        -- See RefreshScenarios(): the authored POI layer is the sole stationary
        -- owner so native vignette textures cannot leak through behind it.
        HidePinCollection(self.vignettePins)
        return
    end

    local ok, vignetteGUIDs = pcall(C_VignetteInfo.GetVignettes)
    if not ok or type(vignetteGUIDs) ~= "table" then
        HidePinCollection(self.vignettePins)
        return
    end

    -- Blizzard's VignetteDataProvider begins each refresh with the existing
    -- pins as removal candidates, then retains only records still selected by
    -- the provider. Hide our pool first for the same accuracy-first behaviour;
    -- only vignettes positively selected below are shown again this pass.
    for _, pin in ipairs(self.vignettePins or {}) do
        pin.BattleMapsVignetteGUID = nil
        pin.BattleMapsVignetteID = nil
        pin.BattleMapsVignetteMapID = nil
        pin:Hide()
    end

    local baseScale = BattleMaps.Clamp(tonumber(BattleMaps.Database:GetBasePinConfig(mapID).objectivePinScale) or 1, 0.5, 2.5)
    local pinScale = baseScale * self:GetPinZoomScale()
    local used = 0
    local seethingShore = IsSeethingShoreMap(mapID)

    -- Blizzard treats isUnique vignettes specially: all GUIDs for the same
    -- vignetteID are passed to FindBestUniqueVignette and only the selected
    -- GUID is displayed. Without this step an obsolete Seething Shore phase
    -- record can remain visible after the native map has switched away from it.
    local uniqueGroups = {}
    local vignetteRecords = {}
    for _, vignetteGUID in ipairs(vignetteGUIDs) do
        local infoOK, info = pcall(C_VignetteInfo.GetVignetteInfo, vignetteGUID)
        if infoOK and type(info) == "table" then
            local record = { guid = vignetteGUID, info = info }
            vignetteRecords[#vignetteRecords + 1] = record
            if info.isUnique == true and info.vignetteID ~= nil then
                local key = tostring(info.vignetteID)
                local group = uniqueGroups[key]
                if not group then
                    group = { guids = {}, records = {} }
                    uniqueGroups[key] = group
                end
                group.guids[#group.guids + 1] = vignetteGUID
                group.records[#group.records + 1] = record
            end
        end
    end

    local bestUniqueGUID = {}
    if type(C_VignetteInfo.FindBestUniqueVignette) == "function" then
        for key, group in pairs(uniqueGroups) do
            local bestOK, bestIndex = pcall(C_VignetteInfo.FindBestUniqueVignette, group.guids)
            bestIndex = bestOK and tonumber(bestIndex) or nil
            if bestIndex and group.guids[bestIndex] then
                bestUniqueGUID[key] = group.guids[bestIndex]
            elseif #group.guids > 0 then
                -- Defensive compatibility fallback if a client exposes the
                -- unique flag but not a usable selector result.
                bestUniqueGUID[key] = group.guids[1]
            end
        end
    else
        for key, group in pairs(uniqueGroups) do
            bestUniqueGUID[key] = group.guids[1]
        end
    end

    for _, record in ipairs(vignetteRecords) do
        local vignetteGUID = record.guid
        local info = record.info
        local uniqueSelected = true
        if info.isUnique == true and info.vignetteID ~= nil then
            uniqueSelected = bestUniqueGUID[tostring(info.vignetteID)] == vignetteGUID
        end

        -- Match Blizzard's provider visibility rule and its unique-vignette
        -- selection. isDead is retained as an additional defensive filter.
        if uniqueSelected and info.atlasName
            and info.onWorldMap == true and info.isDead ~= true then
            local position, sourceMapID = self:GetVignettePositionForMap(vignetteGUID, mapID)
            if position and type(position.GetXY) == "function" then
                local xyOK, x, y = pcall(position.GetXY, position)
                if xyOK and x and y and not ShouldSuppressEotSStationaryFlag(self, mapID, x, y) then
                    local sourceIndex = vignetteGUID
                    local pin = self:GetVignettePin(used + 1)

                    -- Seething Shore is vignette-owned in live play. Do not
                    -- cache these records as preview POIs: RefreshPOIs() has no
                    -- live Area POIs on this map, so cached vignette records
                    -- would otherwise be rendered a second time as stale
                    -- fallback POIs. The real vignette remains the sole owner.
                    if SetPOITexture(pin, info, pinScale, mapID, sourceIndex) then
                        used = used + 1
                        if not seethingShore and self.CachePreviewPOIInfo then
                            self:CachePreviewPOIInfo(mapID, {
                                atlasName = info.atlasName,
                                name = info.name,
                                vignetteID = info.vignetteID,
                                sourceMapID = sourceMapID,
                            }, x, y, sourceIndex)
                        end
                        pin.BattleMapsVignetteGUID = vignetteGUID
                        pin.BattleMapsVignetteID = info.vignetteID
                        pin.BattleMapsVignetteMapID = sourceMapID
                        pin.BattleMapsVignetteUnique = info.isUnique == true
                        ApplyStationaryObjectiveAlpha(pin, mapID)
                        SetTooltip(pin, info.name or "Battleground objective")
                        self:Place(pin, x, y)
                    end
                end
            end
        end
    end

    -- The pool was hidden at the start of this pass. Clear metadata on unused
    -- frames as well so diagnostics/tooltips cannot retain a captured GUID.
    for index = used + 1, #self.vignettePins do
        local pin = self.vignettePins[index]
        pin.BattleMapsVignetteGUID = nil
        pin.BattleMapsVignetteID = nil
        pin.BattleMapsVignetteMapID = nil
        pin.BattleMapsVignetteUnique = nil
        pin:Hide()
    end

    ReapplyTempleOrbStationaryState(self, mapID)
end
