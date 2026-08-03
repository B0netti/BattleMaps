local ADDON_NAME, BattleMaps = ...
BattleMaps = BattleMaps or _G.BattleMaps
if not BattleMaps then return end

local Pins = BattleMaps.Pins
if not Pins then return end
local Rules = BattleMaps.ObjectiveRules or {}

--[[
BattleMaps module contract: ObjectiveTimers.lua

Owns objective capture-timer lifecycle, capture-progress rendering layers,
capture-progress tooltip text, timer test mode, and tooltip installation helpers
used by objective pins.
This file must load before ObjectivePins.lua because ObjectivePins captures
Pins.Private.SetTooltip at file-load time.

This module should not own stationary objective discovery, custom texture
resolution, carried-objective placement, or event registration.
]]

-- Base countdown text must remain readable when friendly-unit pins cross an
-- objective. Keep only the text above the unit-pin family; the objective
-- texture and capture-progress layers retain their existing lower ordering.
local OBJECTIVE_TIMER_TEXT_FRAME_LEVEL_OFFSET = 70

-- Tooltip helpers ---------------------------------------------------------

local function NormalizeObjectiveKey(value)
    if Pins.NormalizeObjectiveKey then
        return Pins:NormalizeObjectiveKey(value)
    end
    local ok, text = pcall(tostring, value or "")
    if not ok or type(text) ~= "string" then return "" end
    text = text:lower()
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("[^%w]+", "")
    return text
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

local function GetObjectiveTooltipFactionName(faction)
    faction = NormalizeObjectiveKey(faction)
    if faction == "alliance" or faction == "contestedalliance" or faction == "alliancecontested" then
        return "Alliance", 0.45, 0.65, 1.00
    elseif faction == "horde" or faction == "contestedhorde" or faction == "hordecontested" then
        return "Horde", 1.00, 0.35, 0.25
    end
    return nil
end

function Pins:AddObjectiveCaptureTooltipLine(pin)
    if not pin then return false end

    local timerKey = pin.objectiveCaptureTimerKey
    local record = timerKey and self.objectiveCaptureTimers
        and self.objectiveCaptureTimers[timerKey]
        or nil
    local now = type(GetTime) == "function" and GetTime() or 0

    if record and record.expiresAt and record.expiresAt > now then
        if IsEyeOfTheStormMapID(record.mapID or pin.objectiveCaptureTimerMapID) and not record.testSerial then
            GameTooltip:AddLine("Contested", 1.00, 0.82, 0.40, true)
            return true
        end

        local factionName, r, g, b = GetObjectiveTooltipFactionName(record.faction)
        local seconds = math.max(math.ceil(record.expiresAt - now), 1)
        if factionName then
            GameTooltip:AddLine(string.format("%s controlled in %d second%s", factionName, seconds, seconds == 1 and "" or "s"), r, g, b, true)
        else
            GameTooltip:AddLine(string.format("Controlled in %d second%s", seconds, seconds == 1 and "" or "s"), 1.00, 0.82, 0.40, true)
        end
        return true
    end

    local uncapKey = pin.objectiveBlitzUncapTimerKey
    local uncapRecord = uncapKey and self.objectiveBlitzUncapTimers
        and self.objectiveBlitzUncapTimers[uncapKey]
        or nil
    if uncapRecord and uncapRecord.expiresAt and uncapRecord.expiresAt > now then
        local factionName, r, g, b = GetObjectiveTooltipFactionName(uncapRecord.faction)
        local seconds = math.max(math.ceil(uncapRecord.expiresAt - now), 1)
        local label = factionName and (factionName .. " unlocks") or "Unlocks"
        GameTooltip:AddLine(string.format("%s in %d second%s", label, seconds, seconds == 1 and "" or "s"), r or 1.00, g or 0.82, b or 0.40, true)
        return true
    end

    local state = NormalizeObjectiveKey(pin.BattleMapsStationaryObjectiveState)
    if state ~= "" and state:find("contested", 1, true) then
        GameTooltip:AddLine("Contested", 1.00, 0.82, 0.40, true)
        return true
    elseif state == "uncontrolled" then
        GameTooltip:AddLine("Uncontrolled", 0.78, 0.78, 0.78, true)
        return true
    end
    return false
end

function Pins:SetTooltip(pin, title, description)
    if not pin then return end
    pin.tooltipTitle = title
    pin.tooltipDescription = description
end

function Pins:InstallTooltip(pin)
    if not pin or pin.BattleMapsTooltipInstalled then return end
    pin.BattleMapsTooltipInstalled = true
    pin:EnableMouse(true)
    pin:SetScript("OnEnter", function(frame)
        if not frame.tooltipTitle then return end
        if Pins.IsTeamTooltipPriorityActive and Pins:IsTeamTooltipPriorityActive() then return end
        local mapFrame = BattleMaps.MapFrame
        local anchor = mapFrame and mapFrame.IsWorldMapMode
            and mapFrame:IsWorldMapMode() and "ANCHOR_CURSOR" or "ANCHOR_RIGHT"
        GameTooltip:SetOwner(frame, anchor)
        GameTooltip:SetText(frame.tooltipTitle)
        if frame.tooltipDescription and frame.tooltipDescription ~= "" then
            GameTooltip:AddLine(frame.tooltipDescription, 0.9, 0.9, 0.9, true)
        end
        Pins:AddObjectiveCaptureTooltipLine(frame)
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function(frame)
        if GameTooltip:GetOwner() == frame then GameTooltip:Hide() end
    end)
    pin:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and BattleMaps.MapFrame
            and BattleMaps.MapFrame.ShowContextMenu then
            BattleMaps.MapFrame:ShowContextMenu()
        end
    end)
end

function Pins:InstallObjectiveCaptureReportClick(pin)
    -- Deliberately inert. Sending INSTANCE_CHAT from an addon path can trigger
    -- protected chat taint in live PvP, so objective pins only show tooltips.
    if not pin then return end
    pin:EnableMouse(true)
end

function Pins:ReportObjectiveCaptureTimerToInstanceChat()
    return false
end

Pins.Private = Pins.Private or {}
Pins.Private.SetTooltip = function(pin, title, description)
    return Pins:SetTooltip(pin, title, description)
end

-- Capture timer lifecycle ------------------------------------------------

-- Capture-timer lifecycle and test-mode orchestration.
--
-- Objective key construction, POI matching, texture selection, and pin rendering
-- remain in Pins.lua. Those helpers are exposed through private-style Pins:
-- methods because they depend on the renderer's local objective tables.
local DEFAULT_ARATHI_BASIN_CAPTURE_DURATION = Pins:GetDefaultObjectiveCaptureDuration()

local function NormalizeObjectiveKey(value)
    return Pins:NormalizeObjectiveKey(value)
end

local function GetCaptureTimerProfile(mapID)
    return Pins:GetCaptureTimerProfile(mapID)
end

local function IsCaptureTimerMap(mapID)
    return Pins:IsCaptureTimerMap(mapID)
end

local function IsCaptureTimerObjective(mapID, info)
    return Pins:IsCaptureTimerObjective(mapID, info)
end

local function IsSyntheticCaptureTimerSuppressed(mapID)
    return Pins.IsSyntheticCaptureTimerSuppressed
        and Pins:IsSyntheticCaptureTimerSuppressed(mapID)
end

local function GetObjectiveCaptureTimerKey(mapID, sourceIndex, info, mapX, mapY)
    return Pins:GetObjectiveCaptureTimerKey(mapID, sourceIndex, info, mapX, mapY)
end

local function FindObjectiveCaptureTimerRecord(pins, mapID, sourceIndex, info, mapX, mapY)
    return pins:FindObjectiveCaptureTimerRecord(mapID, sourceIndex, info, mapX, mapY)
end


local function GetTimerSettings(mapID)
    if BattleMaps.Database and BattleMaps.Database.GetBaseTimerConfig then
        return BattleMaps.Database:GetBaseTimerConfig(mapID)
    end
    return BattleMaps.Database and BattleMaps.Database:Get() or nil
end

local function GetBlitzUncapDuration(mapID, forceBlitz)
    if BattleMaps.Database and BattleMaps.Database.GetObjectiveBlitzUncapDuration then
        return BattleMaps.Database:GetObjectiveBlitzUncapDuration(mapID, forceBlitz)
    end
    if BattleMaps.GetObjectiveBlitzUncapDuration then
        return BattleMaps.GetObjectiveBlitzUncapDuration(mapID, forceBlitz)
    end
    return nil
end

local function GetBlitzRecapDuration(mapID, forceBlitz)
    if BattleMaps.Database and BattleMaps.Database.GetObjectiveBlitzRecapDuration then
        return BattleMaps.Database:GetObjectiveBlitzRecapDuration(mapID, forceBlitz)
    end
    if BattleMaps.GetObjectiveBlitzRecapDuration then
        return BattleMaps.GetObjectiveBlitzRecapDuration(mapID, forceBlitz)
    end
    return nil
end

local function TimerTextEnabledForRecord(db, record)
    if record and record.forceText == true then return true end
    if record and record.timerKind == "blitzUncap" then
        return db and db.showObjectiveBlitzUncapText == true
    end
    return db and db.showObjectiveTimerText ~= false
end

-- Capture timer visual layers ----------------------------------------------

-- Objective textures often contain transparent padding around their visible
-- silhouette. Map logical timer progress into the inner 80% of the texture so
-- the reveal is already visible at timer start and reaches the opposite padded
-- edge just before completion. Because this is a texture-coordinate fraction,
-- it scales with any source and rendered texture size.
local OBJECTIVE_CAPTURE_PROGRESS_EDGE_INSET = 0.10

local Private = Pins.Private or {}

local function BuildObjectiveKeys(info, index, fallbackKey)
    if Private.BuildObjectiveKeys then
        return Private.BuildObjectiveKeys(info, index, fallbackKey)
    end
    return {}
end

local function GetStationaryObjectiveAlpha(mapID)
    local config = BattleMaps.Database and BattleMaps.Database.GetBasePinConfig
        and BattleMaps.Database:GetBasePinConfig(mapID)
        or nil
    return BattleMaps.Clamp(tonumber(config and config.objectivePinAlpha) or 1.00, 0.15, 1.00)
end

local function ApplyStationaryObjectiveVisualAlpha(pin, mapID)
    if not pin then return 1 end
    if Pins.ApplyStationaryObjectiveVisualAlpha then
        Pins:ApplyStationaryObjectiveVisualAlpha(pin, mapID)
        return tonumber(pin.BattleMapsStationaryObjectiveAlpha) or GetStationaryObjectiveAlpha(mapID)
    end

    local alpha = GetStationaryObjectiveAlpha(mapID)
    pin.BattleMapsStationaryObjectiveAlpha = alpha
    if pin.SetAlpha then pin:SetAlpha(alpha) end
    return alpha
end

