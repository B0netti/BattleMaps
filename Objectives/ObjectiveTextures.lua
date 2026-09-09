local ADDON_NAME, BattleMaps = ...
BattleMaps = BattleMaps or _G.BattleMaps
if not BattleMaps or not BattleMaps.Pins then return end

local Pins = BattleMaps.Pins
local Private = Pins.Private or {}
local Rules = BattleMaps.ObjectiveRules or {}

local function Now()
    return type(GetTime) == "function" and GetTime() or 0
end

local CTF_SLOT_LOCK_SECONDS = 15 * 60
local DEEPHAUL_RAVINE_MAP_ID = 2345
local DEEPHAUL_CRYSTAL_HIDDEN_SECONDS = 120
local DEEPHAUL_CRYSTAL_RESPAWN_SECONDS = 25
local DEEPHAUL_CRYSTAL_REAPPEAR_DELAY_SECONDS = 0.20
local TEMPLE_ORB_DROP_SUPPRESSION_SECONDS = 10.0

local function IsDeephaulRavineMapID(mapID)
    if Private.IsDeephaulRavineMap then
        local ok, result = pcall(Private.IsDeephaulRavineMap, mapID)
        if ok then return result == true end
    end
    return tonumber(mapID) == DEEPHAUL_RAVINE_MAP_ID
end

local function NormalizeObjectiveKey(value)
    if Private.NormalizeObjectiveKey then
        return Private.NormalizeObjectiveKey(value)
    end
    local ok, text = pcall(tostring, value or "")
    if not ok or not text then return "" end
    ok, text = pcall(string.lower, text)
    if not ok or not text then return "" end
    return text
end

local function NormalizeMessageText(value)
    local ok, text = pcall(tostring, value or "")
    if not ok or type(text) ~= "string" then return "" end
    ok, text = pcall(string.lower, text)
    if not ok or type(text) ~= "string" then return "" end

    local function SafeGsub(input, pattern, replacement)
        local okGsub, result = pcall(string.gsub, input, pattern, replacement)
        return okGsub and result or input
    end

    text = SafeGsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = SafeGsub(text, "|r", "")
    text = SafeGsub(text, "|h.-|h", " ")
    text = SafeGsub(text, "&", " and ")
    text = SafeGsub(text, "[^%w]+", " ")
    text = SafeGsub(text, "%s+", " ")
    text = SafeGsub(text, "^%s+", "")
    text = SafeGsub(text, "%s+$", "")
    return text
end

local function IsCTF(mapID)
    return Private.IsCaptureTheFlagMap and Private.IsCaptureTheFlagMap(mapID)
end

local function GetCurrentObjectiveMessageMapID()
    return (BattleMaps.ResolveCurrentBattlegroundMapID and BattleMaps.ResolveCurrentBattlegroundMapID())
        or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
        or (BattleMaps.Options and BattleMaps.Options.selectedMapID)
end

local function EventFaction(event)
    if event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" then return "alliance" end
    if event == "CHAT_MSG_BG_SYSTEM_HORDE" then return "horde" end
    return nil
end

local function MessageHasAny(text, tokens)
    text = NormalizeMessageText(text)
    if text == "" then return false end
    for _, token in ipairs(tokens) do
        token = NormalizeMessageText(token)
        if token ~= "" and text:find(token, 1, true) then return true end
    end
    return false
end

local function FlagObjectFactionFromMessage(text)
    text = NormalizeMessageText(text)
    if text:find("alliance flag", 1, true) then return "alliance" end
    if text:find("horde flag", 1, true) then return "horde" end
    return nil
end

local function QueueObjectiveMessageRefresh(self, refreshFlags, refreshVehicles)
    if not self then return end
    self.objectiveMessageRefreshFlags = self.objectiveMessageRefreshFlags == true or refreshFlags == true
    self.objectiveMessageRefreshVehicles = self.objectiveMessageRefreshVehicles == true or refreshVehicles == true
    if self.objectiveMessageRefreshPending then return end
    self.objectiveMessageRefreshPending = true

    local function Refresh()
        self.objectiveMessageRefreshPending = false
        local shouldRefreshFlags = self.objectiveMessageRefreshFlags == true
        local shouldRefreshVehicles = self.objectiveMessageRefreshVehicles == true
        self.objectiveMessageRefreshFlags = nil
        self.objectiveMessageRefreshVehicles = nil

        if not BattleMaps.MapFrame or not BattleMaps.MapFrame.frame or not BattleMaps.MapFrame.frame:IsShown() then return end
        if self.RefreshPOIs then self:RefreshPOIs() end
        if shouldRefreshVehicles and self.RefreshVehicles then self:RefreshVehicles() end
        if shouldRefreshFlags and self.RefreshFlags then self:RefreshFlags() end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, Refresh)
    else
        Refresh()
    end
end

local function ActiveCTFState(self, mapID, create)
    local mapKey = tostring(tonumber(mapID) or mapID or "unknown")
    if create then
        self.ctfFlagObjectStateByMap = self.ctfFlagObjectStateByMap or {}
        self.ctfFlagObjectStateByMap[mapKey] = self.ctfFlagObjectStateByMap[mapKey] or {}
        return self.ctfFlagObjectStateByMap[mapKey]
    end
    local root = self.ctfFlagObjectStateByMap
    return type(root) == "table" and root[mapKey] or nil
end

local function GetCTFSlotLockKey(mapID, index)
    return tostring(tonumber(mapID) or mapID or "unknown")
        .. ":" .. tostring(tonumber(index) or index or 0)
end

