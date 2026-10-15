extends Node
## DebugBoot: a room request skips the title, starts the World in that
## room at the asked entry, with every item at a full stack, and dying
## would respawn there. The F6 path (Room hands itself to DebugBoot) is
## the same request, made by Room._ready.
##
##   godot --headless --path . res://tests/test_room_boot.tscn

const ROOM := "test_shaft"
const ENTRY := "from_hall"

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


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> int:
	await get_tree().process_frame
	_check(DebugBoot.take().is_empty(), "no request (and no --room) means a normal boot")

	DebugBoot.request(ROOM, ENTRY)
	var main: Node = (load(DebugBoot.MAIN_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await _ticks(30)

	_check(DebugBoot.take().is_empty(), "the request is consumed")
	_check(main._screen == null, "no title or start menu")
	var world: World = main.world
	_check(world != null and world.room_name == ROOM, "world is in %s" % ROOM)
	if world == null or world.room == null:
		return 1
	var entry := world.room.entry_node(ENTRY)
	_check(entry != null, "room has entry '%s'" % ENTRY)
	if entry != null:
		var d := world.player.global_position.distance_to(entry.global_position)
		_check(d < Room.TILE * 2, "player starts at '%s' (%.0f px away)" % [ENTRY, d])
	for id: String in Data.items.items:
		var full := int(Data.items.items[id].get("stack", 1))
		_check(GameState.count(id) == full, "has %s x%d" % [id, full])
	_check(GameState.weapon != "", "a weapon is equipped (%s)" % GameState.weapon)
	_check(GameState.respawn_room == ROOM and GameState.respawn_entry == ENTRY, "respawns in the test room")

	main.queue_free()
	await _ticks(2)
	return 1 if _fails > 0 else 0
