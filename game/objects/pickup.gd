@tool
class_name Pickup
extends RoomObject
## An item lying in the room. Walk over it to take it. A `flag` makes it
## once-ever in that save (the flag suppresses its own spawn — naming the
## flag IS the suppression, nothing else to author). Dropped items are
## Pickups too (UiItemVerbs.spawn_pickup → setup()). Position is FEET.

## Item id from data/items.json.
@export var item_id: String = "small_key":
	set(v):
		item_id = v
		queue_redraw()
@export var count: int = 1
## Permanent flag set on collection; "" = respawns every visit.
@export var flag: String = "":
	set(v):
		flag = v
		queue_redraw()
## Draw a chest instead of the floating item (a one-time cache).
@export var appearance: String = "item"

var _area: Area2D
var _sprite: AnimatedSprite2D
var _grace := 0.0
var _t := 0.0
var _taken := false


func setup(id: String, n: int) -> void:
	item_id = id
	count = n
	flag = ""
	_grace = 1.0


func _setup_runtime() -> void:
	var state := Game.state()
	if flag != "" and state != null and state.has_flag(flag):
		queue_free()
		return
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = LAYER_PLAYER
	var s := CollisionShape2D.new()
	s.shape = make_rect(Vector2(24, 24))
	s.position = Vector2(0, -12)
	_area.add_child(s)
	add_child(_area)
	_area.body_entered.connect(_on_body)
	if appearance == "chest":
		_sprite = add_sprite("chest", 0.9)
	add_to_group("pickups")


func _on_body(body: Node) -> void:
	if _taken or _grace > 0.0 or not body.is_in_group("player"):
		return
	var state := Game.state()
	if state == null:
		return
	var def: Dictionary = state.item_def(item_id)
	if def.is_empty():
		return
	_taken = true
	state.add_item(item_id, count)
	if flag != "":
		state.set_flag(flag)
	sfx("pickup_key" if String(def.get("kind", "")) == "key" else "pickup")
	var world := get_tree().get_first_node_in_group("world")
	if world != null:
		world.toast("Got %s%s" % [String(def.get("name", item_id)), (" ×%d" % count) if count > 1 else ""])
	queue_free()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_grace = maxf(_grace - delta, 0.0)
	_t += delta
	if _sprite == null:
		queue_redraw()


func _draw() -> void:
	var c := Color(0.95, 0.85, 0.4)
	if Engine.is_editor_hint():
		_draw_feet()
		_draw_box(Vector2(20, 20), true)
		_draw_label("%s x%d%s" % [item_id, count, (" flag:" + flag) if flag != "" else ""])
		return
	if _sprite != null:
		return
	var bob := sin(_t * 3.0) * 3.0
	var p := Vector2(0, -12 + bob)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9), p + Vector2(7, 0), p + Vector2(0, 9), p + Vector2(-7, 0)]), c)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(3, 0), p + Vector2(0, 5), p + Vector2(-3, 0)]), Color(1, 1, 0.9))
