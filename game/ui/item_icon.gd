class_name UiItemIcon
extends RefCounted
## Item icons: data/sprites.json → icons.<item id>.texture, a SIZE×SIZE
## image drawn at an integer scale. null when an item has no icon (the
## cell shows its name) or the file is missing (pending or purged art —
## deleting assets/ai_placeholder/ must never break the menu).

const SIZE := 32

static var _cache := {}


static func texture(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var tex: Texture2D = null
	var entry: Variant = (Data.sprites.get("icons", {}) as Dictionary).get(id)
	if entry is Dictionary:
		var path := String(entry.get("texture", ""))
		if path != "" and ResourceLoader.exists(path):
			tex = load(path)
		elif path != "":
			push_warning("sprites.json icons.%s: missing %s" % [id, path])
	_cache[id] = tex
	return tex


static func clear_cache() -> void:
	_cache.clear()
