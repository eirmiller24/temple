class_name Enemy
extends EnemyBody
## Base of every enemy. A species is a script extending this (one per
## "behavior": hopper, walker, lasher, guardian, aberration) plus a JSON
## file in data/enemies/<species>.json whose `behavior` names that script;
## the species .tscn is a CharacterBody2D with the script and `species`
## preset. Drop it under a room's `Enemies` node with its origin at the
## FEET (bottom-centre) — the sprite's ground_y puts the feet there.
##
## Common JSON block (every species, hard errors when missing):
##   hp, contact_damage, contact_knockback [x,y], contact_rearm (s between
##   re-arming the touch hitbox), speed, gravity, friction, body_w, body_h
##   (collision px), hurt_stun (s; 0 = hits never stagger — bosses),
##   knockback_resist (0..1), death_linger (s the corpse stays),
##   xp_placeholder, sprite (data/sprites.json "enemies" id), fit_tiles
##   (render height), hit_sfx (data/sfx.json name), boss (bool; bosses add
##   defeat_flag), behavior, and a block named after the behavior.
##
## Contract with combat (EnemyBody builds the nodes): the contact Hitbox
## is active whenever alive and not staggered, re-armed every
## contact_rearm s so a player who stays in contact keeps getting hit.
## `on_hit(info)` takes damage, knockback scaled by (1 - knockback_resist),
## flashes white, hitstops, plays hit_sfx and staggers for hurt_stun; at 0
## HP `die()` plays "death" (fallback "hurt"), emits `died`, lingers, frees.
##
## Attacks are coroutines. They must only ever `await` this node's own
## `stepped` signal (through `wait()`, `step()`, `tell()`, `pulse_box()`):
## a coroutine parked on a self-signal dies silently with the node, whereas
## one parked on a SceneTree timer resumes on a freed instance and errors.
## `wait()` returns false when a stagger or death interrupted the attack;
## callers return at once and `_interrupted()` has already shut their
## hitboxes. Species hooks: _species_ready, _think (per frame while not
## staggered/dead), _hurt_ended, _interrupted, _on_damaged, _on_died,
## _hit_interrupts, _knockback_resist.
##
## Burning: a hit carrying `fire: true` (a burning dart) sets the enemy
## alight for objects.fire.enemy_burn_time, losing enemy_burn_damage every
## enemy_burn_tick s — no stagger, no knockback — and re-lighting restarts
## the clock.
##
## Crushing (design §7.6, Crush): squeezed by a moving solid, an enemy is
## displaced and takes on_hit(); with nowhere to go it dies.

signal died(enemy: Enemy)
## Emitted at the end of every physics frame this enemy processes.
signal stepped

enum State { IDLE, MOVE, TELL, ATTACK, HURT, DEAD, HIDDEN }

## Presentation only (feel, not gameplay): hurt-flash length, tell pulse rate/depth.
const FLASH_SECONDS := 0.08
const TELL_PULSE_HZ := 7.0
const TELL_PULSE_MAX := 0.8
## An enemy this far below the room's painted rect fell out of the world and is freed.
const FELL_OUT_MARGIN := Room.TILE * 4

var hp := 0
var max_hp := 0
var state: int = State.IDLE
var attacks := 0            ## attack sequences started (tests, debug)
var contact_enabled := true  ## species switch touch damage off behind a dedicated hitbox
var uses_gravity := true
var clock := 0.0             ## physics seconds lived; frozen by hitstop and pause

var _seq := 0            ## bumped by every interrupt; coroutines compare against it
var _hurt_time := 0.0
var _flash_time := 0.0
var _death_time := 0.0
var _rearm_time := 0.0
var _crush_ledge := NAN  ## one-way ledge stood on last frame (Crush)
var burning := 0.0       ## seconds of burning left
var _burn_tick := 0.0
var _flames: CPUParticles2D


