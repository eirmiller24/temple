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


## Kind string of the Collision cell at a local pixel position ("" if empty).
func kind_at(local_px: Vector2) -> String:
	if collision == null:
		return ""
	var cell := collision.local_to_map(local_px)
	var td := collision.get_cell_tile_data(cell)
	if td == null:
		return ""
	return String(td.get_custom_data("kind"))


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
	Game.music().play_track(music)


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
	match property.name:
		"skin":
			hint = "none," + _json_keys("res://data/skins.json", "")
		"background":
			hint = _json_keys("res://data/backgrounds.json", "")
		"music":
			hint = _json_keys("res://data/music.json", "tracks")
		_:
			return
	if hint != "":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = hint


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
