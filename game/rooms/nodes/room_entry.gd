@tool
@icon("res://game/rooms/nodes/icons/room_point.svg")
class_name RoomEntry
extends RoomMarker
## Where the player arrives. Child of the room's `Entries` node. Position
## is FEET. `id` is what another room's RoomExit (or a save) names;
## "main" is the conventional first entry.

@export var id: String = "main":
	set(v):
		id = v
		_refresh()
## 1 faces right, -1 faces left on arrival.
@export_enum("right:1", "left:-1") var facing: int = 1


func _gizmo_color() -> Color:
	return Color(0.55, 1.0, 0.6)


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if id.strip_edges() == "":
		out.append("Entry id is empty — exits can't name it.")
	return out


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	_draw_feet()
	draw_string(ThemeDB.fallback_font, Vector2(6, -Room.TILE * 1.4), "entry: " + id,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, _gizmo_color())
