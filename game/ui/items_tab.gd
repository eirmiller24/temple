class_name UiItemsTab
extends Control
## The pause menu's ITEMS tab (design_v2 §7.2): the inventory as a focusable
## list, a detail panel for the highlighted item, a status line and the
## verb hint. Verbs (UiItemVerbs): accept selects, the attack button uses,
## item 2's button drops, interact assigns → the next item-button press
## picks the slot. Button names in the UI are the live bindings (Controls). Items with "hide_use" never list the Use
## verb but menu_use still works on them (the Fang trick, §9.2). With
## SaveManager.settings.hold_to_assign, holding an item button on an item
## for HOLD_MS assigns it (a tap of item 2's button still drops). The owner calls poll() every frame the
## tab is active.

signal rebuilt

const HOLD_MS := 350
const KIND_ORDER := ["weapon", "tool", "consumable", "key", "passive"]
const LIST_WIDTH := 300.0

var world: World
var _list: VBoxContainer
var _rows: Array = []
var _ids: Array = []
var _index := 0
var _name: Label
var _kind: Label
var _desc: Label
var _status: Label
var _hint: Label
var _empty: Label
var _assigning := false
var _hold := {"x": -1, "y": -1}


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size = Vector2(LIST_WIDTH, size.y - 28)
	scroll.follow_focus = true
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.custom_minimum_size.x = LIST_WIDTH - 12
	scroll.add_child(_list)
	_empty = UiTheme.label("Nothing carried.", UiTheme.SIZE_BODY, UiTheme.DIM)
	_empty.position = Vector2(8, 8)
	add_child(_empty)

	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	detail.position = Vector2(LIST_WIDTH + 24, 0)
	detail.size = Vector2(size.x - LIST_WIDTH - 24, size.y - 28)
	add_child(detail)
	_name = UiTheme.label("", UiTheme.SIZE_HEADING)
	detail.add_child(_name)
	_kind = UiTheme.label("", UiTheme.SIZE_LABEL, UiTheme.DIM)
	detail.add_child(_kind)
	detail.add_child(UiTheme.rule(detail.size.x, UiTheme.DIM))
	_desc = UiTheme.label("", UiTheme.SIZE_LABEL)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size.x = detail.size.x
	detail.add_child(_desc)
	_status = UiTheme.label("", UiTheme.SIZE_LABEL, UiTheme.ACCENT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = detail.size.x
	detail.add_child(_status)

	_hint = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.DIM)
	_hint.position = Vector2(0, size.y - 20)
	add_child(_hint)
	GameState.inventory_changed.connect(refresh)
	GameState.slots_changed.connect(refresh)
	Controls.bindings_changed.connect(refresh)
	refresh()


func bind(w: World) -> void:
	world = w


# --- list ----------------------------------------------------------------------------------------

func _sorted_ids() -> Array:
	var ids := GameState.inventory.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ka := KIND_ORDER.find(String(GameState.item_def(a).get("kind", "")))
		var kb := KIND_ORDER.find(String(GameState.item_def(b).get("kind", "")))
		if ka != kb:
			return ka < kb
		return String(GameState.item_def(a).get("name", a)) < String(GameState.item_def(b).get("name", b)))
	return ids


func refresh() -> void:
	var had_focus := list_has_focus()
	for r in _rows:
		_list.remove_child(r)
		r.queue_free()
	_rows.clear()
	_ids = _sorted_ids()
	for id: String in _ids:
		var b := _row(id)
		_list.add_child(b)
		_rows.append(b)
	_empty.visible = _ids.is_empty()
	if _ids.is_empty():
		_index = 0
		_assigning = false
	else:
		_index = clampi(_index, 0, _ids.size() - 1)
		UiTheme.chain_focus(_rows, false)
	if had_focus or (not _ids.is_empty() and get_viewport().gui_get_focus_owner() == null and is_visible_in_tree()):
		focus_list()
	_show_details()
	rebuilt.emit()


func _row(id: String) -> Button:
	var def := GameState.item_def(id)
	var text := String(def.get("name", id))
	var n := GameState.count(id)
	if n > 1:
		text += "  ×%d" % n
	var b := UiTheme.button(text, UiTheme.SIZE_BODY, LIST_WIDTH - 12)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var mark := _mark(id)
	if mark != "":
		var m := UiTheme.label(mark, UiTheme.SIZE_LABEL, UiTheme.ACCENT)
		m.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		m.offset_left = -24
		m.offset_right = -8
		m.offset_top = -9
		m.offset_bottom = 9
		b.add_child(m)
	b.focus_entered.connect(func() -> void: _on_row_focus(id))
	UiTheme.focus_on_hover(b)
	b.pressed.connect(func() -> void: _select(id))
	return b


## The live glyph of the button an item sits on — the weapon's attack
## button, an item slot's button — else "".
static func _mark(id: String) -> String:
	var action := _mark_action(id)
	return Controls.glyph(action) if action != "" else ""


static func _mark_action(id: String) -> String:
	if GameState.weapon == id:
		return "attack"
	if GameState.slot_x == id:
		return "item_x"
	if GameState.slot_y == id:
		return "item_y"
	return ""


