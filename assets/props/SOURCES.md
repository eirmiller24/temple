# Props / decoratives sources & licenses

Rule (see `assets/SOURCES.md`): one line per file before it lands. Every
sheet here comes from the same **Szadi art** "Seasonal Sprite Worlds" packs
as the level-build sheets in `assets/tilesets/` (same purchase, same
"License for Everyone": commercial use OK, editing OK, no logo/trademark
use, no resale, credit appreciated). License texts:
`assets/licenses/<pack>_license.txt`; pack `info.txt` copies next to them.

| file(s) | pack / author | license | license file | notes |
|---|---|---|---|---|
| `SSW_SET3_Decoratives.png` | SSW SET3 — Szadi art | License for Everyone | `assets/licenses/SSW_SET3_license.txt` | 608x896, 32 px grid → `decor_SSW_SET3.tres` |
| `SSW_SET4_Decoratives.png` | SSW SET4 — Szadi art | License for Everyone | `assets/licenses/SSW_SET4_license.txt` | 512x480 → `decor_SSW_SET4.tres` |
| `SSW_SET5_Decoratives.png` | SSW SET5 — Szadi art | License for Everyone | `assets/licenses/SSW_SET5_license.txt` | 1024x288 → `decor_SSW_SET5.tres` |
| `SSW_SET7_Decoratives.png` | SSW SET7 — Szadi art | License for Everyone | `assets/licenses/SSW_SET7_license.txt` | 736x992 → `decor_SSW_SET7.tres` |
| `SSW_CastlePack_Decoratives.png` | SSW Castle Pack — Szadi art | License for Everyone | `assets/licenses/SSW_CastlePack_license.txt` | 256x480 → `decor_SSW_CastlePack.tres` |
| `SSWorlds_SET2_Decoratives.png` | SSW SET2 — Szadi art | License for Everyone | `assets/licenses/SSWorlds_SET2_license.txt` | 896x640 → `decor_SSWorlds_SET2.tres` |
| `SSW2_SET2_dec_props.png` | SSW2 SET2 — Szadi art | License for Everyone | `assets/licenses/SSW2_SET2_license.txt` | 736x928 nets, crates, barrels, banners, poles → `decor_SSW2_SET2.tres` source 0 |
| `SSW2_SET2_lanterns.png` | SSW2 SET2 — Szadi art | License for Everyone | `assets/licenses/SSW2_SET2_license.txt` | 256x512 → `decor_SSW2_SET2.tres` source 1 |
| `SSW2_SET2_handrail.png` | SSW2 SET2 — Szadi art | License for Everyone | `assets/licenses/SSW2_SET2_license.txt` | 448x608 → `decor_SSW2_SET2.tres` source 2 |
| `SSW2_SET2_rocks_col1.png` | SSW2 SET2 — Szadi art | License for Everyone | `assets/licenses/SSW2_SET2_license.txt` | 896x384 rock clusters, colour 1 → `decor_SSW2_SET2.tres` source 3 |
| `SSW2_SET2_rocks_col2.png` | SSW2 SET2 — Szadi art | License for Everyone | `assets/licenses/SSW2_SET2_license.txt` | 896x384 rock clusters, colour 2 → `decor_SSW2_SET2.tres` source 4 |

## Decor TileSets (`decor_*.tres`)

`decor_SSW_SET3.tres`, `decor_SSW_SET4.tres`, `decor_SSW_SET5.tres`,
`decor_SSW_SET7.tres`, `decor_SSW_CastlePack.tres`,
`decor_SSWorlds_SET2.tres`, `decor_SSW2_SET2.tres` — one plain 32 px atlas
TileSet per decoratives sheet (the SSW2_SET2 one carries its five sheets as
sources 0–4). No terrains, no physics, no custom data: a tile per
non-empty 32x32 cell, picked by hand. Generated headlessly by a one-off
script (not in the repo); regenerate the same way if a sheet changes.

**How rooms use them.** `addons/room_tools/room_template.tscn` gives every
new room `DecorBack` (z -2) and `DecorFront` (z 2) TileMapLayers whose
`tile_set` is `res://assets/tilesets/SSW.tres` — a placeholder so the
layers exist. The author swaps in the decor `.tres` that matches the room's
skin per room (select the layer, change Tile Set in the inspector), then
paints props cell by cell (multi-cell props are several adjacent tiles).
Mixing packs in one room is fine: use DecorBack for one `.tres` and
DecorFront for another, or add a third TileMapLayer. These layers are
paint only — nothing outside `Collision` collides.
