extends Node
## The Script of Rhys composer and renderer (game/script/rhys_script.gd,
## data/script.json):
##   - every example chain in design_v2 §11 comes out of its phonetic
##     spelling, and the doc's chain notation reads back unchanged;
##   - each row of the §11.4 word-break table;
##   - what it refuses (letters that aren't sounds) and what it guesses
##     (a third consonant, two vowels) is reported, never silent;
##   - every glyph draws inside its own box, at full and half height, at
##     the default size and at 13 px;
##   - top-to-bottom is the right-to-left image turned counterclockwise;
##   - a ScriptText node renders, shows its chain and warns on bad text.
##
##   godot --headless --path . res://tests/test_script.tscn

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


func _chain(text: String) -> String:
	return RhysScript.compose(text).chain


func _run() -> int:
	await get_tree().process_frame
	_check(RhysScript.reload_data(), "data/script.json loads")

	# --- design_v2 §11 examples ------------------------------------------------
	var examples := {
		"dor": "D·o·R",                                         # §11.5 Door
		"sef": "S·e·F",                                         # Safe
		"sw'ch": "[S/W]·|·Ch",                                  # Switch
		"rh's": "[R/H]·|·S",                                    # Rhys
		"'over": "'·o·V·e·R",                                   # §11.3 over
		"over": "'·o·V·e·R",                                    # the null consonant is implied
		"chen.g": "Ch·e·[N/G]",                                 # "chang"
		"rh's'sth'lseras": "[R/H]·|·S·|·[S/Th]·|·[L/S]·e·R·a·S",  # §11.6, 11 slots
		"tren traks": "[T/R]·e·[N/∅]·[T/R]·a·[K/S]",            # §11.4 train tracks
		"gems 'over": "G·e·[M/S]·_·'·o·V·e·R",                  # §11.4 Games over
	}
	for t in examples:
		_check(_chain(t) == examples[t], "%s → %s (got %s)" % [t, examples[t], _chain(t)])
	for c in ["[R/H]·|·S", "[T/R]·e·[N/∅]·[T/R]·a·[K/S]", "G·e·[M/S]·_·'·o·V·e·R", "[R/H]·|·S·|·[S/Th]·|·[L/S]·e·R·a·S"]:
		_check(_chain(c) == c, "chain notation reads back unchanged: %s" % c)
	_check(_chain("RH'S") == "[R/H]·|·S", "input is case-insensitive")
	_check(_chain("s.h") == "[S/H]" and _chain("sh") == "Sh", "'.' splits a digraph (s.h is S+H, sh is Sh)")
	_check(_chain("widh") == _chain("width"), "dth is typed as Dh too (script.xcf's label)")
	_check(RhysScript.compose("rh's'sth'lseras").lines[0].size() == 11, "the god's name is 11 slots")

	# --- §11.4 word breaks, one row each ----------------------------------------
	_check(_chain("dor sef") == "D·o·[R/∅]·S·e·F", "single consonant → consonant: [C/∅]")
	_check(_chain("traks dor") == "[T/R]·a·[K/S]·[∅/D]·o·R", "cluster → single consonant: [∅/C]")
	_check(_chain("traks tren") == "[T/R]·a·[K/S]·_·[T/R]·e·N", "cluster → cluster: underscore")
	_check(_chain("sa 'o") == "S·a·_·o", "vowel → vowel: underscore in the consonant slot")
	_check(_chain("dor 'over") == "D·o·R·_·'·o·V·e·R", "consonant → vowel: underscore, then the null consonant")
	_check(_chain("sa dor") == "S·a·[∅/D]·o·R", "vowel → single consonant: [∅/C] (Eir, 2026-10-15)")
	_check(_chain("tu bi") == "T·u·[∅/B]·i", "'to be' is T·u·[∅/B]·i")
	_check(_chain("sa traks") == "S·a·'·_·[T/R]·a·[K/S]", "vowel → stack: null consonant, then underscore (placeholder)")
	_check(_chain("dor\nsef") == "D·o·R\nS·e·F", "a new line starts a fresh chain")

	# --- the null vowel is dropped at either end of a word (Eir, 2026-10-15) ---
	_check(_chain("'|z") == "Z" and _chain("dh|") == "Dh", "'is' is Z and 'the' is Dh")
	_check(_chain("'|fily|") == "F·i·[L/Y]", "both ends of 'Ophelia' drop")
	_check(_chain("bi dhat '|z dh| kwesch|n") == "B·i·[∅/Dh]·a·[T/∅]·[Z/∅]·[Dh/∅]·[K/W]·e·[S/Ch]·|·N",
		"'be that is the question' (Eir's example)")
	_check(_chain("'|") == "'", "'a' is just the null consonant (Eir, 2026-10-15)")
	_check(_chain("f|ng|g|rz '| gret") == "F·|·[N/G]·|·G·|·[R/Z]·[∅/']·[G/R]·e·T", "'fingers a great': a takes a half-slot like any one-consonant word")
	_check(_chain("bi '|") == "B·i·[∅/']", "'be a': vowel → a")
	_check(_chain("rh's'") == "[R/H]·|·S", "the pillar syllable Rhys' is [R/H]·|·S (§11.6)")
	_check(_chain("t '| si") == "[T/∅]·['/∅]·S·i", "'…t a sea' keeps the article")
	_check(_chain("'| dor") == "['/∅]·D·o·R", "the article before a consonant")
	_check(_chain("'| 'over") == "'·_·'·o·V·e·R", "the article before a vowel-initial word")
	_check(_chain("strong").begins_with("[S/T]·|·R"), "a null vowel inside a word stays")

	# --- refused and guessed ----------------------------------------------------
	for bad in ["xylo", "cat", "qi", "[r/h", "[a/r]", "[∅/∅]", "dor!"]:
		var r := RhysScript.render(bad)
		_check(not r.errors.is_empty() and r.image == null, "refuses %s: %s" % [bad, r.errors])
	var strong := RhysScript.compose("strong")
	_check(strong.chain == "[S/T]·|·R·o·[N/G]" and strong.warnings.size() == 1, "a third consonant gets a null vowel and a warning")
	var hiatus := RhysScript.compose("a.i")
	_check(hiatus.chain == "'·a·'·i" and hiatus.warnings.size() == 1, "two vowels get a null consonant and a warning")
	_check(RhysScript.compose("dor sef").warnings.is_empty(), "ordinary text has no warnings")

	# --- glyph drawing ----------------------------------------------------------
	for h in [int(RhysScript.default_render("height_px")), 13]:
		var bad_glyphs := []
		for id in RhysScript.glyph_ids():
			for half in [false, true]:
				if half and RhysScript.glyph(id).cls != "consonant":
					continue
				var text := "[%s/∅]" % id if half else id
				if id == RhysScript.NULL_ID:
					text = "'"
				var r := RhysScript.render(text, {"height_px": h, "padding_px": 0})
				var img: Image = r.image
				var used := img.get_used_rect() if img != null else Rect2i()
				var ok := used.size != Vector2i.ZERO
				if RhysScript.glyph(id).cls in ["consonant", "null"]:
					# Full consonants span the slot; a half stays in its half.
					ok = ok and (used.end.y <= (h + 1) / 2 if half else used.size.y == h)
				if not ok:
					bad_glyphs.append("%s%s" % [id, " (half)" if half else ""])
		_check(bad_glyphs.is_empty(), "every glyph draws; consonants span their slot or their half at %d px %s" % [h, bad_glyphs])
	var full: Image = RhysScript.render("S", {"height_px": 25, "padding_px": 0}).image
	_check(full.get_height() == 25, "a full glyph is height_px tall")
	var ink: Color = full.get_pixel(0, 0)
	_check(ink == Color.html(String(RhysScript.default_render("ink"))), "ink is render.ink (S's stem starts at the top-left)")
	_check(full.get_pixel(full.get_width() - 1, 0).a == 0.0, "background is transparent")
	var red: Image = RhysScript.render("S", {"color": Color.RED, "padding_px": 0}).image
	_check(red.get_pixel(0, 0) == Color.RED, "color option recolours the ink")
	var thick: Image = RhysScript.render("S", {"height_px": 25, "stroke_px": 2, "padding_px": 0}).image
	_check(thick.get_height() == 26, "a 2 px stroke grows the glyph by one pixel")

	# --- orientation and determinism -------------------------------------------
	var rtl: Image = RhysScript.render("dor sef\nsw'ch", {}).image
	var ttb: Image = RhysScript.render("dor sef\nsw'ch", {"orientation": "ttb"}).image
	var turned: Image = rtl.duplicate()
	turned.rotate_90(COUNTERCLOCKWISE)
	_check(ttb.get_size() == Vector2i(rtl.get_height(), rtl.get_width()), "ttb swaps width and height")
	_check(ttb.get_data() == turned.get_data(), "ttb is rtl turned 90° counterclockwise")
	_check(RhysScript.render("dor sef\nsw'ch", {}).image.get_data() == rtl.get_data(), "rendering is deterministic")
	# Right to left: the first slot (D) is at the right edge of the line.
	var d_only: Image = RhysScript.render("D", {"padding_px": 0}).image
	var dor: Image = RhysScript.render("dor", {"padding_px": 0}).image
	_check(dor.get_region(Rect2i(dor.get_width() - d_only.get_width(), 0, d_only.get_width(), d_only.get_height())).get_data() == d_only.get_data(),
		"right to left: the first slot is drawn at the right edge")
	_check(RhysScript.render_chart({}) != null, "glyph chart renders")

	# --- the node ---------------------------------------------------------------
	var node := ScriptText.new()
	node.text = "rh's"
	add_child(node)
	_check(node.texture != null and node.chain == "[R/H]·|·S", "ScriptText renders and shows its chain")
	_check(node._get_configuration_warnings().is_empty(), "ScriptText has no warnings for good text")
	node.text = "xylo"
	_check(node.texture == null and not node._get_configuration_warnings().is_empty(), "ScriptText warns on text it can't read")
	node.text = "dor"
	node.orientation = "ttb"
	_check(node.texture != null and node.texture.get_width() < node.texture.get_height(), "ScriptText follows orientation")
	node.queue_free()

	print("test_script: %d failures" % _fails)
	return 1 if _fails > 0 else 0
