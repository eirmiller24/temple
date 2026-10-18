@tool
extends RefCounted
## What Project > Tools > New Room... and the godot-ai `new_room` tool both
## do: copy the template into game/rooms/, and rebuild data/rooms.json.
## Editor-only (it opens scenes and rescans the filesystem).

const TEMPLATE := "res://addons/room_tools/room_template.tscn"
const ROOMS_DIR := "res://game/rooms"
const REGISTRY := "res://data/rooms.json"
## Kind painted round the edge of a sized room.
const WALL_KIND := "solid"
## Columns between the left wall and the default entry.
const ENTRY_INSET := 2


## Where a room named `room_name` in `folder` would be saved.
static func target_path(room_name: String, folder: String) -> String:
	folder = folder.strip_edges().trim_prefix("/").trim_suffix("/")
	return "%s/%s%s.tscn" % [ROOMS_DIR, folder + "/" if folder != "" else "", room_name]


## Why `room_name` can't be used, or "" if it can.
static func validate_name(room_name: String) -> String:
	if room_name == "":
		return "Enter a name."
	if not room_name.is_valid_filename() or room_name != room_name.to_lower() \
			or room_name.contains(" ") or room_name.contains("."):
		return "Use lower-case snake_case with no spaces or dots."
	if room_name == "nodes":
		return "'nodes' is the node-class folder."
	for p in RoomRegistryBuilder.scene_paths():
		if p.get_file().get_basename() == room_name:
			return "A room named %s already exists (%s)." % [room_name, p]
	return ""


## Copy the template to `path`, place it on the world grid and open it.
## `size` (tiles, optional) paints a WALL_KIND border that big and stands
## the entry on its floor; `look` sets Room exports (skin, music, ...).
## Returns "" or the reason it failed.
static func create(room_name: String, path: String, world: Vector2i,
		size := Vector2i.ZERO, look := {}) -> String:
	var problem := validate_name(room_name)
	if problem != "":
		return problem
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var template: PackedScene = load(TEMPLATE)
	if template == null:
		return "cannot load %s" % TEMPLATE
	var root: Node = template.instantiate()
	root.name = room_name
	root.set("world_x", world.x)
	root.set("world_y", world.y)
	for key: String in look:
		root.set(key, look[key])
	if size != Vector2i.ZERO:
		problem = _paint_box(root, size)
		if problem != "":
			root.free()
			return problem
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		root.free()
		return "cannot pack %s" % room_name
	var err := ResourceSaver.save(packed, path)
	root.free()
	if err != OK:
		return "cannot write %s (error %d)" % [path, err]
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.open_scene_from_path(path)
	print("New Room: created %s" % path)
	return ""


## A one-tile wall round a `size` box, local tile (0, 0) at the top left,
## and the `main` entry standing on the floor near the left wall.
static func _paint_box(root: Node, size: Vector2i) -> String:
	var collision := root.get_node_or_null("Collision") as TileMapLayer
	if collision == null:
		return "template has no Collision layer"
	var tile := _kind_tile(collision.tile_set, WALL_KIND)
	if tile.is_empty():
		return "kind tileset has no '%s' tile" % WALL_KIND
	for x in size.x:
		for y in size.y:
			if x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1:
				collision.set_cell(Vector2i(x, y), tile.source, tile.coords)
	var entry := root.get_node_or_null("Entries/main") as Node2D
	if entry != null:
		entry.position = Vector2((ENTRY_INSET + 0.5) * Room.TILE, (size.y - 1) * Room.TILE)
	return ""


## {source, coords} of the tile whose custom data `kind` is `kind`.
static func _kind_tile(ts: TileSet, kind: String) -> Dictionary:
	if ts == null:
		return {}
	for i in ts.get_source_count():
		var id := ts.get_source_id(i)
		var src := ts.get_source(id) as TileSetAtlasSource
		if src == null:
			continue
		for t in src.get_tiles_count():
			var coords := src.get_tile_id(t)
			if String(src.get_tile_data(coords, 0).get_custom_data("kind")) == kind:
				return {"source": id, "coords": coords}
	return {}


## A world-grid spot for a new `size` room that overlaps nothing: the left
## edge of the world, `gap` tiles below the lowest room.
static func free_spot(size: Vector2i, gap := 4) -> Vector2i:
	var reg := RoomRegistryBuilder.build_from_scenes()
	if reg.is_empty():
		return Vector2i.ZERO
	var left := 1 << 30
	var bottom := -(1 << 30)
	for n: String in reg:
		var r: Dictionary = reg[n]
		if int(r.world_x) == Room.UNSET or int(r.world_y) == Room.UNSET:
			continue
		left = mini(left, int(r.x))
		bottom = maxi(bottom, int(r.y) + int(r.h))
	if bottom == -(1 << 30):
		return Vector2i.ZERO
	return Vector2i(left, bottom + gap)


## Rebuild data/rooms.json from the scenes (same code path as
## tools/build_room_registry.gd). Prints and returns the problems.
static func rebuild_registry() -> Dictionary:
	var reg := RoomRegistryBuilder.build_from_scenes()
	var problems := RoomRegistryBuilder.validate(reg)
	for p in problems:
		if p.begins_with("warning:"):
			print("rooms: ", p)
		else:
			push_error("rooms: " + p)
	var out := {
		"_comment": RoomRegistryBuilder.REGISTRY_COMMENT,
		"rooms": {},
	}
	var names := reg.keys()
	names.sort()
	for n in names:
		out.rooms[n] = reg[n]
	var f := FileAccess.open(REGISTRY, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("rooms.json rebuilt: %d rooms, %d problems" % [reg.size(), problems.size()])
	EditorInterface.get_resource_filesystem().scan()
	return {"rooms": reg.size(), "problems": problems}
