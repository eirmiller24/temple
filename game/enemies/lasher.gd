class_name Lasher
extends Enemy
## The bush lasher: planted (gravity only settles it; it never walks).
## Faces the player within `sight_range`; within `lash_range` it tells
## with a long windup, plays "attack" and swings a `lash_size` hitbox in
## front of itself for `lash_active` seconds (strong knockback). While the
## swing is in progress it is armoured: hits still take HP but cannot
## stagger or push it (knockback resist 1). Between swings it is a normal
## soft target. Contact damage the whole time.
##
## Brain block "lasher": sight_range, lash_range, tell_time, lash_startup
## (s from "attack" start to the hitbox), lash_active, lash_recover,
## lash_cooldown, lash_size [w,h], lash_damage, lash_knockback [x,y].

var _box: Hitbox
var _cooldown := 0.0


func behavior_name() -> String:
	return "lasher"


func _species_ready() -> void:
	_box = make_hitbox("Lash", bv("lash_size"), bi("lash_damage"), bv("lash_knockback"), "melee")
	_cooldown = bn("lash_cooldown")


func _think(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, cn("friction") * delta)
	_cooldown -= delta
	if state != State.IDLE:
		return
	SpriteDb.play(sprite, "idle")
	if player_in_range(bn("sight_range")):
		face_player()
	if _cooldown <= 0.0 and is_on_floor() and player_in_range(bn("lash_range")):
		_lash()


func _lash() -> void:
	attacks += 1
	face_player()
	if not await tell(bn("tell_time")):
		return
	state = State.ATTACK
	sprite.stop()
	SpriteDb.play(sprite, "attack")
	var size := bv("lash_size")
	_box.position = Vector2(facing * (cn("body_w") / 2.0 + size.x / 2.0), -size.y / 2.0)
	if not await wait(bn("lash_startup")):
		return
	Sfx.play("lash", self)
	if not await pulse_box(_box, bn("lash_active")):
		return
	if not await wait(bn("lash_recover")):
		return
	state = State.IDLE
	_cooldown = bn("lash_cooldown")


func _knockback_resist() -> float:
	return 1.0 if state == State.ATTACK else cn("knockback_resist")


func _hit_interrupts() -> bool:
	return state != State.ATTACK and cn("hurt_stun") > 0.0


func _interrupted() -> void:
	if _box != null:
		_box.active = false


func _hurt_ended() -> void:
	_cooldown = maxf(_cooldown, bn("lash_recover"))
