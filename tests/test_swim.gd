extends Node
## Leaving water, in the entry hall's pool (cols 15-22, rows 15-16, banks
## level with the surface): swimming up with jump held leaps the feet
## swim_exit_jump_tiles clear of the surface, and that gets the player
## out onto the bank. Swim speed alone used to stop short of the surface,
## stranding the player in any pool.
##
##   godot --headless --path . res://tests/test_swim.tscn

var _fails := 0
var world: World


func _ready() -> void:
	var code := await _run()
	get_tree().quit(code)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error("CHECK FAILED: " + msg)
		_fails += 1
	else:
		print("  ok: ", msg)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _tile(col: float, row: float) -> Vector2:
	return world.room.global_position + Vector2(col, row) * Room.TILE


func _run() -> int:
	await get_tree().process_frame
	world = World.new()
	get_tree().root.add_child(world)
	await world.start_new_game("test_start")
	await _ticks(20)
	var p := world.player
	for e in world.room.get_node("Enemies").get_children():
		e.queue_free()
	var surface := _tile(0, 15).y
	var want := float(Data.player.swim_exit_jump_tiles) * Room.TILE

	# --- straight up with jump held: feet clear the surface by the tunable ----------
	p.spawn_at(_tile(18.5, 17), 1)
	await _ticks(30)
	_check(p.in_water, "starts in the pool")
	Input.action_press("jump")
	var top := INF
	for i in 120:
		await _ticks(1)
		top = minf(top, p.global_position.y)
	Input.action_release("jump")
	var h := surface - top
	_check(absf(h - want) < 3.0, "leap lifts the feet %.1f px above the surface (want %.0f)" % [h, want])

	# --- no jump held: just sinks, no leap ----------------------------------------
	p.spawn_at(_tile(18.5, 17), 1)
	await _ticks(30)
	top = INF
	for i in 60:
		await _ticks(1)
		top = minf(top, p.global_position.y)
	_check(top > surface, "without jump the player stays in the water")

	# --- jump + right from mid-pool: out onto the bank ---------------------------------
	p.spawn_at(_tile(18.5, 17), 1)
	await _ticks(30)
	Input.action_press("jump")
	Input.action_press("move_right")
	await _ticks(150)
	Input.action_release("jump")
	Input.action_release("move_right")
	await _ticks(20)
	_check(not p.in_water and p.is_on_floor() and p.global_position.x > _tile(23, 0).x,
			"climbs out onto the right bank (at %s)" % p.global_position)

	SaveManager.delete_slot(GameState.slot_index)
	world.queue_free()
	await get_tree().process_frame
	print("test_swim: %d failures" % _fails)
	return 1 if _fails > 0 else 0