local function ClearRememberedCTFFlagObjectFaction(pins, mapID, flagObjectFaction)
    if not pins or type(pins.ctfFlagFactionByIndex) ~= "table" then return end

    local mapPrefix = tostring(tonumber(mapID) or mapID or "unknown") .. ":"
    flagObjectFaction = NormalizeObjectiveKey(flagObjectFaction)
    local filterByFaction = flagObjectFaction == "alliance" or flagObjectFaction == "horde"

    for key, record in pairs(pins.ctfFlagFactionByIndex) do
        if tostring(key):sub(1, #mapPrefix) == mapPrefix then
            local faction = NormalizeObjectiveKey(type(record) == "table" and record.faction or nil)
            if not filterByFaction or faction == flagObjectFaction then
                pins.ctfFlagFactionByIndex[key] = nil
            end
        end
    end
end

function Pins:ClearRememberedCTFFlagObjectFaction(mapID, flagObjectFaction)
    ClearRememberedCTFFlagObjectFaction(self, mapID, flagObjectFaction)
end

function Pins:RememberCTFFlagObjectFaction(mapID, index, flagObjectFaction, source)
    if not IsCTF(mapID) then return nil end
    flagObjectFaction = NormalizeObjectiveKey(flagObjectFaction)
    if flagObjectFaction ~= "alliance" and flagObjectFaction ~= "horde" then return nil end

    self.ctfFlagFactionByIndex = self.ctfFlagFactionByIndex or {}
    local key = GetCTFSlotLockKey(mapID, index)
    self.ctfFlagFactionByIndex[key] = {
        faction = flagObjectFaction,
        source = tostring(source or "unknown"),
        time = Now(),
        expires = Now() + CTF_SLOT_LOCK_SECONDS,
    }
    return flagObjectFaction
end

function Pins:GetRememberedCTFFlagObjectFaction(mapID, index)
    if not IsCTF(mapID) then return nil end
    local cache = self.ctfFlagFactionByIndex
    if type(cache) ~= "table" then return nil end

    local key = GetCTFSlotLockKey(mapID, index)
    local record = cache[key]
    if type(record) ~= "table" then return nil end

    local now = Now()
    if record.expires and record.expires <= now then
        cache[key] = nil
        return nil
    end

    local faction = NormalizeObjectiveKey(record.faction)
    if faction == "alliance" or faction == "horde" then
        return faction
    end
    cache[key] = nil
    return nil
end

function Pins:RecordCTFFlagObjectFactionMessage(mapID, flagObjectFaction, taken, dropped, returnedOrCaptured, now)
    if not IsCTF(mapID) then return false end

    flagObjectFaction = NormalizeObjectiveKey(flagObjectFaction)
    local validFaction = flagObjectFaction == "alliance" or flagObjectFaction == "horde"

    -- A reset/capture message without a reliable flag-object phrase invalidates
    -- the map-level CTF state and every per-slot lock for this battleground.
    if returnedOrCaptured and not validFaction then
        local state = ActiveCTFState(self, mapID, false)
        if state then wipe(state) end
        ClearRememberedCTFFlagObjectFaction(self, mapID)
        if type(self.ctfFlagEffectMotionByKey) == "table" then wipe(self.ctfFlagEffectMotionByKey) end
        return true
    end

    if not validFaction then return false end

    local state = ActiveCTFState(self, mapID, true)
    now = tonumber(now) or Now()

    if returnedOrCaptured then
        state[flagObjectFaction] = nil
        -- The battlefield flag list is compact. When either flag is removed
        -- from that list the remaining flag can move to a different API index,
        -- so every index->object lock for this map becomes suspect.
        ClearRememberedCTFFlagObjectFaction(self, mapID)
        if type(self.ctfFlagEffectMotionByKey) == "table" then wipe(self.ctfFlagEffectMotionByKey) end
        return true
    end

    if dropped then
        -- Dropping/re-picking can compact and reorder the entire battlefield
        -- flag list, not just the slot that previously represented this flag.
        -- Invalidate all per-index locks and rebuild them from the explicit
        -- flag-object message/token data on the next refresh.
        ClearRememberedCTFFlagObjectFaction(self, mapID)
        if type(self.ctfFlagEffectMotionByKey) == "table" then wipe(self.ctfFlagEffectMotionByKey) end
        state[flagObjectFaction] = {
            active = true,
            dropped = true,
            time = now,
            expires = now + 180,
        }
        return true
    end

    if taken then
        -- A new pickup also starts a new compact-slot assignment. Clear the
        -- complete map-level slot cache because Blizzard may have reindexed the
        -- other carried flag at the same time.
        ClearRememberedCTFFlagObjectFaction(self, mapID)
        state[flagObjectFaction] = {
            active = true,
            dropped = false,
            time = now,
            expires = now + 180,
        }
        return true
    end

    return false
end

function Pins:RecordDeephaulCrystalMessage(mapID, message)
    if not IsDeephaulRavineMapID(mapID) then return false end

    local text = NormalizeMessageText(message)
    if text == "" or not text:find("crystal", 1, true) then return false end

    -- Blizzard also emits a static rules reminder containing the words
    -- "crystal" and "captured". It is not a lifecycle event and previously
    -- could incorrectly force the synthetic centre crystal visible.
    if text:find("the crystal can be captured outside an earthen cart building", 1, true)
        or (text:find("can be captured", 1, true) and text:find("cart building", 1, true)) then
        return false
    end

    local pickup = MessageHasAny(text, {
        "picked up",
        "has taken",
        "has been taken",
        "was taken",
        "took the crystal",
        "grabbed",
        "carrying the crystal",
    })
    local dropped = MessageHasAny(text, {
        "dropped",
        "has dropped",
        "was dropped",
    })
    local scored = MessageHasAny(text, {
        "captured",
        "delivered",
        "scored",
        "turned in",
        "turned-in",
    })
    local reappears = MessageHasAny(text, {
        "returned",
        "has reset",
        "was reset",
        "respawn",
        "spawned",
        "available",
        "unearthed",
        "center of the ravine",
        "centre of the ravine",
    })

    if not pickup and not dropped and not scored and not reappears then return false end

    local now = Now()
    self.deephaulCrystalState = self.deephaulCrystalState or {}
    local state = self.deephaulCrystalState
    local refreshDelay

    if pickup or dropped then
        -- Once the crystal leaves centre, the synthetic centre pin must be
        -- absent even if Blizzard exposes no moving carried-crystal position.
        state.visible = false
        state.hiddenUntil = now + DEEPHAUL_CRYSTAL_HIDDEN_SECONDS
        state.visibleAfter = nil
        state.reason = pickup and "picked-up" or "dropped"
    elseif scored then
        -- A successful delivery removes the centre crystal. Live testing and
        -- community timing put the ordinary respawn at ~25 seconds; use that
        -- as a fallback in case the later spawn notice arrives on a different
        -- battleground announcement channel. A real spawn/reset notice wins
        -- immediately if Blizzard sends one first.
        state.visible = true
        state.hiddenUntil = nil
        state.visibleAfter = now + DEEPHAUL_CRYSTAL_RESPAWN_SECONDS
        state.reason = "scored"
        refreshDelay = DEEPHAUL_CRYSTAL_RESPAWN_SECONDS + 0.05
    elseif reappears then
        state.visible = true
        state.hiddenUntil = nil
        state.visibleAfter = now + DEEPHAUL_CRYSTAL_REAPPEAR_DELAY_SECONDS
        state.reason = "available"
        refreshDelay = DEEPHAUL_CRYSTAL_REAPPEAR_DELAY_SECONDS + 0.05
    end

    QueueObjectiveMessageRefresh(self, false, true)
    if refreshDelay and C_Timer and C_Timer.After then
        C_Timer.After(refreshDelay, function()
            if BattleMaps.MapFrame and BattleMaps.MapFrame.frame and BattleMaps.MapFrame.frame:IsShown()
                and self.RefreshPOIs then
                self:RefreshPOIs()
            end
        end)
    end
    return true
end

-- Some battleground objective state notices arrive through Blizzard's
-- raid/boss-emote channel rather than CHAT_MSG_BG_SYSTEM_*. Keep the Deephaul
-- lifecycle receiver available directly at that event source.
function Pins:RecordObjectiveRaidNotice(message)
    local mapID = GetCurrentObjectiveMessageMapID()
    if not mapID or not IsDeephaulRavineMapID(mapID) then return false end
    return self:RecordDeephaulCrystalMessage(mapID, message) == true
end

function Pins:IsDeephaulCrystalVisible(mapID)
    if mapID and not IsDeephaulRavineMapID(mapID) then return true end

    local state = self.deephaulCrystalState
    if type(state) ~= "table" then return true end

    local now = Now()
    if state.visibleAfter and state.visibleAfter > now then
        return false
    end
    if state.hiddenUntil and state.hiddenUntil > now then
        return false
    end
    if state.hiddenUntil and state.hiddenUntil <= now then
        state.hiddenUntil = nil
        state.visible = true
    end
    return state.visible ~= false
end

local TEMPLE_ORB_COLORS = { "purple", "green", "orange", "blue" }

local function GetTempleOrbColorFromMessage(text)
    text = NormalizeMessageText(text)
    if text == "" or not text:find("orb", 1, true) then return nil end
    for _, color in ipairs(TEMPLE_ORB_COLORS) do
        if text:find(color, 1, true) then return color end
    end
    return nil
end

function Pins:RecordTempleOrbMessage(mapID, message, carrierFaction)
    if not (Rules.IsTempleOfKotmoguMap and Rules.IsTempleOfKotmoguMap(mapID)) then
        return false
    end

    local text = NormalizeMessageText(message)
    local color = GetTempleOrbColorFromMessage(text)
    if not color then return false end

    local pickedUp = MessageHasAny(text, {
        "picked up", "has taken", "was taken", "grabbed", "is carrying",
    })
    local released = MessageHasAny(text, {
        "dropped", "returned", "has reset", "was reset", "respawned",
        "available", "released",
    })
    if not pickedUp and not released then return false end

    carrierFaction = NormalizeObjectiveKey(carrierFaction)
    if carrierFaction ~= "alliance" and carrierFaction ~= "horde" then
        carrierFaction = nil
    end

    local now = Now()
    self.templeOrbMessageStateByColor = self.templeOrbMessageStateByColor or {}
    self.templeOrbMessageKnownByColor = self.templeOrbMessageKnownByColor or {}
    self.templeOrbSuppressedUntilByColor = self.templeOrbSuppressedUntilByColor or {}
    self.templeOrbMessageKnownByColor[color] = true

    if pickedUp then
        self.templeOrbSuppressedUntilByColor[color] = nil
        if type(self.templeCarriedOrbMotionByColor) == "table" then
            for key in pairs(self.templeCarriedOrbMotionByColor) do
                if tostring(key):match(":" .. color .. "$") then
                    self.templeCarriedOrbMotionByColor[key] = nil
                end
            end
        end
        -- Pickup/return messages are the authoritative per-colour lifecycle.
        -- Keep the pickup active until a matching release message or match reset;
        -- expiring it after a fixed interval allowed long-held orbs to revert to
        -- compact-slot guesses and change colour.
        self.templeOrbMessageStateByColor[color] = {
            active = true,
            time = now,
            faction = carrierFaction,
        }
        self.templeLastPickedOrbColor = color
        self.templeLastPickedOrbAt = now
    else
        -- Blizzard can leave the old carried-objective slot at the dead
        -- carrier's graveyard position for several refreshes. Suppress that
        -- colour briefly, clear its slot memory/trail, and allow the stationary
        -- spawn to return instead of drawing a false graveyard wake.
        self.templeOrbMessageStateByColor[color] = nil
        self.templeOrbSuppressedUntilByColor[color] = now + TEMPLE_ORB_DROP_SUPPRESSION_SECONDS
        if self.templeLastPickedOrbColor == color then
            self.templeLastPickedOrbColor = nil
            self.templeLastPickedOrbAt = nil
        end
        if self.ClearTempleCarriedOrbVisual then
            self:ClearTempleCarriedOrbVisual(color)
        end
    end

    if self.SetTempleActiveCarriedOrbColors then
        self:SetTempleActiveCarriedOrbColors(
            mapID,
            self.templeAPICarriedOrbColors or {}
        )
    elseif self.ApplyTempleOrbStationaryState then
        self:ApplyTempleOrbStationaryState(mapID)
    end
    return true
end

function Pins:GetTempleOrbCarrierFaction(mapID, color)
    if not (Rules.IsTempleOfKotmoguMap and Rules.IsTempleOfKotmoguMap(mapID)) then
        return nil
    end
    color = NormalizeObjectiveKey(color)
    local state = self.templeOrbMessageStateByColor
    local record = type(state) == "table" and state[color] or nil
    if type(record) ~= "table" or record.active ~= true then return nil end
    if self.IsTempleOrbCarriedSuppressed
        and self:IsTempleOrbCarriedSuppressed(mapID, color) then
        return nil
    end
    local faction = NormalizeObjectiveKey(record.faction)
    if faction == "alliance" or faction == "horde" then
        return faction
    end
    return nil
end

function Pins:IsTempleOrbCarriedSuppressed(mapID, color)
    if not (Rules.IsTempleOfKotmoguMap and Rules.IsTempleOfKotmoguMap(mapID)) then
        return false
    end
    color = NormalizeObjectiveKey(color)
    local state = self.templeOrbSuppressedUntilByColor
    local expires = type(state) == "table" and tonumber(state[color]) or nil
    if not expires then return false end
    if expires <= Now() then
        state[color] = nil
        return false
    end
    return true
end

function Pins:SuppressTempleCarriedOrbColor(mapID, color, duration)
    if not (Rules.IsTempleOfKotmoguMap and Rules.IsTempleOfKotmoguMap(mapID)) then
        return false
    end
    color = NormalizeObjectiveKey(color)
    if color == "" then return false end
    self.templeOrbSuppressedUntilByColor = self.templeOrbSuppressedUntilByColor or {}
    self.templeOrbSuppressedUntilByColor[color] = Now()
        + BattleMaps.Clamp(tonumber(duration) or TEMPLE_ORB_DROP_SUPPRESSION_SECONDS, 0.5, 30)
    if self.ClearTempleCarriedOrbVisual then
        self:ClearTempleCarriedOrbVisual(color)
    end
    return true
end

function Pins:GetTempleMessageActiveOrbColors(mapID)
    if not (Rules.IsTempleOfKotmoguMap and Rules.IsTempleOfKotmoguMap(mapID)) then
        return {}
    end

    local now = Now()
    local result = {}
    local state = self.templeOrbMessageStateByColor
    if type(state) ~= "table" then return result end

    for _, color in ipairs(TEMPLE_ORB_COLORS) do
        local record = state[color]
        if type(record) == "table" and record.active == true
            and (not record.expires or record.expires > now)
            and not self:IsTempleOrbCarriedSuppressed(mapID, color) then
            result[color] = true
        elseif record ~= nil then
            state[color] = nil
        end
    end
    return result
end

function Pins:GetRecentTempleOrbPickupColor(mapID)
    local active = self:GetTempleMessageActiveOrbColors(mapID)
    local color = self.templeLastPickedOrbColor
    if color and active[color] then return color end

    local onlyColor
    for _, candidate in ipairs(TEMPLE_ORB_COLORS) do
        if active[candidate] then
            if onlyColor then return nil end
            onlyColor = candidate
        end
    end
    return onlyColor
end

local TEMPLE_STATIONARY_PIN_COLLECTIONS = {
    "poiPins",
    "dummyStationaryPins",
}

local function GetPinMapPosition(pin)
    if not pin then return nil, nil end
    return tonumber(pin.mapX or pin.BattleMapsMapX or pin.x),
        tonumber(pin.mapY or pin.BattleMapsMapY or pin.y)
end

local function ApplyTempleOrbTexture(pins, pin, mapID, color)
    if not pins or not pin or not pin.texture or not color then return false end

    -- Kotmogu stationary identity comes from the fixed map quadrant, so use the
    -- exact colour path rather than feeding generic POI/index aliases back into
    -- the resolver. This prevents the blue location from inheriting green art.
    local texturePath = Rules.GetTempleOrbTexturePath
        and Rules.GetTempleOrbTexturePath(mapID, "stationary", color)
        or nil
    if (type(texturePath) ~= "string" or texturePath == "")
        and type(pins.FindObjectiveTexture) == "function" then
        local textureKey = Rules.GetTempleOrbTextureKey and Rules.GetTempleOrbTextureKey(color)
            or (tostring(color) .. "_orb")
        local ok, resolved = pcall(
            pins.FindObjectiveTexture,
            pins,
            mapID,
            "stationary",
            { textureKey, tostring(color) .. "_orb", tostring(color) },
            "neutral"
        )
        if ok then texturePath = resolved end
    end
    if type(texturePath) ~= "string" or texturePath == "" then return false end

    if pin.texture.SetAtlas then pcall(pin.texture.SetAtlas, pin.texture, nil) end
    pin.texture:SetTexture(texturePath)
    pin.texture:SetTexCoord(0, 1, 0, 1)
    pin.texture:SetVertexColor(1, 1, 1, 1)
    if pin.texture.SetDesaturated then pin.texture:SetDesaturated(false) end
    if pin.texture.SetRotation then pin.texture:SetRotation(0) end
    pin.BattleMapsObjectiveTexturePath = texturePath
    pin.BattleMapsTempleOrbColor = color
    return true
end

function Pins:SetTempleActiveCarriedOrbColors(mapID, activeColors)
    if not (Rules.IsTempleOfKotmoguMap and Rules.IsTempleOfKotmoguMap(mapID)) then return false end

    -- API flag slots are compact and can be reordered, so index alone is not a
    -- reliable orb identity. Merge only colours positively resolved by the
    -- carried renderer with colour-specific battleground messages. The message
    -- state also keeps the correct spawn hidden through brief API gaps.
    local apiActive = {}
    if type(activeColors) == "table" then
        for color, value in pairs(activeColors) do
            if value == true then apiActive[color] = true end
        end
    end
    self.templeAPICarriedOrbColors = apiActive

    local messageColors = self:GetTempleMessageActiveOrbColors(mapID)
    local knownMessageColors = type(self.templeOrbMessageKnownByColor) == "table"
        and self.templeOrbMessageKnownByColor
        or {}
    local merged = {}
    for color, value in pairs(apiActive) do
        local messageSaysReturned = knownMessageColors[color] == true
            and messageColors[color] ~= true
        if value == true and not messageSaysReturned
            and not self:IsTempleOrbCarriedSuppressed(mapID, color) then
            merged[color] = true
        end
    end
    for color, value in pairs(messageColors) do
        if value == true then merged[color] = true end
    end

    self.templeActiveCarriedOrbColors = merged
    return self:ApplyTempleOrbStationaryState(mapID)
end

function Pins:IsTempleOrbColorCarried(mapID, color)
    if not (Rules.IsTempleOfKotmoguMap and Rules.IsTempleOfKotmoguMap(mapID)) then
        return false
    end

    color = NormalizeObjectiveKey(color)
    if color == "" then return false end
    if self:IsTempleOrbCarriedSuppressed(mapID, color) then return false end

    -- Once a colour-specific notification has been observed, its latest
    -- pickup/return state outranks compact API slots and visible stale pins.
    -- This prevents a returned colour from being resurrected after the short
    -- dead-carrier suppression window expires.
    local messageActive = self.GetTempleMessageActiveOrbColors
        and self:GetTempleMessageActiveOrbColors(mapID)
        or {}
    local messageKnown = type(self.templeOrbMessageKnownByColor) == "table"
        and self.templeOrbMessageKnownByColor[color] == true
    if messageKnown and messageActive[color] ~= true then return false end

    -- Treat every positive source as authoritative. In particular, a visible
    -- carried pin is proof that its fixed spawn pad must not also be rendered.
    -- This makes the stationary/carried relationship an explicit invariant
    -- rather than depending on refresh order between the POI and flag APIs.
    local active = self.templeActiveCarriedOrbColors
    if type(active) == "table" and active[color] == true then return true end

    local apiActive = self.templeAPICarriedOrbColors
    if type(apiActive) == "table" and apiActive[color] == true then return true end

    if self.GetTempleMessageActiveOrbColors then
        local messageActive = self:GetTempleMessageActiveOrbColors(mapID)
        if type(messageActive) == "table" and messageActive[color] == true then
            return true
        end
    end

    for _, pin in ipairs(self.flagPins or {}) do
        if pin and pin.BattleMapsObjectiveOrbColor
            and NormalizeObjectiveKey(pin.BattleMapsObjectiveOrbColor) == color
            and pin.IsShown and pin:IsShown() then
            return true
        end
    end

    return false
end

function Pins:ApplyTempleOrbStationaryState(mapID)
    if not (Rules.IsTempleOfKotmoguMap and Rules.IsTempleOfKotmoguMap(mapID)) then return false end
    local changed = false

    for _, collectionName in ipairs(TEMPLE_STATIONARY_PIN_COLLECTIONS) do
        local collection = self[collectionName]
        if type(collection) == "table" then
            for _, pin in ipairs(collection) do
                local x, y = GetPinMapPosition(pin)
                local color = Rules.GetTempleOrbColorByPosition
                    and Rules.GetTempleOrbColorByPosition(x, y) or nil
                if color then
                    ApplyTempleOrbTexture(self, pin, mapID, color)
                    if self:IsTempleOrbColorCarried(mapID, color) then
                        if pin.IsShown and pin:IsShown() then changed = true end
                        pin.BattleMapsHiddenForCarriedTempleOrb = true
                        if self.StopObjectiveEventPulse then
                            pcall(self.StopObjectiveEventPulse, self, pin)
                        end
                        pin:Hide()
                    elseif pin.BattleMapsHiddenForCarriedTempleOrb then
                        pin.BattleMapsHiddenForCarriedTempleOrb = nil
                        -- Re-place instead of blindly showing so returned pads
                        -- respect the current zoom/pan visibility calculation.
                        if self.Place and x and y then
                            self:Place(pin, x, y)
                        else
                            pin:Show()
                        end
                        changed = true
                    end
                end
            end
        end
    end
    return changed
end

-- Extend, do not replace, the base message receiver installed by Pins.lua.
-- The previous handler owns stationary objective announcements, including
-- contested/faction texture state and capture-fill timers for AB/Gilneas-style
-- nodes. This module only layers Deephaul crystal, EotS fallback, and CTF flag
-- object-state handling on top.
local PreviousRecordObjectiveFactionMessage = Pins.RecordObjectiveFactionMessage

function Pins:RecordObjectiveFactionMessage(event, message)
    local previousChanged = false
    if type(PreviousRecordObjectiveFactionMessage) == "function" then
        previousChanged = PreviousRecordObjectiveFactionMessage(self, event, message) == true
    end

    local mapID = GetCurrentObjectiveMessageMapID()
    local text = NormalizeMessageText(message)
    if mapID == nil or text == "" then return previousChanged end

    local changed = false

    if self.RecordDeephaulCrystalMessage and self:RecordDeephaulCrystalMessage(mapID, message) then
        changed = true
    end

    if self.RecordTempleOrbMessage
        and self:RecordTempleOrbMessage(mapID, message, EventFaction(event)) then
        changed = true
    end

    if tonumber(mapID) == 210 and text:find("flag", 1, true) then
        local faction = EventFaction(event)
        local pickedUp = MessageHasAny(text, { "picked up", "taken", "grabbed" })
        local ended = MessageHasAny(text, { "dropped", "returned", "captured", "reset" })

        if pickedUp and (faction == "alliance" or faction == "horde") then
            self.eotsCarriedFlagFactionRecord = {
                faction = faction,
                time = Now(),
                expires = Now() + 90,
            }
            changed = true
        elseif ended then
            self.eotsCarriedFlagFactionRecord = nil
            if type(self.eotsCarriedFlagMotionByIndex) == "table" then wipe(self.eotsCarriedFlagMotionByIndex) end
            changed = true
        end
    end

    if IsCTF(mapID) and text:find("flag", 1, true) then
        local flagObjectFaction = FlagObjectFactionFromMessage(text)
        local taken = MessageHasAny(text, { "picked up", "taken", "grabbed" })
        local dropped = MessageHasAny(text, { "dropped" })
        local returnedOrCaptured = MessageHasAny(text, { "returned", "captured", "reset" })

        if self.RecordCTFFlagObjectFactionMessage
            and self:RecordCTFFlagObjectFactionMessage(mapID, flagObjectFaction, taken, dropped, returnedOrCaptured, Now()) then
            changed = true
        end
    end

    if changed then
        QueueObjectiveMessageRefresh(self, true, true)
    end
    return changed or previousChanged
end

function Pins:GetActiveCTFFlagObjectFactions(mapID)
    local state = ActiveCTFState(self, mapID, false)
    if type(state) ~= "table" then return nil end

    local now = Now()
    local active = {}
    for _, faction in ipairs({ "alliance", "horde" }) do
        local record = state[faction]
        if type(record) == "table" and (not record.expires or record.expires > now) then
            active[#active + 1] = faction
        elseif record ~= nil then
            state[faction] = nil
        end
    end
    return active
end

function Pins:IsCTFFlagObjectActive(mapID, flagObjectFaction)
    if not IsCTF(mapID) then return false end
    flagObjectFaction = NormalizeObjectiveKey(flagObjectFaction)
    if flagObjectFaction ~= "alliance" and flagObjectFaction ~= "horde" then return false end

    local state = ActiveCTFState(self, mapID, false)
    local record = type(state) == "table" and state[flagObjectFaction] or nil
    local now = Now()
    if type(record) == "table" and (not record.expires or record.expires > now) then
        return record.active == true
    elseif type(state) == "table" and record ~= nil then
        state[flagObjectFaction] = nil
    end
    return false
end

function Pins:GetLockedCTFFlagObjectFaction(mapID, index, activeCount)
    local active = self:GetActiveCTFFlagObjectFactions(mapID)
    if type(active) ~= "table" or #active == 0 then return nil end

    -- Slot memory is stronger than a later single-message fallback. In Blitz,
    -- one enemy carrier can temporarily have no map position; a fresh "enemy
    -- flag picked up/dropped" message must not recolour the still-visible
    -- friendly carrier slot.
    local remembered = self:GetRememberedCTFFlagObjectFaction(mapID, index)
    if remembered then return remembered end

    -- Most live CTF ambiguity occurs when only one visible flag is away. The
    -- system message phrase, e.g. "The Horde flag...", gives the object faction.
    -- Use it only after checking slot memory above, and do not use it while the
    -- raw flag API contains hidden/unpositioned carrier slots. That is the Blitz
    -- case where the hidden enemy flag state can otherwise recolour the visible
    -- friendly carrier.
    local rawCount = tonumber(self and self.BattleMapsRawCarriedFlagCount)
    activeCount = tonumber(activeCount)
    if #active == 1 and not (rawCount and activeCount and rawCount > activeCount) then
        return self:RememberCTFFlagObjectFaction(mapID, index, active[1], "message")
    end

    -- If both flags are away and one API slot was already proven, the other
    -- visible flag must be the opposite active flag. This is safer than a raw
    -- slot-number fallback after a drop/re-pickup because Blizzard can reorder
    -- the flag-position slots.
    if #active == 2 then
        local activeSet = {}
        for _, faction in ipairs(active) do activeSet[faction] = true end

        local mapPrefix = tostring(tonumber(mapID) or mapID or "unknown") .. ":"
        local currentKey = GetCTFSlotLockKey(mapID, index)
        local used = {}
        local cache = self.ctfFlagFactionByIndex
        if type(cache) == "table" then
            local now = Now()
            for key, record in pairs(cache) do
                if tostring(key):sub(1, #mapPrefix) == mapPrefix and key ~= currentKey then
                    if type(record) == "table" and (not record.expires or record.expires > now) then
                        local faction = NormalizeObjectiveKey(record.faction)
                        if activeSet[faction] then used[faction] = true end
                    else
                        cache[key] = nil
                    end
                end
            end
        end

        if used.alliance and not used.horde and activeSet.horde then
            return self:RememberCTFFlagObjectFaction(mapID, index, "horde", "complementary-message")
        elseif used.horde and not used.alliance and activeSet.alliance then
            return self:RememberCTFFlagObjectFaction(mapID, index, "alliance", "complementary-message")
        end
    end

    -- When both flags are away, do not assign faction by index here. The main
    -- resolver still has token/texture/state sources before any final fallback.
    return nil
end

function Pins:GetRecentEotSCarriedFlagFaction(mapID)
    if tonumber(mapID) ~= 210 then return nil end
    local record = self.eotsCarriedFlagFactionRecord
    if type(record) ~= "table" then return nil end

    local now = Now()
    if record.expires and record.expires <= now then
        self.eotsCarriedFlagFactionRecord = nil
        return nil
    end

    local faction = NormalizeObjectiveKey(record.faction)
    if faction == "alliance" or faction == "horde" then
        return faction
    end
    return nil
end

function Pins:ResolveCarriedObjectiveFaction(mapID, texture, explicitState, index, x, y, alternateTexture)
    if IsCTF(mapID) then
        local activeCount = tonumber(self and self.BattleMapsActiveCarriedFlagCount)

        -- A colour-specific battleground message identifies the *flag object*
        -- directly ("Alliance Flag" / "Horde Flag"). After a drop/re-pick,
        -- Blizzard can compact/reorder its flag slots before the legacy token
        -- catches up. Prefer the validated message/slot lock first so a stale
        -- token cannot immediately recreate the opposite-faction assignment.
        -- GetLockedCTFFlagObjectFaction deliberately declines the one-active
        -- shortcut when hidden raw slots make that inference unsafe.
        local lockedFaction = self:GetLockedCTFFlagObjectFaction(mapID, index, activeCount)
        if lockedFaction then return lockedFaction end

        -- The legacy token remains the strongest API-side identity when there
        -- is no unambiguous recent message assignment.
        local tokenFaction = Private.InferCTFFlagObjectFactionFromToken
            and Private.InferCTFFlagObjectFactionFromToken(alternateTexture)
        if tokenFaction then
            return self:RememberCTFFlagObjectFaction(mapID, index, tokenFaction, "legacy-token")
        end

        -- If both CTF flags are now away, preserve whatever this API slot was
        -- first proven to be. Without this lock, the second pickup can cause the
        -- first carried flag to be recoloured from the object faction to the
        -- carrier/team colour.
        local rememberedFaction = self:GetRememberedCTFFlagObjectFaction(mapID, index)
        if activeCount and activeCount >= 2 and rememberedFaction then
            return rememberedFaction
        end

        local textureFaction = Private.InferCarriedFlagFactionFromText
            and Private.InferCarriedFlagFactionFromText(texture)
        if textureFaction then
            return self:RememberCTFFlagObjectFaction(mapID, index, textureFaction, "texture")
        end

        if Private.GetStableFactionFromState then
            local explicitFaction = Private.GetStableFactionFromState(explicitState)
            if explicitFaction then
                return self:RememberCTFFlagObjectFaction(mapID, index, explicitFaction, "state")
            end
            if Private.InferObjectiveState then
                local inferredFaction = Private.GetStableFactionFromState(Private.InferObjectiveState(texture, alternateTexture))
                if inferredFaction then
                    return self:RememberCTFFlagObjectFaction(mapID, index, inferredFaction, "inferred-state")
                end
            end
        end

        if rememberedFaction then return rememberedFaction end

        if activeCount and activeCount >= 2 and Private.GetFallbackCTFFlagFactionByIndex then
            local fallbackFaction = Private.GetFallbackCTFFlagFactionByIndex(mapID, index)
            if fallbackFaction then
                return self:RememberCTFFlagObjectFaction(mapID, index, fallbackFaction, "slot-fallback")
            end
        end
        return nil
    end

    local textureFaction = Private.InferCarriedFlagFactionFromText
        and Private.InferCarriedFlagFactionFromText(texture, alternateTexture)
    if textureFaction then return textureFaction end

    if Private.GetStableFactionFromState then
        local explicitFaction = Private.GetStableFactionFromState(explicitState)
        if explicitFaction then return explicitFaction end
        if Private.InferObjectiveState then
            local inferredFaction = Private.GetStableFactionFromState(Private.InferObjectiveState(texture, alternateTexture))
            if inferredFaction then return inferredFaction end
        end
    end

    if self.GetRecentCarriedObjectiveFaction then
        return self:GetRecentCarriedObjectiveFaction(mapID)
    end
    return nil
end



-- Seething Shore Azerite state --------------------------------------------

local SEETHING_AZERITE_PIN_COLLECTIONS = {
    "poiPins",
    "scenarioPins",
    "vignettePins",
    "fallbackObjectivePins",
}
local SEETHING_AZERITE_LIVE_FRAME_LEVEL_OFFSET = 34
local SEETHING_AZERITE_CUSTOM_VISUAL_SIZE = 16
local SEETHING_AZERITE_SPAWN_DURATION = 40

local function IsSeethingShoreMapID(mapID)
    if Rules.IsSeethingShoreMap then
        local ok, result = pcall(Rules.IsSeethingShoreMap, mapID)
        if ok then return result == true end
    end
    mapID = tonumber(mapID)
    return mapID == 907 or mapID == 1803
end

local function GetSeethingPinPosition(pin)
    if not pin then return nil, nil end
    return tonumber(pin.mapX or pin.BattleMapsMapX or pin.x),
        tonumber(pin.mapY or pin.BattleMapsMapY or pin.y)
end

local function GetSeethingAzeriteTexturePaths(mapID)
    local folderID = Rules.GetObjectiveTextureFolderID
        and Rules.GetObjectiveTextureFolderID(mapID)
        or 907
    local folder = string.format(
        "Interface\\AddOns\\BattleMaps\\Media\\Objectives\\%s\\stationary\\",
        tostring(folderID or 907)
    )
    return folder .. "azerite_N.tga", folder .. "azerite_spawning_N.tga"
end

local function GetSeethingAzeriteNow()
    return type(GetTime) == "function" and GetTime() or 0
end

local function PrepareSeethingAzeriteTiming(pins, record)
    if not pins or type(record) ~= "table" then return record end
    -- Synthetic Test-mode records already provide their exact independent
    -- duration/start/expiry values. Do not merge them into the live POI cache.
    if record.testPreview == true then return record end

    pins.seethingAzeriteTimingByPOI = pins.seethingAzeriteTimingByPOI or {}
    -- Vignette IDs are replaced when a geyser becomes a ready node. Key the
    -- local timer by physical spawn location so repeated refreshes and the
    -- spawning->ready transition refer to the same objective.
    local rx, ry = tonumber(record.x), tonumber(record.y)
    local key
    if rx and ry then
        key = tostring(math.floor((rx * 1000) + 0.5))
            .. ":" .. tostring(math.floor((ry * 1000) + 0.5))
    else
        key = tostring(tonumber(record.areaPoiID) or record.areaPoiID or "unknown")
    end
    local timing = pins.seethingAzeriteTimingByPOI[key]
    local now = GetSeethingAzeriteNow()
    local secondsLeft = tonumber(record.secondsLeft)

    if record.state == "spawning" and secondsLeft and secondsLeft > 0 then
        local knownDuration = math.max(
            tonumber(pins.seethingAzeriteKnownSpawnDuration) or 0,
            secondsLeft
        )
        local newCycle = type(timing) ~= "table"
            or timing.state ~= "spawning"
            or secondsLeft > ((tonumber(timing.lastSeconds) or 0) + 1.5)

        if newCycle then
            local duration = math.max(knownDuration, secondsLeft, 1)
            timing = {
                state = "spawning",
                duration = duration,
                startedAt = now - math.max(duration - secondsLeft, 0),
                expiresAt = now + secondsLeft,
                lastSeconds = secondsLeft,
            }
            pins.seethingAzeriteTimingByPOI[key] = timing
        else
            timing.duration = math.max(tonumber(timing.duration) or 0, knownDuration, secondsLeft, 1)
            local observedExpiresAt = now + secondsLeft
            if not timing.expiresAt
                or math.abs(observedExpiresAt - timing.expiresAt) > 1.25 then
                timing.expiresAt = observedExpiresAt
            end
            timing.startedAt = timing.expiresAt - timing.duration
            timing.lastSeconds = secondsLeft
        end

        pins.seethingAzeriteKnownSpawnDuration = math.max(
            tonumber(pins.seethingAzeriteKnownSpawnDuration) or 0,
            tonumber(timing.duration) or secondsLeft,
            secondsLeft
        )
        record.duration = timing.duration
        record.startedAt = timing.startedAt
        record.expiresAt = timing.expiresAt
    elseif record.state == "spawning" then
        -- Current Seething Shore vignettes expose the spawn state but no timer
        -- or widget set. Anchor a local countdown when AzeriteSpawning first
        -- appears. Blizzard's geyser period is 40 seconds; the atlas transition
        -- to AzeriteReady remains authoritative for the actual completion.
        if type(timing) ~= "table" or timing.state ~= "spawning" then
            local duration = record.isVignette == true
                and SEETHING_AZERITE_SPAWN_DURATION
                or math.max(tonumber(pins.seethingAzeriteKnownSpawnDuration) or 0,
                    SEETHING_AZERITE_SPAWN_DURATION)
            timing = {
                state = "spawning",
                duration = duration,
                startedAt = now,
                expiresAt = now + duration,
                lastSeconds = duration,
            }
            pins.seethingAzeriteTimingByPOI[key] = timing
        end

        local estimatedSeconds = math.max((tonumber(timing.expiresAt) or now) - now, 0)
        timing.lastSeconds = estimatedSeconds
        record.secondsLeft = estimatedSeconds
        record.duration = tonumber(timing.duration) or SEETHING_AZERITE_SPAWN_DURATION
        record.startedAt = tonumber(timing.startedAt) or now
        record.expiresAt = tonumber(timing.expiresAt) or now
        pins.seethingAzeriteKnownSpawnDuration = math.max(
            tonumber(pins.seethingAzeriteKnownSpawnDuration) or 0,
            tonumber(record.duration) or 0
        )
    elseif record.state ~= "spawning" then
        if type(timing) == "table" and tonumber(timing.duration) then
            pins.seethingAzeriteKnownSpawnDuration = math.max(
                tonumber(pins.seethingAzeriteKnownSpawnDuration) or 0,
                tonumber(timing.duration) or 0
            )
        end
        pins.seethingAzeriteTimingByPOI[key] = nil
    end
    return record
end

local function SeethingRecordPriority(record)
    if not record then return 0 end
    if record.state == "active" then return 3 end
    if record.state == "spawning" then return 2 end
    return 1
end

local function GetSeethingAzeriteLocationKey(record)
    if type(record) ~= "table" then return nil end
    local x, y = tonumber(record.x), tonumber(record.y)
    if not x or not y then return nil end
    -- Key by physical spawn location rather than POI ID. Blizzard may replace a
    -- timed spawn POI with a different active POI at the same map coordinate.
    return tostring(math.floor((x * 1000) + 0.5))
        .. ":" .. tostring(math.floor((y * 1000) + 0.5))
end

local function GetSeethingAzeriteVisualSize(pins, mapID)
    local config = BattleMaps.Database and BattleMaps.Database.GetBasePinConfig
        and BattleMaps.Database:GetBasePinConfig(mapID)
        or {}
    local scale = BattleMaps.Clamp(tonumber(config.objectivePinScale) or 1, 0.50, 2.50)
    local zoomScale = pins and pins.GetPinZoomScale and pins:GetPinZoomScale() or 1
    return BattleMaps.Clamp(
        SEETHING_AZERITE_CUSTOM_VISUAL_SIZE * scale * zoomScale,
        8,
        128
    )
end

local function AcquireSeethingAzeriteLivePin(pins, key)
    if not pins or not key or not Private.CreateTexturePin or not pins.parent then
        return nil
    end

    pins.seethingAzeriteLivePinsByKey = pins.seethingAzeriteLivePinsByKey or {}
    pins.seethingAzeriteLivePins = pins.seethingAzeriteLivePins or {}
    local pin = pins.seethingAzeriteLivePinsByKey[key]
    if pin then return pin end

    pin = Private.CreateTexturePin(pins.parent, 24, 24)
    if not pin then return nil end
    pin.BattleMapsSyntheticSeethingAzerite = true
    if pins.parent and pin.SetFrameLevel then
        pin:SetFrameLevel(
            pins.parent:GetFrameLevel() + SEETHING_AZERITE_LIVE_FRAME_LEVEL_OFFSET
        )
    end
    if pins.InstallTooltip then pins:InstallTooltip(pin) end
    pin:Hide()

    pins.seethingAzeriteLivePinsByKey[key] = pin
    pins.seethingAzeriteLivePins[#pins.seethingAzeriteLivePins + 1] = pin
    return pin
end

local function SuppressSeethingShoreProviderPins(pins)
    if not pins then return end
    for _, collectionName in ipairs(SEETHING_AZERITE_PIN_COLLECTIONS) do
        local collection = pins[collectionName]
        if type(collection) == "table" then
            for _, pin in ipairs(collection) do
                if pin and not pin.BattleMapsSyntheticSeethingAzerite then
                    if pin.BattleMapsSeethingProviderSuppressed ~= true then
                        pin.BattleMapsSeethingProviderSuppressed = true
                        if pin.IsShown then
                            pin.BattleMapsSeethingProviderWasShown = pin:IsShown() == true
                        end
                    end
                    if pin.Hide then pin:Hide() end
                end
            end
        end
    end
end

local function RestoreSeethingShoreProviderPins(pins)
    if not pins then return end
    for _, collectionName in ipairs(SEETHING_AZERITE_PIN_COLLECTIONS) do
        local collection = pins[collectionName]
        if type(collection) == "table" then
            for _, pin in ipairs(collection) do
                if pin and pin.BattleMapsSeethingProviderSuppressed == true then
                    local wasShown = pin.BattleMapsSeethingProviderWasShown == true
                    pin.BattleMapsSeethingProviderSuppressed = nil
                    pin.BattleMapsSeethingProviderWasShown = nil
                    -- Provider collections are normally rebuilt immediately on a
                    -- map change. Restore only pins that BattleMaps hid while they
                    -- were visible, avoiding activation of dormant provider pins.
                    if wasShown and pin.Show then pin:Show() end
                end
            end
        end
    end
end

local function HideSeethingAzeriteLivePins(pins)
    if not pins then return end
    for _, pin in ipairs(pins.seethingAzeriteLivePins or {}) do
        if pin then
            if pins.ClearSeethingShoreAzeriteTimer then
                pins:ClearSeethingShoreAzeriteTimer(pin)
            end
            pin.BattleMapsSeethingAzerite = nil
            pin.BattleMapsSeethingAzeritePOIID = nil
            pin.BattleMapsSeethingAzeriteState = nil
            pin.BattleMapsSeethingAzeriteSecondsLeft = nil
            pin:Hide()
        end
    end
end

local function ApplySeethingAzeriteRecord(pins, pin, mapID, record, activeTexturePath, spawningTexturePath)
    if not pins or not pin or not record then return false end
    PrepareSeethingAzeriteTiming(pins, record)

    pin.BattleMapsSeethingAzerite = true
    pin.BattleMapsSeethingAzeritePOIID = record.areaPoiID
    pin.BattleMapsSeethingAzeriteState = record.state
    pin.BattleMapsSeethingAzeriteSecondsLeft = record.secondsLeft

    if record.state == "dormant" then
        if pin.IsShown and pin:IsShown() then
            pin.BattleMapsHiddenForDormantAzerite = true
            pin:Hide()
        end
        if pins.ClearSeethingShoreAzeriteTimer then
            pins:ClearSeethingShoreAzeriteTimer(pin)
        end
        return true
    end

    local visibleTexturePath = record.state == "spawning"
        and (spawningTexturePath or activeTexturePath)
        or activeTexturePath
    if visibleTexturePath and pin.texture then
        if pin.texture.SetAtlas then pcall(pin.texture.SetAtlas, pin.texture, nil) end
        pin.texture:SetTexture(visibleTexturePath)
        pin.texture:SetTexCoord(0, 1, 0, 1)
        pin.texture:SetVertexColor(1, 1, 1, 1)
        pin.texture:SetAlpha(1)
        if pin.texture.SetDesaturated then pin.texture:SetDesaturated(false) end
        if pin.texture.SetRotation then pin.texture:SetRotation(0) end
        pin.BattleMapsObjectiveTexturePath = visibleTexturePath
    end

    if pin.BattleMapsHiddenForDormantAzerite then
        pin.BattleMapsHiddenForDormantAzerite = nil
    end
    if pin.Show then pin:Show() end

    if pins.UpdateSeethingShoreAzeriteTimer then
        pins:UpdateSeethingShoreAzeriteTimer(
            pin,
            record,
            activeTexturePath,
            spawningTexturePath
        )
    end
    if record.state ~= "spawning" and pins.SetTooltip then
        pins:SetTooltip(pin, "Azerite", record.description or "Available")
    end
    return true
end

function Pins:ApplySeethingShoreAzeriteRecord(pin, mapID, record)
    if not pin or type(record) ~= "table" then return false end
    local activeTexturePath, spawningTexturePath = GetSeethingAzeriteTexturePaths(mapID)
    return ApplySeethingAzeriteRecord(
        self,
        pin,
        mapID,
        record,
        activeTexturePath,
        spawningTexturePath
    )
end

function Pins:ClearSeethingShoreAzeriteState()
    HideSeethingAzeriteLivePins(self)
    RestoreSeethingShoreProviderPins(self)
    if type(self.seethingAzeriteTimingByPOI) == "table" then
        wipe(self.seethingAzeriteTimingByPOI)
    end
end

function Pins:RefreshSeethingShoreAzeriteState(mapID)
    mapID = tonumber(mapID)
        or tonumber(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local mapFrame = BattleMaps.MapFrame
    if not IsSeethingShoreMapID(mapID)
        or type(Rules.GetSeethingShoreAzeritePOIs) ~= "function" then
        self:ClearSeethingShoreAzeriteState()
        if self.seethingAzeriteController then self.seethingAzeriteController:Hide() end
        return false
    end

    -- Test mode owns dummy stationary pins. Never mix the live synthetic pool
    -- into the preview renderer.
    if mapFrame and mapFrame.testMode == true and not BattleMaps.IsInLiveBattleground() then
        HideSeethingAzeriteLivePins(self)
        return false
    end

    local records = Rules.GetSeethingShoreAzeritePOIs(mapID)
    local activeTexturePath, spawningTexturePath = GetSeethingAzeriteTexturePaths(mapID)
    local bestByLocation = {}

    -- The event and ordinary AreaPOI providers can expose two records for the
    -- same spawn position while the state changes. Prefer spawning over active,
    -- then the closest/latest record for a stable one-pin-per-location renderer.
    for _, record in ipairs(records) do
        local key = GetSeethingAzeriteLocationKey(record)
        if key then
            local existing = bestByLocation[key]
            if not existing
                or SeethingRecordPriority(record) > SeethingRecordPriority(existing)
                or (SeethingRecordPriority(record) == SeethingRecordPriority(existing)
                    and tonumber(record.secondsLeft)
                    and not tonumber(existing.secondsLeft)) then
                bestByLocation[key] = record
            end
        end
    end

    -- Render BattleMaps-owned pins first. Blizzard provider pins are hidden
    -- only after at least one custom live Azerite pin was successfully created.
    -- This prevents transient or changed API responses from producing a blank map.
    local usedKeys = {}
    local size = GetSeethingAzeriteVisualSize(self, mapID)
    local config = BattleMaps.Database and BattleMaps.Database.GetBasePinConfig
        and BattleMaps.Database:GetBasePinConfig(mapID)
        or {}
    local alpha = BattleMaps.Clamp(tonumber(config.objectivePinAlpha) or 1, 0.15, 1)
    local changed = false
    local rendered = 0

    for key, record in pairs(bestByLocation) do
        if record.state ~= "dormant" then
            local pin = AcquireSeethingAzeriteLivePin(self, key)
            if pin then
                usedKeys[key] = true
                pin:SetSize(size, size)
                pin:SetAlpha(alpha)
                if self.Place then self:Place(pin, record.x, record.y) end
                if ApplySeethingAzeriteRecord(
                    self,
                    pin,
                    mapID,
                    record,
                    activeTexturePath,
                    spawningTexturePath
                ) then
                    changed = true
                    rendered = rendered + 1
                end
            end
        end
    end

    if rendered > 0 then
        SuppressSeethingShoreProviderPins(self)
    else
        -- Keep Blizzard's provider output available when no custom live records
        -- can be resolved. Test mode remains unaffected and uses preview pins.
        RestoreSeethingShoreProviderPins(self)
    end

    for key, pin in pairs(self.seethingAzeriteLivePinsByKey or {}) do
        if pin and not usedKeys[key] then
            if self.ClearSeethingShoreAzeriteTimer then
                self:ClearSeethingShoreAzeriteTimer(pin)
            end
            pin.BattleMapsSeethingAzerite = nil
            pin.BattleMapsSeethingAzeritePOIID = nil
            pin.BattleMapsSeethingAzeriteState = nil
            pin.BattleMapsSeethingAzeriteSecondsLeft = nil
            pin:Hide()
        end
    end

    if self.EnsureSeethingShoreAzeriteController then
        self:EnsureSeethingShoreAzeriteController():Show()
    end
    return changed
end

local function InstallSeethingShorePOIRefreshGuard()
    if Pins.BattleMapsSeethingShorePOIRefreshGuardInstalled then return true end
    local originalRefreshPOIs = Pins.RefreshPOIs
    if type(originalRefreshPOIs) ~= "function" then return false end

    Pins.BattleMapsSeethingShorePOIRefreshGuardInstalled = true
    Pins.RefreshPOIs = function(self, ...)
        local results = { originalRefreshPOIs(self, ...) }
        local mapID = tonumber(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
        if IsSeethingShoreMapID(mapID) then
            self:RefreshSeethingShoreAzeriteState(mapID)
        elseif self.seethingAzeriteController and self.seethingAzeriteController:IsShown() then
            self.seethingAzeriteController:Hide()
            self:ClearSeethingShoreAzeriteState()
        end
        return unpack(results)
    end
    return true
end

-- PreviewPins.lua creates stationary Test-mode pins after this module loads.
-- Reapply the quadrant-derived Temple orb identities after every legacy dummy
-- refresh so test mode uses the same custom purple/orange/green/blue assets as
-- the live stationary renderer instead of the fallback POI artwork.
local function InstallTempleOrbPreviewRefreshGuard()
    if Pins.BattleMapsTempleOrbPreviewRefreshGuardInstalled then return true end
    local originalRefreshDummyPins = Pins.RefreshDummyPins
    if type(originalRefreshDummyPins) ~= "function" then return false end

    Pins.BattleMapsTempleOrbPreviewRefreshGuardInstalled = true
    Pins.RefreshDummyPins = function(self, ...)
        originalRefreshDummyPins(self, ...)

        local mapFrame = BattleMaps.MapFrame
        local mapID = tonumber(mapFrame and (mapFrame.currentMapID or mapFrame.selectedMapID))
        if mapFrame and mapFrame.testMode == true
            and Rules.IsTempleOfKotmoguMap
            and Rules.IsTempleOfKotmoguMap(mapID)
            and self.ApplyTempleOrbStationaryState then
            self:ApplyTempleOrbStationaryState(mapID)
        end
    end
    return true
end

if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
        if not InstallTempleOrbPreviewRefreshGuard() then
            C_Timer.After(0.10, InstallTempleOrbPreviewRefreshGuard)
        end
        if not InstallSeethingShorePOIRefreshGuard() then
            C_Timer.After(0.10, InstallSeethingShorePOIRefreshGuard)
        end
    end)
else
    InstallTempleOrbPreviewRefreshGuard()
    InstallSeethingShorePOIRefreshGuard()
end
