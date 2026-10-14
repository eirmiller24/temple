extends SceneTree
## Rebuilds data/rooms.json from the room scenes and validates the world
## grid. Run after any room change; commit the scene AND the JSON:
##
##   godot --headless --path . -s res://tools/build_room_registry.gd
##
## Exit code 1 on any validation error (unknown exit target, a seam exit
## that doesn't touch its neighbour, a missing entry id, an unplaced
## room). Overlap warnings are printed but don't fail the build.


func _init() -> void:
	# Autoloads exist only after the first frame; game classes compiled
	# before that fail to resolve them.
	await process_frame
	quit(_run())


func _run() -> int:
	var reg := RoomRegistryBuilder.build_from_scenes()
	var problems := RoomRegistryBuilder.validate(reg)
	var errors := 0
	for p in problems:
		if p.begins_with("warning:"):
			print("  ", p)
		else:
			push_error(p)
			errors += 1
	var out := {
		"_comment": RoomRegistryBuilder.REGISTRY_COMMENT,
		"rooms": {},
	}
	var names := reg.keys()
	names.sort()
	for n in names:
		out.rooms[n] = reg[n]
	var f := FileAccess.open("res://data/rooms.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("rooms.json: %d rooms, %d errors, %d warnings" % [reg.size(), errors, problems.size() - errors])
	return 1 if errors > 0 else 0
