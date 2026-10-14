extends SceneTree
## ONE-OFF generator for game/rooms/tileset_kind.tres — the authoring
## palette every room's Collision layer is painted with. The .tres is a
## checked-in resource; re-run this only when the kind vocabulary changes
## (then update docs/room_authoring.md and GreyboxLayer.KIND_COLORS).
##
##   godot --headless --path . -s res://tools/gen_kind_tileset.gd
##
## Each tile carries custom data `kind` (String) and, where the kind is
## solid, its physics shape on physics layer 0 (collision layer 1 =
## "world"). Water and hazard carry no shape: the player samples the kind
## under its feet instead.

const T := 32
const KINDS := [
	# name, fill colour, accent colour
	["solid", Color("46464f"), Color("5a5a66")],
	["oneway", Color("6e6a58"), Color("a89c74")],
	["breakable", Color("55504a"), Color("8a8070")],
	["fortified", Color("3a3a48"), Color("7c7cb0")],
	["water", Color("3f7fd0"), Color("8fd0ff")],
	["hazard", Color("b04040"), Color("ffb0b0")],
	["ramp_r", Color("46464f"), Color("5a5a66")],
	["ramp_l", Color("46464f"), Color("5a5a66")],
]


func _init() -> void:
	quit(_run())


func _run() -> int:
	var img := Image.create(T * KINDS.size(), T, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in KINDS.size():
		_paint_tile(img, i, KINDS[i][0], KINDS[i][1], KINDS[i][2])
	var tex := ImageTexture.create_from_image(img)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)   # "world"
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_custom_data_layer(0)
	ts.set_custom_data_layer_name(0, "kind")
	ts.set_custom_data_layer_type(0, TYPE_STRING)

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(T, T)
	# The source must belong to the TileSet BEFORE tile data is written,
	# or the custom-data / physics layers don't exist from the tile's view.
	ts.add_source(src, 0)
	for i in KINDS.size():
		var coords := Vector2i(i, 0)
		src.create_tile(coords)
		var td := src.get_tile_data(coords, 0)
		var kind: String = KINDS[i][0]
		td.set_custom_data("kind", kind)
		var poly := _shape_for(kind)
		if not poly.is_empty():
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, poly)
			if kind == "oneway":
				td.set_collision_polygon_one_way(0, 0, true)
				td.set_collision_polygon_one_way_margin(0, 0, 4.0)
	var err := ResourceSaver.save(ts, "res://game/rooms/tileset_kind.tres")
	if err != OK:
		push_error("save failed: %d" % err)
		return 1
	print("wrote game/rooms/tileset_kind.tres with %d kinds" % KINDS.size())
	return 0


## Polygons are in tile-local coordinates centred on the tile (Godot's
## TileData convention: origin at the tile centre).
func _shape_for(kind: String) -> PackedVector2Array:
	var h := T / 2.0
	match kind:
		"solid", "breakable", "fortified":
			return PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
		"oneway":
			# A thin lip on the top quarter so it reads (and collides) as a ledge.
			return PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, -h + T * 0.25), Vector2(-h, -h + T * 0.25)])
		"ramp_r":
			# ascends toward +x:  /
			return PackedVector2Array([Vector2(-h, h), Vector2(h, -h), Vector2(h, h)])
		"ramp_l":
			# ascends toward -x:  \
			return PackedVector2Array([Vector2(-h, -h), Vector2(h, h), Vector2(-h, h)])
	return PackedVector2Array()


func _paint_tile(img: Image, i: int, kind: String, fill: Color, accent: Color) -> void:
	var ox := i * T
	match kind:
		"oneway":
			for y in int(T * 0.25):
				for x in T:
					img.set_pixel(ox + x, y, accent if y < 2 else fill)
		"ramp_r":
			for y in T:
				for x in T:
					if x >= T - 1 - y:
						img.set_pixel(ox + x, y, accent if x == T - 1 - y else fill)
		"ramp_l":
			for y in T:
				for x in T:
					if x <= y:
						img.set_pixel(ox + x, y, accent if x == y else fill)
		"water":
			for y in T:
				for x in T:
					img.set_pixel(ox + x, y, accent if y < 3 else Color(fill, 0.6))
		"breakable":
			for y in T:
				for x in T:
					var speck := ((x * 7 + y * 11) % 13) == 0
					img.set_pixel(ox + x, y, accent if speck else fill)
		"fortified":
			for y in T:
				for x in T:
					var brick := (y % 8 == 0) or ((x + (8 if (y / 8) % 2 == 0 else 0)) % 16 == 0)
					img.set_pixel(ox + x, y, accent if brick else fill)
		"hazard":
			for y in T:
				for x in T:
					var spike := (y >= T - 12) and (absi((x % 8) - 4) <= (y - (T - 12)) / 3)
					img.set_pixel(ox + x, y, accent if spike else Color(fill, 0.5))
		_:
			for y in T:
				for x in T:
					var edge := x == 0 or y == 0 or x == T - 1 or y == T - 1
					img.set_pixel(ox + x, y, accent if edge else fill)