function Pins:EnsureObjectiveCaptureTimerTextures(pin)
    if not pin then return nil end

    if not pin.objectiveCaptureBaseTexture then
        local captureBaseTexture = pin:CreateTexture(nil, "OVERLAY", nil, 4)
        pin.objectiveCaptureBaseTexture = captureBaseTexture
        captureBaseTexture:SetAlpha(1)
        captureBaseTexture:Hide()

        local captureFillTexture = pin:CreateTexture(nil, "OVERLAY", nil, 5)
        pin.objectiveCaptureFillTexture = captureFillTexture
        captureFillTexture:SetAlpha(1)
        captureFillTexture:Hide()

        -- Retained as hidden compatibility layers for users upgrading from the
        -- earlier hold/flash prototype. The current two-layer timer uses only the
        -- full-colour base and cropped neutral overlay above it.
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
    end

    if not pin.objectiveCaptureTimerTextFrame then
        local timerFrame = CreateFrame("Frame", nil, pin)
        pin.objectiveCaptureTimerTextFrame = timerFrame
        timerFrame:SetAllPoints(pin)
        timerFrame:EnableMouse(false)
    end

    local timerFrame = pin.objectiveCaptureTimerTextFrame
    local pinLayer = pin.GetParent and pin:GetParent() or nil
    if timerFrame and timerFrame.SetFrameLevel then
        local baseLevel = pinLayer and pinLayer.GetFrameLevel and pinLayer:GetFrameLevel()
            or (pin.GetFrameLevel and pin:GetFrameLevel())
            or 0
        timerFrame:SetFrameLevel(baseLevel + OBJECTIVE_TIMER_TEXT_FRAME_LEVEL_OFFSET)
    end

    if not pin.objectiveCaptureTimerText then
        local timerText = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        pin.objectiveCaptureTimerText = timerText
        timerText:SetPoint("CENTER", pin.texture or pin, "CENTER", 0, 0)
        timerText:SetJustifyH("CENTER")
        timerText:SetJustifyV("MIDDLE")
        timerText:SetShadowColor(0, 0, 0, 1)
        timerText:SetShadowOffset(1, -1)
        timerText:Hide()
    end

    return pin
end


Pins.Private = Pins.Private or {}
Pins.Private.EnsureObjectiveCaptureTimerTextures = function(pin)
    return Pins:EnsureObjectiveCaptureTimerTextures(pin)
end

local function CopyObjectiveTextureAppearance(target, source, texturePath, desaturateFallback)
    if not target or not source then return false end

    target:SetRotation(0)
    target:SetVertexColor(1, 1, 1, 1)
    if target.SetDesaturated then target:SetDesaturated(false) end

    if type(texturePath) == "string" and texturePath ~= "" then
        target:SetTexture(texturePath)
        target:SetTexCoord(0, 1, 0, 1)
        return true
    end

    local atlas = source.GetAtlas and source:GetAtlas() or nil
    if atlas and atlas ~= "" and target.SetAtlas then
        local ok = pcall(target.SetAtlas, target, atlas, false)
        if not ok then return false end
    else
        local sourceTexture = source:GetTexture()
        if not sourceTexture then return false end
        target:SetTexture(sourceTexture)
    end

    local coords = { source:GetTexCoord() }
    if #coords >= 8 then
        target:SetTexCoord(
            coords[1], coords[2], coords[3], coords[4],
            coords[5], coords[6], coords[7], coords[8]
        )
    elseif #coords >= 4 then
        target:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        target:SetTexCoord(0, 1, 0, 1)
    end

    if source.GetRotation then
        target:SetRotation(source:GetRotation() or 0)
    end
    if desaturateFallback and target.SetDesaturated then
        target:SetDesaturated(true)
    end
    return true
end

local function SetTestStationaryObjectiveState(pins, pin, record, state)
    if not pins or not pin or not pin.texture or type(record) ~= "table" or not record.testSerial then
        return false
    end

    state = NormalizeObjectiveKey(state)
    if state == "" then return false end

    local mapID = tonumber(record.mapID)
    local sourceIndex = record.sourceIndex or pin.captureTimerTestSourceIndex
    local info = record.info or pin.captureTimerTestInfo or pin.previewObjectiveInfo or {}

    local texturePath
    if state == "alliance" or state == "horde" then
        texturePath = pin.objectiveCaptureFaction == state and pin.objectiveCaptureFactionPath or nil
        if not texturePath and pins.FindObjectiveTexture then
            texturePath = pins:FindObjectiveTexture(mapID, "stationary", BuildObjectiveKeys(info, sourceIndex, "stationary"), state)
        end
        -- Apply directly to the visible objective. The hidden capture base
        -- layer may have been recreated or cleared by a dummy-pin refresh, so
        -- it is not a reliable source for restoring ownership.
        if CopyObjectiveTextureAppearance(pin.texture, pin.texture, texturePath, texturePath == nil) then
            if texturePath then
                pin.texture:SetVertexColor(1, 1, 1, 1)
                if pin.texture.SetDesaturated then pin.texture:SetDesaturated(false) end
            else
                local fallbackColor = state == "alliance" and BattleMaps.COLORS.alliance
                    or state == "horde" and BattleMaps.COLORS.horde
                if fallbackColor then
                    pin.texture:SetVertexColor(fallbackColor[1], fallbackColor[2], fallbackColor[3], 1)
                end
            end
            pin.BattleMapsStationaryObjectiveState = state
            pin.captureTimerTestOwnedFaction = state
            return true
        end
        return false
    end

    if state == "neutral" or state == "uncontrolled" then
        texturePath = pin.objectiveCaptureNeutralPath
        if not texturePath and pins.FindObjectiveTexture then
            texturePath = pins:FindObjectiveTexture(mapID, "stationary", BuildObjectiveKeys(info, sourceIndex, "stationary"), "neutral")
        end
        local neutralSource = pin.objectiveCaptureFillTexture or pin.texture
        if CopyObjectiveTextureAppearance(pin.texture, neutralSource, texturePath, texturePath == nil) then
            pin.texture:SetVertexColor(1, 1, 1, 1)
            if pin.texture.SetDesaturated then pin.texture:SetDesaturated(texturePath == nil) end
            pin.BattleMapsStationaryObjectiveState = "neutral"
            pin.captureTimerTestOwnedFaction = nil
            return true
        end
    end

    return false
end

function Pins:SyncObjectiveCaptureFillTextures(pin, mapID, sourceIndex, info, faction)
    if not pin or not pin.texture
        or not pin.objectiveCaptureBaseTexture
        or not pin.objectiveCaptureFillTexture
        or not pin.objectiveCaptureHoldTexture
        or not pin.objectiveCaptureFlashTexture then
        return false
    end

    local source = pin.texture
    local baseTexture = pin.objectiveCaptureBaseTexture
    local fillTexture = pin.objectiveCaptureFillTexture
    local holdTexture = pin.objectiveCaptureHoldTexture
    local flashTexture = pin.objectiveCaptureFlashTexture
    local width, height = source:GetSize()
    width = tonumber(width) or 16
    height = tonumber(height) or width

    local point, relativeTo, relativePoint, offsetX, offsetY = source:GetPoint(1)
    local function AnchorFullTexture(texture)
        texture:ClearAllPoints()
        if point then
            texture:SetPoint(point, relativeTo or pin, relativePoint or point, offsetX or 0, offsetY or 0)
        else
            texture:SetPoint("CENTER", pin, "CENTER", 0, 0)
        end
        texture:SetSize(width, height)
    end

    AnchorFullTexture(baseTexture)
    AnchorFullTexture(holdTexture)
    AnchorFullTexture(flashTexture)

    local objectiveKeys = BuildObjectiveKeys(info, sourceIndex, "stationary")
    local neutralPath = self:FindObjectiveTexture(mapID, "stationary", objectiveKeys, "neutral")
    local factionPath = self:FindObjectiveTexture(mapID, "stationary", objectiveKeys, faction)

    -- The timer visual is intentionally simple: the attacking faction's full-
    -- colour objective sits on the bottom layer, and a neutral copy above it
    -- is cropped away over the capture duration. Pulsing the neutral top layer
    -- reveals flashes of the faction colour beneath while still preserving the
    -- time-to-capture information.
    if not CopyObjectiveTextureAppearance(baseTexture, source, factionPath, factionPath == nil) then
        return false
    end
    if not factionPath then
        local fallbackColor = faction == "alliance" and BattleMaps.COLORS.alliance
            or faction == "horde" and BattleMaps.COLORS.horde
        if fallbackColor then
            baseTexture:SetVertexColor(fallbackColor[1], fallbackColor[2], fallbackColor[3], 1)
        end
    end
    if not CopyObjectiveTextureAppearance(fillTexture, source, neutralPath, neutralPath == nil) then
        return false
    end
    if not CopyObjectiveTextureAppearance(holdTexture, source, factionPath, false) then
        return false
    end
    if not CopyObjectiveTextureAppearance(flashTexture, source, factionPath, factionPath == nil) then
        return false
    end

    fillTexture:SetBlendMode("BLEND")
    fillTexture:SetVertexColor(1, 1, 1, 1)
    flashTexture:SetBlendMode("ADD")
    if not factionPath then
        local flashFallbackColor = faction == "alliance" and BattleMaps.COLORS.alliance
            or faction == "horde" and BattleMaps.COLORS.horde
        if flashFallbackColor then
            flashTexture:SetVertexColor(flashFallbackColor[1], flashFallbackColor[2], flashFallbackColor[3], 1)
        else
            flashTexture:SetVertexColor(1, 1, 1, 1)
        end
    else
        flashTexture:SetVertexColor(1, 1, 1, 1)
    end
    flashTexture:SetAlpha(0)
    flashTexture:Hide()

    ApplyStationaryObjectiveVisualAlpha(pin, mapID)
    baseTexture:SetAlpha(1)
    fillTexture:SetAlpha(1)
    holdTexture:SetAlpha(1)

    pin.objectiveCaptureFullWidth = width
    pin.objectiveCaptureFullHeight = height
    pin.objectiveCaptureFillTexCoords = { fillTexture:GetTexCoord() }
    pin.objectiveCaptureNeutralPath = neutralPath
    pin.objectiveCaptureFactionPath = factionPath
    pin.objectiveCaptureFaction = faction

    local timerSettings = GetTimerSettings(mapID)
    local direction = timerSettings and timerSettings.objectiveCaptureFillDirection == "vertical"
        and "vertical" or "horizontal"
    self:LayoutObjectiveCaptureFillDirection(pin, direction)
    return true
end

function Pins:LayoutObjectiveCaptureFillDirection(pin, direction)
    if not pin or not pin.objectiveCaptureFillTexture or not pin.objectiveCaptureBaseTexture then
        return false
    end

    direction = direction == "vertical" and "vertical" or "horizontal"
    local fillTexture = pin.objectiveCaptureFillTexture
    local baseTexture = pin.objectiveCaptureBaseTexture
    local fullWidth = tonumber(pin.objectiveCaptureFullWidth) or 16
    local fullHeight = tonumber(pin.objectiveCaptureFullHeight) or fullWidth

    fillTexture:ClearAllPoints()
    if direction == "vertical" then
        -- Reveal faction colour from bottom to top by keeping the remaining
        -- neutral overlay anchored to the top edge.
        fillTexture:SetPoint("TOP", baseTexture, "TOP", 0, 0)
        fillTexture:SetWidth(fullWidth)
    else
        -- Reveal faction colour from left to right by keeping the remaining
        -- neutral overlay anchored to the right edge.
        fillTexture:SetPoint("RIGHT", baseTexture, "RIGHT", 0, 0)
        fillTexture:SetHeight(fullHeight)
    end
    pin.objectiveCaptureFillDirection = direction
    return true
end

