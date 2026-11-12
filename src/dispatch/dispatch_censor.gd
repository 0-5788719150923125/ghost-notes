extends Node2D
class_name DispatchCensor

## DispatchCensor - redacted words hidden over the picture, as an editor hides a name in a video after it was shot
## (next/dispatch.md; [constant DispatchScript.REDACT]). The terminal draws every word as written; this is drawn over the
## desk's finished frame, after the 3D, and covers each redacted run with a box cracked along a few long straight lines
## into large flat shards, each the average color of the frame under it (`shaders/dispatch_redact.gdshader`).
##
## The box belongs to the frame, not the glass: each run's rect on the terminal (padded; runs that then touch become one,
## [method groups]) is carried through the glass's bulge and the camera ([method on_glass], [method seen]), and the box is
## the upright rect round it, as a tracker draws one. It follows a beat behind ([constant LAG]), wavers outward a little
## ([constant WAVER]) and always holds the words' own rect ([method cover]). Its cracks are laid once per run, seeded by
## its words ([method cracks]), and stretch with the box: the shards keep their shapes, only their colors change.

## How many boxes the shader holds at once, and how deep each box's cracks go (LEAVES = 2^DEPTH shards at most; NODES
## lines) - the shader's arrays, about 12 KB, under the 16 KB a uniform block is sure of.
const MOST := 6
const DEPTH := 6
const NODES := 63
const LEAVES := 64
const SHADER := "res://shaders/dispatch_redact.gdshader"
## How far past the words a box reaches on the terminal, in its lines: sideways (into the space before and after them, not
## the next letter: at 0.6 "search" loses its "h"), and up and down from the letters' middle (short of the next line's
## letters, so a word left showing beside, above or below is still read).
const PAD_X := 0.3
const HALF_H := 0.62
## The tracker: the time it takes to close most of the way to where the words went (s, an exponential's), how far an edge
## wavers out past them (a share of the box's height), and how often its jitter steps (per second).
const LAG := 0.09
const WAVER := 0.08
const STEP_RATE := 11.0
## A shard's longest length, in the terminal's px: about three letters.
const SHARD := 56.0

## This frame's boxes: `{rect: Rect2 (px), key: int, aspect: float}`.
var boxes: Array = []
var _eased := {}                # a run's key -> where its box was, eased (Rect2)
var _cracks := {}               # a run's key -> its cracks ([method cracks])
var _last := -INF
var _mat := ShaderMaterial.new()


func _init() -> void:
	name = "DispatchCensor"
	_mat.shader = load(SHADER)
	material = _mat
	visible = false


## Hide [param runs] ({rect, key} on the terminal, [method DispatchScreens.redactions]) where [param cam] sees them on
## [param glass] (its face bulged by [param curve]) at show time [param now]: each group's box eased from where it was,
## wavered, never short of the words' own rect; the shader's arrays pushed whole.
func cover(runs: Array, glass: MeshInstance3D, curve: float, cam: Camera3D, now: float) -> void:
	var dt := now - _last
	_last = now
	var snap := dt < 0.0 or dt > 0.5
	var follow := 1.0 - exp(-maxf(dt, 0.0) / LAG)
	var next := {}
	boxes = []
	for g in groups(runs):
		var key := int(g["key"])
		while next.has(key):
			# the same words in the same column twice: each its own box
			key = hash([key, "again"])
		var exact := seen(g["rect"], glass, curve, cam)
		if exact.size.x <= 0.0 or boxes.size() >= MOST:
			continue
		var was: Rect2 = _eased.get(key, exact)
		var at := exact if snap else Rect2(was.position.lerp(exact.position, follow), Vector2.ZERO).expand(was.end.lerp(exact.end, follow))
		next[key] = at
		var out := exact.size.y * WAVER
		var lo := at.position - Vector2(waver(key, 0, now), waver(key, 1, now)) * out
		var hi := at.end + Vector2(waver(key, 2, now), waver(key, 3, now)) * out
		var r := g["rect"] as Rect2
		if not _cracks.has(key):
			_cracks[key] = cracks(key, r.size.x / r.size.y, SHARD / r.size.y)
		boxes.append({"rect": Rect2(lo, Vector2.ZERO).expand(hi).merge(exact), "key": key, "aspect": r.size.x / r.size.y})
	_eased = next
	for key in _cracks.keys():
		if not next.has(key):
			_cracks.erase(key)
	_push()


