local _, BattleMaps = ...

local Pins = BattleMaps.Pins
if not Pins then return end

-- Unit pin artwork. Keep these paths in sync with Pins.lua defaults.
local RAID_PIN_TEXTURE = "WhiteCircle-RaidBlips"
local PARTY_PIN_TEXTURE = "WhiteDotCircle-RaidBlips"

-- Layered team-pin family. The border and healer glyph remain untinted while
-- Blizzard applies class colour only to the fill layer.
local CUSTOM_TEAM_BORDER_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\team_border.tga"
local CUSTOM_TEAM_FILL_DOT_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\team_fill_dot.tga"
local CUSTOM_TEAM_FILL_WHITE_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\team_fill_white.tga"
local CUSTOM_HEALER_FILL_WHITE_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\healer_fill_white.tga"
local CUSTOM_HEALER_CROSS_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\healer_cross.tga"
local CUSTOM_HEALER_COMBAT_CROSS_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\healer_cross_combat.tga"

-- Previous single-layer media remain as graceful fallbacks while users replace
-- files or when one of the new layered assets is absent.
local CUSTOM_TEAM_PIN_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\team_circle_dot.tga"
local CUSTOM_TEAM_COMBAT_PIN_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\team_circle_white.tga"
local CUSTOM_HEALER_PIN_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\healer.tga"

local DEFAULT_PLAYER_ARROW_TEXTURE = "UI-WorldMapArrow"
local CUSTOM_PLAYER_ARROW_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\player_arrow.tga"
local CUSTOM_PLAYER_COMPASS_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\player_compass.tga"
local PLAYER_FOV_STYLES = {
    soft = {
        under = {
            texture = "Interface\\AddOns\\BattleMaps\\Media\\fov_soft.tga",
            blendMode = "BLEND",
            aspect = 1,
        },
    },
    waves = {
        under = {
            texture = "Interface\\AddOns\\BattleMaps\\Media\\fov_waves.tga",
            blendMode = "BLEND",
            aspect = 1,
        },
    },
    spotlight = {
        under = {
            texture = "Interface\\AddOns\\BattleMaps\\Media\\fov_spotlight.tga",
            blendMode = "BLEND",
            aspect = 1,
            alphaSetting = "playerFovSpotlightAlpha",
        },
        arc = {
            texture = "Interface\\AddOns\\BattleMaps\\Media\\fov_arc.tga",
            blendMode = "ADD",
            aspect = 1,
            alphaSetting = "playerFovArcAlpha",
        },
        beam = {
            texture = "Interface\\AddOns\\BattleMaps\\Media\\fov_beam.tga",
            blendMode = "ADD",
            aspect = 1,
            alphaSetting = "playerFovBeamAlpha",
        },
    },
}
local PLAYER_FOV_LAYER_ORDER = { "under", "arc", "beam" }

local PLAYER_FOV_SUBLEVEL = 1
local PLAYER_PIN_SUBLEVEL = 5
local TEAM_BORDER_SUBLEVEL = 7
local GROUP_PIN_SUBLEVEL = 8
local HEALER_OVERLAY_SUBLEVEL = 9
local TEAM_SPEC_ICON_SUBLEVEL = 10

-- Global frame ordering keeps all black backplates below all class-coloured
-- fills. Normally the player arrow sits above the complete teammate stack. When
-- "Exclude player arrow" is enabled, it moves beneath the teammate layers so
-- deliberately overlapping pins remain readable.
-- FoV passes use dedicated under-map, above-map, and pin-layer parents. Beam
-- sits above the complete team-pin stack; the normal player marker remains
-- above it, while Exclude player pin retains its intentional behind-team rule.
local PLAYER_FOV_FRAME_LEVEL_OFFSET = 57
local PLAYER_FOV_BEAM_FRAME_LEVEL_OFFSET = 67
local PLAYER_BEHIND_TEAM_FRAME_LEVEL_OFFSET = 58
local TEAM_BORDER_FRAME_LEVEL_OFFSET = 59
local UNIT_FRAME_LEVEL_OFFSET = 60
local HEALER_OVERLAY_FRAME_LEVEL_OFFSET = 61
local TEAM_STACK_BORDER_FRAME_LEVEL_OFFSET = 62
local TEAM_STACK_UNIT_FRAME_LEVEL_OFFSET = 63
local TEAM_STACK_HEALER_OVERLAY_FRAME_LEVEL_OFFSET = 64
local TEAM_SPEC_ICON_FRAME_LEVEL_OFFSET = 65
local TEAM_STACK_SPEC_ICON_FRAME_LEVEL_OFFSET = 66
local TEAM_STACK_FRAME_LEVEL_OFFSET = 63
local PLAYER_FRAME_LEVEL_OFFSET = 69
local PLAYER_TEAM_BORDER_FRAME_LEVEL_OFFSET = 68
local TEAM_DEATH_MARKER_FRAME_LEVEL_OFFSET = 68
local MAX_TEAM_STACK_UNIT_FRAMES = 16
local TEAM_DEATH_MARKER_DURATION = 10.00
local TEAM_STATE_POLL_INTERVAL = 0.15
local TEAM_TOOLTIP_POLL_INTERVAL = 0.02
local TEAM_SPEC_INSPECT_INTERVAL = 0.75
local PLAYER_FOV_BASE_SIZE = 96
-- These values use the visible alpha bounds of the shipped artwork rather
-- than its source canvas dimensions. Arrow occupies about 58% of its canvas
-- by geometric footprint and Compass about 40%, so this correction keeps both
-- footprints comparable at the same Player-pin size setting. Team Pin uses
-- the Team members setting and the exact same layered metrics as teammates.
local PLAYER_COMPASS_RENDER_SCALE = 1.47

local GetUnitStackSlot

local function ConfigureTeamTooltipHitTesting(frame, enabled)
    -- UnitPositionFrame mouse configuration is secure-sensitive on current
    -- clients. Calling SetMouseMotionEnabled, SetMouseClickEnabled, or either
    -- SetPropagateMouse* method can taint Blizzard's Area POI acquisition path
    -- and later produce ADDON_ACTION_BLOCKED from native map code.
    --
    -- BattleMaps therefore leaves every UnitPositionFrame mouse-disabled and
    -- only performs tooltip hit testing against ordinary BattleMaps-owned pin
    -- frames whose final coordinates are available to Lua.
    -- Deliberately no-op. Existing call sites remain as renderer-state
    -- documentation without mutating the secure frame.
end

local function GetHighestExistingRaidUnit()
    -- Instance battleground groups use raid unit tokens even when the player
    -- also belongs to a five-person home party. Probe the actual unit tokens so
    -- an uncategorized GetNumGroupMembers() result cannot truncate the visible
    -- battleground roster to that home party.
    local highest = 0
    if type(UnitExists) ~= "function" then return highest end
    for index = 1, 40 do
        local ok, exists = pcall(UnitExists, "raid" .. index)
        if ok and exists then highest = index end
    end
    return highest
end

local function GetCategoryRosterSource(category)
    if category == nil then return nil, nil end

    if type(IsInRaid) == "function" then
        local ok, inRaid = pcall(IsInRaid, category)
        if ok and inRaid then
            local count = 0
            if type(GetNumGroupMembers) == "function" then
                local countOK, categoryCount = pcall(GetNumGroupMembers, category)
                if countOK then count = tonumber(categoryCount) or 0 end
            end
            count = math.max(count, GetHighestExistingRaidUnit())
            if count > 0 then return count, "raid" end
        end
    end

    if type(IsInGroup) == "function" then
        local ok, inGroup = pcall(IsInGroup, category)
        if ok and inGroup and type(GetNumSubgroupMembers) == "function" then
            local countOK, categoryCount = pcall(GetNumSubgroupMembers, category)
            local count = countOK and (tonumber(categoryCount) or 0) or 0
            if count > 0 then return count, "party" end
        end
    end

    return nil, nil
end

local function GetLiveGroupRosterSource(fallbackFrame)
    -- Battleground groups are instance-category groups. Query that category
    -- before the home category; otherwise a premade/home party can make the
    -- renderer see only five players while the battleground raid contains more.
    local memberCount, unitBase

    if LE_PARTY_CATEGORY_INSTANCE ~= nil then
        memberCount, unitBase = GetCategoryRosterSource(LE_PARTY_CATEGORY_INSTANCE)
        if memberCount and memberCount > 0 then return memberCount, unitBase end
    end

    -- Some client states expose raid tokens before the category APIs settle.
    -- The actual raid unit tokens are authoritative for which units AddUnit can
    -- render, so retain them as a direct fallback.
    local raidTokenCount = GetHighestExistingRaidUnit()
    if raidTokenCount > 0 then return raidTokenCount, "raid" end

    if LE_PARTY_CATEGORY_HOME ~= nil then
        memberCount, unitBase = GetCategoryRosterSource(LE_PARTY_CATEGORY_HOME)
        if memberCount and memberCount > 0 then return memberCount, unitBase end
    end

    -- Compatibility fallback for clients/API states without party categories.
    if type(IsInRaid) == "function" then
        local ok, inRaid = pcall(IsInRaid)
        if ok and inRaid then
            local count = 0
            if type(GetNumGroupMembers) == "function" then
                local countOK, groupCount = pcall(GetNumGroupMembers)
                if countOK then count = tonumber(groupCount) or 0 end
            end
            count = math.max(count, GetHighestExistingRaidUnit())
            if count > 0 then return count, "raid" end
        end
    end

    if type(GetNumSubgroupMembers) == "function" then
        local ok, count = pcall(GetNumSubgroupMembers)
        count = ok and tonumber(count) or 0
        if count and count > 0 then return count, "party" end
    end

    if fallbackFrame and type(fallbackFrame.GetMemberCountAndUnitTokenPrefix) == "function" then
        local ok, count, prefix = pcall(
            fallbackFrame.GetMemberCountAndUnitTokenPrefix,
            fallbackFrame
        )
        if ok then
            return tonumber(count) or 0, prefix or "raid"
        end
    end

    return 0, "raid"
end

function Pins:PrintTeamRosterDebug()
    local resolvedCount, resolvedPrefix = GetLiveGroupRosterSource(self.unitFrame)
    local existingRaidCount = GetHighestExistingRaidUnit()

    local function SafeCount(func, category)
        if type(func) ~= "function" then return 0 end
        local ok, value
        if category ~= nil then
            ok, value = pcall(func, category)
        else
            ok, value = pcall(func)
        end
        return ok and (tonumber(value) or 0) or 0
    end

    local instanceCount = LE_PARTY_CATEGORY_INSTANCE ~= nil
        and SafeCount(GetNumGroupMembers, LE_PARTY_CATEGORY_INSTANCE)
        or 0
    local homeCount = LE_PARTY_CATEGORY_HOME ~= nil
        and SafeCount(GetNumGroupMembers, LE_PARTY_CATEGORY_HOME)
        or 0
    local uncategorizedCount = SafeCount(GetNumGroupMembers)

    BattleMaps.Chat(string.format(
        "Team roster: resolved=%s%d, instance=%d, home=%d, uncategorized=%d, existing raid tokens=%d.",
        tostring(resolvedPrefix or "raid"),
        tonumber(resolvedCount) or 0,
        instanceCount,
        homeCount,
        uncategorizedCount,
        existingRaidCount
    ))
end

function Pins:PrintTeamStackDebug()
    local unitMapID = tonumber(self.unitMapID)
    local count, prefix = GetLiveGroupRosterSource(self.unitFrame)
    local readable, missing = 0, 0
    if unitMapID and count and count > 0 then
        for index = 1, count do
            local unit = (prefix or "raid") .. index
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                local x, y = self:GetTeamStackUnitMapPosition(unitMapID, unit)
                if x and y then readable = readable + 1 else missing = missing + 1 end
            end
        end
    end

    local mode = "native"
    if self.teamStackOverlayActive then
        mode = "precise"
    elseif self.teamStackRestrictedFallbackActive then
        mode = "restricted-separation"
    elseif missing > 0 then
        mode = "native-restricted"
    end
    BattleMaps.Chat(string.format(
        "Team stacking: roster=%s%d, readable=%d, restricted=%d, mode=%s, native=%s%s.",
        tostring(prefix or "raid"), tonumber(count) or 0, readable, missing, mode,
        self.nativeGroupPinsVisible == false and "hidden" or "shown",
        mode == "native-restricted" and ", stacking=suspended-for-accuracy" or ""
    ))
end

local TEAM_STACK_DIRECTIONS = {
    compact = true,
    diagonal = true,
    horizontal = true,
    vertical = true,
}

local COMPACT_STACK_OFFSETS = {
    {  0,  0 }, {  1,  0 }, {  0,  1 }, {  1,  1 },
    { -1,  0 }, {  0, -1 }, { -1, -1 }, {  1, -1 }, { -1,  1 },
    {  2,  0 }, {  0,  2 }, {  2,  1 }, {  1,  2 }, {  2,  2 },
    { -2,  0 }, {  0, -2 }, { -2, -1 }, { -1, -2 }, { -2, -2 },
    {  2, -1 }, {  1, -2 }, { -2,  1 }, { -1,  2 },
    {  3,  0 }, {  0,  3 }, {  3,  1 }, {  1,  3 }, {  3,  2 }, {  2,  3 }, {  3,  3 },
    { -3,  0 }, {  0, -3 }, { -3, -1 }, { -1, -3 }, { -3, -2 }, { -2, -3 }, { -3, -3 },
    {  3, -1 }, {  1, -3 }, { -3,  1 },
}

local TEAM_STACK_TEST_COLORS = {
    { 0.96, 0.55, 0.73 }, -- paladin
    { 0.25, 0.78, 0.92 }, -- shaman
    { 1.00, 0.49, 0.04 }, -- druid
    { 0.25, 0.78, 0.92 }, -- mage
    { 0.78, 0.61, 0.43 }, -- warrior
    { 0.41, 0.80, 0.94 }, -- monk
    { 0.58, 0.51, 0.79 }, -- warlock
    { 0.67, 0.83, 0.45 }, -- hunter
    { 1.00, 1.00, 1.00 }, -- priest
    { 1.00, 0.96, 0.41 }, -- rogue
}

