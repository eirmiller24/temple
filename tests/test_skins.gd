extends Node
## Skins coverage lint: for every skin in data/skins.json, paint a 12x8
## room-shaped kind grid (solid border, a oneway row, a water pocket, a
## 1-thick interior wall, plus one cell of every other kind) with the real
## authoring palette (game/rooms/tileset_kind.tres), dress it through the
## real SkinLayer, and report how many cells landed in `unmatched` per kind.
## Fails only when solid or oneway cells are unmatched (those are the
## kinds every skin must dress); water/hazard/ramps are allowed to fall
## back to the greybox rects, and `greybox` itself is expected to be all
## fallback.
##
##   godot --headless --path . res://tests/test_skins.tscn
##
## Tests are SCENES, not `-s` scripts (see tests/test_boot.gd). No autoload
## is touched: skins.json is read directly and SkinLayer/Room are plain
## @tool classes.

const KIND_TILESET := "res://game/rooms/tileset_kind.tres"
const W := 12
const H := 8
const MUST_DRESS := ["solid", "oneway"]

var _fails := 0


func _ready() -> void:
	var code := await _run()
	get_tree().quit(code)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error("CHECK FAILED: " + msg)
		_fails += 1
	else:
		print("  ok: ", msg)


## The authoring grid: kind name per cell ("" = empty).
func _layout() -> Dictionary:
	var g := {}
	for y in H:
		for x in W:
			if x == 0 or y == 0 or x == W - 1 or y == H - 1:
				g[Vector2i(x, y)] = "solid"
	for x in range(3, 9):
		g[Vector2i(x, 3)] = "oneway"            # a one-way ledge row
	for y in range(1, 4):
		g[Vector2i(6, y)] = "solid"              # 1-thick interior wall hanging from the ceiling
	for x in range(1, 3):
		for y in range(5, 7):
			g[Vector2i(x, y)] = "water"          # 2x2 water pocket in the floor corner
	g[Vector2i(4, 6)] = "hazard"
	g[Vector2i(7, 6)] = "ramp_r"
	g[Vector2i(8, 6)] = "ramp_l"
	g[Vector2i(9, 5)] = "breakable"
	g[Vector2i(10, 5)] = "fortified"
	g[Vector2i(10, 6)] = "fortified"
	return g


func _run() -> int:
	await get_tree().process_frame

	var kinds_ts: TileSet = load(KIND_TILESET)
	_check(kinds_ts != null, "kind palette %s loads" % KIND_TILESET)
	if kinds_ts == null:
		return 1
	# kind name -> (source id, atlas coords), read from the palette's custom data.
	var kind_tiles := {}
	for s in kinds_ts.get_source_count():
		var sid := kinds_ts.get_source_id(s)
		var src := kinds_ts.get_source(sid) as TileSetAtlasSource
		if src == null:
			continue
		for i in src.get_tiles_count():
			var coords := src.get_tile_id(i)
			var td := src.get_tile_data(coords, 0)
			kind_tiles[String(td.get_custom_data("kind"))] = [sid, coords]
	for k in ["solid", "oneway", "breakable", "fortified", "water", "hazard", "ramp_r", "ramp_l"]:
		_check(kind_tiles.has(k), "kind palette has a '%s' tile" % k)

	var skins: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/skins.json"))
	_check(typeof(skins) == TYPE_DICTIONARY and skins.has("greybox"), "data/skins.json parses and has greybox")
	if typeof(skins) != TYPE_DICTIONARY:
		return 1

	var layout := _layout()
	var names: Array = (skins as Dictionary).keys()
	names.sort()
	for name: String in names:
		if name.begins_with("_"):
			continue
		var skin: Dictionary = (skins[name] as Dictionary).duplicate()
		skin["_name"] = name

		var collision := TileMapLayer.new()
		collision.tile_set = kinds_ts
		add_child(collision)
		for cell: Vector2i in layout:
			var t: Array = kind_tiles.get(layout[cell], [])
			if not t.is_empty():
				collision.set_cell(cell, t[0], t[1])
		var layer := SkinLayer.new()
		add_child(layer)
		layer.build(collision, skin)

		var per_kind := {}
		for cell in layer.unmatched:
			var k := String(layout.get(cell, "?"))
			per_kind[k] = per_kind.get(k, 0) + 1
		var totals := {}
		for cell in layout:
			totals[layout[cell]] = totals.get(layout[cell], 0) + 1
		var summary := PackedStringArray()
		for k in totals:
			summary.append("%s %d/%d" % [k, per_kind.get(k, 0), totals[k]])
		print("  skin '%s': unmatched per kind: %s" % [name, ", ".join(summary)])

		if not skin.has("tileset"):
			_check(layer.unmatched.size() == layout.size(),
					"skin '%s' has no tileset -> every cell falls back to greybox" % name)
		else:
			_check(layer.visible and layer.tile_set != null, "skin '%s' loaded its tileset" % name)
			var painted := 0
			for cell in layout:
				if layer.get_cell_source_id(cell) != -1:
					painted += 1
			_check(painted + layer.unmatched.size() == layout.size(),
					"skin '%s': every cell is either painted or reported unmatched (%d painted, %d unmatched, %d cells)" % [
							name, painted, layer.unmatched.size(), layout.size()])
			for k in MUST_DRESS:
				_check(per_kind.get(k, 0) == 0, "skin '%s' dresses every %s cell" % [name, k])
		layer.queue_free()
		collision.queue_free()
		await get_tree().process_frame

	print("test_skins: %d failures" % _fails)
	return 1 if _fails > 0 else 0
