class_name Projectile
extends Hitbox
## A moving hitbox: slingshot stones, darts, enemy bolts, boss rocks. The
## player's shots stop at the first thing they hit (pierce = false); all
## of them stop at solids and when their lifetime ends. The layer/mask
## is set by the setup_* helper for whichever side fired it.
##
## Walls are found by sweeping each step with a ray (sweep()), not by the
## Area's overlap: tile collision is merged into hollow outlines per
## physics quadrant, and a stone moving more than its own diameter per
## frame hops the outline and is never inside anything that reports.

const LAYER_WORLD := 1 << 0
const LAYER_PROJECTILE := 1 << 11
const LAYER_PUSHABLE := 1 << 8
## enemy_hurtbox | switch | breakable | world: what a stone can hit.
const SLINGSHOT_MASK := (1 << 4) | (1 << 9) | (1 << 12) | LAYER_WORLD
## What stops a stone dead: the world and every solid object (push blocks).
const SLINGSHOT_SOLIDS := LAYER_WORLD | LAYER_PUSHABLE
const SLINGSHOT_RADIUS := 3.0
const LAYER_FIRE := 1 << 15

var velocity := Vector2.ZERO
var grav := 0.0
var lifetime := 2.0
var radius := 4.0
var color := Color(0.9, 0.85, 0.7)
## Bodies the projectile stops at, found by sweep() each step.
var solid_mask := LAYER_WORLD
## False: stops at the first thing it hits (the player's stones and darts).
## True: passes through what it hits and stops only at solids (enemy shots).
var pierce := true
## Catches fire passing through anything on the fire layer (a dart).
var catches_fire := false
## Burning: its hits carry `fire: true` (Enemy burns, Torch lights, a
## BurnableBarrier goes up).
var burning := false
var _body_shape: CollisionShape2D
var _room: Room


func _ready() -> void:
	super._ready()
	if _body_shape == null:
		_body_shape = CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = radius
		_body_shape.shape = c
		add_child(_body_shape)
	active = true
	var n := get_parent()
	while n != null and not (n is Room):
		n = n.get_parent()
	_room = n


func setup_slingshot(cfg: Dictionary, shooter: Node2D, dir: Vector2) -> void:
	source_node = shooter
	collision_layer = LAYER_PROJECTILE
	collision_mask = SLINGSHOT_MASK
	solid_mask = SLINGSHOT_SOLIDS
	velocity = dir.normalized() * Data.num(cfg, "speed", "objects.slingshot")
	grav = Data.num(cfg, "gravity", "objects.slingshot")
	lifetime = Data.num(cfg, "lifetime", "objects.slingshot")
	damage = Data.inum(cfg, "damage", "objects.slingshot")
	var kb: Array = Data.req(cfg, "knockback", "objects.slingshot")
	knockback = Vector2(float(kb[0]), float(kb[1]))
	hitstop = float(cfg.get("hitstop", 0.0))
	kind = "projectile"
	facing = 1 if dir.x >= 0.0 else -1
	radius = SLINGSHOT_RADIUS
	color = Color(0.85, 0.8, 0.65)
	pierce = false


## Wooden dart: straight (no gravity), fast, stops at the first thing it
## hits, and catches fire flying through a flame.
func setup_dart(cfg: Dictionary, shooter: Node2D, dir: Vector2) -> void:
	source_node = shooter
	collision_layer = LAYER_PROJECTILE
	collision_mask = SLINGSHOT_MASK
	solid_mask = SLINGSHOT_SOLIDS
	velocity = dir.normalized() * Data.num(cfg, "speed", "objects.darts")
	grav = 0.0
	lifetime = Data.num(cfg, "lifetime", "objects.darts")
	damage = Data.inum(cfg, "damage", "objects.darts")
	var kb: Array = Data.req(cfg, "knockback", "objects.darts")
	knockback = Vector2(float(kb[0]), float(kb[1]))
	hitstop = float(cfg.get("hitstop", 0.0))
	kind = "projectile"
	facing = 1 if dir.x >= 0.0 else -1
	radius = SLINGSHOT_RADIUS
	color = Color(0.75, 0.6, 0.4)
	pierce = false
	catches_fire = true