function Pins:SetObjectiveCaptureFillProgress(pin, progress, direction)
    if not pin or not pin.objectiveCaptureFillTexture then return false end

    local fillTexture = pin.objectiveCaptureFillTexture
    local fullWidth = tonumber(pin.objectiveCaptureFullWidth) or 16
    local fullHeight = tonumber(pin.objectiveCaptureFullHeight) or fullWidth
    progress = BattleMaps.Clamp(tonumber(progress) or 0, 0, 1)
    direction = direction == "vertical" and "vertical" or "horizontal"

    if pin.objectiveCaptureFillDirection ~= direction then
        self:LayoutObjectiveCaptureFillDirection(pin, direction)
    end

    -- Objective textures often have transparent padding at their edges. Start
    -- with one inset already revealed and finish with the opposite inset still
    -- neutral, mapping logical 0..1 progress onto visual 10%..90% progress.
    -- Using a fraction rather than pixels keeps the crop correct for different
    -- texture source sizes, map scales, and zoom levels.
    local edgeInset = BattleMaps.Clamp(
        tonumber(OBJECTIVE_CAPTURE_PROGRESS_EDGE_INSET) or 0.10,
        0,
        0.49
    )
    local visualRevealProgress = edgeInset + (progress * (1 - (edgeInset * 2)))
    local visibleProgress = 1 - visualRevealProgress

    local coords = pin.objectiveCaptureFillTexCoords or { 0, 1, 0, 1 }
    if direction == "vertical" then
        local visibleHeight = math.max(fullHeight * visibleProgress, 0.01)
        fillTexture:SetSize(fullWidth, visibleHeight)

        if #coords >= 8 then
            -- Eight-point form: UL, LL, UR, LR. Keep the top edge fixed and
            -- move the bottom edge upward as the neutral overlay recedes.
            local ulx, uly = coords[1], coords[2]
            local llx, lly = coords[3], coords[4]
            local urx, ury = coords[5], coords[6]
            local lrx, lry = coords[7], coords[8]
            local bottomLeftX = ulx + ((llx - ulx) * visibleProgress)
            local bottomLeftY = uly + ((lly - uly) * visibleProgress)
            local bottomRightX = urx + ((lrx - urx) * visibleProgress)
            local bottomRightY = ury + ((lry - ury) * visibleProgress)
            fillTexture:SetTexCoord(
                ulx, uly,
                bottomLeftX, bottomLeftY,
                urx, ury,
                bottomRightX, bottomRightY
            )
        else
            local left = tonumber(coords[1]) or 0
            local right = tonumber(coords[2]) or 1
            local top = tonumber(coords[3]) or 0
            local bottom = tonumber(coords[4]) or 1
            local croppedBottom = top + ((bottom - top) * visibleProgress)
            fillTexture:SetTexCoord(left, right, top, croppedBottom)
        end
    else
        local visibleWidth = math.max(fullWidth * visibleProgress, 0.01)
        fillTexture:SetSize(visibleWidth, fullHeight)

        if #coords >= 8 then
            -- Eight-point form: UL, LL, UR, LR. Keep the right edge fixed and
            -- move the left edge from left to right as the neutral overlay recedes.
            local ulx, uly = coords[1], coords[2]
            local llx, lly = coords[3], coords[4]
            local urx, ury = coords[5], coords[6]
            local lrx, lry = coords[7], coords[8]
            local leftTopX = urx + ((ulx - urx) * visibleProgress)
            local leftTopY = ury + ((uly - ury) * visibleProgress)
            local leftBottomX = lrx + ((llx - lrx) * visibleProgress)
            local leftBottomY = lry + ((lly - lry) * visibleProgress)
            fillTexture:SetTexCoord(
                leftTopX, leftTopY,
                leftBottomX, leftBottomY,
                urx, ury,
                lrx, lry
            )
        else
            local left = tonumber(coords[1]) or 0
            local right = tonumber(coords[2]) or 1
            local top = tonumber(coords[3]) or 0
            local bottom = tonumber(coords[4]) or 1
            local croppedLeft = right - ((right - left) * visibleProgress)
            fillTexture:SetTexCoord(croppedLeft, right, top, bottom)
        end
    end

    fillTexture:Show()
    return true
end

function Pins:EnsureObjectiveCaptureFlashAnimation(pin)
    if not pin or not pin.objectiveCaptureFillTexture then return nil end
    local texture = pin.objectiveCaptureFillTexture
    if texture.BattleMapsCaptureFlashGroup then
        return texture.BattleMapsCaptureFlashGroup
    end

    local group = texture:CreateAnimationGroup()
    group:SetLooping("REPEAT")
    group.BattleMapsTexture = texture
    group.BattleMapsPin = pin

    local fadeOut = group:CreateAnimation("Alpha")
    fadeOut:SetOrder(1)
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0.58)
    fadeOut:SetDuration(0.40)
    fadeOut:SetSmoothing("IN_OUT")

    local fadeIn = group:CreateAnimation("Alpha")
    fadeIn:SetOrder(2)
    fadeIn:SetFromAlpha(0.58)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.40)
    fadeIn:SetSmoothing("IN_OUT")

    group.fadeIn = fadeIn
    group.fadeOut = fadeOut

    group:SetScript("OnPlay", function(animationGroup)
        animationGroup.completedLoops = 0
        animationGroup.completedNaturally = false
        local flash = animationGroup.BattleMapsTexture
        if flash then
            flash:SetAlpha(animationGroup.maximumAlpha or 1)
            flash:Show()
        end
    end)

    group:SetScript("OnLoop", function(animationGroup)
        animationGroup.completedLoops = (animationGroup.completedLoops or 0) + 1
        if animationGroup.completedLoops >= (animationGroup.targetLoops or 1) then
            animationGroup.completedNaturally = true
            animationGroup:Stop()
        end
    end)

    group:SetScript("OnStop", function(animationGroup)
        local flash = animationGroup.BattleMapsTexture
        if flash then
            flash:SetAlpha(animationGroup.maximumAlpha or 1)
            flash:Show()
        end
        local pulsePin = animationGroup.BattleMapsPin
        if pulsePin and animationGroup.completedNaturally then
            pulsePin.objectiveCaptureFlashCompletedEndAt = animationGroup.targetEndAt
        end
    end)

    texture.BattleMapsCaptureFlashGroup = group
    return group
end

function Pins:StopObjectiveCaptureTimerFlash(pin)
    if not pin or not pin.objectiveCaptureFillTexture then return end
    local texture = pin.objectiveCaptureFillTexture
    local group = texture.BattleMapsCaptureFlashGroup
    if group and group:IsPlaying() then
        group.completedNaturally = false
        group:Stop()
    end
    texture:SetAlpha(1)
    if pin.objectiveCaptureTimerKey then
        texture:Show()
    else
        texture:Hide()
    end
    pin.objectiveCaptureFlashEndAt = nil
    pin.objectiveCaptureFlashCompletedEndAt = nil
end

function Pins:EnsureObjectivePreCaptureFlashAnimation(pin)
    if not pin or not pin.objectiveCaptureFlashTexture then return nil end
    local texture = pin.objectiveCaptureFlashTexture
    if texture.BattleMapsPreCaptureFlashGroup then
        return texture.BattleMapsPreCaptureFlashGroup
    end

    local group = texture:CreateAnimationGroup()
    group:SetLooping("REPEAT")
    group.BattleMapsTexture = texture

    local brighten = group:CreateAnimation("Alpha")
    brighten:SetOrder(1)
    brighten:SetFromAlpha(0.10)
    brighten:SetToAlpha(1.00)
    brighten:SetDuration(0.24)
    brighten:SetSmoothing("OUT")

    local fade = group:CreateAnimation("Alpha")
    fade:SetOrder(2)
    fade:SetFromAlpha(1.00)
    fade:SetToAlpha(0.14)
    fade:SetDuration(0.46)
    fade:SetSmoothing("IN_OUT")

    group.brighten = brighten
    group.fade = fade

    group:SetScript("OnPlay", function(animationGroup)
        local flash = animationGroup.BattleMapsTexture
        if flash then
            flash:SetBlendMode("ADD")
            flash:SetAlpha(animationGroup.minimumAlpha or 0.10)
            flash:Show()
        end
    end)

    group:SetScript("OnStop", function(animationGroup)
        local flash = animationGroup.BattleMapsTexture
        if flash then
            flash:SetAlpha(0)
            flash:Hide()
        end
    end)

    texture.BattleMapsPreCaptureFlashGroup = group
    return group
end

function Pins:StopObjectivePreCaptureFlash(pin)
    if not pin or not pin.objectiveCaptureFlashTexture then return end
    local texture = pin.objectiveCaptureFlashTexture
    local group = texture.BattleMapsPreCaptureFlashGroup
    if group and group:IsPlaying() then
        group:Stop()
    end
    texture:SetAlpha(0)
    texture:Hide()
    pin.objectivePreCaptureFlashEndAt = nil
end

function Pins:PlayObjectivePreCaptureFlash(pin, targetEndAt)
    if not pin or not pin.objectiveCaptureFlashTexture then return false end

    local texture = pin.objectiveCaptureFlashTexture
    texture:SetBlendMode("ADD")
    texture:Show()

    local db = GetTimerSettings(pin.objectiveCaptureTimerMapID)
    local peakAlpha = BattleMaps.Clamp(tonumber(db and db.objectiveCaptureFlashBrightness) or 1.00, 0.10, 1.00)
    local minimumAlpha = math.min(peakAlpha, math.max(0.04, peakAlpha * 0.12))
    local fadeAlpha = math.min(peakAlpha, math.max(0.04, peakAlpha * 0.16))

    local group = self:EnsureObjectivePreCaptureFlashAnimation(pin)
    if group then
        if group.brighten then
            group.brighten:SetFromAlpha(minimumAlpha)
            group.brighten:SetToAlpha(peakAlpha)
        end
        if group.fade then
            group.fade:SetFromAlpha(peakAlpha)
            group.fade:SetToAlpha(fadeAlpha)
        end
        group.minimumAlpha = minimumAlpha
        group.maximumAlpha = peakAlpha
        if group:IsPlaying() and pin.objectivePreCaptureFlashEndAt == targetEndAt then
            return true
        end
        if group:IsPlaying() then
            group:Stop()
        end
        pin.objectivePreCaptureFlashEndAt = targetEndAt
        group:Play()
        return true
    end

    texture:SetAlpha(peakAlpha)
    pin.objectivePreCaptureFlashEndAt = targetEndAt
    return true
end

function Pins:PlayObjectiveCaptureTimerFlash(pin, remainingDuration, targetEndAt, timerSettings)
    if not pin or not pin.objectiveCaptureFillTexture then return false end
    remainingDuration = tonumber(remainingDuration) or 0
    if remainingDuration <= 0 then
        self:StopObjectiveCaptureTimerFlash(pin)
        return false
    end

    local group = self:EnsureObjectiveCaptureFlashAnimation(pin)
    if not group then return false end

    if group:IsPlaying() and pin.objectiveCaptureFlashEndAt == targetEndAt then
        return true
    end
    if pin.objectiveCaptureFlashCompletedEndAt == targetEndAt then
        return true
    end

    if group:IsPlaying() then
        group.completedNaturally = false
        group:Stop()
    end

    local db = timerSettings or GetTimerSettings(pin.objectiveCaptureTimerMapID)
    local preferredPeriod = 0.80
    local loopCount = math.max(math.floor((remainingDuration / preferredPeriod) + 0.5), 1)
    local period = remainingDuration / loopCount
    local halfPeriod = period * 0.5
    local minimumAlpha = BattleMaps.Clamp(
        tonumber(db.objectiveCapturePulseMinAlpha) or 0.40,
        0.00,
        1.00)
    local maximumAlpha = BattleMaps.Clamp(
        tonumber(db.objectiveCapturePulseMaxAlpha) or 0.60,
        0.00,
        1.00)
    if minimumAlpha > maximumAlpha then
        minimumAlpha, maximumAlpha = maximumAlpha, minimumAlpha
    end

    group.fadeOut:SetFromAlpha(maximumAlpha)
    group.fadeOut:SetToAlpha(minimumAlpha)
    group.fadeOut:SetDuration(halfPeriod)
    group.fadeIn:SetFromAlpha(minimumAlpha)
    group.fadeIn:SetToAlpha(maximumAlpha)
    group.fadeIn:SetDuration(halfPeriod)
    group.targetLoops = loopCount
    group.targetEndAt = targetEndAt
    group.completedLoops = 0
    group.completedNaturally = false

    pin.objectiveCaptureFlashEndAt = targetEndAt
    pin.objectiveCaptureFlashCompletedEndAt = nil
    group.maximumAlpha = maximumAlpha
    pin.objectiveCaptureFillTexture:SetVertexColor(1, 1, 1, 1)
    pin.objectiveCaptureFillTexture:SetAlpha(maximumAlpha)
    pin.objectiveCaptureFillTexture:Show()
    group:Play()
    return true
end

