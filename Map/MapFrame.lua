local _, BattleMaps = ...

local MapFrame = {
    currentMapID = nil,
    selectedMapID = nil,
    editMode = false,
    previewMode = false,
    testMode = false,
    draggingMap = false,
    chromeRequested = false,
    contextMenu = nil,
    nativeContextMenu = nil,
    contextMenuDismissLayer = nil,
    worldMapMode = false,
    worldMapContainer = nil,
    worldMapRestoreState = nil,
    worldMapOverlay = nil,
    worldMapTransientView = nil,
    worldMapTransientViewMapID = nil,
}
BattleMaps.MapFrame = MapFrame

-- Dedicated FoV parents allow authored passes below and above the map artwork
-- while leaving the ordinary objective and unit pin layer above both.
local FOV_LAYER_LEVEL_OFFSET = 1
local MAP_CANVAS_LEVEL_OFFSET = 10
local FOV_OVERLAY_LAYER_LEVEL_OFFSET = 15
local PIN_LAYER_LEVEL_OFFSET = 20

local function GetTemplate()
    return BackdropTemplateMixin and "BackdropTemplate" or nil
end

local function CaptureFramePoints(frame)
    local points = {}
    if not frame or not frame.GetNumPoints or not frame.GetPoint then return points end

    for index = 1, frame:GetNumPoints() do
        local point, relativeTo, relativePoint, offsetX, offsetY = frame:GetPoint(index)
        points[#points + 1] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            offsetX = offsetX,
            offsetY = offsetY,
        }
    end
    return points
end

local function RestoreFramePoints(frame, points)
    if not frame then return end
    frame:ClearAllPoints()

    for _, placement in ipairs(points or {}) do
        frame:SetPoint(
            placement.point or "CENTER",
            placement.relativeTo or UIParent,
            placement.relativePoint or placement.point or "CENTER",
            tonumber(placement.offsetX) or 0,
            tonumber(placement.offsetY) or 0
        )
    end

    if not points or #points == 0 then
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function CaptureFrameTreeLevels(root)
    local entries = {}
    local function Capture(frame)
        if not frame or not frame.GetFrameLevel then return end
        entries[#entries + 1] = {
            frame = frame,
            level = frame:GetFrameLevel(),
        }
        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do
                Capture(child)
            end
        end
    end
    Capture(root)
    return entries
end

local function ShiftCapturedFrameTreeLevels(entries, delta)
    delta = math.floor(tonumber(delta) or 0)
    for _, entry in ipairs(entries or {}) do
        local frame = entry.frame
        if frame and frame.SetFrameLevel then
            pcall(frame.SetFrameLevel, frame, math.max(0, (entry.level or 0) + delta))
        end
    end
end

local BORDER_STYLES = {
    solid = {
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = function(size) return math.max(1, size) end,
    },
    tooltip = {
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = function(size) return math.max(8, size * 3) end,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    },
    dialog = {
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = function(size) return math.max(10, size * 4) end,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    },
}

local function GetBorderStyle(style)
    return BORDER_STYLES[style or ""] or BORDER_STYLES.solid
end

local function SetBackdrop(frame, borderSize, borderStyle)
    if not frame.SetBackdrop then return end
    borderSize = BattleMaps.Clamp(tonumber(borderSize) or 2, 0, 8)

    local backdrop = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
    }
    if borderSize > 0 then
        local style = GetBorderStyle(borderStyle)
        backdrop.edgeFile = style.edgeFile
        backdrop.edgeSize = style.edgeSize(borderSize)
        backdrop.insets = style.insets
    end

    frame:SetBackdrop(backdrop)
    frame:SetBackdropColor(0.03, 0.025, 0.02, 0)
    frame:SetBackdropBorderColor(0.25, 0.20, 0.15, borderSize > 0 and 1 or 0)
end

local function GetFrameBackgroundColor(db)
    local color = type(db and db.frameBackgroundColor) == "table" and db.frameBackgroundColor or {}
    return BattleMaps.Clamp(tonumber(color.r or color[1]) or 0.015, 0, 1),
        BattleMaps.Clamp(tonumber(color.g or color[2]) or 0.015, 0, 1),
        BattleMaps.Clamp(tonumber(color.b or color[3]) or 0.015, 0, 1),
        BattleMaps.Clamp(tonumber(color.a or color[4]) or 0.12, 0, 1)
end

local function ScoreFactionToName(faction)
    if Enum and Enum.PvPFaction then
        if faction == Enum.PvPFaction.Horde then return "Horde" end
        if faction == Enum.PvPFaction.Alliance then return "Alliance" end
    end
    if faction == 0 or faction == "Horde" then return "Horde" end
    if faction == 1 or faction == "Alliance" then return "Alliance" end
end

function MapFrame:GetNativeFaction()
    return ScoreFactionToName(UnitFactionGroup and UnitFactionGroup("player"))
end

function MapFrame:GetAssignedFaction()
    local guid = UnitGUID and UnitGUID("player")
    if guid and C_PvP and C_PvP.GetScoreInfoByPlayerGuid then
        local ok, info = pcall(C_PvP.GetScoreInfoByPlayerGuid, guid)
        if ok and info then
            return ScoreFactionToName(info.faction)
        end
    end
end

function MapFrame:GetEffectiveFaction()
    return self:GetAssignedFaction() or self:GetNativeFaction()
end

function MapFrame:GetFactionSwapInfo()
    local native = self:GetNativeFaction()
    local assigned = self:GetAssignedFaction()
    local swapped = assigned ~= nil and native ~= nil and assigned ~= native
    return swapped, assigned, native
end

function MapFrame:UpdateBorder()
    if not self.frame or not self.frame.SetBackdropBorderColor then return end
    if self.worldMapMode then
        self.frame:SetBackdropBorderColor(0, 0, 0, 0)
        return
    end
    local db = BattleMaps.Database:Get()
    local strength = BattleMaps.Clamp(tonumber(db.frameBorderStrength) or 1, 0.15, 1.00)
    local swapped, assigned = self:GetFactionSwapInfo()

    if db.factionSwapAlert == true and swapped then
        local color = assigned == "Alliance" and BattleMaps.COLORS.alliance
            or assigned == "Horde" and BattleMaps.COLORS.horde
            or BattleMaps.COLORS.neutral
        self.frame:SetBackdropBorderColor(color[1], color[2], color[3], strength)
        return
    end

    self.frame:SetBackdropBorderColor(0.25, 0.20, 0.15, 0.72 * strength)
end

function MapFrame:StopMapDrag()
    self.draggingMap = false
    self.dragStartX = nil
    self.dragStartY = nil
    self.dragStartPanX = nil
    self.dragStartPanY = nil
end

