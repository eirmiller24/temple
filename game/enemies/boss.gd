class_name Boss
extends Enemy
## Shared boss brain: wakes when the player comes within `aggro_range`
## (switches the music to "boss"), lumbers toward the player between
## attacks, picks the next attack by `weights`, flips to phase 2 at
## `phase2_frac` HP (shorter tells via `tell_mult_p2`), and on death sets
## `defeat_flag` in GameState and restores the room's music. A boss whose
## flag is already set never spawns (Enemy._ready frees it).
##
## Brain keys every boss block needs: aggro_range, approach_stop,
## ledge_probe, first_attack_delay, attack_gap [min,max], weights {name:
## weight}, phase2_frac, tell_mult_p2, tell_time. Slam users also need
## wave_speed, wave_radius, wave_height, wave_lifetime, wave_damage,
## wave_knockback [x,y], slam_shake [strength, seconds].
##
## Species implement `_run_attack(id)` as a coroutine built from tell() /
## wait() / pulse_box(); Boss calls `_end_attack()` after it returns.

const WAVE_COLOR := Color(0.95, 0.75, 0.4)

var phase := 1
var aggro := false
var _gap := 0.0


func _species_ready() -> void:
	_gap = bn("first_attack_delay")


func _think(delta: float) -> void:
	if not aggro:
		velocity.x = move_toward(velocity.x, 0.0, cn("friction") * delta)
		SpriteDb.play(sprite, "idle")
		if player_in_range(bn("aggro_range")):
			_start_fight()
		return
	if state != State.IDLE and state != State.MOVE:
		return
	face_player()
	_gap -= delta
	if _gap <= 0.0 and is_on_floor() and player() != null:
		_gap = INF
		attacks += 1
		_run_then_end(_pick_attack())
		return
	_approach(delta)


func _approach(delta: float) -> void:
	var d := player_delta()
	if d != Vector2.INF and absf(d.x) > bn("approach_stop") and is_on_floor() and not _ledge_ahead(bn("ledge_probe")):
		state = State.MOVE
		velocity.x = facing * cn("speed")
		SpriteDb.play(sprite, "walk", ["idle"])
	else:
		state = State.IDLE
		velocity.x = move_toward(velocity.x, 0.0, cn("friction") * delta)
		SpriteDb.play(sprite, "idle")


func _start_fight() -> void:
	aggro = true
	Music.play_track("boss")
	Sfx.play("boss_roar", self)


func _pick_attack() -> String:
	var weights: Dictionary = Data.req(brain, "weights", ctx + "." + behavior_name())
	return EnemyKit.weighted_pick(weights)


func _run_then_end(id: String) -> void:
	await _run_attack(id)
	_end_attack()


## Species override: one full attack, from tell to recovery.
func _run_attack(_id: String) -> void:
	pass


func _end_attack() -> void:
	sprite.speed_scale = 1.0
	contact_enabled = true
	uses_gravity = true
	if state == State.DEAD:
		return
	state = State.IDLE
	var gap: Vector2 = bv("attack_gap")
	_gap = randf_range(gap.x, gap.y)


func tell_mult() -> float:
	return bn("tell_mult_p2") if phase == 2 else 1.0


func _on_damaged(_info: Dictionary) -> void:
	if not aggro:
		_start_fight()
	if phase == 1 and hp > 0 and float(hp) <= float(max_hp) * bn("phase2_frac"):
		phase = 2
		Sfx.play("boss_roar", self)
		flash(FLASH_SECONDS * 3.0)
		_phase_changed()


func _phase_changed() -> void:
	pass


func _on_died() -> void:
	GameState.set_flag(cs("defeat_flag"))
	var r := room
	if r == null:
		var world := get_tree().get_first_node_in_group("world") as World
		if world != null:
			r = world.room
	if r != null:
		Music.play_track(r.music)


## Ground slam feedback + one shockwave along the floor to each side.
func slam_shock() -> void:
	var shake: Vector2 = bv("slam_shake")
	Juice.shake(shake.x, shake.y)
	Sfx.play("boss_slam", self)
	var r := bn("wave_radius")
	var start_x := cn("body_w") / 2.0 + r
	for side in [-1.0, 1.0]:
		var wave := Shockwave.new()
		wave.setup_enemy(bi("wave_damage"), Vector2(side, 0.0), bn("wave_speed"), bn("wave_lifetime"),
				0.0, bv("wave_knockback"), self, WAVE_COLOR, r)
		spawn_in_room(wave, global_position + Vector2(side * start_x, -bn("wave_height")))


## Keep a teleport target inside the room's painted rect and out of solid tiles.
func clamp_to_room(pos: Vector2) -> Vector2:
	if room == null:
		return pos
	var rect := room.rect_px()
	rect.position += room.global_position
	rect = rect.grow(-Room.TILE)
	pos.x = clampf(pos.x, rect.position.x, rect.end.x)
	pos.y = clampf(pos.y, rect.position.y, rect.end.y)
	var tries := 0
	while tries < 8 and room.kind_at(room.to_local(pos + Vector2(0, -cn("body_h") / 2.0))) == "solid":
		pos.y += Room.TILE
		tries += 1
	return pos
