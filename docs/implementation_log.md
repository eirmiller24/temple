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
`run_all.sh`, findings 8 and 9. Still open: everything else listed.
