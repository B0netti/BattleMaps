local _, BattleMaps = ...
local Options = BattleMaps and BattleMaps.Options
local Callouts = BattleMaps and BattleMaps.Callouts
if not Options or not Options.Widgets or not Callouts then return end

local W = Options.Widgets
local MakeCheckbox = W.MakeCheckbox
local SetControlEnabled = W.SetControlEnabled
local AddControlTooltip = W.AddControlTooltip

local OriginalCreateCalloutsPage = Options.CreateCalloutsPage
if type(OriginalCreateCalloutsPage) ~= "function" then return end

local function Reanchor(control, parent, x, y)
    if not control then return end
    control:ClearAllPoints()
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
end

function Options:CreateCalloutsPage(parent)
    OriginalCreateCalloutsPage(self, parent)

    local page = self.pages and self.pages.callouts
    local dragCheck = self.calloutDragContextCheck
    local iconsPanel = dragCheck and dragCheck.GetParent and dragCheck:GetParent()
    if not page or not iconsPanel then return end

    -- X/Y placement controls no longer add enough value to justify the space.
    -- Keep the saved values compatible, but remove the controls from the page.
    if self.calloutIconXOffsetSlider then self.calloutIconXOffsetSlider:Hide() end
    if self.calloutIconYOffsetSlider then self.calloutIconYOffsetSlider:Hide() end

    -- Compact the remaining size control to roughly half of its former width.
    if self.calloutIconSizeSlider then
        self.calloutIconSizeSlider:SetWidth(138)
        Reanchor(self.calloutIconSizeSlider, iconsPanel, 12, -30)
    end

    -- Use the space freed by the retired X/Y sliders for the gesture-feedback
    -- controls. Two rows keep the labels readable without enlarging the panel.
    Reanchor(self.calloutDragContextCheck, iconsPanel, 190, -34)

    self.calloutDragTetherCheck = MakeCheckbox(iconsPanel, "Glow tether", 382, -34,
        function() return Callouts:GetSettings().showDragTether ~= false end,
        function(value)
            Callouts:GetSettings().showDragTether = value == true
            if Callouts.RefreshDragFeedbackSettings then Callouts:RefreshDragFeedbackSettings() end
        end)
    AddControlTooltip(self.calloutDragTetherCheck, "Glow tether",
        "Draws a glowing line from the pressed objective to the cursor. It fades in with drag distance and becomes thicker only when a configured edge context is active. Callouts with no configured edge contexts do not draw a tether.")

    self.calloutDragPreviewCheck = MakeCheckbox(iconsPanel, "Cursor preview", 190, -79,
        function() return Callouts:GetSettings().showDragPreview ~= false end,
        function(value)
            Callouts:GetSettings().showDragPreview = value == true
            if Callouts.RefreshDragFeedbackSettings then Callouts:RefreshDragFeedbackSettings() end
        end)
    AddControlTooltip(self.calloutDragPreviewCheck, "Cursor preview",
        "Shows the full held callout preview about 18 pixels above the cursor. The preview updates live when a configured edge context is triggered, for example INC BS becoming INC BS 3.")

    self.calloutCenterPreviewCheck = MakeCheckbox(iconsPanel, "Center-screen preview", 382, -79,
        function() return Callouts:GetSettings().showCenterPreview == true end,
        function(value)
            Callouts:GetSettings().showCenterPreview = value == true
            if Callouts.RefreshCenterPreviewSettings then Callouts:RefreshCenterPreviewSettings() end
        end)
    AddControlTooltip(self.calloutCenterPreviewCheck, "Center-screen preview",
        "Shows the same held callout preview near the center of the screen using Blizzard's native large UI font styling. This does not write into RaidWarningFrame, avoiding the raid-warning taint path.")

    local stateRefresher = CreateFrame("Frame", nil, page)
    stateRefresher.Refresh = function()
        local settings = Callouts:GetSettings()
        local enabled = settings.enabled ~= false and settings.dragContextEnabled ~= false
        SetControlEnabled(self.calloutDragTetherCheck, enabled)
        SetControlEnabled(self.calloutDragPreviewCheck, enabled)
        SetControlEnabled(self.calloutCenterPreviewCheck, enabled)
    end
    self.refreshers[#self.refreshers + 1] = stateRefresher
    stateRefresher:Refresh()
end
