extends Node
## Asset lint (assets/SOURCES.md, CLAUDE.md "AI-generated art"):
##   (a) every texture / stream path the manifests under data/ reference exists;
##   (b) every such path is either quarantined under assets/ai_placeholder/
##       or its file (or its folder) is named in some assets/**/SOURCES.md —
##       nothing ships without a sources line;
##   (c) every png/wav/ogg under assets/ai_placeholder/ has an entry in its
##       folder's ai_provenance.json;
##   (d) data/skins.json: greybox stays tileset-less; every other skin's
##       tileset loads and every terrain mapping names an existing terrain
##       set/terrain or an existing atlas tile.
##
##   godot --headless --path . res://tests/test_assets.tscn
##
## Tests are SCENES, not `-s` scripts (see tests/test_boot.gd). This one
## touches no autoload on purpose: it reads the JSON itself so it also runs
## when the data autoload is broken. Exit code 1 on any failed check.

const MANIFESTS := ["res://data/sprites.json", "res://data/skins.json",
		"res://data/backgrounds.json", "res://data/music.json", "res://data/sfx.json"]
const AI_ROOT := "res://assets/ai_placeholder/"
const AI_EXTS := ["png", "wav", "ogg"]

var _fails := 0


func _ready() -> void:
	var code := await _run()
	get_tree().quit(code)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error("CHECK FAILED: " + msg)
		_fails += 1
	else:
		print("  ok: ", msg)


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Every "res://..." string anywhere in a JSON value.
func _collect_paths(v: Variant, out: Dictionary) -> void:
	match typeof(v):
		TYPE_DICTIONARY:
			for k in v:
				_collect_paths(v[k], out)
		TYPE_ARRAY:
			for e in v:
				_collect_paths(e, out)
		TYPE_STRING:
			if String(v).begins_with("res://"):
				out[String(v)] = true


func _walk(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if n != "." and n != "..":
			var p := dir_path.path_join(n)
			if d.current_is_dir():
				_walk(p, out)
			else:
				out.append(p)
		n = d.get_next()
	d.list_dir_end()


func _run() -> int:
	await get_tree().process_frame

	# --- (a) manifest paths exist -------------------------------------------------------
	var refs := {}
	for m in MANIFESTS:
		var parsed: Variant = _read_json(m)
		_check(typeof(parsed) == TYPE_DICTIONARY, "%s parses" % m)
		if typeof(parsed) == TYPE_DICTIONARY:
			_collect_paths(parsed, refs)
	var ref_list := refs.keys()
	ref_list.sort()
	var missing := []
	for p: String in ref_list:
		if not FileAccess.file_exists(p):
			missing.append(p)
	_check(missing.is_empty(), "all %d manifest paths exist (missing: %s)" % [ref_list.size(), str(missing)])

	# --- (b) AI quarantine or a SOURCES.md line ---------------------------------------------
	var all_files: Array[String] = []
	_walk("res://assets", all_files)
	var sources_text := ""
	for f in all_files:
		if f.get_file() == "SOURCES.md":
			sources_text += "\n" + FileAccess.get_file_as_string(f)
	_check(sources_text.length() > 0, "assets/**/SOURCES.md files found")
	var unsourced := []
	for p: String in ref_list:
		if p.begins_with(AI_ROOT):
			continue
		if not _is_sourced(p, sources_text):
			unsourced.append(p)
	_check(unsourced.is_empty(), "every manifest path is quarantined or has a SOURCES.md line (unsourced: %s)" % str(unsourced))

	# --- (c) ai_provenance.json covers every file under ai_placeholder ------------------------
	var ai_files := 0
	var unrecorded := []
	var prov_cache := {}
	for f in all_files:
		if not f.begins_with(AI_ROOT) or not (f.get_extension() in AI_EXTS):
			continue
		ai_files += 1
		var folder := f.get_base_dir()
		if not prov_cache.has(folder):
			prov_cache[folder] = _provenance_files(folder.path_join("ai_provenance.json"))
		if not (f.get_file() in prov_cache[folder]):
			unrecorded.append(f)
	_check(unrecorded.is_empty(), "every file under ai_placeholder/ has a provenance entry (%d files; unrecorded: %s)" % [ai_files, str(unrecorded)])

	# --- (d) skins -------------------------------------------------------------------------------------
	var skins: Variant = _read_json("res://data/skins.json")
	if typeof(skins) == TYPE_DICTIONARY:
		_check(skins.has("greybox") and not (skins.greybox as Dictionary).has("tileset"),
				"skins.json: greybox exists and stays tileset-less")
		for name: String in skins:
			if name.begins_with("_"):
				continue
			var skin: Dictionary = skins[name]
			_check(skin.has("tile_tint"), "skin '%s' has tile_tint" % name)
			if not skin.has("tileset"):
				continue
			var ts_path := String(skin.tileset)
			var ts: TileSet = load(ts_path) if ResourceLoader.exists(ts_path) else null
			_check(ts != null, "skin '%s': tileset %s loads" % [name, ts_path])
			if ts == null:
				continue
			var terrains: Dictionary = skin.get("terrains", {})
			for kind: String in terrains:
				var m: Variant = terrains[kind]
				if typeof(m) == TYPE_ARRAY and m.size() == 2:
					var set_i := int(m[0])
					var terr_i := int(m[1])
					var ok := set_i >= 0 and set_i < ts.get_terrain_sets_count() \
							and terr_i >= 0 and terr_i < ts.get_terrains_count(set_i)
					_check(ok, "skin '%s' %s -> terrain set %d terrain %d exists%s" % [name, kind, set_i, terr_i,
							(" ('%s')" % ts.get_terrain_name(set_i, terr_i)) if ok else ""])
				elif typeof(m) == TYPE_DICTIONARY and m.has("atlas"):
					var a: Array = m.atlas
					var ok := false
					if a.size() == 3 and ts.has_source(int(a[0])):
						var src := ts.get_source(int(a[0])) as TileSetAtlasSource
						ok = src != null and src.has_tile(Vector2i(int(a[1]), int(a[2])))
					_check(ok, "skin '%s' %s -> atlas tile %s exists" % [name, kind, str(a)])
				else:
					_check(false, "skin '%s' %s: mapping must be [set, terrain] or {\"atlas\": [src, x, y]} (got %s)" % [name, kind, str(m)])
	else:
		_check(false, "data/skins.json parses")

	print("test_assets: %d failures" % _fails)
	return 1 if _fails > 0 else 0


## A path is "sourced" when its file name, its folder (relative to the
## project) or its folder's own name appears in some SOURCES.md.
func _is_sourced(p: String, sources_text: String) -> bool:
	var rel := p.trim_prefix("res://")
	var dir := rel.get_base_dir()
	if sources_text.contains(rel.get_file()):
		return true
	if dir != "" and (sources_text.contains(dir + "/") or sources_text.contains(dir.get_file() + "/")):
		return true
	return false


func _provenance_files(path: String) -> Dictionary:
	var out := {}
	var parsed: Variant = _read_json(path)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("entries"):
		push_error("%s missing or has no 'entries' array" % path)
		return out
	for e in parsed.entries:
		if typeof(e) == TYPE_DICTIONARY and e.has("file"):
			out[String(e.file)] = true
			for key in ["tool", "method", "prompt", "ids", "date", "origin"]:
				if not e.has(key):
					push_warning("%s: entry %s lacks '%s'" % [path, e.file, key])
	return out
