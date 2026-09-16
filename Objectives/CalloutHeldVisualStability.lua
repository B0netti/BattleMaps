local _, BattleMaps = ...
BattleMaps = BattleMaps or _G.BattleMaps
if not BattleMaps or not BattleMaps.Callouts then return end

local Callouts = BattleMaps.Callouts

-- Modifier polling runs frequently while a callout is held. Once the pressed
-- action has already been resolved, re-running SetChoiceAction every poll is
-- unnecessary and can visibly re-show/reset the icon while other held/cancel
-- state code is updating. Keep the existing visual untouched until either the
-- action changes or the visual genuinely needs to be restored.
local OriginalSetChoiceAction = Callouts.SetChoiceAction
if type(OriginalSetChoiceAction) == "function" then
    function Callouts:SetChoiceAction(visual, actionKey)
        if visual
            and visual.pressed == true
            and visual.actionKey == actionKey
            and visual.IsShown
            and visual:IsShown() then
            return
        end
        return OriginalSetChoiceAction(self, visual, actionKey)
    end
end
