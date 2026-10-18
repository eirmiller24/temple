@tool
class_name Torch
extends RoomObject
## A wall torch: a flame on the `fire` layer. A wooden dart flying through
## it catches fire (Projectile.catches_fire). An unlit torch is lit by a
## burning hit (a burning dart) and stays lit on later visits. Position is
## the flame's centre.

const LAYER_FIRE := 1 << 15

## Burning when the room is first visited (a lit torch is remembered).
@export var lit: bool = true:
	set(v):
		lit = v
		queue_redraw()

var _fire: Area2D
var _switch: SwitchArea
var _light: PointLight2D
var _t := 0.0


func _setup_runtime() -> void:
	_fire = Area2D.new()
	_fire.name = "Flame"
	_fire.collision_layer = 0
	_fire.collision_mask = 0
	_fire.monitoring = false
	var fs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 8.0
	fs.shape = c
	_fire.add_child(fs)
	add_child(_fire)
	_switch = SwitchArea.new()
	_switch.name = "Switch"
	_switch.target = self
	_switch.hook_switch = false
	_switch.collision_layer = 0
	_switch.collision_mask = 0
	var ss := CollisionShape2D.new()
	ss.shape = make_rect(Vector2(12, 20))
	ss.position = Vector2(0, 6)
	_switch.add_child(ss)
	add_child(_switch)
	_light = PointLight2D.new()
	_light.texture = _light_texture()
	_light.texture_scale = 1.2
	_light.color = Color(1.0, 0.75, 0.45)
	_light.energy = 1.0
	add_child(_light)
	var saved: Variant = room.saved_state(self) if room != null else null
	_set_lit(true if saved != null and bool(saved) else lit)


## Only a burning hit does anything: it lights an unlit torch.
func take_hit(info: Dictionary) -> void:
	if lit or not bool(info.get("fire", false)):
		return
	_set_lit(true)
	sfx("ignite")
	if room != null:
		room.store_state(self, true)


func _set_lit(v: bool) -> void:
	lit = v
	# Lit: a flame (fire layer) that darts fly through. Unlit: a solid-ish
	# target on the switch layer that stops darts and stones. Deferred: this
	# can run inside a physics callback (a dart's hit).
	_fire.set_deferred("collision_layer", LAYER_FIRE if lit else 0)
	_switch.set_deferred("collision_layer", 0 if lit else LAYER_SWITCH)
	_light.visible = lit
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if lit:
		_light.energy = 0.9 + sin(_t * 11.0) * 0.08 + sin(_t * 7.3) * 0.05
		queue_redraw()


static func _light_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 128
	t.height = 128
	return t


func _gizmo_color() -> Color:
	return Color(1.0, 0.6, 0.25)


func _draw() -> void:
	# Sconce below the flame.
	draw_rect(Rect2(-3, 2, 6, 14), Color("5a4430"))
	draw_rect(Rect2(-6, 0, 12, 4), Color("7a5a3a"))
	if lit:
		var f := 0.0 if Engine.is_editor_hint() else sin(_t * 13.0) * 1.5
		draw_colored_polygon(PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(f, -13)]), Color(1.0, 0.5, 0.15))
		draw_colored_polygon(PackedVector2Array([Vector2(-2.5, 0), Vector2(2.5, 0), Vector2(f * 0.5, -7)]), Color(1.0, 0.9, 0.5))
	if Engine.is_editor_hint():
		_draw_label("torch%s" % ("" if lit else " (unlit)"), -18)
