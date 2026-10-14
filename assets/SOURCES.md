# Asset sources — the rule

Everything under `assets/` ships in the binary, so everything under
`assets/` needs a **redistribution-in-a-binary right** on record before it
lands. Concretely:

1. **Nothing ships without a redistribution right.** A file whose license
   we cannot produce is an OPEN ITEM in its class's `SOURCES.md` and must
   be replaced or cleared before any public build.
2. **Every purchased / third-party file has a `SOURCES.md` line** in its
   class folder (`assets/<class>/SOURCES.md`): file(s), pack / author,
   license, where the license file is, notes. The license text itself is
   copied into `assets/licenses/` (one file per pack, plus the pack's
   `info.txt` where there was one) so the repo carries the terms, not a
   link that can rot.
3. **Every AI-generated file lives under `assets/ai_placeholder/<class>/`**
   and nowhere else, with an entry in that folder's `ai_provenance.json`
   (tool, method, prompt, ids, date). See `assets/ai_placeholder/README.md`.
4. `tests/test_assets.tscn` enforces 2 and 3 for every path the manifests
   under `data/` reference, and 3 for every file under `ai_placeholder/`.
   `tests/test_skins.tscn` checks every skin's art actually dresses a room.

`raw_assets/` (gitignored) holds the untouched purchased packs; nothing the
game loads lives there.

## Classes

| Folder | SOURCES | What |
|---|---|---|
| `assets/tilesets/` | [tilesets/SOURCES.md](tilesets/SOURCES.md) | Szadi art level-build sheets + the terrain TileSets (`SSW.tres`, `SSW2_SET2.tres`) |
| `assets/backdrops/` | [backdrops/SOURCES.md](backdrops/SOURCES.md) | Szadi art parallax backgrounds (`data/backgrounds.json`) |
| `assets/props/` | [props/SOURCES.md](props/SOURCES.md) | Szadi art decoratives sheets + the hand-paint `decor_*.tres` TileSets |
| `assets/character/` | [character/SOURCES.md](character/SOURCES.md) | Knight player sheets by @Jump_Button — **credit required** for commercial use |
| `assets/enemies/` | [enemies/SOURCES.md](enemies/SOURCES.md) | Forest Monsters pack — **license file missing, OPEN ITEM** |
| `assets/music/` | [music/SOURCES.md](music/SOURCES.md) | Abstraction / Tallbeard Studios Sketchbook loops, CC0 |
| `assets/sfx/` | [sfx/SOURCES.md](sfx/SOURCES.md) | "400 Sounds Pack" — **license file missing, OPEN ITEM** |
| `assets/ai_placeholder/` | [ai_placeholder/README.md](ai_placeholder/README.md) | PixelLab-generated placeholders, provenance per folder |
| `assets/licenses/` | — | License texts and pack `info.txt` copies referenced above |

## Open items (as of 2026-10-13)

- **Forest Monsters pack** (`assets/enemies/forest_monsters/`): no license
  file was found in the previous project either. Retrieve author / terms /
  purchase receipt and drop the text at `assets/licenses/Forest_Monsters_license.txt`
  before any public build.
- **400 Sounds Pack** (`assets/sfx/*.wav`, all 50): the pack ships no
  license file. Same action: author / terms / receipt → `assets/licenses/400_Sounds_Pack_license.txt`.
- **Store URLs / purchase dates** for the Szadi packs and the Knight are
  still unrecorded (carried over from dungeon-platformer's open list).
- **Credit screen**: the Knight (@Jump_Button) requires credit for
  commercial use; Abstraction asks (not requires) for credit as
  "Abstraction" with a link. Both go on the credits screen before release.
