class_name InteractForwarder
extends Area2D
## An Area2D on the `interact` layer whose interact(player) forwards to
## its owner object — the player's interact sensor only sees Areas.

var target: Node


func interact(player: Node) -> void:
	if target != null and target.has_method("interact"):
		target.interact(player)
