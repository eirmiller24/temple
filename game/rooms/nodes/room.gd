@tool
@icon("res://game/rooms/nodes/icons/room.svg")
class_name Room
extends Node2D
## The root of a room scene (docs/room_authoring.md §2). Rooms are
## hand-authored in the editor and ARE the runtime scene — there is no
## export step and nothing ever generates a .tscn.
##
## The one rule: playable truth is the `Collision` TileMapLayer (painted
## with game/rooms/tileset_kind.tres); everything else is paint. The kind
## tileset carries the physics shapes, so the cells you paint are the
## cells the player collides with, and the runtime SkinLayer auto-tiles
## the room's `skin` art over them. Hand-painted `DecorBack`/`DecorFront`
## layers and `Props` draw around that.
##
## World grid: every room has a world_x/world_y in tiles. At runtime the
## root is placed at (world_x, world_y) * TILE, so neighbouring rooms line
## up seamlessly and the map is drawn from real geometry (design §12).
## Local tile (tx, ty) lives at world tile (world_x + tx, world_y + ty).

const TILE := 32
const UNSET := -99999
## Seam exits get a runtime collision apron this many tiles past the room
## edge (see _build_seam_aprons); must exceed RoomExit.OUTSIDE_TILES.
const APRON_TILES := 3
## Rows/columns of edge geometry copied either side of a seam's span.
const APRON_MARGIN := 2
const APRON_SOLID := ["solid", "fortified", "breakable", "ramp_r", "ramp_l"]

@export_group("Identity")
## Shown on the map and the save slot. Defaults to the scene name.
@export var display_name: String = ""

@export_group("World grid")
## Position of this room's local tile (0, 0) on the shared world grid, in
## tiles. Required: the export registry and the map refuse a room without
## one. Neighbouring rooms must line up — see RoomExit.
@export var world_x: int = UNSET:
	set(v):
		world_x = v
		update_configuration_warnings()
		queue_redraw()
@export var world_y: int = UNSET:
	set(v):
		world_y = v
		update_configuration_warnings()
		queue_redraw()

@export_group("Look")
## data/skins.json entry that auto-tiles the Collision layer at runtime.
## "none" draws no skin (hand-painted rooms); "greybox" draws flat rects.
@export var skin: String = "greybox":
	set(v):
		skin = v
		_preview_dirty = true
## data/backgrounds.json entry: fill colour + parallax layers.
@export var background: String = "greybox"
## data/music.json track name. Carries across seams when unchanged.
@export var music: String = "silence"
## 0 = fully lit, 1 = pitch black outside light sources (design §7.5).
@export_range(0.0, 1.0, 0.01) var darkness: float = 0.0
## The colour darkness fades toward.
@export var ambient_color: Color = Color(0.04, 0.03, 0.06)

@export_group("Editor")
## Draw the skin in the editor as you paint Collision (not saved).
@export var preview_skin: bool = true:
	set(v):
		preview_skin = v
		_preview_dirty = true
## Run Current Scene (F6) starts the real game in this room with every
## item (DebugBoot). The RoomEntry id to start on; empty = the first.
@export var test_entry: String = ""

var collision: TileMapLayer
var skin_layer: SkinLayer
var greybox: GreyboxLayer
var backdrop: Backdrop
var modulate_node: CanvasModulate

var _preview_dirty := true
var _preview_hash := 0
var _preview_timer := 0.0


func _ready() -> void:
	collision = get_node_or_null("Collision") as TileMapLayer
	if Engine.is_editor_hint():
		set_process(true)
		return
	if get_tree().current_scene == self:
		# Run Current Scene (F6): hand over to Main, which loads this room
		# into a World with the player.
		DebugBoot.play_room(get_tree(), registry_name(), test_entry)
		return
	_build_runtime()


# --- geometry -----------------------------------------------------------------------

## Painted extent of the Collision layer, in local tiles.
func rect_tiles() -> Rect2i:
	if collision == null:
		collision = get_node_or_null("Collision") as TileMapLayer
	if collision == null:
		return Rect2i()
	return collision.get_used_rect()


