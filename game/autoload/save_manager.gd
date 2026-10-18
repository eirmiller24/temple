extends Node
## Save slots (user://saves/slot_N.json) and settings (user://settings.json).
## The save body is GameState.to_dict(); this file only does the disk and
## the slot bookkeeping. Settings are not part of a slot.

const SLOTS := 3
const SAVE_DIR := "user://saves"
const SETTINGS_PATH := "user://settings.json"

const DEFAULT_SETTINGS := {
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"fullscreen": false,
	"aim_swap_sticks": true,   # free-aim: left stick aims, right stick moves (off = claw grip: right stick aims)
	"bindings": {},            # Controls overrides, {action: {"pad": [...], "key": [...]}}
}

var settings := DEFAULT_SETTINGS.duplicate(true)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	load_settings()
	apply_settings()


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## {exists, room, playtime, saved_at} for the title screen's slot picker.
func slot_info(slot: int) -> Dictionary:
	if not slot_exists(slot):
		return {"exists": false}
	var d := _read(slot_path(slot))
	if d.is_empty():
		return {"exists": false}
	return {
		"exists": true,
		"room": String(d.get("respawn_room", "")),
		"playtime": float(d.get("playtime", 0.0)),
		"saved_at": String(d.get("saved_at", "")),
		"hp": int(d.get("hp", 0)),
		"max_hp": int(d.get("max_hp", 0)),
	}


func save_game(slot: int) -> bool:
	if slot < 0 or slot >= SLOTS:
		push_error("SaveManager: bad slot %d" % slot)
		return false
	GameState.slot_index = slot
	return _write(slot_path(slot), GameState.to_dict())


func load_game(slot: int) -> bool:
	var d := _read(slot_path(slot))
	if d.is_empty():
		return false
	GameState.from_dict(d)
	GameState.slot_index = slot
	return true


func delete_slot(slot: int) -> void:
	if slot_exists(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot)))


func format_playtime(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


# --- settings -------------------------------------------------------------------

func load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	var d := _read(SETTINGS_PATH)
	for k: String in d:
		if settings.has(k) and typeof(d[k]) == typeof(settings[k]):
			settings[k] = d[k]


func save_settings() -> void:
	_write(SETTINGS_PATH, settings)


func apply_settings() -> void:
	Music.set_user_volume(float(settings.music_volume))
	Sfx.set_user_volume(float(settings.sfx_volume))
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings.fullscreen) \
			else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(mode)
	Controls.apply(settings.bindings)


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	save_settings()


# --- disk --------------------------------------------------------------------------

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _write(path: String, d: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(d, "  "))
	f.close()
	return true
