local _, BattleMaps = ...
local Options = BattleMaps and BattleMaps.Options
if not Options or not Options.Widgets then return end

local W = Options.Widgets
local AddControlTooltip = W.AddControlTooltip
local MakeResetIconButton = W.MakeResetIconButton
local MakePanel = W.MakePanel
local MakeSlider = W.MakeSlider

-- Carts no longer own a navigation page. Flags & Carts calls this helper to
-- embed the cart controls without merging the underlying cart/objective code.
function Options:AddCartsSection(page, topOffset)
    local function CartSettings()
        if self.GetCartsObjectiveTarget then return self:GetCartsObjectiveTarget() end
        return BattleMaps.Database:GetBasePinConfig(self.selectedMapID)
    end

    local carts = MakePanel(page, "Cart pins", 0, tonumber(topOffset) or -124, 684, 82)

    local resetCarts = MakeResetIconButton(carts, "Reset carts",
        "Restores moving-objective/cart size to its default.", function()
            if BattleMaps.Database.ResetCarts then
                BattleMaps.Database:ResetCarts(self.selectedMapID)
            else
                CartSettings().vehicleObjectivePinScale = 1
            end
            self:Refresh()
            if BattleMaps.Pins then BattleMaps.Pins:RefreshVehicles() end
        end)
    resetCarts:SetPoint("TOPRIGHT", carts, "TOPRIGHT", -8, -7)

    self.vehicleObjectiveSlider = MakeSlider(carts, "Moving objectives", 12, -28, 0.50, 2.50, 0.05,
        function()
            local target = CartSettings()
            return tonumber(target.vehicleObjectivePinScale) or tonumber(target.objectivePinScale) or 1
        end,
        function(value)
            CartSettings().vehicleObjectivePinScale = value
            if BattleMaps.Pins then BattleMaps.Pins:RefreshVehicles() end
        end,
        function(value) return string.format("%.2fx", value) end,
        304)
    AddControlTooltip(self.vehicleObjectiveSlider, "Moving objectives",
        "Scales objective-like vehicles and carts, such as Silvershard Mines carts and Deephaul Ravine crystal carts.")

    return carts
end
