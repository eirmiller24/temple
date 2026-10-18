class_name Explosive
extends CharacterBody2D
## The Explosive Charge (design §10): the player's first use sets one at
## their feet, the second sets it off (Player._use_explosive). It drops to
## the floor and sits there. The blast is a circle of objects.explosive
## `radius`: a one-shot Hitbox for enemies, switches and breakable walls
## (tier 0, so fortified walls hold), and `player_damage` to the player if
## their body centre is inside it. Child of the room, so leaving the room
## takes it away.

const LAYER_WORLD := 1 << 0
const LAYER_PUSHABLE := 1 << 8
## enemy_hurtbox | switch | breakable
const BLAST_MASK := (1 << 4) | (1 << 9) | (1 << 12)
## Presentation: how long the blast flash lingers, fuse blink rate.
const FLASH_SECONDS := 0.25
const BLINK_HZ := 3.0

var _blast: Hitbox
var _t := 0.0
var _flash := 0.0
var _gone := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = LAYER_WORLD | LAYER_PUSHABLE
	var s := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 8)
	s.shape = r
	s.position = Vector2(0, -4)
	add_child(s)


func _cfg() -> Dictionary:
	return Data.req(Data.objects, "explosive", "objects.json")


func _physics_process(delta: float) -> void:
	_t += delta
	if _gone:
		_flash -= delta
		if _flash <= 0.0:
			queue_free()
		queue_redraw()
		return
	if not is_on_floor():
		velocity.y += Data.num(_cfg(), "gravity", "objects.explosive") * delta
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	queue_redraw()


func is_spent() -> bool:
	return _gone


func detonate(player: Node2D) -> void:
	if _gone:
		return
	_gone = true
	_flash = FLASH_SECONDS
	var cfg := _cfg()
	var radius := Data.num(cfg, "radius", "objects.explosive")
	var centre := global_position + Vector2(0, -4)
	_blast = Hitbox.new()
	_blast.collision_layer = 0
	_blast.collision_mask = BLAST_MASK
	_blast.source_node = player
	_blast.damage = Data.inum(cfg, "damage", "objects.explosive")
	var kb: Array = Data.req(cfg, "knockback", "objects.explosive")
	_blast.knockback = Vector2(float(kb[0]), float(kb[1]))
	_blast.hitstop = Data.num(cfg, "hitstop", "objects.explosive")
	_blast.kind = "explosion"
	var s := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	s.shape = c
	_blast.add_child(s)
	add_child(_blast)
	_blast.global_position = centre
	_blast.pulse(FLASH_SECONDS * 0.5)
	if player != null and player.has_method("on_hit") and player.has_method("body_rect"):
		var body: Rect2 = player.body_rect()
		if body.get_center().distance_to(centre) <= radius:
			player.on_hit({"damage": Data.inum(cfg, "player_damage", "objects.explosive"),
					"knockback": _blast.knockback, "source": self, "origin": centre,
					"kind": "explosion", "tier": 0, "hitstop": 0.0})
	Sfx.play("explosive_blast", self)
	Juice.shake(4.0, 0.25)


func _draw() -> void:
	if _gone:
		var radius := Data.num(_cfg(), "radius", "objects.explosive")
		var k := clampf(_flash / FLASH_SECONDS, 0.0, 1.0)
		draw_circle(Vector2(0, -4), radius * (1.1 - 0.3 * k), Color(1.0, 0.6, 0.2, 0.45 * k))
		draw_circle(Vector2(0, -4), radius * 0.5 * k, Color(1.0, 0.95, 0.7, 0.8 * k))
		return
	draw_rect(Rect2(-6, -9, 12, 9), Color(0.45, 0.3, 0.2))
	draw_rect(Rect2(-6, -6, 12, 2), Color(0.25, 0.18, 0.12))
	var lit := fmod(_t * BLINK_HZ, 1.0) < 0.5
	draw_circle(Vector2(0, -11), 2.0, Color(1.0, 0.3, 0.2) if lit else Color(0.4, 0.15, 0.1))
