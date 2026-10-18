#!/usr/bin/env python3
"""Writes project.godot from a compact action table.

Godot's project.godot input-map format is verbose and easy to typo by hand,
so the input map is described here once and rendered. Run it when the
action table changes:

    python3 tools/gen_project_godot.py

Everything outside the [input] section is also written here, so this file is
the single source of truth for project settings, in the exact form the
editor saves (so opening the project does not rewrite the file). If you
change a setting in the editor, fold it back into HEADER/FOOTER here.
"""
import os

KEY = {
    "A": 65, "B": 66, "C": 67, "D": 68, "E": 69, "F": 70, "J": 74, "K": 75,
    "L": 76, "Q": 81, "R": 82, "S": 83, "W": 87, "X": 88,
    "Space": 32, "Escape": 4194305, "Tab": 4194306, "Enter": 4194309,
    "Backspace": 4194308, "Shift": 4194325, "Ctrl": 4194326, "Alt": 4194328,
    "Left": 4194319, "Up": 4194320, "Right": 4194321, "Down": 4194322,
    "F1": 4194332, "F2": 4194333, "F3": 4194334, "F4": 4194335,
    "F5": 4194336, "F9": 4194340,
}

# Godot JoyButton (SDL layout): A=0 B=1 X=2 Y=3 Back=4 Guide=5 Start=6
# LStick=7 RStick=8 LB=9 RB=10 DUp=11 DDown=12 DLeft=13 DRight=14
BTN = {"A": 0, "B": 1, "X": 2, "Y": 3, "Back": 4, "Start": 6, "LS": 7,
       "RS": 8, "LB": 9, "RB": 10, "DUp": 11, "DDown": 12, "DLeft": 13,
       "DRight": 14}
# JoyAxis: LX=0 LY=1 RX=2 RY=3 LT=4 RT=5
AXIS = {"LX": 0, "LY": 1, "RX": 2, "RY": 3, "LT": 4, "RT": 5}

# action -> (deadzone, [events]); event = ("key", name) | ("btn", name)
#   | ("axis", name, value) | ("mouse", button_index)
ACTIONS = {
    # --- movement (analog: magnitude picks walk vs run) ---------------
    "move_left":  (0.2, [("key", "A"), ("key", "Left"), ("btn", "DLeft"), ("axis", "LX", -1.0)]),
    "move_right": (0.2, [("key", "D"), ("key", "Right"), ("btn", "DRight"), ("axis", "LX", 1.0)]),
    "move_up":    (0.2, [("key", "W"), ("key", "Up"), ("btn", "DUp"), ("axis", "LY", -1.0)]),
    "move_down":  (0.2, [("key", "S"), ("key", "Down"), ("btn", "DDown"), ("axis", "LY", 1.0)]),
    # right stick: becomes movement while free-aiming
    "rs_left":    (0.2, [("axis", "RX", -1.0)]),
    "rs_right":   (0.2, [("axis", "RX", 1.0)]),
    "rs_up":      (0.2, [("axis", "RY", -1.0)]),
    "rs_down":    (0.2, [("axis", "RY", 1.0)]),
    # --- verbs ----------------------------------------------------------
    "jump":       (0.5, [("key", "Space"), ("btn", "A")]),
    "attack":     (0.5, [("key", "J"), ("btn", "B")]),
    "item_x":     (0.5, [("key", "K"), ("btn", "X")]),
    "item_y":     (0.5, [("key", "L"), ("btn", "Y")]),
    "interact":   (0.5, [("key", "E"), ("btn", "LB")]),
    "dash":       (0.5, [("key", "Shift"), ("btn", "RB")]),
    # crouch/crawl is its own button: RT on pad, C on keyboard. Not S/Down:
    # "down" is move_down, and down + jump (drop through a one-way ledge)
    # must stay distinct from crouch + jump (a crouch jump).
    "crouch":     (0.5, [("key", "C"), ("axis", "RT", 1.0)]),
    # hold to free-aim: LT on pad, right mouse button on keyboard+mouse
    "aim":        (0.5, [("mouse", 2), ("axis", "LT", 1.0)]),
    # keyboard-only walk modifier (sticks use magnitude instead)
    "walk":       (0.5, [("key", "Ctrl")]),
    # --- menus ------------------------------------------------------------
    # These are the DEFAULTS. At runtime game/autoload/controls.gd owns the
    # InputMap: every action above plus menu_accept/menu_back is remappable
    # (Options -> Controls), and menu_use/slot/drop/assign/tab_* are rebuilt
    # as mirrors of attack / item_x / item_y / interact / dash so the menus
    # follow a remap. Keep the two tables in step (Controls.MIRRORS).
    "pause":      (0.5, [("key", "Escape"), ("btn", "Start")]),
    "map":        (0.5, [("key", "Tab"), ("btn", "Back")]),
    "menu_accept":(0.5, [("key", "Enter"), ("key", "Space"), ("btn", "A")]),
    "menu_back":  (0.5, [("key", "Escape"), ("key", "Backspace"), ("btn", "B")]),
    "menu_use":   (0.5, [("key", "J"), ("btn", "B")]),
    "menu_drop":  (0.5, [("key", "L"), ("btn", "Y")]),
    "menu_assign":(0.5, [("key", "E"), ("btn", "LB")]),
    "menu_slot_x":(0.5, [("key", "K"), ("btn", "X")]),
    "menu_slot_y":(0.5, [("key", "L"), ("btn", "Y")]),
    "menu_tab_prev": (0.5, [("key", "Q"), ("btn", "LB")]),
    "menu_tab_next": (0.5, [("key", "R"), ("btn", "RB")]),
    # --- debug ------------------------------------------------------------
    "debug_tuning": (0.5, [("key", "F1")]),
    "debug_view":   (0.5, [("key", "F2")]),
    "debug_reload": (0.5, [("key", "F3")]),
    "debug_rooms":  (0.5, [("key", "F4")]),
}


