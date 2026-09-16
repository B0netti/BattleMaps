local _, BattleMaps = ...
BattleMaps = BattleMaps or _G.BattleMaps
if not BattleMaps or not BattleMaps.Callouts then return end

local Callouts = BattleMaps.Callouts

-- Purely visual feedback for the existing secure edge-drag callout gesture.
-- This module deliberately does not touch the secure click target or macro
-- selection path; it only follows the state already maintained by Callouts.
Callouts.DEFAULTS.showDragTether = true
Callouts.DEFAULTS.previewMode = "CURSOR"
-- Legacy aliases retained so older profiles migrate without a visible change.
Callouts.DEFAULTS.showDragPreview = true
Callouts.DEFAULTS.showCenterPreview = false

local CURSOR_PREVIEW_OFFSET_Y = 18
local TETHER_FADE_START = 10
local TETHER_FADE_END = 82
local TETHER_CORE_THICKNESS = 2.0
local TETHER_GLOW_THICKNESS = 5.0
local TETHER_ACTIVE_CORE_THICKNESS = 4.0
local TETHER_ACTIVE_GLOW_THICKNESS = 9.0
local TETHER_CORE_ALPHA = 0.74
local TETHER_GLOW_ALPHA = 0.24
local TETHER_ACTIVE_CORE_ALPHA = 0.94
local TETHER_ACTIVE_GLOW_ALPHA = 0.34

local VALID_PREVIEW_MODES = {
    OFF = true,
    CURSOR = true,
    CENTER = true,
    NOTIFICATIONS = true,
}

local FALLBACK_ACTION_COLORS = {
    incoming = { 1.00, 0.28, 0.10 },
    attack = { 1.00, 0.18, 0.10 },
    defend = { 0.25, 0.62, 1.00 },
    clear = { 0.30, 1.00, 0.42 },
    custom1 = { 1.00, 0.70, 0.18 },
    custom2 = { 0.72, 0.42, 1.00 },
}

