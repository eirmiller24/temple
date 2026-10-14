# AI placeholder art

How art is generated with PixelLab, recorded, wired into the sprite
manifest, and kept in quarantine. This is the one place the procedure is
written down: this project ships no agent definitions, so any future
session — human or AI — that generates a sheet follows this file
step by step.

The knowledge here was ported from the previous project
(dungeon-platformer, `docs/authoring/classes.md` §4 and `creatures.md`
§5, and its `creature-author`/`class-author` agents), where it was paid
for in regenerations. Where this project differs — 32 px tiles, a 48 px
player, a different manifest shape — the difference is called out.

---

## 1. The rule

**Everything AI-generated lives under `assets/ai_placeholder/<class>/`
and nowhere else, with a record in that folder's `ai_provenance.json`.**
It may ship. It must be obvious: the path says it is AI-made, the manifest
entry that uses it carries a `_source` note pointing at the record, and
the record says how to regenerate it. Replacing a piece with purchased or
commissioned art is a path edit in `data/sprites.json` plus deleting the
file; purging all of it is deleting the folder. Purchased art lives under
`assets/<class>/` with a line in that folder's `SOURCES.md` and its
license in `assets/licenses/`.

Why quarantine rather than a ban: placeholder art is what lets a room,
an enemy or an object be *playable* the day it is designed, and the
design iterates on play, not on art. Why quarantine rather than mixing:
the day the author replaces it, or a storefront asks what is AI-made,
the answer has to be one folder listing, not an archaeology project.

`tests/test_assets.tscn` (open item — not written yet) is the guard: it
fails on any texture path referenced by `data/sprites.json`,
`data/skins.json` or `data/backgrounds.json` that resolves to neither
`assets/ai_placeholder/` nor a path whose folder has a `SOURCES.md`, and
on any file under `ai_placeholder/` without a provenance record. The rule
for the licensed side — every purchased file has a `SOURCES.md` line and
its license text in `assets/licenses/` — is `assets/SOURCES.md`, which
also indexes the per-class files and the current licensing open items.

**Two things the rule implies that are easy to miss:**

- **Never use license-restricted art as a style reference.** PixelLab's
  object creator accepts a style image; the Knight sheets' license
  (`assets/character/Knight_player/Read_me.txt`) forbids any AI or ML use
  of the art, so they never go in. Abstraction's music says the same
  about itself. The Szadi tile packs don't forbid it, but a tileset is a
  poor style image anyway. When in doubt, no style image: PixelLab's
  default style is close enough to the shipped look if you ask for
  "slightly chibi, large head" (§6).
- **Inherited art is still AI art.** Everything under
  `assets/ai_placeholder/` today (`riftmaw`, `stone_guardian`, `box`,
  `boulder`, `button`, `chest`, `beacon`, the levers, `smash_burst`) was
  generated for the previous project in 2026-07 and copied over unchanged
  (two renamed: `stone_guardian.png` was `basalt_sentinel_ai.png`,
  `riftmaw.png` was `riftmaw_ai.png`). The folder's own
  `assets/ai_placeholder/README.md` states the policy in place and lists
  which manifest entry uses which file; the per-folder
  `ai_provenance.json` records, carrying the original object and
  animation ids from that repo's `assets/ai_placeholder/sprites/*/
  ai_provenance.json`, are being back-filled (open item in
  `docs/implementation_log.md`). A copied record carries an `origin` key
  (§3).

## 2. Where files land

```
assets/ai_placeholder/
  players/      the student and any other player-controlled body
  enemies/      species sheets (one PNG per species, rows = clips)
  objects/      push block, button, lever, gate, door, anchor…
  pickups/      items lying in rooms
  props/        decor one-offs for Props nodes
  effects/      hit bursts, dust, VFX not baked into a body sheet
  backdrops/    parallax layers, if ever AI-generated
  tilesets/     terrain art, if ever AI-generated
  ui/           icons, frames
