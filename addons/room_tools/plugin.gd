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
##
## It also registers the godot-ai MCP tool `new_room` (mcp_new_room.gd) —
## "give me a 30x20 room" from a chat — whenever godot-ai's tool registry is
## up, including after godot-ai reloads.

const RoomFactory := preload("res://addons/room_tools/room_factory.gd")
const NEW_ROOM_TOOL := "res://addons/room_tools/mcp_new_room.gd"
const NewRoomTool := preload(NEW_ROOM_TOOL)
const PLUGIN_CFG := "res://addons/room_tools/plugin.cfg"
const MENU_NEW := "New Room..."
const MENU_REGISTRY := "Rebuild Room Registry"

var _dialog: ConfirmationDialog
var _name_edit: LineEdit
var _folder_edit: LineEdit
var _wx: SpinBox
var _wy: SpinBox
var _status: Label
## Instance id of the godot-ai registry `new_room` is registered with (0 = none).
var _mcp_registry_id := 0


func _enter_tree() -> void:
	add_tool_menu_item(MENU_NEW, _open_dialog)
	add_tool_menu_item(MENU_REGISTRY, _rebuild_registry)


## godot-ai may load before or after this plugin and replaces its registry
## when it reloads, so watch for a new one rather than registering once.
func _process(_delta: float) -> void:
	var reg := McpToolRegistry.get_instance()
	var id := reg.get_instance_id() if reg != null else 0
	if id == _mcp_registry_id:
		return
	_mcp_registry_id = id
	if reg != null:
		_register_mcp_tools(reg)


func _register_mcp_tools(reg: McpToolRegistry) -> void:
	var spec := McpCustomToolSpec.new()
	spec.name = "new_room"
	spec.description = NewRoomTool.DESCRIPTION
	spec.params_schema = NewRoomTool.SCHEMA
	spec.script_path = NEW_ROOM_TOOL
	spec.method = &"new_room"
	spec.source_path = PLUGIN_CFG
	spec.promoted = true
	spec.requires_writable = true
	spec.timeout_ms = 30000
	reg.register(spec)


func _exit_tree() -> void:
	var reg := McpToolRegistry.get_instance()
	if reg != null:
		reg.unregister_source(PLUGIN_CFG)
	_mcp_registry_id = 0
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
	return RoomFactory.target_path(_name_edit.text.strip_edges(), _folder_edit.text)


func _validate() -> String:
	return RoomFactory.validate_name(_name_edit.text.strip_edges())


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
	var problem := RoomFactory.create(_name_edit.text.strip_edges(), _target_path(),
			Vector2i(int(_wx.value), int(_wy.value)))
	if problem != "":
		push_error("New Room: " + problem)


func _rebuild_registry() -> void:
	RoomFactory.rebuild_registry()
