extends Node
## The player's item kit, in the entry hall with its objects and enemies
## cleared (everything a check needs is placed at runtime):
##   - the dash needs the Quality Boots, which replace the Ratty Boots;
##   - ammo items (explosive, darts) stay owned at ×0, and upgrades raise
##     the cap and fill it; the test loadout is full;
##   - the Explosive Charge: set, then detonate; hurts enemies and the
##     player in its radius, breaks breakable walls;
##   - slingshot stones and darts stop at the first enemy they hit;
##   - darts fly dead straight, catch fire through a torch, light an unlit
##     torch, burn a barrier away and set an enemy burning;
##   - the whip latches onto a WhipPoint (and the grapple doesn't), swings
##     on a fixed-length rope, and jump lets go;
##   - aim assist: whip and hook take a latch point a few degrees off the
##     aim; the hook's assist ignores pullable blocks;
##   - the hook activates switches (lever, latching button), not fire-only
##     targets, and the assist never steals a shot aimed at a switch.
##
##   godot --headless --path . res://tests/test_items.tscn

const SLIME := preload("res://game/enemies/green_slime.tscn")

var _fails := 0
var world: World
var p: Player


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


func _hold(action: String, n: int) -> void:
	Input.action_press(action)
	await _ticks(n)
	Input.action_release(action)


func _object(script: GDScript, at: Vector2, props := {}) -> Node2D:
	var o: Node2D = script.new()
	for k: String in props:
		o.set(k, props[k])
	o.name = "%s_%d" % [script.get_global_name(), randi()]
	world.room.get_node("Objects").add_child(o)
	o.global_position = at
	return o


func _slime(at: Vector2) -> Enemy:
	var e: Enemy = SLIME.instantiate()
	world.room.get_node("Enemies").add_child(e)
	e.global_position = at
	return e


func _clear_room() -> void:
	for path in ["Objects", "Enemies"]:
		for n in world.room.get_node(path).get_children():
			n.queue_free()
	for n in world.room.get_children():
		if n is Projectile or n is Explosive:
			n.queue_free()
	await _ticks(2)


func _projectiles() -> Array:
	return world.room.get_children().filter(func(n: Node) -> bool: return n is Projectile)


func _run() -> int:
	await get_tree().process_frame
	world = World.new()
	get_tree().root.add_child(world)
	await world.start_new_game("test_start")
	await _ticks(20)
	p = world.player
	await _clear_room()
	await _boots()
	_ammo()
	await _explosive()
	await _darts()
	await _shots_stop_at_enemies()
	await _whip()
	await _assist()
	await _hook_switches()
	print("test_items: %d failures" % _fails)
	return 1 if _fails > 0 else 0


# --- Quality Boots ----------------------------------------------------------------------

func _boots() -> void:
	p.spawn_at(_tile(3, 14), 1)
	await _ticks(10)
	_check(not p.can_dash(), "a new game can't dash (no boots)")
	await _hold("dash", 3)
	_check(p.state != Player.State.DASH, "dash without boots does nothing")
	GameState.add_item("ratty_boots")
	_check(not p.can_dash(), "Ratty Boots don't dash")
	GameState.add_item("quality_boots")
	_check(GameState.has_item("quality_boots") and not GameState.has_item("ratty_boots"),
			"Quality Boots replace the Ratty Boots")
	_check(p.can_dash(), "Quality Boots allow the dash")
	await _ticks(30)
	await _hold("dash", 3)
	_check(p.state == Player.State.DASH, "with boots, dash dashes")
	await _ticks(30)


# --- ammo ----------------------------------------------------------------------------------

func _ammo() -> void:
	GameState.add_item("explosive", 99)
	_check(GameState.count("explosive") == 10, "explosive caps at its base 10 (got %d)" % GameState.count("explosive"))
	GameState.add_item("explosive_upgrade")
	_check(GameState.capacity("explosive") == 15 and GameState.count("explosive") == 15,
			"an upgrade raises the cap by 5 and fills it (%d/%d)" % [GameState.count("explosive"), GameState.capacity("explosive")])
	GameState.remove_item("explosive", 99)
	_check(GameState.count("explosive") == 0 and GameState.has_item("explosive"), "ammo at ×0 is still owned")
	GameState.add_item("darts", 99)
	_check(GameState.count("darts") == 20, "darts cap at their base 20")
	GameState.grant_all_items()
	_check(GameState.count("explosive") == GameState.capacity("explosive") and GameState.capacity("explosive") > 10,
			"the test loadout has full, upgraded explosives (%d)" % GameState.count("explosive"))
	_check(GameState.count("darts") == GameState.capacity("darts") and GameState.capacity("darts") > 20,
			"the test loadout has full, upgraded darts (%d)" % GameState.count("darts"))
	_check(not GameState.has_item("ratty_boots"), "the test loadout ends up with Quality Boots only")


