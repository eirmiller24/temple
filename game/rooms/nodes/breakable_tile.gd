class_name BreakableTile
extends Area2D
## Spawned by Room for every `breakable` / `fortified` Collision cell so
## attacks can find the wall. The kind cell itself provides the collision
## until this node erases it. Fortified cells only break to a tier-1
## (keystone) hit — a fast boulder today, the Power Fang later.

const LAYER_BREAKABLE := 1 << 12

var room: Room
var cell := Vector2i.ZERO
var kind := "breakable"


func setup(r: Room, c: Vector2i, k: String) -> void:
	room = r
	cell = c
	kind = k
	position = (Vector2(c) + Vector2(0.5, 0.5)) * Room.TILE
	collision_layer = LAYER_BREAKABLE
	collision_mask = 0
	monitoring = false
	monitorable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(Room.TILE - 2, Room.TILE - 2)
	shape.shape = rect
	add_child(shape)


func take_hit(info: Dictionary) -> void:
	if kind == "fortified" and int(info.get("tier", 0)) < 1:
		Game.sfx().play("wall_clink", self)
		return
	Game.sfx().play("wall_break", self)
	Game.juice().shake(2.0, 0.12)
	room.erase_cell(cell)
	_puff()
	queue_free()


func _puff() -> void:
	var p := CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = 12
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 140.0
	p.gravity = Vector2(0, 500)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color("8a8070")
	p.global_position = global_position
	room.add_child(p)
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
