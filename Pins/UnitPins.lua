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
local CUSTOM_HEALER_CROSS_BORDER_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\healer_cross_border.tga"
local CUSTOM_HEALER_COMBAT_CROSS_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\healer_cross_combat.tga"

-- Previous single-layer media remain as graceful fallbacks while users replace
-- files or when one of the new layered assets is absent.
local CUSTOM_TEAM_PIN_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\team_circle_dot.tga"
local CUSTOM_TEAM_COMBAT_PIN_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\team_circle_white.tga"
local CUSTOM_HEALER_PIN_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\healer.tga"

local DEFAULT_PLAYER_ARROW_TEXTURE = "UI-WorldMapArrow"
local CUSTOM_PLAYER_ARROW_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\player_arrow.tga"
local CUSTOM_PLAYER_COMPASS_TEXTURE = "Interface\\AddOns\\BattleMaps\\Media\\player_compass.tga"
local PLAYER_FOV_LAYER_TEXTURES = {
    -- Semantic FoV artwork used by the current Sunbeam development stack.
    -- Keep these names map-independent: map-specific shaping belongs in masks.
    core = "Interface\\AddOns\\BattleMaps\\Media\\FoV\\Layers\\fov_core.tga",
    terrain = "Interface\\AddOns\\BattleMaps\\Media\\FoV\\Layers\\fov_terrain.tga",
}

local PLAYER_FOV_STYLES = {
    -- The renderer uses its proven under/beam frame slots so live BG positioning
    -- and rotation remain unchanged. maskKind describes the semantic role of
    -- each pass: core or terrain.
    simple = {
        under = {
            texture = "Interface\\AddOns\\BattleMaps\\Media\\fov_cone_simple.tga",
            blendMode = "ADD",
            aspect = 1,
            maskKind = "core",
        },
    },
    coldRays = {
        under = {
            texture = "Interface\\AddOns\\BattleMaps\\Media\\fov_cone_cool.tga",
            blendMode = "ADD",
            aspect = 1,
            maskKind = "core",
        },
        beam = {
            texture = "Interface\\AddOns\\BattleMaps\\Media\\fov_core_split.tga",
            blendMode = "ADD",
            aspect = 1,
            alphaSetting = "playerFovBeamAlpha",
            maskKind = "terrain",
        },
    },
    sunbeam = {
        -- Sunbeam uses the two retained semantic layer roles:
        --   core      = BLEND, main FoV alpha
        --   terrain = ADD, main FoV alpha * Beam alpha
        under = {
            texture = PLAYER_FOV_LAYER_TEXTURES.core,
            blendMode = "BLEND",
            aspect = 1,
            maskKind = "core",
        },
        beam = {
            texture = PLAYER_FOV_LAYER_TEXTURES.terrain,
            blendMode = "ADD",
            aspect = 1,
            alphaSetting = "playerFovBeamAlpha",
            maskKind = "terrain",
        },
    },
}
local PLAYER_FOV_LAYER_ORDER = { "under", "beam" }

-- Map-space masks are keyed by semantic layer role. Every supported non-epic
-- battleground follows the same core/terrain contract. Keeping the
-- folder name separate from the numeric aliases makes it straightforward to
-- author a map once even when Blizzard exposes more than one ID for it.
local function BuildPlayerFovMaskSet(folder)
    local root = "Interface\\AddOns\\BattleMaps\\Media\\FoV\\Masks\\" .. folder .. "\\"
    return {
        -- Test Mode consumes the generated rectangle-union assets so its mask
        -- boundary is identical to the compiled live geometry. The unsuffixed
        -- files remain the editable authoring inputs.
        core = root .. "core_mask_live.tga",
        terrain = root .. "terrain_mask_live.tga",
    }
end

local PLAYER_FOV_MASK_SETS = {
    ArathiBasin = BuildPlayerFovMaskSet("ArathiBasin"),
    BattleForGilneas = BuildPlayerFovMaskSet("BattleForGilneas"),
    DeepwindGorge = BuildPlayerFovMaskSet("DeepwindGorge"),
    DeephaulRavine = BuildPlayerFovMaskSet("DeephaulRavine"),
    EyeOfTheStorm = BuildPlayerFovMaskSet("EyeOfTheStorm"),
    SeethingShore = BuildPlayerFovMaskSet("SeethingShore"),
    SilvershardMines = BuildPlayerFovMaskSet("SilvershardMines"),
    TempleOfKotmogu = BuildPlayerFovMaskSet("TempleOfKotmogu"),
    TwinPeaks = BuildPlayerFovMaskSet("TwinPeaks"),
    WarsongGulch = BuildPlayerFovMaskSet("WarsongGulch"),
}

local PLAYER_FOV_MAP_MASKS = {
    [112] = PLAYER_FOV_MASK_SETS.ArathiBasin,       -- Arathi Basin legacy/config
    [1366] = PLAYER_FOV_MASK_SETS.ArathiBasin,      -- Arathi Basin modern UI map

    [275] = PLAYER_FOV_MASK_SETS.BattleForGilneas,  -- Battle for Gilneas
    [761] = PLAYER_FOV_MASK_SETS.BattleForGilneas,  -- Battle for Gilneas alias

    [1576] = PLAYER_FOV_MASK_SETS.DeepwindGorge,     -- Deepwind Gorge
    [2345] = PLAYER_FOV_MASK_SETS.DeephaulRavine,    -- Deephaul Ravine
    [210] = PLAYER_FOV_MASK_SETS.EyeOfTheStorm,      -- Eye of the Storm config

    [907] = PLAYER_FOV_MASK_SETS.SeethingShore,      -- Seething Shore
    [1803] = PLAYER_FOV_MASK_SETS.SeethingShore,     -- Seething Shore alias

    [423] = PLAYER_FOV_MASK_SETS.SilvershardMines,   -- Silvershard Mines
    [727] = PLAYER_FOV_MASK_SETS.SilvershardMines,   -- Silvershard Mines alias

    [417] = PLAYER_FOV_MASK_SETS.TempleOfKotmogu,    -- Temple of Kotmogu
    [998] = PLAYER_FOV_MASK_SETS.TempleOfKotmogu,    -- Temple of Kotmogu alias

    [726] = PLAYER_FOV_MASK_SETS.TwinPeaks,           -- Twin Peaks

    [206] = PLAYER_FOV_MASK_SETS.WarsongGulch,        -- Warsong Gulch legacy/config
    [1339] = PLAYER_FOV_MASK_SETS.WarsongGulch,       -- Warsong Gulch modern UI map
}

-- UnitPositionFrame keeps live battleground coordinates inside the client and
-- does not expose its rendered pin as a Lua Texture. Retail does, however,
-- clip an addon-owned UnitPositionFrame to an ordinary parent's rectangle.
-- These compact strings are adaptive midpoint contours compiled from the alpha
-- channels of the corresponding map-space TGA masks. Each partial definition
-- starts with its columns/rows; every four-character run is x, y, width, height
-- in grid cells. The compiler selects the finest map-proportional grid that
-- stays within the native-frame budget for that layer.
local PLAYER_FOV_LIVE_MASK_MAX_GRID_SIZE = 64
local PLAYER_FOV_LIVE_MASK_ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_~"
local PLAYER_FOV_LIVE_MASK_MAX_RECTS = 32
local PLAYER_FOV_LIVE_MASK_FULL_RECTANGLES = {
    { x = 0, y = 0, width = 1, height = 1 },
}
local PLAYER_FOV_LIVE_MASK_GEOMETRY_SOURCE = {
    ArathiBasin = {
        core = "64x43:g481g591g6c2g8p6kel3khm4lll2lnm2lpo4vte2yvb2",
        terrain = "64x43:d1A6d7k1d8j1D7a2F982d9i3dck2del1Gb74dff1xf21Ff81xgg1yhf1dge3mj51ok41pl41zie4qm41ymf1rnm1dj79ds81ps21tok5dtA7",
    },
    BattleForGilneas = {
        core = "64x43:u4d1q5j1n6n1l7p1k8p1i9q1har2gcs1gdt1gev1gfx2ghy1gix1gju1gks1hlr4ipr2irs1hsu1gtv1euy1dvz1cwA2cyz1dzy1dAw1fBr1gCo1iDm1mEb1zE41",
        terrain = "full",
    },
    DeephaulRavine = {
        core = "64x43:e9a18ao16br16cs27er27gt17hv17ix16jA15kD25m71gmt16n21gnu1gov1hpv1oqq1prs1qst1rtt1rus2swo1vxk1xyh1yzg1AAc1CB41HB11",
        terrain = "full",
    },
    DeepwindGorge = {
        core = "48x32:f141e271v241d3b1u361d4f1t481e5n1e6o1b7r188u179w16ax16by16cz15dA15eB15fC26hB18iz19jy1akx2cmu1cnt1cor1cpo2crn1es21msd1ot31st61",
        terrain = "24x16:7131f121a211f2319311c311g3314412a5313611b6217514a811k712b911g921j9215a31ba316b31cb11ha42hc216c72ce21",
    },
    EyeOfTheStorm = {
        core = "64x43:s861q991paa1pbb3pec2pgd1ohe2ojd1pk81tl41tm51sn91ooe1npf1oqe2psd1ptc1qub2qwa1rx91sy71",
        terrain = "64x43:r781p8b1o9c1oad1nbe2ndf2nfg1ngh4mki7nrg3ouf1ove2pxd1pyc1qza1rA71",
    },
    SeethingShore = {
        core = "64x43:m621v651M691k7l1K7c1i8E1g9F1gaG2ecI1cdK1beL3bhM2ajN19kO4aoN29qN2asM1dtJ1euH2ewI2ey71fz51nyz2oAx2rCs1",
        terrain = "32x21:8141h141o16162o153k144i135h126j127a1f761289119910a91ca312b61bb51ib41ac51jc213c52ad313ea24ga25i919j51bk31",
    },
    SilvershardMines = {
        core = "64x43:g3p1f4r1J471f5D2f7E2f9D1eaD1ebC1ecB1ddB1ceC1afE18gF17hG16iH16jG27lF28nE19oD1apC1dqA1frz1gsz1htz6hzy2hBx1hCj1FC71iDf1HD31jEc1kF91",
        terrain = "40x27:i341h461f5c1t521d6j1c7j1a8l189n16ao15b71ibc15c61icb15d51hdc17e21ged1ffa1eg91rf22eh81qh31qi41ei43dl51pj53qm31cm62rn11co51dp21",
    },
    TempleOfKotmogu = {
        core = "64x43:q971mag1kbo1ics1gdv1gew1ffy16f42fgz1Pg416h51ehG16iO55nP15oQ26q61dqI17r31Qr41Rs21erz6fxx2izs1mA61vA81",
        terrain = "24x16:8221d211d3525363c561m51126215631b611f641l6211772e7922961f9812a115a41aa31fa31ka31cb615b62dc516d41dd618e21he11",
    },
    TwinPeaks = {
        core = "64x43:v341t4b1s5e1r6f1r7g1q8h2qag1pbh1och3nfi1ogh2oii1pjh2oli4npj3nsi2ouh1pvg1pwh3qzg1qAf1rBd1tC81",
        terrain = "40x27:g021d111f171c2b1d3a1d492e681f771p721f8c2fab1fb81fc71ed61qd31be71oe51bf61mf71cg51kg81eh31ei41kh72fj21kj11gk11pj22ol31nm52po31",
    },
    WarsongGulch = {
        core = "64x43:s091s1a1r2b2q4c1q5d1p6e1o7g1o8h1n9j1mak1lbm1lcn1mdm3mgn6lmo3lpn3msl2nuj2nwi1nxh2nzg1nAf1nBe2oDc1tE61",
        terrain = "64x43:Ca21nb91Bb31mcb1Ac41ndi2nfj1ngk2oij5nnk1mol5ltl1muk1mv81zv61pw21",
    },
}