func _on_row_focus(id: String) -> void:
	var i := _ids.find(id)
	if i >= 0:
		_index = i
	if _assigning:
		_cancel_assign()
	_show_details()


func focus_list() -> void:
	if _rows.is_empty():
		return
	_index = clampi(_index, 0, _rows.size() - 1)
	(_rows[_index] as Button).grab_focus()


## Test/driver hook: highlight row `i` as if focus moved there.
func highlight(i: int) -> void:
	if _rows.is_empty():
		return
	_index = clampi(i, 0, _rows.size() - 1)
	focus_list()


func highlighted_id() -> String:
	return "" if _ids.is_empty() else String(_ids[_index])


func list_has_focus() -> bool:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return f != null and _rows.has(f)


func first_row() -> Control:
	return null if _rows.is_empty() else _rows[0]


func last_row() -> Control:
	return null if _rows.is_empty() else _rows[_rows.size() - 1]


func is_assigning() -> bool:
	return _assigning


func verb_hint(id: String) -> String:
	return UiItemVerbs.verb_hint(id)


# --- details ----------------------------------------------------------------------------------------

func _show_details() -> void:
	var id := highlighted_id()
	if id == "":
		_name.text = ""
		_kind.text = ""
		_desc.text = ""
		_hint.text = Controls.hint([["menu_back", "back"]])
		return
	var def := GameState.item_def(id)
	_name.text = String(def.get("name", id))
	var where := ""
	match _mark_action(id):
		"attack": where = "  ·  equipped on " + Controls.glyph("attack")
		"item_x", "item_y": where = "  ·  on " + _mark(id)
	var n := GameState.count(id)
	_kind.text = String(def.get("kind", "")) + ("  ·  ×%d" % n if n > 1 else "") + where
	_desc.text = String(def.get("description", ""))
	_hint.text = UiItemVerbs.verb_hint(id)


func _say(text: String) -> void:
	_status.text = text


# --- verbs ------------------------------------------------------------------------------------------

func _select(id: String) -> void:
	_index = maxi(_ids.find(id), 0)
	Sfx.play("menu_accept")
	_show_details()
	_say("")


func _begin_assign(id: String) -> void:
	var name := String(GameState.item_def(id).get("name", id))
	if not UiItemVerbs.assignable(id):
		Sfx.play("menu_error")
		_say("%s can't go in a slot." % name)
		return
	_assigning = true
	Sfx.play("menu_accept")
	_say("Assign %s to:  %s  or  %s    (%s cancels)" % [name, Controls.glyph("item_x"), Controls.glyph("item_y"),
			Controls.glyph("menu_back")])


func _cancel_assign() -> void:
	_assigning = false
	_say("")


func _assign(slot: String, id: String) -> void:
	_assigning = false
	_say(UiItemVerbs.assign(slot, id))


# --- per-frame input --------------------------------------------------------------------------------

## Returns true when this frame's menu_use / menu_back / menu_assign press
## belonged to the list (so the owner must not treat it as back / tab).
func poll() -> bool:
	var id := highlighted_id()
	if _assigning:
		if Input.is_action_just_pressed("menu_slot_x"):
			_assign("x", id)
		elif Input.is_action_just_pressed("menu_slot_y"):
			_assign("y", id)
		elif Input.is_action_just_pressed("menu_back") or Input.is_action_just_pressed("menu_assign"):
			Sfx.play("menu_back")
			_cancel_assign()
		return true
	if id == "" or not list_has_focus():
		_hold.x = -1
		_hold.y = -1
		return false
	if UiTheme.accept_pressed():
		UiTheme.press_focused(get_viewport())
		return true
	if Input.is_action_just_pressed("menu_use"):
		_say(UiItemVerbs.use(world, id))
		return true
	if Input.is_action_just_pressed("menu_assign"):
		_begin_assign(id)
		return true
	if bool(SaveManager.settings.get("hold_to_assign", false)):
		_poll_hold("menu_slot_x", "x", id, false)
		_poll_hold("menu_slot_y", "y", id, true)
	elif Input.is_action_just_pressed("menu_drop"):
		_say(UiItemVerbs.drop(world, id))
		return true
	return false


## Hold-to-assign: a press starts the timer, HOLD_MS later the item is
## assigned; a release before that drops (Y) or does nothing (X).
func _poll_hold(action: String, slot: String, id: String, drop_on_tap: bool) -> void:
	var now := Time.get_ticks_msec()
	var since: int = _hold[slot]
	var down := Input.is_action_pressed(action)
	if Input.is_action_just_pressed(action):
		_hold[slot] = now
		_say("hold to assign to %s…" % Controls.glyph("item_" + slot))
	elif since >= 0 and down and now - since >= HOLD_MS:
		_assign(slot, id)
		_hold[slot] = -2
	elif since >= 0 and not down:
		_hold[slot] = -1
		_say("")
		if drop_on_tap:
			_say(UiItemVerbs.drop(world, id))
	elif since == -2 and not down:
		_hold[slot] = -1
