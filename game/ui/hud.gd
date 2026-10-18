extends Control
## In-game overlay: hearts top-left, the action buttons bottom-left (the
## weapon, then the two item slots: each an icon cell (UiItemCell) badged
## with its live button glyph, ammo counted in the corner), a small minimap top-right, and the room's display name
## fading in for a moment on World.room_changed. Thin, semi-transparent
## panels; everything is driven by GameState signals after bind(world).
## Also hosts the F1 tuning panel (game/debug) so it exists whenever a
## world does.

const TUNING_SCENE := "res://game/debug/tuning_panel.tscn"
const MARGIN := 12.0
const MINIMAP_SIZE := Vector2(120, 80)
const ROOM_NAME_TIME := 2.0
const SLOT_PX := 44.0

var world: World
var hearts: UiHearts
var minimap: UiMinimap
var _slot_x: UiItemCell
var _slot_y: UiItemCell
var _weapon: UiItemCell
var _room_label: Label
var _room_tween: Tween


func _ready() -> void:
	theme = UiTheme.theme()
	UiTheme.fill(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hearts_panel := _panel(Vector2(MARGIN, MARGIN))
	hearts = UiHearts.new()
	hearts_panel.add_child(hearts)

	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 6)
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slots.anchor_top = 1.0
	slots.anchor_bottom = 1.0
	slots.offset_left = MARGIN
	slots.offset_top = -MARGIN - SLOT_PX
	slots.offset_bottom = -MARGIN
	add_child(slots)
	_weapon = _slot(slots)
	_slot_x = _slot(slots)
	_slot_y = _slot(slots)
	Controls.bindings_changed.connect(_refresh_slots)

	minimap = UiMinimap.new()
	minimap.tile_px = 3.0
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -MARGIN - MINIMAP_SIZE.x
	minimap.offset_right = -MARGIN
	minimap.offset_top = MARGIN
	minimap.offset_bottom = MARGIN + MINIMAP_SIZE.y
	add_child(minimap)

	_room_label = UiTheme.label("", UiTheme.SIZE_HEADING)
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_label.anchor_left = 0.0
	_room_label.anchor_right = 1.0
	_room_label.offset_top = 64
	_room_label.offset_bottom = 96
	_room_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_room_label.add_theme_constant_override("shadow_offset_x", 1)
	_room_label.add_theme_constant_override("shadow_offset_y", 1)
	_room_label.modulate.a = 0.0
	add_child(_room_label)

	if ResourceLoader.exists(TUNING_SCENE):
		add_child((load(TUNING_SCENE) as PackedScene).instantiate())

	GameState.slots_changed.connect(_refresh_slots)
	GameState.inventory_changed.connect(_refresh_slots)
	_refresh_slots()


func _panel(at: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.PANEL_THIN, Color(UiTheme.DIM, 0.6), 6))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.position = at
	add_child(p)
	return p


func _slot(parent: Control) -> UiItemCell:
	var c := UiItemCell.new(SLOT_PX, 1, false)
	c.modulate.a = 0.92
	parent.add_child(c)
	return c


func bind(w: World) -> void:
	world = w
	minimap.bind(w)
	if not w.room_changed.is_connected(_on_room_changed):
		w.room_changed.connect(_on_room_changed)
	if w.room_name != "":
		_on_room_changed(w.room_name)


func _refresh_slots() -> void:
	_show(_weapon, GameState.weapon, "attack")
	_show(_slot_x, GameState.slot_x, "item_x")
	_show(_slot_y, GameState.slot_y, "item_y")


## The badge is always the button's glyph, so an empty slot still says
## which button it is.
func _show(cell: UiItemCell, id: String, action: String) -> void:
	if id != "" and not GameState.has_item(id):
		id = ""
	cell.show_item(id, UiItemsTab.count_text(id), Controls.glyph(action))


func _on_room_changed(room: String) -> void:
	var info := RoomRegistry.info(room)
	var text := String(info.get("display_name", ""))
	if text == "" and world != null and world.room != null:
		text = world.room.room_name()
	if text == "":
		text = room
	_room_label.text = text
	if _room_tween != null and _room_tween.is_valid():
		_room_tween.kill()
	_room_tween = create_tween()
	_room_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_room_tween.tween_property(_room_label, "modulate:a", 1.0, 0.3)
	_room_tween.tween_interval(ROOM_NAME_TIME - 0.6)
	_room_tween.tween_property(_room_label, "modulate:a", 0.0, 0.3)
