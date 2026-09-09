local _, BattleMaps = ...

-- BattleMaps 2.9.14 - generalized player-aura relocation.
--
-- One runtime path owns both Blizzard and ElvUI providers. The provider only
-- changes which frames are moved; activation, capture/restore, minimap-area
-- anchoring, combat deferral, and refresh behaviour are shared.
--
-- This intentionally anchors aura frames to the minimap area without
-- reparenting them. BattleMaps hides the minimap with alpha/mouse changes, so
-- reparenting the aura frames under Minimap/MinimapCluster would make them
-- inherit the hidden alpha and disappear.

local AuraLayout = {
    state = nil,
    pending = false,
    elapsed = 0,
    retryElapsed = 0,
    lastProvider = "Unavailable",
    lastShouldManage = false,
    lastMoved = false,
    lastFound = {},
    lastFailed = {},
}

BattleMaps.AuraLayout = AuraLayout

local PROVIDERS = {
    ElvUI = {
        buffs = {
            "ElvUIPlayerBuffsMover",
            "ElvUIPlayerBuffs",
        },
        debuffs = {
            "ElvUIPlayerDebuffsMover",
            "ElvUIPlayerDebuffs",
        },
    },
    Blizzard = {
        buffs = {
            "BuffFrame",
            "BuffFrameContainer",
            "PlayerBuffFrame",
        },
        debuffs = {
            "DebuffFrame",
            "DebuffFrameContainer",
            "PlayerDebuffFrame",
        },
    },
}

local function IsFrame(frame)
    if BattleMaps.IsFrame then
        local ok, result = pcall(BattleMaps.IsFrame, frame)
        if ok then return result == true end
    end
    return frame ~= nil and type(frame.GetPoint) == "function" and type(frame.SetPoint) == "function"
end

local function IsAddonLoaded(name)
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
        if ok then return loaded == true end
    end
    if type(IsAddOnLoaded) == "function" then
        local ok, loaded = pcall(IsAddOnLoaded, name)
        if ok then return loaded == true end
    end
    return false
end

local function IsElvUILoaded()
    return type(_G.ElvUI) == "table" or IsAddonLoaded("ElvUI")
end

local function FindNamedFrames(names)
    local frames, seen = {}, {}
    for _, name in ipairs(names or {}) do
        local frame = _G[name]
        if IsFrame(frame) and not seen[frame] then
            seen[frame] = true
            frames[#frames + 1] = {
                frame = frame,
                name = name,
            }
        end
    end
    return frames
end

local function FindFirstNamedFrame(names)
    for _, name in ipairs(names or {}) do
        local frame = _G[name]
        if IsFrame(frame) then
            return {
                frame = frame,
                name = name,
            }
        end
    end
    return nil
end

local function GetBlizzardLayoutTargets()
    -- Blizzard's native aura system is not structured like ElvUI's mover +
    -- visible-holder pair. Prefer one top-level aura root and let Blizzard keep
    -- control of the buttons/containers it lays out beneath that root.
    --
    -- On the modern native UI BuffFrame owns both helpful and harmful player
    -- aura placement. The later names are compatibility fallbacks only.
    local buffRoot = FindFirstNamedFrame({
        "BuffFrame",
        "BuffFrameContainer",
        "PlayerBuffFrame",
    })

    -- Only use a distinct debuff root when Blizzard actually exposes one and
    -- there is no unified BuffFrame root. Re-anchoring a child/internal debuff
    -- container alongside BuffFrame is what caused the 2.9.x native layout to
    -- spread into the wrong geometry.
    local debuffRoot
    if not (buffRoot and buffRoot.name == "BuffFrame") then
        debuffRoot = FindFirstNamedFrame({
            "DebuffFrame",
            "DebuffFrameContainer",
            "PlayerDebuffFrame",
        })
    end

    return buffRoot, debuffRoot
end

