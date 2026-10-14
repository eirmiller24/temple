class_name UiMinimap
extends Control
## Draws RoomRegistry.rooms (world tiles → pixels at `tile_px`) for every
## room in GameState.visited plus the current one; the current room is
## highlighted, exits are marks on the room borders, and the player is a
## dot at world.player.global_position / Room.TILE. Two uses:
##   HUD   full = false: a small window clipped around the player
##   MAP   full = true:  the whole map centred on the current room, panned
##         with `pan` (tiles) by the pause menu
## Draws nothing (and never errors) when the registry is empty or there is
## no player yet.

@export var tile_px := 3.0
@export var full := false
@export var show_names := false

var world: World
var pan := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func bind(w: World) -> void:
	world = w
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if is_visible_in_tree():
		queue_redraw()


func _current_room() -> String:
	if world != null and is_instance_valid(world) and world.room_name != "":
		return world.room_name
	return GameState.current_room


func _player_tiles() -> Vector2:
	if world == null or not is_instance_valid(world) or world.player == null:
		return Vector2.INF
	return world.player.global_position / float(Room.TILE)


## The point (in world tiles) at the centre of the control.
func _centre_tiles(current: String) -> Vector2:
	var p := _player_tiles()
	if not full and p != Vector2.INF:
		return p
	var r := RoomRegistry.rect(current)
	if r.size != Vector2i.ZERO:
		return Vector2(r.position) + Vector2(r.size) / 2.0 + pan
	if p != Vector2.INF:
		return p + pan
	return pan


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG if full else UiTheme.PANEL_THIN, true)
	var rooms: Dictionary = RoomRegistry.rooms
	var current := _current_room()
	if rooms.is_empty():
		if full:
			draw_string(ThemeDB.fallback_font, Vector2(12, 24), "No map yet.", HORIZONTAL_ALIGNMENT_LEFT,
					-1, UiTheme.SIZE_LABEL, UiTheme.DIM)
		_draw_border()
		return
	var origin := size / 2.0 - _centre_tiles(current) * tile_px
	var names := rooms.keys()
	names.sort()
	for name: String in names:
		if name != current and not GameState.visited.has(name):
			continue
		_draw_room(name, rooms[name], origin, name == current)
	var p := _player_tiles()
	if p != Vector2.INF:
		var dot := (origin + p * tile_px).round()
		var pulse := 0.7 + 0.3 * sin(_time * 5.0)
		draw_circle(dot, maxf(tile_px * 0.6, 2.0), Color(UiTheme.TEXT, pulse))
	_draw_border()


func _draw_room(name: String, info: Dictionary, origin: Vector2, current: bool) -> void:
	var r := RoomRegistry.rect(name)
	if r.size == Vector2i.ZERO:
		return
	var px := Rect2(origin + Vector2(r.position) * tile_px, Vector2(r.size) * tile_px)
	var fill := Color(UiTheme.ACCENT, 0.22) if current else Color(UiTheme.DIM, 0.28)
	var border := UiTheme.ACCENT if current else UiTheme.DIM
	draw_rect(px, fill, true)
	draw_rect(px.grow(-0.5), border, false, 1.0)
	for e in info.get("exits", []):
		var er := Rect2(origin + Vector2(float(e.x), float(e.y)) * tile_px,
				Vector2(float(e.w), float(e.h)) * tile_px)
		# A doorway is a notch in the wall: fill it with the floor colour and
		# mark it with a short accent bar.
		draw_rect(er, UiTheme.BG, true)
		draw_rect(er, Color(UiTheme.ACCENT, 0.8 if current else 0.5), true)
	if show_names and px.size.x > 48.0 and px.size.y > 18.0:
		var label := String(info.get("display_name", name))
		draw_string(ThemeDB.fallback_font, px.position + Vector2(4, 13), label, HORIZONTAL_ALIGNMENT_LEFT,
				px.size.x - 8.0, UiTheme.SIZE_SMALL, UiTheme.TEXT if current else UiTheme.DIM)


func _draw_border() -> void:
	draw_rect(Rect2(Vector2.ZERO, size).grow(-0.5), UiTheme.DIM, false, 1.0)
