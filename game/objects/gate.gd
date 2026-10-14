@tool
class_name Gate
extends RoomObject
## A wired portcullis: a `w` x `h` tile slab that is solid while closed
## and slides up out of the way while any button/lever on its `channel`
## is active (`inverted` flips that). Author it over EMPTY Collision
## cells — it supplies its own StaticBody2D. Position is the slab's
## bottom-centre (FEET of the slab).

@export var w: int = 1:
	set(v):
		w = maxi(v, 1)
		queue_redraw()
@export var h: int = 3:
	set(v):
		h = maxi(v, 1)
		queue_redraw()
## Open when the channel is INACTIVE instead.
@export var inverted: bool = false

var is_open := false
var _body: StaticBody2D
var _shape: CollisionShape2D
var _slab: Node2D
var _target_y := 0.0


func _setup_runtime() -> void:
	_body = StaticBody2D.new()
	_body.name = "Body"
	_body.collision_layer = LAYER_WORLD
	_body.collision_mask = 0
	_shape = CollisionShape2D.new()
	_shape.shape = make_rect(Vector2(w, h) * Room.TILE)
	_shape.position = Vector2(0, -h * Room.TILE / 2.0)
	_body.add_child(_shape)
	add_child(_body)
	_slab = Node2D.new()
	_slab.name = "Slab"
	_slab.draw.connect(_draw_slab)
	add_child(_slab)
	var wiring := Game.wiring()
	if wiring != null:
		wiring.channel_changed.connect(_on_channel)
		_apply(wiring.is_active(channel), true)
	else:
		_apply(false, true)


func _on_channel(ch: int, active: bool) -> void:
	if ch == channel:
		_apply(active)


func _apply(active: bool, instant: bool = false) -> void:
	var open := active != inverted
	if open == is_open and not instant:
		return
	is_open = open
	_shape.disabled = open
	_target_y = -h * Room.TILE if open else 0.0
	if not instant:
		sfx("gate_open" if open else "gate_close")
		Game.juice().shake(1.5, 0.15)
	else:
		_slab.position.y = _target_y


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _slab == null:
		return
	var speed := cfg_num("gate", "open_speed")
	_slab.position.y = move_toward(_slab.position.y, _target_y, speed * delta)


func _draw_slab() -> void:
	var size := Vector2(w, h) * Room.TILE
	var r := Rect2(Vector2(-size.x / 2.0, -size.y), size)
	_slab.draw_rect(r, Color("2b2733"))
	_slab.draw_rect(r, Color("5a5466"), false, 2.0)
	# Bars.
	var bars := maxi(w * 2, 2)
	for i in bars:
		var x := r.position.x + (i + 0.5) * size.x / bars
		_slab.draw_line(Vector2(x, r.position.y + 4), Vector2(x, r.end.y - 4), Color("77708a"), 3.0)
	for j in range(1, h):
		var y := r.position.y + j * Room.TILE
		_slab.draw_line(Vector2(r.position.x + 3, y), Vector2(r.end.x - 3, y), Color("3d3848"), 2.0)


func _gizmo_color() -> Color:
	return Color(0.6, 0.6, 1.0)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	_draw_box(Vector2(w, h) * Room.TILE, true)
	_draw_label("gate ch%d%s" % [channel, " (inverted)" if inverted else ""], -h * Room.TILE - 6)
