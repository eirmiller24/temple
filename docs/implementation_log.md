# Implementation log

Append-only. One entry per working session, newest at the bottom. Each
entry says what was decided, what landed, what was found, and what is
still open — so the next session (human or agent) starts from the state
of the repo rather than from memory. Decisions here are the record;
`design_v2.md` stays the design, `CLAUDE.md` the rules.

---

## 2026-10-13 — Bootstrap

The project was started by cannibalising the process and the reusable
shell code of the previous game (dungeon-platformer, a GDExtension C++ sim
with a Godot shell) and rebuilding it as a pure-Godot metroidvania around
`design_v2.md`.

### What was carried over, and what was left behind

**Carried:** the house rules and their phrasing (CLAUDE.md's shape;
missing-key-is-a-hard-error data loading; "playable truth is the
Collision layer"; "agents draft, they never design"; the AI-art
quarantine; tests as the acceptance criterion); the room-node design —
typed `@tool` nodes with inspector fields, gizmos and scene-tree
warnings, a `Room Tools` editor plugin with *New Room…* from a copied
template, data-backed dropdowns for skin/background/music; the
`SkinLayer` (ring, thin-geometry patch, unmatched → greybox), `Backdrop`
(parallax clipped to the room) and `GreyboxLayer` ports; the sprite
manifest idea (`SpriteDb`: sheets + clips + `ground_y`/`body_h` fit); the
music crossfade with "same track name across a seam keeps playing"; the
one-shot SFX pool; `Wiring` channels (0–31, driven by instance, reset per
room); the `Hitbox`/`Hurtbox`/`take_hit(info)` combat contract with a
`tier` for keystone-grade hits; the `.gitattributes` LFS layout and the
rudolfs server; the PixelLab object-tools workflow and its hard-won prompt
rules (now `docs/authoring/ai_art.md`); the Szadi SSW tile packs,
backdrops and props, the Abstraction music loops, the sound pack, and the
PixelLab placeholder sheets for objects, pickups, two bosses and a burst.

**Left behind, deliberately:** the C++ sim and GDExtension; fixed-point
determinism, replay tapes and the hash canary; the room *exporter* and
the `data/rooms/*.json` + `data/map_layout.json` pair (here the scene is
the runtime scene and the registry is derived); 16 px authoring over a
64 px world (one 32 px grid here); `.claude/agents/` (this project ships
no agents — the procedures are in `docs/` for any session to follow); the
pet/class/move/NPC authoring surface; the playground room.

### Decisions

| Decision | Why |
|---|---|
| **Pure Godot 4.7 GDScript**, no GDExtension, no determinism requirement | Single-player, no replays; the C++ sim existed to make a roguelike reproducible and cost a build step and a second language for every feature. |
| **32 px tiles**, one grid for authoring and runtime | The SSW packs are 32 px native (scale 1, no ×2); 16/64 split grids were a source of unit mistakes. |
| **960 × 540 viewport**, `canvas_items` stretch, integer scale | 30 × 16.9 tiles on screen; exactly ×2 on 1080p so every game pixel is a 2 × 2 block. |
| **Player 1.5 tiles tall** (48 px) via `sprite_fit_tiles` and `body_h` | Readable at 32 px/tile; the Knight placeholder (61 px body) fits down at 0.79×. |
| **Hybrid collision/look**: kind layer with physics shapes + runtime auto-skin + optional hand decor | The kind tiles carry their own polygons, so there is no byte table and no exporter; the skin makes every room presentable for free; decor is spent only where it earns it. |
| **Eight kinds**: solid, oneway, breakable, fortified, water, hazard, ramp_r, ramp_l | The previous set minus ice plus hazard. `fortified` is the Power-Fang wall (design §9.1); `water` is swimming (§7.1). |
| **Rooms are the runtime scene**; `data/rooms.json` is a build artifact with an in-memory rebuild fallback | No second copy of geometry; a stale registry warns and the game still boots. |
| **World grid** (`world_x`/`world_y`), seam vs teleport exits, validator checks adjacency and both-ways wiring | Design §12: the map must be faithful geometry. Seams keep the player's world position; teleports name an entry. |
| **Analog walk/run** by stick magnitude; keyboard Ctrl walks | The design has both verbs; a run button on a stick is a wasted button. |
| **Pad mapping**: A jump, B attack, X/Y item slots, RT crouch/bow, RB dash, LT free-aim (hold), LB interact, Start pause, Back map; menu A select / B use / Y drop per design §7.2 | Crouch is the bow (§9.2) so it must be its own button, not stick-down, or every stop-and-aim risks an activation. |
| **Free aim**: while LT is held, left stick aims and right stick moves; mouse aims on keyboard | Whip and slingshot are "freely aimed" in the design (§10). |
| **Combat info dict** `{damage, knockback, source, origin, kind, tier, hitstop}`; tier 1 breaks fortified | One contract for the player, enemies, projectiles and walls. |
| **All numbers in `data/*.json`**, `Data.req/num/inum` hard-error on a missing key; F3 reloads, F1 edits | Carried rule. Art-manifest keys with documented defaults are the one exception. |
| **Tests are scenes**; `-s` tool scripts touch only plain classes after `await process_frame`; `@tool` scripts reach autoloads via `Game.*()` | A `-s` script is compiled before autoloads exist and cannot name them. |
| **Git LFS** on the local rudolfs server; JSON and `.import` stay in git | Same server as the previous project, this repo's own path; the registry must diff as text. |
| **Input map generated** from `tools/gen_project_godot.py` | Godot's `project.godot` input format is verbose and easy to typo; the table is the source. |
| **Knight by @Jump_Button** as the player placeholder | Full clip set, licensed for commercial use with credit; its no-AI clause means it is never a style reference. |
| **Start loadout is a debug loadout** (sword, slingshot, grapple, lantern, 2 dried fruit) | The design starts the player with nothing; the loadout exercises the systems until the Collapse is built. |

### What shipped this session

- `project.godot` (generated), `CLAUDE.md`, `.gitattributes`, `.gitignore`,
  `.lfsconfig`.
- Autoloads: `Data`, `Wiring`, `SpriteDb`, `Music`, `Sfx`, `Juice`,
  `SaveManager`, `GameState`, `RoomRegistry`; `game/game.gd` static
  accessors.
