extends RefCounted
class_name GlyphSet

## GlyphSet - a seeded alphabet of invented characters, baked as pen-ready ink.
##
## The alphabet is a grammar rather than a font: a small lattice of nodes, a seeded subset of the connections a pen may make
## between them, and a per-glyph walk over that subset. A seed produces a whole writing system with one consistent hand (slant,
## weight, terminal style, nib angle, curves). It lives outside any one scene because writing is also annotation: the `glyphs`
## scene writes a page of it, and a map or cross-section uses the same script for labels. A caller needing a smaller hand passes
## `advance` in `cfg`.
##
## A seed decides: the lattice (3x5 / 4x5 / a 7-node hex), which connections are legal, strokes per character, pen curvature,
## terminals (blunt, serifed or hooked), slant, broad-nib angle and contrast, the diacritic rate, and whether the hand joins its
## characters with a trailing hairline.
##
## Output per glyph: quad geometry already expanded to stroke width, in em space (x to the right, y from -1 at the cap line to 0
## at the baseline, slant already sheared in), so the per-frame transform is one native `Transform2D * PackedVector2Array` per glyph.
##
## Stroke width is baked and resolution independent: `weight` is in pixels at [constant REF_UNIT], the drawn size is `em * unit()`
## pixels, and `unit()` cancels, so the same geometry is correct at 720p and 4K.
##
## The nib: each segment's width is multiplied by `|sin(direction - nib_angle)|` eased toward 1 by the sampled contrast (0 is a
## monoline felt-tip, 0.85 a chisel).
##
## Antialiasing by texture: every stroke quad is drawn wider than its core and carries a 1-D alpha ramp across its width (see
## [method ramp_texture]), replacing [TriBatch]'s three quads per line with one per segment and letting a glyph share a single color.

## Pixels of screen height the sampled [member weight] is quoted at (the 1080-tall reference frame).
const REF_UNIT := 1080.0

## Fraction of a stroke quad's width that is fully opaque; the rest is the feather. 0.5 puts a 1 px gradient either side of a 2 px core.
const CORE := 0.5

## Texels across the alpha ramp (the profile is a trapezoid and the sampler interpolates it).
const RAMP := 16

const LATTICES := {
	"3x5": {"cols": 3, "rows": 5},
	"4x5": {"cols": 4, "rows": 5},
	"hex7": {"cols": 0, "rows": 0},
}

## Blunt is a cut reed, serif adds a written cross-tick at free ends, hook curls the exit of a stroke (a canvas quad has no cap).
const TERMINALS := ["blunt", "serif", "hook"]


## One character: quad geometry, plus the cumulative ink length that lets a pen reveal it stroke by stroke.
class Glyph:
	## 4 vertices per quad, one quad per stroke segment, in em space, in writing order.
	var verts := PackedVector2Array()
	## Parallel to [member verts]: the cross-width ramp coordinate for each vertex.
	var uvs := PackedVector2Array()
	## Cumulative centerline ink length at the END of each segment (em units).
	var seg_end := PackedFloat32Array()
	## Total ink length - the denominator of the pen's reveal parameter.
	var total := 0.0
	## How many separate pen-down strokes this character takes (diacritic included).
	var strokes := 0
	## Where a joining hairline arrives and leaves, on the baseline.
	var entry := Vector2.ZERO
	var exit := Vector2.ZERO


var glyphs: Array = []          # Array[Glyph], the alphabet itself
var lattice := "3x5"
var advance := 0.055            # pen advance per character, in unit fractions
var em := 0.08                  # cap height, in unit fractions (advance * aspect)
var aspect := 1.5               # cap height / advance - how tall the hand is
var fill := 0.72                # drawn character width as a fraction of the advance
var slant_deg := 0.0
var lean := 0.0                 # tan(slant), the shear already baked into the geometry
var weight := 2.2               # stroke core width in px at REF_UNIT
var terminal := "blunt"
var joined := false             # does the hand trail a hairline between characters
var diacritic_p := 0.15
var curve_max := 0.2
var nib_angle := 0.0
var nib_contrast := 0.4
var pressure := 0.15            # how much harder than nominal this nib can be pressed
var word_gap := 0.6             # extra advance between words, in advance units
var strokes_lo := 3
var strokes_hi := 6
var reserve := 0                # characters held out of the sound mapping, used as marks

