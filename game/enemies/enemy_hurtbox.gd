class_name EnemyHurtbox
extends Hurtbox
## The Hurtbox every Enemy builds for itself. A Hitbox reports the AREA it
## overlapped as the hit target, so the player's `hit_landed` handler sees
## this node, not the enemy — it asks `has_method("is_enemy")` to decide
## whether to play its hit sound. This subclass answers for its owner.

var enemy: Enemy = null


func is_enemy() -> bool:
	return true
