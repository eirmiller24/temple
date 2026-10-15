extends Node
## Shared wire channels (0–31) for room puzzles — the same model as
## dungeon-platformer's M15 objects: every pressed button and switched-on
## lever DRIVES its channel; every gate (or wired platform) on that channel
## is open while at least one source drives it.
##
## Sources register by object instance so two momentary buttons on one
## channel don't fight: the channel is active while the set of drivers is
## non-empty. State is per room: World.load_room() calls reset().
##
## For a few physics frames after reset() the room is SETTLING: objects
## restored from the save (a block put back on its plate, a lever left on)
## drive their channels, and listeners should snap to the result rather
## than animate it — the player wasn't there to see it happen.

signal channel_changed(channel: int, active: bool)

const MAX_CHANNELS := 32
## Long enough for a restored block's plate to see it (body_entered lands
## on the second physics frame after the room enters the tree).
const SETTLE_FRAMES := 4

var _drivers: Array[Dictionary] = []  # channel -> {source_id: true}
var _settle := 0


func _ready() -> void:
	reset()


func _physics_process(_delta: float) -> void:
	if _settle > 0:
		_settle -= 1


func reset() -> void:
	_drivers.clear()
	for i in MAX_CHANNELS:
		_drivers.append({})
	_settle = SETTLE_FRAMES


func is_settling() -> bool:
	return _settle > 0


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