var _perm := PackedInt32Array()     # 36 harmonic keys -> character index
var _marks := PackedInt32Array()    # the reserved characters, in order


## Roll a whole writing system. [param cfg] overrides individual decisions (`advance`, `aspect`, `weight`, `count`, `lattice`)
## for a caller that needs the hand to match something else.
func _init(rng: RandomNumberGenerator, cfg: Dictionary = {}) -> void:
	var lat_keys := LATTICES.keys()
	lattice = String(cfg.get("lattice", lat_keys[rng.randi() % lat_keys.size()]))
	advance = float(cfg.get("advance", rng.randf_range(0.035, 0.09)))
	aspect = float(cfg.get("aspect", rng.randf_range(1.10, 1.90)))
	em = maxf(0.001, advance * aspect)
	fill = rng.randf_range(0.62, 0.85)
	slant_deg = rng.randf_range(-12.0, 14.0)
	lean = tan(deg_to_rad(slant_deg))
	weight = float(cfg.get("weight", rng.randf_range(1.2, 4.0)))
	terminal = String(cfg.get("terminal", TERMINALS[rng.randi() % TERMINALS.size()]))
	joined = rng.randf() < 0.35
	diacritic_p = rng.randf_range(0.0, 0.35)
	curve_max = rng.randf_range(0.0, 0.45)
	nib_angle = rng.randf_range(-0.6, 0.9)
	nib_contrast = rng.randf_range(0.0, 0.85)
	pressure = float(cfg.get("pressure", rng.randf_range(0.0, 0.35)))
	word_gap = rng.randf_range(0.45, 1.10)
	strokes_lo = rng.randi_range(3, 4)
	strokes_hi = rng.randi_range(maxi(strokes_lo + 1, 5), 7)
	var count := int(cfg.get("count", rng.randi_range(18, 40)))

	var nodes := _nodes()
	var edges := _edges(nodes, rng)
	var adj := _adjacency(nodes.size(), edges)
	var seen := {}
	var guard := 0
	while glyphs.size() < count and guard < count * 12:
		guard += 1
		var strokes := _walk(nodes.size(), adj, rng)
		if strokes.size() < 2:
			continue
		var sig := _signature(strokes)
		if seen.has(sig):
			continue                        # a real alphabet has distinct letters
		seen[sig] = true
		glyphs.append(_forge(nodes, strokes, rng))

	# A few characters held back from the sound mapping become the hand's punctuation: marks that only appear at a word boundary.
	reserve = 0
	if glyphs.is_empty():
		return
	if rng.randf() < 0.45 and glyphs.size() >= 16:
		reserve = rng.randi_range(1, 3)
	var pool := glyphs.size() - reserve
	var order := PackedInt32Array()
	order.resize(glyphs.size())
	for i in glyphs.size():
		order[i] = i
	for i in range(glyphs.size() - 1, 0, -1):       # Fisher-Yates on the seeded rng
		var j := rng.randi() % (i + 1)
		var t := order[i]
		order[i] = order[j]
		order[j] = t
	_perm.resize(36)
	for i in 36:
		_perm[i] = order[i % maxi(1, pool)]
	_marks.resize(reserve)
	for i in reserve:
		_marks[i] = order[pool + i]


func count() -> int:
	return glyphs.size()


