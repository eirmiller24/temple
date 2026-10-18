extends Node
## Crushing (design §7.6, game/combat/crush.gd). Any moving solid that
## squeezes a character displaces and damages it. With nowhere to go,
## the player voids out to where they last entered the room, and an
## enemy dies. Driven with the entry hall's exit gate, plus a bare moving
## body to show it isn't gate-specific.
##
##   godot --headless --path . res://tests/test_crush.tscn

const GREEN_SLIME := "res://game/enemies/green_slime.tscn"

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


func _clear_enemies() -> void:
	for e in world.room.get_node("Enemies").get_children():
		e.queue_free()


func _gate() -> Gate:
	return world.room.get_node("Objects/exit_gate")


func _open_gate() -> void:
	Wiring.drive(0, self, true)
	await _ticks(60)


func _close_gate() -> void:
	Wiring.drive(0, self, false)


## A 4 px wall `gap` px either side of the gate's slab, at body height.
func _walls_beside_gate(gap: float) -> Array[Node]:
	var out: Array[Node] = []
	var g := _gate()
	for side in [-1.0, 1.0]:
		out.append(_static_box(Vector2(g.global_position.x + side * (16.0 + gap + 2.0), g.global_position.y - 32.0), Vector2(4, 64)))
	return out


func _static_box(centre: Vector2, size: Vector2) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	var s := CollisionShape2D.new()
	s.shape = RectangleShape2D.new()
	(s.shape as RectangleShape2D).size = size
	b.add_child(s)
	world.room.add_child(b)
	b.global_position = centre
	return b


func _slime_at(pos: Vector2) -> Enemy:
	var e: Enemy = (load(GREEN_SLIME) as PackedScene).instantiate()
	world.room.get_node("Enemies").add_child(e)
	e.global_position = pos
	return e