function MapFrame:IsFrameInMapHierarchy(candidate)
    local root = self.frame
    local visited = {}
    while candidate and not visited[candidate] do
        if candidate == root then return true end
        visited[candidate] = true
        candidate = candidate.GetParent and candidate:GetParent() or nil
    end
    return false
end

function MapFrame:HideOwnedTooltip()
    if not GameTooltip or not GameTooltip.GetOwner then return end
    local owner = GameTooltip:GetOwner()
    if owner and self:IsFrameInMapHierarchy(owner) then
        GameTooltip:Hide()
    end
end

function MapFrame:Create()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "BattleMapsMapFrame", UIParent, GetTemplate())
    self.frame = frame
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(240, 180, 1000, 800)
    frame:EnableMouse(true)
    frame:SetSize(420, 300)
    frame:SetPoint("CENTER")
    local db = BattleMaps.Database:Get()
    SetBackdrop(frame, db.frameBorderSize, db.frameBorderStyle)

    local titleBar = CreateFrame("Frame", nil, frame, GetTemplate())
    self.titleBar = titleBar
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    titleBar:SetHeight(25)
    titleBar:EnableMouse(true)
    if titleBar.SetBackdrop then
        titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        titleBar:SetBackdropColor(0.10, 0.075, 0.05, 0.96)
    end

    local close = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    self.closeButton = close
    close:SetPoint("RIGHT", titleBar, "RIGHT", 2, 0)
    close:SetScript("OnClick", function()
        self:CancelEdit()
        frame:Hide()
    end)

    local saveButton = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
    self.saveButton = saveButton
    saveButton:SetSize(52, 18)
    saveButton:SetPoint("RIGHT", close, "LEFT", 0, 0)
    saveButton:SetText("Save")
    saveButton:SetScript("OnClick", function()
        self:CommitEdit()
    end)

    local editButton = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
    self.lockButton = editButton
    editButton:SetSize(52, 18)
    editButton:SetPoint("RIGHT", saveButton, "LEFT", -2, 0)
    editButton:SetText("Edit")
    editButton:SetScript("OnClick", function()
        if not self.editMode then
            self:BeginEdit()
        end
    end)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.title = title
    title:SetPoint("LEFT", titleBar, "LEFT", 9, 0)
    title:SetPoint("RIGHT", editButton, "LEFT", -8, 0)
    title:SetJustifyH("LEFT")
    if title.SetWordWrap then title:SetWordWrap(false) end
    if title.SetNonSpaceWrap then title:SetNonSpaceWrap(false) end
    if title.SetMaxLines then title:SetMaxLines(1) end
    title:SetText("BattleMaps")

    titleBar:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and self.editMode then
            frame:StartMoving()
        elseif button == "RightButton" then
            self:ShowContextMenu()
        end
    end)
    titleBar:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
    end)

    local viewport = CreateFrame("Frame", nil, frame)
    self.viewport = viewport
    viewport:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -29)
    viewport:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    viewport:EnableMouse(true)
    viewport:EnableMouseWheel(true)
    if viewport.SetClipsChildren then viewport:SetClipsChildren(true) end

    local background = viewport:CreateTexture(nil, "BACKGROUND")
    self.viewportBackground = background
    background:SetAllPoints()
    background:SetColorTexture(GetFrameBackgroundColor(db))

    local fovLayer = CreateFrame("Frame", nil, viewport)
    self.fovLayer = fovLayer
    fovLayer:SetAllPoints(viewport)
    fovLayer:SetFrameLevel(viewport:GetFrameLevel() + FOV_LAYER_LEVEL_OFFSET)
    fovLayer:EnableMouse(false)

    local canvas = CreateFrame("Frame", nil, viewport)
    self.canvas = canvas
    canvas:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)
    canvas:SetSize(1, 1)
    canvas:SetFrameLevel(viewport:GetFrameLevel() + MAP_CANVAS_LEVEL_OFFSET)

    local fovOverlayLayer = CreateFrame("Frame", nil, viewport)
    self.fovOverlayLayer = fovOverlayLayer
    fovOverlayLayer:SetAllPoints(viewport)
    fovOverlayLayer:SetFrameLevel(viewport:GetFrameLevel() + FOV_OVERLAY_LAYER_LEVEL_OFFSET)
    fovOverlayLayer:EnableMouse(false)

    local emptyText = viewport:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.emptyText = emptyText
    emptyText:SetPoint("CENTER")
    emptyText:SetWidth(300)
    emptyText:SetJustifyH("CENTER")
    emptyText:SetText("Loading map art…")

    local pinLayer = CreateFrame("Frame", nil, viewport)
    self.pinLayer = pinLayer
    pinLayer:SetAllPoints(viewport)
    pinLayer:SetFrameLevel(viewport:GetFrameLevel() + PIN_LAYER_LEVEL_OFFSET)

    local editBorder = viewport:CreateTexture(nil, "OVERLAY")
    self.editBorder = editBorder
    editBorder:SetAllPoints()
    editBorder:SetColorTexture(1, 0.82, 0.22, 0.07)
    editBorder:Hide()

    local hint = viewport:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.hint = hint
    hint:SetPoint("BOTTOM", viewport, "BOTTOM", 0, 8)
    hint:SetText("Mouse wheel: zoom   Drag map: pan")
    hint:SetTextColor(1, 0.82, 0.55, 0.9)
    hint:Hide()

    local resize = CreateFrame("Button", nil, frame)
    self.resizeHandle = resize

    -- The viewport and its pin layer overlap the lower-right corner. Keep the
    -- sizing control above those layers so its whole visible area receives
    -- mouse input instead of only the few pixels outside the viewport.
    resize:SetFrameLevel(pinLayer:GetFrameLevel() + 20)
    resize:EnableMouse(true)
    resize:SetSize(32, 32)
    resize:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    resize:SetHitRectInsets(-4, -4, -4, -4)
    resize:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    -- Use a large hit target without making the artwork dominate the map.
    for _, texture in ipairs({
        resize:GetNormalTexture(),
        resize:GetHighlightTexture(),
        resize:GetPushedTexture(),
    }) do
        if texture then
            texture:ClearAllPoints()
            texture:SetPoint("BOTTOMRIGHT", resize, "BOTTOMRIGHT", -2, 2)
            texture:SetSize(22, 22)
        end
    end

    resize:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and self.editMode then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resize:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        self:LayoutView()
    end)
    resize:Hide()

    viewport:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            local view = self:GetActiveView()
            if not view then return end
            local scale = UIParent:GetEffectiveScale()
            local cursorX, cursorY = GetCursorPosition()
            self.draggingMap = true
            self.dragStartX = cursorX / scale
            self.dragStartY = cursorY / scale
            self.dragStartPanX = view.customPanX
            self.dragStartPanY = view.customPanY
        elseif button == "RightButton" then
            self:ShowContextMenu()
        end
    end)
    viewport:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            self:StopMapDrag()
        end
    end)
    viewport:SetScript("OnMouseWheel", function(_, delta)
        local view = self:GetActiveView()
        if not view then return end
        view.customZoom = BattleMaps.Clamp(view.customZoom * (delta > 0 and 1.15 or (1 / 1.15)), 1, 3)
        self:ClampPan(view)
        self:LayoutView()
    end)

    frame:SetScript("OnSizeChanged", function()
        self:LayoutView()
    end)
    frame:SetScript("OnShow", function()
        self.chromeRequested = false
        self:ApplyVisualSettings()
        self:UpdateBorder()
        self:UpdateChromeFade(0, true)
        -- Ordinary pan and zoom are session-only. Reopening either surface
        -- begins from that surface's independently saved per-map view. When a
        -- World Map presentation is merely resumed after browsing elsewhere,
        -- preserve its current unsaved session view.
        if self.worldMapMode then
            if not self.worldMapTransientView
                or self.worldMapTransientViewMapID ~= self.currentMapID then
                self:ResetWorldMapTransientView()
            end
        else
            self:ResetTransientView()
        end
        self:LayoutView()
        if BattleMaps.Pins then BattleMaps.Pins:RefreshAll(true) end
    end)
    frame:SetScript("OnHide", function()
        self:StopMapDrag()
        self:HideOwnedTooltip()
        self:HideContextMenu()
        self.testMode = false
        if BattleMaps.Pins and BattleMaps.Pins.StopCaptureTimerTest then
            BattleMaps.Pins:StopCaptureTimerTest()
        end
        self:CancelEdit()
        if not self.worldMapMode then
            self.transientView = nil
            self.transientViewMapID = nil
        end
    end)
    frame:SetScript("OnUpdate", function(_, elapsed)
        self:OnUpdate(elapsed)
    end)

    BattleMaps.MapRenderer:Initialize(canvas, emptyText)
    self:SetEditMode(false)
    frame:Hide()
    return frame
