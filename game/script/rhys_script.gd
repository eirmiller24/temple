class_name RhysScript
extends RefCounted
## The Script of Rhys: glyph composer and pixel renderer (design_v2 §11, §14.2).
##
## Text goes in as the sounds of the words, written in a small romanization
## (docs/authoring/script.md has the full table):
##
##     dor              → D·o·R
##     sw'ch            → [S/W]·|·Ch       (two consonants in a row stack)
##     rh's'sth'lseras  → [R/H]·|·S·|·[S/Th]·|·[L/S]·e·R·a·S
##     gems 'over       → G·e·[M/S]·_·'·o·V·e·R   (word breaks per §11.4)
##
## The design doc's own chain notation is valid input too, so
## `[T/R]·e·[N/∅]·[T/R]·a·[K/S]` prints exactly that chain.
##
## Out comes a list of slots per line (`compose`) and an Image (`render`):
## ink on a transparent background, plain register only (§11.1), one
## glyph per slot, stacked clusters at half height, right-to-left or
## top-to-bottom. Glyph shapes, sizes and spacing all live in
## data/script.json, so redesigning a glyph is a data edit (§11.9).
##
## A plain class on purpose: the bake tool (`-s`), the @tool ScriptText
## node and the tests all use it before or without the autoloads.
## Data is read here directly and cached; `reload_data()` re-reads it.

const DATA_PATH := "res://data/script.json"
const NULL_ID := "null"     ## the null glyph: ' in a consonant slot, | in a vowel slot
const SPACE_ID := "_"       ## the underscore space
const EMPTY_LABEL := "∅"
const CLASSES := ["consonant", "vowel", "null", "space"]
const SEPARATORS := [".", "·", "-"]
const HINTS := {
	"c": "write s for a soft c, k for a hard one",
	"q": "write k or kw",
	"x": "write ks or gz",
}

static var _loaded := false
static var _grid := 12.0
static var _layout: Dictionary = {}
static var _render: Dictionary = {}
static var _glyphs: Dictionary = {}     # id -> {cls, w, strokes: Array[PackedFloat32Array], pair_of}
static var _inputs: Dictionary = {}     # typed text -> glyph id
static var _max_input := 1
static var _load_errors := PackedStringArray()


# --- data ---------------------------------------------------------------------

