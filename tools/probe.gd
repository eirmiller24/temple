extends Node
## Probe runner: boot the real World, clear the room's enemies, and run a
## throwaway GDScript snippet against it — instead of writing (and later
## deleting) a tests/zz_*.gd + .tscn pair for every quick experiment.
##
##   godot --headless --path . res://tools/probe.tscn -- /path/to/probe.gd
##   godot --headless --path . res://tools/probe.tscn -- --room test_shaft \
##       -e 'p.spawn_at(5, 8); await p.ticks(30); print(p.player.is_on_floor())'
##
## A probe file defines `func run(p) -> void` (it may await); a missing
## `extends` line is filled in. `-e` code becomes the body of run(). The
## file can live anywhere (a scratch dir is the point), not just res://.
## `p` is this node:
##
##   p.world, p.player, p.room          the live game
##   await p.ticks(n) / p.frames(n)     n physics / process frames
##   p.tile(col, row) -> Vector2        room tile coords -> world position
##   p.spawn_at(col, row, face := 1)    put the player (its origin) at a tile
##   await p.hold(action, n)            press an input action for n ticks
##   await p.load_room(name, entry)     switch rooms (enemies cleared again)
##   await p.shot(name)                 viewport PNG -> <out>/<name>.png
##   p.check(cond, msg)                 print ok / CHECK FAILED; any failure exits 1
##
## Options (after `--`):
##   --room R [--entry E]   start in R instead of the new-game room
##   --all-items            grant every item (what DebugBoot / F6 does)
##   --keep-enemies         don't free the room's Enemies children
##   --out DIR              screenshot dir (default user://probe)
##   -e CODE                inline snippet instead of a file
##
## Screenshots need a real renderer: under --headless shot() prints a
## warning and does nothing. For pictures run it under Xvfb:
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 \
##       --rendering-method gl_compatibility res://tools/probe.tscn -- …

const SETTLE_TICKS := 20
const SHOT_FRAMES := 4

var world: World
var player: Player
var room: Room

var _fails := 0
var _keep_enemies := false
var _out := "user://probe"


func _ready() -> void:
	var code := await _main()
	get_tree().quit(code)


func _main() -> int:
	var opts := _parse_args(OS.get_cmdline_user_args())
	if opts.has("error"):
		push_error("probe: " + opts.error)
		return 2
	var script := _compile(opts)
	if script == null:
		return 2
	_keep_enemies = opts.keep_enemies
	if opts.out != "":
		_out = opts.out

	await get_tree().process_frame
	world = World.new()
	get_tree().root.add_child(world)
	GameState.new_game()
	if opts.all_items:
		GameState.grant_all_items()
	var start_room: String = opts.room if opts.room != "" else GameState.respawn_room
	var start_entry: String = opts.entry if opts.room != "" else GameState.respawn_entry
	await load_room(start_room, start_entry)
	if room == null:
		return 2

	var inst = script.new()
	await inst.run(self)
	if _fails > 0:
		print("probe: %d check(s) failed" % _fails)
	return 1 if _fails > 0 else 0


# --- helpers for probe code ---------------------------------------------------------------

func ticks(n: int = 1) -> void:
	for i in n:
		await get_tree().physics_frame


func frames(n: int = 1) -> void:
	for i in n:
		await get_tree().process_frame


func tile(col: float, row: float) -> Vector2:
	return room.global_position + Vector2(col, row) * Room.TILE


func spawn_at(col: float, row: float, face: int = 1) -> void:
	player.spawn_at(tile(col, row), face)


func hold(action: String, n: int) -> void:
	Input.action_press(action)
	await ticks(n)
	Input.action_release(action)


func load_room(name: String, entry: String = "") -> void:
	await world.load_room(name, entry)
	room = world.room
	player = world.player
	if room == null:
		push_error("probe: room '%s' did not load" % name)
		return
	if not _keep_enemies and room.has_node("Enemies"):
		for e in room.get_node("Enemies").get_children():
			e.queue_free()
	await ticks(SETTLE_TICKS)


func shot(name: String = "probe") -> String:
	if DisplayServer.get_name() == "headless":
		push_warning("probe: shot('%s') skipped, no renderer under --headless (use xvfb-run)" % name)
		return ""
	await frames(SHOT_FRAMES)
	DirAccess.make_dir_recursive_absolute(_globalize(_out))
	var path := _globalize(_out).path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("probe: wrote ", path)
	return path


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: ", msg)
	else:
		push_error("CHECK FAILED: " + msg)
		_fails += 1


# --- plumbing -------------------------------------------------------------------------------

func _parse_args(args: PackedStringArray) -> Dictionary:
	var o := {"file": "", "code": "", "room": "", "entry": "", "out": "",
		"all_items": false, "keep_enemies": false}
	var i := 0
	while i < args.size():
		var a := args[i]
		var takes_value := a in ["--room", "--entry", "--out", "-e"]
		if takes_value and i + 1 >= args.size():
			return {"error": "%s needs a value" % a}
		match a:
			"--room": o.room = args[i + 1]
			"--entry": o.entry = args[i + 1]
			"--out": o.out = args[i + 1]
			"-e": o.code = args[i + 1]
			"--all-items": o.all_items = true
			"--keep-enemies": o.keep_enemies = true
			_:
				if a.begins_with("-"):
					return {"error": "unknown option " + a}
				o.file = a
		i += 2 if takes_value else 1
	if (o.file == "") == (o.code == ""):
		return {"error": "give a probe file or -e CODE (exactly one)"}
	return o


func _compile(opts: Dictionary) -> GDScript:
	var src: String
	if opts.code != "":
		src = "func run(p) -> void:\n"
		for line in String(opts.code).split("\n"):
			src += "\t" + line + "\n"
		src += "\tpass\n"
	else:
		var path := _globalize(opts.file)
		if not FileAccess.file_exists(path):
			push_error("probe: no such file " + path)
			return null
		src = FileAccess.get_file_as_string(path)
	if not src.strip_edges().begins_with("extends"):
		src = "extends RefCounted\n" + src
	var gd := GDScript.new()
	gd.source_code = src
	if gd.reload() != OK:
		push_error("probe: script failed to compile (see the parse error above)")
		return null
	if not "run" in gd.get_script_method_list().map(func(m): return m.name):
		push_error("probe: script has no func run(p)")
		return null
	return gd


func _globalize(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	if path.is_relative_path():
		return ProjectSettings.globalize_path("res://").path_join(path)
	return path