end


function MapFrame:UpdateTitleText(mapID)
    if not self.title then return end
    local mapName = mapID and (
        BattleMaps.GetBattlegroundNameForConfig
            and BattleMaps.GetBattlegroundNameForConfig(mapID)
            or BattleMaps.Battlegrounds:GetName(mapID)
    ) or ""
    local battle = BattleMaps.ColorText(BattleMaps.COLORS.red, "Battle")
    local maps = BattleMaps.ColorText(BattleMaps.COLORS.parchmentLight, "Maps")
    local suffix = mapName ~= "" and (" |cffc8b58f— " .. mapName .. "|r") or ""
    self.title:SetText(battle .. maps .. suffix)
end

function MapFrame:UpdateViewportChromeInset(chromeAlpha, force)
    if not self.frame or not self.viewport then return end

    if self.worldMapMode then
        if not force and self.reservedHeaderHeight == 0 and self.visualInset == 0 then return end
        self.reservedHeaderHeight = 0
        self.visualInset = 0
        self.viewport:ClearAllPoints()
        self.viewport:SetAllPoints(self.frame)
        self:LayoutView()
        return
    end

    local inset = tonumber(self.visualInset) or 2
    -- Quantise to whole pixels so the expensive map layout is not rebuilt for
    -- imperceptibly small alpha changes on every frame of the fade.
    local reservedHeaderHeight = math.floor((26 * BattleMaps.Clamp(chromeAlpha or 0, 0, 1)) + 0.5)
    if not force and self.reservedHeaderHeight == reservedHeaderHeight then return end
    self.reservedHeaderHeight = reservedHeaderHeight

    self.viewport:ClearAllPoints()
    self.viewport:SetPoint(
        "TOPLEFT",
        self.frame,
        "TOPLEFT",
        inset + 1,
        -(inset + 1 + reservedHeaderHeight)
    )
    self.viewport:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -(inset + 1), inset + 1)
    self:LayoutView()
end

function MapFrame:ApplyVisualSettings()
    if not self.frame then return end
    local db = BattleMaps.Database:Get()
    local backgroundR, backgroundG, backgroundB, backgroundA = GetFrameBackgroundColor(db)

    if self.worldMapMode then
        self.visualInset = 0
        SetBackdrop(self.frame, 0, db.frameBorderStyle)
        if self.frame.SetBackdropColor then self.frame:SetBackdropColor(0, 0, 0, 0) end
        if self.frame.SetBackdropBorderColor then self.frame:SetBackdropBorderColor(0, 0, 0, 0) end

        self.titleBar:Hide()
        self.resizeHandle:Hide()
        self.editBorder:Hide()
        self.hint:Hide()
        self.chromeAlpha = 0
        self:SetChromeInteractive(false)

        if self.viewportBackground then
            self.viewportBackground:SetColorTexture(backgroundR, backgroundG, backgroundB, backgroundA)
        end
        if BattleMaps.MapRenderer then BattleMaps.MapRenderer:ApplyTextureAlpha() end
        self:UpdateViewportChromeInset(0, true)
        return
    end

    local borderSize = BattleMaps.Clamp(tonumber(db.frameBorderSize) or 2, 0, 8)
    local inset = math.max(1, borderSize)
    self.visualInset = inset

    SetBackdrop(self.frame, borderSize, db.frameBorderStyle)
    self.titleBar:Show()

    self.titleBar:ClearAllPoints()
    self.titleBar:SetPoint("TOPLEFT", self.frame, "TOPLEFT", inset, -inset)
    self.titleBar:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -inset, -inset)

    self.resizeHandle:ClearAllPoints()
    self.resizeHandle:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -inset, inset)
    self.resizeHandle:SetShown(self.editMode == true)
    self.editBorder:SetShown(self.editMode == true)
    self.hint:SetShown(self.editMode == true)
    self:UpdateBorder()
    if self.viewportBackground then
        self.viewportBackground:SetColorTexture(backgroundR, backgroundG, backgroundB, backgroundA)
    end
    if BattleMaps.MapRenderer then BattleMaps.MapRenderer:ApplyTextureAlpha() end
    self:UpdateViewportChromeInset(tonumber(self.chromeAlpha) or 1, true)
end

function MapFrame:IsPointerOverFrame()
    if not self.frame or not self.frame:IsShown() then return false end
    if type(MouseIsOver) == "function" then
        local ok, over = pcall(MouseIsOver, self.frame)
        if ok then return over == true end
    end
    if self.frame.IsMouseOver then
        local ok, over = pcall(self.frame.IsMouseOver, self.frame)
        if ok then return over == true end
    end
    return false
end