## Re-read data/script.json. Returns false (and push_errors every problem)
## when the file is missing, malformed or lacks a required key.
static func reload_data(path: String = DATA_PATH) -> bool:
	_loaded = true
	_glyphs = {}
	_inputs = {}
	_max_input = 1
	_load_errors = PackedStringArray()
	if not FileAccess.file_exists(path):
		return _bad("%s is missing" % path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return _bad("%s is not a JSON object" % path)
	var d: Dictionary = parsed
	for key in ["grid", "layout", "render", "glyphs"]:
		if not d.has(key):
			_bad("%s: missing required key '%s'" % [path, key])
	if not _load_errors.is_empty():
		return false
	_grid = float(d.grid)
	_layout = d.layout
	_render = d.render
	for key in ["slot_gap", "cluster_gap", "line_gap", "padding_px"]:
		if not _layout.has(key):
			_bad("%s: layout is missing required key '%s'" % [path, key])
	for key in ["height_px", "stroke_px", "ink"]:
		if not _render.has(key):
			_bad("%s: render is missing required key '%s'" % [path, key])
	if _render.has("ink") and not Color.html_is_valid(String(_render.ink)):
		_bad("%s: render.ink '%s' is not a colour" % [path, _render.ink])
	var glyphs: Dictionary = d.glyphs
	for id in glyphs:
		_load_glyph(String(id), glyphs[id], path)
	for id in [NULL_ID, SPACE_ID]:
		if not _glyphs.has(id):
			_bad("%s: glyph '%s' is required" % [path, id])
	if not _load_errors.is_empty():
		_glyphs = {}
		_inputs = {}
		return false
	return true


static func _load_glyph(id: String, g: Variant, path: String) -> void:
	var ctx := "%s: glyph '%s'" % [path, id]
	if typeof(g) != TYPE_DICTIONARY:
		_bad("%s is not an object" % ctx)
		return
	for key in ["class", "input", "w", "strokes"]:
		if not g.has(key):
			_bad("%s: missing required key '%s'" % [ctx, key])
			return
	var cls := String(g["class"])
	if cls not in CLASSES:
		_bad("%s: class '%s' is not one of %s" % [ctx, cls, CLASSES])
		return
	if (id == NULL_ID and cls != "null") or (id == SPACE_ID and cls != "space"):
		_bad("%s: must have class '%s'" % [ctx, "null" if id == NULL_ID else "space"])
		return
	var strokes: Array[PackedFloat32Array] = []
	for s in g.strokes:
		if typeof(s) != TYPE_ARRAY or s.size() < 4 or s.size() % 2 != 0:
			_bad("%s: a stroke must be [x0,y0, x1,y1, ...] with at least two points" % ctx)
			return
		var pts := PackedFloat32Array(s)
		for k in range(0, pts.size(), 2):
			if pts[k] < 0.0 or pts[k] > float(g.w) or pts[k + 1] < 0.0 or pts[k + 1] > _grid:
				_bad("%s: point (%s, %s) is outside its box (x 0..w=%s, y 0..grid=%s)" % [ctx, pts[k], pts[k + 1], g.w, _grid])
				return
		strokes.append(pts)
	_glyphs[id] = {"cls": cls, "w": float(g.w), "strokes": strokes, "pair_of": String(g.get("pair_of", ""))}
	for typed in g.input:
		var t := String(typed).to_lower()
		if t == "" or t in SEPARATORS or t in ["[", "]", "/", "∅"]:
			_bad("%s: '%s' can't be typed as a glyph" % [ctx, t])
		elif _inputs.has(t):
			_bad("%s: input '%s' already means '%s'" % [ctx, t, _inputs[t]])
		else:
			_inputs[t] = id
			_max_input = maxi(_max_input, t.length())


static func _bad(msg: String) -> bool:
	push_error("script data: " + msg)
	_load_errors.append(msg)
	return false


static func _ensure() -> bool:
	if not _loaded:
		reload_data()
	return not _glyphs.is_empty()


static func glyph_ids() -> PackedStringArray:
	_ensure()
	return PackedStringArray(_glyphs.keys())


## {cls, w, strokes, pair_of} for one glyph id, or {} if unknown.
static func glyph(id: String) -> Dictionary:
	_ensure()
	return _glyphs.get(id, {})


static func default_render(key: String) -> Variant:
	_ensure()
	return _render.get(key)


# --- composing: text → slots --------------------------------------------------
#
# A slot is a Dictionary:
#   {"t": "C"|"V", "one": id}             one full-height glyph (or the underscore)
#   {"t": "C", "top": id, "bot": id}      a stacked cluster; "" = an empty half (§11.4)

## Parse `text` into lines of slots. Never fails silently: anything it
## cannot read is in "errors", anything it had to guess is in "warnings".
static func compose(text: String) -> Dictionary:
	var res := {"lines": [], "chain": "", "warnings": [], "errors": []}
	if not _ensure():
		res.errors.append("data/script.json did not load: " + "; ".join(_load_errors))
		return res
	var chains := PackedStringArray()
	for line_text in text.replace("\r", "").replace("\t", " ").split("\n"):
		var line: Array = []
		for word in line_text.split(" ", false):
			var items := _tokenize(word, res)
			if items.is_empty():
				continue
			var slots := _slot_word(items, word, res)
			if slots.is_empty():
				continue
			if line.is_empty():
				line = slots
			else:
				_join(line, slots)
		res.lines.append(line)
		chains.append(chain_string(line))
	res.chain = "\n".join(chains)
	return res


## One word → items: {"k": "ph", "id"} | {"k": "bracket", "top", "bot"} | {"k": "space"}.
## Returns [] after recording an error.
static func _tokenize(word: String, res: Dictionary) -> Array:
	var items := []
	var s := word.to_lower()
	var i := 0
	while i < s.length():
		var c := s[i]
		if c in SEPARATORS:
			i += 1
			continue
		if c == "[":
			var close := s.find("]", i)
			if close < 0:
				res.errors.append("'%s': '[' is never closed" % word)
				return []
			var parts := s.substr(i + 1, close - i - 1).split("/")
			if parts.size() != 2:
				res.errors.append("'%s': a stacked slot is written [top/bottom]" % word)
				return []
			var top: Variant = _bracket_half(parts[0], word, res)
			var bot: Variant = _bracket_half(parts[1], word, res)
			if top == null or bot == null:
				return []
			if top == "" and bot == "":
				res.errors.append("'%s': [∅/∅] is an empty slot — write _ for a space" % word)
				return []
			items.append({"k": "bracket", "top": top, "bot": bot})
			i = close + 1
			continue
		var matched := ""
		for n in range(mini(_max_input, s.length() - i), 0, -1):
			if _inputs.has(s.substr(i, n)):
				matched = s.substr(i, n)
				break
		if matched == "":
			var msg := "'%s': '%s' is not a sound in the script" % [word, c]
			if HINTS.has(c):
				msg += " (%s)" % HINTS[c]
			res.errors.append(msg)
			return []
		var id: String = _inputs[matched]
		items.append({"k": "space"} if _glyphs[id].cls == "space" else {"k": "ph", "id": id})
		i += matched.length()
	return items


## One half of [top/bottom]: a consonant id, "" for an empty half, or null on error.
static func _bracket_half(part: String, word: String, res: Dictionary) -> Variant:
	if part == "" or part == "∅" or part == "-":
		return ""
	var id: String = _inputs.get(part, "")
	if id == "" or _glyphs[id].cls != "consonant":
		res.errors.append("'%s': '%s' can't stand in a stacked slot (consonants only, ∅ or - for empty)" % [word, part])
		return null
	return id


## Lay one word's items onto alternating consonant/vowel slots (§11.1).
static func _slot_word(items: Array, word: String, res: Dictionary) -> Array:
	var slots := []
	var expect := "C"
	var i := 0
	while i < items.size():
		var it: Dictionary = items[i]
		match it.k:
			"space":
				slots.append({"t": expect, "one": SPACE_ID})
				expect = "V" if expect == "C" else "C"
			"bracket":
				# A bottom-only half starts a new chain: it may follow a
				# consonant slot directly. Anything else needs a vowel slot first.
				if expect == "V" and it.top != "":
					_fill_vowel(slots, word, res)
				slots.append({"t": "C", "top": it.top, "bot": it.bot})
				expect = "C" if it.bot == "" else "V"
			"ph":
				var cls: String = _glyphs[it.id].cls
				if cls == "null":
					slots.append({"t": expect, "one": NULL_ID})
					expect = "V" if expect == "C" else "C"
				elif cls == "vowel":
					if expect == "C":
						if not slots.is_empty() and slots[-1].t == "V" and slots[-1].get("one") != SPACE_ID:
							res.warnings.append("'%s': two vowels in a row — inserted a null consonant between them" % word)
						slots.append({"t": "C", "one": NULL_ID})
					slots.append({"t": "V", "one": it.id})
					expect = "C"
				else:
					if expect == "V":
						_fill_vowel(slots, word, res)
					var nxt: Dictionary = items[i + 1] if i + 1 < items.size() else {}
					if nxt.get("k") == "ph" and _glyphs[nxt.id].cls == "consonant":
						slots.append({"t": "C", "top": it.id, "bot": nxt.id})
						i += 1
					else:
						slots.append({"t": "C", "one": it.id})
					expect = "V"
		i += 1
	# The null vowel is never written at either end of a word (Eir,
	# 2026-10-15): '·|·Z ("is") is just Z, Dh·| ("the") is just Dh. A
	# leading one takes its null consonant with it. A word that is nothing
	# but the null vowel ("a") stays '·| (Eir, 2026-10-15).
	if slots.size() > 2 and _is_null_consonant(slots[0]) and _is_null_vowel(slots[1]):
		slots = slots.slice(2)
	if slots.size() >= 2 and _is_null_vowel(slots[-1]) and not (slots.size() == 2 and _is_null_consonant(slots[0])):
		slots.pop_back()
	return slots


## A third consonant in a row has no slot of its own: the chain needs a
## vowel slot first, so the null vowel goes in and the author is told.
static func _fill_vowel(slots: Array, word: String, res: Dictionary) -> void:
	res.warnings.append("'%s': more than two consonants in a row — inserted a null vowel after %s" % [word, _slot_label(slots[-1])])
	slots.append({"t": "V", "one": NULL_ID})


## Join the next word onto a line with the word-break table of §11.4.
static func _join(line: Array, word: Array) -> void:
	var prev: Dictionary = line[-1]
	var first: Dictionary = word[0]
	if _is_space(prev) or _is_space(first) or _is_half(prev) or _is_half(first):
		pass                                                # the author wrote this break by hand
	elif prev.t == "V":
		if _is_null_consonant(first):
			word[0] = {"t": "C", "one": SPACE_ID}           # V·_·V
		elif first.has("one"):
			word[0] = {"t": "C", "top": "", "bot": first.one}   # V·[∅/C] (Eir, 2026-10-15)
		else:
			line.append({"t": "C", "one": NULL_ID})         # V·'·_·[C/C]: a stack has no free half
			line.append({"t": "V", "one": SPACE_ID})
	elif _is_null_consonant(first):
		line.append({"t": "V", "one": SPACE_ID})            # C·_·'·V
	elif prev.has("one"):
		line[-1] = {"t": "C", "top": prev.one, "bot": ""}   # [C/∅]·C
	elif first.has("one"):
		word[0] = {"t": "C", "top": "", "bot": first.one}   # [C/C]·[∅/C]
	else:
		line.append({"t": "V", "one": SPACE_ID})            # [C/C]·_·[C/C]
	line.append_array(word)


static func _is_space(s: Dictionary) -> bool:
	return s.get("one") == SPACE_ID


static func _is_half(s: Dictionary) -> bool:
	return s.has("top") and (s.top == "" or s.bot == "")


static func _is_null_consonant(s: Dictionary) -> bool:
	return s.t == "C" and s.get("one") == NULL_ID


static func _is_null_vowel(s: Dictionary) -> bool:
	return s.t == "V" and s.get("one") == NULL_ID


## Slots in the design doc's chain notation: [R/H]·|·S.
static func chain_string(slots: Array) -> String:
	var parts := PackedStringArray()
	for s in slots:
		parts.append(_slot_label(s))
	return "·".join(parts)


static func _slot_label(s: Dictionary) -> String:
	if s.has("one"):
		if s.one == NULL_ID:
			return "'" if s.t == "C" else "|"
		return String(s.one)
	return "[%s/%s]" % [_half_label(s.top), _half_label(s.bot)]


static func _half_label(id: String) -> String:
	if id == "":
		return EMPTY_LABEL
	return "'" if id == NULL_ID else id


# --- rendering: slots → pixels ------------------------------------------------

## compose() + an Image. Options (all optional; defaults from data/script.json
## `render`): height_px, stroke_px, padding_px, color (Color), orientation
## ("rtl" | "ttb"), align ("start" | "center" | "end", where start is the
## side reading begins on). Adds "image" (null when there were errors).
static func render(text: String, opts: Dictionary = {}) -> Dictionary:
	var res := compose(text)
	res["image"] = null
	if res.errors.is_empty():
		res["image"] = render_lines(res.lines, opts)
	return res


static func render_lines(lines: Array, opts: Dictionary = {}) -> Image:
	if not _ensure():
		return null
	var m := _metrics(opts)
	var widths: Array[int] = []
	var max_w := 0
	for line in lines:
		var w := _line_width(line, m)
		widths.append(w)
		max_w = maxi(max_w, w)
	var pad: int = m.pad
	var line_h: int = m.line_h
	var img_w := maxi(1, max_w + 2 * pad)
	var img_h := maxi(1, lines.size() * line_h + maxi(0, lines.size() - 1) * m.line_gap + 2 * pad)
	var img := Image.create_empty(img_w, img_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var align := String(opts.get("align", "start"))
	for li in lines.size():
		var top: int = pad + li * (line_h + m.line_gap)
		# Right-to-left: the first slot sits at the right edge of the line.
		var right: int
		match align:
			"end":
				right = pad + widths[li]
			"center":
				right = pad + max_w - (max_w - widths[li]) / 2
			_:
				right = pad + max_w
		for s in lines[li]:
			var sw := _slot_width(s, m)
			var left := right - sw
			if s.has("one"):
				_draw_glyph(img, s.one, left + (sw - _glyph_px_w(s.one, m.k_full, m)) / 2, top, m.k_full, m)
			else:
				if s.top != "":
					_draw_glyph(img, s.top, left + (sw - _glyph_px_w(s.top, m.k_half, m)) / 2, top, m.k_half, m)
				if s.bot != "":
					_draw_glyph(img, s.bot, left + (sw - _glyph_px_w(s.bot, m.k_half, m)) / 2, top + m.half_off, m.k_half, m)
			right = left - m.gap
	if String(opts.get("orientation", "rtl")) == "ttb":
		# §11.1: top-to-bottom is the same writing turned 90° counterclockwise,
		# so the first slot ends up on top and stacks sit side by side.
		img.rotate_90(COUNTERCLOCKWISE)
	return img


## Every glyph, for checking shapes at a pixel size (§11.9 rule 4): one row
## per consonant pair (base, then +base stroke) at full and half height,
## then the vowels, then the null glyph and the underscore.
static func render_chart(opts: Dictionary = {}) -> Image:
	if not _ensure():
		return null
	var rows: Array = []    # each row: Array of [id, k] cells; "" = blank cell
	var paired := {}
	for id in _glyphs:
		if _glyphs[id].pair_of != "" and _glyphs[id].cls == "consonant":
			paired[_glyphs[id].pair_of] = id
	var m := _metrics(opts)
	for id in _glyphs:
		var g: Dictionary = _glyphs[id]
		if g.cls != "consonant" or g.pair_of != "":
			continue
		var mate: String = paired.get(id, "")
		rows.append([[id, "full"], [mate, "full"], ["", ""], [id, "half"], [mate, "half"]])
	var vowels := []
	for id in _glyphs:
		if _glyphs[id].cls == "vowel":
			vowels.append([id, "full"])
	rows.append(vowels)
	var y_pair: String = paired.get(NULL_ID, "")
	rows.append([[NULL_ID, "full"], [y_pair, "full"], ["", ""], [SPACE_ID, "full"]])
	var cell_w := 0
	for id in _glyphs:
		cell_w = maxi(cell_w, _glyph_px_w(id, m.k_full, m))
	cell_w += m.gap
	var cols := 0
	for r in rows:
		cols = maxi(cols, r.size())
	var img := Image.create_empty(cols * cell_w + 2 * m.pad, rows.size() * (m.line_h + m.line_gap) + 2 * m.pad, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for ri in rows.size():
		var top: int = m.pad + ri * (m.line_h + m.line_gap)
		for ci in rows[ri].size():
			var id: String = rows[ri][ci][0]
			if id == "":
				continue
			var left: int = m.pad + ci * cell_w
			if rows[ri][ci][1] == "half":
				_draw_glyph(img, id, left, top, m.k_half, m)
			else:
				_draw_glyph(img, id, left, top, m.k_full, m)
	return img


## Pixel metrics for one render. k_full / k_half are pixels per grid unit.
static func _metrics(opts: Dictionary) -> Dictionary:
	var h := maxi(3, int(opts.get("height_px", _render.height_px)))
	var stroke := maxi(1, int(opts.get("stroke_px", _render.stroke_px)))
	var k_full := (h - 1) / _grid
	var cluster_gap := roundi(float(_layout.cluster_gap) * k_full)
	if float(_layout.cluster_gap) > 0.0:
		cluster_gap = maxi(1, cluster_gap)
	var half_h := maxi(2, (h - cluster_gap) / 2)
	var color: Color = opts.get("color", Color.html(String(_render.ink)))
	return {
		"h": h,
		"stroke": stroke,
		"k_full": k_full,
		"k_half": (half_h - 1) / _grid,
		"half_off": h - half_h,
		"gap": maxi(1, roundi(float(_layout.slot_gap) * k_full)),
		"line_gap": maxi(0, roundi(float(_layout.line_gap) * k_full)),
		"line_h": h + stroke - 1,
		"pad": maxi(0, int(opts.get("padding_px", _layout.padding_px))),
		"color": color,
	}


static func _glyph_px_w(id: String, k: float, m: Dictionary) -> int:
	return roundi(_glyphs[id].w * k) + m.stroke


static func _slot_width(s: Dictionary, m: Dictionary) -> int:
	if s.has("one"):
		return _glyph_px_w(s.one, m.k_full, m)
	var w := 0
	for id in [s.top, s.bot]:
		if id != "":
			w = maxi(w, _glyph_px_w(id, m.k_half, m))
	return w


static func _line_width(line: Array, m: Dictionary) -> int:
	if line.is_empty():
		return 0
	var w: int = (line.size() - 1) * m.gap
	for s in line:
		w += _slot_width(s, m)
	return w


static func _draw_glyph(img: Image, id: String, ox: int, oy: int, k: float, m: Dictionary) -> void:
	for st in _glyphs[id].strokes:
		var pts: PackedFloat32Array = st
		for p in range(0, pts.size() - 2, 2):
			_line(img,
				ox + roundi(pts[p] * k), oy + roundi(pts[p + 1] * k),
				ox + roundi(pts[p + 2] * k), oy + roundi(pts[p + 3] * k),
				m.stroke, m.color)


## Bresenham, with a stroke×stroke brush growing right and down.
static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, stroke: int, color: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var w := img.get_width()
	var h := img.get_height()
	while true:
		for bx in stroke:
			for by in stroke:
				var px := x0 + bx
				var py := y0 + by
				if px >= 0 and py >= 0 and px < w and py < h:
					img.set_pixel(px, py, color)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
