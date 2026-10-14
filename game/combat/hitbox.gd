class_name Hitbox
extends Area2D
## An attack volume. While `active`, every Hurtbox (or anything with a
## `take_hit` method) it overlaps is hit exactly once per activation.
##
## Layers are set by the owner: a player hitbox sits on `player_hitbox`
## and masks `enemy_hurtbox` + `switch` + `breakable`; an enemy hitbox
## sits on `enemy_hitbox` and masks `player_hurtbox`. Hit payload:
##   {damage: int, knockback: Vector2, source: Node2D, kind: String,
##    tier: int, hitstop: float}
## `tier` 0 is an ordinary attack; 1 is keystone-tier (breaks fortified
## walls: a fast boulder, the Power Fang).

signal hit_landed(target: Node, info: Dictionary)

@export var damage: int = 1
@export var knockback: Vector2 = Vector2(220, -120)
@export var kind: String = "melee"
@export var tier: int = 0
@export var hitstop: float = 0.05
## Knockback x follows the hitbox's facing when true (sign of global scale.x
## of the owner, or `facing` set by the owner).
var facing := 1
## Who dealt the hit (the player, an enemy). Set by the owner; falls back
## to the parent. Not `owner` — that is the scene-ownership field.
var source_node: Node2D = null
## Monitoring stays on permanently (toggling it inside physics callbacks
## is an error); `active` gates whether overlaps count.
var active := false:
	set(v):
		if v and not active:
			_already_hit.clear()
		active = v

var _already_hit := {}


func _ready() -> void:
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _pulse_left > 0.0:
		_pulse_left -= delta
		if _pulse_left <= 0.0:
			_pulse_left = 0.0
			active = false
	if not active:
		return
	# Overlaps that already existed when the box turned on don't fire
	# area_entered, so sweep every frame while active.
	for a in get_overlapping_areas():
		_try_hit(a)
	for b in get_overlapping_bodies():
		_try_hit(b)


func _on_area_entered(a: Area2D) -> void:
	if active:
		_try_hit(a)


func _on_body_entered(b: Node) -> void:
	if active:
		_try_hit(b)


func _try_hit(target: Node) -> void:
	if target == null or _already_hit.has(target.get_instance_id()):
		return
	if not target.has_method("take_hit"):
		return
	_already_hit[target.get_instance_id()] = true
	var info := make_info()
	target.take_hit(info)
	hit_landed.emit(target, info)


func make_info() -> Dictionary:
	return {
		"damage": damage,
		"knockback": Vector2(knockback.x * facing, knockback.y),
		"source": source_node if source_node != null else get_parent(),
		"origin": global_position,
		"kind": kind,
		"tier": tier,
		"hitstop": hitstop,
	}


var _pulse_left := 0.0


## One-shot activation for `seconds` (attack frames), counted down in
## this node's own physics step so a freed owner never resumes a timer.
func pulse(seconds: float) -> void:
	active = true
	_pulse_left = seconds
