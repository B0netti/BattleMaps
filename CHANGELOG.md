# BattleMaps changelog

## 3.0.19

- Fixed the Player Arrow **Pin** and **FoV** dropdown button widths so both use the same explicit width and align visually.
- Widened the FoV dropdown to match the Pin dropdown and comfortably fit labels such as **Combined**.
- Matched the Combined player-circle layering in Test Mode to live rendering and excluded that circle from teammate mouseover names.
- Stopped the native teammate hover layer from updating when live unit rendering is inactive.
- Synchronized the source and README version labels with the release metadata.

## 3.0.18

- Tidied the Units panel: **Pin style** is now **Pin**, **Arrow + circle** is now **Combined**, and the Pin/FoV dropdown buttons now align to the same width.
- Increased spacing between the two left-side Team Units checkboxes.
- Reworked the secondary Lock/Unlock control beside Test to use Blizzard's complete lock-button artwork directly instead of nesting that artwork inside another button.
- Spread the Notifications controls vertically across the available page space, with more separation between notification toggles, placement rows, offsets, and appearance controls.
- Retains the 3.0.17 native hover-layer experiment for live teammate mouseover testing.

## 3.0.17

- Replaced teammate-name hover detection with a dedicated invisible stock UnitPositionFrame populated entirely by Blizzard's native mixin.
- The hover layer uses transparent pin artwork and Blizzard's own GetMouseOverUnits/UpdateTooltips path, while BattleMaps' visible stacked pins remain unchanged.
- Enlarged the invisible hover geometry slightly to cover BattleMaps stack offsets without changing visible team-pin size.
- Kept `/bmap hoverprobe`; the diagnostic frame now reports `frame=hover` and `state=native-hover` when the new layer is active.

## 3.0.16

- Enabled mouse-motion hit testing on the teammate UnitPositionFrames without enabling mouse clicks, targeting the `GetMouseOverUnits()` = 0 failure confirmed by the live hover probe.
- Expanded `/bmap hoverprobe` with frame-over and mouse-motion-focus state so the hover pipeline can be verified directly in a battleground.

## 3.0.15

- Removed BattleMaps' extra `viewport:IsMouseOver()` gate from live teammate tooltip processing; Blizzard's native `UnitPositionFrame:GetMouseOverUnits()` is now the sole hover authority, matching the stock GroupMembersPin behavior more closely.
- Added `/bmap hoverprobe` for live diagnosis. While enabled, a small map label reports the native mouseover-unit count, whether the viewport itself reports mouseover, whether the native frame owns `GameTooltip`, and which unit-position frame is being tested.

## 3.0.14

- Reworked live teammate mouseover names to match Blizzard's current GroupMembersPin execution model: each active UnitPositionFrame now refreshes `UpdatePlayerPins()` and then runs native `UpdateTooltips(GameTooltip)` from its own `OnUpdate` while the map is hovered.
- Removed live tooltip polling from the separate BattleMaps interaction driver; that driver now handles synthetic Test Mode names only.
- Retained the Player Pin naming cleanup: the standalone team-style player marker is labeled **Circle**.

## 3.0.13

- Renamed the standalone **Team** player-pin style to **Circle** for clearer wording.
- Reworked live teammate mouseover names to use Blizzard's native `UnitPositionFrameMixin:UpdateTooltips(GameTooltip)` path directly, including BattleMaps' full World Map presentation.
- Removed the incorrect live `GetMouseOverUnits()` -> `GameTooltip:SetUnit()` interpretation; Test Mode retains its synthetic preview tooltip only.

## 3.0.12

- Removed the Compass entry from Player Pins and replaced it with **Arrow + circle**.
- Arrow + circle now layers the BattleMaps player arrow with a same-position team pin above it, so the arrow remains readable while the circular teammate marker stays visible on top.
- Existing saved Compass selections migrate to Arrow + circle automatically.

## 3.0.11

- Added an experimental Blizzard flipbook pulse behind the existing callout confirmation icon/glow so both click-feedback styles can be evaluated together.
- Restored live teammate mouseover tooltips by passing UnitPositionFrame mouseover tokens directly to Blizzard's native unit-tooltip renderer instead of resolving names/classes in addon Lua.
- Kept Test Mode synthetic mouseover names and colours for preview-only pins.

## 3.0.10

- Merged the 3.0.9 Solo Shuffle hardening: BG-system and boss-emote objective processing now exits unless BattleMaps is in a live battleground, keeping arena/Shuffle warnings out of BattleMaps.
- Added a second map lock/unlock control beside Test and tightened the title-bar padlock artwork to visually match the close button.
- Simplified the General panel by making map-header hover fading standard behavior and removing its redundant checkbox.
- Tidied teammate healer controls: the selector now sits in the center column under **Healers**, with **Icon**, **Icon + circle**, and **Ignore** choices.
- Objective timer text now uses adaptive white/yellow/red urgency coloring by default; **Custom color** opts back into a fixed user-selected color.
- Expanded node callouts to six configurable actions with **Custom 1** and **Custom 2**, plus editable modifier-click bindings with conflict swapping.
- Restored optional class-coloured teammate mouseover names using the native pin hit-test query, without changing UnitPositionFrame mouse handling. Includes stacked pins and Test Mode; live battleground validation is still required.

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
