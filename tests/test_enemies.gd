extends Node
## Enemy roster smoke test: every data/enemies/*.json names a sprite that
## exists and a scene that loads; every species spawns on a floor in the
## start room, ticks, takes a hit, and one dies cleanly; hoppers and both
## bosses start an attack when the player comes close; a defeated boss
## does not respawn.
##
##   godot --headless --path . res://tests/test_enemies.tscn
##
## Tests are SCENES (see test_boot.gd): a -s script cannot name autoloads.
## Exit code 1 on any failed check; engine errors go to stderr and the
## harness greps for them.

## Common keys every species file must carry (Enemy reads them with Data.req).
const COMMON_KEYS := ["behavior", "boss", "sprite", "fit_tiles", "hp", "contact_damage",
	"contact_knockback", "contact_rearm", "speed", "gravity", "friction", "body_w", "body_h",
	"hurt_stun", "knockback_resist", "death_linger", "xp_placeholder", "hit_sfx"]
## Room-local x (px) each species is dropped at in test_entry_hall; the
## floor under it is found by scanning the Collision layer, so a repaint
## only needs new x values. All far from the player's entry (x 112).
const SPOTS := {
	"green_slime": 400.0, "blue_slime": 820.0, "orange_slime": 920.0, "mushroom": 1030.0,
	"bush_lasher": 1110.0, "stone_guardian": 1200.0, "riftmaw": 1320.0,
}

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


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Room-local feet position on the first floor found scanning up from the
## bottom of the painted room at local x.
func _floor_spot(room: Room, x: float) -> Vector2:
	var r := room.rect_tiles()
	for ty in range(r.end.y - 1, r.position.y, -1):
		var here := room.kind_at(Vector2(x, ty * Room.TILE + Room.TILE / 2.0))
		var above := room.kind_at(Vector2(x, (ty - 1) * Room.TILE + Room.TILE / 2.0))
		if here != "" and here != "water" and here != "hazard" and above == "":
			return Vector2(x, ty * Room.TILE)
	return Vector2(x, 0.0)


func _fake_hit(e: Enemy) -> Dictionary:
	return {"damage": 1, "knockback": Vector2(200, -100), "source": null,
		"origin": e.global_position + Vector2(-10, 0), "kind": "melee", "tier": 0, "hitstop": 0.0}


func _spawn(world: World, stem: String, local_pos: Vector2) -> Enemy:
	var packed: PackedScene = load("res://game/enemies/%s.tscn" % stem)
	if packed == null:
		return null
	var e := packed.instantiate() as Enemy
	if e == null:
		return null
	e.position = local_pos
	world.room.add_child(e)
	return e


