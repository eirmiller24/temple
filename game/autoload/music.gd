extends Node
## Room-driven music with a crossfade (ported from dungeon-platformer's
## MusicPlayer + MusicDb). The one rule: entering a room whose track NAME
## matches what is already playing does nothing — the song carries across
## room seams. Only a different track triggers the crossfade.
##
## data/music.json: {"base_db", "crossfade_s", "tracks": {name: {stream,
## volume_db, loop}}}. A track without a stream (or whose file hasn't
## landed) is deliberate silence.

const SILENCE_DB := -60.0

var _players: Array[AudioStreamPlayer] = []
var _targets: Array[float] = [SILENCE_DB, SILENCE_DB]
var _active := -1
var _track := ""
var _streams := {}  # name -> AudioStream or null
var _volumes := {}  # name -> float
var _base_db := -8.0
var _crossfade := 1.5
var _user_volume := 1.0  # 0..1 from options


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = SILENCE_DB
		p.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
		add_child(p)
		_players.append(p)
	refresh()
	Data.reloaded.connect(_on_reloaded)


func refresh() -> void:
	_streams.clear()
	_volumes.clear()
	var m := Data.music
	if m.is_empty():
		return
	_base_db = Data.num(m, "base_db", "music.json")
	_crossfade = maxf(Data.num(m, "crossfade_s", "music.json"), 0.01)
	var tracks: Dictionary = Data.req(m, "tracks", "music.json")
	for name: String in tracks:
		var t: Dictionary = tracks[name]
		_streams[name] = null
		_volumes[name] = 0.0
		if t.has("stream"):
			for key in ["volume_db", "loop"]:
				if not t.has(key):
					push_error("music.json '%s': '%s' required when 'stream' is set" % [name, key])
			var path := String(t.stream)
			if ResourceLoader.exists(path):
				var s: AudioStream = load(path)
				if "loop" in s:
					s.set("loop", bool(t.get("loop", true)))
				_streams[name] = s
				_volumes[name] = float(t.get("volume_db", 0.0))
			else:
				push_warning("music.json '%s': stream '%s' not found — silent until it lands" % [name, path])


func has_track(name: String) -> bool:
	return _streams.has(name)


## Public entry: rooms call this with their `music` field; menus with
## their own track names.
func play_track(name: String) -> void:
	if not _streams.has(name):
		if name != "":
			push_warning("music: unknown track '%s' → silence" % name)
		name = "silence"
	if name == _track:
		return
	_track = name
	if _active >= 0:
		_targets[_active] = SILENCE_DB
	var stream: AudioStream = _streams.get(name)
	if stream == null:
		_active = -1
		return
	var next := (_active + 1) % 2
	var p := _players[next]
	p.stream = stream
	p.volume_db = SILENCE_DB
	p.play()
	_targets[next] = _base_db + float(_volumes.get(name, 0.0)) + linear_to_db(maxf(_user_volume, 0.001))
	_active = next


func stop() -> void:
	play_track("silence")


func set_user_volume(v: float) -> void:
	_user_volume = clampf(v, 0.0, 1.0)
	if _active >= 0:
		_targets[_active] = _base_db + float(_volumes.get(_track, 0.0)) + linear_to_db(maxf(_user_volume, 0.001))


func _process(delta: float) -> void:
	var rate := -SILENCE_DB / _crossfade
	for i in 2:
		var p := _players[i]
		if not p.playing:
			continue
		p.volume_db = move_toward(p.volume_db, _targets[i], rate * delta)
		if i != _active and p.volume_db <= SILENCE_DB + 0.01:
			p.stop()


func _on_reloaded() -> void:
	refresh()
	var t := _track
	_track = ""
	play_track(t)


func _exit_tree() -> void:
	for c in get_children():
		if c is AudioStreamPlayer or c is AudioStreamPlayer2D:
			c.stop()
			c.stream = null
