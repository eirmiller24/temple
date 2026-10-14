class_name Game
extends RefCounted
## Autoload access for @tool scripts and headless tool scripts.
##
## An editor-side (@tool) script, or a `-s` tool script compiled before
## the autoloads exist, cannot name an autoload directly — the identifier
## fails to resolve at parse time. These lookups go through the scene
## tree at call time instead and return a plain Node, so the call site
## stays dynamically typed. Runtime-only scripts (player, enemies, UI)
## keep using Data / GameState / Music / Sfx by name.


static func _root() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root
	return null


static func autoload(name: String) -> Node:
	var r := _root()
	return r.get_node_or_null(name) if r != null else null


static func data() -> Node:
	return autoload("Data")


static func state() -> Node:
	return autoload("GameState")


static func music() -> Node:
	return autoload("Music")


static func sfx() -> Node:
	return autoload("Sfx")


static func juice() -> Node:
	return autoload("Juice")


static func wiring() -> Node:
	return autoload("Wiring")


static func sprites() -> Node:
	return autoload("SpriteDb")


## True when running the game (not the editor, not a bare tool script).
static func in_game() -> bool:
	return not Engine.is_editor_hint() and data() != null