function Pins:UpdateObjectiveCaptureTimerSpecialLayers(pin, record, now)
    if not pin or not record then return end
    local db = GetTimerSettings(record.mapID or (pin and pin.objectiveCaptureTimerMapID))

    if pin.objectiveCaptureHoldTexture then
        pin.objectiveCaptureHoldTexture:Hide()
    end

    local remainingDuration = math.max((tonumber(record.expiresAt) or 0) - (tonumber(now) or 0), 0)
    local flashThreshold = BattleMaps.Clamp(
        tonumber(db.objectiveCaptureFlashThreshold) or 9,
        1,
        59
    )

    if db.flashObjectiveBeforeCapture == true
        and remainingDuration > 0
        and remainingDuration <= flashThreshold then
        self:PlayObjectivePreCaptureFlash(pin, record.expiresAt)
    else
        self:StopObjectivePreCaptureFlash(pin)
    end

    if db.pulseObjectiveDuringCaptureTimer ~= false and remainingDuration > 0 then
        self:PlayObjectiveCaptureTimerFlash(pin, remainingDuration, record.expiresAt, db)
    else
        self:StopObjectiveCaptureTimerFlash(pin)
    end
end

function Pins:ApplyObjectiveCaptureTimerTextStyle(pin)
    if not pin then return false end
    self:EnsureObjectiveCaptureTimerTextures(pin)
    local timerText = pin.objectiveCaptureTimerText
    if not timerText then return false end

    local db = GetTimerSettings(pin.objectiveCaptureTimerMapID or pin.objectiveBlitzUncapTimerMapID)
    local fontKey = tostring(db.objectiveTimerTextFont or "friz")
    local fontPath = BattleMaps.GetObjectiveTimerFontPath
        and BattleMaps.GetObjectiveTimerFontPath(fontKey)
        or (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
    if type(fontPath) ~= "string" or fontPath == "" then
        fontPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    end

    -- Font size and offsets are authored against a standard 24 px objective.
    -- Scaling from the live texture dimensions makes the text follow both the
    -- objective-size setting and the map zoom response.
    local sourceTexture = pin.texture or pin.objectiveCaptureBaseTexture
    local textureWidth, textureHeight = sourceTexture and sourceTexture:GetSize()
    textureWidth = tonumber(textureWidth) or tonumber(pin.objectiveCaptureFullWidth) or 24
    textureHeight = tonumber(textureHeight) or tonumber(pin.objectiveCaptureFullHeight) or textureWidth
    local visualSize = math.max(math.min(textureWidth, textureHeight), 1)
    local textureScale = BattleMaps.Clamp(visualSize / 24, 0.50, 4.00)

    local baseFontSize = BattleMaps.Clamp(
        math.floor((tonumber(db.objectiveTimerTextSize) or 14) + 0.5), 8, 32)
    local fontSize = BattleMaps.Clamp(
        math.floor((baseFontSize * textureScale) + 0.5), 6, 72)
    local offsetX = BattleMaps.Clamp(tonumber(db.objectiveTimerTextOffsetX) or 0, -32, 32)
    local offsetY = BattleMaps.Clamp(tonumber(db.objectiveTimerTextOffsetY) or 0, -32, 32)
    local scaledOffsetX = math.floor((offsetX * textureScale) + (offsetX >= 0 and 0.5 or -0.5))
    local scaledOffsetY = math.floor((offsetY * textureScale) + (offsetY >= 0 and 0.5 or -0.5))

    local color = type(db.objectiveTimerTextColor) == "table"
        and db.objectiveTimerTextColor or {}
    local r = BattleMaps.Clamp(tonumber(color.r or color[1]) or 1, 0, 1)
    local g = BattleMaps.Clamp(tonumber(color.g or color[2]) or 1, 0, 1)
    local b = BattleMaps.Clamp(tonumber(color.b or color[3]) or 1, 0, 1)
    local textAlpha = BattleMaps.Clamp(tonumber(db.objectiveTimerTextAlpha) or 1.00, 0, 1)
    local styleKey = table.concat({
        fontKey,
        fontPath,
        tostring(fontSize),
        tostring(r), tostring(g), tostring(b), tostring(textAlpha),
        tostring(scaledOffsetX), tostring(scaledOffsetY),
        string.format("%.2f", textureWidth),
        string.format("%.2f", textureHeight),
    }, ":")

    if pin.objectiveCaptureTimerTextStyleKey ~= styleKey then
        local ok, result = pcall(timerText.SetFont, timerText, fontPath, fontSize, "OUTLINE")
        local fontApplied = ok and result ~= false
        if not fontApplied then
            local fallbackPath = STANDARD_TEXT_FONT or [[Fonts\FRIZQT__.TTF]]
            if GameFontNormal and GameFontNormal.GetFont then
                fallbackPath = select(1, GameFontNormal:GetFont()) or fallbackPath
            end
            local fallbackOK, fallbackResult = pcall(
                timerText.SetFont,
                timerText,
                fallbackPath,
                fontSize,
                "OUTLINE"
            )
            fontApplied = fallbackOK and fallbackResult ~= false
        end

        if not fontApplied and GameFontNormal and timerText.SetFontObject then
            fontApplied = pcall(timerText.SetFontObject, timerText, GameFontNormal)
        end
        if not fontApplied then return false end

        timerText:ClearAllPoints()
        timerText:SetPoint("CENTER", sourceTexture or pin, "CENTER", scaledOffsetX, scaledOffsetY)
        timerText:SetJustifyH("CENTER")
        timerText:SetJustifyV("MIDDLE")
        timerText:SetTextColor(r, g, b, textAlpha)
        timerText:SetShadowColor(0, 0, 0, 1)
        timerText:SetShadowOffset(math.max(math.floor(textureScale + 0.5), 1), -math.max(math.floor(textureScale + 0.5), 1))
        pin.objectiveCaptureTimerTextStyleKey = styleKey
    end
    return true
end

function Pins:UpdateObjectiveCaptureTimerText(pin, record, now)
    if not pin or not record then return end
    self:EnsureObjectiveCaptureTimerTextures(pin)
    local timerText = pin.objectiveCaptureTimerText
    if not timerText then return end

    local db = GetTimerSettings(record.mapID or pin.objectiveCaptureTimerMapID)
    if not TimerTextEnabledForRecord(db, record) then
        timerText:Hide()
        return
    end

    local remaining = math.max((tonumber(record.expiresAt) or 0) - (tonumber(now) or 0), 0)
    local threshold = BattleMaps.Clamp(
        math.floor((tonumber(record.forceThreshold) or tonumber(db.objectiveTimerTextThreshold) or 9) + 0.5), 1, 300)
    if remaining <= 0 or remaining > threshold then
        timerText:Hide()
        return
    end

    if not self:ApplyObjectiveCaptureTimerTextStyle(pin) then
        timerText:Hide()
        return
    end
    local seconds = math.max(math.ceil(remaining - 0.001), 1)
    local displayText
    if seconds >= 60 then
        displayText = string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
    else
        displayText = tostring(seconds)
    end

    if pin.objectiveCaptureTimerTextValue ~= displayText then
        timerText:SetText(displayText)
        pin.objectiveCaptureTimerTextValue = displayText
    end
    timerText:Show()
end

function Pins:RefreshObjectiveTimerTextSettings()
    local now = type(GetTime) == "function" and GetTime() or 0
    for _, collection in ipairs({ self.poiPins or {}, self.dummyStationaryPins or {} }) do
        for _, pin in ipairs(collection) do
            if pin then
                pin.objectiveCaptureTimerTextStyleKey = nil
                local record = pin.objectiveCaptureTimerKey
                    and self.objectiveCaptureTimers[pin.objectiveCaptureTimerKey] or nil
                if not record then
                    record = pin.objectiveBlitzUncapTimerKey
                        and self.objectiveBlitzUncapTimers
                        and self.objectiveBlitzUncapTimers[pin.objectiveBlitzUncapTimerKey]
                        or nil
                end
                if record then
                    self:UpdateObjectiveCaptureTimerText(pin, record, now)
                elseif pin.objectiveCaptureTimerText then
                    pin.objectiveCaptureTimerText:Hide()
                end
            end
        end
    end
end

function Pins:RefreshObjectiveCapturePulseSettings()
    local now = type(GetTime) == "function" and GetTime() or 0
    for _, collection in ipairs({ self.poiPins or {}, self.dummyStationaryPins or {} }) do
        for _, pin in ipairs(collection) do
            if pin and pin.objectiveCaptureTimerKey then
                local record = self.objectiveCaptureTimers
                    and self.objectiveCaptureTimers[pin.objectiveCaptureTimerKey]
                    or nil
                self:StopObjectiveCaptureTimerFlash(pin)
                self:StopObjectivePreCaptureFlash(pin)
                if record and record.expiresAt and record.expiresAt > now then
                    self:UpdateObjectiveCaptureTimerSpecialLayers(pin, record, now)
                end
            end
        end
    end
end

function Pins:ClearObjectiveBlitzUncapTimerPin(pin)
    if not pin then return end

    pin.objectiveBlitzUncapTimerKey = nil
    pin.objectiveBlitzUncapTimerMapID = nil

    if pin.objectiveCaptureTimerText and not pin.objectiveCaptureTimerKey then
        pin.objectiveCaptureTimerText:Hide()
        pin.objectiveCaptureTimerTextValue = nil
    end
end

function Pins:ClearObjectiveCaptureTimerPin(pin)
    if not pin then return end

    self:StopObjectiveCaptureTimerFlash(pin)
    self:StopObjectivePreCaptureFlash(pin)

    if pin.objectiveCaptureBaseTexture then
        pin.objectiveCaptureBaseTexture:Hide()
    end
    if pin.objectiveCaptureFillTexture then
        pin.objectiveCaptureFillTexture:Hide()
        pin.objectiveCaptureFillTexture:SetTexCoord(0, 1, 0, 1)
    end
    if pin.objectiveCaptureHoldTexture then
        pin.objectiveCaptureHoldTexture:Hide()
    end
    if pin.objectiveCaptureFlashTexture then
        pin.objectiveCaptureFlashTexture:SetAlpha(0)
        pin.objectiveCaptureFlashTexture:Hide()
    end
    if pin.objectiveCaptureTimerText and not pin.objectiveBlitzUncapTimerKey then
        -- Hiding is sufficient; avoid writing text during cleanup before an
        -- inherited font template or SharedMedia font has been applied.
        pin.objectiveCaptureTimerText:Hide()
    end
    if not pin.objectiveBlitzUncapTimerKey then
        pin.objectiveCaptureTimerTextValue = nil
    end

    pin.objectiveCaptureTimerKey = nil
    pin.objectiveCaptureFullWidth = nil
    pin.objectiveCaptureFullHeight = nil
    pin.objectiveCaptureFillTexCoords = nil
    pin.objectiveCaptureFillDirection = nil
    pin.objectiveCaptureTimerMapID = nil
    pin.objectiveCaptureNeutralPath = nil
    pin.objectiveCaptureFactionPath = nil
    pin.objectiveCaptureFaction = nil
    pin.objectivePreCaptureFlashEndAt = nil
    pin.objectiveCaptureReportName = nil
    pin.objectiveCaptureReportFaction = nil
    pin.captureTimerTestInfo = nil
    pin.captureTimerTestSourceIndex = nil
end

-- Objective capture chat reporting was removed to avoid protected chat taint in PvP.

function Pins:HasActiveObjectiveTimerVisuals()
    return next(self.objectiveCaptureTimers or {}) ~= nil
        or next(self.objectiveBlitzUncapTimers or {}) ~= nil
end

function Pins:StopObjectiveCaptureTimerByKey(timerKey)
    if not timerKey or timerKey == "" then return false end

    local record = self.objectiveCaptureTimers[timerKey]
    if record then
        record.token = (record.token or 0) + 1
        self.objectiveCaptureTimers[timerKey] = nil
    end

    for _, collection in ipairs({ self.poiPins or {}, self.dummyStationaryPins or {} }) do
        for _, pin in ipairs(collection) do
            if pin and pin.objectiveCaptureTimerKey == timerKey then
                -- In Test mode, a completed capture should leave the base in
                -- the attacking faction state before the Blitz uncap/lockout
                -- phase begins. Without this, clearing the timer exposes the
                -- original neutral dummy texture.
                if record and record.testSerial then
                    SetTestStationaryObjectiveState(self, pin, record, record.faction)
                end
                self:ClearObjectiveCaptureTimerPin(pin)
                if pin.objectiveBlitzUncapTimerKey then
                    local now = type(GetTime) == "function" and GetTime() or 0
                    local uncapRecord = self.objectiveBlitzUncapTimers
                        and self.objectiveBlitzUncapTimers[pin.objectiveBlitzUncapTimerKey]
                        or nil
                    if uncapRecord and uncapRecord.expiresAt and uncapRecord.expiresAt > now then
                        self:UpdateObjectiveCaptureTimerText(pin, uncapRecord, now)
                    end
                end
            end
        end
    end
    return record ~= nil
end

function Pins:StopObjectiveBlitzUncapTimerByKey(timerKey, transitionToNeutral)
    if not timerKey or timerKey == "" then return false end

    local record = self.objectiveBlitzUncapTimers and self.objectiveBlitzUncapTimers[timerKey]
    if record then
        record.token = (record.token or 0) + 1
        self.objectiveBlitzUncapTimers[timerKey] = nil

        -- Natural expiry of the 45-second Blitz control phase deactivates the
        -- base to neutral. Keep this separate from cancellation by a new
        -- assault, which must not momentarily force the base neutral.
        if transitionToNeutral == true then
            local pin = self:FindStationaryObjectivePinAt(record.mapX, record.mapY)
            if record.testSerial then
                if pin then
                    SetTestStationaryObjectiveState(self, pin, record, "neutral")
                end
            elseif self.RecordStationaryObjectiveNeutralTransition then
                self:RecordStationaryObjectiveNeutralTransition(
                    record.mapID,
                    record.sourceIndex,
                    record.info,
                    record.objectiveName
                )
            elseif self.ForceStationaryObjectiveState then
                self:ForceStationaryObjectiveState(
                    record.mapID,
                    record.sourceIndex,
                    record.info,
                    "neutral"
                )
            end
        end
    end

    for _, collection in ipairs({ self.poiPins or {}, self.dummyStationaryPins or {} }) do
        for _, pin in ipairs(collection) do
            if pin and pin.objectiveBlitzUncapTimerKey == timerKey then
                self:ClearObjectiveBlitzUncapTimerPin(pin)
            end
        end
    end

    if record and transitionToNeutral == true
        and not record.testSerial
        and BattleMaps.MapFrame and BattleMaps.MapFrame.frame
        and BattleMaps.MapFrame.frame:IsShown()
        and C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if BattleMaps.MapFrame and BattleMaps.MapFrame.frame
                and BattleMaps.MapFrame.frame:IsShown()
                and self.RefreshPOIs then
                self:RefreshPOIs()
            end
        end)
    end
    return record ~= nil
