# BattleMaps Project Status

*Last updated: 2026-08-03*

## Project Summary

BattleMaps is a World of Warcraft Retail PvP addon that enhances the Battlefield Map with clearer unit pins, objective tracking, capture information, notifications, trails, stacking behaviour, and battleground-specific presentation.

The addon is developed and published under the author name **Bonetti**.

## Current Working Build

* Current version: `2.6.19-kotmogu-raid-notice-returns`
* Primary client target: World of Warcraft Retail `12.0.7`
* PTR compatibility is considered where practical, particularly for `12.1.0`.
* Confirm the version in the TOC and source before making the first new build from this repository.

## Current Milestone

The current working build has reliable Temple of Kotmogu objective tracking under normal testing conditions.

Recent work has focused on:

* Temple of Kotmogu stationary and carried orb tracking
* objective notifications
* carried-objective trails
* spawn tether trails
* faction and objective colour presentation
* avoiding taint caused by interaction with Blizzard map pins
* improving the player pin design

The next planned feature is a selectable player-pin style with an optional independently scalable vision cone.

## Stable Features

The following systems are considered functional unless current testing proves otherwise:

### Battlefield Map

* Separate configurable Battlefield Map frame
* unlock and lock positioning controls
* map scaling and positioning
* Test Mode
* battleground-specific objective handling
* World Map overlay support

### Player and Team Pins

* configurable player-pin size and colour
* healer identification
* class-coloured healer pins
* combat and out-of-combat team-pin textures
* player exclusion from team-pin stacking
* deterministic team-pin behaviour based on raid index
* configurable pin layering
* team-pin mouseover tooltips in supported contexts

### Objectives

* bases and capture-state presentation
* flags in Warsong Gulch and Twin Peaks
* Eye of the Storm flag handling
* Temple of Kotmogu stationary and carried orbs
* Silvershard Mines cart support
* Deephaul Ravine crystal support
* Seething Shore objective support
* battleground-specific capture timers and notifications

### Notifications and Timers

* capture notifications
* faction-coloured notification text
* class-coloured player names
* configurable notification anchoring
* capture pulse and flash behaviour
* Blitz-specific timing where implemented

### Trails

* carried-objective breadcrumbs
* glow-wake trail
* spawn tether trail
* configurable trail colour
* objective-coloured trail option
* adjustable trail presentation

## Recently Validated

The following behaviour has recently been tested successfully:

* Temple of Kotmogu carried objectives remain broadly reliable during normal matches.
* Spawn tether presentation works and is visually useful.
* Temple of Kotmogu notifications are displaying.
* Taint errors associated with Blizzard map pins stop when the native Blizzard Battlefield Map is not opened.
* Normal BattleMaps use without the native Blizzard Battlefield Map does not currently produce the previously observed map-pin taint errors.

These findings are based on in-game testing and should not be treated as guarantees for every map state or client update.

## Work in Progress

### New Player-Pin Presentation

Planned implementation:

* Add selectable player-pin texture options.
* Include `player_compass.tga`.
* Add an optional vision cone using `player_vision_cone.tga`.
* Provide a separate vision-cone enable setting.
* Provide an independent vision-cone scale slider.
* Do not force the cone scale to use the player-pin size.
* Preserve existing player-pin colour behaviour where compatible.
* Ensure Test Mode represents the selected player-pin style.

Required layering:

* Vision cone behind team-member pins.
* Vision cone behind carried-objective pins.
* Vision cone in front of stationary-objective pins.
* Existing player-pin stacking and layer adjustments must be reviewed rather than bypassed.
* The cone must not interfere with mouse input or Blizzard map-pin interaction.

### Trail Expansion

Possible future work:

* Apply spawn tether presentation to Warsong Gulch.
* Apply spawn tether presentation to Twin Peaks.
* Use approximate flag-spawn coordinates where no reliable native source exists.
* Improve breadcrumb visibility in live matches.
* Review trail-pool sizing and performance with multiple simultaneous carriers.

## Known Issues and Unresolved Risks

### Blizzard Map Taint

Opening the native Blizzard Battlefield Map while BattleMaps is active has previously produced repeated protected-action errors involving:

* `SetPropagateMouseClicks`
* `SetPropagateMouseMotion`
* Blizzard shared map POI templates
* `AreaPOIDataProvider`
* Blizzard map-pin acquisition

BattleMaps must not modify, hook, acquire, reparent, or change mouse propagation on Blizzard-owned map pins unless the implementation is proven safe.

The addon’s own frames must also avoid protected propagation changes during restricted execution.

### Team-Pin Stacking

