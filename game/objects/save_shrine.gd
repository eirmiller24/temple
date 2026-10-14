@tool
class_name SaveShrine
extends RoomObject
## A small snake-god statue: interact (LB / E) to save and set the
## respawn point here. Death and Continue return to the last shrine
## used. The shrine doubles as a spawn point: World.load_room() accepts a
## shrine's node name as an entry id. Position is FEET.

var _interact: InteractForwarder
var _sprite: AnimatedSprite2D
var _glow := 0.0


func _setup_runtime() -> void:
	_interact = InteractForwarder.new()
	_interact.target = self
	_interact.collision_layer = LAYER_INTERACT
	_interact.collision_mask = 0
	var s := CollisionShape2D.new()
	s.shape = make_rect(Vector2(48, 40))
	s.position = Vector2(0, -20)
	_interact.add_child(s)
	add_child(_interact)
	_sprite = add_sprite("save_shrine", 1.6)
	add_to_group("save_shrines")


## Feet position for World when this shrine is the respawn entry.
func spawn_position() -> Vector2:
	return global_position


func interact(_player: Node) -> void:
	var state := Game.state()
	var save := Game.autoload("SaveManager")
	if state == null or save == null or room == null:
		return
	state.set_respawn(room.name, name)
	if bool(cfg("save_shrine").get("heal_on_save", true)):
		state.full_heal()
	var slot: int = state.slot_index
	if slot < 0:
		slot = 0
		state.slot_index = 0
	save.save_game(slot)
	sfx("save")
	_glow = 1.0
	var world := get_tree().get_first_node_in_group("world")
	if world != null:
		world.toast("Saved (slot %d)." % (slot + 1))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_glow = maxf(_glow - delta, 0.0)
	queue_redraw()


func _gizmo_color() -> Color:
	return Color(0.6, 1.0, 0.7)


func _draw() -> void:
	if Engine.is_editor_hint():
		_draw_feet()
		_draw_box(Vector2(40, 44), true)
		_draw_label("save shrine '%s'" % name)
		return
	if _sprite == null:
		draw_rect(Rect2(Vector2(-14, -40), Vector2(28, 40)), Color("3a3344"))
		draw_rect(Rect2(Vector2(-14, -40), Vector2(28, 40)), Color("8a7a5a"), false, 2.0)
	if _glow > 0.0:
		draw_circle(Vector2(0, -26), 30.0 * (1.0 - _glow) + 10.0, Color(0.6, 1.0, 0.6, _glow * 0.4))
