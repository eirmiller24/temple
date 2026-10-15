extends SceneTree
## Bakes text in the Script of Rhys to PNG: ink on a transparent
## background (black unless --color says otherwise), plain register,
## pixel strokes. Prints the slot chain it read, and every guess it made.
##
##   godot --headless --path . -s res://tools/bake_script.gd -- "rh's'sth'lseras"
##   godot --headless --path . -s res://tools/bake_script.gd -- "dor" --out res://assets/script/door.png
##   godot --headless --path . -s res://tools/bake_script.gd -- "dor sef\nsw'ch" --ttb --height 13
##   godot --headless --path . -s res://tools/bake_script.gd -- --batch inscriptions.txt --out-dir res://assets/script
##   godot --headless --path . -s res://tools/bake_script.gd -- --chart --height 13 --scale 4
##   godot --headless --path . -s res://tools/bake_script.gd -- --chain "gems 'over"
##
## Options (defaults from data/script.json `render` and `layout`):
##   --out PATH        PNG to write (res://, user:// or absolute). Default
##                     user://script/<text>.png — nothing lands in the repo
##                     unless you say so.
##   --out-dir DIR     where --batch and --chart write (default user://script)
##   --height N        slot height in px. 12k+1 (13, 25, 37) puts every grid point on a pixel.
##   --stroke N        stroke width in px
##   --padding N       transparent border in px
##   --color RRGGBB[AA]  ink colour
##   --ttb             top-to-bottom (the rtl image turned 90° counterclockwise)
##   --align start|center|end   line alignment; start = where reading begins
##   --scale N         upscale the result N× (nearest) — for looking at, not for the game
##   --batch FILE      one inscription per line, "name: text"; # comments; \n = new line
##   --chart           every glyph at full and half height (§11.9 rule 4 check)
##   --chain           print the chain only, write nothing
##
## Text: the sounds, not the spelling — docs/authoring/script.md. `\n` in an
## argument is a line break. Exit code 1 if any text could not be read.


func _init() -> void:
	# Same pattern as build_room_registry.gd: let the autoloads come up first.
	await process_frame
	quit(_run(OS.get_cmdline_user_args()))


func _run(args: PackedStringArray) -> int:
	if not RhysScript.reload_data():
		return 1
	var opts := {}
	var texts: Array[String] = []
	var out := ""
	var out_dir := "user://script"
	var batch := ""
	var scale := 1
	var chart := false
	var chain_only := false
	var i := 0
	while i < args.size():
		var a := args[i]
		var needs_value := a in ["--out", "--out-dir", "--height", "--stroke", "--padding", "--color", "--align", "--scale", "--batch"]
		if needs_value and i + 1 >= args.size():
			return _usage("%s needs a value" % a)
		var v := args[i + 1] if needs_value else ""
		match a:
			"--out": out = v
			"--out-dir": out_dir = v
			"--height": opts.height_px = v.to_int()
			"--stroke": opts.stroke_px = v.to_int()
			"--padding": opts.padding_px = v.to_int()
			"--scale": scale = maxi(1, v.to_int())
			"--batch": batch = v
			"--align":
				if v not in ["start", "center", "end"]:
					return _usage("--align is start, center or end")
				opts.align = v
			"--color":
				if not Color.html_is_valid(v):
					return _usage("--color %s is not RRGGBB or RRGGBBAA" % v)
				opts.color = Color.html(v)
			"--ttb": opts.orientation = "ttb"
			"--rtl": opts.orientation = "rtl"
			"--chart": chart = true
			"--chain": chain_only = true
			"--help", "-h": return _usage("")
			_:
				if a.begins_with("--"):
					return _usage("unknown option %s" % a)
				texts.append(a.replace("\\n", "\n"))
		i += 2 if needs_value else 1

	if chart:
		var img := RhysScript.render_chart(opts)
		var h := int(opts.get("height_px", RhysScript.default_render("height_px")))
		return _save(img, out if out != "" else "%s/chart_%dpx.png" % [out_dir, h], scale)

	var jobs: Array = []     # [name_or_path, text, explicit_path]
	if batch != "":
		var f := FileAccess.open(batch, FileAccess.READ)
		if f == null:
			return _usage("can't read %s" % batch)
		var n := 0
		while not f.eof_reached():
			n += 1
			var line := f.get_line().strip_edges()
			if line == "" or line.begins_with("#"):
				continue
			var colon := line.find(":")
			if colon <= 0:
				push_error("%s:%d: expected 'name: text'" % [batch, n])
				return 1
			jobs.append(["%s/%s.png" % [out_dir, line.substr(0, colon).strip_edges()], line.substr(colon + 1).strip_edges().replace("\\n", "\n")])
	for t in texts:
		jobs.append([out if out != "" and texts.size() == 1 else "%s/%s.png" % [out_dir, _slug(t)], t])
	if jobs.is_empty():
		return _usage("nothing to bake")

	var failed := 0
	for job in jobs:
		var res := RhysScript.render(job[1], opts)
		print("%s\n  %s" % [job[1].replace("\n", " / "), res.chain.replace("\n", "\n  ")])
		for w in res.warnings:
			print("  warning: ", w)
		for e in res.errors:
			push_error(e)
		if not res.errors.is_empty():
			failed += 1
			continue
		if not chain_only and _save(res.image, job[0], scale) != 0:
			failed += 1
	return 1 if failed > 0 else 0


func _save(img: Image, path: String, scale: int) -> int:
	if img == null:
		return 1
	if scale > 1:
		img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err := img.save_png(abs_path)
	if err != OK:
		push_error("could not write %s (%s)" % [abs_path, error_string(err)])
		return 1
	print("  wrote %s (%dx%d)" % [abs_path, img.get_width(), img.get_height()])
	return 0


static func _slug(t: String) -> String:
	var out := ""
	for c in t.to_lower():
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "_"
	return out.left(40) if out.strip_edges() != "" else "text"


func _usage(msg: String) -> int:
	if msg != "":
		push_error(msg)
	print("usage: godot --headless --path . -s res://tools/bake_script.gd -- [options] \"text\" ...")
	print("       (see the header of tools/bake_script.gd for options)")
	return 2 if msg != "" else 0
