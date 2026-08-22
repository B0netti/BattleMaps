local _, BattleMaps = ...

-- BattleMaps ElvUI integration contract:
-- - This file is optional/inert unless ElvUI is loaded.
-- - It changes only a small whitelist of ElvUI/layout values while a supported
--   BattleMaps BG layout is active.
-- - It saves original frame anchors before changing them and restores only the
--   frames BattleMaps moved. Core battleground logic must not depend on this file.
-- - This pass deliberately does not edit ElvUI chat-panel settings; right-chat
--   layout work is deferred to a later, more explicit design.

local AURA_TARGETS = {
    buffs = {
        -- Current ElvUI names these public mover frames without the parent
        -- frame prefix. Keep the older guessed names as fallbacks for forks.
        moverNames = { "BuffsMover", "ElvUIPlayerBuffsMover" },
    },
    debuffs = {
        moverNames = { "DebuffsMover", "ElvUIPlayerDebuffsMover" },
    },
}

local function GetDB()
    return BattleMaps.Database and BattleMaps.Database.Get and BattleMaps.Database:Get() or nil
end

local function GetElvUI()
    local elvui = _G.ElvUI
    if type(elvui) ~= "table" then return nil end

    -- Normal ElvUI add-ons expose a table unpacked as E, L, V, P, G.
    local E = type(elvui[1]) == "table" and elvui[1] or nil
    if E and type(E.db) == "table" then return E end

    -- Very defensive fallback for test/stub environments.
    if type(elvui.db) == "table" then return elvui end
    return nil
end

function BattleMaps.IsElvUIAvailable()
    return GetElvUI() ~= nil
end

local function GetElvUIProfileKey(E)
    if not E then return "unknown" end
    if type(E.data) == "table" and type(E.data.GetCurrentProfile) == "function" then
        local ok, profile = pcall(E.data.GetCurrentProfile, E.data)
        if ok and profile then return tostring(profile) end
    end
    if E.db and E.db.name then return tostring(E.db.name) end
    return "default"
end

local function GetFrameByNameList(names)
    for _, name in ipairs(names or {}) do
        local frame = _G[name]
        if BattleMaps.IsFrame and BattleMaps.IsFrame(frame) then
            return frame, name
        end
    end
    return nil, nil
end

local function GetFrameName(frame)
    if BattleMaps.IsFrame and BattleMaps.IsFrame(frame) and type(frame.GetName) == "function" then
        local ok, name = pcall(frame.GetName, frame)
        if ok and name then return tostring(name) end
    end
    return nil
end

local function ResolveRelativeFrame(name)
    if not name or name == "" then return nil end
    return _G[name] or nil
end

local function IsSecretValue(value)
    if type(issecretvalue) ~= "function" then return false end

    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == true
end

local function SafePublicNumber(value)
    if IsSecretValue(value) then return nil end

    local ok, numberValue = pcall(tonumber, value)
    if not ok then return nil end
    return numberValue
end

local function CaptureFramePoints(frame)
    local points = {}
    if not (BattleMaps.IsFrame and BattleMaps.IsFrame(frame)) then return points end
    if type(frame.GetNumPoints) ~= "function" or type(frame.GetPoint) ~= "function" then return points end

    local count = 0
    local okCount, numPoints = pcall(frame.GetNumPoints, frame)
    if okCount then count = SafePublicNumber(numPoints) or 0 end

    for index = 1, count do
        local ok, point, relativeTo, relativePoint, xOfs, yOfs = pcall(frame.GetPoint, frame, index)
        local x = SafePublicNumber(xOfs)
        local y = SafePublicNumber(yOfs)
        if ok
            and not IsSecretValue(point)
            and not IsSecretValue(relativeTo)
            and not IsSecretValue(relativePoint)
            and point
            and x ~= nil
            and y ~= nil then
            points[#points + 1] = {
                point = point,
                relativeName = GetFrameName(relativeTo),
                relativePoint = relativePoint,
                x = x,
                y = y,
            }
        end
    end

    return points
end

local function SaveFrameState(state, key, frame)
    if not (state and key and BattleMaps.IsFrame and BattleMaps.IsFrame(frame)) then return nil end
    state.auras = type(state.auras) == "table" and state.auras or {}
    state.auras.frames = type(state.auras.frames) == "table" and state.auras.frames or {}

    local frameState = state.auras.frames[key]
    if type(frameState) ~= "table" then
        frameState = {
            frameName = GetFrameName(frame),
            points = CaptureFramePoints(frame),
        }
        state.auras.frames[key] = frameState
    end
    return frameState
end

