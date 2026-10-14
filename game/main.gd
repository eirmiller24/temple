extends Node
## Scene flow: Title → Start menu (slots) → World (+ HUD, pause menu).
## The screens live under game/ui/ and talk to Main through signals; Main
## owns the World and the UI CanvasLayer.

const TITLE_SCENE := "res://game/ui/title_screen.tscn"
const START_MENU_SCENE := "res://game/ui/start_menu.tscn"
const HUD_SCENE := "res://game/ui/hud.tscn"
const PAUSE_SCENE := "res://game/ui/pause_menu.tscn"

var world: World
var ui: CanvasLayer
var hud: Node
var pause_menu: Node
var _screen: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui = CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 10
	add_child(ui)
	show_title()


func _clear_screen() -> void:
	if _screen != null:
		_screen.queue_free()
		_screen = null


func show_title() -> void:
	_clear_screen()
	_teardown_world()
	Music.play_track("title")
	_screen = _instance(TITLE_SCENE)
	ui.add_child(_screen)
	if _screen.has_signal("started"):
		_screen.started.connect(show_start_menu)


func show_start_menu() -> void:
	_clear_screen()
	_screen = _instance(START_MENU_SCENE)
	ui.add_child(_screen)
	if _screen.has_signal("new_game"):
		_screen.new_game.connect(_on_new_game)
	if _screen.has_signal("load_slot"):
		_screen.load_slot.connect(_on_load_slot)
	if _screen.has_signal("back"):
		_screen.back.connect(show_title)


func _on_new_game(slot: int) -> void:
	_clear_screen()
	_setup_world()
	await world.start_new_game()
	GameState.slot_index = slot
	SaveManager.save_game(slot)


func _on_load_slot(slot: int) -> void:
	if not SaveManager.load_game(slot):
		return
	_clear_screen()
	_setup_world()
	await world.continue_game()


func _setup_world() -> void:
	if world != null:
		return
	world = World.new()
	world.name = "World"
	# Main is PROCESS_MODE_ALWAYS (menus must run while paused); the world
	# must not inherit that or the pause menu could never stop it.
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	move_child(world, 0)
	hud = _instance(HUD_SCENE)
	if hud != null:
		hud.process_mode = Node.PROCESS_MODE_PAUSABLE
		ui.add_child(hud)
		if hud.has_method("bind"):
			hud.bind(world)
	pause_menu = _instance(PAUSE_SCENE)
	if pause_menu != null:
		ui.add_child(pause_menu)
		if pause_menu.has_method("bind"):
			pause_menu.bind(world)
		if pause_menu.has_signal("quit_to_title"):
			pause_menu.quit_to_title.connect(show_title)


func _teardown_world() -> void:
	get_tree().paused = false
	for n in [world, hud, pause_menu]:
		if n != null:
			n.queue_free()
	world = null
	hud = null
	pause_menu = null


func _instance(path: String) -> Node:
	if not ResourceLoader.exists(path):
		push_warning("Main: %s does not exist yet" % path)
		return null
	return (load(path) as PackedScene).instantiate()