## The character this moment of music writes.
##
## The 12 chroma channels of [method Spectrum.harmonic_signature] pick a pitch class by argmax, and the coarse low/mid/high tilt
## picks one of three registers, so the key is 36 wide: the same chord in the same register writes the same character each time.
## A seeded permutation stands between the key and the alphabet, so which shape a chord means is per-session.
##
## [param step] is how many characters have already been written under this key; it walks the permutation on by a stride coprime
## with its 36 entries, so a chord names a word rather than a letter (the signature is an EMA over 2.5 s while the pen writes up
## to twelve characters a second, so its argmax holds still for tens of characters). The key still fixes where that word starts.
func pick(sig: PackedFloat32Array, step := 0) -> int:
	if glyphs.is_empty():
		return 0
	var k := key(sig)
	if k < 0 or _perm.is_empty():
		return 0
	return _perm[posmod(k + step * 7, _perm.size())]


## The 36-wide harmonic key this moment of music lands on, or -1 if there is no signature yet. Separate from [method pick] so a
## caller can notice the key changing (where one word ends and the next begins) without comparing characters.
func key(sig: PackedFloat32Array) -> int:
	if sig.size() < 16:
		return -1
	var pc := 0
	for k in 12:
		if sig[k] > sig[pc]:
			pc = k
	var tilt := 0
	if sig[13] > sig[12 + tilt]:
		tilt = 1
	if sig[14] > sig[12 + tilt]:
		tilt = 2
	return pc * 3 + tilt


## The i-th punctuation mark, or -1 if this hand does not punctuate.
func mark(i: int) -> int:
	if _marks.is_empty():
		return -1
	return _marks[posmod(i, _marks.size())]


## The visible prefix of character [param gi] after [param p] of its ink has been laid down (0 = pen down, 1 = finished), plus
## where the nib currently sits. The completed segments come out as a native slice of the baked array and only the segment under
## the nib is rebuilt. Returns `{verts, uvs, tip, dir, done}`.
func trace(gi: int, p: float) -> Dictionary:
	var out := {"verts": PackedVector2Array(), "uvs": PackedVector2Array(),
		"tip": Vector2.ZERO, "dir": Vector2.RIGHT, "done": false}
	if gi < 0 or gi >= glyphs.size():
		return out
	var g: Glyph = glyphs[gi]
	var n := g.seg_end.size()
	if n == 0:
		return out
	var want := clampf(p, 0.0, 1.0) * g.total
	var k := 0
	while k < n and g.seg_end[k] <= want:
		k += 1
	if k >= n:
		var last := (n - 1) * 4
		out["verts"] = g.verts
		out["uvs"] = g.uvs
		out["tip"] = (g.verts[last + 1] + g.verts[last + 2]) * 0.5
		out["dir"] = _edge_dir(g.verts[last], g.verts[last + 1])
		out["done"] = true
		return out
	var prev := 0.0 if k == 0 else float(g.seg_end[k - 1])
	var span := maxf(0.000001, float(g.seg_end[k]) - prev)
	var t := clampf((want - prev) / span, 0.0, 1.0)
	var base := k * 4
	var q0: Vector2 = g.verts[base]
	var q1: Vector2 = g.verts[base + 1]
	var q2: Vector2 = g.verts[base + 2]
	var q3: Vector2 = g.verts[base + 3]
	var e1 := q0.lerp(q1, t)
	var e2 := q3.lerp(q2, t)
	var v := g.verts.slice(0, base)
	var uv := g.uvs.slice(0, base)
	# Below a sliver the partial quad is degenerate and would flicker; the nib is still reported at the stroke's start.
	if t > 0.02:
		v.append(q0)
		v.append(e1)
		v.append(e2)
		v.append(q3)
		uv.append_array(g.uvs.slice(base, base + 4))
	out["verts"] = v
	out["uvs"] = uv
	out["tip"] = (e1 + e2) * 0.5
	out["dir"] = _edge_dir(q0, q1)
	return out


## The typed record of what this seed decided, for the scene's params / feedback.
func spec() -> Dictionary:
	return {
		"alphabet": glyphs.size(),
		"lattice": lattice,
		"strokes": "%d-%d" % [strokes_lo, strokes_hi],
		"terminal": terminal,
		"slant_deg": slant_deg,
		"weight": weight,
		"advance": advance,
		"aspect": aspect,
		"curve_max": curve_max,
		"nib_angle": nib_angle,
		"nib_contrast": nib_contrast,
		"pressure": pressure,
		"diacritic_p": diacritic_p,
		"joined": joined,
		"marks": reserve,
	}


