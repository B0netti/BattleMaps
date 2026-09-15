local addonName, BattleMaps = ...
BattleMaps = BattleMaps or _G.BattleMaps
if not BattleMaps then return end

local Callouts = {
    initialized = false,
    nodeUIs = {},
    scanAccumulator = 0,
    choiceAccumulator = 0,
    hoveredUI = nil,
    currentMode = nil,
    pendingSecureRefresh = false,
}
BattleMaps.Callouts = Callouts

-- Keep runtime version/build in sync with the package metadata without needing
-- a second version constant in Core.lua.
local function ReadAddonVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, version = pcall(C_AddOns.GetAddOnMetadata, addonName, "Version")
        if ok and version and version ~= "" then return tostring(version) end
    elseif GetAddOnMetadata then
        local ok, version = pcall(GetAddOnMetadata, addonName, "Version")
        if ok and version and version ~= "" then return tostring(version) end
    end
    return nil
end

local packageVersion = ReadAddonVersion()
if packageVersion then BattleMaps.VERSION = packageVersion end
-- Published builds use the package version directly. Feature-specific build
-- suffixes are reserved for internal/test packages and should not leak into
-- release login/version reporting.
BattleMaps.BUILD = tostring(BattleMaps.VERSION or packageVersion or "3.1.0")

Callouts.DEFAULTS = {
    enabled = true,
    iconScale = 1.00,
    iconOffsetX = 0,
    iconOffsetY = 0,
    layoutVersion = 2,
    bindingVersion = 2,
    macroVersion = 1,
    contextVersion = 1,
    dragContextEnabled = true,
    -- Legacy message templates are retained only so pre-3.0.29 profiles can
    -- be migrated losslessly into full secure macro templates.
    messages = {
        incoming = "INC [node]",
        attack = "ATTACK [node]",
        defend = "DEF [node_full]",
        clear = "[node] CLEAR",
        custom1 = "CUSTOM [node]",
        custom2 = "CUSTOM [node_full]",
    },
    macros = {
        incoming = "/instance INC [node]",
        attack = "/instance ATTACK [node]",
        defend = "/instance DEF [node_full]",
        clear = "/instance [node] CLEAR",
        custom1 = "/instance CUSTOM [node]",
        custom2 = "/instance CUSTOM [node_full]",
    },
    bindings = {
        incoming = "BUTTON1",
        attack = "ALT-BUTTON1",
        defend = "SHIFT-BUTTON1",
        clear = "BUTTON2",
        custom1 = "ALT-SHIFT-BUTTON1",
        custom2 = "ALT-CTRL-BUTTON1",
    },
    -- Edge-drag context is stored per callout so the same directional swipe
    -- can mean something different for Incoming, Attack, Defend, etc.
    contexts = {
        incoming = { TOP = "stealth", RIGHT = "2", BOTTOM = "1", LEFT = "3" },
        attack   = { TOP = "stealth", RIGHT = "2", BOTTOM = "1", LEFT = "3" },
        defend   = { TOP = "stealth", RIGHT = "2", BOTTOM = "1", LEFT = "3" },
        clear    = { TOP = "stealth", RIGHT = "2", BOTTOM = "1", LEFT = "3" },
        custom1  = { TOP = "stealth", RIGHT = "2", BOTTOM = "1", LEFT = "3" },
        custom2  = { TOP = "stealth", RIGHT = "2", BOTTOM = "1", LEFT = "3" },
    },
}

Callouts.ACTION_ORDER = { "incoming", "attack", "defend", "clear", "custom1", "custom2" }
Callouts.ACTION_LABELS = {
    incoming = "Incoming",
    attack = "Attack",
    defend = "Defend",
    clear = "Clear",
    custom1 = "Custom 1",
    custom2 = "Custom 2",
}
Callouts.ACTION_TEXTURES = {
    incoming = "Interface\\AddOns\\BattleMaps\\Media\\Callouts\\INC.tga",
    attack = "Interface\\AddOns\\BattleMaps\\Media\\Callouts\\ATTACK.tga",
    defend = "Interface\\AddOns\\BattleMaps\\Media\\Callouts\\DEFEND.tga",
    clear = "Interface\\AddOns\\BattleMaps\\Media\\Callouts\\CLEAR.tga",
    custom1 = "Interface\\Icons\\INV_Misc_Note_01",
    custom2 = "Interface\\Icons\\INV_Misc_Note_02",
}

-- Temporary compatibility paths while existing prototype media is moved into
-- Media/Callouts. The production path above is always preferred.
local LEGACY_TEXTURE_CANDIDATES = {
    attack = { "ATTACK.tga", "callout_attack.tga", "attack.tga", "ping_attack.tga", "icon_attack.tga" },
    defend = { "DEFEND.tga", "callout_defend.tga", "defend.tga", "defense.tga", "ping_defend.tga", "icon_defend.tga" },
    incoming = { "INC.tga", "callout_incoming.tga", "incoming.tga", "inc.tga", "ping_incoming.tga", "icon_incoming.tga" },
    clear = { "CLEAR.tga", "callout_clear.tga", "clear.tga", "ping_clear.tga", "icon_clear.tga" },
}
local LEGACY_ROOT = "Interface\\AddOns\\BattleMaps\\Media\\"
local FALLBACK_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark"

local PRESS_SCALE = 0.82
local RELEASE_SCALE_FROM = 1.10
local RELEASE_SETTLE_DURATION = 0.10
local CONFIRM_HOLD_DURATION = 0.14
local CONFIRM_FADE_DURATION = 0.46
local GLOW_FADE_DURATION = 0.52
local PING_FLIPBOOK_DURATION = 0.75
local CONFIRM_PRESENTATION_DURATION = math.max(
    CONFIRM_HOLD_DURATION + CONFIRM_FADE_DURATION,
    GLOW_FADE_DURATION,
    PING_FLIPBOOK_DURATION
)
local PING_FLIPBOOK_SCALE = 2.10
local PING_FLIPBOOK_ATLAS = "UI-HUD-ActionBar-GCD-Flipbook"
local PING_FLIPBOOK_ROWS = 11
local PING_FLIPBOOK_COLUMNS = 2
local PING_FLIPBOOK_FRAMES = 22
local CHOICE_ICON_MIN_SIZE = 1
local HOVER_ICON_HALF_SEPARATION = 0.54
local HOVER_MOUSE_BUTTONS = { "LeftButton", "RightButton" }
local DRAG_CONTEXTS = {
    BASE = { key = "BASE", text = "", label = "" },
    TOP = { key = "TOP", text = "stealth", label = "STEALTH" },
    RIGHT = { key = "RIGHT", text = "2", label = "2" },
    BOTTOM = { key = "BOTTOM", text = "1", label = "1" },
    LEFT = { key = "LEFT", text = "3", label = "3" },
}
local DRAG_CONTEXT_ORDER = { "BASE", "TOP", "RIGHT", "BOTTOM", "LEFT" }
local DRAG_CONTEXT_MIN_TRAVEL_FRACTION = 0.08
local DRAG_CONTEXT_EDGE_PIXELS = 1
local DRAG_CONTEXT_GLOW_DEPTH = 14

local ACTION_GLOW_COLORS = {
    incoming = { 1.00, 0.28, 0.10 },
    attack = { 1.00, 0.18, 0.10 },
    defend = { 0.25, 0.62, 1.00 },
    clear = { 0.30, 1.00, 0.42 },
    custom1 = { 1.00, 0.70, 0.18 },
    custom2 = { 0.72, 0.42, 1.00 },
}

local MAPS = {
    {
        key = "ab",
        display = "Arathi Basin",
        mapIDs = { 112, 1366 },
        nodes = {
            { key = "ab_farm", display = "Farm", chat = "FARM", aliases = { "farm" } },
            { key = "ab_stables", display = "Stables", chat = "STABLES", aliases = { "stables", "stab" } },
            { key = "ab_blacksmith", display = "Blacksmith", chat = "BS", aliases = { "blacksmith", "black smith", "bs" } },
            { key = "ab_lumbermill", display = "Lumber Mill", chat = "LM", aliases = { "lumbermill", "lumber mill", "lm" } },
            { key = "ab_goldmine", display = "Gold Mine", chat = "GM", aliases = { "goldmine", "gold mine", "gm" } },
        },
    },
    {
        key = "bfg",
        display = "Battle for Gilneas",
        mapIDs = { 275, 761 },
        nodes = {
            { key = "bfg_waterworks", display = "Waterworks", chat = "WW", aliases = { "waterworks", "water works", "ww" } },
            { key = "bfg_mine", display = "Mine", chat = "MINE", aliases = { "mine" } },
            { key = "bfg_lighthouse", display = "Lighthouse", chat = "LH", aliases = { "lighthouse", "light house", "lh" } },
        },
    },
    {
        key = "eots",
        display = "Eye of the Storm",
        mapIDs = { 210 },
        nodes = {
            { key = "eots_felreaver", display = "Fel Reaver Ruins", chat = "FRR", aliases = { "felreaverruins", "fel reaver ruins", "felreaver", "fel reaver", "frr" } },
            { key = "eots_draenei", display = "Draenei Ruins", chat = "DR", aliases = { "draeneiruins", "draenei ruins", "draenei", "dr" } },
            { key = "eots_bloodelf", display = "Blood Elf Tower", chat = "BET", aliases = { "bloodelftower", "blood elf tower", "blood elf", "bet" } },
            { key = "eots_magetower", display = "Mage Tower", chat = "MT", aliases = { "magetower", "mage tower", "mt" } },
        },
    },
    {
        key = "dwg",
        display = "Deepwind Gorge",
        mapIDs = { 1576 },
        nodes = {
            { key = "dwg_market", display = "Market", chat = "MARKET", aliases = { "market" } },
            { key = "dwg_quarry", display = "Quarry", chat = "QUARRY", aliases = { "quarry" } },
            { key = "dwg_ruins", display = "Ruins", chat = "RUINS", aliases = { "ruins" } },
            { key = "dwg_shrine", display = "Shrine", chat = "SHRINE", aliases = { "shrine" } },
            { key = "dwg_farm", display = "Farm", chat = "FARM", aliases = { "farm" } },
        },
    },
}