func _run() -> int:
	await get_tree().process_frame
	var stems := Data.dir_names("enemies")
	_check(stems.size() >= 7, "data/enemies has %d species" % stems.size())
	var sprites: Dictionary = Data.sprites.get("enemies", {})
	for stem in stems:
		var cfg: Dictionary = Data.enemies[stem]
		var missing := []
		for k in COMMON_KEYS:
			if not cfg.has(k):
				missing.append(k)
		_check(missing.is_empty(), "%s: common keys present (missing %s)" % [stem, str(missing)])
		var behavior := String(cfg.get("behavior", ""))
		_check(cfg.has(behavior), "%s: has a '%s' brain block" % [stem, behavior])
		_check(sprites.has(String(cfg.get("sprite", ""))), "%s: sprite '%s' is in sprites.json enemies" % [stem, cfg.get("sprite", "")])
		if bool(cfg.get("boss", false)):
			_check(cfg.has("defeat_flag"), "%s: boss has a defeat_flag" % stem)
		var packed: PackedScene = load("res://game/enemies/%s.tscn" % stem)
		_check(packed != null, "%s: scene loads" % stem)
		if packed != null:
			var node := packed.instantiate()
			var inst := node as Enemy
			_check(inst != null and inst.species == stem, "%s: scene is an Enemy with species preset" % stem)
			_check(inst != null and inst.behavior_name() == behavior, "%s: scene script matches behavior '%s'" % [stem, behavior])
			node.free()

	var world := World.new()
	get_tree().root.add_child(world)
	await world.start_new_game("test_start")
	await _ticks(30)
	_check(world.player != null and world.room != null, "world started in '%s'" % world.room_name)
	# The test room ships its own enemies and puzzle objects (a gate, a
	# block); this test is about the species it spawns itself, so clear
	# the authored ones out of the way first.
	for group in ["Enemies", "Objects"]:
		var holder := world.room.get_node_or_null(group)
		if holder != null:
			for c in holder.get_children():
				c.queue_free()
	Wiring.reset()
	await _ticks(2)
	var entry := world.player.global_position

	# Spawn every species on a floor, far from the player.
	var spawned := {}
	for stem in stems:
		var x: float = SPOTS.get(stem, SPOTS.values().back())
		var spot := _floor_spot(world.room, x)
		_check(spot.y > 0.0, "%s: found a floor at local x %.0f (y %.0f)" % [stem, x, spot.y])
		var e := _spawn(world, stem, spot)
		_check(e != null, "%s: spawned under the room" % stem)
		if e != null:
			spawned[stem] = e
	await _ticks(90)
	for stem in spawned:
		var e: Enemy = spawned[stem]
		_check(is_instance_valid(e) and e.hp > 0 and e.hp == e.max_hp, "%s: alive after 90 frames (hp %d)" % [stem, e.hp if is_instance_valid(e) else -1])
		if is_instance_valid(e):
			_check(e.is_on_floor(), "%s: standing on the floor" % stem)
			_check(e.hitbox.active and e.hurtbox.enabled, "%s: contact hitbox live, hurtbox enabled" % stem)

	# Every species takes a hit.
	for stem in spawned:
		var e: Enemy = spawned[stem]
		if not is_instance_valid(e):
			continue
		var before := e.hp
		e.on_hit(_fake_hit(e))
		_check(e.hp == before - 1, "%s: hp dropped %d → %d" % [stem, before, e.hp])
		var boss := bool(e.cfg.get("boss", false))
		if boss:
			_check(e.state != Enemy.State.HURT, "%s: boss is not staggered by a hit" % stem)
		else:
			_check(e.state == Enemy.State.HURT and not e.hitbox.active, "%s: staggered, contact hitbox off" % stem)
	await _ticks(30)

	# Kill the green slime: died fires, the corpse lingers, then frees.
	var slime: Enemy = spawned.get("green_slime")
	if slime != null and is_instance_valid(slime):
		var died_with: Array = []
		slime.died.connect(func(who: Enemy) -> void: died_with.append(who))
		var swings := 0
		while slime.hp > 0 and swings < 20:
			slime.on_hit(_fake_hit(slime))
			swings += 1
		_check(slime.hp <= 0 and slime.state == Enemy.State.DEAD, "green_slime: dead after %d hits" % swings)
		_check(died_with.size() == 1 and died_with[0] == slime, "green_slime: died emitted once with itself")
		_check(not slime.hurtbox.enabled and not slime.hitbox.active, "green_slime: corpse cannot hit or be hit")
		await _ticks(100)
		_check(not is_instance_valid(slime), "green_slime: corpse freed itself")
		spawned.erase("green_slime")

	# Regular attacks start when the player comes close and run to completion.
	var is_cloud := func(n: Node) -> bool: return n is SporeCloud
	var is_rock := func(n: Node) -> bool: return n is Projectile and not (n is Shockwave) and not (n is HomingOrb)
	var is_wave := func(n: Node) -> bool: return n is Shockwave
	var is_orb := func(n: Node) -> bool: return n is HomingOrb
	# Player to the RIGHT: the slime's platform ends in a bottomless water pit on its left.
	await _probe_attack(world, spawned.get("blue_slime"), "blue_slime hop", Vector2(110, 0), 180)
	await _probe_attack(world, spawned.get("mushroom"), "mushroom spore", Vector2(-100, 0), 360, is_cloud)
	await _probe_attack(world, spawned.get("bush_lasher"), "bush_lasher lash", Vector2(-70, 0), 360)
	# Bosses wake up and run every attack (weights forced one at a time).
	var g: Enemy = spawned.get("stone_guardian")
	for id: String in ["slam", "volley", "charge"]:
		_force_weights(g, id)
		await _probe_attack(world, g, "stone_guardian " + id, Vector2(-150, 0), 600,
				is_wave if id == "slam" else (is_rock if id == "volley" else Callable()))
	if g != null and is_instance_valid(g):
		_check((g as Boss).aggro, "stone_guardian: aggro on approach")
	var rm: Enemy = spawned.get("riftmaw")
	for id: String in ["lash", "blink_slam", "volley"]:
		_force_weights(rm, id)
		await _probe_attack(world, rm, "riftmaw " + id, Vector2(-80, 0), 600,
				is_wave if id == "blink_slam" else (is_orb if id == "volley" else Callable()))
	world.player.spawn_at(entry)
	GameState.full_heal()
	await _ticks(60)

	# A defeated boss never respawns in that save.
	GameState.set_flag("boss_stone_guardian_defeated")
	var ghost := _spawn(world, "stone_guardian", _floor_spot(world.room, 1200.0))
	await _ticks(3)
	_check(ghost == null or not is_instance_valid(ghost), "stone_guardian: does not spawn once its defeat_flag is set")
	GameState.flags.erase("boss_stone_guardian_defeated")

	for stem in spawned:
		var e: Enemy = spawned[stem]
		if is_instance_valid(e):
			e.queue_free()
	await _ticks(2)
	world.queue_free()
	await get_tree().process_frame
	print("test_enemies: %d failures" % _fails)
	return 1 if _fails > 0 else 0