end

function Pins:StopAllObjectiveCaptureTimers()
    self.captureTimerTestSerial = (self.captureTimerTestSerial or 0) + 1
    self.captureTimerTestMapID = nil
    for _, record in pairs(self.objectiveCaptureTimers or {}) do
        if record then record.token = (record.token or 0) + 1 end
    end
    wipe(self.objectiveCaptureTimers)

    for _, record in pairs(self.objectiveBlitzUncapTimers or {}) do
        if record then record.token = (record.token or 0) + 1 end
    end
    wipe(self.objectiveBlitzUncapTimers)

    for _, collection in ipairs({ self.poiPins or {}, self.dummyStationaryPins or {} }) do
        for _, pin in ipairs(collection) do
            self:ClearObjectiveCaptureTimerPin(pin)
            self:ClearObjectiveBlitzUncapTimerPin(pin)
        end
    end
end

function Pins:ApplyObjectiveBlitzUncapTimerToPin(pin, mapID, sourceIndex, info, mapX, mapY)
    if not pin then return false end

    mapID = tonumber(mapID) or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local db = GetTimerSettings(mapID)
    if IsSyntheticCaptureTimerSuppressed(mapID)
        or not IsCaptureTimerMap(mapID)
        or not IsCaptureTimerObjective(mapID, info) then
        self:ClearObjectiveBlitzUncapTimerPin(pin)
        return false
    end

    local timerKey = GetObjectiveCaptureTimerKey(mapID, sourceIndex, info, mapX, mapY)
    local record = timerKey and self.objectiveBlitzUncapTimers
        and self.objectiveBlitzUncapTimers[timerKey]
        or nil
    local now = type(GetTime) == "function" and GetTime() or 0

    if not record or not record.expiresAt or now >= record.expiresAt then
        if record then
            self:StopObjectiveBlitzUncapTimerByKey(timerKey, true)
        else
            self:ClearObjectiveBlitzUncapTimerPin(pin)
        end
        return false
    end

    -- The active 45-second Blitz phase is faction-controlled. Keep the pin
    -- associated with the record regardless of whether its optional countdown
    -- text is enabled; visual ownership and text visibility are separate state.
    pin.objectiveBlitzUncapTimerKey = timerKey
    pin.objectiveBlitzUncapTimerMapID = mapID

    if record.testSerial then
        SetTestStationaryObjectiveState(self, pin, record, record.faction)
    end

    if TimerTextEnabledForRecord(db, record) then
        self:EnsureObjectiveCaptureTimerTextures(pin)
        self:UpdateObjectiveCaptureTimerText(pin, record, now)
    elseif pin.objectiveCaptureTimerText and not pin.objectiveCaptureTimerKey then
        pin.objectiveCaptureTimerText:Hide()
        pin.objectiveCaptureTimerTextValue = nil
    end
    return true
end

function Pins:ApplyObjectiveCaptureTimerToPin(pin, mapID, sourceIndex, info, mapX, mapY)
    if not pin then return false end

    mapID = tonumber(mapID) or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local db = GetTimerSettings(mapID)
    if IsSyntheticCaptureTimerSuppressed(mapID)
        or not IsCaptureTimerMap(mapID)
        or not IsCaptureTimerObjective(mapID, info) then
        self:ClearObjectiveCaptureTimerPin(pin)
        self:ClearObjectiveBlitzUncapTimerPin(pin)
        return false
    end

    local timerKey, record = FindObjectiveCaptureTimerRecord(
        self, mapID, sourceIndex, info, mapX, mapY
    )
    local now = type(GetTime) == "function" and GetTime() or 0

    if not record or not record.expiresAt or now >= record.expiresAt
        or (db.showObjectiveCaptureTimers == false and record.forceVisual ~= true) then
        if record and now >= record.expiresAt then self.objectiveCaptureTimers[timerKey] = nil end
        self:ClearObjectiveCaptureTimerPin(pin)
        return self:ApplyObjectiveBlitzUncapTimerToPin(pin, mapID, sourceIndex, info, mapX, mapY)
    end

    if pin.objectiveCaptureTimerKey and pin.objectiveCaptureTimerKey ~= timerKey then
        self:ClearObjectiveCaptureTimerPin(pin)
    end

    if not self:SyncObjectiveCaptureFillTextures(pin, mapID, sourceIndex, info, record.faction) then
        self:ClearObjectiveCaptureTimerPin(pin)
        return self:ApplyObjectiveBlitzUncapTimerToPin(pin, mapID, sourceIndex, info, mapX, mapY)
    end

    self:ClearObjectiveBlitzUncapTimerPin(pin)
    ApplyStationaryObjectiveVisualAlpha(pin, mapID)
    pin.objectiveCaptureBaseTexture:SetAlpha(1)
    pin.objectiveCaptureBaseTexture:Show()
    pin.objectiveCaptureTimerKey = timerKey
    pin.objectiveCaptureTimerMapID = mapID
    pin.objectiveCaptureReportName = record.objectiveName or (info and info.name) or pin.tooltipTitle
    pin.objectiveCaptureReportFaction = record.faction
    local progress = BattleMaps.Clamp((now - record.startedAt) / record.duration, 0, 1)
    local direction = db.objectiveCaptureFillDirection == "vertical" and "vertical" or "horizontal"
    self:SetObjectiveCaptureFillProgress(pin, progress, direction)
    self:UpdateObjectiveCaptureTimerSpecialLayers(pin, record, now)
    self:UpdateObjectiveCaptureTimerText(pin, record, now)
    return true
end

function Pins:UpdateObjectiveCaptureTimerVisuals()
    if not self:HasActiveObjectiveTimerVisuals() then return end

    local currentMapID = self.currentMapID or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    if IsSyntheticCaptureTimerSuppressed(currentMapID) then
        self:StopAllObjectiveCaptureTimers()
        return
    end

    local db = GetTimerSettings(currentMapID)
    local direction = db.objectiveCaptureFillDirection == "vertical" and "vertical" or "horizontal"
    local now = type(GetTime) == "function" and GetTime() or 0
    for _, collection in ipairs({ self.poiPins or {}, self.dummyStationaryPins or {} }) do
        for _, pin in ipairs(collection) do
            local timerKey = pin and pin.objectiveCaptureTimerKey
            local record = timerKey and self.objectiveCaptureTimers[timerKey] or nil
            if record and record.expiresAt and now < record.expiresAt then
                local progress = BattleMaps.Clamp((now - record.startedAt) / record.duration, 0, 1)
                self:SetObjectiveCaptureFillProgress(pin, progress, direction)
                self:UpdateObjectiveCaptureTimerSpecialLayers(pin, record, now)
                self:UpdateObjectiveCaptureTimerText(pin, record, now)
            elseif timerKey then
                self:StopObjectiveCaptureTimerByKey(timerKey)
            end

            local uncapKey = pin and pin.objectiveBlitzUncapTimerKey
            local uncapRecord = uncapKey and self.objectiveBlitzUncapTimers and self.objectiveBlitzUncapTimers[uncapKey] or nil
            if uncapRecord and uncapRecord.expiresAt and now < uncapRecord.expiresAt then
                -- Dummy preview refreshes restore their authored neutral texture.
                -- Reassert the owning faction every update so the 45-second
                -- Blitz lock remains visibly controlled for its full duration.
                if uncapRecord.testSerial then
                    SetTestStationaryObjectiveState(self, pin, uncapRecord, uncapRecord.faction)
                end
                if not pin.objectiveCaptureTimerKey then
                    self:UpdateObjectiveCaptureTimerText(pin, uncapRecord, now)
                end
            elseif uncapKey then
                self:StopObjectiveBlitzUncapTimerByKey(uncapKey, true)
            end
        end
    end
end

