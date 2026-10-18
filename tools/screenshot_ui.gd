extends Node
## Renders the UI screens once each to user://screenshots/ui_<name>.png:
## title, start menu, start-menu options, controls (remap) panel, the
## in-game HUD, the pause menu's ITEMS tab (starting kit, every item, the
## pack popup), its MAP tab and its options. Like
## tools/screenshot_rooms.gd it needs a real renderer:
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 \
##       --rendering-method gl_compatibility res://tools/screenshot_ui.tscn

const SETTLE := 20

var main: Node


func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://screenshots"))
	main = (load("res://game/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await _settle()
	await _shot("title")
	main.show_start_menu()
	await _settle()
	await _shot("start_menu")
	var menu: Node = main._screen
	menu._show(menu.Page.OPTIONS)
	await _settle()
	await _shot("start_options")
	menu._options._open_controls()
	await _settle()
	await _shot("start_controls")
	# Into the game.
	main._on_new_game(2)
	await _settle(60)
	await _shot("hud")
	var pause: Node = main.pause_menu
	pause.open(pause.Tab.ITEMS)
	await _settle()
	await _shot("pause_items")
	# Every item, a key in the pack, then the pack popup on the fruit.
	GameState.grant_all_items()
	GameState.add_item("small_key", 2)
	await _settle()
	pause.items.highlight_item("darts")
	await _settle()
	await _shot("pause_items_full")
	pause.items.highlight_item("dried_fruit")
	await _settle(2)
	pause.items._activate(pause.items._focused)
	await _settle()
	await _shot("pause_items_popup")
	pause.items._close_popup(false)
	pause._set_tab(pause.Tab.MAP)
	await _settle()
	await _shot("pause_map")
	pause._set_tab(pause.Tab.ITEMS)
	pause._open_options()
	await _settle()
	await _shot("pause_options")
	pause.options._open_controls()
	await _settle()
	await _shot("pause_controls")
	SaveManager.delete_slot(2)
	get_tree().quit(0)


func _settle(frames: int = SETTLE) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://screenshots/ui_%s.png" % name
	img.save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))
