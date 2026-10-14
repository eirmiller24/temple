class_name Walker
extends Enemy
## The mushroom. Patrols at `speed`, turning at walls and ledges. When the
## player is within `spore_range` (and the attack is off cooldown) it
## stops, tells, plays "spore" and puffs a SporeCloud in front of itself;
## the cloud is a one-hit Hitbox that lingers. Contact damage the whole
## time; a hit during the tell or windup cancels the puff.
##
## Brain block "walker": turn_cooldown (s between direction flips),
## ledge_probe (px of drop that counts as a ledge), first_spore_delay (s
## after spawning before it may puff), spore_range, tell_time,
## spore_delay (s from "spore" start to the cloud), spore_recover,
## spore_cooldown, cloud_offset [x forward, y up], cloud_radius,
## cloud_lifetime, cloud_damage, cloud_knockback [x,y].

var _turn_cd := 0.0
var _cooldown := 0.0


func behavior_name() -> String:
	return "walker"


func _species_ready() -> void:
	_cooldown = bn("first_spore_delay")


func _think(delta: float) -> void:
	_turn_cd -= delta
	_cooldown -= delta
	match state:
		State.IDLE, State.MOVE:
			if is_on_floor():
				if _turn_cd <= 0.0 and (_wall_ahead() or _ledge_ahead(bn("ledge_probe"))):
					facing = -facing
					_turn_cd = bn("turn_cooldown")
				velocity.x = facing * cn("speed")
				state = State.MOVE
				SpriteDb.play(sprite, "walk", ["idle"])
				if _cooldown <= 0.0 and player_in_range(bn("spore_range")):
					_spore()
		State.TELL, State.ATTACK:
			velocity.x = move_toward(velocity.x, 0.0, cn("friction") * delta)


func _spore() -> void:
	attacks += 1
	face_player()
	if not await tell(bn("tell_time")):
		return
	state = State.ATTACK
	sprite.stop()
	SpriteDb.play(sprite, "spore", ["attack"])
	if not await wait(bn("spore_delay")):
		return
	var cloud := SporeCloud.new()
	cloud.setup(self, bi("cloud_damage"), bv("cloud_knockback"), bn("cloud_radius"), bn("cloud_lifetime"))
	var off := bv("cloud_offset")
	spawn_in_room(cloud, global_position + Vector2(facing * off.x, off.y))
	Sfx.play("spore", self)
	if not await wait(bn("spore_recover")):
		return
	state = State.IDLE
	_cooldown = bn("spore_cooldown")


func _hurt_ended() -> void:
	_cooldown = maxf(_cooldown, bn("turn_cooldown"))
