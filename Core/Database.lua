local _, BattleMaps = ...

local Database = {}
BattleMaps.Database = Database

local PIN_DEFAULTS = {
    playerArrowSize = 42,
    teamMemberPinSize = 9,
    healerPinSize = 20.5,
    combatTeamPinScale = 1.00, -- retired setting retained at 1 for SavedVariables compatibility
    objectivePinScale = 1.40,
    objectivePinAlpha = 0.90,
    carrierObjectivePinScale = 1.10,
    vehicleObjectivePinScale = 0.80,
}

local PLAYER_PIN_DEFAULTS = {
    playerArrowSize = PIN_DEFAULTS.playerArrowSize,
    playerPinStyle = "arrow",
    playerFovStyle = "coldRays",
    playerFovScale = 1.75,
    playerFovAlpha = 1.00,
    playerFovBeamAlpha = 0.25,
    teamMemberPinSize = PIN_DEFAULTS.teamMemberPinSize,
    healerPinSize = PIN_DEFAULTS.healerPinSize,
    teamPinBorderScale = 1.00,
    healerPinStyle = "icon",
    combatTeamPinScale = PIN_DEFAULTS.combatTeamPinScale,
    stackTeamPins = true,
    fanOutTeamPinsOnHover = false,
    excludePlayerArrowFromStack = true,
    teamPinStackRadius = 11, -- retained for SavedVariables compatibility; no longer user-configurable
    teamPinStackOverlap = 0,
    teamPinStackDirection = "compact",
    showTeamSpecIcons = false,
    healerIconColorMode = "class",
    healerIconCustomColor = {
        r = 0.4431372880935669,
        g = 1.00,
        b = 0.3607843220233917,
    },
}

local OBJECTIVE_PIN_DEFAULTS = {
    objectivePinScale = PIN_DEFAULTS.objectivePinScale,
    objectivePinAlpha = PIN_DEFAULTS.objectivePinAlpha,
    carrierObjectivePinScale = PIN_DEFAULTS.carrierObjectivePinScale,
    vehicleObjectivePinScale = PIN_DEFAULTS.vehicleObjectivePinScale,
    showFlagCarrierTrail = true,
    carriedTrailStyle = "glow",
    carriedTrailDuration = 30.00,
    carriedTrailDotScale = 1.40,
    carriedTrailDetail = 24,
    carriedObjectiveColorMode = "original",
    flashCarriedObjectives = true,
    carriedObjectiveFlashPeriod = 1.00,
    carriedObjectiveFlashStrength = 0.75,
}

local TIMER_DEFAULTS = {
    showObjectivePulseAnimations = true,
    showObjectiveCaptureTimers = true,
    pulseObjectiveDuringCaptureTimer = true,
    flashObjectiveBeforeCapture = true,
    objectiveCaptureFlashThreshold = 5,
    objectiveCaptureFlashBrightness = 0.15,
    objectiveCapturePulseMinAlpha = 0.60,
    objectiveCapturePulseMaxAlpha = 0.80,
    objectiveCaptureAfterPulseAlpha = 0.36,
    showObjectiveTimerText = true,
    showObjectiveBlitzUncapText = true,
    objectiveTimerTextThreshold = 59,
    objectiveTimerTextSize = 12,
    objectiveTimerTextAlpha = 1.00,
    objectiveTimerTextOffsetX = 0,
    objectiveTimerTextOffsetY = 0,
    objectiveTimerTextFont = "Expressway",
    objectiveTimerTextColorMode = "custom",
    objectiveTimerTextColor = {
        r = 1.00,
        g = 1.00,
        b = 0.2901960909366608,
    },
    objectiveCaptureFillDirection = "horizontal",
    objectiveCapturePulseCount = 3,
}
local NOTIFICATION_DEFAULTS = {
    enabled = true,
    useBlizzardOnWorldMap = true,
    colorByFaction = true,
    scale = 1.00,
    width = 360,
    justifyH = "RIGHT",
    anchorMode = "MAP",
    mapAnchorSide = "LEFT",
    notificationAnchorPoint = "AUTO",
    point = "RIGHT",
    relativePoint = "RIGHT",
    x = -1.185360550880432,
    y = -300,
    mapX = -22,
    mapY = 68,
    attachmentVersion = 2,
}

local ROOT_DEFAULTS = {
    enabled = true,
    autoShow = true,
    autoHide = true,
    enableWorldMapIntegration = true,
    worldMapPinScale = 1.30,
    applyZoom = true,
    applyFrameSize = true,
    showLoginMessage = true,
    debug = false,
    factionSwapAlert = true,
    factionColoredBorder = true, -- legacy alias; kept for older saved variables
    frameBorderSize = 2,
    frameBorderStrength = 1.00,
    frameBorderStyle = "solid",
    frameBackgroundColor = { r = 0, g = 0, b = 0, a = 1.00 },
    fadeMapHeader = true,
    mapTextureAlpha = 0.80,
    fovBoundaryPreview = false,
    fovBoundaryMask = true,
    fovBeamMask = true,
    fovMaskSettingsVersion = 3,
    highlightFriendlyHealers = true,
    useCustomHealerIcon = true,
    useCustomTeamPinTextures = true,
    useSolidTeamPinOutOfCombat = true,
    showFlagCarrierTrail = true,
    carriedTrailStyle = OBJECTIVE_PIN_DEFAULTS.carriedTrailStyle,
    carriedTrailDuration = OBJECTIVE_PIN_DEFAULTS.carriedTrailDuration,
    carriedTrailDotScale = OBJECTIVE_PIN_DEFAULTS.carriedTrailDotScale,
    carriedTrailDetail = OBJECTIVE_PIN_DEFAULTS.carriedTrailDetail,
    carriedObjectiveColorMode = OBJECTIVE_PIN_DEFAULTS.carriedObjectiveColorMode,
    flashCarriedObjectives = true,
    carriedObjectiveFlashPeriod = OBJECTIVE_PIN_DEFAULTS.carriedObjectiveFlashPeriod,
    carriedObjectiveFlashStrength = OBJECTIVE_PIN_DEFAULTS.carriedObjectiveFlashStrength,
    showObjectivePulseAnimations = true,
    showObjectiveCaptureTimers = true,
    pulseObjectiveDuringCaptureTimer = true,
    flashObjectiveBeforeCapture = true,
    objectiveCaptureFlashThreshold = TIMER_DEFAULTS.objectiveCaptureFlashThreshold,
    objectiveCaptureFlashBrightness = TIMER_DEFAULTS.objectiveCaptureFlashBrightness,
    objectiveCapturePulseMinAlpha = TIMER_DEFAULTS.objectiveCapturePulseMinAlpha,
    objectiveCapturePulseMaxAlpha = TIMER_DEFAULTS.objectiveCapturePulseMaxAlpha,
    objectiveCaptureAfterPulseAlpha = TIMER_DEFAULTS.objectiveCaptureAfterPulseAlpha,
    showObjectiveTimerText = true,
    showObjectiveBlitzUncapText = true,
    objectiveTimerTextThreshold = TIMER_DEFAULTS.objectiveTimerTextThreshold,
    objectiveTimerTextSize = TIMER_DEFAULTS.objectiveTimerTextSize,
    objectiveTimerTextAlpha = TIMER_DEFAULTS.objectiveTimerTextAlpha,
    objectiveTimerTextOffsetX = TIMER_DEFAULTS.objectiveTimerTextOffsetX,
    objectiveTimerTextOffsetY = TIMER_DEFAULTS.objectiveTimerTextOffsetY,
    objectiveTimerTextFont = TIMER_DEFAULTS.objectiveTimerTextFont,
    objectiveTimerTextColorMode = TIMER_DEFAULTS.objectiveTimerTextColorMode,
    objectiveTimerTextColor = {
        r = TIMER_DEFAULTS.objectiveTimerTextColor.r,
        g = TIMER_DEFAULTS.objectiveTimerTextColor.g,
        b = TIMER_DEFAULTS.objectiveTimerTextColor.b,
    },
    objectiveCaptureFillDirection = TIMER_DEFAULTS.objectiveCaptureFillDirection,
    objectiveAssaultPulseCount = 1,
    objectiveCapturePulseCount = TIMER_DEFAULTS.objectiveCapturePulseCount,
    objectivePulsePeriod = 0.80,
    objectivePulseStrength = 1.00,
    showPingPulses = false, -- retired: received ping data is secret during PvP chat lockdown
    hideMinimapInNonEpicBattlegrounds = true,
    -- Canonical provider-agnostic player aura relocation setting. The older
    -- movePlayerAurasToMinimapArea key is kept synchronized as a downgrade
    -- compatibility alias only.
    bgLayoutMovePlayerAuras = true,
    movePlayerAurasToMinimapArea = true,
    hideObjectiveTrackerInBattlegrounds = true,
    playerArrowColorMode = "class",
    playerArrowCustomColor = {
        r = 0.7921569347381592,
        g = 0.8627451658248901,
        b = 0.7803922295570374,
    },
    useGlobalPinSettings = false, -- legacy alias; kept for older saved variables
    useGlobalPlayerPinSettings = false,
    useGlobalObjectiveSettings = false, -- legacy/default seed; map configs own the live base/cart/flag switch
    useGlobalTimerSettings = false,
    useGlobalNotificationSettings = true,
    playerArrowSize = PIN_DEFAULTS.playerArrowSize,
    playerPinStyle = PLAYER_PIN_DEFAULTS.playerPinStyle,
    playerFovStyle = PLAYER_PIN_DEFAULTS.playerFovStyle,
    playerFovScale = PLAYER_PIN_DEFAULTS.playerFovScale,
    playerFovAlpha = PLAYER_PIN_DEFAULTS.playerFovAlpha,
    playerFovBeamAlpha = PLAYER_PIN_DEFAULTS.playerFovBeamAlpha,
    teamMemberPinSize = PIN_DEFAULTS.teamMemberPinSize,
    healerPinSize = PIN_DEFAULTS.healerPinSize,
    teamPinBorderScale = PLAYER_PIN_DEFAULTS.teamPinBorderScale,
    healerPinStyle = PLAYER_PIN_DEFAULTS.healerPinStyle,
    combatTeamPinScale = PIN_DEFAULTS.combatTeamPinScale,
    stackTeamPins = true,
    fanOutTeamPinsOnHover = false,
    excludePlayerArrowFromStack = true,
    teamPinStackRadius = PLAYER_PIN_DEFAULTS.teamPinStackRadius,
    teamPinStackOverlap = PLAYER_PIN_DEFAULTS.teamPinStackOverlap,
    teamPinStackDirection = "compact",
    showTeamSpecIcons = false,
    healerIconColorMode = PLAYER_PIN_DEFAULTS.healerIconColorMode,
    healerIconCustomColor = {
        r = 0.4431372880935669,
        g = 1.00,
        b = 0.3607843220233917,
    },
    objectivePinScale = PIN_DEFAULTS.objectivePinScale,
    objectivePinAlpha = PIN_DEFAULTS.objectivePinAlpha,
    carrierObjectivePinScale = PIN_DEFAULTS.carrierObjectivePinScale,
    vehicleObjectivePinScale = PIN_DEFAULTS.vehicleObjectivePinScale,
    notifications = {
        enabled = true,
        useBlizzardOnWorldMap = true,
        colorByFaction = true,
        scale = 1.00,
        width = 360,
        justifyH = "RIGHT",
        anchorMode = "MAP",
        mapAnchorSide = "LEFT",
        notificationAnchorPoint = "AUTO",
        point = "RIGHT",
        relativePoint = "RIGHT",
        x = -1.185360550880432,
        y = -300,
        mapX = -22,
        mapY = 68,
        attachmentVersion = 2,
    },
    customFrameVersion = 2,
    maps = {},
    optionsWindow = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    },
}

