extends Node
## Renders every registered room once (player at its first entry, HUD
## off) and writes PNGs to user://screenshots/<room>.png — a quick way to
## eyeball skins, backdrops and object placement without opening the
## editor. Needs a real renderer (not --headless); on a machine without a
## display, run it under Xvfb:
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 \
##       --rendering-method gl_compatibility res://tools/screenshot_rooms.tscn
##
## Optional: pass a room name after `--` to shoot only that room, and
## `--debug` to overlay the F2 view.

const SETTLE_FRAMES := 24

var world: World


func _ready() -> void:
	await get_tree().process_frame
	world = World.new()
	world.debug_view = "--debug" in OS.get_cmdline_user_args()
	get_tree().root.add_child(world)
	GameState.new_game()
	var only := ""
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			only = a
	var names := RoomRegistry.rooms.keys()
	names.sort()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://screenshots"))
	for n in names:
		if only != "" and n != only:
			continue
		await world.load_room(n, "")
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var path := "user://screenshots/%s.png" % n
		img.save_png(path)
		print("wrote ", ProjectSettings.globalize_path(path))
	get_tree().quit(0)
