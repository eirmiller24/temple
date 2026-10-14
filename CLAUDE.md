# CLAUDE.md

The Temple of Rhys — a 2D side-scrolling metroidvania with Zelda-style
dungeon puzzles, built in **pure Godot 4.7 (GDScript)**. Single player, no
GDExtension, no determinism requirements. A solo developer with AI help;
the process rules below are the point of this file.

## Read these first

- [design_v2.md](design_v2.md) — the design document. Plain text is decided,
  `> Proposal:` blocks aren't, §17 is the open-question list. `design.md`
  is the raw idea log it supersedes.
- [README.md](README.md) — the principles: AI art ships but stays
  quarantined, agents draft and never design, rooms are hand-authored,
  nothing generates scenes, the kind layer is the only playable truth.
- [docs/room_authoring.md](docs/room_authoring.md) — the room scene
  contract (nodes, kinds, objects, exits, world grid, skins) and the
  tutorial for building one.
- [docs/authoring/ai_art.md](docs/authoring/ai_art.md) — how placeholder
  art is generated with PixelLab, recorded, and kept in quarantine.

## Environment & commands

Godot **4.7-stable** on PATH as `godot` (headless-capable). No build step.

```bash
godot --headless --path . --import                     # once per checkout: build the .godot cache
godot --path .                                          # play
godot --headless --path . -s res://tools/build_room_registry.gd   # after any room change → data/rooms.json
godot --headless --path . res://tests/test_boot.tscn    # one test (tests are SCENES, see below)
tests/run_all.sh                                        # all of them
python3 tools/gen_project_godot.py                     # after editing the input-map table
```

**Tests and tool scripts.** A script run with `-s` is compiled before the
autoloads exist, so it cannot name `Data`, `GameState`, etc. — the parse
fails. Therefore: tests are scenes (`tests/test_*.tscn` with a Node
script that runs in `_ready` and calls `get_tree().quit(code)`), and
`-s` tool scripts only touch the plain classes (`RoomRegistryBuilder`,
`Room`) after `await process_frame`. `@tool` scripts (the room nodes)
follow the same rule and reach autoloads through `Game.data()`,
`Game.state()`, `Game.sfx()`… (`game/game.gd`), dynamically typed.

Debug keys in play: **F1** tuning panel (edit any data number live),
**F2** debug view (kinds, hitboxes), **F3** reload all data from disk,
**F4** jump to the next room.

## The one rule that matters

**Playable truth is the room's `Collision` layer; everything else is
paint.** `game/rooms/tileset_kind.tres` is the authoring palette — flat
tiles carrying a `kind` string (solid, oneway, breakable, fortified,
water, hazard, ramp_r, ramp_l) and, where solid, the physics shape. The
runtime `SkinLayer` auto-tiles the room's `skin` art over it via
terrains; `DecorBack`/`DecorFront`/`Props` are optional hand-painted
paint over that. Nothing outside `Collision` can change what the player
collides with. Adding a kind is a three-place change: the tile in
`tools/gen_kind_tileset.gd` (re-run it), `GreyboxLayer.KIND_COLORS`, and
whatever reads `Room.kind_at()`.

**Rooms are hand-authored scenes and ARE the runtime scene.** No
exporter, no generated `.tscn`, ever. An agent (or a one-off script kept
outside the repo and deleted afterwards) may *draft* a room as a first
pass; from then on the editor owns it. `data/rooms.json` is a build
artifact (`tools/build_room_registry.gd`) — never hand-edit it; commit it
with the scene.

**World grid.** Every room has `world_x`/`world_y` (tiles). At runtime
the root sits at that offset, so neighbours line up and the map is drawn
from real geometry (design §12 needs the map to be faithful). A `RoomExit`
with an empty `to_entry` is a seam (the player keeps its world
position); with a `to_entry` it teleports. The registry validator checks
that seams touch their neighbour and are wired both ways.

## Architecture

