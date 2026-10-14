extends Control
## The title card: name, subtitle, a pulsing "press any button" and the
## credits line. Any menu_accept / pause / ui_accept press or a mouse click
## emits `started`; Main then swaps in the start menu. Plays no music (Main
## already started the "title" track).

signal started

const PULSE_SPEED := 2.4
const SUBTITLE := "a descent through the temple of a snake god"
const CREDITS := "Knight sprite by @Jump_Button · Seasonal Sprite Worlds tiles by Szadi art · music by Tallbeard Studios (Abstraction)"

var _prompt: Label
var _time := 0.0
var _done := false


func _ready() -> void:
	theme = UiTheme.theme()
	UiTheme.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.fill(bg)
	add_child(bg)

	_wide(UiTheme.rule(420), 168, 1, 420)
	var title := UiTheme.label("THE TEMPLE OF RHYS", UiTheme.SIZE_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wide(title, 186, 40)
	var sub := UiTheme.label(SUBTITLE, UiTheme.SIZE_LABEL, UiTheme.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wide(sub, 230, 20)
	_wide(UiTheme.rule(420), 262, 1, 420)

	_prompt = UiTheme.label("press any button", UiTheme.SIZE_BODY, UiTheme.ACCENT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wide(_prompt, 356, 24)

	var credits := UiTheme.label(CREDITS, UiTheme.SIZE_SMALL, UiTheme.DIM)
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wide(credits, 512, 18)


## Place `c` across the full width (or `width` px centred) at `y`.
func _wide(c: Control, y: float, h: float, width: float = 0.0) -> void:
	add_child(c)
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	var inset := 0.0 if width <= 0.0 else (UiTheme.VIEW.x - width) / 2.0
	c.offset_left = inset
	c.offset_right = -inset
	c.offset_top = y
	c.offset_bottom = y + h


func _process(delta: float) -> void:
	_time += delta
	_prompt.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_time * PULSE_SPEED))
	if _done or _time < UiTheme.ARM_DELAY:
		return
	if Input.is_action_just_pressed("menu_accept") or Input.is_action_just_pressed("pause") \
			or Input.is_action_just_pressed("ui_accept"):
		_start()


func _gui_input(event: InputEvent) -> void:
	if _done or _time < UiTheme.ARM_DELAY:
		return
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		_start()


func _start() -> void:
	_done = true
	Sfx.play("menu_accept")
	started.emit()
