class_name Hurtbox
extends Area2D
## A damageable volume. Hitboxes call take_hit(info); the hurtbox forwards
## to its owner's `on_hit(info)` and emits `hurt`. Owners decide what a
## hit means (HP, knockback, i-frames); a hurtbox is only the shape.

signal hurt(info: Dictionary)

## Set false during i-frames or when the owner is dead/untargetable.
var enabled := true


func _ready() -> void:
	monitoring = false
	monitorable = true


func take_hit(info: Dictionary) -> void:
	if not enabled:
		return
	var target := owner if owner != null else get_parent()
	if target != null and target.has_method("on_hit"):
		target.on_hit(info)
	hurt.emit(info)