local function Clamp01(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function HasText(value)
    return tostring(value or ""):match("%S") ~= nil
end

local function HasAnyConfiguredContext(actionKey)
    if not actionKey or type(Callouts.GetActionContexts) ~= "function" then return false end
    local contexts = Callouts:GetActionContexts(actionKey)
    if type(contexts) ~= "table" then return false end
    for _, key in ipairs({ "TOP", "RIGHT", "BOTTOM", "LEFT" }) do
        if HasText(contexts[key]) then return true end
    end
    return false
end

local function GetCursorUIPosition()
    if type(GetCursorPosition) ~= "function" or not UIParent then return nil, nil end
    local x, y = GetCursorPosition()
    local scale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    scale = tonumber(scale) or 1
    if scale <= 0 then scale = 1 end
    return (tonumber(x) or 0) / scale, (tonumber(y) or 0) / scale
end

function Callouts:GetPreviewMode()
    local settings = self:GetSettings()
    local mode = tostring(settings.previewMode or ""):upper()
    if VALID_PREVIEW_MODES[mode] then return mode end

    -- One-time compatibility interpretation for builds that exposed the two
    -- preview checkboxes separately. Centre took precedence if both were set.
    if settings.showCenterPreview == true then
        return "CENTER"
    elseif settings.showDragPreview ~= false then
        return "CURSOR"
    end
    return "OFF"
end

function Callouts:SetPreviewMode(mode)
    local settings = self:GetSettings()
    mode = tostring(mode or "OFF"):upper()
    if not VALID_PREVIEW_MODES[mode] then mode = "OFF" end
    settings.previewMode = mode

    -- Keep legacy fields coherent for users moving between test builds.
    settings.showDragPreview = mode == "CURSOR"
    settings.showCenterPreview = mode == "CENTER"

    if self.RefreshDragFeedbackSettings then self:RefreshDragFeedbackSettings() end
    if self.RefreshSelectedPreviewSettings then self:RefreshSelectedPreviewSettings() end
end

function Callouts:GetFeedbackActionColor(ui)
    local visual = ui and ui.visuals and ui.visuals[ui.pressButton]
    local texture = visual and visual.Glow and visual.Glow.Texture
    if texture and type(texture.GetVertexColor) == "function" then
        local ok, r, g, b = pcall(texture.GetVertexColor, texture)
        if ok and tonumber(r) and tonumber(g) and tonumber(b) then
            return tonumber(r), tonumber(g), tonumber(b)
        end
    end

    local color = FALLBACK_ACTION_COLORS[ui and ui.pressActionKey] or { 1, 1, 1 }
    return color[1], color[2], color[3]
end

function Callouts:EnsureDragFeedbackOverlay()
    if self.dragFeedbackFrame then return self.dragFeedbackFrame end
    if not UIParent or type(UIParent.CreateLine) ~= "function" then return nil end

    local frame = CreateFrame("Frame", "BattleMapsCalloutDragFeedback", UIParent)
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(1900)
    frame:EnableMouse(false)
    frame:Hide()

    local cursorAnchor = CreateFrame("Frame", nil, frame)
    cursorAnchor:SetSize(1, 1)
    cursorAnchor:EnableMouse(false)
    frame.cursorAnchor = cursorAnchor

    -- Match the carried-objective trail language: a crisp additive core plus
    -- a wider, softer additive halo. Thickness changes at context activation
    -- instead of introducing a separate effect family.
    local glow = frame:CreateLine(nil, "ARTWORK", nil, 0)
    glow:SetThickness(TETHER_GLOW_THICKNESS)
    if glow.SetBlendMode then glow:SetBlendMode("ADD") end
    glow:Hide()
    frame.glowLine = glow

    local core = frame:CreateLine(nil, "OVERLAY", nil, 1)
    core:SetThickness(TETHER_CORE_THICKNESS)
    if core.SetBlendMode then core:SetBlendMode("ADD") end
    core:Hide()
    frame.coreLine = core

    local preview = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    preview:SetJustifyH("CENTER")
    preview:SetJustifyV("BOTTOM")
    if preview.SetShadowColor then preview:SetShadowColor(0, 0, 0, 1) end
    if preview.SetShadowOffset then preview:SetShadowOffset(1, -1) end
    preview:Hide()
    frame.previewText = preview

    frame:SetScript("OnUpdate", function()
        local ui = frame.activeUI
        if not ui or ui.pressActive ~= true then
            Callouts:HideDragFeedback()
            return
        end
        Callouts:UpdateDragFeedback(ui)
    end)

    self.dragFeedbackFrame = frame
    return frame
end

-- Hide only the tether/cursor-feedback layer. This deliberately does not call
-- the public HideDragFeedback method because later preview modules wrap that
-- method to also hide centre/notification previews. During an active press we
-- may have no tether and no cursor preview while still needing a selected
-- preview mode (especially Same as Notifications) to remain continuously shown.
local function HideDragFeedbackVisualsOnly(self)
    local frame = self.dragFeedbackFrame
    if not frame then return end
    frame.activeUI = nil
    frame.showTether = nil
    frame.showPreview = nil
    if frame.coreLine then frame.coreLine:Hide() end
    if frame.glowLine then frame.glowLine:Hide() end
    if frame.previewText then frame.previewText:Hide() end
    frame:Hide()
end

function Callouts:HideDragFeedback()
    HideDragFeedbackVisualsOnly(self)
end

function Callouts:UpdateDragFeedback(ui)
    local frame = self.dragFeedbackFrame
    if not frame or not ui or ui.pressActive ~= true then
        self:HideDragFeedback()
        return
    end

    local cursorX, cursorY = GetCursorUIPosition()
    if not cursorX or not cursorY then
        if frame.coreLine then frame.coreLine:Hide() end
        if frame.glowLine then frame.glowLine:Hide() end
        if frame.previewText then frame.previewText:Hide() end
        return
    end

    frame.cursorAnchor:ClearAllPoints()
    frame.cursorAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX, cursorY)

    local originX, originY
    if ui.container and type(ui.container.GetCenter) == "function" then
        originX, originY = ui.container:GetCenter()
    end
    originX = tonumber(originX) or tonumber(ui.centerX)
    originY = tonumber(originY) or tonumber(ui.centerY)
    if not originX or not originY then
        if frame.coreLine then frame.coreLine:Hide() end
        if frame.glowLine then frame.glowLine:Hide() end
        if frame.previewText then frame.previewText:Hide() end
        return
    end

    local dx, dy = cursorX - originX, cursorY - originY
    local distance = math.sqrt((dx * dx) + (dy * dy))
    local fadeRange = math.max(1, TETHER_FADE_END - TETHER_FADE_START)
    local fade = Clamp01((distance - TETHER_FADE_START) / fadeRange)
    fade = fade * fade * (3 - (2 * fade))

    local contextText = tostring(ui.dragContextText or "")
    local activeContext = ui.dragContextKey ~= nil
        and ui.dragContextKey ~= ""
        and HasText(contextText)
    local r, g, b = self:GetFeedbackActionColor(ui)

    if frame.showTether and fade > 0 then
        local coreThickness = activeContext and TETHER_ACTIVE_CORE_THICKNESS or TETHER_CORE_THICKNESS
        local glowThickness = activeContext and TETHER_ACTIVE_GLOW_THICKNESS or TETHER_GLOW_THICKNESS
        local coreAlpha = (activeContext and TETHER_ACTIVE_CORE_ALPHA or TETHER_CORE_ALPHA) * fade
        local glowAlpha = (activeContext and TETHER_ACTIVE_GLOW_ALPHA or TETHER_GLOW_ALPHA) * fade

        frame.glowLine:ClearAllPoints()
        frame.glowLine:SetStartPoint("CENTER", ui.container, 0, 0)
        frame.glowLine:SetEndPoint("CENTER", frame.cursorAnchor, 0, 0)
        frame.glowLine:SetThickness(glowThickness)
        if frame.glowLine.SetBlendMode then frame.glowLine:SetBlendMode("ADD") end
        frame.glowLine:SetColorTexture(r, g, b, glowAlpha)
        frame.glowLine:Show()

        frame.coreLine:ClearAllPoints()
        frame.coreLine:SetStartPoint("CENTER", ui.container, 0, 0)
        frame.coreLine:SetEndPoint("CENTER", frame.cursorAnchor, 0, 0)
        frame.coreLine:SetThickness(coreThickness)
        if frame.coreLine.SetBlendMode then frame.coreLine:SetBlendMode("ADD") end
        frame.coreLine:SetColorTexture(r, g, b, coreAlpha)
        frame.coreLine:Show()
    else
        frame.glowLine:Hide()
        frame.coreLine:Hide()
    end

    local previewText = ""
    if type(self.GetCalloutPreviewText) == "function" then
        previewText = tostring(self:GetCalloutPreviewText(ui.pressActionKey, ui.node, contextText) or "")
    end
    if frame.showPreview and previewText ~= "" then
        frame.previewText:ClearAllPoints()
        frame.previewText:SetPoint("BOTTOM", frame.cursorAnchor, "TOP", 0, CURSOR_PREVIEW_OFFSET_Y)
        frame.previewText:SetText(previewText)
        frame.previewText:SetTextColor(r, g, b, 1)
        frame.previewText:Show()
    else
        frame.previewText:Hide()
    end
