# Tileset sources & licenses

Rule (see `assets/SOURCES.md`): every third-party sheet gets a line here —
file, pack / author, license, where the license file is — **before** its
`.tres` lands. Nothing ships without a redistribution-in-a-binary right.

All level-build sheets in this folder are by **Szadi art** ("Seasonal
Sprite Worlds" / SSW packs), 32 px native tiles, sold under the same
"License for Everyone" text (commercial use and selling works made with
the assets OK; editing allowed; no use in a logo/trademark; no resale of
the asset itself; credit appreciated, not required). The full text per
pack is in `assets/licenses/<pack>_license.txt`; the pack's `info.txt`
(animated-object block sizes) is copied next to it as
`assets/licenses/<pack>_info.txt`. The untouched packs are in
`raw_assets/tilesets/<pack>_v1.0/` (gitignored). Store URLs / purchase
dates are still unrecorded — see the open items in `assets/SOURCES.md`.

## Sheets

| file(s) | pack / author | license | license file | notes |
|---|---|---|---|---|
| `SSW_SET3_MainLevBuild.png` | Seasonal Sprite Worlds SET3 — Szadi art | License for Everyone | `assets/licenses/SSW_SET3_license.txt`, `SSW_SET3_info.txt` | terrain set 3 in `SSW.tres` (skin `cave_dark`) |
| `SSW_SET4_MainLevBuild.png` | Seasonal Sprite Worlds SET4 — Szadi art | License for Everyone | `assets/licenses/SSW_SET4_license.txt`, `SSW_SET4_info.txt` | terrain set 4 in `SSW.tres` (skin `mine`) |
| `SSW_SET5_MainLevBuild.png` | Seasonal Sprite Worlds SET5 — Szadi art | License for Everyone | `assets/licenses/SSW_SET5_license.txt`, `SSW_SET5_info.txt` | terrain sets 5 and 6 in `SSW.tres` (skins `stone_dark`, `stone_pale`) |
| `SSW_SET7_MainLevBuild.png` | Seasonal Sprite Worlds SET7 — Szadi art | License for Everyone | `assets/licenses/SSW_SET7_license.txt`, `SSW_SET7_info.txt` | terrain set 8 in `SSW.tres` (skin `cave_roots`) |
| `SSW_CastlePack_MainLevBuild.png` | Seasonal Sprite Worlds Castle Pack — Szadi art | License for Everyone | `assets/licenses/SSW_CastlePack_license.txt`, `SSW_CastlePack_info.txt` | copied, **not yet autotiled** (no terrain set, no skin) |
| `SSWorlds_SET2_MainLevBuild.png` | Seasonal Sprite Worlds SET2 — Szadi art | License for Everyone | `assets/licenses/SSWorlds_SET2_license.txt`, `SSWorlds_SET2_info.txt` | terrain set 2 in `SSW.tres` (skin `cave_brown`) |
| `SSW2_SET2_mainlev_build1.png` | Seasonal Sprite Worlds 2 SET2 — Szadi art | License for Everyone | `assets/licenses/SSW2_SET2_license.txt`, `SSW2_SET2_info.txt` | mossy brick blob + flat teal water square; source 0 of `SSW2_SET2.tres`, source 9 (water only) of `SSW.tres` |
| `SSW2_SET2_mainlev_build2.png` | Seasonal Sprite Worlds 2 SET2 — Szadi art | License for Everyone | `assets/licenses/SSW2_SET2_license.txt` | floating rough-rock ledges and rock ramps (brown / grey-blue variants); copied, not yet in a `.tres` |
| `SSW2_SET2_mainlev_build3.png` | Seasonal Sprite Worlds 2 SET2 — Szadi art | License for Everyone | `assets/licenses/SSW2_SET2_license.txt` | wooden plank walkways, scaffolding, ladders; source 1 of `SSW2_SET2.tres` (the one-way "platform" strip, row 1) |
| `SSW2_SET2_mainlev_build4.png` | Seasonal Sprite Worlds 2 SET2 — Szadi art | License for Everyone | `assets/licenses/SSW2_SET2_license.txt` | rough cave-rock blob in six colour variants (10x10 cells each); copied, not yet autotiled |

## TileSets (.tres)

| file | textures | what |
|---|---|---|
| `SSW.tres` | SET3, SET4, SET5, SET7, SSWorlds_SET2 sheets above + `SSW2_SET2_mainlev_build1.png` | Nine terrain-set slots (0–8; 0, 1 and 7 are empty — SSWorlds_SET1 / SSW_SET6 were dropped with their missing licenses). Each set: terrain 0 `ground` (blob), terrain 1 `platform` (thin one-way strip). Atlas source 9 holds exactly one tile, the flat teal water square at build1 (10,25), so every SSW skin can map `water` to `{"atlas": [9, 10, 25]}`. |
| `SSW2_SET2.tres` | `SSW2_SET2_mainlev_build1.png` (source 0), `SSW2_SET2_mainlev_build3.png` (source 1) | Terrain set 0, CORNERS_AND_SIDES: `ground` = the mossy brick blob (5x5 block, 1-wide pillar, 1-high strips, lone tiles, three flowered/grassed/rubble top-edge rows, three step clusters with the two downward inner corners); `platform` = the wooden plank walkway (build3 row 1). Water is the plain tile (0, 10, 25). Authored headlessly from a one-off script (not in the repo); every non-empty cell of both sheets is a tile so DecorBack/DecorFront can hand-pick any piece. |

Terrain coverage of `SSW2_SET2.tres` `ground`: 18 of the 47
corners-and-sides configurations have an exact tile (fill, 4 edges, 4
outer corners, inner corners missing top-left / top-right, pillar top /
middle / bottom, strip left / middle / right, lone). The pack has no
upward inner corners (missing bottom-left / bottom-right), no T-junctions
and no diagonal-only joins; Godot's terrain solver substitutes the closest
tile and `SkinLayer` patches anything left empty with the fill tile, so
thin geometry autotiles but with the nearest edge art. The pack has no
spike art — `hazard` stays unmapped (greybox draws it). The pack's
decorated edges overhang their cell by 4–8 px; on a 32 px grid that
overhang is clipped (same as every SSW set).

## Authoring convention (per set, from dungeon-platformer)

1. Import the PNG with filter off (nearest); atlas tile size = the pack's
   native 32 px (`SkinLayer` scales by `Room.TILE / tile_size`, so 1:1 here).
2. One terrain set (corners and sides), one terrain per visual material;
   paint the peering bits. Lone one-off tiles (water, hazard) are mapped
   as `{"atlas": [source, x, y]}` in `data/skins.json`.
3. No physics layers, no navigation, no custom data — these TileSets are
   paint. The kind palette `game/rooms/tileset_kind.tres` owns collision.
4. Wire it in `data/skins.json`; `tests/test_skins.tscn` checks coverage.
