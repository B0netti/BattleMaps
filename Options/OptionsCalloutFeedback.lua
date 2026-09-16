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

function Options:CreateCalloutsPage(parent)
    OriginalCreateCalloutsPage(self, parent)

    local page = self.pages and self.pages.callouts
    local dragCheck = self.calloutDragContextCheck
    local iconsPanel = dragCheck and dragCheck.GetParent and dragCheck:GetParent()
    if not page or not iconsPanel then return end

    self.calloutDragTetherCheck = MakeCheckbox(iconsPanel, "Glow tether", 224, -91,
        function() return Callouts:GetSettings().showDragTether ~= false end,
        function(value)
            Callouts:GetSettings().showDragTether = value == true
            if Callouts.RefreshDragFeedbackSettings then Callouts:RefreshDragFeedbackSettings() end
        end)
    AddControlTooltip(self.calloutDragTetherCheck, "Glow tether",
        "Draws a glowing line from the pressed objective to the cursor. It fades in with drag distance and becomes thicker when an edge context is active.")

    self.calloutDragPreviewCheck = MakeCheckbox(iconsPanel, "Cursor preview", 418, -91,
        function() return Callouts:GetSettings().showDragPreview ~= false end,
        function(value)
            Callouts:GetSettings().showDragPreview = value == true
            if Callouts.RefreshDragFeedbackSettings then Callouts:RefreshDragFeedbackSettings() end
        end)
    AddControlTooltip(self.calloutDragPreviewCheck, "Cursor preview",
        "Shows the active edge-context string about 18 pixels above the cursor while a callout drag is inside a valid context.")

    local stateRefresher = CreateFrame("Frame", nil, page)
    stateRefresher.Refresh = function()
        local settings = Callouts:GetSettings()
        local enabled = settings.enabled ~= false and settings.dragContextEnabled ~= false
        SetControlEnabled(self.calloutDragTetherCheck, enabled)
        SetControlEnabled(self.calloutDragPreviewCheck, enabled)
    end
    self.refreshers[#self.refreshers + 1] = stateRefresher
    stateRefresher:Refresh()
end