Team-pin stacking remains imperfect.

Known behaviour:

* The overlap slider previously showed little or no visible effect between approximately `0%` and `70%`.
* More noticeable changes occurred only near the upper end of the range.
* Native unit-position scanning is not consistently accurate enough to support ideal stacking behaviour.
* Any changes must prioritize correct unit positions over aggressive visual stacking.

### Team-Pin Tooltips

Team-pin tooltips have previously worked in Test Mode but not consistently in live battlegrounds.

The full-size map may still show Blizzard’s default tooltip behaviour instead of the intended BattleMaps tooltip.

### Test Mode

Known or previously observed Test Mode issues include:

* periodic white flashes on captured Arathi Basin bases
* visual behaviour that does not always match live battleground behaviour
* black squares when specialization-icon experiments were active
* stacking previews that did not accurately represent the slider range

### Specialization Icons

The earlier option to show specialization icons beside team pins should remain removed.

The desired design is:

* specialization information appears only in the team-pin mouseover tooltip
* the specialization icon appears beside the player name in that tooltip
* no persistent specialization icon appears beside the map pin

### Objective Edge Cases

Continue checking for:

* stationary objectives remaining visible after pickup
* carried and stationary versions appearing simultaneously
* rapid successive pickups causing one carrier to disappear
* incorrect orb colour or faction identity
* dropped flags retaining the wrong faction colour
* missing carried objectives after state transitions
* objectives working in Test Mode but not live

## Architectural Constraints

* World of Warcraft combat lockdown and taint rules take priority over visual convenience.
* Do not invent Blizzard APIs or assume undocumented behaviour.
* Secret or restricted values must not be compared, transformed, or passed into unsafe code paths.
* Blizzard map pins should be observed rather than modified wherever possible.
* Avoid creating duplicate objective-tracking systems when an established BattleMaps implementation already exists.
* New settings must be implemented consistently across:

  * defaults
  * saved profiles
  * migration logic
  * options controls
  * reset behaviour
  * Test Mode
  * import and export where applicable
* Preserve existing battleground-specific behaviour unless the requested change explicitly replaces it.

## Versioning

Increment the addon version for every distinct build using `MAJOR.MINOR.PATCH`.

* Increment `MAJOR` for major overhauls, architectural rewrites, or breaking changes.
* Increment `MINOR` for substantial new features or significant expansions.
* Increment `PATCH` for bug fixes, small improvements, and maintenance changes.
* Never reuse a previously issued version number.
* Descriptive development suffixes may be appended when useful.
* Keep the TOC version, internal version constants, release filename, login message, and package metadata consistent.

## Testing Priorities

Every meaningful change should be checked for:

1. clean login with no Lua errors
2. `/reload` behaviour
3. options persistence
4. reset-to-default behaviour
5. Test Mode behaviour
6. live battleground behaviour
7. combat-lockdown safety
8. taint or `ADDON_ACTION_BLOCKED` errors
9. interaction with the native Blizzard Battlefield Map
10. interaction with the full-size World Map
11. ElvUI compatibility where relevant
12. regressions on unrelated battlegrounds

Objective-related changes should be tested through complete state transitions:

* initial spawn
* pickup
* carrier movement
* rapid successive pickups
* drop
* return
* capture
* despawn
* respawn
* carrier death
* match reset

## Release Status

The current repository should initially be treated as a working development baseline rather than an immediately publishable release.

Before the next release:

* verify the current version
* complete the player-pin and vision-cone implementation
* test layering with team pins and objectives
* inspect for debugging output
* review all uncommitted changes
* run the privacy audit
* build from a clean staging directory
* inspect the extracted final ZIP
* produce a non-technical changelog

## Privacy Requirements

* Use only the public author name `Bonetti`.
* Do not include the developer’s legal name, personal email, Windows username, account name, machine name, home-directory path, or precise location.
* Do not commit private identity-search terms into this repository.
* Do not package SavedVariables, logs, screenshots, development notes, Git history, IDE files, temporary files, or backups.
* Treat diagnostic SavedVariables as read-only evidence.
* Search the extracted final release archive for personal information before publication.

## Source of Truth

Priority order when information conflicts:

1. current in-game test results
2. current source code and TOC load order
3. current Git diff and repository history
4. this status document
5. older notes, conversations, or release descriptions

This document is a working snapshot. Update it after meaningful changes, resolved issues, newly discovered regressions, or release milestones. Do not use it as a complete changelog.

Keep PROJECT_STATUS.md focused on the current state. Move resolved historical details into CHANGELOG.md rather than allowing this file to grow indefinitely.