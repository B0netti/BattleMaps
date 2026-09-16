local _, BattleMaps = ...
BattleMaps = BattleMaps or _G.BattleMaps
if not BattleMaps or not BattleMaps.Callouts then return end

local Callouts = BattleMaps.Callouts
Callouts.DEFAULTS.showCenterPreview = false

local CENTER_PREVIEW_OFFSET_Y = 115

local function GetNativeWarningColor()
    local info = type(ChatTypeInfo) == "table" and ChatTypeInfo.RAID_WARNING or nil
    if type(info) == "table" then
        return tonumber(info.r) or 1, tonumber(info.g) or 0.35, tonumber(info.b) or 0.10
    end
    return 1, 0.35, 0.10
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
    local r, g, b = GetNativeWarningColor()
    text:SetTextColor(r, g, b, 1)

    frame:SetScript("OnUpdate", function()
        local ui = frame.activeUI
        local settings = Callouts:GetSettings()
        if settings.showCenterPreview ~= true
            or settings.dragContextEnabled == false
            or not ui
            or ui.pressActive ~= true then
            Callouts:HideCenterPreview()
            return
        end

        local contextText = tostring(ui.dragContextText or "")
        local previewText = ""
        if type(Callouts.GetCalloutPreviewText) == "function" then
            previewText = tostring(Callouts:GetCalloutPreviewText(
                ui.pressActionKey,
                ui.node,
                contextText
            ) or "")
        end

        if previewText ~= "" then
            text:SetText(previewText)
            text:Show()
        else
            text:Hide()
        end
    end)

    self.centerPreviewFrame = frame
    return frame
end

function Callouts:ShowCenterPreview(ui)
    local settings = self:GetSettings()
    if settings.showCenterPreview ~= true
        or settings.dragContextEnabled == false
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

function Callouts:RefreshCenterPreviewSettings()
    local frame = self.centerPreviewFrame
    if frame and frame.activeUI and frame.activeUI.pressActive == true then
        self:ShowCenterPreview(frame.activeUI)
    elseif self:GetSettings().showCenterPreview ~= true then
        self:HideCenterPreview()
    end
end

-- Keep this visual path separate from Blizzard's RaidWarningFrame. The latter
-- has already been implicated in UI-taint failures when skinning addons such as
-- ElvUI touch its message layout. This preview borrows Blizzard's font/color
-- language without adding messages to that frame.
local OriginalActivateDragFeedback = Callouts.ActivateDragFeedback
if type(OriginalActivateDragFeedback) == "function" then
    function Callouts:ActivateDragFeedback(ui)
        OriginalActivateDragFeedback(self, ui)
        if ui and ui.pressActive == true then
            self:ShowCenterPreview(ui)
        else
            self:HideCenterPreview()
        end
    end
end

local OriginalHideDragFeedback = Callouts.HideDragFeedback
if type(OriginalHideDragFeedback) == "function" then
    function Callouts:HideDragFeedback(...)
        OriginalHideDragFeedback(self, ...)
        self:HideCenterPreview()
    end
end
