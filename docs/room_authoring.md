# Room authoring

The complete contract for building a room in The Temple of Rhys. Rooms are
**authored by hand in the Godot editor**, and the scene you author **is the
scene the game runs**. There is no exporter and no generated `.tscn`;
this document is the reference for what the room nodes expect, what the
registry validator checks, and how the look is layered on top.

> **Building your first room? Start at [§9](#9-tutorial-a-sixth-test-room-end-to-end).**
> It walks one room from *New Room…* to a green registry build, in order,
> and points back here for the details. §1–§8 are the reference: they
> define the contract, but they don't tell you what to do first.

**The one rule:** *playable truth is the `Collision` layer; everything else
is paint.* Nothing outside `Collision` — and the scene instances under
`Objects` — can change what the player collides with.

---

## 1. The pipeline

```
game/rooms/<folder>/<name>.tscn  ──►  RoomRegistryBuilder  ──►  data/rooms.json  ──►  map, door wiring, debug jumps
     [the room, and the runtime scene]       [one-way]            [build artifact]
```

That's the whole thing. The `.tscn` is the room; `data/rooms.json` is a
build artifact derived from it. There is no second representation of the
geometry anywhere — the kind layer you paint carries its own physics
shapes (§3), so what you paint is literally what the player collides with.

**Workflow for any change:**

1. Edit the scene in the Godot editor.
2. Rebuild the registry: *Project → Tools → Rebuild Room Registry* in the
   editor, or headless
   `godot --headless --path . -s res://tools/build_room_registry.gd`.
3. Commit the `.tscn` **and** the regenerated `data/rooms.json`.

**Starting a new room:** *Project → Tools → New Room…* (the `Room Tools`
plugin, `addons/room_tools/`). It copies
`addons/room_tools/room_template.tscn`, names the root after the scene,
writes the `world_x`/`world_y` you typed in the dialog, saves it under
`game/rooms/<folder>/` and opens it — so the `Collision` layer, the
decor layers, the `Entries`/`Exits`/`Objects`/`Enemies` containers and
one entry are already there and already typed.

The template is a **copy**, not an inherited scene. Inheritance would keep
every room linked to the template, so one tweak there would silently change
all of them. Rooms are independent by design. The template also lives
*outside* `game/rooms/` on purpose: the registry treats every `.tscn` under
that folder as a room, and a template inside it would register as an
unplaced room and fail the build.

**Why a registry at all, if the scene is the truth?** Three readers need
every room's world rectangle without instantiating every scene: the map
(design §12 needs it drawn from real geometry), the door validator (a seam
has to be checked against its *neighbour's* rect), and the F4 debug jump.
`RoomRegistryBuilder` (`game/rooms/nodes/room_registry_builder.gd`) is one
class shared by the headless tool, the editor menu item, and the
`RoomRegistry` autoload at runtime — so the three can never disagree about
what a valid world grid is. If `data/rooms.json` is missing or doesn't
list a scene that exists, the autoload rebuilds it in memory and warns
you to run the tool; the game still boots.

Never hand-edit `data/rooms.json` — the next build overwrites it. Both
writers stamp a `_comment` saying so.

**Drafting by script is allowed, once.** An agent, or a one-off script kept
outside the repo and deleted afterwards, may *draft* a room scene as a
first pass. The five rooms under `game/rooms/test/` were made that way.
From the moment the file exists the editor owns it: nothing re-generates
it, and the draft script is not part of the project. "No generator" means
no checked-in generator and no second copy of a room's geometry that
something could silently re-run — not "never touch a text editor".

### 1.1 Tests are scenes; `-s` scripts can't see autoloads

Worth knowing before you write a tool or a test, because it is the one
Godot gotcha this layout is built around. A script run with
`godot -s res://foo.gd` is compiled **before the autoloads exist**, so an
identifier like `Data` or `GameState` fails to resolve at *parse* time —
not a null at runtime, a script that won't load. Therefore:

- **Tests are scenes.** `tests/test_boot.tscn` is a `Node` with a script
  that does its work in `_ready()` and calls `get_tree().quit(code)`.
  Run one with `godot --headless --path . res://tests/test_boot.tscn`.
- **`-s` tool scripts** (`tools/build_room_registry.gd`,
  `tools/gen_kind_tileset.gd`) `extends SceneTree`, `await process_frame`
  before touching anything, and only name plain `class_name` classes
  (`RoomRegistryBuilder`, `Room`), never an autoload.
- **`@tool` scripts** — every room node — follow the same rule and reach
  autoloads through `Game.data()`, `Game.state()`, `Game.sfx()`,
  `Game.music()`, `Game.juice()` (`game/game.gd`), which look the node up
  in the tree at call time and return a plain `Node`. Call sites stay
  dynamically typed. Runtime-only scripts (player, enemies, UI) use the
  autoload names directly.

---

## 2. The scene contract

Every node in the contract is a registered class in
`game/rooms/nodes/`, so it has a name and an icon in the *Create Node*
dialog, typed fields in the inspector, an editor gizmo where it has a
footprint, and scene-tree warnings when something is unset or
contradictory:

| Class | Extends | Where it goes |
|---|---|---|
| `Room` | `Node2D` | the scene root |
| `RoomExit` | `Area2D` | under `Exits` |
| `RoomEntry` | `Marker2D` (via `RoomMarker`) | under `Entries` |
| *(TileMapLayer)* | — | `Collision`, `DecorBack`, `DecorFront` (§3, §6) |
| *(Node2D)* | — | `Props`, `Objects`, `Enemies` containers (§6, §7) |

They are `@tool` scripts and they **ship in the game** — the same `Room`
script builds the skin, backdrop and darkness at runtime that draws the
preview in the editor. Every editor-only branch is guarded by
`Engine.is_editor_hint()`; keep anything you add there allocation-light,
because `_process` runs in the editor to refresh the skin preview.

### 2.1 Root node

A `Node2D` **named after the file** (the registry warns if they differ;
the name is the room's id everywhere — in exits, saves and the map),
carrying the **`Room`** script (`game/rooms/nodes/room.gd`). Its exported
properties are everything about the room that isn't geometry — edit them
in the inspector, grouped as they appear there.

**Identity**

| Field | Type | Default | Meaning |
|---|---|---|---|
| `display_name` | String | `""` | What the map and the save slot show. Empty means "use the node name". |

**World grid** — required; the registry refuses a room without them (§4):

| Field | Type | Default | Meaning |
|---|---|---|---|
| `world_x` / `world_y` | int | `UNSET` (−99999) | Position of this room's **local tile (0, 0)** on the shared world grid, in tiles. `y` grows downward and may be negative. |

**Look** — cosmetic; change freely (§5):

| Field | Type | Default | Meaning |
|---|---|---|---|
| `skin` | String | `"greybox"` | → `data/skins.json`. Auto-tiles the Collision layer at runtime. `"none"` draws no skin at all (for fully hand-painted rooms). |
| `background` | String | `"greybox"` | → `data/backgrounds.json`: fill colour + parallax layers. |
| `music` | String | `"silence"` | → `data/music.json` `tracks`. The same name across a seam keeps playing; a different name crossfades. |
| `darkness` | float 0–1 | `0.0` | 0 = fully lit; 1 = pitch black outside light sources (design §7.5). Becomes a `CanvasModulate` lerped toward `ambient_color`. |
| `ambient_color` | Color | `(0.04, 0.03, 0.06)` | The colour darkness fades toward. |

`skin`, `background` and `music` are **dropdowns built by reading the JSON
files** (`_validate_property`), so you can only pick a name that exists.
The stored value is still a plain string; an unknown skin at runtime warns
and falls back to greybox, an unknown track warns and plays silence.

**Editor**

| Field | Default | Meaning |
|---|---|---|
| `preview_skin` | `true` | Draw the skin in the editor as you paint Collision. The kind tiles are faded to 35 % over it, so you see both what you painted and how it reads. No runtime effect. |
| `test_entry` | `""` | Where **Run Current Scene** (F6) starts you (§9.9). Suggests the room's entry ids; empty = the first entry. Only affects F6. |

#### The house rule and `@export`

CLAUDE.md says missing data is a hard error and there are no silent
defaults. That sits awkwardly with `@export`, because an exported
property *always* holds some value — "absent" stops being a state.

The two fields with no meaningful default keep the rule via **a sentinel
the registry rejects**: `world_x`/`world_y` start at `Room.UNSET`, the
template deliberately doesn't set them, and a room that never got a grid
position fails the build exactly as loudly as a missing key would. `Room`
also raises a scene-tree configuration warning while they are unset, so
you see it while authoring rather than at build time. Everything else on
the root (`skin`, `music`, `darkness`…) has a legal default by design:
a greybox, silent, fully-lit room is a *valid* room, not a half-finished
one.

### 2.2 Containers and discovery

Children of the root, found **by exact node name**:

| Node | Holds | Found by |
|---|---|---|
| `Collision` | the kind layer (§3) | `Room`, `SkinLayer`, `GreyboxLayer`, the registry |
| `Entries` | `RoomEntry` markers | `Room.entry_node()`, the registry |
| `Exits` | `RoomExit` volumes | the registry; exits trigger themselves at runtime |
| `Objects` | scene instances from `game/objects/` (§7) | the objects themselves — they run as ordinary nodes |
| `Enemies` | scene instances from `game/enemies/` (§7) | likewise |
| `DecorBack*` / `DecorFront*` / `Props` | paint (§6) | nobody; they just draw |

A missing container means "none of these". A bare `Marker2D` under
`Entries`, or any non-`RoomExit` under `Exits`, raises a warning on the
root naming the offender.

Discovery is by parent group, deliberately. A whole-tree walk would find a
`RoomExit` wherever you put it, but then an exit accidentally parented
under `Props` would silently work until someone reorganised the scene. The
group is the contract.

---

## 3. `Collision` — the only geometry

A `TileMapLayer` named exactly `Collision`, using
`game/rooms/tileset_kind.tres`. That TileSet is the **authoring palette**:
eight flat tiles, each carrying a `kind` custom-data string and, where
the kind is something you stand on, its physics polygon on physics layer
0 (collision layer 1, `world`). Paint a cell and the player collides with
it; erase it and they don't. No export, no byte table, no second copy.

The layer is **hidden at runtime** (`collision.visible = false`) — the
flat tiles are never drawn in play — and dressed by the `SkinLayer` (§5).
`F2` shows them again, faded, over everything.

| Atlas | `kind` | Physics | Looks like (palette) | What it does |
|---|---|---|---|---|
| 1st | `solid` | full square | dark slate `#46464f` | Blocks everything. |
| 2nd | `oneway` | **top-quarter lip**, one-way, 4 px margin | tan lip, only the top quarter is drawn | Stand on it, jump up through it from below, **down + jump** drops through (the player samples the kind 2 px under its feet, then nudges itself 5 px down, past the 4 px margin). That drop is the only way down through it: a moving solid pressing on someone standing on it **crushes** them sideways instead (design §7.6). The tile being mostly transparent is deliberate: what you see is what it does. |
| 3rd | `breakable` | full square + a `BreakableTile` area | brown-grey with a regular speckle | A secret wall. Any attack that reaches it (`take_hit`, tier 0 or better) erases the cell with a puff and a shake, and the skin re-fits its neighbours. |
| 4th | `fortified` | full square + a `BreakableTile` area | dark with a brick pattern | **Keystone-grade** wall: only a `tier` 1 hit breaks it; anything less clinks. This is the "Power Fang breaks certain walls" tile (design §9.1). |
| 5th | `water` | **none** | blue, 60 % alpha, bright top edge | Swimming. The player samples the kind at its **body centre**: inside, gravity is cut to `swim_gravity_mult`, horizontal speed is `swim_speed`, holding jump rises at `swim_up_velocity`, crouch and dash are disabled. |
| 6th | `hazard` | **none** | red, 50 % alpha, spike row along the bottom | Damage. The player samples the kind 2 px above its **feet**: standing in it deals `hazard_damage` with `hazard_knockback` and i-frames; `ratty_boots` (`hazard_protect`) take one point off. |
| 7th | `ramp_r` | triangle `/`, ascending toward +x | slate wedge | 45° slope. Walkable (`floor_max_angle` is 50°). |
| 8th | `ramp_l` | triangle `\`, ascending toward −x | slate wedge | Mirror of `ramp_r`. |

All the numbers above are keys in `data/player.json`; nothing is baked into
the tiles beyond shape and `kind`.

**Authoring rules that follow from the physics column:**

- **`water` and `hazard` have no shape**, so they are *volumes the body
  occupies*, not floors. Paint them in the cells **above** a `solid`
  floor, never as the floor itself — a hazard painted where the floor
  should be is a hole with a red tint, and the player falls through it.
  Because hazard is sampled at the feet, a 1-tall hazard strip over solid
  floor is the whole spike pit. Because water is sampled at the body
  centre, a 1-tall water strip over solid floor already counts as
  swimming (the centre is ~19 px above the feet); deeper pools behave the
  same, they just let the player sink.
- **Ramps need solid fill beneath.** Fill the column under a ramp tile
  with `solid`. Two reasons: a fast faller that clips the slope surface is
  caught by the tile behind it, and the skin draws ramp cells as full
  ground blocks anyway (see the note under §5), so an unsupported ramp
  reads as a floating block in art view.
- **`breakable` and `fortified` are skinned as ordinary ground.** Every
  shipped skin maps them to the same terrain as `solid`, so in art view a
  secret wall is indistinguishable from the wall around it. That is
  correct for a *secret*; for a wall the player is meant to notice, hint
  it with `DecorFront` cracks or a `Props` sprite (§6), or accept that
  only `F2` shows the speckle.
- **Doorways are erased cells.** A door is a gap in the border wall —
  right-click the cells out — with a `RoomExit` rect laid over the gap
  (§4). A 3-tall gap fits the standing player (the collider is 42 px tall,
  under 2 tiles); a 1-tall gap is a crawlspace (crouched height 26 px).

**Sizes to design against** (current `data/player.json` numbers; all
F1-tunable): the player stands 1.5 tiles tall on screen and collides as a
16 × 42 px capsule (26 px crouched), runs at 185 px/s and walks at 85,
jumps about 2 tiles (64 px at `jump_velocity` −440 / `gravity` 1500 — a
2-tile ledge is the limit, a 1-tile step is comfortable), and dashes about
2 tiles horizontally. The viewport is 960 × 540 px = 30 × 16.9 tiles:
a room at least that big scrolls; a smaller room is centred on screen
rather than clamped.

**Breakables at runtime.** `Room._spawn_breakables()` gives every
`breakable`/`fortified` cell a `BreakableTile` (`Area2D` on physics layer
13 `breakable`, `game/rooms/nodes/breakable_tile.gd`) so hitboxes can find
it; the kind cell keeps providing the collision until the area erases it
via `Room.erase_cell()`. Broken walls are **not persisted** — a reload
restores them. That matches the design (a secret wall is a discovery, not
a permanent state) and is worth knowing before you build a puzzle on it.

> **Adding a kind is a three-place change:** the tile in
> `tools/gen_kind_tileset.gd` (its `KINDS` row and `_shape_for` polygon;
> re-run `godot --headless --path . -s res://tools/gen_kind_tileset.gd`
> to rewrite `tileset_kind.tres`), the colour in
> `GreyboxLayer.KIND_COLORS`, and whatever reads `Room.kind_at()` for the
> new behaviour (today: the player's `_sample_tile_kinds`, `BreakableTile`,
> and `SkinLayer` via `data/skins.json`). All three or none. Re-running
> the generator rewrites the atlas, so existing painted cells keep their
> atlas column — append kinds, never reorder them.

---

## 4. The world grid, exits and entries

### 4.1 One grid, real geometry

Every room has a `world_x`/`world_y`. At runtime `World.load_room()` places
the root at `(world_x, world_y) × 32` px, so local tile `(tx, ty)` sits at
world tile `(world_x + tx, world_y + ty)`. Neighbouring rooms painted to
line up on that grid **are** lined up — the player can keep its world
position when it walks through a doorway, and the map can be drawn from
the registry's rectangles with no hand-kept layout file. This is what
design §12 asks for: the god's name is read off the finished map, so the
map must be faithful geometry, and the cheapest way to make it faithful
is to never have a second copy.

The registry records two rectangles per room: `world_x/world_y` (what you
authored — where local (0, 0) is) and `x/y/w/h` (the **painted** rect:
`world_x + Collision.get_used_rect()`). Paint from local (0, 0) and they
coincide; paint from (3, 2) and the room's left edge is `world_x + 3`.
The validator and the map use the painted rect. The convention is to
paint from (0, 0), which is where the template's first entry assumes the
room begins.

The root draws a blue outline of the painted rect in the editor, labelled
with the room name, its world position and its size in tiles.

### 4.2 Exits: seam or teleport

A **`RoomExit`** (`Area2D`, physics layer 14 `room_exit`, masks the
player) is a tile-aligned rectangle that sends the player to `to_room`.
The trigger shape is rebuilt from `w`/`h` whenever the node moves and is
never saved — the scene holds only the authored fields.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `to_room` | String | `""` | Scene stem of the target room. A suggestion dropdown lists the scenes it can see (see the note below). |
| `to_entry` | String | `""` | **Empty = seam. Named = teleport.** The `id` of a `RoomEntry` in the target room. |
| `w` / `h` | int | `1` / `3` | Footprint in tiles. A side door is `1 × 3`; a pit or ceiling hole is `2 × 1`. |
| `direction` | enum | `right` | Which way the player travels through it: `right`, `left`, `up`, `down`. Used by seams to nudge the player past the doorway, and by the map. **Set it to match.** |
| `locked_by` | String | `""` | `""` always open; `flag:<name>` needs a permanent flag; `item:<id>` needs the item in the inventory. Anything else warns. A locked exit draws red. |

**Position snaps to whole tiles**, and the gizmo draws the snapped
footprint with a tick line back to the node so the rounding is visible
while you place it. If the tick is long, the rect is not where you think.

**Seam** (`to_entry == ""`): the player keeps its world position along
the seam. This is the normal metroidvania door, and it only works if the
two rooms **line up on the grid**: the doorway gap in this room's border
and the gap in the neighbour's border must occupy the *same world rows*
(or columns, for a vertical seam), and the neighbour's painted rect must
begin where this one's ends. The registry validator checks that the exit
rect, grown by one tile, touches the neighbour's painted rect —
adjacency. It does **not** check that the rows line up; your eye does,
and the play test does (you arrive inside a wall if they don't).

Three runtime details make seams robust, and you get them for free by
putting the exit over the doorway (paint nothing special):

- **The trigger reaches outside.** At runtime a seam's trigger extends
  `RoomExit.OUTSIDE_TILES` (2) past the room edge in its `direction`; the
  gizmo draws that reach faintly. Triggers are **polled** every physics
  frame while the player overlaps them, not edge-triggered, so a request
  that lands during a transition is simply repeated next frame.
- **A collision apron continues the edge.** Only one room is loaded at a
  time, so the world would end at the painted rect. `Room` lays a
  `SeamAprons` StaticBody2D beyond every seam: the edge column (or row)
  of the kind layer, copied `Room.APRON_TILES` (3) outward across the
  exit's span ± `APRON_MARGIN` (2) — solids stay solid, one-way ledges
  stay one-way. A player who steps through the doorway before the trigger
  fires, or who turns straight around after arriving, stands on floor.
  You can see the apron in the F2 debug view.
- **Arrival lands clear of the door.** `World.load_room` places a seam
  arrival just past the inner edge of the *matching* exit in the new
  room (the one that leads back, found by opposite `direction`), body
  fully inside the painted rect, and only locks exits for the fade. So
  turning around at once re-enters that trigger and goes back; standing
  still stays put. The fade is still black while this happens.

`tests/test_objects.gd` walks the hall → shaft seam, turns straight
around, and crosses it again. A `RoomEntry` standing inside an exit's
footprint gets a validator warning — a player spawned there would leave
on the first frame.

**Teleport** (`to_entry` named): the player is placed at that `RoomEntry`
in the target room, feet on the marker, facing its `facing`. Use it for
anything the grid can't express — stairs between non-adjacent rooms, a
pit that drops into a room several tiles away, a one-way fall. The
validator checks the entry exists.

**Wired both ways, or deliberately not.** The validator requires that the
target room has *some* exit back to this one; the message tells you to
either add the exit back or make this one a `to_entry` teleport (a
one-way drop is legal and must be a teleport, because a seam back up
through the floor you fell through makes no sense).

> **Note on the `to_room` dropdown.** `RoomExit._room_names()` scans
> `res://game/rooms` and `res://game/rooms/test` only, while the registry
> builder scans **every** subfolder of `game/rooms/` (except `nodes/`).
> A room saved in a third folder — the *New Room…* dialog lets you type
> any folder — registers fine but shows a false `to_room '…' is not a
> scene under game/rooms/` warning on every exit pointing at it. Keep
> rooms in the top level or `test/` until the scan is unified, or ignore
> that one warning when the registry build is green.

### 4.3 Entries are feet

A **`RoomEntry`** (`RoomMarker` → `Marker2D`) is where the player
*arrives* by teleport, save, death respawn or F4. Position is **feet**:
bottom-centre of the body, not the sprite centre. The gizmo draws a foot
line with a vertical tick instead of a cross so that is never a surprise.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `id` | String | `"main"` | What another room's exit (or a save) names. Empty warns. `"main"` is the conventional first entry: F4 and any load with an *empty* entry id land on the **first** entry under `Entries`, so keep `main` first. A *named* id that doesn't exist is an error — the registry catches it for exits; a stale save would drop the player at the room's centre. |
| `facing` | enum | `right` | Which way the player faces on arrival. |

The rule in practice: if the floor is tile row `R`, the feet go at
**`y = R × 32`** px; horizontally, stand in the middle of a tile at
**`x = (C + 0.5) × 32`**. So a floor at row 17, column 5 puts the entry
at `(176, 544)` — which is exactly where `test_vault`'s entries sit. The
registry stores entries in fractional world tiles (`x = world_x +
position.x / 32`), so the `.5` survives.

**Every room needs at least one entry**, even one only ever reached by
seams: the registry refuses a room with none ("nothing can spawn the
player here"), because saves, death and the debug jump all land on one.

---

## 5. The three look channels

A room's appearance comes from three independent channels that swap
without touching each other or the geometry.

| Channel | Authored | Applies to |
|---|---|---|
| **skin** | root `skin` → `data/skins.json` | the Collision kind layer, auto-tiled at runtime |
| **background** | root `background` → `data/backgrounds.json` | fill colour + parallax layers behind everything |
| **decor** | nodes in the scene (§6) | hand-placed art for this room only |

Skins and backgrounds are **shared** — one entry dresses every room naming
it, at zero per-room cost. Decor is **per-room** and costs authoring time;
spend it on rooms that earn it. This is the "hybrid" in CLAUDE.md: the
auto-skin gets every room to presentable for free, and decor is optional
paint on top.

### 5.1 Skins and how the auto-tiler works

At load, `Room._build_runtime()` creates a `SkinLayer`
(`game/rooms/nodes/skin_layer.gd`, a `TileMapLayer` with the skin's art
TileSet) and calls `build(collision, skin_def)`. For each kind the skin
maps, it runs Godot's terrain solver (`set_cells_terrain_connect`) over
those cells, so a block of `solid` becomes properly edged ground and a
row of `oneway` becomes a platform strip. The layer is paint: it has no
physics layers, and `Room.kind_at()` never looks at it.

Three details make purchased packs usable without hand-fixing:

- **The ring.** One cosmetic ring of cells just outside the painted rect
  is added to the solve, each copying its nearest border cell, and
  rendering is clipped to the room rect so the ring never draws. Without
  it a 1-thick border wall autotiles as a free-standing strip with edges
  on both sides; with it, the wall reads as the edge of solid rock.
- **The thin-geometry patch.** Purchased terrain blobs rarely cover all 47
  peering configurations, so cells the solver leaves empty get the
  terrain's most-connected (interior fill) tile instead of a hole.
- **Unmatched never means invisible.** A kind with no mapping in the skin,
  or a cell nothing could fill, lands in `SkinLayer.unmatched`, and the
  `GreyboxLayer` draws those cells as flat kind-coloured rects. Collision
  is never invisible. At runtime a non-empty `unmatched` warns with a
  count; `F2` shows every kind this way.

**The scale.** The art TileSets are 32 px native, the world is 32 px per
tile, so `SkinLayer.scale` is 1. If a pack with another tile size is ever
added, the layer scales itself by `32 / tile_size` automatically.

**Skin schema** (`data/skins.json` → `<name>`):

```json
"cave_dark": {
  "tile_tint": "#ffffff",
  "tileset": "res://assets/tilesets/SSW.tres",
  "terrains": {
    "solid": [3, 0], "breakable": [3, 0], "fortified": [3, 0],
    "ramp_r": [3, 0], "ramp_l": [3, 0],
    "oneway": [3, 1]
  }
}
```

| Key | Meaning |
|---|---|
| `tile_tint` | Modulate colour over the whole layer. |
| `tileset` | `res://` path of the art TileSet. **Absent = greybox**: the layer hides itself and every cell goes to `unmatched`. |
| `terrains.<kind>` | Either `[terrain_set, terrain]` (autotile through that terrain) or `{"atlas": [source_id, x, y]}` (one fixed tile for every cell of that kind — for packs that cover a kind with a single tile, or for `water`/`hazard` once they get art). |

`greybox` **must stay tileset-less.** It is the permanent fallback — the
room you see when a skin is misspelled, and the view `F2` fades toward —
not a transition state, and it has to keep working.

**Two `.tres` files, one terrain set per pack.** `assets/tilesets/SSW.tres`
carries the Szadi "Seasonal Sprite Worlds" packs wired as one terrain set
each, every set with terrain 0 `ground` and terrain 1 `platform`: set 2 =
SSWorlds_SET2 (`cave_brown`), 3 = SSW_SET3 (`cave_dark`), 4 = SSW_SET4
(`mine`), 5 and 6 = SSW_SET5 (`stone_dark`, `stone_pale`), 8 = SSW_SET7
(`cave_roots`). Sets 0, 1 and 7 were other packs and were removed; the
gaps are harmless. Its atlas source 9 is a single flat teal water square
borrowed from the jungle pack — the only flat water tile in any copied
sheet — which `cave_roots` maps with `"water": {"atlas": [9, 10, 25]}`.
`assets/tilesets/SSW2_SET2.tres` is the jungle-ruins pack (`jungle_ruins`:
mossy brick ground, wooden-plank platform, the same water tile) — the
Collapse's natural skin. The Castle pack is in `assets/tilesets/` with no
terrain set yet. Which packs are licensed how is
`assets/tilesets/SOURCES.md`.

> **Ramps have no slope art.** Every skin maps `ramp_r`/`ramp_l` to the
> `ground` terrain, so in art view a ramp cell draws as a full block and
> the player walks a 45° line through its upper corner. The greybox view
> shows the real wedge. Until a pack with diagonal tiles is wired (an
> `{"atlas": …}` mapping per ramp kind would do it —
> `SSW2_SET2_mainlev_build2.png` has rock ramp pieces and is not in a
> `.tres` yet), use ramps sparingly or hide the seam with decor. **`hazard` has no art in any skin** — no
> copied pack has spike tiles — so it always draws as a greybox rect, and
> `water` draws as greybox in every skin but `cave_roots` and
> `jungle_ruins`. `tests/test_boot.gd` deliberately excludes those two
> kinds from its "every cell has art" check.

**Adding a skin:**

1. Import the pack's PNG into `assets/tilesets/` (project default filter
   is already nearest). Record the pack in `assets/tilesets/SOURCES.md`
   with its license file in `assets/licenses/` **before** it ships.
2. In `SSW.tres` (or a new `.tres` if the pack isn't 32 px), add a
   `TileSetAtlasSource` with 32 × 32 regions, then a terrain set with
   `ground` and `platform` terrains and paint the peering bits on the
   ground blob and the platform strip. **No physics, navigation or custom
   data layers** — this TileSet is paint; `tileset_kind.tres` is the only
   one that carries `kind`.
3. Add the `data/skins.json` entry. The `skin` dropdown picks it up on the
   next inspector refresh.
4. Set a test room's `skin` to it, run the game, press `F2`: anything
   still drawn as a flat rect is a kind you haven't mapped or a peering
   configuration the pack can't fill. (`tests/test_skins.tscn`, planned
   alongside the asset test, will check that every skin dresses a room.)

### 5.2 Backgrounds

`data/backgrounds.json` entries carry a `color` and a `parallax` array,
far → near. Every layer needs `texture`, `factor`, `tint`, `repeat_x`,
`repeat_y`, `y_px` and `scale` — all required, no silent defaults
(`Backdrop.setup()` errors on a missing key and skips the layer).

- `factor` is the scroll ratio: `0` = glued to the camera, `1` = glued to
  the world. A layer draws at `room_origin + (cam_origin − room_origin) ×
  (1 − factor)`.
- `scale` is draw magnification. The SSW backdrops are 32 px/tile-era
  art, so it is `1` here (the previous project drew them ×2 at 64 px
  tiles).
- `y_px` offsets the layer vertically in art pixels — negative lifts a
  skyline so its horizon sits where you want it in a tall room.
- An empty `parallax: []` is explicit and legal (`greybox`, `black`).

Everything is clipped to the room's painted rect, so a backdrop never
bleeds into the neighbour across a seam. Godot's `Parallax2D` is not used;
`Backdrop` reads the active `Camera2D` and draws itself.

---

## 6. Decor: node conventions

Optional children of the root, recognised by **name**. The template ships
all three, empty.

| Node | Type | `z_index` | Drawn |
|---|---|---|---|
| `DecorBack` | `TileMapLayer` (art TileSet) | −2 | behind the skin — wall texture, roots, pipes |
| `Props` | `Node2D` | 1 | its `Sprite2D`/`AnimatedSprite2D` children, free-placed one-offs |
| `DecorFront` | `TileMapLayer` (art TileSet) | 2 | in front of everything — silhouettes, dangling vines |

Runtime z-order within the room (children are relative to the root):

```
Backdrop(−10) → DecorBack(−2) → SkinLayer / GreyboxLayer(−1) → Collision(0, hidden)
             → Props(1) → DecorFront(2)
```

The **player and enemies draw at z 0**, so with the template's values both
`Props` and `DecorFront` draw **in front of** them. That is right for
`DecorFront` and a judgement call for `Props`: a lantern on the wall
behind the player wants `z_index = -1` on that sprite (or on the `Props`
node), a hanging chain in front of them wants `1`. Set it per prop; the
template's `1` is only a starting value, and it is a deliberate change
from the previous project, where props drew behind units.

`Props` is the "skin an individual thing" channel — the toppled statue,
the dead bandit, the broken rope bridge. No schema, no registry entry;
drop a `Sprite2D` in and it ships. Art comes from `assets/props/` (the
SSW decoratives sheets) or, if AI-generated, from
`assets/ai_placeholder/props/` with its provenance record
([ai_art.md](authoring/ai_art.md)).

### Authoring rules

1. **Decor may never contradict collision.** Nothing that reads as
   standable or blocking where the kind layer says otherwise. No test can
   catch it; the reviewer and `F2` do.
2. **Never cover a tell.** `DecorFront` over an enemy's wind-up, a
   button, a lever or a doorway is a bug, not a style.
3. **Author at 32 px/tile**, the same grid as everything else. The decor
   layers are bound to `SSW.tres` by the template; a pack with a different
   tile size needs its own `.tres` and a `scale` on that layer.
4. **Prefer `DecorBack`.** Front decor is the channel most likely to hurt
   play.

### Nothing here reaches the registry

`RoomRegistryBuilder.describe()` reads the root's fields, the painted
rect, `Exits` and `Entries`. Decor, objects and enemies are not in
`data/rooms.json`; repaint `DecorBack` all day and the registry does not
change.

---

## 7. Objects and enemies (scene instances)

> **Status (2026-10-13):** both `game/enemies/` and `game/objects/` have
> landed; §7.1 and §7.2 describe the scripts as they are. The five test
> rooms under `game/rooms/test/` use every object below at least once, so
> they double as live examples.

Unlike the previous project, objects and enemies are **not typed
markers** that something else spawns from. They are ordinary scene
instances: open the room, select the `Objects` (or `Enemies`) node, *Add
Child Node* → *Instantiate Child Scene*, pick
`game/objects/<thing>.tscn` or `game/enemies/<species>.tscn`, drop it
where it goes. The scene *is* the runtime object; its exported fields are
the per-room knobs; every number that is not per-room lives in
`data/objects.json` (`push_block.*`, `button.*`, `gate.*`, `pickup.*`,
`save_shrine.*`, `hazard.*`) or `data/enemies/<species>.json`. `F3`
reloads all of it; the `F1` panel edits `player`, `objects` and `weapons`
numbers in place (not, today, enemies).

**Positions are feet** for anything that stands on the floor, the same
rule as entries (§4.3). Objects that are tile rects (a gate) snap to tiles
like exits do.

### 7.1 Objects (`Objects` node)

Every object script is `@tool`, draws a gizmo and a label in the editor
(feet line, footprint, channel), and builds its runtime children — body,
areas, manifest sprite — in `_ready`, so the scene file holds nothing but
the authored fields. They reach the autoloads through `Game.*`
(`game/game.gd`), which is what lets an editor-side script stay silent
about `Data`/`GameState` at parse time.

| Scene | Exported fields | Does |
|---|---|---|
| `push_block.tscn` (`PushBlock`) | `block_material` (stone / iron / wood) | A one-tile crate. The player walking into it calls `push(dir, delta)` and it slides at `objects.push_block.push_speed`; it falls, weighs buttons, carries the player. A block resting on a key spot (any floor button) saves its position and is still there next visit; left anywhere else it resets to where it was authored. The grappling hook pulls **iron** and **wood** blocks toward the player (`grapple_hit()` returns `"pull"`); stone is too heavy. Layers `pushable` + `grapple`. |
| `floor_button.tscn` (`FloorButton`) | `channel`, `latching` | A pressure plate. Pressed by standing weight — player, push block, enemy. Drives its channel while pressed; a latching one stays down forever (saved: it is still down on the next visit) and also takes a hit (a slingshot stone). A momentary one saves nothing and re-reads its weight on arrival. Sprite: the `button` manifest entry, `raised`/`pressed` clips. |
| `lever.tscn` (`Lever`) | `channel`, `flag`, `starts_on` | Toggled by any hit (sword, whip reach, slingshot) on its `switch`-layer area. Drives its channel while on. Its on/off position is saved per room and restored on every visit, whichever way it was left; `starts_on` only sets the first visit. A `flag` is set the first time it lands on, for anything else to test. It does **not** hold the lever on. |
| `gate.tscn` (`Gate`) | `channel`, `w`, `h`, `inverted` | A `w`×`h` portcullis that slides up `h` tiles (at `objects.gate.open_speed`) while any source drives its channel (`inverted` opens on *inactive*), opening the gap beneath it. The slab is an AnimatableBody on the `world` layer and is **solid all the time**: lowered, raised and mid-slide, and it carries what stands on it. Like every moving solid it **crushes** (design §7.6, `game/combat/crush.gd`, `objects.crush`): anyone it squeezes is displaced to the nearest free spot and hit. With nowhere to go, the player **voids out** (`World.void_out()`: the room reloads and they're back where they last entered it) and an enemy dies. Author it over **empty** Collision cells, with the `h` cells above clear for the raised slab. Position = the slab's bottom-centre. |
| `locked_door.tscn` (`LockedDoor`) | `needs_item`, `consumes`, `w`, `h` | A solid door in a doorway. Interact (LB / E) in front of it: with the item it opens (consuming a key), without it a toast says what it needs. Opening sets the permanent flag `door_<room>_<node>` so it stays open in that save. |
| `pickup.tscn` (`Pickup`) | `item_id`, `count`, `flag`, `appearance` | An item on the floor; walk over it. `flag` makes it once-ever (naming the flag IS the suppression). `appearance` `"chest"` draws the chest sprite instead of the floating gem. Dropped items from the pause menu are Pickups made with `setup(id, n)` and a 1 s re-collect grace. |
| `save_shrine.tscn` (`SaveShrine`) | *(none)* | Interact to save: sets the respawn point to **this shrine** (`GameState.set_respawn(room, node name)`), heals if `objects.save_shrine.heal_on_save`, writes the current slot (slot 1 if the run was never saved). `World.load_room()` accepts a shrine's node name as an entry id, so death and Continue land on it. |
| `grapple_anchor.tscn` (`GrappleAnchor`) | *(none)* | A ring on a wall or ceiling. The hook's raycast hits its `grapple`-layer area, `grapple_hit()` answers `"anchor"`, and the player is pulled to it at `objects.grapple.pull_speed` (jump to let go early). |

Position is FEET (bottom-centre) for everything that stands on the
floor; the gate and door positions are the slab's bottom-centre and want
tile-aligned x (a multiple of 32 plus 16). Each object's editor label
shows what you set, so a room reads at a glance.

**Wiring is a shared integer channel (0–31)** (`game/autoload/wiring.gd`):
every pressed button and switched-on lever *drives* its channel, by
instance, and the channel is active while the set of drivers is
non-empty — so two momentary buttons on one channel don't fight. A
latching button is a permanent open; a momentary button plus a gate is a
hold-the-door puzzle; a push block parked on the button is the solution.
State is **per room**: `World.load_room()` calls `Wiring.reset()`, so a
gate held open by a button in another room closes the moment you leave.

**Puzzle objects remember where they were left.** Lever on/off, latched
buttons, and push blocks *parked on a key spot* (a floor button; group
`key_spot`, `holds(body)`) are written to
`GameState.room_objects` (in the save file) via `Room.store_state()` /
`Room.saved_state()`, keyed by room and the object's node path. **Renaming
or reparenting an object forgets its saved state.** Come back to a room
and the restored objects re-drive their channels. For
`Wiring.SETTLE_FRAMES` after a room loads, wiring changes are the room
settling into that state, not the player acting. Gates snap straight to
position and buttons stay quiet, so nothing visibly slides on arrival.
A block anywhere other than a key spot is not saved and resets on
re-entry (the Ocarina of Time rule), so a block pushed into a dead end
comes back. Other state (a door that stays unlocked, a pickup taken) goes
through `GameState.set_flag()`, and flags are saved too.

**The player's side of these contracts** is already in
`game/player/player.gd` and is what the objects are written against:
`_handle_pushes` calls `push()` on anything it slides into sideways that
has the method; `_interact` calls `interact(self)` on the nearest `Area2D`
on layer 8 within 28 px; `_fire_grapple` raycasts against world + pushable
+ grapple layers and calls `grapple_hit(self)` on the collider (and,
while aiming, `grapple_mode(self)` every frame: the same answer —
`"anchor"`, `"pull"` or `"none"` — with no side effects, which turns the
aim reticle red for anything but `"none"`; implement both); the
attack `Hitbox` calls `take_hit(info)` on anything on layers 5, 10 or 13.
The hit info dict is `{damage, knockback, source, origin, kind, tier,
hitstop}`; `tier` 1 is keystone-grade.

### 7.2 Enemies (`Enemies` node)

A species is a `.tscn` under `game/enemies/` — a `CharacterBody2D` with a
**behaviour script** and the `species` field preset — plus a JSON file at
`data/enemies/<species>.json` whose `behavior` key names that script. The
instance in the room carries **placement only**: position (feet) and
`facing`. Everything else — HP, speed, damage, body size, tell and attack
timings, the sprite id, how tall it renders — is in the JSON, which
`Data.enemies` loads by file stem, so a species dropped into ten rooms
retunes once. The scene's root name is cosmetic; the `species` field is
what matters.

| Scene | Script (behaviour) | Does |
|---|---|---|
| `green_slime`, `blue_slime`, `orange_slime` | `hopper.gd` | Idles until the player is within `aggro_range`, tells, hops at them; contact damage the whole hop; squashes on landing; waits `hop_cooldown`. Three JSON files, one brain. |
| `mushroom` | `walker.gd` | Patrols, turning at walls and ledges; within `spore_range` stops, tells, puffs a lingering `SporeCloud` hitbox. |
| `bush_lasher` | `lasher.gd` | Planted. Tells with a long wind-up, swings a wide hitbox; armoured against stagger while swinging. |
| `stone_guardian` | `guardian.gd` (a `Boss`) | First boss: slam + shockwaves, rock volley, charge. Phase 2 at half HP shortens every tell. |
| `riftmaw` | `aberration.gd` (a `Boss`) | Second boss: lash, blink-slam, homing orbs. |

**Common JSON block** (every species, hard errors when missing — the
boot test lists them in `tests/test_enemies.gd`): `behavior`, `boss`,
`sprite`, `fit_tiles`, `hp`, `contact_damage`, `contact_knockback`,
`contact_rearm`, `speed`, `gravity`, `friction`, `body_w`, `body_h`,
`hurt_stun`, `knockback_resist`, `death_linger`, `xp_placeholder`,
`hit_sfx`, plus a block named after the behaviour with that brain's
numbers (`hopper.aggro_range`, `guardian.slam_size`, …). A boss adds
`defeat_flag`.

**Contract with combat** (`game/enemies/enemy.gd`): body on layer 3
`enemy`, masking world and pushable; an `EnemyHurtbox` on layer 5; a
contact `Hitbox` on layer 7 masking `player_hurtbox`, live whenever the
enemy is alive and not staggered, re-armed every `contact_rearm` seconds
so a player who stands in it is hit again. `on_hit(info)` takes damage,
flashes white, hitstops, and staggers for `hurt_stun` unless that is 0
(bosses: `hurt_stun` 0 and `knockback_resist` 1 means hits never
interrupt). Every attack begins with `tell()` — the "tell" clip plus a
white pulse — because the readable wind-up is the game's fairness
promise. At 0 HP the death clip always plays to its end (`death_linger`
is a minimum, not a cut). The hurtbox answers `is_enemy()` so the player
picks its hit sound. Enemy projectiles (`Projectile.setup_enemy`, the
bosses' rocks, orbs and shockwaves) are added to the **room**, not the
enemy, so they outlive it, and are stopped by `Collision` tiles.

**Placement rules.** Feet on a floor row like an entry (§4.3); a species
spawned in mid-air falls. Hoppers and walkers probe for walls and ledges
(`ledge_probe` px), so a patrol platform needs no fences. Give a boss a
room: `aggro_range` is in px from the player's feet, and `Boss` switches
the music to the `boss` track on wake and back on death. A boss whose
`defeat_flag` is already set in the save frees itself on load and never
respawns; ordinary enemies **do not persist** — leave and come back and
they are there again.

**Adding a species on an existing brain is two files**: copy the nearest
`data/enemies/*.json` and retune, copy its `.tscn` and change `species`,
add the sprite entry to `data/sprites.json`. `tests/test_enemies.tscn`
spawns every species in the start room, hits it, and checks the bosses
start an attack. A new *brain* is a new script extending `Enemy` (or
`Boss`) that implements `behavior_name()` and `_think()`; attacks are
coroutines that only ever `await` the enemy's own `stepped` signal via
`wait()`/`tell()`/`pulse_box()` — a coroutine parked on a scene-tree timer
resumes on a freed node and errors.

---

## 8. Checklists

### A new room

- [ ] Created with *Project → Tools → New Room…* with a real `world_x`/`world_y` typed in (the spin boxes default to 0, 0 — that is the entry hall's spot)
- [ ] Root node named after the file; `display_name` set
- [ ] **No warning triangles left in the scene tree** — `Room`, `RoomExit` and `RoomEntry` flag unset positions, empty Collision, bad children, dead `to_room`s and malformed `locked_by`
- [ ] `Collision` painted with `tileset_kind.tres`, from local (0, 0); every `hazard`/`water` cell sits over a solid floor; every ramp has solid fill beneath
- [ ] Doorways erased from the border wall, 3 tall for doors, with a `RoomExit` over each gap whose `direction` matches and whose snapped rect covers the gap
- [ ] Seams line up on the world grid with the neighbour's gaps on the same rows/columns; non-adjacent connections use `to_entry`
- [ ] Every exit wired back from the other room (or deliberately a one-way teleport)
- [ ] At least one `RoomEntry`, `main` first, feet on the floor
- [ ] `skin` / `background` / `music` / `darkness` set (greybox is fine while the room is being tuned)
- [ ] Any gate sits over empty Collision cells and something on its channel drives it; any locked door has a key or a flag-setter somewhere reachable
- [ ] Registry rebuilt; `.tscn` **and** `data/rooms.json` committed together
- [ ] `godot --headless --path . res://tests/test_boot.tscn` green — it validates the registry and loads every room

### Promoting a room to decor

- [ ] `DecorBack` painted at 32 px/tile, contradicting no collision
- [ ] `DecorFront` sparing, covering no tell, button, lever or doorway
- [ ] `Props` children placed with a conscious `z_index` each; art under `assets/` (or `assets/ai_placeholder/` with provenance), never `raw_assets/`
- [ ] Walked in-game with `F2` toggled on and off
- [ ] Registry rebuilt — decor must produce **zero** `rooms.json` diff

---

## 9. Tutorial: a sixth test room, end to end

We'll build **`test_reliquary`** — a small room west of `test_vault` with a
one-way ledge, a shallow pool, a spike strip and a breakable wall hiding
an alcove — from nothing to a green registry build. Swap in your own
layout as you go; the *order* is the part worth copying.

Everything below happens in the Godot editor except the last step.

### 9.0 Once, before you start

```bash
godot --headless --path . --import    # build the .godot cache
```

Then open the project in the editor and check *Project → Project
Settings → Plugins* shows **Room Tools** enabled. The rest assumes it is.

### 9.1 Pick the grid position

This is the step the previous project's tutorial didn't have, and it is
the one that makes seams work. Open `data/rooms.json` and read the
neighbour you are attaching to:

```
test_vault:   world (104, -14), painted 30 × 20  →  x 104..133, y -14..5
test_gallery: world (58, 10),   painted 46 × 18  →  x 58..103,  y 10..27
```

The vault's left wall is world column 104; its floor is local row 17
(world row 3); its interior spans local rows 3–16. A room **west** of the
vault, sharing its vertical placement, is 20 tiles wide and sits at
**world (84, −14)** — columns 84..103, rows −14..5. Nothing else is there
(the gallery starts at row 10). Because both rooms share `world_y`, a
doorway at local rows 14–16 is at *world* rows 0–2 in **both** scenes,
which is what a seam needs.

### 9.2 Create the scene

**Project → Tools → New Room…**: name `test_reliquary`, folder `test`,
world **x 84**, **y −14**, Create.

The dialog refuses names that exist or aren't snake_case, shows the path
it is about to write, and opens the new scene. You have the skeleton: a
`Room` root named `test_reliquary` with its grid position set, `Collision`
bound to the kind tileset, `DecorBack`/`DecorFront` bound to `SSW.tres`,
`Props`, `Entries` with one `main` entry, `Exits`, `Objects`, `Enemies`.

The root will show one warning: *Collision has no cells painted yet.*
That is the next step.

### 9.3 Fill in the identity

Select the root. `display_name` → `Reliquary`. Under **Look**, leave
`skin` on `greybox` for now, set `background` to `cave_depths`, `music`
to `vault` (the same track as next door, so the seam is silent), and
`darkness` to `0.5`. Leave `preview_skin` on.

### 9.4 Paint the collision

Select **`Collision`**. The TileMap panel opens with the eight-tile
palette from §3; each colour is a rule. Left mouse paints, right erases;
use the **rectangle** tool for floors and walls and the pencil for detail.
Rooms are painted from local (0, 0), so the blue outline grows down and
right from the origin.

Block it out in this order. Rows run top to bottom, columns left to
right, both from 0; the room is 20 × 20 tiles — 640 × 640 px.

1. **Border**, `solid`: columns 0 and 19 top to bottom, row 0, and rows
   17–19 (a 3-thick floor, like the vault's). The walking floor is the
   top of row 17, so feet sit at `y = 544`.
2. **Doorway**, erase: column 19, rows **14, 15, 16**. This is the gap the
   seam uses; it must be these rows because the vault's gap will be too
   (§9.1).
3. **Spikes**, `hazard`: row 16, columns 16–17 — the cells **above** the
   floor, never the floor itself (§3). Two tiles of spikes just inside the
   door: a running jump clears them, a walking one doesn't, which is the
   analog walk/run in one obstacle.
4. **Pool**: erase the floor at row 17, columns 11–13, and paint `water`
   there instead. Then `ramp_l` at row 17 column 10 and `ramp_r` at row
   17 column 14 — the ramps are the way **out**. Row 18 under all of it
   stays solid (ramps need fill beneath). Why ramps: at the current swim
   numbers the body centre leaves the water about 10 px short of a floor
   at surface level, so a pool whose banks are plain floor is a trap.
   Walk down one ramp, swim, walk up the other.
5. **Step and shelf**: `solid` at row 16 column 8 (a one-tile step), then
   `oneway` at row 15 columns 3–7 (a shelf one tile higher). One-tile
   steps, because a jump clears about two tiles and two is the limit
   (§3). Jump onto the step, then up *through* the shelf; down + jump
   drops you back through; standing under it is fine, the lip is 8 px.
6. **Secret**: `solid` at rows 11–12 columns 1–3 (a roof), `solid` at row
   15 columns 1–2 (a floor — solid, not one-way, or the shelf would be a
   back door into the alcove), and `breakable` at rows 13–14 column 3
   (the face). The alcove is columns 1–2, rows 13–14. Stand on the shelf
   and swing left to open it; put something worth finding in it later (a
   pickup under `Objects`, §7).

With `preview_skin` on and `skin` on `greybox` nothing is drawn yet; set
`skin` to `cave_roots` for a moment and the ground autotiles under your
cursor and the pool turns teal. If a cell stays a flat rect, it is a kind
the skin doesn't map (`hazard` — expected everywhere) or a shape the pack
can't edge. Note the ramps draw as full blocks in art view (§5.1); the
greybox view shows the wedges.

### 9.5 The entry

Select `Entries/main`. Move it to **`(592, 544)`** — column 18.5, feet on
row 17, just inside the doorway and clear of the spikes — and set
`facing` to `left`. This is where F4, a new game pointed here, and any
teleport without a better entry will land. The foot-line gizmo should sit
exactly on the floor's top edge.

### 9.6 The door, both sides

**This side.** Select `Exits` → *Add Child Node* → `RoomExit`. Set
`position` to **`(608, 448)`** (column 19, row 14), `w` 1, `h` 3,
`direction` **right**, `to_room` `test_vault`, `to_entry` **empty** (a
seam). The gizmo rect should cover the three erased cells exactly, with
no tick line.

**The other side.** Open `game/rooms/test/test_vault.tscn`. Select its
`Collision` and erase column 0, rows **14, 15, 16** — the vault's left
wall, same rows as ours. Then under its `Exits` add a `RoomExit` at
**`(0, 448)`**, `w` 1, `h` 3, `direction` **left**, `to_room`
`test_reliquary`, `to_entry` empty. Save both scenes.

The vault's existing floor at row 17 and ours line up because both rooms
sit at `world_y = −14` and both floors are at local row 17 — that is the
whole alignment rule, and it was decided in §9.1, not here.

### 9.7 Skin and darkness

Back on our root, set `skin` to **`cave_roots`** to match the vault, or
`stone_pale` for contrast. Pick an existing skin before authoring a new
one (§5.1). Everything in this step is paint and can change any time.

### 9.8 Objects (optional, when they exist)

Select `Objects` → *Instantiate Child Scene* → `game/objects/pickup.tscn`
into the alcove at `(64, 480)` (between columns 1 and 2, feet on the
alcove floor at row 15) and give it an item and a flag per §7.1. Numbers live in `data/objects.json`; the
instance only knows where it is.

### 9.9 Build the registry, test, play

Save, then **Project → Tools → Rebuild Room Registry**. The Output panel
prints `rooms.json rebuilt: 6 rooms, 0 problems`, or lists what is wrong
(§9.10). The same thing headless, which is what CI will run:

```bash
godot --headless --path . -s res://tools/build_room_registry.gd
godot --headless --path . res://tests/test_boot.tscn
```

To play: with the room open, press **F6** (Run Current Scene). The room
hands over to `main.tscn` (`game/debug_boot.gd`), which skips the menus,
starts a fresh run with **every item at a full stack**, and loads the
room at its `test_entry` (empty = first entry); dying respawns there.
From a shell, the same thing is
`godot --path . -- --room test_reliquary [--entry main]`. No save slot is
picked, so a save shrine writes to slot 1. The long way also works:
`godot --path .`, start a new game, press **F4** until the toast
says `debug: → test_reliquary`. Walk right through the door into the
vault and back (if you fall on arrival, read the seam note in §4.2 — it is
the arrival nudge, not your room). Then toggle **F2**: the kinds appear
faded over the art, hitboxes and the exit rect draw, and any cell drawn as
a flat rect is one the skin couldn't dress.

Finally, commit **both scenes and the registry**:

```bash
git add game/rooms/test/test_reliquary.tscn game/rooms/test/test_vault.tscn data/rooms.json
```

### 9.10 When the registry won't build

Every one of these is deliberate — the house rule is that missing data is
a hard error, never a silent default. The build exits 1 on any line that
doesn't start with `warning:`.

| Message | What happened |
|---|---|
| `<room>: world_x/world_y unset` | Still at the sentinel. The *New Room…* dialog sets them; a hand-copied template doesn't. |
| `<room>: Collision layer has no painted cells` | Nothing painted, or painted on `DecorBack` by mistake. |
| `<room>: no RoomEntry — nothing can spawn the player here` | `Entries` is empty or its children aren't `RoomEntry`. |
| `<room>: an exit has no to_room` | Pick a target. |
| `<room>: exit leads to unknown room '<x>'` | Typo, or the scene isn't under `game/rooms/`. |
| `<room>: exit → <x> names entry '<id>', which does not exist` | Teleport to an entry id the target doesn't have. |
| `<room>: seam exit → <x> does not touch that room on the world grid (exit at …; room at …)` | The rects don't abut. Fix `world_x`/`world_y`, or make it a `to_entry` teleport. The message prints both rectangles in world tiles. |
| `<room>: exit → <x> has no exit back (wire both ways, or use a to_entry teleport for a one-way drop)` | You wired one direction only. |
| `warning: <a> and <b> overlap on the world grid by W×H tiles` | Two painted rects share more than a 1-tile strip. Legal (secret alcoves) and usually a mistake. Doesn't fail the build. |
| `rooms: <path> root is not a Room` | A `.tscn` under `game/rooms/` whose root lacks the script. Move it or fix it. |
| `rooms: <path> root node is named '<n>' — should match the file stem` | Rename the root; the stem is the id everywhere. |

Before you ask why it won't build, **look at the scene tree**. `Room`,
`RoomExit` and `RoomEntry` raise configuration warnings for unset grid
positions, empty Collision, wrong children, dead `to_room`s, empty entry
ids and malformed `locked_by`. A clean tree and a failed build is rare; a
triangle you scrolled past is the usual answer.

And the ones no build catches, because they aren't errors:

| Symptom | Cause |
|---|---|
| You walk through a seam and arrive inside a wall | The doorway rows don't line up. The validator checks adjacency, not rows (§4.2). |
| You walk through a seam and bounce straight back | `direction` is wrong on one side — the nudge sent you back into the exit you came from. |
| A whole room is flat grey in play | Unknown `skin` name (warned in the console), or the skin has no `tileset`. |
| A few cells are flat grey in play | Kinds the skin doesn't map (`hazard` always; `water` outside `cave_roots`/`jungle_ruins`) or shapes the pack can't edge. The console prints a count. |
| An exit's `to_room` warning is red but the build is green | The exit's dropdown only scans two folders (§4.2 note). Believe the build. |
| `rooms.json is stale (missing '<room>') — rebuilding in memory` at boot | You added a scene and skipped the rebuild. The game still runs; rebuild and commit. |
| The music stutters at a seam | The two rooms name different tracks. Same name = no crossfade. |
| F4 lands the player in mid-air or inside a wall | The first `RoomEntry` isn't on the floor. F4 uses the *first* entry under `Entries`. |
