extends Control
## In-game overlay: hearts top-left, the two item slots and the weapon
## bottom-left (each fronted by its live button glyph), a small minimap top-right, and the room's display name
## fading in for a moment on World.room_changed. Thin, semi-transparent
## panels; everything is driven by GameState signals after bind(world).
## Also hosts the F1 tuning panel (game/debug) so it exists whenever a
## world does.

const TUNING_SCENE := "res://game/debug/tuning_panel.tscn"
const MARGIN := 12.0
const MINIMAP_SIZE := Vector2(120, 80)
const ROOM_NAME_TIME := 2.0

var world: World
var hearts: UiHearts
var minimap: UiMinimap
var _slot_x: Label
var _slot_y: Label
var _weapon: Label
var _slot_keys := {}   # action -> the glyph Label in front of each slot
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
	slots.offset_top = -MARGIN - 30
	slots.offset_bottom = -MARGIN
	add_child(slots)
	_slot_x = _slot(slots, "item_x")
	_slot_y = _slot(slots, "item_y")
	_weapon = _slot(slots, "attack")
	Controls.bindings_changed.connect(_refresh_glyphs)
	_refresh_glyphs()

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


func _slot(parent: Control, action: String) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.PANEL_THIN, Color(UiTheme.DIM, 0.6), 6))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size.x = 120
	parent.add_child(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var k := UiTheme.label(Controls.glyph(action), UiTheme.SIZE_LABEL, UiTheme.ACCENT)
	row.add_child(k)
	_slot_keys[action] = k
	var name_label := UiTheme.label("—", UiTheme.SIZE_LABEL)
	row.add_child(name_label)
	return name_label


func bind(w: World) -> void:
	world = w
	minimap.bind(w)
	if not w.room_changed.is_connected(_on_room_changed):
		w.room_changed.connect(_on_room_changed)
	if w.room_name != "":
		_on_room_changed(w.room_name)


func _refresh_glyphs() -> void:
	for action: String in _slot_keys:
		(_slot_keys[action] as Label).text = Controls.glyph(action)


func _refresh_slots() -> void:
	_slot_x.text = _item_text(GameState.slot_x)
	_slot_y.text = _item_text(GameState.slot_y)
	_weapon.text = _item_text(GameState.weapon)


func _item_text(id: String) -> String:
	if id == "" or not GameState.has_item(id):
		return "—"
	var def := GameState.item_def(id)
	var text := String(def.get("name", id))
	var n := GameState.count(id)
	if n > 1 or GameState.is_ammo(id):
		text += "  ×%d" % n
	return text


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