# ---------------------------------------------------------------------------------
# The shared alpha-ramp texture: white, opaque across the middle [constant CORE] of
# its width, falling to nothing at both ends. Stretched across a stroke quad it IS
# the antialiasing. The outermost texels are exactly zero and the caller samples at
# texel centers ([method uv_lo] / [method uv_hi]), so nothing depends on the canvas
# item's repeat mode.
# ---------------------------------------------------------------------------------
static var _ramp_tex: Texture2D = null

static func ramp_texture() -> Texture2D:
	if _ramp_tex == null:
		var img := Image.create(RAMP, 1, false, Image.FORMAT_RGBA8)
		var half := float(RAMP - 1) * 0.5
		for i in RAMP:
			var d := absf(float(i) - half) / half        # 0 at the core, 1 at both rims
			var a := clampf((1.0 - d) / maxf(0.001, 1.0 - CORE), 0.0, 1.0)
			img.set_pixel(i, 0, Color(1.0, 1.0, 1.0, a))
		_ramp_tex = ImageTexture.create_from_image(img)
	return _ramp_tex


static func uv_lo() -> float:
	return 0.5 / float(RAMP)


static func uv_hi() -> float:
	return (float(RAMP) - 0.5) / float(RAMP)


## Pen pressure without rebuilding geometry. The width the eye reads is the ramp's opaque plateau inside the quad, so squeezing
## the ramp coordinate toward the middle (`u' = 0.5 + (u - 0.5) * k`, a [Transform2D], so a whole character's uv array is remapped
## by one native multiply) thins the stroke; the opaque core comes out at `baked / k`. The geometry is baked at full pressure and
## `k` only ever thins it.
##
## [param amount] is 0 (the hand's nominal weight) to 1 (leaning on it).
func uv_pressure(amount: float) -> Transform2D:
	var k := (1.0 + pressure) / (1.0 + pressure * clampf(amount, 0.0, 1.0))
	return Transform2D(0.0, Vector2(k, 1.0), 0.0, Vector2(0.5 * (1.0 - k), 0.0))


# ---------------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------------

# Lattice nodes in local coordinates: x in 0..1 across the character, y in -1..0 from the cap line down to the baseline.
func _nodes() -> PackedVector2Array:
	var out := PackedVector2Array()
	if lattice == "hex7":
		out.append(Vector2(0.5, -0.5))
		for k in 6:
			var a := TAU * float(k) / 6.0 + PI / 6.0
			out.append(Vector2(0.5 + 0.5 * cos(a), -0.5 + 0.5 * sin(a)))
		return out
	var m: Dictionary = LATTICES[lattice]
	var cols := int(m["cols"])
	var rows := int(m["rows"])
	for r in rows:
		for c in cols:
			out.append(Vector2(float(c) / float(cols - 1), -float(r) / float(rows - 1)))
	return out


# The grammar: which node pairs this hand may join. Full-height verticals and full-width horizontals are always candidates, plus
# short hops and clean diagonals; then a seeded subset of that is kept.
func _edges(nodes: PackedVector2Array, rng: RandomNumberGenerator) -> Array:
	var legal: Array = []
	var n := nodes.size()
	if lattice == "hex7":
		for i in n:
			for j in range(i + 1, n):
				legal.append(Vector2i(i, j))
	else:
		var m: Dictionary = LATTICES[lattice]
		var cols := int(m["cols"])
		for i in n:
			for j in range(i + 1, n):
				var dc := absi(j % cols - i % cols)
				var dr := absi(int(j / cols) - int(i / cols))
				if dc == 0 or dr == 0 or dc == dr or (dc <= 1 and dr <= 2):
					legal.append(Vector2i(i, j))
	var keep := rng.randf_range(0.45, 0.85)
	var out: Array = []
	for e in legal:
		if rng.randf() < keep:
			out.append(e)
	if out.size() < 8:
		out = legal                     # too sparse to write with; take the whole set
	return out


