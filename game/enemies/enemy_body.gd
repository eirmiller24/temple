class_name EnemyBody
extends CharacterBody2D
## The physical half of an enemy, split out of Enemy to keep each file
## readable: strict access to its data/enemies/<species>.json, the nodes
## it builds for itself (collision box, sprite with the flash material,
## EnemyHurtbox, contact Hitbox), player sensing, wall/ledge probes and
## the F2 debug overlay. Enemy (the brain contract: states, hits, death,
## attack coroutines) extends this; species extend Enemy. Nothing here
## decides behaviour.
##
## Layers: body enemy(3) masking world|pushable; hurtbox enemy_hurtbox(5);
## hitboxes enemy_hitbox(7) masking player_hurtbox(4).

const LAYER_WORLD := 1 << 0
const LAYER_ENEMY := 1 << 2
const LAYER_PLAYER_HURTBOX := 1 << 3
const LAYER_ENEMY_HURTBOX := 1 << 4
const LAYER_ENEMY_HITBOX := 1 << 6
const LAYER_PUSHABLE := 1 << 8
## Reach of the wall/ledge rays past the body edge (geometry epsilon, not a tunable).
const PROBE_PX := 4.0

## A stem in data/enemies/. The species scenes preset it.
@export var species: String = ""
@export_enum("right:1", "left:-1") var facing: int = 1

var cfg: Dictionary = {}     ## the species file
var brain: Dictionary = {}   ## cfg[behavior]
var ctx := ""
var room: Room = null
var sprite: AnimatedSprite2D
var shape: CollisionShape2D
var hurtbox: EnemyHurtbox
var hitbox: Hitbox           ## contact damage
var faces_left := false
var _mat: ShaderMaterial
var _debug := false


## The behavior string this script implements ("hopper", "guardian"...).
func behavior_name() -> String:
	return ""


## Resolve cfg/brain from Data; hard errors on a missing species or block.
func load_config() -> void:
	ctx = "enemies/%s.json" % species
	cfg = Data.req(Data.enemies, species, "data/enemies")
	var behavior := String(Data.req(cfg, "behavior", ctx))
	if behavior != behavior_name():
		push_error("%s: behavior is '%s' but the scene uses the '%s' script" % [ctx, behavior, behavior_name()])
	brain = Data.req(cfg, behavior, ctx)
	room = _find_room()


func build_children() -> void:
	collision_layer = LAYER_ENEMY
	collision_mask = LAYER_WORLD | LAYER_PUSHABLE
	floor_snap_length = 6.0
	floor_max_angle = deg_to_rad(50)
	var size := Vector2(cn("body_w"), cn("body_h"))
	var centre := Vector2(0, -size.y / 2.0)   # box bottom on the origin = feet
	shape = CollisionShape2D.new()
	shape.name = "Shape"
	shape.shape = EnemyKit.rect(size)
	shape.position = centre
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	add_child(sprite)
	var e := SpriteDb.apply(sprite, "enemies", cs("sprite"), cn("fit_tiles"))
	faces_left = bool(e.get("faces_left", false))
	_mat = EnemyKit.flash_material()
	sprite.material = _mat
	hurtbox = EnemyHurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.enemy = self as Enemy
	hurtbox.collision_layer = LAYER_ENEMY_HURTBOX
	hurtbox.collision_mask = 0
	var hs := CollisionShape2D.new()
	hs.shape = EnemyKit.rect(size)
	hs.position = centre
	hurtbox.add_child(hs)
	add_child(hurtbox)
	hitbox = make_hitbox("Contact", size - Vector2(2, 2), ci("contact_damage"), cv("contact_knockback"), "contact")
	hitbox.position = centre
	update_flip()


## A rectangular enemy Hitbox (enemy_hitbox → player_hurtbox), inactive.
## Position it per use: `box.position = Vector2(facing * dx, dy)`.
func make_hitbox(box_name: String, size: Vector2, dmg: int, kb: Vector2, kind: String) -> Hitbox:
	var hb := Hitbox.new()
	hb.name = box_name
	hb.collision_layer = LAYER_ENEMY_HITBOX
	hb.collision_mask = LAYER_PLAYER_HURTBOX
	hb.damage = dmg
	hb.knockback = kb
	hb.kind = kind
	hb.source_node = self
	var cs_ := CollisionShape2D.new()
	cs_.shape = EnemyKit.rect(size)
	hb.add_child(cs_)
	add_child(hb)
	return hb