- Scene flow: `game/main.gd` (title → start menu → World; UI scenes
  loaded by path and tolerated when missing), `game/world.gd` (room
  loading at the world offset, seam/teleport transitions, fade, death,
  toasts, F2/F3/F4).
- Player: `game/player/player.gd` — analog walk/run, variable jump with
  coyote and buffer, crouch/crawl with ceiling check, drop-through
  one-ways, dash with air-dash, weapon attacks with startup/active/recovery
  from `data/weapons.json`, free aim, slingshot and grapple items, lantern
  toggle, swimming, hazard damage, pushing, interaction, hurt/i-frames/
  death, sprite fit via `SpriteDb`.
- Combat: `Hitbox`, `Hurtbox`, `Projectile` (player and enemy setups).
- Rooms: `Room`, `RoomExit`, `RoomEntry`, `RoomMarker`, `SkinLayer`,
  `GreyboxLayer`, `Backdrop`, `BreakableTile`, `RoomRegistryBuilder`;
  `tileset_kind.tres` and its generator; `addons/room_tools/` with *New
  Room…* and *Rebuild Room Registry*; `room_template.tscn`.
- Five test rooms under `game/rooms/test/` (entry hall, shaft, gallery,
  cistern, vault) drafted by a one-off script and now editor-owned;
  `data/rooms.json` built from them.
