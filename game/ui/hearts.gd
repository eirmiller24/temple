class_name UiHearts
extends Control
## The hearts row: one heart per hit point, drawn as a vector polygon (full
## = filled red, empty = dim outline). Wraps to a second row past
## `per_row`. No art involved; follows GameState.hp_changed.

const HEART_SIZE := 14.0
const GAP := 4.0
const PER_ROW := 10

var hp := 0
var max_hp := 0
var _points := PackedVector2Array()
var _flash := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_points = _heart_points(HEART_SIZE)
	GameState.hp_changed.connect(set_hp)
	set_hp(GameState.hp, GameState.max_hp)


func set_hp(new_hp: int, new_max: int) -> void:
	if new_hp < hp:
		_flash = 0.35
	hp = new_hp
	max_hp = new_max
	var rows := ceili(float(maxi(max_hp, 1)) / PER_ROW)
	custom_minimum_size = Vector2(mini(max_hp, PER_ROW) * (HEART_SIZE + GAP), rows * (HEART_SIZE + GAP))
	size = custom_minimum_size
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()


## A heart outline from the classic parametric curve, scaled to `s` px and
## with its top-left at the origin.
static func _heart_points(s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 28
	for i in steps:
		var t := TAU * i / steps
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(Vector2(x, y))
	# Normalise to [0, s].
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var span := maxf(hi.x - lo.x, hi.y - lo.y)
	for i in pts.size():
		pts[i] = (pts[i] - lo) / span * s
	return pts


func _draw() -> void:
	if max_hp <= 0:
		return
	for i in max_hp:
		var col := i % PER_ROW
		var row := i / PER_ROW
		var at := Vector2(col * (HEART_SIZE + GAP), row * (HEART_SIZE + GAP))
		var pts := PackedVector2Array()
		for p in _points:
			pts.append(p + at)
		if i < hp:
			draw_colored_polygon(pts, UiTheme.HEART)
		else:
			var closed := PackedVector2Array(pts)
			closed.append(pts[0])
			var c := Color(UiTheme.DIM, 0.9)
			if _flash > 0.0 and i == hp:
				c = c.lerp(UiTheme.TEXT, _flash / 0.35)  # the heart just lost blinks out
			draw_polyline(closed, c, 1.0)
