# Backdrop sources & licenses

Rule (see `assets/SOURCES.md`): one line per file before it lands.
Everything here is **Szadi art**, "Seasonal Sprite Worlds" packs, under the
same "License for Everyone" (commercial use OK, editing OK, no
logo/trademark use, no resale of the asset, credit appreciated). License
texts: `assets/licenses/<pack>_license.txt`. Wired by `data/backgrounds.json`
(far → near parallax layers over a fill colour, drawn by `Backdrop`).

Measured on 2026-10-13 (Pillow): "opaque from" is the first row where the
silhouette is ≥50 % opaque, used to place horizons; "tiles" says whether the
sheet repeats seamlessly along that axis.

| file(s) | pack / author | license | license file | notes |
|---|---|---|---|---|
| `SSW_SET3_Background1.png` | SSW SET3 — Szadi art | License for Everyone | `assets/licenses/SSW_SET3_license.txt` | 640x480 opaque flat cave rock, tiles x+y; unused |
| `SSW_SET3_Background2.png` | SSW SET3 — Szadi art | License for Everyone | `assets/licenses/SSW_SET3_license.txt` | 640x480 pale cutout rock lattice, tiles x+y; unused |
| `SSW_SET3_Background3.png` | SSW SET3 — Szadi art | License for Everyone | `assets/licenses/SSW_SET3_license.txt` | 640x480 opaque dark cave rock, tiles x+y — `cave_depths` far |
| `SSW_SET3_Background4.png` | SSW SET3 — Szadi art | License for Everyone | `assets/licenses/SSW_SET3_license.txt` | 640x480 cutout rock lattice with vines, tiles x+y — `cave_depths` near |
| `SSW_SET4_MainBackTile.png` | SSW SET4 — Szadi art | License for Everyone | `assets/licenses/SSW_SET4_license.txt` | 1024x832 **32 px back-wall tile sheet** (bricks, pipes, columns) — hand-paint it in DecorBack; it is not a repeating background (it was wrongly used as one before 2026-10-13) |
| `SSW_SET4_background1.png` | SSW SET4 — Szadi art | License for Everyone | `assets/licenses/SSW_SET4_license.txt` | 640x384 opaque crystal cave wall, tiles x+y — `mine` far |
| `SSW_SET4_background2.png` | SSW SET4 — Szadi art | License for Everyone | `assets/licenses/SSW_SET4_license.txt` | 640x384 cutout rock columns with scaffolds, tiles x+y — `mine` mid |
| `SSW_SET4_background3.png` | SSW SET4 — Szadi art | License for Everyone | `assets/licenses/SSW_SET4_license.txt` | 640x384 cutout floating rock ledges, tiles x+y — `mine` near |
| `SSW_SET5_Background1.png` | SSW SET5 — Szadi art | License for Everyone | `assets/licenses/SSW_SET5_license.txt` | 640x640 opaque pale sky: clouds to row ~170, flat haze below — `cave_pale` far |
| `SSW_SET5_Background2.png` | SSW SET5 — Szadi art | License for Everyone | `assets/licenses/SSW_SET5_license.txt` | 640x640 cutout snowy mountains, opaque from row 173 — `stone_hall` far |
| `SSW_SET5_Background3.png` | SSW SET5 — Szadi art | License for Everyone | `assets/licenses/SSW_SET5_license.txt` | 640x640 cutout pine treeline, opaque from row 328 — `cave_pale` mid |
| `SSW_SET5_Background4.png` | SSW SET5 — Szadi art | License for Everyone | `assets/licenses/SSW_SET5_license.txt` | 640x640 cutout nearer trees, opaque from row 355 — `cave_pale` near |
| `SSW_SET5_Background5.png` | SSW SET5 — Szadi art | License for Everyone | `assets/licenses/SSW_SET5_license.txt` | 640x640 cutout foreground rocks, opaque from row 449 — `stone_hall` near |
| `SSW_SET7_Background1.png` | SSW SET7 — Szadi art | License for Everyone | `assets/licenses/SSW_SET7_license.txt` | 1024x640 opaque flat forest haze (tiles x+y); unused |
| `SSW_SET7_Background2.png` | SSW SET7 — Szadi art | License for Everyone | `assets/licenses/SSW_SET7_license.txt` | 1024x640 cutout far trunks; unused |
| `SSW_SET7_Background3.png` | SSW SET7 — Szadi art | License for Everyone | `assets/licenses/SSW_SET7_license.txt` | 1024x640 opaque mid trunks with light rays; unused |
| `SSW_SET7_Background4.png` | SSW SET7 — Szadi art | License for Everyone | `assets/licenses/SSW_SET7_license.txt` | 1024x640 cutout nearer trunks; unused |
| `SSW_SET7_Background5.png` | SSW SET7 — Szadi art | License for Everyone | `assets/licenses/SSW_SET7_license.txt` | 1024x640 cutout dark forest (canopy opaque across the top, sky gaps between trunks, floor at the bottom) — `roots` far; does not tile vertically |
| `SSW_SET7_Background6.png` | SSW SET7 — Szadi art | License for Everyone | `assets/licenses/SSW_SET7_license.txt` | 1024x640 cutout autumn bushes, opaque from row 552 — `roots` near |
| `SSW_CastlePack_Background1.png` | SSW Castle Pack — Szadi art | License for Everyone | `assets/licenses/SSW_CastlePack_license.txt` | 640x480 opaque blue day sky; unused |
| `SSW_CastlePack_Background2.png` | SSW Castle Pack — Szadi art | License for Everyone | `assets/licenses/SSW_CastlePack_license.txt` | 640x480 cutout distant blue ridge, opaque from row 124; unused |
| `SSW_CastlePack_Background3.png` | SSW Castle Pack — Szadi art | License for Everyone | `assets/licenses/SSW_CastlePack_license.txt` | 640x480 cutout snowy peaks over flat grey haze, opaque from row 202 — `castle` far |
| `SSW_CastlePack_Background4.png` | SSW Castle Pack — Szadi art | License for Everyone | `assets/licenses/SSW_CastlePack_license.txt` | 640x480 cutout grey hills, opaque from row 225 — `castle` mid |
| `SSW_CastlePack_Background5.png` | SSW Castle Pack — Szadi art | License for Everyone | `assets/licenses/SSW_CastlePack_license.txt` | 640x480 cutout green cliffs, opaque from row 331 — `castle` near |
| `SSWorlds_SET2_Background_day1.png` | SSW SET2 — Szadi art | License for Everyone | `assets/licenses/SSWorlds_SET2_license.txt` | 640x480 opaque sunset sky; unused |
| `SSWorlds_SET2_Background_day2.png` | SSW SET2 — Szadi art | License for Everyone | `assets/licenses/SSWorlds_SET2_license.txt` | 640x480 cutout brown ridge, opaque from row 142; unused |
| `SSWorlds_SET2_Background_day3.png` | SSW SET2 — Szadi art | License for Everyone | `assets/licenses/SSWorlds_SET2_license.txt` | 640x480 cutout hills, opaque from row 279; unused |
| `SSWorlds_SET2_Background_day4.png` | SSW SET2 — Szadi art | License for Everyone | `assets/licenses/SSWorlds_SET2_license.txt` | 640x480 cutout foreground brush, opaque from row 422; unused |
| `SSWorlds_SET2_Background_night1.png` | SSW SET2 — Szadi art | License for Everyone | `assets/licenses/SSWorlds_SET2_license.txt` | 640x480 opaque night sky, tiles x+y — `cave_brown` far |
| `SSWorlds_SET2_Background_night2.png` | SSW SET2 — Szadi art | License for Everyone | `assets/licenses/SSWorlds_SET2_license.txt` | 640x480 cutout night ridge, opaque from row 142 — `cave_brown` mid |
| `SSWorlds_SET2_Background_night3.png` | SSW SET2 — Szadi art | License for Everyone | `assets/licenses/SSWorlds_SET2_license.txt` | 640x480 cutout night hills, opaque from row 279 — `cave_brown` near |
| `SSWorlds_SET2_Background_night4.png` | SSW SET2 — Szadi art | License for Everyone | `assets/licenses/SSWorlds_SET2_license.txt` | 640x480 cutout night brush, opaque from row 422; unused |
| `SSW2_SET2_background_day1.png` | SSW2 SET2 — Szadi art | License for Everyone | `assets/licenses/SSW2_SET2_license.txt` | 640x640 opaque storm sky, beach (rows ~430–490) and sea — `jungle_ruins_day` far |
| `SSW2_SET2_background_day2.png` | SSW2 SET2 — Szadi art | License for Everyone | `assets/licenses/SSW2_SET2_license.txt` | 640x640 cloud band hanging from the TOP (opaque rows 0–275) — `jungle_ruins_day` |
| `SSW2_SET2_background_day3.png` | SSW2 SET2 — Szadi art | License for Everyone | `assets/licenses/SSW2_SET2_license.txt` | 640x640 cloud band from the top (rows 0–197) — `jungle_ruins_day` |
| `SSW2_SET2_background_day4.png` | SSW2 SET2 — Szadi art | License for Everyone | `assets/licenses/SSW2_SET2_license.txt` | 640x640 cloud band from the top (rows 0–120) — `jungle_ruins_day` near |
| `SSW2_SET2_background_night1.png` | SSW2 SET2 — Szadi art | License for Everyone | `assets/licenses/SSW2_SET2_license.txt` | 640x640 opaque night storm sky + sea — `jungle_ruins_night` far |
| `SSW2_SET2_background_night2.png` | SSW2 SET2 — Szadi art | License for Everyone | `assets/licenses/SSW2_SET2_license.txt` | 640x640 night cloud band from the top (rows 0–275) — `jungle_ruins_night` |
| `SSW2_SET2_background_night3.png` | SSW2 SET2 — Szadi art | License for Everyone | `assets/licenses/SSW2_SET2_license.txt` | 640x640 night cloud band (rows 0–197) — `jungle_ruins_night` |
| `SSW2_SET2_background_night4.png` | SSW2 SET2 — Szadi art | License for Everyone | `assets/licenses/SSW2_SET2_license.txt` | 640x640 night cloud band (rows 0–120) — `jungle_ruins_night` near |

Note: the SSW2_SET2 pack is a shoreline set (the pack's animated extras
are ships, cranes and water), so its "jungle ruins" backdrop is a stormy
sea horizon; the brick blob in `assets/tilesets/` is what reads as temple.
