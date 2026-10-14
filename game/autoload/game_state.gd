extends Node
## The run: health, inventory, equipped slots, permanent flags, visited
## rooms, where to respawn. This is exactly what a save file holds —
## to_dict()/from_dict() are the save format, SaveManager does the disk.
##
## Nothing here is a tunable: numbers come from data/player.json and
## data/items.json. Item ids are keys in data/items.json.

signal hp_changed(hp: int, max_hp: int)
signal inventory_changed
signal slots_changed
signal flag_set(flag: String)
signal room_visited(room: String)
signal died

const SAVE_VERSION := 1

var max_hp := 6
var hp := 6
var inventory := {}      # item_id -> count
var weapon := ""         # item id on the attack button
var slot_x := ""         # item id on X
var slot_y := ""         # item id on Y
var flags := {}          # permanent flags: name -> true
var visited := {}        # room name -> true (map reveal)
var current_room := ""
var respawn_room := ""   # last save shrine (or the start room)
var respawn_entry := ""
var playtime := 0.0
var lantern_on := false
var slot_index := -1     # which save slot this run lives in (-1 = unsaved)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if current_room != "":
		playtime += delta


## Fresh run from data/player.json.
func new_game() -> void:
	var p := Data.player
	max_hp = Data.inum(p, "max_hp", "player.json")
	hp = max_hp
	inventory = {}
	weapon = ""
	slot_x = ""
	slot_y = ""
	flags = {}
	visited = {}
	playtime = 0.0
	lantern_on = false
	slot_index = -1
	var start: Dictionary = Data.req(p, "start", "player.json")
	current_room = ""
	respawn_room = String(Data.req(start, "room", "player.json.start"))
	respawn_entry = String(Data.req(start, "entry", "player.json.start"))
	for id: String in Data.req(start, "items", "player.json.start"):
		add_item(id, int(start.items[id]))
	weapon = String(start.get("weapon", ""))
	slot_x = String(start.get("slot_x", ""))
	slot_y = String(start.get("slot_y", ""))
	hp_changed.emit(hp, max_hp)
	inventory_changed.emit()
	slots_changed.emit()


# --- items ---------------------------------------------------------------

func item_def(id: String) -> Dictionary:
	var items: Dictionary = Data.items.get("items", {})
	if not items.has(id):
		push_error("items.json: unknown item '%s'" % id)
		return {}
	return items[id]


func has_item(id: String) -> bool:
	return inventory.get(id, 0) > 0


func count(id: String) -> int:
	return int(inventory.get(id, 0))


func add_item(id: String, n: int = 1) -> void:
	var def := item_def(id)
	if def.is_empty():
		return
	var cap := int(def.get("stack", 1))
	inventory[id] = mini(count(id) + n, cap)
	# First weapon picked up equips itself; first tool fills an empty slot.
	var kind := String(def.get("kind", ""))
	if kind == "weapon" and weapon == "":
		weapon = id
		slots_changed.emit()
	elif bool(def.get("assignable", false)) and slot_x != id and slot_y != id:
		if slot_x == "":
			slot_x = id
			slots_changed.emit()
		elif slot_y == "":
			slot_y = id
			slots_changed.emit()
	inventory_changed.emit()


func remove_item(id: String, n: int = 1) -> void:
	if not inventory.has(id):
		return
	inventory[id] = count(id) - n
	if inventory[id] <= 0:
		inventory.erase(id)
		if weapon == id:
			weapon = ""
		if slot_x == id:
			slot_x = ""
		if slot_y == id:
			slot_y = ""
		slots_changed.emit()
	inventory_changed.emit()


func assign(slot: String, id: String) -> void:
	if id != "" and not bool(item_def(id).get("assignable", false)):
		return
	if slot == "x":
		if slot_y == id:
			slot_y = slot_x
		slot_x = id
	elif slot == "y":
		if slot_x == id:
			slot_x = slot_y
		slot_y = id
	slots_changed.emit()


func equip_weapon(id: String) -> void:
	if id != "" and String(item_def(id).get("kind", "")) != "weapon":
		return
	weapon = id
	slots_changed.emit()


# --- flags & rooms ----------------------------------------------------------

func has_flag(flag: String) -> bool:
	return flags.has(flag)


func set_flag(flag: String) -> void:
	if flag == "" or flags.has(flag):
		return
	flags[flag] = true
	flag_set.emit(flag)


func visit(room: String) -> void:
	current_room = room
	if not visited.has(room):
		visited[room] = true
		room_visited.emit(room)


func set_respawn(room: String, entry: String) -> void:
	respawn_room = room
	respawn_entry = entry


# --- health -----------------------------------------------------------------

func damage(n: int) -> void:
	if hp <= 0:
		return
	hp = maxi(hp - n, 0)
	hp_changed.emit(hp, max_hp)
	if hp == 0:
		died.emit()


func heal(n: int) -> void:
	hp = mini(hp + n, max_hp)
	hp_changed.emit(hp, max_hp)


func full_heal() -> void:
	hp = max_hp
	hp_changed.emit(hp, max_hp)


# --- save format -------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"max_hp": max_hp, "hp": hp,
		"inventory": inventory.duplicate(),
		"weapon": weapon, "slot_x": slot_x, "slot_y": slot_y,
		"flags": flags.keys(), "visited": visited.keys(),
		"respawn_room": respawn_room, "respawn_entry": respawn_entry,
		"playtime": playtime, "lantern_on": lantern_on,
		"saved_at": Time.get_datetime_string_from_system(),
	}


func from_dict(d: Dictionary) -> void:
	max_hp = int(d.get("max_hp", 6))
	hp = int(d.get("hp", max_hp))
	inventory = {}
	for k: String in d.get("inventory", {}):
		inventory[k] = int(d.inventory[k])
	weapon = String(d.get("weapon", ""))
	slot_x = String(d.get("slot_x", ""))
	slot_y = String(d.get("slot_y", ""))
	flags = {}
	for f: String in d.get("flags", []):
		flags[f] = true
	visited = {}
	for r: String in d.get("visited", []):
		visited[r] = true
	respawn_room = String(d.get("respawn_room", ""))
	respawn_entry = String(d.get("respawn_entry", ""))
	playtime = float(d.get("playtime", 0.0))
	lantern_on = bool(d.get("lantern_on", false))
	current_room = ""
	hp_changed.emit(hp, max_hp)
	inventory_changed.emit()
	slots_changed.emit()
