class_name UiItemVerbs
extends RefCounted
## The pause menu's item verbs as plain functions over GameState / World:
## use (weapons equip, usable or hidden-use items go through
## Player.use_item_from_menu), drop (remove one and put a Pickup at the
## player's feet when the project has a Pickup yet, else toast) and assign.
## Each returns the status line the menu shows and plays the sound.

const PICKUP_SCENE := "res://game/objects/pickup.tscn"


static func use(world: World, id: String) -> String:
	var def := GameState.item_def(id)
	var name := String(def.get("name", id))
	if String(def.get("kind", "")) == "weapon":
		GameState.equip_weapon(id)
		Sfx.play("item_equip")
		return "%s equipped." % name
	if bool(def.get("usable", false)) or bool(def.get("hide_use", false)):
		var ok := false
		if world != null and world.player != null:
			ok = world.player.use_item_from_menu(id)
		if ok:
			Sfx.play("menu_accept")
			return "Used %s." % name
		Sfx.play("menu_error")
		return "Can't use %s now." % name
	Sfx.play("menu_error")
	return "%s has no use here." % name


static func drop(world: World, id: String) -> String:
	var name := String(GameState.item_def(id).get("name", id))
	GameState.remove_item(id, 1)
	var spawned := spawn_pickup(world, id)
	Sfx.play("item_drop")
	if not spawned and world != null:
		world.toast("dropped %s" % name)
	return "Dropped %s." % name


## Put a Pickup at the player's feet if the project has one (the scene
## first, then a global class named Pickup); false when it doesn't yet.
static func spawn_pickup(world: World, id: String) -> bool:
	if world == null or world.player == null or world.room == null:
		return false
	var node: Node = null
	if ResourceLoader.exists(PICKUP_SCENE):
		node = (load(PICKUP_SCENE) as PackedScene).instantiate()
	else:
		for c in ProjectSettings.get_global_class_list():
			if String(c["class"]) == "Pickup":
				var script: Script = load(String(c["path"]))
				if script != null and script.can_instantiate():
					node = script.new()
				break
	if node == null:
		return false
	if node.has_method("setup"):
		node.setup(id, 1)
	else:
		for prop in ["item_id", "item"]:
			if prop in node:
				node.set(prop, id)
		if "count" in node:
			node.set("count", 1)
	world.room.add_child(node)
	if node is Node2D:
		node.global_position = world.player.global_position
	return true


static func assignable(id: String) -> bool:
	return bool(GameState.item_def(id).get("assignable", false))


## Returns "" when the item cannot go in a slot.
static func assign(slot: String, id: String) -> String:
	if not assignable(id):
		Sfx.play("menu_error")
		return ""
	GameState.assign(slot, id)
	Sfx.play("item_equip")
	return "%s → %s" % [String(GameState.item_def(id).get("name", id)), Controls.glyph("item_" + slot)]


## "A select  B use  Y drop  LB assign" with the LIVE glyphs (Controls),
## minus "use" for items that hide it or cannot be used (design §9.2: a
## Fang lists only Drop).
static func verb_hint(id: String) -> String:
	var def := GameState.item_def(id)
	var verbs := [["menu_accept", "select"]]
	var usable := String(def.get("kind", "")) == "weapon" or bool(def.get("usable", false))
	if usable and not bool(def.get("hide_use", false)):
		verbs.append(["attack", "use"])
	verbs.append(["item_y", "drop"])
	verbs.append(["interact", "assign"])
	return Controls.hint(verbs)
