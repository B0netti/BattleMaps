local _, BattleMaps = ...
BattleMaps = BattleMaps or _G.BattleMaps
if not BattleMaps or not BattleMaps.Callouts then return end

local Callouts = BattleMaps.Callouts
local CENTER_PREVIEW_OFFSET_Y = 115

local function GetPreviewText(ui)
    if not ui or type(Callouts.GetCalloutPreviewText) ~= "function" then return "" end
    return tostring(Callouts:GetCalloutPreviewText(
        ui.pressActionKey,
        ui.node,
        tostring(ui.dragContextText or "")
    ) or "")
end

local function GetPreviewColor(ui)
    if type(Callouts.GetFeedbackActionColor) == "function" then
        return Callouts:GetFeedbackActionColor(ui)
    end
    return 1, 1, 1
end

function Callouts:EnsureCenterPreviewFrame()
    if self.centerPreviewFrame then return self.centerPreviewFrame end
    if not UIParent then return nil end

    local frame = CreateFrame("Frame", "BattleMapsCalloutCenterPreview", UIParent)
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(1880)
    frame:EnableMouse(false)
    frame:Hide()

    local text = frame:CreateFontString(nil, "OVERLAY")
    frame.text = text
    if _G.GameFontNormalHuge and text.SetFontObject then
        text:SetFontObject(_G.GameFontNormalHuge)
    elseif _G.GameFontNormalLarge and text.SetFontObject then
        text:SetFontObject(_G.GameFontNormalLarge)
    end
    text:SetPoint("CENTER", UIParent, "CENTER", 0, CENTER_PREVIEW_OFFSET_Y)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    if text.SetShadowColor then text:SetShadowColor(0, 0, 0, 1) end
    if text.SetShadowOffset then text:SetShadowOffset(1, -1) end

    frame:SetScript("OnUpdate", function()
        local ui = frame.activeUI
        if Callouts:GetPreviewMode() ~= "CENTER"
            or Callouts:GetSettings().dragContextEnabled == false
            or not ui
            or ui.pressActive ~= true then
            Callouts:HideCenterPreview()
            return
        end

        local previewText = GetPreviewText(ui)
        if previewText ~= "" then
            local r, g, b = GetPreviewColor(ui)
            text:SetText(previewText)
            text:SetTextColor(r, g, b, 1)
            text:Show()
        else
            text:Hide()
        end
    end)

    self.centerPreviewFrame = frame
    return frame
end

function Callouts:ShowCenterPreview(ui)
    if self:GetPreviewMode() ~= "CENTER"
        or self:GetSettings().dragContextEnabled == false
        or not ui
        or ui.pressActive ~= true then
        self:HideCenterPreview()
        return
    end

    local frame = self:EnsureCenterPreviewFrame()
    if not frame then return end
    frame.activeUI = ui
    frame:Show()
end

function Callouts:HideCenterPreview()
    local frame = self.centerPreviewFrame
    if not frame then return end
    frame.activeUI = nil
    if frame.text then frame.text:Hide() end
    frame:Hide()
end

function Callouts:LayoutNotificationPreview(frame)
    local notifications = BattleMaps.Notifications
    if not frame or not notifications
        or type(notifications.EnsureDisplayFrame) ~= "function" then
        return false
    end

    if type(notifications.ApplyDisplayLayout) == "function" then
        pcall(notifications.ApplyDisplayLayout, notifications)
    end

    local source = notifications:EnsureDisplayFrame()
    if not source then return false end

    local width = tonumber(source:GetWidth()) or 520
    local height = tonumber(source:GetHeight()) or 70
    local scale = tonumber(source:GetScale()) or 1
    if scale <= 0 then scale = 1 end

    frame:SetScale(scale)
    frame:SetSize(width, height)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", source, "CENTER", 0, 0)

    if frame.text and source.text and type(source.text.GetJustifyH) == "function" then
        local justifyH = source.text:GetJustifyH()
        if justifyH and justifyH ~= "" then frame.text:SetJustifyH(justifyH) end
    end
    return true
end

