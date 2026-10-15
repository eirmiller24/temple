class_name UiControlsPanel
extends Control
## Options → Controls: one row per remappable action (Controls.ACTIONS)
## with a Pad button and a Keyboard button showing the live binding.
## Pressing one listens for the next control of that kind and binds it
## (Controls.set_binding → settings → InputMap), Esc cancels, a shared pad
## button inside a clash group is marked. "Reset to defaults" forgets
## every override. The owner (UiOptionsPanel) calls poll() each frame
## while this is visible.

signal closed

const ROW_WIDTH := 460.0
const NAME_WIDTH := 170.0
const BIND_WIDTH := 120.0
const LISTEN_SECONDS := 6.0
## Height of the scrolling action list (the whole panel must fit the pause
## menu body and the start menu page, ~330 px).
const LIST_HEIGHT := 186.0
## Frames after a capture during which menu polling is suppressed, so the
## button just bound to, say, "Menu: back" doesn't also close the menu.
const SWALLOW_FRAMES := 2

var _rows: Array = []          # [{action, pad: Button, key: Button, mark: Label}]
var _reset: Button
var _back: Button
var _hint: Label
var _status: Label
var _listening := {}           # {action, device, button, until} while capturing
var _swallow := 0


func _ready() -> void:
	theme = UiTheme.theme()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size.x = ROW_WIDTH
	add_child(box)
	box.add_child(UiTheme.label("CONTROLS", UiTheme.SIZE_HEADING, UiTheme.ACCENT))
	box.add_child(UiTheme.rule(ROW_WIDTH, UiTheme.DIM))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var h0 := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.DIM)
	h0.custom_minimum_size.x = NAME_WIDTH
	head.add_child(h0)
	var h1 := UiTheme.label("Pad", UiTheme.SIZE_SMALL, UiTheme.DIM)
	h1.custom_minimum_size.x = BIND_WIDTH
	head.add_child(h1)
	var h2 := UiTheme.label("Keyboard / mouse", UiTheme.SIZE_SMALL, UiTheme.DIM)
	h2.custom_minimum_size.x = BIND_WIDTH
	head.add_child(h2)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(ROW_WIDTH, LIST_HEIGHT)
	scroll.follow_focus = true
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.custom_minimum_size.x = ROW_WIDTH - 12
	scroll.add_child(list)
	for entry in Controls.ACTIONS:
		var action: String = entry[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		var name_label := UiTheme.label(String(entry[1]), UiTheme.SIZE_LABEL)
		name_label.custom_minimum_size.x = NAME_WIDTH
		row.add_child(name_label)
		var pad := UiTheme.button("", UiTheme.SIZE_LABEL, BIND_WIDTH)
		var key := UiTheme.button("", UiTheme.SIZE_LABEL, BIND_WIDTH)
		for b in [pad, key]:
			_compact(b)
			UiTheme.focus_on_hover(b)
			row.add_child(b)
		pad.pressed.connect(_listen.bind(action, "pad", pad))
		key.pressed.connect(_listen.bind(action, "key", key))
		pad.focus_entered.connect(_show_row_status.bind(action))
		key.focus_entered.connect(_show_row_status.bind(action))
		var mark := UiTheme.label("", UiTheme.SIZE_LABEL, Color("e07a5f"))
		row.add_child(mark)
		_rows.append({"action": action, "pad": pad, "key": key, "mark": mark})

	box.add_child(UiTheme.rule(ROW_WIDTH, UiTheme.DIM))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	box.add_child(foot)
	_reset = UiTheme.button("Reset to defaults", UiTheme.SIZE_LABEL, 170)
	_back = UiTheme.button("Back", UiTheme.SIZE_LABEL, 120)
	for b in [_reset, _back]:
		_compact(b)
		UiTheme.focus_on_hover(b)
		foot.add_child(b)
	_reset.pressed.connect(_on_reset)
	_back.pressed.connect(close)
	_status = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.ACCENT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = ROW_WIDTH
	box.add_child(_status)
	_hint = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = ROW_WIDTH
	box.add_child(_hint)

	# Focus grid: up/down walks the rows within a column, left/right hops
	# between Pad and Keyboard, the footer sits below the last row.
	var n := _rows.size()
	for i in n:
		var r: Dictionary = _rows[i]
		var up: Dictionary = _rows[(i - 1 + n) % n]
		var down: Dictionary = _rows[(i + 1) % n]
		for col in ["pad", "key"]:
			var b: Button = r[col]
			b.focus_neighbor_top = b.get_path_to(up[col] if i > 0 else _back)
			b.focus_neighbor_bottom = b.get_path_to(down[col] if i < n - 1 else (_reset if col == "pad" else _back))
			b.focus_previous = b.focus_neighbor_top
			b.focus_next = b.focus_neighbor_bottom
		(r.pad as Button).focus_neighbor_left = (r.pad as Button).get_path_to(r.key)
		(r.pad as Button).focus_neighbor_right = (r.pad as Button).get_path_to(r.key)
		(r.key as Button).focus_neighbor_left = (r.key as Button).get_path_to(r.pad)
		(r.key as Button).focus_neighbor_right = (r.key as Button).get_path_to(r.pad)
	var last: Dictionary = _rows[n - 1]
	var first: Dictionary = _rows[0]
	_reset.focus_neighbor_top = _reset.get_path_to(last.pad)
	_back.focus_neighbor_top = _back.get_path_to(last.key)
	_reset.focus_neighbor_bottom = _reset.get_path_to(first.pad)
	_back.focus_neighbor_bottom = _back.get_path_to(first.key)
	_reset.focus_neighbor_left = _reset.get_path_to(_back)
	_reset.focus_neighbor_right = _reset.get_path_to(_back)
	_back.focus_neighbor_left = _back.get_path_to(_reset)
	_back.focus_neighbor_right = _back.get_path_to(_reset)

	Controls.bindings_changed.connect(refresh)
	set_process_input(false)
	refresh()


## Tighter padding than the theme's buttons so thirteen rows fit.
static func _compact(b: Button) -> void:
	b.add_theme_stylebox_override("normal", UiTheme.panel(Color(0.09, 0.08, 0.12, 0.85), UiTheme.DIM, 2))
	b.add_theme_stylebox_override("hover", UiTheme.panel(Color(0.14, 0.13, 0.18, 0.95), UiTheme.TEXT, 2))
	b.add_theme_stylebox_override("focus", UiTheme.panel(Color(0, 0, 0, 0), UiTheme.ACCENT, 2))
	b.add_theme_stylebox_override("pressed", UiTheme.panel(UiTheme.ACCENT, UiTheme.ACCENT, 2))


func refresh() -> void:
	for r in _rows:
		var action: String = r.action
		if not _listening.is_empty() and _listening.action == action:
			continue
		(r.pad as Button).text = Controls.glyph(action, "pad")
		(r.key as Button).text = Controls.glyph(action, "key")
		(r.mark as Label).text = "!" if not Controls.conflicts(action, "pad").is_empty() else ""
	_hint.text = Controls.hint([["menu_accept", "rebind"], ["menu_back", "back"]]) \
			+ "    Esc cancels a capture.  Two actions on one button are marked."


## The status line explains a clash mark while its row is focused.
func _show_row_status(action: String) -> void:
	if not _listening.is_empty():
		return
	var clash := Controls.conflicts(action, "pad")
	if clash.is_empty():
		_status.text = ""
		return
	_status.text = "%s shares %s with %s." % [Controls.display_name(action), Controls.glyph(action, "pad"),
			", ".join(clash.map(func(a: String) -> String: return Controls.display_name(a)))]


func focus_first() -> void:
	if not _rows.is_empty():
		(_rows[0].pad as Button).grab_focus()


# --- capture ---------------------------------------------------------------------------------------------

func _listen(action: String, device: String, button: Button) -> void:
	if not _listening.is_empty():
		return
	_listening = {"action": action, "device": device, "button": button,
			"until": Time.get_ticks_msec() + int(LISTEN_SECONDS * 1000.0)}
	button.text = "press…"
	_status.text = ("Press a pad button or trigger for %s" if device == "pad" else "Press a key or mouse button for %s") \
			% Controls.display_name(action) + "   (Esc cancels)"
	Sfx.play("menu_accept")
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if _listening.is_empty():
		return
	var device: String = _listening.device
	var captured: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if code == KEY_ESCAPE:
			_cancel()
			get_viewport().set_input_as_handled()
			return
		if device == "key":
			captured = event
	elif event is InputEventMouseButton and event.pressed and device == "key":
		captured = event
	elif event is InputEventJoypadButton and event.pressed and device == "pad":
		captured = event
	elif event is InputEventJoypadMotion and device == "pad" and absf(event.axis_value) > 0.6 \
			and (event.axis == JOY_AXIS_TRIGGER_LEFT or event.axis == JOY_AXIS_TRIGGER_RIGHT):
		captured = event
	if captured == null:
		return
	get_viewport().set_input_as_handled()
	var action: String = _listening.action
	if Controls.set_binding(action, device, captured):
		Sfx.play("item_equip")
		_status.text = "%s → %s" % [Controls.display_name(action), Controls.event_name(captured)]
	else:
		Sfx.play("menu_error")
		_status.text = "That can't be bound (sticks and the left mouse button are fixed)."
	var btn: Button = _listening.button
	_listening = {}
	set_process_input(false)
	_swallow = SWALLOW_FRAMES
	refresh()
	btn.grab_focus()


func _cancel() -> void:
	if _listening.is_empty():
		return
	var btn: Button = _listening.button
	_listening = {}
	set_process_input(false)
	_swallow = SWALLOW_FRAMES
	Sfx.play("menu_back")
	refresh()
	btn.grab_focus()


func _on_reset() -> void:
	Controls.reset_all()
	Sfx.play("menu_accept")
	_status.text = "Defaults restored."


func close() -> void:
	_cancel()
	Sfx.play("menu_back")
	closed.emit()


## Called by the owner each frame while visible. Returns true when the
## frame's input belongs here (always, while this panel is up).
func poll() -> bool:
	if not visible:
		return false
	if not _listening.is_empty():
		if Time.get_ticks_msec() > int(_listening.until):
			_cancel()
		return true
	if _swallow > 0:
		_swallow -= 1
		return true
	if Input.is_action_just_pressed("menu_back"):
		close()
		return true
	if UiTheme.accept_pressed():
		UiTheme.press_focused(get_viewport())
		return true
	return true
