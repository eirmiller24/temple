class_name DebugBoot
extends RefCounted
## Dev shortcut past the title screen: start the real game (World, player,
## HUD, pause menu) in one room with every item. Two ways in:
##
##   - Run Current Scene (F6) on a room scene: the Room sees it is the scene
##     being played, asks for itself here and hands over to main.tscn.
##     Its `test_entry` picks the RoomEntry (empty = the first).
##   - The command line:  godot --path . -- --room test_shaft [--entry from_hall]
##
## Main takes the request once, in _ready. Plain class (no autoload names)
## because the @tool Room calls it.

const MAIN_SCENE := "res://game/main.tscn"

static var _room := ""
static var _entry := ""
static var _cmdline_read := false


static func request(room: String, entry: String = "") -> void:
	_room = room
	_entry = entry


## Called by a Room that is the running scene: replace it with Main.
static func play_room(tree: SceneTree, room: String, entry: String) -> void:
	request(room, entry)
	# Deferred: during boot the root is still adding the room.
	tree.change_scene_to_file.call_deferred(MAIN_SCENE)


## The pending request as {room, entry}, or {} for a normal boot. Clears it.
static func take() -> Dictionary:
	if _room == "" and not _cmdline_read:
		_cmdline_read = true
		_read_cmdline()
	if _room == "":
		return {}
	var req := {"room": _room, "entry": _entry}
	_room = ""
	_entry = ""
	return req


static func _read_cmdline() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var next := args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--room":
				_room = next
			"--entry":
				_entry = next
