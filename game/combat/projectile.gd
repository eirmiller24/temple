class_name Projectile
extends Hitbox
## A moving hitbox: slingshot stones, enemy bolts, boss rocks. Despawns
## on the first thing it hits or when its lifetime ends. The layer/mask
## is set by the setup_* helper for whichever side fired it.

const LAYER_WORLD := 1 << 0
const LAYER_PROJECTILE := 1 << 11

var velocity := Vector2.ZERO
var grav := 0.0
var lifetime := 2.0
var radius := 4.0
var color := Color(0.9, 0.85, 0.7)
var _body_shape: CollisionShape2D


func _ready() -> void:
	super._ready()
	if _body_shape == null:
		_body_shape = CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = radius
		_body_shape.shape = c
		add_child(_body_shape)
	active = true
	body_entered.connect(_on_world_body)


func setup_slingshot(cfg: Dictionary, shooter: Node2D, dir: Vector2) -> void:
	source_node = shooter
	collision_layer = LAYER_PROJECTILE
	collision_mask = (1 << 4) | (1 << 9) | (1 << 12) | LAYER_WORLD   # enemy_hurtbox | switch | breakable | world
	velocity = dir.normalized() * Data.num(cfg, "speed", "objects.slingshot")
	grav = Data.num(cfg, "gravity", "objects.slingshot")
	lifetime = Data.num(cfg, "lifetime", "objects.slingshot")
	damage = Data.inum(cfg, "damage", "objects.slingshot")
	var kb: Array = Data.req(cfg, "knockback", "objects.slingshot")
	knockback = Vector2(float(kb[0]), float(kb[1]))
	hitstop = float(cfg.get("hitstop", 0.0))
	kind = "projectile"
	facing = 1 if dir.x >= 0.0 else -1
	radius = 3.0
	color = Color(0.85, 0.8, 0.65)


## Enemy-fired bolt: damages the player, blocked by walls.
func setup_enemy(dmg: int, dir: Vector2, speed: float, life: float, grav_: float,
		kb: Vector2, shooter: Node2D, col: Color = Color(1.0, 0.5, 0.3), r: float = 5.0) -> void:
	source_node = shooter
	collision_layer = LAYER_PROJECTILE
	collision_mask = (1 << 3) | LAYER_WORLD   # player_hurtbox | world
	velocity = dir.normalized() * speed
	grav = grav_
	lifetime = life
	damage = dmg
	knockback = kb
	kind = "projectile"
	facing = 1 if dir.x >= 0.0 else -1
	radius = r
	color = col


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	velocity.y += grav * delta
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
	queue_redraw()


func _try_hit(target: Node) -> void:
	if not target.has_method("take_hit"):
		return
	super._try_hit(target)
	if _already_hit.has(target.get_instance_id()):
		_despawn()


func _on_world_body(body: Node) -> void:
	if body is TileMapLayer or body is StaticBody2D:
		_despawn()


func _despawn() -> void:
	set_physics_process(false)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_line(Vector2.ZERO, -velocity.normalized() * radius * 3.0, Color(color, 0.4), 1.5)