function MapFrame:SetChromeInteractive(enabled)
    enabled = enabled == true
    if self.chromeInteractive == enabled then return end
    self.chromeInteractive = enabled
    if self.titleBar then self.titleBar:EnableMouse(enabled) end
    if self.closeButton then self.closeButton:EnableMouse(enabled) end
    if self.saveButton then self.saveButton:EnableMouse(enabled) end
    if self.lockButton then self.lockButton:EnableMouse(enabled) end
end

function MapFrame:SetChromeRequested(enabled)
    self.chromeRequested = enabled == true
    self:UpdateChromeFade(0, true)
end

function MapFrame:ToggleChromeRequested()
    local db = BattleMaps.Database:Get()
    if db.fadeMapHeader == false then return end
    self:SetChromeRequested(not self.chromeRequested)
end

function MapFrame:UpdateChromeFade(elapsed, force)
    if not self.titleBar or not self.frame then return end
    if self.worldMapMode then
        self.chromeAlpha = 0
        self.titleBar:SetAlpha(0)
        self:SetChromeInteractive(false)
        self:UpdateViewportChromeInset(0, force)
        return
    end
    local db = BattleMaps.Database:Get()

    -- Restore the original hover behaviour: the map header appears whenever
    -- the pointer is over the map and fades after the pointer leaves. Keep it
    -- visible while the right-click context menu is open so the transition
    -- does not feel abrupt when moving from the map into the menu.
    local pointerOverMap = self:IsPointerOverFrame()
    local contextMenuOpen = (self.contextMenu and self.contextMenu:IsShown())
        or (self.nativeContextMenu and self.nativeContextMenu.IsShown and self.nativeContextMenu:IsShown())
    local shouldShow = db.fadeMapHeader == false
        or self.editMode
        or pointerOverMap
        or contextMenuOpen
    local target = shouldShow and 1 or 0
    local current = tonumber(self.chromeAlpha) or 1

    if force then
        current = target
    else
        local speed = 5.5 * (tonumber(elapsed) or 0)
        if current < target then
            current = math.min(target, current + speed)
        elseif current > target then
            current = math.max(target, current - speed)
        end
    end

    self.chromeAlpha = current
    self.titleBar:SetAlpha(current)
    self:SetChromeInteractive(current > 0.12 or self.editMode)
    self:UpdateViewportChromeInset(current, force)
end

function MapFrame:CreateContextMenuDismissLayer()
    if self.contextMenuDismissLayer then return self.contextMenuDismissLayer end

    -- This layer is used only by the legacy/custom fallback menu. The modern
    -- Blizzard menu framework already owns outside-click dismissal.
    local dismiss = CreateFrame("Button", nil, UIParent)
    self.contextMenuDismissLayer = dismiss
    dismiss:SetAllPoints(UIParent)
    dismiss:SetFrameStrata("TOOLTIP")
    dismiss:SetFrameLevel(900)
    dismiss:EnableMouse(true)
    dismiss:RegisterForClicks("LeftButtonUp")
    dismiss:SetScript("OnClick", function()
        self:HideContextMenu()
    end)
    dismiss:Hide()
    return dismiss
end

