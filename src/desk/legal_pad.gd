extends Node3D
class_name LegalPad

## LegalPad - the desk's pad ([DeskMedium]): its cardboard back, its stack, the binding across its head,
## the page being written, and the pages turned over its head.
##
## A PAGE IS TURNED AS A HAND TURNS ONE (the user, 2026-10-19: "When a page is turned, it sort of just
## disappears. Can we do a proper page turn, which gently lifts the head of the pad and folds the paper
## around the back? ... a turned page will COVER that top part of the paper. And multiple pages might
## fan-apart a bit, giving more depth"). The sheet was a rigid plane swung about the pad's top edge and
## hidden once it was over. Now it is lifted at its foot, the bottom right corner a little ahead
## ([constant LEAD]), and ROLLED: flat on the pad up to where it has lifted, round a bend that moves up
## the page toward the binding as it tightens - the notebook's peeling photo's roller ([NotebookMedium]),
## here as long as the page - and straight beyond it, its free end trailing while it swings
## ([constant TRAIL]). As it comes over the binding the pad's head is lifted on its foot ([method tilt]),
## the free end curls down behind it and under, and the head comes back down on it as the curl tightens
## round the binding ([method curve]): the page is folded round the back of the pad, its end under it.
## A page left lying flat behind the pad (as one does on a desk) was the first cut: it read as a sheet
## on the desk, not a page turned on a pad.
##
## IT STAYS ROUND THE HEAD. Each page turned later comes over it a little rounder ([constant GAP]): a
## page's root is under the roots of the pages turned before it, so its loop goes round theirs, the
## newest outermost. The loops' bulge in front of the binding covers the top of the page being
## written, above its first rule, and they fan apart round the head. The [constant KEPT] newest are
## drawn - older ones lie inside them, unseen - and as one more comes over, the rest close up a loop's
## width.
##
## A PURE FUNCTION of how many pages are over and how far the one turning has gone ([method show_turned]),
## so a seek lands on the pad as it was. A sheet is its profile, a curve in the pad's own (z, y) - z
## toward the foot, y up - from its root at the page's top edge, under the binding, to its foot, swept
## across the pad's width; the pad's body, every sheet with it, is turned on its foot by the tilt.

## The pad's size (meters): an 8.5 x 11 page, how thick the whole pad is, its cardboard back, and the
## binding across its head - how far down the front it reaches, past the page's top edge, and how high
## it stands over the page.
const W := 0.2159
const H := 0.2794
const THICK := 0.0055
const BOARD := 0.0012
const BIND_W := 0.022
const BIND_OVER := 0.0015
const TAPE_TOP := 0.0017
## Where the desk's face is under the pad (meters, the pad's frame): the pad lies on whatever is on
## it, at most [constant Tables.LAYERS_UNDER] thick.
const DESK_Y := -THICK - Tables.LAYERS_UNDER - 0.0001
## A sheet: the points along it, the steps between two of them, and the columns across a turning one.
const SAMPLES := 240
const STEPS := 2
const COLUMNS := 8
## THE LOOPS round the pad's head: the innermost's radius over the binding, how much rounder each later
## page's is (and how much that varies), and how many are drawn.
const LOOP := 0.007
const GAP := 0.0006
const GAP_SPREAD := 0.35
const KEPT := 8
## The roots: how high the newest page's is over the page being written, each older one a little
## higher (it lay over it in the pad).
const ROOT_Y := 0.0004
const ROOT_STEP := 0.0001
## Under the pad: how far below its back the oldest page's end lies, each later one a little lower.
const UNDER := 0.00005
const UNDER_STEP := 0.00004
## Where a page turns down behind the head: this far behind the binding's back.
const BEHIND := 0.0015
## THE TURN, as shares of [constant DeskScript.TURN]: the sheet is over the binding by [constant FLIP];
## its free end curls under over [constant WRAP]; the head is lifted over the first two of [constant
## RAISE] and set down over the last two, by [constant RAISE_MOST] radians at most, and the curl is
## tight round the head as it is down.
const FLIP := 0.45
const WRAP := Vector2(0.36, 0.62)
const RAISE := Vector3(0.2, 0.48, 0.62)
const RAISE_DOWN := 0.92
const RAISE_MOST := 0.42
## THE LIFT: the bend's radius as the foot first lifts, how far up the page it lifts from (a share of
## its length), how much the free end trails while it swings, and how far ahead (of the turn's 0 to 1)
## the bottom right corner is mid-turn.
const ROLL := 0.10
const PEEL := 0.62
const TRAIL := 1.2
const LEAD := 0.07
## How far a sheet keeps above the desk while the head is up (meters).
const CLEAR := 0.0004
## Paper is not quite white under the lamp: what the page's texture is multiplied by.
const TINT := Color(0.93, 0.92, 0.88)

