local _, BattleMaps = ...

-- Generic battleground HUD-layout integration.
--
-- The minimap visibility itself is owned by Core.lua. This module only moves
-- the player's existing aura frames into the space vacated by the minimap.
-- It supports the two UI providers BattleMaps can identify safely:
--   * ElvUI: move its public BuffsMover / DebuffsMover frames.
--   * Blizzard: move the public BuffFrame / DebuffFrame Edit Mode systems.
--
-- No aura containers are reparented and no provider settings are modified.
-- Original anchors are captured in memory and restored when the BG layout
-- deactivates, so SavedVariables never contain stale frame references.

local ELVUI_AURA_TARGETS = {
    buffs = { "BuffsMover", "ElvUIPlayerBuffsMover" },
    debuffs = { "DebuffsMover", "ElvUIPlayerDebuffsMover" },
}

local function IsFrame(frame)
    return BattleMaps.IsFrame and BattleMaps.IsFrame(frame)
end

local function GetDB()
    return BattleMaps.Database and BattleMaps.Database.Get and BattleMaps.Database:Get() or nil
end

local function GetElvUI()
    local elvui = _G.ElvUI
    if type(elvui) ~= "table" then return nil end

    local E = type(elvui[1]) == "table" and elvui[1] or nil
    if E and type(E.db) == "table" then return E end
    if type(elvui.db) == "table" then return elvui end
    return nil
end

function BattleMaps.IsElvUIAvailable()
    return GetElvUI() ~= nil
end

local function GetFrameByNameList(names)
    for _, name in ipairs(names or {}) do
        local frame = _G[name]
        if IsFrame(frame) then return frame end
    end
    return nil
end