func _ready() -> void:
	load_config()
	if bool(Data.req(cfg, "boss", ctx)) and GameState.has_flag(cs("defeat_flag")):
		set_physics_process(false)
		queue_free()
		return
	add_to_group("enemies")
	add_to_group("debug_draw")
	max_hp = ci("hp")
	hp = max_hp
	build_children()
	Data.reloaded.connect(_on_data_reloaded)
	_species_ready()


# --- species hooks ---------------------------------------------------------------------

func _species_ready() -> void:
	pass


## Per physics frame while alive and not staggered. Set velocity.x / state here.
func _think(_delta: float) -> void:
	pass


func _hurt_ended() -> void:
	pass


## An attack was cut short (stagger or death): switch off any live hitbox.
func _interrupted() -> void:
	pass


func _on_damaged(_info: Dictionary) -> void:
	pass


func _on_died() -> void:
	pass


func _hit_interrupts() -> bool:
	return cn("hurt_stun") > 0.0


func _knockback_resist() -> float:
	return cn("knockback_resist")


# --- frame ----------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	clock += delta
	_tick_fx(delta)
	_tick_burn(delta)
	match state:
		State.DEAD:
			_death_time -= delta
			if _death_time <= 0.0:
				queue_free()
				return
		State.HURT:
			_hurt_time -= delta
			velocity.x = move_toward(velocity.x, 0.0, cn("friction") * delta)
			if _hurt_time <= 0.0:
				state = State.IDLE
				_hurt_ended()
		_:
			_think(delta)
	if uses_gravity:
		velocity.y += cn("gravity") * delta
	move_and_slide()
	if room != null and global_position.y > room.global_position.y + room.rect_px().end.y + FELL_OUT_MARGIN:
		queue_free()   # hopped into a pit with no floor: gone, no corpse
		return
	if state != State.DEAD and state != State.HIDDEN:
		_check_crush()
	hitbox.facing = facing
	var want := contact_enabled and state != State.HURT and state != State.DEAD and state != State.HIDDEN
	_rearm_time -= delta
	if want and _rearm_time <= 0.0:
		hitbox.active = false   # re-arm: the touch can land again on a lingering player
		_rearm_time = cn("contact_rearm")
	hitbox.active = want
	update_flip()
	if _debug:
		queue_redraw()
	stepped.emit()


func _tick_fx(delta: float) -> void:
	_flash_time = maxf(_flash_time - delta, 0.0)
	var f := 0.0
	if _flash_time > 0.0:
		f = 1.0
	elif state == State.TELL:
		f = TELL_PULSE_MAX * (0.5 + 0.5 * sin(clock * TAU * TELL_PULSE_HZ))
	_mat.set_shader_parameter("flash", f)


func ignite() -> void:
	if state == State.DEAD or state == State.HIDDEN:
		return
	var fire: Dictionary = Data.req(Data.objects, "fire", "objects.json")
	if burning <= 0.0:
		_burn_tick = Data.num(fire, "enemy_burn_tick", "objects.fire")
		Sfx.play("ignite", self)
	burning = Data.num(fire, "enemy_burn_time", "objects.fire")
	if _flames == null:
		_flames = CPUParticles2D.new()
		_flames.amount = 14
		_flames.lifetime = 0.5
		_flames.direction = Vector2.UP
		_flames.spread = 25.0
		_flames.gravity = Vector2(0, -60)
		_flames.initial_velocity_min = 10.0
		_flames.initial_velocity_max = 30.0
		_flames.scale_amount_min = 2.0
		_flames.scale_amount_max = 4.0
		_flames.color = Color(1.0, 0.55, 0.15)
		_flames.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_flames.emission_rect_extents = Vector2(cn("body_w") / 2.0, cn("body_h") / 4.0)
		_flames.position = Vector2(0, -cn("body_h") / 2.0)
		add_child(_flames)
	_flames.emitting = true


