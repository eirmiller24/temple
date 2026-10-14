class_name Guardian
extends Boss
## The Stone Guardian (first boss). Three attacks, picked by `weights`:
##   SLAM    tell → "attack" → a wide low hitbox at its feet (slam_damage)
##           plus a Shockwave along the floor to each side (wave_*).
##   VOLLEY  tell → lobs throw_count rocks (arcing Projectiles, rock_*)
##           at the player's feet, spread by rock_spread px; phase 2 throws
##           throw_count_p2.
##   CHARGE  tell → runs at charge_speed with a body-sized hitbox
##           (charge_damage, big knockback) until a wall or ledge or
##           charge_max_time, then is stunned for charge_stun (its window).
## Phase 2 at phase2_frac HP shortens every tell by tell_mult_p2.
## hurt_stun is 0 and knockback_resist 1 in its JSON: hits flash it but
## never stagger it — the fight is 40 one-damage hits.
##
## Brain block "guardian": the Boss keys plus slam_delay, slam_size [w,h],
## slam_damage, slam_knockback, slam_active, slam_recover, throw_count,
## throw_count_p2, throw_interval, rock_speed, rock_gravity, rock_radius,
## rock_lifetime, rock_damage, rock_knockback, hand_offset [x fwd, y up],
## rock_spread, volley_recover, charge_speed, charge_damage,
## charge_knockback, charge_max_time, charge_stun, charge_box [w,h],
## charge_anim_speed.

const ROCK_COLOR := Color(0.62, 0.58, 0.5)

var _slam_box: Hitbox
var _charge_box: Hitbox


func behavior_name() -> String:
	return "guardian"


func _species_ready() -> void:
	super._species_ready()
	_slam_box = make_hitbox("Slam", bv("slam_size"), bi("slam_damage"), bv("slam_knockback"), "slam")
	_charge_box = make_hitbox("Charge", bv("charge_box"), bi("charge_damage"), bv("charge_knockback"), "charge")


func _run_attack(id: String) -> void:
	match id:
		"slam":
			await _slam()
		"volley":
			await _volley()
		"charge":
			await _charge()
		_:
			push_error("%s: unknown attack '%s' in weights" % [ctx, id])


func _slam() -> void:
	face_player()
	if not await tell(bn("tell_time") * tell_mult()):
		return
	state = State.ATTACK
	sprite.stop()
	SpriteDb.play(sprite, "attack")
	if not await wait(bn("slam_delay")):
		return
	var size := bv("slam_size")
	_slam_box.position = Vector2(0, -size.y / 2.0)
	slam_shock()
	if not await pulse_box(_slam_box, bn("slam_active")):
		return
	await wait(bn("slam_recover"))


func _volley() -> void:
	face_player()
	if not await tell(bn("tell_time") * tell_mult()):
		return
	state = State.ATTACK
	var count := bi("throw_count_p2") if phase == 2 else bi("throw_count")
	var spread := bn("rock_spread")
	for k in count:
		face_player()
		sprite.stop()
		SpriteDb.play(sprite, "attack")
		var hand := bv("hand_offset")
		var from := global_position + Vector2(facing * hand.x, hand.y)
		var p := player()
		# No player (tests): lob toward the edge of the aggro range.
		var target := global_position + Vector2(facing * bn("aggro_range"), 0.0)
		if p != null:
			target = p.global_position + Vector2(spread * (float(k) - float(count - 1) / 2.0), 0.0)
		var dir := EnemyKit.ballistic_dir(from, target, bn("rock_speed"), bn("rock_gravity"), true)
		var rock := Projectile.new()
		rock.setup_enemy(bi("rock_damage"), dir, bn("rock_speed"), bn("rock_lifetime"), bn("rock_gravity"),
				bv("rock_knockback"), self, ROCK_COLOR, bn("rock_radius"))
		spawn_in_room(rock, from)
		Sfx.play("enemy_shoot", self)
		if not await wait(bn("throw_interval")):
			return
	await wait(bn("volley_recover"))


func _charge() -> void:
	face_player()
	if not await tell(bn("tell_time") * tell_mult()):
		return
	state = State.ATTACK
	contact_enabled = false
	var box := bv("charge_box")
	_charge_box.position = Vector2(facing * (box.x - cn("body_w")) / 2.0, -box.y / 2.0)
	_charge_box.facing = facing
	_charge_box.active = true
	SpriteDb.play(sprite, "walk", ["idle"])
	sprite.speed_scale = bn("charge_anim_speed")
	Sfx.play("boss_charge", self)
	var t0 := clock
	var hit_wall := false
	while clock - t0 < bn("charge_max_time"):
		velocity.x = facing * bn("charge_speed")
		if not await step():
			_charge_box.active = false
			return
		if _wall_ahead() or _ledge_ahead(bn("ledge_probe")):
			hit_wall = true
			break
	_charge_box.active = false
	velocity.x = 0.0
	sprite.speed_scale = 1.0
	contact_enabled = true
	if hit_wall:
		var shake: Vector2 = bv("slam_shake")
		Juice.shake(shake.x, shake.y)
		Sfx.play("boss_slam", self)
	sprite.stop()
	SpriteDb.play(sprite, "hurt", ["idle"])
	await wait(bn("charge_stun"))


func _interrupted() -> void:
	if _slam_box != null:
		_slam_box.active = false
	if _charge_box != null:
		_charge_box.active = false