## This room's rectangle on the world grid, in tiles.
func world_rect_tiles() -> Rect2i:
	var r := rect_tiles()
	return Rect2i(r.position + Vector2i(world_x, world_y), r.size)


## Local pixel rect of the painted room.
func rect_px() -> Rect2:
	var r := rect_tiles()
	return Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE)


func room_name() -> String:
	return display_name if display_name != "" else name


## The registry name (the scene file's stem) — what World, RoomRegistry
## and the save file call this room.
func registry_name() -> String:
	return scene_file_path.get_file().get_basename() if scene_file_path != "" else String(name)


# --- puzzle-object persistence --------------------------------------------------------

## What `node` (a push block, lever, latching button under this room) last
## stored in the save, or null if it never has. Keyed by its node path in
## the room, so renaming an object orphans its saved state.
func saved_state(node: Node) -> Variant:
	var state := Game.state()
	if state == null:
		return null
	return state.object_state(registry_name(), String(get_path_to(node)))


func store_state(node: Node, value: Variant) -> void:
	var state := Game.state()
	if state != null:
		state.set_object_state(registry_name(), String(get_path_to(node)), value)


## Kind string of the Collision cell at a local pixel position ("" if empty).
func kind_at(local_px: Vector2) -> String:
	if collision == null:
		return ""
	var cell := collision.local_to_map(local_px)
	var td := collision.get_cell_tile_data(cell)
	if td == null:
		return ""
	return String(td.get_custom_data("kind"))


## True if the Collision cell at a local pixel position has a physics
## shape (solid, ramps, breakables, one-way — not water or hazard).
func collides_at(local_px: Vector2) -> bool:
	if collision == null:
		return false
	var td := collision.get_cell_tile_data(collision.local_to_map(local_px))
	return td != null and td.get_collision_polygons_count(0) > 0


func kind_at_cell(cell: Vector2i) -> String:
	if collision == null:
		return ""
	var td := collision.get_cell_tile_data(cell)
	return "" if td == null else String(td.get_custom_data("kind"))


## Erase a Collision cell (a broken wall) and refresh the skin around it.
func erase_cell(cell: Vector2i) -> void:
	if collision == null:
		return
	collision.erase_cell(cell)
	if skin_layer != null:
		skin_layer.update_cells([cell])
	if greybox != null:
		greybox.queue_redraw()


## The RoomEntry with `id`, or an object under Objects whose node name
## is `id` and that offers spawn_position() (a save shrine). "" = the
## first entry.
func entry_node(id: String) -> Node2D:
	var entries := get_node_or_null("Entries")
	var first: RoomEntry = null
	if entries != null:
		for c in entries.get_children():
			if c is RoomEntry:
				if first == null:
					first = c
				if c.id == id:
					return c
	if id != "":
		var objects := get_node_or_null("Objects")
		if objects != null:
			var o := objects.get_node_or_null(id)
			if o != null and o.has_method("spawn_position"):
				return o
	return first if id == "" else null


# --- runtime build -----------------------------------------------------------------------

func _build_runtime() -> void:
	if collision == null:
		push_error("Room %s: no TileMapLayer named 'Collision'" % name)
		return
	# Kinds are physics + data; the flat tiles themselves are never drawn
	# in play (F2 debug view shows them).
	collision.visible = false
	collision.z_index = 0
	var data := Game.data()
	var skins: Dictionary = data.skins
	var skin_def: Dictionary = (skins.get(skin, {}) as Dictionary).duplicate()
	if not skins.has(skin) and skin != "none":
		push_warning("Room %s: unknown skin '%s' → greybox" % [name, skin])
		skin_def = (skins.get("greybox", {}) as Dictionary).duplicate()
	skin_def["_name"] = skin
	var bgs: Dictionary = data.backgrounds
	backdrop = Backdrop.new()
	backdrop.name = "Backdrop"
	backdrop.z_index = -10
	backdrop.setup(self, bgs.get(background, bgs.get("greybox", {})))
	add_child(backdrop)
	move_child(backdrop, 0)
	skin_layer = SkinLayer.new()
	skin_layer.name = "SkinLayer"
	skin_layer.z_index = -1
	add_child(skin_layer)
	skin_layer.build(collision, skin_def if skin != "none" else {})
	greybox = GreyboxLayer.new()
	greybox.name = "GreyboxLayer"
	greybox.z_index = -1
	greybox.setup(self, skin_layer)
	add_child(greybox)
	modulate_node = CanvasModulate.new()
	modulate_node.name = "Darkness"
	modulate_node.color = Color.WHITE.lerp(ambient_color, darkness)
	add_child(modulate_node)
	_spawn_breakables()
	_build_seam_aprons()
	Game.music().play_track(music)


