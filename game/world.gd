class_name World
extends Node2D
## Owns the current room and the player. Rooms are separate scenes placed
## at their world-grid offset; the player is a sibling of the room so it
## survives room swaps. Transitions: an exit volume asks for one, the
## screen fades, the neighbour loads, the player either keeps its world
## position (seam) or lands on a named entry (teleport).

signal room_changed(room_name: String)

const PLAYER_SCENE := "res://game/player/player.tscn"
const FADE_TIME := 0.18

var player: Player
var room: Room
var room_name := ""
var hud: CanvasLayer
var _fade: ColorRect
var _fade_layer: CanvasLayer
var _transitioning := false
var _toast: Label
var _toast_time := 0.0
var debug_view := false
## Where the player came into the current room: {pos, facing}. A void-out
## reloads the room and puts them back here.
var _arrival := {}


func _ready() -> void:
	add_to_group("world")
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 50
	_fade_layer.name = "FadeLayer"
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)
	_toast = Label.new()
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 0.82
	_toast.anchor_bottom = 0.82
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	_toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_toast.add_theme_constant_override("shadow_offset_x", 1)
	_toast.add_theme_constant_override("shadow_offset_y", 1)
	_toast.visible = false
	_fade_layer.add_child(_toast)
	GameState.died.connect(func() -> void: pass)


func _process(delta: float) -> void:
	_debug_keys()
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			_toast.visible = false
	if player != null and player.camera != null:
		player.camera.offset = Juice.shake_offset()


## Debug keys are polled (not _unhandled_input) so they also work when
## driven by Input.action_press from a test or a scripted sequence.
func _debug_keys() -> void:
	if Input.is_action_just_pressed("debug_view"):
		debug_view = not debug_view
		_apply_debug_view()
	elif Input.is_action_just_pressed("debug_reload"):
		Data.reload()
		toast("data reloaded")
	elif Input.is_action_just_pressed("debug_rooms"):
		_debug_jump_room()


# --- starting --------------------------------------------------------------------------------

func start_new_game(start_key: String = "start") -> void:
	GameState.new_game(start_key)
	await load_room(GameState.respawn_room, GameState.respawn_entry)


func continue_game() -> void:
	await load_room(GameState.respawn_room, GameState.respawn_entry)


func _ensure_player() -> void:
	if player != null:
		return
	player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.name = "Player"
	add_child(player)


# --- room loading -----------------------------------------------------------------------------

## Load `name`; arrive at `entry_id` (teleport) or keep the world position
## (seam) when `seam_exit` is given, or land exactly on `arrive`
## ({pos, facing}, a void-out going back to the last entrance).
func load_room(name: String, entry_id: String = "", seam_exit: RoomExit = null, arrive: Dictionary = {}) -> void:
	var path := RoomRegistry.scene_path(name)
	if path == "":
		push_error("World: no room scene named '%s'" % name)
		return
	_ensure_player()
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("World: cannot load %s" % path)
		return
	var keep_pos := seam_exit != null and arrive.is_empty()
	var prev_pos := player.global_position
	var prev_facing := player.facing
	var travel := Vector2.ZERO
	if seam_exit != null:
		match seam_exit.direction:
			"right": travel = Vector2.RIGHT
			"left": travel = Vector2.LEFT
			"up": travel = Vector2.UP
			"down": travel = Vector2.DOWN
	if room != null:
		remove_child(room)
		room.queue_free()
		room = null
	Wiring.reset()
	room = packed.instantiate()
	room_name = name
	room.position = Vector2(room.world_x, room.world_y) * Room.TILE
	add_child(room)
	move_child(room, 0)
	player.room = room
	if not arrive.is_empty():
		player.spawn_at(arrive.pos, arrive.facing)
		player.lock_exits(0.4)
	elif keep_pos:
		# Keep the world position along the seam; along the travel axis,
		# land just clear of the new room's matching exit trigger (the one
		# that leads back), body fully inside the painted rect. That way
		# nothing is locked for long: turning straight around re-enters the
		# trigger and goes back, and standing still stays put. The fade is
		# still black while this happens, so the shift is invisible.
		var pos := prev_pos
		var r := room.rect_px()
		var inset := Room.TILE * 0.5
		var lo := room.position + r.position + Vector2(inset, inset)
		var hi := room.position + r.end - Vector2(inset, 0.0)
		if travel.x != 0.0:
			pos.x = clampf(pos.x, lo.x, hi.x)
		if travel.y != 0.0:
			pos.y = clampf(pos.y, lo.y, hi.y)
		pos = _clear_of_arrival_exit(pos, travel)
		player.global_position = pos
		player.facing = prev_facing
		player.lock_exits(FADE_TIME + 0.05)
		player.camera.reset_smoothing()
	else:
		var entry := room.entry_node(entry_id)
		if entry == null:
			entry = room.entry_node("")
			if entry != null:
				push_warning("World: room '%s' has no entry '%s' — using the first" % [name, entry_id])
		if entry == null:
			push_error("World: room '%s' has no RoomEntry (wanted '%s')" % [name, entry_id])
			player.spawn_at(room.global_position + room.rect_px().get_center())
		else:
			var face := int(entry.facing) if entry is RoomEntry else player.facing
			var pos: Vector2 = entry.spawn_position() if entry.has_method("spawn_position") else entry.global_position
			player.spawn_at(pos, face)
			player.lock_exits(0.4)
	_arrival = {"pos": player.global_position, "facing": player.facing}
	_apply_camera_limits()
	_apply_debug_view()
	GameState.visit(name)
	room_changed.emit(name)
	await _fade_to(0.0)


