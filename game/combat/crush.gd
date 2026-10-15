class_name Crush
extends RefCounted
## Crushing (design §7.6). Any moving solid (a closing gate, a pulled
## block, a future platform) can push a character somewhere it cannot get
## out of. The engine then leaves the character overlapping solid
## geometry after its own move_and_slide(), and that overlap is the
## signal: nothing about the crusher needs to know about crushing.
##
## The player and Enemy call Crush.resolve() after they move. A
## squeezed character is displaced to the nearest free spot (never through
## a wall) and damaged; with no free spot the player voids out and an enemy
## dies. Numbers: data/objects.json "crush".
##
## Solids are the room's Collision kinds (the playable truth) plus any
## other physics body on the character's mask (gates, push blocks, seam
## aprons). One-way shapes and kinds don't count, EXCEPT the one-way
## ledge a character is standing on: the only way down through that is an
## intentional drop, so a crusher pushing them into it is a squeeze (put
## back on top, displaced sideways, hurt) and no escape goes down through
## it. Callers keep that ledge between frames: pass last frame's
## ledge_under() into resolve(), and forget it on an intentional drop.

const SOLID_KINDS := ["solid", "fortified", "breakable"]
## Overlap shallower than this is resting contact / the physics margin.
const INSET := 2.0
## Displacement search granularity, px.
const STEP := 4.0
## Small nudges across the direction of every candidate: a squeezed body
## has usually been pressed a few px into the floor, ceiling or wall too.
const LIFTS := [0.0, -2.0, -4.0, -8.0, 2.0, 4.0, 8.0]

enum { FREE, DISPLACED, TRAPPED }


## FREE (not squeezed), DISPLACED (moved clear; `out.offset` says by how
## much) or TRAPPED (nowhere to go). Moves the body when displacing.
##
## Overlap is tested with the body's real shapes (shrunk by INSET), not
## its bounding rect: the player's capsule rolling over a ledge corner puts
## the rect's corner a few px into the ledge while the capsule touches it
## only tangentially, and that was read as a squeeze.
static func resolve(body: PhysicsBody2D, room: Room, out: Dictionary, ledge_y: float = NAN) -> int:
	var parts := _parts(body, INSET)
	if parts.is_empty():
		return FREE
	var lips := _ledge_lips(body, room, ledge_y)
	var squeezed := false
	if not lips.is_empty() and body.global_position.y > ledge_y + 0.5 \
			and body.global_position.y < ledge_y + Room.TILE * 0.5:
		# Pushed down into the ledge it stood on: the engine lets bodies
		# through a one-way shape they're inside. Put it back on top; if
		# anything is then actually pressing on it, that's a squeeze.
		var sunk := body.global_position.y - ledge_y
		body.global_position.y = ledge_y
		squeezed = not _solids(body, _parts(body, 0.0), Vector2.ZERO, room).is_empty()
		if not squeezed:
			return FREE
		parts = _parts(body, INSET)
		out["sunk"] = sunk
	if not squeezed and _solids(body, parts, Vector2.ZERO, room, lips).is_empty():
		return FREE
	var off: Variant = find_escape(body, room, lips)
	if off == null:
		return TRAPPED
	body.global_position += off
	out["offset"] = off
	return DISPLACED


## The top of the one-way ledge `body` is standing on (world y), or NAN.
## Call after the body has moved this frame with last frame's value; pass
## the result to next frame's resolve(). A ledge is kept, not just while
## the body is on the floor, but while it is still over the ledge and
## hasn't risen above it: something pressing down from above stops the
## engine calling it "on floor" a frame before it sinks.
static func ledge_under(body: CharacterBody2D, room: Room, prev: float = NAN) -> float:
	if room == null:
		return NAN
	var feet := body.global_position
	if body.is_on_floor():
		var row := floori((feet.y + 1.0 - room.global_position.y) / Room.TILE)
		var top := room.global_position.y + row * Room.TILE
		if absf(feet.y - top) <= 1.0 and _over_oneway(body, room, row):
			return top
		return NAN
	if is_nan(prev) or feet.y < prev - 1.0 or feet.y > prev + Room.TILE * 0.5:
		return NAN
	return prev if _over_oneway(body, room, roundi((prev - room.global_position.y) / Room.TILE)) else NAN


static func _over_oneway(body: PhysicsBody2D, room: Room, row: int) -> bool:
	var r := body_rect(body)
	var c0 := floori((r.position.x - room.global_position.x) / Room.TILE)
	var c1 := floori((r.end.x - room.global_position.x) / Room.TILE)
	for x in range(c0, c1 + 1):
		if room.kind_at_cell(Vector2i(x, row)) == "oneway":
			return true
	return false


