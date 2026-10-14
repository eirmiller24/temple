class_name Aberration
extends Boss
## Riftmaw (second boss). Three attacks, picked by `weights`:
##   LASH        tell → "attack" → a wide hitbox in front (lash_*). Only
##               chosen when the player is within lash_range; otherwise it
##               walks closer and re-rolls on the next gap.
##   BLINK_SLAM  short tell → vanishes (hurtbox off, sprite hidden, no
##               contact) for blink_out → reappears slam_hover_height above
##               the player and hangs there pulsing for slam_hover (the
##               tell) → drops at slam_fall_speed → on landing a feet hitbox
##               (slam_*) plus two Shockwaves (wave_*).
##   VOLLEY      tell → spawns orb_count HomingOrbs (orb_count_p2 in phase
##               2) fanned by orb_spread_deg that steer toward the player at
##               orb_turn rad/s for orb_lifetime.
## Phase 2 at phase2_frac HP shortens every tell by tell_mult_p2.
## hurt_stun 0 / knockback_resist 1: hits flash it but never stagger it.
##
## Brain block "aberration": the Boss keys plus lash_range, lash_size,
## lash_damage, lash_knockback, lash_startup, lash_active, lash_recover,
## blink_tell, blink_out, slam_hover, slam_hover_height, slam_fall_speed,
## slam_fall_timeout, slam_size, slam_damage, slam_knockback, slam_active,
## slam_recover, orb_count, orb_count_p2, orb_interval, orb_speed, orb_turn,
## orb_lifetime, orb_damage, orb_knockback, orb_radius, orb_aim_height,
## orb_spread_deg, mouth_offset [x fwd, y up], volley_recover.

const ORB_COLOR := Color(0.7, 0.35, 1.0)

var _lash_box: Hitbox
var _slam_box: Hitbox


func behavior_name() -> String:
	return "aberration"


func _species_ready() -> void:
	super._species_ready()
	_lash_box = make_hitbox("Lash", bv("lash_size"), bi("lash_damage"), bv("lash_knockback"), "melee")
	_slam_box = make_hitbox("Slam", bv("slam_size"), bi("slam_damage"), bv("slam_knockback"), "slam")


func _pick_attack() -> String:
	var id := super._pick_attack()
	if id == "lash" and not player_in_range(bn("lash_range")):
		return "approach"
	return id


func _run_attack(id: String) -> void:
	match id:
		"lash":
			await _lash()
		"blink_slam":
			await _blink_slam()
		"volley":
			await _volley()
		"approach":
			pass   # too far to lash: _end_attack rolls a fresh gap while we walk in
		_:
			push_error("%s: unknown attack '%s' in weights" % [ctx, id])


func _lash() -> void:
	face_player()
	if not await tell(bn("tell_time") * tell_mult()):
		return
	state = State.ATTACK
	sprite.stop()
	SpriteDb.play(sprite, "attack")
	var size := bv("lash_size")
	_lash_box.position = Vector2(facing * (cn("body_w") / 2.0 + size.x / 2.0), -size.y / 2.0)
	if not await wait(bn("lash_startup")):
		return
	Sfx.play("lash", self)
	if not await pulse_box(_lash_box, bn("lash_active")):
		return
	await wait(bn("lash_recover"))


func _blink_slam() -> void:
	face_player()
	if not await tell(bn("blink_tell") * tell_mult()):
		return
	state = State.HIDDEN
	_hide(true)
	Sfx.play("boss_blink", self)
	if not await wait(bn("blink_out")):
		_hide(false)
		return
	var p := player()
	var above := (p.global_position if p != null else global_position) + Vector2(0, -bn("slam_hover_height"))
	global_position = clamp_to_room(above)
	face_player()
	# Hover: visible and hittable again, still weightless, pulsing as the tell.
	sprite.visible = true
	hurtbox.enabled = true
	state = State.TELL
	SpriteDb.play(sprite, "tell", ["idle"])
	if not await wait(bn("slam_hover") * tell_mult()):
		_hide(false)
		return
	_hide(false)
	state = State.ATTACK
	velocity = Vector2(0, bn("slam_fall_speed"))
	sprite.stop()
	SpriteDb.play(sprite, "attack")
	var t0 := clock
	while not is_on_floor() and clock - t0 < bn("slam_fall_timeout"):
		velocity.y = bn("slam_fall_speed")
		if not await step():
			return
	velocity = Vector2.ZERO
	var size := bv("slam_size")
	_slam_box.position = Vector2(0, -size.y / 2.0)
	slam_shock()
	if not await pulse_box(_slam_box, bn("slam_active")):
		return
	await wait(bn("slam_recover"))


## Vanish (untargetable, no touch damage, weightless) or come back. Never
## touches `state`: callers set it, and die() must keep DEAD.
func _hide(on: bool) -> void:
	if state == State.DEAD:
		return
	hurtbox.enabled = not on
	sprite.visible = not on
	contact_enabled = not on
	uses_gravity = not on
	if on:
		velocity = Vector2.ZERO


func _volley() -> void:
	face_player()
	if not await tell(bn("tell_time") * tell_mult()):
		return
	state = State.ATTACK
	sprite.stop()
	SpriteDb.play(sprite, "attack")
	var count := bi("orb_count_p2") if phase == 2 else bi("orb_count")
	var spread := deg_to_rad(bn("orb_spread_deg"))
	var mouth := bv("mouth_offset")
	for k in count:
		var fan := spread * (float(k) - float(count - 1) / 2.0)
		var dir := Vector2(facing, 0.0).rotated(fan * facing)
		var orb := HomingOrb.new()
		orb.setup_enemy(bi("orb_damage"), dir, bn("orb_speed"), bn("orb_lifetime"), 0.0,
				bv("orb_knockback"), self, ORB_COLOR, bn("orb_radius"))
		orb.homing_target = player()
		orb.turn_rate = bn("orb_turn")
		orb.aim_height = bn("orb_aim_height")
		spawn_in_room(orb, global_position + Vector2(facing * mouth.x, mouth.y))
		Sfx.play("enemy_shoot", self)
		if not await wait(bn("orb_interval")):
			return
	await wait(bn("volley_recover"))


func _interrupted() -> void:
	if _lash_box != null:
		_lash_box.active = false
	if _slam_box != null:
		_slam_box.active = false
