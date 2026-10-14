class_name HomingOrb
extends Projectile
## Riftmaw's volley: an enemy Projectile that steers toward
## `homing_target` (the player) by turning its velocity at most
## `turn_rate` rad/s each frame, aiming `aim_height` px above the target's
## origin (its feet). Everything else — speed, lifetime, damage, knockback,
## wall despawn — is the stock Projectile set up through setup_enemy.

var homing_target: Node2D = null
var turn_rate := 2.0
var aim_height := 20.0


func _physics_process(delta: float) -> void:
	if homing_target != null and is_instance_valid(homing_target) and velocity.length() > 0.0:
		var goal := homing_target.global_position + Vector2(0, -aim_height)
		var want := (goal - global_position).angle()
		var have := velocity.angle()
		var turned := rotate_toward(have, want, turn_rate * delta)
		velocity = Vector2.from_angle(turned) * velocity.length()
	super._physics_process(delta)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius * 1.6, 0.0, TAU, 16, Color(color, 0.45), 1.0)
	draw_line(Vector2.ZERO, -velocity.normalized() * radius * 3.0, Color(color, 0.4), 1.5)