function AuraLayout:GetProvider()
    if IsElvUILoaded() then
        return "ElvUI"
    end

    local buffRoot, debuffRoot = GetBlizzardLayoutTargets()
    if buffRoot or debuffRoot then
        return "Blizzard"
    end
    return "Unavailable"
end

function BattleMaps.ResolveAuraLayoutProvider()
    return AuraLayout:GetProvider()
end
BattleMaps.GetAuraLayoutProvider = BattleMaps.ResolveAuraLayoutProvider
BattleMaps.GetPlayerAuraProvider = BattleMaps.ResolveAuraLayoutProvider
BattleMaps.GetBattlegroundAuraProvider = BattleMaps.ResolveAuraLayoutProvider
BattleMaps.GetPlayerAuraProviderName = BattleMaps.ResolveAuraLayoutProvider
function BattleMaps.IsPlayerAuraLayoutAvailable()
    return AuraLayout:GetProvider() ~= "Unavailable"
end

local function GetDB()
    return BattleMaps.Database and BattleMaps.Database.Get and BattleMaps.Database:Get() or nil
end

local function EnsureCanonicalAuraSetting(db)
    if type(db) ~= "table" then return false end

    -- One provider-agnostic setting owns this feature. The legacy ElvUI key
    -- is migration-only and is kept synchronized for downgrade compatibility.
    if db.bgLayoutMovePlayerAuras == nil then
        if db.movePlayerAurasToMinimapArea ~= nil then
            db.bgLayoutMovePlayerAuras = db.movePlayerAurasToMinimapArea == true
        elseif db.elvuiBGLayoutMovePlayerAuras ~= nil then
            db.bgLayoutMovePlayerAuras = db.elvuiBGLayoutMovePlayerAuras == true
        elseif db.movePlayerAurasIntoMinimap ~= nil then
            db.bgLayoutMovePlayerAuras = db.movePlayerAurasIntoMinimap == true
        elseif db.movePlayerAurasToMinimap ~= nil then
            db.bgLayoutMovePlayerAuras = db.movePlayerAurasToMinimap == true
        else
            db.bgLayoutMovePlayerAuras = false
        end
    end

    local enabled = db.bgLayoutMovePlayerAuras == true
    -- Synchronize legacy aliases in one direction only. The canonical value is
    -- authoritative after initialization so an old UI key cannot reset it on
    -- /reload.
    db.movePlayerAurasToMinimapArea = enabled
    db.elvuiBGLayoutMovePlayerAuras = enabled
    return enabled
end

local function MoveSettingEnabled(db)
    return EnsureCanonicalAuraSetting(db)
end

function BattleMaps.GetAuraLayoutEnabled()
    return MoveSettingEnabled(GetDB())
end

function BattleMaps.SetAuraLayoutEnabled(enabled)
    local db = GetDB()
    if type(db) ~= "table" then return false end
    enabled = enabled == true
    db.bgLayoutMovePlayerAuras = enabled
    db.movePlayerAurasToMinimapArea = enabled
    db.elvuiBGLayoutMovePlayerAuras = enabled
    AuraLayout:Apply()
    return true
end

local function IsSupportedTestMode()
    local mapFrame = BattleMaps.MapFrame
    if not mapFrame or mapFrame.testMode ~= true then return false end

    local mapID = tonumber(mapFrame.currentMapID)
        or tonumber(mapFrame.selectedMapID)
        or (BattleMaps.Options and tonumber(BattleMaps.Options.selectedMapID))

    if type(BattleMaps.IsNonEpicBattlegroundMapID) == "function" then
        local ok, supported = pcall(BattleMaps.IsNonEpicBattlegroundMapID, mapID)
        if ok then return supported == true end
    end

    -- Test Mode itself is an explicit user preview. If the map classifier is
    -- temporarily unavailable during options creation, allow the aura preview
    -- rather than silently doing nothing.
    return mapID ~= nil
end