end

function Callouts:ActivateDragFeedback(ui)
    local settings = self:GetSettings()
    if not ui or ui.pressActive ~= true or settings.dragContextEnabled == false then
        self:HideDragFeedback()
        return
    end

    local showTether = settings.showDragTether ~= false
        and HasAnyConfiguredContext(ui.pressActionKey)
    local showPreview = self:GetPreviewMode() == "CURSOR"
    if not showTether and not showPreview then
        -- The press is still active; only this module has nothing to draw.
        -- Do not invoke the public cleanup path here, because Same as
        -- Notifications / Center screen may still be the selected preview.
        HideDragFeedbackVisualsOnly(self)
        return
    end

    local frame = self:EnsureDragFeedbackOverlay()
    if not frame then return end
    frame.activeUI = ui
    frame.showTether = showTether
    frame.showPreview = showPreview
    frame:Show()
    self:UpdateDragFeedback(ui)
end

function Callouts:RefreshDragFeedbackSettings()
    local frame = self.dragFeedbackFrame
    if frame and frame.activeUI and frame.activeUI.pressActive == true then
        self:ActivateDragFeedback(frame.activeUI)
    elseif frame and self:GetPreviewMode() ~= "CURSOR" then
        if frame.previewText then frame.previewText:Hide() end
    end
end

-- The core callout module still tracks the nearest crossed edge even when the
-- configured string is blank, because the secure macro path needs a stable
-- directional selection. Suppress only the visual edge glow in that case.
local OriginalShowDragContextOverlay = Callouts.ShowDragContextOverlay
if type(OriginalShowDragContextOverlay) == "function" then
    function Callouts:ShowDragContextOverlay(activeKey, actionKey)
        if activeKey and type(self.GetDragContextText) == "function" then
            local text = self:GetDragContextText(activeKey, actionKey)
            if not HasText(text) then activeKey = nil end
        end
        return OriginalShowDragContextOverlay(self, activeKey, actionKey)
    end
end

local OriginalUpdateHeldDragContext = Callouts.UpdateHeldDragContext
if type(OriginalUpdateHeldDragContext) == "function" then
    function Callouts:UpdateHeldDragContext(ui)
        local key, contextText = OriginalUpdateHeldDragContext(self, ui)
        if ui and ui.pressActive == true then
            self:ActivateDragFeedback(ui)
        else
            self:HideDragFeedback()
        end
        return key, contextText
    end
end

local OriginalHideHeldPreview = Callouts.HideHeldPreview
function Callouts:HideHeldPreview(...)
    if type(OriginalHideHeldPreview) == "function" then
        OriginalHideHeldPreview(self, ...)
    end
    self:HideDragFeedback()
end
