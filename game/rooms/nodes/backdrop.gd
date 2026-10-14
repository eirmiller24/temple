class_name Backdrop
extends Node2D
## Room background: a fill colour plus parallax layers, clipped to the
## room rect (ported from dungeon-platformer's Backdrop). Parallax is
## computed against the active Camera2D: a layer with scroll `factor`
## draws at `cam_origin * (1 - factor)` — 0 is glued to the camera,
## 1 to the world.
##
## backgrounds.json entry: {"color": "#rrggbb", "parallax": [{texture,
## factor, tint, repeat_x, repeat_y, y_px, scale}, ...]} far → near. Every
## layer key is required (no silent defaults); a missing texture file is a
## warning and the layer is skipped.

var _room: Room
var _color := Color("101014")
var _layers: Array[Dictionary] = []


func setup(room: Room, def: Dictionary) -> void:
	_room = room
	if def.is_empty():
		return
	for key in ["color", "parallax"]:
		if not def.has(key):
			push_error("backgrounds.json: entry missing '%s'" % key)
			return
	_color = Color(String(def.color))
	for layer: Dictionary in def.parallax:
		var ok := true
		for key in ["texture", "factor", "tint", "repeat_x", "repeat_y", "y_px", "scale"]:
			if not layer.has(key):
				push_error("backgrounds.json: parallax layer missing '%s'" % key)
				ok = false
		if not ok:
			continue
		var path := String(layer.texture)
		if not ResourceLoader.exists(path):
			push_warning("backgrounds.json: texture '%s' not found" % path)
			continue
		_layers.append({
			"texture": load(path), "factor": clampf(float(layer.factor), 0.0, 1.0),
			"tint": Color(String(layer.tint)), "repeat_x": bool(layer.repeat_x),
			"repeat_y": bool(layer.repeat_y), "y_px": float(layer.y_px),
			"scale": float(layer.scale),
		})


func _process(_delta: float) -> void:
	if not _layers.is_empty():
		queue_redraw()


func _draw() -> void:
	if _room == null:
		return
	var room := _room.rect_px()
	draw_rect(room, _color)
	if _layers.is_empty():
		return
	var cam := get_viewport().get_camera_2d()
	var view_size := get_viewport_rect().size
	var cam_center := cam.get_screen_center_position() if cam != null else room.get_center()
	var cam_origin := to_local(cam_center) - view_size / 2.0
	for layer in _layers:
		var tex: Texture2D = layer.texture
		var size: Vector2 = tex.get_size() * float(layer.scale)
		var origin := room.position + (cam_origin - room.position) * (1.0 - float(layer.factor)) \
				+ Vector2(0, float(layer.y_px) * float(layer.scale))
		var xs := _steps(origin.x, size.x, layer.repeat_x,
				maxf(room.position.x, cam_origin.x), minf(room.end.x, cam_origin.x + view_size.x))
		var ys := _steps(origin.y, size.y, layer.repeat_y,
				maxf(room.position.y, cam_origin.y), minf(room.end.y, cam_origin.y + view_size.y))
		for x in xs:
			for y in ys:
				_draw_clipped(tex, Vector2(x, y), size, layer.tint, room)


func _steps(start: float, step: float, repeat: bool, lo: float, hi: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if not repeat or step <= 0.0:
		out.append(start)
		return out
	var x := start + floorf((lo - start) / step) * step
	while x < hi:
		out.append(x)
		x += step
	return out


func _draw_clipped(tex: Texture2D, pos: Vector2, size: Vector2, tint: Color, room: Rect2) -> void:
	var dest := Rect2(pos, size).intersection(room)
	if not dest.has_area():
		return
	var px_per_unit := tex.get_size() / size
	var src := Rect2((dest.position - pos) * px_per_unit, dest.size * px_per_unit)
	draw_texture_rect_region(tex, dest, src, tint)