## Add a projectile / cloud to the room (so it outlives us) at a world position.
func spawn_in_room(node: Node2D, at: Vector2) -> void:
	var holder: Node = room if room != null else get_parent()
	holder.add_child(node)
	node.global_position = at


## flip_h honours the sheet's native facing (manifest `faces_left`).
func update_flip() -> void:
	sprite.flip_h = (facing < 0) != faces_left


# --- senses ------------------------------------------------------------------------------------------

func player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


## Feet-to-feet vector to the player, or Vector2.INF when there is none.
func player_delta() -> Vector2:
	var p := player()
	return p.global_position - global_position if p != null else Vector2.INF


func player_dist() -> float:
	var d := player_delta()
	return INF if d == Vector2.INF else d.length()


func player_in_range(r: float) -> bool:
	return player_dist() <= r


func face_player() -> void:
	var d := player_delta()
	if d != Vector2.INF and absf(d.x) > 0.5:
		facing = 1 if d.x > 0.0 else -1


## No floor within `depth` px below the point just ahead of the feet.
func _ledge_ahead(depth: float) -> bool:
	var from := global_position + Vector2(facing * (cn("body_w") / 2.0 + PROBE_PX), -PROBE_PX)
	return not _ray_hits(from, from + Vector2(0, depth + PROBE_PX))


func _wall_ahead() -> bool:
	if is_on_wall() and get_wall_normal().x * facing < 0.0:
		return true
	var from := global_position + Vector2(0, -cn("body_h") / 2.0)
	return _ray_hits(from, from + Vector2(facing * (cn("body_w") / 2.0 + PROBE_PX), 0))


func _ray_hits(from: Vector2, to: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(from, to, LAYER_WORLD | LAYER_PUSHABLE)
	q.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _find_room() -> Room:
	var n := get_parent()
	while n != null:
		if n is Room:
			return n
		n = n.get_parent()
	return null


# --- data access (strict: a missing key is a hard error) ------------------------------

func cn(key: String) -> float:
	return Data.num(cfg, key, ctx)


func ci(key: String) -> int:
	return Data.inum(cfg, key, ctx)


func cs(key: String) -> String:
	return String(Data.req(cfg, key, ctx))


func cv(key: String) -> Vector2:
	return _vec(Data.req(cfg, key, ctx), key)


## Brain-block (behavior) numbers.
func bn(key: String) -> float:
	return Data.num(brain, key, ctx + "." + behavior_name())


func bi(key: String) -> int:
	return Data.inum(brain, key, ctx + "." + behavior_name())


func bv(key: String) -> Vector2:
	return _vec(Data.req(brain, key, ctx + "." + behavior_name()), key)


func _vec(v: Variant, key: String) -> Vector2:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() != 2:
		push_error("%s: '%s' must be [x, y]" % [ctx, key])
		return Vector2.ZERO
	return Vector2(float(v[0]), float(v[1]))


## F3: pick up the re-read file; numbers are read live so no rebuild needed.
func _on_data_reloaded() -> void:
	if Data.enemies.has(species):
		cfg = Data.enemies[species]
		brain = cfg.get(behavior_name(), brain)


# --- debug (F2 view, group "debug_draw") --------------------------------------------------------

func set_debug(on: bool) -> void:
	_debug = on
	queue_redraw()


## Text drawn over the enemy in the debug view; Enemy adds hp and state.
func debug_label() -> String:
	return species


func _draw() -> void:
	if not _debug or shape == null:
		return
	for c in get_children():
		var col := Color(0.4, 0.7, 1.0, 0.9)
		var cs_: CollisionShape2D = null
		if c is Hitbox:
			cs_ = c.get_child(0) as CollisionShape2D
			col = Color(1, 0.2, 0.2, 0.9) if (c as Hitbox).active else Color(1, 0.4, 0.4, 0.3)
		elif c is Hurtbox:
			cs_ = c.get_child(0) as CollisionShape2D
			col = Color(0.3, 1, 0.4, 0.9) if (c as Hurtbox).enabled else Color(0.3, 1, 0.4, 0.3)
		elif c == shape:
			cs_ = shape
		if cs_ == null or not (cs_.shape is RectangleShape2D):
			continue
		var r: RectangleShape2D = cs_.shape
		var at := cs_.position - r.size / 2.0
		if c != shape:
			at += (c as Node2D).position
		draw_rect(Rect2(at, r.size), col, false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(-24, -cn("body_h") - 6), debug_label(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 0.8))