func _adjacency(n: int, edges: Array) -> Array:
	var adj: Array = []
	adj.resize(n)
	for i in n:
		adj[i] = PackedInt32Array()
	for e in edges:
		var v: Vector2i = e
		var a: PackedInt32Array = adj[v.x]
		a.append(v.y)
		adj[v.x] = a
		var b: PackedInt32Array = adj[v.y]
		b.append(v.x)
		adj[v.y] = b
	return adj


# One character as a walk over the grammar: the pen lands, runs a few legal connections without retracing itself, and occasionally
# lifts and lands elsewhere. Pure topology (an Array of Vector2i(node, node)); curvature is drawn later.
func _walk(n: int, adj: Array, rng: RandomNumberGenerator) -> Array:
	var want := rng.randi_range(strokes_lo, strokes_hi)
	var lift_p := rng.randf_range(0.12, 0.40)
	var used := {}
	var out: Array = []
	var cur := rng.randi() % n
	for k in want:
		if k > 0 and rng.randf() < lift_p:
			cur = rng.randi() % n
		var opts := _free(adj, cur, used)
		if opts.is_empty():
			cur = rng.randi() % n
			opts = _free(adj, cur, used)
		if opts.is_empty():
			break
		var nxt: int = opts[rng.randi() % opts.size()]
		used[mini(cur, nxt) * 64 + maxi(cur, nxt)] = true
		out.append(Vector2i(cur, nxt))
		cur = nxt
	return out