local function GetTeamStackTestColor(index, classFile)
    if classFile then
        local r, g, b
        if type(GetClassColor) == "function" then
            local ok, cr, cg, cb = pcall(GetClassColor, classFile)
            if ok then r, g, b = cr, cg, cb end
        end
        if (not r or not g or not b) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
            local color = RAID_CLASS_COLORS[classFile]
            r, g, b = color.r, color.g, color.b
        end
        if r and g and b then return { r, g, b } end
    end
    return TEAM_STACK_TEST_COLORS[((tonumber(index) or 1) - 1) % #TEAM_STACK_TEST_COLORS + 1]
end

local TEAM_STACK_TEST_SPEC_IDS = {
    PALADIN = 65,  -- Holy
    SHAMAN = 264,  -- Restoration
    DRUID = 105,   -- Restoration
    WARRIOR = 71,  -- Arms
    ROGUE = 259,   -- Assassination
    MAGE = 63,     -- Fire
    WARLOCK = 267, -- Destruction
    EVOKER = 1468, -- Preservation
    HUNTER = 254,  -- Marksmanship
    MONK = 270,    -- Mistweaver
}

local TEAM_PIN_TEST_LAYOUTS = {
    -- Coordinates are normalized map fractions. They are visual-only and are
    -- chosen to put the preview near plausible objective fights rather than
    -- in a full-map grid.
    [112]  = { player = { 0.50, 0.56 }, primary = { 0.55, 0.45 } }, -- Arathi Basin
    [1366] = { player = { 0.50, 0.56 }, primary = { 0.55, 0.45 } }, -- Arathi Basin modern UI map ID
    [1576] = { player = { 0.49, 0.55 }, primary = { 0.53, 0.47 } }, -- Deepwind Gorge
    [275]  = { player = { 0.51, 0.52 }, primary = { 0.55, 0.41 } }, -- Battle for Gilneas
    [761]  = { player = { 0.51, 0.52 }, primary = { 0.55, 0.41 } },
    [210]  = { player = { 0.50, 0.53 }, primary = { 0.58, 0.47 } }, -- Eye of the Storm
    [417]  = { player = { 0.50, 0.58 }, primary = { 0.49, 0.43 } }, -- Temple of Kotmogu
    [423]  = { player = { 0.48, 0.55 }, primary = { 0.58, 0.47 } }, -- Silvershard Mines
    [206]  = { player = { 0.50, 0.58 }, primary = { 0.43, 0.49 } }, -- Warsong Gulch
    [726]  = { player = { 0.50, 0.58 }, primary = { 0.43, 0.49 } }, -- Twin Peaks, if used by API/config
    [2345] = { player = { 0.50, 0.55 }, primary = { 0.50, 0.45 } }, -- Deephaul Ravine
}

local DEFAULT_TEAM_PIN_TEST_LAYOUT = {
    player = { 0.50, 0.56 },
    primary = { 0.56, 0.46 },
}

local CUSTOM_UNIT_TEXTURES = {
    [CUSTOM_TEAM_BORDER_TEXTURE:lower():gsub("\\", "/")] = true,
    [CUSTOM_TEAM_FILL_DOT_TEXTURE:lower():gsub("\\", "/")] = true,
    [CUSTOM_TEAM_FILL_WHITE_TEXTURE:lower():gsub("\\", "/")] = true,
    [CUSTOM_HEALER_FILL_WHITE_TEXTURE:lower():gsub("\\", "/")] = true,
    [CUSTOM_HEALER_CROSS_TEXTURE:lower():gsub("\\", "/")] = true,
    [CUSTOM_HEALER_COMBAT_CROSS_TEXTURE:lower():gsub("\\", "/")] = true,
    [CUSTOM_TEAM_PIN_TEXTURE:lower():gsub("\\", "/")] = true,
    [CUSTOM_TEAM_COMBAT_PIN_TEXTURE:lower():gsub("\\", "/")] = true,
    [CUSTOM_HEALER_PIN_TEXTURE:lower():gsub("\\", "/")] = true,
}

local function IsBattleMapsCustomUnitTexture(texture)
    if not texture or type(texture.GetTexture) ~= "function" then return false end
    local value = texture:GetTexture()
    if type(value) ~= "string" then return false end
    value = value:lower():gsub("\\", "/")
    return CUSTOM_UNIT_TEXTURES[value] == true
end

local function NormalizeTextureRegion(region)
    if not IsBattleMapsCustomUnitTexture(region) then return end
    if region.SetRotation then region:SetRotation(0) end
    if region.SetTexCoord then region:SetTexCoord(0, 1, 0, 1) end
    if region.SetBlendMode then region:SetBlendMode("BLEND") end
end

function Pins:NormalizeUnitFrameCustomTextures(frame)
    if not frame then return end

    if type(frame.GetRegions) == "function" then
        for _, region in ipairs({ frame:GetRegions() }) do
            NormalizeTextureRegion(region)
        end
    end

    if type(frame.GetChildren) == "function" then
        for _, child in ipairs({ frame:GetChildren() }) do
            if type(child.GetRegions) == "function" then
                for _, region in ipairs({ child:GetRegions() }) do
                    NormalizeTextureRegion(region)
                end
            end
        end
    end
end

function Pins:ShouldUseLayeredTeamPins()
    return self:CustomTextureExists(CUSTOM_TEAM_BORDER_TEXTURE)
        and self:CustomTextureExists(CUSTOM_TEAM_FILL_DOT_TEXTURE)
end

function Pins:ShouldUseSplitHealerOverlay()
    return self:ShouldUseLayeredTeamPins()
        and self:CustomTextureExists(CUSTOM_HEALER_CROSS_TEXTURE)
end

function Pins:GetTeamFillTexture(inCombat, useSolidOutOfCombat, isHealer)
    -- Healers always use their dedicated dot-free fill. Combat state is shown
    -- by healer_cross_combat.tga, so the ordinary team combat/dot treatment must
    -- never be applied beneath a partially transparent healer glyph.
    if isHealer then
        return CUSTOM_HEALER_FILL_WHITE_TEXTURE
    end

    if not inCombat and useSolidOutOfCombat
        and self:CustomTextureExists(CUSTOM_TEAM_FILL_WHITE_TEXTURE) then
        return CUSTOM_TEAM_FILL_WHITE_TEXTURE
    end
    return CUSTOM_TEAM_FILL_DOT_TEXTURE
end

function Pins:ShouldUseCombatHealerTexture()
    -- The alternate healer artwork is now automatic: installing the file is the
    -- opt-in. No saved checkbox state is required.
    return self:CustomTextureExists(CUSTOM_HEALER_COMBAT_CROSS_TEXTURE)
end

function Pins:GetHealerOverlayTexture(inCombat)
    if self:ShouldUseSplitHealerOverlay() then
        if inCombat and self:ShouldUseCombatHealerTexture() then
            return CUSTOM_HEALER_COMBAT_CROSS_TEXTURE
        end
        return CUSTOM_HEALER_CROSS_TEXTURE
    end

    -- Do not fall back to the retired healer_dot.tga combat artwork. The
    -- single-layer fallback remains the normal healer icon.
    return CUSTOM_HEALER_PIN_TEXTURE
end

-- One texture family is used at every scale. The final rendered pin size drives
-- the relative layer sizes: small competitive pins expose a light border, while
-- larger/zoomed pins progressively expose more of the black backplate.
function Pins:GetTeamPinMetrics(displayedSize, healerSettingSize, baseTeamSize, playerSize)
    displayedSize = BattleMaps.Clamp(tonumber(displayedSize) or 12, 3, 128)
    baseTeamSize = BattleMaps.Clamp(tonumber(baseTeamSize) or displayedSize, 3, 128)

    -- Healer Size controls the glyph's ratio relative to the circular team
    -- pin. It is deliberately kept unzoomed; displayedSize already contains
    -- team-size and map-zoom scaling. Do not retain the old whole-pin minimum
    -- of 3/6 px here, which produced a hard lower limit at compact map sizes.
    healerSettingSize = BattleMaps.Clamp(
        tonumber(healerSettingSize) or 16,
        0.50,
        160
    )

    local zoomWeight = BattleMaps.Clamp((displayedSize - 10) / 14, 0, 1)

    -- The authored border and fill share a 64 px canvas. At small rendered
    -- sizes, enlarge the fill slightly so it overlaps more of the border's
    -- inner edge. At larger/zoomed sizes, reduce it slightly so the border
    -- gains visible weight without swapping texture families.
    local fillScale = 1.04 - (0.08 * zoomWeight)

    -- Healer Size is a relative glyph-control value, not an absolute rendered
    -- pixel size. A value of 16 is the neutral/default ratio. Do not divide by
    -- the current team-pin size here: doing so cancels the border-size factor
    -- below and leaves the cross nearly constant while team pins scale.
    local neutralHealerSetting = 16
    local healerControl = healerSettingSize / neutralHealerSetting
    healerControl = BattleMaps.Clamp(healerControl, 0.25, 3.00)

    -- healer_cross.tga is authored with an approximately 26 px glyph inside a
    -- 64 px canvas. Convert the desired visible glyph ratio into the texture
    -- frame size needed to produce it. Texture-frame scales below 1 are valid;
    -- preventing them was the source of the apparent minimum healer size.
    local healerArtFraction = 26 / 64
    local desiredVisibleHealerScale = BattleMaps.Clamp(
        (0.52 + (0.06 * zoomWeight)) * healerControl,
        0.16,
        0.82
    )
    local healerTextureScale = BattleMaps.Clamp(
        desiredVisibleHealerScale / healerArtFraction,
        0.38,
        2.05
    )

    local borderSize = displayedSize
    local fillSize = BattleMaps.Clamp(borderSize * fillScale, 3, 160)
    local healerSize = BattleMaps.Clamp(borderSize * healerTextureScale, 1, 192)
    local resolvedPlayerSize = BattleMaps.Clamp(tonumber(playerSize) or 22, 8, 256)

    return {
        borderSize = borderSize,
        fillSize = fillSize,
        healerSize = healerSize,
        collisionSize = borderSize,
        playerAvoidRadius = (resolvedPlayerSize * 0.46) + (borderSize * 0.50) + 2,
    }
end

function Pins:GetHealerOverlaySize(baseSize, healerSize, baseTeamSize)
    return self:GetTeamPinMetrics(baseSize, healerSize, baseTeamSize).healerSize
end

function Pins:BuildTeamPinAppearance(isHealer, inCombat, displayedSize, healerSettingSize, baseTeamSize, useSolidOutOfCombat, r, g, b, healerR, healerG, healerB, specIcon, specName)
    if self:ShouldUseLayeredTeamPins() then
        local metrics = self:GetTeamPinMetrics(displayedSize, healerSettingSize, baseTeamSize)
        return {
            kind = "team",
            layered = true,
            borderTexture = CUSTOM_TEAM_BORDER_TEXTURE,
            borderSize = metrics.borderSize,
            fillTexture = self:GetTeamFillTexture(inCombat, useSolidOutOfCombat, isHealer),
            fillSize = metrics.fillSize,
            healerTexture = isHealer and self:ShouldUseSplitHealerOverlay() and self:GetHealerOverlayTexture(inCombat) or nil,
            healerSize = metrics.healerSize,
            collisionSize = metrics.collisionSize,
            r = r or 1,
            g = g or 1,
            b = b or 1,
            healerR = healerR or 1,
            healerG = healerG or 1,
            healerB = healerB or 1,
            specIcon = specIcon,
            specName = specName,
        }
    end

    local texture
    local size = displayedSize
    if isHealer and self:CustomTextureExists(CUSTOM_HEALER_PIN_TEXTURE) then
        texture = self:GetHealerOverlayTexture(inCombat)
        size = healerSettingSize or displayedSize
    elseif self:CustomTextureExists(CUSTOM_TEAM_PIN_TEXTURE) then
        texture = (not inCombat) and useSolidOutOfCombat and CUSTOM_TEAM_COMBAT_PIN_TEXTURE or CUSTOM_TEAM_PIN_TEXTURE
    else
        texture = RAID_PIN_TEXTURE
    end

    local fillR, fillG, fillB = r or 1, g or 1, b or 1
    if isHealer and healerR and healerG and healerB then
        fillR, fillG, fillB = healerR, healerG, healerB
    end

    return {
        kind = "team",
        layered = false,
        fillTexture = texture,
        fillSize = size,
        collisionSize = size,
        r = fillR,
        g = fillG,
        b = fillB,
        healerR = healerR or fillR,
        healerG = healerG or fillG,
        healerB = healerB or fillB,
        specIcon = specIcon,
        specName = specName,
    }
end

function Pins:UpdateHealerOverlayFramePeriodic(frame)
    self:NormalizeUnitFrameCustomTextures(frame)
end

function Pins:PopulateHealerOverlayFrame(frame, timeNow, targetSlot, targetUnit)
    if not frame then return end
    frame:ClearUnits()

    if not self:ShouldUseSplitHealerOverlay() then
        frame:FinalizeUnits()
        frame.needsFullUpdate = false
        return
    end

    local unitFrame = self.unitFrame
    if not unitFrame then
        frame:FinalizeUnits()
        frame.needsFullUpdate = false
        return
    end

    local memberCount, unitBase = GetLiveGroupRosterSource(unitFrame)
    local normalSize = self.unitTeamSize or 12
    local healerSettingSize = self.unitHealerSize or 16
    local trackCombat = self:ShouldUseCombatHealerTexture()
    local pinConfig = BattleMaps.Database:GetUnitsConfig(
        self.unitConfigMapID or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    )

    for index = 1, memberCount do
        local unit = unitBase .. index
        if UnitExists(unit)
            and not UnitIsUnit(unit, "player")
            and (not targetUnit or UnitIsUnit(unit, targetUnit))
            and (not targetSlot or GetUnitStackSlot(unit) == targetSlot)
            and self:IsFriendlyHealer(unit) then
            local inCombat = trackCombat and self:IsUnitInCombat(unit) or false
            local metrics = self:GetTeamPinMetrics(normalSize, healerSettingSize, normalSize)
            local healerR, healerG, healerB = self:GetHealerIconColor(unit, timeNow, pinConfig)
            frame:AddUnit(
                unit,
                self:GetHealerOverlayTexture(inCombat),
                metrics.healerSize,
                metrics.healerSize,
                healerR, healerG, healerB, 1,
                HEALER_OVERLAY_SUBLEVEL,
                false
            )
        end
    end

    frame:FinalizeUnits()
    self:NormalizeUnitFrameCustomTextures(frame)
    frame.needsFullUpdate = false
end

function Pins:UpdateHealerOverlayFrameFull(frame, timeNow)
    self:PopulateHealerOverlayFrame(frame, timeNow, nil)
end

function Pins:UpdateTeamStackHealerOverlayFrameFull(frame, timeNow)
    local targetUnit = frame and frame.BattleMapsTargetUnit
    self:PopulateHealerOverlayFrame(
        frame,
        timeNow,
        targetUnit and nil or (tonumber(frame and frame.BattleMapsStackSlot) or 1),
        targetUnit
    )
end

function Pins:GetTeamSpecIconMetrics(teamSize)
    teamSize = BattleMaps.Clamp(tonumber(teamSize) or 12, 3, 128)
    local iconSize = BattleMaps.Clamp(teamSize * 0.78, 7, 28)
    local offsetX = (teamSize * 0.52) + (iconSize * 0.52) + 1
    return iconSize, offsetX
end

function Pins:UpdateTeamSpecIconFramePeriodic(frame)
    self:NormalizeUnitFrameCustomTextures(frame)
end

function Pins:PopulateTeamSpecIconFrame(frame, timeNow, targetSlot, targetUnit)
    if not frame then return end
    -- Specialization artwork belongs in the team-pin tooltip only. Keep the
    -- legacy UnitPositionFrame empty so upgraded profiles cannot render the
    -- previous side icons or Test-mode placeholder squares.
    frame:ClearUnits()
    frame:FinalizeUnits()
    frame.needsFullUpdate = false
end

function Pins:UpdateTeamSpecIconFrameFull(frame, timeNow)
    self:PopulateTeamSpecIconFrame(frame, timeNow, nil)
end

function Pins:UpdateTeamStackSpecIconFrameFull(frame, timeNow)
    local targetUnit = frame and frame.BattleMapsTargetUnit
    self:PopulateTeamSpecIconFrame(
        frame,
        timeNow,
        targetUnit and nil or (tonumber(frame and frame.BattleMapsStackSlot) or 1),
        targetUnit
    )
end

function Pins:UpdateTeamBorderFramePeriodic(frame)
    self:NormalizeUnitFrameCustomTextures(frame)
end

function Pins:PopulateTeamBorderFrame(frame, timeNow, targetSlot, targetUnit)
    if not frame then return end
    frame:ClearUnits()

    if not self:ShouldUseLayeredTeamPins() then
        frame:FinalizeUnits()
        frame.needsFullUpdate = false
        return
    end

    local unitFrame = self.unitFrame
    if not unitFrame then
        frame:FinalizeUnits()
        frame.needsFullUpdate = false
        return
    end

    local memberCount, unitBase = GetLiveGroupRosterSource(unitFrame)
    local normalSize = self.unitTeamSize or 12
    local healerSettingSize = self.unitHealerSize or 16
    local trackCombat = false

    for index = 1, memberCount do
        local unit = unitBase .. index
        if UnitExists(unit)
            and not UnitIsUnit(unit, "player")
            and (not targetUnit or UnitIsUnit(unit, targetUnit))
            and (not targetSlot or GetUnitStackSlot(unit) == targetSlot) then
            local inCombat = trackCombat and self:IsUnitInCombat(unit) or false
            local metrics = self:GetTeamPinMetrics(normalSize, healerSettingSize, normalSize)
            frame:AddUnit(
                unit,
                CUSTOM_TEAM_BORDER_TEXTURE,
                metrics.borderSize,
                metrics.borderSize,
                1, 1, 1, 1,
                TEAM_BORDER_SUBLEVEL,
                false
            )
        end
    end

    frame:FinalizeUnits()
    self:NormalizeUnitFrameCustomTextures(frame)
    frame.needsFullUpdate = false
end

function Pins:UpdateTeamBorderFrameFull(frame, timeNow)
    self:PopulateTeamBorderFrame(frame, timeNow, nil)
end

function Pins:UpdateTeamStackBorderFrameFull(frame, timeNow)
    local targetUnit = frame and frame.BattleMapsTargetUnit
    self:PopulateTeamBorderFrame(
        frame,
        timeNow,
        targetUnit and nil or (tonumber(frame and frame.BattleMapsStackSlot) or 1),
        targetUnit
    )
end

function Pins:UpdatePlayerFramePeriodic(frame)
    if not self:ShouldRenderLivePlayerPosition() then
        frame:SetUnitColor("player", 1, 1, 1, 0)
        return
    end
    local mapID = self.unitConfigMapID or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local pinConfig = BattleMaps.Database:GetUnitsConfig(mapID)
    if self:PlayerPinStyleUsesColor(pinConfig) then
        local r, g, b, mode = self:GetPlayerArrowColor()
        frame:SetUnitColor("player", r, g, b, 1)
        self.lastPlayerColorMode = mode
    else
        frame:SetUnitColor("player", 1, 1, 1, 1)
        self.lastPlayerColorMode = nil
    end
    self:NormalizeUnitFrameCustomTextures(frame)
end

function Pins:GetPlayerPinStyle(pinConfig)
    local style = pinConfig and pinConfig.playerPinStyle
    return ({
        default = true,
        arrow = true,
        compass = true,
        team = true,
    })[style] and style or "arrow"
end

function Pins:PlayerPinStyleUsesColor(pinConfig)
    local style = self:GetPlayerPinStyle(pinConfig)
    return style == "arrow" or style == "team"
end

function Pins:GetPlayerPinAppearance(pinConfig, playerSize, teamPinSize)
    local style = self:GetPlayerPinStyle(pinConfig)
    playerSize = BattleMaps.Clamp(tonumber(playerSize) or 22, 12, 256)

    if style == "compass" then
        local size = BattleMaps.Clamp(playerSize * PLAYER_COMPASS_RENDER_SCALE, 12, 384)
        return { style = style, texture = CUSTOM_PLAYER_COMPASS_TEXTURE, size = size, usesColor = false }
    end
    if style == "team" then
        local renderedSize = BattleMaps.Clamp(tonumber(teamPinSize) or playerSize, 3, 64)
        local metrics = self:GetTeamPinMetrics(renderedSize, 16, renderedSize)
        return {
            style = style,
            texture = self:GetTeamFillTexture(false, true, false),
            size = metrics.fillSize,
            borderTexture = CUSTOM_TEAM_BORDER_TEXTURE,
            borderSize = metrics.borderSize,
            usesColor = true,
        }
    end
    if style == "default" then
        return { style = style, texture = DEFAULT_PLAYER_ARROW_TEXTURE, size = playerSize, usesColor = false }
    end
    return { style = style, texture = CUSTOM_PLAYER_ARROW_TEXTURE, size = playerSize, usesColor = true }
end

function Pins:GetPlayerFovStyle(pinConfig)
    local style = pinConfig and pinConfig.playerFovStyle or "none"
    return PLAYER_FOV_STYLES[style] and style or "none"
end

function Pins:GetPlayerFovLayerAppearance(pinConfig, layer)
    local style = PLAYER_FOV_STYLES[self:GetPlayerFovStyle(pinConfig)]
    return style and style[layer] or nil
end

function Pins:GetPlayerFovSize(pinConfig, zoomScale)
    local scale = BattleMaps.Clamp(
        tonumber(pinConfig and pinConfig.playerFovScale) or 1.00,
        0.25,
        3.00
    )
    return BattleMaps.Clamp(PLAYER_FOV_BASE_SIZE * scale * (zoomScale or 1), 24, 1024)
end

function Pins:GetPlayerFovAlpha(pinConfig)
    return BattleMaps.Clamp(
        tonumber(pinConfig and pinConfig.playerFovAlpha) or 0.65,
        0.10,
        1.00
    )
end

function Pins:GetPlayerFovLayerAlpha(pinConfig, layer)
    local appearance = self:GetPlayerFovLayerAppearance(pinConfig, layer)
    if not appearance then return 0 end

    local multiplier = 1
    if appearance.alphaSetting then
        multiplier = BattleMaps.Clamp(
            tonumber(pinConfig and pinConfig[appearance.alphaSetting]) or 1,
            0,
            1
        )
    end
    return BattleMaps.Clamp(self:GetPlayerFovAlpha(pinConfig) * multiplier, 0, 1)
end

local function ConfigurePlayerFovTextureRegion(region, appearance)
    if not region or not appearance or type(region.GetTexture) ~= "function" then return end
    local texture = region:GetTexture()
    if type(texture) ~= "string" then return end
    if texture:lower():gsub("\\", "/") ~= appearance.texture:lower():gsub("\\", "/") then return end

    -- Do not touch rotation or texture coordinates here; UnitPositionFrame
    -- owns those values while following the player's facing.
    if region.SetBlendMode then region:SetBlendMode(appearance.blendMode or "BLEND") end
end

function Pins:ConfigurePlayerFovFrameTextures(frame, appearance)
    if not frame or not appearance then return end
    if type(frame.GetRegions) == "function" then
        for _, region in ipairs({ frame:GetRegions() }) do
            ConfigurePlayerFovTextureRegion(region, appearance)
        end
    end
    if type(frame.GetChildren) == "function" then
        for _, child in ipairs({ frame:GetChildren() }) do
            if type(child.GetRegions) == "function" then
                for _, region in ipairs({ child:GetRegions() }) do
                    ConfigurePlayerFovTextureRegion(region, appearance)
                end
            end
        end
    end
end

function Pins:ShouldRenderLivePlayerPosition()
    -- BattleMaps only presents the real character position while the player is
    -- actually inside a battleground. Preview and Test Mode provide their own
    -- fixed-position player marker instead.
    return BattleMaps.IsInLiveBattleground() == true
end

function Pins:GetPlayerFacingRotation()
    if type(GetPlayerFacing) ~= "function" then return 0 end
    local ok, facing = pcall(GetPlayerFacing)
    return ok and tonumber(facing) or 0
end

function Pins:UpdateSmoothTestPlayerFacing()
    local mapFrame = BattleMaps.MapFrame
    if not self.teamStackTestPreviewActive
        or not mapFrame or mapFrame.testMode ~= true
        or (BattleMaps.IsInLiveBattleground and BattleMaps.IsInLiveBattleground()) then
        return
    end

    local rotation = self:GetPlayerFacingRotation()
    for _, fovFrame in pairs(self.testFovFrames or {}) do
        if fovFrame:IsShown() and fovFrame.texture and fovFrame.texture.SetRotation then
            fovFrame.texture:SetRotation(rotation)
        end
    end

    local playerFrame = self.testPlayerFacingFrame
    if playerFrame and playerFrame:IsShown() then
        if playerFrame.fillTexture and playerFrame.fillTexture.SetRotation then
            playerFrame.fillTexture:SetRotation(rotation)
        end
        if playerFrame.borderTexture and playerFrame.borderTexture:IsShown()
            and playerFrame.borderTexture.SetRotation then
            playerFrame.borderTexture:SetRotation(rotation)
        end
    end
end

function Pins:UpdatePlayerFovFramePeriodic(frame)
    if not self:ShouldRenderLivePlayerPosition() then
        frame:SetUnitColor("player", 1, 1, 1, 0)
        return
    end
    -- The FoV retains its authored artwork and never follows the
    -- selectable player-pin colour mode.
    local mapID = self.unitConfigMapID or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local pinConfig = BattleMaps.Database:GetUnitsConfig(mapID)
    local layer = frame.BattleMapsFovLayer or "under"
    local appearance = self:GetPlayerFovLayerAppearance(pinConfig, layer)
    frame:SetUnitColor("player", 1, 1, 1, self:GetPlayerFovLayerAlpha(pinConfig, layer))
    self:ConfigurePlayerFovFrameTextures(frame, appearance)
end

function Pins:UpdatePlayerFovFrameFull(frame)
    frame:ClearUnits()
    if not self:ShouldRenderLivePlayerPosition() then
        frame:FinalizeUnits()
        frame.needsFullUpdate = false
        return
    end
    local mapID = self.unitConfigMapID or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local pinConfig = BattleMaps.Database:GetUnitsConfig(mapID)
    local layer = frame.BattleMapsFovLayer or "under"
    local appearance = self:GetPlayerFovLayerAppearance(pinConfig, layer)
    if appearance then
        local r, g, b = 1, 1, 1
        local alpha = self:GetPlayerFovLayerAlpha(pinConfig, layer)
        local size = self.unitFovSize or self:GetPlayerFovSize(pinConfig, self:GetPinZoomScale())
        frame:AddUnit(
            "player",
            appearance.texture,
            size,
            size * (appearance.aspect or 1),
            r, g, b, alpha,
            PLAYER_FOV_SUBLEVEL,
            true
        )
    end
    frame:FinalizeUnits()
    self:ConfigurePlayerFovFrameTextures(frame, appearance)
    frame.needsFullUpdate = false
end

function Pins:UpdatePlayerFrameFull(frame)
    frame:ClearUnits()
    if not self:ShouldRenderLivePlayerPosition() then
        frame:FinalizeUnits()
        frame.needsFullUpdate = false
        return
    end
    local mapID = self.unitConfigMapID or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local pinConfig = BattleMaps.Database:GetUnitsConfig(mapID)
    local teamSize = BattleMaps.Clamp(
        (tonumber(pinConfig and pinConfig.teamMemberPinSize) or 12) * self:GetPinZoomScale(),
        3,
        64
    )
    local appearance = self.unitPlayerAppearance or self:GetPlayerPinAppearance(pinConfig, self.unitPlayerSize or 22, teamSize)
    local r, g, b = 1, 1, 1
    if appearance.usesColor then
        r, g, b = self:GetPlayerArrowColor()
    end
    frame:AddUnit(
        "player",
        appearance.texture,
        appearance.size,
        appearance.size,
        r, g, b, 1,
        PLAYER_PIN_SUBLEVEL,
        true
    )
    frame:FinalizeUnits()
    self:NormalizeUnitFrameCustomTextures(frame)
    frame.needsFullUpdate = false
end

function Pins:UpdatePlayerTeamBorderFrameFull(frame)
    frame:ClearUnits()
    if not self:ShouldRenderLivePlayerPosition() then
        frame:FinalizeUnits()
        frame.needsFullUpdate = false
        return
    end
    local mapID = self.unitConfigMapID or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local pinConfig = BattleMaps.Database:GetUnitsConfig(mapID)
    local teamSize = BattleMaps.Clamp(
        (tonumber(pinConfig and pinConfig.teamMemberPinSize) or 12) * self:GetPinZoomScale(),
        3,
        64
    )
    local appearance = self.unitPlayerAppearance or self:GetPlayerPinAppearance(pinConfig, self.unitPlayerSize or 22, teamSize)
    if appearance.style == "team" then
        frame:AddUnit(
            "player",
            appearance.borderTexture,
            appearance.borderSize,
            appearance.borderSize,
            1, 1, 1, 1,
            TEAM_BORDER_SUBLEVEL,
            true
        )
    end
    frame:FinalizeUnits()
    self:NormalizeUnitFrameCustomTextures(frame)
    frame.needsFullUpdate = false
end

function Pins:IsFriendlyHealer(unit)
    if not unit or not UnitExists(unit) or UnitIsUnit(unit, "player") then
        return false
    end

    local ok, role = pcall(UnitGroupRolesAssigned, unit)
    return ok and role == "HEALER"
end

local function GetSpecializationInfoSafe(specID)
    specID = tonumber(specID)
    if not specID or specID <= 0 then return nil, nil end

    local specializationAPI = C_SpecializationInfo
    if type(specializationAPI) == "table" then
        for _, methodName in ipairs({
            "GetSpecializationInfoForSpecID",
            "GetSpecializationInfoByID",
        }) do
            local method = specializationAPI[methodName]
            if type(method) == "function" then
                local packed = { pcall(method, specID) }
                if packed[1] then
                    local first = packed[2]
                    if type(first) == "table" then
                        local icon = first.icon or first.iconID or first.iconFileID
                        local name = first.name
                        if icon then return icon, name end
                    else
                        -- Compatibility with tuple-returning versions.
                        local name = packed[3] or packed[2]
                        local icon = packed[5] or packed[4]
                        if type(icon) == "number" or type(icon) == "string" then
                            return icon, type(name) == "string" and name or nil
                        end
                    end
                end
            end
        end
    end

    if type(GetSpecializationInfoByID) == "function" then
        local packed = { pcall(GetSpecializationInfoByID, specID) }
        if packed[1] then
            local name = packed[3] or packed[2]
            local icon = packed[5] or packed[4]
            if type(icon) == "number" or type(icon) == "string" then
                return icon, type(name) == "string" and name or nil
            end
        end
    end

    return nil, nil
end

function Pins:GetUnitSpecID(unit)
    if not unit or not UnitExists(unit) then return nil end

    if UnitIsUnit(unit, "player") and type(GetSpecialization) == "function"
        and type(GetSpecializationInfo) == "function" then
        local ok, index = pcall(GetSpecialization)
        if ok and index then
            local packed = { pcall(GetSpecializationInfo, index) }
            local id = packed[1] and tonumber(packed[2]) or nil
            if id and id > 0 then return id end
        end
    end

    local guid = type(UnitGUID) == "function" and UnitGUID(unit) or nil
    self.teamSpecByGUID = self.teamSpecByGUID or {}
    local cached = guid and self.teamSpecByGUID[guid]
    if cached and tonumber(cached.specID) and tonumber(cached.specID) > 0 then
        return tonumber(cached.specID)
    end

    if type(GetInspectSpecialization) == "function" then
        local ok, value = pcall(GetInspectSpecialization, unit)
        local specID
        if ok then
            local convertOK, converted = pcall(tonumber, value)
            if convertOK then specID = converted end
        end
        if specID and specID > 0 then
            if guid then
                self.teamSpecByGUID[guid] = { specID = specID, time = GetTime() }
            end
            return specID
        end
    end

    return nil
end

function Pins:GetUnitSpecIcon(unit, classFile, forcedSpecID)
    -- Live specialization tooltips were removed. Their secure map-renderer
    -- hit-testing caused protected mouse-propagation taint on current clients.
    return nil, nil, nil
end

function Pins:GetHealerIconColor(unit, timeNow, pinConfig, classFile)
    pinConfig = pinConfig or (BattleMaps.Database and BattleMaps.Database.GetUnitsConfig
        and BattleMaps.Database:GetUnitsConfig(self.unitConfigMapID
            or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID))) or {}

    if pinConfig.healerIconColorMode == "class" then
        return self:GetPlayerClassColor()
    end

    local color = type(pinConfig.healerIconCustomColor) == "table"
        and pinConfig.healerIconCustomColor or {}
    return BattleMaps.Clamp(tonumber(color.r or color[1]) or 1, 0, 1),
        BattleMaps.Clamp(tonumber(color.g or color[2]) or 1, 0, 1),
        BattleMaps.Clamp(tonumber(color.b or color[3]) or 1, 0, 1)
