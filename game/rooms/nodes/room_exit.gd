@tool
@icon("res://game/rooms/nodes/icons/room_exit.svg")
class_name RoomExit
extends Area2D
## A doorway: a tile-aligned rect that sends the player to `to_room`.
## Child of the room's `Exits` node.
##
## Two ways to arrive, picked by `to_entry`:
##   ""        SEAM — the player keeps its world position. Requires the
##             two rooms to line up on the world grid (the registry
##             validator checks that the neighbour's painted rect touches
##             this exit). This is the normal metroidvania door.
##   "<id>"    TELEPORT — the player is placed at that RoomEntry in the
##             target room (stairs, pits, one-way drops).
##
## Position snaps to whole tiles; the gizmo draws the snapped footprint.

const LAYER_ROOM_EXIT := 1 << 13
const MASK_PLAYER := 1 << 1

## Scene name of the target room (file stem under game/rooms/).
@export var to_room: String = "":
	set(v):
		to_room = v
		_refresh()
## RoomEntry id in the target room, or "" for a seam transition.
@export var to_entry: String = "":
	set(v):
		to_entry = v
		_refresh()
## Footprint in tiles.
@export var w: int = 1:
	set(v):
		w = maxi(v, 1)
		if is_inside_tree():
			_rebuild_shape()
		_refresh()
@export var h: int = 3:
	set(v):
		h = maxi(v, 1)
		if is_inside_tree():
			_rebuild_shape()
		_refresh()
## Which way the player travels through this exit (used for seam
## transitions to nudge the player past the doorway and for the map).
@export_enum("right", "left", "up", "down") var direction: String = "right"
## "" = always open; "flag:<name>" needs a permanent flag; "item:<id>" needs
## an item (a locked door is a LockedDoor object in front of the exit).
@export var locked_by: String = ""

var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = LAYER_ROOM_EXIT
	collision_mask = MASK_PLAYER
	monitoring = not Engine.is_editor_hint()
	monitorable = false
	set_notify_transform(true)
	_rebuild_shape()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree():
		if Engine.is_editor_hint():
			_rebuild_shape()
			queue_redraw()


## Snapped tile origin (local tiles of the room).
func tile_origin() -> Vector2i:
	return Vector2i(roundi(position.x / Room.TILE), roundi(position.y / Room.TILE))


func rect_tiles() -> Rect2i:
	return Rect2i(tile_origin(), Vector2i(w, h))


## The trigger shape is built at runtime/in-editor and never saved (no
## owner), so the scene file holds only the authored fields.
func _rebuild_shape() -> void:
	if _shape == null:
		_shape = get_node_or_null("_Shape") as CollisionShape2D
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.name = "_Shape"
		add_child(_shape)
	var r := RectangleShape2D.new()
	r.size = Vector2(w, h) * Room.TILE
	_shape.shape = r
	var snapped := Vector2(tile_origin()) * Room.TILE - position
	_shape.position = snapped + r.size / 2.0


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("request_exit"):
		body.request_exit(self)


func is_open() -> bool:
	if locked_by == "":
		return true
	var state := Game.state()
	if state == null:
		return true
	if locked_by.begins_with("flag:"):
		return state.has_flag(locked_by.trim_prefix("flag:"))
	if locked_by.begins_with("item:"):
		return state.has_item(locked_by.trim_prefix("item:"))
	return false


func _refresh() -> void:
	update_configuration_warnings()
	queue_redraw()


func _validate_property(property: Dictionary) -> void:
	if property.name == "to_room":
		var names := _room_names()
		if not names.is_empty():
			property.hint = PROPERTY_HINT_ENUM_SUGGESTION
			property.hint_string = ",".join(names)


static func _room_names() -> PackedStringArray:
	return RoomRegistryBuilder.scene_stems()


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if to_room == "":
		out.append("to_room is unset — this exit leads nowhere.")
	elif not _room_names().has(to_room):
		out.append("to_room '%s' is not a scene under game/rooms/." % to_room)
	if locked_by != "" and not (locked_by.begins_with("flag:") or locked_by.begins_with("item:")):
		out.append("locked_by must be 'flag:<name>' or 'item:<id>'.")
	return out


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var c := Color(1.0, 0.83, 0.48) if locked_by == "" else Color(1.0, 0.45, 0.45)
	var origin := Vector2(tile_origin()) * Room.TILE - position
	var r := Rect2(origin, Vector2(w, h) * Room.TILE)
	draw_rect(r, Color(c.r, c.g, c.b, 0.18), true)
	draw_rect(r, c, false, 2.0)
	# Tick from the node to the snapped rect so rounding is visible.
	draw_line(Vector2.ZERO, origin, Color(c.r, c.g, c.b, 0.6), 1.0)
	var label := "→ %s" % (to_room if to_room != "" else "?")
	if to_entry != "":
		label += " @" + to_entry
	draw_string(ThemeDB.fallback_font, origin + Vector2(2, -4), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)