function Pins:StartObjectiveCaptureTimer(mapID, sourceIndex, info, mapX, mapY, faction, elapsedOverride, testSerial, durationOverride, forceText, forceVisual)
    mapID = tonumber(mapID) or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local db = GetTimerSettings(mapID)
    faction = NormalizeObjectiveKey(faction)
    if IsSyntheticCaptureTimerSuppressed(mapID)
        or (db.showObjectiveCaptureTimers == false and forceVisual ~= true)
        or not IsCaptureTimerMap(mapID)
        or not IsCaptureTimerObjective(mapID, info)
        or (faction ~= "alliance" and faction ~= "horde") then
        return false
    end

    local timerKey = GetObjectiveCaptureTimerKey(mapID, sourceIndex, info, mapX, mapY)
    local now = type(GetTime) == "function" and GetTime() or 0
    local previous = self.objectiveCaptureTimers[timerKey]
    local token = ((previous and previous.token) or 0) + 1
    local duration = tonumber(durationOverride)
        or BattleMaps.Database:GetObjectiveCaptureDuration(mapID)
        or DEFAULT_ARATHI_BASIN_CAPTURE_DURATION
    local elapsed = BattleMaps.Clamp(tonumber(elapsedOverride) or 0, 0, math.max(duration - 0.25, 0))
    local startedAt = now - elapsed
    local remaining = math.max(duration - elapsed, 0.25)

    if self.objectiveBlitzUncapTimers then
        self:StopObjectiveBlitzUncapTimerByKey(timerKey)
    end

    self.objectiveCaptureTimers[timerKey] = {
        mapID = mapID,
        mapX = mapX,
        mapY = mapY,
        faction = faction,
        objectiveName = tostring((type(info) == "table" and info.name) or "Objective"),
        sourceIndex = sourceIndex,
        info = info,
        startedAt = startedAt,
        duration = duration,
        expiresAt = now + remaining,
        token = token,
        testSerial = testSerial,
        forceText = forceText == true,
        forceThreshold = forceText == true and duration or nil,
        forceVisual = forceVisual == true,
        timerKind = "capture",
    }

    local pin = self:FindStationaryObjectivePinAt(mapX, mapY)
    if pin then
        self:ApplyObjectiveCaptureTimerToPin(pin, mapID, sourceIndex, info, mapX, mapY)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(remaining + 0.10, function()
            local current = self.objectiveCaptureTimers[timerKey]
            if current and current.token == token then
                self:StopObjectiveCaptureTimerByKey(timerKey)
            end
        end)
    end
    return true
end

function Pins:StartObjectiveBlitzUncapTimer(mapID, sourceIndex, info, mapX, mapY, faction, elapsedOverride, durationOverride, testSerial, forceText)
    mapID = tonumber(mapID) or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    faction = NormalizeObjectiveKey(faction)
    local duration = tonumber(durationOverride) or GetBlitzUncapDuration(mapID)
    if not duration
        or IsSyntheticCaptureTimerSuppressed(mapID)
        or not IsCaptureTimerMap(mapID)
        or not IsCaptureTimerObjective(mapID, info)
        or (faction ~= "alliance" and faction ~= "horde") then
        return false
    end

    self.objectiveBlitzUncapTimers = self.objectiveBlitzUncapTimers or {}

    local timerKey = GetObjectiveCaptureTimerKey(mapID, sourceIndex, info, mapX, mapY)
    local now = type(GetTime) == "function" and GetTime() or 0
    local previous = self.objectiveBlitzUncapTimers[timerKey]
    local token = ((previous and previous.token) or 0) + 1
    local elapsed = BattleMaps.Clamp(tonumber(elapsedOverride) or 0, 0, math.max(duration - 0.25, 0))
    local remaining = math.max(duration - elapsed, 0.25)

    self.objectiveBlitzUncapTimers[timerKey] = {
        mapID = mapID,
        mapX = mapX,
        mapY = mapY,
        faction = faction,
        objectiveName = tostring((type(info) == "table" and info.name) or "Objective"),
        sourceIndex = sourceIndex,
        info = info,
        startedAt = now - elapsed,
        duration = duration,
        expiresAt = now + remaining,
        token = token,
        testSerial = testSerial,
        forceText = forceText == true,
        forceThreshold = forceText == true and duration or nil,
        timerKind = "blitzUncap",
    }

    local pin = self:FindStationaryObjectivePinAt(mapX, mapY)
    if pin and not pin.objectiveCaptureTimerKey then
        self:ApplyObjectiveBlitzUncapTimerToPin(pin, mapID, sourceIndex, info, mapX, mapY)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(remaining + 0.10, function()
            local current = self.objectiveBlitzUncapTimers and self.objectiveBlitzUncapTimers[timerKey]
            if current and current.token == token then
                self:StopObjectiveBlitzUncapTimerByKey(timerKey, true)
            end
        end)
    end
    return true
end

function Pins:StopObjectiveCaptureTimer(mapID, sourceIndex, info, mapX, mapY)
    if not IsCaptureTimerMap(mapID) or not IsCaptureTimerObjective(mapID, info) then return false end
    local timerKey = FindObjectiveCaptureTimerRecord(
        self, mapID, sourceIndex, info, mapX, mapY
    )
    return self:StopObjectiveCaptureTimerByKey(timerKey)
end

function Pins:StopObjectiveBlitzUncapTimer(mapID, sourceIndex, info, mapX, mapY, transitionToNeutral)
    if not IsCaptureTimerMap(mapID) or not IsCaptureTimerObjective(mapID, info) then return false end
    local timerKey = GetObjectiveCaptureTimerKey(mapID, sourceIndex, info, mapX, mapY)
    return self:StopObjectiveBlitzUncapTimerByKey(timerKey, transitionToNeutral == true)
end

function Pins:StopCaptureTimerTest()
    self.captureTimerTestSerial = (self.captureTimerTestSerial or 0) + 1
    self.captureTimerTestMapID = nil

    for _, pin in ipairs(self.dummyStationaryPins or {}) do
        if pin then
            pin.captureTimerTestInfo = nil
            pin.captureTimerTestSourceIndex = nil
        end
    end

    for timerKey, record in pairs(self.objectiveCaptureTimers or {}) do
        if record and record.testSerial then
            self:StopObjectiveCaptureTimerByKey(timerKey)
        end
    end

    for timerKey, record in pairs(self.objectiveBlitzUncapTimers or {}) do
        if record and record.testSerial then
            self:StopObjectiveBlitzUncapTimerByKey(timerKey)
        end
    end
end

