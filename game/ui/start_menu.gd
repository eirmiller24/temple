extends Control
## The start menu: New Game, Continue, Options, Quit. New Game opens the
## three-slot picker (an occupied slot asks before overwriting) and emits
## new_game(slot); Continue lists the occupied slots and emits load_slot
## (disabled when there are none); Options shows UiOptionsPanel; Quit quits.
## menu_back at the top level emits `back` (Main returns to the title).
##
## Lists are Buttons driven by Godot focus (ui_up/down, ui_accept, mouse,
## d-pad); menu_accept presses the focused button for the keys/buttons that
## are not ui_accept.

signal new_game(slot: int)
signal load_slot(slot: int)
signal back

enum Page { MAIN, SLOTS_NEW, SLOTS_LOAD, CONFIRM, OPTIONS }

const LIST_X := 120.0
const LIST_Y := 170.0
const SLOT_WIDTH := 560.0

var _page: int = Page.MAIN
var _pages := {}
var _main_buttons: Array = []
var _slot_buttons: Array = []
var _continue_btn: Button
var _slots_title: Label
var _confirm_label: Label
var _confirm_yes: Button
var _confirm_no: Button
var _options: UiOptionsPanel
var _hint: Label
var _pending_slot := -1
var _time := 0.0
var _last_focus: Control
var _main_focus: Button


func _ready() -> void:
	theme = UiTheme.theme()
	UiTheme.fill(self)
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.fill(bg)
	add_child(bg)
	var title := UiTheme.label("THE TEMPLE OF RHYS", UiTheme.SIZE_HEADING, UiTheme.DIM)
	title.position = Vector2(LIST_X, 96)
	add_child(title)
	var r := UiTheme.rule(SLOT_WIDTH, UiTheme.DIM)
	r.position = Vector2(LIST_X, 130)
	add_child(r)
	_hint = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.DIM)
	_hint.position = Vector2(LIST_X, 500)
	add_child(_hint)
	_build_main()
	_build_slots()
	_build_confirm()
	_build_options()
	_show(Page.MAIN)