## Push a seam arrival position past the inner edge of the exit the
## player just came through from the other side (the new room's exit whose
## direction opposes `travel` and whose trigger spans the arrival point).
## Falls back to 1.5 tiles inside the painted rect when no exit matches.
func _clear_of_arrival_exit(pos: Vector2, travel: Vector2) -> Vector2:
	const MARGIN := 3.0
	var half_w: float = player.body_width() / 2.0
	var height: float = player.body_height()
	var back := Vector2i(-int(travel.x), -int(travel.y))
	var best: RoomExit = null
	var best_d := INF
	var exits := room.get_node_or_null("Exits")
	if exits != null:
		for e in exits.get_children():
			if not (e is RoomExit) or not (e as RoomExit).is_seam() or (e as RoomExit).travel() != back:
				continue
			var tr: Rect2i = (e as RoomExit).trigger_rect_tiles()
			var wr := Rect2(room.position + Vector2(tr.position) * Room.TILE, Vector2(tr.size) * Room.TILE)
			# Distance along the seam axis from the arrival point to the trigger.
			var d := 0.0
			if travel.x != 0.0:
				d = maxf(0.0, maxf(wr.position.y - pos.y, (pos.y - height) - wr.end.y))
			else:
				d = maxf(0.0, maxf(wr.position.x - (pos.x + half_w), (pos.x - half_w) - wr.end.x))
			if d < best_d:
				best_d = d
				best = e
	if best == null:
		var r := room.rect_px()
		var inset := Room.TILE * 1.5
		if travel.x != 0.0:
			pos.x = clampf(pos.x, room.position.x + r.position.x + inset, room.position.x + r.end.x - inset)
		else:
			pos.y = clampf(pos.y, room.position.y + r.position.y + inset, room.position.y + r.end.y - inset)
		return pos
	var inner := Rect2i(best.rect_tiles())
	var zone := Rect2(room.position + Vector2(inner.position) * Room.TILE, Vector2(inner.size) * Room.TILE)
	if travel.x > 0.0:
		pos.x = maxf(pos.x, zone.end.x + half_w + MARGIN)
	elif travel.x < 0.0:
		pos.x = minf(pos.x, zone.position.x - half_w - MARGIN)
	elif travel.y > 0.0:
		pos.y = maxf(pos.y, zone.end.y + height + MARGIN)
	else:
		pos.y = minf(pos.y, zone.position.y - MARGIN)
	return pos


func _apply_camera_limits() -> void:
	if player == null or room == null:
		return
	var r := room.rect_px()
	var cam := player.camera
	cam.limit_left = int(room.position.x + r.position.x)
	cam.limit_top = int(room.position.y + r.position.y)
	cam.limit_right = int(room.position.x + r.end.x)
	cam.limit_bottom = int(room.position.y + r.end.y)
	# Rooms smaller than the viewport: centre on the room instead of clamping.
	var view := get_viewport_rect().size
	if r.size.x < view.x:
		var cx := int(room.position.x + r.get_center().x)
		cam.limit_left = cx - int(view.x / 2)
		cam.limit_right = cx + int(view.x / 2)
	if r.size.y < view.y:
		var cy := int(room.position.y + r.get_center().y)
		cam.limit_top = cy - int(view.y / 2)
		cam.limit_bottom = cy + int(view.y / 2)


func transition(exit: RoomExit) -> void:
	if _transitioning:
		return
	if not RoomRegistry.has_room(exit.to_room) and RoomRegistry.scene_path(exit.to_room) == "":
		toast("Exit leads to unknown room '%s'" % exit.to_room)
		player.lock_exits(1.0)
		return
	_transitioning = true
	get_tree().paused = true
	await _fade_to(1.0)
	get_tree().paused = false
	await load_room(exit.to_room, exit.to_entry, exit if exit.to_entry == "" else null)
	_transitioning = false


## Void out (e.g. a closing gate with nowhere to knock the player): fade, reload the current
## room and put the player back where they last came in. Damage, if any,
## was already dealt by whatever caused it.
func void_out() -> void:
	if _transitioning or room_name == "":
		return
	_transitioning = true
	get_tree().paused = true
	await _fade_to(1.0)
	get_tree().paused = false
	await load_room(room_name, "", null, _arrival)
	_transitioning = false


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await tween.finished


# --- death -------------------------------------------------------------------------------------

func on_player_died() -> void:
	if _transitioning:
		return
	_transitioning = true
	await get_tree().create_timer(1.3).timeout
	await _fade_to(1.0)
	GameState.full_heal()
	await load_room(GameState.respawn_room, GameState.respawn_entry)
	player.revive()
	_transitioning = false


# --- misc ---------------------------------------------------------------------------------------

func toast(text: String, seconds: float = 2.5) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_time = seconds


func _apply_debug_view() -> void:
	if room == null:
		return
	if room.greybox != null:
		room.greybox.debug_all = debug_view
	if room.skin_layer != null:
		room.skin_layer.modulate.a = 0.35 if debug_view else 1.0
	get_tree().debug_collisions_hint = debug_view
	for n in get_tree().get_nodes_in_group("debug_draw"):
		if n.has_method("set_debug"):
			n.set_debug(debug_view)


func _debug_jump_room() -> void:
	var names := RoomRegistry.rooms.keys()
	if names.is_empty():
		return
	names.sort()
	var i := names.find(room_name)
	var next: String = names[(i + 1) % names.size()]
	toast("debug: → " + next)
	_transitioning = true
	await _fade_to(1.0)
	await load_room(next, "")
	_transitioning = false
