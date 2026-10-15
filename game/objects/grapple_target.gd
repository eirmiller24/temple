class_name GrappleTarget
extends Area2D
## An Area2D on the `grapple` layer that forwards grapple_hit(player) to
## its owner object. The player's hook raycast reports the Area it hit,
## and the object decides whether it is an anchor (pull the player) or
## something to pull (returns "pull") — or neither.

var target: Node


func grapple_hit(player: Node2D) -> String:
	if target != null and target.has_method("grapple_hit"):
		return target.grapple_hit(player)
	return "none"


## What grapple_hit would answer, without side effects (the aim reticle).
func grapple_mode(player: Node2D) -> String:
	if target != null and target.has_method("grapple_mode"):
		return target.grapple_mode(player)
	return "none"