## Only one room is loaded at a time, so the world ends at the painted
## rect: a player who steps through a seam before the transition fires (or
## turns straight back after arriving) would fall through the unloaded
## neighbour. For every seam exit, copy the edge column/row's solid cells
## APRON_TILES outward across the exit's span (± APRON_MARGIN), as plain
## StaticBody2D shapes on the world layer. One-way ledges stay one-way.
## The exit trigger reaches OUTSIDE_TILES past the edge, so it fires while
## the player is still on apron.
func _build_seam_aprons() -> void:
	var exits := get_node_or_null("Exits")
	if exits == null:
		return
	var body: StaticBody2D = null
	for e in exits.get_children():
		if not (e is RoomExit) or not (e as RoomExit).is_seam():
			continue
		var exit: RoomExit = e
		var r := exit.rect_tiles()
		var t := exit.travel()
		# [apron cell, edge cell it copies] pairs.
		var pairs: Array = []
		if t.x != 0:
			var edge_col := r.end.x - 1 if t.x > 0 else r.position.x
			for row in range(r.position.y - APRON_MARGIN, r.end.y + APRON_MARGIN):
				for i in range(1, APRON_TILES + 1):
					pairs.append([Vector2i(edge_col + i * t.x, row), Vector2i(edge_col, row)])
		else:
			var edge_row := r.end.y - 1 if t.y > 0 else r.position.y
			for col in range(r.position.x - APRON_MARGIN, r.end.x + APRON_MARGIN):
				for i in range(1, APRON_TILES + 1):
					pairs.append([Vector2i(col, edge_row + i * t.y), Vector2i(col, edge_row)])
		var painted := rect_tiles()
		for pair in pairs:
			var cell: Vector2i = pair[0]
			if painted.has_point(cell):
				continue   # never shadow the room's own cells (L-shaped rooms)
			var kind := kind_at_cell(pair[1])
			if kind == "":
				continue
			var is_oneway := kind == "oneway"
			if not is_oneway and not APRON_SOLID.has(kind):
				continue
			if body == null:
				body = StaticBody2D.new()
				body.name = "SeamAprons"
				body.collision_layer = 1 << 0
				body.collision_mask = 0
				add_child(body)
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			if is_oneway:
				rect.size = Vector2(TILE, 4)
				shape.position = Vector2(cell) * TILE + Vector2(TILE / 2.0, 2.0)
				shape.one_way_collision = true
			else:
				rect.size = Vector2(TILE, TILE)
				shape.position = Vector2(cell) * TILE + Vector2(TILE, TILE) / 2.0
			shape.shape = rect
			body.add_child(shape)


## Every breakable/fortified cell gets a BreakableTile area so attacks can
## find it; the kind cell itself keeps providing the collision until it
## is erased.
func _spawn_breakables() -> void:
	var holder := Node2D.new()
	holder.name = "Breakables"
	add_child(holder)
	for cell in collision.get_used_cells():
		var kind := kind_at_cell(cell)
		if kind == "breakable" or kind == "fortified":
			var b := BreakableTile.new()
			b.setup(self, cell, kind)
			holder.add_child(b)


# --- editor --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_preview_timer -= delta
	if _preview_timer > 0.0 and not _preview_dirty:
		return
	_preview_timer = 0.5
	_refresh_preview()


