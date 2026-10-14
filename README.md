# The Temple of Rhys

A robbed and stranded archaeology student has only one way out of a
collapsed mountaintop: down, through the temple of a snake god. The
quickest route out takes a few hours, and it damns them. The way to save
the world is hidden in the temple's script, in its shape, and in its god's
name. It is a 2D side-scrolling metroidvania with Zelda-style dungeon
puzzles, in pixel art, where darkness and lighting carry the mood; the
critical path runs three to five hours and ends badly, and the better
endings belong to the player who learns to read. The design is
[design_v2.md](design_v2.md) — plain text there is decided, `> Proposal:`
blocks aren't, §17 is the open-question list.

Built in pure Godot 4.7 GDScript by one developer with AI help. The
rules below are what make that arrangement work, and they matter more
than anything else in this file.

## The principles

**AI-generated art may ship, but it stays in quarantine.** Everything an
AI produced lives under `assets/ai_placeholder/<class>/` and nowhere else,
with a record in that folder's `ai_provenance.json` saying which tool,
which prompt, which ids and when. Purchased or commissioned art lives under
`assets/<class>/` with a line in that folder's `SOURCES.md` and the
license text in `assets/licenses/`. The point is that three things are
always true at a glance: it is obvious what is AI-made (the path says so),
any one piece is replaceable by editing a manifest path in
`data/sprites.json`, and all of it is purgeable by deleting one folder. A
test, `tests/test_assets.tscn`, guards the boundary by failing on any
manifest path that lives in neither place (it is on the bootstrap
open-items list until it lands). How the art is actually made is in
[docs/authoring/ai_art.md](docs/authoring/ai_art.md).

**Agents draft; they never design.** Every room, enemy, item and puzzle in
this game is the author's idea. An agent's job begins when a concept is
mostly final — "a room shaped like this, with these exits, this enemy,
this secret" — and consists of building exactly that, filling placeholders
only where the brief is silent and reporting every placeholder it filled
so the author can sweep them afterwards. "Make me twenty rooms" is not a
use of these tools; it is the failure mode they exist to prevent. A brief
is a spec to implement, not a prompt to riff on: agents don't invent
mechanics, don't add unrequested entities, and don't improve the design.
When code and a document disagree, they flag it rather than silently
picking one.

**All final rooms are hand-authored in the Godot editor, and nothing
generates `.tscn` files.** The room scene you edit is the scene the game
runs; there is no exporter and no second copy of the geometry. A one-off
script kept outside the repo and deleted afterwards is allowed as a first
draft — the five test rooms started that way — but from the moment the
file exists, the editor owns it. `data/rooms.json` is a build artifact of
`tools/build_room_registry.gd` and is committed next to the scenes, never
hand-edited.

**The kind layer is the only playable truth; art is paint.** Each room has
one `Collision` layer painted with `game/rooms/tileset_kind.tres`: eight
flat tiles — solid, oneway, breakable, fortified, water, hazard, two ramps
— each carrying a `kind` string and, where you stand on it, its physics
shape. Nothing outside that layer can change what the player collides
with. The look is hybrid: a `SkinLayer` auto-tiles the room's chosen art
over the kinds at runtime for free, and optional hand-painted
`DecorBack`/`DecorFront` layers and `Props` sit over that for rooms that
earn it. `F2` strips the paint away so the truth is always one key away.

**Rooms live on a shared world grid, so the map is faithful geometry.**
Every room has a `world_x`/`world_y` in tiles and is placed there at
runtime, so neighbours line up and the notebook map can be drawn from
real rectangles rather than a hand-kept layout. The design needs this
(§12): the god's name is read off the finished map, which only works if
the map tells the truth. A door with no target entry is a seam — the
player keeps its world position — and the registry validator refuses a
seam whose rooms don't touch.

**All numbers live in `data/*.json`, missing keys are hard errors, and
everything reloads live.** No tunable is hardcoded in a script. A key that
isn't there fails at first use with the file and key named
(`Data.req`), rather than quietly behaving oddly; the deliberate exception
is a handful of art-manifest keys with documented defaults. `F3` re-reads
every file from disk mid-play and `F1` edits any number in place, which is
what makes iterating on feel fast enough that nobody is tempted to bake a
constant.

**Tests are headless scenes.** A script run with `-s` is compiled before
the autoloads exist and cannot name `Data` or `GameState`, so tests are
`tests/test_*.tscn` scenes whose script runs in `_ready()` and quits with
an exit code. `tests/test_boot.tscn` validates the room registry, starts a
game, loads every room and exercises the player. `tests/run_all.sh` runs
them all (planned alongside the asset-boundary test).

## Quick start

You need **Godot 4.7-stable** on your `PATH` as `godot`, headless-capable.
There is no build step and no GDExtension.

```bash
godot --headless --path . --import       # once per checkout: builds the .godot cache
godot --path .                           # play
godot --headless --path . res://tests/test_boot.tscn           # the boot test
godot --headless --path . -s res://tools/build_room_registry.gd # after any room change
```

The game opens on a title screen, then a slot picker; a new game starts in
the test entry hall with a debug loadout (sword, slingshot, grappling hook,
lantern) that the design will replace with "nothing".

**Controls.** Movement is analog: how far you push the left stick picks
walk or run (`walk_threshold` in `data/player.json`); on a keyboard, hold
Ctrl to walk. Crouching is the bow from the design (§9.2), so it has its
own button rather than stick-down. Free aim is a hold: while held, the
left stick (or the mouse) aims and the right stick moves.

