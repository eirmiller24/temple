extends Node
## Shared wire channels (0–31) for room puzzles — the same model as
## dungeon-platformer's M15 objects: every pressed button and switched-on
## lever DRIVES its channel; every gate (or wired platform) on that channel
## is open while at least one source drives it.
##
## Sources register by object instance so two momentary buttons on one
## channel don't fight: the channel is active while the set of drivers is
## non-empty. State is per room: World.load_room() calls reset().

signal channel_changed(channel: int, active: bool)

const MAX_CHANNELS := 32

var _drivers: Array[Dictionary] = []  # channel -> {source_id: true}


func _ready() -> void:
	reset()


func reset() -> void:
	_drivers.clear()
	for i in MAX_CHANNELS:
		_drivers.append({})


func drive(channel: int, source: Object, on: bool) -> void:
	if channel < 0 or channel >= MAX_CHANNELS:
		push_error("Wiring: channel %d out of range 0..%d" % [channel, MAX_CHANNELS - 1])
		return
	var was := is_active(channel)
	var id := source.get_instance_id()
	if on:
		_drivers[channel][id] = true
	else:
		_drivers[channel].erase(id)
	var now := is_active(channel)
	if was != now:
		channel_changed.emit(channel, now)


func is_active(channel: int) -> bool:
	if channel < 0 or channel >= MAX_CHANNELS:
		return false
	return not _drivers[channel].is_empty()