func _refresh_preview() -> void:
	if collision == null:
		collision = get_node_or_null("Collision") as TileMapLayer
	if collision == null:
		return
	var h := hash([collision.get_used_cells(), collision.tile_map_data, skin, preview_skin])
	if h == _preview_hash and not _preview_dirty:
		return
	_preview_hash = h
	_preview_dirty = false
	var existing := get_node_or_null("_SkinPreview")
	if existing != null:
		existing.queue_free()
	collision.modulate = Color(1, 1, 1, 1)
	if not preview_skin:
		update_configuration_warnings()
		queue_redraw()
		return
	var skins := _read_json("res://data/skins.json")
	var skin_def: Dictionary = skins.get(skin, {})
	if skin_def.has("tileset"):
		var layer := SkinLayer.new()
		layer.name = "_SkinPreview"
		layer.z_index = -1
		add_child(layer)
		layer.build(collision, skin_def)
		# Faint kinds over the art: you see what you painted AND how it reads.
		collision.modulate = Color(1, 1, 1, 0.35)
	update_configuration_warnings()
	queue_redraw()


func _validate_property(property: Dictionary) -> void:
	var hint := ""
	var kind := PROPERTY_HINT_ENUM
	match property.name:
		"skin":
			hint = "none," + _json_keys("res://data/skins.json", "")
		"background":
			hint = _json_keys("res://data/backgrounds.json", "")
		"music":
			hint = _json_keys("res://data/music.json", "tracks")
		"test_entry":
			kind = PROPERTY_HINT_ENUM_SUGGESTION
			hint = ",".join(_entry_ids())
		_:
			return
	if hint != "":
		property.hint = kind
		property.hint_string = hint


func _entry_ids() -> PackedStringArray:
	var out := PackedStringArray()
	var entries := get_node_or_null("Entries")
	if entries != null:
		for e in entries.get_children():
			if e is RoomEntry and String(e.id) != "":
				out.append(String(e.id))
	return out


func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if world_x == UNSET or world_y == UNSET:
		w.append("world_x/world_y are unset. The room has no place on the world grid, so the map and the registry refuse it.")
	var layer := get_node_or_null("Collision")
	if layer == null or not (layer is TileMapLayer):
		w.append("No TileMapLayer named 'Collision' — that layer is the room's only geometry.")
	elif (layer as TileMapLayer).get_used_cells().is_empty():
		w.append("Collision has no cells painted yet.")
	for child in get_children():
		if child.name == "Exits":
			for e in child.get_children():
				if not (e is RoomExit):
					w.append("'%s' under Exits is not a RoomExit." % e.name)
		if child.name == "Entries":
			var has := false
			for e in child.get_children():
				if e is RoomEntry:
					has = true
				else:
					w.append("'%s' under Entries is not a RoomEntry." % e.name)
			if not has:
				w.append("No RoomEntry under Entries — the player has nowhere to arrive (saves and new games need one).")
	return w


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := rect_px()
	if r.size == Vector2.ZERO:
		return
	draw_rect(r, Color(0.35, 0.8, 1.0, 0.05), true)
	draw_rect(r, Color(0.35, 0.8, 1.0, 0.6), false, 2.0)
	var label := "%s  world (%s, %s)  %dx%d tiles" % [room_name(),
			str(world_x) if world_x != UNSET else "?",
			str(world_y) if world_y != UNSET else "?",
			rect_tiles().size.x, rect_tiles().size.y]
	draw_string(ThemeDB.fallback_font, r.position + Vector2(4, -6), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.9, 1.0))


# --- edit-time data helpers (no autoloads in the editor) ---------------------------------

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func _json_keys(path: String, subkey: String) -> String:
	var d := _read_json(path)
	if subkey != "":
		d = d.get(subkey, {})
	var keys := d.keys()
	keys.sort()
	var out := PackedStringArray()
	for k in keys:
		if String(k).begins_with("_"):
			continue
		out.append(String(k))
	return ",".join(out)
