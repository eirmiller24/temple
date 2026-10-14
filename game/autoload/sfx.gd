extends Node
## One-shot sound effects by name, from data/sfx.json:
##   {"base_db": -14.0, "sounds": {name: {stream, volume_db, pitch?, pitch_var?}}}
## A sound with an empty entry ({}) is a silent slot you can fill later —
## the game never errors over a missing sound. `play(name, at)` is
## positional when `at` is given (2D attenuation), else global.

const POOL := 12

var _defs := {}
var _streams := {}
var _base_db := -14.0
var _user_volume := 1.0
var _pool: Array[AudioStreamPlayer] = []
var _pool2d: Array[AudioStreamPlayer2D] = []
var _next := 0
var _next2d := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
		var p2 := AudioStreamPlayer2D.new()
		p2.max_distance = 900.0
		add_child(p2)
		_pool2d.append(p2)
	refresh()
	Data.reloaded.connect(refresh)


func refresh() -> void:
	_defs.clear()
	_streams.clear()
	var s := Data.sfx
	if s.is_empty():
		return
	_base_db = Data.num(s, "base_db", "sfx.json")
	var sounds: Dictionary = Data.req(s, "sounds", "sfx.json")
	for name: String in sounds:
		var d: Dictionary = sounds[name]
		_defs[name] = d
		if d.has("stream"):
			var path := String(d.stream)
			if ResourceLoader.exists(path):
				_streams[name] = load(path)
			else:
				push_warning("sfx.json '%s': stream '%s' not found" % [name, path])


func has_sound(name: String) -> bool:
	return _streams.has(name)


func play(name: String, at: Node2D = null) -> void:
	var stream: AudioStream = _streams.get(name)
	if stream == null:
		return
	var d: Dictionary = _defs[name]
	var pitch := float(d.get("pitch", 1.0))
	var var_ := float(d.get("pitch_var", 0.0))
	if var_ > 0.0:
		pitch *= 1.0 + randf_range(-var_, var_)
	var db := _base_db + float(d.get("volume_db", 0.0)) + linear_to_db(maxf(_user_volume, 0.001))
	if at != null and is_instance_valid(at) and at.is_inside_tree():
		var p := _pool2d[_next2d]
		_next2d = (_next2d + 1) % POOL
		p.global_position = at.global_position
		p.stream = stream
		p.pitch_scale = pitch
		p.volume_db = db
		p.play()
	else:
		var p := _pool[_next]
		_next = (_next + 1) % POOL
		p.stream = stream
		p.pitch_scale = pitch
		p.volume_db = db
		p.play()


func set_user_volume(v: float) -> void:
	_user_volume = clampf(v, 0.0, 1.0)


func _exit_tree() -> void:
	for c in get_children():
		if c is AudioStreamPlayer or c is AudioStreamPlayer2D:
			c.stop()
			c.stream = null
