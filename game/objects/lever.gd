@tool
class_name Lever
extends RoomObject
## A switch toggled by hitting it — sword, whip (which reaches it from a
## distance), slingshot stone. Drives `channel` while on. A named `flag`
## is set permanently the first time it lands on, and restores the lever
## to "on" in later visits (how a lever-gated secret stays solved).
## Position is FEET.

## Permanent flag set when first switched on ("" = none).
@export var flag: String = "":
	set(v):
		flag = v
		queue_redraw()
## Start switched on.
@export var starts_on: bool = false

var on := false
var _area: SwitchArea
var _sprite: AnimatedSprite2D
var _cooldown := 0.0


func _setup_runtime() -> void:
	_area = SwitchArea.new()
	_area.name = "Switch"
	_area.target = self
	_area.collision_layer = LAYER_SWITCH
	_area.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.shape = make_rect(Vector2(20, 30))
	shape.position = Vector2(0, -15)
	_area.add_child(shape)
	add_child(_area)
	_sprite = add_sprite("lever", 1.0)
	var state := Game.state()
	var start := starts_on
	if flag != "" and state != null and state.has_flag(flag):
		start = true
	_set_on(start, true)


## Any hit toggles the lever (the SwitchArea child forwards here).
func take_hit(_info: Dictionary) -> void:
	toggle()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_cooldown = maxf(_cooldown - delta, 0.0)


func _set_on(v: bool, silent: bool = false) -> void:
	on = v
	var w := Game.wiring()
	if w != null:
		w.drive(channel, self, on)
	if on and flag != "":
		var state := Game.state()
		if state != null:
			state.set_flag(flag)
	if not silent:
		sfx("lever")
	if _sprite != null:
		_sprite.flip_h = on
	queue_redraw()


func toggle() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = 0.25
	_set_on(not on)


func _gizmo_color() -> Color:
	return Color(1.0, 0.55, 0.3)


func _draw() -> void:
	if not Engine.is_editor_hint():
		if _sprite == null:
			var c := Color(0.6, 0.5, 0.4)
			draw_rect(Rect2(Vector2(-8, -6), Vector2(16, 6)), c)
			draw_line(Vector2(0, -6), Vector2(10 if on else -10, -26), Color(0.8, 0.7, 0.5), 3.0)
		return
	_draw_feet()
	draw_line(Vector2(0, 0), Vector2(Room.TILE * 0.35, -Room.TILE * 0.9), _gizmo_color(), 2.0)
	_draw_label("lever ch%d%s" % [channel, (" flag:" + flag) if flag != "" else ""])