## Teleport the player `offset` from the enemy and wait (up to `max_frames`)
## for it to start an attack and come back to IDLE/MOVE; `spawns` (if
## given) must match some room child at some point — a cloud, rocks, orbs.
## Bosses may be mid-attack already (one boss's probe wakes the other, the
## room is that small), so the budget covers a whole attack plus the gap.
## The player's HP is padded so nothing can kill them mid-probe (a death
## would reload the room under the test).
func _probe_attack(world: World, e: Enemy, label: String, offset: Vector2, max_frames: int,
		spawns: Callable = Callable()) -> void:
	if e == null or not is_instance_valid(e):
		_check(false, "%s: enemy missing for the attack probe" % label)
		return
	var attacks_before := e.attacks
	GameState.hp = 60
	world.player.spawn_at(e.global_position + offset)
	var waited := 0
	var started := false
	var finished := false
	var seen := not spawns.is_valid()
	while waited < max_frames and is_instance_valid(e):
		await _ticks(5)
		waited += 5
		if not seen:
			seen = _room_has(world.room, spawns)
		if not started:
			started = e.attacks > attacks_before
		elif e.state == Enemy.State.IDLE or e.state == Enemy.State.MOVE:
			finished = true
			break
	var alive := is_instance_valid(e)
	_check(alive and started, "%s: started within %d frames of the player arriving (waited %d)" % [label, max_frames, waited])
	_check(alive and finished, "%s: ran to completion (state %s)" % [label, Enemy.State.keys()[e.state] if alive else "freed"])
	_check(seen, "%s: spawned what it should" % label)


func _room_has(room: Room, pred: Callable) -> bool:
	for n in room.get_children():
		if bool(pred.call(n)):
			return true
	return false


## Make a boss pick only `id` from now on (its brain copy is the test's own).
func _force_weights(e: Enemy, id: String) -> void:
	if e == null or not is_instance_valid(e):
		return
	e.brain = e.brain.duplicate()
	e.brain["weights"] = {id: 1.0}