function MapFrame:CreateContextMenu()
    if self.contextMenu then return self.contextMenu end

    local menu = CreateFrame("Frame", "BattleMapsMapContextMenu", UIParent, GetTemplate())
    self.contextMenu = menu
    menu:SetFrameStrata("TOOLTIP")
    menu:SetFrameLevel(910)
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:SetSize(204, 10)
    menu:Hide()

    if menu.SetBackdrop then
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        menu:SetBackdropColor(0.055, 0.045, 0.035, 0.98)
        menu:SetBackdropBorderColor(0.63, 0.45, 0.24, 0.95)
    end

    menu.buttons = {}
    for index = 1, 5 do
        local button = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
        button:SetHeight(22)
        button:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6 - ((index - 1) * 24))
        button:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -6, -6 - ((index - 1) * 24))
        button:Hide()
        menu.buttons[index] = button
    end

    menu:SetScript("OnHide", function()
        if self.contextMenuDismissLayer then
            self.contextMenuDismissLayer:Hide()
        end
        self:UpdateChromeFade(0, true)
    end)

    if type(UISpecialFrames) == "table" then
        local found = false
        for _, name in ipairs(UISpecialFrames) do
            if name == "BattleMapsMapContextMenu" then
                found = true
                break
            end
        end
        if not found then
            UISpecialFrames[#UISpecialFrames + 1] = "BattleMapsMapContextMenu"
        end
    end

    return menu
end

function MapFrame:HideContextMenu()
    if self.contextMenu and self.contextMenu:IsShown() then
        self.contextMenu:Hide()
    end
    if self.contextMenuDismissLayer then
        self.contextMenuDismissLayer:Hide()
    end
    if self.nativeContextMenu and self.nativeContextMenu.IsShown
        and self.nativeContextMenu:IsShown() and self.nativeContextMenu.Hide then
        self.nativeContextMenu:Hide()
    end
    self.nativeContextMenu = nil
end

function MapFrame:GetContextMenuItems()
    local function OpenOptions()
        if BattleMaps.Options and BattleMaps.Options.Open then
            BattleMaps.Options:Open()
        end
    end

    local function DismissMenu()
        -- Cancel dismisses only this context menu. It deliberately does not
        -- alter Edit mode or revert map changes.
        self:HideContextMenu()
    end

    if self.worldMapMode then
        return {
            {
                text = "Save Full Map View",
                action = function() self:SaveWorldMapView() end,
            },
            {
                text = "Reset Full Map View",
                action = function() self:ResetWorldMapView() end,
            },
            { text = "Options", action = OpenOptions },
            { text = "Cancel", action = DismissMenu },
        }
    end

    return {
        { text = "Options", action = OpenOptions },
        {
            text = "Save",
            disabled = self.editMode ~= true,
            action = function()
                if self.editMode then self:CommitEdit() end
            end,
        },
        { text = "Cancel", action = DismissMenu },
    }
end

function MapFrame:ConfigureContextMenu()
    local menu = self:CreateContextMenu()
    local items = self:GetContextMenuItems()

    for index, button in ipairs(menu.buttons) do
        local item = items[index]
        if item then
            button:SetText(item.text)
            button:SetEnabled(item.disabled ~= true)
            button:SetScript("OnClick", function()
                menu:Hide()
                if item.action then item.action() end
            end)
            button:Show()
        else
            button:SetScript("OnClick", nil)
            button:Hide()
        end
    end

    menu:SetHeight(12 + (#items * 24))
    return menu
end

function MapFrame:ShowContextMenu()
    if not self.frame or not self.frame:IsShown() then return end

    self:HideContextMenu()

    -- Retail's Blizzard_Menu framework supplies the same context-menu style
    -- used by the current client and automatically dismisses the menu when the
    -- player clicks elsewhere. UI skin addons can also skin this shared menu
    -- implementation instead of BattleMaps maintaining a separate visual.
    if type(MenuUtil) == "table" and type(MenuUtil.CreateContextMenu) == "function" then
        local items = self:GetContextMenuItems()
        local ok, nativeMenu = pcall(MenuUtil.CreateContextMenu, self.frame,
            function(_, rootDescription)
                for _, item in ipairs(items) do
                    local element = rootDescription:CreateButton(item.text, function()
                        if item.action then item.action() end
                    end)
                    if item.disabled == true and element and element.SetEnabled then
                        element:SetEnabled(false)
                    end
                end
            end)

        if ok then
            -- Some client builds return the created menu frame; others do not.
            -- Keep it when available so frame hiding can close it explicitly.
            if nativeMenu and nativeMenu.IsShown then
                self.nativeContextMenu = nativeMenu
                if nativeMenu.HookScript then
                    nativeMenu:HookScript("OnHide", function(hiddenMenu)
                        if self.nativeContextMenu == hiddenMenu then
                            self.nativeContextMenu = nil
                        end
                        self:UpdateChromeFade(0, true)
                    end)
                end
            end
            self:UpdateChromeFade(0, true)
            return
        end
    end

    -- Compatibility fallback for clients without Blizzard_Menu.
    local menu = self:ConfigureContextMenu()
    local dismiss = self:CreateContextMenuDismissLayer()

    local scale = UIParent:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    cursorX = (tonumber(cursorX) or 0) / scale
    cursorY = (tonumber(cursorY) or 0) / scale

    dismiss:Show()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cursorX + 4, cursorY - 4)
    menu:Show()
    self:UpdateChromeFade(0, true)
end

function MapFrame:GetCurrentConfig()
    return self.currentMapID and BattleMaps.Database:GetMapConfig(self.currentMapID) or nil
end

local function CopyViewValues(source)
    if not source then return nil end
    return {
        customZoom = BattleMaps.Clamp(
            tonumber(source.customZoom or source.zoom) or 1, 1, 3),
        customPanX = tonumber(source.customPanX or source.panX) or 0.5,
        customPanY = tonumber(source.customPanY or source.panY) or 0.5,
    }
end

local function StoreWorldMapView(destination, source, configured)
    destination = type(destination) == "table" and destination or {}
    source = source or {}
    destination.zoom = BattleMaps.Clamp(tonumber(source.customZoom or source.zoom) or 1, 1, 3)
    destination.panX = tonumber(source.customPanX or source.panX) or 0.5
    destination.panY = tonumber(source.customPanY or source.panY) or 0.5
    destination.configured = configured == true
    -- Remove prototype aliases so SavedVariables retain one canonical schema.
    destination.customZoom = nil
    destination.customPanX = nil
    destination.customPanY = nil
    return destination
end

function MapFrame:ResetTransientView(config)
    config = config or self:GetCurrentConfig()
    if not config or not self.currentMapID then
        self.transientView = nil
        self.transientViewMapID = nil
        return nil
    end

    self.transientView = CopyViewValues(config)
    self.transientViewMapID = self.currentMapID
    self:ClampPan(self.transientView)
    return self.transientView
end

function MapFrame:ResetWorldMapTransientView(config)
    config = config or self:GetCurrentConfig()
    if not config or not self.currentMapID then
        self.worldMapTransientView = nil
        self.worldMapTransientViewMapID = nil
        return nil
    end

    local saved = type(config.worldMapView) == "table" and config.worldMapView or {}
    self.worldMapTransientView = CopyViewValues(saved)
    self.worldMapTransientViewMapID = self.currentMapID
    self:ClampPan(self.worldMapTransientView)
    return self.worldMapTransientView
end

function MapFrame:IsWorldMapViewConfigured(mapID)
    mapID = tonumber(mapID) or tonumber(self.currentMapID)
    local config = mapID and BattleMaps.Database:GetMapConfig(mapID) or nil
    return config ~= nil
        and type(config.worldMapView) == "table"
        and config.worldMapView.configured == true
end

function MapFrame:CanSaveWorldMapView(mapID)
    mapID = tonumber(mapID) or tonumber(self.currentMapID)
    return self.worldMapMode == true
        and self:IsWorldMapPresentationVisible()
        and mapID ~= nil
        and tonumber(self.currentMapID) == mapID
end

function MapFrame:SaveWorldMapView(mapID)
    mapID = tonumber(mapID) or tonumber(self.currentMapID)
    if not self:CanSaveWorldMapView(mapID) then return false end

    local config = BattleMaps.Database:GetMapConfig(mapID)
    local view = self:GetActiveView()
    if not config or not view then return false end

    self:ClampPan(view)
    config.worldMapView = StoreWorldMapView(config.worldMapView, view, true)

    local mapName = BattleMaps.GetBattlegroundNameForConfig
        and BattleMaps.GetBattlegroundNameForConfig(mapID)
        or BattleMaps.Battlegrounds:GetName(mapID)
    BattleMaps.Chat("Saved " .. tostring(mapName) .. " full-map view.")
    return true
end

function MapFrame:ResetWorldMapView(mapID)
    mapID = tonumber(mapID) or tonumber(self.currentMapID)
    local config = mapID and BattleMaps.Database:GetMapConfig(mapID) or nil
    if not config then return false end

    if BattleMaps.Database and BattleMaps.Database.ResetWorldMapView then
        BattleMaps.Database:ResetWorldMapView(mapID)
        config = BattleMaps.Database:GetMapConfig(mapID) or config
    else
        config.worldMapView = StoreWorldMapView(config.worldMapView, nil, false)
    end

    if tonumber(self.currentMapID) == mapID then
        self:ResetWorldMapTransientView(config)
        if self.worldMapMode then self:LayoutView() end
    end

    local mapName = BattleMaps.GetBattlegroundNameForConfig
        and BattleMaps.GetBattlegroundNameForConfig(mapID)
        or BattleMaps.Battlegrounds:GetName(mapID)
    BattleMaps.Chat("Reset " .. tostring(mapName) .. " full-map view.")
    return true
end

function MapFrame:GetActiveView()
    local config = self:GetCurrentConfig()
    if not config then return nil end

    if self.worldMapMode then
        if not self.worldMapTransientView
            or self.worldMapTransientViewMapID ~= self.currentMapID then
            return self:ResetWorldMapTransientView(config)
        end
        return self.worldMapTransientView
    end

    if self.editMode then
        if not self.editView or self.editViewMapID ~= self.currentMapID then
            self.editView = CopyViewValues(config)
            self.editViewMapID = self.currentMapID
            self:ClampPan(self.editView)
        end
        return self.editView
    end

    if not self.transientView or self.transientViewMapID ~= self.currentMapID then
        return self:ResetTransientView(config)
    end
    return self.transientView
end

function MapFrame:IsWorldMapMode()
    return self.worldMapMode == true
end

function MapFrame:IsWorldMapPresentationVisible()
    return self.worldMapMode == true and self.worldMapPresentationVisible ~= false
end

function MapFrame:GetWorldMapContainer()
    return self.worldMapContainer
end

function MapFrame:CaptureWorldMapRestoreState()
    local frame = self:Create()
    local width, height = frame:GetSize()
    local state = {
        mapID = self.currentMapID,
        shown = frame:IsShown(),
        width = width,
        height = height,
        points = CaptureFramePoints(frame),
        parent = frame:GetParent(),
        frameStrata = frame:GetFrameStrata(),
        frameLevel = frame:GetFrameLevel(),
        clampedToScreen = frame:IsClampedToScreen(),
        movable = frame:IsMovable(),
        resizable = frame:IsResizable(),
        mouseEnabled = frame.IsMouseEnabled and frame:IsMouseEnabled() or true,
        chromeRequested = self.chromeRequested == true,
    }
    self.worldMapRestoreState = state
    return state
end

function MapFrame:GetOrCreateWorldMapOverlay()
    if self.worldMapOverlay then return self.worldMapOverlay end

    -- Keep the World Map presentation in an addon-owned hierarchy. Parenting
    -- an addon frame directly to WorldMapFrame or its ScrollContainer can taint
    -- Blizzard's protected MapCanvas pin acquisition during combat.
    local overlay = CreateFrame("Frame", "BattleMapsWorldMapOverlay", UIParent)
    overlay:SetFrameStrata("TOOLTIP")
    overlay:SetFrameLevel(100)
    overlay:EnableMouse(false)
    overlay:Hide()
    self.worldMapOverlay = overlay
    return overlay
end

function MapFrame:ApplyWorldMapLayering()
    local frame = self:Create()
    local overlay = self:GetOrCreateWorldMapOverlay()
    if not overlay then return false end

    -- The overlay is owned by BattleMaps and only anchors visually to the
    -- Blizzard viewport. This keeps BattleMaps above the native map without
    -- making it part of the protected WorldMapFrame hierarchy.
    local oldBaseLevel = frame:GetFrameLevel()
    local frameTreeLevels = CaptureFrameTreeLevels(frame)
    if frame:GetParent() ~= overlay then
        frame:SetParent(overlay)
    end

    overlay:SetFrameStrata("TOOLTIP")
    overlay:SetFrameLevel(100)
    frame:SetFrameStrata("TOOLTIP")

    local baseLevel = overlay:GetFrameLevel() + 100
    ShiftCapturedFrameTreeLevels(frameTreeLevels, baseLevel - oldBaseLevel)

    -- UnitPositionFrames and pooled pins can recalculate their levels during
    -- layout, so refresh them after rebasing the addon-owned render tree.
    if BattleMaps.Pins and BattleMaps.Pins.LayoutAll then
        BattleMaps.Pins:LayoutAll()
    end
    return true
end

function MapFrame:ApplyWorldMapPlacement(container)
    local frame = self:Create()
    container = container or self.worldMapContainer
    if not container or not container.GetSize then return false end

    local overlay = self:GetOrCreateWorldMapOverlay()
    if not overlay then return false end

    self.worldMapContainer = container
    overlay:ClearAllPoints()
    overlay:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    overlay:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)

    if not self:ApplyWorldMapLayering() then return false end

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0)

    if self.worldMapPresentationVisible ~= false then
        overlay:Show()
        frame:Show()
    else
        overlay:Hide()
        frame:Hide()
    end

    self:LayoutView()
    return true