func _run() -> int:
	await get_tree().process_frame
	world = World.new()
	get_tree().root.add_child(world)
	await world.start_new_game("test_start")
	await _ticks(10)
	_clear_enemies()
	var p := world.player
	var floor_y := _gate().global_position.y
	var start_room := world.room
	var first_room_check := func() -> Room: return start_room
	var slab := func() -> Rect2:
		return Rect2(_gate().global_position + Vector2(-16, -96 + _gate()._body.position.y), Vector2(32, 96))

	# --- ordinary movement never crushes ---------------------------------------------
	# Walking off a stationary raised gate, and off a plain tile ledge: the
	# capsule rolls over the corner, which is not a squeeze. (It used to read
	# as one at walking speed, depending on frame timing, so sweep speeds.)
	var shelf: Gate = world.room.get_node("Objects/shelf_gate")
	var top := shelf.global_position + Vector2(0, shelf._body.position.y - shelf.h * Room.TILE)
	var ledge := world.room.global_position + Vector2(7.5, 14) * Room.TILE
	var walks := 0
	var hurt := []
	for start: Vector2 in [top, ledge]:
		for dir in ([-1, 1] if start == top else [1]):
			for strength in [0.3, 0.45, 0.6, 0.8, 1.0]:
				GameState.full_heal()
				p.spawn_at(start, dir)
				await _ticks(5)
				var action := "move_left" if dir < 0 else "move_right"
				Input.action_press(action, strength)
				await _ticks(45)
				Input.action_release(action)
				await _ticks(20)
				if GameState.hp != GameState.max_hp:
					hurt.append("%s %s @%.2f" % ["gate" if start == top else "ledge", action, strength])
				walks += 1
	GameState.full_heal()
	_check(hurt.is_empty(), "walking/running off a raised gate (both ways) and a ledge never hurts (%d walk-offs; hurt on %s)" % [walks, hurt])

	# --- one-way ledges --------------------------------------------------------------
	# Standing on a one-way platform, a crusher pushes you sideways and hurts
	# you; it never shoves you down through (that used to depend on frame
	# timing). The shelf gate closes onto the one-way run at row 13.
	var ow_top := world.room.global_position.y + 13 * Room.TILE
	var lever: Lever = world.room.get_node("Objects/shelf_lever")
	var through := []
	var not_hurt := []
	for dx in [-14.0, -10.0, -6.0, -2.0, 0.0, 3.0, 7.0, 11.0, 15.0]:
		GameState.full_heal()
		await _ticks(70)   # i-frames
		if lever.on:
			lever._cooldown = 0.0
			lever.toggle()
			await _ticks(60)
		p.spawn_at(Vector2(shelf.global_position.x + dx, ow_top), 1)
		await _ticks(10)
		lever._cooldown = 0.0
		lever.toggle()
		var lowest := p.global_position.y
		for i in 90:
			await _ticks(1)
			lowest = maxf(lowest, p.global_position.y)
		if lowest > ow_top + 1.0:
			through.append(dx)
		if GameState.hp != GameState.max_hp - 1:
			not_hurt.append("%+.0f: hp %d" % [dx, GameState.hp])
	_check(through.is_empty(), "a gate closing on someone on a one-way ledge never pushes them through (failed at dx %s)" % [through])
	_check(not_hurt.is_empty(), "and always costs exactly 1 hp (exceptions %s)" % [not_hurt])
	_check(world.room == first_room_check.call(), "no void-outs on the ledge (there's room to the side)")
	GameState.full_heal()
	if lever.on:
		lever._cooldown = 0.0
		lever.toggle()
		await _ticks(60)

	# Down + jump drops through on purpose, and that isn't a squeeze.
	var ow_spot := Vector2(34.5 * Room.TILE + world.room.global_position.x, ow_top)
	await _ticks(70)
	p.spawn_at(ow_spot, 1)
	await _ticks(10)
	Input.action_press("move_down")
	await _ticks(2)
	Input.action_press("jump")
	await _ticks(3)
	Input.action_release("jump")
	Input.action_release("move_down")
	await _ticks(40)
	_check(p.global_position.y > ow_top + Room.TILE and p.is_on_floor(), "down + jump drops through a one-way ledge (feet y %.0f, ledge %.0f)" % [p.global_position.y, ow_top])
	_check(GameState.hp == GameState.max_hp, "and costs nothing")

	# Crouch + jump is a crouch jump: it rises, keeps the short collider in
	# the air while crouch is held, and on a one-way ledge does NOT drop.
	p.spawn_at(ow_spot, 1)
	await _ticks(10)
	Input.action_press("crouch")
	await _ticks(6)
	_check(p.state == Player.State.CROUCH, "crouch crouches")
	Input.action_press("jump")
	var apex := p.global_position.y
	var tall := 0.0
	for i in 40:
		await _ticks(1)
		apex = minf(apex, p.global_position.y)
		tall = maxf(tall, p.body_rect().size.y)
	Input.action_release("jump")
	await _ticks(40)
	_check(apex < ow_top - Room.TILE, "a crouch jump leaves the ground (apex %.0f px up)" % (ow_top - apex))
	_check(tall < p.body_height() - 4.0, "and keeps the crouched collider in the air (max %.0f px, standing %.0f)" % [tall, p.body_height()])
	_check(absf(p.global_position.y - ow_top) < 1.0 and p.state == Player.State.CROUCH,
			"and lands back on the one-way ledge, still crouched (feet y %.0f)" % p.global_position.y)
	Input.action_release("crouch")
	await _ticks(5)
	_check(p.state == Player.State.NORMAL, "letting go of crouch stands up")

	# Keyboard: crouch has its own key, so S/Down are only "down".
	var crouch_keys := []
	for ev in InputMap.action_get_events("crouch"):
		if ev is InputEventKey:
			crouch_keys.append(OS.get_keycode_string((ev as InputEventKey).physical_keycode))
	_check(not crouch_keys.has("S") and not crouch_keys.has("Down") and not crouch_keys.is_empty(),
			"keyboard crouch is its own key, not S/Down (%s)" % [crouch_keys])

	# --- player, room to escape: displaced and hurt ------------------------------
	var hp0 := GameState.hp
	var first_room := world.room
	await _open_gate()
	p.spawn_at(_gate().global_position, 1)
	await _ticks(10)
	_close_gate()
	var deepest := 0.0
	for i in 150:
		await _ticks(1)
		deepest = maxf(deepest, p.global_position.y - floor_y)
	_check(GameState.hp == hp0 - 1, "a closing gate costs the player 1 hp (%d → %d)" % [hp0, GameState.hp])
	_check(not (slab.call() as Rect2).intersects(p.body_rect()), "the player was displaced out from under it (x=%.0f)" % p.global_position.x)
	_check(deepest <= Crush.INSET + 1.0, "pressed at most a couple of px before being displaced (%.1f px)" % deepest)
	_check(is_equal_approx(_gate()._body.position.y, 0.0), "the gate finished closing")
	_check(world.room == first_room, "no void-out when there was room to escape")

	# --- player, walled in: void out -----------------------------------------------
	await _ticks(70)   # i-frames run out
	var arrival: Vector2 = world._arrival.pos
	hp0 = GameState.hp
	await _open_gate()
	_walls_beside_gate(6.0)   # 6 px either side: no room for a 16 px body
	p.spawn_at(_gate().global_position, 1)
	await _ticks(10)
	_close_gate()
	var waited := 0
	while world.room == first_room and waited < 300:
		await _ticks(1)
		waited += 1
	await _ticks(30)
	_check(world.room != first_room, "walled in, the player voided out (room reloaded after %d ticks)" % waited)
	_check(GameState.hp == hp0 - 1, "the crush still cost 1 hp (%d → %d)" % [hp0, GameState.hp])
	_check(p.global_position.distance_to(arrival) < 4.0, "back at the room's last entrance (%s)" % p.global_position)
	_check(p.state != Player.State.DEAD and p.state != Player.State.HURT, "standing, not hurt or dead")
	_clear_enemies()

	# --- enemy, room to escape: displaced and hurt --------------------------------------
	p.spawn_at(world.room.global_position + Vector2(3.5, 14) * Room.TILE, 1)   # far away, out of aggro
	await _open_gate()
	var slime := _slime_at(_gate().global_position)
	await _ticks(10)
	var shp0 := slime.hp
	_close_gate()
	await _ticks(120)
	_check(is_instance_valid(slime) and slime.state != Enemy.State.DEAD, "the slime survived a closing gate it could escape")
	if is_instance_valid(slime):
		_check(slime.hp == shp0 - 1, "and took 1 damage (%d → %d)" % [shp0, slime.hp])
		_check(not (slab.call() as Rect2).intersects(Crush.body_rect(slime)), "and was displaced out from under it")
		slime.queue_free()

	# --- enemy, walled in: dies ------------------------------------------------------------
	await _open_gate()
	var walls := _walls_beside_gate(6.0)
	slime = _slime_at(_gate().global_position)
	var died := [false]
	slime.died.connect(func(_e: Enemy) -> void: died[0] = true)
	await _ticks(10)
	_close_gate()
	await _ticks(120)
	_check(died[0], "a walled-in slime under a closing gate dies")
	for w in walls:
		w.queue_free()

	# --- not just gates: a moving block pins the player against a wall --------------------
	await _ticks(70)
	var left_wall_x := world.room.global_position.x + Room.TILE   # inner face of column 0
	var feet := Vector2(left_wall_x + 9.0, world.room.global_position.y + 14 * Room.TILE)
	p.spawn_at(feet, -1)
	await _ticks(10)
	hp0 = GameState.hp
	var room_now := world.room
	var pusher := AnimatableBody2D.new()
	pusher.collision_layer = 1
	var ps := CollisionShape2D.new()
	ps.shape = RectangleShape2D.new()
	(ps.shape as RectangleShape2D).size = Vector2(32, 32)
	pusher.add_child(ps)
	world.room.add_child(pusher)
	pusher.global_position = feet + Vector2(9.0 + 16.0 + 2.0, -16.0)
	for i in 90:
		await _ticks(1)
		# Scaled like any real mover (speed * delta): hitstop zeroes time, and a
		# platform that moves in zero time has infinite velocity (NaN rider).
		pusher.global_position.x = maxf(pusher.global_position.x - 2.0 * Engine.time_scale, left_wall_x + 16.0)
	await _ticks(10)
	var pr := Crush.body_rect(p).grow(-Crush.INSET)
	_check(GameState.hp == hp0 - 1, "pinned to a wall by a moving block: 1 damage (%d → %d)" % [hp0, GameState.hp])
	_check(world.room == room_now, "displaced, not voided (there was room above the block)")
	_check(not pr.intersects(Crush.body_rect(pusher)) and p.global_position.y < feet.y - 30.0,
			"the player was displaced on top of the block (%s)" % p.global_position)
	pusher.queue_free()

	world.queue_free()
	await get_tree().process_frame
	print("test_crush: %d failures" % _fails)
	return 1 if _fails > 0 else 0
