class_name SwitchArea
extends Area2D
## An Area2D on the `switch` layer that forwards take_hit() to its owner
## object (lever, latching button) — Hitboxes only see the Area they
## overlap, so the object's hit entry point has to live on it.

var target: Node
var method := "take_hit"
## The grappling hook's shot activates it (levers, latching buttons). False
## for hit areas that only care about fire (unlit torch, burnable barrier):
## to the hook they're just in the way.
var hook_switch := true


func take_hit(info: Dictionary) -> void:
	if target != null and target.has_method(method):
		target.call(method, info)
