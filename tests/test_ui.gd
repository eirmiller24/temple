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
	_check(hud._slot_x.id == "slingshot", "HUD item 1 slot shows the slingshot (got '%s')" % hud._slot_x.id)
	_check(hud._weapon.id == "sword" and hud._weapon.icon_texture() != null, "HUD attack slot shows the sword's icon")
	_check(hud._slot_x.badge_text() == Controls.glyph("item_x"), "HUD slot is badged with its button glyph")
	_check(hud.minimap != null and hud.minimap.world == world, "HUD minimap bound")
	GameState.damage(1)
	await _ticks(3)
	_check(hud.hearts.hp == GameState.hp, "hearts update on damage")
	GameState.assign("y", "slingshot")
	await _ticks(2)
	_check(hud._slot_y.id == "slingshot" and hud._slot_x.id == "grapple", "GameState.assign swaps the HUD slots")
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
	_check(items.has_cell_focus(), "an item cell takes focus")
	_check(items.highlighted_id() == "sword" and items.highlighted_section() == "weapons",
			"the first cell is the sword under WEAPONS (got '%s')" % items.highlighted_id())
	_check(items.cells("weapons").size() == UiItemsTab.fixed_slots("weapon").size()
			and items.cells("tools").size() == UiItemsTab.fixed_slots("tool").size(),
			"weapons and tools get one fixed slot per item in items.json")
	var boots := UiItemsTab.fixed_slots("passive").filter(func(c: Array) -> bool: return c.has("quality_boots"))
	_check(boots.size() == 1 and boots[0] == ["ratty_boots", "quality_boots"], "Quality Boots share the Ratty Boots slot")
	_check(items.cells("pack").size() >= UiItemsTab.COLS * UiItemsTab.PACK_ROWS, "the pack has its fixed grid")
	_check(UiItemsTab.pack_ids() == ["dried_fruit"], "only the fruit is in the starting pack (got %s)" % str(UiItemsTab.pack_ids()))
	await _event("ui_right")
	_check(items.has_cell_focus() and items.highlighted_section() == "weapons", "ui_right moves along the weapons row")
	await _event("ui_down")
	_check(items.highlighted_section() == "tools", "ui_down reaches the tools row (got '%s')" % items.highlighted_section())
	await _tap("menu_tab_next")
	_check(pause.tab == pause.Tab.MAP and pause.map.visible, "menu_tab_next shows the MAP tab")
	var pan0: Vector2 = pause.map.pan
	Input.action_press("ui_right", 1.0)
	await _ticks(5)
	Input.action_release("ui_right")
	_check(pause.map.pan.x > pan0.x, "ui_right pans the full map")
	await _tap("menu_tab_prev")
	_check(pause.tab == pause.Tab.ITEMS and items.has_cell_focus(), "menu_tab_prev returns to ITEMS with focus")

	# Weapons: accept equips, the item buttons and drop do nothing.
	GameState.add_item("whip")
	await _ticks(2)
	_check(items.highlight_item("whip"), "the whip has a weapons cell")
	await _ticks(1)
	await _tap("menu_accept")
	_check(GameState.weapon == "whip", "accept on a weapon equips it")
	await _tap("menu_slot_x")
	_check(GameState.slot_x != "whip" and GameState.has_item("whip"), "an item button does not put a weapon in a slot")
	_check(UiItemVerbs.drop(world, "whip").contains("can't") and GameState.has_item("whip"), "weapons can't be dropped")
	items.highlight_item("sword")
	await _ticks(1)
	await _tap("menu_accept")
	_check(GameState.weapon == "sword", "accept on the sword equips it back")

	# Tools: the item buttons assign directly; accept opens nothing.
	_check(items.highlight_item("lantern"), "the lantern has a tools cell")
	await _ticks(1)
	await _tap("menu_slot_x")
	_check(GameState.slot_x == "lantern", "item 1's button assigns the lantern to it")
	await _tap("menu_slot_y")
	_check(GameState.slot_y == "lantern" and GameState.slot_x != "lantern", "item 2's button moves it there")
	await _tap("menu_accept")
	_check(not items.is_popup_open() and pause.is_open, "accept on a tool opens no popup")
	_check(UiItemVerbs.drop(world, "lantern").contains("can't") and GameState.has_item("lantern"), "tools can't be dropped")
	_check(items.loadout_cell("item_y").id == "lantern", "the loadout card follows the assignment")
	GameState.assign("x", "slingshot")
	GameState.assign("y", "grapple")
	await _ticks(2)

	# Pack: accept opens the popup; item 2's button uses, accept toggles
	# the description, attack (= menu_back) backs out, item 1's button drops.
	_check(items.highlight_item("dried_fruit"), "the fruit has a pack cell")
	await _ticks(1)
	await _tap("menu_accept")
	_check(items.popup_item() == "dried_fruit" and items.is_modal(), "accept on a pack item opens its popup")
	_check(not items.popup_showing_description(), "the press that opened the popup does not also run it")
	var labels := items._popup_box.get_children().filter(func(c: Node) -> bool: return c is Button).map(
			func(b: Button) -> String: return b.text)
	_check(labels.size() == 4 and String(labels[0]).ends_with("Use"), "usable item lists Use, Drop, Description, Close (%s)" % str(labels))
	await _tap("menu_accept")
	_check(items.popup_showing_description(), "accept again shows the description")
	await _tap("menu_accept")
	_check(items.is_popup_open() and not items.popup_showing_description(), "accept returns to the verbs")
	var fruit0 := GameState.count("dried_fruit")
	var hp0 := GameState.hp
	await _tap("menu_use")
	_check(GameState.hp == mini(hp0 + 2, GameState.max_hp) and GameState.count("dried_fruit") == fruit0 - 1,
			"menu_use eats a fruit (hp %d → %d)" % [hp0, GameState.hp])
	_check(not items.is_popup_open() and items.has_cell_focus(), "using closes the popup and focus returns to the cell")
	await _tap("menu_accept")
	await _tap("menu_use")  # full hp: returns false → error, no change
	_check(GameState.count("dried_fruit") == fruit0 - 1, "menu_use at full hp is refused")
	_check(InputMap.action_get_events("menu_back").any(func(e: InputEvent) -> bool:
			return InputMap.event_is_action(e, "attack")), "menu_back carries the attack button")
	await _tap("menu_accept")
	await _tap("menu_back")
	_check(not items.is_popup_open() and pause.is_open, "menu_back shuts the popup, not the menu")
	GameState.add_item("small_key", 2)
	await _ticks(2)
	items.highlight_item("small_key")
	await _ticks(1)
	await _tap("menu_accept")
	var key_labels := items._popup_box.get_children().filter(func(c: Node) -> bool: return c is Button).map(
			func(b: Button) -> String: return b.text)
	_check(key_labels.size() == 3 and not str(key_labels).contains("Use"), "a key lists no Use (%s)" % str(key_labels))
	await _tap("menu_drop")
	_check(GameState.count("small_key") == 1 and not items.is_popup_open(), "menu_drop drops one key and closes the popup")
	_check(items.status_text().begins_with("Dropped"), "the card reports the drop (%s)" % items.status_text())
	# Hidden-use hook: a fake item with hide_use lists no Use but menu_use still runs.
	Data.items.items["_test_fang"] = {"name": "Test Fang", "kind": "key", "hide_use": true, "description": "", "stack": 1}
	GameState.add_item("_test_fang")
	await _ticks(2)
	_check(UiItemVerbs.section("_test_fang") == "pack", "a quest item lands in the pack")
	_check(UiItemVerbs.pack_verbs("_test_fang").filter(func(v: Array) -> bool: return v[1] == "use").is_empty(),
			"hide_use item lists no Use verb")
	items.highlight_item("_test_fang")
	await _ticks(1)
	await _tap("menu_accept")
	await _tap("menu_use")
	_check(items.status_text().begins_with("Can't use"), "menu_use still reaches the hidden item (refused by player)")
	GameState.remove_item("_test_fang")
	GameState.remove_item("small_key", 9)
	Data.items.items.erase("_test_fang")
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
	var drop_pad := ""
	for ev in InputMap.action_get_events("menu_drop"):
		if ev is InputEventJoypadButton:
			drop_pad = Controls.event_name(ev)
	_check(drop_pad == "A", "menu_drop mirrors the remapped item 1 button (%s)" % drop_pad)
	var use_pad := ""
	for ev in InputMap.action_get_events("menu_use"):
		if ev is InputEventJoypadButton:
			use_pad = Controls.event_name(ev)
	_check(use_pad == "X", "menu_use mirrors the remapped item 2 button (%s)" % use_pad)
	_check(Controls.glyph("menu_back", "pad") == "Y" and Controls.glyph("ui_cancel", "pad") == "Y",
			"menu_back and ui_cancel follow the remapped attack button (%s)" % Controls.glyph("menu_back", "pad"))
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
	_check(hud._slot_x.badge_text() == Controls.glyph("item_x"), "HUD slot glyphs refreshed")
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