function Callouts:EnsureNotificationPreviewFrame()
    if self.notificationPreviewFrame then return self.notificationPreviewFrame end
    if not UIParent then return nil end

    local frame = CreateFrame("Frame", "BattleMapsCalloutNotificationPreview", UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(1890)
    frame:EnableMouse(false)
    frame:Hide()

    local text = frame:CreateFontString(nil, "OVERLAY")
    frame.text = text
    if _G.GameFontNormalHuge and text.SetFontObject then
        text:SetFontObject(_G.GameFontNormalHuge)
    elseif _G.GameFontNormalLarge and text.SetFontObject then
        text:SetFontObject(_G.GameFontNormalLarge)
    end
    text:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    text:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(true)
    if text.SetShadowColor then text:SetShadowColor(0, 0, 0, 1) end
    if text.SetShadowOffset then text:SetShadowOffset(1, -1) end

    frame:SetScript("OnUpdate", function()
        local ui = frame.activeUI
        if Callouts:GetPreviewMode() ~= "NOTIFICATIONS"
            or Callouts:GetSettings().dragContextEnabled == false
            or not ui
            or ui.pressActive ~= true then
            Callouts:HideNotificationPreview()
            return
        end

        if not Callouts:LayoutNotificationPreview(frame) then
            Callouts:HideNotificationPreview()
            return
        end

        local previewText = GetPreviewText(ui)
        if previewText ~= "" then
            local r, g, b = GetPreviewColor(ui)
            text:SetText(previewText)
            text:SetTextColor(r, g, b, 1)
            text:Show()
        else
            text:Hide()
        end
    end)

    self.notificationPreviewFrame = frame
    return frame
end

function Callouts:ShowNotificationPreview(ui)
    if self:GetPreviewMode() ~= "NOTIFICATIONS"
        or self:GetSettings().dragContextEnabled == false
        or not ui
        or ui.pressActive ~= true then
        self:HideNotificationPreview()
        return
    end

    local frame = self:EnsureNotificationPreviewFrame()
    if not frame or not self:LayoutNotificationPreview(frame) then return end
    frame.activeUI = ui
    frame:Show()
end

function Callouts:HideNotificationPreview()
    local frame = self.notificationPreviewFrame
    if not frame then return end
    frame.activeUI = nil
    if frame.text then frame.text:Hide() end
    frame:Hide()
end

function Callouts:ShowSelectedPreview(ui)
    local mode = self:GetPreviewMode()
    if mode == "CENTER" then
        self:HideNotificationPreview()
        self:ShowCenterPreview(ui)
    elseif mode == "NOTIFICATIONS" then
        self:HideCenterPreview()
        self:ShowNotificationPreview(ui)
    else
        self:HideCenterPreview()
        self:HideNotificationPreview()
    end
end

function Callouts:HideSelectedPreview()
    self:HideCenterPreview()
    self:HideNotificationPreview()
end

function Callouts:RefreshSelectedPreviewSettings()
    local ui = (self.centerPreviewFrame and self.centerPreviewFrame.activeUI)
        or (self.notificationPreviewFrame and self.notificationPreviewFrame.activeUI)
        or (self.dragFeedbackFrame and self.dragFeedbackFrame.activeUI)

    self:HideSelectedPreview()
    if ui and ui.pressActive == true then
        self:ShowSelectedPreview(ui)
    end
end

-- Keep these visual paths separate from Blizzard's RaidWarningFrame. The
-- notification-position mode borrows the BattleMaps Notifications geometry,
-- font, scale, width and alignment without writing into the live notification
-- text frame, so held previews cannot replace real battleground announcements.
local OriginalActivateDragFeedback = Callouts.ActivateDragFeedback
if type(OriginalActivateDragFeedback) == "function" then
    function Callouts:ActivateDragFeedback(ui)
        OriginalActivateDragFeedback(self, ui)
        if ui and ui.pressActive == true then
            self:ShowSelectedPreview(ui)
        else
            self:HideSelectedPreview()
        end
    end
end

local OriginalHideDragFeedback = Callouts.HideDragFeedback
if type(OriginalHideDragFeedback) == "function" then
    function Callouts:HideDragFeedback(...)
        OriginalHideDragFeedback(self, ...)
        self:HideSelectedPreview()
    end
end
