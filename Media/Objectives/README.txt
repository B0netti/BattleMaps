BattleMaps custom objective textures
====================================

ROOT
----
Interface\AddOns\BattleMaps\Media\Objectives\

FOLDER STRUCTURE
----------------
Objectives\
  <liveMapID>\
    stationary\
    carried\
    vehicle\

BattleMaps now uses one canonical filename for each objective/state. It does
not search alternate long names, generic state fallbacks, or the common folder.
If the exact canonical file is missing, Blizzard's original texture is used.

Use the live UI map ID printed by:
  /bmap texturekeys

Known examples:
  1366  Arathi Basin
  210   Eye of the Storm
  206   Warsong Gulch
  118   Wintergrasp
  1576  Deepwind Gorge

ARATHI BASIN KEYS
-----------------
  BS  Blacksmith
  LM  Lumber Mill
  GM  Gold Mine
  ST  Stables
  FM  Farm

EYE OF THE STORM KEYS
---------------------
  MT   Mage Tower
  DR   Draenei Ruins
  FRR  Fel Reaver Ruins
  BET  Blood Elf Tower
  NF   Netherstorm Flag

CANONICAL STATE SUFFIXES
------------------------
  _N    neutral / unclaimed
  _A    controlled by Alliance
  _H    controlled by Horde
  _A_C  currently being assaulted/captured by Alliance
  _H_C  currently being assaulted/captured by Horde

There is no generic _C file. If BattleMaps cannot identify the attacking
faction, it deliberately uses Blizzard's original texture.

ARATHI BASIN EXAMPLES
---------------------
Interface\AddOns\BattleMaps\Media\Objectives\1366\stationary\BS_N.tga
Interface\AddOns\BattleMaps\Media\Objectives\1366\stationary\BS_A.tga
Interface\AddOns\BattleMaps\Media\Objectives\1366\stationary\BS_H.tga
Interface\AddOns\BattleMaps\Media\Objectives\1366\stationary\BS_A_C.tga
Interface\AddOns\BattleMaps\Media\Objectives\1366\stationary\BS_H_C.tga

The same suffixes apply to LM, GM, ST, and FM.

IMPORTANT MIGRATION NOTE
------------------------
The following old alternatives are no longer loaded:
  lumber_mill.tga
  lumber_mill_alliance.tga
  LM.tga
  LM_C.tga
  default.tga
  common\... fallbacks

Rename each file to its single exact state name. For example:
  lumber_mill_alliance.tga  -> LM_A.tga
  lumber_mill_horde.tga     -> LM_H.tga
  contested by Alliance     -> LM_A_C.tga
  contested by Horde        -> LM_H_C.tga

CARRIED OBJECTIVES AND VEHICLES
-------------------------------
When Blizzard exposes a supported faction/state, the same suffix system is used.
There is no inactive state. When no supported state exists, the canonical key
alone is used, for example:
  <mapID>\carried\flag.tga
  <mapID>\vehicle\mine_cart.tga

Run /bmap texturekeys or /bmap texturedebug to see the canonical key and state
BattleMaps detected for a live objective.

FILE PROPERTIES
---------------
Recommended:
  - TGA
  - 32-bit RGBA with transparency
  - Uncompressed / RLE disabled
  - Power-of-two dimensions
  - 64x64 or 128x128 source canvas
  - Keep the intended objective anchor visually centred

Changing the source image dimensions does not change its on-map size. BattleMaps
sets display size in Lua and applies the objective-size slider.

IMPORTANT
---------
Fully exit and restart WoW after adding or renaming texture files. /reload is
not sufficient for a file that did not exist when the client started.