func _free(adj: Array, node: int, used: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	var a: PackedInt32Array = adj[node]
	for o in a:
		if not used.has(mini(node, o) * 64 + maxi(node, o)):
			out.append(o)
	return out


func _signature(strokes: Array) -> String:
	var keys := PackedInt32Array()
	for s in strokes:
		var v: Vector2i = s
		keys.append(mini(v.x, v.y) * 64 + maxi(v.x, v.y))
	keys.sort()
	var out := ""
	for k in keys:
		out += "%d," % k
	return out


# Local (0..1, -1..0) to em space: scale x by the character's width in ems and shear by the hand's slant.
func _em(p: Vector2) -> Vector2:
	var wr := fill / maxf(0.2, aspect)
	return Vector2(p.x * wr - p.y * lean, p.y)


# Topology plus curves, terminals and a diacritic, baked to quads.
func _forge(nodes: PackedVector2Array, strokes: Array, rng: RandomNumberGenerator) -> Glyph:
	var g := Glyph.new()
	var wr := fill / maxf(0.2, aspect)
	var deg := {}
	for s in strokes:
		var v: Vector2i = s
		deg[v.x] = int(deg.get(v.x, 0)) + 1
		deg[v.y] = int(deg.get(v.y, 0)) + 1
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var lines: Array = []
	for s in strokes:
		var v: Vector2i = s
		var a := _em(nodes[v.x])
		var b := _em(nodes[v.y])
		var pl := _polyline(a, b, rng.randf_range(-curve_max, curve_max))
		# Terminals live at ends the rest of the character does not reach. A hook is part of the stroke; a serif is its own tick,
		# written after the stroke it finishes.
		var ticks: Array = []
		if terminal == "hook" and int(deg.get(v.y, 0)) == 1 and pl.size() >= 2:
			var d := _edge_dir(pl[pl.size() - 2], pl[pl.size() - 1])
			var nrm := Vector2(-d.y, d.x) * side
			pl.append(b + d * 0.055 + nrm * 0.018)
			pl.append(b + d * 0.070 + nrm * 0.062)
		elif terminal == "serif":
			if int(deg.get(v.x, 0)) == 1:
				ticks.append(_serif(pl[0], _edge_dir(pl[0], pl[1])))
			if int(deg.get(v.y, 0)) == 1:
				ticks.append(_serif(pl[pl.size() - 1],
					_edge_dir(pl[pl.size() - 2], pl[pl.size() - 1])))
		lines.append(pl)
		for t in ticks:
			lines.append(t)
	if rng.randf() < diacritic_p:
		lines.append(_diacritic(wr, rng))
	g.strokes = lines.size()
	g.entry = Vector2(0.0, 0.0)
	g.exit = Vector2(wr, 0.0)
	_bake(g, lines)
	return g


func _serif(p: Vector2, d: Vector2) -> PackedVector2Array:
	var nrm := Vector2(-d.y, d.x) * 0.075
	var out := PackedVector2Array()
	out.append(p - nrm)
	out.append(p + nrm)
	return out


# A tick above the cap line or below the baseline: doubles an alphabet's apparent size.
func _diacritic(wr: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var x := wr * rng.randf_range(0.2, 0.8)
	var y := -1.16 if rng.randf() < 0.65 else 0.16
	var out := PackedVector2Array()
	var kind := rng.randi() % 3
	if kind == 0:                                  # a dot
		out.append(Vector2(x - 0.012, y))
		out.append(Vector2(x + 0.012, y))
	elif kind == 1:                                # a bar
		out.append(Vector2(x - wr * 0.22, y))
		out.append(Vector2(x + wr * 0.22, y))
	else:                                          # a slash
		out.append(Vector2(x - wr * 0.16, y + 0.07))
		out.append(Vector2(x + wr * 0.16, y - 0.07))
	return out


# A stroke as a quadratic bow. Segment count follows the curvature: a straight bar is one segment and one quad.
func _polyline(a: Vector2, b: Vector2, curve: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var d := b - a
	var l := d.length()
	var ac := absf(curve)
	var segs := 1
	if ac >= 0.04:
		segs = 2
	if ac >= 0.15:
		segs = 3
	if ac >= 0.30:
		segs = 4
	if segs == 1 or l < 0.000001:
		out.append(a)
		out.append(b)
		return out
	var mid := (a + b) * 0.5 + Vector2(-d.y, d.x).normalized() * curve * l
	for i in segs + 1:
		var t := float(i) / float(segs)
		var it := 1.0 - t
		out.append(a * (it * it) + mid * (2.0 * it * t) + b * (t * t))
	return out


func _nib(dir: Vector2) -> float:
	if nib_contrast <= 0.001:
		return 1.0
	var thin := 1.0 - nib_contrast * 0.75
	return thin + (1.0 - thin) * absf(sin(dir.angle() - nib_angle))


func _bake(g: Glyph, lines: Array) -> void:
	# Core width in em units (resolution-free: `weight` is px at REF_UNIT and unit() cancels). Baked at full pressure, because
	# [method uv_pressure] can only thin a stroke.
	var base_w := weight * (1.0 + pressure) / (REF_UNIT * em)
	var u0 := uv_lo()
	var u1 := uv_hi()
	var acc := 0.0
	for pl in lines:
		var p: PackedVector2Array = pl
		for i in range(p.size() - 1):
			var a: Vector2 = p[i]
			var b: Vector2 = p[i + 1]
			var d := b - a
			var l := d.length()
			if l < 0.000001:
				continue
			var dir := d / l
			var nrm := Vector2(-dir.y, dir.x)
			var w := base_w * _nib(dir)
			var hw := w / CORE * 0.5                # quad half width: core + feather
			var ext := dir * (w * 0.5)              # square caps, and they fill the joints
			var a2 := a - ext
			var b2 := b + ext
			var o := nrm * hw
			g.verts.append(a2 - o)
			g.verts.append(b2 - o)
			g.verts.append(b2 + o)
			g.verts.append(a2 + o)
			g.uvs.append(Vector2(u0, 0.5))
			g.uvs.append(Vector2(u0, 0.5))
			g.uvs.append(Vector2(u1, 0.5))
			g.uvs.append(Vector2(u1, 0.5))
			acc += l
			g.seg_end.append(acc)
	g.total = maxf(0.000001, acc)


static func _edge_dir(a: Vector2, b: Vector2) -> Vector2:
	var d := b - a
	if d.length_squared() < 0.000000000001:
		return Vector2.RIGHT
	return d.normalized()
