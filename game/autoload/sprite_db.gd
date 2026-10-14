extends Node
## data/sprites.json → SpriteFrames. One manifest drives every animated
## unit (player, enemies, objects), so swapping placeholder art for real
## art is a path edit in the manifest and nothing else.
##
## Entry schema (data/sprites.json → <section>.<id>):
##   frame_w / frame_h   cell size on the sheet (required)
##   ground_y            row the feet stand on, in cell px (default frame_h)
##   body_h              real body height in px; owners fit to it (default frame_h)
##   faces_left          true when the art faces -x (default false)
##   scale               extra draw scale (default 1.0)
##   sheet               default sheet for clips that don't name their own
##   clips.<name>        {sheet?, row (default 0), frames (int or [i,...]),
##                        fps (default 8), loop (default false)}
##
## A sheet whose file is missing warns and the clip is skipped — the game
## never fails to boot over art (fallback all the way down).

var _cache := {}  # "section/id" -> Dictionary(entry+frames)


func _ready() -> void:
	Data.reloaded.connect(func() -> void: _cache.clear())


## Returns {frames: SpriteFrames, frame_w, frame_h, ground_y, body_h,
## faces_left, scale, clips: [names]} or an empty dict if the id is
## unknown (push_warning'd once).
func entry(section: String, id: String) -> Dictionary:
	var key := "%s/%s" % [section, id]
	if _cache.has(key):
		return _cache[key]
	var sec: Dictionary = Data.sprites.get(section, {})
	if not sec.has(id):
		push_warning("sprites.json: no entry %s" % key)
		_cache[key] = {}
		return {}
	var src: Dictionary = sec[id]
	var fw := Data.inum(src, "frame_w", key)
	var fh := Data.inum(src, "frame_h", key)
	var out := {
		"frame_w": fw, "frame_h": fh,
		"ground_y": int(src.get("ground_y", fh)),
		"body_h": int(src.get("body_h", fh)),
		"faces_left": bool(src.get("faces_left", false)),
		"scale": float(src.get("scale", 1.0)),
		"frames": SpriteFrames.new(),
		"clips": [],
	}
	var frames: SpriteFrames = out.frames
	frames.remove_animation("default")
	var default_sheet := String(src.get("sheet", ""))
	var clips: Dictionary = Data.req(src, "clips", key)
	for clip_name: String in clips:
		var c: Dictionary = clips[clip_name]
		var sheet_path := String(c.get("sheet", default_sheet))
		if sheet_path == "" or not ResourceLoader.exists(sheet_path):
			push_warning("sprites.json %s.%s: sheet '%s' not found" % [key, clip_name, sheet_path])
			continue
		var tex: Texture2D = load(sheet_path)
		var row := int(c.get("row", 0))
		var idx: Array = []
		var f: Variant = c.get("frames", 1)
		if typeof(f) == TYPE_ARRAY:
			idx = f
		else:
			for i in int(f):
				idx.append(i)
		frames.add_animation(clip_name)
		frames.set_animation_speed(clip_name, float(c.get("fps", 8)))
		frames.set_animation_loop(clip_name, bool(c.get("loop", false)))
		for i: Variant in idx:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(int(i) * fw, row * fh, fw, fh)
			frames.add_frame(clip_name, at)
		out.clips.append(clip_name)
	_cache[key] = out
	return out


## Wire an AnimatedSprite2D so its feet sit on the owner's origin and it
## renders `fit_tiles` tall (0 = use the entry's own scale only).
func apply(sprite: AnimatedSprite2D, section: String, id: String,
		fit_tiles: float = 0.0) -> Dictionary:
	var e := entry(section, id)
	if e.is_empty():
		return e
	sprite.sprite_frames = e.frames
	sprite.centered = false
	var s: float = e.scale
	if fit_tiles > 0.0 and e.body_h > 0:
		s = fit_tiles * Room.TILE / float(e.body_h)
	sprite.scale = Vector2(s, s)
	sprite.offset = Vector2(-e.frame_w / 2.0, -float(e.ground_y))
	if e.clips.has("idle"):
		sprite.play("idle")
	elif not e.clips.is_empty():
		sprite.play(e.clips[0])
	return e


## Play `clip` if the sheet has it, else the first of `fallbacks` that
## exists. Returns the clip actually played ("" if none).
func play(sprite: AnimatedSprite2D, clip: String, fallbacks: Array = []) -> String:
	if sprite.sprite_frames == null:
		return ""
	var chain: Array = [clip]
	chain.append_array(fallbacks)
	for c: String in chain:
		if sprite.sprite_frames.has_animation(c):
			if sprite.animation != c or not sprite.is_playing():
				sprite.play(c)
			return c
	return ""
