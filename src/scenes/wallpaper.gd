extends GhostScene

## wallpaper - one motif, one symmetry group, and the whole plane follows.
##
## A flat printed pattern, edge to edge: three to five solid inks, thin keylines, no glow,
## gradient or soft edge. One small motif (bars, a wedge, a disc, an arc) is repeated by an
## actual plane symmetry group, so the mirrors, glides and rotation centers are real. The group
## table, its closure and the lattice walk live in [WallpaperGroup].
##
## Nothing moves as a particle. The music re-inks the pattern: every motif element is bound at
## build to a pitch class; a few times a second the twelve chroma bins of
## [method Spectrum.harmonic_signature] are ranked, and each element takes the ink its pitch
## class's rank points at, so one chord change repaints hundreds of copies on the same tick.
## `f.beat` starts a lattice glide: the tiling translates by exactly one lattice vector over a
## fraction of the beat period and lands back in register (a step, not a scroll). `f.movement`
## cross-fades the motif between two seeded vertex sets (a radial lerp with matched counts).
## `f.energy` moves the keyline alpha inside a narrow sampled band.
##
## The seed decides the group (of seventeen, weighted toward the richer ones), the lattice
## aspect and angle, the motif's elements, the morph jitter, the [Scheme] mood and ink count, a
## high-key or near-black ground, the keyline, the re-rank rate and the glide.
##
## The cell size is derived, not sampled: cells x group order x elements is the polygon count
## (18x18 cells of five elements under p6m, order 12, is 19,440 polygons). A total motif budget
## is sampled, the element count is capped against the group's order, and the cell length is
## solved from the budget, clamped so cells across the frame stay in [5, 18].
##
## The motif is identical in every cell, so the frame is built once per cell and that triangle
## array is submitted per cell under a shifted transform: two RenderingServer calls per cell
## instead of tens of thousands of vertex appends.

const OVER := 1.35            # draw this far beyond the frame, for view drift headroom

## How far past its own cell origin the motif can reach, in cell lengths (element centers sit in
## roughly the first half of the cell, radii top out near 0.2, and the glide adds a whole lattice
## vector). Cells are enumerated with this as their margin.
const MOTIF_REACH := 2.0

## Total motifs drawn, whatever group was picked. The low end is where a pattern stops reading as
## a pattern; the high end is the frame budget (see the packet note in the header).
const BUDGET := [500.0, 1800.0]

## The keyline is feathered ([constant TriBatch.FEATHER]) only while the pattern is sparse:
## feathering triples a line's triangle count, and keylines are the most numerous thing on
## screen. Past this many motifs the hard-edged form is used (a printed rule is crisp anyway).
const SOFT_KEYLINE_MAX := 800

## How fast the morph follows f.movement, per second of simulated time: slow enough that a
## transient does not twitch the plane, fast enough that a section change completes promptly.
const MORPH_RATE := 1.6

## Groups, weighted by how much pattern they make: p1 is a plain repeat and appears once; the
## mirror and 6-fold groups appear more often.
const GROUP_POOL := [
	"p1", "p2", "p2", "pm", "pm", "pg", "cm", "cm", "pmm", "pmg", "pgg",
	"cmm", "p4", "p4", "p4m", "p4m", "p4g", "p3", "p3m1", "p31m", "p6", "p6m", "p6m",
]

## Where in the cell the motif's anchor may sit, in fractional coordinates: a stand-in for the
## group's true asymmetric unit. This corner is near enough to the fundamental domain that the
## copies interleave instead of piling on the rotation center; the hexagonal region is squatter
## because a hex cell's fundamental wedge lies close to the a1 edge.
const SEED_REGION := {
	"oblique": {"u": [0.08, 0.44], "v": [0.08, 0.44]},
	"rect":    {"u": [0.08, 0.44], "v": [0.08, 0.44]},
	"square":  {"u": [0.10, 0.42], "v": [0.10, 0.42]},
	"hex":     {"u": [0.12, 0.46], "v": [0.04, 0.26]},
}

const KINDS := ["bar", "wedge", "disc", "arc"]

var _f: AudioFeatures = AudioFeatures.new()
var _sim := SimClock.new(60.0)
var _tb := TriBatch.new()
var _group: WallpaperGroup = null
var _offsets := PackedVector2Array()
var _cell := 0.0                     # current cell length, px
var _els: Array = []                 # the motif: one Dictionary per element
var _inks: Array = []                # Color per ink
var _ink_of := PackedInt32Array()    # element index -> ink index, re-ranked on the beat clock
var _key_col := Color.BLACK
var _dirs: Array = []                # glide directions, as lattice coefficient pairs
var _ch := Vector2.ZERO              # live tonal color (hue, strength)
var _prev_beat := 0.0
var _beat_n := 0
var _dir_i := 0
var _gliding := false
var _glide_p := 0.0
var _glide_dur := 0.5
var _morph := 0.0
var _morph_target := 0.0
var _reink_t := 0.0


