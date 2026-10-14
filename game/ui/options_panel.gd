class_name UiOptionsPanel
extends Control
## The options rows, shared by the start menu and the pause menu: music and
## SFX volume sliders, fullscreen and "hold X/Y to assign" toggles, Back.
## Every change goes straight through SaveManager.set_setting (applied and
## written at once). The owner calls poll() each frame while the panel is
## visible so menu_back is handled in one place.

signal closed

const ROW_WIDTH := 460.0

var _music: HSlider
var _sfx: HSlider
var _music_value: Label
var _sfx_value: Label
var _fullscreen: Button
var _hold: Button
var _back: Button
var _rows: Array = []


func _ready() -> void:
	theme = UiTheme.theme()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size.x = ROW_WIDTH
	add_child(box)
	box.add_child(UiTheme.label("OPTIONS", UiTheme.SIZE_HEADING, UiTheme.ACCENT))
	box.add_child(UiTheme.rule(ROW_WIDTH, UiTheme.DIM))

	_music = _slider_row(box, "Music volume")
	_music_value = _music.get_meta("value_label")
	_sfx = _slider_row(box, "SFX volume")
	_sfx_value = _sfx.get_meta("value_label")
	_fullscreen = UiTheme.button("", UiTheme.SIZE_BODY, ROW_WIDTH)
	_fullscreen.alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_fullscreen)
	_hold = UiTheme.button("", UiTheme.SIZE_BODY, ROW_WIDTH)
	_hold.alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_hold)
	box.add_child(UiTheme.label("Hold: in the item menu, holding X or Y for a moment assigns the item.",
			UiTheme.SIZE_SMALL, UiTheme.DIM))
	_back = UiTheme.button("Back", UiTheme.SIZE_BODY, 120)
	box.add_child(_back)
	box.add_child(UiTheme.label("left/right adjust   A toggle   B back", UiTheme.SIZE_SMALL, UiTheme.DIM))

	_rows = [_music, _sfx, _fullscreen, _hold, _back]
	UiTheme.chain_focus(_rows)
	_music.focus_neighbor_left = NodePath("")
	_music.focus_neighbor_right = NodePath("")
	_sfx.focus_neighbor_left = NodePath("")
	_sfx.focus_neighbor_right = NodePath("")

	_music.value_changed.connect(func(v: float) -> void: _apply("music_volume", v / 100.0))
	_sfx.value_changed.connect(func(v: float) -> void: _apply("sfx_volume", v / 100.0))
	_fullscreen.pressed.connect(func() -> void: _toggle("fullscreen"))
	_hold.pressed.connect(func() -> void: _toggle("hold_to_assign"))
	_back.pressed.connect(close)
	for r in _rows:
		UiTheme.focus_on_hover(r)
	refresh()


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
	_fullscreen.text = "Fullscreen:  %s" % ("On" if bool(s.fullscreen) else "Off")
	_hold.text = "Hold X/Y to assign item:  %s" % ("On" if bool(s.hold_to_assign) else "Off")


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


func close() -> void:
	Sfx.play("menu_back")
	closed.emit()


## Called by the owner each frame while visible. Returns true when the
## frame's input was consumed here.
func poll() -> bool:
	if not visible:
		return false
	if Input.is_action_just_pressed("menu_back"):
		close()
		return true
	if UiTheme.accept_pressed():
		return UiTheme.press_focused(get_viewport())
	return false
