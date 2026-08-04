local _, BattleMaps = ...
local Options = BattleMaps and BattleMaps.Options
if not Options or not Options.Widgets then return end

local W = Options.Widgets
local MakePanel = W.MakePanel
local MakeCheckbox = W.MakeCheckbox
local AddControlTooltip = W.AddControlTooltip
local SetControlEnabled = W.SetControlEnabled

local function ApplyElvUIBGLayout()
    if BattleMaps.ApplyElvUIBGLayout then
        BattleMaps.ApplyElvUIBGLayout()
    end
end

local function ApplyMinimapVisibility()
    if BattleMaps.ApplyMinimapVisibility then
        BattleMaps.ApplyMinimapVisibility()
    end
end

local function AddElvUIOptions(self)
    if not self.pages or not self.pages.general then return end
    local page = self.pages.general
    if page.BattleMapsElvUIPanel then return end

    local db = BattleMaps.Database:Get()

    -- Combined personal BG-layout panel. Minimap autohide lives here because it
    -- is the layout precondition for the ElvUI aura placement option below.
    local panel = MakePanel(page, "BG layout", 0, -176, 334, 150)
    page.BattleMapsElvUIPanel = panel

    self.hideMinimapNonEpicBGCheck = MakeCheckbox(panel, "Hide minimap in non-epic BGs", 10, -34,
        function() return db.hideMinimapInNonEpicBattlegrounds == true end,
        function(value)
            db.hideMinimapInNonEpicBattlegrounds = value == true
            ApplyMinimapVisibility()
            ApplyElvUIBGLayout()
        end)

    AddControlTooltip(self.hideMinimapNonEpicBGCheck, "Hide minimap in non-epic BGs",
        "Hides the Blizzard/ElvUI minimap while inside ordinary battlegrounds supported by BattleMaps, and while BattleMaps Test mode is active for an ordinary battleground. Epic battlegrounds are ignored. Addon buttons attached to the minimap may also be hidden.")

    local status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -62)
    status:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -62)
    status:SetJustifyH("LEFT")
    panel.statusText = status

    self.elvuiBGLayoutCheck = MakeCheckbox(panel, "Apply ElvUI BG layout", 10, -82,
        function() return db.elvuiBGLayoutEnabled == true end,
        function(value)
            db.elvuiBGLayoutEnabled = value == true
            if not db.elvuiBGLayoutEnabled and BattleMaps.RestoreElvUIBGLayout then
                BattleMaps.RestoreElvUIBGLayout()
            else
                ApplyElvUIBGLayout()
            end
        end)

    AddControlTooltip(self.elvuiBGLayoutCheck, "Apply ElvUI BG layout",
        "Applies a small BattleMaps-owned ElvUI layout preset while inside supported non-epic battlegrounds, and while BattleMaps Test mode is active. The preset restores itself when BattleMaps leaves that layout state.")

    self.elvuiMovePlayerAurasCheck = MakeCheckbox(panel, "Move player buffs/debuffs to minimap area", 10, -110,
        function() return db.elvuiBGLayoutMovePlayerAuras == true end,
        function(value)
            db.elvuiBGLayoutMovePlayerAuras = value == true
            ApplyElvUIBGLayout()
        end)

    AddControlTooltip(self.elvuiMovePlayerAurasCheck, "Move player buffs/debuffs",
        "Temporarily moves ElvUI's player buffs to the hidden minimap area and anchors player debuffs below them while the BattleMaps ElvUI BG layout is active. This is intended to be used with BattleMaps' minimap autohide option.")

    local refresher = {}
    refresher.Refresh = function()
        local available = BattleMaps.IsElvUIAvailable and BattleMaps.IsElvUIAvailable() == true
        local enabled = db.elvuiBGLayoutEnabled == true
        local active = BattleMaps.elvuiBGLayoutActive == true

        if available then
            status:SetText(active and "Status: ElvUI layout active" or "Status: ElvUI detected")
            status:SetTextColor(active and 0.50 or 0.70, active and 1.00 or 0.85, active and 0.50 or 0.70)
        else
            status:SetText("Status: ElvUI not detected")
            status:SetTextColor(0.85, 0.45, 0.35)
        end

        SetControlEnabled(self.elvuiBGLayoutCheck, available)
        SetControlEnabled(self.elvuiMovePlayerAurasCheck, available and enabled)
    end
    Options.refreshers[#Options.refreshers + 1] = refresher
end

if type(Options.CreateGeneralPage) == "function" and not Options.BattleMapsElvUIOptionsWrapped then
    Options.BattleMapsElvUIOptionsWrapped = true
    local CreateGeneralPage = Options.CreateGeneralPage
    function Options:CreateGeneralPage(parent)
        CreateGeneralPage(self, parent)
        AddElvUIOptions(self)
    end
end