# --- Explosive Charge -----------------------------------------------------------------------

func _explosive() -> void:
	await _clear_room()
	GameState.full_heal()
	p.spawn_at(_tile(3, 14), 1)
	await _ticks(10)
	var slime := _slime(_tile(4.5, 14))
	var n0 := GameState.count("explosive")
	p.use_slot("explosive")
	_check(GameState.count("explosive") == n0 - 1, "setting a charge uses one")
	var charge: Explosive = p._explosive
	_check(charge != null and charge.global_position.distance_to(p.global_position) < 2.0, "the charge sits at the feet")
	await _ticks(20)
	var hp0 := GameState.hp
	var slime_hp := slime.hp
	p.use_slot("explosive")
	_check(GameState.count("explosive") == n0 - 1, "detonating uses nothing")
	await _ticks(6)
	_check(GameState.hp == hp0 - int(Data.objects.explosive.player_damage), "the blast hurts the player standing on it")
	_check(not is_instance_valid(slime) or slime.hp < slime_hp, "the blast hurts an enemy beside it")
	await _ticks(30)
	_check(not is_instance_valid(charge), "the charge is gone after the blast")

	# A breakable wall (cols 41-42, rows 10-12), the player well away.
	GameState.full_heal()
	p.spawn_at(_tile(3, 14), 1)
	await _ticks(70)
	var wall := Vector2i(41, 11)
	_check(world.room.kind_at(world.room.to_local(_tile(41.5, 11.5))) == "breakable", "the hall has a breakable wall at %s" % wall)
	var far := Explosive.new()
	world.room.add_child(far)
	far.global_position = _tile(40.6, 12)
	far.detonate(p)
	await _ticks(6)
	_check(world.room.kind_at(world.room.to_local(_tile(41.5, 11.5))) != "breakable", "the blast breaks the breakable wall")
	_check(GameState.hp == GameState.max_hp, "a blast far away doesn't hurt the player")

	# Out of ammo: nothing to set.
	GameState.assign("x", "explosive")
	GameState.remove_item("explosive", 999)
	await _ticks(20)
	p.use_slot("explosive")
	_check(p._explosive == null, "no charge to set at ×0")
	_check(GameState.has_item("explosive") and (GameState.slot_x == "explosive" or GameState.slot_y == "explosive"),
			"and it stays owned and in its slot at ×0")
	GameState.add_item("explosive", 99)


# --- darts and fire --------------------------------------------------------------------------

func _fire_dart() -> Projectile:
	var before := _projectiles()
	p._item_cooldown = 0.0
	p.use_slot("darts")
	for s: Projectile in _projectiles():
		if not before.has(s):
			return s
	return null


