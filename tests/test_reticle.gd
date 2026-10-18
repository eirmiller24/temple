extends Node
## The free-aim reticle, in the real entry hall: it shows only while
## aiming; it follows the last aimable item used; on the grapple it sits on
## the first thing the hook would hit and turns red (latch) on anchors and
## pullable blocks, without pulling anything; on the slingshot it sits on
## the straight aim line. Real stones stop at walls, the crate and the top
## of a one-way ledge, and spawn at the player in an offset room.
##
##   godot --headless --path . res://tests/test_reticle.tscn

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
	return world.room.global_position + Vector2(col, row) * Room.TILE


func _aim(p: Player, dir: Vector2) -> void:
	p.forced_aim = dir
	Input.action_press("aim")
	await _ticks(3)


func _unaim(p: Player) -> void:
	Input.action_release("aim")
	p.forced_aim = Vector2.ZERO
	await _ticks(2)


## Fires the slingshot along the current aim; returns {start, end}: where
## the stone was the frame it appeared and where it left the tree
## (Vector2.INF for both if no stone was spawned).
func _shoot(p: Player) -> Dictionary:
	var before := {}
	for n in world.room.get_children():
		before[n.get_instance_id()] = true
	await _press("item_x", 2)
	var stone: Projectile = null
	for n in world.room.get_children():
		if n is Projectile and not before.has(n.get_instance_id()):
			stone = n
	if stone == null:
		return {"start": Vector2.INF, "end": Vector2.INF}
	var start := stone.global_position
	var end := [Vector2.INF]
	stone.tree_exiting.connect(func() -> void: end[0] = stone.global_position)
	while is_instance_valid(stone):
		await _ticks(1)
	await _ticks(10)   # item cooldown
	return {"start": start, "end": end[0]}


## True if `at` lies on the aim line from the shot origin.
func _on_line(p: Player, at: Vector2, dir: Vector2) -> bool:
	var rel := at - (p.global_position + Player.SHOT_ORIGIN)
	return absf(rel.cross(dir)) < 1.5 and rel.dot(dir) > 0.0


