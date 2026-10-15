@tool
@icon("res://game/rooms/nodes/icons/room_object.svg")
class_name PushBlock
extends CharacterBody2D
## A pushable stone crate, one tile square. Walk into it to push it;
## it falls under gravity, weighs floor buttons, carries the player, and
## can be pulled with the grappling hook when its `material` is one the
## hook grabs (design §10: "grabs items made of certain materials").
##
## Persistence (the Zelda rule): a block resting on a KEY SPOT (any node
## in group "key_spot" that answers holds(block), i.e. a floor button)
## saves its position and is still there on the next visit. Anywhere else
## the saved position is forgotten and the block resets to where it was
## authored.
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
var _stored_pos := Vector2.ZERO
var _parked := false   # resting on a key spot, position saved


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var n := get_parent()
	while n != null and not (n is Room):
		n = n.get_parent()
	room = n
	var saved: Variant = room.saved_state(self) if room != null else null
	if saved is Array and (saved as Array).size() == 2:
		position = Vector2(saved[0], saved[1])
		_parked = true
	_stored_pos = position
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
	if grapple_mode(player) != "pull":
		return "none"
	_pull_from = player
	_pull_time = 0.9
	return "pull"


## What grapple_hit would answer, without doing it (the aim reticle asks).
func grapple_mode(_player: Node2D) -> String:
	return "none" if block_material == "stone" else "pull"


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
	_update_saved()


## Save the position while parked on a key spot; forget it when the block
## leaves one. Skipped while the room settles: a restored block's plate
## hasn't seen it yet, and it must not be forgotten for that.
func _update_saved() -> void:
	var w := Game.wiring()
	if room == null or (w != null and w.is_settling()):
		return
	var parked := false
	for spot in get_tree().get_nodes_in_group("key_spot"):
		if spot.holds(self):
			parked = true
			break
	if parked and (not _parked or position != _stored_pos):
		_stored_pos = position
		room.store_state(self, [position.x, position.y])
	elif not parked and _parked:
		room.store_state(self, null)
	_parked = parked


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var c := Color(0.85, 0.65, 0.4)
	var t := float(Room.TILE)
	draw_rect(Rect2(Vector2(-t / 2.0, -t), Vector2(t, t)), Color(c.r, c.g, c.b, 0.2), true)
	draw_rect(Rect2(Vector2(-t / 2.0, -t), Vector2(t, t)), c, false, 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(-t / 2.0, -t - 4), "push block (%s)" % block_material,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c)