local MAP_ID_TO_KEY = {}
local NODE_ORDER = {}
local NODE_DEFS = {}
for _, map in ipairs(MAPS) do
    for _, mapID in ipairs(map.mapIDs or {}) do
        MAP_ID_TO_KEY[tonumber(mapID)] = map.key
    end
    for _, node in ipairs(map.nodes or {}) do
        node.mapKey = map.key
        node.mapDisplay = map.display
        NODE_ORDER[#NODE_ORDER + 1] = node.key
        NODE_DEFS[node.key] = node
    end
end

local MODE_ORDER = { "NONE", "ALT", "SHIFT", "CTRL", "ALT_SHIFT", "ALT_CTRL", "CTRL_SHIFT", "ALT_CTRL_SHIFT" }
local MODE_BINDING_LABELS = {
    NONE = "",
    ALT = "Alt",
    SHIFT = "Shift",
    CTRL = "Ctrl",
    ALT_SHIFT = "Alt + Shift",
    ALT_CTRL = "Alt + Ctrl",
    CTRL_SHIFT = "Ctrl + Shift",
    ALT_CTRL_SHIFT = "Alt + Ctrl + Shift",
}
local MODE_SECURE_PREFIX = {
    NONE = "",
    ALT = "alt-",
    SHIFT = "shift-",
    CTRL = "ctrl-",
    ALT_SHIFT = "alt-shift-",
    ALT_CTRL = "alt-ctrl-",
    CTRL_SHIFT = "ctrl-shift-",
    ALT_CTRL_SHIFT = "alt-ctrl-shift-",
}
local LEGACY_MODE_BINDINGS = {
    NONE = "BUTTON1",
    ALT = "ALT-BUTTON1",
    SHIFT = "SHIFT-BUTTON1",
    CTRL = "CTRL-BUTTON1",
    ALT_SHIFT = "ALT-SHIFT-BUTTON1",
    ALT_CTRL = "ALT-CTRL-BUTTON1",
    CTRL_SHIFT = "CTRL-SHIFT-BUTTON1",
    ALT_CTRL_SHIFT = "ALT-CTRL-SHIFT-BUTTON1",
}
local MOUSE_BUTTON_INFO = {
    LeftButton = { token = "BUTTON1", suffix = "1", label = "Left Click", short = "LMB" },
    RightButton = { token = "BUTTON2", suffix = "2", label = "Right Click", short = "RMB" },
    MiddleButton = { token = "BUTTON3", suffix = "3", label = "Middle Click", short = "MMB" },
}
local MOUSE_TOKEN_INFO = {
    BUTTON1 = { mouseButton = "LeftButton", suffix = "1", label = "Left Click", short = "LMB" },
    BUTTON2 = { mouseButton = "RightButton", suffix = "2", label = "Right Click", short = "RMB" },
    BUTTON3 = { mouseButton = "MiddleButton", suffix = "3", label = "Middle Click", short = "MMB" },
}
local MODIFIER_ORDER = { "ALT", "CTRL", "SHIFT" }

local function ModifierModeFromFlags(alt, ctrl, shift)
    if alt and ctrl and shift then return "ALT_CTRL_SHIFT" end
    if alt and shift and not ctrl then return "ALT_SHIFT" end
    if alt and ctrl and not shift then return "ALT_CTRL" end
    if ctrl and shift and not alt then return "CTRL_SHIFT" end
    if alt and not shift and not ctrl then return "ALT" end
    if shift and not alt and not ctrl then return "SHIFT" end
    if ctrl and not alt and not shift then return "CTRL" end
    return "NONE"
end

function Callouts:NormalizeBinding(binding)
    if binding == nil then return nil end
    binding = tostring(binding):upper():gsub("_", "-"):gsub("%s+", "")
    if binding == "" or binding == "UNBOUND" or binding == "NONE-BOUND" then return "UNBOUND" end

    local legacy = LEGACY_MODE_BINDINGS[binding:gsub("-", "_")]
    if legacy then return legacy end

    local flags = { ALT = false, CTRL = false, SHIFT = false }
    local mouseToken
    for token in binding:gmatch("[^%-]+") do
        if flags[token] ~= nil then
            flags[token] = true
        elseif MOUSE_TOKEN_INFO[token] then
            if mouseToken then return nil end
            mouseToken = token
        elseif token ~= "CLICK" then
            return nil
        end
    end
    if not mouseToken then return nil end

    local parts = {}
    for _, modifier in ipairs(MODIFIER_ORDER) do
        if flags[modifier] then parts[#parts + 1] = modifier end
    end
    parts[#parts + 1] = mouseToken
    return table.concat(parts, "-")
end

function Callouts:GetBindingParts(binding)
    binding = self:NormalizeBinding(binding)
    if not binding or binding == "UNBOUND" then
        return { binding = "UNBOUND", modifiers = {}, mouseToken = nil, mode = "NONE" }
    end

    local flags = { ALT = false, CTRL = false, SHIFT = false }
    local modifiers, mouseToken = {}, nil
    for token in binding:gmatch("[^%-]+") do
        if flags[token] ~= nil then
            flags[token] = true
            modifiers[#modifiers + 1] = token
        elseif MOUSE_TOKEN_INFO[token] then
            mouseToken = token
        end
    end
    return {
        binding = binding,
        modifiers = modifiers,
        mouseToken = mouseToken,
        mouse = MOUSE_TOKEN_INFO[mouseToken],
        mode = ModifierModeFromFlags(flags.ALT, flags.CTRL, flags.SHIFT),
    }
end

function Callouts:GetBindingFromMouseButton(mouseButton)
    local mouse = MOUSE_BUTTON_INFO[mouseButton]
    if not mouse then return nil end
    local parts = {}
    if IsAltKeyDown and IsAltKeyDown() == true then parts[#parts + 1] = "ALT" end
    if IsControlKeyDown and IsControlKeyDown() == true then parts[#parts + 1] = "CTRL" end
    if IsShiftKeyDown and IsShiftKeyDown() == true then parts[#parts + 1] = "SHIFT" end
    parts[#parts + 1] = mouse.token
    return table.concat(parts, "-")
end

function Callouts:GetActionBinding(actionKey)
    local settings = self:GetSettings()
    return self:NormalizeBinding(settings.bindings and settings.bindings[actionKey])
        or self.DEFAULTS.bindings[actionKey]
end

function Callouts:GetBindingLabel(binding)
    local parts = self:GetBindingParts(binding)
    if not parts.mouse then return "Unbound" end
    local labels = {}
    for _, modifier in ipairs(parts.modifiers) do
        labels[#labels + 1] = MODE_BINDING_LABELS[modifier] or modifier
    end
    labels[#labels + 1] = parts.mouse.label
    return table.concat(labels, " + ")
end

function Callouts:GetActionBindingLabel(actionKey)
    return self:GetBindingLabel(self:GetActionBinding(actionKey))
end

function Callouts:GetActionForBinding(binding)
    binding = self:NormalizeBinding(binding)
    if not binding or binding == "UNBOUND" then return nil end
    local settings = self:GetSettings()
    for _, actionKey in ipairs(self.ACTION_ORDER) do
        if self:NormalizeBinding(settings.bindings and settings.bindings[actionKey]) == binding then
            return actionKey
        end
    end
    return nil
end

function Callouts:GetActionForMode(mode)
    return self:GetActionForBinding(LEGACY_MODE_BINDINGS[mode or "NONE"])
end

function Callouts:GetBindingForModeAndMouseButton(mode, mouseButton)
    local mouse = MOUSE_BUTTON_INFO[mouseButton]
    if not mouse then return nil end
    mode = mode or "NONE"
    local modifierPrefix = mode ~= "NONE" and (mode:gsub("_", "-") .. "-") or ""
    return modifierPrefix .. mouse.token
end

function Callouts:GetActionForModeAndMouseButton(mode, mouseButton)
    return self:GetActionForBinding(self:GetBindingForModeAndMouseButton(mode, mouseButton))
end

function Callouts:GetActionForMouseButton(mouseButton)
    return self:GetActionForBinding(self:GetBindingFromMouseButton(mouseButton))
end

function Callouts:IsSupportedMouseButton(mouseButton)
    return MOUSE_BUTTON_INFO[mouseButton] ~= nil
end

function Callouts:GetBindingConflict(actionKey, binding)
    binding = self:NormalizeBinding(binding)
    if not binding or binding == "UNBOUND" then return nil end
    local settings = self:GetSettings()
    for _, otherKey in ipairs(self.ACTION_ORDER) do
        if otherKey ~= actionKey
            and self:NormalizeBinding(settings.bindings and settings.bindings[otherKey]) == binding then
            return otherKey
        end
    end
    return nil
end

function Callouts:SetActionBinding(actionKey, binding, replaceExisting)
    if not self.DEFAULTS.bindings[actionKey] then return false, nil end
    if InCombatLockdown and InCombatLockdown() then
        if BattleMaps.Chat then BattleMaps.Chat("Callout bindings can only be changed out of combat.") end
        return false, nil
    end

    binding = self:NormalizeBinding(binding)
    if not binding then return false, nil end
    local settings = self:GetSettings()
    settings.bindings = type(settings.bindings) == "table" and settings.bindings or {}

    local conflict = self:GetBindingConflict(actionKey, binding)
    if conflict and replaceExisting ~= true then return false, conflict end
    if conflict then settings.bindings[conflict] = "UNBOUND" end
    settings.bindings[actionKey] = binding
    settings.bindingVersion = 2
    self:RequestSecureRefresh()
    return true, conflict
end

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if BattleMaps.Clamp then return BattleMaps.Clamp(value, minimum, maximum) end
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function CopyDefaults(defaults, target)
    target = type(target) == "table" and target or {}
    for key, value in pairs(defaults or {}) do
        if type(value) == "table" then
            target[key] = CopyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

function Callouts:GetSettings()
    local db = BattleMaps.Database and BattleMaps.Database.Get and BattleMaps.Database:Get()
    if type(db) ~= "table" then return self.DEFAULTS end

    local existing = type(db.callouts) == "table" and db.callouts or {}
    local wasLegacyLayout = tonumber(existing.layoutVersion) ~= 2
    local previousBindingVersion = tonumber(existing.bindingVersion) or 1
    local previousMacroVersion = tonumber(existing.macroVersion) or 0
    local legacyMessages = type(existing.messages) == "table" and existing.messages or nil
    local legacyPingOnIncoming = existing.pingTargetOnIncoming == true
    db.callouts = CopyDefaults(self.DEFAULTS, existing)

    -- 2.9.4 recalibrates icon sizing so 100% is approximately the visible
    -- base-node texture size rather than the larger interactive pin region.
    if wasLegacyLayout and math.abs((tonumber(db.callouts.iconScale) or 0) - 0.575) < 0.0001 then
        db.callouts.iconScale = 0.25
    end

    db.callouts.layoutVersion = 2
    db.callouts.iconScale = Clamp(db.callouts.iconScale, 0.25, 1.50)
    db.callouts.iconOffsetX = Clamp(db.callouts.iconOffsetX, -60, 60)
    db.callouts.iconOffsetY = Clamp(db.callouts.iconOffsetY, -60, 60)
    db.callouts.dragContextEnabled = db.callouts.dragContextEnabled ~= false
    db.callouts.bindings = CopyDefaults(self.DEFAULTS.bindings, db.callouts.bindings)

    -- Macro v1 replaces the old one-line message field with the complete
    -- secure macro. Preserve customised legacy text and, if the old INC ping
    -- option was enabled, fold that ping command into the Incoming macro.
    if previousMacroVersion < 1 then
        local migrated = {}
        for _, actionKey in ipairs(self.ACTION_ORDER) do
            local message = legacyMessages and legacyMessages[actionKey]
                or self.DEFAULTS.messages[actionKey]
                or "[node]"
            message = tostring(message or "")
                :gsub("[\r\n]+", " ")
                :gsub("%s+", " ")
                :match("^%s*(.-)%s*$") or ""
            if message == "" then message = tostring(self.DEFAULTS.messages[actionKey] or "[node]") end
            migrated[actionKey] = "/instance " .. message
        end
        if legacyPingOnIncoming then
            migrated.incoming = migrated.incoming
                .. "\n/ping [@target,exists,harm] attack; [@target,exists,noharm] assist; [@player] assist"
        end
        db.callouts.macros = migrated
    end
    db.callouts.macros = CopyDefaults(self.DEFAULTS.macros, db.callouts.macros)
    db.callouts.macroVersion = 1
    db.callouts.contexts = CopyDefaults(self.DEFAULTS.contexts, db.callouts.contexts)
    db.callouts.contextVersion = 1

    -- Binding v2 adds the mouse button to each gesture. Existing modifier-only
    -- bindings are migrated to left-click equivalents, while the two primary
    -- gestures deliberately adopt the new simple defaults requested for node
    -- interaction: LMB = Incoming and RMB = Clear.
    if previousBindingVersion < 2 then
        db.callouts.bindings.incoming = "BUTTON1"
        db.callouts.bindings.clear = "BUTTON2"
    end

    local used = {}
    for _, actionKey in ipairs(self.ACTION_ORDER) do
        local binding = self:NormalizeBinding(db.callouts.bindings[actionKey])
            or self.DEFAULTS.bindings[actionKey]
        if binding ~= "UNBOUND" and used[binding] then
            local preferred = self:NormalizeBinding(self.DEFAULTS.bindings[actionKey])
            if preferred and preferred ~= "UNBOUND" and not used[preferred] then
                binding = preferred
            else
                binding = "UNBOUND"
            end
        end
        db.callouts.bindings[actionKey] = binding
        if binding ~= "UNBOUND" then used[binding] = true end
    end
    db.callouts.bindingVersion = 2
    return db.callouts
end

local function SanitizeTemplate(value, fallback)
    value = tostring(value or "")
    value = value:gsub("[\r\n]+", " "):gsub("%s+", " ")
    value = value:match("^%s*(.-)%s*$") or ""
    if value == "" then value = tostring(fallback or "") end
    if #value > 120 then value = value:sub(1, 120) end
    return value
end

local MAX_MACRO_TEMPLATE_LENGTH = 1023

local function NormalizeMacroTemplate(value)
    value = tostring(value or "")
    value = value:gsub("\r\n", "\n"):gsub("\r", "\n")
    -- Trim outer whitespace without collapsing internal newlines or macro
    -- conditionals. Secure macrotext can therefore contain ordinary WoW macro
    -- commands exactly as the user typed them.
    value = value:match("^%s*(.-)%s*$") or ""
    if #value > MAX_MACRO_TEMPLATE_LENGTH then
        value = value:sub(1, MAX_MACRO_TEMPLATE_LENGTH)
    end
    return value
end

function Callouts:GetMacroTemplate(actionKey)
    local settings = self:GetSettings()
    settings.macros = CopyDefaults(self.DEFAULTS.macros, settings.macros)
    local value = settings.macros[actionKey]
    if value == nil then value = self.DEFAULTS.macros[actionKey] or "" end
    return NormalizeMacroTemplate(value)
end

function Callouts:SetMacroTemplate(actionKey, value)
    if self.DEFAULTS.macros[actionKey] == nil then return false end
    if InCombatLockdown and InCombatLockdown() then
        if BattleMaps.Chat then BattleMaps.Chat("Callout macros can only be changed out of combat.") end
        return false
    end
    local settings = self:GetSettings()
    settings.macros = type(settings.macros) == "table" and settings.macros or {}
    settings.macros[actionKey] = NormalizeMacroTemplate(value)
    settings.macroVersion = 1
    self:RequestSecureRefresh()
    return true
end

function Callouts:ResetMacro(actionKey)
    if self.DEFAULTS.macros[actionKey] == nil then return false end
    return self:SetMacroTemplate(actionKey, self.DEFAULTS.macros[actionKey])
end

function Callouts:ResetMacros()
    if InCombatLockdown and InCombatLockdown() then
        if BattleMaps.Chat then BattleMaps.Chat("Callout macros can only be changed out of combat.") end
        return false
    end
    local settings = self:GetSettings()
    settings.macros = {}
    for key, value in pairs(self.DEFAULTS.macros) do settings.macros[key] = value end
    settings.macroVersion = 1
    self:RequestSecureRefresh()
    return true
end

local CHAT_COMMANDS = {
    instance = true, i = true, bg = true, battleground = true,
    raid = true, ra = true, rw = true, party = true, p = true,
    say = true, s = true, yell = true, y = true,
}

local function AppendContextToFirstChatLine(resolved, contextText)
    contextText = tostring(contextText or "")
    if contextText == "" then return resolved end
    local output, appended = {}, false
    for line in (tostring(resolved or "") .. "\n"):gmatch("(.-)\n") do
        if not appended then
            local command = line:match("^%s*/([%a]+)%s+")
            command = command and command:lower() or nil
            if command and CHAT_COMMANDS[command] then
                line = line:gsub("%s+$", "") .. " " .. contextText
                appended = true
            end
        end
        output[#output + 1] = line
    end
    return table.concat(output, "\n"):gsub("\n$", "")
end

function Callouts:ResolveMacro(actionKey, node, contextText)
    if not node then return "" end
    local template = self:GetMacroTemplate(actionKey)
    local usedContextToken = false
    local resolved = (template:gsub("%[([%w_]+)%]", function(token)
        token = tostring(token or ""):lower()
        if token == "node" then return tostring(node.chat or node.display or "") end
        if token == "node_full" then return tostring(node.display or node.chat or "") end
        if token == "context" then
            usedContextToken = true
            return tostring(contextText or "")
        end
        -- Preserve normal WoW macro conditionals such as [combat] or [help].
        return "[" .. token .. "]"
    end))
    resolved = resolved:gsub("[ \t]+\n", "\n"):gsub("[ \t]+$", "")
    if not usedContextToken and contextText and contextText ~= "" then
        resolved = AppendContextToFirstChatLine(resolved, contextText)
    end
    return resolved
end

function Callouts:GetCalloutPreviewText(actionKey, node, contextText)
    if not actionKey or not node then return "" end
    local resolved = self:ResolveMacro(actionKey, node, contextText)
    for line in tostring(resolved or ""):gmatch("[^\n]+") do
        local command, text = line:match("^%s*/([%a]+)%s+(.+)$")
        command = command and command:lower() or nil
        if command and CHAT_COMMANDS[command] then
            return tostring(text or "")
        end
    end
    local label = self.ACTION_LABELS[actionKey] or tostring(actionKey)
    local nodeText = tostring(node.chat or node.display or "")
    local base = nodeText ~= "" and (label .. " " .. nodeText) or label
    if contextText and contextText ~= "" then base = base .. " " .. tostring(contextText) end
    return base
end

local MAX_CONTEXT_STRING_LENGTH = 40

local function NormalizeContextString(value)
    value = tostring(value or "")
    value = value:gsub("[\r\n]+", " "):gsub("%s+", " ")
    value = value:match("^%s*(.-)%s*$") or ""
    if #value > MAX_CONTEXT_STRING_LENGTH then
        value = value:sub(1, MAX_CONTEXT_STRING_LENGTH)
    end
    return value
end

function Callouts:GetActionContexts(actionKey)
    local defaults = self.DEFAULTS.contexts and self.DEFAULTS.contexts[actionKey]
    if type(defaults) ~= "table" then return nil end
    local settings = self:GetSettings()
    settings.contexts = CopyDefaults(self.DEFAULTS.contexts, settings.contexts)
    local source = settings.contexts[actionKey] or defaults
    local result = {}
    for _, key in ipairs({ "TOP", "RIGHT", "BOTTOM", "LEFT" }) do
        local value = source[key]
        if value == nil then value = defaults[key] end
        result[key] = NormalizeContextString(value)
    end
    return result
end

function Callouts:SetActionContexts(actionKey, values)
    local defaults = self.DEFAULTS.contexts and self.DEFAULTS.contexts[actionKey]
    if type(defaults) ~= "table" or type(values) ~= "table" then return false end
    if InCombatLockdown and InCombatLockdown() then
        if BattleMaps.Chat then BattleMaps.Chat("Callout context strings can only be changed out of combat.") end
        return false
    end
    local settings = self:GetSettings()
    settings.contexts = type(settings.contexts) == "table" and settings.contexts or {}
    settings.contexts[actionKey] = settings.contexts[actionKey] or {}
    for _, key in ipairs({ "TOP", "RIGHT", "BOTTOM", "LEFT" }) do
        settings.contexts[actionKey][key] = NormalizeContextString(values[key])
    end
    settings.contextVersion = 1
    self:RequestSecureRefresh()
    return true
end

function Callouts:GetMaxContextStringLength()
    return MAX_CONTEXT_STRING_LENGTH
end

function Callouts:GetDragContextText(contextKey, actionKey)
    local key = tostring(contextKey or "BASE"):upper()
    if key == "BASE" then return "" end
    if actionKey then
        local contexts = self:GetActionContexts(actionKey)
        if contexts and contexts[key] ~= nil then return contexts[key] end
    end
    local info = DRAG_CONTEXTS[key]
    return info and info.text or ""
end

function Callouts:GetMaxMacroTemplateLength()
    return MAX_MACRO_TEMPLATE_LENGTH
end

function Callouts:GetMessageTemplate(actionKey)
    local settings = self:GetSettings()
    local fallback = self.DEFAULTS.messages[actionKey] or "[node]"
    settings.messages = CopyDefaults(self.DEFAULTS.messages, settings.messages)
    return SanitizeTemplate(settings.messages[actionKey], fallback)
end

function Callouts:SetMessageTemplate(actionKey, value)
    if not self.DEFAULTS.messages[actionKey] then return false end
    local settings = self:GetSettings()
    settings.messages[actionKey] = SanitizeTemplate(value, self.DEFAULTS.messages[actionKey])
    self:RequestSecureRefresh()
    return true
end

function Callouts:ResetMessages()
    local settings = self:GetSettings()
    settings.messages = {}
    for key, value in pairs(self.DEFAULTS.messages) do settings.messages[key] = value end
    self:RequestSecureRefresh()
end

function Callouts:ResolveMessage(actionKey, node)
    if not node then return "" end
    local template = self:GetMessageTemplate(actionKey)
    return (template:gsub("%[([%w_]+)%]", function(token)
        token = tostring(token or ""):lower()
        if token == "node" then return tostring(node.chat or node.display or "") end
        if token == "node_full" then return tostring(node.display or node.chat or "") end
        return "[" .. token .. "]"
    end))
end

function Callouts:GetActionTexture(actionKey)
    local canonical = self.ACTION_TEXTURES[actionKey]
    local function IsKnown(path)
        if not path then return false end
        if C_UIFileAsset and type(C_UIFileAsset.IsKnownFile) == "function" then
            local ok, known = pcall(C_UIFileAsset.IsKnownFile, path)
            if ok and known == true then return true end
        end
        if type(GetFileIDFromPath) == "function" then
            local ok, fileID = pcall(GetFileIDFromPath, path)
            if ok and tonumber(fileID) then return true end
        end
        return false
    end

    if canonical and IsKnown(canonical) then return canonical end
    for _, filename in ipairs(LEGACY_TEXTURE_CANDIDATES[actionKey] or {}) do
        local path = LEGACY_ROOT .. filename
        if IsKnown(path) then return path end
    end
    return canonical or FALLBACK_TEXTURE
end

function Callouts:GetCurrentModifierMode()
    local alt = IsAltKeyDown and IsAltKeyDown() == true
    local shift = IsShiftKeyDown and IsShiftKeyDown() == true
    local ctrl = IsControlKeyDown and IsControlKeyDown() == true
    if alt and ctrl and shift then return "ALT_CTRL_SHIFT" end
    if alt and shift and not ctrl then return "ALT_SHIFT" end
    if alt and ctrl and not shift then return "ALT_CTRL" end
    if ctrl and shift and not alt then return "CTRL_SHIFT" end
    if alt and not shift and not ctrl then return "ALT" end
    if shift and not alt and not ctrl then return "SHIFT" end
    if ctrl and not alt and not shift then return "CTRL" end
    if not alt and not shift and not ctrl then return "NONE" end
    return nil
end

local function Normalize(value)
    local ok, text = pcall(tostring, value or "")
    if not ok or type(text) ~= "string" then return "" end
    text = text:lower()
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return text:gsub("[^%w]", "")
end

local function GetCurrentMapID()
    if BattleMaps and type(BattleMaps.ResolveCurrentBattlegroundMapID) == "function" then
        local ok, mapID = pcall(BattleMaps.ResolveCurrentBattlegroundMapID)
        if ok and tonumber(mapID) then return tonumber(mapID) end
    end
    local mapFrame = BattleMaps and BattleMaps.MapFrame
    if mapFrame then
        return tonumber(mapFrame.currentMapID) or tonumber(mapFrame.selectedMapID)
    end
    return nil
end

local function ResolveNode(title)
    local normalized = Normalize(title)
    if normalized == "" then return nil end
    local currentMapKey = MAP_ID_TO_KEY[GetCurrentMapID()]
    local bestNode, bestLength = nil, 0

    for _, node in pairs(NODE_DEFS) do
        if not currentMapKey or node.mapKey == currentMapKey then
            for _, alias in ipairs(node.aliases or {}) do
                local candidate = Normalize(alias)
                -- Stationary pin titles contain the real objective name; avoid
                -- matching two-letter chat abbreviations against unrelated text.
                if #candidate >= 4 and (normalized == candidate or normalized:find(candidate, 1, true)) then
                    if #candidate > bestLength then
                        bestNode, bestLength = node, #candidate
                    end
                end
            end
        end
    end
    return bestNode
end

local function GetPinScreenPosition(pin)
    if not pin or not pin.GetCenter then return nil end
    local x, y = pin:GetCenter()
    if not x or not y then return nil end

    local pinScale = pin.GetEffectiveScale and pin:GetEffectiveScale() or 1
    local rootScale = UIParent and UIParent:GetEffectiveScale() or 1
    if not pinScale or pinScale <= 0 then pinScale = 1 end
    if not rootScale or rootScale <= 0 then rootScale = 1 end
    local ratio = pinScale / rootScale
    return x * ratio, y * ratio, ratio
end

local function CreateChoiceVisual(name)
    -- Keep the screen-positioned wrapper at scale 1. Scaling a frame that is
    -- anchored to UIParent with absolute screen coordinates also scales the
    -- anchor offset, which makes the icon jump toward the lower-left corner.
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(150)
    frame:SetSize(24, 24)
    frame:Hide()
    frame:SetAlpha(1)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("CENTER", frame, "CENTER")
    content:SetSize(24, 24)
    content:SetScale(1)
    content:SetAlpha(1)
    frame.Content = content

    local texture = content:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints(content)
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetVertexColor(1, 1, 1, 1)
    frame.Texture = texture

    -- Separate additive copy used only for the brief post-click glow. Its
    -- animated content is also a child so glow scaling cannot shift position.
    local glow = CreateFrame("Frame", name .. "Glow", UIParent)
    glow:SetFrameStrata("TOOLTIP")
    glow:SetFrameLevel(149)
    glow:SetSize(34, 34)
    glow:Hide()
    glow:SetAlpha(1)

    local glowContent = CreateFrame("Frame", nil, glow)
    glowContent:SetPoint("CENTER", glow, "CENTER")
    glowContent:SetSize(34, 34)
    glowContent:SetScale(1)
    glowContent:SetAlpha(0)
    glow.Content = glowContent

    local glowTexture = glowContent:CreateTexture(nil, "ARTWORK")
    glowTexture:SetAllPoints(glowContent)
    glowTexture:SetTexCoord(0, 1, 0, 1)
    glowTexture:SetBlendMode("ADD")
    glowTexture:SetVertexColor(1, 1, 1, 1)
    glow.Texture = glowTexture
    frame.Glow = glow

    -- Experimental Blizzard flipbook pulse. Keep this separate from the
    -- existing icon confirmation + additive icon glow so both treatments can
    -- be evaluated simultaneously in live BG testing. We deliberately use an
    -- ordinary texture/FlipBook animation rather than Blizzard's protected
    -- Ping System display frames.
    local ping = CreateFrame("Frame", name .. "PingFlipbook", UIParent)
    ping:SetFrameStrata("TOOLTIP")
    ping:SetFrameLevel(148)
    ping:SetSize(48, 48)
    ping:Hide()
    ping:SetAlpha(1)

    local pingContent = CreateFrame("Frame", nil, ping)
    pingContent:SetPoint("CENTER", ping, "CENTER")
    pingContent:SetSize(48, 48)
    pingContent:SetScale(1)
    pingContent:SetAlpha(1)
    ping.Content = pingContent

    local pingTexture = pingContent:CreateTexture(nil, "ARTWORK")
    pingTexture:SetAllPoints(pingContent)
    pingTexture:SetBlendMode("ADD")
    pingTexture:SetVertexColor(1, 1, 1, 1)
    local pingAtlasAvailable = false
    if C_Texture and C_Texture.GetAtlasInfo then
        local ok, atlasInfo = pcall(C_Texture.GetAtlasInfo, PING_FLIPBOOK_ATLAS)
        pingAtlasAvailable = ok and atlasInfo ~= nil
    else
        pingAtlasAvailable = true
    end
    if pingAtlasAvailable and pingTexture.SetAtlas then
        local ok = pcall(pingTexture.SetAtlas, pingTexture, PING_FLIPBOOK_ATLAS, false)
        pingAtlasAvailable = ok
    end
    ping.Texture = pingTexture
    ping.available = pingAtlasAvailable
    frame.PingFlipbook = ping

    if pingAtlasAvailable then
        local pingAnimation = pingContent:CreateAnimationGroup()
        local flip = pingAnimation:CreateAnimation("FlipBook")
        flip:SetOrder(1)
        flip:SetDuration(PING_FLIPBOOK_DURATION)
        flip:SetFlipBookRows(PING_FLIPBOOK_ROWS)
        flip:SetFlipBookColumns(PING_FLIPBOOK_COLUMNS)
        flip:SetFlipBookFrames(PING_FLIPBOOK_FRAMES)

        local pingScale = pingAnimation:CreateAnimation("Scale")
        pingScale:SetOrder(1)
        pingScale:SetDuration(PING_FLIPBOOK_DURATION)
        pingScale:SetSmoothing("OUT")
        pingScale:SetScaleFrom(0.82, 0.82)
        pingScale:SetScaleTo(1.18, 1.18)

        local pingFade = pingAnimation:CreateAnimation("Alpha")
        pingFade:SetOrder(1)
        pingFade:SetDuration(PING_FLIPBOOK_DURATION)
        pingFade:SetFromAlpha(0.95)
        pingFade:SetToAlpha(0)
        pingFade:SetSmoothing("IN")

        pingAnimation:SetScript("OnPlay", function()
            pingContent:SetScale(1)
            pingContent:SetAlpha(0.95)
            ping:Show()
        end)
        pingAnimation:SetScript("OnFinished", function()
            pingContent:SetScale(1)
            pingContent:SetAlpha(1)
            ping:Hide()
        end)
        pingAnimation:SetScript("OnStop", function()
            pingContent:SetScale(1)
            pingContent:SetAlpha(1)
            ping:Hide()
        end)
        ping.Animation = pingAnimation
    end

    local confirm = content:CreateAnimationGroup()

    local settle = confirm:CreateAnimation("Scale")
    settle:SetOrder(1)
    settle:SetDuration(RELEASE_SETTLE_DURATION)
    settle:SetSmoothing("OUT")
    settle:SetScaleFrom(RELEASE_SCALE_FROM, RELEASE_SCALE_FROM)
    settle:SetScaleTo(1.00, 1.00)

    local hold = confirm:CreateAnimation("Alpha")
    hold:SetOrder(1)
    hold:SetDuration(CONFIRM_HOLD_DURATION)
    hold:SetFromAlpha(1)
    hold:SetToAlpha(1)

    local fade = confirm:CreateAnimation("Alpha")
    fade:SetOrder(2)
    fade:SetDuration(CONFIRM_FADE_DURATION)
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetSmoothing("IN")

    confirm:SetScript("OnPlay", function()
        frame.animationBusy = true
        frame.pressed = false
        content:SetScale(1)
        content:SetAlpha(1)
        frame.Texture:SetVertexColor(1, 1, 1, 1)
        frame:Show()
    end)
    confirm:SetScript("OnFinished", function()
        frame.animationBusy = false
        content:SetScale(1)
        content:SetAlpha(1)
        frame.Texture:SetVertexColor(1, 1, 1, 1)
        frame:Hide()
    end)
    confirm:SetScript("OnStop", function()
        frame.animationBusy = false
        content:SetScale(1)
        content:SetAlpha(1)
        frame.Texture:SetVertexColor(1, 1, 1, 1)
    end)
    frame.ConfirmAnimation = confirm

    local glowAnimation = glowContent:CreateAnimationGroup()

    local glowScale = glowAnimation:CreateAnimation("Scale")
    glowScale:SetOrder(1)
    glowScale:SetDuration(GLOW_FADE_DURATION)
    glowScale:SetSmoothing("OUT")
    glowScale:SetScaleFrom(0.78, 0.78)
    glowScale:SetScaleTo(1.25, 1.25)

    local glowFade = glowAnimation:CreateAnimation("Alpha")
    glowFade:SetOrder(1)
    glowFade:SetDuration(GLOW_FADE_DURATION)
    glowFade:SetFromAlpha(0.82)
    glowFade:SetToAlpha(0)
    glowFade:SetSmoothing("IN")

    glowAnimation:SetScript("OnPlay", function()
        glowContent:SetScale(1)
        glowContent:SetAlpha(0.82)
        glow:Show()
    end)
    glowAnimation:SetScript("OnFinished", function()
        glowContent:SetScale(1)
        glowContent:SetAlpha(0)
        glow:Hide()
    end)
    glowAnimation:SetScript("OnStop", function()
        glowContent:SetScale(1)
        glowContent:SetAlpha(0)
        glow:Hide()
    end)
    glow.Animation = glowAnimation

    return frame
end

function Callouts:BuildCallouts(node)
    local result = {}
    local settings = self:GetSettings()
    for _, actionKey in ipairs(self.ACTION_ORDER) do
        local parts = self:GetBindingParts(settings.bindings and settings.bindings[actionKey])
        local prefix = MODE_SECURE_PREFIX[parts.mode]
        local suffix = parts.mouse and parts.mouse.suffix
        if prefix and suffix then
            local attr = prefix .. "macrotext" .. suffix
            -- Keep a permanent secure copy of the base macro plus four edge
            -- variants. PreClick selects among these without asking insecure
            -- Lua to alter protected attributes during combat.
            result[attr] = self:ResolveMacro(actionKey, node)
            result["drag-base-" .. attr] = result[attr]
            result["drag-action-" .. prefix .. suffix] = actionKey
            for _, contextKey in ipairs(DRAG_CONTEXT_ORDER) do
                if contextKey ~= "BASE" then
                    local contextText = self:GetDragContextText(contextKey, actionKey)
                    result["drag-" .. contextKey:lower() .. "-" .. attr] = self:ResolveMacro(actionKey, node, contextText)
                end
            end
        end
    end
    return result
end

function Callouts:ApplySecureAttributes(ui)
    if not ui or not ui.button then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local settings = self:GetSettings()
    ui.button:SetAttribute("drag-enabled", settings.dragContextEnabled ~= false and 1 or 0)
    ui.button:SetAttribute("drag-edge-pixels", DRAG_CONTEXT_EDGE_PIXELS)
    ui.button:SetAttribute("drag-min-travel-fraction", DRAG_CONTEXT_MIN_TRAVEL_FRACTION)

    -- Restricted frame handles may only be used as relative anchors when they
    -- refer to explicitly protected frames. UIParent and our ordinary node
    -- container therefore cannot safely be passed through SetFrameRef and then
    -- used by SetAllPoints during combat. The restricted frame API provides
    -- special $screen/$parent anchors specifically for this case.
    --
    -- While expanded to $screen, restricted GetMousePosition() returns values
    -- normalized to the frame (0..1), not pixel coordinates. Snapshot the map
    -- rectangle into the same normalized screen coordinate space so the secure
    -- release snippet can choose an edge zone without touching an insecure map
    -- frame or mixing coordinate systems.
    local map = BattleMaps.MapFrame and BattleMaps.MapFrame.frame
    local left, bottom, width, height
    if map and map.GetRect then
        left, bottom, width, height = map:GetRect()
    end
    left = tonumber(left) or (map and map.GetLeft and tonumber(map:GetLeft())) or 0
    bottom = tonumber(bottom) or (map and map.GetBottom and tonumber(map:GetBottom())) or 0
    width = tonumber(width) or (map and map.GetWidth and tonumber(map:GetWidth())) or 0
    height = tonumber(height) or (map and map.GetHeight and tonumber(map:GetHeight())) or 0

    local mapScale = map and map.GetEffectiveScale and tonumber(map:GetEffectiveScale()) or 1
    local rootScale = UIParent and UIParent.GetEffectiveScale and tonumber(UIParent:GetEffectiveScale()) or 1
    local rootWidth = UIParent and UIParent.GetWidth and tonumber(UIParent:GetWidth()) or 0
    local rootHeight = UIParent and UIParent.GetHeight and tonumber(UIParent:GetHeight()) or 0
    local screenPixelWidth = rootWidth * rootScale
    local screenPixelHeight = rootHeight * rootScale
    local leftN, bottomN, widthN, heightN = 0, 0, 0, 0
    if screenPixelWidth > 0 and screenPixelHeight > 0 then
        leftN = (left * mapScale) / screenPixelWidth
        bottomN = (bottom * mapScale) / screenPixelHeight
        widthN = (width * mapScale) / screenPixelWidth
        heightN = (height * mapScale) / screenPixelHeight
    end
    ui.button:SetAttribute("drag-map-left-n", leftN)
    ui.button:SetAttribute("drag-map-bottom-n", bottomN)
    ui.button:SetAttribute("drag-map-width-n", widthN)
    ui.button:SetAttribute("drag-map-height-n", heightN)
    ui.button:SetAttribute("drag-map-ui-width", width)
    ui.button:SetAttribute("drag-map-ui-height", height)
    for _, mode in ipairs(MODE_ORDER) do
        local prefix = MODE_SECURE_PREFIX[mode]
        -- Define all supported mouse/modifier combinations explicitly. This
        -- prevents an unassigned modified click from falling through to the
        -- corresponding unmodified action.
        for suffix = 1, 3 do
            local attr = prefix .. "macrotext" .. suffix
            ui.button:SetAttribute(prefix .. "type" .. suffix, "macro")
            ui.button:SetAttribute(attr, "")
            ui.button:SetAttribute("drag-base-" .. attr, "")
            ui.button:SetAttribute("drag-action-" .. prefix .. suffix, "")
            for _, contextKey in ipairs(DRAG_CONTEXT_ORDER) do
                if contextKey ~= "BASE" then
                    ui.button:SetAttribute("drag-" .. contextKey:lower() .. "-" .. attr, "")
                end
            end
        end
    end
    local callouts = self:BuildCallouts(ui.node)
    for attribute, value in pairs(callouts) do
        ui.button:SetAttribute(attribute, value)
    end
    return true
end

function Callouts:SetBaseHoverSuppressed(ui, suppressed)
    if not ui then return end
    suppressed = suppressed == true

    if suppressed then
        local pin = ui.pin
        if not pin or type(pin.SetAlpha) ~= "function" then return end

        -- A POI refresh may replace the frame representing this node while the
        -- pointer is still inside the callout hit-zone. Restore the old frame
        -- before adopting the new one so no stale base stays invisible.
        if ui.suppressedPin and ui.suppressedPin ~= pin then
            local oldPin = ui.suppressedPin
            local oldAlpha = tonumber(oldPin.BattleMapsStationaryObjectiveAlpha)
                or tonumber(ui.suppressedPinAlpha) or 1
            oldPin.BattleMapsCalloutHoverSuppressed = nil
            if type(oldPin.SetAlpha) == "function" then oldPin:SetAlpha(oldAlpha) end
            ui.suppressedPin = nil
            ui.suppressedPinAlpha = nil
        end

        if ui.suppressedPin ~= pin then
            ui.suppressedPin = pin
            if type(pin.GetAlpha) == "function" then
                local ok, alpha = pcall(pin.GetAlpha, pin)
                if ok then ui.suppressedPinAlpha = tonumber(alpha) end
            end
        end

        -- Mark suppression on the objective pin itself. Objective refreshes
        -- reapply stationary-objective opacity, so the renderer must know the
        -- callout currently owns visual presentation rather than briefly
        -- restoring the base between hover polling ticks.
        pin.BattleMapsCalloutHoverSuppressed = true

        -- Stationary objective textures, capture-fill layers, pulse overlays,
        -- and timer text all inherit the pin frame's alpha. Hiding the parent
        -- makes the callout artwork cleanly replace the complete base visual
        -- without disturbing the separate secure callout button.
        pin:SetAlpha(0)
        return
    end

    local pin = ui.suppressedPin
    if pin then
        pin.BattleMapsCalloutHoverSuppressed = nil
        if type(pin.SetAlpha) == "function" then
            local restoreAlpha = tonumber(pin.BattleMapsStationaryObjectiveAlpha)
                or tonumber(ui.suppressedPinAlpha) or 1
            pin:SetAlpha(restoreAlpha)
        end
    end
    ui.suppressedPin = nil
    ui.suppressedPinAlpha = nil
end

function Callouts:HideHeldPreview()
    -- Held callout text previews were removed in 3.0.40. Keep this no-op for
    -- compatibility with cleanup paths that may still call it.
end

function Callouts:EnsureDragContextOverlay()
    if self.dragContextOverlay then return self.dragContextOverlay end
    local map = BattleMaps.MapFrame and BattleMaps.MapFrame.frame
    if not map then return nil end

    local frame = CreateFrame("Frame", "BattleMapsCalloutDragContextOverlay", UIParent)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel((map.GetFrameLevel and map:GetFrameLevel() or 100) + 30)
    frame:EnableMouse(false)
    frame:Hide()
    frame.regions = {}

    local bandSpecs = {
        { size = 2, alpha = 0.95 },
        { size = 3, alpha = 0.55 },
        { size = 4, alpha = 0.30 },
        { size = 5, alpha = 0.14 },
    }

    for _, key in ipairs({ "TOP", "RIGHT", "BOTTOM", "LEFT" }) do
        local region = CreateFrame("Frame", nil, frame)
        region:EnableMouse(false)
        region:Hide()
        region.bands = {}

        if key == "TOP" then
            region:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            region:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
            region:SetHeight(DRAG_CONTEXT_GLOW_DEPTH)
        elseif key == "BOTTOM" then
            region:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
            region:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            region:SetHeight(DRAG_CONTEXT_GLOW_DEPTH)
        elseif key == "LEFT" then
            region:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            region:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
            region:SetWidth(DRAG_CONTEXT_GLOW_DEPTH)
        else
            region:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
            region:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            region:SetWidth(DRAG_CONTEXT_GLOW_DEPTH)
        end

        local offset = 0
        for index, spec in ipairs(bandSpecs) do
            local band = region:CreateTexture(nil, "ARTWORK")
            band:SetTexture("Interface\\Buttons\\WHITE8X8")
            band:SetBlendMode("ADD")
            band.BattleMapsGlowAlpha = spec.alpha

            if key == "TOP" then
                band:SetPoint("TOPLEFT", region, "TOPLEFT", 0, -offset)
                band:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, -offset)
                band:SetHeight(spec.size)
            elseif key == "BOTTOM" then
                band:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, offset)
                band:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, offset)
                band:SetHeight(spec.size)
            elseif key == "LEFT" then
                band:SetPoint("TOPLEFT", region, "TOPLEFT", offset, 0)
                band:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", offset, 0)
                band:SetWidth(spec.size)
            else
                band:SetPoint("TOPRIGHT", region, "TOPRIGHT", -offset, 0)
                band:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -offset, 0)
                band:SetWidth(spec.size)
            end

            region.bands[index] = band
            offset = offset + spec.size
        end

        frame.regions[key] = region
    end

    self.dragContextOverlay = frame
    return frame
end

function Callouts:HideDragContextOverlay()
    local frame = self.dragContextOverlay
    if not frame then return end
    frame.activeKey = nil
    frame.activeAction = nil
    for _, region in pairs(frame.regions or {}) do
        region:Hide()
    end
    frame:Hide()
end

local function GetMapMousePosition(map)
    if not map then return nil, nil end
    if type(map.GetMousePosition) == "function" then
        local ok, x, y = pcall(map.GetMousePosition, map)
        if ok and tonumber(x) and tonumber(y) then return tonumber(x), tonumber(y) end
    end

    local left, bottom = map.GetLeft and map:GetLeft(), map.GetBottom and map:GetBottom()
    local scale = map.GetEffectiveScale and map:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()
    if not left or not bottom or not cursorX or not cursorY or not scale or scale == 0 then return nil, nil end
    return (cursorX / scale) - left, (cursorY / scale) - bottom
end

function Callouts:GetDragContextAtCursor(ui)
    local settings = self:GetSettings()
    if settings.dragContextEnabled == false or not ui or not ui.pressActive then return nil, "" end
    local map = BattleMaps.MapFrame and BattleMaps.MapFrame.frame
    if not map or not map:IsShown() then return nil, "" end

    local width, height = map:GetWidth(), map:GetHeight()
    local x, y = GetMapMousePosition(map)
    if not x or not y or not width or not height or width <= 0 or height <= 0 then return nil, "" end
    -- Do not require the cursor to remain inside the map. The edge regions
    -- act as trigger thresholds: once the pointer reaches one, it may continue
    -- past the map edge and the same context remains selected for release.
    -- This makes the gesture a deliberate "swipe through" rather than
    -- requiring the player to stop and release inside a narrow strip.

    local startX, startY = ui.pressStartMapX, ui.pressStartMapY
    if startX and startY then
        local dx, dy = x - startX, y - startY
        local minDim = math.min(width, height)
        local travel = minDim * DRAG_CONTEXT_MIN_TRAVEL_FRACTION
        if (dx * dx + dy * dy) < (travel * travel) then return nil, "" end
    end

    -- The interaction threshold is intentionally only one UI pixel. The
    -- pointer can continue beyond the frame; outside coordinates become
    -- negative/greater-than-size and therefore remain past the crossed edge.
    local dl, dr = x, width - x
    local db, dt = y, height - y
    local minimum, key = dl, "LEFT"
    if dr < minimum then minimum, key = dr, "RIGHT" end
    if db < minimum then minimum, key = db, "BOTTOM" end
    if dt < minimum then minimum, key = dt, "TOP" end
    if minimum > DRAG_CONTEXT_EDGE_PIXELS then return nil, "" end
    return key, self:GetDragContextText(key, ui.pressActionKey)
end

function Callouts:ShowDragContextOverlay(activeKey, actionKey)
    local settings = self:GetSettings()
    if settings.dragContextEnabled == false or not activeKey then
        self:HideDragContextOverlay()
        return
    end

    local map = BattleMaps.MapFrame and BattleMaps.MapFrame.frame
    local frame = self:EnsureDragContextOverlay()
    if not frame or not map or not map:IsShown() then
        self:HideDragContextOverlay()
        return
    end

    frame:ClearAllPoints()
    frame:SetAllPoints(map)

    local color = ACTION_GLOW_COLORS[actionKey] or { 1, 1, 1 }
    for key, region in pairs(frame.regions or {}) do
        if key == activeKey then
            for _, band in ipairs(region.bands or {}) do
                band:SetVertexColor(color[1], color[2], color[3], 1)
                band:SetAlpha(band.BattleMapsGlowAlpha or 1)
            end
            region:Show()
        else
            region:Hide()
        end
    end

    frame.activeKey = activeKey
    frame.activeAction = actionKey
    frame:Show()
end

function Callouts:UpdateHeldDragContext(ui)
    if not ui or not ui.pressActive or not ui.pressActionKey then
        self:HideDragContextOverlay()
        return nil, ""
    end
    local key, contextText = self:GetDragContextAtCursor(ui)
    ui.dragContextKey = key
    ui.dragContextText = contextText
    self:ShowDragContextOverlay(key, ui.pressActionKey)
    return key, contextText
end

function Callouts:CreateNodeUI(node, index)
    local container = CreateFrame("Frame", "BattleMapsCalloutContainer" .. index, UIParent)
    container:SetSize(32, 32)
    container:SetFrameStrata("DIALOG")
    container:Hide()

    local button = CreateFrame("Button", "BattleMapsCalloutNode" .. index, container, "SecureActionButtonTemplate,SecureHandlerMouseUpDownTemplate")
    button:SetAllPoints(container)
    button:SetFrameStrata("DIALOG")
    -- The secure macro is release-triggered only. Mouse-down remains purely
    -- visual. With edge-drag context enabled, secure mouse-down expands the
    -- hit target so a drag can leave the objective and still commit on release.
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("_onmousedown", [[
        if self:GetAttribute("drag-enabled") ~= 1 then return end
        local suffix = button == "LeftButton" and "1" or button == "RightButton" and "2" or button == "MiddleButton" and "3" or nil
        if not suffix then return end
        local prefix = SecureCmdOptionParse("[mod:alt,ctrl,shift] alt-ctrl-shift-; [mod:alt,ctrl] alt-ctrl-; [mod:alt,shift] alt-shift-; [mod:ctrl,shift] ctrl-shift-; [mod:alt] alt-; [mod:ctrl] ctrl-; [mod:shift] shift-; [] none") or "none"
        if prefix == "none" then prefix = "" end
        local action = self:GetAttribute("drag-action-" .. prefix .. suffix)
        if not action or action == "" then return end
        self:SetAttribute("drag-active-prefix", prefix)
        self:SetAttribute("drag-active-suffix", suffix)
        -- $screen is a built-in restricted anchor and does not require an
        -- explicitly protected frame handle. This keeps the click captured
        -- after the cursor leaves the objective without triggering
        -- "Invalid relative frame handle" in combat.
        self:ClearAllPoints()
        self:SetAllPoints("$screen")
        self:SetAttribute("drag-expanded", 1)

        local px, py = self:GetMousePosition()
        local left = self:GetAttribute("drag-map-left-n") or 0
        local bottom = self:GetAttribute("drag-map-bottom-n") or 0
        self:SetAttribute("drag-start-x", px and (px - left) or -10000)
        self:SetAttribute("drag-start-y", py and (py - bottom) or -10000)
    ]])
    button:Show()

    -- Secure PreClick chooses an edge-context macro after the pointer has been
    -- dragged, while PostClick restores the base macro and compact node hitbox.
    button:WrapScript(button, "PreClick", [[
        if down then return end
        local suffix = button == "LeftButton" and "1" or button == "RightButton" and "2" or button == "MiddleButton" and "3" or nil
        if not suffix then return end
        local prefix = SecureCmdOptionParse("[mod:alt,ctrl,shift] alt-ctrl-shift-; [mod:alt,ctrl] alt-ctrl-; [mod:alt,shift] alt-shift-; [mod:ctrl,shift] ctrl-shift-; [mod:alt] alt-; [mod:ctrl] ctrl-; [mod:shift] shift-; [] none") or "none"
        if prefix == "none" then prefix = "" end
        local attr = prefix .. "macrotext" .. suffix
        local macro = self:GetAttribute("drag-base-" .. attr) or ""
        if self:GetAttribute("drag-enabled") == 1 and macro ~= "" and self:GetAttribute("drag-expanded") == 1 then
            local px, py = self:GetMousePosition()
            local left = self:GetAttribute("drag-map-left-n") or 0
            local bottom = self:GetAttribute("drag-map-bottom-n") or 0
            local w = self:GetAttribute("drag-map-width-n") or 0
            local h = self:GetAttribute("drag-map-height-n") or 0
            local x = px and (px - left) or nil
            local y = py and (py - bottom) or nil
            local sx, sy = self:GetAttribute("drag-start-x"), self:GetAttribute("drag-start-y")
            local edgePixels = self:GetAttribute("drag-edge-pixels") or 1
            local mapUiW = self:GetAttribute("drag-map-ui-width") or 0
            local mapUiH = self:GetAttribute("drag-map-ui-height") or 0
            local travelFrac = self:GetAttribute("drag-min-travel-fraction") or 0.08
            if x and y and w > 0 and h > 0 and mapUiW > 0 and mapUiH > 0 and sx and sy then
                -- x/y are intentionally allowed beyond the map rectangle.
                -- Crossing an edge threshold selects that context even if the
                -- pointer continues outside the map before mouse-up.
                local dx, dy = x - sx, y - sy
                local minDim = w < h and w or h
                local travel = minDim * travelFrac
                if (dx * dx + dy * dy) >= (travel * travel) then
                    local dl = (x / w) * mapUiW
                    local dr = ((w - x) / w) * mapUiW
                    local db = (y / h) * mapUiH
                    local dt = ((h - y) / h) * mapUiH
                    local nearest, zone = dl, "left"
                    if dr < nearest then nearest, zone = dr, "right" end
                    if db < nearest then nearest, zone = db, "bottom" end
                    if dt < nearest then nearest, zone = dt, "top" end
                    if nearest <= edgePixels then
                        macro = self:GetAttribute("drag-" .. zone .. "-" .. attr) or macro
                        self:SetAttribute("drag-selected-zone", zone)
                    else
                        self:SetAttribute("drag-selected-zone", "")
                    end
                end
            end
        end
        self:SetAttribute(attr, macro)
    ]])
    button:WrapScript(button, "PostClick", [[
        local suffix = button == "LeftButton" and "1" or button == "RightButton" and "2" or button == "MiddleButton" and "3" or nil
        if suffix then
            local prefix = SecureCmdOptionParse("[mod:alt,ctrl,shift] alt-ctrl-shift-; [mod:alt,ctrl] alt-ctrl-; [mod:alt,shift] alt-shift-; [mod:ctrl,shift] ctrl-shift-; [mod:alt] alt-; [mod:ctrl] ctrl-; [mod:shift] shift-; [] none") or "none"
            if prefix == "none" then prefix = "" end
            local attr = prefix .. "macrotext" .. suffix
            local base = self:GetAttribute("drag-base-" .. attr)
            if base then self:SetAttribute(attr, base) end
        end
        if self:GetAttribute("drag-expanded") == 1 then
            -- Restore the compact hitbox to the button's ordinary parent.
            -- $parent is also a built-in restricted anchor, so no unprotected
            -- frame handle is involved.
            self:ClearAllPoints()
            self:SetAllPoints("$parent")
        end
        self:SetAttribute("drag-expanded", nil)
        self:SetAttribute("drag-active-prefix", nil)
        self:SetAttribute("drag-active-suffix", nil)
        self:SetAttribute("drag-selected-zone", nil)
    ]])

    local leftVisual = CreateChoiceVisual("BattleMapsCalloutChoice" .. index .. "Left")
    local rightVisual = CreateChoiceVisual("BattleMapsCalloutChoice" .. index .. "Right")
    local ui = {
        node = node,
        container = container,
        button = button,
        pin = nil,
        centerX = nil,
        centerY = nil,
        iconDistance = 24,
        visuals = {
            LeftButton = leftVisual,
            RightButton = rightVisual,
        },
    }

    self:ApplySecureAttributes(ui)

    button:SetScript("OnEnter", function()
        ui.suppressUntil = nil

        Callouts.hoveredUI = ui
        local mode = Callouts:GetCurrentModifierMode() or "NONE"
        Callouts.currentMode = mode

        if ui.pressActive and ui.pressButton then
            -- While a mouse button is held, the pressed action owns the whole
            -- hover presentation. Do not restore the opposite-button icon when
            -- re-entering the node or when modifier polling refreshes.
            local visual = ui.visuals and ui.visuals[ui.pressButton]
            local actionKey = ui.pressActionKey or Callouts:GetActionForMouseButton(ui.pressButton)
            if visual and actionKey then
                Callouts:SetChoiceAction(visual, actionKey)
                Callouts:HideChoiceVisuals(ui, visual)
                Callouts:SetBaseHoverSuppressed(ui, true)
                ui.pressInside = true
                Callouts:SetPressedState(ui, true, ui.pressButton)
                Callouts:UpdateHeldDragContext(ui)
            end
            return
        end

        -- Do not wait for IsMouseOver()/the polling pass to establish the
        -- initial hover actions. Show both left/right bindings immediately.
        local shown = Callouts:RefreshHoverChoices(ui, mode)
        Callouts:SetBaseHoverSuppressed(ui, shown)
    end)
    button:SetScript("OnLeave", function()
        if ui.pressActive then
            -- Once a valid callout press begins, keep its visual/preview armed
            -- until mouse-up even if the cursor leaves the objective. This is
            -- also the foundation for directional drag context gestures.
            ui.pressInside = false
            Callouts.hoveredUI = ui
            Callouts:SetBaseHoverSuppressed(ui, true)
            Callouts:SetPressedState(ui, true, ui.pressButton)
            Callouts:UpdateHeldDragContext(ui)
            return
        end
        Callouts:SetBaseHoverSuppressed(ui, false)
        Callouts:SetPressedState(ui, false, ui.pressButton)
        Callouts:HideChoiceVisuals(ui)
        Callouts:HideHeldPreview()
        if Callouts.hoveredUI == ui then
            Callouts.hoveredUI = nil
        end
    end)
    button:HookScript("OnMouseDown", function(_, mouseButton)
        if not Callouts:IsSupportedMouseButton(mouseButton) then return end
        local actionKey = Callouts:GetActionForMouseButton(mouseButton)
        if not actionKey then return end
        local visual = ui.visuals and ui.visuals[mouseButton]
        if visual then
            Callouts:SetChoiceAction(visual, actionKey)
            -- Hover previews both LMB/RMB actions, but once a button is
            -- depressed only that button's callout should remain visible.
            Callouts:HideChoiceVisuals(ui, visual)
        end
        ui.pressActive = true
        ui.pressButton = mouseButton
        ui.pressActionKey = actionKey
        ui.pressInside = true
        ui.pressOriginated = true
        local dragMap = BattleMaps.MapFrame and BattleMaps.MapFrame.frame
        ui.pressStartMapX, ui.pressStartMapY = GetMapMousePosition(dragMap)
        ui.dragContextKey = nil
        ui.dragContextText = ""
        Callouts:SetPressedState(ui, true, mouseButton)
        Callouts:UpdateHeldDragContext(ui)
    end)
    button:HookScript("OnMouseUp", function(selfButton, mouseButton)
        if not Callouts:IsSupportedMouseButton(mouseButton) or ui.pressButton ~= mouseButton then return end
        local inside = selfButton.IsMouseOver and selfButton:IsMouseOver() or false
        ui.pressInside = inside == true
        ui.pressActive = false
        Callouts:SetPressedState(ui, false, mouseButton)
        Callouts:HideHeldPreview()
        Callouts:HideDragContextOverlay()
        ui.pressButton = nil
        ui.pressActionKey = nil
        ui.pressStartMapX = nil
        ui.pressStartMapY = nil
        ui.dragContextKey = nil
        ui.dragContextText = nil
        if not ui.pressInside then
            ui.pressOriginated = false
            Callouts:HideChoiceVisuals(ui)
        end
    end)
    button:HookScript("PostClick", function(selfButton, mouseButton, down)
        if down or not Callouts:IsSupportedMouseButton(mouseButton) then return end

        -- When edge-drag context is enabled the secure button temporarily
        -- covers UIParent, so a release away from the source objective is a
        -- deliberate commit rather than a cancel. Without drag context we keep
        -- the classic release-over-the-objective requirement.
        local dragEnabled = Callouts:GetSettings().dragContextEnabled ~= false
        local validRelease = ui.pressOriginated == true
            and (dragEnabled or (selfButton.IsMouseOver and selfButton:IsMouseOver()))
        ui.pressOriginated = false
        if not validRelease then return end
        Callouts:HandleSecureCalloutClick(ui, mouseButton)
    end)
    return ui
end

function Callouts:CreateSecureNodeUIs()
    if next(self.nodeUIs) then return true end
    if InCombatLockdown and InCombatLockdown() then return false end
    for index, key in ipairs(NODE_ORDER) do
        self.nodeUIs[key] = self:CreateNodeUI(NODE_DEFS[key], index)
    end
    return true
end

function Callouts:RefreshSecureActions()
    if InCombatLockdown and InCombatLockdown() then
        self.pendingSecureRefresh = true
        return false
    end
    for _, key in ipairs(NODE_ORDER) do
        self:ApplySecureAttributes(self.nodeUIs[key])
    end
    self.pendingSecureRefresh = false
    return true
end

function Callouts:RequestSecureRefresh()
    if InCombatLockdown and InCombatLockdown() then
        self.pendingSecureRefresh = true
        return
    end
    self:RefreshSecureActions()
    self:ScanPins(false)
end

function Callouts:PlaceChoiceVisual(ui, mouseButton, posX)
    local visual = ui and ui.visuals and ui.visuals[mouseButton]
    if not visual then return end
    local iconSize = tonumber(ui.iconSize) or 1
    local visualY = tonumber(ui.visualY) or 0
    visual:SetSize(iconSize, iconSize)
    if visual.Content then visual.Content:SetSize(iconSize, iconSize) end
    visual:ClearAllPoints()
    visual:SetPoint("CENTER", UIParent, "BOTTOMLEFT", posX, visualY)
    if visual.Glow then
        visual.Glow:SetSize(iconSize * 1.55, iconSize * 1.55)
        if visual.Glow.Content then visual.Glow.Content:SetSize(iconSize * 1.55, iconSize * 1.55) end
        visual.Glow:ClearAllPoints()
        -- Keep auxiliary confirmation effects physically attached to their
        -- owning callout icon. They can animate independently, but can no
        -- longer drift into a stale left/right hover slot.
        visual.Glow:SetPoint("CENTER", visual, "CENTER")
    end
    if visual.PingFlipbook then
        local pingSize = iconSize * PING_FLIPBOOK_SCALE
        visual.PingFlipbook:SetSize(pingSize, pingSize)
        if visual.PingFlipbook.Content then visual.PingFlipbook.Content:SetSize(pingSize, pingSize) end
        visual.PingFlipbook:ClearAllPoints()
        visual.PingFlipbook:SetPoint("CENTER", visual, "CENTER")
    end
end

function Callouts:IsChoicePresentationLocked(visual)
    if not visual then return false end
    local untilTime = tonumber(visual.presentationUntil)
    if not untilTime then return false end
    if GetTime and GetTime() < untilTime then return true end
    visual.presentationUntil = nil
    return false
end

function Callouts:LayoutVisibleChoices(ui, pressedButton)
    if not ui then return end
    local centerX = tonumber(ui.visualX) or tonumber(ui.centerX) or 0
    local half = tonumber(ui.halfSeparation) or 0
    if pressedButton and ui.visuals and ui.visuals[pressedButton] then
        self:PlaceChoiceVisual(ui, pressedButton, centerX)
        return
    end

    -- Release feedback is a single-callout presentation. Keep the selected
    -- icon *and every effect belonging to it* locked to the objective centre
    -- until the longest confirmation effect has finished. This prevents pin
    -- rescans/layout refreshes from pushing the glow/flipbook back into the
    -- normal two-icon hover slots midway through the animation.
    for _, mouseButton in ipairs(HOVER_MOUSE_BUTTONS) do
        local visual = ui.visuals and ui.visuals[mouseButton]
        if self:IsChoicePresentationLocked(visual) then
            self:PlaceChoiceVisual(ui, mouseButton, centerX)
            return
        end
    end

    local visible = {}
    for _, mouseButton in ipairs(HOVER_MOUSE_BUTTONS) do
        local visual = ui.visuals and ui.visuals[mouseButton]
        if visual and visual:IsShown() and not visual.animationBusy then visible[#visible + 1] = mouseButton end
    end
    if #visible == 1 then
        self:PlaceChoiceVisual(ui, visible[1], centerX)
    elseif #visible >= 2 then
        self:PlaceChoiceVisual(ui, "LeftButton", centerX - half)
        self:PlaceChoiceVisual(ui, "RightButton", centerX + half)
    end
end

function Callouts:PositionChoiceVisual(ui, x, y, iconSize, offsetX, offsetY)
    if not ui then return end
    ui.centerX, ui.centerY = x, y
    ui.iconSize = iconSize
    ui.iconOffsetX = offsetX
    ui.iconOffsetY = offsetY
    ui.visualX = x + (tonumber(offsetX) or 0)
    ui.visualY = y + (tonumber(offsetY) or 0)
    ui.halfSeparation = iconSize * HOVER_ICON_HALF_SEPARATION

    -- Position updates can happen while the post-click confirmation is still
    -- running (map refresh, pin scan, zoom/pan). Respect the same centre lock
    -- used by LayoutVisibleChoices so auxiliary animation frames cannot jump
    -- back to the normal left/right hover positions.
    local lockedButton
    for _, mouseButton in ipairs(HOVER_MOUSE_BUTTONS) do
        local visual = ui.visuals and ui.visuals[mouseButton]
        if self:IsChoicePresentationLocked(visual) then
            lockedButton = mouseButton
            break
        end
    end
    if lockedButton then
        self:PlaceChoiceVisual(ui, lockedButton, ui.visualX)
    else
        self:PlaceChoiceVisual(ui, "LeftButton", ui.visualX - ui.halfSeparation)
        self:PlaceChoiceVisual(ui, "RightButton", ui.visualX + ui.halfSeparation)
    end
end

function Callouts:PositionNodeUI(ui, pin)
    if not ui or not ui.container or not pin then return false end
    if InCombatLockdown and InCombatLockdown() then return false end

    local x, y, ratio = GetPinScreenPosition(pin)
    if not x or not y then return false end
    local settings = self:GetSettings()
    local pinWidth = tonumber(pin.GetWidth and pin:GetWidth()) or 24
    local pinHeight = tonumber(pin.GetHeight and pin:GetHeight()) or 24
    local renderedWidth = math.max(1, pinWidth * (ratio or 1))
    local renderedHeight = math.max(1, pinHeight * (ratio or 1))

    -- The secure callout hitbox should match the visible base artwork, not the
    -- often-larger objective placement/hit frame. Use the same rendered texture
    -- dimensions that drive proportional callout icon sizing so hover begins
    -- and ends at the visible node boundary consistently across battlegrounds.
    local texture = pin.texture
    local textureWidth = texture and texture.GetWidth and tonumber(texture:GetWidth()) or nil
    local textureHeight = texture and texture.GetHeight and tonumber(texture:GetHeight()) or nil
    local visualWidth = textureWidth and textureWidth > 0 and (textureWidth * (ratio or 1)) or renderedWidth
    local visualHeight = textureHeight and textureHeight > 0 and (textureHeight * (ratio or 1)) or renderedHeight

    ui.container:ClearAllPoints()
    ui.container:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    ui.container:SetSize(math.max(1, visualWidth), math.max(1, visualHeight))
    if ui.pin and ui.pin ~= pin and ui.suppressedPin then
        self:SetBaseHoverSuppressed(ui, false)
    end
    ui.pin = pin

    -- Size callout artwork from the base pin's *visible texture*, not its hit
    -- frame. Blizzard/custom stationary POIs do not all use the same ratio of
    -- placement-frame size to rendered artwork. Measuring the texture makes
    -- the slider a true proportional control across maps: e.g. 50% remains
    -- half the visible base size regardless of the objective provider.
    local nodeReferenceSize = math.max(1, math.min(visualWidth, visualHeight))
    local iconSize = math.max(
        CHOICE_ICON_MIN_SIZE,
        nodeReferenceSize * Clamp(settings.iconScale, 0.25, 1.50)
    )
    self:PositionChoiceVisual(
        ui,
        x,
        y,
        iconSize,
        tonumber(settings.iconOffsetX) or 0,
        tonumber(settings.iconOffsetY) or 0
    )
    if self.hoveredUI == ui then
        if ui.suppressUntil and GetTime and GetTime() < ui.suppressUntil then
            self:SetBaseHoverSuppressed(ui, true)
        else
            local mode = self:GetCurrentModifierMode() or "NONE"
            local shown = self:RefreshHoverChoices(ui, mode)
            self:SetBaseHoverSuppressed(ui, shown)
        end
    end
    return true
end

function Callouts:SetNodeEnabled(ui, enabled)
    if not ui or not ui.container then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if enabled and self:GetSettings().enabled ~= false then
        ui.container:Show()
    else
        self:SetBaseHoverSuppressed(ui, false)
        if ui.pressActive then
            self:HideHeldPreview()
            self:HideDragContextOverlay()
        end
        ui.pressActive = false
        ui.pressButton = nil
        ui.pressActionKey = nil
        ui.container:Hide()
        ui.pin = nil
        for _, mouseButton in ipairs(HOVER_MOUSE_BUTTONS) do
            local visual = ui.visuals and ui.visuals[mouseButton]
            if visual then
                if visual.ConfirmAnimation and visual.ConfirmAnimation:IsPlaying() then
                    visual.ConfirmAnimation:Stop()
                end
                if visual.Glow and visual.Glow.Animation and visual.Glow.Animation:IsPlaying() then
                    visual.Glow.Animation:Stop()
                end
                if visual.PingFlipbook and visual.PingFlipbook.Animation
                    and visual.PingFlipbook.Animation:IsPlaying() then
                    visual.PingFlipbook.Animation:Stop()
                end
                visual:Hide()
                if visual.Glow then visual.Glow:Hide() end
                if visual.PingFlipbook then visual.PingFlipbook:Hide() end
            end
        end
    end
end

function Callouts:SetChoiceAction(visual, actionKey)
    if not visual or visual.animationBusy then return end
    visual.actionKey = actionKey
    local texturePath = self:GetActionTexture(actionKey)
    visual.Texture:SetTexture(texturePath)
    local color = ACTION_GLOW_COLORS[actionKey] or { 1, 1, 1 }
    if visual.Glow and visual.Glow.Texture then
        visual.Glow.Texture:SetTexture(texturePath)
        visual.Glow.Texture:SetVertexColor(color[1], color[2], color[3], 1)
    end
    if visual.PingFlipbook and visual.PingFlipbook.Texture then
        visual.PingFlipbook.Texture:SetVertexColor(color[1], color[2], color[3], 1)
    end

    -- Modifier polling runs every 0.05s. Preserve an active depressed state
    -- instead of resetting it on every action/texture refresh.
    local content = visual.Content or visual
    content:SetAlpha(1)
    if visual.pressed then
        content:SetScale(PRESS_SCALE)
        visual.Texture:SetVertexColor(0.78, 0.78, 0.78, 1)
    else
        content:SetScale(1)
        visual.Texture:SetVertexColor(1, 1, 1, 1)
    end
    visual:SetAlpha(1)
    visual:Show()
end

function Callouts:HideChoiceVisuals(ui, exceptVisual)
    if not ui then return end
    for _, mouseButton in ipairs(HOVER_MOUSE_BUTTONS) do
        local visual = ui.visuals and ui.visuals[mouseButton]
        if visual and visual ~= exceptVisual then
            if not visual.animationBusy then
                visual.pressed = false
                local content = visual.Content or visual
                content:SetScale(1)
                content:SetAlpha(1)
                visual:SetAlpha(1)
                visual.Texture:SetVertexColor(1, 1, 1, 1)
                visual:Hide()
            end
            if visual.Glow and visual.Glow.Animation and not visual.Glow.Animation:IsPlaying() then
                visual.Glow:Hide()
            end
            if visual.PingFlipbook and visual.PingFlipbook.Animation
                and not visual.PingFlipbook.Animation:IsPlaying() then
                visual.PingFlipbook:Hide()
            end
        end
    end
end

function Callouts:RefreshHoverChoices(ui, mode)
    if not ui then return false end
    mode = mode or self:GetCurrentModifierMode() or "NONE"
    local shown = false
    for _, mouseButton in ipairs(HOVER_MOUSE_BUTTONS) do
        local visual = ui.visuals and ui.visuals[mouseButton]
        local actionKey = self:GetActionForModeAndMouseButton(mode, mouseButton)
        if visual then
            if actionKey then
                self:SetChoiceAction(visual, actionKey)
                shown = true
            elseif not visual.animationBusy then
                visual.pressed = false
                local content = visual.Content or visual
                content:SetScale(1)
                content:SetAlpha(1)
                visual.Texture:SetVertexColor(1, 1, 1, 1)
                visual:Hide()
            end
        end
    end
    self:LayoutVisibleChoices(ui)
    return shown
end

function Callouts:FindHoveredNodeUI()
    if self:GetSettings().enabled == false then return nil, nil end
    local mode = self:GetCurrentModifierMode() or "NONE"
    for _, key in ipairs(NODE_ORDER) do
        local ui = self.nodeUIs[key]
        local button = ui and ui.button
        if ui and ui.pin and button and button:IsShown() and button.IsMouseOver and button:IsMouseOver() then
            return ui, mode
        end
    end
    return nil, mode
end

function Callouts:HandleGlobalMouseUp(mouseButton)
    if not self:IsSupportedMouseButton(mouseButton) then return end

    -- Per-button OnMouseUp/PostClick remains in charge while the secure drag
    -- hit target is expanded. GLOBAL_MOUSE_UP is only a safety cleanup for a
    -- press that did not remain captured by the protected button.
    for _, key in ipairs(NODE_ORDER) do
        local ui = self.nodeUIs[key]
        if ui and ui.pressActive then
            local button = ui.button
            local over = button and button.IsMouseOver and button:IsMouseOver()
            if not over then
                ui.pressActive = false
                local releasedButton = ui.pressButton
                ui.pressButton = nil
                ui.pressActionKey = nil
                ui.pressInside = false
                ui.pressOriginated = false
                self:SetPressedState(ui, false, releasedButton)
                self:HideHeldPreview()
                self:HideDragContextOverlay()
                ui.pressStartMapX = nil
                ui.pressStartMapY = nil
                ui.dragContextKey = nil
                ui.dragContextText = nil
                self:SetBaseHoverSuppressed(ui, false)
                self:HideChoiceVisuals(ui)
            end
        end
    end
end

function Callouts:UpdateModifierChoices()
    local activePressUI
    for _, key in ipairs(NODE_ORDER) do
        local candidate = self.nodeUIs[key]
        if candidate and candidate.pressActive and candidate.pressButton then
            activePressUI = candidate
            break
        end
    end
    if activePressUI then
        self.hoveredUI = activePressUI
        self.currentMode = self:GetCurrentModifierMode() or "NONE"
        local visual = activePressUI.visuals and activePressUI.visuals[activePressUI.pressButton]
        local actionKey = activePressUI.pressActionKey
        if visual and actionKey then
            self:SetChoiceAction(visual, actionKey)
            self:HideChoiceVisuals(activePressUI, visual)
            self:SetBaseHoverSuppressed(activePressUI, true)
            self:SetPressedState(activePressUI, true, activePressUI.pressButton)
            self:UpdateHeldDragContext(activePressUI)
        end
        return
    end

    local ui, mode = self:FindHoveredNodeUI()
    if self.hoveredUI and self.hoveredUI ~= ui then
        self:SetBaseHoverSuppressed(self.hoveredUI, false)
        if self.hoveredUI.pressActive then
            self.hoveredUI.pressInside = false
            self:SetPressedState(self.hoveredUI, false, self.hoveredUI.pressButton)
        else
            self:HideChoiceVisuals(self.hoveredUI)
        end
    end
    self.hoveredUI = ui
    self.currentMode = mode
    if not ui then
        self:HideHeldPreview()
        self:HideDragContextOverlay()
        return
    end

    if ui.suppressUntil and GetTime and GetTime() < ui.suppressUntil then
        -- During the release confirmation, keep the base hidden and let the
        -- chosen callout animation own the presentation.
        self:SetBaseHoverSuppressed(ui, true)
        return
    end

    if ui.pressActive and ui.pressButton then
        -- Modifier polling continues while the mouse is held. Keep the
        -- down-pressed presentation exclusive to the button that started the
        -- press instead of allowing the opposite hover icon to reappear.
        local visual = ui.visuals and ui.visuals[ui.pressButton]
        if visual then
            self:HideChoiceVisuals(ui, visual)
            self:SetBaseHoverSuppressed(ui, true)
            self:SetPressedState(ui, true, ui.pressButton)
            self:UpdateHeldDragContext(ui)
        end
        return
    end

    -- Show the left- and right-button actions simultaneously for the current
    -- modifier state. If neither button is bound, leave the base visible rather
    -- than replacing it with an empty hover state.
    local shown = self:RefreshHoverChoices(ui, mode)
    self:SetBaseHoverSuppressed(ui, shown)
end

function Callouts:SetPressedState(ui, pressed, mouseButton)
    local visual = ui and ui.visuals and ui.visuals[mouseButton]
    if not visual or visual.animationBusy or not visual:IsShown() then return end
    visual.pressed = pressed == true
    local content = visual.Content or visual
    if visual.pressed then
        self:LayoutVisibleChoices(ui, mouseButton)
        content:SetScale(PRESS_SCALE)
        visual.Texture:SetVertexColor(0.78, 0.78, 0.78, 1)
    else
        content:SetScale(1)
        visual.Texture:SetVertexColor(1, 1, 1, 1)
    end
end

function Callouts:PlayChosenConfirmation(visual, ui, actionKey)
    if not visual then return end

    if visual.ConfirmAnimation and visual.ConfirmAnimation:IsPlaying() then
        visual.ConfirmAnimation:Stop()
    end
    if visual.Glow and visual.Glow.Animation and visual.Glow.Animation:IsPlaying() then
        visual.Glow.Animation:Stop()
    end
    if visual.PingFlipbook and visual.PingFlipbook.Animation
        and visual.PingFlipbook.Animation:IsPlaying() then
        visual.PingFlipbook.Animation:Stop()
    end

    self:SetChoiceAction(visual, actionKey or visual.actionKey or "incoming")
    visual.pressed = false
    local content = visual.Content or visual
    content:SetScale(1)
    content:SetAlpha(1)
    visual.Texture:SetVertexColor(1, 1, 1, 1)

    if GetTime then
        -- The flipbook outlives the main icon fade. Lock the whole feedback
        -- stack to centre for the longest effect, not merely the icon fade.
        visual.presentationUntil = GetTime() + CONFIRM_PRESENTATION_DURATION
        if ui then
            ui.suppressUntil = visual.presentationUntil
        end
    end

    if visual.Glow and visual.Glow.Animation then
        visual.Glow.Animation:Play()
    end
    if visual.PingFlipbook and visual.PingFlipbook.Animation then
        visual.PingFlipbook.Animation:Play()
    end
    if visual.ConfirmAnimation then
        visual.ConfirmAnimation:Play()
    else
        visual:Hide()
    end
end

function Callouts:HandleSecureCalloutClick(ui, mouseButton)
    if not ui or not self:IsSupportedMouseButton(mouseButton) then return end
    local actionKey = self:GetActionForMouseButton(mouseButton)
    if not actionKey then return end
    local visual = ui.visuals and ui.visuals[mouseButton]
    if not visual then return end

    -- Once a click is committed, leave only the chosen callout on screen so
    -- the release confirmation reads as feedback for that exact mouse button.
    self:HideChoiceVisuals(ui, visual)
    self:PlayChosenConfirmation(visual, ui, actionKey)
end

function Callouts:ScanPins(printResults)
    local pins = BattleMaps and BattleMaps.Pins
    if not pins then return 0 end
    local settings = self:GetSettings()
    local found, seen, bestPinByNode = 0, {}, {}
    local collections = { pins.poiPins, pins.scenarioPins, pins.vignettePins, pins.dummyStationaryPins }

    for _, collection in ipairs(collections) do
        if type(collection) == "table" then
            for _, pin in pairs(collection) do
                if pin and not seen[pin] then
                    seen[pin] = true
                    local node = ResolveNode(pin.tooltipTitle)
                    if node and pin.IsShown and pin:IsShown() then
                        found = found + 1
                        if not bestPinByNode[node.key] then bestPinByNode[node.key] = pin end
                        if printResults and BattleMaps.Chat then
                            BattleMaps.Chat("Callout node: " .. node.display .. " [" .. node.mapDisplay .. "]")
                        end
                    end
                end
            end
        end
    end

    if not (InCombatLockdown and InCombatLockdown()) then
        for _, key in ipairs(NODE_ORDER) do
            local ui = self.nodeUIs[key]
            local pin = bestPinByNode[key]
            if ui and pin and settings.enabled ~= false then
                self:PositionNodeUI(ui, pin)
                self:SetNodeEnabled(ui, true)
            elseif ui then
                self:SetNodeEnabled(ui, false)
            end
        end
    end
    return found
end


function Callouts:Initialize()
    if self.initialized then return true end
    if not BattleMaps.Pins then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    self:GetSettings()
    if not self:CreateSecureNodeUIs() then return false end
    self.initialized = true
    self:ScanPins(false)
    return true
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:RegisterEvent("PLAYER_REGEN_DISABLED")
driver:RegisterEvent("MODIFIER_STATE_CHANGED")
driver:RegisterEvent("GLOBAL_MOUSE_UP")
driver:SetScript("OnEvent", function(_, event, mouseButton)
    Callouts:Initialize()
    if event == "GLOBAL_MOUSE_UP" then
        Callouts:HandleGlobalMouseUp(mouseButton)
        return
    end
    if event == "PLAYER_REGEN_ENABLED" and Callouts.pendingSecureRefresh then
        Callouts:RefreshSecureActions()
    end
    if event ~= "MODIFIER_STATE_CHANGED" then
        Callouts:ScanPins(false)
    end
    Callouts:UpdateModifierChoices()
end)

driver:SetScript("OnUpdate", function(_, elapsed)
    elapsed = tonumber(elapsed) or 0
    Callouts.choiceAccumulator = (Callouts.choiceAccumulator or 0) + elapsed
    if Callouts.choiceAccumulator >= 0.05 then
        Callouts.choiceAccumulator = 0
        if Callouts.initialized then Callouts:UpdateModifierChoices() end
    end

    Callouts.scanAccumulator = (Callouts.scanAccumulator or 0) + elapsed
    if Callouts.scanAccumulator < 0.50 then return end
    Callouts.scanAccumulator = 0
    if not Callouts.initialized then Callouts:Initialize() end
    if Callouts.initialized then Callouts:ScanPins(false) end
end)
