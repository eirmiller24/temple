class_name Hopper
extends Enemy
## The slimes (green_slime, blue_slime, orange_slime — one script, three
## JSON files). Sits idle; when the player comes within `aggro_range` it
## tells (readable windup, white pulse) and hops at them with
## (hop_vx, hop_vy). Damage is contact only, live the whole hop. On landing
## it plays "attack" as a squash, then waits `hop_cooldown` before the
## next hop. A hit during the tell cancels the hop.
##
## Brain block "hopper": aggro_range, idle_wait (s before the first hop),
## tell_time, hop_vx, hop_vy (negative = up), hop_cooldown, min_air_time
## (s airborne before a floor contact counts as landing).

var _cooldown := 0.0
var _air := 0.0


func behavior_name() -> String:
	return "hopper"


func _species_ready() -> void:
	_cooldown = bn("idle_wait")


func _think(delta: float) -> void:
	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, cn("friction") * delta)
			if not (sprite.animation == "attack" and sprite.is_playing()):
				SpriteDb.play(sprite, "idle")
			_cooldown -= delta
			if is_on_floor() and _cooldown <= 0.0 and player_in_range(bn("aggro_range")):
				_hop()
		State.TELL:
			velocity.x = move_toward(velocity.x, 0.0, cn("friction") * delta)
		State.ATTACK:
			_air += delta
			if _air >= bn("min_air_time") and is_on_floor():
				_land()


func _hop() -> void:
	attacks += 1
	face_player()
	if not await tell(bn("tell_time")):
		return
	face_player()
	state = State.ATTACK
	_air = 0.0
	velocity = Vector2(facing * bn("hop_vx"), bn("hop_vy"))
	SpriteDb.play(sprite, "jump", ["walk"])
	Sfx.play("enemy_hop", self)


func _land() -> void:
	state = State.IDLE
	velocity.x = 0.0
	_cooldown = bn("hop_cooldown")
	Sfx.play("land", self)
	sprite.stop()
	SpriteDb.play(sprite, "attack", ["idle"])


func _hurt_ended() -> void:
	_cooldown = bn("hop_cooldown")