local function IsSecretValue(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == true
end

local function SafeNumber(value)
    if IsSecretValue(value) then return nil end
    local ok, numberValue = pcall(tonumber, value)
    return ok and numberValue or nil
end

local function GetFrameTop(frame)
    if not IsFrame(frame) or type(frame.GetTop) ~= "function" then return nil end
    local ok, top = pcall(frame.GetTop, frame)
    return ok and SafeNumber(top) or nil
end

local function CaptureFramePoints(frame)
    local points = {}
    if not IsFrame(frame) or type(frame.GetNumPoints) ~= "function" or type(frame.GetPoint) ~= "function" then
        return points
    end

    local okCount, count = pcall(frame.GetNumPoints, frame)
    count = okCount and SafeNumber(count) or 0
    count = count or 0

    for index = 1, count do
        local ok, point, relativeTo, relativePoint, x, y = pcall(frame.GetPoint, frame, index)
        x, y = SafeNumber(x), SafeNumber(y)
        if ok
            and point
            and not IsSecretValue(point)
            and not IsSecretValue(relativeTo)
            and not IsSecretValue(relativePoint)
            and x ~= nil
            and y ~= nil then
            points[#points + 1] = {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                x = x,
                y = y,
            }
        end
    end

    return points
end

local function SaveFrameState(state, key, frame)
    if not state or not key or not IsFrame(frame) then return nil end
    state.frames = type(state.frames) == "table" and state.frames or {}

    local frameState = state.frames[key]
    if not frameState then
        frameState = {
            frame = frame,
            points = CaptureFramePoints(frame),
        }
        state.frames[key] = frameState
    end
    return frameState
end

local RestoreFrameState

local function SetFramePoint(state, key, frame, point, relativeFrame, relativePoint, x, y)
    if not IsFrame(frame)
        or not IsFrame(relativeFrame)
        or type(frame.ClearAllPoints) ~= "function"
        or type(frame.SetPoint) ~= "function" then
        return false
    end

    local frameState = SaveFrameState(state, key, frame)
    if not frameState then return false end

    -- Never move a provider frame unless its original anchors were captured.
    -- That guarantees BattleMaps can restore the exact pre-BG layout instead
    -- of guessing a fallback position for Blizzard or another UI provider.
    if type(frameState.points) ~= "table" or #frameState.points == 0 then
        state.frames[key] = nil
        return false
    end

    if not pcall(frame.ClearAllPoints, frame) then
        state.frames[key] = nil
        return false
    end

    local moved = pcall(frame.SetPoint, frame,
        point or "TOPRIGHT",
        relativeFrame,
        relativePoint or point or "TOPRIGHT",
        tonumber(x) or 0,
        tonumber(y) or 0)
    if moved then return true end

    -- If the provider rejects the temporary anchor, put the captured layout
    -- back immediately and forget this frame rather than leaving it point-less.
    RestoreFrameState(frameState)
    state.frames[key] = nil
    return false
end

RestoreFrameState = function(frameState)
    if type(frameState) ~= "table" or not IsFrame(frameState.frame) then return false end
    local frame = frameState.frame
    if type(frame.ClearAllPoints) ~= "function" or type(frame.SetPoint) ~= "function" then return false end

    if not pcall(frame.ClearAllPoints, frame) then return false end

    local restored = false
    for _, p in ipairs(frameState.points or {}) do
        local relativeTo = IsFrame(p.relativeTo) and p.relativeTo or UIParent
        local ok = pcall(frame.SetPoint, frame,
            p.point or "TOPRIGHT",
            relativeTo,
            p.relativePoint or p.point or "TOPRIGHT",
            tonumber(p.x) or 0,
            tonumber(p.y) or 0)
        restored = ok or restored
    end

    return restored
end

local function GetAuraProvider()
    if GetElvUI() then
        local buffsMover = GetFrameByNameList(ELVUI_AURA_TARGETS.buffs)
        local debuffsMover = GetFrameByNameList(ELVUI_AURA_TARGETS.debuffs)
        if buffsMover or debuffsMover then
            return "elvui", "ElvUI", buffsMover, debuffsMover
        end
    end

    local buffFrame = _G.BuffFrame
    local debuffFrame = _G.DebuffFrame
    if IsFrame(buffFrame) or IsFrame(debuffFrame) then
        return "blizzard", "Blizzard UI", buffFrame, debuffFrame
    end

    return nil, "Unavailable", nil, nil
end

function BattleMaps.GetPlayerAuraProviderName()
    local _, displayName = GetAuraProvider()
    return displayName
end

function BattleMaps.IsPlayerAuraLayoutAvailable()
    local provider = GetAuraProvider()
    return provider ~= nil
end

local function GetMinimapAnchorFrame()
    if IsFrame(_G.Minimap) then return _G.Minimap end
    if IsFrame(_G.MinimapCluster) then return _G.MinimapCluster end
    return UIParent
end

local function GetFrameRight(frame)
    if not IsFrame(frame) or type(frame.GetRight) ~= "function" then return nil end
    local ok, right = pcall(frame.GetRight, frame)
    return ok and SafeNumber(right) or nil
end

local function GetFrameEffectiveScale(frame)
    if not IsFrame(frame) or type(frame.GetEffectiveScale) ~= "function" then return nil end
    local ok, scale = pcall(frame.GetEffectiveScale, frame)
    scale = ok and SafeNumber(scale) or nil
    return scale and scale > 0 and scale or nil
end

local function MoveFrameHorizontallyToMinimap(state, key, frame, anchor)
    -- GetTop/GetRight are expressed in each region's own scaled coordinate
    -- system. ElvUI movers commonly have a different effective scale from the
    -- Blizzard minimap, so subtracting those values directly produces a large
    -- vertical error. Convert both edges to physical screen coordinates first,
    -- then convert the target point back into the aura mover's coordinate space.
    local frameTop = GetFrameTop(frame)
    local frameScale = GetFrameEffectiveScale(frame)
    local anchorRight = GetFrameRight(anchor)
    local anchorScale = GetFrameEffectiveScale(anchor)
    if frameTop == nil or frameScale == nil or anchorRight == nil or anchorScale == nil then
        return false
    end

    local physicalTop = frameTop * frameScale
    local physicalRight = anchorRight * anchorScale

    return SetFramePoint(state, key, frame,
        "TOPRIGHT", UIParent, "BOTTOMLEFT",
        physicalRight / frameScale,
        physicalTop / frameScale)
end

local function RestorePlayerAuras()
    local state = BattleMaps.battlegroundAuraLayoutState
    if type(state) ~= "table" then
        BattleMaps.battlegroundAuraLayoutActive = false
        return true
    end

    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        BattleMaps.pendingBattlegroundAuraLayoutRefresh = true
        return false
    end

    for _, frameState in pairs(state.frames or {}) do
        RestoreFrameState(frameState)
    end

    BattleMaps.battlegroundAuraLayoutState = nil
    BattleMaps.battlegroundAuraLayoutActive = false
    BattleMaps.battlegroundAuraLayoutProvider = nil
    return true
end

function BattleMaps.RestoreBattlegroundAuraLayout()
    return RestorePlayerAuras()
end

local function ShouldMovePlayerAurasNow()
    local db = GetDB()
    if not db or db.movePlayerAurasToMinimapArea ~= true then return false end
    if db.hideMinimapInNonEpicBattlegrounds ~= true then return false end
    if not (BattleMaps.ShouldHideMinimapNow and BattleMaps.ShouldHideMinimapNow()) then return false end
    if BattleMaps.minimapHiddenByBattleMaps ~= true then return false end
    return true
end

function BattleMaps.ApplyBattlegroundAuraLayout()
    BattleMaps.pendingBattlegroundAuraLayoutRefresh = nil

    if not ShouldMovePlayerAurasNow() then
        return RestorePlayerAuras()
    end

    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        BattleMaps.pendingBattlegroundAuraLayoutRefresh = true
        return false
    end

    local provider, displayName, buffs, debuffs = GetAuraProvider()
    if not provider then return RestorePlayerAuras() end

    local current = BattleMaps.battlegroundAuraLayoutState
    if current and current.provider ~= provider then
        RestorePlayerAuras()
        current = nil
    end

    local state = current or { provider = provider, frames = {} }
    BattleMaps.battlegroundAuraLayoutState = state

    local anchor = GetMinimapAnchorFrame()
    local changed = false

    -- Move each provider frame horizontally into the vacated minimap region
    -- while preserving its existing Y position. This keeps the user's normal
    -- Blizzard/ElvUI vertical aura layout unchanged and avoids the visible
    -- downward jump caused by anchoring directly to Minimap:TOPRIGHT.
    if buffs then
        changed = MoveFrameHorizontallyToMinimap(state, "buffs", buffs, anchor) or changed
    end

    if debuffs then
        changed = MoveFrameHorizontallyToMinimap(state, "debuffs", debuffs, anchor) or changed
    end

    BattleMaps.battlegroundAuraLayoutActive = changed and next(state.frames) ~= nil
    if BattleMaps.battlegroundAuraLayoutActive then
        BattleMaps.battlegroundAuraLayoutProvider = displayName
        return true
    end

    BattleMaps.battlegroundAuraLayoutState = nil
    BattleMaps.battlegroundAuraLayoutProvider = nil
    return false
end