func _tick_burn(delta: float) -> void:
	if burning <= 0.0:
		return
	if state == State.DEAD:
		burning = 0.0
		_flames.emitting = false
		return
	burning -= delta
	_burn_tick -= delta
	var fire: Dictionary = Data.req(Data.objects, "fire", "objects.json")
	if _burn_tick <= 0.0:
		_burn_tick += Data.num(fire, "enemy_burn_tick", "objects.fire")
		hp -= Data.inum(fire, "enemy_burn_damage", "objects.fire")
		flash(FLASH_SECONDS)
		if hp <= 0:
			die()
	if burning <= 0.0:
		_flames.emitting = false


func flash(seconds: float) -> void:
	_flash_time = maxf(_flash_time, seconds)


# --- coroutine timing ------------------------------------------------------------------------

## Await one physics frame. False when a stagger/death interrupted the attack.
func step() -> bool:
	var tok := _seq
	await stepped
	return tok == _seq and state != State.DEAD


## Await `seconds` of this enemy's physics time (pause and hitstop freeze it).
func wait(seconds: float) -> bool:
	var tok := _seq
	var until := clock + seconds
	while clock < until:
		await stepped
		if tok != _seq or state == State.DEAD:
			return false
	return true


## The readable windup every attack starts with: "tell" clip + white pulse.
func tell(seconds: float) -> bool:
	state = State.TELL
	velocity.x = 0.0
	SpriteDb.play(sprite, "tell", ["idle"])
	return await wait(seconds)


## Switch a hitbox on for `seconds`; always switches it off again.
func pulse_box(box: Hitbox, seconds: float) -> bool:
	box.facing = facing
	box.active = true
	var ok := await wait(seconds)
	box.active = false
	return ok


# --- damage ----------------------------------------------------------------------------------------

func is_enemy() -> bool:
	return true


func on_hit(info: Dictionary) -> void:
	if state == State.DEAD or state == State.HIDDEN:
		return
	hp -= int(info.get("damage", 1))
	if bool(info.get("fire", false)) and hp > 0:
		ignite()
	Juice.hitstop(float(info.get("hitstop", 0.0)))
	Sfx.play(cs("hit_sfx"), self)
	flash(FLASH_SECONDS)
	_on_damaged(info)
	if hp <= 0:
		die()
		return
	if not _hit_interrupts():
		return
	var kb: Vector2 = info.get("knockback", Vector2.ZERO)
	var origin: Vector2 = info.get("origin", global_position)
	var away := signf(global_position.x - origin.x)
	if away == 0.0:
		away = signf(kb.x) if kb.x != 0.0 else float(-facing)
	var keep := 1.0 - clampf(_knockback_resist(), 0.0, 1.0)
	velocity = Vector2(away * absf(kb.x), kb.y) * keep
	_seq += 1
	state = State.HURT
	_hurt_time = cn("hurt_stun")
	uses_gravity = true
	hitbox.active = false
	SpriteDb.play(sprite, "hurt", ["idle"])
	_interrupted()


func die() -> void:
	if state == State.DEAD:
		return
	_seq += 1
	state = State.DEAD
	velocity.x = 0.0
	uses_gravity = true
	contact_enabled = false
	hitbox.active = false
	hurtbox.enabled = false
	collision_layer = 0
	sprite.visible = true
	Sfx.play("enemy_death", self)
	var clip := SpriteDb.play(sprite, "death", ["hurt"])
	_death_time = maxf(EnemyKit.clip_length(sprite, clip), cn("death_linger"))
	_interrupted()
	_on_died()
	died.emit(self)


## Design §7.6: squeezed by a moving solid, an enemy is displaced and
## hurt, or (nowhere to go) dies.
func _check_crush() -> void:
	var out := {}
	match Crush.resolve(self, room, out, _crush_ledge):
		Crush.DISPLACED:
			on_hit(Crush.hit_info(self, out.offset))
		Crush.TRAPPED:
			die()
	_crush_ledge = Crush.ledge_under(self, room, _crush_ledge)


func debug_label() -> String:
	return "%s %d/%d %s" % [species, hp, max_hp, State.keys()[state]]