end

function MapFrame:SetWorldMapPresentationVisible(visible, container)
    visible = visible == true
    if not self.worldMapMode then
        if not visible then return false end
        return self:EnterWorldMapMode(container)
    end

    if container and container.GetSize then
        self.worldMapContainer = container
    end
    local wasVisible = self:IsWorldMapPresentationVisible()
    self.worldMapPresentationVisible = visible

    local frame = self:Create()
    local overlay = self:GetOrCreateWorldMapOverlay()
    if visible then
        self:ApplyVisualSettings()
        if not self:ApplyWorldMapPlacement(self.worldMapContainer) then return false end
        overlay:Show()
        frame:Show()
        self:LayoutView()
        if not wasVisible and BattleMaps.Pins then BattleMaps.Pins:RefreshAll(true) end
    else
        self:StopMapDrag()
        self:HideOwnedTooltip()
        if overlay then overlay:Hide() end
        frame:Hide()
    end
    return true
end

function MapFrame:EnterWorldMapMode(container)
    if not container or not container.GetSize then return false end
    local frame = self:Create()

    if self.worldMapMode then
        return self:SetWorldMapPresentationVisible(true, container)
    end

    if self.editMode then self:CancelEdit() end
    self:HideContextMenu()
    self:CaptureWorldMapRestoreState()

    self.worldMapMode = true
    self.worldMapPresentationVisible = true
    self.worldMapContainer = container
    self.chromeRequested = false
    self:ResetWorldMapTransientView()

    frame:SetClampedToScreen(false)
    frame:SetMovable(false)
    frame:SetResizable(false)
    frame:EnableMouse(true)

    self:SetEditMode(false)
    self:ApplyVisualSettings()
    if not self:ApplyWorldMapPlacement(container) then
        self:ExitWorldMapMode()
        return false
    end

    frame:Show()
    self:LayoutView()
    if BattleMaps.Pins then BattleMaps.Pins:RefreshAll(true) end
    BattleMaps.Debug("entered World Map presentation mode")
    return true
end

function MapFrame:ExitWorldMapMode()
    if not self.worldMapMode then return false end

    local frame = self:Create()
    local state = self.worldMapRestoreState
    self:StopMapDrag()
    self:HideOwnedTooltip()
    self.worldMapMode = false
    self.worldMapPresentationVisible = nil
    self.worldMapContainer = nil
    self.worldMapRestoreState = nil
    self.worldMapTransientView = nil
    self.worldMapTransientViewMapID = nil

    local overlay = self.worldMapOverlay
    if overlay then
        overlay:Hide()
        overlay:ClearAllPoints()
    end

    if state then
        local currentBaseLevel = frame:GetFrameLevel()
        local frameTreeLevels = CaptureFrameTreeLevels(frame)
        frame:SetParent(state.parent or UIParent)
        frame:SetFrameStrata(state.frameStrata or "MEDIUM")
        ShiftCapturedFrameTreeLevels(
            frameTreeLevels,
            (tonumber(state.frameLevel) or 0) - currentBaseLevel
        )
        frame:SetClampedToScreen(state.clampedToScreen ~= false)
        frame:SetMovable(state.movable ~= false)
        frame:SetResizable(state.resizable ~= false)
        frame:EnableMouse(state.mouseEnabled ~= false)
        self.chromeRequested = state.chromeRequested == true
    else
        local currentBaseLevel = frame:GetFrameLevel()
        local frameTreeLevels = CaptureFrameTreeLevels(frame)
        frame:SetParent(UIParent)
        frame:SetFrameStrata("MEDIUM")
        ShiftCapturedFrameTreeLevels(frameTreeLevels, -currentBaseLevel)
        frame:SetClampedToScreen(true)
        frame:SetMovable(true)
        frame:SetResizable(true)
        self.chromeRequested = false
    end

    self:ApplyVisualSettings()

    if state and state.mapID == self.currentMapID then
        frame:SetSize(state.width or 420, state.height or 300)
        RestoreFramePoints(frame, state.points)
    else
        local config = self:GetCurrentConfig()
        if config then self:ApplyFramePlacement(config) end
    end

    if state and state.shown then
        frame:Show()
        self:UpdateChromeFade(0, true)
        self:LayoutView()
        if BattleMaps.Pins then BattleMaps.Pins:RefreshAll(true) end
    else
        frame:Hide()
    end

    BattleMaps.Debug("left World Map presentation mode")
    return true
