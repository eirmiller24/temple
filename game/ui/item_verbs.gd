class_name UiItemVerbs
extends RefCounted
## The pause menu's item rules as plain functions over GameState / World.
## Every item belongs to one section of the menu by its kind (section()):
##
##   weapons    kind "weapon": accept equips it on the attack button.
##   tools      kind "tool": an item button assigns it to that button.
##   equipment  kind "passive": always on, nothing to press.
##   pack       everything else (consumable, key, quest items): the only
##              section with a verb popup, and the only one that drops.
##
## use (weapons equip; usable or hidden-use pack items go through
## Player.use_item_from_menu), drop (remove one and put a Pickup at the
## player's feet when the project has a Pickup yet, else toast) and assign
## each return the status line the menu shows and play the sound.

const PICKUP_SCENE := "res://game/objects/pickup.tscn"
const SECTIONS := {"weapon": "weapons", "tool": "tools", "passive": "equipment"}
const SECTION_NAMES := {"weapons": "Weapon", "tools": "Tool", "equipment": "Equipment"}


static func section(id: String) -> String:
	return String(SECTIONS.get(String(GameState.item_def(id).get("kind", "")), "pack"))


## "Weapon", "Tool", "Equipment", or the pack item's own kind ("Consumable", "Key").
static func section_name(id: String) -> String:
	var s := section(id)
	if SECTION_NAMES.has(s):
		return String(SECTION_NAMES[s])
	return String(GameState.item_def(id).get("kind", "item")).capitalize()


## Weapons, tools and equipment are permanent: only the pack drops.
static func droppable(id: String) -> bool:
	return section(id) == "pack"


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
	if not droppable(id):
		Sfx.play("menu_error")
		return "%s can't be dropped." % name
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


## Returns the status line; refuses (error sound) an item that cannot go
## on an item button.
static func assign(slot: String, id: String) -> String:
	var name := String(GameState.item_def(id).get("name", id))
	if not assignable(id):
		Sfx.play("menu_error")
		return "%s can't go on a button." % name
	GameState.assign(slot, id)
	Sfx.play("item_equip")
	return "%s → %s" % [name, Controls.glyph("item_" + slot)]


## The pack popup's rows as [gameplay action whose glyph to show, verb],
## in display order. "use" is left out for items that hide it or cannot
## be used (design §9.2: a Fang lists only Drop) — menu_use still works.
static func pack_verbs(id: String) -> Array:
	var def := GameState.item_def(id)
	var verbs := []
	if bool(def.get("usable", false)) and not bool(def.get("hide_use", false)):
		verbs.append(["item_y", "use"])
	verbs.append(["item_x", "drop"])
	verbs.append(["menu_accept", "description"])
	verbs.append(["attack", "back"])
	return verbs


## The footer hint for a highlighted cell, with the live glyphs.
static func cell_hint(section_id: String, id: String) -> String:
	var parts := PackedStringArray()
	if id != "":
		match section_id:
			"weapons":
				if GameState.weapon != id:
					parts.append(Controls.hint([["menu_accept", "equip"]]))
			"tools":
				parts.append("%s / %s assign" % [Controls.glyph("item_x"), Controls.glyph("item_y")])
			"pack":
				parts.append(Controls.hint([["menu_accept", "options"]]))
	parts.append(Controls.hint([["attack", "back"]]))
	return "    ".join(parts)
