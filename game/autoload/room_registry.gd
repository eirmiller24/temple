extends Node
## Every room's place on the world grid, read from data/rooms.json (a build
## artifact of tools/build_room_registry.gd) or, when that file is stale or
## missing, rebuilt from the scenes under game/rooms/. The map, door
## wiring and the validator all read from here.
##
## Entry schema (data/rooms.json → rooms.<name>):
##   path            res:// scene path
##   display_name    what the map shows
##   x, y, w, h      world rect in tiles (x/y = world_x + painted rect origin)
##   world_x/world_y the authored grid position of local tile (0,0)
##   exits           [{to_room, to_entry, x, y, w, h, direction, locked_by}] (world tiles)
##   entries         {id: {x, y, facing}} (world tiles, fractional, feet)
##   darkness, music, skin, background  (for the map and debug jumps)

const ROOMS_DIR := "res://game/rooms"

var rooms := {}


func _ready() -> void:
	reload()
	Data.reloaded.connect(reload)


func reload() -> void:
	rooms = {}
	var from_file: Dictionary = Data.rooms.get("rooms", {})
	if not from_file.is_empty():
		rooms = from_file
		# Drift check: a scene added since the last registry build is
		# still reachable (we rebuild in memory and warn).
		for s in RoomRegistryBuilder.scene_stems():
			if not rooms.has(s):
				push_warning("rooms.json is stale (missing '%s') — rebuilding in memory; run tools/build_room_registry.gd" % s)
				rooms = RoomRegistryBuilder.build_from_scenes()
				break
	else:
		rooms = RoomRegistryBuilder.build_from_scenes()


func has_room(name: String) -> bool:
	return rooms.has(name)


func scene_path(name: String) -> String:
	if rooms.has(name):
		return String(rooms[name].path)
	for p in RoomRegistryBuilder.scene_paths():
		if p.get_file().get_basename() == name:
			return p
	return ""


func info(name: String) -> Dictionary:
	return rooms.get(name, {})


## World rect in tiles.
func rect(name: String) -> Rect2i:
	var r: Dictionary = rooms.get(name, {})
	if r.is_empty():
		return Rect2i()
	return Rect2i(int(r.x), int(r.y), int(r.w), int(r.h))


func entry_world_px(name: String, entry_id: String) -> Dictionary:
	var r: Dictionary = rooms.get(name, {})
	var entries: Dictionary = r.get("entries", {})
	if entries.is_empty():
		return {}
	var e: Dictionary = entries.get(entry_id, {})
	if e.is_empty():
		e = entries.values()[0]
	return {"pos": Vector2(float(e.x), float(e.y)) * Room.TILE, "facing": int(e.get("facing", 1))}
