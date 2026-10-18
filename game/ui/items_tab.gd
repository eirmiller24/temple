class_name UiItemsTab
extends Control
## The pause menu's ITEMS tab, laid out like a Zelda subscreen: icon grids
## by section on the left, a detail card for the highlighted cell on the
## right with the current loadout under it. Sections (UiItemVerbs.section):
##
##   WEAPONS    one fixed slot per kind "weapon" item. Accept equips it on
##              the attack button. Never dropped.
##   EQUIPMENT  one fixed slot per kind "passive" item; an item that
##              `replaces` another takes over its slot. Nothing to press.
##   TOOLS      one fixed slot per kind "tool" item. An item button
##              (menu_slot_x / menu_slot_y) puts the tool on that button.
##              Never dropped.
##   PACK       everything else, packed left to right. Accept opens the
##              item's popup: menu_use (item 2's button) uses, menu_drop
##              (item 1's) drops, menu_back (attack) backs out, accept
##              again shows the description. Items with "hide_use" never list
##              Use but menu_use still works on them (the Fang trick, §9.2).
##
## The fixed slots come from data/items.json in file order, so an item not
## found yet is a visible gap. Navigation between cells is Godot's own
## geometric focus. Button names in the UI are the live bindings
## (Controls). The owner calls poll() every frame the tab is active.

signal hint_changed(text: String)

const CELL := 72.0
const GAP := 6
const COLS := 7
const PACK_ROWS := 2
const SECTION_GAP := 12
const ROW_GAP := 40
const GRID_W := 540.0
const CARD_X := 572.0
const CARD_ICON := 3
const KIND_ORDER := ["consumable", "key"]

var world: World
var _cells: Array = []          # every UiItemCell in the grids, in build order
var _layout_key := ""
var _grid_root: VBoxContainer
var _focused: UiItemCell
var _focus_index := 0

var _card_icon: TextureRect
var _card_alt: Label            # the name, in the frame, for an item without an icon
var _card_frame: PanelContainer
var _name: Label
var _meta: Label
var _desc: Label
var _status: Label
var _loadout := {}              # gameplay action -> UiItemCell

var _popup: PanelContainer
var _popup_box: VBoxContainer
var _popup_id := ""
var _popup_desc := false
var _popup_frame := -1


func _ready() -> void:
	_grid_root = VBoxContainer.new()
	_grid_root.add_theme_constant_override("separation", SECTION_GAP)
	_grid_root.custom_minimum_size.x = GRID_W
	add_child(_grid_root)
	_build_card()
	_build_popup()
	GameState.inventory_changed.connect(refresh)
	GameState.slots_changed.connect(refresh)
	Controls.bindings_changed.connect(refresh)
	if not Data.reloaded.is_connected(UiItemIcon.clear_cache):
		Data.reloaded.connect(UiItemIcon.clear_cache)
	refresh()


func bind(w: World) -> void:
	world = w


# --- slots --------------------------------------------------------------------------------------------

## The fixed slots of one item kind, in data/items.json order: an Array of
## chains (Arrays of ids), where an item that `replaces` another of the
## same kind joins that item's chain instead of opening a slot.
static func fixed_slots(kind: String) -> Array:
	var chains := []
	var chain_of := {}
	var items: Dictionary = Data.items.get("items", {})
	for id: String in items:
		var def: Dictionary = items[id]
		if String(def.get("kind", "")) != kind:
			continue
		var rep := String(def.get("replaces", ""))
		if rep != "" and chain_of.has(rep):
			(chain_of[rep] as Array).append(id)
			chain_of[id] = chain_of[rep]
		else:
			var c := [id]
			chains.append(c)
			chain_of[id] = c
	return chains


## The pack's contents: every owned item outside the fixed sections,
## consumables first, then keys, then the rest, by name within a kind.
static func pack_ids() -> Array:
	var ids := []
	for id: String in GameState.inventory:
		if UiItemVerbs.section(id) == "pack":
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ka := _kind_rank(a)
		var kb := _kind_rank(b)
		if ka != kb:
			return ka < kb
		return String(GameState.item_def(a).get("name", a)) < String(GameState.item_def(b).get("name", b)))
	return ids


static func _kind_rank(id: String) -> int:
	var i := KIND_ORDER.find(String(GameState.item_def(id).get("kind", "")))
	return i if i >= 0 else KIND_ORDER.size()


func _pack_rows() -> int:
	return maxi(PACK_ROWS, ceili(pack_ids().size() / float(COLS)))


