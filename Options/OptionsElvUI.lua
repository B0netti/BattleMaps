local _, BattleMaps = ...

-- Compatibility shim.
--
-- BattleMaps 2.8 generalized the battleground HUD-layout controls so the same
-- UI owns Blizzard and ElvUI aura placement. The older ElvUI-specific options
-- wrapper also created its own "BG layout" controls, which results in two
-- panels occupying the same coordinates when both generations are present.
--
-- Runtime ElvUI integration remains in Integrations/ElvUIIntegration.lua.
-- Keep this file in the TOC for existing package/load-order compatibility, but
-- do not create a second set of options controls here.
