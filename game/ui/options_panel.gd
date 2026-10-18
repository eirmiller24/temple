class_name UiOptionsPanel
extends Control
## The options rows, shared by the start menu and the pause menu: music and
## SFX volume sliders, the fullscreen / "hold to assign" / "aiming swaps
## sticks" toggles, a Controls… button (UiControlsPanel, button remapping)
## and Back. Every change goes straight through SaveManager.set_setting
## (applied and written at once). The owner calls poll() each frame while
## the panel is visible so menu_back is handled in one place.

signal closed

const ROW_WIDTH := 460.0

var _box: VBoxContainer
var _music: HSlider
var _sfx: HSlider
var _music_value: Label
var _sfx_value: Label
var _fullscreen: Button
var _swap: Button
var _swap_help: Label
var _controls_btn: Button
var _back: Button
var _hint: Label
var _rows: Array = []
var _controls: UiControlsPanel


func _ready() -> void:
	theme = UiTheme.theme()
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	_box.custom_minimum_size.x = ROW_WIDTH
	add_child(_box)
	_box.add_child(UiTheme.label("OPTIONS", UiTheme.SIZE_HEADING, UiTheme.ACCENT))
	_box.add_child(UiTheme.rule(ROW_WIDTH, UiTheme.DIM))

	_music = _slider_row(_box, "Music volume")
	_music_value = _music.get_meta("value_label")
	_sfx = _slider_row(_box, "SFX volume")
	_sfx_value = _sfx.get_meta("value_label")
	_fullscreen = _toggle_row("")
	_swap = _toggle_row("")
	_swap_help = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.DIM)
	_box.add_child(_swap_help)
	_controls_btn = UiTheme.button("Controls…", UiTheme.SIZE_BODY, ROW_WIDTH)
	_controls_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_box.add_child(_controls_btn)
	_back = UiTheme.button("Back", UiTheme.SIZE_BODY, 120)
	_box.add_child(_back)
	_hint = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.DIM)
	_box.add_child(_hint)

	_rows = [_music, _sfx, _fullscreen, _swap, _controls_btn, _back]
	UiTheme.chain_focus(_rows)
	_music.focus_neighbor_left = NodePath("")
	_music.focus_neighbor_right = NodePath("")
	_sfx.focus_neighbor_left = NodePath("")
	_sfx.focus_neighbor_right = NodePath("")

	_music.value_changed.connect(func(v: float) -> void: _apply("music_volume", v / 100.0))
	_sfx.value_changed.connect(func(v: float) -> void: _apply("sfx_volume", v / 100.0))
	_fullscreen.pressed.connect(func() -> void: _toggle("fullscreen"))
	_swap.pressed.connect(func() -> void: _toggle("aim_swap_sticks"))
	_controls_btn.pressed.connect(_open_controls)
	_back.pressed.connect(close)
	for r in _rows:
		UiTheme.focus_on_hover(r)

	_controls = UiControlsPanel.new()
	_controls.visible = false
	add_child(_controls)
	_controls.closed.connect(_close_controls)
	Controls.bindings_changed.connect(refresh)
	refresh()


func _toggle_row(text: String) -> Button:
	var b := UiTheme.button(text, UiTheme.SIZE_BODY, ROW_WIDTH)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_box.add_child(b)
	return b


func _slider_row(parent: Control, title: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var name_label := UiTheme.label(title, UiTheme.SIZE_BODY)
	name_label.custom_minimum_size.x = 170
	row.add_child(name_label)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.custom_minimum_size = Vector2(220, 22)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	row.add_child(s)
	var value := UiTheme.label("0%", UiTheme.SIZE_BODY, UiTheme.ACCENT)
	value.custom_minimum_size.x = 48
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	s.set_meta("value_label", value)
	return s


## Re-read SaveManager.settings into the widgets (silently).
func refresh() -> void:
	var s := SaveManager.settings
	_music.set_value_no_signal(roundf(float(s.music_volume) * 100.0))
	_sfx.set_value_no_signal(roundf(float(s.sfx_volume) * 100.0))
	_music_value.text = "%d%%" % int(_music.value)
	_sfx_value.text = "%d%%" % int(_sfx.value)
	_fullscreen.text = "Fullscreen:  %s" % _onoff(s.fullscreen)
	_swap.text = "Aiming (%s) swaps sticks:  %s" % [Controls.glyph("aim", "pad"), _onoff(s.aim_swap_sticks)]
	_swap_help.text = "On: left stick aims, right stick moves.   Off: left stick moves, right stick aims (claw grip)."
	_hint.text = "left/right adjust   " + Controls.hint([["menu_accept", "toggle"], ["menu_back", "back"]])


static func _onoff(v: Variant) -> String:
	return "On" if bool(v) else "Off"


func focus_first() -> void:
	_music.grab_focus()


func _apply(key: String, value: Variant) -> void:
	SaveManager.set_setting(key, value)
	Sfx.play("menu_move")
	refresh()


func _toggle(key: String) -> void:
	SaveManager.set_setting(key, not bool(SaveManager.settings[key]))
	Sfx.play("menu_accept")
	refresh()


func _open_controls() -> void:
	_box.visible = false
	_controls.visible = true
	_controls.refresh()
	_controls.focus_first()
	Sfx.play("menu_accept")


func _close_controls() -> void:
	_controls.visible = false
	_box.visible = true
	refresh()
	_controls_btn.grab_focus()


func close() -> void:
	if _controls.visible:
		_close_controls()
	Sfx.play("menu_back")
	closed.emit()


## Called by the owner each frame while visible. Returns true when the
## frame's input was consumed here.
func poll() -> bool:
	if not visible:
		return false
	if _controls.visible:
		return _controls.poll()
	if Input.is_action_just_pressed("menu_back"):
		close()
		return true
	if UiTheme.accept_pressed():
		return UiTheme.press_focused(get_viewport())
	return false
