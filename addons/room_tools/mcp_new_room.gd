@tool
extends RefCounted
## godot-ai custom tool `new_room` (registered by plugin.gd): "give me a
## 30x20 room". Creates a walled, empty room of that size with the entry
## hall's look, rebuilds data/rooms.json and opens the scene. Same code
## path as Project > Tools > New Room... (room_factory.gd).

const RoomFactory := preload("res://addons/room_tools/room_factory.gd")
const ErrorCodes := preload("res://addons/godot_ai/utils/error_codes.gd")

## The entry hall's look (test_entry_hall.tscn); each can be overridden.
const DEFAULT_LOOK := {
	"skin": "cave_dark",
	"background": "cave_depths",
	"music": "collapse",
}
const DEFAULT_FOLDER := "test"
const MIN_SIZE := 4
const MAX_SIZE := 512

const SCHEMA := {
	"type": "object",
	"properties": {
		"width": {"type": "integer", "description": "Width in tiles, walls included."},
		"height": {"type": "integer", "description": "Height in tiles, walls included."},
		"name": {"type": "string", "description": "snake_case scene name. Default: room_<w>x<h>, numbered if taken."},
		"folder": {"type": "string", "description": "Folder under game/rooms/. Default 'test'; '' for top level."},
		"world_x": {"type": "integer", "description": "World-grid tile of local (0,0). Omit both to place below every existing room."},
		"world_y": {"type": "integer"},
		"display_name": {"type": "string"},
		"skin": {"type": "string", "description": "data/skins.json id. Default: the entry hall's."},
		"background": {"type": "string", "description": "data/backgrounds.json id. Default: the entry hall's."},
		"music": {"type": "string", "description": "data/music.json track. Default: the entry hall's."},
	},
	"required": ["width", "height"],
}
const DESCRIPTION := "Create a new empty Temple of Rhys room: a width x height (tiles) box with solid walls round the edge, a 'main' entry on the floor, the entry hall's skin/background/music. Saves it under game/rooms/<folder>/, rebuilds data/rooms.json and opens it in the editor. Returns the path, world position and any registry problems."


func new_room(params: Dictionary, _ctx) -> Dictionary:
	var w := int(params.get("width", 0))
	var h := int(params.get("height", 0))
	if w < MIN_SIZE or h < MIN_SIZE or w > MAX_SIZE or h > MAX_SIZE:
		return ErrorCodes.make(ErrorCodes.INVALID_PARAMS,
				"width and height must be %d..%d tiles (got %dx%d)" % [MIN_SIZE, MAX_SIZE, w, h])
	var size := Vector2i(w, h)
	var has_x := params.has("world_x")
	if has_x != params.has("world_y"):
		return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, "give both world_x and world_y, or neither")
	var world := Vector2i(int(params.world_x), int(params.world_y)) if has_x else RoomFactory.free_spot(size)

	var room_name := String(params.get("name", "")).strip_edges()
	if room_name == "":
		room_name = _free_name("room_%dx%d" % [w, h])
	var folder := String(params.get("folder", DEFAULT_FOLDER))
	var path := RoomFactory.target_path(room_name, folder)

	var look := DEFAULT_LOOK.duplicate()
	for key in ["skin", "background", "music", "display_name"]:
		if params.has(key):
			look[key] = String(params[key])

	var problem := RoomFactory.create(room_name, path, world, size, look)
	if problem != "":
		return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, problem)
	var registry := RoomFactory.rebuild_registry()
	return {"data": {
		"path": path,
		"name": room_name,
		"size": [w, h],
		"world_x": world.x,
		"world_y": world.y,
		"look": look,
		"registry_rooms": registry.rooms,
		"registry_problems": Array(registry.problems),
	}}


## `base`, or base_2, base_3... — the first no room uses.
func _free_name(base: String) -> String:
	var taken := {}
	for stem in RoomRegistryBuilder.scene_stems():
		taken[stem] = true
	var n := base
	var i := 2
	while taken.has(n):
		n = "%s_%d" % [base, i]
		i += 1
	return n
