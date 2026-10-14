extends Node
## Every tunable number and manifest in the game, loaded from data/*.json.
##
## House rule (carried over from dungeon-platformer): a missing key is a
## hard error, never a silent default. Code reads values through req() so
## a typo in a JSON file fails at the first use with a message naming the
## file and the key, instead of quietly behaving oddly.
##
## F3 (debug_reload) re-reads everything from disk at runtime and emits
## `reloaded`; anything that caches a derived value (SpriteDb, Music)
## listens and rebuilds. Numbers read live through Data.player etc. pick
## the new values up on the next physics frame, which is what makes the
## F1 tuning panel usable without restarting.

signal reloaded

const DATA_DIR := "res://data"

## Top-level documents, one per file. Directories (data/enemies/) become a
## dictionary keyed by file stem.
var player: Dictionary = {}
var items: Dictionary = {}
var objects: Dictionary = {}
var skins: Dictionary = {}
var backgrounds: Dictionary = {}
var music: Dictionary = {}
var sfx: Dictionary = {}
var sprites: Dictionary = {}
var rooms: Dictionary = {}
var enemies: Dictionary = {}
var weapons: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	player = _load("player.json")
	items = _load("items.json")
	objects = _load("objects.json")
	skins = _load("skins.json")
	backgrounds = _load("backgrounds.json")
	music = _load("music.json")
	sfx = _load("sfx.json")
	sprites = _load("sprites.json")
	weapons = _load("weapons.json")
	# data/rooms.json is a build artifact of tools/build_room_registry.gd;
	# a missing file is a warning (fresh checkout), not an error — the
	# registry autoload rebuilds it in-memory from the scenes.
	rooms = _load("rooms.json", false)
	enemies = _load_dir("enemies")
	reloaded.emit()


## Strict key access: `Data.req(Data.player, "run_speed")`.
func req(dict: Dictionary, key: String, ctx: String = "") -> Variant:
	if not dict.has(key):
		var where := ctx if ctx != "" else "data"
		push_error("%s: missing required key '%s'" % [where, key])
		assert(false, "%s: missing required key '%s'" % [where, key])
		return null
	return dict[key]


## Float convenience with the same strictness.
func num(dict: Dictionary, key: String, ctx: String = "") -> float:
	return float(req(dict, key, ctx))


func inum(dict: Dictionary, key: String, ctx: String = "") -> int:
	return int(req(dict, key, ctx))


## Sorted names of a data directory (data/enemies/*.json → species ids).
func dir_names(subdir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open("%s/%s" % [DATA_DIR, subdir])
	if d == null:
		return out
	var files := []
	for f in d.get_files():
		var stem := f.trim_suffix(".remap")
		if stem.ends_with(".json"):
			files.append(stem.trim_suffix(".json"))
	files.sort()
	for f in files:
		out.append(String(f))
	return out


func _load(file: String, required: bool = true) -> Dictionary:
	var path := "%s/%s" % [DATA_DIR, file]
	if not FileAccess.file_exists(path):
		if required:
			push_error("data: %s is missing" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("data: %s is not a JSON object" % path)
		return {}
	return parsed


func _load_dir(subdir: String) -> Dictionary:
	var out := {}
	for stem in dir_names(subdir):
		out[stem] = _load("%s/%s.json" % [subdir, stem])
	return out
