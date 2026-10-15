class_name AimReticle
extends Node2D
## The free-aim crosshair. The player places it every physics frame while
## aim is held (Player._update_reticle): at the end of the aimed item's
## reach, or on the first thing that item would hit. `latch` turns it red
## — the grappling hook would catch what it's on. Top-level, so its
## position is world space.

const COLOR := Color(1, 1, 0.8, 0.9)
const LATCH_COLOR := Color(1.0, 0.2, 0.15, 1.0)
const OUTLINE := Color(0, 0, 0, 0.6)

## True when the reticle sits on something the item would hit (not just
## the end of its reach): draws a centre dot.
var on_target := false
var latch := false


func _init() -> void:
	top_level = true
	z_index = 5
	visible = false


func place(at: Vector2, hit: bool, can_latch: bool) -> void:
	global_position = at.round()
	if hit != on_target or can_latch != latch:
		on_target = hit
		latch = can_latch
		queue_redraw()
	visible = true


func _draw() -> void:
	var c := LATCH_COLOR if latch else COLOR
	for pass_i in 2:
		var col := OUTLINE if pass_i == 0 else c
		var w := 3.0 if pass_i == 0 else 1.0
		draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 16, col, w)
		for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(d * 7.0, d * 10.0, col, w)
	if on_target:
		draw_circle(Vector2.ZERO, 1.5, c)