func _build_grids() -> void:
	var had_focus := has_cell_focus()
	for c in _grid_root.get_children():
		_grid_root.remove_child(c)
		c.queue_free()
	_cells.clear()
	_focused = null
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", ROW_GAP)
	_grid_root.add_child(top)
	var weapons := fixed_slots("weapon")
	var gear := fixed_slots("passive")
	top.add_child(_section("WEAPONS", "weapons", weapons, weapons.size()))
	top.add_child(_section("EQUIPMENT", "equipment", gear, gear.size()))
	_grid_root.add_child(_section("TOOLS", "tools", fixed_slots("tool"), COLS))
	var packed := []
	for i in _pack_rows() * COLS:
		packed.append([])
	_grid_root.add_child(_section("PACK", "pack", packed, COLS))
	if had_focus:
		focus_cell(_focus_index)


func _section(title: String, section_id: String, slots: Array, cols: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols = clampi(cols, 1, COLS)
	var width := cols * CELL + (cols - 1) * GAP
	box.add_child(UiTheme.section_header(title, width))
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(grid)
	for chain: Array in slots:
		var cell := UiItemCell.new(CELL, 2)
		cell.section = section_id
		cell.chain = chain
		var index := _cells.size()
		cell.focus_entered.connect(func() -> void: _on_cell_focus(cell, index))
		cell.pressed.connect(func() -> void: _activate(cell))
		UiTheme.focus_on_hover(cell)
		grid.add_child(cell)
		_cells.append(cell)
	return box


func refresh() -> void:
	var key := "%s|%s|%s|%d" % [fixed_slots("weapon"), fixed_slots("passive"), fixed_slots("tool"), _pack_rows()]
	if key != _layout_key:
		_layout_key = key
		_build_grids()
	var packed := pack_ids()
	var p := 0
	for cell: UiItemCell in _cells:
		var id := ""
		if cell.section == "pack":
			id = String(packed[p]) if p < packed.size() else ""
			p += 1
		else:
			for c: String in cell.chain:
				if GameState.has_item(c):
					id = c
		cell.show_item(id, count_text(id), badge_text(id))
	if _popup_id != "" and not GameState.has_item(_popup_id):
		_close_popup(false)
	_show_details()
	_refresh_loadout()


## What a cell shows in its corner: ammo always (×0 included), any other
## stack above one.
static func count_text(id: String) -> String:
	if id == "":
		return ""
	var n := GameState.count(id)
	return str(n) if n > 1 or GameState.is_ammo(id) else ""


## The glyph of the button an item sits on — the weapon's attack button,
## an item slot's button — else "".
static func badge_text(id: String) -> String:
	if id == "":
		return ""
	if GameState.weapon == id:
		return Controls.glyph("attack")
	if GameState.slot_x == id:
		return Controls.glyph("item_x")
	if GameState.slot_y == id:
		return Controls.glyph("item_y")
	return ""


# --- focus ---------------------------------------------------------------------------------------------

func _on_cell_focus(cell: UiItemCell, index: int) -> void:
	_focused = cell
	_focus_index = index
	if _popup.visible and cell.id != _popup_id:
		_close_popup(false)
	_say("")
	_show_details()


func focus_cell(i: int) -> void:
	if _cells.is_empty():
		return
	_focus_index = clampi(i, 0, _cells.size() - 1)
	(_cells[_focus_index] as UiItemCell).grab_focus()


## Focus the last highlighted cell (the first one on a fresh menu).
func focus_list() -> void:
	focus_cell(_focus_index)


## Test/driver hook: highlight the cell holding `id`; false if no cell does.
func highlight_item(id: String) -> bool:
	for i in _cells.size():
		if (_cells[i] as UiItemCell).id == id:
			focus_cell(i)
			return true
	return false


func highlighted_id() -> String:
	return _focused.id if _focused != null else ""


func highlighted_section() -> String:
	return _focused.section if _focused != null else ""


func has_cell_focus() -> bool:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return f != null and _cells.has(f)


## Every cell of one section, in order.
func cells(section_id: String) -> Array:
	return _cells.filter(func(c: UiItemCell) -> bool: return c.section == section_id)


func loadout_cell(action: String) -> UiItemCell:
	return _loadout.get(action)


# --- detail card ---------------------------------------------------------------------------------------

func _build_card() -> void:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 6)
	card.position = Vector2(CARD_X, 0)
	card.custom_minimum_size = Vector2(size.x - CARD_X, size.y)
	card.size = card.custom_minimum_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var w := card.size.x
	card.add_child(UiTheme.section_header("ITEM", w))
	_card_frame = PanelContainer.new()
	_card_frame.add_theme_stylebox_override("panel", UiTheme.cell("normal"))
	var frame_px := UiItemIcon.SIZE * CARD_ICON + 16
	_card_frame.custom_minimum_size = Vector2(w, frame_px)
	_card_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(_card_frame)
	_card_icon = TextureRect.new()
	_card_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_card_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card_icon.custom_minimum_size = Vector2(UiItemIcon.SIZE * CARD_ICON, UiItemIcon.SIZE * CARD_ICON)
	_card_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_card_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_frame.add_child(_card_icon)
	_card_alt = UiTheme.label("", UiTheme.SIZE_HEADING, UiTheme.DIM)
	_card_alt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_alt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_frame.add_child(_card_alt)
	_name = UiTheme.label("", UiTheme.SIZE_HEADING)
	card.add_child(_name)
	_meta = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.DIM)
	card.add_child(_meta)
	_desc = UiTheme.label("", UiTheme.SIZE_LABEL)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size.x = w
	_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(_desc)
	_status = UiTheme.label("", UiTheme.SIZE_LABEL, UiTheme.ACCENT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = w
	card.add_child(_status)
	card.add_child(UiTheme.section_header("LOADOUT", w))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	for action in ["attack", "item_x", "item_y"]:
		var c := UiItemCell.new(48.0, 1, false)
		row.add_child(c)
		_loadout[action] = c


func _show_details() -> void:
	var id := highlighted_id()
	if id == "":
		_card_icon.texture = null
		_card_alt.text = ""
		_name.text = ""
		_meta.text = ""
		_desc.text = ""
		if _focused != null:
			_name.text = "—"
			_meta.text = "empty" if _focused.section == "pack" else "not found yet"
		hint_changed.emit(UiItemVerbs.cell_hint("", ""))
		return
	var def := GameState.item_def(id)
	_card_icon.texture = UiItemIcon.texture(id)
	_name.text = String(def.get("name", id))
	_card_alt.text = _name.text if _card_icon.texture == null else ""
	var meta := PackedStringArray([UiItemVerbs.section_name(id)])
	var n := GameState.count(id)
	if n > 1 or GameState.is_ammo(id):
		meta.append("×%d" % n)
	var badge := badge_text(id)
	if badge != "":
		meta.append("on " + badge)
	_meta.text = "  ·  ".join(meta)
	_desc.text = String(def.get("description", ""))
	hint_changed.emit(UiItemVerbs.cell_hint(_focused.section, id))


func _refresh_loadout() -> void:
	for action: String in _loadout:
		var id: String = {"attack": GameState.weapon, "item_x": GameState.slot_x, "item_y": GameState.slot_y}[action]
		if id != "" and not GameState.has_item(id):
			id = ""
		(_loadout[action] as UiItemCell).show_item(id, count_text(id), Controls.glyph(action))


func _say(text: String) -> void:
	_status.text = text


func status_text() -> String:
	return _status.text


# --- verbs ------------------------------------------------------------------------------------------------

func _activate(cell: UiItemCell) -> void:
	if _popup.visible:
		_popup_verb("description")
		return
	var id := cell.id
	if id == "":
		Sfx.play("menu_error")
		return
	var name := String(GameState.item_def(id).get("name", id))
	match cell.section:
		"weapons":
			if GameState.weapon == id:
				Sfx.play("menu_accept")
				_say("%s is already on %s." % [name, Controls.glyph("attack")])
			else:
				_say(UiItemVerbs.use(world, id))
		"tools":
			Sfx.play("menu_move")
			_say("Press %s or %s to put the %s on that button." % [Controls.glyph("item_x"),
					Controls.glyph("item_y"), name])
		"equipment":
			Sfx.play("menu_move")
			_say("Always in use.")
		"pack":
			_open_popup(cell)


# --- pack popup ---------------------------------------------------------------------------------------------

func _build_popup() -> void:
	_popup = PanelContainer.new()
	var sb := UiTheme.panel(Color(0.05, 0.045, 0.07, 0.98), UiTheme.ACCENT, 10)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	_popup.add_theme_stylebox_override("panel", sb)
	_popup.focus_mode = Control.FOCUS_ALL
	for side in ["focus_neighbor_left", "focus_neighbor_right", "focus_neighbor_top",
			"focus_neighbor_bottom", "focus_next", "focus_previous"]:
		_popup.set(side, NodePath("."))
	_popup.visible = false
	_popup.z_index = 1
	add_child(_popup)
	_popup_box = VBoxContainer.new()
	_popup_box.add_theme_constant_override("separation", 2)
	_popup.add_child(_popup_box)


func is_popup_open() -> bool:
	return _popup.visible


func popup_item() -> String:
	return _popup_id if _popup.visible else ""


func popup_showing_description() -> bool:
	return _popup.visible and _popup_desc


func _open_popup(cell: UiItemCell) -> void:
	_popup_id = cell.id
	_popup_desc = false
	_popup_frame = Engine.get_process_frames()
	_fill_popup()
	_popup.visible = true
	_place_popup(cell)
	_popup.grab_focus()
	Sfx.play("menu_accept")


func _close_popup(sound: bool = true) -> void:
	if not _popup.visible:
		return
	_popup.visible = false
	_popup_id = ""
	_popup_desc = false
	if sound:
		Sfx.play("menu_back")
	if _focused != null and is_instance_valid(_focused) and is_visible_in_tree():
		_focused.grab_focus()


## Right of the cell, or left of it if that would leave the grid area.
func _place_popup(cell: UiItemCell) -> void:
	_popup.reset_size()
	var sz := _popup.get_combined_minimum_size()
	var r := cell.get_global_rect()
	var at := r.position - global_position
	var x := at.x + r.size.x + 8
	if x + sz.x > CARD_X - 8:
		x = at.x - sz.x - 8
	var y := clampf(at.y - 8, 0, size.y - sz.y)
	_popup.position = Vector2(x, y)
	_popup.size = sz


func _fill_popup() -> void:
	for c in _popup_box.get_children():
		_popup_box.remove_child(c)
		c.queue_free()
	var def := GameState.item_def(_popup_id)
	var title := UiTheme.label(String(def.get("name", _popup_id)), UiTheme.SIZE_LABEL, UiTheme.ACCENT)
	_popup_box.add_child(title)
	_popup_box.add_child(UiTheme.rule(0, Color(UiTheme.DIM, 0.6)))
	if _popup_desc:
		var d := UiTheme.label(String(def.get("description", "")), UiTheme.SIZE_LABEL)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 220
		_popup_box.add_child(d)
		_popup_box.add_child(UiTheme.label(Controls.hint([["menu_accept", "back"], ["attack", "back"]]),
				UiTheme.SIZE_SMALL, UiTheme.DIM))
		return
	for v: Array in UiItemVerbs.pack_verbs(_popup_id):
		var b := UiTheme.button("", UiTheme.SIZE_LABEL, 168)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.text = "%s    %s" % [Controls.glyph(String(v[0])), String(v[1]).capitalize()]
		var verb := String(v[1])
		b.pressed.connect(func() -> void: _popup_verb(verb))
		_popup_box.add_child(b)


func _popup_verb(verb: String) -> void:
	var id := _popup_id
	match verb:
		"use":
			_close_popup(false)
			_say(UiItemVerbs.use(world, id))
		"drop":
			_close_popup(false)
			_say(UiItemVerbs.drop(world, id))
		"description":
			_popup_desc = not _popup_desc
			Sfx.play("page_turn" if _popup_desc else "menu_back")
			_fill_popup()
			_place_popup(_focused)
		"back":
			if _popup_desc:
				_popup_verb("description")
			else:
				_close_popup()


# --- per-frame input --------------------------------------------------------------------------------------

## True while the tab owns every input (the popup is open): the owner
## must hand it the frame before anything else, pause and back included.
func is_modal() -> bool:
	return _popup.visible


## Returns true when this frame's press belonged to the tab (so the owner
## must not treat it as back / tab switch / close).
func poll() -> bool:
	if _popup.visible:
		if Engine.get_process_frames() == _popup_frame:
			return true  # the accept that opened it
		if Input.is_action_just_pressed("menu_drop"):
			_popup_verb("drop")
		elif Input.is_action_just_pressed("menu_use"):
			_popup_verb("use")
		elif Input.is_action_just_pressed("menu_back") or Input.is_action_just_pressed("pause"):
			_popup_verb("back")
		elif Input.is_action_just_pressed("menu_accept"):
			_popup_verb("description")
		return true
	if not has_cell_focus():
		return false
	if UiTheme.accept_pressed():
		UiTheme.press_focused(get_viewport())
		return true
	if _focused.section == "tools" and _focused.id != "":
		if Input.is_action_just_pressed("menu_slot_x"):
			_say(UiItemVerbs.assign("x", _focused.id))
			return true
		if Input.is_action_just_pressed("menu_slot_y"):
			_say(UiItemVerbs.assign("y", _focused.id))
			return true
	return false
