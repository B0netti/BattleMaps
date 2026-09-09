local _, BattleMaps = ...
local Options = BattleMaps and BattleMaps.Options
if not Options then return end

local W = Options.Widgets
local SetControlEnabled = W and W.SetControlEnabled

-- 2.9.7 options polish:
--   * make ElvUI availability independent of whether its player-aura frames
--     have been instantiated at the exact moment the options panel refreshes;
--   * keep tall options pages inside their own window and on-screen;
--   * leave the runtime ElvUI aura relocation implementation untouched.

-- Provider detection and relocation are owned by
-- Integrations/AuraLayout.lua. The options layer only presents that state.
local function ResolveProvider()
    if type(BattleMaps.ResolveAuraLayoutProvider) == "function" then
        local ok, provider = pcall(BattleMaps.ResolveAuraLayoutProvider)
        if ok and type(provider) == "string" then return provider end
    end
    return "Unavailable"
end

local function SafeText(region)
    if not region or type(region.GetText) ~= "function" then return nil end
    local ok, value = pcall(region.GetText, region)
    if not ok or type(value) ~= "string" then return nil end
    return value
end

local function WalkFrame(frame, fn, visited)
    if not frame or type(frame) ~= "table" and type(frame) ~= "userdata" then return end
    visited = visited or {}
    if visited[frame] then return end
    visited[frame] = true

    fn(frame)

    if type(frame.GetRegions) == "function" then
        local regions = { frame:GetRegions() }
        for _, region in ipairs(regions) do
            fn(region)
        end
    end

    if type(frame.GetChildren) == "function" then
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do
            WalkFrame(child, fn, visited)
        end
    end
end

local function EnableControlFromLabel(labelRegion, enabled)
    if not labelRegion then return end

    local owner = type(labelRegion.GetParent) == "function" and labelRegion:GetParent() or nil
    for _ = 1, 4 do
        if not owner then break end
        if SetControlEnabled then
            local ok = pcall(SetControlEnabled, owner, enabled)
            if ok then return end
        end
        if type(owner.SetControlEnabled) == "function" then
            pcall(owner.SetControlEnabled, owner, enabled)
            return
        end
        if type(owner.SetEnabled) == "function" then
            pcall(owner.SetEnabled, owner, enabled)
            return
        end
        owner = type(owner.GetParent) == "function" and owner:GetParent() or nil
    end
end

local function GetControlLabel(control)
    if not control then return nil end
    if control.Text and type(control.Text.GetText) == "function" then
        local ok, text = pcall(control.Text.GetText, control.Text)
        if ok and type(text) == "string" then return text end
    end
    return nil
end

local AURA_CHECKBOX_FIELDS = {
    "movePlayerAurasToMinimapCheck",
    "movePlayerAurasCheck",
    "playerAuraRelocationCheck",
    "bgLayoutMovePlayerAurasCheck",
    "elvuiMovePlayerAurasCheck",
}

local function IsAuraCheckbox(control)
    if not control or type(control.GetChecked) ~= "function" then return false end
    local text = GetControlLabel(control)
    return text == "Move player auras"
        or text == "Move player buffs/debuffs into minimap area"
        or text == "Move player buffs/debuffs to minimap area"
end

local function FindAuraCheckbox(page)
    -- Prefer the actual control handles used by BattleMaps options modules.
    -- This is much more reliable than reverse-walking the rendered FontString.
    for _, field in ipairs(AURA_CHECKBOX_FIELDS) do
        local control = Options[field]
        if IsAuraCheckbox(control) then
            return control
        end
    end

    -- Fallback: find a CheckButton directly.
    local found
    WalkFrame(page, function(region)
        if found then return end
        if IsAuraCheckbox(region) then
            found = region
        end
    end)
    if found then return found end

    -- Last fallback: find the label FontString, then walk upward until the
    -- owning CheckButton is found.
    WalkFrame(page, function(region)
        if found then return end
        local label = SafeText(region)
        if label ~= "Move player auras"
            and label ~= "Move player buffs/debuffs into minimap area"
            and label ~= "Move player buffs/debuffs to minimap area" then
            return
        end

        local owner = type(region.GetParent) == "function" and region:GetParent() or nil
        for _ = 1, 5 do
            if not owner then break end
            if type(owner.GetChecked) == "function" then
                found = owner
                break
            end
            owner = type(owner.GetParent) == "function" and owner:GetParent() or nil
        end
    end)

    return found
end

function BattleMaps.GetAuraLayoutOptionControl()
    local page = Options.pages and Options.pages.general
    if not page then return nil end
    return FindAuraCheckbox(page)
end

local function BindAuraCheckbox(page)
    local control = FindAuraCheckbox(page)
    if not control then return nil end

    -- Publish the real visible control for diagnostics/compatibility only.
    -- The checkbox's getter/setter in OptionsGeneral now talks directly to the
    -- canonical SavedVariables key; do not replace its OnClick handler or copy
    -- the rendered checkbox state back into the database.
    BattleMaps.auraLayoutOptionControl = control
    return control
end