end

function Pins:MarkTeamSpecFramesForUpdate()
    -- Specialization rendering is disabled.
end

function Pins:HandleTeamInspectReady(guid)
    -- Specialization inspection is disabled.
end

function Pins:UpdateTeamSpecInspection(now)
    -- Specialization inspection is disabled.
end

function Pins:IsUnitInCombat(unit)
    if not unit or not UnitExists(unit) then
        return false
    end

    local ok, inCombat = pcall(UnitAffectingCombat, unit)
    return ok and inCombat == true
end

-- Objective rules still need the effective battleground faction (for example,
-- Eye of the Storm's carried-objective handling). This is deliberately kept
-- separate from the retired player-pin Faction Color mode.
function Pins:GetPlayerFactionColor()
    local faction
    if BattleMaps.MapFrame and type(BattleMaps.MapFrame.GetEffectiveFaction) == "function" then
        faction = BattleMaps.MapFrame:GetEffectiveFaction()
    end

    local color = faction == "Alliance" and BattleMaps.COLORS.alliance
        or faction == "Horde" and BattleMaps.COLORS.horde
        or BattleMaps.COLORS.neutral

    return color[1], color[2], color[3], faction
end

function Pins:GetPlayerClassColor()
    local classFile = select(2, UnitClass("player"))
    if classFile then
        local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
        if classColor then
            return classColor.r, classColor.g, classColor.b
        end
        local r, g, b = GetClassColor(classFile)
        if r and g and b then
            return r, g, b
        end
    end
    return 1, 1, 1
end

function Pins:GetPlayerCustomColor()
    local db = BattleMaps.Database:Get()
    local color = type(db.playerArrowCustomColor) == "table" and db.playerArrowCustomColor or {}
    return BattleMaps.Clamp(tonumber(color.r or color[1]) or 1, 0, 1),
        BattleMaps.Clamp(tonumber(color.g or color[2]) or 0.82, 0, 1),
        BattleMaps.Clamp(tonumber(color.b or color[3]) or 0.22, 0, 1)
end

function Pins:GetPlayerArrowColor()
    local db = BattleMaps.Database:Get()
    local mode = db.playerArrowColorMode

    if mode == "custom" then
        local r, g, b = self:GetPlayerCustomColor()
        return r, g, b, "custom", nil
    end

    local r, g, b = self:GetPlayerClassColor()
    return r, g, b, "class", nil
end

local function GetVectorXY(vector)
    if not vector then return nil, nil end
    if type(vector.GetXY) == "function" then
        local ok, x, y = pcall(vector.GetXY, vector)
        if ok and x and y then return tonumber(x), tonumber(y) end
    end
    return tonumber(vector.x), tonumber(vector.y)
end

local function IsUsableNormalizedPosition(x, y)
    x = tonumber(x)
    y = tonumber(y)
    return x and y and x >= -0.02 and x <= 1.02 and y >= -0.02 and y <= 1.02 and (x ~= 0 or y ~= 0)
end

local function GetUnitStackSortKey(unit)
    unit = tostring(unit or "")
    local raidIndex = unit:match("^raid(%d+)$")
    if raidIndex then return tonumber(raidIndex) or 999 end
    local partyIndex = unit:match("^party(%d+)$")
    if partyIndex then return 100 + (tonumber(partyIndex) or 999) end
    return 1000
end

GetUnitStackSlot = function(unit)
    local sortKey = GetUnitStackSortKey(unit)
    if sortKey >= 1000 then return 1 end
    return ((sortKey - 1) % MAX_TEAM_STACK_UNIT_FRAMES) + 1
end

local function GetStackOffsetVector(direction, index)
    direction = TEAM_STACK_DIRECTIONS[direction] and direction or "compact"
    index = math.max(1, tonumber(index) or 1)

    if direction == "horizontal" then
        if index == 1 then return 0, 0 end
        local magnitude = math.floor(index / 2)
        local sign = (index % 2 == 0) and 1 or -1
        return sign * magnitude, 0
    elseif direction == "vertical" then
        if index == 1 then return 0, 0 end
        local magnitude = math.floor(index / 2)
        local sign = (index % 2 == 0) and 1 or -1
        return 0, sign * magnitude
    elseif direction == "diagonal" then
        if index == 1 then return 0, 0 end
        local magnitude = math.floor(index / 2)
        local sign = (index % 2 == 0) and 1 or -1
        return sign * magnitude, sign * magnitude
    end

    local offset = COMPACT_STACK_OFFSETS[index]
    if offset then return offset[1], offset[2] end

    local ring = math.ceil((math.sqrt(index) - 1) / 2)
    local side = math.max(1, ring * 2)
    local position = (index - 1) % (side * 4)
    if position < side then
        return ring, -ring + position
    elseif position < side * 2 then
        return ring - (position - side), ring
    elseif position < side * 3 then
        return -ring, ring - (position - side * 2)
    end
    return -ring + (position - side * 3), -ring
end

-- UnitPositionFrame can continue drawing restricted battleground positions even
-- when addon Lua cannot read those coordinates. In that fallback path we move
-- each full-canvas, single-unit frame by a small visual offset. Detection radius
-- must never affect this spacing: it is exclusively the proximity threshold used
-- by the precise coordinate path. Pin overlap controls the fallback step.
local function GetNativeStackOffset(direction, index, step)
    local vx, vy = GetStackOffsetVector(direction, index)
    local offsetX = vx * step
    local offsetY = vy * step
    local distance = math.sqrt((offsetX * offsetX) + (offsetY * offsetY))

    -- Keep extreme horizontal/vertical roster patterns bounded without tying
    -- the bound to detection radius. The bound scales only with stack spacing.
    local maximumDistance = BattleMaps.Clamp(math.max(step * 4, 48), 48, 96)
    if distance > maximumDistance and distance > 0 then
        local scale = maximumDistance / distance
        offsetX = offsetX * scale
        offsetY = offsetY * scale
    end

    return offsetX, offsetY
end

local function ApplyTextureToRegion(region, texture)
    if not region or not texture then return end
    if region.SetRotation then region:SetRotation(0) end
    if region.SetTexCoord then region:SetTexCoord(0, 1, 0, 1) end
    if region.SetBlendMode then region:SetBlendMode("BLEND") end

    local textureValue = tostring(texture or "")
    local isPath = textureValue:find("\\", 1, true) or textureValue:find("/", 1, true)
    if not isPath and region.SetAtlas then
        local ok = pcall(region.SetAtlas, region, textureValue)
        if ok then return end
    end
    if region.SetTexture then
        region:SetTexture(textureValue)
    end
end

function Pins:GetTeamStackWorldRect(mapID)
    mapID = tonumber(mapID)
    if not mapID or not C_Map or not C_Map.GetWorldPosFromMapPos or type(CreateVector2D) ~= "function" then
        return nil
    end

    self.teamStackWorldRects = self.teamStackWorldRects or {}
    if self.teamStackWorldRects[mapID] then return self.teamStackWorldRects[mapID] end

    local ok1, first1, second1 = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
    local ok2, first2, second2 = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(1, 1))
    if not ok1 or not ok2 then return nil end

    local topLeft = second1 or first1
    local bottomRight = second2 or first2
    local leftX, topY = GetVectorXY(topLeft)
    local rightX, bottomY = GetVectorXY(bottomRight)
    if not leftX or not topY or not rightX or not bottomY then return nil end
    if math.abs(rightX - leftX) < 0.001 or math.abs(bottomY - topY) < 0.001 then return nil end

    local rect = {
        leftX = leftX,
        topY = topY,
        width = rightX - leftX,
        height = bottomY - topY,
    }
    self.teamStackWorldRects[mapID] = rect
    return rect
end

function Pins:GetTeamStackUnitMapPosition(unitMapID, unit)
    unitMapID = tonumber(unitMapID)
    if not unitMapID or not unit or not UnitExists(unit) then return nil, nil end

    local cacheKey = (type(UnitGUID) == "function" and UnitGUID(unit)) or tostring(unit)
    local timeNow = GetTime()
    self.teamStackPositionCache = self.teamStackPositionCache or {}

    local function Remember(x, y)
        x, y = BattleMaps.Clamp(x, 0, 1), BattleMaps.Clamp(y, 0, 1)
        self.teamStackPositionCache[cacheKey] = {
            mapID = unitMapID,
            x = x,
            y = y,
            time = timeNow,
        }
        return x, y
    end

    if C_Map and C_Map.GetPlayerMapPosition then
        local ok, position = pcall(C_Map.GetPlayerMapPosition, unitMapID, unit)
        if ok and position then
            local x, y = GetVectorXY(position)
            if IsUsableNormalizedPosition(x, y) then
                return Remember(x, y)
            end
        end
    end

    if type(UnitPosition) == "function" then
        local ok, unitX, unitY = pcall(UnitPosition, unit)
        if ok and unitX and unitY then
            local rect = self:GetTeamStackWorldRect(unitMapID)
            if rect then
                local x = (unitX - rect.leftX) / rect.width
                local y = (unitY - rect.topY) / rect.height
                if IsUsableNormalizedPosition(x, y) then
                    return Remember(x, y)
                end

                -- Some older map/world coordinate paths expose the axes in the
                -- opposite order. Try the swapped form only as a fallback.
                x = (unitY - rect.leftX) / rect.width
                y = (unitX - rect.topY) / rect.height
                if IsUsableNormalizedPosition(x, y) then
                    return Remember(x, y)
                end
            end
        end
    end

    -- A single restricted API tick should not force the whole battleground
    -- roster into secure fallback. Reuse only a very recent authoritative
    -- position; the short lifetime avoids the stale-pin drift seen previously.
    local cached = self.teamStackPositionCache[cacheKey]
    if cached
        and cached.mapID == unitMapID
        and (timeNow - (tonumber(cached.time) or 0)) <= 0.35 then
        return cached.x, cached.y
    end

    return nil, nil
end

function Pins:GetTeamStackAppearance(unit, timeNow)
    local db = BattleMaps.Database:Get()
    local isHealer = self:IsFriendlyHealer(unit)
    local useSolidOutOfCombat = db.useSolidTeamPinOutOfCombat ~= false
    local trackHealerCombat = self:ShouldUseSplitHealerOverlay()
    local inCombat = (useSolidOutOfCombat or trackHealerCombat)
        and self:IsUnitInCombat(unit)
        or false

    local normalSize = self.unitTeamSize or 12
    local healerSettingSize = self.unitHealerSize or 16
    local currentTime = timeNow or GetTime()
    local r, g, b = self:GetUnitClassColor(unit, currentTime)
    local pinConfig = BattleMaps.Database:GetUnitsConfig(
        self.unitConfigMapID or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    )
    local healerR, healerG, healerB = self:GetHealerIconColor(unit, currentTime, pinConfig)
    local specIcon, specName = nil, nil
    local appearance = self:BuildTeamPinAppearance(
        isHealer,
        inCombat,
        normalSize,
        healerSettingSize,
        normalSize,
        useSolidOutOfCombat,
        r, g, b,
        healerR, healerG, healerB,
        specIcon, specName
    )
    appearance.isHealer = isHealer
    appearance.inCombat = inCombat
    return appearance
end

function Pins:AcquireTeamStackPin(index)
    self.teamStackPinPool = self.teamStackPinPool or {}
    local frame = self.teamStackPinPool[index]
    if frame then return frame end

    frame = CreateFrame("Frame", nil, self.parent)
    frame:SetFrameLevel(self.parent:GetFrameLevel() + TEAM_STACK_FRAME_LEVEL_OFFSET)

    local borderTexture = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    borderTexture:SetPoint("CENTER", frame, "CENTER", 0, 0)
    borderTexture:SetBlendMode("BLEND")
    borderTexture:Hide()
    frame.borderTexture = borderTexture

    local fillTexture = frame:CreateTexture(nil, "ARTWORK", nil, 0)
    fillTexture:SetPoint("CENTER", frame, "CENTER", 0, 0)
    fillTexture:SetBlendMode("BLEND")
    frame.fillTexture = fillTexture
    frame.texture = fillTexture -- compatibility with older helper paths

    local healerTexture = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    healerTexture:SetPoint("CENTER", frame, "CENTER", 0, 0)
    healerTexture:SetBlendMode("BLEND")
    healerTexture:Hide()
    frame.healerTexture = healerTexture
    frame.overlayTexture = healerTexture -- compatibility alias

    local specBackdrop = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    specBackdrop:SetColorTexture(0, 0, 0, 0.92)
    specBackdrop:Hide()
    frame.specBackdrop = specBackdrop

    local specTexture = frame:CreateTexture(nil, "ARTWORK", nil, 3)
    specTexture:SetBlendMode("BLEND")
    specTexture:Hide()
    frame.specTexture = specTexture

    frame:Hide()
    self.teamStackPinPool[index] = frame
    return frame
end

function Pins:HideTeamStackOverlay()
    self:ResetTeamHoverFanOut(true)
    if type(self.teamStackPinPool) == "table" then
        for _, frame in ipairs(self.teamStackPinPool) do
            frame:Hide()
            frame.active = false
        end
    end
    self.testPlayerFacingFrame = nil
    self.teamStackOverlayActive = false
end

function Pins:SetNativeGroupPinsVisible(unitFrame, visible)
    visible = visible ~= false
    if self.nativeGroupPinsVisible == visible then return false end
    self.nativeGroupPinsVisible = visible

    for _, frame in ipairs({ unitFrame, self.teamBorderFrame, self.healerOverlayFrame, self.teamSpecIconFrame }) do
        if frame then
            pcall(frame.SetShouldShowUnits, frame, "party", visible)
            pcall(frame.SetShouldShowUnits, frame, "raid", visible)
            if frame.SetNeedsFullUpdate then
                pcall(frame.SetNeedsFullUpdate, frame)
            end
        end
    end
    return true
