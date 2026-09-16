local _, BattleMaps = ...
local Options = BattleMaps and BattleMaps.Options
local MapFrame = BattleMaps and BattleMaps.MapFrame
if not Options or not Options.Widgets then return end

local W = Options.Widgets
local MakeCheckbox = W.MakeCheckbox
local AddControlTooltip = W.AddControlTooltip

local function ReplaceVisibleText(root, oldText, newText)
    if not root then return end
    if root.GetRegions then
        for _, region in ipairs({ root:GetRegions() }) do
            if region and region.GetText and region.SetText and region:GetText() == oldText then
                region:SetText(newText)
            end
        end
    end
    if root.GetChildren then
        for _, child in ipairs({ root:GetChildren() }) do
            ReplaceVisibleText(child, oldText, newText)
        end
    end
end

local OriginalCreateGeneralPage = Options.CreateGeneralPage
if type(OriginalCreateGeneralPage) ~= "function" then return end

function Options:CreateGeneralPage(parent)
    OriginalCreateGeneralPage(self, parent)

    local page = self.pages and self.pages.general
    if not page then return end

    -- Shorter labels read more cleanly in the compact Options panel.
    ReplaceVisibleText(page, "Show automatically in battlegrounds", "Show in BG")
    ReplaceVisibleText(page, "Hide automatically after leaving", "Hide after leaving")

    local db = BattleMaps.Database:Get()
    self.showMapHeaderCheck = MakeCheckbox(page, "Show map header on hover", 360, -292,
        function()
            if MapFrame and MapFrame.IsMapHeaderEnabled then
                return MapFrame:IsMapHeaderEnabled()
            end
            return db.showMapHeader ~= false
        end,
        function(value)
            if MapFrame and MapFrame.SetMapHeaderEnabled then
                MapFrame:SetMapHeaderEnabled(value == true)
            else
                db.showMapHeader = value == true
            end
        end)

    AddControlTooltip(self.showMapHeaderCheck, "Map header",
        "Shows the BattleMaps banner, battleground name, Lock control, and Close button when hovering the floating map. Disable it for a map-only presentation. The header is still forced visible while the layout is unlocked, and it can be shown again from the map's right-click menu.")
end