local function RefreshAuraProviderUI()
    local page = Options.pages and Options.pages.general
    if not page then return end

    local provider = ResolveProvider()
    local available = provider ~= "Unavailable"
    local db = BattleMaps.Database and BattleMaps.Database.Get and BattleMaps.Database:Get() or nil
    local canMove = available and type(db) == "table" and db.hideMinimapInNonEpicBattlegrounds == true

    local boundAuraControl = BindAuraCheckbox(page)

    -- Prefer explicit handles if the current General-page implementation
    -- exposes them.
    local knownControls = {
        Options.movePlayerAurasToMinimapCheck,
        Options.movePlayerAurasCheck,
        Options.playerAuraRelocationCheck,
        Options.bgLayoutMovePlayerAurasCheck,
        Options.elvuiMovePlayerAurasCheck,
    }
    for _, control in ipairs(knownControls) do
        if control then
            if SetControlEnabled then
                pcall(SetControlEnabled, control, canMove)
            elseif type(control.SetControlEnabled) == "function" then
                pcall(control.SetControlEnabled, control, canMove)
            elseif type(control.SetEnabled) == "function" then
                pcall(control.SetEnabled, control, canMove)
            end
        end
    end

    if boundAuraControl then
        if SetControlEnabled then
            pcall(SetControlEnabled, boundAuraControl, canMove)
        elseif type(boundAuraControl.SetEnabled) == "function" then
            pcall(boundAuraControl.SetEnabled, boundAuraControl, canMove)
        end
    end

    -- The General page has changed names a few times, so also locate the two
    -- visible widgets by their user-facing text. This is intentionally limited
    -- to the options frame and does not inspect gameplay UI.
    WalkFrame(page, function(region)
        local text = SafeText(region)
        if not text then return end

        if text:match("^Aura provider:%s*") then
            if type(region.SetText) == "function" then
                region:SetText("Aura provider: " .. provider)
            end
            if type(region.SetFontObject) == "function" and GameFontHighlightSmall then
                pcall(region.SetFontObject, region, GameFontHighlightSmall)
            end
            if type(region.SetTextColor) == "function" then
                if available then
                    region:SetTextColor(0.25, 1.00, 0.35, 1)
                else
                    region:SetTextColor(0.85, 0.45, 0.35, 1)
                end
            end
        elseif text == "Move player auras"
            or text == "Move player buffs/debuffs into minimap area"
            or text == "Move player buffs/debuffs to minimap area" then
            EnableControlFromLabel(region, canMove)
        end
    end)
end

-- The old page heights predate the additional Callouts controls and the
-- combined Flags & Carts page. Give those pages enough logical height for
-- their children, then scale the whole options window only when required to
-- fit the user's UIParent. This keeps controls inside the frame instead of
-- letting them draw below its bottom border.
local PAGE_HEIGHTS = {
    callouts = 560,
    flags = 720,
    notifications = 720,
}

local function ApplyPageHeightOverrides()
    if not Options.GetSettingsPageDefinition then return end
    for key, height in pairs(PAGE_HEIGHTS) do
        local definition = Options:GetSettingsPageDefinition(key)
        if definition then
            definition.height = math.max(tonumber(definition.height) or 0, height)
        end
    end
end

local function FitOptionsFrame()
    local frame = Options.frame
    if not frame or not UIParent or type(UIParent.GetHeight) ~= "function" then return end

    ApplyPageHeightOverrides()

    local activeKey = Options.activePage or "general"
    local targetHeight = Options.GetSettingsPageHeight and Options:GetSettingsPageHeight(activeKey)
        or frame:GetHeight()
    targetHeight = tonumber(targetHeight) or frame:GetHeight()

    if math.abs((frame:GetHeight() or 0) - targetHeight) > 0.5 then
        frame:SetHeight(targetHeight)
    end

    local screenHeight = tonumber(UIParent:GetHeight()) or targetHeight
    local screenWidth = type(UIParent.GetWidth) == "function" and tonumber(UIParent:GetWidth()) or 0
    local frameWidth = tonumber(frame:GetWidth()) or 720

    local maxHeight = math.max(320, screenHeight - 24)
    local maxWidth = screenWidth > 0 and math.max(480, screenWidth - 24) or frameWidth

    local scale = math.min(1, maxHeight / math.max(1, targetHeight), maxWidth / math.max(1, frameWidth))
    scale = math.max(0.68, scale)

    if type(frame.SetScale) == "function" then
        frame:SetScale(scale)
    end
end

ApplyPageHeightOverrides()

if type(Options.Refresh) == "function" and not Options.BattleMaps297RefreshWrapped then
    Options.BattleMaps297RefreshWrapped = true
    local OriginalRefresh = Options.Refresh
    function Options:Refresh(...)
        local result = OriginalRefresh(self, ...)
        RefreshAuraProviderUI()
        FitOptionsFrame()
        return result
    end
end

if type(Options.ShowPage) == "function" and not Options.BattleMaps297ShowPageWrapped then
    Options.BattleMaps297ShowPageWrapped = true
    local OriginalShowPage = Options.ShowPage
    function Options:ShowPage(key, ...)
        local result = OriginalShowPage(self, key, ...)
        FitOptionsFrame()
        RefreshAuraProviderUI()
        return result
    end
end

if type(Options.Open) == "function" and not Options.BattleMaps297OpenWrapped then
    Options.BattleMaps297OpenWrapped = true
    local OriginalOpen = Options.Open
    function Options:Open(...)
        local result = OriginalOpen(self, ...)
        FitOptionsFrame()
        RefreshAuraProviderUI()
        return result
    end
end