func _page_box(page: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.position = Vector2(LIST_X, LIST_Y)
	add_child(box)
	_pages[page] = box
	return box


func _build_main() -> void:
	var box := _page_box(Page.MAIN)
	var new_btn := UiTheme.button("New Game", UiTheme.SIZE_BODY, 260)
	_continue_btn = UiTheme.button("Continue", UiTheme.SIZE_BODY, 260)
	var options_btn := UiTheme.button("Options", UiTheme.SIZE_BODY, 260)
	var quit_btn := UiTheme.button("Quit", UiTheme.SIZE_BODY, 260)
	for b in [new_btn, _continue_btn, options_btn, quit_btn]:
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiTheme.focus_on_hover(b)
		box.add_child(b)
	new_btn.pressed.connect(func() -> void: _show(Page.SLOTS_NEW))
	_continue_btn.pressed.connect(func() -> void: _show(Page.SLOTS_LOAD))
	options_btn.pressed.connect(func() -> void: _show(Page.OPTIONS))
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	_main_buttons = [new_btn, _continue_btn, options_btn, quit_btn]
	for b: Button in _main_buttons:
		b.focus_entered.connect(func() -> void: _main_focus = b)


func _build_slots() -> void:
	var box := _page_box(Page.SLOTS_NEW)
	_pages[Page.SLOTS_LOAD] = box
	_slots_title = UiTheme.label("", UiTheme.SIZE_LABEL, UiTheme.ACCENT)
	box.add_child(_slots_title)
	for i in SaveManager.SLOTS:
		var b := UiTheme.button("", UiTheme.SIZE_BODY, SLOT_WIDTH)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiTheme.focus_on_hover(b)
		b.pressed.connect(_on_slot.bind(i))
		box.add_child(b)
		_slot_buttons.append(b)


func _build_confirm() -> void:
	var box := _page_box(Page.CONFIRM)
	_confirm_label = UiTheme.label("", UiTheme.SIZE_BODY)
	box.add_child(_confirm_label)
	box.add_child(UiTheme.label("This save will be lost.", UiTheme.SIZE_LABEL, UiTheme.DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_confirm_yes = UiTheme.button("Overwrite", UiTheme.SIZE_BODY, 140)
	_confirm_no = UiTheme.button("Keep it", UiTheme.SIZE_BODY, 140)
	row.add_child(_confirm_no)
	row.add_child(_confirm_yes)
	_confirm_yes.pressed.connect(func() -> void:
		Sfx.play("menu_accept")
		_choose_new(_pending_slot))
	_confirm_no.pressed.connect(func() -> void:
		Sfx.play("menu_back")
		_show(Page.SLOTS_NEW))
	UiTheme.chain_focus_row([_confirm_no, _confirm_yes])


func _build_options() -> void:
	_options = UiOptionsPanel.new()
	_options.position = Vector2(LIST_X, LIST_Y)
	add_child(_options)
	_pages[Page.OPTIONS] = _options
	_options.closed.connect(func() -> void: _show(Page.MAIN))


# --- pages ------------------------------------------------------------------------------------

func _show(page: int) -> void:
	_page = page
	for p in _pages.values():
		p.visible = false
	_pages[page].visible = true
	match page:
		Page.MAIN:
			_refresh_main()
			_hint.text = "up/down move   " + Controls.hint([["menu_accept", "select"], ["menu_back", "back to title"]])
		Page.SLOTS_NEW, Page.SLOTS_LOAD:
			_refresh_slots(page == Page.SLOTS_LOAD)
			_hint.text = "up/down move   " + Controls.hint([["menu_accept", "choose"], ["menu_back", "back"]])
		Page.CONFIRM:
			_confirm_label.text = "Overwrite slot %d?" % (_pending_slot + 1)
			_confirm_no.grab_focus()
			_hint.text = "left/right move   " + Controls.hint([["menu_accept", "confirm"], ["menu_back", "back"]])
		Page.OPTIONS:
			_options.refresh()
			_options.focus_first()
			_hint.text = ""


func _refresh_main() -> void:
	var any := false
	for i in SaveManager.SLOTS:
		any = any or SaveManager.slot_exists(i)
	_continue_btn.disabled = not any
	_continue_btn.text = "Continue" if any else "Continue  (no saves)"
	_continue_btn.focus_mode = Control.FOCUS_ALL if any else Control.FOCUS_NONE
	var chain := _main_buttons.filter(func(b: Button) -> bool: return not b.disabled)
	UiTheme.chain_focus(chain)
	if _main_focus != null and chain.has(_main_focus):
		_main_focus.grab_focus()
	else:
		chain[0].grab_focus()


func _refresh_slots(load_only: bool) -> void:
	_slots_title.text = "CONTINUE — choose a save" if load_only else "NEW GAME — choose a slot"
	var chain: Array = []
	for i in SaveManager.SLOTS:
		var b: Button = _slot_buttons[i]
		var info := SaveManager.slot_info(i)
		if bool(info.exists):
			b.text = "%d    %s    %s    %s" % [i + 1, _room_name(String(info.room)),
					SaveManager.format_playtime(float(info.playtime)), String(info.saved_at).replace("T", "  ")]
			b.disabled = false
		else:
			b.text = "%d    — Empty —" % (i + 1)
			b.disabled = load_only
		b.focus_mode = Control.FOCUS_NONE if b.disabled else Control.FOCUS_ALL
		if not b.disabled:
			chain.append(b)
	if chain.is_empty():
		_show(Page.MAIN)
		return
	UiTheme.chain_focus(chain)
	chain[0].grab_focus()


func _room_name(room: String) -> String:
	var info := RoomRegistry.info(room)
	return String(info.get("display_name", room)) if not info.is_empty() else room


func _on_slot(slot: int) -> void:
	Sfx.play("menu_accept")
	if _page == Page.SLOTS_LOAD:
		load_slot.emit(slot)
	elif SaveManager.slot_exists(slot):
		_pending_slot = slot
		_show(Page.CONFIRM)
	else:
		_choose_new(slot)


func _choose_new(slot: int) -> void:
	new_game.emit(slot)


# --- input ----------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	var f := get_viewport().gui_get_focus_owner()
	if f != _last_focus and _last_focus != null and f != null and is_ancestor_of(f):
		Sfx.play("menu_move")
	_last_focus = f
	if _time < UiTheme.ARM_DELAY:
		return
	if _page == Page.OPTIONS:
		_options.poll()
		return
	if Input.is_action_just_pressed("menu_back"):
		Sfx.play("menu_back")
		if _page == Page.MAIN:
			back.emit()
		elif _page == Page.CONFIRM:
			_show(Page.SLOTS_NEW)
		else:
			_show(Page.MAIN)
		return
	if UiTheme.accept_pressed():
		UiTheme.press_focused(get_viewport())
