# Enemy sources & licenses

Rule (see `assets/SOURCES.md`): one line per file before it lands. Nothing
ships without a redistribution-in-a-binary right.

## Forest Monsters pack (`assets/enemies/forest_monsters/`) — OPEN ITEM

All 40 sheets in `forest_monsters/` are the **"with VFX"** variants of a
purchased pack that dungeon-platformer stored as
`assets/enemies/Forest_Monsters_PREMIUM/<Monster>/<Monster> with VFX/`
(the "without VFX" variants were not copied). Single-row sheets, 64 px
tall: slimes 64 px frames, mushroom 80 px, bush monster 90 px. Wired as
`enemies.green_slime / blue_slime / orange_slime / mushroom / bush_lasher`
in `data/sprites.json`.

**OPEN ITEM — no license on record.** The previous project had no license
file for this pack either (the folder name "PREMIUM" is all we know), and
none was found in `raw_assets/` or anywhere else on disk. Before any
public build: retrieve the author / store page / terms and the purchase
receipt, drop the license text at
`assets/licenses/Forest_Monsters_license.txt`, and fill the columns
below. Until then these sheets are **not cleared to ship**; if the terms
cannot be produced, replace the five enemies with art that has them.

| file(s) | pack / author | license | license file | notes |
|---|---|---|---|---|
| `Green_Slime-Idle.png` (7 f), `Green_Slime-Run.png` (6), `Green_Slime-Run_Jump.png` (11), `Green_Slime-Idle_Jump.png` (11), `Green_Slime-Attack_Ground.png` (12), `Green_Slime-Hit_Ground.png` (4), `Green_Slime-Hit_Air.png` (4), `Green_Slime-Die_Ground.png` (11), `Green_Slime-Die_Air.png` (11) | Forest Monsters (PREMIUM, "with VFX") — author UNKNOWN | **UNKNOWN — OPEN ITEM** | (missing) | `green_slime`, 64 px frames |
| `Blue_Slime-Idle.png` (7), `Blue_Slime-Run.png` (6), `Blue_Slime-Run_Jump.png` (11), `Blue_Slime-Idle_Jump.png` (11), `Blue_Slime-Attack_Ground.png` (12), `Blue_Slime-Hit_Ground.png` (4), `Blue_Slime-Hit_Air.png` (4), `Blue_Slime-Die_Ground.png` (11), `Blue_Slime-Die_Air.png` (11) | same | **UNKNOWN — OPEN ITEM** | (missing) | `blue_slime` |
| `Orange_Slime-Idle.png` (7), `Orange_Slime-Run.png` (6), `Orange_Slime-Run_Jump.png` (11), `Orange_Slime-Idle_Jump.png` (11), `Orange_Slime-Attack_Ground.png` (12), `Orange_Slime-Hit_Ground.png` (4), `Orange_Slime-Hit_Air.png` (4), `Orange_Slime-Die_Ground.png` (11), `Orange_Slime-Die_Air.png` (11) | same | **UNKNOWN — OPEN ITEM** | (missing) | `orange_slime` |
| `Mushroom-Idle.png` (7), `Mushroom-Run.png` (8), `Mushroom-Attack.png` (10), `Mushroom-AttackWithStun.png` (24), `Mushroom-Stun.png` (18), `Mushroom-Hit.png` (5), `Mushroom-Die.png` (15) | same | **UNKNOWN — OPEN ITEM** | (missing) | `mushroom`, 80 px frames |
| `Bush_Monster-Idle.png` (8), `Bush_Monster-Run.png` (7), `Bush_Monster-AttackTimeFrame.png` (1), `Bush_Monster-Attack.png` (18), `Bush_Monster-Hit.png` (4), `Bush_Monster-Die.png` (14) | same | **UNKNOWN — OPEN ITEM** | (missing) | `bush_lasher`, 90 px frames |

The two AI-generated enemies (`stone_guardian`, `riftmaw`) are not here:
they live in `assets/ai_placeholder/enemies/` with their provenance.