func _darts() -> void:
	await _clear_room()
	GameState.full_heal()
	p.spawn_at(_tile(2, 14), 1)
	await _ticks(10)

	# Straight and fast.
	var dart := _fire_dart()
	_check(dart != null, "a dart flies")
	var y0 := dart.global_position.y
	var x0 := dart.global_position.x
	await _ticks(20)
	_check(absf(dart.global_position.y - y0) < 0.01, "it doesn't drop (dy %.2f)" % (dart.global_position.y - y0))
	var per_tick := (dart.global_position.x - x0) / 20.0
	var stone := Data.num(Data.objects.slingshot, "speed", "objects.slingshot") / 60.0
	_check(per_tick > stone, "it's faster than a slingshot stone (%.1f vs %.1f px/tick)" % [per_tick, stone])
	await _ticks(60)

	# A plain dart doesn't burn a barrier.
	var barrier: BurnableBarrier = _object(BurnableBarrier, _tile(7.5, 14))
	await _ticks(2)
	dart = _fire_dart()
	await _ticks(20)
	_check(not is_instance_valid(dart), "a dart stops at the barrier")
	_check(not barrier.burning, "and an unlit dart doesn't set it alight")

	# Lit torch → burning dart → lights the unlit torch beyond it.
	var line_y := p.global_position.y + Player.SHOT_ORIGIN.y
	var lit: Torch = _object(Torch, Vector2(_tile(4, 0).x, line_y))
	var unlit: Torch = _object(Torch, Vector2(_tile(6, 0).x, line_y), {"lit": false})
	await _ticks(2)
	await _ticks(20)
	dart = _fire_dart()
	var caught := false
	for i in 20:
		await _ticks(1)
		if not is_instance_valid(dart):
			break
		caught = caught or dart.burning
	_check(caught, "a dart through a torch catches fire")
	_check(unlit.lit, "a burning dart lights an unlit torch")
	_check(not barrier.burning, "and stops there")

	# Through both torches now → burns the barrier away for good.
	await _ticks(20)
	dart = _fire_dart()
	await _ticks(20)
	_check(barrier.burning, "a burning dart sets the barrier alight")
	var flag := barrier.flag_name()
	await _ticks(int(Data.num(Data.objects.fire, "barrier_burn_time", "objects.fire") * 60.0) + 10)
	_check(not is_instance_valid(barrier), "the barrier burns away")
	_check(GameState.has_flag(flag), "and stays gone (flag %s)" % flag)

	# A burning dart sets an enemy burning.
	var slime := _slime(_tile(8.5, 14))
	slime.set_physics_process(true)
	await _ticks(2)
	var hp0 := slime.hp
	dart = _fire_dart()
	await _ticks(15)
	_check(not is_instance_valid(slime) or slime.burning > 0.0 or slime.hp <= 0, "a burning dart sets an enemy burning")
	var tick := Data.num(Data.objects.fire, "enemy_burn_tick", "objects.fire")
	await _ticks(int(tick * 60.0) + 5)
	var dart_dmg := Data.inum(Data.objects.darts, "damage", "objects.darts")
	_check(not is_instance_valid(slime) or slime.hp <= hp0 - dart_dmg - 1 or slime.state == Enemy.State.DEAD,
			"and the fire hurts it over time")


# --- stones and darts stop at the first enemy ------------------------------------------------

func _shots_stop_at_enemies() -> void:
	for item in ["slingshot", "darts"]:
		await _clear_room()
		p.spawn_at(_tile(2, 14), 1)
		await _ticks(10)
		var front := _slime(_tile(5, 14))
		var back := _slime(_tile(7, 14))
		await _ticks(2)
		front.set_physics_process(false)   # hold still: just targets
		back.set_physics_process(false)
		var hp_front := front.hp
		var hp_back := back.hp
		var before := _projectiles()
		p._item_cooldown = 0.0
		p.use_slot(item)
		var shot: Projectile = null
		for s: Projectile in _projectiles():
			if not before.has(s):
				shot = s
		await _ticks(30)
		_check(front.hp < hp_front, "a %s shot hits the first enemy" % item)
		_check(back.hp == hp_back, "and stops there: the enemy behind is untouched")
		_check(not is_instance_valid(shot), "and the %s shot is gone" % item)
		front.queue_free()
		back.queue_free()


# --- whip ------------------------------------------------------------------------------------

