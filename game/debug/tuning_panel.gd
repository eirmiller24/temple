extends Control
## F1 (debug_tuning) toggles a panel that lists every numeric leaf of
## Data.player, Data.objects and Data.weapons as "path: value" rows with a
## LineEdit. A submitted value is written into the Data dictionary in place
## — the player and objects read those each frame, so it takes effect at
## once — and is lost on F3 / restart: the note says so. Dictionaries are
## walked recursively; "_comment" keys, arrays and booleans are skipped.
## Does not pause the game. Runs PROCESS_MODE_ALWAYS so it works while the
## pause menu is up.

const WIDTH := 380.0
const SOURCES := {"player": "player.json", "objects": "objects.json", "weapons": "weapons.json"}

var _rows: VBoxContainer
var _filter: LineEdit
var _count: Label
var _entries: Array = []   # {dict, key, path, edit, row}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.theme()
	visible = false
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -WIDTH
	offset_right = 0
	offset_top = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(Color(UiTheme.BG, 0.94), UiTheme.ACCENT, 8))
	UiTheme.fill(panel)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(UiTheme.label("TUNING  (F1)", UiTheme.SIZE_LABEL, UiTheme.ACCENT))
	box.add_child(UiTheme.label("unsaved: edit data/*.json to keep", UiTheme.SIZE_SMALL, UiTheme.DIM))
	_filter = LineEdit.new()
	_filter.placeholder_text = "filter…"
	_filter.text_changed.connect(func(_t: String) -> void: _apply_filter())
	box.add_child(_filter)
	_count = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.DIM)
	box.add_child(_count)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	box.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	Data.reloaded.connect(rebuild)
	rebuild()


## Re-list every numeric leaf (after F3, the dictionaries are new objects).
func rebuild() -> void:
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	_entries.clear()
	for root: String in SOURCES:
		var d: Variant = Data.get(root)
		if typeof(d) != TYPE_DICTIONARY:
			continue
		_walk(d, root)
	_apply_filter()


func _walk(d: Dictionary, prefix: String) -> void:
	var keys := d.keys()
	keys.sort()
	for k in keys:
		var key := String(k)
		if key == "_comment":
			continue
		var v: Variant = d[k]
		var path := "%s.%s" % [prefix, key]
		match typeof(v):
			TYPE_DICTIONARY:
				_walk(v, path)
			TYPE_FLOAT, TYPE_INT:
				_add_row(d, k, path, v)


func _add_row(d: Dictionary, key: Variant, path: String, value: Variant) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := UiTheme.label(path, UiTheme.SIZE_SMALL, UiTheme.TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
	var edit := LineEdit.new()
	edit.text = _fmt(value)
	edit.custom_minimum_size.x = 84
	edit.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)
	row.add_child(edit)
	_rows.add_child(row)
	var entry := {"dict": d, "key": key, "path": path, "edit": edit, "row": row, "label": label}
	_entries.append(entry)
	edit.text_submitted.connect(func(_t: String) -> void: _commit(entry))
	edit.focus_exited.connect(func() -> void: _commit(entry))


static func _fmt(v: Variant) -> String:
	var f := float(v)
	if is_equal_approx(f, roundf(f)) and absf(f) < 1e9:
		return str(int(roundf(f)))
	return String.num(f, 4)


func _commit(entry: Dictionary) -> void:
	var edit: LineEdit = entry.edit
	var d: Dictionary = entry.dict
	var text := edit.text.strip_edges()
	if not text.is_valid_float():
		edit.text = _fmt(d[entry.key])
		return
	var v := text.to_float()
	if is_equal_approx(v, float(d[entry.key])):
		return
	d[entry.key] = v
	edit.text = _fmt(v)
	(entry.label as Label).add_theme_color_override("font_color", UiTheme.ACCENT)
	print("tuning: %s = %s (unsaved)" % [entry.path, edit.text])


func _apply_filter() -> void:
	var f := _filter.text.strip_edges().to_lower()
	var shown := 0
	for e in _entries:
		var vis: bool = f == "" or String(e.path).to_lower().contains(f)
		(e.row as Control).visible = vis
		if vis:
			shown += 1
	_count.text = "%d / %d values" % [shown, _entries.size()]


## Programmatic edit (tests and tools): set `path` to `value` as a row would.
func set_value(path: String, value: float) -> bool:
	for e in _entries:
		if String(e.path) == path:
			(e.edit as LineEdit).text = str(value)
			_commit(e)
			return true
	return false


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_tuning"):
		visible = not visible
		if visible:
			_filter.grab_focus()
		else:
			get_viewport().gui_release_focus()