```

One `ai_provenance.json` per class folder. The class is the asset's role
in the game, not the tool that made it; `stations/` exists today only
because the previous project had stations — its two sheets stand in for
the lever and the save shrine and belong under `objects/` once the
manifest is pointed there. The empty `sprites/` folder is the previous
project's extra nesting level and should be deleted; this project
flattens to `ai_placeholder/<class>/`.

A sheet is **one PNG per entity**: either a single multi-row sheet (one
clip per row, fixed cell size — what the inherited enemy sheets are) or
one horizontal strip per clip (what the Knight pack is). The manifest
supports both (§4). Prefer the multi-row sheet for anything new: one file
per entity keeps the folder listing readable and the record short.

## 3. The provenance record

`ai_provenance.json` in each class folder is a JSON object keyed by file
stem. **This document establishes the schema** — nothing in code reads it
yet, and the planned asset test will check only the keys marked required.

```json
{
  "_comment": "Every PNG in this folder has an entry here. Keys marked required in docs/authoring/ai_art.md §3.",
  "stone_guardian": {
    "file": "stone_guardian.png",
    "tool": "pixellab",
    "date": "2026-07-13",
    "method": "create_1_direction_object(view=sidescroller, size=128) + animate_object(v3, keep_first_frame=false)",
    "prompt": "slightly chibi pixel art side-view stone temple guardian, cracked basalt body, facing right, transparent background, no text",
    "clip_prompts": {
      "walk": "the near leg steps forward heel first, the far leg pushes off on its toe, scissoring past each other",
      "attack": "raises both arms high above its head then slams them down, a short grey dust burst where they land"
    },
    "style_ref": "none",
    "ids": {
      "object": "9a2d72e7-0bc3-47cf-b8f8-fdec175554c5",
      "review_pack": "0db2e480-… (candidate 3 of 4)",
      "animations": {"idle": "4681bcfe-…", "walk": "7ba7882a-…", "tell": "…", "attack": "…", "hurt": "…"}
    },
    "canvas": "128x128 generation canvas, padded to 128x128 cells; body ~110 px",
    "layout": "rows idle(4) walk(6) tell(4) attack(6) hurt(4); 128 px cells; frames bottom-anchored per frame",
    "frames_dropped": {"attack": [5]},
    "notes": "accessories detach in the attack tail; frame 5 dropped and fps re-derived"
  }
}
```

| Key | Required | Why it is there |
|---|---|---|
| `file` | yes | The record is keyed by stem; the extension makes the match unambiguous for the test. |
| `tool` | yes | `pixellab` today. The folder rule covers any tool. |
| `date` | yes | Models change; a date tells you whether a regeneration will match. |
| `method` | yes | Which tool calls, which engine (`v3`), `keep_first_frame`. Enough to redo it. |
| `prompt` | yes | The creation prompt verbatim. |
| `clip_prompts` | per animated clip | The animate prompt per clip, verbatim — the limb descriptions (§7) are the expensive part to rediscover. |
| `style_ref` | yes | `none`, or the path of the image used. Must be an asset whose license allows it (§1). |
| `ids.object` | yes | The PixelLab object id — the thing you download and re-animate. |
| `ids.review_pack` | if used | The review pack and which candidate won. |
| `ids.animations` | per clip | Animation ids, so one bad clip regenerates alone. |
| `canvas` | yes | Generation canvas, padded canvas, measured body height. The manifest's `body_h` comes from here. |
| `layout` | yes | Row order and frame counts, cell size, how frames were anchored. |
| `frames_dropped` | if any | Which generated frames were cut at assembly, so a regeneration knows to expect them. |
| `origin` | if copied | `"copied from dungeon-platformer <path>"` — for sheets inherited rather than generated here, so the record's ids are read against the right project. |
| `notes` | no | Whatever the next person needs. |

One record per *file*. If a species has a separate effects sheet, that is
a second record in `effects/`. `assets/ai_placeholder/README.md` sketches
the same record with the required keys only; this table is the full
schema and the one the asset test should check against.

## 4. The manifest entry

`data/sprites.json` → `<section>.<id>` is what the game reads
(`SpriteDb`, `game/autoload/sprite_db.gd`). Sections are `players`,
`enemies`, `objects`. Two shapes, both already in the file:

**Multi-row sheet** (one PNG, one clip per row — the inherited enemy
sheets, and the shape to prefer for new art):

```json
"stone_guardian": {
  "_source": "assets/ai_placeholder/enemies/ai_provenance.json — PixelLab, quarantined",
  "sheet": "res://assets/ai_placeholder/enemies/stone_guardian.png",
  "frame_w": 128, "frame_h": 128, "ground_y": 128, "body_h": 120,
  "faces_left": false, "scale": 1.0,
  "clips": {
    "idle":   {"row": 0, "frames": 4, "fps": 4,  "loop": true},
    "walk":   {"row": 1, "frames": 6, "fps": 6,  "loop": true},
    "tell":   {"row": 2, "frames": 4, "fps": 8,  "loop": true},
    "attack": {"row": 3, "frames": 6, "fps": 12, "loop": false},
    "hurt":   {"row": 4, "frames": 4, "fps": 10, "loop": false}
  }
}
```

**One strip per clip** (the Knight pack; each clip names its own `sheet`):

```json
"knight": {
  "_source": "assets/character/SOURCES.md — Knight by @Jump_Button (placeholder for the archaeology student)",
  "frame_w": 100, "frame_h": 64, "ground_y": 64, "body_h": 61, "faces_left": false, "scale": 1.0,
  "clips": {
    "idle": {"sheet": "res://assets/character/Knight_player/Idle_KG_1.png", "frames": 4, "fps": 6, "loop": true},
    "attack": {"sheet": "res://assets/character/Knight_player/Attack_KG_1.png", "frames": 6, "fps": 20, "loop": false}
  }
}
```

| Key | Default | Meaning |
|---|---|---|
| `_source` | — | **Every entry carries one.** A pointer at the provenance record (AI) or the `SOURCES.md` line (purchased). `SpriteDb` ignores it; the asset test and the reader don't. Several inherited entries (`blue_slime`, `orange_slime`, `mushroom`, `bush_lasher`, `boulder`, `button`, `lever`, `chest`, `save_shrine`) are missing it — open item. |
| `frame_w` / `frame_h` | required | Cell size on the sheet, px. |
| `ground_y` | `frame_h` | The row (from the cell's top) the feet stand on. The sprite is offset so this row lands on the owner's origin — the owner's origin is **feet**, like a `RoomEntry`. |
| `body_h` | `frame_h` | The **real** body height in px, measured from the frames — not the cell height, not a scale knob. §5 explains why it is the one number that decides on-screen size. |
| `faces_left` | `false` | True when the art faces −x (the Forest Monsters do). The owner flips accordingly. |
| `scale` | `1.0` | Extra draw scale, used when the owner doesn't pass a fit. |
| `sheet` | — | Default sheet for clips that don't name one. |
| `clips.<name>` | required | `{sheet?, row (0), frames (int or [indices]), fps (8), loop (false)}`. A `frames` **list** reorders or drops frames without touching the PNG — `[3, 0, 1, 2]` moves a late strike into the active window, `[0, 1, 2, 3]` drops a melted tail. |

These defaults (`fps`, `loop`, `scale`, `ground_y`, `body_h`, `row`) are
the one deliberate exception to the no-silent-defaults rule — they are
art-manifest conveniences, not gameplay values, and a missing sheet file
warns and skips the clip rather than failing the boot. A clip the owner
asks for that doesn't exist falls back along the chain the owner names
(`SpriteDb.play(sprite, "crawl", ["crouch_idle"])`), so a four-clip
sheet is *playable* on day one and a shipped one fills the chain in.

**Clip names the code asks for today.** Player: `idle walk run jump fall
land crouch crouch_idle crawl dash attack attack_air hurt death push
use_item aim swim` (`ladder`, `wall`, `ledge` are in the manifest but
nothing plays them yet). Enemies: `idle walk tell attack hurt death` plus
whatever a species script adds (`jump`, `spore`). Objects: `idle`, or
state names (`raised`/`pressed`). `tell` is not optional in practice: the
wind-up is the game's readability promise (design pillar 2, "never
comfortable" but always fair), and a creature whose tell doesn't read is
a bug even when the manifest is legal.

## 5. Sizing for 32 px tiles

The world is 32 px per tile; the viewport is 960 × 540, integer-scaled
×2 to 1080p, so one game pixel is a 2 × 2 block on screen. The player is
**1.5 tiles tall = 48 px** on screen. That number comes from
`data/player.json` → `sprite_fit_tiles`, and `SpriteDb.apply()` turns it
into a scale:

```
scale = fit_tiles × 32 / body_h          (when the owner passes fit_tiles > 0)
scale = entry.scale                      (otherwise — enemies and objects today)
```

So `body_h` is the fit divisor: declare the *measured* body height and
every player sheet renders to the same 48 px regardless of what canvas it
was drawn on. It is not a free scale knob — get it from the frames' bbox.
What the number actually decides is whether the engine scales the sheet
up or down, and by how clean a ratio:

| Generated body | Fit scale to 48 px | What nearest filtering does |
|---|---|---|
| 48 px | 1.00 | nothing — pixel-perfect |
| 61 px (Knight) | 0.79 | drops roughly every fifth row; a mild shimmer in motion |
| 64 px | 0.75 | drops every fourth row; acceptable for a placeholder |
| 96 px | 0.50 | exact halving — clean |
| 128 px | 0.375 | drops rows unevenly; faces turn to mush |

The project renders with `default_texture_filter = 0` (nearest). Nearest
upscales cleanly and downscales by dropping rows, so **generating a
64–96 px body and fitting down is fine for placeholders**, and 96 px —
an exact half — is the sweet spot when you can hit it. Avoid bodies much
over 100 px for anything the fit will shrink; a 146 px body at 0.33×
visibly shimmers, which the previous project learned at 64 px/tile and
which is twice as true at 32.

**Recommended generation sizes** (the canvases the previous project found
worked — the object creator *fills* its canvas, so canvas ≈ body):

| Subject | `size` | Body lands | Fits to |
|---|---|---|---|
| Player, humanoid NPC | **~100** | 64–96 px | 48 px at 0.5–0.75× |
| Small creature, pickup, prop | **64** | 40–60 px | about 1 tile at `scale` 0.6–0.8, or 1.0 for a 1-tile object |
| Boss | **128** | 100–120 px | 3–4 tiles at `scale` 1.0 (no fit) |

The two PixelLab pipelines do not mean the same thing by "canvas": the
character creator leaves margin for eight rotations (a 63 px body on 160,
39 % fill) while the object creator fills the frame (146 px on 160,
91 %). Matching a character-creator canvas number gets a body twice as
tall as you meant. Bigger canvases also miss more often — at 160, two of
four candidates came back as an item sheet and a wall trap; at 100 it was
four of four.

Enemies fit the same way: `Enemy._build_children()` passes the species'
`fit_tiles` from `data/enemies/<species>.json`, so a slime (`body_h` 22,
`fit_tiles` 1.0) draws 32 px tall at 1.45× and the Stone Guardian
(`body_h` 120, `fit_tiles` 3.5) draws 112 px at 0.93×. The manifest's
`scale` only applies where no fit is passed — objects, today, which are
64 px sheets at 0.5× (one tile). Either way `body_h` must be the measured
height: the fit reads it, and a wrong value makes a species the wrong size
in every room at once. Note the enemy's *collision* size is separate —
`body_w`/`body_h` in the species JSON, in world px — and should agree with
what the fitted sprite shows (`F2` draws both).

## 6. Object tools, not character tools — and why

> **Standing method (carried from the previous project, author's call,
> 2026-08-01): use PixelLab's OBJECT tools — `create_1_direction_object`
> + `animate_object` — and never the character tools
> (`create_character` / `animate_character` / `create_character_state`)
> for any sprite or animation, player included.**

The character creator locks a sprite into eight rotations and draws a 3/4
pose whose far foot floats 5–8 px above the near one, so every clip
inherits a hovering boot and the ground line has to be fudged into the
sole. Its template animations re-draw the hands and lose whatever the
character is holding whenever the arms move, which costs a re-roll per
weapon. And a side-scroller uses one of the eight directions.

The object creator gives a true side-on 3/4 with **both feet planted on
one row**, keeps held gear in every frame because there is no template
engine to redraw it, generates only the one direction the engine uses,
and — through the padding step below — lets you choose the animation
canvas, which the character creator never does. Its single direction is
named **`unknown`**, not `south-east`.

The costs, honestly, from the previous project's Alpha Scout experiment:
v3 animates the flashy element and leaves the body still unless the
prompt names limbs; big motions degrade in their tail frames and need
trims; and creation has real variance, so a review pack and a cherry-pick
are mandatory. The style also matches the shipped look **only if you ask
for it** — a size-160 pass drew realistic proportions that read as a
different game next to near-chibi placeholders; "slightly chibi, large
head" closed the gap. Net: better posture and identity, worse body
motion, and a prompt discipline you have to keep.

## 7. The procedure

With the PixelLab MCP server attached (in a Claude session, load its tools
with `ToolSearch` for `mcp__pixellab__*`), in order:

1. **Create.** `create_1_direction_object` with `view: "sidescroller"` and
   `size` from the §5 table. Prompt the *subject* and the style: "slightly
   chibi pixel art side-view <thing>, <two or three concrete design
   elements>, facing right, transparent background, no text". Ask for a
   multi-candidate review pack — the object creator does not know it is
   drawing a character, and one candidate in four is routinely a crate, a
   wall fixture or an item sheet.
2. **Cherry-pick.** `select_object_frames` from the review pack. A human
   (or the session, reporting its choice) picks; record the candidate
   index in the provenance. Keep a backup object id if two were close.
3. **Pad before you animate.** Take the chosen frame, paste it centred on
   a transparent canvas roughly **2× its size** — about its own height
   again in headroom and half that below the feet — quantize the PNG to
   its own palette (a 57-colour sprite compresses to ~1.7 KB; the value
   is repeated on every call), and pass it as `animate_object`'s
   `custom_start_frame_base64`. **This is the load-bearing step:** the
   supplied image's dimensions *become* the animation canvas. Without it
   the body fills the frame with zero footroom and every crouch, leap,
   lunge and downward swing is clipped at the edge. Verify the first
   call succeeds before firing a batch; a truncated base64 fails with
   "broken data stream". (A `custom_start_frame_url` variant exists but
   needs a public URL, which a locally padded frame does not have.)
4. **One `animate_object` per clip**, mode `v3`, `keep_first_frame:
   false`. Concurrency caps at 10 jobs. Clips per §4: the player set, or
   `idle walk tell attack hurt death` for a species, `idle` for a static.
   Three prompt rules that each cost a regeneration to learn:
   - **Describe limbs, not effects.** v3 will animate the glow and leave
     the body still — a finisher that sweeps a gorgeous arc while the
     sword arm never moves. "The near leg steps forward heel first, the
     far leg pushes off on its toe, scissoring past each other" turns a
     cloak-flapping non-gait into a stride; "raises the axe high above
     her head with both arms **then** swings it down" gets the arm moving.
   - **Vague design elements dissolve; loud ones bleed.** A soft-glow
     accessory degrades into floating specks; a large saturated one
     contaminates the attack VFX, because v3 borrows the nearest strong
     colour (cyan slash arcs came back muddy green next to a green
     shield). Give accessories hard edges in a colour that is not the
     VFX colour.
   - **VFX go IN the attack sheets.** Nothing is overlaid on a body at
     runtime, so `attack` must include its own slash trail, dust or
     impact burst — ask for it ("a thin bright crescent slash trail
     following the blade"). Keep everything *else* (idle, walk, tell,
     hurt) clean body motion, described mechanically, so a separate
     effects sheet can be layered if the game ever wants one.
5. **Download the whole object as a zip** from
   `https://api.pixellab.ai/mcp/objects/<id>/download` — far cheaper than
   repeated `get_object` calls. Frames arrive as
   `<description-slug>/unknown/frame_NNN.png`.
