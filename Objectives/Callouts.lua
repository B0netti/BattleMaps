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
BattleMaps.BUILD = tostring(BattleMaps.VERSION or packageVersion or "3.0.8")

Callouts.DEFAULTS = {
    enabled = true,
    iconScale = 1.00,
    iconOffsetX = 0,
    iconOffsetY = 0,
    layoutVersion = 2,
    messages = {
        incoming = "INC [node]",
        attack = "ATTACK [node]",
        defend = "DEF [node_full]",
        clear = "[node] CLEAR",
    },
}

Callouts.ACTION_ORDER = { "incoming", "attack", "defend", "clear" }
Callouts.ACTION_LABELS = {
    incoming = "Incoming",
    attack = "Attack",
    defend = "Defend",
    clear = "Clear",
}
Callouts.ACTION_TEXTURES = {
    incoming = "Interface\\AddOns\\BattleMaps\\Media\\Callouts\\INC.tga",
    attack = "Interface\\AddOns\\BattleMaps\\Media\\Callouts\\ATTACK.tga",
    defend = "Interface\\AddOns\\BattleMaps\\Media\\Callouts\\DEFEND.tga",
    clear = "Interface\\AddOns\\BattleMaps\\Media\\Callouts\\CLEAR.tga",
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
local CHOICE_ICON_MIN_SIZE = 1

local ACTION_GLOW_COLORS = {
    incoming = { 1.00, 0.28, 0.10 },
    attack = { 1.00, 0.18, 0.10 },
    defend = { 0.25, 0.62, 1.00 },
    clear = { 0.30, 1.00, 0.42 },
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

local MODE_ACTIONS = {
    NONE = "incoming",
    ALT = "attack",
    SHIFT = "defend",
    CTRL = "clear",
}
local MODE_BINDING_LABELS = {
    NONE = "Click",
    ALT = "Alt + Click",
    SHIFT = "Shift + Click",
    CTRL = "Ctrl + Click",
}

function Callouts:GetActionBindingLabel(actionKey)
    for mode, mappedActionKey in pairs(MODE_ACTIONS) do
        if mappedActionKey == actionKey then
            return MODE_BINDING_LABELS[mode] or ""
        end
    end
    return ""
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
    if IsAltKeyDown and IsAltKeyDown() then return "ALT" end
    if IsShiftKeyDown and IsShiftKeyDown() then return "SHIFT" end
    if IsControlKeyDown and IsControlKeyDown() then return "CTRL" end
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
    return {
        ["macrotext1"] = "/instance " .. self:ResolveMessage("incoming", node),
        ["alt-macrotext1"] = "/instance " .. self:ResolveMessage("attack", node),
        ["shift-macrotext1"] = "/instance " .. self:ResolveMessage("defend", node),
        ["ctrl-macrotext1"] = "/instance " .. self:ResolveMessage("clear", node),
    }
end

function Callouts:ApplySecureAttributes(ui)
    if not ui or not ui.button then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local callouts = self:BuildCallouts(ui.node)
    for attribute, value in pairs(callouts) do
        ui.button:SetAttribute(attribute:gsub("macrotext", "type"), "macro")
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

function Callouts:CreateNodeUI(node, index)
    local container = CreateFrame("Frame", "BattleMapsCalloutContainer" .. index, UIParent)
    container:SetSize(32, 32)
    container:SetFrameStrata("DIALOG")
    container:Hide()

    local button = CreateFrame("Button", "BattleMapsCalloutNode" .. index, container, "SecureActionButtonTemplate")
    button:SetAllPoints(container)
    button:SetFrameStrata("DIALOG")
    -- The secure macro is release-triggered only. Mouse-down remains purely
    -- visual, matching a normal button and allowing release outside to cancel.
    button:RegisterForClicks("LeftButtonUp")
    button:SetAttribute("useOnKeyDown", false)
    button:Show()

    local ui = {
        node = node,
        container = container,
        button = button,
        pin = nil,
        centerX = nil,
        centerY = nil,
        iconDistance = 24,
        visual = CreateChoiceVisual("BattleMapsCalloutChoice" .. index),
    }

    self:ApplySecureAttributes(ui)

    button:SetScript("OnEnter", function()
        ui.suppressUntil = nil

        -- Do not wait for IsMouseOver()/the polling pass to establish the
        -- initial hover action. Plain objective hover is the primary INC
        -- interaction, so show it immediately and then let modifier events
        -- replace it with Attack / Defend / Clear as appropriate.
        Callouts.hoveredUI = ui
        local mode = Callouts:GetCurrentModifierMode() or "NONE"
        Callouts.currentMode = mode
        local actionKey = MODE_ACTIONS[mode] or MODE_ACTIONS.NONE or "incoming"
        Callouts:SetChoiceAction(ui.visual, actionKey)
        Callouts:SetBaseHoverSuppressed(ui, true)

        -- Standard button behaviour: if the pointer re-enters while the same
        -- left-button press is still held, depress the visual again.
        if ui.pressActive then
            ui.pressInside = true
            Callouts:SetPressedState(ui, true)
        end
    end)
    button:SetScript("OnLeave", function()
        Callouts:SetBaseHoverSuppressed(ui, false)
        if ui.pressActive then
            -- Keep the icon visible but pop it back up while the held press is
            -- outside the clickable zone. Releasing here cancels the click.
            ui.pressInside = false
            Callouts:SetPressedState(ui, false)
        else
            Callouts:SetPressedState(ui, false)
            Callouts:HideChoiceVisuals(ui)
        end
        if Callouts.hoveredUI == ui then
            Callouts.hoveredUI = nil
        end
    end)
    button:SetScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            ui.pressActive = true
            ui.pressInside = true
            ui.pressOriginated = true
            Callouts:SetPressedState(ui, true)
        end
    end)
    button:SetScript("OnMouseUp", function(selfButton, mouseButton)
        if mouseButton == "LeftButton" then
            local inside = selfButton.IsMouseOver and selfButton:IsMouseOver() or false
            ui.pressInside = inside == true
            ui.pressActive = false
            Callouts:SetPressedState(ui, false)
            if not ui.pressInside then
                ui.pressOriginated = false
                Callouts:HideChoiceVisuals(ui)
            end
        end
    end)
    button:SetScript("PostClick", function(selfButton, mouseButton, down)
        if down or mouseButton ~= "LeftButton" then return end

        -- Only confirm the local animation for a press that started on this
        -- button and was released over its clickable region. The secure action
        -- itself is registered for LeftButtonUp only, so release outside is
        -- canceled by the normal Button click semantics as well.
        local validRelease = ui.pressOriginated == true
            and selfButton.IsMouseOver and selfButton:IsMouseOver()
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

function Callouts:PositionChoiceVisual(ui, x, y, iconSize, offsetX, offsetY)
    if not ui then return end
    ui.centerX, ui.centerY = x, y
    ui.iconSize = iconSize
    ui.iconOffsetX = offsetX
    ui.iconOffsetY = offsetY

    local visualX = x + (tonumber(offsetX) or 0)
    local visualY = y + (tonumber(offsetY) or 0)

    if ui.visual then
        ui.visual:SetSize(iconSize, iconSize)
        if ui.visual.Content then ui.visual.Content:SetSize(iconSize, iconSize) end
        ui.visual:ClearAllPoints()
        ui.visual:SetPoint("CENTER", UIParent, "BOTTOMLEFT", visualX, visualY)

        if ui.visual.Glow then
            ui.visual.Glow:SetSize(iconSize * 1.55, iconSize * 1.55)
            if ui.visual.Glow.Content then
                ui.visual.Glow.Content:SetSize(iconSize * 1.55, iconSize * 1.55)
            end
            ui.visual.Glow:ClearAllPoints()
            ui.visual.Glow:SetPoint("CENTER", UIParent, "BOTTOMLEFT", visualX, visualY)
        end
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
        self:SetBaseHoverSuppressed(ui, true)
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
        ui.container:Hide()
        ui.pin = nil
        if ui.visual and not ui.visual.animationBusy then ui.visual:Hide() end
    end
end

function Callouts:SetChoiceAction(visual, actionKey)
    if not visual or visual.animationBusy then return end
    visual.actionKey = actionKey
    local texturePath = self:GetActionTexture(actionKey)
    visual.Texture:SetTexture(texturePath)
    if visual.Glow and visual.Glow.Texture then
        visual.Glow.Texture:SetTexture(texturePath)
        local color = ACTION_GLOW_COLORS[actionKey] or { 1, 1, 1 }
        visual.Glow.Texture:SetVertexColor(color[1], color[2], color[3], 1)
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

function Callouts:HideChoiceVisuals(ui)
    if not ui then return end
    if ui.visual and not ui.visual.animationBusy then
        ui.visual.pressed = false
        local content = ui.visual.Content or ui.visual
        content:SetScale(1)
        content:SetAlpha(1)
        ui.visual:SetAlpha(1)
        ui.visual.Texture:SetVertexColor(1, 1, 1, 1)
        ui.visual:Hide()
    end
    if ui.visual and ui.visual.Glow and ui.visual.Glow.Animation
        and not ui.visual.Glow.Animation:IsPlaying() then
        ui.visual.Glow:Hide()
    end
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
    if mouseButton ~= "LeftButton" then return end

    -- Per-button OnMouseUp/PostClick is intentionally left in charge when the
    -- pointer is still over the button. GLOBAL_MOUSE_UP only cleans up presses
    -- that ended outside, where the secure click must be canceled.
    for _, key in ipairs(NODE_ORDER) do
        local ui = self.nodeUIs[key]
        if ui and ui.pressActive then
            local button = ui.button
            local over = button and button.IsMouseOver and button:IsMouseOver()
            if not over then
                ui.pressActive = false
                ui.pressInside = false
                ui.pressOriginated = false
                self:SetPressedState(ui, false)
                self:SetBaseHoverSuppressed(ui, false)
                self:HideChoiceVisuals(ui)
            end
        end
    end
end

function Callouts:UpdateModifierChoices()
    local ui, mode = self:FindHoveredNodeUI()
    if self.hoveredUI and self.hoveredUI ~= ui then
        self:SetBaseHoverSuppressed(self.hoveredUI, false)
        if self.hoveredUI.pressActive then
            self.hoveredUI.pressInside = false
            self:SetPressedState(self.hoveredUI, false)
        else
            self:HideChoiceVisuals(self.hoveredUI)
        end
    end
    self.hoveredUI = ui
    self.currentMode = mode
    if not ui then return end

    -- Refreshes in the objective provider can reapply the configured base
    -- opacity while the pointer remains over the node. Reassert suppression on
    -- the same light 0.05s hover pass that already updates modifier choices.
    self:SetBaseHoverSuppressed(ui, true)

    if ui.suppressUntil and GetTime and GetTime() < ui.suppressUntil then
        return
    end

    local actionKey = MODE_ACTIONS[mode] or MODE_ACTIONS.NONE
    if not actionKey then
        self:HideChoiceVisuals(ui)
        return
    end
    self:SetChoiceAction(ui.visual, actionKey)
end

function Callouts:SetPressedState(ui, pressed)
    local visual = ui and ui.visual
    if not visual or visual.animationBusy or not visual:IsShown() then return end
    visual.pressed = pressed == true
    local content = visual.Content or visual
    if visual.pressed then
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

    self:SetChoiceAction(visual, actionKey or visual.actionKey or "incoming")
    visual.pressed = false
    local content = visual.Content or visual
    content:SetScale(1)
    content:SetAlpha(1)
    visual.Texture:SetVertexColor(1, 1, 1, 1)

    if ui and GetTime then
        ui.suppressUntil = GetTime() + CONFIRM_HOLD_DURATION + CONFIRM_FADE_DURATION
    end

    if visual.Glow and visual.Glow.Animation then
        visual.Glow.Animation:Play()
    end
    if visual.ConfirmAnimation then
        visual.ConfirmAnimation:Play()
    else
        visual:Hide()
    end
end

function Callouts:HandleSecureCalloutClick(ui, mouseButton)
    if not ui or mouseButton ~= "LeftButton" then return end
    local mode = self:GetCurrentModifierMode() or "NONE"
    local actionKey = MODE_ACTIONS[mode] or MODE_ACTIONS.NONE
    if not actionKey then return end
    self:PlayChosenConfirmation(ui.visual, ui, actionKey)
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
