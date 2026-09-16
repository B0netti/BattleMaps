local _, BattleMaps = ...
BattleMaps = BattleMaps or _G.BattleMaps
if not BattleMaps or not BattleMaps.Callouts then return end

local Callouts = BattleMaps.Callouts

local MODE_PREFIXES = {
    "",
    "alt-",
    "shift-",
    "ctrl-",
    "alt-shift-",
    "alt-ctrl-",
    "ctrl-shift-",
    "alt-ctrl-shift-",
}
local CONTEXT_KEYS = { "top", "right", "bottom", "left" }

local function IsLiveBattleground()
    local battlegrounds = BattleMaps.Battlegrounds
    if battlegrounds and type(battlegrounds.IsInBattleground) == "function" then
        local ok, live = pcall(battlegrounds.IsInBattleground, battlegrounds)
        if ok then return live == true end
    end

    if IsInInstance then
        local inInstance, instanceType = IsInInstance()
        return inInstance == true and instanceType == "pvp"
    end
    return false
end

function Callouts:IsLiveCalloutEnvironment()
    return IsLiveBattleground()
end

local function DisableSecureCalloutActions(button)
    if not button or not button.SetAttribute then return end

    button:SetAttribute("callout-live", 0)
    button:SetAttribute("drag-enabled", 0)
    button:SetAttribute("drag-expanded", nil)
    button:SetAttribute("drag-selected-zone", nil)
    button:SetAttribute("drag-release-cancelled", nil)

    for _, prefix in ipairs(MODE_PREFIXES) do
        for suffix = 1, 3 do
            local attr = prefix .. "macrotext" .. suffix
            button:SetAttribute(attr, "")
            button:SetAttribute("drag-base-" .. attr, "")
            button:SetAttribute("drag-action-" .. prefix .. suffix, "")
            for _, contextKey in ipairs(CONTEXT_KEYS) do
                button:SetAttribute("drag-" .. contextKey .. "-" .. attr, "")
            end
        end
    end
end

-- Keep the preview/test presentation available outside battlegrounds, but make
-- the protected action button a true no-op there. This prevents /instance or
-- edge-drag macros from reaching WoW's macro parser while testing gestures in
-- a city/world zone. Entering a live battleground rebuilds the secure actions.
local OriginalApplySecureAttributes = Callouts.ApplySecureAttributes
if type(OriginalApplySecureAttributes) == "function" then
    function Callouts:ApplySecureAttributes(ui)
        local ok = OriginalApplySecureAttributes(self, ui)
        local button = ui and ui.button
        if not button then return ok end

        if IsLiveBattleground() then
            button:SetAttribute("callout-live", 1)
        else
            DisableSecureCalloutActions(button)
        end
        return ok
    end
end

-- Environment transitions must refresh protected attributes. PLAYER_ENTERING_WORLD
-- covers the ordinary BG load/unload path; ZONE_CHANGED_NEW_AREA catches edge
-- cases where the instance state settles just after the first event.
local environmentDriver = CreateFrame("Frame")
environmentDriver:RegisterEvent("PLAYER_LOGIN")
environmentDriver:RegisterEvent("PLAYER_ENTERING_WORLD")
environmentDriver:RegisterEvent("ZONE_CHANGED_NEW_AREA")
environmentDriver:RegisterEvent("PLAYER_REGEN_ENABLED")

environmentDriver:SetScript("OnEvent", function(_, event)
    local live = IsLiveBattleground()
    if event ~= "PLAYER_REGEN_ENABLED" and Callouts._lastLiveCalloutEnvironment == live then
        return
    end
    Callouts._lastLiveCalloutEnvironment = live

    if InCombatLockdown and InCombatLockdown() then
        Callouts.pendingSecureRefresh = true
        return
    end

    if Callouts.initialized and type(Callouts.RefreshSecureActions) == "function" then
        Callouts:RefreshSecureActions()
        if type(Callouts.ScanPins) == "function" then Callouts:ScanPins(false) end
    end
end)
