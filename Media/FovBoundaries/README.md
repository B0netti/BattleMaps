# FoV map masks

Each mask must match its battleground's rendered map-art canvas exactly and
must be exported as a 32-bit TGA with an 8-bit alpha channel.

## Files

- Editable master: `<descriptive_map_name>.pdn` (for example, `arathi_basin.pdn`)
- Cone boundary: `fov_boundary_<map_key>.tga`
- Beam/core detail: `fov_detail_<map_key>.tga`
- Accent terrain detail: `fov_accent_<map_key>.tga`

`<map_key>` is lowercase with underscores; for example, `arathi`.

The alpha channel controls visibility: white/opaque reveals the associated FoV
pass; black/transparent removes it; grey creates a soft edge. RGB can stay
white for both mask types.

## Pass convention

- `boundary` masks the `under` (cone) pass to the playable area.
- `beam` masks the `beam` (core) pass with the detail texture.
- `accent` masks the subtle broken-ray pass with terrain detail.
- A future pass opts in explicitly with `maskKind` in
  `Pins/UnitPins.lua`; an absent `maskKind` leaves that pass unmasked.

Register each exported texture under both the BattleMaps configuration ID and
its current Blizzard UI-map alias in `PLAYER_FOV_MAP_MASKS` in
`Pins/UnitPins.lua`.

## In-game controls

- `/bmap fovmask all on|off`
- `/bmap fovmask boundary on|off`
- `/bmap fovmask beam on|off`
- `/bmap fovmask accent on|off`

Omit `on|off` to toggle that target. `/bmap boundary` remains the separate blue
alignment-preview overlay.
