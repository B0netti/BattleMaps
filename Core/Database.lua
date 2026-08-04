local _, BattleMaps = ...

local Database = {}
BattleMaps.Database = Database

local PIN_DEFAULTS = {
    playerArrowSize = 33,
    teamMemberPinSize = 13,
    healerPinSize = 16.5,
    combatTeamPinScale = 1.00, -- retired setting retained at 1 for SavedVariables compatibility
    objectivePinScale = 2.10,
    objectivePinAlpha = 0.90,
    carrierObjectivePinScale = 0.75,
    vehicleObjectivePinScale = 0.70,
}

local PLAYER_PIN_DEFAULTS = {
    playerArrowSize = PIN_DEFAULTS.playerArrowSize,
    playerPinStyle = "arrow",
    playerFovStyle = "none",
    playerFovScale = 1.00,
    playerFovAlpha = 0.65,
    playerFovSpotlightAlpha = 1.00,
    playerFovBeamAlpha = 1.00,
    playerFovArcAlpha = 1.00,
    teamMemberPinSize = PIN_DEFAULTS.teamMemberPinSize,
    healerPinSize = PIN_DEFAULTS.healerPinSize,
    combatTeamPinScale = PIN_DEFAULTS.combatTeamPinScale,
    stackTeamPins = true,
    fanOutTeamPinsOnHover = true,
    excludePlayerArrowFromStack = false,
    teamPinStackRadius = 13, -- retained for SavedVariables compatibility; no longer user-configurable
    teamPinStackOverlap = 25,
    teamPinStackDirection = "compact",
    showTeamSpecIcons = true,
    healerIconColorMode = "custom",
    healerIconCustomColor = { r = 1.00, g = 1.00, b = 1.00 },
}

local OBJECTIVE_PIN_DEFAULTS = {
    objectivePinScale = PIN_DEFAULTS.objectivePinScale,
    objectivePinAlpha = PIN_DEFAULTS.objectivePinAlpha,
    carrierObjectivePinScale = PIN_DEFAULTS.carrierObjectivePinScale,
    vehicleObjectivePinScale = PIN_DEFAULTS.vehicleObjectivePinScale,
    showFlagCarrierTrail = true,
    carriedTrailStyle = "glow",
    carriedTrailDuration = 4.75,
    carriedTrailDotScale = 0.80,
    carriedTrailDetail = 16,
    factionColorEnemyKotmoguOrbs = true,
    flashCarriedObjectives = true,
    carriedObjectiveFlashPeriod = 1.00,
    carriedObjectiveFlashStrength = 0.75,
}

local TIMER_DEFAULTS = {
    showObjectivePulseAnimations = true,
    showObjectiveCaptureTimers = true,
    pulseObjectiveDuringCaptureTimer = true,
    flashObjectiveBeforeCapture = true,
    objectiveCaptureFlashThreshold = 10,
    objectiveCaptureFlashBrightness = 0.25,
    objectiveCapturePulseMinAlpha = 0.45,
    objectiveCapturePulseMaxAlpha = 0.75,
    objectiveCaptureAfterPulseAlpha = 0.36,
    showObjectiveTimerText = false,
    showObjectiveBlitzUncapText = true,
    objectiveTimerTextThreshold = 59,
    objectiveTimerTextSize = 16,
    objectiveTimerTextAlpha = 0.65,
    objectiveTimerTextOffsetX = 0,
    objectiveTimerTextOffsetY = 0,
    objectiveTimerTextFont = "Expressway",
    objectiveTimerTextColorMode = "custom",
    objectiveTimerTextColor = {
        r = 1.00,
        g = 0.988235354423523,
        b = 0.333333343267441,
    },
    objectiveCaptureFillDirection = "horizontal",
    objectiveCapturePulseCount = 3,
}
local NOTIFICATION_DEFAULTS = {
    enabled = true,
    useBlizzardOnWorldMap = true,
    colorByFaction = true,
    scale = 1.00,
    width = 520,
    justifyH = "CENTER",
    anchorMode = "INDEPENDENT",
    mapAnchorSide = "TOP",
    point = "TOP",
    relativePoint = "TOP",
    x = 0,
    y = -100,
    mapX = 0,
    mapY = 28,
    attachmentVersion = 2,
}