local function DecodePlayerFovLiveMaskGeometry(encoded)
    if encoded == "full" then return { full = true, columns = 1, rows = 1 } end
    if encoded == "empty" then return { empty = true, columns = 1, rows = 1 } end
    if type(encoded) ~= "string" then return nil end

    local columns, rows, rectangleData = encoded:match("^(%d+)x(%d+):(.+)$")
    columns, rows = tonumber(columns), tonumber(rows)
    if not columns or not rows or not rectangleData
        or columns < 1 or columns > PLAYER_FOV_LIVE_MASK_MAX_GRID_SIZE
        or rows < 1 or rows > PLAYER_FOV_LIVE_MASK_MAX_GRID_SIZE
        or #rectangleData % 4 ~= 0 then
        return nil
    end

    local rectangles = {}
    for offset = 1, #rectangleData, 4 do
        local values = {}
        for component = 0, 3 do
            local token = rectangleData:sub(offset + component, offset + component)
            local index = PLAYER_FOV_LIVE_MASK_ALPHABET:find(token, 1, true)
            if not index then return nil end
            values[component + 1] = index - 1
        end

        local x, y, width, height = values[1], values[2], values[3], values[4]
        if width <= 0 or height <= 0
            or x + width > columns
            or y + height > rows then
            return nil
        end
        rectangles[#rectangles + 1] = { x = x, y = y, width = width, height = height }
    end
    if #rectangles > PLAYER_FOV_LIVE_MASK_MAX_RECTS then return nil end
    return { columns = columns, rows = rows, rectangles = rectangles }
end

local PLAYER_FOV_LIVE_MASK_GEOMETRY_SETS = {}
for setName, definitions in pairs(PLAYER_FOV_LIVE_MASK_GEOMETRY_SOURCE) do
    local decoded = {}
    for semanticKind, encoded in pairs(definitions) do
        decoded[semanticKind] = DecodePlayerFovLiveMaskGeometry(encoded)
    end
    PLAYER_FOV_LIVE_MASK_GEOMETRY_SETS[setName] = decoded
end

local PLAYER_FOV_LIVE_MAP_MASK_GEOMETRY = {
    [112] = PLAYER_FOV_LIVE_MASK_GEOMETRY_SETS.ArathiBasin,
    [1366] = PLAYER_FOV_LIVE_MASK_GEOMETRY_SETS.ArathiBasin,
    [275] = PLAYER_FOV_LIVE_MASK_GEOMETRY_SETS.BattleForGilneas,
    [761] = PLAYER_FOV_LIVE_MASK_GEOMETRY_SETS.BattleForGilneas,
    [1576] = PLAYER_FOV_LIVE_MASK_GEOMETRY_SETS.DeepwindGorge,
    [2345] = PLAYER_FOV_LIVE_MASK_GEOMETRY_SETS.DeephaulRavine,
    [210] = PLAYER_FOV_LIVE_MASK_GEOMETRY_SETS.EyeOfTheStorm,
    [907] = PLAYER_FOV_LIVE_MASK_GEOMETRY_SETS.SeethingShore,
    [1803] = PLAYER_FOV_LIVE_MASK_GEOMETRY_SETS.SeethingShore,
    [423] = PLAYER_FOV_LIVE_MASK_GEOMETRY_SETS.SilvershardMines,
    [727] = PLAYER_FOV_LIVE_MASK_GEOMETRY_SETS.SilvershardMines,
    [417] = PLAYER_FOV_LIVE_MASK_GEOMETRY_SETS.TempleOfKotmogu,
    [998] = PLAYER_FOV_LIVE_MASK_GEOMETRY_SETS.TempleOfKotmogu,
    [726] = PLAYER_FOV_LIVE_MASK_GEOMETRY_SETS.TwinPeaks,
    [206] = PLAYER_FOV_LIVE_MASK_GEOMETRY_SETS.WarsongGulch,
    [1339] = PLAYER_FOV_LIVE_MASK_GEOMETRY_SETS.WarsongGulch,
}

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
-- sits above every black unit backplate and below every coloured unit layer.
local PLAYER_FOV_BEAM_FRAME_LEVEL_OFFSET = 61
local TEAM_BORDER_FRAME_LEVEL_OFFSET = 59
local TEAM_STACK_BORDER_FRAME_LEVEL_OFFSET = 60
local PLAYER_BEHIND_TEAM_FRAME_LEVEL_OFFSET = 62
local UNIT_FRAME_LEVEL_OFFSET = 63
local TEAM_STACK_UNIT_FRAME_LEVEL_OFFSET = 64
local HEALER_OVERLAY_FRAME_LEVEL_OFFSET = 65
local TEAM_STACK_HEALER_OVERLAY_FRAME_LEVEL_OFFSET = 66
local TEAM_SPEC_ICON_FRAME_LEVEL_OFFSET = 67
local TEAM_STACK_SPEC_ICON_FRAME_LEVEL_OFFSET = 68
local TEAM_STACK_FRAME_LEVEL_OFFSET = TEAM_STACK_UNIT_FRAME_LEVEL_OFFSET
local PLAYER_FRAME_LEVEL_OFFSET = 69
local PLAYER_TEAM_BORDER_FRAME_LEVEL_OFFSET = TEAM_STACK_BORDER_FRAME_LEVEL_OFFSET
local TEAM_DEATH_MARKER_FRAME_LEVEL_OFFSET = 70
local MAX_TEAM_STACK_UNIT_FRAMES = 16
local TEAM_DEATH_MARKER_DURATION = 10.00
local TEAM_STATE_POLL_INTERVAL = 0.15
local TEAM_TOOLTIP_POLL_INTERVAL = 0.02
local TEAM_SPEC_INSPECT_INTERVAL = 0.75
local PLAYER_FOV_BASE_SIZE = 96
-- The default 420 px map frame leaves a 414 px-wide viewport after its border.
-- FoV artwork represents map area rather than a readability-sized icon, so
-- keep its footprint proportional to the fully zoomed canvas width.
local PLAYER_FOV_REFERENCE_CANVAS_WIDTH = 414
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
    local count, prefix = GetLiveGroupRosterSource(self.unitFrame)
    local mode = self.teamStackLiveActive and "live-separation" or "native"
    local spread = ""
    if self.teamStackLiveActive and tonumber(self.teamStackMaxOffset) then
        spread = string.format(", spread<=%.1fpx", tonumber(self.teamStackMaxOffset) or 0)
    end

    BattleMaps.Chat(string.format(
        "Team stacking: roster=%s%d, mode=%s, native=%s%s.",
        tostring(prefix or "raid"), tonumber(count) or 0, mode,
        self.nativeGroupPinsVisible == false and "hidden" or "shown",
        spread
    ))
end

local function IsFovDiagnosticSecret(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == true
end

local function DescribeFovDiagnosticValue(value)
    if IsFovDiagnosticSecret(value) then return "secret" end
    if value == nil then return "nil" end
    local valueType = type(value)
    if valueType == "number" then return string.format("%.4f", value) end
    if valueType == "boolean" or valueType == "string" then return tostring(value) end
    return valueType
end

local function GetFovDiagnosticMapPosition(unitMapID)
    if not unitMapID or not C_Map or type(C_Map.GetPlayerMapPosition) ~= "function" then
        return "unavailable"
    end

    local ok, position = pcall(C_Map.GetPlayerMapPosition, unitMapID, "player")
    if not ok then return "error" end
    if IsFovDiagnosticSecret(position) then return "secret" end
    if position == nil then return "nil" end
    if type(position.GetXY) ~= "function" then return type(position) .. ":no-GetXY" end

    local xyOK, x, y = pcall(position.GetXY, position)
    if not xyOK then return "GetXY-error" end
    return DescribeFovDiagnosticValue(x) .. "," .. DescribeFovDiagnosticValue(y)
end

local function GetFovDiagnosticUnitPosition()
    if type(UnitPosition) ~= "function" then return "unavailable" end
    local ok, x, y, z, instanceID = pcall(UnitPosition, "player")
    if not ok then return "error" end
    return table.concat({
        DescribeFovDiagnosticValue(x),
        DescribeFovDiagnosticValue(y),
        DescribeFovDiagnosticValue(z),
        DescribeFovDiagnosticValue(instanceID),
    }, ",")
end

local function GetFovDiagnosticRegionStats(frame)
    local stats = {
        containers = 0,
        children = 0,
        regions = 0,
        textures = 0,
        maskableTextures = 0,
    }

    local function Scan(container, depth)
        if not container or depth > 4 then return end
        stats.containers = stats.containers + 1

        if type(container.GetRegions) == "function" then
            local packed = { pcall(container.GetRegions, container) }
            if packed[1] then
                for index = 2, #packed do
                    local region = packed[index]
                    if region then
                        stats.regions = stats.regions + 1
                        if type(region.GetTexture) == "function" then
                            stats.textures = stats.textures + 1
                            if type(region.AddMaskTexture) == "function" then
                                stats.maskableTextures = stats.maskableTextures + 1
                            end
                        end
                    end
                end
            end
        end

        if type(container.GetChildren) == "function" then
            local packed = { pcall(container.GetChildren, container) }
            if packed[1] then
                for index = 2, #packed do
                    local child = packed[index]
                    if child then
                        stats.children = stats.children + 1
                        Scan(child, depth + 1)
                    end
                end
            end
        end
    end

    Scan(frame, 0)

    local anchoring = "unavailable"
    if frame and type(frame.IsAnchoringRestricted) == "function" then
        local ok, restricted = pcall(frame.IsAnchoringRestricted, frame)
        anchoring = ok and DescribeFovDiagnosticValue(restricted) or "error"
    end
    stats.anchoring = anchoring
    if frame and type(frame.GetSize) == "function" then
        local ok, width, height = pcall(frame.GetSize, frame)
        stats.size = ok and (DescribeFovDiagnosticValue(width) .. "x" .. DescribeFovDiagnosticValue(height)) or "error"
    else
        stats.size = "unavailable"
    end
    if frame and type(frame.GetScale) == "function" then
        local ok, scale = pcall(frame.GetScale, frame)
        stats.scale = ok and DescribeFovDiagnosticValue(scale) or "error"
    else
        stats.scale = "unavailable"
    end
    return stats
end

function Pins:PrintFovDiagnostics()
    local mapFrame = BattleMaps.MapFrame
    local configMapID = tonumber(mapFrame and mapFrame.currentMapID)
        or tonumber(self.unitConfigMapID)
    local unitMapID = tonumber(self.unitMapID)
    if not unitMapID and configMapID and BattleMaps.GetBattlegroundUIMapID then
        local ok, resolved = pcall(BattleMaps.GetBattlegroundUIMapID, configMapID, true)
        unitMapID = ok and tonumber(resolved) or nil
    end

    local pinConfig = configMapID and BattleMaps.Database:GetUnitsConfig(configMapID) or nil
    local style = self:GetPlayerFovStyle(pinConfig)
    local configuredScale = tonumber(pinConfig and pinConfig.playerFovScale) or 1
    local mapScale = self:GetPlayerFovMapScale()
    local size = pinConfig and self:GetPlayerFovSize(pinConfig, mapScale) or 0
    BattleMaps.Chat(string.format(
        "FoV diag: live=%s, configMap=%s, unitMap=%s, style=%s, size=%.2f.",
        BattleMaps.IsInLiveBattleground() and "yes" or "no",
        tostring(configMapID or "nil"),
        tostring(unitMapID or "nil"),
        tostring(style),
        tonumber(size) or 0
    ))

    local canvas = mapFrame and mapFrame.canvas
    local canvasWidth, canvasHeight = 0, 0
    if canvas and type(canvas.GetSize) == "function" then
        canvasWidth, canvasHeight = canvas:GetSize()
    end
    BattleMaps.Chat(string.format(
        "FoV sizing: setting=%.2fx, mapScale=%.4f, canvas=%.2fx%.2f.",
        configuredScale,
        tonumber(mapScale) or 0,
        tonumber(canvasWidth) or 0,
        tonumber(canvasHeight) or 0
    ))

    BattleMaps.Chat(string.format(
        "FoV coords: C_Map=%s; UnitPosition=%s.",
        GetFovDiagnosticMapPosition(unitMapID),
        GetFovDiagnosticUnitPosition()
    ))

    local maskStates = {}
    for _, layer in ipairs(PLAYER_FOV_LAYER_ORDER) do
        local appearance = self:GetPlayerFovLayerAppearance(pinConfig, layer)
        if appearance then
            local texture = appearance.maskKind and self:GetPlayerFovMask(appearance.maskKind) or nil
            maskStates[#maskStates + 1] = string.format(
                "%s:%s=%s",
                layer,
                tostring(appearance.maskKind or "none"),
                texture and "asset" or "off/missing"
            )
        end
    end
    BattleMaps.Chat("FoV masks: " .. (#maskStates > 0 and table.concat(maskStates, ", ") or "no active layers") .. ".")

    local liveMaskStates = {}
    for _, layer in ipairs(PLAYER_FOV_LAYER_ORDER) do
        local appearance = self:GetPlayerFovLayerAppearance(pinConfig, layer)
        if appearance then
            local geometry = appearance.maskKind and self:GetPlayerFovLiveMaskGeometry(appearance.maskKind) or nil
            local state = "native"
            if geometry then
                if geometry.full then
                    state = "full/1 canvas clip"
                elseif geometry.empty then
                    state = "empty"
                elseif geometry.rectangles then
                    state = string.format(
                        "%d clips @ %dx%d",
                        #geometry.rectangles,
                        tonumber(geometry.columns) or 0,
                        tonumber(geometry.rows) or 0
                    )
                end
            end
            liveMaskStates[#liveMaskStates + 1] = layer .. "=" .. state
        end
    end
    BattleMaps.Chat("FoV live mask geometry: "
        .. (#liveMaskStates > 0 and table.concat(liveMaskStates, ", ") or "no active layers") .. ".")

    for _, info in ipairs({
        { name = "under", frame = self.playerFovFrame },
        { name = "beam", frame = self.playerFovBeamFrame },
    }) do
        if info.frame then
            local stats = GetFovDiagnosticRegionStats(info.frame)
            BattleMaps.Chat(string.format(
                "FoV native %s: frame=%s@%s, children=%d, regions=%d, textures=%d, maskable=%d, anchoringRestricted=%s.",
                info.name,
                stats.size,
                stats.scale,
                stats.children,
                stats.regions,
                stats.textures,
                stats.maskableTextures,
                stats.anchoring
            ))
        end
    end
end

local FOV_CLIP_DIAGNOSTIC_STRIPE_COUNT = 8

local function UpdateClippedPlayerFovFrameFull(frame)
    frame:ClearUnits()
    local appearance = frame.BattleMapsFovAppearance
    if appearance and frame.BattleMapsFovTexture then
        frame:AddUnit(
            "player",
            frame.BattleMapsFovTexture,
            frame.BattleMapsFovSize or 96,
            (frame.BattleMapsFovSize or 96) * (tonumber(appearance.aspect) or 1),
            1, 1, 1, frame.BattleMapsFovAlpha or 1,
            PLAYER_FOV_SUBLEVEL,
            true
        )
    end
    frame:FinalizeUnits()
    frame.needsFullUpdate = false
end

local function UpdateClippedPlayerFovFramePeriodic(frame)
    frame:SetUnitColor("player", 1, 1, 1, frame.BattleMapsFovAlpha or 1)
end

local function CreateClippedPlayerFovUnitFrame(pins, host)
    local unitFrame = CreateFrame("UnitPositionFrame", nil, host, "UnitPositionFrameTemplate")
    unitFrame.BattleMapsPins = pins
    unitFrame.UpdateFull = UpdateClippedPlayerFovFrameFull
    unitFrame.UpdatePeriodic = UpdateClippedPlayerFovFramePeriodic
    unitFrame:SetPinSubLevel("player", PLAYER_FOV_SUBLEVEL)
    unitFrame:SetUseClassColor("player", false)
    unitFrame:SetShouldShowUnits("player", false)
    unitFrame:SetShouldShowUnits("party", false)
    unitFrame:SetShouldShowUnits("raid", false)
    -- The native widget continuously owns position/facing. Periodic Lua work is
    -- unnecessary; settings and map changes explicitly request a full update.
    unitFrame:SetNeedsPeriodicUpdate(false)
    unitFrame:SetAlpha(1)
    unitFrame:Show()
    return unitFrame
end

function Pins:HideFovClipDiagnostic()
    for _, host in ipairs(self.fovClipDiagnosticHosts or {}) do
        host:Hide()
    end
end

function Pins:AcquireFovClipDiagnosticHost(index)
    self.fovClipDiagnosticHosts = self.fovClipDiagnosticHosts or {}
    local host = self.fovClipDiagnosticHosts[index]
    if host then return host end

    local parent = self.parent
    if not parent or type(parent.SetClipsChildren) ~= "function" then return nil end

    host = CreateFrame("Frame", nil, parent)
    host:SetClipsChildren(true)
    host:EnableMouse(false)

    host.unitFrame = CreateClippedPlayerFovUnitFrame(self, host)

    host:Hide()
    self.fovClipDiagnosticHosts[index] = host
    return host
end

function Pins:RefreshFovClipDiagnostic()
    if self.fovClipDiagnosticEnabled ~= true or not self:ShouldRenderLivePlayerPosition() then
        self:HideFovClipDiagnostic()
        return false
    end

    local mapFrame = BattleMaps.MapFrame
    local canvas = mapFrame and mapFrame.canvas
    local width, height
    if canvas then width, height = canvas:GetSize() end
    if not canvas or not width or width <= 1 or not height or height <= 1 then
        self:HideFovClipDiagnostic()
        return false
    end

    local configMapID = tonumber(mapFrame.currentMapID) or tonumber(self.unitConfigMapID)
    local unitMapID = tonumber(self.unitMapID)
    local pinConfig = configMapID and BattleMaps.Database:GetUnitsConfig(configMapID) or nil
    local appearance = self:GetPlayerFovLayerAppearance(pinConfig, "under")
        or self:GetPlayerFovLayerAppearance(pinConfig, "beam")
    if not unitMapID or not appearance then
        self:HideFovClipDiagnostic()
        return false
    end

    local size = self:GetPlayerFovSize(pinConfig, self:GetPlayerFovMapScale())
    local alpha = self:GetPlayerFovLayerAlpha(pinConfig, "under")
    if not self:GetPlayerFovLayerAppearance(pinConfig, "under") then
        alpha = self:GetPlayerFovAlpha(pinConfig)
    end
    local stripeWidth = width / FOV_CLIP_DIAGNOSTIC_STRIPE_COUNT
    local hostCount = FOV_CLIP_DIAGNOSTIC_STRIPE_COUNT / 2

    for index = 1, hostCount do
        local host = self:AcquireFovClipDiagnosticHost(index)
        if not host then
            self:HideFovClipDiagnostic()
            return false
        end

        local stripeIndex = (index - 1) * 2
        host:ClearAllPoints()
        host:SetPoint("TOPLEFT", canvas, "TOPLEFT", stripeIndex * stripeWidth, 0)
        host:SetSize(stripeWidth, height)
        host:SetFrameLevel(self.parent:GetFrameLevel() + PLAYER_FOV_BEAM_FRAME_LEVEL_OFFSET)

        local unitFrame = host.unitFrame
        unitFrame:ClearAllPoints()
        unitFrame:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
        unitFrame:SetSize(width, height)
        unitFrame:SetFrameLevel(host:GetFrameLevel() + 1)
        unitFrame.BattleMapsFovAppearance = appearance
        unitFrame.BattleMapsFovTexture = appearance.texture
        unitFrame.BattleMapsFovSize = size
        unitFrame.BattleMapsFovAlpha = alpha
        unitFrame:SetUiMapID(unitMapID)
        unitFrame:UpdateAppearanceData()
        unitFrame:SetNeedsFullUpdate()
        unitFrame:UpdatePlayerPins()
        host:Show()
    end

    return true
end

function Pins:SetFovClipDiagnosticEnabled(enabled)
    enabled = enabled == true
    if enabled and BattleMaps.IsInLiveBattleground() ~= true then
        BattleMaps.Chat("FoV clip test requires a live battleground.")
        return false
    end

    self.fovClipDiagnosticEnabled = enabled or nil
    if not enabled then self:HideFovClipDiagnostic() end
    self:RefreshGroup()
    BattleMaps.Chat(enabled
        and "FoV clip test enabled. The cone should appear in alternating vertical stripes; run /bmap fovcliptest off to restore normal rendering."
        or "FoV clip test disabled; normal FoV rendering restored.")
    return true
end

function Pins:HideLiveMaskedPlayerFovLayer(layer, firstUnused)
    local fullHide = not firstUnused or firstUnused <= 1
    if fullHide and not (self.liveMaskedPlayerFovActiveLayers
        and self.liveMaskedPlayerFovActiveLayers[layer]) then
        return
    end

    local hosts = self.liveMaskedPlayerFovHosts and self.liveMaskedPlayerFovHosts[layer]
    if hosts then
        for index = firstUnused or 1, #hosts do
            hosts[index]:Hide()
        end
    end
    if fullHide then
        self.liveMaskedPlayerFovState = self.liveMaskedPlayerFovState or {}
        self.liveMaskedPlayerFovState[layer] = nil
        self.liveMaskedPlayerFovActiveLayers[layer] = nil
    end
end

function Pins:HideLiveMaskedPlayerFov()
    for layer in pairs(self.liveMaskedPlayerFovHosts or {}) do
        self:HideLiveMaskedPlayerFovLayer(layer)
    end
end

function Pins:AcquireLiveMaskedPlayerFovHost(layer, index)
    self.liveMaskedPlayerFovHosts = self.liveMaskedPlayerFovHosts or {}
    self.liveMaskedPlayerFovHosts[layer] = self.liveMaskedPlayerFovHosts[layer] or {}
    local hosts = self.liveMaskedPlayerFovHosts[layer]
    local host = hosts[index]
    if host then return host end

    local parent = self:GetPlayerFovLayerRenderParent(layer)
    if not parent or type(parent.SetClipsChildren) ~= "function" then return nil end

    host = CreateFrame("Frame", nil, parent)
    host.BattleMapsFovLayer = layer
    host:SetClipsChildren(true)
    host:EnableMouse(false)
    host.unitFrame = CreateClippedPlayerFovUnitFrame(self, host)
    host:Hide()
    hosts[index] = host
    return host
end


local function RefreshLiveMaskedPlayerFovHosts(pins, layer, rectangleCount)
    local hosts = pins.liveMaskedPlayerFovHosts and pins.liveMaskedPlayerFovHosts[layer]
    if type(hosts) ~= "table" then return end

    for index = 1, math.min(tonumber(rectangleCount) or 0, #hosts) do
        local host = hosts[index]
        local unitFrame = host and host.unitFrame
        if host and host:IsShown() and unitFrame then
            pcall(unitFrame.SetNeedsFullUpdate, unitFrame)
            pcall(unitFrame.UpdatePlayerPins, unitFrame)
        end
    end
end

local function ScheduleLiveMaskedPlayerFovRefresh(pins, layer, renderKey, rectangleCount)
    if not C_Timer or type(C_Timer.After) ~= "function" then return end

    local function RefreshIfCurrent()
        local state = pins.liveMaskedPlayerFovState
        if not state or state[layer] ~= renderKey then return end

        -- A UnitPositionFrame can be created before Blizzard has finished
        -- publishing the live battleground player pin. The geometry/settings
        -- render key is already valid in that case, so retry the native pin
        -- build shortly after initial creation. Forced battleground refreshes
        -- also use this same helper below, which covers slower zone-entry
        -- initialization without disabling the normal render cache.
        RefreshLiveMaskedPlayerFovHosts(pins, layer, rectangleCount)
    end

    C_Timer.After(0.15, RefreshIfCurrent)
    C_Timer.After(0.75, RefreshIfCurrent)
end

function Pins:RenderLiveMaskedPlayerFovLayer(layer, pinConfig, appearance, size, unitMapID, forceNativeRefresh)
    local geometry = appearance and appearance.maskKind
        and self:GetPlayerFovLiveMaskGeometry(appearance.maskKind) or nil
    if not geometry then
        self:HideLiveMaskedPlayerFovLayer(layer)
        return false
    end
    if geometry.empty then
        self:HideLiveMaskedPlayerFovLayer(layer)
        return true
    end

    -- A fully opaque map mask is still finite: outside the map-sized mask
    -- region is transparent. Keep it on one canvas-sized clip rather than
    -- incorrectly falling back to an unbounded native pass.
    local columns = tonumber(geometry.columns) or 1
    local rows = tonumber(geometry.rows) or 1
    local rectangles = geometry.rectangles
    if geometry.full then
        rectangles = PLAYER_FOV_LIVE_MASK_FULL_RECTANGLES
    end
    if type(rectangles) ~= "table" or #rectangles == 0
        or #rectangles > PLAYER_FOV_LIVE_MASK_MAX_RECTS then
        self:HideLiveMaskedPlayerFovLayer(layer)
        return false
    end

    local mapFrame = BattleMaps.MapFrame
    local canvas = mapFrame and mapFrame.canvas
    local canvasWidth, canvasHeight
    if canvas then canvasWidth, canvasHeight = canvas:GetSize() end
    if not canvas or not canvasWidth or canvasWidth <= 1
        or not canvasHeight or canvasHeight <= 1 then
        self:HideLiveMaskedPlayerFovLayer(layer)
        return false
    end

    local cellWidth = canvasWidth / columns
    local cellHeight = canvasHeight / rows
    local frameLevel = self:GetPlayerFovLayerFrameLevel(layer)
    local alpha = self:GetPlayerFovLayerAlpha(pinConfig, layer)
    local renderKey = table.concat({
        tostring(unitMapID),
        tostring(geometry),
        tostring(appearance.texture),
        tostring(appearance.aspect or 1),
        string.format("%.4f", tonumber(size) or 0),
        string.format("%.4f", tonumber(alpha) or 0),
        string.format("%.4f", canvasWidth),
        string.format("%.4f", canvasHeight),
        tostring(frameLevel),
    }, "\031")
    self.liveMaskedPlayerFovState = self.liveMaskedPlayerFovState or {}
    if self.liveMaskedPlayerFovState[layer] == renderKey then
        -- Zone-entry retries deliberately call RefreshUnits(true). Previously
        -- the masked FoV cache swallowed those forced refreshes because its
        -- geometry had not changed. If Blizzard had not published the live
        -- player pin during the first build, the cone stayed absent until pan
        -- or zoom changed renderKey. Re-push the native pin only on a forced
        -- refresh; ordinary 0.2 s unit polling remains fully cached.
        if forceNativeRefresh == true then
            RefreshLiveMaskedPlayerFovHosts(self, layer, #rectangles)
        end
        return true
    end
    self.liveMaskedPlayerFovActiveLayers = self.liveMaskedPlayerFovActiveLayers or {}
    self.liveMaskedPlayerFovActiveLayers[layer] = true

    for index, rectangle in ipairs(rectangles) do
        local host = self:AcquireLiveMaskedPlayerFovHost(layer, index)
        if not host then
            self:HideLiveMaskedPlayerFovLayer(layer)
            return false
        end

        host:ClearAllPoints()
        host:SetPoint(
            "TOPLEFT",
            canvas,
            "TOPLEFT",
            rectangle.x * cellWidth,
            -(rectangle.y * cellHeight)
        )
        host:SetSize(rectangle.width * cellWidth, rectangle.height * cellHeight)
        host:SetFrameLevel(math.max(0, frameLevel - 1))

        local unitFrame = host.unitFrame
        unitFrame:ClearAllPoints()
        unitFrame:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
        unitFrame:SetSize(canvasWidth, canvasHeight)
        unitFrame:SetFrameLevel(frameLevel)
        unitFrame.BattleMapsFovAppearance = appearance
        unitFrame.BattleMapsFovTexture = appearance.texture
        unitFrame.BattleMapsFovSize = size
        unitFrame.BattleMapsFovAlpha = alpha
        if unitFrame.BattleMapsFovMapID ~= unitMapID then
            unitFrame:SetUiMapID(unitMapID)
            unitFrame:UpdateAppearanceData()
            unitFrame.BattleMapsFovMapID = unitMapID
        end
        unitFrame:SetNeedsFullUpdate()
        host:Show()
        unitFrame:UpdatePlayerPins()
    end

    self:HideLiveMaskedPlayerFovLayer(layer, #rectangles + 1)
    self.liveMaskedPlayerFovState[layer] = renderKey
    ScheduleLiveMaskedPlayerFovRefresh(self, layer, renderKey, #rectangles)
    return true
end

function Pins:RenderLiveMaskedPlayerFov(pinConfig, size, unitMapID, forceNativeRefresh)
    local handledLayers = {}
    if not self:ShouldRenderLivePlayerPosition() or self.fovClipDiagnosticEnabled == true then
        self:HideLiveMaskedPlayerFov()
        return handledLayers
    end

    for _, layer in ipairs(PLAYER_FOV_LAYER_ORDER) do
        local appearance = self:GetPlayerFovLayerAppearance(pinConfig, layer)
        if appearance then
            handledLayers[layer] = self:RenderLiveMaskedPlayerFovLayer(
                layer,
                pinConfig,
                appearance,
                size,
                unitMapID,
                forceNativeRefresh
            )
        else
            self:HideLiveMaskedPlayerFovLayer(layer)
        end
    end
    return handledLayers
end

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
    [CUSTOM_HEALER_CROSS_BORDER_TEXTURE:lower():gsub("\\", "/")] = true,
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

function Pins:GetTeamPinBorderScale(pinConfig)
    return BattleMaps.Clamp(
        tonumber(pinConfig and pinConfig.teamPinBorderScale) or 1.00,
        0.50,
        2.00
    )
end

function Pins:GetHealerPinStyle(pinConfig)
    local style = pinConfig and pinConfig.healerPinStyle
    return ({ circle = true, icon = true, ignore = true })[style] and style or "icon"
end

function Pins:ShouldRenderHealerIcon(isHealer, pinConfig)
    return isHealer == true and self:GetHealerPinStyle(pinConfig) ~= "ignore"
end

function Pins:ShouldRenderHealerCircle(isHealer, pinConfig)
    return isHealer == true and self:GetHealerPinStyle(pinConfig) == "circle"
end

function Pins:ShouldUseHealerIconOverlay(pinConfig)
    local style = self:GetHealerPinStyle(pinConfig)
    if style == "ignore" or not self:ShouldUseLayeredTeamPins() then return false end
    return self:ShouldUseSplitHealerOverlay()
        or (style == "icon" and (
            self:CustomTextureExists(CUSTOM_HEALER_CROSS_BORDER_TEXTURE)
            or self:CustomTextureExists(CUSTOM_HEALER_PIN_TEXTURE)
        ))
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

function Pins:GetHealerIconOnlyBorderTexture()
    if self:CustomTextureExists(CUSTOM_HEALER_CROSS_BORDER_TEXTURE) then
        return CUSTOM_HEALER_CROSS_BORDER_TEXTURE
    end
    return nil
end

function Pins:GetHealerIconOnlyBorderSize(metrics)
    metrics = type(metrics) == "table" and metrics or {}

    -- Both healer textures use a 64 px canvas, but their authored artwork does
    -- not occupy the same fraction of it: healer_cross.tga is roughly 38 px
    -- across while healer_cross_border.tga fills almost the entire canvas.
    -- Giving them equal texture-frame sizes therefore makes the visible black
    -- backing about 1.7x larger than the colored cross. Size the backing from
    -- the authored-content ratio, with a small allowance so it remains visible
    -- as an outline around the glyph.
    local healerSize = BattleMaps.Clamp(tonumber(metrics.healerSize) or 12, 1, 192)
    local authoredCrossRatio = 38 / 64
    local outlineAllowance = 1.14
    return BattleMaps.Clamp(healerSize * authoredCrossRatio * outlineAllowance, 2, 192)
end

-- One texture family is used at every scale. The final rendered pin size drives
-- the relative layer sizes: small competitive pins expose a light border, while
-- larger/zoomed pins progressively expose more of the black backplate.
function Pins:GetTeamPinMetrics(displayedSize, healerSettingSize, baseTeamSize, playerSize, borderScale)
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

    -- Healer Size is a linear relative control. 16 = 100%. Keeping this
    -- deliberately simple makes every slider movement visible and keeps Test
    -- Mode identical to the live UnitPositionFrame renderer. The authored
    -- cross uses transparent padding, so its texture frame is slightly larger
    -- than the ordinary circular pin at the neutral setting.
    local neutralHealerSetting = 16
    local healerControl = BattleMaps.Clamp(
        healerSettingSize / neutralHealerSetting,
        0.25,
        3.00
    )
    local healerTextureScale = BattleMaps.Clamp(1.30 * healerControl, 0.325, 3.90)

    borderScale = BattleMaps.Clamp(tonumber(borderScale) or 1.00, 0.50, 2.00)
    local borderSize = BattleMaps.Clamp(displayedSize * borderScale, 3, 160)
    local fillSize = BattleMaps.Clamp(displayedSize * fillScale, 3, 160)
    local healerSize = BattleMaps.Clamp(displayedSize * healerTextureScale, 1, 192)
    local resolvedPlayerSize = BattleMaps.Clamp(tonumber(playerSize) or 22, 8, 256)

    return {
        borderSize = borderSize,
        fillSize = fillSize,
        healerSize = healerSize,
        collisionSize = math.max(borderSize, fillSize),
        playerAvoidRadius = (resolvedPlayerSize * 0.46) + (math.max(borderSize, fillSize) * 0.50) + 2,
    }
end

function Pins:GetHealerOverlaySize(baseSize, healerSize, baseTeamSize)
    return self:GetTeamPinMetrics(baseSize, healerSize, baseTeamSize).healerSize
end

function Pins:BuildTeamPinAppearance(isHealer, inCombat, displayedSize, healerSettingSize, baseTeamSize, useSolidOutOfCombat, r, g, b, healerR, healerG, healerB, specIcon, specName, pinConfig)
    local healerStyle = self:GetHealerPinStyle(pinConfig)
    local showHealerIcon = isHealer and healerStyle ~= "ignore"
    local showHealerCircle = isHealer and healerStyle == "circle"
    if self:ShouldUseLayeredTeamPins() then
        local metrics = self:GetTeamPinMetrics(
            displayedSize,
            healerSettingSize,
            baseTeamSize,
            nil,
            pinConfig and pinConfig.teamPinBorderScale
        )
        if showHealerIcon and not showHealerCircle and self:ShouldUseHealerIconOverlay(pinConfig) then
            local borderTexture = self:GetHealerIconOnlyBorderTexture()
            local borderSize = borderTexture
                and self:GetHealerIconOnlyBorderSize(metrics)
                or metrics.healerSize
            return {
                kind = "team",
                layered = true,
                borderTexture = borderTexture,
                borderSize = borderSize,
                healerTexture = self:GetHealerOverlayTexture(inCombat),
                healerSize = metrics.healerSize,
                collisionSize = borderTexture and metrics.collisionSize or metrics.healerSize,
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
        return {
            kind = "team",
            layered = true,
            borderTexture = CUSTOM_TEAM_BORDER_TEXTURE,
            borderSize = metrics.borderSize,
            fillTexture = self:GetTeamFillTexture(inCombat, useSolidOutOfCombat, showHealerCircle),
            fillSize = metrics.fillSize,
            healerTexture = showHealerIcon and self:ShouldUseHealerIconOverlay(pinConfig)
                and self:GetHealerOverlayTexture(inCombat) or nil,
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
    if showHealerIcon and self:CustomTextureExists(CUSTOM_HEALER_PIN_TEXTURE) then
        texture = self:GetHealerOverlayTexture(inCombat)
        size = healerSettingSize or displayedSize
    elseif self:CustomTextureExists(CUSTOM_TEAM_PIN_TEXTURE) then
        texture = (not inCombat) and useSolidOutOfCombat and CUSTOM_TEAM_COMBAT_PIN_TEXTURE or CUSTOM_TEAM_PIN_TEXTURE
    else
        texture = RAID_PIN_TEXTURE
    end

    local fillR, fillG, fillB = r or 1, g or 1, b or 1
    if showHealerIcon and healerR and healerG and healerB then
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

    local pinConfig = BattleMaps.Database:GetUnitsConfig(
        self.unitConfigMapID or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    )
    if not self:ShouldUseHealerIconOverlay(pinConfig) then
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
    for index = 1, memberCount do
        local unit = unitBase .. index
        if UnitExists(unit)
            and not UnitIsUnit(unit, "player")
            and (not targetUnit or UnitIsUnit(unit, targetUnit))
            and (not targetSlot or GetUnitStackSlot(unit) == targetSlot)
            and self:ShouldRenderHealerIcon(self:IsFriendlyHealer(unit), pinConfig) then
            local inCombat = trackCombat and self:IsUnitInCombat(unit) or false
            local metrics = self:GetTeamPinMetrics(
                normalSize,
                healerSettingSize,
                normalSize,
                nil,
                pinConfig.teamPinBorderScale
            )
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
    local pinConfig = BattleMaps.Database:GetUnitsConfig(
        self.unitConfigMapID or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    )

    for index = 1, memberCount do
        local unit = unitBase .. index
        if UnitExists(unit)
            and not UnitIsUnit(unit, "player")
            and (not targetUnit or UnitIsUnit(unit, targetUnit))
            and (not targetSlot or GetUnitStackSlot(unit) == targetSlot) then
            local inCombat = trackCombat and self:IsUnitInCombat(unit) or false
            local metrics = self:GetTeamPinMetrics(
                normalSize,
                healerSettingSize,
                normalSize,
                nil,
                pinConfig.teamPinBorderScale
            )
            local isIconOnly = self:IsFriendlyHealer(unit)
                and self:GetHealerPinStyle(pinConfig) == "icon"
                and self:ShouldUseHealerIconOverlay(pinConfig)
            local borderTexture = isIconOnly and self:GetHealerIconOnlyBorderTexture()
                or CUSTOM_TEAM_BORDER_TEXTURE
            if borderTexture then
                local borderSize = isIconOnly
                    and self:GetHealerIconOnlyBorderSize(metrics)
                    or metrics.borderSize
                frame:AddUnit(
                    unit,
                    borderTexture,
                    borderSize,
                    borderSize,
                    1, 1, 1, 1,
                    TEAM_BORDER_SUBLEVEL,
                    false
                )
            end
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
        local metrics = self:GetTeamPinMetrics(
            renderedSize,
            16,
            renderedSize,
            nil,
            pinConfig and pinConfig.teamPinBorderScale
        )
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

function Pins:GetPlayerFovMask(maskKind)
    local db = BattleMaps.Database and BattleMaps.Database:Get()
    if not db then return nil end

    -- Preserve the retained SavedVariables/toggles while exposing semantic
    -- layer names in the renderer. boundary/beam remain compatibility aliases
    -- for older debug calls and builds.
    local semanticKind = ({
        boundary = "core",
        beam = "terrain",
    })[maskKind] or maskKind

    if semanticKind == "core" and db.fovBoundaryMask ~= true then return nil end
    if semanticKind == "terrain" and db.fovBeamMask == false then return nil end

    local mapID = tonumber(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
        or tonumber(self.unitConfigMapID)
    local definitions = PLAYER_FOV_MAP_MASKS[mapID]
    return definitions and definitions[semanticKind] or nil
end

function Pins:GetPlayerFovLiveMaskGeometry(maskKind)
    local semanticKind = ({
        boundary = "core",
        beam = "terrain",
    })[maskKind] or maskKind

    -- The existing setting/asset lookup remains authoritative. A disabled mask
    -- deliberately falls back to the ordinary single native FoV pass.
    if not self:GetPlayerFovMask(semanticKind) then return nil end

    local mapID = tonumber(BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
        or tonumber(self.unitConfigMapID)
    local definitions = PLAYER_FOV_LIVE_MAP_MASK_GEOMETRY[mapID]
    return definitions and definitions[semanticKind] or nil
end

function Pins:HasPlayerFovMask(pinConfig)
    for _, layer in ipairs(PLAYER_FOV_LAYER_ORDER) do
        local appearance = self:GetPlayerFovLayerAppearance(pinConfig, layer)
        if appearance and appearance.maskKind and self:GetPlayerFovMask(appearance.maskKind) then
            return true
        end
    end
    return false
end

function Pins:HideMapBoundFov()
    for _, frame in pairs(self.mapBoundFovFrames or {}) do
        frame:Hide()
    end
    self.mapBoundFovActiveLayers = nil
    self.mapBoundFovState = nil
end

function Pins:AcquireMapBoundFovLayer(layer)
    self.mapBoundFovFrames = self.mapBoundFovFrames or {}
    if self.mapBoundFovFrames[layer] then return self.mapBoundFovFrames[layer] end

    local parent = self:GetPlayerFovLayerRenderParent(layer)
    if not parent or type(parent.CreateTexture) ~= "function" then return nil end

    local frame = CreateFrame("Frame", nil, parent)
    frame.BattleMapsFovLayer = layer
    frame:SetFrameLevel(self:GetPlayerFovLayerFrameLevel(layer))
    frame:EnableMouse(false)

    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    frame.texture = texture

    -- MaskTexture is attached to an unrotated, canvas-sized region. The cone
    -- rotates through its UV coordinates, so the boundary remains fixed to
    -- the map instead of stretching or rotating with the cone.
    if not frame.CreateMaskTexture or not texture.AddMaskTexture then
        frame.maskUnsupported = true
    else
        local mask = frame:CreateMaskTexture()
        if mask then
            mask:SetAllPoints(frame)
            frame.mask = mask
            texture:AddMaskTexture(mask)
        else
            frame.maskUnsupported = true
        end
    end

    frame:Hide()
    self.mapBoundFovFrames[layer] = frame
    return frame
end

local function GetMapBoundFovTexCoord(width, height, originX, originY, drawWidth, drawHeight, rotation)
    local cosine = math.cos(rotation or 0)
    local sine = math.sin(rotation or 0)

    local function Transform(x, y)
        local dx, dy = x - originX, y - originY
        -- Transform map coordinates into the FoV source texture using WoW's
        -- screen-coordinate rotation convention, while the physical region
        -- remains aligned to the map canvas.
        local sourceX = (cosine * dx) - (sine * dy)
        local sourceY = (sine * dx) + (cosine * dy)
        return 0.5 + (sourceX / drawWidth), 0.5 + (sourceY / drawHeight)
    end

    local ulX, ulY = Transform(0, 0)
    local llX, llY = Transform(0, height)
    local urX, urY = Transform(width, 0)
    local lrX, lrY = Transform(width, height)
    return ulX, ulY, llX, llY, urX, urY, lrX, lrY
end

function Pins:RenderMapBoundFov(pinConfig, x, y, size, isTest)
    local mapFrame = BattleMaps.MapFrame
    local canvas = mapFrame and mapFrame.canvas
    if not canvas then
        self:HideMapBoundFov()
        return false
    end

    local canvasWidth, canvasHeight = canvas:GetSize()
    if not canvasWidth or not canvasHeight or canvasWidth <= 1 or canvasHeight <= 1 then
        self:HideMapBoundFov()
        return false
    end

    x = BattleMaps.Clamp(tonumber(x) or 0.5, 0, 1)
    y = BattleMaps.Clamp(tonumber(y) or 0.5, 0, 1)
    size = math.max(1, tonumber(size) or 1)
    local rotation = self:GetPlayerFacingRotation()
    local originX, originY = x * canvasWidth, y * canvasHeight

    local activeLayers = {}
    for _, layer in ipairs(PLAYER_FOV_LAYER_ORDER) do
        local appearance = self:GetPlayerFovLayerAppearance(pinConfig, layer)
        local frame = self.mapBoundFovFrames and self.mapBoundFovFrames[layer]
        local maskTexture = appearance and appearance.maskKind
            and self:GetPlayerFovMask(appearance.maskKind) or nil
        if appearance and maskTexture then
            frame = self:AcquireMapBoundFovLayer(layer)
            if not frame or frame.maskUnsupported or not frame.mask then
                self:HideMapBoundFov()
                return false
            end

            frame:SetFrameLevel(self:GetPlayerFovLayerFrameLevel(layer))
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
            frame:SetSize(canvasWidth, canvasHeight)
            frame.mask:SetTexture(maskTexture)
            frame.texture:SetTexture(appearance.texture)
            frame.texture:SetBlendMode(appearance.blendMode or "BLEND")
            frame.texture:SetVertexColor(1, 1, 1, 1)
            frame.texture:SetAlpha(self:GetPlayerFovLayerAlpha(pinConfig, layer))
            frame.texture:SetTexCoord(GetMapBoundFovTexCoord(
                canvasWidth,
                canvasHeight,
                originX,
                originY,
                size,
                size * (appearance.aspect or 1),
                rotation
            ))
            frame:Show()
            activeLayers[layer] = true
        elseif frame then
            frame:Hide()
        end
    end

    if not next(activeLayers) then
        self:HideMapBoundFov()
        return false
    end

    self.mapBoundFovActiveLayers = activeLayers
    self.mapBoundFovState = {
        pinConfig = pinConfig,
        x = x,
        y = y,
        size = size,
        isTest = isTest == true,
    }
    return true
end

function Pins:UpdateMapBoundFov()
    local state = self.mapBoundFovState
    if not state then return false end
    return self:RenderMapBoundFov(state.pinConfig, state.x, state.y, state.size, state.isTest)
end

function Pins:GetPlayerFovMapScale()
    local mapFrame = BattleMaps.MapFrame
    local canvas = mapFrame and mapFrame.canvas
    local canvasWidth = canvas and canvas:GetWidth()
    if canvasWidth and canvasWidth > 1 then
        return BattleMaps.Clamp(canvasWidth / PLAYER_FOV_REFERENCE_CANVAS_WIDTH, 0.25, 16)
    end

    -- LayoutView normally establishes the canvas before pins refresh. Retain a
    -- full-zoom fallback for the brief startup path where it has not done so.
    local view = mapFrame and mapFrame.GetActiveView and mapFrame:GetActiveView()
    return BattleMaps.Clamp(tonumber(view and view.customZoom) or 1, 1, 3)
end

function Pins:GetPlayerFovSize(pinConfig, mapScale)
    local scale = BattleMaps.Clamp(
        tonumber(pinConfig and pinConfig.playerFovScale) or 1.00,
        0.25,
        5.00
    )
    return BattleMaps.Clamp(PLAYER_FOV_BASE_SIZE * scale * (mapScale or 1), 24, 4096)
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

    local multiplier = BattleMaps.Clamp(tonumber(appearance.alphaMultiplier) or 1, 0, 1)
    if appearance.alphaSetting then
        multiplier = multiplier * BattleMaps.Clamp(
            tonumber(pinConfig and pinConfig[appearance.alphaSetting]) or 1,
            0,
            1
        )
    end
    return BattleMaps.Clamp(self:GetPlayerFovAlpha(pinConfig) * multiplier, 0, 1)
end

local function NormalizeFovTextureKey(value)
    if type(value) ~= "string" then return nil end
    return value:lower():gsub("\\", "/")
end

local function PlayerAnchorTextureMatches(region, appearance)
    if not region or not appearance then return false end
    local expected = NormalizeFovTextureKey(appearance.texture)
    if not expected then return false end

    if type(region.GetTexture) == "function" then
        local ok, value = pcall(region.GetTexture, region)
        if ok and NormalizeFovTextureKey(value) == expected then
            return true
        end
    end
    if type(region.GetAtlas) == "function" then
        local ok, atlas = pcall(region.GetAtlas, region)
        if ok and NormalizeFovTextureKey(atlas) == expected then
            return true
        end
    end
    return false
end

function Pins:ConfigurePlayerFovTextureRegion(region, appearance)
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
            self:ConfigurePlayerFovTextureRegion(region, appearance)
        end
    end
    if type(frame.GetChildren) == "function" then
        for _, child in ipairs({ frame:GetChildren() }) do
            if type(child.GetRegions) == "function" then
                for _, region in ipairs({ child:GetRegions() }) do
                    self:ConfigurePlayerFovTextureRegion(region, appearance)
                end
            end
        end
    end
end

function Pins:GetLivePlayerAnchorRegion()
    local frame = self.playerFrame
    local appearance = self.unitPlayerAppearance
    if not frame or not appearance then return nil end

    local exactMatch
    local fallback
    local function ScanRegion(region)
        if exactMatch or not region or type(region.GetTexture) ~= "function" then return end
        if type(region.IsShown) == "function" then
            local shownOK, shown = pcall(region.IsShown, region)
            if shownOK and not shown then return end
        end
        if PlayerAnchorTextureMatches(region, appearance) then
            exactMatch = region
            return
        end

        -- UnitPositionFrameTemplate has no authored decorative regions; with
        -- only the player unit enabled, the first visible textured native
        -- region is a safe fallback for atlas/file-ID representation differences.
        local ok, value = pcall(region.GetTexture, region)
        if ok and value ~= nil and fallback == nil then
            fallback = region
        end
    end

    local function ScanContainer(container, depth)
        if exactMatch or not container or depth > 3 then return end
        if type(container.GetRegions) == "function" then
            for _, region in ipairs({ container:GetRegions() }) do
                ScanRegion(region)
                if exactMatch then return end
            end
        end
        if type(container.GetChildren) == "function" then
            for _, child in ipairs({ container:GetChildren() }) do
                ScanContainer(child, depth + 1)
                if exactMatch then return end
            end
        end
    end

    ScanContainer(frame, 0)
    return exactMatch or fallback
end

function Pins:AcquireLivePlayerFovLayer(layer)
    self.livePlayerFovFrames = self.livePlayerFovFrames or {}
    if self.livePlayerFovFrames[layer] then return self.livePlayerFovFrames[layer] end

    local parent = self:GetPlayerFovLayerRenderParent(layer)
    if not parent then return nil end

    local frame = CreateFrame("Frame", nil, parent)
    frame.BattleMapsFovLayer = layer
    frame:SetFrameLevel(self:GetPlayerFovLayerFrameLevel(layer))
    frame:SetSize(1, 1)
    frame:EnableMouse(false)

    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints(frame)
    texture:SetTexCoord(0, 1, 0, 1)
    frame.texture = texture

    frame:Hide()
    self.livePlayerFovFrames[layer] = frame
    return frame
end

function Pins:ConfigureLivePlayerFovMask(frame, appearance)
    if not frame or not frame.texture then return end

    local texture = frame.texture
    local mapFrame = BattleMaps.MapFrame
    local canvas = mapFrame and mapFrame.canvas
    local maskTexture = appearance and appearance.maskKind
        and self:GetPlayerFovMask(appearance.maskKind) or nil

    local function DetachMask()
        if frame.BattleMapsMaskAttached and frame.mask and texture.RemoveMaskTexture then
            pcall(texture.RemoveMaskTexture, texture, frame.mask)
        end
        frame.BattleMapsMaskAttached = nil
        frame.BattleMapsMaskTexture = nil
    end

    if not maskTexture or not canvas or not frame.CreateMaskTexture or not texture.AddMaskTexture then
        DetachMask()
        return
    end

    local mask = frame.mask
    if not mask then
        mask = frame:CreateMaskTexture(nil, "ARTWORK")
        if not mask then
            DetachMask()
            return
        end
        frame.mask = mask
    end

    -- The cone frame follows the native player pin, but this mask is anchored
    -- to the whole map canvas. It therefore remains geographically fixed while
    -- the cone moves and rotates underneath it.
    mask:ClearAllPoints()
    mask:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
    mask:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", 0, 0)
    mask:SetTexture(maskTexture)
    frame.BattleMapsMaskTexture = maskTexture

    if not frame.BattleMapsMaskAttached then
        local ok = pcall(texture.AddMaskTexture, texture, mask)
        frame.BattleMapsMaskAttached = ok == true or nil
    end
end

function Pins:HideLivePlayerFov()
    for _, frame in pairs(self.livePlayerFovFrames or {}) do
        frame:Hide()
    end
    self.livePlayerFovAnchor = nil
end

function Pins:RenderLivePlayerFov(pinConfig, size)
    if not self:ShouldRenderLivePlayerPosition() then
        self:HideLivePlayerFov()
        return false
    end

    local anchor = self:GetLivePlayerAnchorRegion()
    if not anchor then
        self:HideLivePlayerFov()
        return false
    end

    size = math.max(1, tonumber(size) or self:GetPlayerFovSize(pinConfig, self:GetPlayerFovMapScale()))
    local rotation = self:GetPlayerFacingRotation()
    local active = false

    for _, layer in ipairs(PLAYER_FOV_LAYER_ORDER) do
        local appearance = self:GetPlayerFovLayerAppearance(pinConfig, layer)
        local frame = self.livePlayerFovFrames and self.livePlayerFovFrames[layer]
        if appearance then
            frame = self:AcquireLivePlayerFovLayer(layer)
            if frame then
                frame:SetFrameLevel(self:GetPlayerFovLayerFrameLevel(layer))
                frame:SetSize(size, size * (tonumber(appearance.aspect) or 1))
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", anchor, "CENTER", 0, 0)

                frame.texture:SetTexture(appearance.texture)
                frame.texture:SetTexCoord(0, 1, 0, 1)
                frame.texture:SetBlendMode(appearance.blendMode or "BLEND")
                frame.texture:SetVertexColor(1, 1, 1, 1)
                frame.texture:SetAlpha(self:GetPlayerFovLayerAlpha(pinConfig, layer))
                if frame.texture.SetRotation then
                    frame.texture:SetRotation(rotation)
                end
                self:ConfigureLivePlayerFovMask(frame, appearance)
                frame:Show()
                active = true
            end
        elseif frame then
            frame:Hide()
        end
    end

    self.livePlayerFovAnchor = active and anchor or nil
    if not active then self:HideLivePlayerFov() end
    return active
end

function Pins:ShouldRenderLivePlayerPosition()
    -- A live battleground is authoritative. Test Mode is a preview-only path
    -- and must never replace the real player position while inside a match.
    return BattleMaps.IsInLiveBattleground() == true
end

function Pins:GetPlayerFacingRotation()
    if type(GetPlayerFacing) ~= "function" then return 0 end
    local ok, facing = pcall(GetPlayerFacing)
    return ok and tonumber(facing) or 0
end

function Pins:UpdateSmoothTestPlayerFacing()
    local mapFrame = BattleMaps.MapFrame
    local updateTestPreview = self.teamStackTestPreviewActive
        and mapFrame and mapFrame.testMode == true
    local liveFovFrames = self.livePlayerFovFrames
    local hasVisibleLiveFov = false

    -- Older BattleMaps-owned player-anchored frames remain for compatibility.
    -- Avoid polling facing when neither those frames nor Test Mode needs a
    -- rotation update.
    for _, fovFrame in pairs(liveFovFrames or {}) do
        if fovFrame:IsShown() and fovFrame.texture and fovFrame.texture.SetRotation then
            hasVisibleLiveFov = true
            break
        end
    end
    if not updateTestPreview and not hasVisibleLiveFov then return end

    local rotation = self:GetPlayerFacingRotation()

    -- Live FoV artwork is BattleMaps-owned and anchored to Blizzard's native
    -- player pin. The anchor supplies the restricted battleground position;
    -- BattleMaps owns rotation so the artwork can retain its authored aspect
    -- ratio and scale without UnitPositionFrame resizing it.
    for _, fovFrame in pairs(liveFovFrames or {}) do
        if fovFrame:IsShown() and fovFrame.texture and fovFrame.texture.SetRotation then
            fovFrame.texture:SetRotation(rotation)
        end
    end

    local mapBoundState = self.mapBoundFovState
    if mapBoundState and mapBoundState.isTest then
        self:UpdateMapBoundFov()
    end

    if not updateTestPreview then
        return
    end

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

    -- Live battleground position/facing must remain on UnitPositionFrame.
    -- Blizzard can render that restricted position even though addon Lua
    -- cannot read it back for anchoring an ordinary frame.
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
        local size = self.unitFovSize or self:GetPlayerFovSize(pinConfig, self:GetPlayerFovMapScale())
        local nativeWidth = size
        local nativeHeight = size * (tonumber(appearance.aspect) or 1)
        frame:AddUnit(
            "player",
            appearance.texture,
            nativeWidth,
            nativeHeight,
            1, 1, 1, self:GetPlayerFovLayerAlpha(pinConfig, layer),
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

    if (pinConfig.healerIconColorMode or "class") == "class" then
        classFile = classFile or (unit and select(2, UnitClass(unit)))
        if classFile then
            local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
            if classColor then
                return classColor.r, classColor.g, classColor.b
            end
            local r, g, b = GetClassColor(classFile)
            if r and g and b then return r, g, b end
        end
        return 1, 1, 1
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

local function GetTeamStackGeometry(teamSize, overlap)
    teamSize = BattleMaps.Clamp(tonumber(teamSize) or 12, 3, 64)
    overlap = BattleMaps.Clamp(tonumber(overlap) or 25, 0, 80)

    -- Treat every teammate as the same footprint. unitTeamSize already includes
    -- the current BattleMaps zoom scale, so live restricted spread follows the
    -- visible pin size without a second map-size heuristic.
    local desiredSeparation = BattleMaps.Clamp(
        teamSize * (1 - (overlap / 100)),
        1,
        teamSize
    )

    -- Live battleground positions are intentionally not read: keep the displacement below one
    -- visible teammate diameter so isolated players remain geographically honest,
    -- while allowing enough room for a coincident group to become distinguishable.
    local maxOffset = BattleMaps.Clamp(
        desiredSeparation * 1.15,
        math.max(2.5, teamSize * 0.20),
        math.max(3, teamSize * 0.95)
    )

    return desiredSeparation, maxOffset
end

local function ClampTeamStackOffset(offsetX, offsetY, maxOffset)
    maxOffset = math.max(0, tonumber(maxOffset) or 0)
    local distance = math.sqrt((offsetX * offsetX) + (offsetY * offsetY))
    if maxOffset > 0 and distance > maxOffset and distance > 0 then
        local scale = maxOffset / distance
        offsetX = offsetX * scale
        offsetY = offsetY * scale
    end
    return offsetX, offsetY
end

local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))

local function GetTeamStackRadialOffset(index, count, desiredSeparation, maxOffset, reservePlayerSlot)
    index = math.max(1, tonumber(index) or 1)
    count = math.max(index, tonumber(count) or index)
    desiredSeparation = math.max(1, tonumber(desiredSeparation) or 1)
    maxOffset = math.max(1, tonumber(maxOffset) or desiredSeparation)

    -- If the player is excluded from stacking, leave one teammate on its exact
    -- Blizzard position. Otherwise reserve the centre for the player and spread
    -- every teammate around it.
    local centreAvailable = reservePlayerSlot ~= true
    if centreAvailable and index == 1 then
        return 0, 0
    end

    local radialIndex = index - (centreAvailable and 1 or 0)
    local radialCount = count - (centreAvailable and 1 or 0)
    if radialCount <= 0 then return 0, 0 end

    -- Live PvP does not expose which teammates actually overlap to addon Lua. A
    -- golden-angle (sunflower) distribution is therefore preferable to fixed
    -- rings: arbitrary subsets of roster ordinals are less likely to inherit
    -- neighbouring offsets, while every offset remains deterministic. Vary the
    -- radius continuously between a small inner clearance and the same bounded
    -- maxOffset used by the previous restricted fallback.
    local minRadius = math.min(
        maxOffset * 0.38,
        math.max(2, desiredSeparation * 0.42)
    )
    if radialCount == 1 then
        minRadius = math.min(maxOffset, math.max(minRadius, desiredSeparation * 0.55))
    end

    local t = BattleMaps.Clamp((radialIndex - 0.5) / radialCount, 0, 1)
    local minRadiusSq = minRadius * minRadius
    local maxRadiusSq = maxOffset * maxOffset
    local radius = math.sqrt(minRadiusSq + ((maxRadiusSq - minRadiusSq) * t))
    local startAngle = -math.pi * 0.5
    local angle = startAngle + ((radialIndex - 1) * GOLDEN_ANGLE)

    return math.cos(angle) * radius, math.sin(angle) * radius
end

local function GetTeamStackOffset(index, count, desiredSeparation, maxOffset, reservePlayerSlot)
    return GetTeamStackRadialOffset(
        index,
        count,
        desiredSeparation,
        maxOffset,
        reservePlayerSlot
    )
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

-- Test Mode owns the lightweight synthetic pin appearance/rendering helpers below.

function Pins:AcquireTeamStackPin(index)
    self.teamStackPinPool = self.teamStackPinPool or {}
    local frame = self.teamStackPinPool[index]
    if frame then return frame end

    frame = CreateFrame("Frame", nil, self.parent)
    frame:SetFrameLevel(self.parent:GetFrameLevel() + TEAM_STACK_FRAME_LEVEL_OFFSET)

    -- Keep the black backplate on its own frame so the FoV beam can pass
    -- between it and this frame's coloured fill/healer artwork.
    local borderFrame = CreateFrame("Frame", nil, self.parent)
    borderFrame:SetFrameLevel(self.parent:GetFrameLevel() + TEAM_STACK_BORDER_FRAME_LEVEL_OFFSET)
    borderFrame:Hide()
    frame.borderFrame = borderFrame

    local borderTexture = borderFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
    borderTexture:SetPoint("CENTER", borderFrame, "CENTER", 0, 0)
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
            if frame.borderFrame then frame.borderFrame:Hide() end
            frame.active = false
        end
    end
    self.testPlayerFacingFrame = nil
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

-- Test Mode uses the lightweight overlay renderer below, but all stacking
-- geometry is supplied by the same deterministic live-PvP offset generator
-- used by the UnitPositionFrame path. There is no separate readable-coordinate
-- collision solver.

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
        local borderFrameLevelOffset = TEAM_STACK_BORDER_FRAME_LEVEL_OFFSET
        if isPlayer then
            frameLevelOffset = entry.behindTeamPins
                and PLAYER_BEHIND_TEAM_FRAME_LEVEL_OFFSET
                or PLAYER_FRAME_LEVEL_OFFSET
            if isTeamPlayer then
                borderFrameLevelOffset = PLAYER_TEAM_BORDER_FRAME_LEVEL_OFFSET
            end
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
        local borderFrame = frame.borderFrame
        if borderFrame then
            borderFrame:SetSize(outerSize, outerSize)
            borderFrame:SetFrameLevel(self.parent:GetFrameLevel() + borderFrameLevelOffset)
            borderFrame.BattleMapsBasePointX = pointX
            borderFrame.BattleMapsBasePointY = pointY
            borderFrame:ClearAllPoints()
            borderFrame:SetPoint("CENTER", canvas, "TOPLEFT", pointX, pointY)
        end

        if isPlayer and not isTeamPlayer then
            frame.borderTexture:Hide()
            if borderFrame then borderFrame:Hide() end
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
                frame.borderTexture:SetPoint("CENTER", borderFrame or frame, "CENTER", 0, 0)
                frame.borderTexture:SetSize(borderSize, borderSize)
                ApplyTextureToRegion(frame.borderTexture, entry.borderTexture)
                if frame.borderTexture.SetRotation then frame.borderTexture:SetRotation(playerRotation) end
                frame.borderTexture:SetVertexColor(1, 1, 1, 1)
                frame.borderTexture:SetAlpha(1)
                frame.borderTexture:Show()
                if borderFrame then borderFrame:Show() end
            else
                frame.borderTexture:Hide()
                if borderFrame then borderFrame:Hide() end
            end

            if entry.fillTexture or entry.texture then
                local fillSize = BattleMaps.Clamp(tonumber(entry.fillSize or entry.size) or outerSize, 3, renderedSizeMaximum)
                frame.fillTexture:ClearAllPoints()
                frame.fillTexture:SetPoint("CENTER", frame, "CENTER", 0, 0)
                frame.fillTexture:SetSize(fillSize, fillSize)
                ApplyTextureToRegion(frame.fillTexture, entry.fillTexture or entry.texture)
                if frame.fillTexture.SetRotation then frame.fillTexture:SetRotation(playerRotation) end
                frame.fillTexture:SetVertexColor(entry.r or 1, entry.g or 1, entry.b or 1, 1)
                frame.fillTexture:SetAlpha(1)
                frame.fillTexture:Show()
            else
                frame.fillTexture:Hide()
            end

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
                if frame.borderFrame then frame.borderFrame:Hide() end
                frame:Hide()
            end
        end
    end
end

function Pins:IsTeamStackTestPreviewActive()
    local mapFrame = BattleMaps.MapFrame
    if not mapFrame or mapFrame.testMode ~= true then return false end
    local mapID = tonumber(mapFrame.currentMapID) or tonumber(mapFrame.selectedMapID)
    if not mapID then return false end

    local pinConfig = BattleMaps.Database and BattleMaps.Database.GetUnitsConfig
        and BattleMaps.Database:GetUnitsConfig(mapID)
        or nil
    if not pinConfig then return false end

    -- Test Mode is a visual sandbox for the same deterministic stacking offsets
    -- used by live battleground UnitPositionFrames. There is no alternate
    -- readable-coordinate stacking mode.
    return true
end

function Pins:GetTeamStackTestAppearance(index, isHealer, inCombat, pinConfig, zoomScale, classFile)
    pinConfig = pinConfig or {}
    zoomScale = tonumber(zoomScale) or (self.GetPinZoomScale and self:GetPinZoomScale()) or 1

    local useSolidOutOfCombat = BattleMaps.Database:Get().useSolidTeamPinOutOfCombat ~= false
    local normalSize = BattleMaps.Clamp((tonumber(pinConfig.teamMemberPinSize) or 12) * zoomScale, 3, 64)
    local healerSettingSize = tonumber(pinConfig.healerPinSize) or 16
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
        specIcon, specName,
        pinConfig
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
    local playerSize = BattleMaps.Clamp((tonumber(pinConfig.playerArrowSize) or 22) * zoomScale, 12, 256)
    local playerAppearance = self:GetPlayerPinAppearance(pinConfig, playerSize, teamSize)
    local playerVisualSize = playerAppearance.borderSize or playerAppearance.size
    local fovSize = self:GetPlayerFovSize(pinConfig, self:GetPlayerFovMapScale())
    local overlap = BattleMaps.Clamp(tonumber(pinConfig.teamPinStackOverlap) or 30, 0, 80)
    local stackEnabled = pinConfig.stackTeamPins ~= false

    local layout = TEAM_PIN_TEST_LAYOUTS[tonumber(mapID)] or DEFAULT_TEAM_PIN_TEST_LAYOUT
    local playerX, playerY = layout.player[1], layout.player[2]
    local primaryX, primaryY = layout.primary[1], layout.primary[2]

    -- Two pins deliberately exercise the player relationship. With
    -- "Exclude player pin" enabled, the first teammate is allowed the zero
    -- offset slot and can sit directly on the player. With it disabled, the
    -- centre slot is reserved and every teammate receives the live-PvP spread.
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
    end

    -- Stacking uses one canonical teammate footprint. Healer artwork and
    -- combat-state textures do not change the live/test spread geometry.

    local excludePlayerArrow = pinConfig.excludePlayerArrowFromStack == true
    if stackEnabled then
        -- Use the exact same geometry generator as the live battleground
        -- UnitPositionFrame path so Test Mode reflects production behaviour.
        local desiredSeparation, maxOffset = GetTeamStackGeometry(teamSize, overlap)
        local reservePlayerSlot = not excludePlayerArrow
        for index, entry in ipairs(entries) do
            local offsetX, offsetY = GetTeamStackOffset(
                index,
                #entries,
                desiredSeparation,
                maxOffset,
                reservePlayerSlot
            )
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
        x = playerX,
        y = playerY,
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
    return self.parent
end

function Pins:GetPlayerFovLayerFrameLevel(layer)
    local renderParent = self:GetPlayerFovLayerRenderParent(layer)
    if renderParent and renderParent ~= self.parent then
        return renderParent:GetFrameLevel() + 1
    end
    return self.parent:GetFrameLevel() + PLAYER_FOV_BEAM_FRAME_LEVEL_OFFSET
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
    local useMapBoundFov = self:RenderMapBoundFov(pinConfig, x, y, size, true)

    local mapFrame = BattleMaps.MapFrame
    local canvas = mapFrame and mapFrame.canvas
    if not canvas then
        self:HideTestFov()
        return
    end

    for _, layer in ipairs(PLAYER_FOV_LAYER_ORDER) do
        local appearance = self:GetPlayerFovLayerAppearance(pinConfig, layer)
        local existingFrame = self.testFovFrames and self.testFovFrames[layer]
        if useMapBoundFov and self.mapBoundFovActiveLayers and self.mapBoundFovActiveLayers[layer] then
            if existingFrame then existingFrame:Hide() end
        elseif appearance then
            local frame = self:AcquireTestFovLayer(layer)
            frame:SetSize(size, size * (appearance.aspect or 1))
            frame:SetFrameLevel(self:GetPlayerFovLayerFrameLevel(layer))
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", canvas, "TOPLEFT", x * canvasWidth, -(y * canvasHeight))
            frame.texture:SetTexture(appearance.texture)
            self:ConfigurePlayerFovTextureRegion(frame.texture, appearance)
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
    if self.mapBoundFovState and self.mapBoundFovState.isTest then
        self:HideMapBoundFov()
    end
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
    self.teamStackLiveActive = false
    self.teamStackMaxOffset = nil
end

function Pins:SetLivePlayerUnitFramesEnabled(enabled)
    enabled = enabled == true
    if self.livePlayerUnitFramesEnabled == enabled then return false end
    self.livePlayerUnitFramesEnabled = enabled

    -- Keep every live player-position pass on Blizzard's UnitPositionFrame.
    -- This widget is the supported route for restricted battleground position.
    for _, frame in ipairs({
        self.playerTeamBorderFrame,
        self.playerFovFrame,
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
        self.playerFovBeamFrame,
        self.playerFrame,
    }) do
        if frame then
            frame:SetAlpha(0)
            ConfigureTeamTooltipHitTesting(frame, false)
        end
    end

    self:HideTeamStackUnitFrames()
    self:HideLivePlayerFov()
    if self.unitFrame then self:SetNativeGroupPinsVisible(self.unitFrame, true) end
    self:SetLivePlayerUnitFramesEnabled(false)
    for _, frame in ipairs({
        self.playerTeamBorderFrame,
        self.playerFovFrame,
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

local function GetTeamStackSlotOrdinals(pins)
    local ordinals = {}
    local activeCount = 0
    local memberCount, unitBase = GetLiveGroupRosterSource(pins and pins.unitFrame)

    for index = 1, tonumber(memberCount) or 0 do
        local unit = tostring(unitBase or "raid") .. index
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local slot = GetUnitStackSlot(unit)
            -- MAX_TEAM_STACK_UNIT_FRAMES can intentionally fold very large raid
            -- rosters. Count each render slot once because every unit in that
            -- slot necessarily shares the same visual offset.
            if not ordinals[slot] then
                activeCount = activeCount + 1
                ordinals[slot] = activeCount
            end
        end
    end

    return ordinals, activeCount
end

function Pins:LayoutTeamStackUnitFrames(step, reservePlayerSlot, maxOffset)
    local mapFrame = BattleMaps.MapFrame
    local canvas = mapFrame and mapFrame.canvas
    if not canvas or type(self.teamStackUnitFrames) ~= "table" then return false end

    local width, height = canvas:GetSize()
    if not width or width <= 0 or not height or height <= 0 then
        self:HideTeamStackUnitFrames()
        return false
    end

    step = BattleMaps.Clamp(tonumber(step) or 8, 1, 80)
    maxOffset = math.max(0, tonumber(maxOffset) or step)

    local stackOrdinals, stackCount = GetTeamStackSlotOrdinals(self)

    for slot, fillFrame in ipairs(self.teamStackUnitFrames) do
        local offsetX, offsetY = 0, 0
        local ordinal = stackOrdinals and stackOrdinals[slot]
        if ordinal then
            -- Live PvP uses dense roster ordering so the player's raid slot does
            -- not leave a random hole. Blizzard remains authoritative for each
            -- UnitPositionFrame position; BattleMaps only adds this bounded,
            -- deterministic render offset.
            local vx, vy = GetTeamStackOffset(
                ordinal,
                stackCount or ordinal,
                step,
                maxOffset,
                reservePlayerSlot
            )
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

function Pins:ResetTeamHoverFanOut(clearOnly)
    local state = self.teamHoverFanOutState
    if state and type(state.entries) == "table" and not clearOnly then
        for _, entry in ipairs(state.entries) do
            local unit = entry and entry.unit
            if unit then
                if self.teamStackLiveActive then
                    self:SetTeamStackSlotFanOffset(GetUnitStackSlot(unit), 0, 0)
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

function Pins:PrepareTeamStackUnitFrames(
    unitMapID,
    reservePlayerSlot
)
    if not unitMapID or type(self.teamStackUnitFrames) ~= "table" then return false end

    local _, teammateCount = GetTeamStackSlotOrdinals(self)
    if not teammateCount or teammateCount <= 0 then
        self:HideTeamStackUnitFrames()
        return false
    end

    -- This is the sole live stacking path. Each auxiliary UnitPositionFrame owns
    -- one stable roster slot (or several slots in very large raids), leaving
    -- Blizzard authoritative for restricted battleground positions while
    -- BattleMaps applies only a bounded deterministic render offset.
    local teamSize = BattleMaps.Clamp(tonumber(self.unitTeamSize) or 12, 3, 64)
    local mapID = self.unitConfigMapID or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    local pinConfig = BattleMaps.Database:GetUnitsConfig(mapID)
    local overlap = BattleMaps.Clamp(tonumber(pinConfig.teamPinStackOverlap) or 30, 0, 80)
    local stackStep, maxOffset = GetTeamStackGeometry(teamSize, overlap)

    if not self:LayoutTeamStackUnitFrames(
        stackStep,
        reservePlayerSlot,
        maxOffset
    ) then
        return false
    end

    local anyActive = false
    local useLayered = self:ShouldUseLayeredTeamPins()
    local useHealerOverlay = self:ShouldUseHealerIconOverlay(pinConfig)

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

    self.teamStackLiveActive = anyActive
    self.teamStackMaxOffset = maxOffset
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
    local pinConfig = BattleMaps.Database:GetUnitsConfig(
        self.unitConfigMapID or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    )
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
            local healerR, healerG, healerB = self:GetHealerIconColor(unit, timeNow, pinConfig)

            if useLayered then
                if not (isHealer and self:GetHealerPinStyle(pinConfig) == "icon"
                    and self:ShouldUseHealerIconOverlay(pinConfig)) then
                    local metrics = self:GetTeamPinMetrics(
                        normalSize, healerSettingSize, normalSize, nil, pinConfig.teamPinBorderScale)
                    frame:AddUnit(
                        unit,
                        self:GetTeamFillTexture(
                            inCombat, useSolidOutOfCombat,
                            self:ShouldRenderHealerCircle(isHealer, pinConfig)
                        ),
                        metrics.fillSize,
                        metrics.fillSize,
                        r, g, b, 1,
                        GROUP_PIN_SUBLEVEL,
                        false
                    )
                end
            else
                local appearance = self:BuildTeamPinAppearance(
                    isHealer, inCombat, normalSize, healerSettingSize, normalSize,
                    useSolidOutOfCombat, r, g, b,
                    healerR, healerG, healerB,
                    nil, nil, pinConfig
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
    local pinConfig = BattleMaps.Database:GetUnitsConfig(
        self.unitConfigMapID or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
    )
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
                local healerR, healerG, healerB = self:GetHealerIconColor(unit, timeNow, pinConfig)

                if useLayered then
                    if not (isHealer and self:GetHealerPinStyle(pinConfig) == "icon"
                        and self:ShouldUseHealerIconOverlay(pinConfig)) then
                        local metrics = self:GetTeamPinMetrics(
                            normalSize, healerSettingSize, normalSize, nil, pinConfig.teamPinBorderScale)
                        unitFrame:AddUnit(
                            unit,
                            self:GetTeamFillTexture(
                                inCombat, useSolidOutOfCombat,
                                self:ShouldRenderHealerCircle(isHealer, pinConfig)
                            ),
                            metrics.fillSize,
                            metrics.fillSize,
                            r, g, b, 1,
                            GROUP_PIN_SUBLEVEL,
                            false
                        )
                    end
                else
                    local appearance = self:BuildTeamPinAppearance(
                        isHealer, inCombat, normalSize, healerSettingSize, normalSize,
                        useSolidOutOfCombat, r, g, b,
                        healerR, healerG, healerB,
                        nil, nil, pinConfig
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

            if info.fovLayer then
                -- UnitPositionFrame owns the restricted live player position.
                -- Scaling its coordinate space makes that position and the
                -- canvas-anchored MaskTexture disagree, which distorts the
                -- cone and prevents a geographic clip. Keep both in native
                -- canvas coordinates.
                frame.BattleMapsFovNativeScale = nil
                frame:SetScale(1)
                frame:SetSize(width, height)
            end
        end
    end

    if self.unitFrameWidth ~= width or self.unitFrameHeight ~= height then
        self.unitFrameWidth = width
        self.unitFrameHeight = height
        for _, info in ipairs(frames) do
            if info.frame and not info.fovLayer then info.frame:SetSize(width, height) end
        end
    end

    for _, pingFrame in ipairs(self.unitPingFrames) do
        self:LayoutPingUnitFrame(pingFrame)
    end
end

function Pins:RefreshUnits(forceFullUpdate)
    if self:ShouldShowDummyPins() then
        self:HideFovClipDiagnostic()
        self:HideLiveMaskedPlayerFov()
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
        self:HideLivePlayerFov()
        self:HideMapBoundFov()
        self:HideFovClipDiagnostic()
        self:HideLiveMaskedPlayerFov()
        if unitFrame then self:SetNativeGroupPinsVisible(unitFrame, true) end
        for _, frame in ipairs({
            self.teamBorderFrame,
            self.unitFrame,
            self.healerOverlayFrame,
            self.teamSpecIconFrame,
            self.playerTeamBorderFrame,
            self.playerFovFrame,
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
        self.playerFovBeamFrame,
        self.playerFrame,
    }) do
        if frame and not frame:IsShown() then
            frame:Show()
            forceFullUpdate = true
        end
    end

    self:LayoutUnitFrame()

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
    local playerTeamBorderFrameLevelOffset = PLAYER_TEAM_BORDER_FRAME_LEVEL_OFFSET
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
    local fovSize = self:GetPlayerFovSize(pinConfig, self:GetPlayerFovMapScale())
    local teamBorderScale = self:GetTeamPinBorderScale(pinConfig)
    local healerPinStyle = self:GetHealerPinStyle(pinConfig)
    local healerSettingSize = tonumber(pinConfig.healerPinSize) or 16
    local metrics = self:GetTeamPinMetrics(
        teamSize,
        healerSettingSize,
        teamSize,
        playerAppearance.borderSize or playerAppearance.size,
        teamBorderScale
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
        -- UnitPositionFrame owns live battleground positioning. Keep its
        -- native pin dimensions synchronized with the FoV scale setting.
        for _, frame in ipairs({ self.playerFovFrame, self.playerFovBeamFrame }) do
            if frame then frame:SetPinSize("player", fovSize) end
        end
        forceFullUpdate = true
    end
    -- Exact unit coordinates are unavailable in battleground instances, so
    -- the map-bound masked renderer is reserved for Test Mode.
    self:HideMapBoundFov()
    if self.unitTeamSize ~= teamSize or self.unitTeamBorderScale ~= teamBorderScale then
        self.unitTeamSize = teamSize
        self.unitTeamBorderScale = teamBorderScale
        self.teamSpecIconFrameAnchored = false
        if self.teamBorderFrame then
            self.teamBorderFrame:SetPinSize("party", metrics.borderSize)
            self.teamBorderFrame:SetPinSize("raid", metrics.borderSize)
        end
        unitFrame:SetPinSize("party", metrics.fillSize)
        unitFrame:SetPinSize("raid", metrics.fillSize)
        forceFullUpdate = true
    end
    if self.unitHealerSize ~= healerSettingSize or self.unitHealerPinStyle ~= healerPinStyle then
        self.unitHealerSize = healerSettingSize
        self.unitHealerPinStyle = healerPinStyle
        forceFullUpdate = true
    end
    self:LayoutUnitFrame()

    local useTeamStackUnitFrames = false
    if pinConfig.stackTeamPins ~= false then
        useTeamStackUnitFrames = self:PrepareTeamStackUnitFrames(
            unitMapID,
            pinConfig.excludePlayerArrowFromStack ~= true
        )
    end

    local showNativeTeam = not useTeamStackUnitFrames
    ConfigureTeamTooltipHitTesting(unitFrame, showNativeTeam)
    ConfigureTeamTooltipHitTesting(self.teamBorderFrame, false)
    ConfigureTeamTooltipHitTesting(self.healerOverlayFrame, false)
    ConfigureTeamTooltipHitTesting(self.teamSpecIconFrame, false)
    ConfigureTeamTooltipHitTesting(self.playerTeamBorderFrame, false)
    ConfigureTeamTooltipHitTesting(self.playerFovFrame, false)
    ConfigureTeamTooltipHitTesting(self.playerFovBeamFrame, false)
    ConfigureTeamTooltipHitTesting(self.playerFrame, false)
    if self:SetNativeGroupPinsVisible(unitFrame, showNativeTeam) then forceFullUpdate = true end
    if not useTeamStackUnitFrames then
        self:HideTeamStackUnitFrames()
    end

    if forceFullUpdate then
        for _, frame in ipairs({
            self.teamBorderFrame,
            self.unitFrame,
            self.healerOverlayFrame,
            self.teamSpecIconFrame,
            self.playerTeamBorderFrame,
            self.playerFovFrame,
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

    -- Enabled masks use clipped duplicates of the same native widget. A full
    -- mask needs one canvas clip; partial masks use their compiled rectangles.
    -- Disabled masks stay on the single established UnitPositionFrame pass.
    local liveMaskedFovLayers = self:RenderLiveMaskedPlayerFov(
        pinConfig,
        fovSize,
        unitMapID,
        forceFullUpdate == true
    )

    -- Live FoV passes remain on UnitPositionFrame so Blizzard can supply the
    -- restricted player position and facing inside battleground instances.
    for _, info in ipairs({
        { layer = "under", frame = self.playerFovFrame },
        { layer = "beam", frame = self.playerFovBeamFrame },
    }) do
        local frame = info.frame
        if frame then
            local appearance = self:GetPlayerFovLayerAppearance(pinConfig, info.layer)
            local showFov = renderLivePlayerPosition and appearance ~= nil
                and self.fovClipDiagnosticEnabled ~= true
                and liveMaskedFovLayers[info.layer] ~= true
            frame:SetAlpha(showFov and 1 or 0)
            frame:UpdatePlayerPins()
            if showFov then
                self:ConfigurePlayerFovFrameTextures(frame, appearance)
            end
        end
    end
    if self.fovClipDiagnosticEnabled == true then
        self:RefreshFovClipDiagnostic()
    else
        self:HideFovClipDiagnostic()
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
    -- Any overlay-anchor frames created by 2.7.2-2.7.4 are retired. They
    -- cannot follow a restricted UnitPositionFrame pin in live battlegrounds.
    self:HideLivePlayerFov()

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
            local useHealer = self:ShouldUseHealerIconOverlay(pinConfig)
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

    -- The overlay renderer is Test-Mode-only. Live battleground stacking always
    -- uses the UnitPositionFrame path above.
    self:HideTeamStackOverlay()
    if useTeamStackUnitFrames then self:UpdateTeamStackUnitFrames() end

    for _, pingFrame in ipairs(self.unitPingFrames) do
        if pingFrame:IsShown() then pingFrame:UpdatePlayerPins() end
    end

end

function Pins:PrintHealerDebug()
    local mapID = BattleMaps.ResolveCurrentBattlegroundMapID()
        or (BattleMaps.MapFrame and BattleMaps.MapFrame.currentMapID)
        or (BattleMaps.Options and BattleMaps.Options.selectedMapID)
    local pinConfig = BattleMaps.Database and BattleMaps.Database:GetUnitsConfig(mapID)
    if not pinConfig then
        BattleMaps.Chat("Healer diagnostics unavailable: unit settings not found.")
        return
    end

    local zoomScale = self:GetPinZoomScale()
    local teamSize = BattleMaps.Clamp((tonumber(pinConfig.teamMemberPinSize) or 12) * zoomScale, 3, 64)
    local healerSettingSize = tonumber(pinConfig.healerPinSize) or 16
    local metrics = self:GetTeamPinMetrics(
        teamSize,
        healerSettingSize,
        teamSize,
        nil,
        pinConfig.teamPinBorderScale
    )
    BattleMaps.Chat(string.format(
        "Healer pins: style=%s, setting=%.1f (%.0f%%), team=%.1fpx, glyph=%.1fpx, icon-backing=%.1fpx, stacking=%s.",
        self:GetHealerPinStyle(pinConfig),
        healerSettingSize,
        (healerSettingSize / 16) * 100,
        teamSize,
        metrics.healerSize or 0,
        self:GetHealerIconOnlyBorderSize(metrics),
        self.teamStackLiveActive and "live" or "native"
    ))
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
