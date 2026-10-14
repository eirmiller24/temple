@tool
class_name FloorButton
extends RoomObject
## A pressure plate. Pressed by standing weight — the player, a push
## block, an enemy. Momentary buttons release when the weight leaves;
## latching ones stay pressed forever (and can also be pressed by an
## attack). Drives `channel` while pressed. Position is FEET.

@export var latching: bool = false:
	set(v):
		latching = v
		queue_redraw()

var pressed := false
var _area: SwitchArea
var _sprite: AnimatedSprite2D


func _setup_runtime() -> void:
	_area = SwitchArea.new()
	_area.name = "Plate"
	_area.target = self
	_area.collision_layer = LAYER_SWITCH if latching else 0
	_area.collision_mask = LAYER_PLAYER | LAYER_PUSHABLE | LAYER_ENEMY
	var shape := CollisionShape2D.new()
	shape.shape = make_rect(Vector2(Room.TILE * 0.8, 10))
	shape.position = Vector2(0, -5)
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(func(_b: Node) -> void: _refresh())
	_area.body_exited.connect(func(_b: Node) -> void: _refresh())
	_sprite = add_sprite("button", 1.0)
	_show_state()


## Latching buttons also take hits (a slingshot stone from across the room).
func take_hit(_info: Dictionary) -> void:
	if latching and not pressed:
		_set_pressed(true)


func _refresh() -> void:
	if _area == null:
		return
	var weight := _area.get_overlapping_bodies().size() > 0
	if latching:
		if weight and not pressed:
			_set_pressed(true)
	else:
		if weight != pressed:
			_set_pressed(weight)


func _set_pressed(on: bool) -> void:
	pressed = on
	var w := Game.wiring()
	if w != null:
		w.drive(channel, self, on)
	sfx("button_press" if on else "button_release")
	_show_state()


func _show_state() -> void:
	if _sprite == null:
		queue_redraw()
		return
	var sprites := Game.sprites()
	if sprites != null:
		sprites.play(_sprite, "pressed" if pressed else "raised", ["raised"])


func _gizmo_color() -> Color:
	return Color(1.0, 0.75, 0.3)


func _draw() -> void:
	if not Engine.is_editor_hint():
		if _sprite == null:
			# No art: draw a plate.
			var c := Color(0.5, 0.45, 0.35) if not pressed else Color(0.35, 0.3, 0.25)
			draw_rect(Rect2(Vector2(-12, -6 if not pressed else -3), Vector2(24, 6 if not pressed else 3)), c)
		return
	_draw_feet()
	_draw_box(Vector2(26, 6), true)
	_draw_label("button ch%d%s" % [channel, " (latch)" if latching else ""])