function Pins:StartCaptureTimerTest(mapID, faction)
    if BattleMaps.IsInLiveBattleground() then
        return false, "The capture-timer test is available only outside a live battleground."
    end

    local mapFrame = BattleMaps.MapFrame
    mapID = tonumber(mapID) or (mapFrame and mapFrame.currentMapID)
    faction = NormalizeObjectiveKey(faction)
    local profile = GetCaptureTimerProfile(mapID)
    if not profile then
        return false, "This battleground does not use delayed capture-objective timers."
    end
    if faction ~= "alliance" and faction ~= "horde" then
        faction = "alliance"
    end

    self:RefreshDummyPins()
    -- PreviewPins owns objective previews only; UnitPins owns the single
    -- per-map player/team test preview. Keep both refreshed when a timer test
    -- starts without recreating any legacy unit frames.
    if self.RefreshUnitTestPreview then
        self:RefreshUnitTestPreview()
    end

    local targets = {}
    for _, pin in ipairs(self.dummyStationaryPins or {}) do
        if pin and pin:IsShown() and pin.mapX and pin.mapY then
            local info = pin.previewObjectiveInfo or {}
            if IsCaptureTimerObjective(mapID, info) then
                targets[#targets + 1] = pin
            end
        end
    end

    if #targets == 0 then
        return false, "No capturable objective previews are currently visible."
    end

    self:StopCaptureTimerTest()
    self:StopAllObjectiveCaptureTimers()
    self.captureTimerTestSerial = (self.captureTimerTestSerial or 0) + 1
    local serial = self.captureTimerTestSerial
    self.captureTimerTestMapID = mapID

    local forceBlitzCycle = BattleMaps.IsObjectiveBlitzUncapMap
        and BattleMaps.IsObjectiveBlitzUncapMap(mapID) == true
    local duration
    if forceBlitzCycle then
        duration = BattleMaps.Clamp(tonumber(profile.blitzDuration) or 30, 1, 300)
    else
        duration = BattleMaps.Database:GetObjectiveCaptureDuration(mapID, false)
            or DEFAULT_ARATHI_BASIN_CAPTURE_DURATION
    end
    local uncapDuration = forceBlitzCycle
        and GetBlitzUncapDuration(mapID, true)
        or nil
    local recapDelay = forceBlitzCycle
        and (GetBlitzRecapDuration(mapID, true) or 5)
        or 0
    local assaultCastDuration = forceBlitzCycle
        and BattleMaps.Clamp(tonumber(profile.blitzAssaultCastDuration) or 4, 0, 30)
        or 0
    local progressPattern = { 0.08, 0.24, 0.43, 0.62, 0.81, 0.34, 0.70 }
    local startedCount = 0
    local objectiveNames = {}

    local function OppositeFaction(value)
        return value == "horde" and "alliance" or "horde"
    end

    local function TestStillActive()
        return self.captureTimerTestSerial == serial
            and self.captureTimerTestMapID == mapID
            and BattleMaps.MapFrame
            and BattleMaps.MapFrame.currentMapID == mapID
            and BattleMaps.MapFrame.testMode == true
    end

    local StartLoopForPin
    local StartUncapForPin

    StartUncapForPin = function(pin, index, owningFaction, elapsed)
        if not TestStillActive() then return end
        if not uncapDuration then
            StartLoopForPin(pin, index, OppositeFaction(owningFaction), 0)
            return
        end

        local info = pin.previewObjectiveInfo or {}
        local sourceIndex = pin.previewObjectiveSourceIndex or index
        pin.captureTimerTestInfo = info
        pin.captureTimerTestSourceIndex = sourceIndex

        -- A Blitz uncap/lockout timer belongs to a base that has already been
        -- fully captured. Show the owning faction texture for the whole
        -- lockout period, even when the uncap text option is disabled.
        SetTestStationaryObjectiveState(self, pin, {
            testSerial = serial,
            mapID = mapID,
            sourceIndex = sourceIndex,
            info = info,
            faction = owningFaction,
        }, owningFaction)

        local started = self:StartObjectiveBlitzUncapTimer(
            mapID,
            sourceIndex,
            info,
            pin.mapX,
            pin.mapY,
            owningFaction,
            elapsed,
            uncapDuration,
            serial,
            false
        )
        if not started then return end

        local remaining = math.max(uncapDuration - (tonumber(elapsed) or 0), 0.25)
        if C_Timer and C_Timer.After then
            C_Timer.After(remaining + recapDelay + assaultCastDuration + 0.20, function()
                if not TestStillActive() then return end
                StartLoopForPin(pin, index, OppositeFaction(owningFaction), 0)
            end)
        end
    end

    StartLoopForPin = function(pin, index, nextFaction, elapsed)
        if not TestStillActive() then return end

        local info = pin.previewObjectiveInfo or {}
        local sourceIndex = pin.previewObjectiveSourceIndex or index
        pin.captureTimerTestInfo = info
        pin.captureTimerTestSourceIndex = sourceIndex

        local started = self:StartObjectiveCaptureTimer(
            mapID,
            sourceIndex,
            info,
            pin.mapX,
            pin.mapY,
            nextFaction,
            elapsed,
            serial,
            duration,
            false,
            forceBlitzCycle
        )
        if not started then return end

        local remaining = math.max(duration - (tonumber(elapsed) or 0), 0.25)
        if C_Timer and C_Timer.After then
            C_Timer.After(remaining + 0.20, function()
                if not TestStillActive() then return end
                if forceBlitzCycle and uncapDuration then
                    StartUncapForPin(pin, index, nextFaction, 0)
                else
                    StartLoopForPin(pin, index, OppositeFaction(nextFaction), 0)
                end
            end)
        end
    end

    for index, pin in ipairs(targets) do
        local info = pin.previewObjectiveInfo or {}
        local baseFaction = (index % 2 == 1) and faction or OppositeFaction(faction)
        local progress = progressPattern[((index - 1) % #progressPattern) + 1]
        if forceBlitzCycle and uncapDuration and index % 3 == 0 then
            StartUncapForPin(pin, index, baseFaction, uncapDuration * progress)
        else
            StartLoopForPin(pin, index, baseFaction, duration * progress)
        end
        startedCount = startedCount + 1
        objectiveNames[#objectiveNames + 1] = tostring(info.name or ("Objective " .. index))
    end

    if startedCount == 0 then
        return false, "The capture timers could not be started for the visible objectives."
    end

    return true, tostring(startedCount) .. " bases: " .. table.concat(objectiveNames, ", ")
end


-- Seething Shore Azerite spawn countdowns --------------------------------

local SEETHING_AZERITE_REFRESH_INTERVAL = 0.20

local function IsSeethingShoreMapID(mapID)
    if Rules.IsSeethingShoreMap then
        local ok, result = pcall(Rules.IsSeethingShoreMap, mapID)
        if ok then return result == true end
    end
    mapID = tonumber(mapID)
    return mapID == 907 or mapID == 1803
end

local function EnsureSeethingAzeriteVisuals(pin)
    if not pin then return nil end

    if not pin.BattleMapsSeethingAzeriteBaseTexture then
        local base = pin:CreateTexture(nil, "OVERLAY", nil, 4)
        base:SetBlendMode("BLEND")
        base:SetAlpha(1)
        base:Hide()
        pin.BattleMapsSeethingAzeriteBaseTexture = base

        local fill = pin:CreateTexture(nil, "OVERLAY", nil, 5)
        fill:SetBlendMode("BLEND")
        fill:SetAlpha(1)
        fill:Hide()
        pin.BattleMapsSeethingAzeriteFillTexture = fill

        local flash = pin:CreateTexture(nil, "OVERLAY", nil, 7)
        flash:SetBlendMode("ADD")
        flash:SetAlpha(0)
        flash:Hide()
        pin.BattleMapsSeethingAzeriteFlashTexture = flash
    end

    if not pin.BattleMapsSeethingAzeriteTimerText then
        local text = pin:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER", pin.texture or pin, "CENTER", 0, 0)
        text:SetJustifyH("CENTER")
        text:SetJustifyV("MIDDLE")
        text:SetShadowColor(0, 0, 0, 1)
        text:SetShadowOffset(1, -1)
        text:Hide()
        pin.BattleMapsSeethingAzeriteTimerText = text
    end
    return pin
end

local function AnchorSeethingAzeriteTexture(pin, texture, source, width, height)
    if not pin or not texture then return end
    local point, relativeTo, relativePoint, offsetX, offsetY = source and source:GetPoint(1)
    texture:ClearAllPoints()
    if point then
        texture:SetPoint(point, relativeTo or pin, relativePoint or point, offsetX or 0, offsetY or 0)
    else
        texture:SetPoint("CENTER", pin, "CENTER", 0, 0)
    end
    texture:SetSize(width, height)
end

local function LayoutSeethingAzeriteFill(pin, direction)
    local fill = pin and pin.BattleMapsSeethingAzeriteFillTexture
    local base = pin and pin.BattleMapsSeethingAzeriteBaseTexture
    if not fill or not base then return false end

    direction = direction == "vertical" and "vertical" or "horizontal"
    local width = tonumber(pin.BattleMapsSeethingAzeriteFullWidth) or 16
    local height = tonumber(pin.BattleMapsSeethingAzeriteFullHeight) or width
    fill:ClearAllPoints()
    if direction == "vertical" then
        -- Match the base-assault reveal direction: completed artwork grows from
        -- the bottom edge toward the top edge.
        fill:SetPoint("BOTTOM", base, "BOTTOM", 0, 0)
        fill:SetWidth(width)
    else
        -- Completed artwork grows from left to right.
        fill:SetPoint("LEFT", base, "LEFT", 0, 0)
        fill:SetHeight(height)
    end
    pin.BattleMapsSeethingAzeriteFillDirection = direction
    return true
end

local function SyncSeethingAzeriteVisuals(pin, mapID, activeTexturePath, spawningTexturePath)
    if not pin or not pin.texture then return false end
    EnsureSeethingAzeriteVisuals(pin)

    local source = pin.texture
    local base = pin.BattleMapsSeethingAzeriteBaseTexture
    local fill = pin.BattleMapsSeethingAzeriteFillTexture
    local flash = pin.BattleMapsSeethingAzeriteFlashTexture
    local width, height = source:GetSize()
    width = tonumber(width) or 16
    height = tonumber(height) or width

    AnchorSeethingAzeriteTexture(pin, base, source, width, height)
    AnchorSeethingAzeriteTexture(pin, fill, source, width, height)
    AnchorSeethingAzeriteTexture(pin, flash, source, width, height)

    -- The spawning artwork is the stable bottom layer.  The completed Azerite
    -- artwork is revealed over it as the timer advances.  This ordering is
    -- deliberate: a partially transparent spawning texture must never expose
    -- the fully completed texture across the whole pin before the countdown has
    -- actually progressed.
    if not CopyObjectiveTextureAppearance(base, source, spawningTexturePath, false) then
        return false
    end
    if not CopyObjectiveTextureAppearance(fill, source, activeTexturePath, false) then
        return false
    end
    if not CopyObjectiveTextureAppearance(flash, source, activeTexturePath, false) then
        return false
    end

    base:SetBlendMode("BLEND")
    base:SetVertexColor(1, 1, 1, 1)
    base:SetAlpha(1)
    fill:SetBlendMode("BLEND")
    fill:SetVertexColor(1, 1, 1, 1)
    fill:SetAlpha(1)
    flash:SetBlendMode("ADD")
    flash:SetVertexColor(1, 1, 1, 1)
    flash:SetAlpha(0)
    flash:Hide()

    pin.BattleMapsSeethingAzeriteFullWidth = width
    pin.BattleMapsSeethingAzeriteFullHeight = height
    pin.BattleMapsSeethingAzeriteFillTexCoords = { fill:GetTexCoord() }
    pin.BattleMapsSeethingAzeriteActiveTexturePath = activeTexturePath
    pin.BattleMapsSeethingAzeriteSpawningTexturePath = spawningTexturePath

    local settings = GetTimerSettings(mapID)
    local direction = settings and settings.objectiveCaptureFillDirection == "vertical"
        and "vertical" or "horizontal"
    LayoutSeethingAzeriteFill(pin, direction)
    return true
end

local function SetSeethingAzeriteProgress(pin, progress, direction)
    local fill = pin and pin.BattleMapsSeethingAzeriteFillTexture
    if not fill then return false end

    local width = tonumber(pin.BattleMapsSeethingAzeriteFullWidth) or 16
    local height = tonumber(pin.BattleMapsSeethingAzeriteFullHeight) or width
    progress = BattleMaps.Clamp(tonumber(progress) or 0, 0, 1)
    direction = direction == "vertical" and "vertical" or "horizontal"
    if pin.BattleMapsSeethingAzeriteFillDirection ~= direction then
        LayoutSeethingAzeriteFill(pin, direction)
    end

    -- Preserve the same transparent-edge compensation used by the ordinary
    -- base-assault fill, but grow the completed layer rather than shrinking the
    -- spawning layer.  At timer start only the first inset is visible; at timer
    -- completion the completed texture reaches the opposite inset.
    local edgeInset = BattleMaps.Clamp(
        tonumber(OBJECTIVE_CAPTURE_PROGRESS_EDGE_INSET) or 0.10,
        0,
        0.49
    )
    local visibleProgress = edgeInset + (progress * (1 - (edgeInset * 2)))
    local coords = pin.BattleMapsSeethingAzeriteFillTexCoords or { 0, 1, 0, 1 }

    if direction == "vertical" then
        fill:SetSize(width, math.max(height * visibleProgress, 0.01))
        if #coords >= 8 then
            local ulx, uly = coords[1], coords[2]
            local llx, lly = coords[3], coords[4]
            local urx, ury = coords[5], coords[6]
            local lrx, lry = coords[7], coords[8]
            fill:SetTexCoord(
                llx + ((ulx - llx) * visibleProgress),
                lly + ((uly - lly) * visibleProgress),
                llx, lly,
                lrx + ((urx - lrx) * visibleProgress),
                lry + ((ury - lry) * visibleProgress),
                lrx, lry
            )
        else
            local left = tonumber(coords[1]) or 0
            local right = tonumber(coords[2]) or 1
            local top = tonumber(coords[3]) or 0
            local bottom = tonumber(coords[4]) or 1
            fill:SetTexCoord(left, right, bottom - ((bottom - top) * visibleProgress), bottom)
        end
    else
        fill:SetSize(math.max(width * visibleProgress, 0.01), height)
        if #coords >= 8 then
            local ulx, uly = coords[1], coords[2]
            local llx, lly = coords[3], coords[4]
            local urx, ury = coords[5], coords[6]
            local lrx, lry = coords[7], coords[8]
            fill:SetTexCoord(
                ulx, uly,
                llx, lly,
                ulx + ((urx - ulx) * visibleProgress),
                uly + ((ury - uly) * visibleProgress),
                llx + ((lrx - llx) * visibleProgress),
                lly + ((lry - lly) * visibleProgress)
            )
        else
            local left = tonumber(coords[1]) or 0
            local right = tonumber(coords[2]) or 1
            local top = tonumber(coords[3]) or 0
            local bottom = tonumber(coords[4]) or 1
            fill:SetTexCoord(left, left + ((right - left) * visibleProgress), top, bottom)
        end
    end
    fill:Show()
    return true
end

local function FormatSeethingAzeriteSeconds(secondsLeft)
    local seconds = math.max(math.ceil((tonumber(secondsLeft) or 0) - 0.001), 0)
    if seconds >= 60 then
        return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
    end
    return tostring(seconds)
end

local function ApplySeethingAzeriteTextStyle(pin, mapID)
    local text = pin and pin.BattleMapsSeethingAzeriteTimerText
    if not text then return false end
    local settings = GetTimerSettings(mapID)
    if not settings then return false end

    local fontKey = tostring(settings.objectiveTimerTextFont or "friz")
    local fontPath = BattleMaps.GetObjectiveTimerFontPath
        and BattleMaps.GetObjectiveTimerFontPath(fontKey)
        or (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
    if type(fontPath) ~= "string" or fontPath == "" then
        fontPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    end

    local source = pin.texture or pin
    local width, height = source.GetSize and source:GetSize()
    width = tonumber(width) or 24
    height = tonumber(height) or width
    local textureScale = BattleMaps.Clamp(math.max(math.min(width, height), 1) / 24, 0.50, 4.00)
    local baseSize = BattleMaps.Clamp(
        math.floor((tonumber(settings.objectiveTimerTextSize) or 14) + 0.5),
        8,
        32
    )
    local fontSize = BattleMaps.Clamp(math.floor((baseSize * textureScale) + 0.5), 6, 72)
    local offsetX = BattleMaps.Clamp(tonumber(settings.objectiveTimerTextOffsetX) or 0, -32, 32)
    local offsetY = BattleMaps.Clamp(tonumber(settings.objectiveTimerTextOffsetY) or 0, -32, 32)
    local scaledOffsetX = math.floor((offsetX * textureScale) + (offsetX >= 0 and 0.5 or -0.5))
    local scaledOffsetY = math.floor((offsetY * textureScale) + (offsetY >= 0 and 0.5 or -0.5))
    local color = type(settings.objectiveTimerTextColor) == "table"
        and settings.objectiveTimerTextColor or {}
    local r = BattleMaps.Clamp(tonumber(color.r or color[1]) or 1, 0, 1)
    local g = BattleMaps.Clamp(tonumber(color.g or color[2]) or 1, 0, 1)
    local b = BattleMaps.Clamp(tonumber(color.b or color[3]) or 1, 0, 1)
    local alpha = BattleMaps.Clamp(tonumber(settings.objectiveTimerTextAlpha) or 1, 0, 1)
    local styleKey = table.concat({
        fontKey, fontPath, tostring(fontSize),
        tostring(r), tostring(g), tostring(b), tostring(alpha),
        tostring(scaledOffsetX), tostring(scaledOffsetY),
        string.format("%.2f", width), string.format("%.2f", height),
    }, ":")

    if pin.BattleMapsSeethingAzeriteTextStyleKey ~= styleKey then
        local ok, result = pcall(text.SetFont, text, fontPath, fontSize, "OUTLINE")
        if not ok or result == false then
            local fallback = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
            ok, result = pcall(text.SetFont, text, fallback, fontSize, "OUTLINE")
        end
        if not ok or result == false then return false end

        text:ClearAllPoints()
        text:SetPoint("CENTER", source, "CENTER", scaledOffsetX, scaledOffsetY)
        text:SetTextColor(r, g, b, alpha)
        text:SetShadowColor(0, 0, 0, 1)
        local shadow = math.max(math.floor(textureScale + 0.5), 1)
        text:SetShadowOffset(shadow, -shadow)
        pin.BattleMapsSeethingAzeriteTextStyleKey = styleKey
    end
    return true
end

function Pins:ClearSeethingShoreAzeriteTimer(pin)
    if not pin then return end
    for _, texture in ipairs({
        pin.BattleMapsSeethingAzeriteBaseTexture,
        pin.BattleMapsSeethingAzeriteFillTexture,
        pin.BattleMapsSeethingAzeriteFlashTexture,
    }) do
        if texture then
            texture:SetAlpha(texture == pin.BattleMapsSeethingAzeriteFlashTexture and 0 or 1)
            texture:Hide()
        end
    end
    local text = pin.BattleMapsSeethingAzeriteTimerText
    if text then
        text:Hide()
        text:SetText("")
    end
    if pin.texture then pin.texture:SetAlpha(1) end
    pin.BattleMapsSeethingAzeriteFullWidth = nil
    pin.BattleMapsSeethingAzeriteFullHeight = nil
    pin.BattleMapsSeethingAzeriteFillTexCoords = nil
    pin.BattleMapsSeethingAzeriteFillDirection = nil
    pin.BattleMapsSeethingAzeriteActiveTexturePath = nil
    pin.BattleMapsSeethingAzeriteSpawningTexturePath = nil
end

function Pins:UpdateSeethingShoreAzeriteTimer(pin, record, activeTexturePath, spawningTexturePath)
    if not pin or type(record) ~= "table" then return false end
    if record.state ~= "spawning" or not tonumber(record.secondsLeft) then
        self:ClearSeethingShoreAzeriteTimer(pin)
        return false
    end

    local mapID = tonumber(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local settings = GetTimerSettings(mapID)
    local now = type(GetTime) == "function" and GetTime() or 0
    local expiresAt = tonumber(record.expiresAt) or (now + tonumber(record.secondsLeft))
    local remaining = math.max(expiresAt - now, 0)
    local duration = math.max(tonumber(record.duration) or remaining, remaining, 1)
    local progress = BattleMaps.Clamp((duration - remaining) / duration, 0, 1)
    local direction = settings and settings.objectiveCaptureFillDirection == "vertical"
        and "vertical" or "horizontal"

    EnsureSeethingAzeriteVisuals(pin)
    local visualsEnabled = not settings or settings.showObjectiveCaptureTimers ~= false
    if visualsEnabled
        and SyncSeethingAzeriteVisuals(pin, mapID, activeTexturePath, spawningTexturePath) then
        if pin.texture then pin.texture:SetAlpha(0) end
        pin.BattleMapsSeethingAzeriteBaseTexture:Show()
        SetSeethingAzeriteProgress(pin, progress, direction)

        local fill = pin.BattleMapsSeethingAzeriteFillTexture
        if settings and settings.pulseObjectiveDuringCaptureTimer ~= false then
            local minimumAlpha = BattleMaps.Clamp(
                tonumber(settings.objectiveCapturePulseMinAlpha) or 0.40,
                0,
                1
            )
            local maximumAlpha = BattleMaps.Clamp(
                tonumber(settings.objectiveCapturePulseMaxAlpha) or 0.60,
                0,
                1
            )
            if minimumAlpha > maximumAlpha then
                minimumAlpha, maximumAlpha = maximumAlpha, minimumAlpha
            end
            local phase = ((now / 0.80) * math.pi * 2)
            local wave = (math.sin(phase) + 1) * 0.5
            fill:SetAlpha(minimumAlpha + ((maximumAlpha - minimumAlpha) * wave))
        else
            fill:SetAlpha(1)
        end

        local flash = pin.BattleMapsSeethingAzeriteFlashTexture
        local threshold = BattleMaps.Clamp(
            tonumber(settings and settings.objectiveCaptureFlashThreshold) or 9,
            1,
            59
        )
        if settings and settings.flashObjectiveBeforeCapture == true
            and remaining > 0 and remaining <= threshold then
            local brightness = BattleMaps.Clamp(
                tonumber(settings.objectiveCaptureFlashBrightness) or 0.25,
                0.10,
                1
            )
            local phase = ((now / 0.70) * math.pi * 2)
            local wave = (math.sin(phase) + 1) * 0.5
            flash:SetAlpha(brightness * wave * wave)
            flash:Show()
        else
            flash:SetAlpha(0)
            flash:Hide()
        end
    else
        if pin.texture then pin.texture:SetAlpha(1) end
        if pin.BattleMapsSeethingAzeriteBaseTexture then pin.BattleMapsSeethingAzeriteBaseTexture:Hide() end
        if pin.BattleMapsSeethingAzeriteFillTexture then pin.BattleMapsSeethingAzeriteFillTexture:Hide() end
        if pin.BattleMapsSeethingAzeriteFlashTexture then pin.BattleMapsSeethingAzeriteFlashTexture:Hide() end
    end

    local text = pin.BattleMapsSeethingAzeriteTimerText
    local threshold = BattleMaps.Clamp(
        math.floor((tonumber(settings and settings.objectiveTimerTextThreshold) or 9) + 0.5),
        1,
        59
    )
    if settings and settings.showObjectiveTimerText ~= false
        and remaining > 0 and remaining <= threshold
        and ApplySeethingAzeriteTextStyle(pin, mapID) then
        local display = FormatSeethingAzeriteSeconds(remaining)
        text:SetText(display)
        text:Show()
    elseif text then
        text:Hide()
    end

    local display = FormatSeethingAzeriteSeconds(remaining)
    if self.SetTooltip then
        self:SetTooltip(pin, "Azerite spawning", "Available in " .. display)
    end
    return true
end

local SEETHING_AZERITE_TEST_PROFILES = {
    -- Two independent cycles make it possible to inspect different progress,
    -- countdown, pulse, and completion states at the same time.
    [1] = { spawnDuration = 18, activeDuration = 5, cappedDuration = 4 },
    [2] = { spawnDuration = 29, activeDuration = 6, cappedDuration = 5 },
}

local function BuildSeethingAzeriteTestRecord(profile, index, startedAt, now)
    profile = profile or SEETHING_AZERITE_TEST_PROFILES[1]
    startedAt = tonumber(startedAt) or now
    now = tonumber(now) or startedAt

    local spawnDuration = math.max(tonumber(profile.spawnDuration) or 18, 1)
    local activeDuration = math.max(tonumber(profile.activeDuration) or 5, 0.25)
    local cappedDuration = math.max(tonumber(profile.cappedDuration) or 4, 0.25)
    local cycleDuration = spawnDuration + activeDuration + cappedDuration
    local elapsed = (now - startedAt) % cycleDuration
    local record = {
        areaPoiID = "BattleMapsTestAzerite" .. tostring(index),
        name = "Azerite " .. tostring(index),
        description = "Synthetic Seething Shore spawn preview.",
        testPreview = true,
    }

    if elapsed < spawnDuration then
        local remaining = spawnDuration - elapsed
        record.state = "spawning"
        record.timed = true
        record.secondsLeft = remaining
        record.duration = spawnDuration
        record.startedAt = now - elapsed
        record.expiresAt = now + remaining
    elseif elapsed < (spawnDuration + activeDuration) then
        record.state = "active"
        record.description = "Available; the test preview will simulate collection shortly."
    else
        record.state = "dormant"
        record.description = "Collected; waiting for the next synthetic spawn cycle."
    end
    return record
end

function Pins:StopSeethingShoreAzeriteTestPreview()
    self.seethingAzeriteTestStartedAt = nil
    self.seethingAzeriteTestMapID = nil
    for _, pin in ipairs(self.dummyStationaryPins or {}) do
        if pin and pin.BattleMapsSeethingAzeriteTestIndex then
            pin.BattleMapsSeethingAzeriteTestIndex = nil
            pin.BattleMapsSeethingAzerite = nil
            pin.BattleMapsSeethingAzeritePOIID = nil
            pin.BattleMapsSeethingAzeriteState = nil
            pin.BattleMapsSeethingAzeriteSecondsLeft = nil
            pin.BattleMapsHiddenForDormantAzerite = nil
            self:ClearSeethingShoreAzeriteTimer(pin)
        end
    end
end

function Pins:RefreshSeethingShoreAzeriteTestPreview(mapID)
    local mapFrame = BattleMaps.MapFrame
    mapID = tonumber(mapID) or tonumber(mapFrame and mapFrame.currentMapID)
    if not mapFrame or mapFrame.testMode ~= true
        or not IsSeethingShoreMapID(mapID)
        or BattleMaps.IsInLiveBattleground()
        or type(self.ApplySeethingShoreAzeriteRecord) ~= "function" then
        self:StopSeethingShoreAzeriteTestPreview()
        return false
    end

    local now = type(GetTime) == "function" and GetTime() or 0
    if tonumber(self.seethingAzeriteTestMapID) ~= mapID
        or not tonumber(self.seethingAzeriteTestStartedAt) then
        self.seethingAzeriteTestMapID = mapID
        self.seethingAzeriteTestStartedAt = now
    end

    local used = 0
    for index, profile in ipairs(SEETHING_AZERITE_TEST_PROFILES) do
        local pin = self.dummyStationaryPins and self.dummyStationaryPins[index]
        if pin then
            pin.BattleMapsSeethingAzeriteTestIndex = index
            local record = BuildSeethingAzeriteTestRecord(
                profile,
                index,
                self.seethingAzeriteTestStartedAt,
                now
            )
            self:ApplySeethingShoreAzeriteRecord(pin, mapID, record)
            used = used + 1
        end
    end
    return used > 0
end

function Pins:EnsureSeethingShoreAzeriteController()
    if self.seethingAzeriteController then return self.seethingAzeriteController end

    local controller = CreateFrame("Frame")
    controller:Hide()
    controller.elapsed = 0
    controller:SetScript("OnUpdate", function(frame, elapsed)
        frame.elapsed = (frame.elapsed or 0) + (tonumber(elapsed) or 0)
        if frame.elapsed < SEETHING_AZERITE_REFRESH_INTERVAL then return end
        frame.elapsed = 0

        local mapFrame = BattleMaps.MapFrame
        local mapID = tonumber(mapFrame and mapFrame.currentMapID)
        if not mapFrame or not mapFrame.frame or not mapFrame.frame:IsShown()
            or not IsSeethingShoreMapID(mapID) then
            frame:Hide()
            self:StopSeethingShoreAzeriteTestPreview()
            if type(self.ClearSeethingShoreAzeriteState) == "function" then
                self:ClearSeethingShoreAzeriteState()
            end
            return
        end

        if mapFrame.testMode == true and not BattleMaps.IsInLiveBattleground() then
            self:RefreshSeethingShoreAzeriteTestPreview(mapID)
            return
        end

        self:StopSeethingShoreAzeriteTestPreview()
        if type(self.RefreshSeethingShoreAzeriteState) ~= "function" then
            frame:Hide()
            return
        end
        self:RefreshSeethingShoreAzeriteState(mapID)
    end)
    self.seethingAzeriteController = controller
    return controller
end

-- Compatibility aliases for development builds that referenced the original
-- Arathi-specific method names.
Pins.StartArathiBasinObjectiveCaptureTimer = Pins.StartObjectiveCaptureTimer
Pins.StopArathiBasinObjectiveCaptureTimer = Pins.StopObjectiveCaptureTimer
function Pins:StartArathiBasinCaptureTimerTest(faction)
    return self:StartCaptureTimerTest(112, faction)
end
