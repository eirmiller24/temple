@tool
class_name GrappleAnchor
extends RoomObject
## A fixed ring the grappling hook can latch onto: the hook pulls the
## PLAYER to it (design §10 — anchored objects pull you to them). Place
## it on a wall or ceiling; position is the ring's centre.

var _area: GrappleTarget
var _t := 0.0


func _setup_runtime() -> void:
	_area = GrappleTarget.new()
	_area.target = self
	_area.collision_layer = LAYER_GRAPPLE
	_area.collision_mask = 0
	var s := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 10.0
	s.shape = c
	_area.add_child(s)
	add_child(_area)
	# Dedicated latch point: the hook's aim assist looks for these only.
	add_to_group("grapple_anchors")


## Where the hook's aim assist aims (world space).
func latch_point() -> Vector2:
	return global_position


## Grapple contract (the player raycasts and calls this on what it hit).
func grapple_hit(player: Node2D) -> String:
	return grapple_mode(player)


## What grapple_hit would answer, without doing it (the aim reticle asks).
func grapple_mode(_player: Node2D) -> String:
	return "anchor"


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	queue_redraw()


func _gizmo_color() -> Color:
	return Color(0.8, 0.8, 1.0)


func _draw() -> void:
	var pulse := 0.0 if Engine.is_editor_hint() else (sin(_t * 2.0) * 0.5 + 0.5)
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 16, Color("b8b8d0"), 3.0)
	draw_arc(Vector2.ZERO, 4.0, 0.0, TAU, 12, Color("6e6a80"), 2.0)
	if not Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, 11.0 + pulse * 3.0, 0.0, TAU, 20, Color(0.7, 0.9, 1.0, 0.25 + pulse * 0.2), 1.5)
	else:
		_draw_label("grapple anchor", -16)
