@tool
class_name RoomMarker
extends Marker2D
## Base for point markers in a room (entries, spawn points). Position is
## FEET: bottom-centre of whatever stands here. The gizmo draws a foot
## line rather than a symmetric cross so that is never a surprise.


func _gizmo_color() -> Color:
	return Color(0.7, 0.9, 1.0)


func _refresh() -> void:
	update_configuration_warnings()
	queue_redraw()


func _draw_feet() -> void:
	var c := _gizmo_color()
	var t := float(Room.TILE)
	draw_line(Vector2(-t * 0.4, 0), Vector2(t * 0.4, 0), c, 2.0)
	draw_line(Vector2(0, 0), Vector2(0, -t * 1.4), Color(c.r, c.g, c.b, 0.5), 1.0)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	_draw_feet()
