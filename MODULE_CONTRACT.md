# BattleMaps module contract

This is a working contract for keeping the refactor cohesive. It is not loaded by WoW.

## Core/Core.lua
Owns the add-on namespace, shared constants, clamp/debug helpers, map identity helpers, and cross-module services. It should not grow feature-specific pin, timer, or options logic.

## Core/Database.lua / Core/Battlegrounds.lua
Own saved defaults, per-battleground configuration, battleground metadata, and migration-safe config accessors.

## Integrations/ElvUIIntegration.lua
Owns optional ElvUI detection/integration only. It should not own BattleMaps runtime rendering logic.

## Map/MapFrame.lua / Map/MapRenderer.lua
Own the independent Battlefield Map frame, map texture rendering, viewport behaviour, anchoring, zoom/pan, drag/configure mode, and custom map assets. Custom map texture registration is consolidated into MapRenderer.lua.

## Pins/Pins.lua
Owns pin lifecycle and renderer-owned state: pools, placement, refresh orchestration, update loop, pings, and low-level objective pin helpers used by the objective modules. Objective-event texture pulses belong in ObjectivePins.lua. Capture-timer visual layers belong in ObjectiveTimers.lua.

## Pins/UnitPins.lua
Owns friendly/team/unit pin collection and visibility rules. It should not contain stationary objective or carried-objective logic.

## Objectives/ObjectiveRules.lua
Pure rules/data layer. Owns objective key normalisation, aliases, map/category rules, objective matching, and state inference. It should not create frames, start animations, or mutate live UI.

## Objectives/ObjectiveTextures.lua
Owns custom objective texture lookup and CTF/objective texture resolution. It may update objective texture state, but should not own carried-objective placement or capture-timer lifecycle. If it extends `Pins:RecordObjectiveFactionMessage`, it must capture and call the previous handler before doing Deephaul/CTF/EotS-specific work. The previous handler owns stationary objective assault/capture records and capture-fill timers.

## Objectives/ObjectivePins.lua
Owns stationary objective-like pins: vehicles, POIs, scenario pins, vignettes, Deephaul synthetic crystal, fallback objective markers, and objective-event texture pulse overlays attached to stationary objective pins.

## Objectives/PreviewPins.lua
Owns offline/edit/test previews for stationary objectives, carried objectives, vehicles, cached POI artwork, and objective-preview movement/effects. It must not create player arrows, teammate pins, healer overlays, death markers, or unit tooltips; those belong exclusively to UnitPins.lua.

## Objectives/ObjectiveTimers.lua
Owns capture-timer lifecycle, capture-progress rendering layers, capture-progress tooltip text, timer test mode, and tooltip installation helpers used by objective pins. It must load before ObjectivePins.lua because ObjectivePins captures Pins.Private.SetTooltip at file load.

## Objectives/CarriedObjectives.lua
Owns carried-objective placement and effects: WSG/TP/EotS/Deephaul carried flags/crystals, carried-objective trail breadcrumbs, and carried-objective flash overlays.

## Options/Options*.lua
Own UI construction and saved-setting mutation only. Options may call high-level refresh methods, but should avoid implementing runtime gameplay logic.

## Core/Events.lua
Own event registration and dispatch. It should translate game events/messages into calls on Core/Pins/Notifications, not contain detailed rendering logic.

## General rules
- Do not add a new file for every small feature. Prefer expanding the closest cohesive module.
- Avoid scattering core `Pins:` methods across many files unless the file owns that whole feature family.
- Keep load-order assumptions explicit in the TOC and in this contract.
- Data/rules modules should not create frames or animations.
- Event modules should dispatch, not render.
- `Pins:RecordObjectiveFactionMessage` is a chained handler. New modules must not replace it without preserving the previous implementation.