local function ShouldManageNow()
    local db = GetDB()
    if not MoveSettingEnabled(db) then return false end

    -- Test Mode is an explicit preview of the BG HUD layout. Do not make aura
    -- relocation depend on the minimap's current hidden-state bookkeeping:
    -- when Test Mode is active for a supported map, preview the aura placement.
    if IsSupportedTestMode() then
        return true
    end

    -- Live mode follows the same non-epic BG/minimap-layout decision as the
    -- rest of BattleMaps.
    if type(BattleMaps.ShouldHideMinimapNow) == "function" then
        local ok, result = pcall(BattleMaps.ShouldHideMinimapNow)
        if ok then return result == true end
    end

    return BattleMaps.minimapHiddenByBattleMaps == true
end

local function RelativeName(frame)
    if not frame then return nil end
    if frame == UIParent then return "UIParent" end
    if type(frame.GetName) == "function" then
        local ok, name = pcall(frame.GetName, frame)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    return nil
end

local function ResolveRelative(name)
    if name == "UIParent" or not name then return UIParent end
    local frame = _G[name]
    if IsFrame(frame) then return frame end
    return UIParent
end

local function CanAccessValue(value)
    if type(canaccessvalue) == "function" then
        local ok, accessible = pcall(canaccessvalue, value)
        if ok then return accessible == true end
    end
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if ok then return secret ~= true end
    end
    return true
end

local function CaptureFrame(frame, frameName)
    if not IsFrame(frame) then return nil end

    local state = {
        name = frameName or RelativeName(frame),
        points = {},
        anchorReadable = true,
    }

    local numPoints = 0
    if type(frame.GetNumPoints) == "function" then
        local ok, value = pcall(frame.GetNumPoints, frame)
        if not ok or not CanAccessValue(value) then
            state.anchorReadable = false
            return state
        end
        numPoints = tonumber(value) or 0
    end

    for i = 1, numPoints do
        local ok, point, relativeTo, relativePoint, x, y = pcall(frame.GetPoint, frame, i)
        if not ok
            or not CanAccessValue(point)
            or not CanAccessValue(relativeTo)
            or not CanAccessValue(relativePoint)
            or not CanAccessValue(x)
            or not CanAccessValue(y) then
            state.anchorReadable = false
            state.points = {}
            return state
        end

        if point then
            state.points[#state.points + 1] = {
                point = point,
                relativeName = RelativeName(relativeTo),
                relativePoint = relativePoint or point,
                x = tonumber(x) or 0,
                y = tonumber(y) or 0,
            }
        end
    end

    return state
end

local function RestoreFrame(frameState)
    if type(frameState) ~= "table" then return false end
    local frame = frameState.name and _G[frameState.name] or nil
    if not IsFrame(frame) then return false end

    local okClear = pcall(frame.ClearAllPoints, frame)
    if not okClear then return false end

    local restored = false
    for _, point in ipairs(frameState.points or {}) do
        local relative = ResolveRelative(point.relativeName)
        local ok = pcall(
            frame.SetPoint,
            frame,
            point.point or "TOPRIGHT",
            relative,
            point.relativePoint or point.point or "TOPRIGHT",
            tonumber(point.x) or 0,
            tonumber(point.y) or 0
        )
        restored = ok or restored
    end

    return restored
end

local function GetAnchor()
    if IsFrame(_G.Minimap) then return _G.Minimap end
    if IsFrame(_G.MinimapCluster) then return _G.MinimapCluster end
    return UIParent
end

local function CaptureTargets(provider)
    local providerDef = PROVIDERS[provider]
    if not providerDef then return nil end

    local state = {
        provider = provider,
        frames = {},
    }

    -- Midnight 12.1 marks ElvUI player-aura anchor information secret while
    -- aura restrictions are active. Never inspect GetNumPoints/GetPoint for
    -- ElvUI aura holders or movers. ElvUI itself will restore its configured
    -- mover layout when BattleMaps releases ownership.
    if provider == "ElvUI" then
        state.restoreWithProvider = true
        return state
    end

    local function Add(kind, entry)
        if not entry then return end
        local captured = CaptureFrame(entry.frame, entry.name)
        if captured then
            state.frames[#state.frames + 1] = {
                kind = kind,
                state = captured,
            }
        end
    end

    if provider == "Blizzard" then
        local buffRoot, debuffRoot = GetBlizzardLayoutTargets()
        Add("buffs", buffRoot)
        Add("debuffs", debuffRoot)
        return state
    end

    return state
