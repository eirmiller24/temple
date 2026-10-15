extends Node
## Puzzle state survives leaving a room and coming back, and survives a
## save/load: a push block parked on a plate stays there (anywhere else it
## resets), a lever stays on OR off, and the gates they drive arrive
## already in the matching position instead of sliding there. Gates are
## solid lowered, raised and mid-slide.
##
##   godot --headless --path . res://tests/test_room_state.tscn

const HALL := "test_entry_hall"

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


func _obj(name: String) -> Node:
	return world.room.get_node_or_null("Objects/" + name)


func _clear_enemies() -> void:
	var enemies := world.room.get_node_or_null("Enemies")
	if enemies != null:
		for e in enemies.get_children():
			e.queue_free()


## Leave for the shaft and come back by the hall's main entry.
func _reenter() -> void:
	await world.load_room("test_shaft", "")
	await _ticks(10)
	await world.load_room(HALL, "main")
	_clear_enemies()


## A gate whose slab is already where its state says (snapped, not sliding).
func _settled(g: Gate, open: bool) -> bool:
	return g.is_open == open and is_equal_approx(g._body.position.y, -g.h * Room.TILE if open else 0.0)


## Does the world layer have the gate's slab at `y` px above the gate's feet?
func _solid(g: Gate, y: float) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = g.global_position + Vector2(0, -y)
	q.collision_mask = 1
	for hit in get_viewport().world_2d.direct_space_state.intersect_point(q):
		if hit.collider == g._body:
			return true
	return false


func _hit(lever: Lever) -> void:
	lever._cooldown = 0.0
	lever.take_hit({"damage": 1, "knockback": Vector2.ZERO, "source": null, "origin": Vector2.ZERO, "kind": "melee", "tier": 0, "hitstop": 0.0})


func _run() -> int:
	await get_tree().process_frame
	world = World.new()
	get_tree().root.add_child(world)
	await world.start_new_game()
	await _ticks(10)
	_clear_enemies()

	var home: Vector2 = (_obj("block") as Node2D).position
	_check(not (_obj("plate") as FloorButton).pressed and not (_obj("shelf_lever") as Lever).on,
			"fresh hall: plate up, lever off")
	_check(_settled(_obj("exit_gate"), false) and _settled(_obj("shelf_gate"), true),
			"fresh hall: exit gate closed, inverted shelf gate open")
	var shelf: Gate = _obj("shelf_gate")
	var span := shelf.h * Room.TILE
	_check(_solid(shelf, span * 1.5) and not _solid(shelf, span * 0.5),
			"a raised gate is solid where it hangs, and clear beneath")
	_check(_solid(_obj("exit_gate"), span * 0.5), "a lowered gate is solid")

	# --- block on the plate + lever on, then leave ------------------------------
	var block: PushBlock = _obj("block")
	block.global_position = (_obj("plate") as Node2D).global_position + Vector2(0, -2)
	_hit(_obj("shelf_lever"))
	await _ticks(20)
	_check((_obj("plate") as FloorButton).pressed and (_obj("shelf_lever") as Lever).on, "block weighs the plate, lever is on")
	var moving: Gate = _obj("exit_gate")
	var mid := -moving._body.position.y
	_check(mid > 4.0 and mid < span - 4.0 and _solid(moving, mid + span * 0.5),
			"a gate is solid mid-slide (%.0f px up)" % mid)
	var left_at: Vector2 = block.position
	await _reenter()
	# Within the settle window: the gates must already be in place, no slide.
	await _ticks(Wiring.SETTLE_FRAMES + 1)
	_check((_obj("block") as Node2D).position.distance_to(left_at) < 2.0,
			"the block is where it was left (%s, left at %s)" % [(_obj("block") as Node2D).position, left_at])
	_check((_obj("plate") as FloorButton).pressed, "the restored block presses the plate again")
	_check((_obj("shelf_lever") as Lever).on, "the lever is still on")
	_check(_settled(_obj("exit_gate"), true), "exit gate arrives already open")
	_check(_settled(_obj("shelf_gate"), false), "shelf gate arrives already closed")

	# --- lever back off, block pushed somewhere that isn't a key spot ------------------
	_hit(_obj("shelf_lever"))
	(_obj("block") as Node2D).position = home + Vector2(-2 * Room.TILE, 0)
	await _ticks(20)
	_check(not (_obj("plate") as FloorButton).pressed and not (_obj("shelf_lever") as Lever).on, "block moved off, lever off")
	_check(GameState.object_state(HALL, "Objects/block") == null, "a block off its key spot forgets its saved position")
	_check(GameState.has_flag("hall_shelf_lever"), "the lever's flag stays set once it has been pulled")
	await _reenter()
	await _ticks(Wiring.SETTLE_FRAMES + 1)
	_check((_obj("block") as Node2D).position.distance_to(home) < 2.0,
			"a block left anywhere but a key spot resets to its authored place")
	_check(not (_obj("shelf_lever") as Lever).on, "the lever stays OFF despite its flag")
	_check(not (_obj("plate") as FloorButton).pressed, "the plate stays up")
	_check(_settled(_obj("exit_gate"), false) and _settled(_obj("shelf_gate"), true),
			"exit gate closed, shelf gate open, as left")

	# --- through a save file ---------------------------------------------------------
	(_obj("block") as Node2D).global_position = (_obj("plate") as Node2D).global_position + Vector2(0, -2)
	_hit(_obj("shelf_lever"))
	await _ticks(20)
	# The same path SaveManager takes, minus the disk (don't touch real slots).
	var text := JSON.stringify(GameState.to_dict())
	GameState.new_game()
	_check(GameState.object_state(HALL, "Objects/shelf_lever") == null, "new_game() clears object state")
	GameState.from_dict(JSON.parse_string(text))
	await world.load_room(HALL, "main")
	_clear_enemies()
	await _ticks(Wiring.SETTLE_FRAMES + 1)
	_check((_obj("plate") as FloorButton).pressed and (_obj("shelf_lever") as Lever).on,
			"after a save/load the block is on the plate and the lever is on")
	_check(_settled(_obj("exit_gate"), true) and _settled(_obj("shelf_gate"), false),
			"and both gates match")

	world.queue_free()
	await get_tree().process_frame
	print("test_room_state: %d failures" % _fails)
	return 1 if _fails > 0 else 0