## The lips (top quarter, as the kind tileset shapes them) of the one-way
## cells in the ledge's row, near the body, as solid rects; empty when the
## body has no ledge or isn't over one any more.
static func _ledge_lips(body: PhysicsBody2D, room: Room, ledge_y: float) -> Array:
	var out := []
	if room == null or is_nan(ledge_y):
		return out
	var r := body_rect(body)
	var row := roundi((ledge_y - room.global_position.y) / Room.TILE)
	var reach := Data.num(Data.req(Data.objects, "crush", "objects.json"), "max_displace", "objects.crush") + r.size.x
	var c0 := floori((r.position.x - reach - room.global_position.x) / Room.TILE)
	var c1 := floori((r.end.x + reach - room.global_position.x) / Room.TILE)
	var under := false
	for x in range(c0, c1 + 1):
		if room.kind_at_cell(Vector2i(x, row)) != "oneway":
			continue
		var lip := Rect2(room.global_position + Vector2(x, row) * Room.TILE, Vector2(Room.TILE, Room.TILE * 0.25))
		out.append(lip)
		if lip.position.x < r.end.x and lip.end.x > r.position.x:
			under = true
	return out if under else []


## The body's collision shapes as one world-space rect.
static func body_rect(body: CollisionObject2D) -> Rect2:
	var r := Rect2()
	var first := true
	for c in body.get_children():
		if not (c is CollisionShape2D) or c.disabled or c.shape == null:
			continue
		var sr: Rect2 = (c as CollisionShape2D).shape.get_rect()
		sr.position += (c as CollisionShape2D).global_position
		r = sr if first else r.merge(sr)
		first = false
	return r


## The hit a crush deals, for on_hit(): away from where it was pushed from.
static func hit_info(body: Node2D, offset: Vector2) -> Dictionary:
	var c: Dictionary = Data.req(Data.objects, "crush", "objects.json")
	var kb: Array = Data.req(c, "knockback", "objects.crush")
	return {"damage": Data.inum(c, "damage", "objects.crush"),
			"knockback": Vector2(float(kb[0]), float(kb[1])), "source": null,
			"origin": body.global_position - Vector2(signf(offset.x), 0.0),
			"kind": "crush", "tier": 0, "hitstop": 0.0}


## Nearest offset that puts the body somewhere free without crossing a
## solid it isn't already in; null when there is none within
## crush.max_displace. "Free" is judged with the REAL shapes, not the
## INSET-shrunk ones used to detect the squeeze: a body landed even partly
## inside something gets depenetrated by the engine, and during hitstop
## (time_scale 0, which the crush's own hit starts) that recovery divides
## by a zero delta and turns the body's position into NaN.
static func find_escape(body: PhysicsBody2D, room: Room, lips: Array = []) -> Variant:
	var parts := _parts(body, 0.0)
	var max_d := Data.num(Data.req(Data.objects, "crush", "objects.json"), "max_displace", "objects.crush")
	var rect := body_rect(body).grow(-INSET)
	var side := 1.0 if body.velocity.x >= 0.0 else -1.0
	var d := STEP
	while d <= max_d:
		var cands: Array[Vector2] = []
		for s in [side, -side]:
			for lift: float in LIFTS:
				cands.append(Vector2(s * d, lift))
		for v in [-d, d]:
			for nudge: float in LIFTS:
				cands.append(Vector2(nudge, v))
		for off in cands:
			if _solids(body, parts, off, room, lips).is_empty() and _path_clear(body, room, rect, off, lips):
				return off
		d += STEP
	return null


## The middle band of the swept rect (half the body across the direction
## of travel) may only touch solids the body is already in, and must not
## carry it from one side of those to the other. That lets a body pressed
## into the floor slide out sideways, or one buried in a block climb out of
## it, but stops one pressed into a wall being displaced through it. The
## band's tile cells count as one block (a two-tile wall is one wall); the
## band leaves out the floor under the body and the ceiling over it, so they
## don't merge with a wall beside it.
static func _path_clear(body: PhysicsBody2D, room: Room, rect: Rect2, off: Vector2, lips: Array) -> bool:
	var band := rect
	if absf(off.x) >= absf(off.y):
		band = rect.grow_individual(0.0, -rect.size.y * 0.25, 0.0, -rect.size.y * 0.25)
	else:
		band = rect.grow_individual(-rect.size.x * 0.25, 0.0, -rect.size.x * 0.25, 0.0)
	var already := _solids(body, [_rect_part(band)], Vector2.ZERO, room, lips)
	var swept := band.merge(Rect2(band.position + off, band.size))
	for s in _solids(body, [_rect_part(swept)], Vector2.ZERO, room, lips):
		if not already.has(s):
			return false
	var from := rect.get_center()
	var to := from + off
	var horizontal := absf(off.x) >= absf(off.y)
	var cells := Rect2()
	var have_cells := false
	for s in already:
		if s is Vector2i:
			var cr := _solid_rect(s, room)
			cells = cr if not have_cells else cells.merge(cr)
			have_cells = true
		elif _crosses(from, to, _solid_rect(s, room), horizontal):
			return false
	return not (have_cells and _crosses(from, to, cells, horizontal))


