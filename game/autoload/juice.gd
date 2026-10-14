extends Node
## Game-feel helpers that touch global state: hitstop and screenshake.
## Pure presentation — nothing here changes an outcome.
##
## Hitstop sets Engine.time_scale to 0, which also zeroes every _process
## delta (including ours), so the freeze is timed on the wall clock.

var _hitstop_until_ms := 0
var _shake_until_ms := 0
var _shake_strength := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Freeze the world for `seconds` (a few frames) — the hit "lands".
func hitstop(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	_hitstop_until_ms = maxi(_hitstop_until_ms, until)
	Engine.time_scale = 0.0


func shake(strength: float, seconds: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_until_ms = maxi(_shake_until_ms,
			Time.get_ticks_msec() + int(seconds * 1000.0))


func shake_offset() -> Vector2:
	if Time.get_ticks_msec() >= _shake_until_ms:
		return Vector2.ZERO
	return Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _hitstop_until_ms > 0 and now >= _hitstop_until_ms:
		_hitstop_until_ms = 0
		Engine.time_scale = 1.0
	if _shake_strength > 0.0 and now >= _shake_until_ms:
		_shake_strength = 0.0