end

function Pins:BuildTeamStackEntries(unitMapID, timeNow, excludePlayerArrow)
    local unitFrame = self.unitFrame
    if not unitFrame or not unitMapID then return nil end

    local memberCount, unitBase = GetLiveGroupRosterSource(unitFrame)
    if memberCount <= 0 then return nil end

    local entries = {}
    local missingUnits = {}
    local visibleMembers = 0
    local largestCollisionSize = 0
    for index = 1, memberCount do
        local unit = unitBase .. index
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            visibleMembers = visibleMembers + 1
            local x, y = self:GetTeamStackUnitMapPosition(unitMapID, unit)
            if x and y then
                local appearance = self:GetTeamStackAppearance(unit, timeNow)
                local entry = {
                    unit = unit,
                    x = x,
                    y = y,
                    offsetX = 0,
                    offsetY = 0,
                    sortKey = GetUnitStackSortKey(unit),
                }
                for key, value in pairs(appearance) do entry[key] = value end
                entries[#entries + 1] = entry
                largestCollisionSize = math.max(largestCollisionSize, tonumber(entry.collisionSize) or 0)
            else
                missingUnits[#missingUnits + 1] = unit
            end
        end
    end

    if visibleMembers <= 0 then
        return nil, nil, nil
    end
    if #entries <= 0 then
        return nil, nil, missingUnits
    end

    local playerX, playerY = self:GetTeamStackUnitMapPosition(unitMapID, "player")
    local playerEntry
    if not excludePlayerArrow and playerX and playerY then
        -- The arrow is visually larger than a teammate pin, but treating that
        -- artwork as its collision footprint creates an exaggerated empty ring.
        -- For stacking, the player occupies one ordinary team-pin slot.
        local teamCollisionSize = largestCollisionSize > 0
            and largestCollisionSize
            or (self.unitTeamSize or 12)
        playerEntry = {
            unit = "player",
            x = playerX,
            y = playerY,
            fixed = true,
            sortKey = 0,
            size = self.unitPlayerSize or 22,
            collisionSize = teamCollisionSize,
        }
    end

    return entries, playerEntry, missingUnits
end

function Pins:ApplyTeamStackOffsets(entries, playerEntry, radius, step, direction, canvasWidth, canvasHeight)
    if type(entries) ~= "table" or #entries == 0 then return end
    radius = BattleMaps.Clamp(tonumber(radius) or 18, 8, 40)
    step = BattleMaps.Clamp(tonumber(step) or 8, 1, 80)
    direction = TEAM_STACK_DIRECTIONS[direction] and direction or "compact"
    canvasWidth = math.max(tonumber(canvasWidth) or 1, 1)
    canvasHeight = math.max(tonumber(canvasHeight) or 1, 1)

    for _, entry in ipairs(entries) do
        entry.offsetX = 0
        entry.offsetY = 0
        entry.pixelX = entry.x * canvasWidth
        entry.pixelY = entry.y * canvasHeight
    end

    local nodes = {}
    if playerEntry then
        playerEntry.pixelX = playerEntry.x * canvasWidth
        playerEntry.pixelY = playerEntry.y * canvasHeight
        nodes[#nodes + 1] = playerEntry
    end
    for _, entry in ipairs(entries) do nodes[#nodes + 1] = entry end
    if #nodes <= 1 then return end

    -- Build anchor-bounded clusters rather than transitive chains. A line of
    -- individually-nearby pins cannot pull a distant moving teammate through
    -- the group. Each ordinary cluster remains bounded to its seed pin, while
    -- a player-centred cluster remains bounded to the player's true position.
    -- Departing pins therefore return immediately to their true map position.
    local function GetCollisionRadius(node)
        return math.max(
            tonumber(node and (node.collisionSize or node.borderSize or node.size)) or 0,
            0
        ) * 0.5
    end

    local function WithinRadius(left, right)
        local dx = left.pixelX - right.pixelX
        local dy = left.pixelY - right.pixelY

        -- The user radius is an early clustering threshold, not permission for
        -- visibly overlapping pins to remain unstacked. Always include the
        -- actual rendered collision footprints, including combat-scaled pins.
        local collisionDistance = GetCollisionRadius(left) + GetCollisionRadius(right)
        local effectiveRadius = math.max(radius, collisionDistance)
        local effectiveRadiusSquared = effectiveRadius * effectiveRadius
        return math.abs(dx) <= effectiveRadius
            and math.abs(dy) <= effectiveRadius
            and ((dx * dx) + (dy * dy)) <= effectiveRadiusSquared
    end

    local function CanJoinGroup(group, node)
        -- Every group is bounded to a stable source position rather than using
        -- transitive neighbour links. This keeps ordinary overlapping clusters
        -- easy to form while ensuring a moving pin leaves as soon as it is no
        -- longer near the player or the group's seed pin.
        return group.anchorNode and WithinRadius(group.anchorNode, node) or false
    end

    local function AddMember(group, node)
        group.members[#group.members + 1] = node
        group.sourceX = group.sourceX + node.pixelX
        group.sourceY = group.sourceY + node.pixelY
    end

    local function SortByDistanceFrom(anchor, list)
        table.sort(list, function(a, b)
            local adx, ady = a.pixelX - anchor.pixelX, a.pixelY - anchor.pixelY
            local bdx, bdy = b.pixelX - anchor.pixelX, b.pixelY - anchor.pixelY
            local distanceA = (adx * adx) + (ady * ady)
            local distanceB = (bdx * bdx) + (bdy * bdy)
            if distanceA ~= distanceB then return distanceA < distanceB end
            if a.sortKey ~= b.sortKey then return a.sortKey < b.sortKey end
            return tostring(a.unit or "") < tostring(b.unit or "")
        end)
    end

    local groups = {}
    local assigned = {}

    if playerEntry then
        local playerGroup = {
            members = {},
            fixedNode = playerEntry,
            anchorNode = playerEntry,
            sourceX = 0,
            sourceY = 0,
        }
        assigned[playerEntry] = true

        local candidates = {}
        for _, node in ipairs(entries) do candidates[#candidates + 1] = node end
        SortByDistanceFrom(playerEntry, candidates)
        for _, node in ipairs(candidates) do
            if not assigned[node] and CanJoinGroup(playerGroup, node) then
                assigned[node] = true
                AddMember(playerGroup, node)
            end
        end
        groups[#groups + 1] = playerGroup
    end

    for _, seed in ipairs(entries) do
        if not assigned[seed] then
            local group = {
                members = {},
                fixedNode = nil,
                anchorNode = seed,
                sourceX = 0,
                sourceY = 0,
            }
            assigned[seed] = true
            AddMember(group, seed)

            local candidates = {}
            for _, node in ipairs(entries) do
                if not assigned[node] then candidates[#candidates + 1] = node end
            end
            SortByDistanceFrom(seed, candidates)
            for _, node in ipairs(candidates) do
                if not assigned[node] and CanJoinGroup(group, node) then
                    assigned[node] = true
                    AddMember(group, node)
                end
            end
            groups[#groups + 1] = group
        end
    end

    local TWO_PI = math.pi * 2

    -- Compact mode uses concentric rings. Ring N contains 6*N slots at radius
    -- N*step, so nearest-neighbour spacing remains approximately `step` at
    -- every ring. This avoids the uneven diagonal gaps of the previous square
    -- lattice and makes 0/40/80% overlap visually consistent.
    local function GetCompactRingOffset(slotIndex, skipCenter)
        slotIndex = math.max(math.floor(tonumber(slotIndex) or 1), 1)
        if not skipCenter then
            if slotIndex == 1 then return 0, 0 end
            slotIndex = slotIndex - 1
        end

        local ring = 1
        local slotsInRing = 6
        while slotIndex > slotsInRing do
            slotIndex = slotIndex - slotsInRing
            ring = ring + 1
            slotsInRing = 6 * ring
        end

        -- A participating player occupies one normal stack slot. The visual
        -- dimensions of the arrow do not enlarge the first ring.
        local ringRadius = ring * step

        -- Alternate each ring by half a slot so radial seams do not line up.
        local phase = -math.pi * 0.5
        if ring % 2 == 0 then
            phase = phase + (math.pi / slotsInRing)
        end
        local angle = phase + (((slotIndex - 1) / slotsInRing) * TWO_PI)
        return math.cos(angle) * ringRadius, math.sin(angle) * ringRadius
    end

    for _, group in pairs(groups) do
        local memberCount = #group.members
        if memberCount > 1 or group.fixedNode then
            table.sort(group.members, function(a, b)
                if a.sortKey ~= b.sortKey then return a.sortKey < b.sortKey end
                return tostring(a.unit or "") < tostring(b.unit or "")
            end)

            local anchorX, anchorY
            if group.fixedNode then
                anchorX = group.fixedNode.pixelX
                anchorY = group.fixedNode.pixelY
            else
                anchorX = group.sourceX / math.max(memberCount, 1)
                anchorY = group.sourceY / math.max(memberCount, 1)
            end

            local planned = {}
            local minimumX, minimumY = math.huge, math.huge
            local maximumX, maximumY = -math.huge, -math.huge

            for memberIndex, entry in ipairs(group.members) do
                local relativeX, relativeY
                if direction == "compact" then
                    relativeX, relativeY = GetCompactRingOffset(
                        memberIndex,
                        group.fixedNode ~= nil
                    )
                else
                    local patternIndex = memberIndex + (group.fixedNode and 1 or 0)
                    local vx, vy = GetStackOffsetVector(direction, patternIndex)
                    if group.fixedNode then
                        local length = math.sqrt((vx * vx) + (vy * vy))
                        local ring = math.max(math.abs(vx), math.abs(vy))
                        local targetDistance = math.max(ring, 1) * step
                        if length > 0 then
                            relativeX = (vx / length) * targetDistance
                            relativeY = (vy / length) * targetDistance
                        else
                            relativeX, relativeY = 0, 0
                        end
                    else
                        relativeX = vx * step
                        relativeY = vy * step
                    end
                end

                local targetX = anchorX + relativeX
                local targetY = anchorY + relativeY
                local halfSize = math.max(
                    tonumber(entry.collisionSize or entry.borderSize or entry.size) or step,
                    1
                ) * 0.5

                planned[#planned + 1] = {
                    entry = entry,
                    targetX = targetX,
                    targetY = targetY,
                    halfSize = halfSize,
                }
                minimumX = math.min(minimumX, targetX - halfSize)
                maximumX = math.max(maximumX, targetX + halfSize)
                minimumY = math.min(minimumY, targetY - halfSize)
                maximumY = math.max(maximumY, targetY + halfSize)
            end

            -- Move the entire layout as one unit if it would clip outside the
            -- map canvas. Per-pin clamping would collapse spacing near edges.
            local shiftX, shiftY = 0, 0
            if minimumX < 0 then
                shiftX = -minimumX
            elseif maximumX > canvasWidth then
                shiftX = canvasWidth - maximumX
            end
            if minimumY < 0 then
                shiftY = -minimumY
            elseif maximumY > canvasHeight then
                shiftY = canvasHeight - maximumY
            end

            for _, placement in ipairs(planned) do
                local entry = placement.entry
                local targetX = placement.targetX + shiftX
                local targetY = placement.targetY + shiftY
                entry.offsetX = targetX - entry.pixelX
                entry.offsetY = targetY - entry.pixelY
            end
        end
    end
end

function Pins:RenderTeamStackOverlay(entries, canvasWidth, canvasHeight)
    if type(entries) ~= "table" or #entries == 0 then
        self:HideTeamStackOverlay()
        return
    end

    local mapFrame = BattleMaps.MapFrame
    local canvas = mapFrame and mapFrame.canvas
    if not canvas then
        self:HideTeamStackOverlay()
        return
    end

    for index, entry in ipairs(entries) do
        local frame = self:AcquireTeamStackPin(index)
        local isPlayer = entry.kind == "player" or entry.unit == "player"
        local isTeamPlayer = entry.kind == "teamPlayer"
        local playerRotation = isPlayer and entry.rotateWithPlayer
            and self:GetPlayerFacingRotation() or 0
        local renderedSizeMaximum = isTeamPlayer and 256 or 128
        local outerSize = (isPlayer and not isTeamPlayer)
            and BattleMaps.Clamp(tonumber(entry.size) or 22, 3, 256)
            or BattleMaps.Clamp(tonumber(entry.borderSize or entry.fillSize or entry.size) or 12, 3, renderedSizeMaximum)

        frame:SetSize(outerSize, outerSize)
        local frameLevelOffset = TEAM_STACK_FRAME_LEVEL_OFFSET
        if isPlayer then
            frameLevelOffset = entry.behindTeamPins
                and PLAYER_BEHIND_TEAM_FRAME_LEVEL_OFFSET
                or PLAYER_FRAME_LEVEL_OFFSET
        end
        frame:SetFrameLevel(self.parent:GetFrameLevel() + frameLevelOffset)
        local pointX = (entry.x * canvasWidth) + (tonumber(entry.offsetX) or 0)
        local pointY = -((entry.y * canvasHeight) + (tonumber(entry.offsetY) or 0))
        frame.BattleMapsBasePointX = pointX
        frame.BattleMapsBasePointY = pointY
        frame.BattleMapsFanOffsetX = 0
        frame.BattleMapsFanOffsetY = 0
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", canvas, "TOPLEFT", pointX, pointY)

        if isPlayer and not isTeamPlayer then
            frame.borderTexture:Hide()
            frame.healerTexture:Hide()
            frame.specBackdrop:Hide()
            frame.specTexture:Hide()
            frame.fillTexture:ClearAllPoints()
            frame.fillTexture:SetPoint("CENTER", frame, "CENTER", 0, 0)
            frame.fillTexture:SetSize(outerSize, outerSize)
            ApplyTextureToRegion(frame.fillTexture, entry.fillTexture or entry.texture)
            if frame.fillTexture.SetRotation then frame.fillTexture:SetRotation(playerRotation) end
            frame.fillTexture:SetVertexColor(entry.r or 1, entry.g or 1, entry.b or 1, 1)
            frame.fillTexture:SetAlpha(1)
            frame.fillTexture:Show()
        else
            if entry.layered and entry.borderTexture then
                local borderSize = BattleMaps.Clamp(tonumber(entry.borderSize) or outerSize, 3, renderedSizeMaximum)
                frame.borderTexture:ClearAllPoints()
                frame.borderTexture:SetPoint("CENTER", frame, "CENTER", 0, 0)
                frame.borderTexture:SetSize(borderSize, borderSize)
                ApplyTextureToRegion(frame.borderTexture, entry.borderTexture)
                if frame.borderTexture.SetRotation then frame.borderTexture:SetRotation(playerRotation) end
                frame.borderTexture:SetVertexColor(1, 1, 1, 1)
                frame.borderTexture:SetAlpha(1)
                frame.borderTexture:Show()
            else
                frame.borderTexture:Hide()
            end

            local fillSize = BattleMaps.Clamp(tonumber(entry.fillSize or entry.size) or outerSize, 3, renderedSizeMaximum)
            frame.fillTexture:ClearAllPoints()
            frame.fillTexture:SetPoint("CENTER", frame, "CENTER", 0, 0)
            frame.fillTexture:SetSize(fillSize, fillSize)
            ApplyTextureToRegion(frame.fillTexture, entry.fillTexture or entry.texture)
            if frame.fillTexture.SetRotation then frame.fillTexture:SetRotation(playerRotation) end
            frame.fillTexture:SetVertexColor(entry.r or 1, entry.g or 1, entry.b or 1, 1)
            frame.fillTexture:SetAlpha(1)
            frame.fillTexture:Show()

            if entry.healerTexture then
                local healerSize = BattleMaps.Clamp(tonumber(entry.healerSize) or (outerSize * 0.56), 3, 128)
                frame.healerTexture:ClearAllPoints()
                frame.healerTexture:SetPoint("CENTER", frame, "CENTER", 0, 0)
                frame.healerTexture:SetSize(healerSize, healerSize)
                ApplyTextureToRegion(frame.healerTexture, entry.healerTexture)
                frame.healerTexture:SetVertexColor(
                    entry.healerR or 1,
                    entry.healerG or 1,
                    entry.healerB or 1,
                    1
                )
                frame.healerTexture:SetAlpha(1)
                frame.healerTexture:Show()
            else
                frame.healerTexture:Hide()
            end

            frame.specBackdrop:Hide()
            frame.specTexture:Hide()
        end

        frame.active = true
        frame.BattleMapsUnit = entry.unit
        frame.BattleMapsDisplayName = entry.displayName
        frame.BattleMapsTooltipR = entry.r or 1
        frame.BattleMapsTooltipG = entry.g or 1
        frame.BattleMapsTooltipB = entry.b or 1
        frame.BattleMapsSpecIcon = entry.specIcon
        frame.BattleMapsSpecName = entry.specName
        frame.BattleMapsIsPlayer = isPlayer
        if isPlayer and entry.rotateWithPlayer then
            self.testPlayerFacingFrame = frame
        end
        frame:Show()

        -- Coordinate-readable live stacking already gives us the exact map
        -- position. Preserve it for the short-lived death marker without any
        -- additional map/API query.
        if not isPlayer and entry.unit and UnitExists(entry.unit) and UnitGUID then
            local guid = UnitGUID(entry.unit)
            if guid then
                self.teamLastKnownPositionByGUID = self.teamLastKnownPositionByGUID or {}
                self.teamLastKnownPositionByGUID[guid] = {
                    x = BattleMaps.Clamp(tonumber(entry.x) or 0, 0, 1),
                    y = BattleMaps.Clamp(tonumber(entry.y) or 0, 0, 1),
                    mapID = tonumber(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID),
                    time = type(GetTime) == "function" and GetTime() or 0,
                }
            end
        end
    end

    if type(self.teamStackPinPool) == "table" then
        for index = #entries + 1, #self.teamStackPinPool do
            local frame = self.teamStackPinPool[index]
            if frame then
                frame.active = false
                frame.BattleMapsUnit = nil
                frame.BattleMapsDisplayName = nil
                frame.BattleMapsSpecIcon = nil
                frame.BattleMapsSpecName = nil
                frame.BattleMapsIsPlayer = nil
                if frame.specBackdrop then frame.specBackdrop:Hide() end
                if frame.specTexture then frame.specTexture:Hide() end
                frame:Hide()
            end
        end
    end
    self.teamStackOverlayActive = true
end

function Pins:IsTeamStackTestPreviewActive()
    local mapFrame = BattleMaps.MapFrame
    if not mapFrame or mapFrame.testMode ~= true then return false end
    if BattleMaps.IsInLiveBattleground and BattleMaps.IsInLiveBattleground() then return false end
    local mapID = tonumber(mapFrame.currentMapID) or tonumber(mapFrame.selectedMapID)
    if not mapID then return false end

    local pinConfig = BattleMaps.Database and BattleMaps.Database.GetUnitsConfig
        and BattleMaps.Database:GetUnitsConfig(mapID)
        or nil
    if not pinConfig then return false end

    -- Test mode is a visual sandbox. Replace the old full-map dummy team-pin
    -- grid with a small grouped preview on every map. When stacking is enabled,
    -- the same preview is run through the stack-offset pass.
    return true
end

function Pins:GetTeamStackTestAppearance(index, isHealer, inCombat, pinConfig, zoomScale, classFile)
    pinConfig = pinConfig or {}
    zoomScale = tonumber(zoomScale) or (self.GetPinZoomScale and self:GetPinZoomScale()) or 1

    local useSolidOutOfCombat = BattleMaps.Database:Get().useSolidTeamPinOutOfCombat ~= false
    local normalSize = BattleMaps.Clamp((tonumber(pinConfig.teamMemberPinSize) or 12) * zoomScale, 3, 64)
    local healerSettingSize = BattleMaps.Clamp(tonumber(pinConfig.healerPinSize) or 16, 0.50, 160)
    local color = GetTeamStackTestColor(index, classFile)
    local healerR, healerG, healerB = self:GetHealerIconColor(nil, GetTime(), pinConfig, classFile)
    local specIcon, specName = nil, nil

    local appearance = self:BuildTeamPinAppearance(
        isHealer,
        inCombat,
        normalSize,
        healerSettingSize,
        normalSize,
        useSolidOutOfCombat,
        color[1], color[2], color[3],
        healerR, healerG, healerB,
        specIcon, specName
    )
    appearance.isHealer = isHealer
    appearance.inCombat = inCombat
    return appearance
end

function Pins:RefreshTeamStackTestPreview()
    if not self:IsTeamStackTestPreviewActive() then return false end

    local mapFrame = BattleMaps.MapFrame
    local canvas = mapFrame and mapFrame.canvas
    if not canvas then return false end
    local canvasWidth, canvasHeight = canvas:GetSize()
    if not canvasWidth or canvasWidth <= 0 or not canvasHeight or canvasHeight <= 0 then return false end

    local mapID = tonumber(mapFrame.currentMapID) or tonumber(mapFrame.selectedMapID)
    local pinConfig = BattleMaps.Database:GetUnitsConfig(mapID)
    local zoomScale = (self.GetPinZoomScale and self:GetPinZoomScale()) or 1
    local teamSize = BattleMaps.Clamp((tonumber(pinConfig.teamMemberPinSize) or 12) * zoomScale, 3, 64)
    local healerSettingSize = BattleMaps.Clamp(tonumber(pinConfig.healerPinSize) or 16, 0.50, 160)
    local playerSize = BattleMaps.Clamp((tonumber(pinConfig.playerArrowSize) or 22) * zoomScale, 12, 256)
    local playerAppearance = self:GetPlayerPinAppearance(pinConfig, playerSize, teamSize)
    local playerVisualSize = playerAppearance.borderSize or playerAppearance.size
    local fovSize = self:GetPlayerFovSize(pinConfig, zoomScale)
    local overlap = BattleMaps.Clamp(tonumber(pinConfig.teamPinStackOverlap) or 45, 0, 80)
    local step = BattleMaps.Clamp(teamSize * (1 - (overlap / 100)), 1, 80)
    local direction = pinConfig.teamPinStackDirection or "compact"
    local stackEnabled = pinConfig.stackTeamPins ~= false

    local layout = TEAM_PIN_TEST_LAYOUTS[tonumber(mapID)] or DEFAULT_TEAM_PIN_TEST_LAYOUT
    local playerX, playerY = layout.player[1], layout.player[2]
    local primaryX, primaryY = layout.primary[1], layout.primary[2]

    -- Two pins deliberately exercise the player-arrow relationship. With
    -- "Exclude player arrow" enabled, raid1 sits directly on the arrow and
    -- raid2 remains close beside it. With the option disabled, the normal
    -- player-avoidance pass moves them away from the arrow footprint.
    local nearbyPlayerX = playerX + ((playerVisualSize * 0.72) / canvasWidth)
    local specs = {
        { unit = "raid1",  x = playerX,          y = playerY,          healer = false, combat = false, classFile = "PALADIN", playerDemo = true },
        { unit = "raid2",  x = nearbyPlayerX,    y = playerY,          healer = true,  combat = false, classFile = "SHAMAN",  playerDemo = true },
        { unit = "raid3",  x = primaryX,         y = primaryY,         healer = false, combat = true,  classFile = "WARRIOR" },
        { unit = "raid4",  x = primaryX + 0.004, y = primaryY + 0.003, healer = true,  combat = true,  classFile = "DRUID" },
        { unit = "raid5",  x = primaryX - 0.006, y = primaryY + 0.005, healer = false, combat = false, classFile = "ROGUE" },
        { unit = "raid6",  x = primaryX + 0.012, y = primaryY - 0.006, healer = false, combat = true,  classFile = "MAGE" },
        { unit = "raid7",  x = primaryX - 0.017, y = primaryY - 0.009, healer = false, combat = false, classFile = "WARLOCK" },
        { unit = "raid8",  x = primaryX + 0.027, y = primaryY + 0.010, healer = true,  combat = false, classFile = "EVOKER" },
        { unit = "raid9",  x = primaryX - 0.043, y = primaryY + 0.016, healer = false, combat = true,  classFile = "HUNTER" },
        { unit = "raid10", x = primaryX + 0.065, y = primaryY - 0.020, healer = false, combat = false, classFile = "MONK" },
    }

    local entries = {}
    local largestCollisionSize = 0
    for index, spec in ipairs(specs) do
        local appearance = self:GetTeamStackTestAppearance(index, spec.healer, spec.combat, pinConfig, zoomScale, spec.classFile)
        local entry = {
            unit = spec.unit,
            displayName = spec.classFile and (spec.classFile:sub(1, 1) .. spec.classFile:sub(2):lower() .. (spec.healer and " healer" or " teammate"))
                or ("Test teammate " .. tostring(index)),
            x = BattleMaps.Clamp(spec.x, 0.03, 0.97),
            y = BattleMaps.Clamp(spec.y, 0.03, 0.97),
            offsetX = 0,
            offsetY = 0,
            sortKey = GetUnitStackSortKey(spec.unit),
        }
        for key, value in pairs(appearance) do entry[key] = value end
        entries[#entries + 1] = entry
        largestCollisionSize = math.max(largestCollisionSize, tonumber(entry.collisionSize) or 0)
    end

    -- Match live stacking: spacing is based on the largest currently rendered
    -- collision circle, so 0% stack overlap remains genuinely non-overlapping
    -- even when combat scaling makes some teammate pins larger than others.
    step = BattleMaps.Clamp(
        math.max(teamSize, largestCollisionSize) * (1 - (overlap / 100)),
        1,
        80
    )

    local metrics = self:GetTeamPinMetrics(
        largestCollisionSize > 0 and largestCollisionSize or teamSize,
        healerSettingSize,
        teamSize,
        playerVisualSize
    )
    local playerEntry = {
        unit = "player",
        x = playerX,
        y = playerY,
        fixed = true,
        sortKey = 0,
        size = playerVisualSize,
        avoidRadius = metrics.playerAvoidRadius,
    }

    local excludePlayerArrow = pinConfig.excludePlayerArrowFromStack == true
    if stackEnabled then
        -- Live PvP cannot expose exact teammate coordinates to addon Lua. Test
        -- mode therefore demonstrates the same bounded roster-based separation
        -- used by the restricted live path instead of the retired radius model.
        local overlapFraction = overlap / 80
        local maxOffset = BattleMaps.Clamp(
            teamSize * (0.84 - (0.51 * overlapFraction)),
            3,
            12
        )
        local restrictedStep = BattleMaps.Clamp(
            maxOffset * (0.88 - (0.63 * overlapFraction)),
            1,
            maxOffset
        )
        for index, entry in ipairs(entries) do
            local patternIndex = index + (excludePlayerArrow and 0 or 1)
            local offsetX, offsetY = GetNativeStackOffset(direction, patternIndex, restrictedStep)
            local distance = math.sqrt((offsetX * offsetX) + (offsetY * offsetY))
            if distance > maxOffset and distance > 0 then
                local scale = maxOffset / distance
                offsetX, offsetY = offsetX * scale, offsetY * scale
            end
            entry.offsetX = offsetX
            entry.offsetY = offsetY
        end
    end

    -- UnitPins owns the sole Test-mode player pin. Render it from the
    -- per-map authored coordinate so the visible marker and stack-avoidance
    -- reference can never diverge.
    local playerR, playerG, playerB = 1, 1, 1
    if playerAppearance.usesColor then
        local mode
        playerR, playerG, playerB, mode = self:GetPlayerArrowColor()
        self.lastPlayerColorMode = mode
    end
    table.insert(entries, 1, {
        kind = playerAppearance.style == "team" and "teamPlayer" or "player",
        unit = "player",
        displayName = "Player",
        x = playerEntry.x,
        y = playerEntry.y,
        offsetX = 0,
        offsetY = 0,
        fillTexture = playerAppearance.texture,
        size = playerAppearance.size,
        layered = playerAppearance.style == "team",
        borderTexture = playerAppearance.borderTexture,
        borderSize = playerAppearance.borderSize,
        fillSize = playerAppearance.size,
        r = playerR,
        g = playerG,
        b = playerB,
        sortKey = 0,
        behindTeamPins = excludePlayerArrow,
        rotateWithPlayer = true,
    })

    self:RenderTeamStackOverlay(entries, canvasWidth, canvasHeight)
    self:RenderTestFov(pinConfig, playerX, playerY, fovSize, canvasWidth, canvasHeight)
    self.teamStackTestPreviewActive = true
    return true
end

function Pins:RefreshUnitTestPreview()
    if self:RefreshTeamStackTestPreview() then
        return true
    end
    self:HideTeamStackTestPreview()
    return false
end

function Pins:HideUnitTestPreview()
    self:HideTeamStackTestPreview()
end

function Pins:HideTeamStackTestPreview()
    if self.teamStackTestPreviewActive then
        self.teamStackTestPreviewActive = false
        self:HideTeamStackOverlay()
    end
    self:HideTestFov()
end

function Pins:GetPlayerFovLayerRenderParent(layer)
    local mapFrame = BattleMaps.MapFrame
    if layer == "under" then
        return (mapFrame and mapFrame.fovLayer) or self.parent
    end
    if layer == "arc" then
        return (mapFrame and mapFrame.fovOverlayLayer) or self.parent
    end
    return self.parent
end

function Pins:GetPlayerFovLayerFrameLevel(layer)
    local renderParent = self:GetPlayerFovLayerRenderParent(layer)
    if renderParent and renderParent ~= self.parent then
        return renderParent:GetFrameLevel() + 1
    end
    if layer == "beam" then
        return self.parent:GetFrameLevel() + PLAYER_FOV_BEAM_FRAME_LEVEL_OFFSET
    end
    return self.parent:GetFrameLevel() + PLAYER_FOV_FRAME_LEVEL_OFFSET
end

function Pins:AcquireTestFovLayer(layer)
    self.testFovFrames = self.testFovFrames or {}
    if self.testFovFrames[layer] then return self.testFovFrames[layer] end

    local frame = CreateFrame("Frame", nil, self:GetPlayerFovLayerRenderParent(layer))
    frame.BattleMapsFovLayer = layer
    frame:SetFrameLevel(self:GetPlayerFovLayerFrameLevel(layer))
    frame:EnableMouse(false)
    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    frame.texture = texture
    frame:Hide()
    self.testFovFrames[layer] = frame
    return frame
end

function Pins:RenderTestFov(pinConfig, x, y, size, canvasWidth, canvasHeight)
    local mapFrame = BattleMaps.MapFrame
    local canvas = mapFrame and mapFrame.canvas
    if not canvas then
        self:HideTestFov()
        return
    end

    for _, layer in ipairs(PLAYER_FOV_LAYER_ORDER) do
        local appearance = self:GetPlayerFovLayerAppearance(pinConfig, layer)
        local existingFrame = self.testFovFrames and self.testFovFrames[layer]
        if appearance then
            local frame = self:AcquireTestFovLayer(layer)
            frame:SetSize(size, size * (appearance.aspect or 1))
            frame:SetFrameLevel(self:GetPlayerFovLayerFrameLevel(layer))
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", canvas, "TOPLEFT", x * canvasWidth, -(y * canvasHeight))
            frame.texture:SetTexture(appearance.texture)
            frame.texture:SetBlendMode(appearance.blendMode or "BLEND")
            frame.texture:SetVertexColor(1, 1, 1, 1)
            frame.texture:SetAlpha(self:GetPlayerFovLayerAlpha(pinConfig, layer))
            if frame.texture.SetRotation then
                frame.texture:SetRotation(self:GetPlayerFacingRotation())
            end
            frame:Show()
        elseif existingFrame then
            existingFrame:Hide()
        end
    end
end

function Pins:HideTestFov()
    for _, frame in pairs(self.testFovFrames or {}) do frame:Hide() end
end

function Pins:HideTeamStackUnitFrames()
    self:ResetTeamHoverFanOut(true)
    for _, collection in ipairs({
        self.teamStackBorderFrames,
        self.teamStackUnitFrames,
        self.teamStackHealerOverlayFrames,
        self.teamStackSpecIconFrames,
    }) do
        if type(collection) == "table" then
            for _, frame in ipairs(collection) do
                frame:SetAlpha(0)
                ConfigureTeamTooltipHitTesting(frame, false)
                frame.BattleMapsActive = false
                frame.BattleMapsTargetUnit = nil
            end
        end
    end
    self.teamStackUnitFrameFallbackActive = false
    self.teamStackFallbackUsesFullRoster = false
    self.teamStackRestrictedFallbackActive = false
    self.teamStackRestrictedMaxOffset = nil
end

function Pins:SetLivePlayerUnitFramesEnabled(enabled)
    enabled = enabled == true
    if self.livePlayerUnitFramesEnabled == enabled then return false end
    self.livePlayerUnitFramesEnabled = enabled

    for _, frame in ipairs({
        self.playerTeamBorderFrame,
        self.playerFovFrame,
        self.playerFovArcFrame,
        self.playerFovBeamFrame,
        self.playerFrame,
    }) do
        if frame then
            pcall(frame.SetShouldShowUnits, frame, "player", enabled)
            pcall(frame.SetNeedsFullUpdate, frame)
        end
    end
    return true
end

function Pins:SuppressLiveUnitFramesForPreview()
    -- Preview/Test Mode owns a static player marker. Disable the player unit in
    -- every live-position renderer while that preview is active so native
    -- UnitPositionFrame updates cannot draw the real character as a duplicate.
    for _, frame in ipairs({
        self.teamBorderFrame,
        self.unitFrame,
        self.healerOverlayFrame,
        self.teamSpecIconFrame,
        self.playerTeamBorderFrame,
        self.playerFovFrame,
        self.playerFovArcFrame,
        self.playerFovBeamFrame,
        self.playerFrame,
    }) do
        if frame then
            frame:SetAlpha(0)
            ConfigureTeamTooltipHitTesting(frame, false)
        end
    end

    self:HideTeamStackUnitFrames()
    if self.unitFrame then self:SetNativeGroupPinsVisible(self.unitFrame, true) end
    self:SetLivePlayerUnitFramesEnabled(false)
    for _, frame in ipairs({
        self.playerTeamBorderFrame,
        self.playerFovFrame,
        self.playerFovArcFrame,
        self.playerFovBeamFrame,
        self.playerFrame,
    }) do
        if frame then
            pcall(frame.SetUnitColor, frame, "player", 1, 1, 1, 0)
            pcall(frame.SetNeedsFullUpdate, frame)
            pcall(frame.UpdatePlayerPins, frame)
        end
    end
    self.liveUnitFramesSuppressedForPreview = true
end

function Pins:InitializeTeamStackUnitFrames(parent)
    self.teamStackBorderFrames = self.teamStackBorderFrames or {}
    self.teamStackUnitFrames = self.teamStackUnitFrames or {}
    self.teamStackHealerOverlayFrames = self.teamStackHealerOverlayFrames or {}
    self.teamStackSpecIconFrames = self.teamStackSpecIconFrames or {}

    for slot = 1, MAX_TEAM_STACK_UNIT_FRAMES do
        local borderFrame = CreateFrame(
            "UnitPositionFrame",
            "BattleMapsTeamStackBorderFrame" .. slot,
            parent,
            "UnitPositionFrameTemplate"
        )
        borderFrame.BattleMapsPins = self
        borderFrame.BattleMapsStackSlot = slot
        borderFrame.UpdateFull = function(stackFrame, timeNow)
            stackFrame.BattleMapsPins:UpdateTeamStackBorderFrameFull(stackFrame, timeNow)
        end
        borderFrame.UpdatePeriodic = function(stackFrame, timeNow)
            stackFrame.BattleMapsPins:UpdateTeamBorderFramePeriodic(stackFrame, timeNow)
        end
        borderFrame:SetFrameLevel(parent:GetFrameLevel() + TEAM_STACK_BORDER_FRAME_LEVEL_OFFSET)
        borderFrame:SetUseClassColor("player", false)
        borderFrame:SetUseClassColor("party", false)
        borderFrame:SetUseClassColor("raid", false)
        borderFrame:SetShouldShowUnits("player", false)
        borderFrame:SetShouldShowUnits("party", true)
        borderFrame:SetShouldShowUnits("raid", true)
        borderFrame:SetNeedsPeriodicUpdate(true)
        borderFrame:SetAlpha(0)
        borderFrame:Show()
        self.teamStackBorderFrames[slot] = borderFrame

        local fillFrame = CreateFrame(
            "UnitPositionFrame",
            "BattleMapsTeamStackUnitFrame" .. slot,
            parent,
            "UnitPositionFrameTemplate"
        )
        fillFrame.BattleMapsPins = self
        fillFrame.BattleMapsStackSlot = slot
        fillFrame.UpdateFull = function(stackFrame, timeNow)
            stackFrame.BattleMapsPins:UpdateTeamStackUnitFrameFull(stackFrame, timeNow)
        end
        fillFrame.UpdatePeriodic = function(stackFrame, timeNow)
            stackFrame.BattleMapsPins:UpdateUnitFramePeriodic(stackFrame, timeNow)
        end
        fillFrame:SetFrameLevel(parent:GetFrameLevel() + TEAM_STACK_UNIT_FRAME_LEVEL_OFFSET)
        fillFrame:SetUseClassColor("player", false)
        fillFrame:SetUseClassColor("party", true)
        fillFrame:SetUseClassColor("raid", true)
        fillFrame:SetShouldShowUnits("player", false)
        fillFrame:SetShouldShowUnits("party", true)
        fillFrame:SetShouldShowUnits("raid", true)
        fillFrame:SetNeedsPeriodicUpdate(true)
        fillFrame:SetAlpha(0)
        fillFrame:Show()
        self.teamStackUnitFrames[slot] = fillFrame

        local healerFrame = CreateFrame(
            "UnitPositionFrame",
            "BattleMapsTeamStackHealerOverlayFrame" .. slot,
            parent,
            "UnitPositionFrameTemplate"
        )
        healerFrame.BattleMapsPins = self
        healerFrame.BattleMapsStackSlot = slot
        healerFrame.UpdateFull = function(stackFrame, timeNow)
            stackFrame.BattleMapsPins:UpdateTeamStackHealerOverlayFrameFull(stackFrame, timeNow)
        end
        healerFrame.UpdatePeriodic = function(stackFrame, timeNow)
            stackFrame.BattleMapsPins:UpdateHealerOverlayFramePeriodic(stackFrame, timeNow)
        end
        healerFrame:SetFrameLevel(parent:GetFrameLevel() + TEAM_STACK_HEALER_OVERLAY_FRAME_LEVEL_OFFSET)
        healerFrame:SetUseClassColor("player", false)
        healerFrame:SetUseClassColor("party", false)
        healerFrame:SetUseClassColor("raid", false)
        healerFrame:SetShouldShowUnits("player", false)
        healerFrame:SetShouldShowUnits("party", true)
        healerFrame:SetShouldShowUnits("raid", true)
        healerFrame:SetNeedsPeriodicUpdate(true)
        healerFrame:SetAlpha(0)
        healerFrame:Show()
        self.teamStackHealerOverlayFrames[slot] = healerFrame

    end
end

function Pins:LayoutTeamStackUnitFrames(step, direction, useNativePositions, reservePlayerSlot, maxOffset)
    local mapFrame = BattleMaps.MapFrame
    local canvas = mapFrame and mapFrame.canvas
    if not canvas or type(self.teamStackUnitFrames) ~= "table" then return false end

    local width, height = canvas:GetSize()
    if not width or width <= 0 or not height or height <= 0 then
        self:HideTeamStackUnitFrames()
        return false
    end

    direction = TEAM_STACK_DIRECTIONS[direction] and direction or "compact"
    step = BattleMaps.Clamp(tonumber(step) or 8, 1, 80)

    for slot, fillFrame in ipairs(self.teamStackUnitFrames) do
        local offsetX, offsetY = 0, 0
        if not useNativePositions then
            -- Reserve the centre slot for the player arrow when it participates
            -- in stacking. The teammate's native position remains the anchor;
            -- only this bounded visual offset is added.
            local patternIndex = slot + (reservePlayerSlot and 1 or 0)
            local vx, vy = GetNativeStackOffset(direction, patternIndex, step)
            maxOffset = tonumber(maxOffset)
            if maxOffset and maxOffset > 0 then
                -- In restricted PvP these are deliberate micro-offsets, not
                -- authoritative proximity stacks. Keep every teammate close to
                -- Blizzard's native position so isolated players and objective
                -- carriers are never displaced by a large roster-slot offset.
                local length = math.sqrt((vx * vx) + (vy * vy))
                if length > maxOffset and length > 0 then
                    local scale = maxOffset / length
                    vx, vy = vx * scale, vy * scale
                end
            end
            offsetX, offsetY = vx, -vy
        end

        local borderFrame = self.teamStackBorderFrames and self.teamStackBorderFrames[slot]
        if borderFrame then
            borderFrame:ClearAllPoints()
            borderFrame:SetPoint("TOPLEFT", canvas, "TOPLEFT", offsetX, offsetY)
            borderFrame:SetFrameLevel(self.parent:GetFrameLevel() + TEAM_STACK_BORDER_FRAME_LEVEL_OFFSET)
            borderFrame:SetSize(width, height)
            borderFrame.BattleMapsBaseOffsetX = offsetX
            borderFrame.BattleMapsBaseOffsetY = offsetY
            borderFrame.BattleMapsFanOffsetX = 0
            borderFrame.BattleMapsFanOffsetY = 0
        end

        fillFrame:ClearAllPoints()
        fillFrame:SetPoint("TOPLEFT", canvas, "TOPLEFT", offsetX, offsetY)
        fillFrame:SetFrameLevel(self.parent:GetFrameLevel() + TEAM_STACK_UNIT_FRAME_LEVEL_OFFSET)
        fillFrame:SetSize(width, height)
        fillFrame.BattleMapsBaseOffsetX = offsetX
        fillFrame.BattleMapsBaseOffsetY = offsetY
        fillFrame.BattleMapsFanOffsetX = 0
        fillFrame.BattleMapsFanOffsetY = 0

        local healerFrame = self.teamStackHealerOverlayFrames and self.teamStackHealerOverlayFrames[slot]
        if healerFrame then
            healerFrame:ClearAllPoints()
            healerFrame:SetPoint("TOPLEFT", canvas, "TOPLEFT", offsetX, offsetY)
            healerFrame:SetFrameLevel(self.parent:GetFrameLevel() + TEAM_STACK_HEALER_OVERLAY_FRAME_LEVEL_OFFSET)
            healerFrame:SetSize(width, height)
            healerFrame.BattleMapsBaseOffsetX = offsetX
            healerFrame.BattleMapsBaseOffsetY = offsetY
            healerFrame.BattleMapsFanOffsetX = 0
            healerFrame.BattleMapsFanOffsetY = 0
        end

        local specFrame = self.teamStackSpecIconFrames and self.teamStackSpecIconFrames[slot]
        if specFrame then
            local _, specOffsetX = self:GetTeamSpecIconMetrics(self.unitTeamSize or 12)
            local specBaseX = offsetX + specOffsetX
            specFrame:ClearAllPoints()
            specFrame:SetPoint("TOPLEFT", canvas, "TOPLEFT", specBaseX, offsetY)
            specFrame:SetFrameLevel(self.parent:GetFrameLevel() + TEAM_STACK_SPEC_ICON_FRAME_LEVEL_OFFSET)
            specFrame:SetSize(width, height)
            specFrame.BattleMapsBaseOffsetX = specBaseX
            specFrame.BattleMapsBaseOffsetY = offsetY
            specFrame.BattleMapsFanOffsetX = 0
            specFrame.BattleMapsFanOffsetY = 0
        end
    end

    return true
end


local function GetTeamFrameCollections(pins)
    return {
        pins.teamStackBorderFrames,
        pins.teamStackUnitFrames,
        pins.teamStackHealerOverlayFrames,
        pins.teamStackSpecIconFrames,
    }
end

function Pins:SetTeamStackSlotFanOffset(slot, offsetX, offsetY)
    local mapFrame = BattleMaps.MapFrame
    local canvas = mapFrame and mapFrame.canvas
    if not canvas then return end

    offsetX = tonumber(offsetX) or 0
    offsetY = tonumber(offsetY) or 0
    for _, collection in ipairs(GetTeamFrameCollections(self)) do
        local frame = type(collection) == "table" and collection[slot] or nil
        if frame then
            local currentX = tonumber(frame.BattleMapsFanOffsetX) or 0
            local currentY = tonumber(frame.BattleMapsFanOffsetY) or 0
            if math.abs(currentX - offsetX) > 0.01 or math.abs(currentY - offsetY) > 0.01 then
                frame.BattleMapsFanOffsetX = offsetX
                frame.BattleMapsFanOffsetY = offsetY
                frame:ClearAllPoints()
                frame:SetPoint(
                    "TOPLEFT",
                    canvas,
                    "TOPLEFT",
                    (tonumber(frame.BattleMapsBaseOffsetX) or 0) + offsetX,
                    (tonumber(frame.BattleMapsBaseOffsetY) or 0) + offsetY
                )
            end
        end
    end
end

function Pins:SetTeamOverlayFanOffset(unit, offsetX, offsetY)
    local mapFrame = BattleMaps.MapFrame
    local canvas = mapFrame and mapFrame.canvas
    if not canvas or type(self.teamStackPinPool) ~= "table" then return end

    for _, frame in ipairs(self.teamStackPinPool) do
        if frame.active and frame.BattleMapsUnit == unit then
            offsetX = tonumber(offsetX) or 0
            offsetY = tonumber(offsetY) or 0
            local currentX = tonumber(frame.BattleMapsFanOffsetX) or 0
            local currentY = tonumber(frame.BattleMapsFanOffsetY) or 0
            if math.abs(currentX - offsetX) > 0.01 or math.abs(currentY - offsetY) > 0.01 then
                frame.BattleMapsFanOffsetX = offsetX
                frame.BattleMapsFanOffsetY = offsetY
                frame:ClearAllPoints()
                frame:SetPoint(
                    "CENTER",
                    canvas,
                    "TOPLEFT",
                    (tonumber(frame.BattleMapsBasePointX) or 0) + offsetX,
                    (tonumber(frame.BattleMapsBasePointY) or 0) + offsetY
                )
            end
            return
        end
    end
end

function Pins:ResetTeamHoverFanOut(clearOnly)
    local state = self.teamHoverFanOutState
    if state and type(state.entries) == "table" and not clearOnly then
        for _, entry in ipairs(state.entries) do
            local unit = entry and entry.unit
            if unit then
                if self.teamStackUnitFrameFallbackActive then
                    self:SetTeamStackSlotFanOffset(GetUnitStackSlot(unit), 0, 0)
                end
                if self.teamStackOverlayActive then
                    self:SetTeamOverlayFanOffset(unit, 0, 0)
                end
            end
        end
    end
    self.teamHoverFanOutState = nil
end

function Pins:ApplyTeamHoverFanOut(entries, pinConfig)
    -- Removed: team pins no longer move in response to mouseover.
end

function Pins:UpdateTeamHoverFanOut(entries)
    self:ResetTeamHoverFanOut()
    return type(entries) == "table" and entries or {}
end

function Pins:PrepareTeamStackUnitFrameFallback(
    unitMapID,
    step,
    direction,
    reservePlayerSlot
)
    if not unitMapID or type(self.teamStackUnitFrames) ~= "table" then return false end

    -- If even one teammate position is restricted, use the secure-frame path
    -- for the complete roster. Mixing coordinate-readable overlay pins with
    -- one-unit secure frames caused the restricted units to disappear on live
    -- battleground maps. Each auxiliary frame owns one stable roster slot (or
    -- several slots in very large raids), so Blizzard remains authoritative for
    -- every live position while BattleMaps applies only a bounded visual offset.
    local teamSize = BattleMaps.Clamp(tonumber(self.unitTeamSize) or 12, 3, 64)
    local mapID = self.unitConfigMapID or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local pinConfig = BattleMaps.Database:GetUnitsConfig(mapID)
    local overlap = BattleMaps.Clamp(tonumber(pinConfig.teamPinStackOverlap) or 45, 0, 80)
    local overlapFraction = overlap / 80
    local maxOffset = BattleMaps.Clamp(
        teamSize * (0.84 - (0.51 * overlapFraction)),
        3,
        12
    )
    local restrictedStep = BattleMaps.Clamp(
        maxOffset * (0.88 - (0.63 * overlapFraction)),
        1,
        maxOffset
    )

    if not self:LayoutTeamStackUnitFrames(
        restrictedStep,
        direction,
        false,
        reservePlayerSlot,
        maxOffset
    ) then
        return false
    end

    local anyActive = false
    local useLayered = self:ShouldUseLayeredTeamPins()
    local useHealerOverlay = self:ShouldUseSplitHealerOverlay()

    for _, fillFrame in ipairs(self.teamStackUnitFrames) do
        local borderFrame = self.teamStackBorderFrames
            and self.teamStackBorderFrames[fillFrame.BattleMapsStackSlot]
        local healerFrame = self.teamStackHealerOverlayFrames
            and self.teamStackHealerOverlayFrames[fillFrame.BattleMapsStackSlot]
        local specFrame = self.teamStackSpecIconFrames
            and self.teamStackSpecIconFrames[fillFrame.BattleMapsStackSlot]

        for _, frame in ipairs({ borderFrame, fillFrame, healerFrame, specFrame }) do
            if frame then
                local targetChanged = frame.BattleMapsTargetUnit ~= nil
                frame.BattleMapsTargetUnit = nil
                if frame.BattleMapsMapID ~= unitMapID or targetChanged then
                    frame.BattleMapsMapID = unitMapID
                    frame:SetUiMapID(unitMapID)
                    frame:SetNeedsFullUpdate()
                end
            end
        end

        fillFrame.BattleMapsActive = true
        fillFrame:SetAlpha(1)
        ConfigureTeamTooltipHitTesting(fillFrame, true)

        if borderFrame then
            borderFrame.BattleMapsActive = useLayered
            borderFrame:SetAlpha(useLayered and 1 or 0)
            ConfigureTeamTooltipHitTesting(borderFrame, false)
        end
        if healerFrame then
            healerFrame.BattleMapsActive = useHealerOverlay
            healerFrame:SetAlpha(useHealerOverlay and 1 or 0)
            ConfigureTeamTooltipHitTesting(healerFrame, false)
        end
        if specFrame then
            specFrame.BattleMapsActive = false
            specFrame:SetAlpha(0)
            ConfigureTeamTooltipHitTesting(specFrame, false)
        end
        anyActive = true
    end

    self.teamStackUnitFrameFallbackActive = anyActive
    self.teamStackFallbackUsesFullRoster = anyActive
    self.teamStackRestrictedFallbackActive = anyActive
    self.teamStackRestrictedMaxOffset = maxOffset
    return anyActive
end

function Pins:UpdateTeamStackUnitFrameFull(frame, timeNow)
    if not frame then return end
    frame:ClearUnits()

    local unitFrame = self.unitFrame
    if not unitFrame then
        frame:FinalizeUnits()
        frame.needsFullUpdate = false
        return
    end

    local memberCount, unitBase = GetLiveGroupRosterSource(unitFrame)
    local targetUnit = frame.BattleMapsTargetUnit
    local targetSlot = targetUnit and nil or (tonumber(frame.BattleMapsStackSlot) or 1)
    local db = BattleMaps.Database:Get()
    local useLayered = self:ShouldUseLayeredTeamPins()
    local useSolidOutOfCombat = db.useSolidTeamPinOutOfCombat ~= false
    local trackHealerCombat = self:ShouldUseSplitHealerOverlay()
    local trackCombat = useSolidOutOfCombat or trackHealerCombat
    local normalSize = self.unitTeamSize or 12
    local healerSettingSize = self.unitHealerSize or 16
    local combatStateByUnit = self.teamCombatStateByUnit or {}
    local seenUnits = {}

    for index = 1, memberCount do
        local unit = unitBase .. index
        if UnitExists(unit)
            and not UnitIsUnit(unit, "player")
            and (not targetUnit or UnitIsUnit(unit, targetUnit))
            and (not targetSlot or GetUnitStackSlot(unit) == targetSlot) then
            local isHealer = self:IsFriendlyHealer(unit)
            local inCombat = trackCombat and self:IsUnitInCombat(unit) or false
            seenUnits[unit] = true
            combatStateByUnit[unit] = inCombat
            local r, g, b = self:GetUnitClassColor(unit, timeNow)

            if useLayered then
                local metrics = self:GetTeamPinMetrics(normalSize, healerSettingSize, normalSize)
                frame:AddUnit(
                    unit,
                    self:GetTeamFillTexture(inCombat, useSolidOutOfCombat, isHealer),
                    metrics.fillSize,
                    metrics.fillSize,
                    r, g, b, 1,
                    GROUP_PIN_SUBLEVEL,
                    false
                )
            else
                local appearance = self:BuildTeamPinAppearance(
                    isHealer, inCombat, normalSize, healerSettingSize, normalSize,
                    useSolidOutOfCombat, r, g, b
                )
                frame:AddUnit(
                    unit,
                    appearance.fillTexture,
                    appearance.fillSize,
                    appearance.fillSize,
                    appearance.r or r, appearance.g or g, appearance.b or b, 1,
                    GROUP_PIN_SUBLEVEL,
                    false
                )
            end
        end
    end

    for unitKey in pairs(combatStateByUnit) do
        if not seenUnits[unitKey]
            and (not targetUnit or UnitIsUnit(unitKey, targetUnit))
            and (not targetSlot or GetUnitStackSlot(unitKey) == targetSlot) then
            combatStateByUnit[unitKey] = nil
        end
    end
    self.teamCombatStateByUnit = combatStateByUnit

    frame:FinalizeUnits()
    self:NormalizeUnitFrameCustomTextures(frame)
    frame.needsFullUpdate = false
end

function Pins:UpdateTeamStackUnitFrames()
    if type(self.teamStackUnitFrames) ~= "table" then return end
    for index, fillFrame in ipairs(self.teamStackUnitFrames) do
        local borderFrame = self.teamStackBorderFrames and self.teamStackBorderFrames[index]
        local healerFrame = self.teamStackHealerOverlayFrames and self.teamStackHealerOverlayFrames[index]
        local specFrame = self.teamStackSpecIconFrames and self.teamStackSpecIconFrames[index]

        for _, frame in ipairs({ borderFrame, fillFrame, healerFrame, specFrame }) do
            if frame and frame.BattleMapsActive then
                if frame.SetNeedsFullUpdate then frame:SetNeedsFullUpdate() end
                frame:UpdatePlayerPins()
                self:NormalizeUnitFrameCustomTextures(frame)
            end
        end
    end
end

function Pins:GetUnitClassColor(unit, timeNow)
    local classFile = select(2, UnitClass(unit))
    local r, g, b = 1, 1, 1
    if classFile then
        local cr, cg, cb = GetClassColor(classFile)
        r, g, b = cr or 1, cg or 1, cb or 1
    end

    if type(CheckColorOverrideForPVPInactive) == "function" then
        local ok, rr, gg, bb = pcall(CheckColorOverrideForPVPInactive, unit, timeNow, r, g, b)
        if ok and rr and gg and bb then
            return rr, gg, bb
        end
    end

    return r, g, b
end

function Pins:UpdateUnitFramePeriodic(unitFrame, timeNow)
    local db = BattleMaps.Database:Get()
    local allowGroupPinRefresh = (unitFrame ~= self.unitFrame) or (self.nativeGroupPinsVisible ~= false)
    local memberCount, unitBase = GetLiveGroupRosterSource(unitFrame)
    local watchCombat = allowGroupPinRefresh and (db.useSolidTeamPinOutOfCombat ~= false
        or self:ShouldUseSplitHealerOverlay())
    local combatStateByUnit = self.teamCombatStateByUnit or {}
    local seenUnits = {}
    local combatTextureChanged = false

    if allowGroupPinRefresh then
        for index = 1, memberCount do
            local unit = unitBase .. index
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                local r, g, b = self:GetUnitClassColor(unit, timeNow)
                unitFrame:SetUnitColor(unit, r, g, b, 1)

                if watchCombat then
                    seenUnits[unit] = true
                    local inCombat = self:IsUnitInCombat(unit)
                    local previous = combatStateByUnit[unit]
                    if previous ~= nil and previous ~= inCombat then
                        combatTextureChanged = true
                    end
                    combatStateByUnit[unit] = inCombat
                end
            end
        end
    end

    if watchCombat then
        for unitKey in pairs(combatStateByUnit) do
            if not seenUnits[unitKey] and unitFrame == self.unitFrame then
                combatStateByUnit[unitKey] = nil
            end
        end
        self.teamCombatStateByUnit = combatStateByUnit

        if combatTextureChanged then
            unitFrame:SetNeedsFullUpdate()
            if unitFrame == self.unitFrame then
                if self.teamBorderFrame then self.teamBorderFrame:SetNeedsFullUpdate() end
                if self.healerOverlayFrame then self.healerOverlayFrame:SetNeedsFullUpdate() end
            else
                local slot = tonumber(unitFrame.BattleMapsStackSlot)
                local borderFrame = slot and self.teamStackBorderFrames and self.teamStackBorderFrames[slot]
                local healerFrame = slot and self.teamStackHealerOverlayFrames and self.teamStackHealerOverlayFrames[slot]
                if borderFrame then borderFrame:SetNeedsFullUpdate() end
                if healerFrame then healerFrame:SetNeedsFullUpdate() end
            end
        end
    elseif next(combatStateByUnit) and unitFrame == self.unitFrame then
        wipe(combatStateByUnit)
        self.teamCombatStateByUnit = combatStateByUnit
    end

    self:NormalizeUnitFrameCustomTextures(unitFrame)
end

function Pins:UpdateUnitFrameFull(unitFrame, timeNow)
    unitFrame:ClearUnits()

    local db = BattleMaps.Database:Get()
    local memberCount, unitBase = GetLiveGroupRosterSource(unitFrame)
    local showNativeGroupPins = self.nativeGroupPinsVisible ~= false
    local useLayered = self:ShouldUseLayeredTeamPins()
    local useSolidOutOfCombat = db.useSolidTeamPinOutOfCombat ~= false
    local trackHealerCombat = self:ShouldUseSplitHealerOverlay()
    local trackCombat = useSolidOutOfCombat or trackHealerCombat
    local normalSize = self.unitTeamSize or 12
    local healerSettingSize = self.unitHealerSize or 16
    local healerCount = 0
    local combatStateByUnit = self.teamCombatStateByUnit or {}
    local seenUnits = {}

    if showNativeGroupPins then
        for index = 1, memberCount do
            local unit = unitBase .. index
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                local isHealer = self:IsFriendlyHealer(unit)
                local inCombat = trackCombat and self:IsUnitInCombat(unit) or false
                seenUnits[unit] = true
                combatStateByUnit[unit] = inCombat
                if isHealer then healerCount = healerCount + 1 end

                local r, g, b = self:GetUnitClassColor(unit, timeNow)

                if useLayered then
                    local metrics = self:GetTeamPinMetrics(normalSize, healerSettingSize, normalSize)
                    unitFrame:AddUnit(
                        unit,
                        self:GetTeamFillTexture(inCombat, useSolidOutOfCombat, isHealer),
                        metrics.fillSize,
                        metrics.fillSize,
                        r, g, b, 1,
                        GROUP_PIN_SUBLEVEL,
                        false
                    )
                else
                    local appearance = self:BuildTeamPinAppearance(
                        isHealer, inCombat, normalSize, healerSettingSize, normalSize,
                        useSolidOutOfCombat, r, g, b
                    )
                    unitFrame:AddUnit(
                        unit,
                        appearance.fillTexture,
                        appearance.fillSize,
                        appearance.fillSize,
                        appearance.r or r, appearance.g or g, appearance.b or b, 1,
                        GROUP_PIN_SUBLEVEL,
                        false
                    )
                end
            end
        end
    end

    for unitKey in pairs(combatStateByUnit) do
        if not seenUnits[unitKey] then combatStateByUnit[unitKey] = nil end
    end
    self.teamCombatStateByUnit = combatStateByUnit

    unitFrame:FinalizeUnits()
    self:NormalizeUnitFrameCustomTextures(unitFrame)
    unitFrame.needsFullUpdate = false

    if self.lastDetectedHealerCount ~= healerCount then
        self.lastDetectedHealerCount = healerCount
        BattleMaps.Debug("friendly healers detected:", healerCount)
    end
end


-- Teammate interaction layer ------------------------------------------------

local function GetUnitDisplayName(unit)
    if not unit or not UnitExists(unit) then return nil end
    if type(GetUnitName) == "function" then
        local ok, name = pcall(GetUnitName, unit, true)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    if type(UnitName) == "function" then
        local ok, name, realm = pcall(UnitName, unit)
        if ok and type(name) == "string" and name ~= "" then
            if type(realm) == "string" and realm ~= "" then
                return name .. "-" .. realm
            end
            return name
        end
    end
    return unit
end

local function IsUnitDeadForMarker(unit)
    if not unit or not UnitExists(unit) then return false end

    if type(UnitIsDeadOrGhost) == "function" then
        local ok, dead = pcall(function()
            local value = UnitIsDeadOrGhost(unit)
            return value == true or value == 1
        end)
        if ok and dead == true then return true end
    end
    if type(UnitIsDead) == "function" then
        local ok, dead = pcall(function()
            local value = UnitIsDead(unit)
            return value == true or value == 1
        end)
        if ok and dead == true then return true end
    end
    if type(UnitIsGhost) == "function" then
        local ok, ghost = pcall(function()
            local value = UnitIsGhost(unit)
            return value == true or value == 1
        end)
        if ok and ghost == true then return true end
    end
    return false
end

function Pins:GetTeamDeathRosterSource()
    return GetLiveGroupRosterSource(self.unitFrame)
end

local function CursorIsInsideFrame(frame, padding)
    if not frame or not frame.IsShown or not frame:IsShown() then return false end
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not left or not right or not top or not bottom then return false end
    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local x, y = GetCursorPosition()
    x, y = x / math.max(scale, 0.001), y / math.max(scale, 0.001)
    padding = tonumber(padding) or 2
    return x >= (left - padding) and x <= (right + padding)
        and y >= (bottom - padding) and y <= (top + padding)
end

function Pins:AcquireTeamDeathMarker(index)
    self.teamDeathMarkerFrames = self.teamDeathMarkerFrames or {}
    local frame = self.teamDeathMarkerFrames[index]
    if frame then return frame end

    frame = CreateFrame("Frame", nil, self.parent)
    frame:SetFrameLevel(self.parent:GetFrameLevel() + TEAM_DEATH_MARKER_FRAME_LEVEL_OFFSET)

    local function CreateBar(layer, sublevel, rotation)
        local texture = frame:CreateTexture(nil, layer, nil, sublevel)
        texture:SetTexture("Interface\\Buttons\\WHITE8X8")
        texture:SetPoint("CENTER", frame, "CENTER", 0, 0)
        texture:SetRotation(rotation)
        return texture
    end

    frame.shadowA = CreateBar("BACKGROUND", 0, math.rad(45))
    frame.shadowB = CreateBar("BACKGROUND", 0, math.rad(-45))
    frame.coreA = CreateBar("ARTWORK", 0, math.rad(45))
    frame.coreB = CreateBar("ARTWORK", 0, math.rad(-45))
    frame.shadowA:SetVertexColor(0, 0, 0, 0.95)
    frame.shadowB:SetVertexColor(0, 0, 0, 0.95)
    frame:Hide()
    self.teamDeathMarkerFrames[index] = frame
    return frame
end

function Pins:ShowTeamDeathMarker(guid, name, mapID, x, y, r, g, b, now)
    if not guid or not x or not y then return false end
    now = tonumber(now) or (type(GetTime) == "function" and GetTime() or 0)
    self.teamDeathMarkersByGUID = self.teamDeathMarkersByGUID or {}

    local record = self.teamDeathMarkersByGUID[guid]
    if not record then
        local index = 1
        while self.teamDeathMarkerFrames and self.teamDeathMarkerFrames[index]
            and self.teamDeathMarkerFrames[index].BattleMapsDeathActive do
            index = index + 1
        end
        local frame = self:AcquireTeamDeathMarker(index)
        record = { frame = frame, guid = guid }
        self.teamDeathMarkersByGUID[guid] = record
    end

    record.name = name or "Teammate"
    record.mapID = tonumber(mapID)
    record.x = BattleMaps.Clamp(tonumber(x) or 0, 0, 1)
    record.y = BattleMaps.Clamp(tonumber(y) or 0, 0, 1)
    record.r, record.g, record.b = r or 1, g or 1, b or 1
    record.expiresAt = now + TEAM_DEATH_MARKER_DURATION
    record.frame.BattleMapsDeathActive = true
    record.frame.BattleMapsDeathRecord = record
    return true
end

function Pins:ClearTeamDeathMarkers()
    if type(self.teamDeathMarkerFrames) == "table" then
        for _, frame in ipairs(self.teamDeathMarkerFrames) do
            frame.BattleMapsDeathActive = false
            frame.BattleMapsDeathRecord = nil
            frame:Hide()
        end
    end
    self.teamDeathMarkersByGUID = {}
end

function Pins:UpdateTeamDeathMarkers(now)
    now = tonumber(now) or (type(GetTime) == "function" and GetTime() or 0)
    local currentMapID = tonumber(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local live = BattleMaps.IsInLiveBattleground and BattleMaps.IsInLiveBattleground()
    if not live then
        if next(self.teamDeathMarkersByGUID or {}) then self:ClearTeamDeathMarkers() end
        return
    end

    local pinConfig = BattleMaps.Database and BattleMaps.Database.GetUnitsConfig
        and BattleMaps.Database:GetUnitsConfig(currentMapID) or {}
    local zoomScale = self.GetPinZoomScale and self:GetPinZoomScale() or 1
    local markerSize = BattleMaps.Clamp((tonumber(pinConfig.teamMemberPinSize) or 12) * zoomScale * 1.18, 6, 80)

    for guid, record in pairs(self.teamDeathMarkersByGUID or {}) do
        local frame = record and record.frame
        if not record or not frame or record.mapID ~= currentMapID or now >= (record.expiresAt or 0) then
            if frame then
                frame.BattleMapsDeathActive = false
                frame.BattleMapsDeathRecord = nil
                frame:Hide()
            end
            self.teamDeathMarkersByGUID[guid] = nil
        else
            local life = BattleMaps.Clamp(((record.expiresAt or now) - now) / TEAM_DEATH_MARKER_DURATION, 0, 1)
            local alpha = life < 0.20 and (life / 0.20) or 1
            frame:SetFrameLevel(self.parent:GetFrameLevel() + TEAM_DEATH_MARKER_FRAME_LEVEL_OFFSET)
            frame:SetSize(markerSize, markerSize)
            frame.shadowA:SetSize(markerSize * 0.92, math.max(markerSize * 0.28, 3))
            frame.shadowB:SetSize(markerSize * 0.92, math.max(markerSize * 0.28, 3))
            frame.coreA:SetSize(markerSize * 0.72, math.max(markerSize * 0.13, 1))
            frame.coreB:SetSize(markerSize * 0.72, math.max(markerSize * 0.13, 1))
            frame.coreA:SetVertexColor(record.r, record.g, record.b, alpha)
            frame.coreB:SetVertexColor(record.r, record.g, record.b, alpha)
            frame.shadowA:SetAlpha(alpha)
            frame.shadowB:SetAlpha(alpha)
            frame:SetAlpha(alpha)
            self:Place(frame, record.x, record.y)
        end
    end
end

function Pins:EvaluateTeamDeathUnit(unit, now, allowInitialDeath)
    if not unit or not UnitExists(unit) or UnitIsUnit(unit, "player") then return false end
    if not (BattleMaps.IsInLiveBattleground and BattleMaps.IsInLiveBattleground()) then return false end

    local mapID = tonumber(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local unitMapID = mapID and (BattleMaps.GetBattlegroundUIMapID
        and BattleMaps.GetBattlegroundUIMapID(mapID, true) or mapID)
    local guid = UnitGUID and UnitGUID(unit)
    if not mapID or not unitMapID or not guid then return false end

    now = tonumber(now) or (type(GetTime) == "function" and GetTime() or 0)
    local states = self.teamDeathStateByGUID or {}
    local positions = self.teamLastKnownPositionByGUID or {}
    local previous = states[guid]
    local dead = IsUnitDeadForMarker(unit)
    local x, y = self:GetTeamStackUnitMapPosition(unitMapID, unit)

    if x and y and not dead then
        positions[guid] = { x = x, y = y, mapID = mapID, time = now }
    end

    local transitioned = previous and previous.dead == false and dead
    local eventDetected = allowInitialDeath == true and dead and (not previous or previous.dead ~= true)
    if transitioned or eventDetected then
        local position = (x and y) and { x = x, y = y, mapID = mapID } or positions[guid]
        if position and position.x and position.y then
            local r, g, b = self:GetUnitClassColor(unit, now)
            self:ShowTeamDeathMarker(
                guid, GetUnitDisplayName(unit), position.mapID or mapID,
                position.x, position.y, r, g, b, now
            )
        end
    end

    states[guid] = { dead = dead, unit = unit, time = now }
    self.teamDeathStateByGUID = states
    self.teamLastKnownPositionByGUID = positions
    return transitioned or eventDetected
end

function Pins:UpdateTeamDeathTracking(now)
    if not (BattleMaps.IsInLiveBattleground and BattleMaps.IsInLiveBattleground()) then
        self.teamDeathStateByGUID = {}
        self.teamLastKnownPositionByGUID = {}
        return
    end

    now = tonumber(now) or (type(GetTime) == "function" and GetTime() or 0)
    local memberCount, unitBase = self:GetTeamDeathRosterSource()
    local states = self.teamDeathStateByGUID or {}
    local positions = self.teamLastKnownPositionByGUID or {}
    local seen = {}

    for index = 1, memberCount do
        local unit = unitBase .. index
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local guid = UnitGUID and UnitGUID(unit)
            if guid then
                seen[guid] = true
                self:EvaluateTeamDeathUnit(unit, now, false)
            end
        end
    end

    states = self.teamDeathStateByGUID or states
    positions = self.teamLastKnownPositionByGUID or positions
    for guid in pairs(states) do
        if not seen[guid] then states[guid] = nil end
    end
    for guid, record in pairs(positions) do
        if not seen[guid] and now - (tonumber(record.time) or 0) > TEAM_DEATH_MARKER_DURATION then
            positions[guid] = nil
        end
    end

    self.teamDeathStateByGUID = states
    self.teamLastKnownPositionByGUID = positions
end

function Pins:ShowTeamDeathMarkerTest()
    local mapID = tonumber(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local unitMapID = mapID and (BattleMaps.GetBattlegroundUIMapID
        and BattleMaps.GetBattlegroundUIMapID(mapID, true) or mapID)
    if not mapID or not unitMapID then return false end

    local x, y = self:GetTeamStackUnitMapPosition(unitMapID, "player")
    if not x or not y then return false end

    local now = type(GetTime) == "function" and GetTime() or 0
    local r, g, b = self:GetUnitClassColor("player", now)
    self:ShowTeamDeathMarker(
        "BattleMapsDeathMarkerTest", "Death marker test", mapID,
        x, y, r, g, b, now
    )
    self:UpdateTeamDeathMarkers(now)
    return true
end

local function AddTooltipUnit(result, seen, unit, displayName, r, g, b, specIcon, specName)
    local key = unit or displayName
    if not key or seen[key] then return end
    if unit == "player" then return end
    if unit and UnitExists(unit) then
        displayName = GetUnitDisplayName(unit) or displayName
    end
    if not displayName or displayName == "" then return end
    seen[key] = true
    result[#result + 1] = {
        unit = unit,
        name = displayName,
        r = r or 1,
        g = g or 1,
        b = b or 1,
        specIcon = specIcon,
        specName = specName,
    }
end

local function BuildTeamTooltipName(entry)
    local name = tostring(entry and entry.name or "Teammate")
    local icon = entry and entry.specIcon
    if icon then
        -- Crop the standard square specialization artwork slightly so its
        -- transparent edge does not create excess spacing in the tooltip row.
        return string.format("|T%s:16:16:0:0:64:64:5:59:5:59|t %s", tostring(icon), name)
    end
    return name
end

function Pins:CollectTeamPinTooltipEntries()
    return {}
end

function Pins:IsTeamTooltipPriorityActive()
    return false
end

function Pins:UpdateTeamPinTooltip()
    self.teamTooltipHasEntries = false
end

function Pins:InitializeTeamInteractionDriver(parent)
    if self.teamInteractionDriver then return end
    local driver = CreateFrame("Frame", nil, parent)
    self.teamInteractionDriver = driver
    driver.elapsedState = 0
    driver:RegisterEvent("UNIT_HEALTH")
    driver:RegisterEvent("UNIT_FLAGS")
    driver:RegisterEvent("UNIT_CONNECTION")
    driver:RegisterEvent("GROUP_ROSTER_UPDATE")
    driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    driver:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    driver:SetScript("OnEvent", function(_, event, unit)
        local now = type(GetTime) == "function" and GetTime() or 0
        if event == "UNIT_HEALTH" or event == "UNIT_FLAGS" or event == "UNIT_CONNECTION" then
            if type(unit) == "string" and (unit:match("^raid%d+$") or unit:match("^party%d+$")) then
                self:EvaluateTeamDeathUnit(unit, now, true)
                self:UpdateTeamDeathMarkers(now)
            end
        else
            -- Rebuild the baseline after roster/zone changes. The ordinary
            -- poll still requires an alive-to-dead transition, so joining a
            -- battleground beside an already-dead teammate does not create a
            -- misleading fresh marker.
            self:UpdateTeamDeathTracking(now)
            self:UpdateTeamDeathMarkers(now)
        end
    end)
    driver:SetScript("OnUpdate", function(_, elapsed)
        driver.elapsedState = driver.elapsedState + elapsed
        local now = type(GetTime) == "function" and GetTime() or 0

        if driver.elapsedState >= TEAM_STATE_POLL_INTERVAL then
            driver.elapsedState = 0
            self:UpdateTeamDeathTracking(now)
            self:UpdateTeamDeathMarkers(now)
        end
    end)
end

function Pins:InitializeUnitFrames(parent)
    local teamBorderFrame = CreateFrame(
        "UnitPositionFrame",
        "BattleMapsTeamBorderFrame",
        parent,
        "UnitPositionFrameTemplate"
    )
    self.teamBorderFrame = teamBorderFrame
    teamBorderFrame.BattleMapsPins = self
    teamBorderFrame.UpdateFull = function(frame, timeNow)
        frame.BattleMapsPins:UpdateTeamBorderFrameFull(frame, timeNow)
    end
    teamBorderFrame.UpdatePeriodic = function(frame, timeNow)
        frame.BattleMapsPins:UpdateTeamBorderFramePeriodic(frame, timeNow)
    end
    teamBorderFrame:SetFrameLevel(parent:GetFrameLevel() + TEAM_BORDER_FRAME_LEVEL_OFFSET)
    teamBorderFrame:SetUseClassColor("player", false)
    teamBorderFrame:SetUseClassColor("party", false)
    teamBorderFrame:SetUseClassColor("raid", false)
    teamBorderFrame:SetShouldShowUnits("player", false)
    teamBorderFrame:SetShouldShowUnits("party", true)
    teamBorderFrame:SetShouldShowUnits("raid", true)
    teamBorderFrame:SetNeedsPeriodicUpdate(true)
    teamBorderFrame:SetAlpha(0)
    teamBorderFrame:Show()

    local unitFrame = CreateFrame(
        "UnitPositionFrame",
        "BattleMapsUnitPositionFrame",
        parent,
        "UnitPositionFrameTemplate"
    )
    self.unitFrame = unitFrame
    unitFrame.BattleMapsPins = self
    unitFrame.UpdateFull = function(frame, timeNow)
        frame.BattleMapsPins:UpdateUnitFrameFull(frame, timeNow)
    end
    unitFrame.UpdatePeriodic = function(frame, timeNow)
        frame.BattleMapsPins:UpdateUnitFramePeriodic(frame, timeNow)
    end
    unitFrame:SetFrameLevel(parent:GetFrameLevel() + UNIT_FRAME_LEVEL_OFFSET)
    unitFrame:SetPinSubLevel("party", GROUP_PIN_SUBLEVEL)
    unitFrame:SetPinSubLevel("raid", GROUP_PIN_SUBLEVEL)
    unitFrame:SetUseClassColor("player", false)
    unitFrame:SetUseClassColor("party", true)
    unitFrame:SetUseClassColor("raid", true)
    unitFrame:SetShouldShowUnits("player", false)
    unitFrame:SetShouldShowUnits("party", true)
    unitFrame:SetShouldShowUnits("raid", true)
    unitFrame:SetNeedsPeriodicUpdate(true)
    unitFrame:SetAlpha(0)
    unitFrame:Show()

    local healerOverlayFrame = CreateFrame(
        "UnitPositionFrame",
        "BattleMapsHealerOverlayFrame",
        parent,
        "UnitPositionFrameTemplate"
    )
    self.healerOverlayFrame = healerOverlayFrame
    healerOverlayFrame.BattleMapsPins = self
    healerOverlayFrame.UpdateFull = function(frame, timeNow)
        frame.BattleMapsPins:UpdateHealerOverlayFrameFull(frame, timeNow)
    end
    healerOverlayFrame.UpdatePeriodic = function(frame, timeNow)
        frame.BattleMapsPins:UpdateHealerOverlayFramePeriodic(frame, timeNow)
    end
    healerOverlayFrame:SetFrameLevel(parent:GetFrameLevel() + HEALER_OVERLAY_FRAME_LEVEL_OFFSET)
    healerOverlayFrame:SetUseClassColor("player", false)
    healerOverlayFrame:SetUseClassColor("party", false)
    healerOverlayFrame:SetUseClassColor("raid", false)
    healerOverlayFrame:SetShouldShowUnits("player", false)
    healerOverlayFrame:SetShouldShowUnits("party", true)
    healerOverlayFrame:SetShouldShowUnits("raid", true)
    healerOverlayFrame:SetNeedsPeriodicUpdate(true)
    healerOverlayFrame:SetAlpha(0)
    healerOverlayFrame:Show()

    self.teamSpecIconFrame = nil

    local playerTeamBorderFrame = CreateFrame(
        "UnitPositionFrame",
        "BattleMapsPlayerTeamBorderFrame",
        parent,
        "UnitPositionFrameTemplate"
    )
    self.playerTeamBorderFrame = playerTeamBorderFrame
    playerTeamBorderFrame.BattleMapsPins = self
    playerTeamBorderFrame.UpdateFull = function(frame)
        frame.BattleMapsPins:UpdatePlayerTeamBorderFrameFull(frame)
    end
    playerTeamBorderFrame.UpdatePeriodic = function() end
    playerTeamBorderFrame:SetFrameLevel(parent:GetFrameLevel() + PLAYER_TEAM_BORDER_FRAME_LEVEL_OFFSET)
    playerTeamBorderFrame:SetPinSubLevel("player", TEAM_BORDER_SUBLEVEL)
    playerTeamBorderFrame:SetUseClassColor("player", false)
    playerTeamBorderFrame:SetShouldShowUnits("player", false)
    playerTeamBorderFrame:SetShouldShowUnits("party", false)
    playerTeamBorderFrame:SetShouldShowUnits("raid", false)
    playerTeamBorderFrame:SetAlpha(0)
    playerTeamBorderFrame:Show()

    local function CreatePlayerFovFrame(layer, frameName)
        local fovFrame = CreateFrame(
            "UnitPositionFrame",
            frameName,
            self:GetPlayerFovLayerRenderParent(layer),
            "UnitPositionFrameTemplate"
        )
        fovFrame.BattleMapsPins = self
        fovFrame.BattleMapsFovLayer = layer
        fovFrame.UpdateFull = function(frame)
            frame.BattleMapsPins:UpdatePlayerFovFrameFull(frame)
        end
        fovFrame.UpdatePeriodic = function(frame)
            frame.BattleMapsPins:UpdatePlayerFovFramePeriodic(frame)
        end
        fovFrame:SetFrameLevel(self:GetPlayerFovLayerFrameLevel(layer))
        fovFrame:SetPinSubLevel("player", PLAYER_FOV_SUBLEVEL)
        fovFrame:SetUseClassColor("player", false)
        fovFrame:SetShouldShowUnits("player", false)
        fovFrame:SetShouldShowUnits("party", false)
        fovFrame:SetShouldShowUnits("raid", false)
        fovFrame:SetNeedsPeriodicUpdate(true)
        fovFrame:SetAlpha(0)
        fovFrame:Show()
        return fovFrame
    end

    self.playerFovFrame = CreatePlayerFovFrame("under", "BattleMapsPlayerFovFrame")
    self.playerFovArcFrame = CreatePlayerFovFrame("arc", "BattleMapsPlayerFovArcFrame")
    self.playerFovBeamFrame = CreatePlayerFovFrame("beam", "BattleMapsPlayerFovBeamFrame")

    local playerFrame = CreateFrame(
        "UnitPositionFrame",
        "BattleMapsPlayerArrowFrame",
        parent,
        "UnitPositionFrameTemplate"
    )
    self.playerFrame = playerFrame
    playerFrame.BattleMapsPins = self
    playerFrame.UpdateFull = function(frame)
        frame.BattleMapsPins:UpdatePlayerFrameFull(frame)
    end
    playerFrame.UpdatePeriodic = function(frame)
        frame.BattleMapsPins:UpdatePlayerFramePeriodic(frame)
    end
    playerFrame:SetFrameLevel(parent:GetFrameLevel() + PLAYER_FRAME_LEVEL_OFFSET)
    playerFrame:SetUseClassColor("player", false)
    playerFrame:SetShouldShowUnits("player", false)
    playerFrame:SetShouldShowUnits("party", false)
    playerFrame:SetShouldShowUnits("raid", false)
    playerFrame:SetNeedsPeriodicUpdate(true)
    playerFrame:SetAlpha(0)
    playerFrame:Show()


    self:InitializeTeamStackUnitFrames(parent)
    self:InitializeTeamInteractionDriver(parent)
end

function Pins:LayoutUnitFrame()
    local mapFrame = BattleMaps.MapFrame
    if not mapFrame or not mapFrame.canvas then return end

    local frames = {
        { frame = self.teamBorderFrame, level = TEAM_BORDER_FRAME_LEVEL_OFFSET, key = "teamBorderFrameAnchored" },
        { frame = self.unitFrame, level = UNIT_FRAME_LEVEL_OFFSET, key = "unitFrameAnchored" },
        { frame = self.healerOverlayFrame, level = HEALER_OVERLAY_FRAME_LEVEL_OFFSET, key = "healerOverlayFrameAnchored" },
        { frame = self.teamSpecIconFrame, level = TEAM_SPEC_ICON_FRAME_LEVEL_OFFSET, key = "teamSpecIconFrameAnchored", specOffset = true },
        { frame = self.playerTeamBorderFrame, level = self.playerTeamBorderFrameLevelOffset or PLAYER_TEAM_BORDER_FRAME_LEVEL_OFFSET, key = "playerTeamBorderFrameAnchored" },
        { frame = self.playerFovFrame, key = "playerFovFrameAnchored", fovLayer = "under" },
        { frame = self.playerFovArcFrame, key = "playerFovArcFrameAnchored", fovLayer = "arc" },
        { frame = self.playerFovBeamFrame, key = "playerFovBeamFrameAnchored", fovLayer = "beam" },
        { frame = self.playerFrame, level = self.playerArrowFrameLevelOffset or PLAYER_FRAME_LEVEL_OFFSET, key = "playerFrameAnchored" },
    }

    local width, height = mapFrame.canvas:GetSize()
    if not width or width <= 0 or not height or height <= 0 then
        for _, info in ipairs(frames) do
            if info.frame then info.frame:SetAlpha(0) end
        end
        self:HideTeamStackUnitFrames()
        return
    end

    local _, specOffsetX = self:GetTeamSpecIconMetrics(self.unitTeamSize or 12)
    for _, info in ipairs(frames) do
        local frame = info.frame
        if frame then
            local desiredX = info.specOffset and specOffsetX or 0
            if not self[info.key] or (info.specOffset and frame.BattleMapsAnchorOffsetX ~= desiredX) then
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", mapFrame.canvas, "TOPLEFT", desiredX, 0)
                frame.BattleMapsAnchorOffsetX = desiredX
                self[info.key] = true
            end
            frame:SetFrameLevel(info.fovLayer and self:GetPlayerFovLayerFrameLevel(info.fovLayer)
                or (self.parent:GetFrameLevel() + info.level))
        end
    end

    if self.unitFrameWidth ~= width or self.unitFrameHeight ~= height then
        self.unitFrameWidth = width
        self.unitFrameHeight = height
        for _, info in ipairs(frames) do
            if info.frame then info.frame:SetSize(width, height) end
        end
    end

    for _, pingFrame in ipairs(self.unitPingFrames) do
        self:LayoutPingUnitFrame(pingFrame)
    end
end

function Pins:RefreshUnits(forceFullUpdate)
    if self:ShouldShowDummyPins() then
        self:SuppressLiveUnitFramesForPreview()
        self:RefreshDummyPins()
        -- Re-render on every settings refresh so Test Mode immediately shows
        -- player style, FoV style, and FoV-scale changes.
        self:RefreshUnitTestPreview()
        return
    end

    self:HideTeamStackTestPreview()
    self:HideDummyPins()

    local mapFrame = BattleMaps.MapFrame
    local mapID = mapFrame and mapFrame.currentMapID
    local unitMapID = mapID and (
        BattleMaps.GetBattlegroundUIMapID
            and BattleMaps.GetBattlegroundUIMapID(mapID, true)
            or mapID
    )
    local unitFrame = self.unitFrame

    if self.liveUnitFramesSuppressedForPreview then
        self.liveUnitFramesSuppressedForPreview = nil
        forceFullUpdate = true
    end

    if not unitFrame or not mapID or not unitMapID then
        self:HideTeamStackOverlay()
        self:HideTeamStackUnitFrames()
        if unitFrame then self:SetNativeGroupPinsVisible(unitFrame, true) end
        for _, frame in ipairs({
            self.teamBorderFrame,
            self.unitFrame,
            self.healerOverlayFrame,
            self.teamSpecIconFrame,
            self.playerTeamBorderFrame,
            self.playerFovFrame,
            self.playerFovArcFrame,
            self.playerFovBeamFrame,
            self.playerFrame,
        }) do
            if frame then
                frame:SetAlpha(0)
                ConfigureTeamTooltipHitTesting(frame, false)
            end
        end
        return
    end

    -- Older running builds may have hidden these frames while suppressing the
    -- Test Mode duplicate. Repair that state before an ordinary map refresh.
    for _, frame in ipairs({
        self.playerTeamBorderFrame,
        self.playerFovFrame,
        self.playerFovArcFrame,
        self.playerFovBeamFrame,
        self.playerFrame,
    }) do
        if frame and not frame:IsShown() then
            frame:Show()
            forceFullUpdate = true
        end
    end

    self:LayoutUnitFrame()

    local db = BattleMaps.Database:Get()
    local pinConfig = BattleMaps.Database:GetUnitsConfig(mapID)
    local renderLivePlayerPosition = self:ShouldRenderLivePlayerPosition()
    if self:SetLivePlayerUnitFramesEnabled(renderLivePlayerPosition) then
        forceFullUpdate = true
    end
    if self.livePlayerPositionRenderActive ~= renderLivePlayerPosition then
        self.livePlayerPositionRenderActive = renderLivePlayerPosition
        forceFullUpdate = true
    end
    local playerFrameLevelOffset = pinConfig.excludePlayerArrowFromStack == true
        and PLAYER_BEHIND_TEAM_FRAME_LEVEL_OFFSET
        or PLAYER_FRAME_LEVEL_OFFSET
    local playerTeamBorderFrameLevelOffset = playerFrameLevelOffset - 1
    if self.playerArrowFrameLevelOffset ~= playerFrameLevelOffset then
        self.playerArrowFrameLevelOffset = playerFrameLevelOffset
        if self.playerFrame then
            self.playerFrame:SetFrameLevel(self.parent:GetFrameLevel() + playerFrameLevelOffset)
        end
    end
    if self.playerTeamBorderFrameLevelOffset ~= playerTeamBorderFrameLevelOffset then
        self.playerTeamBorderFrameLevelOffset = playerTeamBorderFrameLevelOffset
        if self.playerTeamBorderFrame then
            self.playerTeamBorderFrame:SetFrameLevel(self.parent:GetFrameLevel() + playerTeamBorderFrameLevelOffset)
        end
    end
    local zoomScale = self:GetPinZoomScale()
    local teamSize = BattleMaps.Clamp((tonumber(pinConfig.teamMemberPinSize) or 12) * zoomScale, 3, 64)
    local playerSize = BattleMaps.Clamp((tonumber(pinConfig.playerArrowSize) or 22) * zoomScale, 12, 256)
    local playerAppearance = self:GetPlayerPinAppearance(pinConfig, playerSize, teamSize)
    local fovStyle = self:GetPlayerFovStyle(pinConfig)
    local fovSize = self:GetPlayerFovSize(pinConfig, zoomScale)
    local healerSettingSize = BattleMaps.Clamp(tonumber(pinConfig.healerPinSize) or 16, 0.50, 160)
    local metrics = self:GetTeamPinMetrics(
        teamSize,
        healerSettingSize,
        teamSize,
        playerAppearance.borderSize or playerAppearance.size
    )

    if self.unitMapID ~= unitMapID or self.unitConfigMapID ~= mapID then
        self:StopAllPings()
        self.unitMapID = unitMapID
        self.unitConfigMapID = mapID

        for _, frame in ipairs({
            self.teamBorderFrame,
            self.unitFrame,
            self.healerOverlayFrame,
            self.teamSpecIconFrame,
            self.playerTeamBorderFrame,
            self.playerFovFrame,
            self.playerFovArcFrame,
            self.playerFovBeamFrame,
            self.playerFrame,
        }) do
            if frame then
                if not frame:IsShown() then frame:Show() end
                frame:SetUiMapID(unitMapID)
                frame:UpdateAppearanceData()
            end
        end

        BattleMaps.Debug("unit map resolved", "config=", tostring(mapID), "ui=", tostring(unitMapID))
        for _, pingFrame in ipairs(self.unitPingFrames) do
            self:LayoutPingUnitFrame(pingFrame)
            pingFrame:SetNeedsFullUpdate()
        end
        forceFullUpdate = true
    end

    local playerAppearanceKey = table.concat({
        playerAppearance.style,
        tostring(playerAppearance.size),
        tostring(playerAppearance.borderSize or 0),
        tostring(playerAppearance.texture or ""),
    }, ":")
    self.unitPlayerAppearance = playerAppearance
    if self.unitPlayerSize ~= playerSize or self.unitPlayerAppearanceKey ~= playerAppearanceKey then
        self.unitPlayerSize = playerSize
        self.unitPlayerAppearanceKey = playerAppearanceKey
        if self.playerFrame then self.playerFrame:SetPinSize("player", playerAppearance.size) end
        if self.playerTeamBorderFrame then
            self.playerTeamBorderFrame:SetPinSize("player", playerAppearance.borderSize or playerAppearance.size)
        end
        forceFullUpdate = true
    end
    if self.unitFovSize ~= fovSize or self.unitFovStyle ~= fovStyle then
        self.unitFovSize = fovSize
        self.unitFovStyle = fovStyle
        for _, frame in ipairs({ self.playerFovFrame, self.playerFovArcFrame, self.playerFovBeamFrame }) do
            if frame then frame:SetPinSize("player", fovSize) end
        end
        forceFullUpdate = true
    end
    if self.unitTeamSize ~= teamSize then
        self.unitTeamSize = teamSize
        self.teamSpecIconFrameAnchored = false
        if self.teamBorderFrame then
            self.teamBorderFrame:SetPinSize("party", metrics.borderSize)
            self.teamBorderFrame:SetPinSize("raid", metrics.borderSize)
        end
        unitFrame:SetPinSize("party", metrics.fillSize)
        unitFrame:SetPinSize("raid", metrics.fillSize)
        forceFullUpdate = true
    end
    if self.unitHealerSize ~= healerSettingSize then
        self.unitHealerSize = healerSettingSize
        forceFullUpdate = true
    end
    self:LayoutUnitFrame()

    local teamStackEntries, teamStackPlayerEntry, missingTeamStackUnits
    local useTeamStackOverlay = false
    local useTeamStackUnitFrameFallback = false
    local stackStep
    local stackDirection = pinConfig.teamPinStackDirection or "compact"
    if pinConfig.stackTeamPins ~= false then
        local excludePlayerArrow = pinConfig.excludePlayerArrowFromStack == true
        teamStackEntries, teamStackPlayerEntry, missingTeamStackUnits = self:BuildTeamStackEntries(
            unitMapID,
            GetTime(),
            excludePlayerArrow
        )
        local radius = tonumber(pinConfig.teamPinStackRadius) or 18
        local overlap = BattleMaps.Clamp(tonumber(pinConfig.teamPinStackOverlap) or 45, 0, 80)
        local stackCollisionSize = teamSize
        for _, entry in ipairs(teamStackEntries or {}) do
            stackCollisionSize = math.max(
                stackCollisionSize,
                tonumber(entry.collisionSize or entry.borderSize or entry.size) or 0
            )
        end
        stackStep = BattleMaps.Clamp(stackCollisionSize * (1 - (overlap / 100)), 1, 80)
        if teamStackEntries then
            self:ApplyTeamStackOffsets(
                teamStackEntries,
                teamStackPlayerEntry,
                radius,
                stackStep,
                stackDirection,
                self.unitFrameWidth or 1,
                self.unitFrameHeight or 1
            )
            useTeamStackOverlay = true
        end

        -- Blizzard restricts teammate coordinates in live battlegrounds, so
        -- true radius clustering cannot be calculated there. Use the existing
        -- per-roster UnitPositionFrames with small, bounded, deterministic
        -- offsets. This preserves Blizzard's native position while making
        -- overlapping groups readable at a glance without mouse interaction.
        -- The offset cap is intentionally much smaller than one team pin.
        if type(missingTeamStackUnits) == "table" and #missingTeamStackUnits > 0 then
            useTeamStackOverlay = false
            teamStackEntries = nil
            useTeamStackUnitFrameFallback = self:PrepareTeamStackUnitFrameFallback(
                unitMapID,
                stackStep,
                stackDirection,
                pinConfig.excludePlayerArrowFromStack ~= true
            )
        end
    end

    local showNativeTeam = not (useTeamStackOverlay or useTeamStackUnitFrameFallback)
    ConfigureTeamTooltipHitTesting(unitFrame, showNativeTeam)
    ConfigureTeamTooltipHitTesting(self.teamBorderFrame, false)
    ConfigureTeamTooltipHitTesting(self.healerOverlayFrame, false)
    ConfigureTeamTooltipHitTesting(self.teamSpecIconFrame, false)
    ConfigureTeamTooltipHitTesting(self.playerTeamBorderFrame, false)
    ConfigureTeamTooltipHitTesting(self.playerFovFrame, false)
    ConfigureTeamTooltipHitTesting(self.playerFovArcFrame, false)
    ConfigureTeamTooltipHitTesting(self.playerFovBeamFrame, false)
    ConfigureTeamTooltipHitTesting(self.playerFrame, false)
    if self:SetNativeGroupPinsVisible(unitFrame, showNativeTeam) then forceFullUpdate = true end
    if not useTeamStackUnitFrameFallback then
        self:HideTeamStackUnitFrames()
    else
        self.teamStackRestrictedFallbackActive = true
    end

    if forceFullUpdate then
        for _, frame in ipairs({
            self.teamBorderFrame,
            self.unitFrame,
            self.healerOverlayFrame,
            self.teamSpecIconFrame,
            self.playerTeamBorderFrame,
            self.playerFovFrame,
            self.playerFovArcFrame,
            self.playerFovBeamFrame,
            self.playerFrame,
        }) do
            if frame then frame:SetNeedsFullUpdate() end
        end
        for _, pingFrame in ipairs(self.unitPingFrames) do
            self:LayoutPingUnitFrame(pingFrame)
            pingFrame:SetNeedsFullUpdate()
        end
        for _, collection in ipairs({ self.teamStackBorderFrames, self.teamStackUnitFrames, self.teamStackHealerOverlayFrames, self.teamStackSpecIconFrames }) do
            if type(collection) == "table" then
                for _, frame in ipairs(collection) do frame:SetNeedsFullUpdate() end
            end
        end
    end

    -- FoV passes occupy dedicated under-map, above-map, and pin-layer levels.
    -- The player marker remains above all three passes.
    for _, info in ipairs({
        { layer = "under", frame = self.playerFovFrame },
        { layer = "arc", frame = self.playerFovArcFrame },
        { layer = "beam", frame = self.playerFovBeamFrame },
    }) do
        local frame = info.frame
        if frame then
            local appearance = self:GetPlayerFovLayerAppearance(pinConfig, info.layer)
            local showFov = renderLivePlayerPosition and appearance ~= nil
            frame:SetAlpha(showFov and 1 or 0)
            frame:UpdatePlayerPins()
            if showFov then
                self:ConfigurePlayerFovFrameTextures(frame, appearance)
            end
        end
    end
    if self.playerTeamBorderFrame then
        local showPlayerTeamBorder = renderLivePlayerPosition
            and self.unitPlayerAppearance and self.unitPlayerAppearance.style == "team"
        self.playerTeamBorderFrame:SetAlpha(showPlayerTeamBorder and 1 or 0)
        self.playerTeamBorderFrame:UpdatePlayerPins()
        if showPlayerTeamBorder then
            self:NormalizeUnitFrameCustomTextures(self.playerTeamBorderFrame)
        end
    end
    if self.playerFrame then
        self.playerFrame:SetAlpha(renderLivePlayerPosition and 1 or 0)
        self.playerFrame:UpdatePlayerPins()
        if renderLivePlayerPosition then self:NormalizeUnitFrameCustomTextures(self.playerFrame) end
    end

    if showNativeTeam then
        unitFrame:SetAlpha(1)
        unitFrame:UpdatePlayerPins()
        self:NormalizeUnitFrameCustomTextures(unitFrame)

        local useLayered = self:ShouldUseLayeredTeamPins()
        if self.teamBorderFrame then
            self.teamBorderFrame:SetAlpha(useLayered and 1 or 0)
            if useLayered then
                self.teamBorderFrame:UpdatePlayerPins()
                self:NormalizeUnitFrameCustomTextures(self.teamBorderFrame)
            end
        end
        if self.healerOverlayFrame then
            local useHealer = self:ShouldUseSplitHealerOverlay()
            self.healerOverlayFrame:SetAlpha(useHealer and 1 or 0)
            if useHealer then
                self.healerOverlayFrame:UpdatePlayerPins()
                self:NormalizeUnitFrameCustomTextures(self.healerOverlayFrame)
            end
        end
        if self.teamSpecIconFrame then self.teamSpecIconFrame:SetAlpha(0) end
    else
        unitFrame:SetAlpha(0)
        if self.teamBorderFrame then self.teamBorderFrame:SetAlpha(0) end
        if self.healerOverlayFrame then self.healerOverlayFrame:SetAlpha(0) end
        if self.teamSpecIconFrame then self.teamSpecIconFrame:SetAlpha(0) end
    end

    if useTeamStackOverlay then
        self:RenderTeamStackOverlay(teamStackEntries, self.unitFrameWidth or 1, self.unitFrameHeight or 1)
    else
        self:HideTeamStackOverlay()
    end
    if useTeamStackUnitFrameFallback then self:UpdateTeamStackUnitFrames() end

    for _, pingFrame in ipairs(self.unitPingFrames) do
        if pingFrame:IsShown() then pingFrame:UpdatePlayerPins() end
    end

end

function Pins:RefreshPlayer()
    self:RefreshUnits(false)
end

function Pins:RefreshGroup()
    self:RefreshUnits(true)
end

-- PreviewPins.lua loads after this module and delegates unit-test rendering to
-- RefreshUnitTestPreview/HideUnitTestPreview. No method wrapping or legacy
-- frame suppression is required.