## Enemy-fired bolt: damages the player, blocked by walls.
func setup_enemy(dmg: int, dir: Vector2, speed: float, life: float, grav_: float,
		kb: Vector2, shooter: Node2D, col: Color = Color(1.0, 0.5, 0.3), r: float = 5.0) -> void:
	source_node = shooter
	collision_layer = LAYER_PROJECTILE
	collision_mask = (1 << 3) | LAYER_WORLD   # player_hurtbox | world
	solid_mask = LAYER_WORLD
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
	if not is_physics_processing():
		return   # despawned by a hit this step
	velocity.y += grav * delta
	var to := global_position + velocity * delta
	if catches_fire and not burning and _crosses_fire(global_position, to):
		burning = true
		Sfx.play("ignite", self)
	if solid_mask != 0:
		var hit := sweep(get_world_2d().direct_space_state, global_position, to, radius,
				solid_mask, false, _room)
		if not hit.is_empty():
			global_position = hit.position
			# A solid that takes hits itself (a BurnableBarrier) gets this one.
			var col: Object = hit.get("collider")
			if col is Node and col.has_method("take_hit"):
				_try_hit(col)
			_despawn()
			return
	global_position = to
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
	queue_redraw()


## The first thing on `mask` that one step from `from` to `to` runs into,
## as intersect_ray's result ({} for none). The ray reaches `r` past `to`
## so the projectile's leading edge, not its centre, meets the wall.
## Projectile._physics_process and the player's aim reticle both use it.
##
## One-way ledges follow the player's rule: they stop something coming
## down onto their top and let everything else through.
static func sweep(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2, r: float,
		mask: int, areas: bool, room: Room) -> Dictionary:
	var motion := to - from
	if motion == Vector2.ZERO:
		return {}
	var dir := motion.normalized()
	var q := PhysicsRayQueryParameters2D.create(from, to + dir * r, mask)
	q.collide_with_areas = areas
	for i in 8:
		var hit := space.intersect_ray(q)
		if hit.is_empty() or room == null or hit.collider is Area2D:
			return hit
		var p: Vector2 = hit.position + dir * 0.5
		if room.kind_at(room.to_local(p)) != "oneway" or (dir.y > 0.0 and hit.normal.y < -0.5):
			return hit
		# Passing through a ledge: carry on from where the ray leaves its
		# one-way cells. If that's straight into a solid cell or body (a
		# block resting on the ledge), the ray would start inside it and
		# miss it, so that's the hit.
		var steps := 0
		while room.kind_at(room.to_local(p)) == "oneway" and steps < 96:
			p += dir
			steps += 1
		if room.collides_at(room.to_local(p)):
			return {"position": p - dir, "normal": -dir, "collider": hit.collider}
		var pq := PhysicsPointQueryParameters2D.new()
		pq.position = p
		pq.collision_mask = mask
		var inside := space.intersect_point(pq, 1)
		if not inside.is_empty():
			return {"position": p - dir, "normal": -dir, "collider": inside[0].collider}
		if (p - from).dot(dir) >= (to - from).length() + r:
			return {}
		q.from = p
	return {}


## Does the step from `from` to `to` pass through a flame (fire layer)?
func _crosses_fire(from: Vector2, to: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(from, to, LAYER_FIRE)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.hit_from_inside = true
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _try_hit(target: Node) -> void:
	if not pierce and not is_physics_processing():
		return   # already spent on something else this step
	super._try_hit(target)
	if not pierce and _already_hit.has(target.get_instance_id()) and target.has_method("take_hit"):
		_despawn()


func make_info() -> Dictionary:
	var info := super.make_info()
	if burning:
		info["fire"] = true
	return info


func _despawn() -> void:
	set_physics_process(false)
	queue_free()


func _draw() -> void:
	if not pierce:
		# A dart: a shaft along its flight, aflame at the tip when burning.
		var d := velocity.normalized()
		draw_line(-d * 9.0, d * 3.0, color, 2.0)
		if burning:
			var flick := 2.5 + sin(Time.get_ticks_msec() * 0.04) * 1.0
			draw_circle(d * 3.0, flick, Color(1.0, 0.55, 0.15))
			draw_circle(d * 3.0, flick * 0.5, Color(1.0, 0.9, 0.5))
		return
	draw_circle(Vector2.ZERO, radius, color)
	draw_line(Vector2.ZERO, -velocity.normalized() * radius * 3.0, Color(color, 0.4), 1.5)