func _whip() -> void:
	await _clear_room()
	GameState.full_heal()
	GameState.equip_weapon("whip")
	p.spawn_at(_tile(4, 8.5), 1)
	var hand := p.global_position + Player.SHOT_ORIGIN
	var point: WhipPoint = _object(WhipPoint, hand + Vector2(45, -45))
	await _ticks(1)
	p.forced_aim = Vector2(45, -45)
	Input.action_press("aim")
	await _hold("attack", 2)
	for i in 20:
		if p.state == Player.State.SWING:
			break
		await _ticks(1)
	_check(p.state == Player.State.SWING, "the whip latches onto a whip point")
	Input.action_release("aim")
	p.forced_aim = Vector2.ZERO
	var anchor := point.latch_point()
	var length: float = p._swing_len
	var longest := 0.0
	var left := INF
	var right := -INF
	for i in 120:
		await _ticks(1)
		var h := p.global_position + Player.SHOT_ORIGIN
		longest = maxf(longest, (h - anchor).length())
		left = minf(left, h.x)
		right = maxf(right, h.x)
	_check(p.state == Player.State.SWING, "still swinging two seconds later")
	_check(longest <= length + 1.5, "the rope never stretches (%.1f of %.1f)" % [longest, length])
	_check(left < anchor.x - 20.0 and right > anchor.x + 20.0, "the player swings through under the beam (x %.0f..%.0f, beam %.0f)" % [left, right, anchor.x])
	await _hold("jump", 2)
	_check(p.state != Player.State.SWING, "jump lets go")
	await _ticks(60)

	# Out of reach: no latch (the whip got shorter).
	p.spawn_at(_tile(4, 8.5), 1)
	hand = p.global_position + Player.SHOT_ORIGIN
	point.global_position = hand + Vector2(70, -70)
	await _ticks(1)
	p.forced_aim = Vector2(1, -1)
	Input.action_press("aim")
	await _hold("attack", 2)
	await _ticks(15)
	_check(p.state != Player.State.SWING, "a whip point beyond reach isn't latched")

	# The grappling hook doesn't take a whip point.
	await _ticks(30)
	p.spawn_at(_tile(4, 8.5), 1)
	hand = p.global_position + Player.SHOT_ORIGIN
	point.global_position = hand + Vector2(45, -45)
	await _ticks(1)
	p.forced_aim = Vector2(45, -45)
	p._grapple_cooldown = 0.0
	p._item_cooldown = 0.0
	p.use_slot("grapple")
	await _ticks(2)
	_check(p.state != Player.State.GRAPPLE, "the grappling hook doesn't latch a whip point")
	Input.action_release("aim")
	p.forced_aim = Vector2.ZERO


# --- aim assist ----------------------------------------------------------------------------

func _assist() -> void:
	await _clear_room()
	GameState.full_heal()
	GameState.equip_weapon("whip")
	p.spawn_at(_tile(4, 8.5), 1)
	await _ticks(1)
	var from := p.global_position + Player.SWING_ORIGIN
	var point: WhipPoint = _object(WhipPoint, from + Vector2.RIGHT.rotated(deg_to_rad(-4.5)) * 75.0)
	await _ticks(1)
	from = p.global_position + Player.SWING_ORIGIN
	point.global_position = from + Vector2.RIGHT.rotated(deg_to_rad(-4.5)) * 75.0
	var exact: Dictionary = p._ray(from, from + Vector2.RIGHT * 84.0, Player.LAYER_WORLD | Player.LAYER_WHIP).hit
	_check(exact.is_empty(), "(setup: a straight whip line misses the beam)")
	_check(p._whip_latch_ray(Vector2.RIGHT).get("point") == point, "the whip takes a beam 4.5° off its aim")
	point.global_position = from + Vector2.RIGHT.rotated(deg_to_rad(-9.0)) * 75.0
	await _ticks(1)
	_check(p._whip_latch_ray(Vector2.RIGHT).is_empty(), "but not one 9° off")
	point.queue_free()

	# Hook: an anchor 200 px out, 4° off; then a wooden block (pullable) 4° off.
	p.spawn_at(_tile(4, 8.5), 1)
	await _ticks(1)
	var anchor: GrappleAnchor = _object(GrappleAnchor, Vector2.ZERO)
	var hand := p.global_position + Player.SHOT_ORIGIN
	anchor.global_position = hand + Vector2.RIGHT.rotated(deg_to_rad(4.0)) * 200.0
	await _ticks(1)
	hand = p.global_position + Player.SHOT_ORIGIN
	anchor.global_position = hand + Vector2.RIGHT.rotated(deg_to_rad(4.0)) * 200.0
	var g: Dictionary = p._grapple_ray(Vector2.RIGHT)
	_check(Player._latch_owner(g.hit.get("collider")) == anchor, "the hook takes an anchor 4° off its aim, 200 px out")
	anchor.global_position = hand + Vector2.RIGHT.rotated(deg_to_rad(9.0)) * 200.0
	await _ticks(1)
	g = p._grapple_ray(Vector2.RIGHT)
	_check(Player._latch_owner(g.hit.get("collider")) != anchor, "but not one 9° off")
	# Firing it for real, falling: latched.
	anchor.global_position = p.global_position + Player.SHOT_ORIGIN + Vector2.RIGHT.rotated(deg_to_rad(-3.0)) * 200.0
	await _ticks(1)
	p._grapple_cooldown = 0.0
	p._item_cooldown = 0.0
	p.facing = 1
	p.use_slot("grapple")
	_check(p.state == Player.State.GRAPPLE, "firing the hook near an anchor latches on")
	await _ticks(60)
	anchor.queue_free()

	p.spawn_at(_tile(4, 8.5), 1)
	await _ticks(1)
	hand = p.global_position + Player.SHOT_ORIGIN
	var block: Node2D = load("res://game/objects/push_block.tscn").instantiate()
	block.set("block_material", "wood")
	world.room.get_node("Objects").add_child(block)
	await _ticks(1)
	hand = p.global_position + Player.SHOT_ORIGIN
	block.global_position = hand + Vector2.RIGHT.rotated(deg_to_rad(7.0)) * 200.0 + Vector2(0, 16)
	await _ticks(1)   # the physics server sees the move next step (the block falls < 1 px)
	hand = p.global_position + Player.SHOT_ORIGIN
	var is_block := func(c: Object) -> bool:
		return c != null and (c == block or (c is GrappleTarget and (c as GrappleTarget).target == block))
	var centre: Vector2 = block.global_position + Vector2(0, -16)
	_check(is_block.call(p._grapple_ray((centre - hand).normalized()).hit.get("collider")),
			"(control: aimed straight at it, the hook hits the block)")
	# Widen the assist past it: the block still isn't a latch point.
	var deg: float = Data.objects.grapple.assist_deg
	Data.objects.grapple.assist_deg = 10.0
	_check(not is_block.call(p._grapple_ray(Vector2.RIGHT).hit.get("collider")),
			"the hook's assist ignores a pullable block (7° off, assist widened to 10°)")
	Data.objects.grapple.assist_deg = deg


