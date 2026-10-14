@tool
class_name SkinLayer
extends TileMapLayer
## Auto-tiles a skin's art over the room's Collision kind layer (ported
## from dungeon-platformer's SkinLayer). This layer is paint, never
## collision: the kind layer keeps the physics.
##
## Skin schema (data/skins.json → <name>):
##   tile_tint   modulate colour (required)
##   tileset     res:// path of the art TileSet (absent → greybox rects)
##   terrains    kind → [terrain_set, terrain] (terrain autotile) or
##               {"atlas": [source_id, x, y]} (one fixed tile)
##
## THE RING: one cosmetic ring of cells just outside the painted room,
## each copying its nearest border cell, so 1-thick border walls autotile
## as proper edges. The ring is constraint-only: rendering is clipped to
## the room rect.
##
## Thin-geometry patch: purchased terrain blobs rarely cover all 47
## configurations, so cells the solver leaves empty get the terrain's
## fill tile; kinds with no mapping at all land in `unmatched` and the
## GreyboxLayer draws them as flat rects (collision is never invisible).

var unmatched: Array[Vector2i] = []

var _collision: TileMapLayer
var _skin: Dictionary = {}
var _room_rect := Rect2i()


func build(collision: TileMapLayer, skin: Dictionary) -> void:
	clear()
	unmatched = []
	_collision = collision
	_skin = skin
	_room_rect = collision.get_used_rect()
	var ts_path := String(skin.get("tileset", ""))
	if ts_path == "" or not ResourceLoader.exists(ts_path):
		visible = false
		for cell in collision.get_used_cells():
			unmatched.append(cell)
		return
	visible = true
	tile_set = load(ts_path)
	var native := float(tile_set.tile_size.x)
	scale = Vector2(Room.TILE / native, Room.TILE / native)
	modulate = Color(String(skin.get("tile_tint", "#ffffff")))
	# Clip rendering to the room rect (ring cells constrain but never draw).
	var rid := get_canvas_item()
	RenderingServer.canvas_item_set_custom_rect(rid, true,
			Rect2(Vector2(_room_rect.position) * native, Vector2(_room_rect.size) * native))
	RenderingServer.canvas_item_set_clip(rid, true)
	var by_kind := _cells_by_kind(_all_cells_with_ring())
	for kind: String in by_kind:
		_paint(by_kind[kind], kind)
	if not unmatched.is_empty() and not Engine.is_editor_hint():
		push_warning("skin '%s': %d cells have no art — drawn as greybox" % [
				String(skin.get("_name", "?")), unmatched.size()])


## Refresh only the given kind cells (a broken wall) so the solver's
## random variant picks elsewhere don't reshuffle.
func update_cells(cells: Array[Vector2i]) -> void:
	if _collision == null or not visible:
		return
	var terrains: Dictionary = _skin.get("terrains", {})
	for cell in cells:
		unmatched.erase(cell)
		var kind := _kind(cell)
		if kind == "":
			# Painting "no terrain" erases AND re-fits the neighbours.
			var m: Variant = _mapping_for_cell_neighbours(cell, terrains)
			if typeof(m) == TYPE_ARRAY:
				set_cells_terrain_connect([cell], int(m[0]), -1)
			else:
				erase_cell(cell)
		else:
			_paint([cell], kind)


func _mapping_for_cell_neighbours(cell: Vector2i, terrains: Dictionary) -> Variant:
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var k := _kind(cell + d)
		if k != "" and terrains.has(k):
			return terrains[k]
	return null


func _kind(cell: Vector2i) -> String:
	var td := _collision.get_cell_tile_data(cell)
	return "" if td == null else String(td.get_custom_data("kind"))


## Kind of a cell, with ring cells clamp-sampling the nearest in-room cell.
func _kind_ringed(cell: Vector2i) -> String:
	var c := Vector2i(
			clampi(cell.x, _room_rect.position.x, _room_rect.end.x - 1),
			clampi(cell.y, _room_rect.position.y, _room_rect.end.y - 1))
	return _kind(c)


func _all_cells_with_ring() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(_room_rect.position.y - 1, _room_rect.end.y + 1):
		for x in range(_room_rect.position.x - 1, _room_rect.end.x + 1):
			out.append(Vector2i(x, y))
	return out


func _cells_by_kind(cells: Array[Vector2i]) -> Dictionary:
	var out := {}
	for cell in cells:
		var kind := _kind_ringed(cell)
		if kind == "":
			continue
		if not out.has(kind):
			out[kind] = [] as Array[Vector2i]
		out[kind].append(cell)
	return out


func _in_room(c: Vector2i) -> bool:
	return _room_rect.has_point(c)


func _paint(cells: Array[Vector2i], kind: String) -> void:
	var terrains: Dictionary = _skin.get("terrains", {})
	var mapping: Variant = terrains.get(kind)
	if mapping == null:
		for cell in cells:
			if _in_room(cell) and not unmatched.has(cell):
				unmatched.append(cell)
	elif typeof(mapping) == TYPE_ARRAY:
		set_cells_terrain_connect(cells, int(mapping[0]), int(mapping[1]))
		_patch_unmatched(cells, int(mapping[0]), int(mapping[1]))
	elif typeof(mapping) == TYPE_DICTIONARY and mapping.has("atlas"):
		var a: Array = mapping.atlas
		for cell in cells:
			set_cell(cell, int(a[0]), Vector2i(int(a[1]), int(a[2])))


func _patch_unmatched(cells: Array[Vector2i], terrain_set: int, terrain: int) -> void:
	var fill := _fill_tile(terrain_set, terrain)
	for cell in cells:
		if get_cell_source_id(cell) != -1:
			continue
		if fill.is_empty():
			if _in_room(cell) and not unmatched.has(cell):
				unmatched.append(cell)
		else:
			set_cell(cell, fill.source, fill.coords)


## The terrain's most-connected tile (all eight peering bits = interior fill).
func _fill_tile(terrain_set: int, terrain: int) -> Dictionary:
	var best := {}
	var best_bits := -1
	for s in tile_set.get_source_count():
		var sid := tile_set.get_source_id(s)
		var src := tile_set.get_source(sid) as TileSetAtlasSource
		if src == null:
			continue
		for i in src.get_tiles_count():
			var coords := src.get_tile_id(i)
			var td := src.get_tile_data(coords, 0)
			if td.terrain_set != terrain_set or td.terrain != terrain:
				continue
			var bits := 0
			for b in 16:
				if td.is_valid_terrain_peering_bit(b) and td.get_terrain_peering_bit(b) == terrain:
					bits += 1
			if bits > best_bits:
				best_bits = bits
				best = {"source": sid, "coords": coords}
	return best