## What this scene can be told ([method GhostScene.choice], [method GhostScene.number]): a
## storyboard entry's `set`, by name; a setting not told is drawn from the seed.
const FIELDS := {
	"group": {"label": "Group", "type": "choice", "options": "GROUP_POOL", "default": null,
		"blurb": "Which of the 17 wallpaper symmetry groups tiles the pattern, from a plain p1 repeat to the mirror and six-fold groups."},
	"cell_ratio": {"label": "Cell ratio", "type": "num", "range": [0.72, 1.40], "default": null,
		"blurb": "How stretched the repeating tile is, where the symmetry group allows it."},
	"inks": {"label": "Ink colors", "type": "num", "range": [2, 4], "default": null,
		"blurb": "How many related ink colors the pattern is printed in."},
	"keyline": {"label": "Keyline width", "type": "num", "range": [0.8, 2.4], "default": null,
		"blurb": "How thick the outline around each shape is."},
	"glide_beats": {"label": "Glide beats", "type": "num", "range": [1, 4], "default": null,
		"blurb": "How many beats pass between one glide of the pattern and the next."},
	"cluster": {"label": "Motif cluster", "type": "num", "range": [0.05, 0.20], "default": null,
		"blurb": "How tightly the shapes of each motif gather together."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "canvas"
	framing = "field"
	# A printed pattern is abstract matter: take the whole mood set.
	var sch := Scheme.pick(rng)
	var gname := String(choice("group", rng))
	var ratio: float = number("cell_ratio", rng)
	var angle := rng.randf_range(50.0, 90.0)
	# Build the group once at unit cell length only to learn its order, which the element count
	# is capped against.
	var probe := WallpaperGroup.make(gname, 1.0, ratio, angle)
	var order := probe.order()
	# Order x elements is the per-cell polygon count. Holding it near 30 keeps a p6m instance from
	# needing forty cells' worth of budget in one cell.
	var n_el := rng.randi_range(2, clampi(int(30.0 / float(order)), 2, 5))

	var high_key := rng.randf() < 0.5
	var n_hue: int = number("inks", rng)
	_inks = _build_inks(rng, sch, n_hue, high_key)
	_key_col = (Color.from_hsv(sch.hue, 0.22, rng.randf_range(0.05, 0.11))
		if high_key else Color.from_hsv(sch.hue, 0.08, rng.randf_range(0.88, 0.97)))

	_els = _build_motif(rng, probe, n_el, _inks.size())
	_ink_of.resize(n_el)
	for i in n_el:
		var el: Dictionary = _els[i]
		_ink_of[i] = int(el["home"])

	# The glide walks a seeded ring of lattice vectors, never an rng draw on an audio event: the
	# live analyzer and the offline bake give different beat streams, and an export that stepped
	# differently from its preview would be a different video.
	_dirs = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1)]
	for i in range(_dirs.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = _dirs[i]
		_dirs[i] = _dirs[j]
		_dirs[j] = tmp
	_dirs.resize(rng.randi_range(2, 4))

	var kinds: Array = []
	var pitches: Array = []
	for i in n_el:
		var el2: Dictionary = _els[i]
		kinds.append(el2["kind"])
		pitches.append(el2["pitch"])

	# Keyline alpha rides f.energy (the mean over 64 bands, rarely past 0.5), so the band is
	# narrow and the drive is scaled up to reach across it.
	var key_lo := rng.randf_range(0.30, 0.68)
	var g_sat := rng.randf_range(0.03, 0.11) if high_key else rng.randf_range(0.18, 0.44)
	var g_val := rng.randf_range(0.88, 0.97) if high_key else rng.randf_range(0.05, 0.12)
	return {
		"group": gname,
		"order": order,
		"lattice": probe.lattice,
		"ratio": ratio,
		"angle": angle,
		"mood": sch.name,
		"elements": n_el,
		"kinds": kinds,
		"pitch_classes": pitches,
		"inks": _inks.size(),
		"ink_hues": n_hue,
		"high_key": high_key,
		"ground_sat": g_sat,
		"ground_val": g_val,
		"ground_hue": sch.hue,
		"tint": rng.randf_range(0.20, 0.45),
		"key_width": number("keyline", rng),
		"key_lo": key_lo,
		"key_hi": minf(1.0, key_lo + rng.randf_range(0.10, 0.32)),
		"budget": rng.randf_range(float(BUDGET[0]), float(BUDGET[1])),
		"beat_thr": rng.randf_range(0.35, 0.60),
		"glide_every": number("glide_beats", rng),
		"glide_frac": rng.randf_range(0.35, 0.80),
		"reink_hold": rng.randf_range(0.10, 0.30),
		"morph_gain": rng.randf_range(0.8, 1.6),
	}


# The inks: a run of related hues from the Scheme, plus one extreme that the ground decides. On
# a high-key ground an ink drifting toward it stops being an ink, so on paper every ink is
# capped in value and floored in saturation and the extra ink is near-black; on a dark ground
# it is near-white.
func _build_inks(rng: RandomNumberGenerator, sch: Scheme, n_hue: int, high_key: bool) -> Array:
	var out: Array = []
	# hue_at's own construction, but with the far end pushed out by Scheme.opposed first: several
	# moods keep their accent within 0.04 of the base, and two inks that close read as one.
	var h0 := sch.hue
	var h1 := sch.opposed(h0, rng.randf_range(0.18, 0.34))
	var d := fposmod(h1 - h0 + 0.5, 1.0) - 0.5
	for i in n_hue:
		var t := float(i) / float(maxi(1, n_hue - 1))
		var c := sch.color(fposmod(h0 + d * t, 1.0),
			rng.randf_range(0.85, 1.25), rng.randf_range(0.85, 1.15))
		var s := c.s
		var v := c.v
		if high_key:
			v = minf(v, 0.80)
			s = maxf(s, 0.42)
		else:
			v = maxf(v, 0.48)
			s = maxf(s, 0.30)
		out.append(Color.from_hsv(c.h, s, v))
	if high_key:
		out.append(Color.from_hsv(sch.hue, rng.randf_range(0.10, 0.24), rng.randf_range(0.06, 0.14)))
	else:
		out.append(Color.from_hsv(sch.hue, rng.randf_range(0.03, 0.12), rng.randf_range(0.90, 0.98)))
	return out


# The motif: n_el elements clustered around one anchor inside the fundamental domain. Points are
# stored in cell lengths, not pixels, so the motif survives a resize.
#
# Two vertex sets per element with matched counts; the second is the first with a per-vertex
# radial scale about the element's center. A radially perturbed polygon stays star-shaped about
# it, so the fill fan stays exact (free jitter could make an 8-gon concave).
func _build_motif(rng: RandomNumberGenerator, probe: WallpaperGroup, n_el: int, n_inks: int) -> Array:
	var region: Dictionary = SEED_REGION.get(probe.lattice, SEED_REGION["rect"])
	var ru: Array = region["u"]
	var rv: Array = region["v"]
	var anchor := (probe.a1 * rng.randf_range(float(ru[0]), float(ru[1]))
		+ probe.a2 * rng.randf_range(float(rv[0]), float(rv[1])))
	var cluster: float = number("cluster", rng)
	var jit_amp := rng.randf_range(0.10, 0.50)
	var out: Array = []
	for i in n_el:
		var kind := String(KINDS[rng.randi() % KINDS.size()])
		var n := rng.randi_range(3, 8)
		var r := rng.randf_range(0.07, 0.20)
		var rot := rng.randf_range(0.0, TAU)
		var ctr := anchor + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * cluster
		var pts := PackedVector2Array()
		var strip := false
		match kind:
			"bar":
				# An elongated n-gon: at n = 4 with the half-step phase a plain rectangle (the
				# bar); higher n rounds its ends off.
				var hl := rng.randf_range(0.10, 0.28)
				var hw := maxf(0.012, hl / rng.randf_range(2.0, 6.0))
				for k in n:
					var ab := TAU * (float(k) + 0.5) / float(n)
					pts.append(ctr + Vector2(cos(ab) * hl, sin(ab) * hw).rotated(rot))
			"wedge":
				# Apex at the element center, so the fill fan and the shape agree exactly.
				var span_w := rng.randf_range(0.5, 1.8)
				pts.append(ctr)
				for k in n - 1:
					var aw := rot - span_w * 0.5 + span_w * float(k) / float(n - 2)
					pts.append(ctr + Vector2(cos(aw), sin(aw)) * r)
			"arc":
				# A band, as a closed ring of 2n points (outer forward, inner back) filled as a
				# strip of trapezoids: the one non-convex element.
				strip = true
				var span_a := rng.randf_range(0.9, 2.8)
				var r_in := r * rng.randf_range(0.45, 0.80)
				for k in n:
					var ao := rot - span_a * 0.5 + span_a * float(k) / float(n - 1)
					pts.append(ctr + Vector2(cos(ao), sin(ao)) * r)
				for k in range(n - 1, -1, -1):
					var ai := rot - span_a * 0.5 + span_a * float(k) / float(n - 1)
					pts.append(ctr + Vector2(cos(ai), sin(ai)) * r_in)
			_:
				var asp := rng.randf_range(0.80, 1.20)
				for k in n:
					var ad := TAU * (float(k) + 0.5) / float(n)
					pts.append(ctr + Vector2(cos(ad) * r, sin(ad) * r * asp).rotated(rot))
		# The morph target: one jitter factor per angular position, shared by an arc's inner and
		# outer point so the band stays a band.
		var na := (pts.size() / 2) if strip else pts.size()
		var jf := PackedFloat32Array()
		for k in na:
			jf.append(rng.randf_range(-jit_amp, jit_amp))
		var pts_b := PackedVector2Array()
		for k in pts.size():
			var ang := k
			if strip and k >= na:
				ang = pts.size() - 1 - k
			pts_b.append(ctr + (pts[k] - ctr) * (1.0 + jf[ang]))
		out.append({
			"kind": kind,
			"strip": strip,
			"ctr": ctr,
			"pts_a": pts,
			"pts_b": pts_b,
			"pitch": rng.randi_range(0, 11),
			"home": rng.randi_range(0, maxi(1, n_inks) - 1),
		})
	return out


func update(f: AudioFeatures, delta: float) -> void:
	_f = f
	tick(f, delta)
	# Barely any camera: a printed surface stops being one the moment it breathes. The overscan
	# and the shot still give a "drift" registration something to do.
	drift_view(f, 0.02, 0.02)
	_ch = chroma_hue()
	_size_lattice()
	var thr: float = params["beat_thr"]
	if f.beat > thr and _prev_beat <= thr:
		_on_beat(f)
	_prev_beat = f.beat
	_morph_target = clampf(f.movement * float(params["morph_gain"]), 0.0, 1.0)
	# The glide, the morph follower and the re-ink clock are state, so they advance through a
	# SimClock, not once per update(): the Director sub-steps up to fifteen times a frame and
	# pre-warms every scene twelve times.
	for _i in _sim.ticks(delta):
		_step(_sim.dt)
	queue_redraw()


func _step(dt: float) -> void:
	if _gliding:
		_glide_p += dt / _glide_dur
		if _glide_p >= 1.0:
			# A full lattice vector: the picture at phase 1 is the picture at phase 0, so resetting
			# here is invisible.
			_glide_p = 0.0
			_gliding = false
	_morph = lerpf(_morph, _morph_target, 1.0 - exp(-MORPH_RATE * dt))
	_reink_t += dt
	var hold: float = params["reink_hold"]
	if _reink_t >= hold:
		_reink_t = 0.0
		_reink()


func _on_beat(f: AudioFeatures) -> void:
	_beat_n += 1
	var every: int = params["glide_every"]
	if _gliding or _beat_n % every != 0:
		return
	_gliding = true
	_glide_p = 0.0
	_glide_dur = maxf(0.12, f.beat_period * float(params["glide_frac"]))
	_dir_i = (_dir_i + 1) % _dirs.size()


# Rank the twelve chroma bins and hand every element the ink its pitch class's rank points at,
# offset by the element's seeded resting ink, so a chord change permutes the palette across the
# motif and the pattern stays multi-ink with no audio.
func _reink() -> void:
	var n_inks := _inks.size()
	var sig := signature()
	var peak := 0.0
	if sig.size() >= 12:
		for k in 12:
			peak = maxf(peak, sig[k])
	if sig.size() < 12 or peak < 1e-4:
		for i in _els.size():
			var el: Dictionary = _els[i]
			_ink_of[i] = int(el["home"]) % n_inks
		return
	var rank := PackedInt32Array()
	rank.resize(12)
	for k in 12:
		var r := 0
		for j in 12:
			# The index tiebreak makes the ranking a strict permutation, so the buckets below
			# divide the twelve classes evenly however flat the chroma is.
			if sig[j] > sig[k] or (sig[j] == sig[k] and j < k):
				r += 1
		rank[k] = r
	for i in _els.size():
		var el2: Dictionary = _els[i]
		var pc: int = el2["pitch"]
		var bucket := int(float(rank[pc]) * float(n_inks) / 12.0)
		_ink_of[i] = (int(el2["home"]) + bucket) % n_inks


# Solve the cell length backwards from the motif budget, then hold cells-across in range.
func _size_lattice() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var field := size * OVER
	var gname: String = params["group"]
	var ratio: float = params["ratio"]
	var angle: float = params["angle"]
	var per_cell := float(int(params["order"]) * int(params["elements"]))
	var want := maxf(1.0, float(params["budget"]) / per_cell)
	var shape := WallpaperGroup.unit_cell_area(gname, ratio, angle)
	var cell := sqrt(field.x * field.y / (want * shape))
	var across := clampf(minf(field.x, field.y) / maxf(1.0, cell), 5.0, 18.0)
	cell = minf(field.x, field.y) / across
	if _group != null and absf(cell - _cell) < 0.5:
		return
	_cell = cell
	_group = WallpaperGroup.make(gname, cell, ratio, angle)
	_offsets = _group.cell_offsets(size * 0.5 * OVER, cell * MOTIF_REACH)
	params["cell_px"] = cell
	params["cells"] = _offsets.size()
	params["motifs"] = _offsets.size() * int(per_cell)


func _draw() -> void:
	begin_draw()
	if _group == null or _offsets.is_empty():
		return
	paint_ground(float(params["ground_hue"]), float(params["ground_sat"]),
		float(params["ground_val"]), float(params["tint"]) * _ch.y, _ch.x)

	var key := _key_col
	key.a = lerpf(float(params["key_lo"]), float(params["key_hi"]),
		clampf(_f.energy * 2.2, 0.0, 1.0))
	var soft := _offsets.size() * int(params["order"]) * int(params["elements"]) <= SOFT_KEYLINE_MAX
	_build_cell(key, float(params["key_width"]), soft)

	var d: Vector2i = _dirs[_dir_i]
	var p := _glide_p
	var glide := _group.lattice_vector(d.x, d.y) * (p * p * p * (p * (p * 6.0 - 15.0) + 10.0))
	# One prebuilt triangle array, submitted once per cell under a shifted transform: TriBatch.flush's
	# call without the reset, so the same buffers serve every cell.
	var base := view.matrix(size)
	var ci := get_canvas_item()
	for off in _offsets:
		draw_set_transform_matrix(base.translated_local(off + glide))
		RenderingServer.canvas_item_add_triangle_array(ci, _tb.idx, _tb.pts, _tb.cols)
	draw_set_transform_matrix(base)
	_tb.pts.clear()
	_tb.cols.clear()
	_tb.idx.clear()


# One cell: every coset x every element, fills first and keylines second, so a keyline is never
# buried under a neighbor's fill.
func _build_cell(key: Color, key_w: float, soft: bool) -> void:
	var n_el := _els.size()
	var placed: Array = []
	var fans := PackedVector2Array()
	for ci in _group.cosets.size():
		var co: Dictionary = _group.cosets[ci]
		var xf: Transform2D = co["xf"]
		var flip: bool = co["flip"]
		for ei in n_el:
			var el: Dictionary = _els[ei]
			var a: PackedVector2Array = el["pts_a"]
			var b: PackedVector2Array = el["pts_b"]
			var ctr: Vector2 = el["ctr"]
			var out := PackedVector2Array()
			out.resize(a.size())
			for k in a.size():
				out[k] = xf * (a[k].lerp(b[k], _morph) * _cell)
			# A reflected coset comes out wound the other way. Nothing here culls by winding, so this
			# is hygiene; it keeps every triangle consistently oriented, at one reverse per coset.
			if flip:
				out.reverse()
			placed.append(out)
			fans.append(xf * (ctr * _cell))

	for i in placed.size():
		var pts: PackedVector2Array = placed[i]
		var el2: Dictionary = _els[i % n_el]
		var col: Color = _inks[_ink_of[i % n_el]]
		var n := pts.size()
		if bool(el2["strip"]):
			var h := n / 2
			for k in h - 1:
				_tb.quad(pts[k], pts[k + 1], pts[2 * h - 2 - k], pts[2 * h - 1 - k], col)
		else:
			var f := fans[i]
			for k in n:
				_tb.tri(f, pts[k], pts[(k + 1) % n], col)

	for i in placed.size():
		var pts2: PackedVector2Array = placed[i]
		var n2 := pts2.size()
		for k in n2:
			_tb.line(pts2[k], pts2[(k + 1) % n2], key, key_w, soft)