# --- the hook activates switches ------------------------------------------------------------

func _fire_hook_at(target: Vector2) -> void:
	p._grapple_cooldown = 0.0
	p._item_cooldown = 0.0
	Input.action_press("aim")
	p.forced_aim = target - (p.global_position + Player.SHOT_ORIGIN)
	await _ticks(1)
	p.forced_aim = target - (p.global_position + Player.SHOT_ORIGIN)
	await _ticks(1)
	p.use_slot("grapple")
	Input.action_release("aim")
	p.forced_aim = Vector2.ZERO


func _hook_switches() -> void:
	await _clear_room()
	# Player on the floor at col 2; targets on the same floor, 4-6 tiles off.
	p.spawn_at(_tile(2, 14), 1)
	await _ticks(10)
	var lever: Lever = _object(Lever, _tile(7, 14))
	await _ticks(2)
	var lever_mid := lever.global_position + Vector2(0, -15)
	Input.action_press("aim")
	p.forced_aim = lever_mid - (p.global_position + Player.SHOT_ORIGIN)
	await _ticks(2)
	_check(p._trace_grapple(p.aim_dir).get("latch", false), "the reticle shows the hook will work a lever")
	Input.action_release("aim")
	p.forced_aim = Vector2.ZERO
	await _fire_hook_at(lever_mid)
	_check(lever.on, "the hook flips a lever")
	_check(p.state != Player.State.GRAPPLE, "and doesn't pull the player to it")

	# An anchor 3° off a shot aimed straight at the lever doesn't steal it.
	await _ticks(30)
	var hand := p.global_position + Player.SHOT_ORIGIN
	var anchor: GrappleAnchor = _object(GrappleAnchor,
			hand + (lever_mid - hand).normalized().rotated(deg_to_rad(-3.0)) * 200.0)
	await _ticks(2)
	await _fire_hook_at(lever_mid)
	_check(not lever.on and p.state != Player.State.GRAPPLE, "a shot at a lever works the lever, not a nearby anchor")
	anchor.queue_free()
	lever.queue_free()

	var button: FloorButton = _object(FloorButton, _tile(7, 14), {"latching": true})
	await _ticks(30)
	await _fire_hook_at(button.global_position + Vector2(0, -5))
	_check(button.pressed, "the hook presses a latching button")
	button.queue_free()

	# Fire-only targets are just in the way.
	var torch: Torch = _object(Torch, _tile(7, 13.3), {"lit": false})
	await _ticks(30)
	_check(p._hook_mode(torch.get_node("Switch")) == "none", "an unlit torch isn't a hook switch")
	torch.queue_free()
