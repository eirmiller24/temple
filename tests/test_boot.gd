extends Node
## Boot smoke test: autoloads load their data, a new game starts in the
## start room, every registered room loads and ticks, the player stands
## on a floor, walks, jumps, attacks, crouches, saves.
##
##   godot --headless --path . res://tests/test_boot.tscn
##
## Tests are SCENES, not `-s` scripts: a script run with -s is compiled
## before the autoloads exist, so it cannot name Data/GameState/etc.
## Exit code 1 on any failed check. Engine errors print to stderr; the
## harness (tests/run_all.sh) greps for them too.

var _fails := 0


func _ready() -> void:
	var code := await _run()
	get_tree().quit(code)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error("CHECK FAILED: " + msg)
		_fails += 1
	else:
		print("  ok: ", msg)


## Kinds of unmatched cells other than the known art gaps (water/hazard).
func _unmatched_kinds(room: Room) -> Array:
	var out := []
	if room.skin_layer == null:
		return out
	for cell in room.skin_layer.unmatched:
		var k := room.kind_at_cell(cell)
		if k != "water" and k != "hazard" and not out.has(k):
			out.append(k)
	return out


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> int:
	await get_tree().process_frame
	_check(not Data.player.is_empty(), "data/player.json loaded")
	_check(not Data.items.is_empty(), "data/items.json loaded")
	_check(not Data.sprites.is_empty(), "data/sprites.json loaded")
	_check(RoomRegistry.rooms.size() >= 1, "room registry has rooms (%d)" % RoomRegistry.rooms.size())
	var problems := RoomRegistryBuilder.validate(RoomRegistry.rooms)
	for p in problems:
		if not p.begins_with("warning:"):
			_check(false, "registry: " + p)

	var world := World.new()
	get_tree().root.add_child(world)
	await world.start_new_game()
	await _ticks(30)
	_check(world.player != null, "player spawned")
	_check(world.room != null and world.room_name == GameState.respawn_room,
			"start room is '%s'" % GameState.respawn_room)
	_check(world.player.is_on_floor(), "player landed on a floor")
	_check(world.room.skin_layer != null, "start room built a skin layer")
	_check(_unmatched_kinds(world.room).is_empty(),
			"start room skin covers every solid/oneway cell (unmatched kinds: %s)" % str(_unmatched_kinds(world.room)))

	# Walk right for a second (from the open floor, away from the push block
	# that sits beside the start).
	world.player.spawn_at(world.room.global_position + Vector2(32.5, 17) * Room.TILE, 1)
	await _ticks(5)
	var x0 := world.player.global_position.x
	Input.action_press("move_right", 1.0)
	await _ticks(60)
	Input.action_release("move_right")
	_check(world.player.global_position.x > x0 + 50.0, "player ran right (%.0f px)" % (world.player.global_position.x - x0))

	# Jump.
	var y0 := world.player.global_position.y
	Input.action_press("jump")
	await _ticks(12)
	Input.action_release("jump")
	_check(world.player.global_position.y < y0 - 20.0, "player jumped")
	await _ticks(60)

	# Attack and item use don't error.
	Input.action_press("attack")
	await _ticks(2)
	Input.action_release("attack")
	await _ticks(30)
	Input.action_press("item_x")
	await _ticks(2)
	Input.action_release("item_x")
	await _ticks(30)
	Input.action_press("crouch")
	await _ticks(10)
	_check(world.player.state == Player.State.CROUCH, "crouch button crouches")
	Input.action_release("crouch")
	await _ticks(10)

	# Load every room (teleport to its first entry) and tick it.
	var names := RoomRegistry.rooms.keys()
	names.sort()
	for n in names:
		await world.load_room(n, "")
		await _ticks(20)
		_check(world.room_name == n and world.room != null, "room '%s' loads and ticks" % n)
		var unmatched := world.room.skin_layer.unmatched.size() if world.room.skin_layer != null else 0
		if unmatched > 0:
			print("  note: room '%s' has %d greybox-fallback cells (kinds without art)" % [n, unmatched])

	# Save / load round trip.
	SaveManager.save_game(2)
	var info := SaveManager.slot_info(2)
	_check(info.exists and info.room == GameState.respawn_room, "save slot 2 round-trips")
	SaveManager.delete_slot(2)

	world.queue_free()
	await get_tree().process_frame
	print("test_boot: %d failures" % _fails)
	return 1 if _fails > 0 else 0
