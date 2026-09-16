local _, BattleMaps = ...
local Options = BattleMaps and BattleMaps.Options
local Callouts = BattleMaps and BattleMaps.Callouts
if not Options or not Options.Widgets or not Callouts then return end

local W = Options.Widgets
local MakeCheckbox = W.MakeCheckbox
local MakeDropdown = W.MakeDropdown
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

    Reanchor(self.calloutDragContextCheck, iconsPanel, 190, -34)

    self.calloutDragTetherCheck = MakeCheckbox(iconsPanel, "Glow tether", 382, -34,
        function() return Callouts:GetSettings().showDragTether ~= false end,
        function(value)
            Callouts:GetSettings().showDragTether = value == true
            if Callouts.RefreshDragFeedbackSettings then Callouts:RefreshDragFeedbackSettings() end
        end)
    AddControlTooltip(self.calloutDragTetherCheck, "Glow tether",
        "Draws a glowing line from the pressed objective to the cursor. It fades in with drag distance and becomes thicker only when a configured edge context is active. Callouts with no configured edge contexts do not draw a tether.")

    self.calloutPreviewModeDropdown = MakeDropdown(iconsPanel, "Preview", 190, -72, 360, {
        { value = "OFF", label = "Disabled" },
        { value = "CURSOR", label = "At cursor" },
        { value = "CENTER", label = "Center screen" },
        { value = "NOTIFICATIONS", label = "Same as Notifications" },
    }, function()
        return Callouts:GetPreviewMode()
    end, function(value)
        Callouts:SetPreviewMode(value)
    end, true)
    AddControlTooltip(self.calloutPreviewModeDropdown, "Callout preview",
        "Chooses one place to show the held callout text. At cursor follows the pointer; Center screen uses Blizzard-style large text; Same as Notifications uses the configured BattleMaps notification position, attachment, width, scale, and alignment. Preview text uses the active callout's color.")

    local stateRefresher = CreateFrame("Frame", nil, page)
    stateRefresher.Refresh = function()
        local settings = Callouts:GetSettings()
        local enabled = settings.enabled ~= false and settings.dragContextEnabled ~= false
        SetControlEnabled(self.calloutDragTetherCheck, enabled)
        SetControlEnabled(self.calloutPreviewModeDropdown, enabled)
    end
    self.refreshers[#self.refreshers + 1] = stateRefresher
    stateRefresher:Refresh()
end