## Does going from `from` to `to` start wholly on one side of `r` and end
## wholly on the other?
static func _crosses(from: Vector2, to: Vector2, r: Rect2, horizontal: bool) -> bool:
	if horizontal:
		return (from.x <= r.position.x and to.x >= r.end.x) or (from.x >= r.end.x and to.x <= r.position.x)
	return (from.y <= r.position.y and to.y >= r.end.y) or (from.y >= r.end.y and to.y <= r.position.y)


## World rect of a _solids() entry: a cell, a lip rect, or a body.
static func _solid_rect(s: Variant, room: Room) -> Rect2:
	if s is Vector2i:
		return Rect2(room.global_position + Vector2(s as Vector2i) * Room.TILE, Vector2(Room.TILE, Room.TILE))
	if s is Rect2:
		return s
	return body_rect(s as CollisionObject2D)


## The body's collision shapes, each shrunk by `shrink` px: [{shape, pos}]
## with `pos` the shape's world centre (shapes are assumed unrotated).
static func _parts(body: CollisionObject2D, shrink: float) -> Array:
	var out := []
	for c in body.get_children():
		if not (c is CollisionShape2D) or c.disabled or c.shape == null:
			continue
		var src: Shape2D = (c as CollisionShape2D).shape
		var shrunk: Shape2D
		if src is CapsuleShape2D:
			var cap := CapsuleShape2D.new()
			cap.radius = maxf((src as CapsuleShape2D).radius - shrink, 0.5)
			cap.height = maxf((src as CapsuleShape2D).height - 2.0 * shrink, cap.radius * 2.0)
			shrunk = cap
		elif src is CircleShape2D:
			var circ := CircleShape2D.new()
			circ.radius = maxf((src as CircleShape2D).radius - shrink, 0.5)
			shrunk = circ
		else:
			var r := src.get_rect().grow(-shrink)
			if r.size.x <= 0.0 or r.size.y <= 0.0:
				continue
			out.append({"shape": _rect_shape(r.size), "pos": (c as CollisionShape2D).global_position + r.get_center()})
			continue
		out.append({"shape": shrunk, "pos": (c as CollisionShape2D).global_position})
	return out


static func _rect_part(r: Rect2) -> Dictionary:
	return {"shape": _rect_shape(r.size), "pos": r.get_center()}


static func _rect_shape(size: Vector2) -> RectangleShape2D:
	var s := RectangleShape2D.new()
	s.size = size
	return s


## Does `part` (moved by `off`) overlap the world rect `r`? Exact for
## capsules and circles, the bounding rect for everything else.
static func _part_hits_rect(part: Dictionary, off: Vector2, r: Rect2) -> bool:
	var s: Shape2D = part.shape
	var p: Vector2 = part.pos + off
	if s is CapsuleShape2D or s is CircleShape2D:
		var rad: float = s.radius
		var half_seg := (s as CapsuleShape2D).height / 2.0 - rad if s is CapsuleShape2D else 0.0
		var dx := maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0)
		var dy := maxf(maxf(r.position.y - (p.y + half_seg), (p.y - half_seg) - r.end.y), 0.0)
		return dx * dx + dy * dy < rad * rad
	var b := s.get_rect()
	return Rect2(b.position + p, b.size).intersects(r)


## Solids the parts (moved by `off`) overlap: Collision cells of a solid
## kind (as Vector2i), other bodies on `body`'s mask (as the body) and any
## of the `extra` world rects (as Rect2: a standing ledge's lips).
static func _solids(body: PhysicsBody2D, parts: Array, off: Vector2, room: Room, extra: Array = []) -> Array:
	var out := []
	var space := body.get_world_2d().direct_space_state
	for part in parts:
		var s: Shape2D = part.shape
		var centre: Vector2 = part.pos + off
		for x: Rect2 in extra:
			if not out.has(x) and _part_hits_rect(part, off, x):
				out.append(x)
		if room != null:
			var b := s.get_rect()
			var local := Rect2(b.position + centre - room.global_position, b.size)
			var c0 := Vector2i((local.position / Room.TILE).floor())
			var c1 := Vector2i((local.end / Room.TILE).ceil())
			for y in range(c0.y, c1.y):
				for x in range(c0.x, c1.x):
					var cell := Vector2i(x, y)
					if out.has(cell) or not SOLID_KINDS.has(room.kind_at_cell(cell)):
						continue
					var cr := Rect2(room.global_position + Vector2(cell) * Room.TILE, Vector2(Room.TILE, Room.TILE))
					if _part_hits_rect(part, off, cr):
						out.append(cell)
		var q := PhysicsShapeQueryParameters2D.new()
		q.shape = s
		q.transform = Transform2D(0.0, centre)
		q.collision_mask = body.collision_mask
		q.exclude = [body.get_rid()]
		for hit in space.intersect_shape(q, 16):
			var col: Object = hit.collider
			if col is TileMapLayer or out.has(col):
				continue   # tiles are read from the kind grid above
			if col is CollisionObject2D:
				var sh := (col as CollisionObject2D).shape_owner_get_owner((col as CollisionObject2D).shape_find_owner(hit.shape))
				if sh is CollisionShape2D and (sh as CollisionShape2D).one_way_collision:
					continue
			out.append(col)
	return out