const SHEET_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D front : source_color, filter_linear;
uniform float has_front = 1.0;
uniform vec3 tint : source_color = vec3(0.93, 0.92, 0.88);
uniform vec3 back : source_color = vec3(0.9, 0.88, 0.8);

// A small box filter over the pixel's footprint (the book's, BookMedium.LEAF_SHADER): a page's target
// has no mipmaps, and its thin rules minified without them broke into dashes in a wide shot.
vec4 tap(sampler2D tex, vec2 uv) {
	vec2 dx = dFdx(uv) * 0.38;
	vec2 dy = dFdy(uv) * 0.38;
	vec4 c = texture(tex, uv) * 2.0;
	c += texture(tex, uv + dx + dy);
	c += texture(tex, uv + dx - dy);
	c += texture(tex, uv - dx + dy);
	c += texture(tex, uv - dx - dy);
	return c / 6.0;
}

void fragment() {
	// the page's face is written; its back is plain paper
	ALBEDO = FRONT_FACING && has_front > 0.5 ? tap(front, UV).rgb * tint : back;
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
}
"""

## The episode's seed: how much rounder each page's loop is than the last.
var seed := 1
var _body: Node3D                  # the pad itself, turned on its foot as a page is tucked under it
var _page: MeshInstance3D
var _turning: MeshInstance3D
var _over: Array = []              # the pages lying over, newest last
var _turn_mat: ShaderMaterial
var _over_mat: ShaderMaterial
var _parts: Array = []             # cardboard, stack, binding: rebuilt with a new look
var _shown := ""


## THE PAD, built: its back, its stack, its binding in [param look]'s colors ([method DeskLook.of]),
## the page being written (its texture [param page]), and the turning sheet's face [param turning].
func build(look: Dictionary, page: Texture2D, turning: Texture2D) -> void:
	for n in _parts:
		(n as Node).queue_free()
	_parts = []
	if _body == null:
		_body = Node3D.new()
		add_child(_body)
	var paper: Color = look.get("paper", Color(0.985, 0.972, 0.9))
	var top := -H * 0.5
	var head := top - BIND_W
	# the cardboard back, a little wider and longer than the paper
	_part(_box(Vector3(W + 0.004, BOARD, H + BIND_W + 0.005), Vector3(0.0, -THICK + BOARD * 0.5, (head + H * 0.5) * 0.5),
		look.get("board", Color(0.32, 0.27, 0.22)), 0.9))
	# the stack of pages under the one being written, its edges a little darker than a face
	_part(_box(Vector3(W, THICK - BOARD, H + BIND_W), Vector3(0.0, -(THICK - BOARD) * 0.5, (head + H * 0.5) * 0.5),
		paper.darkened(0.12), 0.95))
	# the binding: a tape wrapped over the head, its front edge a little over the page's top
	var tape := _box(Vector3(W + 0.005, THICK + TAPE_TOP + 0.0003, BIND_W + BIND_OVER + 0.0025),
		Vector3(0.0, (TAPE_TOP - THICK - 0.0003) * 0.5, top + (BIND_OVER - BIND_W - 0.0025) * 0.5),
		look.get("binding", Color(0.5, 0.1, 0.1)), 0.55)
	_part(tape)
	if _page == null:
		_page = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(W, H)
		_page.mesh = pm
		_page.position = Vector3(0.0, 0.0002, 0.0)
		_body.add_child(_page)
		_turn_mat = _sheet_material(turning, true)
		_over_mat = _sheet_material(null, false)
		_turning = MeshInstance3D.new()
		_turning.material_override = _turn_mat
		_body.add_child(_turning)
		for _k in KEPT:
			var m := MeshInstance3D.new()
			m.material_override = _over_mat
			_body.add_child(m)
			_over.append(m)
	_page.material_override = _sheet_material(page, true)
	var back := Color(paper.r * TINT.r, paper.g * TINT.g, paper.b * TINT.b).darkened(0.02)
	_turn_mat.set_shader_parameter("back", back)
	_over_mat.set_shader_parameter("back", back)
	_shown = ""
	for m in _over:
		(m as MeshInstance3D).set_meta("shape", "")


func _part(m: MeshInstance3D) -> void:
	_body.add_child(m)
	_parts.append(m)


static func _box(size: Vector3, at: Vector3, color: Color, rough: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	m.material_override = mat
	m.position = at
	return m


static func _sheet_material(front: Texture2D, written: bool) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = SHEET_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("front", front)
	mat.set_shader_parameter("has_front", 1.0 if written else 0.0)
	mat.set_shader_parameter("tint", TINT)
	return mat


## SHOWS [param over] pages turned and lying round the pad's head and, while [param u] is 0 to 1, the
## next turning over them (its face the turning texture [method build] was handed), the pad's head
## lifted as it is tucked under; -1, none is. Rebuilt only when either has changed.
func show_turned(over: int, u: float) -> void:
	var key := "%d|%.4f" % [over, u]
	if key == _shown:
		return
	_shown = key
	var e := turn_progress(u) if u >= 0.0 else 0.0
	var beta := tilt(u) if u >= 0.0 else 0.0
	_body.transform = body_at(beta)
	var lo := maxi(0, over - KEPT)
	for k in KEPT:
		var j := lo + k
		var m: MeshInstance3D = _over[k]
		var r := rank(j, over, e)
		m.visible = j < over and r >= 0.0
		var mk := "%d|%.4f" % [j, r]
		if m.visible and m.get_meta("shape", "") != mk:
			# a page round the head moves with the pad's body; its shape changes only as its rank does
			var c := curve(1.0, loop_of(j, r, seed), root_of(r), under_of(r))
			m.mesh = sheet_mesh(c, c, 2)
			m.set_meta("shape", mk)
	_turning.visible = u >= 0.0
	if u >= 0.0:
		var r := rank(over, over, e)
		var lead := LEAD * sin(PI * clampf(u / FLIP, 0.0, 1.0))
		var lc := curve(clampf(u - lead, 0.0, 1.0), loop_of(over, r, seed), root_of(r), under_of(r), beta)
		var rc := curve(clampf(u + lead, 0.0, 1.0), loop_of(over, r, seed), root_of(r), under_of(r), beta)
		_turning.mesh = sheet_mesh(lc, rc, COLUMNS)


## The pad's body turned on its foot by [param beta] radians, its head up.
static func body_at(beta: float) -> Transform3D:
	var foot := Vector3(0.0, -THICK, H * 0.5 + 0.0025)
	return Transform3D(Basis.IDENTITY, foot) * Transform3D(Basis(Vector3.RIGHT, beta), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -foot)


## A point of the pad's body (z, y) where it is on the desk with the head up [param beta] radians: in
## the pad's frame, the one the pen and the camera know.
static func lifted(q: Vector2, beta: float) -> Vector2:
	var p := body_at(beta) * Vector3(0.0, q.y, q.x)
	return Vector2(p.z, p.y)


## HOW FAR THE PAD'S HEAD IS LIFTED [param u] of the way through a turn (radians): up as the page comes
## over, held while its end goes under, and down again before the pen comes back ([constant
## DeskMedium.PARK_BACK]).
static func tilt(u: float) -> float:
	var up := _ease(clampf((u - RAISE.x) / (RAISE.y - RAISE.x), 0.0, 1.0))
	var down := _ease(clampf((u - RAISE.z) / (RAISE_DOWN - RAISE.z), 0.0, 1.0))
	return RAISE_MOST * up * (1.0 - down)


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## How far over a turn [param u] of the way through its time has the sheet gone: eased in and out.
static func turn_progress(u: float) -> float:
	var x := clampf(u, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## PAGE [param j]'s place among the loops, 0 the innermost drawn, with [param over] pages over and the
## next [param e] of the way over them: past [constant KEPT] they close up a loop's width as it comes.
static func rank(j: int, over: int, e: float) -> float:
	return float(j) - maxf(0.0, float(over) + e - float(KEPT))


## The radius of page [param j]'s loop at [param r] (its [method rank]): each later page's a gap
## rounder, by a little more or less ([param seed]'s), and never as little as its root's step.
static func loop_of(j: int, r: float, seed: int) -> float:
	var h := float(absi(hash(["pad-loop", seed, j])) % 10007) / 10006.0
	return LOOP + maxf(r, 0.0) * GAP + GAP * GAP_SPREAD * (h - 0.5)


static func root_of(r: float) -> float:
	return ROOT_Y + (float(KEPT) - r) * ROOT_STEP


static func under_of(r: float) -> float:
	return -THICK - UNDER - maxf(r, 0.0) * UNDER_STEP


## A SHEET'S PROFILE: (z, y) in the pad's body at [constant SAMPLES] even steps along it, from its root
## (the page's top edge, under the binding) to its foot. [param u] is how far through its turn it is -
## 0 flat on the pad, 1 round the head with its end under the pad - [param loop] the radius it goes over
## the binding at, [param root] how high its root is, [param under] how far under the pad its end lies,
## and [param beta] how far the head is lifted (it keeps off the desk).
##
## Its angle along it: 0 (flat) up to where it has lifted, then round a bend of a radius that tightens
## from [constant ROLL] to [param loop] as the lift moves up the page, its free part straight on, trailing
## while it swings. Once it is over, past the binding, the free part curls down: at first all of it one
## arc, so a page hangs no lower than a hand would let it, then - as the head comes down - a bend round
## the head's back, as tight as the loop, and the rest straight under the pad.
static func curve(u: float, loop: float, root: float, under: float, beta := 0.0) -> PackedVector2Array:
	var top := -H * 0.5
	var a := _ease(clampf(u / FLIP, 0.0, 1.0))
	var phi := PI * a
	var peel := PEEL * H * pow(1.0 - a, 1.4)
	var r := loop + (ROLL - loop) * pow(1.0 - a, 1.6)
	var bend := peel + phi * r
	var trail := -TRAIL * sin(phi) * (1.0 - a) / H
	# behind the head it turns down: all its free part one arc while it swings, then tightening round
	# the head's back as the head comes down
	var back := top - BIND_W - 0.0025 - BEHIND
	var turn_at := bend + (top - back)
	var free := maxf(H - turn_at, 0.001)
	var phi2 := PI * _ease(clampf((u - WRAP.x) / (WRAP.y - WRAP.x), 0.0, 1.0))
	var tight := (root + 2.0 * loop - under) * 0.5
	var rho := minf(free / maxf(phi2, 1e-3), 0.6)
	if u > WRAP.y:
		var k := pow(tilt(u) / RAISE_MOST, 1.3)
		rho = tight + (free / PI - tight) * k
	var out := PackedVector2Array()
	var p := Vector2(top, root)
	out.append(p)
	var ds := H / float((SAMPLES - 1) * STEPS)
	var s := 0.0
	for _i in range(1, SAMPLES):
		for _k in STEPS:
			var mid := s + ds * 0.5
			var th := 0.0
			if mid >= bend:
				th = phi + trail * (mid - bend)
				if mid >= turn_at:
					th += minf((mid - turn_at) / rho, phi2)
			elif mid > peel:
				th = (mid - peel) / r
			p += Vector2(cos(th), sin(th)) * ds
			if p.y > -THICK * 0.5:
				p.y = maxf(p.y, floor_at(p.x, root))
			s += ds
		out.append(_off_desk(p, beta))
	return out


## What is under a sheet at [param z] over the pad (its body's frame): the page up to its top edge
## (where the sheet lies at its [param root]) and the binding over the head; nothing behind it.
static func floor_at(z: float, root: float) -> float:
	var top := -H * 0.5
	if z >= top:
		return root
	if z >= top - BIND_W - 0.0025:
		return TAPE_TOP + 0.0002
	return -INF


## [param p] (the body's frame) kept [constant CLEAR] above the desk the body stands on with its head up
## [param beta]: where it would be under the desk's face, it lies on it.
static func _off_desk(p: Vector2, beta: float) -> Vector2:
	var w := lifted(p, beta)
	if w.y >= DESK_Y + CLEAR:
		return p
	var back := body_at(beta).affine_inverse() * Vector3(0.0, DESK_Y + CLEAR, w.x)
	return Vector2(back.z, back.y)


## A sheet's mesh between its left edge's profile [param left] and its right edge's [param right], in
## [param columns] across: its face (UV as the page's texture) up when it lies flat.
static func sheet_mesh(left: PackedVector2Array, right: PackedVector2Array, columns: int) -> ArrayMesh:
	var n := left.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var pts: Array = []
	for i in n:
		var row := PackedVector3Array()
		for c in columns:
			var f := float(c) / float(columns - 1)
			var q := left[i].lerp(right[i], f)
			row.append(Vector3((f - 0.5) * W, q.y, q.x))
		pts.append(row)
	for i in n:
		for c in columns:
			var along: Vector3 = (pts[mini(i + 1, n - 1)] as PackedVector3Array)[c] - (pts[maxi(i - 1, 0)] as PackedVector3Array)[c]
			var across: Vector3 = (pts[i] as PackedVector3Array)[mini(c + 1, columns - 1)] - (pts[i] as PackedVector3Array)[maxi(c - 1, 0)]
			var nrm := along.cross(across)
			verts.append((pts[i] as PackedVector3Array)[c])
			normals.append(nrm.normalized() if nrm.length() > 1e-9 else Vector3.UP)
			uvs.append(Vector2(float(c) / float(columns - 1), float(i) / float(n - 1)))
	var idx := PackedInt32Array()
	for i in n - 1:
		for c in columns - 1:
			var a := i * columns + c
			var b := a + 1
			var d := a + columns
			var e := d + 1
			idx.append_array([a, b, d, b, e, d])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