func _run() -> int:
	await get_tree().process_frame
	world = World.new()
	get_tree().root.add_child(world)
	await world.start_new_game("test_start")
	await _ticks(20)
	var p := world.player
	GameState.max_hp = 60
	GameState.hp = 60
	var enemies := world.room.get_node_or_null("Enemies")
	if enemies != null:
		for e in enemies.get_children():
			e.queue_free()
	GameState.assign("x", "slingshot")
	GameState.assign("y", "grapple")

	# --- hidden unless aiming --------------------------------------------------
	p.spawn_at(_tile(13.5, 16), 1)
	await _ticks(5)
	_check(not p.reticle.visible, "no reticle without aim held")
	await _aim(p, Vector2.RIGHT)
	_check(p.reticle.visible, "reticle shows while aiming")
	_check(p._reticle_kind() == "slingshot", "defaults to slot X (slingshot)")

	# --- slingshot reticle: straight along the aim, no gravity -----------------
	var origin := p.global_position + Player.SHOT_ORIGIN
	await _aim(p, Vector2.RIGHT)
	_check(p.reticle.on_target and _on_line(p, p.reticle.global_position, Vector2.RIGHT)
			and absf(p.reticle.global_position.x - _tile(23, 0).x) < 1.5,
			"aimed right: reticle level with the shot, on the wall face (%s)" % p.reticle.global_position)
	await _aim(p, Vector2.UP)
	_check(p.reticle.on_target and absf(p.reticle.global_position.y - _tile(0, 1).y) < 1.5,
			"aimed up: through the one-way ledge to the ceiling (%s)" % p.reticle.global_position)
	var diag := Vector2(-0.4, -1).normalized()
	await _aim(p, diag)
	var reach := Data.num(Data.objects.slingshot, "speed", "") * Data.num(Data.objects.slingshot, "lifetime", "")
	var dist := p.reticle.global_position.distance_to(origin + diag * 12.0)
	_check(_on_line(p, p.reticle.global_position, diag) and (p.reticle.on_target or absf(dist - reach) < 1.5),
			"aimed up-left: on the aim line (%.0f px out)" % dist)

	# --- real stones stop at walls (they used to fly through) ----------------------
	await _aim(p, Vector2.RIGHT)
	var shot := await _shoot(p)
	_check(absf(shot.end.x - _tile(23, 0).x) < 1.5 and shot.end.y < _tile(0, 17).y,
			"stone fired right stops at the wall face (%s)" % shot.end)
	_check(shot.start.distance_to(p.global_position) < 40.0, "the stone appears at the player")
	await _aim(p, Vector2.LEFT)
	shot = await _shoot(p)
	_check(absf(shot.end.x - _tile(9, 0).x) < 1.5, "stone fired left stops at the wall face (%s)" % shot.end)
	await _aim(p, Vector2.UP)
	shot = await _shoot(p)
	_check(absf(shot.end.y - _tile(0, 1).y) < 1.5, "stone fired up passes the ledge, stops at the ceiling (%s)" % shot.end)
	_check(p._reticle_kind() == "slingshot", "still slingshot after firing it")

	# --- one-way ledges: a stone falling onto the top stops there --------------------
	# From the upper ledge (row 10, cols 25-30) a stone fired left drops onto
	# the lower ledge (row 11, cols 12-17).
	await _unaim(p)
	p.spawn_at(_tile(27.5, 10), -1)
	await _ticks(5)
	await _aim(p, Vector2.LEFT)
	shot = await _shoot(p)
	_check(absf(shot.end.y - _tile(0, 11).y) < 1.5 and shot.end.x > _tile(12, 0).x and shot.end.x < _tile(18, 0).x,
			"the stone lands on the lower ledge's top (%s)" % shot.end)

	# --- the crate stops stones, and the reticle ---------------------------------------
	await _unaim(p)
	var crate: PushBlock = world.room.get_node("Objects/block")
	p.spawn_at(_tile(6.5, 14), -1)
	await _ticks(5)
	var crate_face := crate.global_position.x + (Room.TILE - 2) / 2.0
	await _aim(p, Vector2.LEFT)
	_check(p.reticle.on_target and absf(p.reticle.global_position.x - crate_face) < 1.5,
			"reticle stops on the crate (%s, face x %.0f)" % [p.reticle.global_position, crate_face])
	shot = await _shoot(p)
	_check(absf(shot.end.x - crate_face) < 1.5, "the crate stops the stone (%s)" % shot.end)
	await _unaim(p)

	# --- a room away from the world origin -----------------------------------------
	# The stone used to be placed before entering the tree, so it appeared at
	# the room's world offset away from the player in every room but this one.
	await world.load_room("test_cistern", "from_vault")
	await _ticks(10)
	for e in world.room.get_node("Enemies").get_children():
		e.queue_free()
	_check(world.room.global_position != Vector2.ZERO, "cistern sits off the world origin")
	await _aim(p, Vector2.RIGHT)
	shot = await _shoot(p)
	_check(shot.start.distance_to(p.global_position) < 40.0,
			"in the cistern the stone appears at the player (%s vs %s)" % [shot.start, p.global_position])
	await _aim(p, Vector2.LEFT)
	_check(p.reticle.visible and _on_line(p, p.reticle.global_position, Vector2.LEFT), "reticle works in the cistern")
	await _unaim(p)
	await world.load_room("test_entry_hall", "main")
	await _ticks(10)
	for e in world.room.get_node("Enemies").get_children():
		e.queue_free()
	p.spawn_at(_tile(13.5, 16), 1)
	await _ticks(5)

	# --- grapple at the anchor: red, on the ring ----------------------------------
	var anchor: GrappleAnchor = world.room.get_node("Objects/anchor_trough")
	var aim_to_anchor := (anchor.global_position - (p.global_position + Player.SHOT_ORIGIN)).normalized()
	p._reticle_use = "grapple"
	await _aim(p, aim_to_anchor)
	_check(p._reticle_kind() == "grapple", "last used (grapple) wins")
	_check(p.reticle.latch and p.reticle.on_target, "reticle is red on the anchor")
	_check(p.reticle.global_position.distance_to(anchor.global_position) < 13.0,
			"reticle sits on the anchor ring (%.0f px from centre)" % p.reticle.global_position.distance_to(anchor.global_position))
	_check(p.state != Player.State.GRAPPLE, "previewing didn't fire the hook")

	# --- grapple at the floor: a hit, not red ------------------------------------
	await _aim(p, Vector2.DOWN)
	_check(p.reticle.on_target and not p.reticle.latch, "floor: on target, not latchable")
	_check(absf(p.reticle.global_position.y - _tile(0, 16).y) < 2.0, "reticle on the floor surface")

	# --- grapple into open air: end of range ----------------------------------------
	await _aim(p, Vector2(-1, -1).normalized())
	var range_px := Data.num(Data.objects.grapple, "range", "objects.grapple")
	var d := p.reticle.global_position.distance_to(p.global_position + Player.SHOT_ORIGIN)
	_check(not p.reticle.on_target and absf(d - range_px) < 2.0,
			"open air: reticle at the hook's range (%.0f of %.0f px)" % [d, range_px])
	await _unaim(p)

	# --- grapple at the iron block: red, and the preview doesn't pull it ----------
	var block: PushBlock = world.room.get_node("Objects/block")
	p.spawn_at(_tile(6.5, 14), -1)
	await _ticks(5)
	var bx := block.global_position.x
	await _aim(p, Vector2.LEFT)
	await _ticks(20)
	_check(p.reticle.latch, "reticle is red on the iron block")
	_check(absf(block.global_position.x - bx) < 0.5, "previewing didn't pull the block")
	block.block_material = "stone"
	await _ticks(2)
	_check(p.reticle.on_target and not p.reticle.latch, "a stone block isn't latchable")
	block.block_material = "iron"

	# --- firing the slingshot switches the reticle back ------------------------------
	await _press("item_x", 2)
	await _ticks(2)
	_check(p._reticle_kind() == "slingshot", "firing the slingshot makes it the reticle item")
	await _unaim(p)
	_check(not p.reticle.visible, "reticle hides when aim is released")

	SaveManager.delete_slot(GameState.slot_index)
	world.queue_free()
	await get_tree().process_frame
	print("test_reticle: %d failures" % _fails)
	return 1 if _fails > 0 else 0
