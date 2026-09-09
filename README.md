# BattleMaps

BattleMaps is a World of Warcraft Retail PvP addon that provides a configurable battlefield map with clearer team pins, objective information, timers, and notifications.

## Key features

- Improved battleground zone map
- Improved map and objective textures
- Improved battleground raid warnings
- One-click objective callouts to instance chat
- Healer icons
- Animated capture timers
- ElvUI integration

## Supported battlegrounds

*Epic Battlegrounds are intentionally not included yet.*

1. Warsong Gulch
2. Twin Peaks
3. Eye of the Storm
4. Temple of Kotmogu
5. Silvershard Mines
6. Deephaul Ravine
7. Seething Shore

## Installation

Install BattleMaps with the CurseForge app, or download the release ZIP and extract the `BattleMaps` folder so this file is in the expected location:

   ```text
   World of Warcraft\_retail_\Interface\AddOns\BattleMaps\BattleMaps.toc
   ```

Then start or restart World of Warcraft and enable **BattleMaps** in the character-selection AddOns list.

## Getting started

- Click the minimap icon or type `/bmap` to open BattleMaps settings.
- Use **Test Mode** to preview supported battleground layouts and visual settings while outside a battleground.
- Click the lock icon on the BattleMaps frame to unlock it, then position and resize it as needed.

## Current status

BattleMaps is under active development. The current source version is **3.0.8** and targets World of Warcraft Retail interface **120100**. More features are planned, and user feedback is appreciated.

## Reporting an issue

Please include:

- BattleMaps version
- Clear steps to reproduce the issue
- Any Lua error message

Including the World of Warcraft client version, battleground, game mode, and objective state can also help diagnose battleground-specific problems.

Avoid sharing SavedVariables or personal information publicly. SavedVariables are useful diagnostic evidence, but they may contain account-specific data and should not be uploaded unless requested through a private channel.

## Development notes

BattleMaps is designed around World of Warcraft's combat-lockdown and taint restrictions. In particular, it avoids modifying Blizzard-owned map pins. Test changes on `/reload`, in Test Mode, and in live battleground scenarios before treating them as stable.

For custom objective textures, see [Media/Objectives/README.txt](Media/Objectives/README.txt).

## Rights and permissions

Copyright © 2026 B0netti. All rights reserved.

No license is granted for this repository. You may view the source on GitHub, but you may not use, copy, modify, distribute, or create derivative works from it without prior written permission from the copyright holder.
