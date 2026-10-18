extends Control
## The pause menu. `pause` opens it on ITEMS (get_tree().paused = true;
## this node runs PROCESS_MODE_ALWAYS), `map` opens straight to MAP. Two
## tabs — ITEMS (UiItemsTab) and MAP (UiMinimap, full, panned with ui_*
## while nothing has focus) — switched with menu_tab_prev/next or a click,
## and a footer: the highlighted item's verb hint on the left, then
## Options (UiOptionsPanel), Save & Quit to Title (saves to
## GameState.slot_index when >= 0, then emits quit_to_title) and Resume.
##
## Input is polled once per frame here and handed down (item popup →
## options → items → tabs → back), which resolves the shared gamepad
## buttons in one place: attack is back everywhere (Controls.MIRRORS); in
## the item popup item 1's button drops and item 2's uses; on a tool the
## item buttons assign.

signal quit_to_title

enum Tab { ITEMS, MAP }

const PANEL := Rect2(24, 16, 912, 508)
const BODY := Rect2(40, 62, 880, 400)
const MAP_TILE_PX := 8.0
const PAN_TILES_PER_SEC := 30.0

var world: World
var tab: int = Tab.ITEMS
var items: UiItemsTab
var map: UiMinimap
var options: UiOptionsPanel
var is_open := false
var _tab_buttons: Array = []
var _bottom: Array = []
var _room_label: Label
var _tab_hint: Label
var _verb_hint: Label
var _last_focus: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.theme()
	UiTheme.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = UiTheme.DIM_OVERLAY
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.fill(dim)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.PANEL, UiTheme.DIM, 0))
	panel.position = PANEL.position
	panel.size = PANEL.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_build_header()
	_build_body()
	_build_footer()
	_set_tab(Tab.ITEMS)


func _build_header() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.position = PANEL.position + Vector2(16, 12)
	row.size = Vector2(PANEL.size.x - 32, 32)
	add_child(row)
	for t in [["ITEMS", Tab.ITEMS], ["MAP", Tab.MAP]]:
		var b := UiTheme.button(String(t[0]), UiTheme.SIZE_LABEL, 110)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_set_tab.bind(int(t[1])))
		row.add_child(b)
		_tab_buttons.append(b)
	_tab_hint = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.DIM)
	row.add_child(_tab_hint)
	Controls.bindings_changed.connect(_refresh_tab_hint)
	_refresh_tab_hint()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	_room_label = UiTheme.label("", UiTheme.SIZE_LABEL, UiTheme.DIM)
	row.add_child(_room_label)


func _refresh_tab_hint() -> void:
	_tab_hint.text = "  %s  ◂  ▸  %s" % [Controls.glyph("menu_tab_prev"), Controls.glyph("menu_tab_next")]


func _build_body() -> void:
	items = UiItemsTab.new()
	items.position = BODY.position
	items.size = BODY.size
	add_child(items)
	items.hint_changed.connect(func(t: String) -> void: _verb_hint.text = t)
	map = UiMinimap.new()
	map.full = true
	map.show_names = true
	map.tile_px = MAP_TILE_PX
	map.position = BODY.position
	map.size = BODY.size
	add_child(map)
	options = UiOptionsPanel.new()
	options.position = BODY.position + Vector2(16, 8)
	options.visible = false
	add_child(options)
	options.closed.connect(_close_options)


func _build_footer() -> void:
	var rule := UiTheme.rule(PANEL.size.x - 32, Color(UiTheme.DIM, 0.5))
	rule.position = Vector2(PANEL.position.x + 16, PANEL.end.y - 50)
	add_child(rule)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.position = Vector2(BODY.position.x, PANEL.end.y - 42)
	row.size = Vector2(BODY.size.x, 32)
	add_child(row)
	_verb_hint = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.DIM)
	_verb_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_verb_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_verb_hint)
	var opt := UiTheme.button("Options", UiTheme.SIZE_LABEL, 120)
	var quit := UiTheme.button("Save & Quit to Title", UiTheme.SIZE_LABEL, 190)
	var resume := UiTheme.button("Resume", UiTheme.SIZE_LABEL, 120)
	for b in [opt, quit, resume]:
		UiTheme.focus_on_hover(b)
		row.add_child(b)
	opt.pressed.connect(_open_options)
	quit.pressed.connect(_save_and_quit)
	resume.pressed.connect(close)
	_bottom = [opt, quit, resume]
	UiTheme.chain_focus_row(_bottom)