end

local function IsAlreadyCaptured(state, frameName)
    for _, entry in ipairs(state and state.frames or {}) do
        if entry.state and entry.state.name == frameName then
            return true
        end
    end
    return false
end

local function CaptureNewFrames(state, provider)
    if not state or provider == "ElvUI" then return end

    if provider == "Blizzard" then
        local buffRoot, debuffRoot = GetBlizzardLayoutTargets()
        for _, pair in ipairs({
            { kind = "buffs", entry = buffRoot },
            { kind = "debuffs", entry = debuffRoot },
        }) do
            local entry = pair.entry
            if entry and not IsAlreadyCaptured(state, entry.name) then
                local captured = CaptureFrame(entry.frame, entry.name)
                if captured then
                    state.frames[#state.frames + 1] = {
                        kind = pair.kind,
                        state = captured,
                    }
                end
            end
        end
    end
end

local function RefreshElvUIConfiguredLayout()
    local elvui = _G.ElvUI
    local E = type(elvui) == "table" and type(elvui[1]) == "table" and elvui[1] or elvui
    if type(E) ~= "table" then return false end

    -- ElvUI owns the original aura-mover coordinates. Asking it to re-run its
    -- own layout avoids reading secret anchor values from the aura frames.
    if type(E.UpdateAll) == "function" then
        local ok = pcall(E.UpdateAll, E, true)
        return ok == true
    end
    return false
end

