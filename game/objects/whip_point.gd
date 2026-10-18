@tool
class_name WhipPoint
extends RoomObject
## A thin beam the whip's end can wrap round (design §10: the whip swings
## from them). Its own `whip` physics layer, separate from the grappling
## hook's `grapple` layer: the hook needs something soft to bite into, the
## whip something thin to wrap. A whip swing whose aim line reaches it
## latches on and the player swings below it (Player._try_whip_latch);
## jump lets go. Position is the beam's centre.

const LAYER_WHIP := 1 << 14

## Beam length in px (presentation and the latch area's width).
@export var length: float = 32.0:
	set(v):
		length = maxf(v, 8.0)
		queue_redraw()

var _area: Area2D


func _setup_runtime() -> void:
	_area = Area2D.new()
	_area.name = "WhipLatch"
	_area.collision_layer = LAYER_WHIP
	_area.collision_mask = 0
	_area.monitoring = false
	var s := CollisionShape2D.new()
	s.shape = make_rect(Vector2(length, 10.0))
	_area.add_child(s)
	add_child(_area)
	_area.set_meta("whip_point", self)
	add_to_group("whip_points")   # the whip's aim assist looks for these


## Where the rope hangs from (world space).
func latch_point() -> Vector2:
	return global_position


func _gizmo_color() -> Color:
	return Color(0.9, 0.75, 0.45)


func _draw() -> void:
	var r := Rect2(Vector2(-length / 2.0, -3.0), Vector2(length, 6.0))
	draw_rect(r, Color("6b4a2e"))
	draw_rect(r, Color("a07a50"), false, 1.0)
	if Engine.is_editor_hint():
		_draw_label("whip point", -10)
