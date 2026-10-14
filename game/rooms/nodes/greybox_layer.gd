class_name GreyboxLayer
extends Node2D
## Flat-rect fallback for Collision cells the skin could not dress, and
## the F2 debug view of every kind. Collision is never invisible.

const KIND_COLORS := {
	"solid": Color("46464f"),
	"oneway": Color("6e6a58"),
	"breakable": Color("55504a"),
	"fortified": Color("3a3a48"),
	"water": Color("3f7fd0", 0.6),
	"hazard": Color("b04040"),
	"ramp_r": Color("46464f"),
	"ramp_l": Color("46464f"),
}

var _room: Room
var _skin: SkinLayer
var debug_all := false:
	set(v):
		debug_all = v
		queue_redraw()


func setup(room: Room, skin: SkinLayer) -> void:
	_room = room
	_skin = skin


func _draw() -> void:
	if _room == null or _room.collision == null:
		return
	var cells: Array[Vector2i] = []
	if debug_all:
		cells = _room.collision.get_used_cells()
	elif _skin != null:
		cells = _skin.unmatched
	for cell in cells:
		var kind := _room.kind_at_cell(cell)
		var col: Color = KIND_COLORS.get(kind, Color.MAGENTA)
		if debug_all:
			col.a = 0.55
		var pos := Vector2(cell) * Room.TILE
		match kind:
			"oneway":
				draw_rect(Rect2(pos, Vector2(Room.TILE, Room.TILE * 0.25)), col)
			"ramp_r":
				draw_colored_polygon(PackedVector2Array([pos + Vector2(0, Room.TILE),
						pos + Vector2(Room.TILE, 0), pos + Vector2(Room.TILE, Room.TILE)]), col)
			"ramp_l":
				draw_colored_polygon(PackedVector2Array([pos, pos + Vector2(Room.TILE, Room.TILE),
						pos + Vector2(0, Room.TILE)]), col)
			"water":
				draw_rect(Rect2(pos, Vector2(Room.TILE, Room.TILE)), col)
				draw_rect(Rect2(pos, Vector2(Room.TILE, 3)), Color("8fd0ff", 0.8))
			"breakable":
				draw_rect(Rect2(pos, Vector2(Room.TILE, Room.TILE)), col)
				for i in 4:
					draw_rect(Rect2(pos + Vector2(4 + (i * 7) % 24, 4 + (i * 11) % 24), Vector2(3, 3)), Color("8a8070"))
			_:
				draw_rect(Rect2(pos, Vector2(Room.TILE, Room.TILE)), col)