local function SetFramePoint(state, key, frame, point, relativeFrame, relativePoint, x, y)
    if not (BattleMaps.IsFrame and BattleMaps.IsFrame(frame)) then return false end
    if type(frame.ClearAllPoints) ~= "function" or type(frame.SetPoint) ~= "function" then return false end

    local frameState = SaveFrameState(state, key, frame)
    if not frameState then return false end

    point = point or "TOPRIGHT"
    relativePoint = relativePoint or point
    x = tonumber(x) or 0
    y = tonumber(y) or 0

    local okClear = pcall(frame.ClearAllPoints, frame)
    if not okClear then return false end

    local okSet = pcall(frame.SetPoint, frame, point, relativeFrame, relativePoint, x, y)
    if okSet then
        frameState.applied = {
            point = point,
            relativeName = GetFrameName(relativeFrame),
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
        return true
    end

    return false
end

local function RestoreFrameState(frameState)
    if type(frameState) ~= "table" or not frameState.frameName then return false end
    local frame = _G[frameState.frameName]
    if not (BattleMaps.IsFrame and BattleMaps.IsFrame(frame)) then return false end
    if type(frame.ClearAllPoints) ~= "function" or type(frame.SetPoint) ~= "function" then return false end

    local okClear = pcall(frame.ClearAllPoints, frame)
    if not okClear then return false end

    local restored = false
    for _, p in ipairs(frameState.points or {}) do
        local relativeFrame = ResolveRelativeFrame(p.relativeName) or UIParent
        local okSet = pcall(frame.SetPoint, frame, p.point, relativeFrame, p.relativePoint or p.point, tonumber(p.x) or 0, tonumber(p.y) or 0)
        restored = okSet or restored
    end

    if not restored then
        -- Defensive fallback: leave the frame somewhere visible rather than
        -- point-less if the original relative frame no longer exists.
        pcall(frame.SetPoint, frame, "TOPRIGHT", UIParent, "TOPRIGHT", -40, -40)
        restored = true
    end

    return restored
end

local function GetMinimapAnchorFrame()
    if BattleMaps.IsFrame and BattleMaps.IsFrame(_G.Minimap) then return _G.Minimap end
    if BattleMaps.IsFrame and BattleMaps.IsFrame(_G.MinimapCluster) then return _G.MinimapCluster end
    return UIParent
end

local function RestorePlayerAuras(state)
    if type(state) ~= "table" then return false end
    local auras = type(state.auras) == "table" and state.auras or nil
    if not auras or type(auras.frames) ~= "table" then
        state.auras = nil
        return false
    end

    local changed = false
    -- ElvUI's Retail aura containers can expose secret anchor data in PvP. Its
    -- movers are public and own the containers' placement, so restore only them.
    for _, key in ipairs({ "buffsMover", "debuffsMover" }) do
        changed = RestoreFrameState(auras.frames[key]) or changed
    end

    state.auras = nil
    return changed
end

local function ApplyPlayerAuras(state)
    if type(state) ~= "table" then return false end

    local anchor = GetMinimapAnchorFrame()
    local buffsMover = GetFrameByNameList(AURA_TARGETS.buffs.moverNames)
    local debuffsMover = GetFrameByNameList(AURA_TARGETS.debuffs.moverNames)

    local changed = false

    -- Retail treats the AuraContainer's points as secret while in PvP. ElvUI
    -- already anchors each container to its mover, so move only the public
    -- movers and preserve their public anchors for restoration.
    if buffsMover then
        changed = SetFramePoint(state, "buffsMover", buffsMover, "TOPRIGHT", anchor, "TOPRIGHT", 0, 0) or changed
    end

    local debuffAnchor = buffsMover or anchor
    if debuffsMover then
        changed = SetFramePoint(state, "debuffsMover", debuffsMover, "TOPRIGHT", debuffAnchor, "BOTTOMRIGHT", 0, -8) or changed
    end

    return changed
end

function BattleMaps.ShouldApplyElvUIBGLayoutNow()
    local db = GetDB()
    if not db or db.elvuiBGLayoutEnabled ~= true then return false end
    if not GetElvUI() then return false end

    local mapFrame = BattleMaps.MapFrame
    if mapFrame and mapFrame.testMode == true then
        local testMapID = tonumber(mapFrame.currentMapID)
            or tonumber(mapFrame.selectedMapID)
            or (BattleMaps.Options and tonumber(BattleMaps.Options.selectedMapID))
        return BattleMaps.IsNonEpicBattlegroundMapID
            and BattleMaps.IsNonEpicBattlegroundMapID(testMapID) == true
    end

    if not (BattleMaps.IsInLiveBattleground and BattleMaps.IsInLiveBattleground()) then
        return false
    end

    local epicState = BattleMaps.GetCurrentBattlegroundEpicState
        and BattleMaps.GetCurrentBattlegroundEpicState()
    return epicState == false
end

function BattleMaps.RestoreElvUIBGLayout()
    local db = GetDB()
    if not db then return false end

    local state = type(db.elvuiBGLayoutState) == "table" and db.elvuiBGLayoutState or nil
    if not state or state.active ~= true then
        db.elvuiBGLayoutState = nil
        BattleMaps.elvuiBGLayoutActive = false
        return true
    end

    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        BattleMaps.pendingElvUIBGLayoutRefresh = true
        return false
    end

    RestorePlayerAuras(state)

    db.elvuiBGLayoutState = nil
    BattleMaps.elvuiBGLayoutActive = false
    return true
end

function BattleMaps.ApplyElvUIBGLayout()
    local db = GetDB()
    if not db then return false end

    if not BattleMaps.ShouldApplyElvUIBGLayoutNow() then
        return BattleMaps.RestoreElvUIBGLayout()
    end

    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        BattleMaps.pendingElvUIBGLayoutRefresh = true
        return false
    end

    local E = GetElvUI()
    if not E then
        return BattleMaps.RestoreElvUIBGLayout()
    end

    local state = type(db.elvuiBGLayoutState) == "table" and db.elvuiBGLayoutState or {}
    db.elvuiBGLayoutState = state
    state.active = true
    state.profileKey = GetElvUIProfileKey(E)

    if db.elvuiBGLayoutMovePlayerAuras == true then
        ApplyPlayerAuras(state)
    else
        RestorePlayerAuras(state)
    end

    BattleMaps.elvuiBGLayoutActive = true
    return true
end

local PreviousApplyMinimapVisibility = BattleMaps.ApplyMinimapVisibility
if type(PreviousApplyMinimapVisibility) == "function" and not BattleMaps.ElvUIIntegrationWrappedMinimapApply then
    BattleMaps.ElvUIIntegrationWrappedMinimapApply = true
    function BattleMaps.ApplyMinimapVisibility(...)
        local result = PreviousApplyMinimapVisibility(...)
        if BattleMaps.ApplyElvUIBGLayout then
            BattleMaps.ApplyElvUIBGLayout()
        end
        return result
    end
end
