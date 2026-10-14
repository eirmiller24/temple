extends Node
## Interactive objects and room transitions, driven through the real
## World in the test rooms: a push block weighs a plate and opens a gate,
## a lever toggles on a hit, a locked door eats a key, a pickup lands in
## the inventory, a save shrine saves and becomes the respawn point, a
## seam exit carries the player into the neighbouring room, a teleport
## exit lands on its entry, and a breakable wall breaks to an attack.
##
##   godot --headless --path . res://tests/test_objects.tscn

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


func _press(action: String, frames: int) -> void:
	Input.action_press(action)
	await _ticks(frames)
	Input.action_release(action)


func _tile(col: float, row: float) -> Vector2:
	return Vector2(col, row) * Room.TILE


func _obj(name: String) -> Node:
	return world.room.get_node_or_null("Objects/" + name)


## This test is about objects; a wandering enemy would stagger the player
## mid-check.
func _clear_enemies() -> void:
	var enemies := world.room.get_node_or_null("Enemies")
	if enemies != null:
		for e in enemies.get_children():
			e.queue_free()


func _run() -> int:
	await get_tree().process_frame
	world = World.new()
	get_tree().root.add_child(world)
	await world.start_new_game()
	await _ticks(20)
	var p := world.player
	GameState.max_hp = 60
	GameState.hp = 60
	_clear_enemies()

	# --- push block → plate → gate -------------------------------------------
	var block: PushBlock = _obj("block")
	var plate: FloorButton = _obj("plate")
	var gate: Gate = _obj("exit_gate")
	_check(block != null and plate != null and gate != null, "entry hall has block, plate and gate")
	_check(not gate.is_open and not Wiring.is_active(0), "gate starts closed")
	p.spawn_at(world.room.global_position + _tile(2.5, 14), 1)
	await _ticks(5)
	var bx0 := block.global_position.x
	await _press("move_right", 150)
	_check(block.global_position.x > bx0 + 40.0, "walking into the block pushed it (%.0f px)" % (block.global_position.x - bx0))
	_check(plate.pressed, "the block weighs the plate")
	_check(Wiring.is_active(0) and gate.is_open, "the plate opens the gate on channel 0")

	# --- lever toggles on a hit ------------------------------------------------
	var lever: Lever = _obj("shelf_lever")
	var shelf_gate: Gate = _obj("shelf_gate")
	_check(lever != null and not lever.on, "shelf lever starts off")
	_check(shelf_gate != null and shelf_gate.is_open, "inverted gate starts open")
	lever.take_hit({"damage": 1, "knockback": Vector2.ZERO, "source": null, "origin": Vector2.ZERO, "kind": "melee", "tier": 0, "hitstop": 0.0})
	await _ticks(5)
	_check(lever.on and GameState.has_flag("hall_shelf_lever"), "a hit switches the lever on and sets its flag")
	_check(not shelf_gate.is_open, "inverted gate closes while the lever drives channel 1")

	# --- pickup --------------------------------------------------------------------
	var before := GameState.count("dried_fruit")
	p.spawn_at(_obj("fruit").global_position + Vector2(-40, 0), 1)
	await _press("move_right", 40)
	_check(GameState.count("dried_fruit") == before + 1 and GameState.has_flag("hall_fruit"), "walking over the pickup collects it and sets its flag")

	# --- save shrine ------------------------------------------------------------------
	var shrine: SaveShrine = _obj("shrine_hall")
	p.spawn_at(shrine.global_position + Vector2(-10, 0), 1)
	await _ticks(5)
	await _press("interact", 3)
	await _ticks(5)
	_check(GameState.respawn_room == "test_entry_hall" and GameState.respawn_entry == "shrine_hall", "shrine sets the respawn point")
	_check(SaveManager.slot_exists(GameState.slot_index), "shrine wrote a save")
	await world.load_room(GameState.respawn_room, GameState.respawn_entry)
	await _ticks(5)
	_clear_enemies()
	_check(p.global_position.distance_to(_obj("shrine_hall").global_position) < 4.0, "respawning at the shrine lands on it")

	# --- breakable wall ---------------------------------------------------------------
	var room := world.room
	var cell := Vector2i(41, 11)
	_check(room.kind_at_cell(cell) == "breakable", "breakable patch exists at (41,11)")
	var bt: BreakableTile = null
	for b in room.get_node("Breakables").get_children():
		if b.cell == cell:
			bt = b
	_check(bt != null, "a BreakableTile was spawned for it")
	bt.take_hit({"damage": 1, "knockback": Vector2.ZERO, "source": null, "origin": Vector2.ZERO, "kind": "melee", "tier": 0, "hitstop": 0.0})
	await _ticks(3)
	_check(room.kind_at_cell(cell) == "", "a hit erases the breakable cell")

	# --- seam exit: hall → shaft -----------------------------------------------------
	Wiring.drive(0, self, true)   # hold the exit gate open for the walk
	await _ticks(2)
	_check((_obj("exit_gate") as Gate).is_open, "driving channel 0 opens the (re-spawned) gate")
	p.spawn_at(world.room.global_position + _tile(41.5, 17), 1)
	await _ticks(5)
	Input.action_press("move_right")
	var waited := 0
	while world.room_name == "test_entry_hall" and waited < 240:
		await _ticks(1)
		waited += 1
	Input.action_release("move_right")
	await _ticks(30)
	_check(world.room_name == "test_shaft", "walking through the seam exit loads test_shaft")
	_clear_enemies()
	_check(p.is_on_floor(), "player stands on the shaft floor after the seam")
	_check(p.global_position.x > 44 * Room.TILE, "player is inside the shaft's world rect (x=%.0f)" % p.global_position.x)
	var hall_rect := RoomRegistry.rect("test_entry_hall")
	_check(not hall_rect.has_point(Vector2i(int(p.global_position.x / Room.TILE), int(p.global_position.y / Room.TILE) - 1)),
			"player left the hall's rect")

	# --- teleport exit: vault pit → cistern --------------------------------------------
	await world.load_room("test_vault", "main")
	await _ticks(5)
	_clear_enemies()
	p.spawn_at(world.room.global_position + _tile(2.5, 16), 1)
	waited = 0
	while world.room_name == "test_vault" and waited < 240:
		await _ticks(1)
		waited += 1
	await _ticks(20)
	_check(world.room_name == "test_cistern", "falling into the vault pit teleports to the cistern")
	var e := RoomRegistry.entry_world_px("test_cistern", "from_vault")
	_check(not e.is_empty() and p.global_position.distance_to(e.pos) < 6.0, "teleport lands on the 'from_vault' entry")

	# --- locked door -------------------------------------------------------------------
	await world.load_room("test_vault", "main")
	await _ticks(5)
	_clear_enemies()
	var door: LockedDoor = _obj("alcove_door")
	_check(door != null and not door.is_open, "vault door starts locked")
	p.spawn_at(door.global_position + Vector2(-30, 0), 1)
	await _ticks(5)
	GameState.remove_item("small_key", 99)
	await _press("interact", 3)
	await _ticks(5)
	_check(not door.is_open, "door stays locked without a key")
	GameState.add_item("small_key", 1)
	await _press("interact", 3)
	await _ticks(40)
	_check(door.is_open and GameState.count("small_key") == 0, "a key opens the door and is consumed")
	_check(GameState.has_flag(door.flag_name()), "opening sets the door's permanent flag")

	# --- grapple anchor pulls the player ---------------------------------------------------
	await world.load_room("test_entry_hall", "main")
	await _ticks(5)
	_clear_enemies()
	var anchor: GrappleAnchor = _obj("anchor_trough")
	p.spawn_at(world.room.global_position + _tile(13.5, 16), 1)
	await _ticks(5)
	GameState.assign("x", "grapple")
	p.forced_aim = (anchor.global_position - (p.global_position + Vector2(0, -22))).normalized()
	Input.action_press("aim")
	await _ticks(2)
	await _press("item_x", 2)
	await _ticks(2)
	_check(p.state == Player.State.GRAPPLE, "grapple latched onto the anchor")
	var closest := INF
	for i in 60:
		await _ticks(1)
		closest = minf(closest, p.global_position.distance_to(anchor.global_position))
	Input.action_release("aim")
	p.forced_aim = Vector2.ZERO
	_check(closest < 40.0, "grapple pulled the player to the anchor (closest %.0f px)" % closest)

	SaveManager.delete_slot(GameState.slot_index)
	world.queue_free()
	await get_tree().process_frame
	print("test_objects: %d failures" % _fails)
	return 1 if _fails > 0 else 0
