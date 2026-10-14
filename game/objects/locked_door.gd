@tool
class_name LockedDoor
extends RoomObject
## A door that needs an item (default a small key, consumed) and stays
## open forever in that save: the first opening sets a permanent flag
## named after the room and the node, so it never locks again. Author it
## over EMPTY Collision cells in a doorway; it supplies the body. Position
## is the door's bottom-centre. Interact (LB / E) while standing in front.

## Item id from data/items.json that opens it.
@export var needs_item: String = "small_key":
	set(v):
		needs_item = v
		queue_redraw()
## Consume the item on opening (keys yes; a tool no).
@export var consumes: bool = true
@export var w: int = 1:
	set(v):
		w = maxi(v, 1)
		queue_redraw()
@export var h: int = 3:
	set(v):
		h = maxi(v, 1)
		queue_redraw()

var is_open := false
var _body: StaticBody2D
var _shape: CollisionShape2D
var _interact: InteractForwarder
var _slab: Node2D


func flag_name() -> String:
	return "door_%s_%s" % [room.name if room != null else "room", name]


func _setup_runtime() -> void:
	_body = StaticBody2D.new()
	_body.collision_layer = LAYER_WORLD
	_body.collision_mask = 0
	_shape = CollisionShape2D.new()
	_shape.shape = make_rect(Vector2(w, h) * Room.TILE)
	_shape.position = Vector2(0, -h * Room.TILE / 2.0)
	_body.add_child(_shape)
	add_child(_body)
	_interact = InteractForwarder.new()
	_interact.target = self
	_interact.collision_layer = LAYER_INTERACT
	_interact.collision_mask = 0
	var s := CollisionShape2D.new()
	s.shape = make_rect(Vector2((w + 2) * Room.TILE, h * Room.TILE))
	s.position = Vector2(0, -h * Room.TILE / 2.0)
	_interact.add_child(s)
	add_child(_interact)
	_slab = Node2D.new()
	_slab.draw.connect(_draw_slab)
	add_child(_slab)
	var state := Game.state()
	if state != null and state.has_flag(flag_name()):
		_open(true)


## Called by the player's interact (via the InteractForwarder area).
func interact(_player: Node) -> void:
	if is_open:
		return
	var state := Game.state()
	if state == null:
		return
	if needs_item != "" and not state.has_item(needs_item):
		sfx("door_locked")
		var world := get_tree().get_first_node_in_group("world")
		if world != null:
			var def: Dictionary = state.item_def(needs_item)
			world.toast("Locked. Needs %s." % String(def.get("name", needs_item)))
		return
	if needs_item != "" and consumes:
		state.remove_item(needs_item, 1)
	state.set_flag(flag_name())
	sfx("door_unlock")
	_open(false)


func _open(instant: bool) -> void:
	is_open = true
	_shape.set_deferred("disabled", true)
	_interact.set_deferred("monitorable", false)
	if instant:
		_slab.visible = false
	else:
		sfx("door_open")
		var tw := create_tween()
		tw.tween_property(_slab, "position:y", -h * Room.TILE, 0.6)
		tw.tween_callback(func() -> void: _slab.visible = false)


func _draw_slab() -> void:
	var size := Vector2(w, h) * Room.TILE
	var r := Rect2(Vector2(-size.x / 2.0, -size.y), size)
	_slab.draw_rect(r, Color("3a2d22"))
	_slab.draw_rect(r, Color("7a5a3a"), false, 2.0)
	_slab.draw_line(r.position + Vector2(size.x / 2.0, 4), r.position + Vector2(size.x / 2.0, size.y - 4), Color("5a4430"), 2.0)
	_slab.draw_circle(r.position + Vector2(size.x * 0.7, size.y * 0.55), 3.0, Color("d8b860"))


func _gizmo_color() -> Color:
	return Color(1.0, 0.45, 0.45)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	_draw_box(Vector2(w, h) * Room.TILE, true)
	_draw_label("door: %s" % needs_item, -h * Room.TILE - 6)