6. **Measure, then choose the window.** Dump every frame's bbox. Set the
   ground row where the feet actually land (both feet, one row — that is
   what the object pipeline buys you), the footroom for whatever hangs
   below (a downward swing, a dangling tail), and the frame **wide enough
   for the VFX**, not the body: a 64 px silhouette with a slash arc needs
   a ~100 px cell. Any frame whose art escapes the window is a bug to fix
   at the window, never a silent crop.
7. **Trim the tails.** v3 degrades the further a frame is from its
   reference: weapons melt and accessories detach in the last frames of a
   big motion. Drop them with the clip's `frames` list rather than
   regenerating, **re-derive `fps`** for the new count (§8), and reorder
   if the strike landed late. Record the drops in `frames_dropped`.
8. **Assemble** into one PNG (§9), write the manifest entry (§4) with
   `_source`, measured `body_h`, the chosen `ground_y`, and the
   provenance record (§3). File both in the class folder.
9. **Review in the game.** Run it, find the thing, press `F2`: the
   hurtbox should sit on the body, the feet on the floor line, the attack
   arc where the hitbox is. Check the defects a still frame hides — a
   foot that never reaches the contact row, a loop whose last frame
   doesn't meet its first, a clip so static it reads frozen, a clip that
   outlives its action (§8). Then F1 the owner's numbers if the art
   changed what reads well.