func _push() -> void:
	var packed := PackedVector4Array()
	packed.resize(MOST)
	var aspects := PackedFloat32Array()
	aspects.resize(MOST)
	var leaves := PackedVector4Array()
	leaves.resize(MOST * LEAVES)
	var lines := PackedVector3Array()
	lines.resize(MOST * NODES)
	lines.fill(Vector3(0, 0, 1))
	for i in boxes.size():
		var b: Dictionary = boxes[i]
		var q: Rect2 = b["rect"]
		packed[i] = Vector4(q.position.x, q.position.y, q.end.x, q.end.y)
		aspects[i] = float(b["aspect"])
		var laid: Dictionary = _cracks[int(b["key"])]
		var c: PackedVector3Array = laid["lines"]
		for k in NODES:
			lines[i * NODES + k] = c[k]
		var bb: PackedVector4Array = laid["leaves"]
		for k in LEAVES:
			leaves[i * LEAVES + k] = bb[k]
	_mat.set_shader_parameter("boxes", packed)
	_mat.set_shader_parameter("aspects", aspects)
	_mat.set_shader_parameter("leaves", leaves)
	_mat.set_shader_parameter("cracks", lines)
	_mat.set_shader_parameter("count", boxes.size())
	visible = not boxes.is_empty()
	queue_redraw()


func _draw() -> void:
	for b in boxes:
		draw_rect(b["rect"], Color.WHITE)


# --- where the boxes go -----------------------------------------------------------------------------------------------

## The runs as boxes on the terminal (px): each of [param runs] ({rect, key}) padded ([constant PAD_X], [constant HALF_H]),
## and those that then overlap made one (the names down a column of matches are one box): `{rect, key}`.
static func groups(runs: Array) -> Array:
	var line := DispatchScreens.TERM_LINE
	var out: Array = []
	for r in runs:
		var q: Rect2 = r["rect"]
		var mid := q.get_center().y
		out.append({"rect": Rect2(q.position.x - PAD_X * line, mid - HALF_H * line, q.size.x + 2.0 * PAD_X * line, 2.0 * HALF_H * line),
			"key": int(r["key"])})
	var merged := true
	while merged:
		merged = false
		for i in out.size():
			for j in range(i + 1, out.size()):
				var a: Rect2 = out[i]["rect"]
				var b: Rect2 = out[j]["rect"]
				if a.intersects(b):
					out[i] = {"rect": a.merge(b), "key": hash([out[i]["key"], out[j]["key"]])}
					out.remove_at(j)
					merged = true
					break
			if merged:
				break
	return out


## Where terminal pixel [param px] is shown on [param glass], in the world: a quad whose face `shaders/dispatch_screen.gdshader`
## bulges by [param curve], showing the face's point b at the quad's c where c (1 + curve |c|^2 / 2) = b.
static func on_glass(px: Vector2, glass: MeshInstance3D, curve: float) -> Vector3:
	var b := px / Vector2(DispatchScreens.TERM_SIZE) * 2.0 - Vector2.ONE
	var c := b
	for _i in 10:
		c = b / (1.0 + curve * c.dot(c) * 0.5)
	var size := (glass.mesh as QuadMesh).size
	return glass.global_transform * Vector3(c.x * 0.5 * size.x, -c.y * 0.5 * size.y, 0.0)


## The upright rect round [param r] (terminal px) in [param cam]'s frame, its edges followed through the bulge; empty when
## any of it is behind the camera.
static func seen(r: Rect2, glass: MeshInstance3D, curve: float, cam: Camera3D) -> Rect2:
	var out := Rect2()
	var first := true
	for k in 16:
		var u := float(k % 4) / 4.0
		var edge := k / 4
		var px: Vector2 = [r.position + Vector2(r.size.x * u, 0.0), Vector2(r.end.x, r.position.y + r.size.y * u),
			r.end - Vector2(r.size.x * u, 0.0), Vector2(r.position.x, r.end.y - r.size.y * u)][edge]
		var w := on_glass(px, glass, curve)
		if cam.is_position_behind(w):
			return Rect2()
		var s := cam.unproject_position(w)
		out = Rect2(s, Vector2.ZERO) if first else out.expand(s)
		first = false
	return out


## How far edge [param edge] of run [param key]'s box is out at [param now], 0 to 1: a slow drift and a tracker's small
## steps, a function of show time alone.
static func waver(key: int, edge: int, now: float) -> float:
	var h := hash([key, edge])
	var p1 := float(h & 0xffff) / 65535.0 * TAU
	var p2 := float((h >> 16) & 0xffff) / 65535.0 * TAU
	var slow := 0.5 + 0.5 * (0.6 * sin(now * 1.7 + p1) + 0.4 * sin(now * 3.9 + p2))
	return clampf(0.7 * slow + 0.3 * DispatchSounds.hash01(h, floori(now * STEP_RATE)), 0.0, 1.0)


