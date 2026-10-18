@tool
class_name Boulder
extends RoomObject
## A wired rolling-boulder trap. Hidden (no body, no collision) until its
## `channel` goes active; then it appears with its FEET at this node's
## position, drops under gravity and, on landing, rolls at the player
## (whichever side they're on then) until it meets a wall, where it stops for
## good. One shot per room visit: reloading the room (a void-out, a re-entry)
## puts it back.
##
## It is a heavy rolling solid. Rolling (or dropping) into the player faster
## than objects.boulder impact_speed hurts them (Player._surface_contacts,
## the "impact" meta on the body), again each time their i-frames run out.
## Two bodies: an invisible CharacterBody2D `_mover` does the falling and
## rolling against the room, and the solid everyone touches is a StaticBody2D
## `_body` that follows it, turning as it rolls and DECLARING its velocity and
## spin (constant_linear/angular_velocity), so the physics server knows the
## surface velocity at every point. (A kinematic body's velocity is derived
## as motion ÷ step instead, which is NaN during hitstop and crashed the
## player's platform carry.) Standing on it, the engine's moving-platform
## carry moves the player with the surface: twice the boulder's speed on top,
## so standing still walks you off the front into its path. Touching its sides,
## the player feels Coulomb friction (Player._surface_contacts, the
## "surface_friction" meta on the body). Pinned against a wall, the player is
## crushed (design §7.6, Crush). Author it high up over empty Collision cells,
## `size` tiles of clear space below and beside the feet. Numbers:
## data/objects.json "boulder".

## Diameter in tiles. The body and the art are this circle.
@export_range(1, 16) var size: int = 3:
	set(v):
		size = v
		queue_redraw()

var triggered := false
## The solid the player touches: origin at the circle's centre, turns as it rolls.
var _body: StaticBody2D
## Moves it: same circle, no layer, so only the room stops it.
var _mover: CharacterBody2D
var _shape: CollisionShape2D
var _mover_shape: CollisionShape2D
var _armed := false          # set inside the wiring callback, acted on in _physics_process
var _rolling := 0.0          # -1 / +1 once landed
var _was_on_floor := false


func _setup_runtime() -> void:
	var r := size * Room.TILE / 2.0
	var c := cfg("boulder")
	var data := Game.data()
	_mover = CharacterBody2D.new()
	_mover.name = "Mover"
	_mover.position = Vector2(0, -r)
	_mover.collision_layer = 0
	_mover.collision_mask = LAYER_WORLD
	_mover.floor_snap_length = 4.0
	_mover_shape = CollisionShape2D.new()
	_mover_shape.shape = _circle(r)
	_mover_shape.disabled = true
	_mover.add_child(_mover_shape)
	add_child(_mover)
	_body = StaticBody2D.new()
	_body.name = "Body"
	_body.position = Vector2(0, -r)
	_body.collision_layer = LAYER_WORLD
	_body.collision_mask = 0
	_body.set_meta("surface_friction", data.num(c, "friction", "objects.boulder"))
	var kb: Array = data.req(c, "impact_knockback", "objects.boulder")
	_body.set_meta("impact", {
		"speed": data.num(c, "impact_speed", "objects.boulder"),
		"damage": data.inum(c, "impact_damage", "objects.boulder"),
		"knockback": Vector2(float(kb[0]), float(kb[1])),
	})
	_shape = CollisionShape2D.new()
	_shape.shape = _circle(r)
	_shape.disabled = true
	_body.add_child(_shape)
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	_body.add_child(sprite)
	var sprites := Game.sprites()
	var e: Dictionary = sprites.apply(sprite, "objects", "boulder", size) if sprites != null else {}
	if e.is_empty():
		sprite.queue_free()
		_body.draw.connect(_draw_rock)
	else:
		# The rock (body_h px tall, bottom on ground_y) centred on the body,
		# so it turns about its middle and its rim meets the floor.
		sprite.offset = Vector2(-e.frame_w / 2.0, -(float(e.ground_y) - e.body_h / 2.0))
	add_child(_body)
	_mover.add_collision_exception_with(_body)
	_body.visible = false
	var wiring := Game.wiring()
	if wiring != null:
		wiring.channel_changed.connect(_on_channel)


func _on_channel(ch: int, active: bool) -> void:
	# Runs inside a button's body_entered (the physics server is flushing),
	# so the shape is switched on next physics frame, not here.
	if ch == channel and active and not triggered:
		triggered = true
		_armed = true


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _body == null or not triggered:
		return
	if _armed:
		_armed = false
		_shape.disabled = false
		_mover_shape.disabled = false
		_body.visible = true
		return
	var c := cfg("boulder")
	var data := Game.data()
	var r := size * Room.TILE / 2.0
	_mover.velocity.y = minf(_mover.velocity.y + data.num(c, "gravity", "objects.boulder") * delta,
			data.num(c, "terminal_velocity", "objects.boulder"))
	if _rolling != 0.0:
		_mover.velocity.x = move_toward(_mover.velocity.x, _rolling * data.num(c, "roll_speed", "objects.boulder"),
				data.num(c, "roll_accel", "objects.boulder") * delta)
	var before := _mover.position.x
	_mover.move_and_slide()
	var on_floor := _mover.is_on_floor()
	# The solid follows, turning by distance / radius (rolling without
	# slipping), and declares the motion: on the floor the spin is v / r.
	_body.position = _mover.position
	_body.rotation = wrapf(_body.rotation + (_mover.position.x - before) / r, -PI, PI)
	_body.constant_linear_velocity = _mover.velocity
	_body.constant_angular_velocity = _mover.velocity.x / r if on_floor else 0.0
	if on_floor and not _was_on_floor:
		_land()
	_was_on_floor = on_floor
	if _rolling != 0.0 and _mover.is_on_wall():
		_stop()


func _land() -> void:
	sfx("boss_slam")
	Game.juice().shake(4.0, 0.3)
	if _rolling != 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var dx := player.global_position.x - _body.global_position.x if player != null else -1.0
	_rolling = signf(dx) if dx != 0.0 else -1.0


func _stop() -> void:
	_rolling = 0.0
	_mover.velocity.x = 0.0
	_body.constant_linear_velocity = Vector2.ZERO
	_body.constant_angular_velocity = 0.0
	sfx("hit_stone")
	Game.juice().shake(5.0, 0.35)


static func _circle(radius: float) -> CircleShape2D:
	var c := CircleShape2D.new()
	c.radius = radius
	return c


## No art in the manifest: a grey disc.
func _draw_rock() -> void:
	var r := size * Room.TILE / 2.0
	_body.draw_circle(Vector2.ZERO, r, Color("6b6570"))
	_body.draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color("3d3842"), 3.0)
	_body.draw_line(Vector2(-r * 0.5, 0), Vector2(r * 0.5, 0), Color("3d3842"), 3.0)


func _gizmo_color() -> Color:
	return Color(0.75, 0.6, 0.5)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var d := size * Room.TILE
	_draw_feet()
	draw_circle(Vector2(0, -d / 2.0), d / 2.0, Color(_gizmo_color(), 0.15))
	draw_arc(Vector2(0, -d / 2.0), d / 2.0, 0.0, TAU, 32, _gizmo_color(), 1.5)
	_draw_label("boulder ch%d (drops, rolls at player)" % channel, -d - 6)