```
game/main.gd            scene flow: title → start menu → World (+HUD, pause)
game/world.gd           owns the current Room and the Player; transitions, death, toasts
game/player/            CharacterBody2D controller; items; free-aim; grapple; light
game/rooms/nodes/       Room, RoomExit, RoomEntry, SkinLayer, Backdrop, GreyboxLayer,
                        BreakableTile, RoomRegistryBuilder  (@tool, editor-safe)
game/objects/           push block, button, lever, gate, locked door, pickup, shrine, anchor
game/enemies/           Enemy base + species scripts; bosses
game/combat/            Hitbox, Hurtbox, Projectile
game/ui/                title, start menu, HUD, pause menu (items/map), options, minimap
game/autoload/          Data, Wiring, SpriteDb, Music, Sfx, Juice, SaveManager, GameState,
                        RoomRegistry
addons/room_tools/      Project > Tools > New Room… / Rebuild Room Registry; room_template.tscn
data/                   every tunable and manifest (JSON); rooms.json is generated
assets/                 licensed art/audio, one SOURCES.md per class, licenses/
assets/ai_placeholder/  EVERYTHING AI-generated, by class, with ai_provenance.json
raw_assets/             gitignored source packs (zips, PSDs)
tools/                  headless scripts (registry build, generators)
tests/                  headless test scenes + run_all.sh
```

**Physics layers** (project.godot `[layer_names]`): 1 world, 2 player,
3 enemy, 4 player_hurtbox, 5 enemy_hurtbox, 6 player_hitbox,
7 enemy_hitbox, 8 interact, 9 pushable, 10 switch, 11 grapple,
12 projectile, 13 breakable, 14 room_exit. A `Hitbox` (Area2D) calls
`take_hit(info)` on anything it overlaps that has the method while
`active`; `Hurtbox` forwards to its owner's `on_hit(info)`. The info
dict: `damage, knockback (Vector2), source, origin, kind, tier, hitstop`.
`tier` 1 is keystone-grade (breaks fortified walls).

**Puzzle wiring:** `Wiring.drive(channel, source, on)`; gates listen to
`Wiring.channel_changed`. Reset per room.

**Sprites:** `data/sprites.json` → `SpriteDb.apply(sprite, section, id,
fit_tiles)`. Clips are rows/strips on sheets; `ground_y` puts the feet at
the owner's origin. Enemies render with `faces_left` honoured. Swapping
art is a manifest edit.

**Autoload access:** runtime scripts use the names (`Data.player`,
`GameState.add_item`, `Music.play_track`, `Sfx.play`, `Juice.hitstop`).

## Tuning data

All gameplay numbers live in JSON under `data/` and reload live (F3; F1
edits them). **Never hardcode a tunable in a script** — add it to the
relevant `data/*.json`. Missing keys are hard errors by design
(`Data.req` / `Data.num` / `Data.inum`); don't add silent defaults for
gameplay values. (Art-manifest keys with documented defaults — `fps`,
`loop`, `scale` — are the one deliberate exception.)

## AI-generated art

Allowed to ship, but **everything AI-generated lives under
`assets/ai_placeholder/<class>/` and nowhere else**, with an
`ai_provenance.json` entry (tool, prompt, ids, date) per asset. Purchased
art lives under `assets/<class>/` with a `SOURCES.md` line and its
license file in `assets/licenses/`. `tests/test_assets.tscn` fails on a
manifest path that is in neither place. See docs/authoring/ai_art.md for
the PixelLab workflow.

## Agents draft, they never design

Every room, enemy, item and puzzle is the author's idea. An agent's job
starts when a concept is mostly final and consists of building exactly
that, filling placeholders only where the brief is silent and
**reporting every placeholder it filled**. "Make me twenty rooms" is the
failure mode these rules exist to prevent. When code and a doc disagree,
flag it — don't silently pick one.

## Git

Binary assets are in Git LFS on the local rudolfs server (`.lfsconfig`);
run `git lfs install` once per clone before the first commit. Commit
room scenes together with the regenerated `data/rooms.json`.