end

function MapFrame:ApplyFramePlacement(config)
    if self.worldMapMode then
        return self:ApplyWorldMapPlacement()
    end
    local frame = self:Create()
    frame:SetSize(config.width or 420, config.height or 300)
    frame:ClearAllPoints()
    local relativeTo = BattleMaps.GetSafeGlobalFrame(config.relativeTo)
    frame:SetPoint(
        config.point or "CENTER",
        relativeTo,
        config.relativePoint or config.point or "CENTER",
        tonumber(config.offsetX) or 0,
        tonumber(config.offsetY) or 0)
end

function MapFrame:SaveCurrentLayout()
    if self.worldMapMode then return end
    local frame = self.frame
    local config = self:GetCurrentConfig()
    if not frame or not config then return end

    config.width, config.height = frame:GetSize()
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    config.point = point or "CENTER"
    config.relativeTo = relativeTo and relativeTo.GetName and relativeTo:GetName() or "UIParent"
    config.relativePoint = relativePoint or config.point
    config.offsetX = x or 0
    config.offsetY = y or 0
    config.configured = true
end

function MapFrame:SetMapID(mapID, forcePlacement)
    mapID = tonumber(mapID)
    local config = BattleMaps.Database:GetMapConfig(mapID)
    if not config then return false end

    if self.editMode and self.currentMapID and self.currentMapID ~= mapID then
        self:CancelEdit()
    end

    local changed = self.currentMapID ~= mapID
    self.currentMapID = mapID
    self.selectedMapID = mapID

    if changed or forcePlacement then
        self:ApplyFramePlacement(config)
        if self.worldMapMode then
            self:ResetWorldMapTransientView(config)
        else
            self:ResetTransientView(config)
        end
    end

    self:UpdateTitleText(mapID)
    BattleMaps.MapRenderer:SetMapID(mapID)
    self:LayoutView()
    if BattleMaps.Pins then BattleMaps.Pins:RefreshAll(true) end
    return true
end

function MapFrame:ShowMap(mapID, preview)
    if not self:SetMapID(mapID, true) then return false end
    self.previewMode = preview == true
    self.frame:Show()
    return true
end

function MapFrame:SetTestMode(enabled)
    self.testMode = enabled == true
    if BattleMaps.Pins then
        BattleMaps.Pins:RefreshAll(true)
    end
end

-- A live battleground transition is authoritative. If the user was editing a
-- different preview map when the queue entered, cancel that map's snapshot,
-- switch to the real battleground, and begin a fresh edit snapshot there. This
-- does not change frame visibility; the caller retains normal auto-show rules.
function MapFrame:SetLiveBattleground(mapID, preserveEditMode)
    mapID = tonumber(mapID)
    if not mapID then return false end

    self.testMode = false
    if BattleMaps.Pins and BattleMaps.Pins.StopCaptureTimerTest then
        BattleMaps.Pins:StopCaptureTimerTest()
    end

    local changedMap = self.currentMapID ~= mapID
    local resumeEdit = preserveEditMode == true
        and self.editMode == true
        and changedMap

    if resumeEdit then
        self:CancelEdit()
    end

    if not self:SetMapID(mapID, changedMap) then
        return false
    end
    self.previewMode = false

    if resumeEdit then
        self:BeginEdit()
    end
    return true
end

function MapFrame:ShowCurrentOrSelected()
    local mapID = BattleMaps.ResolveCurrentBattlegroundMapID()
        or self.selectedMapID
        or BattleMaps.Options.selectedMapID
        or BattleMaps.Battlegrounds.MAPS[1].id
    self:ShowMap(mapID, not BattleMaps.IsInLiveBattleground())
end

function MapFrame:Toggle()
    self:Create()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:ShowCurrentOrSelected()
    end
end

function MapFrame:Hide()
    self.testMode = false
    if BattleMaps.Pins and BattleMaps.Pins.StopCaptureTimerTest then
        BattleMaps.Pins:StopCaptureTimerTest()
    end
    if self.frame then self.frame:Hide() end
end

function MapFrame:CaptureEditSnapshot()
    local config = self:GetCurrentConfig()
    if not config then return nil end

    return {
        mapID = self.currentMapID,
        width = config.width,
        height = config.height,
        point = config.point,
        relativeTo = config.relativeTo,
        relativePoint = config.relativePoint,
        offsetX = config.offsetX,
        offsetY = config.offsetY,
        customZoom = config.customZoom,
        customPanX = config.customPanX,
        customPanY = config.customPanY,
        configured = config.configured,
    }
end

function MapFrame:BeginEdit()
    if self.worldMapMode or self.editMode then return end

    -- Snapshot the persisted layout first. The active casual view becomes the
    -- edit starting point, but remains separate from SavedVariables until Save.
    local transient = self:GetActiveView()
    self.editSnapshot = self:CaptureEditSnapshot()
    self.editView = CopyViewValues(transient or self:GetCurrentConfig())
    self.editViewMapID = self.currentMapID

    self:SetEditMode(true)
    self:LayoutView()
end

function MapFrame:CommitEdit()
    if self.worldMapMode or not self.editMode then return end

    local config = self:GetCurrentConfig()
    if config and self.editView then
        config.customZoom = self.editView.customZoom
        config.customPanX = self.editView.customPanX
        config.customPanY = self.editView.customPanY
    end
    self:SaveCurrentLayout()
    self.editSnapshot = nil
    self.editView = nil
    self.editViewMapID = nil
    self:SetEditMode(false)
    self:ResetTransientView()
    self:LayoutView()

    local mapID = self.currentMapID
    if mapID then
        local mapName = BattleMaps.GetBattlegroundNameForConfig
            and BattleMaps.GetBattlegroundNameForConfig(mapID)
            or BattleMaps.Battlegrounds:GetName(mapID)
        BattleMaps.Chat("Saved " .. tostring(mapName) .. " layout.")
    end
