class_name UiItemCell
extends Button
## One square item slot: the item's icon (UiItemIcon) or, without one, its
## name; a count in the bottom-right corner; a badge in the top-left naming
## the button the item sits on. The pause menu's grids (UiItemsTab) use
## focusable cells; the HUD's action buttons and the pause menu's loadout
## use the same cell with focus off. An empty cell (id "") is a dim frame:
## the grids keep fixed slots, as Zelda's subscreens do, so an item not
## found yet reads as a gap.

var id := ""
## Which grid the cell belongs to (UiItemVerbs.section), "" outside one.
var section := ""
## The item ids that share this slot, oldest first — an item that
## `replaces` another takes over its slot (Quality Boots over Ratty
## Boots). Empty for packed cells, which are filled by index.
var chain: Array = []

var _icon: TextureRect
var _name: Label
var _count: Label
var _badge: Label
var _equipped := false


func _init(cell_px: float = 72.0, icon_scale: int = 2, focusable: bool = true) -> void:
	custom_minimum_size = Vector2(cell_px, cell_px)
	focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE
	if not focusable:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["hover", "focus"]:
		add_theme_stylebox_override(s, UiTheme.cell(s))
	_icon = TextureRect.new()
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_px := float(UiItemIcon.SIZE * icon_scale)
	_icon.set_anchors_preset(Control.PRESET_CENTER)
	_icon.offset_left = -icon_px / 2.0
	_icon.offset_top = -icon_px / 2.0
	_icon.offset_right = icon_px / 2.0
	_icon.offset_bottom = icon_px / 2.0
	add_child(_icon)
	_name = UiTheme.outline(UiTheme.label("", UiTheme.SIZE_SMALL), 3)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.fill(_name)
	_name.offset_left = 3
	_name.offset_right = -3
	add_child(_name)
	_count = UiTheme.outline(UiTheme.label("", UiTheme.SIZE_SMALL))
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_count.offset_left = -40
	_count.offset_top = -18
	_count.offset_right = -4
	_count.offset_bottom = -1
	add_child(_count)
	_badge = UiTheme.outline(UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.ACCENT))
	_badge.position = Vector2(4, 1)
	add_child(_badge)
	show_item("")


## Show `item_id` ("" = empty slot). `count` is drawn when non-empty;
## `badge` is the glyph of the button the item sits on.
func show_item(item_id: String, count: String = "", badge: String = "") -> void:
	id = item_id
	var tex := UiItemIcon.texture(item_id) if item_id != "" else null
	_icon.texture = tex
	_name.text = "" if item_id == "" or tex != null else String(GameState.item_def(item_id).get("name", item_id))
	_count.text = count
	_count.modulate = Color(UiTheme.HEART, 1.0) if count == "0" else Color.WHITE
	_badge.text = badge
	_equipped = badge != ""
	_restyle()


func _restyle() -> void:
	var state := "empty" if id == "" else ("equipped" if _equipped else "normal")
	add_theme_stylebox_override("normal", UiTheme.cell(state))
	add_theme_stylebox_override("pressed", UiTheme.cell(state))
	add_theme_stylebox_override("disabled", UiTheme.cell(state))


func icon_texture() -> Texture2D:
	return _icon.texture


func count_text() -> String:
	return _count.text


func badge_text() -> String:
	return _badge.text
