class_name SporeCloud
extends Hitbox
## The mushroom's attack: a stationary round cloud (kind "cloud") that
## hurts the player once if they stand in it, hangs for `lifetime`
## seconds and fades out. Layers: enemy_hitbox → player_hurtbox. Spawned by
## Walker with its numbers from data/enemies/mushroom.json.

const LAYER_PLAYER_HURTBOX := 1 << 3
const LAYER_ENEMY_HITBOX := 1 << 6
const COLOR := Color(0.75, 0.55, 0.9)

var lifetime := 1.0
var radius := 24.0
var _life_total := 1.0


func setup(shooter: Node2D, dmg: int, kb: Vector2, r: float, life: float) -> void:
	source_node = shooter
	damage = dmg
	knockback = kb
	kind = "cloud"
	hitstop = 0.0
	radius = r
	lifetime = life
	_life_total = maxf(life, 0.001)
	collision_layer = LAYER_ENEMY_HITBOX
	collision_mask = LAYER_PLAYER_HURTBOX


func _ready() -> void:
	super._ready()
	var cs := CollisionShape2D.new()
	cs.shape = EnemyKit.circle(radius)
	add_child(cs)
	active = true


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a := clampf(lifetime / _life_total, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(COLOR, 0.35 * a))
	draw_arc(Vector2.ZERO, radius * (1.0 - 0.15 * a), 0.0, TAU, 24, Color(COLOR, 0.8 * a), 1.5)
	for i in 5:
		var ang := TAU * float(i) / 5.0 + lifetime * 1.7
		draw_circle(Vector2.from_angle(ang) * radius * 0.55, radius * 0.18, Color(1, 1, 1, 0.5 * a))
