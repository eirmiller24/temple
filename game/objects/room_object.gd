@tool
@icon("res://game/rooms/nodes/icons/room_object.svg")
class_name RoomObject
extends Node2D
## Base for the hand-placed interactive objects (docs/room_authoring.md
## §7): push block, floor button, lever, gate, locked door, pickup, save
## shrine, grapple anchor. Each is a scene under game/objects/ that the
## author drags into a room's `Objects` node and positions by its FEET
## (bottom-centre). Numbers live in data/objects.json.
##
## The scripts are @tool so they draw a gizmo in the editor. Because an
## editor-side script cannot name an autoload at parse time, the runtime
## side reaches them through Game.data() / Game.sfx() / Game.state() /
## Game.wiring() (game/game.gd) and stays dynamically typed there.

const LAYER_WORLD := 1 << 0
const LAYER_PLAYER := 1 << 1
const LAYER_ENEMY := 1 << 2
const LAYER_ENEMY_HURTBOX := 1 << 4
const LAYER_INTERACT := 1 << 7
const LAYER_PUSHABLE := 1 << 8
const LAYER_SWITCH := 1 << 9
const LAYER_GRAPPLE := 1 << 10
const LAYER_BREAKABLE := 1 << 12

## Wire channel for objects that drive or listen to one (0–31).
@export_range(0, 31) var channel: int = 0:
	set(v):
		channel = v
		queue_redraw()

var room: Room


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	room = _find_room()
	_setup_runtime()


## Override: build children, connect signals (runtime only).
func _setup_runtime() -> void:
	pass


func _find_room() -> Room:
	var n := get_parent()
	while n != null and not (n is Room):
		n = n.get_parent()
	return n


func cfg(section: String) -> Dictionary:
	var data := Game.data()
	if data == null:
		return {}
	return data.req(data.objects, section, "objects.json")


func cfg_num(section: String, key: String) -> float:
	var data := Game.data()
	return data.num(cfg(section), key, "objects." + section)


## Attach the manifest sprite for `id` (data/sprites.json "objects"),
## feet at the origin. Returns the sprite (null if the manifest lacks it).
func add_sprite(id: String, fit_tiles: float = 0.0) -> AnimatedSprite2D:
	var sprites := Game.sprites()
	if sprites == null:
		return null
	var s := AnimatedSprite2D.new()
	s.name = "Sprite"
	add_child(s)
	var e: Dictionary = sprites.apply(s, "objects", id, fit_tiles)
	if e.is_empty():
		s.queue_free()
		return null
	return s


func sfx(name: String) -> void:
	var s := Game.sfx()
	if s != null:
		s.play(name, self)


static func make_rect(size: Vector2) -> RectangleShape2D:
	var r := RectangleShape2D.new()
	r.size = size
	return r


## Gizmo helpers --------------------------------------------------------------------

func _gizmo_color() -> Color:
	return Color(0.85, 0.65, 0.4)


func _draw_feet() -> void:
	var c := _gizmo_color()
	var t := float(Room.TILE)
	draw_line(Vector2(-t * 0.4, 0), Vector2(t * 0.4, 0), c, 2.0)


func _draw_label(text: String, y: float = -Room.TILE * 1.2) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(-Room.TILE * 0.45, y), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _gizmo_color())


func _draw_box(size: Vector2, filled: bool = false) -> void:
	var c := _gizmo_color()
	var r := Rect2(Vector2(-size.x / 2.0, -size.y), size)
	if filled:
		draw_rect(r, Color(c.r, c.g, c.b, 0.15), true)
	draw_rect(r, c, false, 1.5)
