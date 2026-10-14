@tool
@icon("res://game/rooms/nodes/icons/room_object.svg")
class_name PushBlock
extends CharacterBody2D
## A pushable stone crate, one tile square. Walk into it to push it;
## it falls under gravity, weighs floor buttons, carries the player, and
## can be pulled with the grappling hook when its `material` is one the
## hook grabs (design §10: "grabs items made of certain materials").
##
## Position is FEET (bottom-centre). Numbers: data/objects.json push_block.

const LAYER_WORLD := 1 << 0
const LAYER_PLAYER := 1 << 1
const LAYER_PUSHABLE := 1 << 8
const LAYER_GRAPPLE := 1 << 10

## What the block is made of. The grappling hook pulls "iron" and "wood";
## "stone" is too heavy to hook.
@export_enum("stone", "iron", "wood") var block_material: String = "iron"
## Draw size in tiles (collision is always 1 tile for puzzle clarity).
@export var size_tiles: int = 1

var room: Room
var _push_dir := 0.0
var _pull_from: Node2D = null
var _pull_time := 0.0
var _sprite: AnimatedSprite2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = LAYER_PUSHABLE | LAYER_GRAPPLE
	collision_mask = LAYER_WORLD | LAYER_PUSHABLE
	floor_snap_length = 4.0
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(Room.TILE - 2, Room.TILE - 2)
	shape.shape = r
	shape.position = Vector2(0, -Room.TILE / 2.0)
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	add_child(_sprite)
	var sprites := Game.sprites()
	if sprites != null:
		sprites.apply(_sprite, "objects", "push_block", 1.0)
	add_to_group("pushable")


## Called by the player while it walks into the block.
func push(dir: float, _delta: float) -> void:
	if not is_on_floor():
		return
	_push_dir = signf(dir)


## Grapple contract: returns "pull" and gets dragged toward the player.
func grapple_hit(player: Node2D) -> String:
	if block_material == "stone":
		return "none"
	_pull_from = player
	_pull_time = 0.9
	return "pull"


func _physics_process(delta: float) -> void:
	var data := Game.data()
	if data == null:
		return
	var c: Dictionary = data.req(data.objects, "push_block", "objects.json")
	var g: float = data.num(c, "gravity", "objects.push_block")
	var speed: float = data.num(c, "push_speed", "objects.push_block")
	velocity.y = minf(velocity.y + g * delta, data.num(c, "terminal_velocity", "objects.push_block"))
	var vx := 0.0
	if _pull_time > 0.0 and _pull_from != null and is_instance_valid(_pull_from):
		_pull_time -= delta
		var dx := _pull_from.global_position.x - global_position.x
		if absf(dx) > Room.TILE * 0.9:
			vx = signf(dx) * data.num(c, "grapple_pull_speed", "objects.push_block")
		else:
			_pull_time = 0.0
	elif _push_dir != 0.0:
		vx = _push_dir * speed
		if randi() % 20 == 0:
			var s := Game.sfx()
			if s != null:
				s.play("block_push", self)
	velocity.x = vx
	_push_dir = 0.0
	move_and_slide()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var c := Color(0.85, 0.65, 0.4)
	var t := float(Room.TILE)
	draw_rect(Rect2(Vector2(-t / 2.0, -t), Vector2(t, t)), Color(c.r, c.g, c.b, 0.2), true)
	draw_rect(Rect2(Vector2(-t / 2.0, -t), Vector2(t, t)), c, false, 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(-t / 2.0, -t - 4), "push block (%s)" % block_material,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c)
