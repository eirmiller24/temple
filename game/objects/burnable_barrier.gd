@tool
class_name BurnableBarrier
extends RoomObject
## A wooden barricade (or web, or brush) that blocks the way until it is
## set alight: a burning hit (a dart that flew through a flame) starts it
## burning, it burns for objects.fire.barrier_burn_time — a flame on the
## `fire` layer the whole time, so a dart can catch from it too — then it
## is gone for good (a permanent flag named after the room and node).
## Other hits do nothing. Author it over EMPTY Collision cells; it supplies
## the body. Position is its bottom-centre.

const LAYER_FIRE := 1 << 15

@export var w: int = 1:
	set(v):
		w = maxi(v, 1)
		queue_redraw()
@export var h: int = 3:
	set(v):
		h = maxi(v, 1)
		queue_redraw()

var burning := false
var _burn_left := 0.0
var _body: HitBody
var _switch: SwitchArea
var _fire: Area2D
var _t := 0.0


## The solid. Projectiles stop on solids before their Area can overlap
## anything behind them, so the body takes the hit itself.
class HitBody extends StaticBody2D:
	var target: Node

	func take_hit(info: Dictionary) -> void:
		target.take_hit(info)


func flag_name() -> String:
	return "burnt_%s_%s" % [room.name if room != null else "room", name]


func _setup_runtime() -> void:
	var state := Game.state()
	if state != null and state.has_flag(flag_name()):
		queue_free()
		return
	var size := Vector2(w, h) * Room.TILE
	_body = HitBody.new()
	_body.target = self
	_body.collision_layer = LAYER_WORLD
	_body.collision_mask = 0
	var bs := CollisionShape2D.new()
	bs.shape = make_rect(size)
	bs.position = Vector2(0, -size.y / 2.0)
	_body.add_child(bs)
	add_child(_body)
	# Melee reaches it through the switch layer (a sword's Hitbox is an Area).
	_switch = SwitchArea.new()
	_switch.target = self
	_switch.hook_switch = false
	_switch.collision_layer = LAYER_SWITCH
	_switch.collision_mask = 0
	var ss := CollisionShape2D.new()
	ss.shape = make_rect(size + Vector2(4, 4))
	ss.position = Vector2(0, -size.y / 2.0)
	_switch.add_child(ss)
	add_child(_switch)
	_fire = Area2D.new()
	_fire.collision_layer = 0
	_fire.collision_mask = 0
	_fire.monitoring = false
	var fs := CollisionShape2D.new()
	fs.shape = make_rect(size + Vector2(8, 8))
	fs.position = Vector2(0, -size.y / 2.0)
	_fire.add_child(fs)
	add_child(_fire)


func take_hit(info: Dictionary) -> void:
	if burning or not bool(info.get("fire", false)):
		return
	burning = true
	_burn_left = cfg_num("fire", "barrier_burn_time")
	_fire.set_deferred("collision_layer", LAYER_FIRE)
	sfx("ignite")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if not burning:
		return
	_burn_left -= delta
	queue_redraw()
	if _burn_left <= 0.0:
		var state := Game.state()
		if state != null:
			state.set_flag(flag_name())
		queue_free()


func _gizmo_color() -> Color:
	return Color(0.75, 0.5, 0.25)


func _draw() -> void:
	var size := Vector2(w, h) * Room.TILE
	var r := Rect2(Vector2(-size.x / 2.0, -size.y), size)
	if Engine.is_editor_hint():
		_draw_box(size, true)
		_draw_label("burnable", -size.y - 6)
		return
	var char_k := 0.0
	if burning:
		char_k = 1.0 - clampf(_burn_left / maxf(cfg_num("fire", "barrier_burn_time"), 0.01), 0.0, 1.0)
	var wood := Color("6b4a2e").lerp(Color("201510"), char_k)
	var plank := 8.0
	var x := r.position.x
	while x < r.end.x - 0.5:
		draw_rect(Rect2(x + 1, r.position.y, plank - 2, size.y), wood)
		x += plank
	draw_rect(Rect2(r.position.x, r.position.y + size.y * 0.25, size.x, 4), wood.darkened(0.3))
	draw_rect(Rect2(r.position.x, r.position.y + size.y * 0.7, size.x, 4), wood.darkened(0.3))
	if burning:
		for i in 5:
			var fx := r.position.x + size.x * (0.1 + 0.2 * i)
			var fy := r.end.y - size.y * fmod(_t * 1.7 + i * 0.37, 1.0)
			var s := 4.0 + sin(_t * 12.0 + i) * 1.5
			draw_colored_polygon(PackedVector2Array([Vector2(fx - s, fy), Vector2(fx + s, fy), Vector2(fx, fy - s * 2.5)]), Color(1.0, 0.55, 0.15, 0.85))