## A box's cracks for [param key], on a box [param aspect] wide to its one high: a tree of straight lines, each right
## across the shard it splits (steep across a wide one, shallow along a tall one) until no shard is longer than
## [param most] (in box heights). A long box is often first cracked along its length, slanting across most of its height,
## so the cracks across it stagger as glass's do. `{lines, leaves}`: [constant NODES] lines `(n.x, n.y, d)`, a point p's
## side the sign of `n . p + d`, p in box heights from the top left, a node that does not split `(0, 0, 1)`; and each
## shard's bounds by the leaf [method shard] names (`x0, y0, x1, y1`), what the shader reads its color off.
static func cracks(key: int, aspect: float, most: float) -> Dictionary:
	var out := PackedVector3Array()
	out.resize(NODES)
	out.fill(Vector3(0, 0, 1))
	var leaves := PackedVector4Array()
	leaves.resize(LEAVES)
	var rng := RandomNumberGenerator.new()
	rng.seed = key
	_split(PackedVector2Array([Vector2(0, 0), Vector2(aspect, 0), Vector2(aspect, 1), Vector2(0, 1)]), 0, 0, most, out, leaves, rng)
	return {"lines": out, "leaves": leaves}


static func _split(poly: PackedVector2Array, node: int, depth: int, most: float, out: PackedVector3Array, leaves: PackedVector4Array, rng: RandomNumberGenerator) -> void:
	var lo := poly[0]
	var hi := poly[0]
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	if depth >= DEPTH:
		_leaf(node, depth, lo, hi, leaves)
		return
	var mid := Vector2.ZERO
	for p in poly:
		mid += p
	mid /= float(poly.size())
	var size := hi - lo
	var long := maxf(size.x, size.y)
	# a shard short enough is mostly left whole; one a little long is sometimes left too, so they are not all one size
	if long <= most * 0.75 or (long <= most and rng.randf() < 0.5):
		_leaf(node, depth, lo, hi, leaves)
		return
	var area := absf(_area(poly))
	var along := depth == 0 and size.x > size.y * 3.0 and rng.randf() < 0.7
	for _attempt in 4:
		var wide := size.x >= size.y
		var at := mid + (Vector2(size.x, 0.0) if wide else Vector2(0.0, size.y)) * rng.randf_range(-0.16, 0.16)
		var tilt := deg_to_rad(rng.randf_range(6.0, 38.0)) * (1.0 if rng.randf() < 0.5 else -1.0)
		var dir := Vector2(sin(tilt), cos(tilt)) if wide else Vector2(cos(tilt), sin(tilt))
		if along:
			at = mid + Vector2(size.x * rng.randf_range(-0.1, 0.1), 0.0)
			dir = Vector2(size.x, size.y * rng.randf_range(0.3, 0.7) * (1.0 if rng.randf() < 0.5 else -1.0)).normalized()
		var n := Vector2(dir.y, -dir.x)
		var d := -n.dot(at)
		var neg := _clip(poly, n, d, -1.0)
		var pos := _clip(poly, n, d, 1.0)
		if neg.size() < 3 or pos.size() < 3 or absf(_area(neg)) < area * 0.18 or absf(_area(pos)) < area * 0.18:
			continue
		out[node] = Vector3(n.x, n.y, d)
		_split(neg, 2 * node + 1, depth + 1, most, out, leaves, rng)
		_split(pos, 2 * node + 2, depth + 1, most, out, leaves, rng)
		return
	_leaf(node, depth, lo, hi, leaves)


## A shard left whole at [param node], [param depth] down: its bounds put where [method shard] ends for it (a node that
## does not split sends every point to its second child, down to the leaves).
static func _leaf(node: int, depth: int, lo: Vector2, hi: Vector2, leaves: PackedVector4Array) -> void:
	var n := node
	for _d in DEPTH - depth:
		n = 2 * n + 2
	leaves[n - NODES] = Vector4(lo.x, lo.y, hi.x, hi.y)


## The part of convex [param poly] on [param side] (-1 or 1) of the line `n . p + d = 0`.
static func _clip(poly: PackedVector2Array, n: Vector2, d: float, side: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var fa := (n.dot(a) + d) * side
		var fb := (n.dot(b) + d) * side
		if fa >= 0.0:
			out.append(a)
		if (fa >= 0.0) != (fb >= 0.0):
			out.append(a.lerp(b, fa / (fa - fb)))
	return out


static func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		s += poly[i].cross(poly[(i + 1) % poly.size()])
	return s * 0.5


## Which shard of a box point [param p] (box heights from its top left) is in, by [param lines] ([method cracks]); the
## shader's `shard`, line for line.
static func shard(lines: PackedVector3Array, p: Vector2) -> int:
	var n := 0
	for d in DEPTH:
		var k := lines[n]
		n = 2 * n + (1 if k.x * p.x + k.y * p.y + k.z < 0.0 else 2)
	return n
