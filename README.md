# BattleMaps

BattleMaps is a World of Warcraft Retail PvP addon that provides a configurable battlefield map with clearer team pins, objective information, timers, notifications, and carried-objective trails.

## Current status

BattleMaps is under active development. The current source version is **2.7.0** and targets World of Warcraft Retail interface **120100**.

## Highlights

- Independent, movable and scalable Battlefield Map frame
- Configurable player and team pins, including healer identification and pin layering
- Objective, vehicle, flag and capture-state presentation for supported battlegrounds
- Capture timers, faction-coloured notifications, pulse and flash effects
- Carried-objective breadcrumbs, glow wakes and spawn tethers on supported maps
- Test Mode for previewing map layouts and settings outside a live battleground
- Optional World Map presentation and ElvUI battleground-layout integration

Current objective support includes standard capture bases, Warsong Gulch and Twin Peaks flags, Eye of the Storm, Temple of Kotmogu orbs, Silvershard Mines carts, Deephaul Ravine crystals, and Seething Shore objectives. Client APIs and battleground states can change, so edge cases are still being tested and refined.

## Installation

This repository currently contains the addon source rather than a packaged release download.

1. Download the repository source from GitHub.
2. Extract it so this file is in the expected location:

   ```text
   World of Warcraft\_retail_\Interface\AddOns\BattleMaps\BattleMaps.toc
   ```

3. Start or restart World of Warcraft.
4. Enable **BattleMaps** in the character-selection AddOns list.

## Getting started

- Type `/bmap` to open BattleMaps settings.
- `/bg` is an alias for the same settings page.
- Use **Test Mode** in the options to preview supported battleground layouts and visual settings.
- Use `Shift-M` to open Blizzard's native battlefield map.

## Reporting an issue

Please include:

- BattleMaps version and World of Warcraft client version
- Battleground and game mode (including Battleground Blitz, where applicable)
- The objective state involved, such as spawn, pickup, drop, capture, return or respawn
- Clear steps to reproduce the issue
- Any Lua error or `ADDON_ACTION_BLOCKED` message

Avoid sharing SavedVariables or personal information publicly. SavedVariables are useful diagnostic evidence, but they may contain account-specific data and should not be uploaded unless requested through a private channel.

## Development notes

BattleMaps is designed around World of Warcraft's combat-lockdown and taint restrictions. In particular, it avoids modifying Blizzard-owned map pins. Test changes on `/reload`, in Test Mode, and in live battleground scenarios before treating them as stable.

For custom objective textures, see [Media/Objectives/README.txt](Media/Objectives/README.txt).

## Rights and permissions

Copyright © 2026 B0netti. All rights reserved.

No license is granted for this repository. You may view the source on GitHub, but you may not use, copy, modify, distribute, or create derivative works from it without prior written permission from the copyright holder.
