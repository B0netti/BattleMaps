local _, BattleMaps = ...
local Options = BattleMaps and BattleMaps.Options
if not Options or not Options.Widgets then return end

local W = Options.Widgets
local MakeCheckbox = W.MakeCheckbox
local AddControlTooltip = W.AddControlTooltip
local MakeResetIconButton = W.MakeResetIconButton
local MakePanel = W.MakePanel
local MakeSlider = W.MakeSlider

function Options:CreateCartsPage(parent)
    local db = BattleMaps.Database:Get()
    local page = CreateFrame("Frame", nil, parent)
    self.pages.carts = page
    page:SetAllPoints(parent)

    local function CartSettings()
        if self.GetCartsObjectiveTarget then
            return self:GetCartsObjectiveTarget()
        end
        return BattleMaps.Database:GetBasePinConfig(self.selectedMapID)
    end

    self.cartsGlobalCheck = MakeCheckbox(page, "Use global cart settings", 4, -2,
        function()
            return not BattleMaps.Database.MapUsesGlobalObjectiveSettings
                or BattleMaps.Database:MapUsesGlobalObjectiveSettings(self.selectedMapID)
        end,
        function(value)
            if BattleMaps.Database.SetMapUsesGlobalObjectiveSettings then
                BattleMaps.Database:SetMapUsesGlobalObjectiveSettings(self.selectedMapID, value)
            else
                db.useGlobalObjectiveSettings = value
                db.useGlobalPinSettings = db.useGlobalPlayerPinSettings ~= false and db.useGlobalObjectiveSettings ~= false
            end
            self:Refresh()
            if BattleMaps.Pins then BattleMaps.Pins:RefreshVehicles() end
        end)
    AddControlTooltip(self.cartsGlobalCheck, "Use global cart settings",
        "When enabled, the selected battleground uses the shared cart/base/flag pin settings. Disable it to edit only the selected battleground.")

    local resetCarts = MakeResetIconButton(page, "Reset carts", "Restores moving-objective/cart size for this page to its default.", function()
        if BattleMaps.Database.ResetCarts then
            BattleMaps.Database:ResetCarts(self.selectedMapID)
        else
            local target = CartSettings()
            target.vehicleObjectivePinScale = 1
        end
        self:Refresh()
        if BattleMaps.Pins then BattleMaps.Pins:RefreshVehicles() end
    end)
    resetCarts:SetPoint("TOPRIGHT", page, "TOPRIGHT", -4, -2)

    local carts = MakePanel(page, "Cart pins", 0, -34, 684, 82)
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
end

if Options.RegisterPage then
    Options:RegisterPage("carts", "Carts", 220, "CreateCartsPage", 35)
end