local PERSONAL_MAP_DEFAULTS = {
    [112] = {
        width = 411.629638671875,
        height = 306.0003967285156,
        configured = true,
        customZoom = 1.972548697295965,
        customPanX = 0.4836261377580955,
        customPanY = 0.439103818491639,
        useGlobalPlayerPinSettings = false,
        useGlobalObjectiveSettings = false,
        playerPins = {
            playerArrowSize = 45,
            playerPinStyle = "arrow",
            playerFovStyle = "sunbeam",
            playerFovScale = 2.2,
            playerFovAlpha = 1,
            playerFovBeamAlpha = 0.25,
            teamMemberPinSize = 9,
            healerPinSize = 19,
            teamPinBorderScale = 1,
            healerPinStyle = "icon",
            combatTeamPinScale = 1,
            stackTeamPins = true,
            fanOutTeamPinsOnHover = true,
            excludePlayerArrowFromStack = true,
            teamPinStackRadius = 10,
            teamPinStackOverlap = 20,
            teamPinStackDirection = "compact",
            showTeamSpecIcons = false,
            healerIconColorMode = "class",
            healerIconCustomColor = {
                b = 0.2745098173618317,
                g = 1,
                r = 0.2549019753932953,
            },
        },
        objectives = {
            objectivePinScale = 2.1,
            objectivePinAlpha = 0.95,
            carrierObjectivePinScale = 1,
            vehicleObjectivePinScale = 1,
            showFlagCarrierTrail = true,
            carriedTrailStyle = "breadcrumbs",
            carriedTrailDuration = 12,
            carriedTrailDotScale = 0.7,
            carriedTrailDetail = 16,
            carriedObjectiveColorMode = "original",
            flashCarriedObjectives = true,
            carriedObjectiveFlashPeriod = 0.7,
            carriedObjectiveFlashStrength = 0.95,
        },
        timers = {
            showObjectivePulseAnimations = false,
            showObjectiveCaptureTimers = true,
            pulseObjectiveDuringCaptureTimer = true,
            flashObjectiveBeforeCapture = true,
            objectiveCaptureFlashThreshold = 10,
            objectiveCaptureFlashBrightness = 0.2,
            objectiveCapturePulseMinAlpha = 0.7,
            objectiveCapturePulseMaxAlpha = 0.9,
            objectiveCaptureAfterPulseAlpha = 0.36,
            showObjectiveTimerText = false,
            showObjectiveBlitzUncapText = true,
            objectiveTimerTextThreshold = 59,
            objectiveTimerTextSize = 25,
            objectiveTimerTextAlpha = 0.55,
            objectiveTimerTextOffsetX = 0,
            objectiveTimerTextOffsetY = 0,
            objectiveTimerTextFont = "Accidental Presidency",
            objectiveTimerTextColorMode = "custom",
            objectiveTimerTextColor = {
                b = 0.9725490808486938,
                g = 1,
                r = 0.9843137860298157,
            },
            objectiveCaptureFillDirection = "horizontal",
            objectiveCapturePulseCount = 3,
        },
    },
    [206] = {
        width = 261.9263610839844,
        height = 453.3333129882813,
        configured = true,
        customZoom = 3,
        customPanX = 0.5304060824946187,
        customPanY = 0.4884276281097376,
        useGlobalPlayerPinSettings = false,
        useGlobalObjectiveSettings = false,
        playerPins = {
            playerArrowSize = 45,
            playerPinStyle = "arrow",
            playerFovStyle = "coldRays",
            playerFovScale = 1.9,
            playerFovAlpha = 1,
            playerFovBeamAlpha = 0.25,
            teamMemberPinSize = 8,
            healerPinSize = 20,
            teamPinBorderScale = 1,
            healerPinStyle = "icon",
            combatTeamPinScale = 1,
            stackTeamPins = true,
            fanOutTeamPinsOnHover = true,
            excludePlayerArrowFromStack = true,
            teamPinStackRadius = 10,
            teamPinStackOverlap = 25,
            teamPinStackDirection = "compact",
            showTeamSpecIcons = false,
            healerIconColorMode = "class",
            healerIconCustomColor = {
                r = 0.09019608050584793,
                g = 1,
                b = 0,
            },
        },
        objectives = {
            objectivePinScale = 1,
            objectivePinAlpha = 1,
            carrierObjectivePinScale = 1.05,
            vehicleObjectivePinScale = 1,
            showFlagCarrierTrail = true,
            carriedTrailStyle = "glow",
            carriedTrailDuration = 30,
            carriedTrailDotScale = 0.4,
            carriedTrailDetail = 24,
            carriedObjectiveColorMode = "original",
            flashCarriedObjectives = true,
            carriedObjectiveFlashPeriod = 0.7,
            carriedObjectiveFlashStrength = 0.7,
        },
        timers = {
            showObjectivePulseAnimations = true,
            showObjectiveCaptureTimers = true,
            pulseObjectiveDuringCaptureTimer = true,
            flashObjectiveBeforeCapture = false,
            objectiveCaptureFlashThreshold = 9,
            objectiveCaptureFlashBrightness = 0.25,
            objectiveCapturePulseMinAlpha = 0.4,
            objectiveCapturePulseMaxAlpha = 0.6,
            objectiveCaptureAfterPulseAlpha = 0.36,
            showObjectiveTimerText = true,
            showObjectiveBlitzUncapText = true,
            objectiveTimerTextThreshold = 9,
            objectiveTimerTextSize = 14,
            objectiveTimerTextAlpha = 1,
            objectiveTimerTextOffsetX = 0,
            objectiveTimerTextOffsetY = 0,
            objectiveTimerTextFont = "friz",
            objectiveTimerTextColorMode = "custom",
            objectiveTimerTextColor = {
                b = 1,
                g = 1,
                r = 1,
            },
            objectiveCaptureFillDirection = "horizontal",
            objectiveCapturePulseCount = 1,
        },
    },
    [210] = {
        width = 416,
        height = 346,
        configured = true,
        customZoom = 3,
        customPanX = 0.4844634809741701,
        customPanY = 0.496770698648,
        useGlobalPlayerPinSettings = false,
        useGlobalObjectiveSettings = false,
        playerPins = {
            playerArrowSize = 36,
            playerPinStyle = "arrow",
            playerFovStyle = "sunbeam",
            playerFovScale = 1.75,
            playerFovAlpha = 1,
            playerFovBeamAlpha = 0.25,
            teamMemberPinSize = 7,
            healerPinSize = 19.5,
            teamPinBorderScale = 1,
            healerPinStyle = "icon",
            combatTeamPinScale = 1,
            stackTeamPins = true,
            fanOutTeamPinsOnHover = true,
            excludePlayerArrowFromStack = true,
            teamPinStackRadius = 8,
            teamPinStackOverlap = 0,
            teamPinStackDirection = "compact",
            showTeamSpecIcons = false,
            healerIconColorMode = "class",
            healerIconCustomColor = {
                r = 0,
                g = 1,
                b = 0.01176470704376698,
            },
        },
        objectives = {
            objectivePinScale = 1.55,
            objectivePinAlpha = 1,
            carrierObjectivePinScale = 1.15,
            vehicleObjectivePinScale = 1,
            showFlagCarrierTrail = true,
            carriedTrailStyle = "glow",
            carriedTrailDuration = 20,
            carriedTrailDotScale = 2.2,
            carriedTrailDetail = 16,
            carriedObjectiveColorMode = "original",
            flashCarriedObjectives = true,
            carriedObjectiveFlashPeriod = 0.55,
            carriedObjectiveFlashStrength = 0.35,
        },
        timers = {
            showObjectivePulseAnimations = false,
            showObjectiveCaptureTimers = true,
            pulseObjectiveDuringCaptureTimer = true,
            flashObjectiveBeforeCapture = true,
            objectiveCaptureFlashThreshold = 9,
            objectiveCaptureFlashBrightness = 0.25,
            objectiveCapturePulseMinAlpha = 0.45,
            objectiveCapturePulseMaxAlpha = 0.65,
            objectiveCaptureAfterPulseAlpha = 0.36,
            showObjectiveTimerText = true,
            showObjectiveBlitzUncapText = true,
            objectiveTimerTextThreshold = 9,
            objectiveTimerTextSize = 14,
            objectiveTimerTextAlpha = 1,
            objectiveTimerTextOffsetX = 0,
            objectiveTimerTextOffsetY = 0,
            objectiveTimerTextFont = "Expressway",
            objectiveTimerTextColorMode = "custom",
            objectiveTimerTextColor = {
                b = 0,
                g = 0.8196079134941101,
                r = 1,
            },
            objectiveCaptureFillDirection = "vertical",
            objectiveCapturePulseCount = 1,
        },
    },
    [275] = {
        width = 416.9999389648438,
        height = 351.0000305175781,
        configured = true,
        customZoom = 1.972548697295965,
        customPanX = 0.4960182779557474,
        customPanY = 0.5901374970511981,
        useGlobalPlayerPinSettings = false,
        useGlobalObjectiveSettings = false,
        playerPins = {
            playerArrowSize = 51,
            playerPinStyle = "arrow",
            playerFovStyle = "sunbeam",
            playerFovScale = 2.6,
            playerFovAlpha = 1,
            playerFovBeamAlpha = 0.25,
            teamMemberPinSize = 10,
            healerPinSize = 16,
            teamPinBorderScale = 1,
            healerPinStyle = "icon",
            combatTeamPinScale = 1,
            stackTeamPins = true,
            fanOutTeamPinsOnHover = true,
            excludePlayerArrowFromStack = true,
            teamPinStackRadius = 18,
            teamPinStackOverlap = 20,
            teamPinStackDirection = "compact",
            showTeamSpecIcons = true,
            healerIconColorMode = "class",
            healerIconCustomColor = {
                r = 1,
                g = 1,
                b = 1,
            },
        },
        objectives = {
            objectivePinScale = 2.5,
            objectivePinAlpha = 0.9,
            carrierObjectivePinScale = 1,
            vehicleObjectivePinScale = 1,
            showFlagCarrierTrail = true,
            carriedTrailStyle = "breadcrumbs",
            carriedTrailDuration = 10,
            carriedTrailDotScale = 0.7,
            carriedTrailDetail = 16,
            carriedObjectiveColorMode = "original",
            flashCarriedObjectives = true,
            carriedObjectiveFlashPeriod = 0.7,
            carriedObjectiveFlashStrength = 0.95,
        },
        timers = {
            showObjectivePulseAnimations = true,
            showObjectiveCaptureTimers = true,
            pulseObjectiveDuringCaptureTimer = true,
            flashObjectiveBeforeCapture = true,
            objectiveCaptureFlashThreshold = 9,
            objectiveCaptureFlashBrightness = 0.25,
            objectiveCapturePulseMinAlpha = 0.4,
            objectiveCapturePulseMaxAlpha = 0.6,
            objectiveCaptureAfterPulseAlpha = 0.36,
            showObjectiveTimerText = true,
            showObjectiveBlitzUncapText = true,
            objectiveTimerTextThreshold = 9,
            objectiveTimerTextSize = 8,
            objectiveTimerTextAlpha = 0.85,
            objectiveTimerTextOffsetX = 1,
            objectiveTimerTextOffsetY = -3,
            objectiveTimerTextFont = "Expressway",
            objectiveTimerTextColorMode = "custom",
            objectiveTimerTextColor = {
                r = 0.8784314393997192,
                g = 0.8235294818878174,
                b = 0.1529411822557449,
            },
            objectiveCaptureFillDirection = "vertical",
            objectiveCapturePulseCount = 1,
        },
    },
    [417] = {
        width = 408.5187683105469,
        height = 315.3334655761719,
        configured = true,
        customZoom = 2.26843100189036,
        customPanX = 0.4868067618801732,
        customPanY = 0.5285561673016094,
        useGlobalPlayerPinSettings = false,
        useGlobalObjectiveSettings = false,
        playerPins = {
            playerArrowSize = 60,
            playerPinStyle = "arrow",
            playerFovStyle = "sunbeam",
            playerFovScale = 1.8,
            playerFovAlpha = 0.75,
            playerFovBeamAlpha = 0.25,
            teamMemberPinSize = 9,
            healerPinSize = 16,
            teamPinBorderScale = 1,
            healerPinStyle = "icon",
            combatTeamPinScale = 1,
            stackTeamPins = true,
            fanOutTeamPinsOnHover = true,
            excludePlayerArrowFromStack = true,
            teamPinStackRadius = 40,
            teamPinStackOverlap = 30,
            teamPinStackDirection = "compact",
            showTeamSpecIcons = true,
            healerIconColorMode = "class",
            healerIconCustomColor = {
                r = 0.917647123336792,
                g = 1,
                b = 0.9137255549430847,
            },
        },
        objectives = {
            objectivePinScale = 1.25,
            objectivePinAlpha = 1,
            carrierObjectivePinScale = 0.8,
            vehicleObjectivePinScale = 1,
            showFlagCarrierTrail = true,
            carriedTrailStyle = "tether",
            carriedTrailDuration = 2.25,
            carriedTrailDotScale = 1.7,
            carriedTrailDetail = 24,
            carriedObjectiveColorMode = "faction",
            flashCarriedObjectives = true,
            carriedObjectiveFlashPeriod = 0.6,
            carriedObjectiveFlashStrength = 0.4,
        },
        timers = {
            showObjectivePulseAnimations = true,
            showObjectiveCaptureTimers = true,
            pulseObjectiveDuringCaptureTimer = true,
            flashObjectiveBeforeCapture = false,
            objectiveCaptureFlashThreshold = 9,
            objectiveCaptureFlashBrightness = 0.25,
            objectiveCapturePulseMinAlpha = 0.4,
            objectiveCapturePulseMaxAlpha = 0.6,
            objectiveCaptureAfterPulseAlpha = 0.36,
            showObjectiveTimerText = true,
            showObjectiveBlitzUncapText = true,
            objectiveTimerTextThreshold = 9,
            objectiveTimerTextSize = 14,
            objectiveTimerTextAlpha = 1,
            objectiveTimerTextOffsetX = 0,
            objectiveTimerTextOffsetY = 0,
            objectiveTimerTextFont = "friz",
            objectiveTimerTextColorMode = "custom",
            objectiveTimerTextColor = {
                b = 1,
                g = 1,
                r = 1,
            },
            objectiveCaptureFillDirection = "horizontal",
            objectiveCapturePulseCount = 1,
        },
    },
    [423] = {
        width = 372.2962036132813,
        height = 301.9258422851563,
        configured = true,
        customZoom = 1.49153020589487,
        customPanX = 0.4569815519585109,
        customPanY = 0.5272656157325321,
        useGlobalPlayerPinSettings = false,
        useGlobalObjectiveSettings = true,
        playerPins = {
            playerArrowSize = 45,
            playerPinStyle = "arrow",
            playerFovStyle = "sunbeam",
            playerFovScale = 2.6,
            playerFovAlpha = 1,
            playerFovBeamAlpha = 0.25,
            teamMemberPinSize = 10,
            healerPinSize = 19.5,
            teamPinBorderScale = 1,
            healerPinStyle = "icon",
            combatTeamPinScale = 1,
            stackTeamPins = true,
            fanOutTeamPinsOnHover = true,
            excludePlayerArrowFromStack = true,
            teamPinStackRadius = 17,
            teamPinStackOverlap = 0,
            teamPinStackDirection = "compact",
            showTeamSpecIcons = true,
            healerIconColorMode = "class",
            healerIconCustomColor = {
                r = 0.1882353127002716,
                g = 0.803921639919281,
                b = 0,
            },
        },
        objectives = {
            objectivePinScale = 1,
            objectivePinAlpha = 1,
            carrierObjectivePinScale = 1,
            vehicleObjectivePinScale = 1,
            showFlagCarrierTrail = true,
            carriedTrailStyle = "breadcrumbs",
            carriedTrailDuration = 10,
            carriedTrailDotScale = 0.7,
            carriedTrailDetail = 16,
            carriedObjectiveColorMode = "original",
            flashCarriedObjectives = true,
            carriedObjectiveFlashPeriod = 0.7,
            carriedObjectiveFlashStrength = 0.95,
        },
        timers = {
            showObjectivePulseAnimations = true,
            showObjectiveCaptureTimers = true,
            pulseObjectiveDuringCaptureTimer = true,
            flashObjectiveBeforeCapture = false,
            objectiveCaptureFlashThreshold = 9,
            objectiveCaptureFlashBrightness = 0.25,
            objectiveCapturePulseMinAlpha = 0.4,
            objectiveCapturePulseMaxAlpha = 0.6,
            objectiveCaptureAfterPulseAlpha = 0.36,
            showObjectiveTimerText = true,
            showObjectiveBlitzUncapText = true,
            objectiveTimerTextThreshold = 9,
            objectiveTimerTextSize = 14,
            objectiveTimerTextAlpha = 1,
            objectiveTimerTextOffsetX = 0,
            objectiveTimerTextOffsetY = 0,
            objectiveTimerTextFont = "friz",
            objectiveTimerTextColorMode = "custom",
            objectiveTimerTextColor = {
                b = 1,
                g = 1,
                r = 1,
            },
            objectiveCaptureFillDirection = "horizontal",
            objectiveCapturePulseCount = 1,
        },
    },
    [907] = {
        width = 372.0000610351563,
        height = 301.9999694824219,
        configured = true,
        customZoom = 1.7152597367791,
        customPanX = 0.4501366273719146,
        customPanY = 0.5399246356733366,
        useGlobalPlayerPinSettings = false,
        useGlobalObjectiveSettings = false,
        playerPins = {
            playerArrowSize = 50,
            playerPinStyle = "arrow",
            playerFovStyle = "sunbeam",
            playerFovScale = 2.3,
            playerFovAlpha = 1,
            playerFovBeamAlpha = 0.25,
            teamMemberPinSize = 9,
            healerPinSize = 20.5,
            teamPinBorderScale = 1,
            healerPinStyle = "icon",
            combatTeamPinScale = 1,
            stackTeamPins = true,
            fanOutTeamPinsOnHover = true,
            excludePlayerArrowFromStack = true,
            teamPinStackRadius = 22,
            teamPinStackOverlap = 10,
            teamPinStackDirection = "compact",
            showTeamSpecIcons = true,
            healerIconColorMode = "class",
            healerIconCustomColor = {
                r = 1,
                g = 1,
                b = 1,
            },
        },
        objectives = {
            objectivePinScale = 2.5,
            objectivePinAlpha = 1,
            carrierObjectivePinScale = 1,
            vehicleObjectivePinScale = 1,
            showFlagCarrierTrail = true,
            carriedTrailStyle = "breadcrumbs",
            carriedTrailDuration = 10,
            carriedTrailDotScale = 0.7,
            carriedTrailDetail = 16,
            carriedObjectiveColorMode = "original",
            flashCarriedObjectives = true,
            carriedObjectiveFlashPeriod = 0.7,
            carriedObjectiveFlashStrength = 0.95,
        },
        timers = {
            showObjectivePulseAnimations = true,
            showObjectiveCaptureTimers = true,
            pulseObjectiveDuringCaptureTimer = true,
            flashObjectiveBeforeCapture = true,
            objectiveCaptureFlashThreshold = 9,
            objectiveCaptureFlashBrightness = 0.25,
            objectiveCapturePulseMinAlpha = 0.25,
            objectiveCapturePulseMaxAlpha = 0.6,
            objectiveCaptureAfterPulseAlpha = 0.36,
            showObjectiveTimerText = true,
            showObjectiveBlitzUncapText = true,
            objectiveTimerTextThreshold = 59,
            objectiveTimerTextSize = 12,
            objectiveTimerTextAlpha = 0.85,
            objectiveTimerTextOffsetX = 0,
            objectiveTimerTextOffsetY = 0,
            objectiveTimerTextFont = "Expressway",
            objectiveTimerTextColorMode = "custom",
            objectiveTimerTextColor = {
                b = 1,
                g = 1,
                r = 1,
            },
            objectiveCaptureFillDirection = "vertical",
            objectiveCapturePulseCount = 1,
        },
    },
    [1339] = {
        width = 249.4815521240234,
        height = 431.4078674316406,
        configured = true,
        customZoom = 3,
        customPanX = 0.5442577401943665,
        customPanY = 0.5142659117594052,
        useGlobalPlayerPinSettings = false,
        useGlobalObjectiveSettings = false,
        playerPins = {
            playerArrowSize = 45,
            playerPinStyle = "arrow",
            playerFovStyle = "sunbeam",
            playerFovScale = 2.75,
            playerFovAlpha = 1,
            playerFovBeamAlpha = 0.25,
            teamMemberPinSize = 9,
            healerPinSize = 19,
            teamPinBorderScale = 1,
            healerPinStyle = "icon",
            combatTeamPinScale = 1,
            stackTeamPins = true,
            fanOutTeamPinsOnHover = true,
            excludePlayerArrowFromStack = true,
            teamPinStackRadius = 18,
            teamPinStackOverlap = 0,
            teamPinStackDirection = "compact",
            showTeamSpecIcons = true,
            healerIconColorMode = "class",
            healerIconCustomColor = {
                r = 0.3137255012989044,
                g = 0.8862745761871338,
                b = 0.2196078598499298,
            },
        },
        objectives = {
            objectivePinScale = 1,
            objectivePinAlpha = 1,
            carrierObjectivePinScale = 1.05,
            vehicleObjectivePinScale = 1,
            showFlagCarrierTrail = true,
            carriedTrailStyle = "glow",
            carriedTrailDuration = 30,
            carriedTrailDotScale = 1,
            carriedTrailDetail = 24,
            carriedObjectiveColorMode = "original",
            flashCarriedObjectives = true,
            carriedObjectiveFlashPeriod = 0.8,
            carriedObjectiveFlashStrength = 0.45,
        },
        timers = {
            showObjectivePulseAnimations = true,
            showObjectiveCaptureTimers = true,
            pulseObjectiveDuringCaptureTimer = true,
            flashObjectiveBeforeCapture = false,
            objectiveCaptureFlashThreshold = 9,
            objectiveCaptureFlashBrightness = 0.25,
            objectiveCapturePulseMinAlpha = 0.4,
            objectiveCapturePulseMaxAlpha = 0.6,
            objectiveCaptureAfterPulseAlpha = 0.36,
            showObjectiveTimerText = true,
            showObjectiveBlitzUncapText = true,
            objectiveTimerTextThreshold = 9,
            objectiveTimerTextSize = 14,
            objectiveTimerTextAlpha = 1,
            objectiveTimerTextOffsetX = 0,
            objectiveTimerTextOffsetY = 0,
            objectiveTimerTextFont = "friz",
            objectiveTimerTextColorMode = "custom",
            objectiveTimerTextColor = {
                b = 1,
                g = 1,
                r = 1,
            },
            objectiveCaptureFillDirection = "horizontal",
            objectiveCapturePulseCount = 1,
        },
    },
    [1576] = {
        width = 416.7409362792969,
        height = 390.2226257324219,
        configured = true,
        customZoom = 1.520875,
        customPanX = 0.5,
        customPanY = 0.5,
        useGlobalPlayerPinSettings = true,
        useGlobalObjectiveSettings = false,
        playerPins = {
            playerArrowSize = 128,
            playerPinStyle = "compass",
            playerFovStyle = "sunbeam",
            playerFovScale = 3,
            playerFovAlpha = 1,
            playerFovBeamAlpha = 0.25,
            teamMemberPinSize = 14,
            healerPinSize = 16,
            teamPinBorderScale = 1,
            healerPinStyle = "icon",
            combatTeamPinScale = 1,
            stackTeamPins = true,
            fanOutTeamPinsOnHover = true,
            excludePlayerArrowFromStack = true,
            teamPinStackRadius = 37,
            teamPinStackOverlap = 35,
            teamPinStackDirection = "compact",
            showTeamSpecIcons = false,
            healerIconColorMode = "class",
            healerIconCustomColor = {
                r = 0.1529411822557449,
                g = 1,
                b = 0,
            },
        },
        objectives = {
            objectivePinScale = 2.5,
            objectivePinAlpha = 0.9,
            carrierObjectivePinScale = 1,
            vehicleObjectivePinScale = 1,
            showFlagCarrierTrail = true,
            carriedTrailStyle = "breadcrumbs",
            carriedTrailDuration = 10,
            carriedTrailDotScale = 0.7,
            carriedTrailDetail = 16,
            carriedObjectiveColorMode = "original",
            flashCarriedObjectives = true,
            carriedObjectiveFlashPeriod = 0.7,
            carriedObjectiveFlashStrength = 0.95,
        },
        timers = {
            showObjectivePulseAnimations = true,
            showObjectiveCaptureTimers = true,
            pulseObjectiveDuringCaptureTimer = true,
            flashObjectiveBeforeCapture = false,
            objectiveCaptureFlashThreshold = 9,
            objectiveCaptureFlashBrightness = 0.25,
            objectiveCapturePulseMinAlpha = 0.4,
            objectiveCapturePulseMaxAlpha = 0.6,
            objectiveCaptureAfterPulseAlpha = 0.36,
            showObjectiveTimerText = false,
            showObjectiveBlitzUncapText = true,
            objectiveTimerTextThreshold = 59,
            objectiveTimerTextSize = 14,
            objectiveTimerTextAlpha = 1,
            objectiveTimerTextOffsetX = 0,
            objectiveTimerTextOffsetY = 0,
            objectiveTimerTextFont = "Expressway",
            objectiveTimerTextColorMode = "custom",
            objectiveTimerTextColor = {
                r = 1,
                g = 0.8431373238563538,
                b = 0.3843137621879578,
            },
            objectiveCaptureFillDirection = "horizontal",
            objectiveCapturePulseCount = 1,
        },
    },
    [2345] = {
        width = 416.9265441894531,
        height = 228.4074859619141,
        configured = true,
        customZoom = 1.520875,
        customPanX = 0.5304078978952738,
        customPanY = 0.5003964727195013,
        useGlobalPlayerPinSettings = false,
        useGlobalObjectiveSettings = false,
        playerPins = {
            playerArrowSize = 41,
            playerPinStyle = "arrow",
            playerFovStyle = "sunbeam",
            playerFovScale = 3.25,
            playerFovAlpha = 0.65,
            playerFovBeamAlpha = 0.25,
            teamMemberPinSize = 13,
            healerPinSize = 20.5,
            teamPinBorderScale = 1,
            healerPinStyle = "icon",
            combatTeamPinScale = 1,
            stackTeamPins = true,
            fanOutTeamPinsOnHover = true,
            excludePlayerArrowFromStack = true,
            teamPinStackRadius = 31,
            teamPinStackOverlap = 30,
            teamPinStackDirection = "compact",
            showTeamSpecIcons = false,
            healerIconColorMode = "class",
            healerIconCustomColor = {
                r = 1,
                g = 1,
                b = 1,
            },
        },
        objectives = {
            objectivePinScale = 2.2,
            objectivePinAlpha = 1,
            carrierObjectivePinScale = 1,
            vehicleObjectivePinScale = 1,
            showFlagCarrierTrail = true,
            carriedTrailStyle = "breadcrumbs",
            carriedTrailDuration = 10,
            carriedTrailDotScale = 0.7,
            carriedTrailDetail = 16,
            carriedObjectiveColorMode = "original",
            flashCarriedObjectives = true,
            carriedObjectiveFlashPeriod = 0.7,
            carriedObjectiveFlashStrength = 0.95,
        },
        timers = {
            showObjectivePulseAnimations = true,
            showObjectiveCaptureTimers = true,
            pulseObjectiveDuringCaptureTimer = true,
            flashObjectiveBeforeCapture = false,
            objectiveCaptureFlashThreshold = 9,
            objectiveCaptureFlashBrightness = 0.25,
            objectiveCapturePulseMinAlpha = 0.4,
            objectiveCapturePulseMaxAlpha = 0.6,
            objectiveCaptureAfterPulseAlpha = 0.36,
            showObjectiveTimerText = true,
            showObjectiveBlitzUncapText = true,
            objectiveTimerTextThreshold = 9,
            objectiveTimerTextSize = 14,
            objectiveTimerTextAlpha = 1,
            objectiveTimerTextOffsetX = 0,
            objectiveTimerTextOffsetY = 0,
            objectiveTimerTextFont = "friz",
            objectiveTimerTextColorMode = "custom",
            objectiveTimerTextColor = {
                b = 1,
                g = 1,
                r = 1,
            },
            objectiveCaptureFillDirection = "horizontal",
            objectiveCapturePulseCount = 1,
        },
    },
}

