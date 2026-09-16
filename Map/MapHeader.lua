local _, BattleMaps = ...
BattleMaps = BattleMaps or _G.BattleMaps
local MapFrame = BattleMaps and BattleMaps.MapFrame
if not MapFrame then return end

-- Nil intentionally means enabled so existing profiles and new installs retain
-- the discoverable branded/header presentation until the user opts out.
function MapFrame:IsMapHeaderEnabled()
    local db = BattleMaps.Database and BattleMaps.Database:Get()
    return not db or db.showMapHeader ~= false
end

function MapFrame:SetMapHeaderEnabled(enabled)
    local db = BattleMaps.Database and BattleMaps.Database:Get()
    if db then db.showMapHeader = enabled == true end
    self:UpdateChromeFade(0, true)
end

local OriginalUpdateChromeFade = MapFrame.UpdateChromeFade
if type(OriginalUpdateChromeFade) == "function" then
    function MapFrame:UpdateChromeFade(elapsed, force)
        -- World Map mode already owns its own no-header presentation. Layout
        -- editing always forces the floating-map header visible because the
        -- lock state and frame controls are functional UI there, not branding.
        if self.worldMapMode or self.editMode or self:IsMapHeaderEnabled() then
            return OriginalUpdateChromeFade(self, elapsed, force)
        end

        if not self.titleBar or not self.frame then return end
        self.chromeAlpha = 0
        self.titleBar:SetAlpha(0)
        if self.SetChromeInteractive then self:SetChromeInteractive(false) end
        if self.UpdateViewportChromeInset then
            self:UpdateViewportChromeInset(0, force)
        end
    end
end

local OriginalGetContextMenuItems = MapFrame.GetContextMenuItems
if type(OriginalGetContextMenuItems) == "function" then
    function MapFrame:GetContextMenuItems()
        local original = OriginalGetContextMenuItems(self)
        if self.worldMapMode then return original end

        local optionsItem, layoutItem, cancelItem
        for _, item in ipairs(original or {}) do
            local text = tostring(item and item.text or "")
            if text == "Options" then
                optionsItem = item
            elseif text == "Lock Layout" or text == "Unlock Layout" then
                layoutItem = item
            elseif text == "Cancel" then
                cancelItem = item
            end
        end

        local items = {
            {
                text = "Hide BattleMaps",
                action = function()
                    self:HideContextMenu()
                    if self.frame then self.frame:Hide() end
                end,
            },
            {
                text = self:IsMapHeaderEnabled() and "Hide Map Header" or "Show Map Header",
                action = function()
                    self:SetMapHeaderEnabled(not self:IsMapHeaderEnabled())
                end,
            },
        }

        if layoutItem then items[#items + 1] = layoutItem end
        if optionsItem then items[#items + 1] = optionsItem end
        if cancelItem then items[#items + 1] = cancelItem end
        return items
    end
end