local function MoveFrame(entry, point, relativeFrame, relativePoint, x, y)
    if not entry or not IsFrame(entry.frame) then return false end

    local frame = entry.frame
    local okClear, clearErr = pcall(frame.ClearAllPoints, frame)
    local okPoint, pointErr = false, nil
    if okClear then
        okPoint, pointErr = pcall(
            frame.SetPoint, frame,
            point, relativeFrame, relativePoint,
            tonumber(x) or 0, tonumber(y) or 0
        )
    end

    if not okClear or not okPoint then
        AuraLayout.lastFailed[#AuraLayout.lastFailed + 1] =
            entry.name .. ":" .. tostring(not okClear and clearErr or pointErr or "SetPoint failed")
    end

    return okPoint == true
end

local function PlaceProvider(provider, state)
    CaptureNewFrames(state, provider)

    local anchor = GetAnchor()
    AuraLayout.lastFound = {
        buffs = {},
        debuffs = {},
        anchor = RelativeName(anchor) or tostring(anchor),
    }
    AuraLayout.lastFailed = {}

    if provider == "ElvUI" then
        -- Preserve the now-tested working ElvUI behaviour exactly: ElvUI can
        -- favour either its mover or visible holder during a layout refresh,
        -- so BattleMaps moves both.
        local providerDef = PROVIDERS.ElvUI
        local buffs = FindNamedFrames(providerDef.buffs)
        local debuffs = FindNamedFrames(providerDef.debuffs)

        for _, entry in ipairs(buffs) do
            AuraLayout.lastFound.buffs[#AuraLayout.lastFound.buffs + 1] = entry.name
        end
        for _, entry in ipairs(debuffs) do
            AuraLayout.lastFound.debuffs[#AuraLayout.lastFound.debuffs + 1] = entry.name
        end

        if #buffs == 0 and #debuffs == 0 then
            return false
        end

        local moved = false
        for _, entry in ipairs(buffs) do
            moved = MoveFrame(entry, "TOPRIGHT", anchor, "TOPRIGHT", 0, 0) or moved
        end

        local debuffAnchor = (#buffs > 0 and buffs[#buffs].frame) or anchor
        for _, entry in ipairs(debuffs) do
            moved = MoveFrame(entry, "TOPRIGHT", debuffAnchor, "BOTTOMRIGHT", 0, -8) or moved
        end
        return moved
    end

    if provider == "Blizzard" then
        local buffRoot, debuffRoot = GetBlizzardLayoutTargets()

        if buffRoot then
            AuraLayout.lastFound.buffs[1] = buffRoot.name
        end
        if debuffRoot then
            AuraLayout.lastFound.debuffs[1] = debuffRoot.name
        end

        if not buffRoot and not debuffRoot then
            return false
        end

        local moved = false

        -- The native BuffFrame is the layout root: its aura buttons already
        -- grow leftward and debuffs are positioned below the buff rows by
        -- Blizzard. Move only this root into the hidden minimap footprint.
        if buffRoot then
            moved = MoveFrame(buffRoot, "TOPRIGHT", anchor, "TOPRIGHT", 0, 0) or moved
        end

        -- Compatibility only for native UI variants which truly expose a
        -- separate harmful-aura root instead of using BuffFrame.
        if debuffRoot then
            local relative = buffRoot and buffRoot.frame or anchor
            local relativePoint = buffRoot and "BOTTOMRIGHT" or "TOPRIGHT"
            local y = buffRoot and -8 or 0
            moved = MoveFrame(debuffRoot, "TOPRIGHT", relative, relativePoint, 0, y) or moved
        end

        return moved
    end

    return false
end

function AuraLayout:Restore()
    local state = self.state
    self.state = nil
    self.pending = false
    if type(state) ~= "table" then return true end

    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        self.state = state
        self.pending = true
        return false
    end

    if state.provider == "ElvUI" or state.restoreWithProvider == true then
        local restored = RefreshElvUIConfiguredLayout()
        self.lastFailed = restored and {} or { "ElvUI:UpdateAll restore failed" }
        return restored
    end

    for _, kind in ipairs({ "buffs", "debuffs" }) do
        for _, entry in ipairs(state.frames or {}) do
            if entry.kind == kind
                and entry.state
                and entry.state.anchorReadable ~= false then
                RestoreFrame(entry.state)
            end
        end
    end

    return true
end

function AuraLayout:Apply()
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        self.pending = true
        return false
    end

    self.lastShouldManage = ShouldManageNow()
    if not self.lastShouldManage then
        self.lastMoved = false
        return self:Restore()
    end

    local provider = self:GetProvider()
    self.lastProvider = provider
    if provider == "Unavailable" then
        self.pending = true
        return false
    end

    if self.state and self.state.provider ~= provider then
        self:Restore()
    end

    if not self.state then
        self.state = CaptureTargets(provider)
    end

    local moved = PlaceProvider(provider, self.state)
    self.lastMoved = moved == true
    self.pending = not moved
    return moved
end

function BattleMaps.ApplyPlayerAuraLayout()
    return AuraLayout:Apply()
end

-- Compatibility with older ElvUI-specific naming. New code should call the
-- provider-agnostic function above.
BattleMaps.ApplyAuraLayout = BattleMaps.ApplyPlayerAuraLayout

-- ElvUIIntegration.lua predates the generalized provider. It is intentionally
-- loaded first for the rest of its compatibility behaviour, but all of its
-- aura-layout entry points now delegate here so there is only one owner.
function BattleMaps.ShouldApplyElvUIBGLayoutNow()
    return ShouldManageNow() and AuraLayout:GetProvider() == "ElvUI"
end

function BattleMaps.ApplyElvUIBGLayout()
    return AuraLayout:Apply()
end

function BattleMaps.RestoreElvUIBGLayout()
    return AuraLayout:Restore()
end

-- Whenever minimap visibility is reconsidered, reconsider aura placement as a
-- paired layout operation.
if type(BattleMaps.ApplyMinimapVisibility) == "function"
    and not BattleMaps.BattleMaps298MinimapWrapped then
    BattleMaps.BattleMaps298MinimapWrapped = true
    local OriginalApplyMinimapVisibility = BattleMaps.ApplyMinimapVisibility
    function BattleMaps.ApplyMinimapVisibility(...)
        local result = OriginalApplyMinimapVisibility(...)
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0, function()
                AuraLayout:Apply()
            end)
        else
            AuraLayout:Apply()
        end
        return result
    end
end

SLASH_BATTLEMAPSAURALAYOUT1 = "/bmaura"
SlashCmdList.BATTLEMAPSAURALAYOUT = function(message)
    message = tostring(message or ""):lower():match("^%s*(.-)%s*$") or ""
    local db = GetDB()

    if message == "on" then
        if type(db) == "table" then
            db.bgLayoutMovePlayerAuras = true
            db.movePlayerAurasToMinimapArea = true
            db.elvuiBGLayoutMovePlayerAuras = true
        end
        AuraLayout:Apply()
    elseif message == "off" then
        if type(db) == "table" then
            db.bgLayoutMovePlayerAuras = false
            db.movePlayerAurasToMinimapArea = false
            db.elvuiBGLayoutMovePlayerAuras = false
        end
        AuraLayout:Restore()
    end

    local mapFrame = BattleMaps.MapFrame
    local testMode = mapFrame and mapFrame.testMode == true or false
    local enabled = MoveSettingEnabled(db)
    local provider = AuraLayout:GetProvider()
    local shouldManage = ShouldManageNow()

    local found = AuraLayout.lastFound or {}
    local buffs = type(found.buffs) == "table" and table.concat(found.buffs, ",") or ""
    local debuffs = type(found.debuffs) == "table" and table.concat(found.debuffs, ",") or ""
    local failed = type(AuraLayout.lastFailed) == "table" and table.concat(AuraLayout.lastFailed, " | ") or ""

    BattleMaps.Chat(
        "Aura layout:",
        "provider=" .. tostring(provider),
        "enabled=" .. tostring(enabled),
        "canonical=" .. tostring(db and db.bgLayoutMovePlayerAuras)
            .. ", legacy=" .. tostring(db and db.elvuiBGLayoutMovePlayerAuras),
        "test=" .. tostring(testMode),
        "manage=" .. tostring(shouldManage),
        "moved=" .. tostring(AuraLayout.lastMoved == true),
        "anchor=" .. tostring(found.anchor or "?"),
        "buffs=" .. (buffs ~= "" and buffs or "none"),
        "debuffs=" .. (debuffs ~= "" and debuffs or "none"),
        "failed=" .. (failed ~= "" and failed or "none")
    )

    if message == "" then
        AuraLayout:Apply()
    end
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("ZONE_CHANGED_NEW_AREA")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:RegisterEvent("DISPLAY_SIZE_CHANGED")
driver:RegisterEvent("UI_SCALE_CHANGED")
driver:RegisterEvent("ADDON_LOADED")

driver:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName ~= "ElvUI" and addonName ~= "Blizzard_BuffFrame" then
        return
    end

    if event == "PLAYER_REGEN_ENABLED" and not AuraLayout.pending and not ShouldManageNow() then
        AuraLayout:Restore()
        return
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0.10, function()
            AuraLayout:Apply()
        end)
    else
        AuraLayout:Apply()
    end
end)

driver:SetScript("OnUpdate", function(_, elapsed)
    AuraLayout.elapsed = (AuraLayout.elapsed or 0) + (tonumber(elapsed) or 0)
    if AuraLayout.elapsed < 1.0 then return end
    AuraLayout.elapsed = 0

    -- ElvUI and Blizzard can both re-run layout code after zone/UI changes.
    -- While this feature is active, lightly enforce the saved BattleMaps anchor
    -- once per second out of combat. This also discovers aura frames that were
    -- created after PLAYER_ENTERING_WORLD.
    if ShouldManageNow() or AuraLayout.state or AuraLayout.pending then
        AuraLayout:Apply()
    end
end)