local PERSONAL_MAP_DEFAULT_ALIASES = {
    [397] = 210,   -- historical Eye of the Storm configuration bucket
    [519] = 1576,  -- retired Deepwind Gorge map ID
    [761] = 275,   -- Battle for Gilneas instance/historical ID
    [1366] = 112,  -- modern Arathi Basin UI map ID
    [1803] = 907,  -- alternate Seething Shore UI map ID
}

local PERSONAL_MAP_DEFAULT_NAME_IDS = {
    arathibasin = 112,
    twinpeaks = 206,
    eyeofthestorm = 210,
    battleforgilneas = 275,
    templeofkotmogu = 417,
    silvershardmines = 423,
    seethingshore = 907,
    warsonggulch = 1339,
    deepwindgorge = 1576,
    deephaulravine = 2345,
}

local function NormalizeDefaultMapName(value)
    value = tostring(value or ""):lower()
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return value:gsub("[%s%p%c]", "")
end

local function ResolvePersonalMapDefaultID(infoOrID)
    local info = type(infoOrID) == "table" and infoOrID or nil
    if info then
        local nameID = PERSONAL_MAP_DEFAULT_NAME_IDS[NormalizeDefaultMapName(info.name)]
        if nameID then return nameID end
    end

    local id = tonumber(info and (info.id or info.configID or info.mapID or info.uiMapID) or infoOrID)
    return PERSONAL_MAP_DEFAULT_ALIASES[id] or id