| Action | Pad | Keyboard / mouse |
|---|---|---|
| Move | left stick, d-pad | WASD, arrows |
| Walk | stick magnitude | hold Ctrl |
| Jump (variable height) | A | Space |
| Attack (equipped weapon) | B | J |
| Item slot X / Y | X / Y | K / L |
| Crouch, crawl, bow | RT | S, Down |
| Dash | RB | Shift |
| Free aim (hold) | LT | right mouse button |
| Interact | LB | E |
| Pause / items | Start | Esc |
| Map | Back | Tab |
| Menu: accept / back | A / B | Enter / Esc |
| Menu: use / drop / assign | B / Y / LB | J / L / E |
| Menu: tabs | LB / RB | Q / R |

Debug keys in play: **F1** tuning panel (edits any `player`, `objects` or
`weapons` number in place, unsaved — copy what works into the JSON),
**F2** debug view (kinds, hitboxes, exit rects, enemy state), **F3**
reload all data from disk, **F4** jump to the next room in the registry.
The input map is generated from the table in `tools/gen_project_godot.py`;
edit the table, re-run it, never `project.godot` by hand.

## Adding a room in five steps

1. *Project → Tools → New Room…* in the editor. Give it a snake_case name
   and its `world_x`/`world_y` in tiles — read the neighbour's position out
   of `data/rooms.json` first, because seams only work when the doorways
   land on the same world rows.
2. Paint `Collision` with the kind palette. Erase the border cells where
   the doors go.
3. Add a `RoomExit` over each doorway (and the matching exit back in the
   neighbour), and put a `RoomEntry` with its feet on the floor.
4. Pick a `skin`, `background` and `music` from the dropdowns.
5. *Project → Tools → Rebuild Room Registry* (or the headless command
   above), run the boot test, commit the scene **with** `data/rooms.json`.

The whole contract — the eight kinds and what each does, seams versus
teleports, the validator's messages, how skins and backgrounds are added,
and a step-by-step tutorial that builds a sixth test room — is
[docs/room_authoring.md](docs/room_authoring.md).

## Repository layout

```
game/main.gd            scene flow: title → start menu → World (+HUD, pause)
game/world.gd           owns the current Room and the Player; transitions, death, toasts
game/player/            CharacterBody2D controller; items; free-aim; grapple; light
game/rooms/nodes/       Room, RoomExit, RoomEntry, SkinLayer, Backdrop, GreyboxLayer,
                        BreakableTile, RoomRegistryBuilder  (@tool, editor-safe)
game/rooms/test/        the five test rooms (drafted once by script, now editor-owned)
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
tools/                  headless scripts (registry build, kind-tileset generator, input map)
tests/                  headless test scenes + run_all.sh
docs/                   room_authoring.md, authoring/ai_art.md, implementation_log.md
```

`game/objects/` is being built as this is written (the enemies, the UI
stack and the F1 panel landed during the bootstrap session);
`docs/implementation_log.md` records what has landed and what is open.

## Git and large files

Binary assets (`*.png`, `*.ogg`, `*.wav`, `*.xcf`, fonts) are stored in
Git LFS on a self-hosted rudolfs server; `.lfsconfig` points at it and
`.gitattributes` lists the patterns. Run `git lfs install` once per clone
**before your first commit** — without it the files still become pointers
on commit, but nothing is ever pushed to the server, and they exist only
in your local `.git/lfs`. Everything under `data/` and every `.import`
file stays in git proper, so the room registry diffs as text. A clone
somewhere the server isn't reachable gets ~130-byte pointer files in
place of images; the game still boots (missing sheets warn and skip), and
the planned `tests/run_all.sh` detects that state by content and skips
the asset-decoding tests with a banner rather than failing on them.

Commit room scenes together with the regenerated `data/rooms.json`.

## Credits and licensing

Everything the game loads has a recorded source or an open item against
it. The per-class detail is in each `assets/<class>/SOURCES.md`; the
summary:

- **Knight player sprite** (`assets/character/Knight_player/`) by
  **@Jump_Button** — the placeholder for the archaeology student. Free
  for commercial use **with credit required**; modification allowed; no
  resale; and **explicitly no use of the art for AI or machine-learning
  purposes**, which for us means it is never fed to PixelLab as a style
  reference. See the pack's `Read_me.txt`.
- **Tilesets, backdrops and props** — Szadi art's "Seasonal Sprite
  Worlds" packs (SSW SET3, SET4, SET5, SET7, SSWorlds SET2, SSW2 SET2,
  Castle Pack). "License for Everyone": commercial use and selling works
  made with them allowed, no resale of the packs, no logo/trademark use;
  credit appreciated, not required. Full text per pack in
  `assets/licenses/`.
- **Forest Monsters pack** (`assets/enemies/forest_monsters/` — the slimes,
  the mushroom, the bush monster). **Open item:** no license text is on
  disk; record author, terms and receipt before anything using these ships.
- **Music** — Abstraction's Music Loop Bundle (Tallbeard Studios), eight
  "Sketchbook" loops. CC0 / public domain; the author asks that it not be
  used for NFTs, AI/ML or unmodified resale, and appreciates the credit
  "Abstraction" with a link to abstractionmusic.com.
- **Sound effects** (`assets/sfx/`) — from the "400 Sounds Pack" and
  whatever came in alongside it. **Open item:** the pack ships no license
  file and no per-file attribution exists yet.
- **AI placeholder art** (`assets/ai_placeholder/`) — generated with
  PixelLab, most of it carried over from the previous project. Its
  provenance records have not been carried with it yet (open item); the
  rule for anything new is in [docs/authoring/ai_art.md](docs/authoring/ai_art.md).

The rule itself, the per-class index and the live list of licensing open
items are in [assets/SOURCES.md](assets/SOURCES.md).