- Enemies (`game/enemies/`): `Enemy` base (strict JSON config, contact
  hitbox with re-arm, white-flash shader, tell pulse, coroutine attacks
  that only await the enemy's own `stepped` signal), `EnemyHurtbox`,
  `EnemyKit`, `Boss` (wake/aggro, weighted attacks, phase 2, `defeat_flag`,
  music swap); five brains — `hopper` (three slimes), `walker` (mushroom),
  `lasher` (bush lasher), `guardian` (Stone Guardian), `aberration`
  (Riftmaw) — with `SporeCloud`, `Shockwave`, `HomingOrb`; seven species
  scenes and `data/enemies/*.json`.
- UI (`game/ui/`): title screen, start menu with slots, HUD (hearts,
  item slots, weapon, minimap, room name), pause menu with ITEMS tab
  (select / use / drop / assign, `hide_use` honoured) and MAP tab (the
  minimap full-size, panned), options panel, shared theme. The pause menu
  polls input once per frame and resolves the shared pad buttons by
  context.
- Debug (`game/debug/`): the F1 tuning panel — every numeric leaf of
  `player`, `objects` and `weapons`, edited in place, unsaved.
- Data: `player`, `items`, `weapons`, `objects`, `skins` (six SSW skins,
  `jungle_ruins`, greybox; water tile in `cave_roots`/`jungle_ruins`),
  `backgrounds` (ten), `music` (eight tracks + silence + title), `sfx`,
  `sprites` (Knight, five Forest Monsters, two inherited bosses, six
  objects), `enemies/` (seven species).
- Assets: `SSW.tres` (six terrain sets + a flat water tile) and
  `SSW2_SET2.tres` (jungle ruins), SSW backdrops and props, Knight sheets,
  Forest Monsters, Abstraction music, the sound pack, inherited PixelLab
  placeholders; `assets/SOURCES.md` (the licensing rule, class index and
  open items).
- Tests: `test_boot.tscn` (data, registry, new game, player verbs, every
  room, save round-trip), `test_enemies.tscn` (every species spawns,
  ticks, takes a hit; hoppers and bosses attack; a defeated boss stays
  dead), `test_ui.tscn` (every screen instantiates headless; pause,
  tabs, verbs, options, F1 edit).
- Docs: `README.md`, `docs/room_authoring.md`,
  `docs/authoring/ai_art.md`, this log.
- Licensing: `assets/SOURCES.md` (rule, class index, open items), the
  per-class `SOURCES.md` in `character`, `enemies`, `tilesets`,
  `backdrops`, `props`, `music`, `sfx`, and `assets/ai_placeholder/README.md`.
- In progress by a parallel session at the time of writing:
  `game/objects/` (push block, floor button, lever, gate, locked door,
  pickup, save shrine, grapple anchor) and the `ai_provenance.json`
  back-fill.

### Findings: where code and design or docs disagree

Recorded rather than silently resolved, per the house rule.

1. **Dash is not item-gated.** Design §7.1/§10 gives dash to the Quality
   Boots; `player.gd` allows it from the start. Fine for the test loadout;
   needs a gate when items land.
2. **No double jump, no rope climbing, no breath meter, no scan.** All
   design verbs/systems; none started. `climbing_gear` is an item whose
   use shows a toast.
3. **Darkness is a `CanvasModulate` + a point light**, not the three-band
   visibility falloff of design §7.5. It is the right first step, not the
   design.
4. **A sword exists** (`items.json` says so itself: stand-in until the whip
   and axe are real). The design has no sword.
5. **Nothing emits `tier` 1**, so `fortified` cells are currently
   unbreakable. The design's source is the Power Fang passive; the code
   comment still says "a fast boulder today" from the previous project.
6. **Ramps draw as full blocks** in every skin (mapped to the `ground`
   terrain); only greybox shows the wedge. `water` and `hazard` have no
   skin art at all and always draw as greybox rects (test_boot excludes
   them on purpose).
7. **`Props` draws in front of the player** (template `z_index` 1), the
   opposite of the previous project. Documented as a per-prop choice;
   confirm it is intended.
8. **Seam arrival distance.** The exit rect sits over the departing room's
   border column and the nudge is 0.75 tile, so by the numbers the player
   lands a few pixels short of the neighbour's floor and may drop.
   Unverified — Godot was not available in the documentation session and
   `test_boot` never walks a seam. Needs a play test or a seam walk in the
   test.
9. **The vault ↔ cistern teleport pair is sealed.** `test_vault`'s down
   exit at local (2–3, 19) is under two rows of solid floor (rows 17–18),
   and `test_cistern`'s up exit at (36–37, 0) has solid rows 1–4 beneath
   it. Both validate (teleports only need the entry to exist) and neither
   can be reached. Drafting bug; fix in the editor.
10. **`RoomExit._room_names()` scans two folders**, the registry scans all
    of `game/rooms/`. A room in any other subfolder gets a false
    `to_room` warning on every exit that names it.
11. **Two registry writers, two `_comment` strings.** The editor menu item
    and the headless tool write `data/rooms.json` with slightly different
    `_comment` text, so which one you ran last shows up as a diff. The
    plugin's header also says it calls `RoomRegistry.build_from_scenes`;
    it calls `RoomRegistryBuilder`.
12. **Swimming out of a pool.** At the current numbers the body centre
    leaves the water about 10 px short of a floor at surface level and no
    jump is available, so a pool whose banks are plain floor is a trap.
    Tutorial rooms use ramps; the numbers may want retuning.
13. **Menu input overlaps**: `menu_drop` and `menu_slot_y` are both Y/L;
    `menu_use` and `menu_back` are both B. Resolved in code: the pause
    menu polls input once per frame and hands it down options → items →
    tabs → back, so B is "use" in the list and "back" elsewhere; Y is
    "drop" unless an assign is pending or `hold_to_assign` is on.
14. **`skin.tile_tint` is documented as required** in `SkinLayer`'s header
    but read with a `#ffffff` default.
15. **`Room.preview_skin` comment says "not saved"**; it is an `@export`
    and is saved when changed. Harmless.
16. **The F1 panel covers `player`, `objects` and `weapons`**, not
    `enemies`; CLAUDE.md says "any data number". Enemy numbers reload with
    F3 (`Enemy._on_data_reloaded`).
17. **`items_tab.gd` references `game/objects/pickup.tscn`** (for drop)
    before that scene exists; harmless until objects land, then it must
    match the pickup's API.
18. **`assets/SOURCES.md` names `tests/test_skins.tscn`**, which does not
    exist yet (intended). `assets/ai_placeholder/README.md` landed late in
    the session with a provenance record sketch; `docs/authoring/ai_art.md`
    §3 is the full schema and adds the README's `origin` key for copied
    sheets. The two agree on the required keys.

### Open items

**Licensing and provenance** (the live list is `assets/SOURCES.md`)
- Forest Monsters pack: no license text on disk. Record author, terms,
  receipt before anything using it ships.
- "400 Sounds Pack" (all 50 files in `assets/sfx/`): no license file.
- Store URLs and purchase dates for the Szadi packs and the Knight.
- `assets/ai_placeholder/*/ai_provenance.json` do not exist yet; the
  inherited sheets' records are in the previous repo and are being
  back-filled to the schema in `docs/authoring/ai_art.md` §3 (the folder's
  `README.md` landed; it should link that doc). Delete the empty
  `ai_placeholder/sprites/`; fold `stations/` into `objects/`.
- `_source` missing on nine `sprites.json` entries.
- `tests/test_assets.tscn` (the boundary guard), `tests/test_skins.tscn`
  and `tests/run_all.sh` are referenced by CLAUDE.md / `assets/SOURCES.md`
  and not written.
- A credits screen: the Knight requires credit; Abstraction asks for it.

**Art**
- The Castle pack is in `assets/tilesets/` with no terrain set and no skin.
- Hazard art (no copied pack has spikes); water tiles for the skins that
  lack one; ramp slope art (or `{"atlas": …}` mappings per ramp kind).
- A real sprite for the archaeology student, replacing the Knight.

**Systems (design §16, roughly by risk)**
- Glyph composer and the localisation pipeline (§14) — the most novel
  system and a core pillar; nothing exists. Prototype first.
- Rope system (§8): anchors, shafts, placed ropes, the reachability graph,
  remote re-anchoring from the notebook. `climbing_gear` is a toast.
- Radio and notebook UI (§7.3, §7.4): dialogue with the world paused,
  map, glyph glossary, lore log, rope manager, pins.
- Fang system (§9): passives, the hidden close-menu-then-bow activation,
  cooldowns on game time, `hide_use` in the item menu.
- Double jump, rope climbing, breath, scan mode, the three-band darkness.
- Room objects (`game/objects/`, in progress) — the first puzzle verbs.
- `tests/run_all.sh`; the F1 panel reaching `enemies`.
- Seam arrival nudge (finding 8) and the sealed vault/cistern teleports
  (finding 9).

### Addendum, same day — objects, seams, the screenshot tool

Written after the four parallel work streams (enemies, UI, assets, docs)
merged and the remaining pieces landed.

- **`game/objects/` shipped**: `PushBlock`, `FloorButton`, `Lever`,
  `Gate`, `LockedDoor`, `Pickup`, `SaveShrine`, `GrappleAnchor`, plus the
  two forwarders (`SwitchArea`, `InteractForwarder`, `GrappleTarget`) that
  give a plain Area2D the `take_hit` / `interact` / `grapple_hit` entry
  point the player looks for. All `@tool`, all gizmo-drawn, all reading
  numbers from `data/objects.json` through `Game.*`. The `material`
  export had to become `block_material` — `CanvasItem.material` already
  exists, and the parse error only showed up headless.
- **The five test rooms were re-drafted** (the one-off script stayed in
  the scratchpad) to place every object and enemy at least once, and to
  fix finding 9: the vault's teleport is now a pit erased through the
  floor, the cistern's a real staircase under the ceiling hole, and the
  `from_vault` entry sits on the one-way ledge instead of in mid-air.
  Nobody had opened them in the editor, so re-drafting was still legal;
  from here on they are editor-owned.
- **Finding 8 was real.** A seam arrival placed the player's centre
  2 px short of the neighbour's painted rect. `World.load_room()` now
  clamps a seam arrival at least half a tile inside the new room's rect
  along the travel axis, and `tests/test_objects.tscn` walks the
  hall → shaft seam and the vault → cistern teleport for real.
- **Grapple pull bug**: `move_and_slide()` reports the floor you are
  standing on as a collision, which ended every pull on frame one. The
  pull now ends only on a collision whose normal opposes the pull.
- `Hitbox.pulse()` counts frames in its own physics step (no timer on a
  possibly-freed owner); `Hitbox.source_node` replaces the misuse of
  `owner`; the player resolves a hit Hurtbox to its owner before asking
  `is_enemy()`; `RoomExit.to_room` suggestions scan every subfolder;
  Music/Sfx stop their players on exit (no more leaked-stream warnings);
  `World` is `PROCESS_MODE_PAUSABLE` so the pause menu stops it; debug
  keys are polled so scripted sequences can press them.
- **`tools/screenshot_rooms.tscn`** renders every room to
  `user://screenshots/` with a real renderer. On a machine without a
  display: `xvfb-run -a godot --path . --rendering-driver opengl3
  --rendering-method gl_compatibility res://tools/screenshot_rooms.tscn`.
  That is how the skins, backdrops and object placement were checked
  this session (llvmpipe renders the game fine). The `stone_hall` and
  `castle` backdrops are outdoor mountain views — fine for a surface
  room, wrong for a gallery; the test gallery uses `mine`.
- `tests/run_all.sh` exists (import → registry → every `tests/test_*.tscn`,
  with the LFS-pointer gate from the previous project). Suite at the end
  of the session: test_assets, test_boot, test_enemies, test_objects,
  test_skins, test_ui — all green, no engine script errors.

Open items from the list above that this addendum closes: objects,
`run_all.sh` and the two asset tests (`test_assets`, `test_skins`),
findings 8 and 9, and the `ai_provenance.json` back-fill (one per
`ai_placeholder/<class>/`, schema per `docs/authoring/ai_art.md` §3; the
empty `sprites/` folder was never committed). Still open: everything
else listed — above all the Forest Monsters and 400 Sounds Pack
licenses, which block any public build.

## 2026-10-13 — First playtest fixes

Eir played the build and reported: the jump was ~2.5 tiles; the push
clip flickered against a block every frame; walking through a seam and
turning straight around dropped the player off the world; a claw-grip
player wants the sticks NOT swapped while aiming; the pad layout should
be remappable (theirs: B jump, Y attack, A and X items); and two engine
errors — `gate.gd:60 Can't change this state while flushing queries` and
a one-time `shader_rd _load_from_cache header` mismatch.

### What changed

- **Jump height is a tile count.** `data/player.json` `jump_velocity`
  became `jump_height_tiles` (4.0); `Player.jump_velocity()` derives the
  take-off speed from it and `gravity`, with half a physics tick of
  compensation for the semi-implicit integrator. Gravity now applies on
  the jump frame too (it used to be skipped, which added a free frame of
  travel and made the derivation lie by a third of a tile).
  `tests/test_boot.gd` measures a held jump (4.08 tiles) and a tapped one.
- **Push detection** is a 2 px `test_move` toward the stick instead of
  reading the last `move_and_slide` collisions — the block moves too, so
  contact was reported on alternating frames. The clip is also held
  `PUSH_HOLD` (0.1 s) after the last contact. `test_objects` counts clip
  changes over 80 frames of pushing: 0.
- **Seams** (docs/room_authoring.md §4.2, rewritten): the root cause was
  a time lock (0.6 s) on arrival plus `body_entered`-only triggering. The
  arriving body sat inside the far room's own exit trigger; the one
  `body_entered` was swallowed by the lock; walking back out never
  re-entered anything and crossed into the unloaded neighbour. Now:
  `RoomExit` polls overlapping bodies every physics frame and a seam
  trigger reaches `OUTSIDE_TILES` (2) past the edge; `Room` builds a
  `SeamAprons` StaticBody2D that copies the edge column/row of the kind
  layer `APRON_TILES` (3) outward across the exit's span (± 2), one-way
  ledges as one-way; `World.load_room` places a seam arrival just clear
  of the matching exit that leads back (`_clear_of_arrival_exit`) and
  locks exits only for the fade. The registry validator warns when a
  `RoomEntry` stands inside an exit footprint. `test_objects` now walks
  hall → shaft, turns straight around (18 ticks to be back in the hall,
  never below the floor), waits, and crosses again.
- **`aim_swap_sticks` setting** (default on = design behaviour): off,
  the left stick keeps moving and the right stick aims while aim is
  held. `Player._aim_from_pad()` now asks `Controls.pad_pressed("aim")`
  instead of reading the raw LT axis, so a remapped aim button still
  counts as pad aim. Aim direction resets to facing on each aim press.
- **Button remapping.** New autoload `Controls` (game/autoload/controls.gd)
  captures the project.godot defaults at boot and owns the InputMap:
  `SaveManager.settings.bindings` overrides any of 13 actions (the
  gameplay verbs, pause, map, Menu: accept, Menu: back) per device; the
  menu actions that are the same physical control as a gameplay one
  (`menu_use` ← attack, `menu_slot_x/y` and `menu_drop` ← items,
  `menu_assign`/`menu_tab_prev` ← interact, `menu_tab_next` ← dash) and
  Godot's `ui_accept`/`ui_cancel` (← Menu accept/back) are rebuilt as
  mirrors. Options → Controls… (`UiControlsPanel`) lists Pad and
  Keyboard per action, captures the next press, marks two gameplay verbs
  (or accept/back) on one pad button with "!" and explains on focus,
  resets to defaults. Every UI string that named a button (HUD slots,
  item marks, verb hints, assign prompt, menu hints, tab hint) now reads
  `Controls.glyph` / `Controls.hint`, pad glyphs while a joypad is
  connected and keyboard ones otherwise. `menu_accept` lost its stray
  default `J` (it made the keyboard attack key select instead of use).
  `test_ui` applies Eir's layout, checks the InputMap, the mirrors, the
  glyphs, a captured keyboard rebind, persistence across a settings
  reload, and reset.
- **Gate shape toggling is deferred** (`_shape.set_deferred("disabled")`):
  it runs inside the button's `body_entered` → `Wiring.drive` →
  `channel_changed` chain, i.e. during the physics flush. The locked door
  already did this. `tests/run_all.sh` now fails on engine `ERROR:` lines
  (the exit-time "resources still in use", from `UiTheme`'s static Theme,
  is tolerated).
- **Shader cache message**: `.godot/` was never shipped; the cache that
  mismatched was written by a different Godot build on Eir's machine and
  is rebuilt once. Nothing to do; delete `.godot/shader_cache/` if it
  repeats every launch.
- New tools: `tools/dump_rooms.tscn` (every room as ASCII with exits,
  entries, objects, enemies and a column ruler — how this session read
  the geometry headlessly) and `tools/screenshot_ui.tscn` (title, start
  menu, options, controls, HUD, pause tabs under Xvfb).
- **Puzzle state persists per room, in the save.** Before this, re-entering
  the entry hall put the block back home and the plate came up. The
  lever's `flag` also forced it back ON even if it had been switched off.
  Together that meant both gates were down after any return. Now
  `GameState.room_objects` (room → node path → value, in `to_dict`)
  holds push-block positions, lever on/off and latched buttons, through
  `Room.store_state()`/`saved_state()`. Momentary plates save nothing and
  re-read their weight. The lever's flag now only records "has been
  pulled once". `Wiring.reset()` opens a `SETTLE_FRAMES` window in which
  gates snap and buttons stay quiet, so a restored room arrives already
  in position. Blocks persist only while parked on a key spot (any
  floor button, group `key_spot`); left anywhere else they reset on
  re-entry, per Eir (the Ocarina of Time rule).
  `tests/test_room_state.tscn` covers leave/return both ways plus a JSON
  save round trip.
- **Gates are solid raised and mid-slide.** The slab is now an
  AnimatableBody2D that moves (in `_physics_process`), not a StaticBody
  whose shape was switched off while open. A raised gate is a solid
  block hanging `h` tiles up that carries anyone standing on it.
- **Crushing is a general physics rule (design §7.6, Eir's rule).**
  `game/combat/crush.gd`: after the player or an enemy moves, if it is
  still overlapping solid geometry by more than 2 px, a moving solid has
  squeezed it somewhere it can't get out of. Overlap is tested with the
  real collision shapes shrunk by 2 px. The first cut used bounding rects,
  and walking (not running) off a raised gate cost hp: the capsule's
  rounded bottom rolling over the corner put the rect's corner about
  2.3 px into the slab, on whichever frame happened to land there. A
  landing spot must clear the full-size shapes, because a body landed
  even slightly inside something is depenetrated during the crush hit's
  hitstop (time_scale 0) and ends up with a NaN position.
  One-way ledges (Eir: "the only way down through a one-way platform is
  to intentionally drop through"): the engine ignores a one-way shape a
  body is inside, so a crusher pressing someone 1–2 px into one dropped
  them through, depending on frame timing. Player and Enemy now keep
  `_crush_ledge` (`Crush.ledge_under`). It's held while still over the
  ledge and not above it, because pressure from above clears is_on_floor
  a frame before the body sinks. While it's held, the ledge's lips are
  solid to the crush check and the escape search, and a body pushed
  below the ledge is put back on top and crushed sideways. The player's
  down + jump drop clears it.
- **Drop-through fixed, and moved to down + jump (Eir).** The old drop
  (crouch + jump on a one-way ledge) nudged the player 2 px down, inside
  the tiles' 4 px one-way margin, so the engine pushed them straight back
  up and it never worked. It's now `DROP_THROUGH_NUDGE` = 5 px, triggered
  by jump while the move input points mostly down, at least
  `player.drop_through_down` (0.4, placeholder; below the walk
  modifier's 0.45 cap). **Crouch + jump is now a crouch jump** (Eir): same
  height, and the crouched collider is kept in the air while crouch is
  held. Crouch now persists airborne once started, and still only starts
  on the floor. **Keyboard crouch moved from S/Down to C** (placeholder
  key, remappable), because S/Down are `move_down` and the two inputs had
  to be told apart. On pad it stays RT. `test_crush` covers the drop and the ledge
  squeeze at 9 positions under the shelf gate (verified to fail with the
  ledge memory disabled). Solids are the room's
  Collision kinds (solid, fortified, breakable; not one-way or ramps) plus
  any other body on its mask, minus one-way shapes. It is displaced to the
  nearest free spot within `objects.crush.max_displace` (searched
  sideways with small lifts, then up/down with small sideways nudges,
  never ACROSS a solid: the path may touch only solids the body is already
  in, and must not go from wholly one side of them to wholly the other.
  The first version exempted already-overlapped solids outright, which
  let a player pressed 3 px into the room's wall be displaced through it
  and out of the room) and takes on_hit(`crush.damage`, `crush.knockback`).
  With no spot the player is hit and voids out, and an enemy dies (this
  includes bosses). `World.void_out()` fades, reloads the room and puts
  the player at `_arrival`, the spot `load_room` recorded on entry (an
  entry or a seam). The gate has no crush code of its own.
  `tests/test_crush.tscn` covers a gate on the player (escape / void), a
  gate on a slime (escape / death), and a bare moving body pinning the
  player to a wall. Numbers (1 damage, [220, -120], 64 px) are
  placeholders. Side effects: a character teleported INTO a wall (a test
  spawning at a fixed offset) now gets displaced and hit instead of
  quietly depenetrated. And anything that moves a solid outside `speed *
  delta` during hitstop (time_scale 0) gives anything riding it a NaN
  position; every current mover is delta-scaled. Not reproduced: Eir's "both columns up
  with no collision on first load". Headless, a fresh hall has the exit
  gate closed and blocking (player stops at its face) and only the
  inverted shelf gate raised, which is intended.

### Still open

Everything in the bootstrap list above, plus: `move_*`/`rs_*` (sticks,
d-pad, WASD) are not remappable yet; the Controls panel has no
per-action "clear" (bind something else or reset all); with aim-swap off,
running while aiming is still allowed (Eir may want it off later).
Broken walls
still don't persist.

## 2026-10-14 — Aim reticle

Asked for by Eir: a reticle on free aim, out at the weapon's range,
pulled in to whatever the shot would hit, red when the hook can latch.

- **`AimReticle`** (`game/player/aim_reticle.gd`), placed by
  `Player._update_reticle()` after the body moves each physics frame,
  only while aim is held. One reticle, for **the last aimable thing used**
  (slingshot, grapple, or an `aimable` weapon); until one is used, or if
  the last one is unequipped, slot X, then slot Y, then the weapon (Eir's
  choice). Nothing aimable equipped → no reticle.
- **Each trace runs the real shot's query.** Grapple: `_grapple_ray()`,
  now shared with `_fire_grapple`. Slingshot: the stone's own per-tick
  integration through `Projectile.sweep()` until its lifetime ends, so
  the reticle follows the arc (gravity 300 drops a level shot ~250 px
  over its life) and in open air can sit off-screen at the end of the
  arc. Aimable melee: the far edge of the hitbox, or the first
  hurtbox/switch/breakable on the swing line, through walls, because the
  hitbox ignores walls.
- **Red = the hook catches it**: anchors and iron/wood blocks (Eir's
  choice). Targets answer a new side-effect-free `grapple_mode(player)`
  (`GrappleAnchor`, `PushBlock`, `GrappleTarget`); `grapple_hit` goes
  through it.
- **Bug fixed on the way: projectiles went through walls.** Godot merges
  TileMapLayer collision into hollow outlines per physics quadrant. A
  stone (6 px across, ~9 px per tick) hops the outline and is never
  inside anything that reports an overlap, so `body_entered` never fired
  and stones flew out of the room. The same was true for every enemy
  `Projectile` (guardian rocks, orbs, shockwaves). Walls are now found by
  `Projectile.sweep()`, a ray per step reaching `radius` ahead. Hurtboxes
  and switches still go through the Area's overlap.
- **Placeholder rule: projectiles follow the player's one-way rule.** A
  ledge stops a projectile coming down onto its top and lets anything
  else through, so stones can be shot up through a ledge. Never decided
  in the design; a raw ray would stop at the underside instead.
- Placeholders: reticle look (10 px ring + ticks, centre dot when it sits
  on a hit, red `#ff3326` for latch), and its colours are constants in
  the script, not data, like the aim line's.
- `Room.collides_at()` added (the cell has a physics shape) so the sweep
  doesn't keep its own list of solid kinds.
- `tests/test_reticle.tscn`: the reticle matches where real stones stop
  (5 angles, through and onto a one-way ledge) to within 1.5 px; red on
  the anchor and the iron block, not on the floor or a stone block;
  previewing doesn't fire the hook or pull the block; range in open air;
  last-used switching; hidden when not aiming.

## 2026-10-14 — Script of Rhys: glyph composer

Asked for by Eir, now that every character (Th and Dh included) is
drawn in `script.xcf`: a tool that writes arbitrary text in the script,
for baking textures and for writing on walls. Eir chose phonetic input,
a Godot composer with a bake CLI and a room node, and cleaned-up glyph
shapes. How to use it: `docs/authoring/script.md`.

- **`data/script.json`**: the 24 consonants, 7 vowels, the null glyph
  and the underscore, as stroke polylines on a 12-unit grid, transcribed
  from `script.xcf` and cleaned up (snapped, mirror pairs symmetric,
  base strokes and stems aligned). Also the spacing and the render
  defaults. Redesigning a glyph is an edit here (§11.9 process step 1).
  Every key is required, and a stroke point outside its glyph's box is a
  load error.
- **`RhysScript`** (`game/script/rhys_script.gd`, a plain class, so the
  `-s` tools and `@tool` nodes can use it). `compose(text)` reads the
  sounds into slots: consonants and vowels alternate, two consonants
  stack, a vowel-initial word gets the null consonant, and the §11.4
  word-break table goes between words. The design doc's chain notation
  is valid input and reads back unchanged. `render(text, opts)` draws
  Bresenham pixel strokes (ink on transparent, any stroke width) right
  to left; `ttb` turns the image 90° counterclockwise. `render_chart()`
  draws every glyph at full and half height.
- **`ScriptText`** (`game/script/script_text.gd`): a `@tool` `Sprite2D`
  for rooms. You type into the inspector and it redraws live; it shows
  the chain read-only and lists refusals and guesses as scene-tree
  warnings. The texture is generated and never saved into the `.tscn`.
  F3 and an inspector button reload the glyph data.
- **`tools/bake_script.gd`**: headless PNG baker with single, batch,
  `--chart` and `--chain` modes. It writes to `user://script/` unless
  given `--out`.
- **`tests/test_script.tscn`**: every chain example in design §11, each
  §11.4 row, refusals (c/q/x, punctuation, bad brackets), the two
  guesses, every glyph drawing inside its slot at 25 and 13 px, ttb as
  the rotation of rtl, and the node. 52 checks, green on Godot 4.7.
- **Found:** a static `reload()` on a `class_name` script calls
  `Script.reload()` instead (it returned OK = 0 = false and reset the
  statics). The method is `reload_data()`.
- **Found (§11.9 rule 4):** at 25 px, half-height Ch/Kh, Th/Dh, Sh/J and
  M lose their inner strokes. At 13 px only S/Z, T/D, K/G and H/W
  survive at half height. Stacked clusters need ~37 px or simpler
  half-size shapes. Run `--chart` to see it.
- **Doc vs file:** `script.xcf` labels the Th pair "Dth" while
  design_v2 §11.2 says "Dh". The tool prints Dh and accepts both `dh`
  and `dth`. design_v2 §11.2/§11.6 still call Th/Dh "to draw". Not
  edited; it's Eir's document.
- **Placeholders** (all listed in docs/authoring/script.md §6): the
  cleaned glyph geometry itself; spacing (slot gap 3, cluster gap 1,
  line gap 6 units, underscore 6 wide); stacks centred; a third
  consonant gets a null vowel after the first stack; two vowels get a
  null consonant; single consonant → stack uses the top half-slot; no
  wrapping, and ttb lines become left-to-right columns; 25 px / 1 px /
  black defaults.

### Still open

Grapheme-to-phoneme and the per-language pipeline (§14.2 steps 1–4);
the decorative register and sigil sets; punctuation and wrapping (§11.4,
§17); the automated collision checker and the LLM decipherment harness
(§11.9 steps 2–3), which can build on `RhysScript.render_lines` and
`render_chart`.

### Follow-up, 2026-10-15 — Eir's review

- **Slingshot reticle shows the aim, not the landing.** It's now a straight
  line along the aim with no gravity, out to `speed × lifetime` (702 px)
  or the first thing in the way. The real stone drops below it, which is
  intended. This replaces the arc trace above.
- **Solid objects stop stones.** `Projectile.solid_mask` decides what a
  shot stops at. The slingshot's is `SLINGSHOT_SOLIDS` (world +
  pushable), so crates stop stones; enemy shots stay world-only. `sweep()`
  also catches a body sitting right on top of a ledge the shot came up
  through.
- **Bug (old): the slingshot only worked in rooms at world (0, 0).**
  `_fire_slingshot` set the stone's `global_position` before adding it to
  the room. Outside the tree that's just `position`, so the stone appeared
  at the room's world offset, thousands of px away. Now it's added first,
  like `EnemyBody.spawn_in_room` does. `test_reticle` fires in the
  cistern to cover it.

## 2026-10-15 — Jumping out of water

Bug (old): the player couldn't get out of a pool. Holding jump swims up
at `swim_up_velocity` (190 px/s, clamped to 1.5 × `swim_terminal`). Once
the water sample point (0.45 × body height above the feet) clears the
surface, full gravity takes over, and that speed buys about 9 px. The feet
topped out 10 px below the surface, so even a bank level with the water
was out of reach. Now, on the frame the sample point surfaces, with jump
held and moving up, the player leaps. Take-off speed is computed from the
real surface (the bottom of the cell the sample point just entered) so the
feet clear it by `player.swim_exit_jump_tiles` (2.0, Eir's number). The
leap is an ordinary jump from there: releasing jump cuts it. No jump held
→ no leap. `tests/test_swim.tscn` checks the 2-tile height (exactly
64 px), no leap without jump, and climbing out onto the hall's bank; it
fails both movement checks with the fix removed.

## 2026-10-15 — Script: vowel → consonant word break

Eir's decision after seeing the Hamlet sample: when a word ends in a
vowel and the next starts with a single consonant, the consonant takes
the bottom half of its slot and the top half stays empty. So *to be* is
T·u·[∅/B]·i, not T·u·'·_·B·i. Changed in `RhysScript._join`, with tests
for both the new form and the stack case. A stack has no free half, so
vowel → stack keeps V·'·_·[C/C] (a placeholder, in
docs/authoring/script.md §6). design_v2 §11.4's table row still shows
the old V·'·_·C and needs Eir's edit.

Then, same day: **the null vowel is dropped at either end of a word**
(Eir). *Is* ('·|·Z) is Z and *the* (Dh·|) is Dh, so *that is the
question* is [∅/Dh]·a·[T/∅]·[Z/∅]·[Dh/∅]·[K/W]·e·[S/Ch]·|·N. A leading
null vowel takes its null consonant with it, and null vowels inside a
word stay. Placeholders: a word that is only the null vowel (*a*) keeps
'·| rather than vanishing. The pillar syllable *Rhys'* ([R/H]·|·S·| in
§11.6) now prints without its final null vowel, which is open for Eir.
Also fixed: a null glyph in a half-slot printed as `[null/∅]` in chains.
Tests: 61 checks.

Eir confirmed both: *a* stays '·| (decided, no longer a placeholder),
and the pillar syllable *Rhys'* is [R/H]·|·S. §11.6 said
[R/H]·|·S·|, which Eir called wrong. design_v2 is updated to match the
composer: §11.3 has the end-of-word rule and the *a* exception, §11.4
has the vowel → single consonant row (vowel → cluster kept as
*(assumed)*), and §11.6 has the pillar chain. Tests: 62 checks.

**First machine read (Eir, 2026-10-15).** Eir gave GPT Astra sample bakes
(the soliloquy, *safe / place / safe place*, the Lovecraft couplet, *jump
and shout*). It translated the couplet and *jump and shout*. It stalled on
the half-slot word start: the small Sh in [∅/Sh]·au·T read as a different
letter until it saw the empty top half as the space. At Eir's request,
design_v2 §11.8 now requires two explicit clues (word forms change at
word breaks; the script is a transliteration, not a cipher), with a
Proposal block of ways to give them. docs/authoring/script.md §7 repeats
both for whoever places inscriptions.

## 2026-10-15 — Play one room (DebugBoot)

**Asked for (Eir):** run any room straight from the editor, with the
player and every item.

**What landed.** `game/debug_boot.gd` holds a one-shot room request; Main
takes it in `_ready` and skips the menus: new game, `grant_all_items()`
(every `items.json` id at its full `stack`), respawn set to the room,
`world.load_room`. There are two ways in. A `Room` that is the
`current_scene` at runtime (F6, Run Current Scene) requests itself and
swaps to `main.tscn`. The scene change is deferred, because the root is
still busy adding the room at boot. The shell form is
`godot --path . -- --room <name> [--entry <id>]`. The new editor-only
export `Room.test_entry` picks the entry for F6; it suggests the room's
entry ids, and empty means the first. Test: `tests/test_room_boot.tscn`.

**Placeholders chosen without a brief.** "All items" means full stacks
(99 small keys, 9 dried fruit, 3 climbing gear). The equipped weapon and
slots come from `add_item`'s first-come rule: sword, slingshot on X,
grapple on Y. No save slot is picked, so a shrine saves to slot 1.

**The article *a* is the null consonant (Eir, 2026-10-15).** It replaces
the '·| decision above. *A* is written as one vertical stroke, a
one-glyph word like *is* = Z, and takes the §11.4 breaks like any single
consonant: *fingers a great* is …[R/Z]·[∅/']·[G/R]…, *was a ghastly*
is …[Z/∅]·['/∅]·G…. A word that opens with the null consonant counts as
vowel-initial only if more follows (`_starts_with_vowel`), so *a* is
never swallowed by the V·_·V rule. design_v2 §11.3 and script.md are
updated. Tests: 65 checks. Noticed while doing this: the clue section
added to design_v2 §11.8 and script.md §7 earlier today is no longer in
either file on disk. Not restored; asked Eir.

## 2026-10-17 — Down-dash, Quality Boots, whip swing, explosive, darts, fire

**Asked for (Eir):**
- In the air, down + dash dashes straight down.
- The dash needs the Quality Boots, and test loads get them.
- The whip got shorter. It latches onto its own targets (thin things like beams, with a flag separate from the grappling hook's) and swings the player, with no climbing.
- A remote explosive: first use sets it at the feet, second detonates it. Small blast that also hurts the player. Ammo 10, with upgrades.
- Wooden darts: faster than the slingshot, no drop, catch fire through a flame and set what they hit alight. Ammo 20, with upgrades.
- Test loads have full ammo.
- Follow-up answers from Eir:
  - Fire is a torch, an ignite path, a burnable barrier, and enemies that burn.
  - Jump lets go of a swing.
  - The blast hits enemies, breakable walls, switches and levers.
  - Whip targets are a room object.

**What landed.**
- **Down-dash.** Same time, cooldown, i-frames and once-per-airtime as the side dash, at `player.down_dash_speed` (520).
  - A separate fast-fall state was tried and dropped: with its terminal speed equal to the normal one, gravity reaches 640 four ticks after the dash anyway.
- **Quality Boots.** A passive item with `dash: true` and `replaces: ratty_boots`; owning it removes the Ratty Boots. `Player.can_dash()` gates the dash.
- **Ammo** (`GameState`).
  - `ammo: true` items stay owned at ×0, so they keep their slot.
  - `capacity(id)` = `stack` + each owned `ammo_for` upgrade's count × `ammo_bonus`. Picking up an upgrade fills the ammo it raises.
  - `grant_all_items()` adds ammo last, so the test loadout is every upgrade plus full ammo (20 charges, 40 darts).
  - The HUD and items tab always show ammo counts.
- **Explosive Charge** (`game/combat/explosive.gd`). A body that drops to the floor. The blast is a one-shot tier-0 Hitbox on enemy hurtboxes, switches and breakable walls (`objects.explosive.damage`). The player takes `player_damage` if their body centre is inside `radius`. One charge out at a time.
- **Darts.** `Projectile.setup_dart`: no gravity, stops at the first thing it hits (`pierce = false`), and catches fire when its step crosses the new `fire` layer.
  - A burning dart's hit info carries `fire: true`.
  - Projectiles now also call `take_hit` on a **solid** they stop at, if it has the method, because a stone or dart stops at a body before its Area can overlap anything behind it.
  - The reticle previews darts.
- **Fire.**
  - `Torch`: lit = a flame on the `fire` layer; unlit = a `switch`-layer target that a burning hit lights, saved per room.
  - `BurnableBarrier`: solid; burns for `objects.fire.barrier_burn_time`, a flame the whole time, then gone for good via a flag.
  - `Enemy.ignite()`: burns for `enemy_burn_time`, losing `enemy_burn_damage` every `enemy_burn_tick`, with no stagger.
- **Whip.**
  - `reach` 46 → 40, `hitbox` 76×14 → 64×14.
  - `WhipPoint` is on the new `whip` layer (15). The grapple's raycast doesn't include that layer, and grapple anchors aren't on it.
  - The latch target is picked when the attack is pressed (the reticle shows it in red) and taken on the first active frame. A fresh ray then would miss a thin beam after the ~20 px fall during startup.
  - `State.SWING` is a fixed-length rope pendulum under plain gravity. Left/right pumps it (`weapons.whip.swing_pump`). Jump lets go, rising at least `swing_release_hop`.
- **Physics layers 15 `whip` and 16 `fire`** were added to `project.godot` and `tools/gen_project_godot.py`.
- **Tests.** `tests/test_items.tscn` has 44 checks. `test_room_boot` now expects capacity and replaced items.

**Placeholders chosen without a brief.**
- Numbers:
  - `down_dash_speed` 520.
  - Explosive: radius 40 px, 3 damage to enemies, 1 to the player.
  - Darts: speed 820, lifetime 0.9 s, 1 damage.
  - Burn: 3 s, 1 HP every 1 s. Barrier burn time 1.2 s.
  - `swing_pump` 420; `swing_release_hop` −260.
- Quality Boots keep the Ratty Boots' 1.15 speed and `hazard_protect`. "Better protection" means nothing yet: hazard damage is 1, and one protection already cancels it.
- Upgrades:
  - Charge Satchel +5 and Dart Quiver +10, two of each.
  - Picking one up fills that ammo.
  - Names and descriptions are placeholders.
- Behaviour:
  - The charge falls to the floor if set in mid-air.
  - Attacking or dashing doesn't detonate it.
  - Leaving the room loses it, and its ammo is spent.
- Art is drawn in code with no manifest sprite: the charge, the dart shaft and flame, the torch, the barrier and its flames, the whip beam and line, and the enemy flame particles.
  - The down-dash plays `fall`.
  - Sounds reuse existing streams: `explosive_set`, `explosive_blast`, `dart`, `ignite`, `whip_latch`.
- A torch is a wall sconce with its position at the flame. It doesn't drive a wiring channel.

**Found.**
- Slingshot stones pass through enemies and stop only at walls. Unchanged.
- `tools/gen_project_godot.py` has drifted: running it drops the godot-ai/terminal plugins and `_mcp_game_helper` from `project.godot`. Not fixed; noted in CLAUDE.md.
- The burnt-barrier flag is named after the node, like the locked door's, so renaming a barrier brings it back.

**Follow-up, same day (Eir).**
- Slingshot stones now stop at the first thing they hit, as darts do (`pierce = false` in `setup_slingshot`). A test checks that the enemy behind the first one is untouched.
- Enemy shots still pass through what they hit (`pierce` defaults to true). Unchanged; not asked.
- `tools/gen_project_godot.py` is fixed. It now writes the godot-ai/room_tools/terminal plugin list and the `_mcp_game_helper` autoload, and regenerating reproduces `project.godot` exactly. The CLAUDE.md drift note is removed.

**Follow-up: whip length back, latch aim assist (Eir).**
- The whip is back to `reach` 46 and hitbox 76×14.
- The whip and the grappling hook now auto-target latch points within 5° of the aim (`weapons.whip.latch_assist_deg`, `objects.grapple.assist_deg`). It covers points in reach with nothing in the way, and picks the closest in angle.
- Only dedicated latch points count: the groups `whip_points` and `grapple_anchors`. The hook's assist never picks a pullable block or a switch.
- An exact hit wins, so a shot that already latches or pulls something isn't redirected.
- The reticle shows the assisted target.
- Tests cover a whip point at 4.5° (taken) and 9° (not), and an anchor at 4° (taken, and latching for real while falling) and 9° (not). A pullable block is ignored even with the assist widened to 10°.

**Follow-up: the hook activates switches (Eir).**
- The hook's ray now includes the `switch` layer. A `SwitchArea` with `hook_switch` (levers, latching buttons) gets an ordinary `take_hit` (`kind` `"grapple"`, 0 damage), and the player isn't pulled.
- The unlit torch and the burnable barrier set `hook_switch = false`. To the hook they're just obstacles, so the reticle doesn't go red at them. Momentary buttons aren't on the switch layer at all.
- A shot already aimed at a switch is never redirected by the anchor assist.
- The reticle goes red at a switch.
- Tests: the hook flips a lever, presses a latching button, keeps a lever shot when an anchor is 3° off, and doesn't treat an unlit torch as a switch.