end

local function GetPersonalMapDefaults(infoOrID)
    return PERSONAL_MAP_DEFAULTS[ResolvePersonalMapDefaultID(infoOrID)]
end

local function NormalizeCarriedTrailStyle(value)
    if value == "glow" or value == "tether" then return value end
    return "breadcrumbs"
end

local function NormalizeCarriedObjectiveColorMode(value, legacyKotmoguMode, legacyEnemyTint)
    if value == "original" or value == "faction" then return value end
    if legacyKotmoguMode == "faction" then return "faction" end
    if legacyKotmoguMode == "orb" then return "original" end
    -- The retired "enemy" Kotmogu mode mixed original and faction colouring,
    -- so it has no exact equivalent. Migrate it to Original, which preserves
    -- the objective artwork rather than recolouring every friendly carrier.
    if legacyKotmoguMode == "enemy" then return "original" end
    if legacyEnemyTint == false then return "original" end
    return OBJECTIVE_PIN_DEFAULTS.carriedObjectiveColorMode
end

local function CopyDefaults(source, destination)
    destination = type(destination) == "table" and destination or {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            destination[key] = CopyDefaults(value, destination[key])
        elseif destination[key] == nil then
            destination[key] = value
        end
    end
    return destination
end

local function ResetDefaults(source, destination)
    destination = type(destination) == "table" and destination or {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            destination[key] = ResetDefaults(value, {})
        else
            destination[key] = value
        end
    end
    return destination
end

local function NormalizePlayerFovSettings(settings)
    if type(settings) ~= "table" then return end

    -- Migrate the retired checkbox once. An enabled cone becomes the Simple FoV
    -- style; disabled or absent cones become None. Scale and alpha retain the
    -- user's previous values under their new FoV setting names.
    local hasLegacySettings = settings.showPlayerVisionCone ~= nil
        or settings.playerVisionConeScale ~= nil
        or settings.playerVisionConeAlpha ~= nil
    local styleVersion = tonumber(settings.playerFovStyleVersion) or 0
    if styleVersion < 1 and hasLegacySettings then
        settings.playerFovStyle = settings.showPlayerVisionCone == true and "simple" or "none"
        settings.playerFovScale = tonumber(settings.playerVisionConeScale)
            or tonumber(settings.playerFovScale)
            or PLAYER_PIN_DEFAULTS.playerFovScale
        settings.playerFovAlpha = tonumber(settings.playerVisionConeAlpha)
            or tonumber(settings.playerFovAlpha)
            or PLAYER_PIN_DEFAULTS.playerFovAlpha
    end

    -- Soft is superseded by Simple. Waves has been removed without a direct
    -- replacement, so it is safely disabled rather than silently selecting a
    -- visually different variant.
    if styleVersion < 2 then
        if settings.playerFovStyle == "soft" then
            settings.playerFovStyle = "simple"
        elseif settings.playerFovStyle == "waves" then
            settings.playerFovStyle = "none"
        end
    end

    if styleVersion < 3 then
        if settings.playerFovStyle == "split45" then
            settings.playerFovStyle = "coldRays"
        elseif settings.playerFovStyle == "spotlight" then
            settings.playerFovStyle = "sunbeam"
        end
    end

    if styleVersion < 4 then
        if settings.playerFovStyle == "cone" then
            settings.playerFovStyle = "simple"
            settings.playerFovAlpha = 1.00
        end
        if settings.playerFovStyle == "coldRays" or settings.playerFovStyle == "sunbeam" then
            settings.playerFovBeamAlpha = 0.25
        end
    end

    settings.playerFovStyle = ({ none = true, simple = true, coldRays = true, sunbeam = true })[settings.playerFovStyle]
        and settings.playerFovStyle or PLAYER_PIN_DEFAULTS.playerFovStyle
    settings.playerFovScale = BattleMaps.Clamp(
        tonumber(settings.playerFovScale) or PLAYER_PIN_DEFAULTS.playerFovScale,
        0.25,
        5.00
    )
    settings.playerFovAlpha = BattleMaps.Clamp(
        tonumber(settings.playerFovAlpha) or PLAYER_PIN_DEFAULTS.playerFovAlpha,
        0.10,
        1.00
    )
    settings.playerFovBeamAlpha = BattleMaps.Clamp(
        tonumber(settings.playerFovBeamAlpha) or PLAYER_PIN_DEFAULTS.playerFovBeamAlpha,
        0.00,
        1.00
    )
    settings.playerFovStyleVersion = 5
    settings.showPlayerVisionCone = nil
    settings.playerVisionConeScale = nil
    settings.playerVisionConeAlpha = nil
    settings.playerFovSpotlightAlpha = nil
    settings.playerFovArcAlpha = nil
end

local function MigrateLegacyPinBuckets(config)
    if type(config) ~= "table" then return end
    local legacy = type(config.pins) == "table" and config.pins or {}
    local playerPins = type(config.playerPins) == "table" and config.playerPins or {}
    for _, key in ipairs({ "showPlayerVisionCone", "playerVisionConeScale", "playerVisionConeAlpha" }) do
        if playerPins[key] == nil and legacy[key] ~= nil then
            playerPins[key] = legacy[key]
        end
    end
    config.pins = CopyDefaults(PIN_DEFAULTS, config.pins)
    config.playerPins = CopyDefaults(PLAYER_PIN_DEFAULTS, playerPins)
    local objectiveSettings = type(config.objectives) == "table" and config.objectives or {}
    if objectiveSettings.carriedObjectiveColorMode == nil then
        objectiveSettings.carriedObjectiveColorMode = NormalizeCarriedObjectiveColorMode(
            nil,
            objectiveSettings.kotmoguOrbColorMode,
            objectiveSettings.factionColorEnemyKotmoguOrbs
        )
    end
    objectiveSettings.kotmoguOrbColorMode = nil
    objectiveSettings.factionColorEnemyKotmoguOrbs = nil
    config.objectives = CopyDefaults(OBJECTIVE_PIN_DEFAULTS, objectiveSettings)
    config.timers = CopyDefaults(TIMER_DEFAULTS, config.timers)
    config.notifications = CopyDefaults(NOTIFICATION_DEFAULTS, config.notifications)

    -- In-combat team-pin scaling is retired. Keep both compatibility buckets
    -- pinned to 1 so an older profile cannot silently restore the old effect.
    config.playerPins.combatTeamPinScale = 1
    config.pins.combatTeamPinScale = 1

    for key in pairs(PLAYER_PIN_DEFAULTS) do
        if config.playerPins[key] == nil and legacy[key] ~= nil then
            config.playerPins[key] = legacy[key]
        end
    end
    for key in pairs(OBJECTIVE_PIN_DEFAULTS) do
        if config.objectives[key] == nil and legacy[key] ~= nil then
            config.objectives[key] = legacy[key]
        end
    end
    NormalizePlayerFovSettings(config.playerPins)
    config.pins.showPlayerVisionCone = nil
    config.pins.playerVisionConeScale = nil
    config.pins.playerVisionConeAlpha = nil
end

local function NewWorldMapViewDefaults()
    return {
        zoom = 1,
        panX = 0.5,
        panY = 0.5,
        configured = false,
    }
end

local function NewMapDefaults(info)
    local defaults = {
        name = info.name,
        enabled = true,
        width = info.width,
        height = info.height,
        point = "CENTER",
        relativePoint = "CENTER",
        relativeTo = "UIParent",
        offsetX = 0,
        offsetY = 0,
        configured = false,
        customZoom = 1,
        customPanX = 0.5,
        customPanY = 0.5,
        worldMapView = NewWorldMapViewDefaults(),
        pins = CopyDefaults(PIN_DEFAULTS, {}), -- legacy combined bucket
        playerPins = CopyDefaults(PLAYER_PIN_DEFAULTS, {}),
        objectives = CopyDefaults(OBJECTIVE_PIN_DEFAULTS, {}),
        timers = CopyDefaults(TIMER_DEFAULTS, {}),
        notifications = CopyDefaults(NOTIFICATION_DEFAULTS, {}),
    }

    local personal = GetPersonalMapDefaults(info)
    if personal then
        for key, value in pairs(personal) do
            if type(value) == "table" then
                defaults[key] = ResetDefaults(value, defaults[key])
            else
                defaults[key] = value
            end
        end
    end

    -- Keep the legacy combined bucket coherent for older modules or profiles.
    defaults.playerPins.combatTeamPinScale = 1
    defaults.pins.combatTeamPinScale = 1
    for key in pairs(PIN_DEFAULTS) do
        local value = defaults.playerPins[key]
        if value == nil then value = defaults.objectives[key] end
        if value ~= nil then defaults.pins[key] = value end
    end
    return defaults
end

local function EnsureMapScopedSettings(config, db)
    if type(config) ~= "table" then return end
    db = type(db) == "table" and db or BattleMapsDB or {}

    -- These switches are map-scoped. The root values are retained only as
    -- migration/default seeds for older SavedVariables and newly discovered maps.
    if config.useGlobalPlayerPinSettings == nil then
        config.useGlobalPlayerPinSettings = db.useGlobalPlayerPinSettings ~= false
    end
    if config.useGlobalObjectiveSettings == nil then
        config.useGlobalObjectiveSettings = db.useGlobalObjectiveSettings ~= false
    end
end

function Database:Initialize()
    if BattleMapsDB == nil and type(AutoBGMapDB) == "table" then
        BattleMapsDB = AutoBGMapDB
    end

    local previousNotificationAttachmentVersion = type(BattleMapsDB) == "table"
        and type(BattleMapsDB.notifications) == "table"
        and tonumber(BattleMapsDB.notifications.attachmentVersion)
        or nil
    local previousTimerCompactDefaultsVersion = type(BattleMapsDB) == "table"
        and tonumber(BattleMapsDB.timerCompactDefaultsVersion)
        or 0
    local hadSolidTeamPinOutOfCombat = type(BattleMapsDB) == "table"
        and BattleMapsDB.useSolidTeamPinOutOfCombat ~= nil
    local previousCombatTextureSetting = type(BattleMapsDB) == "table"
        and BattleMapsDB.useCombatTeamPinTexture
    local previousPlayerPinStyleVersion = type(BattleMapsDB) == "table"
        and tonumber(BattleMapsDB.playerPinStyleVersion)
        or 0
    local previousCustomPlayerArrow = type(BattleMapsDB) == "table"
        and BattleMapsDB.useCustomPlayerArrow
    local previousFovMaskSettingsVersion = type(BattleMapsDB) == "table"
        and tonumber(BattleMapsDB.fovMaskSettingsVersion)
        or 0
    local previousFovBoundaryMask = type(BattleMapsDB) == "table"
        and BattleMapsDB.fovBoundaryMask == true
    local hadFovBeamMask = type(BattleMapsDB) == "table"
        and BattleMapsDB.fovBeamMask ~= nil
    local previousCarriedObjectiveColorMode = type(BattleMapsDB) == "table"
        and BattleMapsDB.carriedObjectiveColorMode or nil
    local previousKotmoguOrbColorMode = type(BattleMapsDB) == "table"
        and BattleMapsDB.kotmoguOrbColorMode or nil
    local previousKotmoguEnemyTint = type(BattleMapsDB) == "table"
        and BattleMapsDB.factionColorEnemyKotmoguOrbs
    local previousMovePlayerAurasSetting = nil
    if type(BattleMapsDB) == "table" then
        -- Prefer the provider-neutral key introduced by AuraLayout. 3.0.3's
        -- General-page checkbox still read the older alias, which could be
        -- false even after the canonical value had been enabled. Reading the
        -- canonical key first prevents /reload from resetting the option.
        if BattleMapsDB.bgLayoutMovePlayerAuras ~= nil then
            previousMovePlayerAurasSetting = BattleMapsDB.bgLayoutMovePlayerAuras == true
        elseif BattleMapsDB.movePlayerAurasToMinimapArea ~= nil then
            previousMovePlayerAurasSetting = BattleMapsDB.movePlayerAurasToMinimapArea == true
        elseif BattleMapsDB.elvuiBGLayoutMovePlayerAuras ~= nil then
            previousMovePlayerAurasSetting = (BattleMapsDB.elvuiBGLayoutEnabled ~= false)
                and BattleMapsDB.elvuiBGLayoutMovePlayerAuras == true
        end
    end

    BattleMapsDB = CopyDefaults(ROOT_DEFAULTS, BattleMapsDB)
    -- 2.8.8 briefly prototyped this as a nameplate aura. The feature now
    -- belongs to ElvUI group unit frames in BattleMaps; discard the test key.
    BattleMapsDB.showFriendlyFlagCarrierNameplateAura = nil
    -- 2.8.11 safety hotfix: retire the ElvUI secure unit-frame overlay experiment.
    BattleMapsDB.showFlagCarrierUnitFrameIcon = nil

    -- Migrate the former ElvUI-only aura placement preference to the provider-
    -- neutral battleground layout option. Clean installs default to off; users
    -- who already enabled the personal ElvUI layout keep that preference.
    if previousMovePlayerAurasSetting ~= nil then
        BattleMapsDB.bgLayoutMovePlayerAuras = previousMovePlayerAurasSetting
        BattleMapsDB.movePlayerAurasToMinimapArea = previousMovePlayerAurasSetting
    end
    BattleMapsDB.elvuiBGLayoutEnabled = nil
    BattleMapsDB.elvuiBGLayoutMovePlayerAuras = nil
    BattleMapsDB.elvuiBGLayoutState = nil
    BattleMapsDB.maps = BattleMapsDB.maps or {}

    -- The first mask experiment had one boundary toggle. Preserve its enabled
    -- state for the new beam detail mask so existing Arathi test setups keep
    -- their visible effect after upgrading.
    if previousFovMaskSettingsVersion < 1 and not hadFovBeamMask then
        BattleMapsDB.fovBeamMask = previousFovBoundaryMask
    end
    -- Version 2 promotes the map-space FoV masks from an experiment to the
    -- normal renderer. The prior controls were debug-only, so make every
    -- authored FoV pass clip by default rather than leaving the primary cone
    -- and beam unmasked on existing profiles.
    if previousFovMaskSettingsVersion < 2 then
        BattleMapsDB.fovBoundaryMask = true
        BattleMapsDB.fovBeamMask = true
    end
    -- Version 3 removes the retired proximity/accent FoV pass and its saved
    -- toggle. Keep the SavedVariables table clean rather than carrying a setting
    -- that can no longer affect rendering.
    BattleMapsDB.fovAccentMask = nil
    BattleMapsDB.fovMaskSettingsVersion = 3

    if BattleMapsDB.useGlobalPlayerPinSettings == nil then
        BattleMapsDB.useGlobalPlayerPinSettings = BattleMapsDB.useGlobalPinSettings ~= false
    end
    if BattleMapsDB.useGlobalObjectiveSettings == nil then
        BattleMapsDB.useGlobalObjectiveSettings = BattleMapsDB.useGlobalPinSettings ~= false
    end
    BattleMapsDB.useGlobalPlayerPinSettings = BattleMapsDB.useGlobalPlayerPinSettings ~= false
    BattleMapsDB.useGlobalObjectiveSettings = BattleMapsDB.useGlobalObjectiveSettings ~= false
    BattleMapsDB.useGlobalTimerSettings = BattleMapsDB.useGlobalTimerSettings ~= false
    BattleMapsDB.useGlobalNotificationSettings = BattleMapsDB.useGlobalNotificationSettings ~= false
    BattleMapsDB.useGlobalPinSettings = BattleMapsDB.useGlobalPlayerPinSettings and BattleMapsDB.useGlobalObjectiveSettings

    -- 2.5.68 reverses the optional team-fill state: the solid fill is now the
    -- out-of-combat appearance and the centre-dot fill is the combat appearance.
    -- Preserve the user's old checkbox preference while migrating to the new key.
    if not hadSolidTeamPinOutOfCombat then
        BattleMapsDB.useSolidTeamPinOutOfCombat = previousCombatTextureSetting ~= false
    else
        BattleMapsDB.useSolidTeamPinOutOfCombat = BattleMapsDB.useSolidTeamPinOutOfCombat ~= false
    end
    BattleMapsDB.useCombatTeamPinTexture = nil

    local colorMode = BattleMapsDB.playerArrowColorMode
    if colorMode ~= "class" and colorMode ~= "custom" then
        -- Faction colour is retired. Class colour is evaluated from the
        -- currently logged-in character rather than from a saved RGB value.
        BattleMapsDB.playerArrowColorMode = "class"
    end

    local customColor = type(BattleMapsDB.playerArrowCustomColor) == "table"
        and BattleMapsDB.playerArrowCustomColor or {}
    customColor.r = BattleMaps.Clamp(tonumber(customColor.r or customColor[1]) or 1, 0, 1)
    customColor.g = BattleMaps.Clamp(tonumber(customColor.g or customColor[2]) or 0.82, 0, 1)
    customColor.b = BattleMaps.Clamp(tonumber(customColor.b or customColor[3]) or 0.22, 0, 1)
    BattleMapsDB.playerArrowCustomColor = customColor

    BattleMapsDB.fanOutTeamPinsOnHover = BattleMapsDB.fanOutTeamPinsOnHover ~= false
    BattleMapsDB.showTeamSpecIcons = BattleMapsDB.showTeamSpecIcons ~= false
    BattleMapsDB.combatTeamPinScale = 1
    BattleMapsDB.teamPinBorderScale = BattleMaps.Clamp(
        tonumber(BattleMapsDB.teamPinBorderScale) or PLAYER_PIN_DEFAULTS.teamPinBorderScale,
        0.50,
        2.00
    )
    BattleMapsDB.healerPinStyle = ({ circle = true, icon = true, ignore = true })[BattleMapsDB.healerPinStyle]
        and BattleMapsDB.healerPinStyle or PLAYER_PIN_DEFAULTS.healerPinStyle
    local healerIconColor = type(BattleMapsDB.healerIconCustomColor) == "table"
        and BattleMapsDB.healerIconCustomColor or {}
    healerIconColor.r = BattleMaps.Clamp(tonumber(healerIconColor.r or healerIconColor[1]) or 1, 0, 1)
    healerIconColor.g = BattleMaps.Clamp(tonumber(healerIconColor.g or healerIconColor[2]) or 1, 0, 1)
    healerIconColor.b = BattleMaps.Clamp(tonumber(healerIconColor.b or healerIconColor[3]) or 1, 0, 1)
    BattleMapsDB.healerIconCustomColor = healerIconColor
    BattleMapsDB.healerIconColorMode = BattleMapsDB.healerIconColorMode == "class"
        and "class" or "custom"

    if BattleMapsDB.factionSwapAlert == nil then
        BattleMapsDB.factionSwapAlert = BattleMapsDB.factionColoredBorder ~= false
    end
    BattleMapsDB.factionSwapAlert = BattleMapsDB.factionSwapAlert ~= false
    BattleMapsDB.factionColoredBorder = BattleMapsDB.factionSwapAlert -- legacy alias
    BattleMapsDB.frameBorderSize = BattleMaps.Clamp(tonumber(BattleMapsDB.frameBorderSize) or 2, 0, 8)
    BattleMapsDB.frameBorderStrength = BattleMaps.Clamp(tonumber(BattleMapsDB.frameBorderStrength) or 1.00, 0.15, 1.00)
    if BattleMapsDB.frameBorderStyle ~= "tooltip" and BattleMapsDB.frameBorderStyle ~= "dialog" then
        BattleMapsDB.frameBorderStyle = "solid"
    end
    local frameBackgroundColor = type(BattleMapsDB.frameBackgroundColor) == "table"
        and BattleMapsDB.frameBackgroundColor or {}
    frameBackgroundColor.r = BattleMaps.Clamp(
        tonumber(frameBackgroundColor.r or frameBackgroundColor[1]) or 0.015, 0, 1)
    frameBackgroundColor.g = BattleMaps.Clamp(
        tonumber(frameBackgroundColor.g or frameBackgroundColor[2]) or 0.015, 0, 1)
    frameBackgroundColor.b = BattleMaps.Clamp(
        tonumber(frameBackgroundColor.b or frameBackgroundColor[3]) or 0.015, 0, 1)
    frameBackgroundColor.a = BattleMaps.Clamp(
        tonumber(frameBackgroundColor.a or frameBackgroundColor[4]) or 0.12, 0, 1)
    BattleMapsDB.frameBackgroundColor = frameBackgroundColor

    -- These are now core behaviours rather than optional menu toggles.
    BattleMapsDB.highlightFriendlyHealers = true
    BattleMapsDB.useCustomHealerIcon = true
    BattleMapsDB.useCustomTeamPinTextures = true

    -- Player radius support was retired. Remove stale SavedVariables so an
    -- older profile cannot recreate the removed renderer or options controls.
    BattleMapsDB.showPlayerRadius = nil
    BattleMapsDB.playerRadiusSize = nil

    if previousPlayerPinStyleVersion < 1 then
        -- The Player pin selector supersedes the former Custom player arrow
        -- checkbox. Preserve the existing choice once, before discarding the
        -- retired key.
        BattleMapsDB.playerPinStyle = previousCustomPlayerArrow == false
            and "default" or "arrow"
    end
    BattleMapsDB.playerPinStyle = ({
        default = true,
        arrow = true,
        compass = true,
        team = true,
    })[BattleMapsDB.playerPinStyle] and BattleMapsDB.playerPinStyle or "arrow"
    BattleMapsDB.playerPinStyleVersion = 1
    BattleMapsDB.useCustomPlayerArrow = nil
    NormalizePlayerFovSettings(BattleMapsDB)

    BattleMapsDB.fadeMapHeader = BattleMapsDB.fadeMapHeader ~= false
    BattleMapsDB.mapTextureAlpha = BattleMaps.Clamp(tonumber(BattleMapsDB.mapTextureAlpha) or 1, 0.20, 1.00)
    BattleMapsDB.fovBoundaryPreview = BattleMapsDB.fovBoundaryPreview == true
    BattleMapsDB.fovBoundaryMask = BattleMapsDB.fovBoundaryMask == true
    BattleMapsDB.fovBeamMask = BattleMapsDB.fovBeamMask ~= false
    BattleMapsDB.worldMapPinScale = BattleMaps.Clamp(
        tonumber(BattleMapsDB.worldMapPinScale) or 1.00, 0.75, 2.00)
    BattleMapsDB.showFlagCarrierTrail = BattleMapsDB.showFlagCarrierTrail ~= false
    BattleMapsDB.carriedTrailStyle = NormalizeCarriedTrailStyle(BattleMapsDB.carriedTrailStyle)
    local savedCarriedTrailDuration = tonumber(BattleMapsDB.carriedTrailDuration)
    if savedCarriedTrailDuration == nil
        or savedCarriedTrailDuration == 4.50
        or savedCarriedTrailDuration == 7.50 then
        savedCarriedTrailDuration = 12.00
    end
    BattleMapsDB.carriedTrailDuration = BattleMaps.Clamp(savedCarriedTrailDuration, 1.00, 30.00)
    BattleMapsDB.carriedTrailDotScale = BattleMaps.Clamp(
        tonumber(BattleMapsDB.carriedTrailDotScale) or 0.70, 0.20, 3.00)
    BattleMapsDB.carriedTrailDetail = math.floor(BattleMaps.Clamp(
        tonumber(BattleMapsDB.carriedTrailDetail) or OBJECTIVE_PIN_DEFAULTS.carriedTrailDetail,
        4,
        24
    ) + 0.5)
    BattleMapsDB.carriedObjectiveColorMode = NormalizeCarriedObjectiveColorMode(
        previousCarriedObjectiveColorMode,
        previousKotmoguOrbColorMode,
        previousKotmoguEnemyTint
    )
    BattleMapsDB.kotmoguOrbColorMode = nil
    BattleMapsDB.factionColorEnemyKotmoguOrbs = nil
    BattleMapsDB.flashCarriedObjectives = BattleMapsDB.flashCarriedObjectives ~= false
    BattleMapsDB.carriedObjectiveFlashPeriod = BattleMaps.Clamp(
        tonumber(BattleMapsDB.carriedObjectiveFlashPeriod) or 0.70, 0.30, 2.00)
    BattleMapsDB.carriedObjectiveFlashStrength = BattleMaps.Clamp(
        tonumber(BattleMapsDB.carriedObjectiveFlashStrength) or 0.95, 0.10, 1.00)
    BattleMapsDB.showObjectivePulseAnimations = BattleMapsDB.showObjectivePulseAnimations ~= false
    BattleMapsDB.showObjectiveCaptureTimers = BattleMapsDB.showObjectiveCaptureTimers ~= false
    BattleMapsDB.pulseObjectiveDuringCaptureTimer = BattleMapsDB.pulseObjectiveDuringCaptureTimer ~= false
    BattleMapsDB.flashObjectiveBeforeCapture = BattleMapsDB.flashObjectiveBeforeCapture == true

    -- Move users who still have the former defaults to the new compact-page
    -- defaults without overwriting deliberately customised values.
    if previousTimerCompactDefaultsVersion < 1 then
        local oldMin = tonumber(BattleMapsDB.objectiveCapturePulseMinAlpha)
        local oldMax = tonumber(BattleMapsDB.objectiveCapturePulseMaxAlpha)
        if oldMin == nil or (math.abs(oldMin - 0.45) < 0.001 and math.abs((oldMax or 1) - 1.00) < 0.001) then
            BattleMapsDB.objectiveCapturePulseMinAlpha = 0.40
            BattleMapsDB.objectiveCapturePulseMaxAlpha = 0.60
        end
        local oldThreshold = tonumber(BattleMapsDB.objectiveTimerTextThreshold)
        if oldThreshold == nil or oldThreshold == 10 then
            BattleMapsDB.objectiveTimerTextThreshold = 9
        end
        local oldCount = tonumber(BattleMapsDB.objectiveCapturePulseCount)
        if oldCount == nil or oldCount == 4 then
            BattleMapsDB.objectiveCapturePulseCount = 1
        end
    end
    BattleMapsDB.timerCompactDefaultsVersion = 1

    -- Migrate the earlier single range value into explicit lower/upper
    -- alpha bounds. Existing users keep the same visual result (1-range to 1).
    local legacyCapturePulseRange = tonumber(BattleMapsDB.objectiveCapturePulseAlphaRange)
    local capturePulseMinAlpha = tonumber(BattleMapsDB.objectiveCapturePulseMinAlpha)
    local capturePulseMaxAlpha = tonumber(BattleMapsDB.objectiveCapturePulseMaxAlpha)
    if legacyCapturePulseRange ~= nil then
        legacyCapturePulseRange = BattleMaps.Clamp(legacyCapturePulseRange, 0.00, 1.00)
        capturePulseMinAlpha = 1 - legacyCapturePulseRange
        capturePulseMaxAlpha = 1
        BattleMapsDB.objectiveCapturePulseAlphaRange = nil
    end
    capturePulseMinAlpha = BattleMaps.Clamp(capturePulseMinAlpha or 0.40, 0.00, 1.00)
    capturePulseMaxAlpha = BattleMaps.Clamp(capturePulseMaxAlpha or 0.60, 0.00, 1.00)
    if capturePulseMinAlpha > capturePulseMaxAlpha then
        capturePulseMinAlpha, capturePulseMaxAlpha = capturePulseMaxAlpha, capturePulseMinAlpha
    end
    BattleMapsDB.objectiveCapturePulseMinAlpha = capturePulseMinAlpha
    BattleMapsDB.objectiveCapturePulseMaxAlpha = capturePulseMaxAlpha
    BattleMapsDB.objectiveCaptureFlashThreshold = BattleMaps.Clamp(
        math.floor((tonumber(BattleMapsDB.objectiveCaptureFlashThreshold) or 9) + 0.5), 1, 59)
    BattleMapsDB.objectiveCaptureFlashBrightness = BattleMaps.Clamp(
        tonumber(BattleMapsDB.objectiveCaptureFlashBrightness) or 0.25, 0.10, 1.00)
    BattleMapsDB.objectiveCaptureAfterPulseAlpha = BattleMaps.Clamp(
        tonumber(BattleMapsDB.objectiveCaptureAfterPulseAlpha) or 0.36, 0.05, 1.00)
    BattleMapsDB.showObjectiveTimerText = BattleMapsDB.showObjectiveTimerText ~= false
    BattleMapsDB.showObjectiveBlitzUncapText = BattleMapsDB.showObjectiveBlitzUncapText ~= false
    BattleMapsDB.objectiveTimerTextThreshold = BattleMaps.Clamp(
        math.floor((tonumber(BattleMapsDB.objectiveTimerTextThreshold) or 9) + 0.5), 1, 59)
    BattleMapsDB.objectiveTimerTextSize = BattleMaps.Clamp(
        math.floor((tonumber(BattleMapsDB.objectiveTimerTextSize) or 14) + 0.5), 8, 32)
    BattleMapsDB.objectiveTimerTextAlpha = BattleMaps.Clamp(
        tonumber(BattleMapsDB.objectiveTimerTextAlpha) or 1.00, 0.00, 1.00)
    BattleMapsDB.objectiveTimerTextOffsetX = BattleMaps.Clamp(
        math.floor((tonumber(BattleMapsDB.objectiveTimerTextOffsetX) or 0) + 0.5), -32, 32)
    BattleMapsDB.objectiveTimerTextOffsetY = BattleMaps.Clamp(
        math.floor((tonumber(BattleMapsDB.objectiveTimerTextOffsetY) or 0) + 0.5), -32, 32)
    -- Preserve arbitrary LibSharedMedia font names such as "Expressway".
    -- Missing/unloaded media falls back safely at render time instead of
    -- destroying the user's saved selection.
    local timerFont = tostring(BattleMapsDB.objectiveTimerTextFont or "friz")
    if timerFont == "" then timerFont = "friz" end
    BattleMapsDB.objectiveTimerTextFont = timerFont
    local timerTextColor = type(BattleMapsDB.objectiveTimerTextColor) == "table"
        and BattleMapsDB.objectiveTimerTextColor or {}
    timerTextColor.r = BattleMaps.Clamp(tonumber(timerTextColor.r or timerTextColor[1]) or 1, 0, 1)
    timerTextColor.g = BattleMaps.Clamp(tonumber(timerTextColor.g or timerTextColor[2]) or 1, 0, 1)
    timerTextColor.b = BattleMaps.Clamp(tonumber(timerTextColor.b or timerTextColor[3]) or 1, 0, 1)
    BattleMapsDB.objectiveTimerTextColor = timerTextColor
    BattleMapsDB.objectiveTimerTextColorMode = BattleMapsDB.objectiveTimerTextColorMode == "class"
        and "class" or "custom"
    BattleMapsDB.objectiveCaptureFillDirection = BattleMapsDB.objectiveCaptureFillDirection == "vertical"
        and "vertical" or "horizontal"
    BattleMapsDB.objectiveAssaultPulseCount = BattleMaps.Clamp(
        math.floor((tonumber(BattleMapsDB.objectiveAssaultPulseCount) or 8) + 0.5), 1, 30)
    BattleMapsDB.objectiveCapturePulseCount = BattleMaps.Clamp(
        math.floor((tonumber(BattleMapsDB.objectiveCapturePulseCount) or 1) + 0.5), 1, 20)
    BattleMapsDB.objectivePulsePeriod = BattleMaps.Clamp(
        tonumber(BattleMapsDB.objectivePulsePeriod) or 0.80, 0.30, 2.00)
    BattleMapsDB.objectivePulseStrength = BattleMaps.Clamp(
        tonumber(BattleMapsDB.objectivePulseStrength) or 1.00, 0.25, 2.00)

    BattleMapsDB.showPingPulses = false
    BattleMapsDB.hideMinimapInNonEpicBattlegrounds = BattleMapsDB.hideMinimapInNonEpicBattlegrounds == true
    BattleMapsDB.bgLayoutMovePlayerAuras = BattleMapsDB.bgLayoutMovePlayerAuras == true
    -- Keep the previous public key coherent for downgrade compatibility, but
    -- never let it override the canonical value on startup.
    BattleMapsDB.movePlayerAurasToMinimapArea = BattleMapsDB.bgLayoutMovePlayerAuras
    BattleMapsDB.stackTeamPins = BattleMapsDB.stackTeamPins ~= false
    BattleMapsDB.excludePlayerArrowFromStack = BattleMapsDB.excludePlayerArrowFromStack == true
    BattleMapsDB.fanOutTeamPinsOnHover = BattleMapsDB.fanOutTeamPinsOnHover ~= false
    BattleMapsDB.showTeamSpecIcons = BattleMapsDB.showTeamSpecIcons ~= false
    BattleMapsDB.teamPinStackRadius = BattleMaps.Clamp(
        math.floor((tonumber(BattleMapsDB.teamPinStackRadius) or 18) + 0.5), 8, 40)
    BattleMapsDB.teamPinStackOverlap = BattleMaps.Clamp(
        math.floor((tonumber(BattleMapsDB.teamPinStackOverlap) or 30) + 0.5), 0, 80)
    -- Stacking now has one live/test presentation: the radial low-discrepancy spread.
    BattleMapsDB.teamPinStackDirection = "compact"

    local notifications = type(BattleMapsDB.notifications) == "table" and BattleMapsDB.notifications or {}
    notifications.enabled = notifications.enabled ~= false
    notifications.useBlizzardOnWorldMap = notifications.useBlizzardOnWorldMap ~= false
    notifications.colorByFaction = notifications.colorByFaction ~= false
    notifications.scale = BattleMaps.Clamp(tonumber(notifications.scale) or 1, 0.50, 2.00)
    notifications.width = BattleMaps.Clamp(tonumber(notifications.width) or 520, 240, 900)
    notifications.justifyH = (notifications.justifyH == "LEFT" or notifications.justifyH == "RIGHT")
        and notifications.justifyH or "CENTER"
    notifications.anchorMode = notifications.anchorMode == "MAP" and "MAP" or "INDEPENDENT"
    notifications.mapAnchorSide = ({
        TOP = true,
        TOPLEFT = true,
        TOPRIGHT = true,
        BOTTOM = true,
        LEFT = true,
        RIGHT = true,
    })[notifications.mapAnchorSide] and notifications.mapAnchorSide or "TOP"
    notifications.notificationAnchorPoint = ({
        AUTO = true,
        TOP = true,
        TOPLEFT = true,
        TOPRIGHT = true,
        BOTTOM = true,
        BOTTOMLEFT = true,
        BOTTOMRIGHT = true,
        LEFT = true,
        RIGHT = true,
    })[notifications.notificationAnchorPoint] and notifications.notificationAnchorPoint or "AUTO"
    notifications.point = notifications.point or "TOP"
    notifications.relativePoint = notifications.relativePoint or notifications.point
    notifications.x = BattleMaps.Clamp(tonumber(notifications.x) or 0, -300, 300)
    notifications.y = BattleMaps.Clamp(tonumber(notifications.y) or -100, -300, 300)
    notifications.mapX = BattleMaps.Clamp(tonumber(notifications.mapX) or 0, -300, 300)
    notifications.mapY = BattleMaps.Clamp(tonumber(notifications.mapY) or 28, -300, 300)

    -- alpha1.12 changes the corner attachments from "above the map" to true
    -- side attachments. Migrate the old default +28 vertical offset once so
    -- existing TOPLEFT/TOPRIGHT users begin with the corners actually joined.
    if (not previousNotificationAttachmentVersion or previousNotificationAttachmentVersion < 2)
        and (notifications.mapAnchorSide == "TOPLEFT" or notifications.mapAnchorSide == "TOPRIGHT")
        and notifications.mapY == 28 then
        notifications.mapX = 0
        notifications.mapY = 0
    end
    notifications.attachmentVersion = 2
    BattleMapsDB.notifications = notifications

    -- Deepwind Gorge was rebuilt in 8.3. Preserve any prototype settings that
    -- were stored against the retired UI map 519 when moving to map 1576.
    if BattleMapsDB.maps[1576] == nil and type(BattleMapsDB.maps[519]) == "table" then
        BattleMapsDB.maps[1576] = BattleMapsDB.maps[519]
    end

    for _, info in ipairs(BattleMaps.Battlegrounds.MAPS) do
        local defaults = NewMapDefaults(info)
        if type(BattleMapsDB.maps[info.id]) == "table" then
            EnsureMapScopedSettings(BattleMapsDB.maps[info.id], BattleMapsDB)
        end
        local config = CopyDefaults(defaults, BattleMapsDB.maps[info.id])
        EnsureMapScopedSettings(config, BattleMapsDB)

        -- Preserve existing native-map dimensions and placement as a sensible
        -- first position for the new independent frame. Zoom and pan use new
        -- keys because native MapCanvas scale values are not transferable.
        config.width = BattleMaps.Clamp(config.width, 240, 1000)
        config.height = BattleMaps.Clamp(config.height, 180, 800)
        config.customZoom = BattleMaps.Clamp(config.customZoom, 1, 3)
        config.customPanX = BattleMaps.Clamp(config.customPanX, 0, 1)
        config.customPanY = BattleMaps.Clamp(config.customPanY, 0, 1)
        config.worldMapView = type(config.worldMapView) == "table" and config.worldMapView or {}
        config.worldMapView.zoom = BattleMaps.Clamp(
            tonumber(config.worldMapView.zoom or config.worldMapView.customZoom) or 1, 1, 3)
        config.worldMapView.panX = BattleMaps.Clamp(
            tonumber(config.worldMapView.panX or config.worldMapView.customPanX) or 0.5, 0, 1)
        config.worldMapView.panY = BattleMaps.Clamp(
            tonumber(config.worldMapView.panY or config.worldMapView.customPanY) or 0.5, 0, 1)
        config.worldMapView.configured = config.worldMapView.configured == true
        config.worldMapView.customZoom = nil
        config.worldMapView.customPanX = nil
        config.worldMapView.customPanY = nil
        MigrateLegacyPinBuckets(config)
        config.objectives.carriedTrailStyle = NormalizeCarriedTrailStyle(config.objectives.carriedTrailStyle)
        config.objectives.carriedTrailDetail = math.floor(BattleMaps.Clamp(
            tonumber(config.objectives.carriedTrailDetail) or OBJECTIVE_PIN_DEFAULTS.carriedTrailDetail,
            4,
            24
        ) + 0.5)
        config.objectives.carriedObjectiveColorMode = NormalizeCarriedObjectiveColorMode(
            config.objectives.carriedObjectiveColorMode,
            config.objectives.kotmoguOrbColorMode,
            config.objectives.factionColorEnemyKotmoguOrbs
        )
        config.objectives.kotmoguOrbColorMode = nil
        config.objectives.factionColorEnemyKotmoguOrbs = nil
        config.playerPins.combatTeamPinScale = 1
        config.playerPins.teamPinBorderScale = BattleMaps.Clamp(
            tonumber(config.playerPins.teamPinBorderScale) or PLAYER_PIN_DEFAULTS.teamPinBorderScale,
            0.50,
            2.00
        )
        config.playerPins.healerPinStyle = ({ circle = true, icon = true, ignore = true })[config.playerPins.healerPinStyle]
            and config.playerPins.healerPinStyle or PLAYER_PIN_DEFAULTS.healerPinStyle
        config.playerPins.stackTeamPins = config.playerPins.stackTeamPins ~= false
        config.playerPins.fanOutTeamPinsOnHover = config.playerPins.fanOutTeamPinsOnHover ~= false
        config.playerPins.excludePlayerArrowFromStack = config.playerPins.excludePlayerArrowFromStack == true
        config.playerPins.showTeamSpecIcons = config.playerPins.showTeamSpecIcons ~= false
        if previousPlayerPinStyleVersion < 1 then
            config.playerPins.playerPinStyle = previousCustomPlayerArrow == false
                and "default" or "arrow"
        end
        config.playerPins.playerPinStyle = ({
            default = true,
            arrow = true,
            compass = true,
            team = true,
        })[config.playerPins.playerPinStyle] and config.playerPins.playerPinStyle or "arrow"
        local healerColor = type(config.playerPins.healerIconCustomColor) == "table"
            and config.playerPins.healerIconCustomColor or {}
        healerColor.r = BattleMaps.Clamp(tonumber(healerColor.r or healerColor[1]) or 1, 0, 1)
        healerColor.g = BattleMaps.Clamp(tonumber(healerColor.g or healerColor[2]) or 1, 0, 1)
        healerColor.b = BattleMaps.Clamp(tonumber(healerColor.b or healerColor[3]) or 1, 0, 1)
        config.playerPins.healerIconCustomColor = healerColor
        config.playerPins.healerIconColorMode = config.playerPins.healerIconColorMode == "class"
            and "class" or "custom"
        config.timers.objectiveTimerTextColorMode = config.timers.objectiveTimerTextColorMode == "class"
            and "class" or "custom"
        config.playerPins.playerRadiusSize = nil
        config.playerPins.teamPinStackRadius = BattleMaps.Clamp(
            math.floor((tonumber(config.playerPins.teamPinStackRadius) or BattleMapsDB.teamPinStackRadius or 18) + 0.5), 8, 40)
        config.playerPins.teamPinStackOverlap = BattleMaps.Clamp(
            math.floor((tonumber(config.playerPins.teamPinStackOverlap) or BattleMapsDB.teamPinStackOverlap or 30) + 0.5), 0, 80)
        config.playerPins.teamPinStackDirection = "compact"
        config.pins.combatTeamPinScale = config.playerPins.combatTeamPinScale
        config.pins.playerRadiusSize = nil
        BattleMapsDB.maps[info.id] = config
    end

    -- Correct the legacy AB configuration bucket if a modern C_Map collision
    -- previously initialized ID 112 with Eye of the Storm metadata.
    local arathiInfo = BattleMaps.GetArathiBasinInfo and BattleMaps.GetArathiBasinInfo() or nil
    if arathiInfo then
        if type(BattleMapsDB.maps[112]) == "table" then
            EnsureMapScopedSettings(BattleMapsDB.maps[112], BattleMapsDB)
        end
        local arathiConfig = CopyDefaults(NewMapDefaults(arathiInfo), BattleMapsDB.maps[112])
        EnsureMapScopedSettings(arathiConfig, BattleMapsDB)
        local normalizedName = tostring(arathiConfig.name or ""):lower():gsub("[%s%p%c]", "")
        if normalizedName:find("eyeofthestorm", 1, true) then
            arathiConfig.name = "Arathi Basin"
            arathiConfig.width = tonumber(arathiInfo.width) or 560
            arathiConfig.height = tonumber(arathiInfo.height) or 420
            arathiConfig.customZoom = 1
            arathiConfig.customPanX = 0.5
            arathiConfig.customPanY = 0.5
            arathiConfig.configured = false
        else
            arathiConfig.name = "Arathi Basin"
        end
        arathiConfig.width = BattleMaps.Clamp(tonumber(arathiConfig.width) or tonumber(arathiInfo.width) or 560, 240, 1000)
        arathiConfig.height = BattleMaps.Clamp(tonumber(arathiConfig.height) or tonumber(arathiInfo.height) or 420, 180, 800)
        MigrateLegacyPinBuckets(arathiConfig)
        arathiConfig.objectives.carriedTrailStyle = NormalizeCarriedTrailStyle(arathiConfig.objectives.carriedTrailStyle)
        BattleMapsDB.maps[112] = arathiConfig
    end

    -- Eye of the Storm uses modern UI map ID 112, but BattleMaps keeps it in
    -- configuration bucket 210 so it cannot collide with legacy Arathi Basin.
    local eyeInfo = BattleMaps.GetEyeOfTheStormInfo and BattleMaps.GetEyeOfTheStormInfo() or nil
    if eyeInfo then
        if type(BattleMapsDB.maps[210]) == "table" then
            EnsureMapScopedSettings(BattleMapsDB.maps[210], BattleMapsDB)
        end
        local eyeConfig = CopyDefaults(NewMapDefaults(eyeInfo), BattleMapsDB.maps[210])
        EnsureMapScopedSettings(eyeConfig, BattleMapsDB)
        eyeConfig.name = "Eye of the Storm"
        eyeConfig.width = BattleMaps.Clamp(tonumber(eyeConfig.width) or tonumber(eyeInfo.width) or 560, 240, 1000)
        eyeConfig.height = BattleMaps.Clamp(tonumber(eyeConfig.height) or tonumber(eyeInfo.height) or 420, 180, 800)
        eyeConfig.customZoom = BattleMaps.Clamp(tonumber(eyeConfig.customZoom) or 1, 1, 3)
        eyeConfig.customPanX = BattleMaps.Clamp(tonumber(eyeConfig.customPanX) or 0.5, 0, 1)
        eyeConfig.customPanY = BattleMaps.Clamp(tonumber(eyeConfig.customPanY) or 0.5, 0, 1)
        MigrateLegacyPinBuckets(eyeConfig)
        eyeConfig.objectives.carriedTrailStyle = NormalizeCarriedTrailStyle(eyeConfig.objectives.carriedTrailStyle)
        BattleMapsDB.maps[210] = eyeConfig
    end

    BattleMapsDB.customFrameVersion = 2
    self.db = BattleMapsDB
    return self.db
end

function Database:Get()
    return self.db or self:Initialize()
end

function Database:GetMapConfig(mapID)
    mapID = tonumber(mapID)
    local db = self:Get()
    local info = BattleMaps.GetBattlegroundInfoForConfig
        and BattleMaps.GetBattlegroundInfoForConfig(mapID)
        or BattleMaps.Battlegrounds:GetInfo(mapID)
    if not info then return nil end
    if type(db.maps[mapID]) == "table" then
        EnsureMapScopedSettings(db.maps[mapID], db)
    end
    db.maps[mapID] = CopyDefaults(NewMapDefaults(info), db.maps[mapID])
    EnsureMapScopedSettings(db.maps[mapID], db)
    MigrateLegacyPinBuckets(db.maps[mapID])
    if mapID == 112 then
        db.maps[mapID].name = "Arathi Basin"
    elseif mapID == 210 then
        db.maps[mapID].name = "Eye of the Storm"
    end
    return db.maps[mapID]
end

function Database:MapUsesGlobalPlayerPinSettings(mapID)
    local config = self:GetMapConfig(mapID)
    if not config then return true end
    EnsureMapScopedSettings(config, self:Get())
    return config.useGlobalPlayerPinSettings ~= false
end

function Database:SetMapUsesGlobalPlayerPinSettings(mapID, value)
    local config = self:GetMapConfig(mapID)
    if not config then return false end
    config.useGlobalPlayerPinSettings = value ~= false
    return true
end

function Database:GetPlayerPinConfig(mapID)
    local db = self:Get()
    local config = self:GetMapConfig(mapID)
    if config then
        EnsureMapScopedSettings(config, db)
        if config.useGlobalPlayerPinSettings ~= false then
            return db
        end
        MigrateLegacyPinBuckets(config)
        return config.playerPins or config.pins or db
    end
    return db
end

function Database:MapUsesGlobalObjectiveSettings(mapID)
    local config = self:GetMapConfig(mapID)
    if not config then return true end
    EnsureMapScopedSettings(config, self:Get())
    return config.useGlobalObjectiveSettings ~= false
end

function Database:SetMapUsesGlobalObjectiveSettings(mapID, value)
    local config = self:GetMapConfig(mapID)
    if not config then return false end
    config.useGlobalObjectiveSettings = value ~= false
    return true
end

function Database:GetObjectivePinConfig(mapID)
    local db = self:Get()
    local config = self:GetMapConfig(mapID)
    if config then
        EnsureMapScopedSettings(config, db)
        if config.useGlobalObjectiveSettings ~= false then
            return db
        end
        MigrateLegacyPinBuckets(config)
        config.objectives.carriedTrailStyle = NormalizeCarriedTrailStyle(config.objectives.carriedTrailStyle)
        return config.objectives or config.pins or db
    end
    return db
end

function Database:GetPinConfig(mapID)
    -- Legacy combined accessor. Prefer GetPlayerPinConfig or GetObjectivePinConfig.
    local db = self:Get()
    local config = self:GetMapConfig(mapID)
    if config then
        EnsureMapScopedSettings(config, db)
        if config.useGlobalPlayerPinSettings ~= false
            and config.useGlobalObjectiveSettings ~= false then
            return db
        end
        MigrateLegacyPinBuckets(config)
        return config.pins or db
    end
    return db
end

function Database:GetTimerConfig(mapID)
    local db = self:Get()
    if db.useGlobalTimerSettings ~= false then
        return db
    end
    local config = self:GetMapConfig(mapID)
    if config then
        MigrateLegacyPinBuckets(config)
        return config.timers or db
    end
    return db
end

-- Semantic accessors for the user-facing options taxonomy. These deliberately
-- preserve the existing SavedVariables buckets: Units use playerPins, Bases
-- use objectives + timers, and Flags use the carried-objective fields inside
-- objectives. Keep the legacy accessors below/above for older modules and saved
-- configurations.
function Database:GetUnitsConfig(mapID)
    return self:GetPlayerPinConfig(mapID)
end

function Database:GetBasePinConfig(mapID)
    return self:GetObjectivePinConfig(mapID)
end

function Database:GetBaseTimerConfig(mapID)
    return self:GetTimerConfig(mapID)
end

function Database:GetFlagConfig(mapID)
    return self:GetObjectivePinConfig(mapID)
end

function Database:GetNotificationConfig(mapID)
    local db = self:Get()
    if db.useGlobalNotificationSettings ~= false then
        return db.notifications
    end
    local config = self:GetMapConfig(mapID)
    if config then
        MigrateLegacyPinBuckets(config)
        return config.notifications or db.notifications
    end
    return db.notifications
end

local MAP_POSITION_KEYS = {
    "point",
    "relativePoint",
    "relativeTo",
    "offsetX",
    "offsetY",
}

local function PreserveMapScreenPosition(source, destination)
    if type(source) ~= "table" or type(destination) ~= "table" then return end
    for _, key in ipairs(MAP_POSITION_KEYS) do
        if source[key] ~= nil then destination[key] = source[key] end
    end
end

local function GetCategoryResetSource(mapID, categoryDefaults, profileKey, useGlobal)
    if useGlobal then return categoryDefaults end
    local info = BattleMaps.GetBattlegroundInfoForConfig
        and BattleMaps.GetBattlegroundInfoForConfig(mapID)
        or (BattleMaps.Battlegrounds and BattleMaps.Battlegrounds:GetInfo(mapID))
    local personal = GetPersonalMapDefaults(info or mapID)
    return personal and personal[profileKey] or categoryDefaults
end

function Database:ResetMapView(mapID)
    local info = BattleMaps.GetBattlegroundInfoForConfig
        and BattleMaps.GetBattlegroundInfoForConfig(mapID)
        or BattleMaps.Battlegrounds:GetInfo(mapID)
    local config = self:GetMapConfig(mapID)
    if not info or not config then return end

    local defaults = NewMapDefaults(info)
    config.width = defaults.width
    config.height = defaults.height
    config.customZoom = defaults.customZoom
    config.customPanX = defaults.customPanX
    config.customPanY = defaults.customPanY
    config.worldMapView = ResetDefaults(defaults.worldMapView, {})
    config.configured = defaults.configured
end

function Database:ResetWorldMapView(mapID)
    local config = self:GetMapConfig(mapID)
    if not config then return false end
    config.worldMapView = NewWorldMapViewDefaults()
    return true
end

function Database:ResetMapSettings(mapID)
    mapID = tonumber(mapID)
    if not mapID then return false end

    local db = self:Get()
    local info = BattleMaps.GetBattlegroundInfoForConfig
        and BattleMaps.GetBattlegroundInfoForConfig(mapID)
        or BattleMaps.Battlegrounds:GetInfo(mapID)
    if not info then return false end

    -- Restore the authored per-battleground profile while preserving the
    -- user's chosen screen anchor and offsets. Width/height, zoom, pan, pins,
    -- objectives, timers, and global/local category choices are reset.
    local previous = db.maps[mapID]
    local reset = NewMapDefaults(info)
    PreserveMapScreenPosition(previous, reset)
    db.maps[mapID] = reset
    EnsureMapScopedSettings(db.maps[mapID], db)
    if mapID == 112 then
        db.maps[mapID].name = "Arathi Basin"
    elseif mapID == 210 then
        db.maps[mapID].name = "Eye of the Storm"
    end

    return true
end

function Database:ResetPlayerPins(mapID)
    local config = self:GetMapConfig(mapID)
    local useGlobal = not config or config.useGlobalPlayerPinSettings ~= false
    local target = useGlobal and self:Get() or config.playerPins
    if not target then return end
    local source = GetCategoryResetSource(mapID, PLAYER_PIN_DEFAULTS, "playerPins", useGlobal)
    ResetDefaults(source, target)
    target.teamPinBorderScale = BattleMaps.Clamp(
        tonumber(source.teamPinBorderScale) or PLAYER_PIN_DEFAULTS.teamPinBorderScale,
        0.50,
        2.00
    )
    target.healerPinStyle = ({ circle = true, icon = true, ignore = true })[source.healerPinStyle]
        and source.healerPinStyle or PLAYER_PIN_DEFAULTS.healerPinStyle
    target.playerFovStyle = source.playerFovStyle or PLAYER_PIN_DEFAULTS.playerFovStyle
    target.playerFovScale = source.playerFovScale or PLAYER_PIN_DEFAULTS.playerFovScale
    target.playerFovAlpha = source.playerFovAlpha or PLAYER_PIN_DEFAULTS.playerFovAlpha
    target.playerFovBeamAlpha = source.playerFovBeamAlpha or PLAYER_PIN_DEFAULTS.playerFovBeamAlpha
    target.playerFovStyleVersion = 5
    target.showPlayerVisionCone = nil
    target.playerVisionConeScale = nil
    target.playerVisionConeAlpha = nil
    NormalizePlayerFovSettings(target)
end

function Database:ResetObjectives(mapID)
    local config = self:GetMapConfig(mapID)
    local useGlobal = not config or config.useGlobalObjectiveSettings ~= false
    local target = useGlobal and self:Get() or config.objectives
    if not target then return end
    local source = GetCategoryResetSource(mapID, OBJECTIVE_PIN_DEFAULTS, "objectives", useGlobal)
    ResetDefaults(source, target)
    target.carriedTrailStyle = NormalizeCarriedTrailStyle(target.carriedTrailStyle)
end

function Database:ResetTimers(mapID)
    local db = self:Get()
    local useGlobal = db.useGlobalTimerSettings ~= false
    local config = useGlobal and nil or self:GetMapConfig(mapID)
    local target = useGlobal and db or (config and config.timers)
    if not target then return end
    local source = GetCategoryResetSource(mapID, TIMER_DEFAULTS, "timers", useGlobal)
    ResetDefaults(source, target)
end

function Database:ResetUnits(mapID)
    return self:ResetPlayerPins(mapID)
end

function Database:ResetBasePins(mapID)
    local config = self:GetMapConfig(mapID)
    local useGlobal = not config or config.useGlobalObjectiveSettings ~= false
    local target = useGlobal and self:Get() or config.objectives
    if not target then return end
    local source = GetCategoryResetSource(mapID, OBJECTIVE_PIN_DEFAULTS, "objectives", useGlobal)
    target.objectivePinScale = source.objectivePinScale
    target.objectivePinAlpha = source.objectivePinAlpha
end

function Database:ResetCarts(mapID)
    local config = self:GetMapConfig(mapID)
    local useGlobal = not config or config.useGlobalObjectiveSettings ~= false
    local target = useGlobal and self:Get() or config.objectives
    if not target then return end
    local source = GetCategoryResetSource(mapID, OBJECTIVE_PIN_DEFAULTS, "objectives", useGlobal)
    target.vehicleObjectivePinScale = source.vehicleObjectivePinScale
end

function Database:ResetBaseTimers(mapID)
    return self:ResetTimers(mapID)
end

function Database:ResetFlags(mapID)
    local config = self:GetMapConfig(mapID)
    local useGlobal = not config or config.useGlobalObjectiveSettings ~= false
    local target = useGlobal and self:Get() or config.objectives
    if not target then return end
    local source = GetCategoryResetSource(mapID, OBJECTIVE_PIN_DEFAULTS, "objectives", useGlobal)
    target.carrierObjectivePinScale = source.carrierObjectivePinScale
    target.showFlagCarrierTrail = source.showFlagCarrierTrail
    target.carriedTrailStyle = NormalizeCarriedTrailStyle(source.carriedTrailStyle)
    target.carriedTrailDuration = source.carriedTrailDuration
    target.carriedTrailDotScale = source.carriedTrailDotScale
    target.carriedTrailDetail = source.carriedTrailDetail
    target.carriedObjectiveColorMode = NormalizeCarriedObjectiveColorMode(
        source.carriedObjectiveColorMode,
        source.kotmoguOrbColorMode,
        source.factionColorEnemyKotmoguOrbs
    )
    target.kotmoguOrbColorMode = nil
    target.factionColorEnemyKotmoguOrbs = nil
    target.flashCarriedObjectives = source.flashCarriedObjectives
    target.carriedObjectiveFlashPeriod = source.carriedObjectiveFlashPeriod
    target.carriedObjectiveFlashStrength = source.carriedObjectiveFlashStrength
end

function Database:ResetNotifications(mapID)
    local target = self:GetNotificationConfig(mapID)
    if not target then return end
    ResetDefaults(NOTIFICATION_DEFAULTS, target)
end

function Database:ResetPins(mapID)
    self:ResetPlayerPins(mapID)
    self:ResetObjectives(mapID)
end

function Database:GetObjectiveCaptureDuration(mapID, forceBlitz)
    if BattleMaps.GetObjectiveCaptureDuration then
        return BattleMaps.GetObjectiveCaptureDuration(mapID, forceBlitz)
    end

    local profile = BattleMaps.GetCaptureTimerProfile and BattleMaps.GetCaptureTimerProfile(mapID)
    if not profile then return nil end
    return BattleMaps.Clamp(tonumber(profile.defaultDuration) or 60, 1, 300)
end

function Database:GetObjectiveBlitzUncapDuration(mapID, forceBlitz)
    if BattleMaps.GetObjectiveBlitzUncapDuration then
        return BattleMaps.GetObjectiveBlitzUncapDuration(mapID, forceBlitz)
    end
    return nil
end

function Database:GetObjectiveBlitzRecapDuration(mapID, forceBlitz)
    if BattleMaps.GetObjectiveBlitzRecapDuration then
        return BattleMaps.GetObjectiveBlitzRecapDuration(mapID, forceBlitz)
    end
    return nil
end

-- Capture durations are defined in Core.lua for each supported battleground.
-- This compatibility method intentionally does not persist overrides.
function Database:SetObjectiveCaptureDuration(mapID, value)
    return false
end
