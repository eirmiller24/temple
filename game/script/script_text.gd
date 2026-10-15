@tool
class_name ScriptText
extends Sprite2D
## An inscription in the Script of Rhys, drawn live in the editor and in
## the game. Type the sounds into `text` (docs/authoring/script.md) and the
## glyphs appear; the inspector shows the slot chain it was read as, and
## the scene-tree warning icon lists anything it could not read or had to
## guess.
##
## Paint, like DecorBack/DecorFront/Props: it never collides. The texture
## is rendered at load time and is not saved into the scene, so a .tscn
## only ever holds the text and the settings. For a texture to paint over
## or import elsewhere, bake a PNG with tools/bake_script.gd instead.
##
## Later (design §14): `text` becomes a localized string key run through
## grapheme-to-phoneme, and every ScriptText re-renders when the language
## changes. Nothing here needs to move for that — only where `text` comes from.

const GROUP := "script_text"

## The words, as sounds. Several lines are allowed.
@export_multiline var text := "": set = set_text
## Slot height in pixels; 0 uses render.height_px from data/script.json.
@export_range(0, 256, 1, "suffix:px") var height_px := 0: set = _set_height
## Stroke width in pixels; 0 uses render.stroke_px from data/script.json.
@export_range(0, 8, 1, "suffix:px") var stroke_px := 0: set = _set_stroke
## rtl: the base orientation. ttb: the same writing turned 90° counterclockwise.
@export_enum("rtl", "ttb") var orientation := "rtl": set = _set_orientation
## Line alignment; start is the side reading begins on (right in rtl, top in ttb).
@export_enum("start", "center", "end") var align := "start": set = _set_align
@export var ink := Color.BLACK: set = _set_ink
## Read-only: the slot chain the text was read as, in the design doc's notation.
@export var chain := ""
@export_tool_button("Reload glyph data", "Reload") var reload_glyphs := reload_data

var _problems := PackedStringArray()


func _ready() -> void:
	add_to_group(GROUP, false)
	if not Engine.is_editor_hint():
		var data = Game.data()
		if data != null and not data.reloaded.is_connected(reload_data):
			data.reloaded.connect(reload_data)
	_rebuild()


func _validate_property(property: Dictionary) -> void:
	match property.name:
		"chain":
			property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		"texture", "hframes", "vframes", "frame", "frame_coords", "region_enabled", "region_rect", "region_filter_clip_enabled":
			# Generated from `text` on load; never saved, never hand-set.
			property.usage = PROPERTY_USAGE_NONE


func _get_configuration_warnings() -> PackedStringArray:
	return _problems


func set_text(value: String) -> void:
	text = value
	_rebuild()


func _set_height(value: int) -> void:
	height_px = value
	_rebuild()


func _set_stroke(value: int) -> void:
	stroke_px = value
	_rebuild()


func _set_orientation(value: String) -> void:
	orientation = value
	_rebuild()


func _set_align(value: String) -> void:
	align = value
	_rebuild()


func _set_ink(value: Color) -> void:
	ink = value
	_rebuild()


## Re-read data/script.json and redraw every inscription (F3 in game, the
## inspector button in the editor).
func reload_data() -> void:
	RhysScript.reload_data()
	if is_inside_tree():
		for n in get_tree().get_nodes_in_group(GROUP):
			if n is ScriptText:
				n._rebuild()
	else:
		_rebuild()


func _rebuild() -> void:
	if not is_node_ready():
		return
	var opts := {"orientation": orientation, "align": align, "color": ink}
	if height_px > 0:
		opts.height_px = height_px
	if stroke_px > 0:
		opts.stroke_px = stroke_px
	var res := RhysScript.render(text, opts)
	chain = res.chain
	_problems = PackedStringArray(res.errors + res.warnings)
	var img: Image = res.image
	texture = ImageTexture.create_from_image(img) if img != null and text.strip_edges() != "" else null
	update_configuration_warnings()
