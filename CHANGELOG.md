# BattleMaps changelog

## 3.0.8

- BG system and boss-emote/objective warnings now use the BattleMaps notification frame, including the yellow warning path.
- Player `/rw` remains Blizzard-owned and immediately restores the normal Blizzard raid-warning presentation.
- Flag messages support semantic colouring: faction names use their faction colour, carrier names use the acting faction colour, and the remaining sentence stays notification yellow.
- CTF carrier faction is inferred from the objective action: pickup/drop/capture use the opposing faction; return/recovery use the owning faction.
- Added short duplicate-event protection for announcements received through multiple BG event paths.
- Native boss-emote warnings are temporarily suppressed while BattleMaps presents their BG equivalent and restored when BattleMaps no longer owns notifications.
- Updated clean-install, category-reset, and battleground-specific defaults to the current tuned BattleMaps configuration.
- Restored Spawn tether, carried-objective color, and per-carrier trail-detail controls on the combined Flags & Carts page.
- Reordered the main settings navigation to Bases, Flags & Carts, Callouts, then Notifications.
- Added the matching Click, Alt + Click, Shift + Click, and Ctrl + Click gestures beside the callout message editors.

## 3.0.7

- Reduced stationary-node callout hitboxes to match the visible base-node texture instead of the larger objective pin frame.
- Removed the previous 6px padding and 24px minimum from the callout interaction zone, keeping hover/click activation aligned with the visible node footprint across battlegrounds.

## 3.0.6

- Fixed stationary neutral/base textures flickering during callout hover outside live battlegrounds.
- Offline, Edit Mode, and Test Mode objective previews now respect the same callout-hover suppression state as live battleground objective pins.

## 3.0.5

- Shortened Battleground UI checkbox labels to avoid repeating the section context.
- Fixed stationary base artwork flickering during callout hover by making callout suppression part of the objective pin's alpha state, so normal objective refreshes no longer restore the base between hover updates.

## 3.0.4

- Fixed **Move player auras** resetting after `/reload` by making the provider-neutral aura-layout setting authoritative and synchronizing legacy aliases one-way.
- Renamed the aura relocation option to **Move player auras** and made successful aura-provider detection display in green.
- Consolidated the former **Minimap** and **Battleground UI** General-page groups into one **Battleground UI** section.
- Callout hover now temporarily hides the complete stationary base visual, including capture timer layers/text, so the selected callout icon visually replaces the base until the pointer leaves.

## 3.0.3

- Callout icon size now scales from the actual visible stationary-base texture instead of an estimated fraction of the objective hit frame.
- Callout percentage sizing is therefore consistent across battlegrounds/providers and follows base-pin scaling/zoom proportionally.

## 3.0.2

- Fixed Eye of the Storm base markers flashing on and off when live POI refreshes alternated with authored fallback pins.
- EotS fallback duplicate detection now considers only pins populated in the current refresh pass, preventing stale pooled frames from suppressing a base before cleanup.

## 3.0.1

- Fixed WSG/Twin Peaks-style CTF flag identity becoming swapped after a flag was dropped and picked up again when Blizzard reordered compact flag API slots.
- CTF pickup/drop/capture notifications now colour the full BattleMaps notification by the acting faction; for example, an Alliance Flag pickup is Horde-coloured.

## 3.0.0

BattleMaps 3.0 is a major presentation and battleground-interaction update.

### Player map and field of view

- Added the configurable player field-of-view cone and layered map-space FoV presentation.
- Added per-battleground FoV masking support to reduce visual spill over non-playable terrain.
- Added configurable player-pin styles and independent FoV scaling.
- Fixed the FoV cone failing to appear immediately after entering a battleground until the map was panned or zoomed.

### Objective callouts

- Added clickable objective callouts for supported battleground nodes with configurable message templates.
- Improved button interaction to behave like a normal press-and-release control: hold while pressed, pop up when dragged outside, and cancel when released outside the clickable area.
- Fixed the callout icon briefly jumping away from the frame during click-drag interactions.

### Battleground notifications

- Restored BattleMaps-owned battleground notification presentation without modifying Blizzard's protected raid-warning FontStrings.
- Restored configurable notification position, text alignment, text-area width, scale, and faction colouring.
- Added independent map attachment and notification attachment controls, including automatic outside-facing attachment.
- Updated the movable notification guide so its dimensions match the configured notification text area.
- Preserved optional Blizzard notification handling while the full-screen map is open.

### Battleground objectives and reliability

- Restored Eye of the Storm base markers when the centre flag is present.
- Preserved live ownership/state updates for Eye of the Storm's Mage Tower, Draenei Ruins, Fel Reaver Ruins, and Blood Elf Tower.
- Continued reliability work across carried objectives, objective state presentation, and supported battleground layouts.

### UI and integrations

- Generalized optional player buff/debuff relocation across supported Blizzard and ElvUI aura providers.
- Improved provider detection and related options-state handling.
- Continued options, map-layout, and battleground UI integration cleanup.