end

function MapFrame:CancelEdit()
    local snapshot = self.editSnapshot
    self.editSnapshot = nil

    if snapshot and snapshot.mapID == self.currentMapID then
        local config = self:GetCurrentConfig()
        if config then
            config.width = snapshot.width
            config.height = snapshot.height
            config.point = snapshot.point
            config.relativeTo = snapshot.relativeTo
            config.relativePoint = snapshot.relativePoint
            config.offsetX = snapshot.offsetX
            config.offsetY = snapshot.offsetY
            config.customZoom = snapshot.customZoom
            config.customPanX = snapshot.customPanX
            config.customPanY = snapshot.customPanY
            config.configured = snapshot.configured
            self:ApplyFramePlacement(config)
        end
    end

    self.editView = nil
    self.editViewMapID = nil
    self:SetEditMode(false)
    self:ResetTransientView()
    self:LayoutView()
end

function MapFrame:SetEditMode(enabled)
    if self.worldMapMode then enabled = false end
    self.editMode = enabled == true
    if not self.frame then return end

    self.resizeHandle:SetShown(self.editMode)
    self.editBorder:SetShown(self.editMode)
    self.hint:SetShown(self.editMode)
    self.saveButton:SetShown(self.editMode)

    self.lockButton:ClearAllPoints()
    if self.editMode then
        self.lockButton:SetPoint("RIGHT", self.saveButton, "LEFT", -2, 0)
    else
        self.lockButton:SetPoint("RIGHT", self.closeButton, "LEFT", 0, 0)
    end

    self.lockButton:SetEnabled(not self.editMode)
    self.lockButton:SetText(self.editMode and "Editing" or "Edit")
    if self.editMode then
        self.lockButton:LockHighlight()
    else
        self.lockButton:UnlockHighlight()
        self.chromeRequested = false
    end
    self:UpdateChromeFade(0, true)
end

function MapFrame:ClampPan(config)
    local zoom = BattleMaps.Clamp(config.customZoom or 1, 1, 3)
    local minPan = 0.5 / zoom
    local maxPan = 1 - minPan
    config.customPanX = BattleMaps.Clamp(config.customPanX or 0.5, minPan, maxPan)
    config.customPanY = BattleMaps.Clamp(config.customPanY or 0.5, minPan, maxPan)
end

function MapFrame:LayoutView()
    if not self.viewport or not self.canvas then return end
    local view = self:GetActiveView()
    if not view then return end

    local viewportWidth, viewportHeight = self.viewport:GetSize()
    if not viewportWidth or viewportWidth <= 1 or not viewportHeight or viewportHeight <= 1 then return end

    local aspect = BattleMaps.MapRenderer:GetAspectRatio()
    if aspect <= 0 then aspect = viewportWidth / viewportHeight end

    local baseWidth = viewportWidth
    local baseHeight = baseWidth / aspect
    if baseHeight > viewportHeight then
        baseHeight = viewportHeight
        baseWidth = baseHeight * aspect
    end

    local zoom = BattleMaps.Clamp(view.customZoom or 1, 1, 3)
    self:ClampPan(view)

    local canvasWidth = baseWidth * zoom
    local canvasHeight = baseHeight * zoom
    local left = (viewportWidth * 0.5) - ((view.customPanX or 0.5) * canvasWidth)
    local top = (viewportHeight * 0.5) - ((view.customPanY or 0.5) * canvasHeight)

    self.viewLeft = left
    self.viewTop = top
    self.viewWidth = canvasWidth
    self.viewHeight = canvasHeight

    self.canvas:ClearAllPoints()
    self.canvas:SetPoint("TOPLEFT", self.viewport, "TOPLEFT", left, -top)
    self.canvas:SetSize(canvasWidth, canvasHeight)
    BattleMaps.MapRenderer:Layout()
    if BattleMaps.Pins then BattleMaps.Pins:LayoutAll() end
end

function MapFrame:MapToViewport(x, y)
    if not self.viewWidth or not self.viewHeight then return nil end
    return self.viewLeft + (x * self.viewWidth), self.viewTop + (y * self.viewHeight)
end

function MapFrame:IsMapPointVisible(x, y, padding)
    local screenX, screenY = self:MapToViewport(x, y)
    if not screenX then return false end
    local width, height = self.viewport:GetSize()
    padding = padding or 20
    return screenX >= -padding and screenX <= width + padding
        and screenY >= -padding and screenY <= height + padding
end

function MapFrame:ResetViewOnly()
    local view = self:GetActiveView()
    if not view then return end
    view.customZoom = 1
    view.customPanX = 0.5
    view.customPanY = 0.5
    self:LayoutView()
end

function MapFrame:OnUpdate(elapsed)
    self:UpdateChromeFade(elapsed)

    if self.draggingMap then
        -- Mouse-up can occur outside the viewport after a fast drag. Poll the
        -- physical button state so panning never remains latched until the next
        -- click, especially on the larger full-screen surface.
        if type(IsMouseButtonDown) == "function" and not IsMouseButtonDown("LeftButton") then
            self:StopMapDrag()
        end

        local view = self.draggingMap and self:GetActiveView() or nil
        if view and self.viewWidth and self.viewHeight then
            local scale = UIParent:GetEffectiveScale()
            local cursorX, cursorY = GetCursorPosition()
            cursorX, cursorY = cursorX / scale, cursorY / scale
            view.customPanX = self.dragStartPanX - ((cursorX - self.dragStartX) / self.viewWidth)
            view.customPanY = self.dragStartPanY + ((cursorY - self.dragStartY) / self.viewHeight)
            self:ClampPan(view)
            self:LayoutView()
        end
    end

    -- Objective texture pulses and Test Mode player-facing rotations are
    -- lightweight visual updates that need frame-rate refreshes to remain
    -- smooth. Keep all provider/pin rebuild work on the 0.10-second throttle.
    if BattleMaps.Pins and self.frame:IsShown()
        and BattleMaps.Pins.UpdateSmoothObjectiveAnimations then
        BattleMaps.Pins:UpdateSmoothObjectiveAnimations()
    end
    if BattleMaps.Pins and self.frame:IsShown()
        and BattleMaps.Pins.UpdateSmoothTestPlayerFacing then
        BattleMaps.Pins:UpdateSmoothTestPlayerFacing()
    end

    self.pinElapsed = (self.pinElapsed or 0) + elapsed
    if self.pinElapsed >= 0.10 then
        self.pinElapsed = 0
        if BattleMaps.Pins and self.frame:IsShown() then
            BattleMaps.Pins:OnUpdate()
        end
    end
end
