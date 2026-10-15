extends Node
## Prints every registered room as ASCII — the kind layer plus exits (E),
## entries (@), objects (o) and enemies (!) — so a room can be read
## headlessly without opening the editor or rendering a screenshot.
##
##   godot --headless --path . res://tools/dump_rooms.tscn            # all rooms
##   godot --headless --path . res://tools/dump_rooms.tscn -- test_shaft
##
## Legend:  # solid   = oneway   % breakable   F fortified   ~ water
##          ^ hazard   / ramp_r  \ ramp_l   . empty   E exit   @ entry
##          o object   ! enemy    (exit/entry/object markers win over kinds)

const GLYPH := {
	"solid": "#", "oneway": "=", "breakable": "%", "fortified": "F",
	"water": "~", "hazard": "^", "ramp_r": "/", "ramp_l": "\\",
}


func _ready() -> void:
	await get_tree().process_frame
	var only := ""
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			only = a
	var names := RoomRegistry.rooms.keys()
	names.sort()
	for n in names:
		if only != "" and n != only:
			continue
		_dump(n)
	get_tree().quit(0)


func _dump(name: String) -> void:
	var packed: PackedScene = load(RoomRegistry.scene_path(name))
	if packed == null:
		print("?? cannot load ", name)
		return
	var room: Room = packed.instantiate()
	# Not added to the tree: _ready (and the runtime build) never runs, so
	# only the authored data is read.
	var collision := room.get_node_or_null("Collision") as TileMapLayer
	if collision == null:
		print("?? ", name, " has no Collision layer")
		room.free()
		return
	var r := collision.get_used_rect()
	var grid: Array = []
	for y in r.size.y:
		var row := PackedStringArray()
		for x in r.size.x:
			var cell := Vector2i(r.position.x + x, r.position.y + y)
			var td := collision.get_cell_tile_data(cell)
			var kind := "" if td == null else String(td.get_custom_data("kind"))
			row.append(GLYPH.get(kind, "." if kind == "" else "?"))
		grid.append(row)
	var legend := PackedStringArray()
	for e in _children(room, "Exits"):
		if e is RoomExit:
			var rt: Rect2i = e.rect_tiles()
			for y in range(rt.position.y, rt.end.y):
				for x in range(rt.position.x, rt.end.x):
					_mark(grid, r, Vector2i(x, y), "E")
			legend.append("  E %s (%d,%d %dx%d %s) -> %s%s" % [e.name, rt.position.x, rt.position.y,
					rt.size.x, rt.size.y, e.direction, e.to_room, (" @" + e.to_entry) if e.to_entry != "" else " (seam)"])
	for en in _children(room, "Entries"):
		if en is Node2D:
			var c := _cell_of(en.position, true)
			_mark(grid, r, c, "@")
			legend.append("  @ %s (%d,%d)%s" % [en.name, c.x, c.y, (" id=" + en.id) if en is RoomEntry else ""])
	for o in _children(room, "Objects"):
		if o is Node2D:
			var c := _cell_of(o.position, true)
			_mark(grid, r, c, "o")
			var extra := ""
			if "channel" in o:
				extra += " ch%d" % int(o.channel)
			if "w" in o and "h" in o:
				extra += " %dx%d" % [int(o.w), int(o.h)]
			legend.append("  o %s (%d,%d)%s" % [o.name, c.x, c.y, extra])
	for e in _children(room, "Enemies"):
		if e is Node2D:
			var c := _cell_of(e.position, true)
			_mark(grid, r, c, "!")
			legend.append("  ! %s (%d,%d)" % [e.name, c.x, c.y])
	print("== %s  world (%d,%d)  rect (%d,%d %dx%d)  skin=%s bg=%s music=%s" % [name, room.world_x, room.world_y,
			r.position.x, r.position.y, r.size.x, r.size.y, room.skin, room.background, room.music])
	# Column ruler (tens then units) so cells can be named exactly.
	var tens := "     "
	var units := "     "
	for x in r.size.x:
		var col := r.position.x + x
		tens += str((col / 10) % 10) if col % 10 == 0 else " "
		units += str(col % 10)
	print(tens)
	print(units)
	for y in r.size.y:
		print("%4d " % (r.position.y + y), "".join(grid[y]))
	for l in legend:
		print(l)
	print()
	room.free()


func _children(room: Node, holder: String) -> Array:
	var h := room.get_node_or_null(holder)
	return [] if h == null else h.get_children()


## Objects/entries store FEET positions; the cell they stand on is the one
## just above the feet line.
func _cell_of(px: Vector2, feet: bool) -> Vector2i:
	var p := px
	if feet:
		p.y -= 1.0
	return Vector2i(floori(p.x / Room.TILE), floori(p.y / Room.TILE))


func _mark(grid: Array, r: Rect2i, cell: Vector2i, glyph: String) -> void:
	var x := cell.x - r.position.x
	var y := cell.y - r.position.y
	if x < 0 or y < 0 or y >= grid.size() or x >= (grid[y] as PackedStringArray).size():
		return
	(grid[y] as PackedStringArray)[x] = glyph
