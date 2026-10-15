extends Node
## UI smoke test: every screen under game/ui instantiates and runs headless,
## the HUD and minimap draw against a real World, the pause menu opens and
## closes on the `pause` action, switches tabs, highlights items and runs
## the use / drop / assign verbs, options change a setting (and put it
## back), and the F1 tuning panel edits a Data value in place.
##
##   godot --headless --path . res://tests/test_ui.tscn
##
## Tests are SCENES (see test_boot.gd). Exit 1 on any failed check.

const TEST_SLOT := 2

var _fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
		await get_tree().process_frame


## Press an action for two frames. The press must land right after a
## process_frame resume — before that frame's _process callbacks — for the
## menus' Input.is_action_just_pressed polling to see it, which is where a
## real input event (flushed at the start of the iteration) lands too.
func _tap(action: String) -> void:
	await get_tree().process_frame
	Input.action_press(action)
	await _ticks(2)
	Input.action_release(action)
	await _ticks(2)


## Send a real input event so Godot's focus navigation reacts to it.
func _event(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _ticks(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _ticks(2)


func _instance(path: String) -> Node:
	_check(ResourceLoader.exists(path), "%s exists" % path)
	if not ResourceLoader.exists(path):
		return null
	var n: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(n)
	return n


func _run() -> int:
	await get_tree().process_frame
	SaveManager.delete_slot(TEST_SLOT)

	# --- title ---------------------------------------------------------------------------------------------
	var title := _instance("res://game/ui/title_screen.tscn")
	var started := [false]
	_check(title.has_signal("started"), "title has `started`")
	title.started.connect(func() -> void: started[0] = true)
	await get_tree().create_timer(UiTheme.ARM_DELAY + 0.05).timeout
	await _tap("menu_accept")
	_check(started[0], "title emits started on menu_accept")
	title.queue_free()
	await _ticks(1)

	# --- start menu -----------------------------------------------------------------------------------------
	var menu := _instance("res://game/ui/start_menu.tscn")
	for s in ["new_game", "load_slot", "back"]:
		_check(menu.has_signal(s), "start menu has `%s`" % s)
	var picked := [-1]
	menu.new_game.connect(func(slot: int) -> void: picked[0] = slot)
	await get_tree().create_timer(UiTheme.ARM_DELAY + 0.05).timeout
	var focus := get_viewport().gui_get_focus_owner()
	_check(focus is Button and focus.text == "New Game", "start menu focuses New Game")
	await _tap("menu_accept")
	_check(menu._page == menu.Page.SLOTS_NEW, "New Game opens the slot picker")
	await _event("ui_down")
	await _event("ui_down")
	focus = get_viewport().gui_get_focus_owner()
	_check(focus is Button and focus.text.begins_with("3"), "ui_down reaches slot 3 (got '%s')" % (focus.text if focus else "none"))
	await _tap("menu_accept")
	_check(picked[0] == TEST_SLOT, "empty slot emits new_game(%d)" % TEST_SLOT)
	# Options page via keyboard: back to main, down to Options, accept.
	menu._show(menu.Page.MAIN)
	await _ticks(1)
	for i in 4:
		focus = get_viewport().gui_get_focus_owner()
		if focus is Button and focus.text == "Options":
			break
		await _event("ui_down")
	focus = get_viewport().gui_get_focus_owner()
	_check(focus is Button and focus.text == "Options", "ui_down walks to Options (got '%s')" % (focus.text if focus else "none"))
	await _tap("menu_accept")
	_check(menu._page == menu.Page.OPTIONS, "Options opens from the start menu")
	await _tap("menu_back")
	_check(menu._page == menu.Page.MAIN, "menu_back leaves options")
	# Continue lists only occupied slots and emits load_slot.
	SaveManager.save_game(TEST_SLOT)
	GameState.slot_index = -1
	var loaded := [-1]
	menu.load_slot.connect(func(slot: int) -> void: loaded[0] = slot)
	menu._show(menu.Page.MAIN)
	await _ticks(1)
	_check(not menu._continue_btn.disabled, "Continue enables once a slot exists")
	menu._show(menu.Page.SLOTS_LOAD)
	await _ticks(1)
	focus = get_viewport().gui_get_focus_owner()
	_check(focus is Button and focus.text.begins_with("3"), "Continue focuses the only occupied slot")
	await _tap("menu_accept")
	_check(loaded[0] == TEST_SLOT, "occupied slot emits load_slot(%d)" % TEST_SLOT)
	SaveManager.delete_slot(TEST_SLOT)
	menu._show(menu.Page.MAIN)
	await _ticks(1)
	var went_back := [false]
	menu.back.connect(func() -> void: went_back[0] = true)
	await _tap("menu_back")
	_check(went_back[0], "menu_back at top level emits back")
	menu.queue_free()
	await _ticks(1)

	# --- world + HUD -------------------------------------------------------------------------------------
	var world := World.new()
	get_tree().root.add_child(world)
	await world.start_new_game()
	await _ticks(10)
	var hud := _instance("res://game/ui/hud.tscn")
	hud.bind(world)
	await _ticks(5)
	_check(hud.hearts != null and hud.hearts.max_hp == GameState.max_hp, "HUD hearts follow max_hp")
	_check(hud._slot_x.text.begins_with("Slingshot"), "HUD X slot shows Slingshot (got '%s')" % hud._slot_x.text)
	_check(hud._weapon.text.begins_with("Bandit"), "HUD B shows the sword")
	_check(hud.minimap != null and hud.minimap.world == world, "HUD minimap bound")
	GameState.damage(1)
	await _ticks(3)
	_check(hud.hearts.hp == GameState.hp, "hearts update on damage")
	GameState.assign("y", "slingshot")
	await _ticks(2)
	_check(hud._slot_y.text.begins_with("Slingshot") and hud._slot_x.text.begins_with("Grappling"),
			"GameState.assign swaps the HUD slots")
	GameState.assign("x", "slingshot")
	await _ticks(2)

	# --- pause menu --------------------------------------------------------------------------------------
	var pause := _instance("res://game/ui/pause_menu.tscn")
	_check(pause.has_signal("quit_to_title"), "pause menu has `quit_to_title`")
	pause.bind(world)
	await _ticks(2)
	await _tap("pause")
	_check(pause.is_open and pause.visible and get_tree().paused, "pause opens the menu and pauses the tree")
	_check(pause.tab == pause.Tab.ITEMS, "opens on ITEMS")
	var items: UiItemsTab = pause.items
	_check(items.list_has_focus(), "item list takes focus")
	_check(items._ids.size() == GameState.inventory.size(), "list shows every inventory item (%d)" % items._ids.size())
	_check(items.highlighted_id() == "sword", "weapons list first (got '%s')" % items.highlighted_id())
	await _event("ui_down")
	_check(items.highlighted_id() != "sword", "ui_down highlights the next item")
	await _tap("menu_tab_next")
	_check(pause.tab == pause.Tab.MAP and pause.map.visible, "menu_tab_next shows the MAP tab")
	var pan0: Vector2 = pause.map.pan
	Input.action_press("ui_right", 1.0)
	await _ticks(5)
	Input.action_release("ui_right")
	_check(pause.map.pan.x > pan0.x, "ui_right pans the full map")
	await _tap("menu_tab_prev")
	_check(pause.tab == pause.Tab.ITEMS and items.list_has_focus(), "menu_tab_prev returns to ITEMS with focus")

	# Verbs: use (heal), assign prompt, drop.
	items.highlight(items._ids.find("dried_fruit"))
	await _ticks(1)
	var use_verb := Controls.glyph("attack") + " use"
	_check(items.verb_hint("dried_fruit").contains(use_verb), "usable item lists '%s'" % use_verb)
	_check(not items.verb_hint("small_key").contains(use_verb), "key item hides the use verb")
	var fruit0 := GameState.count("dried_fruit")
	var hp0 := GameState.hp
	await _tap("menu_use")
	_check(GameState.hp == mini(hp0 + 2, GameState.max_hp) and GameState.count("dried_fruit") == fruit0 - 1,
			"menu_use eats a fruit (hp %d → %d)" % [hp0, GameState.hp])
	await _tap("menu_use")  # full hp: returns false → error sound, no change
	_check(GameState.count("dried_fruit") == fruit0 - 1, "menu_use at full hp is refused")
	items.highlight(items._ids.find("lantern"))
	await _ticks(1)
	await _tap("menu_assign")
	_check(items.is_assigning(), "menu_assign prompts for a slot")
	await _tap("menu_slot_x")
	_check(GameState.slot_x == "lantern" and not items.is_assigning(), "menu_slot_x assigns the lantern to X")
	items.highlight(items._ids.find("sword"))
	await _ticks(1)
	await _tap("menu_assign")
	_check(not items.is_assigning() and GameState.slot_x == "lantern", "non-assignable item is refused")
	GameState.add_item("small_key", 2)
	await _ticks(2)
	items.highlight(items._ids.find("small_key"))
	await _ticks(1)
	await _tap("menu_drop")
	_check(GameState.count("small_key") == 1, "menu_drop removes one key")
	# Hidden-use hook: a fake item with hide_use shows no Use verb but menu_use still runs.
	Data.items.items["_test_fang"] = {"name": "Test Fang", "kind": "key", "hide_use": true, "description": "", "stack": 1}
	GameState.add_item("_test_fang")
	await _ticks(2)
	_check(not items.verb_hint("_test_fang").contains(use_verb), "hide_use item lists no Use verb")
	items.highlight(items._ids.find("_test_fang"))
	await _ticks(1)
	await _tap("menu_use")
	_check(items._status.text.begins_with("Can't use"), "menu_use still reaches the hidden item (refused by player)")
	GameState.remove_item("_test_fang")
	Data.items.items.erase("_test_fang")
	await _ticks(2)

	# Hold-to-assign (optional mode): hold Y assigns, a Y tap still drops.
	var hold0 := bool(SaveManager.settings.hold_to_assign)
	SaveManager.set_setting("hold_to_assign", true)
	GameState.add_item("climbing_gear", 2)
	await _ticks(2)
	items.highlight(items._ids.find("climbing_gear"))
	await _ticks(1)
	await get_tree().process_frame
	Input.action_press("menu_slot_y")
	await get_tree().create_timer(0.45).timeout
	Input.action_release("menu_slot_y")
	await _ticks(2)
	_check(GameState.slot_y == "climbing_gear" and GameState.count("climbing_gear") == 2, "holding Y assigns to Y without dropping")
	await _tap("menu_slot_y")
	_check(GameState.count("climbing_gear") == 1, "a Y tap in hold mode still drops")
	SaveManager.set_setting("hold_to_assign", hold0)
	GameState.remove_item("climbing_gear", 9)
	GameState.assign("y", "grapple")
	await _ticks(2)

	# Options from the pause menu: change SFX volume, then restore.
	var sfx0 := float(SaveManager.settings.sfx_volume)
	pause._open_options()
	await _ticks(2)
	_check(pause.options.visible and get_viewport().gui_get_focus_owner() is HSlider, "options panel opens with a slider focused")
	pause.options._sfx.value = 35
	await _ticks(1)
	_check(is_equal_approx(float(SaveManager.settings.sfx_volume), 0.35), "slider applies SaveManager.set_setting")
	SaveManager.set_setting("sfx_volume", sfx0)

	# Controls: the stick-swap toggle and button remapping.
	var swap0 := bool(SaveManager.settings.aim_swap_sticks)
	pause.options._swap.pressed.emit()
	await _ticks(1)
	_check(bool(SaveManager.settings.aim_swap_sticks) != swap0, "aim_swap_sticks toggles from the options row")
	SaveManager.set_setting("aim_swap_sticks", swap0)
	pause.options._controls_btn.pressed.emit()
	await _ticks(2)
	var ctl: UiControlsPanel = pause.options._controls
	_check(ctl.visible and not pause.options._box.visible, "Controls… opens the remap panel")
	_check(get_viewport().gui_get_focus_owner() == ctl._rows[0].pad, "first pad binding is focused")
	var bindings0: Dictionary = (SaveManager.settings.bindings as Dictionary).duplicate(true)
	# Eir's pad: B jump, Y attack, A/X items.
	var b_btn := InputEventJoypadButton.new()
	b_btn.button_index = JOY_BUTTON_B
	var y_btn := InputEventJoypadButton.new()
	y_btn.button_index = JOY_BUTTON_Y
	var a_btn := InputEventJoypadButton.new()
	a_btn.button_index = JOY_BUTTON_A
	var x_btn := InputEventJoypadButton.new()
	x_btn.button_index = JOY_BUTTON_X
	_check(Controls.set_binding("jump", "pad", b_btn) and Controls.set_binding("attack", "pad", y_btn)
			and Controls.set_binding("item_x", "pad", a_btn) and Controls.set_binding("item_y", "pad", x_btn),
			"set_binding accepts pad buttons")
	_check(Controls.glyph("jump", "pad") == "B" and Controls.glyph("attack", "pad") == "Y"
			and Controls.glyph("item_x", "pad") == "A" and Controls.glyph("item_y", "pad") == "X", "glyphs follow the remap")
	_check(Controls.glyph("jump", "key") == "Space", "keyboard binding untouched by a pad remap (%s)" % Controls.glyph("jump", "key"))
	var jump_events := InputMap.action_get_events("jump")
	var has_b := false
	var has_a := false
	for ev in jump_events:
		if ev is InputEventJoypadButton:
			has_b = has_b or ev.button_index == JOY_BUTTON_B
			has_a = has_a or ev.button_index == JOY_BUTTON_A
	_check(has_b and not has_a, "InputMap 'jump' now has B and not A")
	var use_pad := ""
	for ev in InputMap.action_get_events("menu_use"):
		if ev is InputEventJoypadButton:
			use_pad = Controls.event_name(ev)
	_check(use_pad == "Y", "menu_use mirrors the remapped attack button (%s)" % use_pad)
	var slot_pad := ""
	for ev in InputMap.action_get_events("menu_slot_x"):
		if ev is InputEventJoypadButton:
			slot_pad = Controls.event_name(ev)
	_check(slot_pad == "A", "menu_slot_x mirrors item 1 (%s)" % slot_pad)
	_check(Controls.conflicts("jump", "pad").is_empty(), "jump on B clashes with nothing (menu back on B is resolved by priority)")
	var b2 := InputEventJoypadButton.new()
	b2.button_index = JOY_BUTTON_B
	Controls.set_binding("dash", "pad", b2)
	_check(Controls.conflicts("jump", "pad").has("dash") and Controls.conflicts("dash", "pad").has("jump"),
			"two gameplay verbs on B are marked against each other")
	ctl.refresh()
	_check((ctl._rows[0].pad as Button).text == "B" and (ctl._rows[0].mark as Label).text == "!",
			"panel row shows the new glyph and the clash mark")
	ctl._show_row_status("jump")
	_check(ctl._status.text.contains("Dash"), "focusing the row explains the clash (%s)" % ctl._status.text)
	_check(hud._slot_keys["item_x"].text == Controls.glyph("item_x"), "HUD slot glyphs refreshed")
	# Keyboard rebind through the capture path.
	ctl._listen("dash", "key", ctl._rows[5].key)
	var k := InputEventKey.new()
	k.physical_keycode = KEY_F
	k.pressed = true
	ctl._input(k)
	await _ticks(1)
	_check(Controls.glyph("dash", "key") == "F" and ctl._listening.is_empty(), "captured key rebinds dash to F")
	_check(ctl.poll(), "panel swallows the frame after a capture")
	await _ticks(2)
	# Persistence: the settings file round-trips the bindings.
	SaveManager.load_settings()
	SaveManager.apply_settings()
	_check(Controls.glyph("jump", "pad") == "B" and Controls.glyph("dash", "key") == "F", "bindings survive a settings reload")
	Controls.reset_all()
	_check(Controls.glyph("jump", "pad") == "A" and Controls.glyph("dash", "key") == "Shift" and Controls.is_default("jump"),
			"reset restores the project defaults")
	SaveManager.set_setting("bindings", bindings0)
	await _tap("menu_back")
	_check(not ctl.visible and pause.options._box.visible, "menu_back leaves Controls for the options rows")
	await _tap("menu_back")
	_check(not pause.options.visible and pause.is_open, "menu_back closes options, menu stays open")
	await _tap("pause")
	_check(not pause.is_open and not pause.visible and not get_tree().paused, "pause closes the menu and unpauses")
	await _tap("map")
	_check(pause.is_open and pause.tab == pause.Tab.MAP, "map opens straight to MAP")
	await _tap("map")
	_check(not pause.is_open, "map again closes")

	# Save & Quit writes the slot and emits quit_to_title.
	GameState.slot_index = TEST_SLOT
	var quit := [false]
	pause.quit_to_title.connect(func() -> void: quit[0] = true)
	await _tap("pause")
	pause._save_and_quit()
	await _ticks(1)
	_check(quit[0] and SaveManager.slot_exists(TEST_SLOT) and not get_tree().paused, "Save & Quit saves and emits quit_to_title")
	SaveManager.delete_slot(TEST_SLOT)

	# --- tuning panel ---------------------------------------------------------------------------------------
	var tuning := hud.get_node_or_null("TuningPanel")
	_check(tuning != null, "HUD hosts the tuning panel")
	if tuning != null:
		await _tap("debug_tuning")
		_check(tuning.visible and tuning._entries.size() > 20, "F1 shows %d numeric rows" % tuning._entries.size())
		var run0 := float(Data.player.run_speed)
		_check(tuning.set_value("player.run_speed", 201.0) and is_equal_approx(float(Data.player.run_speed), 201.0),
				"editing a row writes Data.player in place")
		Data.player.run_speed = run0
		await _tap("debug_tuning")
		_check(not tuning.visible, "F1 hides it again")

	# Minimap with an empty registry must not error.
	var saved_rooms := RoomRegistry.rooms
	RoomRegistry.rooms = {}
	hud.minimap.queue_redraw()
	pause.map.queue_redraw()
	await _ticks(2)
	RoomRegistry.rooms = saved_rooms
	_check(true, "minimap survives an empty registry")

	for n in [pause, hud, world]:
		n.queue_free()
	await _ticks(2)

	await _main_flow()
	print("test_ui: %d failures" % _fails)
	return 1 if _fails > 0 else 0


## The real wiring: game/main.tscn drives title → start menu → new game in
## the test slot → pause → Save & Quit → title, all by input actions.
func _main_flow() -> void:
	var main := _instance("res://game/main.tscn")
	if main == null:
		return
	await get_tree().create_timer(UiTheme.ARM_DELAY + 0.05).timeout
	await _tap("menu_accept")  # title → start menu
	await get_tree().create_timer(UiTheme.ARM_DELAY + 0.05).timeout
	var screen: Node = main._screen
	_check(screen != null and screen.has_signal("new_game"), "Main shows the start menu after the title")
	await _tap("menu_accept")  # New Game → slot picker
	for i in 3:
		var f := get_viewport().gui_get_focus_owner()
		if f is Button and f.text.begins_with(str(TEST_SLOT + 1)):
			break
		await _event("ui_down")
	await _tap("menu_accept")  # empty test slot → new_game(TEST_SLOT)
	for i in 120:  # start_new_game awaits the fade before Main saves the slot
		await get_tree().process_frame
		if GameState.slot_index == TEST_SLOT:
			break
	_check(main.world != null and main.world.room != null, "Main built the world from new_game")
	_check(main.hud != null and main.pause_menu != null, "Main attached the HUD and pause menu")
	_check(GameState.slot_index == TEST_SLOT and SaveManager.slot_exists(TEST_SLOT), "new game saved to the slot")
	await _ticks(10)
	await _tap("pause")
	_check(main.pause_menu.is_open and get_tree().paused, "pause opens in the real scene tree")
	_check(not main.world.can_process(), "the world is actually paused under Main")
	await _tap("pause")
	_check(not get_tree().paused and main.world.can_process(), "resume unpauses the world")
	await _tap("pause")
	main.pause_menu._save_and_quit()
	await _ticks(3)
	_check(main.world == null and main._screen != null and main._screen.has_signal("started"),
			"Save & Quit returns to the title")
	SaveManager.delete_slot(TEST_SLOT)
	main.queue_free()
	await _ticks(2)
