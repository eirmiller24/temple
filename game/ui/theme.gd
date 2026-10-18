class_name UiTheme
extends RefCounted
## The shared look of every screen: the temple palette, the font sizes and
## the StyleBoxFlat builders. Colours and sizes are presentation, not
## tunables, so they live here as consts rather than in data/. Everything
## is drawn with Godot's default font; the viewport is 960x540.

const BG := Color("0c0a10")
const PANEL := Color(0.07, 0.06, 0.09, 0.92)
const PANEL_THIN := Color(0.05, 0.04, 0.07, 0.6)
const TEXT := Color("e8dcc0")
const ACCENT := Color("9fd36a")
const DIM := Color("6a6480")
const HEART := Color("c8453c")
const DIM_OVERLAY := Color(0.047, 0.039, 0.063, 0.78)

const SIZE_TITLE := 28
const SIZE_HEADING := 20
const SIZE_BODY := 16
const SIZE_LABEL := 14
const SIZE_SMALL := 12
const VIEW := Vector2(960, 540)

## Delay before a freshly shown screen reacts to menu actions, so the press
## that opened it cannot also drive it.
const ARM_DELAY := 0.2

static var _theme: Theme


## A flat panel with a 1px border.
static func panel(bg: Color = PANEL, border: Color = DIM, margin: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_content_margin_all(margin)
	return sb


static func empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


## An item slot's frame (UiItemCell): `state` is normal, hover, focus,
## equipped or empty. Focus draws a 2px accent ring outside the cell so the
## icon never shifts.
static func cell(state: String) -> StyleBoxFlat:
	var sb: StyleBoxFlat
	match state:
		"hover":
			sb = panel(Color(0.12, 0.11, 0.16, 0.95), TEXT, 0)
		"focus":
			sb = panel(Color(ACCENT, 0.10), ACCENT, 0)
			sb.set_border_width_all(2)
			sb.set_expand_margin_all(2)
		"equipped":
			sb = panel(Color(ACCENT, 0.16), Color(ACCENT, 0.7), 0)
		"empty":
			sb = panel(Color(0.04, 0.035, 0.055, 0.6), Color(DIM, 0.35), 0)
		_:
			sb = panel(Color(0.08, 0.07, 0.11, 0.92), DIM, 0)
	sb.set_corner_radius_all(3)
	return sb


## A section title: small accent caps and a hairline running to `width`.
static func section_header(text: String, width: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.x = width
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label(text, SIZE_SMALL, ACCENT))
	var r := rule(0, Color(DIM, 0.6))
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(r)
	return row


## Label outline for text drawn over art (counts, button badges).
static func outline(l: Label, px: int = 4) -> Label:
	l.add_theme_constant_override("outline_size", px)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	return l


## One Theme for the whole UI layer: buttons, sliders, line edits.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = SIZE_BODY
	# Buttons: bordered, accent border when focused, filled when pressed.
	var normal := panel(Color(0.09, 0.08, 0.12, 0.85), DIM, 6)
	var hover := panel(Color(0.14, 0.13, 0.18, 0.95), TEXT, 6)
	var focus := panel(Color(0, 0, 0, 0), ACCENT, 6)
	var pressed := panel(ACCENT, ACCENT, 6)
	var disabled := panel(Color(0.07, 0.06, 0.09, 0.6), Color(DIM, 0.4), 6)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", BG)
	t.set_color("font_disabled_color", "Button", Color(DIM, 0.6))
	t.set_font_size("font_size", "Button", SIZE_BODY)
	# Labels.
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", SIZE_BODY)
	# Sliders.
	t.set_stylebox("slider", "HSlider", panel(Color(0.12, 0.11, 0.16), DIM, 0))
	t.set_stylebox("grabber_area", "HSlider", panel(Color(ACCENT, 0.55), Color(ACCENT, 0.55), 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", panel(ACCENT, ACCENT, 0))
	var knob := _dot_texture(10, TEXT)
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", _dot_texture(10, ACCENT))
	t.set_icon("grabber_disabled", "HSlider", _dot_texture(10, DIM))
	# Line edits (tuning panel).
	t.set_stylebox("normal", "LineEdit", panel(Color(0.05, 0.04, 0.07), DIM, 3))
	t.set_stylebox("focus", "LineEdit", panel(Color(0.05, 0.04, 0.07), ACCENT, 3))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_font_size("font_size", "LineEdit", SIZE_SMALL)
	t.set_stylebox("panel", "PanelContainer", panel())
	_theme = t
	return t


static func _dot_texture(d: int, color: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d / 2.0, d / 2.0)
	for y in d:
		for x in d:
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= d / 2.0:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


static func label(text: String, size: int = SIZE_BODY, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, size: int = SIZE_BODY, min_width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_ALL
	if min_width > 0.0:
		b.custom_minimum_size.x = min_width
	return b


## A 1px horizontal rule.
static func rule(width: float, color: Color = ACCENT) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(width, 1)
	r.size = Vector2(width, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func fill(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Vertical focus chain (ui_up/ui_down and Tab) through `controls`, with
## left/right pinned to self so a row never loses focus sideways.
static func chain_focus(controls: Array, wrap: bool = true) -> void:
	var n := controls.size()
	for i in n:
		var c: Control = controls[i]
		var prev: Control = controls[(i - 1 + n) % n] if (wrap or i > 0) else c
		var next: Control = controls[(i + 1) % n] if (wrap or i < n - 1) else c
		c.focus_neighbor_top = c.get_path_to(prev)
		c.focus_neighbor_bottom = c.get_path_to(next)
		c.focus_previous = c.get_path_to(prev)
		c.focus_next = c.get_path_to(next)
		c.focus_neighbor_left = NodePath(".")
		c.focus_neighbor_right = NodePath(".")


## Horizontal focus chain (ui_left/ui_right) through `controls`.
static func chain_focus_row(controls: Array) -> void:
	var n := controls.size()
	for i in n:
		var c: Control = controls[i]
		c.focus_neighbor_left = c.get_path_to(controls[(i - 1 + n) % n])
		c.focus_neighbor_right = c.get_path_to(controls[(i + 1) % n])


## Mouse hover moves keyboard/gamepad focus too, so the three input kinds
## always agree on the highlighted row. Skips controls that cannot focus.
static func focus_on_hover(c: Control) -> void:
	c.mouse_entered.connect(func() -> void:
		if c.focus_mode != Control.FOCUS_NONE and not (c is BaseButton and c.disabled):
			c.grab_focus())


## True when `menu_accept` was pressed this frame by something the focused
## Button will not already handle itself (ui_accept fires BaseButton).
static func accept_pressed() -> bool:
	return Input.is_action_just_pressed("menu_accept") and not Input.is_action_just_pressed("ui_accept")


## Press the focused Button, if any, as a menu_accept would.
static func press_focused(viewport: Viewport) -> bool:
	var f := viewport.gui_get_focus_owner()
	if f is BaseButton and not f.disabled:
		f.pressed.emit()
		return true
	return false