local ROOT_DEFAULTS = {
    enabled = true,
    autoShow = true,
    autoHide = true,
    enableWorldMapIntegration = true,
    worldMapPinScale = 1.00,
    applyZoom = true,
    applyFrameSize = true,
    showLoginMessage = true,
    debug = false,
    developerOptions = false,
    factionSwapAlert = true,
    factionColoredBorder = true, -- legacy alias; kept for older saved variables
    frameBorderSize = 3,
    frameBorderStrength = 1.00,
    frameBorderStyle = "solid",
    frameBackgroundColor = { r = 0.015, g = 0.015, b = 0.015, a = 0.12 },
    fadeMapHeader = true,
    mapTextureAlpha = 0.90,
    highlightFriendlyHealers = true,
    useCustomHealerIcon = true,
    useCustomTeamPinTextures = true,
    useSolidTeamPinOutOfCombat = true,
    showFlagCarrierTrail = true,
    carriedTrailStyle = OBJECTIVE_PIN_DEFAULTS.carriedTrailStyle,
    carriedTrailDuration = OBJECTIVE_PIN_DEFAULTS.carriedTrailDuration,
    carriedTrailDotScale = OBJECTIVE_PIN_DEFAULTS.carriedTrailDotScale,
    carriedTrailDetail = OBJECTIVE_PIN_DEFAULTS.carriedTrailDetail,
    factionColorEnemyKotmoguOrbs = OBJECTIVE_PIN_DEFAULTS.factionColorEnemyKotmoguOrbs,
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
    showObjectiveTimerText = false,
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
    elvuiBGLayoutEnabled = true,
    elvuiBGLayoutMovePlayerAuras = true,
    playerArrowColorMode = "class",
    playerArrowCustomColor = {
        r = 1.00,
        g = 0.996078491210938,
        b = 0.968627512454987,
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
    playerFovSpotlightAlpha = PLAYER_PIN_DEFAULTS.playerFovSpotlightAlpha,
    playerFovBeamAlpha = PLAYER_PIN_DEFAULTS.playerFovBeamAlpha,
    playerFovArcAlpha = PLAYER_PIN_DEFAULTS.playerFovArcAlpha,
    teamMemberPinSize = PIN_DEFAULTS.teamMemberPinSize,
    healerPinSize = PIN_DEFAULTS.healerPinSize,
    combatTeamPinScale = PIN_DEFAULTS.combatTeamPinScale,
    stackTeamPins = true,
    fanOutTeamPinsOnHover = true,
    excludePlayerArrowFromStack = false,
    teamPinStackRadius = PLAYER_PIN_DEFAULTS.teamPinStackRadius,
    teamPinStackOverlap = PLAYER_PIN_DEFAULTS.teamPinStackOverlap,
    teamPinStackDirection = "compact",
    showTeamSpecIcons = true,
    healerIconColorMode = PLAYER_PIN_DEFAULTS.healerIconColorMode,
    healerIconCustomColor = { r = 1.00, g = 1.00, b = 1.00 },
    objectivePinScale = PIN_DEFAULTS.objectivePinScale,
    objectivePinAlpha = PIN_DEFAULTS.objectivePinAlpha,
    carrierObjectivePinScale = PIN_DEFAULTS.carrierObjectivePinScale,
    vehicleObjectivePinScale = PIN_DEFAULTS.vehicleObjectivePinScale,
    notifications = {
        enabled = true,
        useBlizzardOnWorldMap = true,
        colorByFaction = true,
        scale = 1.00,
        width = 520,
        justifyH = "CENTER",
        anchorMode = "INDEPENDENT",
        mapAnchorSide = "TOP",
        point = "TOP",
        relativePoint = "TOP",
        x = 0,
        y = -100,
        mapX = 0,
        mapY = 28,
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
        width = 414.073974609375,
        height = 345.185180664062,
        configured = true,
        customZoom = 2.60869565217391,
        customPanX = 0.479416082159281,
        customPanY = 0.429533467756182,
        useGlobalPlayerPinSettings = false,
        useGlobalObjectiveSettings = false,
        playerPins = {
            playerArrowSize = 33,
            teamMemberPinSize = 12,
            healerPinSize = 15.5,
            combatTeamPinScale = 1,
            stackTeamPins = true,
            excludePlayerArrowFromStack = true,
            teamPinStackRadius = 15,
            teamPinStackOverlap = 25,
            teamPinStackDirection = "compact",
        },
        objectives = {
            objectivePinScale = 1.6,
            objectivePinAlpha = 1,
            carrierObjectivePinScale = 1,
            vehicleObjectivePinScale = 1,
            showFlagCarrierTrail = true,
            carriedTrailStyle = "breadcrumbs",
            carriedTrailDuration = 12,
            carriedTrailDotScale = 0.7,
            flashCarriedObjectives = true,
            carriedObjectiveFlashPeriod = 0.7,
            carriedObjectiveFlashStrength = 0.95,
        },
        timers = {
            showObjectivePulseAnimations = true,
            showObjectiveCaptureTimers = true,
            pulseObjectiveDuringCaptureTimer = true,
            flashObjectiveBeforeCapture = true,
            objectiveCaptureFlashThreshold = 10,
            objectiveCaptureFlashBrightness = 0.25,
            objectiveCapturePulseMinAlpha = 0.4,
            objectiveCapturePulseMaxAlpha = 0.6,
            objectiveCaptureAfterPulseAlpha = 0.36,
            showObjectiveTimerText = false,
            showObjectiveBlitzUncapText = true,
            objectiveTimerTextThreshold = 9,
            objectiveTimerTextSize = 16,
            objectiveTimerTextAlpha = 0.8,
            objectiveTimerTextOffsetX = 0,
            objectiveTimerTextOffsetY = 0,
            objectiveTimerTextFont = "Expressway",
            objectiveTimerTextColor = {
                r = 0.99215692281723,
                g = 1,
                b = 0.258823543787003,
            },
            objectiveCaptureFillDirection = "horizontal",
            objectiveCapturePulseCount = 3,
        },
    },
    [206] = {
        width = 270.814880371094,
        height = 452.740753173828,
        configured = true,
        customZoom = 3,
        customPanX = 0.524525871302152,
        customPanY = 0.493237019190261,
        useGlobalPlayerPinSettings = false,
        useGlobalObjectiveSettings = false,
        playerPins = {
            playerArrowSize = 22,
            teamMemberPinSize = 11,
            healerPinSize = 9.5,
            combatTeamPinScale = 1,
            stackTeamPins = true,
            excludePlayerArrowFromStack = false,
            teamPinStackRadius = 18,
            teamPinStackOverlap = 25,
            teamPinStackDirection = "compact",
        },
        objectives = {
            objectivePinScale = 1,
            objectivePinAlpha = 1,
            carrierObjectivePinScale = 0.8,
            vehicleObjectivePinScale = 1,
            showFlagCarrierTrail = true,
            carriedTrailStyle = "glow",
            carriedTrailDuration = 20,
            carriedTrailDotScale = 1.25,
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
            objectiveTimerTextColor = {
                r = 1,
                g = 1,
                b = 1,
            },
            objectiveCaptureFillDirection = "horizontal",
            objectiveCapturePulseCount = 1,
        },
    },
    [210] = {
        width = 386.221740722656,
        height = 304.888793945312,
        configured = true,
        customZoom = 3,
        customPanX = 0.479631734721611,
        customPanY = 0.5,
        useGlobalPlayerPinSettings = false,
        useGlobalObjectiveSettings = false,
        playerPins = {
            playerArrowSize = 28,
            teamMemberPinSize = 9,
            healerPinSize = 16,
            combatTeamPinScale = 1,
            stackTeamPins = true,
            excludePlayerArrowFromStack = true,
            teamPinStackRadius = 14,
            teamPinStackOverlap = 40,
            teamPinStackDirection = "compact",
        },
        objectives = {
            objectivePinScale = 1.4,
            objectivePinAlpha = 0.85,
            carrierObjectivePinScale = 0.95,
            vehicleObjectivePinScale = 1,
            showFlagCarrierTrail = true,
            carriedTrailStyle = "glow",
            carriedTrailDuration = 20,
            carriedTrailDotScale = 1.25,
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
            showObjectiveTimerText = false,
            showObjectiveBlitzUncapText = true,
            objectiveTimerTextThreshold = 9,
            objectiveTimerTextSize = 14,
            objectiveTimerTextAlpha = 1,
            objectiveTimerTextOffsetX = 0,
            objectiveTimerTextOffsetY = 0,
            objectiveTimerTextFont = "friz",
            objectiveTimerTextColor = {
                r = 1,
                g = 1,
                b = 1,
            },
            objectiveCaptureFillDirection = "vertical",
            objectiveCapturePulseCount = 1,
        },
    },
    [275] = {
        width = 416.740142822266,
        height = 350.518829345703,
        configured = true,
        customZoom = 2.60869565217391,
        customPanX = 0.496748880524483,
        customPanY = 0.575883986963143,
        useGlobalPlayerPinSettings = false,
        useGlobalObjectiveSettings = false,
        playerPins = {
            playerArrowSize = 22,
            teamMemberPinSize = 6,
            healerPinSize = 7,
            combatTeamPinScale = 1,
            stackTeamPins = true,
            excludePlayerArrowFromStack = false,
            teamPinStackRadius = 18,
            teamPinStackOverlap = 35,
            teamPinStackDirection = "compact",
        },
        objectives = {
            objectivePinScale = 1.45,
            objectivePinAlpha = 0.9,
            carrierObjectivePinScale = 1,
            vehicleObjectivePinScale = 1,
            showFlagCarrierTrail = true,
            carriedTrailStyle = "breadcrumbs",
            carriedTrailDuration = 10,
            carriedTrailDotScale = 0.7,
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
            objectiveTimerTextColor = {
                r = 1,
                g = 1,
                b = 1,
            },
            objectiveCaptureFillDirection = "horizontal",
            objectiveCapturePulseCount = 1,
        },
    },
    [417] = {
        width = 414.963897705078,
        height = 284.148620605469,
        configured = true,
        customZoom = 1.97254869729596,
        customPanX = 0.489605127946207,
        customPanY = 0.534447066394035,
        useGlobalPlayerPinSettings = false,
        useGlobalObjectiveSettings = false,
        playerPins = {
            playerArrowSize = 45,
            teamMemberPinSize = 13,
            healerPinSize = 14,
            combatTeamPinScale = 1,
            stackTeamPins = true,
            excludePlayerArrowFromStack = true,
            teamPinStackRadius = 40,
            teamPinStackOverlap = 25,
            teamPinStackDirection = "compact",
        },
        objectives = {
            objectivePinScale = 0.95,
            objectivePinAlpha = 0.65,
            carrierObjectivePinScale = 0.8,
            vehicleObjectivePinScale = 1,
            showFlagCarrierTrail = true,
            carriedTrailStyle = "glow",
            carriedTrailDuration = 20,
            carriedTrailDotScale = 1.25,
            carriedTrailDetail = 16,
            factionColorEnemyKotmoguOrbs = true,
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
            objectiveTimerTextColor = {
                r = 1,
                g = 1,
                b = 1,
            },
            objectiveCaptureFillDirection = "horizontal",
            objectiveCapturePulseCount = 1,
        },
    },
    [423] = {
        width = 372.296203613281,
        height = 301.925842285156,
        configured = true,
        customZoom = 1.49153020589487,
        customPanX = 0.455047219942502,
        customPanY = 0.522967005510735,
        useGlobalPlayerPinSettings = false,
        useGlobalObjectiveSettings = true,
        playerPins = {
            playerArrowSize = 22,
            teamMemberPinSize = 12,
            healerPinSize = 16,
            combatTeamPinScale = 1,
            stackTeamPins = true,
            excludePlayerArrowFromStack = false,
            teamPinStackRadius = 18,
            teamPinStackOverlap = 10,
            teamPinStackDirection = "compact",
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
            objectiveTimerTextColor = {
                r = 1,
                g = 1,
                b = 1,
            },
            objectiveCaptureFillDirection = "horizontal",
            objectiveCapturePulseCount = 1,
        },
    },
    [907] = {
        width = 365.630310058594,
        height = 345.407379150391,
        configured = true,
        customZoom = 1.97254869729596,
        customPanX = 0.435774532159024,
        customPanY = 0.482548887169603,
        useGlobalPlayerPinSettings = true,
        useGlobalObjectiveSettings = false,
        playerPins = {
            playerArrowSize = 34,
            teamMemberPinSize = 13,
            healerPinSize = 15,
            combatTeamPinScale = 1,
            stackTeamPins = true,
            excludePlayerArrowFromStack = true,
            teamPinStackRadius = 22,
            teamPinStackOverlap = 40,
            teamPinStackDirection = "compact",
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
            objectiveTimerTextColor = {
                r = 1,
                g = 1,
                b = 1,
            },
            objectiveCaptureFillDirection = "horizontal",
            objectiveCapturePulseCount = 1,
        },
    },
    [1339] = {
        width = 249.481552124023,
        height = 431.407867431641,
        configured = true,
        customZoom = 3,
        customPanX = 0.5161875840712,
        customPanY = 0.522830520067089,
        useGlobalPlayerPinSettings = false,
        useGlobalObjectiveSettings = false,
        playerPins = {
            playerArrowSize = 28,
            teamMemberPinSize = 10,
            healerPinSize = 14.5,
            combatTeamPinScale = 1,
            stackTeamPins = true,
            excludePlayerArrowFromStack = true,
            teamPinStackRadius = 18,
            teamPinStackOverlap = 25,
            teamPinStackDirection = "compact",
        },
        objectives = {
            objectivePinScale = 1,
            objectivePinAlpha = 1,
            carrierObjectivePinScale = 1.3,
            vehicleObjectivePinScale = 1,
            showFlagCarrierTrail = true,
            carriedTrailStyle = "glow",
            carriedTrailDuration = 15.25,
            carriedTrailDotScale = 2.9,
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
            objectiveTimerTextColor = {
                r = 1,
                g = 1,
                b = 1,
            },
            objectiveCaptureFillDirection = "horizontal",
            objectiveCapturePulseCount = 1,
        },
    },
    [1576] = {
        width = 415.555877685547,
        height = 396.740966796875,
        configured = true,
        customZoom = 1.520875,
        customPanX = 0.527886807550305,
        customPanY = 0.509285156039878,
        useGlobalPlayerPinSettings = false,
        useGlobalObjectiveSettings = true,
        playerPins = {
            playerArrowSize = 31,
            teamMemberPinSize = 12,
            healerPinSize = 18.5,
            combatTeamPinScale = 1,
            stackTeamPins = true,
            excludePlayerArrowFromStack = false,
            teamPinStackRadius = 36,
            teamPinStackOverlap = 25,
            teamPinStackDirection = "compact",
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
            objectiveTimerTextColor = {
                r = 1,
                g = 1,
                b = 1,
            },
            objectiveCaptureFillDirection = "horizontal",
            objectiveCapturePulseCount = 1,
        },
    },
    [2345] = {
        width = 464.334106445312,
        height = 298.333282470703,
        configured = true,
        customZoom = 1.520875,
        customPanX = 0.5,
        customPanY = 0.5,
        useGlobalPlayerPinSettings = false,
        useGlobalObjectiveSettings = true,
        playerPins = {
            playerArrowSize = 41,
            teamMemberPinSize = 15,
            healerPinSize = 12,
            combatTeamPinScale = 1,
            stackTeamPins = true,
            excludePlayerArrowFromStack = true,
            teamPinStackRadius = 15,
            teamPinStackOverlap = 20,
            teamPinStackDirection = "compact",
        },
        objectives = {
            objectivePinScale = 1.75,
            objectivePinAlpha = 1,
            carrierObjectivePinScale = 1,
            vehicleObjectivePinScale = 1,
            showFlagCarrierTrail = true,
            carriedTrailStyle = "breadcrumbs",
            carriedTrailDuration = 10,
            carriedTrailDotScale = 0.7,
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
            objectiveTimerTextColor = {
                r = 1,
                g = 1,
                b = 1,
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

    -- Migrate the retired checkbox once. An enabled cone becomes the Soft FoV
    -- style; disabled or absent cones become None. Scale and alpha retain the
    -- user's previous values under their new FoV setting names.
    local hasLegacySettings = settings.showPlayerVisionCone ~= nil
        or settings.playerVisionConeScale ~= nil
        or settings.playerVisionConeAlpha ~= nil
    if settings.playerFovStyleVersion ~= 1 and hasLegacySettings then
        settings.playerFovStyle = settings.showPlayerVisionCone == true and "soft" or "none"
        settings.playerFovScale = tonumber(settings.playerVisionConeScale)
            or tonumber(settings.playerFovScale)
            or PLAYER_PIN_DEFAULTS.playerFovScale
        settings.playerFovAlpha = tonumber(settings.playerVisionConeAlpha)
            or tonumber(settings.playerFovAlpha)
            or PLAYER_PIN_DEFAULTS.playerFovAlpha
    end

    settings.playerFovStyle = ({ none = true, soft = true, waves = true, spotlight = true })[settings.playerFovStyle]
        and settings.playerFovStyle or PLAYER_PIN_DEFAULTS.playerFovStyle
    settings.playerFovScale = BattleMaps.Clamp(
        tonumber(settings.playerFovScale) or PLAYER_PIN_DEFAULTS.playerFovScale,
        0.25,
        3.00
    )
    settings.playerFovAlpha = BattleMaps.Clamp(
        tonumber(settings.playerFovAlpha) or PLAYER_PIN_DEFAULTS.playerFovAlpha,
        0.10,
        1.00
    )
    settings.playerFovSpotlightAlpha = BattleMaps.Clamp(
        tonumber(settings.playerFovSpotlightAlpha) or PLAYER_PIN_DEFAULTS.playerFovSpotlightAlpha,
        0.00,
        1.00
    )
    settings.playerFovBeamAlpha = BattleMaps.Clamp(
        tonumber(settings.playerFovBeamAlpha) or PLAYER_PIN_DEFAULTS.playerFovBeamAlpha,
        0.00,
        1.00
    )
    settings.playerFovArcAlpha = BattleMaps.Clamp(
        tonumber(settings.playerFovArcAlpha) or PLAYER_PIN_DEFAULTS.playerFovArcAlpha,
        0.00,
        1.00
    )
    settings.playerFovStyleVersion = 1
    settings.showPlayerVisionCone = nil
    settings.playerVisionConeScale = nil
    settings.playerVisionConeAlpha = nil
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
    config.objectives = CopyDefaults(OBJECTIVE_PIN_DEFAULTS, config.objectives)
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

    BattleMapsDB = CopyDefaults(ROOT_DEFAULTS, BattleMapsDB)
    BattleMapsDB.maps = BattleMapsDB.maps or {}

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
    BattleMapsDB.factionColorEnemyKotmoguOrbs = BattleMapsDB.factionColorEnemyKotmoguOrbs ~= false
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
    BattleMapsDB.elvuiBGLayoutEnabled = BattleMapsDB.elvuiBGLayoutEnabled == true
    BattleMapsDB.elvuiBGLayoutMovePlayerAuras = BattleMapsDB.elvuiBGLayoutMovePlayerAuras == true
    BattleMapsDB.stackTeamPins = BattleMapsDB.stackTeamPins ~= false
    BattleMapsDB.excludePlayerArrowFromStack = BattleMapsDB.excludePlayerArrowFromStack == true
    BattleMapsDB.fanOutTeamPinsOnHover = BattleMapsDB.fanOutTeamPinsOnHover ~= false
    BattleMapsDB.showTeamSpecIcons = BattleMapsDB.showTeamSpecIcons ~= false
    BattleMapsDB.teamPinStackRadius = BattleMaps.Clamp(
        math.floor((tonumber(BattleMapsDB.teamPinStackRadius) or 18) + 0.5), 8, 40)
    BattleMapsDB.teamPinStackOverlap = BattleMaps.Clamp(
        math.floor((tonumber(BattleMapsDB.teamPinStackOverlap) or 45) + 0.5), 0, 80)
    BattleMapsDB.teamPinStackDirection = ({ compact = true, diagonal = true, horizontal = true, vertical = true })[BattleMapsDB.teamPinStackDirection]
        and BattleMapsDB.teamPinStackDirection or "compact"

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
        config.objectives.factionColorEnemyKotmoguOrbs = config.objectives.factionColorEnemyKotmoguOrbs ~= false
        config.playerPins.combatTeamPinScale = 1
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
            math.floor((tonumber(config.playerPins.teamPinStackOverlap) or BattleMapsDB.teamPinStackOverlap or 45) + 0.5), 0, 80)
        config.playerPins.teamPinStackDirection = ({ compact = true, diagonal = true, horizontal = true, vertical = true })[config.playerPins.teamPinStackDirection]
            and config.playerPins.teamPinStackDirection or BattleMapsDB.teamPinStackDirection or "compact"
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
    target.playerFovStyle = source.playerFovStyle or PLAYER_PIN_DEFAULTS.playerFovStyle
    target.playerFovScale = source.playerFovScale or PLAYER_PIN_DEFAULTS.playerFovScale
    target.playerFovAlpha = source.playerFovAlpha or PLAYER_PIN_DEFAULTS.playerFovAlpha
    target.playerFovSpotlightAlpha = source.playerFovSpotlightAlpha
        or PLAYER_PIN_DEFAULTS.playerFovSpotlightAlpha
    target.playerFovBeamAlpha = source.playerFovBeamAlpha or PLAYER_PIN_DEFAULTS.playerFovBeamAlpha
    target.playerFovArcAlpha = source.playerFovArcAlpha or PLAYER_PIN_DEFAULTS.playerFovArcAlpha
    target.playerFovStyleVersion = 1
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
    target.factionColorEnemyKotmoguOrbs = source.factionColorEnemyKotmoguOrbs
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
