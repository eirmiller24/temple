class_name EnemyKit
extends RefCounted
## Stateless helpers shared by the enemy scripts: the white-flash shader
## every enemy sprite wears, shape builders, clip timing, weighted picks
## and the ballistic solve bosses use to lob rocks. Nothing here reads
## data or touches the tree; species pass numbers in.

const FLASH_SHADER: Shader = preload("res://game/enemies/enemy_flash.gdshader")


## A per-sprite material whose `flash` uniform whitens the art (0..1).
static func flash_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLASH_SHADER
	m.set_shader_parameter("flash", 0.0)
	return m


static func rect(size: Vector2) -> RectangleShape2D:
	var r := RectangleShape2D.new()
	r.size = size
	return r


static func circle(radius: float) -> CircleShape2D:
	var c := CircleShape2D.new()
	c.radius = radius
	return c


## Seconds a non-looping clip takes to play once (0 if the sprite lacks it).
static func clip_length(sprite: AnimatedSprite2D, clip: String) -> float:
	var frames := sprite.sprite_frames
	if frames == null or clip == "" or not frames.has_animation(clip):
		return 0.0
	var fps := frames.get_animation_speed(clip)
	if fps <= 0.0:
		return 0.0
	var total := 0.0
	for i in frames.get_frame_count(clip):
		total += frames.get_frame_duration(clip, i)
	return total / fps


## Pick a key from {name: weight}. Zero/negative weights never win.
static func weighted_pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += maxf(float(weights[k]), 0.0)
	if total <= 0.0:
		return ""
	var roll := randf() * total
	var last := ""
	for k in weights:
		var w := maxf(float(weights[k]), 0.0)
		if w <= 0.0:
			continue
		last = String(k)
		roll -= w
		if roll <= 0.0:
			return last
	return last


## Launch direction (unit vector, screen coords: y down) so a projectile
## fired at `speed` under `grav` lands on `to`. `high` picks the lofted of
## the two solutions. Out of range → a 45° lob toward the target.
static func ballistic_dir(from: Vector2, to: Vector2, speed: float, grav: float, high: bool) -> Vector2:
	var dx := to.x - from.x
	var up := from.y - to.y          # positive when the target is above
	var sx := 1.0 if dx >= 0.0 else -1.0
	var x := absf(dx)
	if grav <= 0.0:
		return (to - from).normalized() if to != from else Vector2(sx, 0.0)
	if x < 0.001:
		return Vector2.UP
	var v2 := speed * speed
	var disc := v2 * v2 - grav * (grav * x * x + 2.0 * up * v2)
	if disc < 0.0:
		return Vector2(sx, -1.0).normalized()
	var root := sqrt(disc)
	var tan_theta := (v2 + root) / (grav * x) if high else (v2 - root) / (grav * x)
	var theta := atan(tan_theta)
	return Vector2(sx * cos(theta), -sin(theta))