func bind(w: World) -> void:
	world = w
	items.bind(w)
	map.bind(w)
	# Main runs PROCESS_MODE_ALWAYS and the world inherits it; pausing the
	# tree must actually stop the world.
	if w.process_mode == Node.PROCESS_MODE_INHERIT:
		w.process_mode = Node.PROCESS_MODE_PAUSABLE


# --- open / close ---------------------------------------------------------------------------------

func open(to_tab: int = Tab.ITEMS) -> void:
	if is_open or world == null or not is_instance_valid(world):
		return
	if get_tree().paused:
		return  # a room transition owns the pause right now
	if world.player != null and world.player.state == Player.State.DEAD:
		return
	is_open = true
	visible = true
	get_tree().paused = true
	Sfx.play("map_open" if to_tab == Tab.MAP else "menu_open")
	_room_label.text = "%s   %s" % [_room_name(), SaveManager.format_playtime(GameState.playtime)]
	items.refresh()
	_set_tab(to_tab)


func close() -> void:
	if not is_open:
		return
	is_open = false
	options.visible = false
	visible = false
	get_tree().paused = false
	get_viewport().gui_release_focus()
	Sfx.play("menu_close")


func _room_name() -> String:
	if world == null or world.room == null:
		return ""
	var info := RoomRegistry.info(world.room_name)
	return String(info.get("display_name", world.room.room_name()))


func _set_tab(t: int) -> void:
	tab = t
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = i == t
	items.visible = t == Tab.ITEMS and not options.visible
	map.visible = t == Tab.MAP and not options.visible
	_verb_hint.visible = t == Tab.ITEMS
	if t == Tab.MAP:
		map.pan = Vector2.ZERO
		if is_inside_tree():
			get_viewport().gui_release_focus()
	elif is_open:
		items.focus_list()
	# ui_up from the bottom row finds the nearest item cell (Godot's
	# geometric focus) on ITEMS and stays put on MAP.
	for b: Button in _bottom:
		b.focus_neighbor_top = NodePath("") if t == Tab.ITEMS else NodePath(".")
		b.focus_neighbor_bottom = NodePath(".")


func _open_options() -> void:
	options.visible = true
	items.visible = false
	map.visible = false
	options.refresh()
	options.focus_first()
	Sfx.play("menu_accept")


func _close_options() -> void:
	options.visible = false
	_set_tab(tab)


func _save_and_quit() -> void:
	if GameState.slot_index >= 0:
		SaveManager.save_game(GameState.slot_index)
		Sfx.play("save")
	close()
	quit_to_title.emit()


# --- per-frame input --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_open:
		if world == null or not is_instance_valid(world):
			return
		if Input.is_action_just_pressed("pause"):
			open(Tab.ITEMS)
		elif Input.is_action_just_pressed("map"):
			open(Tab.MAP)
		return
	_focus_sound()
	if tab == Tab.ITEMS and items.is_modal() and not options.visible:
		items.poll()
		return
	if options.visible:
		if options.poll():
			return
	if Input.is_action_just_pressed("pause"):
		close()
		return
	if Input.is_action_just_pressed("map"):
		if tab == Tab.MAP and not options.visible:
			close()
		else:
			options.visible = false
			_set_tab(Tab.MAP)
		return
	if options.visible:
		return
	if tab == Tab.ITEMS and items.poll():
		return
	if Input.is_action_just_pressed("menu_tab_next") or Input.is_action_just_pressed("menu_tab_prev"):
		Sfx.play("page_turn")
		_set_tab(Tab.MAP if tab == Tab.ITEMS else Tab.ITEMS)
		return
	var focus := get_viewport().gui_get_focus_owner()
	if Input.is_action_just_pressed("menu_back"):
		if tab == Tab.MAP and focus != null:
			get_viewport().gui_release_focus()
			Sfx.play("menu_back")
		else:
			close()
		return
	if UiTheme.accept_pressed():
		if not UiTheme.press_focused(get_viewport()):
			(_bottom[2] as Button).grab_focus()
		return
	if tab == Tab.MAP and focus == null:
		var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		map.pan += v * PAN_TILES_PER_SEC * delta


func _focus_sound() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f != _last_focus and _last_focus != null and f != null and is_ancestor_of(f):
		Sfx.play("menu_move")
	_last_focus = f
