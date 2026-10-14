class_name Shockwave
extends Projectile
## A ground ripple a boss slam sends along the floor to each side. It is a
## plain enemy Projectile (set up with setup_enemy, gravity 0) that draws
## as a squat crest instead of a dot and dies at the first wall, so the
## numbers (speed, lifetime, damage, knockback) all come from the boss's
## JSON through the caller.

const CREST_STRETCH := Vector2(2.4, 0.9)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, CREST_STRETCH)
	draw_circle(Vector2.ZERO, radius, Color(color, 0.85))
	draw_arc(Vector2(0, -radius * 0.2), radius * 1.35, PI, TAU, 10, Color(1, 1, 0.9, 0.9), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tail := -velocity.normalized() * radius * 4.0
	draw_line(Vector2.ZERO, tail, Color(color, 0.35), 2.0)