**If PixelLab is unavailable**, point the manifest at the closest existing
placeholder (an inherited sheet, or the Knight for a humanoid), let the
fallback chains cover the missing clips, and report the art as pending.
Never block data or room work on art — that is the whole reason the
placeholder policy exists.

## 8. Timing a clip to its action

**A clip longer than its action never finishes**; a clip much shorter
reads as nothing. Frame count and `fps` are not taste — read the action's
real length and fit the clip inside it, with the strike frame landing in
the active window.

- **Player attacks:** `data/weapons.json` → `<weapon>.startup + active +
  recovery`, in seconds. The sword is `0.06 + 0.12 + 0.14 = 0.32 s`; the
  Knight's 6-frame attack at 20 fps runs 0.30 s and fits, with frames
  2–3 (0.10–0.15 s) inside the active window. The whip is 0.41 s. A
  5-frame clip at 13 fps would run 0.38 s and be cut off mid-swing on the
  sword, which is exactly what "the attack looks like almost nothing"
  is.
- **Player `hurt`** ends with `hurt_stun` (0.25 s); `dash` with
  `dash_time` (0.16 s); `land` is held 0.12 s (`_land_time`).
- **Enemy clips** (`data/enemies/<species>.json`): `tell` **loops** for
  the brain's `tell_time` (bosses: × `tell_mult_p2` in phase 2) under a
  code-driven white pulse, so its length is free but its rhythm should
  read as a wind-up; `attack` must fit the brain's active window — a
  lasher's `lash_startup + lash_active + lash_recover`, a walker's
  `spore_delay + spore_recover`, a guardian's `slam_delay + slam_active +
  slam_recover` — with the strike frame landing after the startup;
  `hurt` must fit `hurt_stun` (a boss with `hurt_stun` 0 only flashes, so
  its hurt clip is never seen); `death` is the one clip that **always
  plays to its end** — `Enemy.die()` keeps the body for the longer of the
  clip and `death_linger` — so a long death is a design choice, not a
  bug.
- **Gaits** are timed against travel or the feet slide: cycle seconds ≈
  2 × stride ÷ speed. At `walk_speed` 85 px/s a 7-frame walk at 9 fps
  (0.78 s) implies a 33 px stride — one tile, right for a 48 px body. At
  `run_speed` 185 the same count at 14 fps (0.5 s) implies 46 px, which
  is why the Knight's run is its walk sheet played faster.

Everything in this section is an F1-tunable; if the author retunes an
attack, the clip's `fps` is the knob that follows it.

## 9. Assembling the sheet (strip tool — port TODO)

The previous project assembled PixelLab frames with
`tools/pixellab_player_strips.py`. **This repo does not have it yet**; the
inherited sheets were assembled with ad-hoc scripts in that project. Until
it is ported, assemble by hand (any image tool that can paste frames on a
grid) and record the window numbers in the provenance. When it is ported,
this is what it does and what changes:

**What it does.** Takes a frames directory (the unzipped download:
`<src>/<clip>/<direction>/<n>.png`), an output directory and a
`spec.json`. The spec maps each manifest clip to its source clip and
optionally selects frames; underscore keys set **one crop window shared by
every clip**, so all clips agree on where the ground and the body centre
are:

| Spec key | Meaning |
|---|---|
| `_direction` | the frames subfolder — `"unknown"` for objects |
| `_canvas` | the PixelLab canvas edge, px |
| `_center_x` | the column the body centres on (default canvas/2) |
| `_ground` | the canvas row the feet stand on |
| `_frame` | `[frame_w, frame_h]` of the crop window |
| `_footroom` | rows kept below `_ground` |
| `_body_h` | the measured body height → manifest `body_h` |
| `_downscale` | integer density divisor (default 1) |
| `<clip>` | `{"src": "<pixellab clip>", "frames": [i, …]}` |

It writes one horizontal strip PNG per clip, prints the
`frame_w/frame_h/ground_y/body_h` to declare in the manifest, and **fails
loudly on any frame whose art falls outside the window** — a silent crop
would clip a sword mid-swing. `_downscale` is the repair for a sheet
generated at the wrong density: box-average down by an integer, snap every
pixel back to that frame's own palette (plain averaging invents blend
colours that pixel art reads as mush), re-harden alpha, and divide the
four reported numbers to match. It costs real detail, so it is the
fallback, not the plan — fix density at generation (§5).

**What the port changes.** Its defaults are the previous project's Alpha
Fighter (`_canvas` 160, `_ground` 107, `_frame` [144, 112], `_footroom`
25, `_body_h` 64, `_direction` "south-east"); none of those are right
here, so every spec states its own and the defaults should become
required. It emits one strip per clip; this manifest also accepts a
multi-row sheet, and a `--rows` mode that stacks the strips into one PNG
(cell = the window, one row per clip in spec order) would match the
inherited sheets. It depends on Pillow. It belongs at
`tools/pixellab_strips.py`, and like every other tool it is a headless
script that never touches a `.tscn`.

## 10. Checklist for one new sheet

- [ ] Brief from the author names the subject, its role (which species /
      object / player), its size class and two or three design elements —
      the session does not invent them
- [ ] `size` from the §5 table; `view: "sidescroller"`; no style image
      from a license-restricted pack
- [ ] Review pack generated; candidate chosen and recorded
- [ ] Chosen frame padded to ~2× and passed as `custom_start_frame_base64`
- [ ] One `animate_object` v3 per clip; limbs described; VFX only in
      `attack`
- [ ] Zip downloaded; every frame's bbox measured; window sized off the
      VFX; ground row where both feet land
- [ ] Tails trimmed with `frames`; `fps` re-derived against §8
- [ ] PNG under `assets/ai_placeholder/<class>/`; record in that folder's
      `ai_provenance.json` with every required key
- [ ] Manifest entry with `_source`, measured `body_h`, `ground_y`,
      `faces_left`
- [ ] Walked in-game with `F2`; feet on the floor line, hurtbox on the
      body, clip ends inside its action
- [ ] Report lists the file, the record, every prompt, every frame dropped,
      and anything the brief left to the session's judgement
