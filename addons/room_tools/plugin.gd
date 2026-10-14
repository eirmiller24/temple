@tool
extends EditorPlugin
## Project > Tools > New Room... — adding a room is just adding a scene,
## made one click (docs/room_authoring.md §1).
##
## It COPIES addons/room_tools/room_template.tscn; it does not create an
## inherited scene. Inheritance would keep every room linked to the
## template, so one later tweak there would silently change all of them.
## Rooms are independent by design.
##
## Project > Tools > Rebuild Room Registry runs tools/build_room_registry.gd
## in-editor (same code path: RoomRegistryBuilder.build_from_scenes + validate)
## and prints the problems to the Output panel.

const TEMPLATE := "res://addons/room_tools/room_template.tscn"
const ROOMS_DIR := "res://game/rooms"
const MENU_NEW := "New Room..."
const MENU_REGISTRY := "Rebuild Room Registry"

var _dialog: ConfirmationDialog
var _name_edit: LineEdit
var _folder_edit: LineEdit
var _wx: SpinBox
var _wy: SpinBox
var _status: Label


func _enter_tree() -> void:
	add_tool_menu_item(MENU_NEW, _open_dialog)
	add_tool_menu_item(MENU_REGISTRY, _rebuild_registry)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_NEW)
	remove_tool_menu_item(MENU_REGISTRY)
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


func _open_dialog() -> void:
	if not is_instance_valid(_dialog):
		_build_dialog()
	_name_edit.text = ""
	_refresh_status()
	_dialog.popup_centered()
	_name_edit.grab_focus()


func _build_dialog() -> void:
	_dialog = ConfirmationDialog.new()
	_dialog.title = "New Room"
	_dialog.ok_button_text = "Create"
	_dialog.min_size = Vector2i(480, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	var l1 := Label.new()
	l1.text = "Scene name (snake_case; becomes the room's name and map id):"
	box.add_child(l1)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "collapse_entry_hall"
	_name_edit.text_changed.connect(func(_t: String) -> void: _refresh_status())
	_name_edit.text_submitted.connect(func(_t: String) -> void:
			if _validate() == "":
				_dialog.hide()
				_create())
	box.add_child(_name_edit)

	var l2 := Label.new()
	l2.text = "Folder under game/rooms/ (blank = top level; 'test' for throwaway rooms):"
	box.add_child(l2)
	_folder_edit = LineEdit.new()
	_folder_edit.placeholder_text = ""
	_folder_edit.text_changed.connect(func(_t: String) -> void: _refresh_status())
	box.add_child(_folder_edit)

	var l3 := Label.new()
	l3.text = "World grid position of local tile (0,0), in tiles. Neighbours must line up:"
	box.add_child(l3)
	var row := HBoxContainer.new()
	_wx = SpinBox.new()
	_wx.min_value = -100000
	_wx.max_value = 100000
	_wx.prefix = "x "
	_wy = SpinBox.new()
	_wy.min_value = -100000
	_wy.max_value = 100000
	_wy.prefix = "y "
	row.add_child(_wx)
	row.add_child(_wy)
	box.add_child(row)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 48)
	box.add_child(_status)

	_dialog.add_child(box)
	_dialog.confirmed.connect(_create)
	EditorInterface.get_base_control().add_child(_dialog)


func _target_path() -> String:
	var n := _name_edit.text.strip_edges()
	var folder := _folder_edit.text.strip_edges().trim_prefix("/").trim_suffix("/")
	return "%s/%s%s.tscn" % [ROOMS_DIR, folder + "/" if folder != "" else "", n]


func _validate() -> String:
	var n := _name_edit.text.strip_edges()
	if n == "":
		return "Enter a name."
	if not n.is_valid_filename() or n != n.to_lower() or n.contains(" ") or n.contains("."):
		return "Use lower-case snake_case with no spaces or dots."
	if n == "nodes":
		return "'nodes' is the node-class folder."
	for p in RoomRegistryBuilder.scene_paths():
		if p.get_file().get_basename() == n:
			return "A room named %s already exists (%s)." % [n, p]
	return ""


func _refresh_status() -> void:
	var problem := _validate()
	if problem != "":
		_status.text = problem
		_status.modulate = Color(1.0, 0.75, 0.55)
		_dialog.get_ok_button().disabled = true
		return
	_status.text = "Creates %s at world (%d, %d).\nPaint Collision, add exits, then Project > Tools > Rebuild Room Registry." % [
			_target_path(), int(_wx.value), int(_wy.value)]
	_status.modulate = Color(1, 1, 1)
	_dialog.get_ok_button().disabled = false


func _create() -> void:
	if _validate() != "":
		return
	var room_name := _name_edit.text.strip_edges()
	var path := _target_path()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var template: PackedScene = load(TEMPLATE)
	if template == null:
		push_error("New Room: cannot load %s" % TEMPLATE)
		return
	var root: Node = template.instantiate()
	root.name = room_name
	root.set("world_x", int(_wx.value))
	root.set("world_y", int(_wy.value))
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("New Room: cannot pack %s" % room_name)
		root.free()
		return
	var err := ResourceSaver.save(packed, path)
	root.free()
	if err != OK:
		push_error("New Room: cannot write %s (error %d)" % [path, err])
		return
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.open_scene_from_path(path)
	print("New Room: created %s" % path)


func _rebuild_registry() -> void:
	var reg := RoomRegistryBuilder.build_from_scenes()
	var problems := RoomRegistryBuilder.validate(reg)
	for p in problems:
		if p.begins_with("warning:"):
			print("rooms: ", p)
		else:
			push_error("rooms: " + p)
	var out := {
		"_comment": RoomRegistryBuilder.REGISTRY_COMMENT,
		"rooms": {},
	}
	var names := reg.keys()
	names.sort()
	for n in names:
		out.rooms[n] = reg[n]
	var f := FileAccess.open("res://data/rooms.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("rooms.json rebuilt: %d rooms, %d problems" % [reg.size(), problems.size()])
	EditorInterface.get_resource_filesystem().scan()