def key_event(name):
    return ('Object(InputEventKey,"resource_local_to_scene":false,'
            '"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,'
            '"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,'
            '"pressed":false,"keycode":0,"physical_keycode":%d,"key_label":0,'
            '"unicode":0,"location":0,"echo":false,"script":null)' % KEY[name])


def btn_event(name):
    return ('Object(InputEventJoypadButton,"resource_local_to_scene":false,'
            '"resource_name":"","device":-1,"button_index":%d,"pressure":0.0,'
            '"pressed":true,"script":null)' % BTN[name])


def axis_event(name, value):
    return ('Object(InputEventJoypadMotion,"resource_local_to_scene":false,'
            '"resource_name":"","device":-1,"axis":%d,"axis_value":%s,'
            '"script":null)' % (AXIS[name], "%.1f" % value))


def mouse_event(index):
    return ('Object(InputEventMouseButton,"resource_local_to_scene":false,'
            '"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,'
            '"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,'
            '"button_mask":%d,"position":Vector2(0, 0),"global_position":'
            'Vector2(0, 0),"factor":1.0,"button_index":%d,"canceled":false,'
            '"pressed":true,"double_click":false,"script":null)'
            % (1 << (index - 1), index))


def render_event(ev):
    kind = ev[0]
    if kind == "key":
        return key_event(ev[1])
    if kind == "btn":
        return btn_event(ev[1])
    if kind == "axis":
        return axis_event(ev[1], ev[2])
    if kind == "mouse":
        return mouse_event(ev[1])
    raise ValueError(ev)


# Written in the exact form the editor itself saves (section order, no
# values that equal the engine default, its standard header), so opening
# the project in the editor does not rewrite the file and git stays quiet.
# Everything after the [input] section goes in FOOTER. The editor plugins
# (godot-ai, room_tools, the local-only terminal) and godot-ai's
# _mcp_game_helper autoload (its export plugin strips it from exports) are
# what enabling them in the editor writes; keep them here or regenerating
# disables them.
HEADER = """; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.
;
; Format:
;   [section] ; section goes between []
;   param=value ; assign values to parameters

config_version=5

[application]

config/name="The Temple of Rhys"
config/description="A robbed and stranded archaeology student has only one way out of a collapsed mountaintop: down, through the temple of a snake god."
run/main_scene="res://game/main.tscn"
config/features=PackedStringArray("4.7")
config/icon="res://icon.svg"

[autoload]

Data="*res://game/autoload/data.gd"
Wiring="*res://game/autoload/wiring.gd"
SpriteDb="*res://game/autoload/sprite_db.gd"
Music="*res://game/autoload/music.gd"
Sfx="*res://game/autoload/sfx.gd"
Juice="*res://game/autoload/juice.gd"
Controls="*res://game/autoload/controls.gd"
SaveManager="*res://game/autoload/save_manager.gd"
GameState="*res://game/autoload/game_state.gd"
RoomRegistry="*res://game/autoload/room_registry.gd"
_mcp_game_helper="*res://addons/godot_ai/runtime/game_helper.gd"

[display]

window/size/viewport_width=960
window/size/viewport_height=540
window/size/window_width_override=1920
window/size/window_height_override=1080
window/stretch/mode="canvas_items"
window/stretch/scale_mode="integer"

[editor_plugins]

enabled=PackedStringArray("res://addons/godot_ai/plugin.cfg", "res://addons/room_tools/plugin.cfg", "res://addons/terminal/plugin.cfg")

[input]

"""

# Physics layer names, physics and rendering. (physics_ticks_per_second is
# the default 60 and window/stretch/aspect the default "keep"; the editor
# drops defaults, so they are not written.)
FOOTER = """
[layer_names]

2d_physics/layer_1="world"
2d_physics/layer_2="player"
2d_physics/layer_3="enemy"
2d_physics/layer_4="player_hurtbox"
2d_physics/layer_5="enemy_hurtbox"
2d_physics/layer_6="player_hitbox"
2d_physics/layer_7="enemy_hitbox"
2d_physics/layer_8="interact"
2d_physics/layer_9="pushable"
2d_physics/layer_10="switch"
2d_physics/layer_11="grapple"
2d_physics/layer_12="projectile"
2d_physics/layer_13="breakable"
2d_physics/layer_14="room_exit"
2d_physics/layer_15="whip"
2d_physics/layer_16="fire"

[physics]

2d/default_gravity=1400.0

[rendering]

textures/canvas_textures/default_texture_filter=0
environment/defaults/default_clear_color=Color(0.05, 0.05, 0.07, 1)
2d/snap/snap_2d_transforms_to_pixel=true
2d/snap/snap_2d_vertices_to_pixel=true
"""


def main():
    out = [HEADER]
    for action, (deadzone, events) in ACTIONS.items():
        out.append('%s={\n"deadzone": %s,\n"events": [' % (action, deadzone))
        out.append("\n, ".join(render_event(e) for e in events))
        out.append("\n]\n}\n")
    out.append(FOOTER)
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    with open(os.path.join(root, "project.godot"), "w") as f:
        f.write("".join(out))
    print("wrote project.godot with %d actions" % len(ACTIONS))


if __name__ == "__main__":
    main()
