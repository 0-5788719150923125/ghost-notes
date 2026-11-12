extends Scene3D

## Neural field - a layered network in real depth, lit only where the harmony routes.
##
## Three to six flat sheets of neurons hang one behind the other in perspective, seen from a
## slow three-quarter yaw. A sparse fan of straight edges runs between consecutive sheets and
## every edge is always there; what changes is which are lit, and an edge lights only when both
## endpoints fire at the same time. Nothing is destroyed or re-randomized, and loudness alone
## lights nothing.
##
## The seed decides the mood ([Scheme]; each sheet takes `hue_at(l, layers)`), the sheet count,
## the topology (`slab`, `funnel`, `fan_out`, `bottleneck`), grid size and jitter, fan-out and
## weights (an inhibitory fraction is drawn in the opposed hue), each sheet's [Activation], and
## the lens and look constants.
##
## Audio: the input sheet is read across its width (the neuron at column fraction cx takes
## `f.sample(cx)`). Each neuron has a pitch class and mixes in `signature()` for it, so harmony
## decides which neurons are eligible to fire and a chord change re-routes the slab without the
## level moving (the signature array is empty until the analyzer is up, hence the
## `.size() > pc` guard). One [Activation] per sheet supplies the slow seeded gate; a faster
## per-neuron envelope supplies the firing. Sheet L+1's drive is what sheet L fired times a
## sampled gain, so activity propagates. On a beat onset a bright packet walks one pre-rolled
## route, one layer per `beat_period * hops`. A `movement` spike eases the lens toward a new
## seeded angle. `chroma_hue()` pulls every hue toward the tonal center by `0.35 * strength`.
## No radius is multiplied by energy.
##
## Cost: edges are split into sub-segments before the painter's sort, so an edge interleaves
## with the neurons it passes (see terrain.gd's collect_surface). Neurons per sheet are capped at
## [constant MAX_PER_SHEET] and the fan-out is clamped so `edges * segments` stays under
## [constant MAX_SEGMENTS]. [Scene3D]'s `add_body` / `render_world` are not used (a lambda sort
## and a batch flush per body); everything goes into one [TriBatch] in a [FrameForge] job, sorted
## by `TriBatch.painter_sort`. Dark edges use the cheap hard-edged line (2 triangles), lit ones
## the feathered form (6).
##
## The propagation and the packets run on a [SimClock], not on `update()`: the Director
## sub-steps a scene up to 15 times a frame and pre-warms it 12 times.

## Neurons a single sheet may hold. Rows and columns are sampled in [4,9] (up to 81 per sheet);
## 64 keeps the worst case near 380 neurons, and the column count is drawn from what the row
## count leaves.
const MAX_PER_SHEET := 64

## Ceiling on sortable edge sub-segments per frame. The fan-out degree is clamped down until
## `edges * segments` fits, so the item count is bounded whatever the seed asks for.
const MAX_SEGMENTS := 2600

## Beat level a rising edge must cross to count as an onset.
const BEAT_ON := 0.55

## How far every hue is pulled toward the live tonal center, scaled by how tonal the moment is.
const CHROMA_PULL := 0.35

## Below this the material counts as silence and the drive reference stops learning, so a held
## pause cannot divide a tiny number by a tinier one. Same role as [member Director.silence_floor].
const SILENCE_FLOOR := 0.03

## Where the material's own average lands on the 0..1 drive dial: half, so an ordinary passage
## sits mid-scale and a passage that leans in has room. A normalization, not a look knob.
const DRIVE_MID := 0.5

# How each topology scales a sheet's row/column counts along the slab.
const TOPOLOGIES := ["slab", "funnel", "bottleneck", "fan_out"]

var _f: AudioFeatures = AudioFeatures.new()
var _sig := PackedFloat32Array()      # 12 chroma channels + coarse shape, read live
var _ch := Vector2.ZERO               # (hue, strength) of the music's tonality
var _sch: Scheme = null
var _sim := SimClock.new(45.0, 3)
var _forge := FrameForge.new()

# --- the graph (immutable after build) ---
var _pos := PackedVector3Array()      # neuron world positions, normalized to unit radius
var _layer_of := PackedInt32Array()
var _cx := PackedFloat32Array()       # column fraction 0..1, for f.sample()
var _pc := PackedInt32Array()         # pitch class 0..11
var _hjit := PackedFloat32Array()     # per-neuron hue jitter
var _start := PackedInt32Array()      # first neuron index of each sheet
var _count := PackedInt32Array()      # neurons in each sheet
var _esrc := PackedInt32Array()
var _edst := PackedInt32Array()
var _ew := PackedFloat32Array()       # signed weight; sign = excitatory / inhibitory
var _ehue := PackedFloat32Array()     # per-edge base hue, precomputed
var _eoff := PackedInt32Array()       # first outgoing edge of each neuron
var _ecnt := PackedInt32Array()
var _routes: Array = []               # pre-rolled packet paths (PackedInt32Array of neurons)

# --- the state ---
var _level := PackedFloat32Array()    # per-neuron firing envelope 0..1
var _acts: Array = []                 # one Activation per sheet (the route gate)
var _gain := PackedFloat32Array()     # sheet-to-sheet transmission (see _step)
var _packets: Array = []
var _glow := 0.0
var _prev_beat := 0.0
var _last_launch := -10.0
var _last_reframe := 0.0
var _route_i := 0
var _yaw_i := 0

# The material's own recent level, which every drive here is measured against (see _step).
var _e_ref := 0.0                     # EMA of f.energy
var _b_ref := 0.0                     # EMA of the loudest band this frame
var _ref_seeded := false

# --- sampled definition kept as typed members (hot in the per-frame path) ---
var _layers := 4
var _rows := 6
var _cols := 6
var _segs := 4
var _disc_r := 0.03
var _edge_w := 1.4
var _sides := 8
var _dark := 0.12
var _band_mix := 0.8
var _chroma_mix := 0.8
var _gate_floor := 0.12
var _w_att := 0.3
var _w_dec := 0.05
var _packets_on := true
var _burst := 2
var _hops := 1
var _move_thresh := 0.45
var _reframe_gap := 24.0
var _dist := 1.7
var _push := 0.0
var _pitch := 0.1
var _yaw_center := 0.65
var _yaw_goal := 0.65
var _yaw_amp := 0.08
var _yaw_rate := 0.02
var _yaw_phase := 0.0
var _yaw_ease := 0.1
var _yaw_bag := PackedFloat32Array()
var _ref_tau := 25.0
var _a_floor := 0.20
var _bleach := 0.85
var _ghost_sat := 0.45
var _edge_gamma := 0.5
var _node_gamma := 0.6


## What this scene can be told ([method GhostScene.choice], [method GhostScene.number]): a
## storyboard entry's `set`, by name; a setting not told is drawn from the seed.
const FIELDS := {
	"topology": {"label": "Topology", "type": "choice", "options": "TOPOLOGIES", "default": null,
		"blurb": "How the sheets change size through the network: a slab of equal sheets, a funnel that narrows toward the output, a bottleneck that pinches in the middle, or a fan that widens."},
	"sheets": {"label": "Sheets", "type": "num", "range": [3, 6], "default": null,
		"blurb": "How many sheets of neurons the network is stacked in."},
	"rows": {"label": "Rows", "type": "num", "range": [4, 9], "default": null,
		"blurb": "How many rows of neurons each sheet has."},
	"sheet_spacing": {"label": "Sheet spacing", "type": "num", "range": [0.5, 1.2], "default": null,
		"blurb": "How far apart the sheets of neurons stand in depth."},
	"connections": {"label": "Connections", "type": "num", "range": [2, 5], "default": null,
		"blurb": "How many connections each neuron reaches out to the next sheet, at most."},
	"neuron_size": {"label": "Neuron size", "type": "num", "range": [0.07, 0.14], "default": null,
		"blurb": "How large each neuron's disc is drawn."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	framing = "plane"                       # the yaw comes from the lens, not the shot
	_sch = Scheme.pick(rng)                 # a graph is abstract: no mood is wrong for it
	_layers = number("sheets", rng)
	_rows = number("rows", rng)
	# The column count is drawn from what the per-sheet budget leaves, so the sampled range is
	# honored where it can be and the item count stays bounded.
	_cols = rng.randi_range(4, clampi(MAX_PER_SHEET / _rows, 4, 9))
	var topo := String(choice("topology", rng))
	var jitter := rng.randf_range(0.0, 0.35)
	var spacing: float = number("sheet_spacing", rng)
	var wexp := rng.randf_range(0.6, 2.2)
	var inhib := rng.randf_range(0.15, 0.40)
	var reach := rng.randi_range(1, 3)      # how far sideways a neuron may look for a target
	var k_want: int = number("connections", rng)
	_segs = rng.randi_range(3, 5)
	_disc_r = number("neuron_size", rng)   # as a fraction of a cell, scaled below
	_edge_w = rng.randf_range(0.8, 2.2)
	_sides = rng.randi_range(5, 12)
	_dark = rng.randf_range(0.05, 0.25)
	_band_mix = rng.randf_range(0.5, 1.0)
	_chroma_mix = rng.randf_range(0.5, 1.1)
	_gate_floor = rng.randf_range(0.05, 0.20)
	_packets_on = rng.randf() < 0.75
	_burst = rng.randi_range(1, 4)
	_hops = rng.randi_range(1, 3)
	_move_thresh = rng.randf_range(0.35, 0.60)
	# Seconds the framing must hold before a section change may re-aim it (narration spikes
	# `movement` at nearly every sentence).
	_reframe_gap = rng.randf_range(18.0, 32.0)
	# Seconds the drive reference takes to forget. Short = the slab tracks each sentence's own
	# loudness; long = it tracks the passage.
	_ref_tau = rng.randf_range(15.0, 40.0)
	# The lit/unlit mapping (see NeuralJob.run): `bleach` is how completely a firing route burns
	# out to white, `ghost_sat` the color the unlit graph keeps, `a_floor` its presence, and the
	# gammas (above one) how sharply firing becomes light, holding the unlit majority down.
	_a_floor = rng.randf_range(0.14, 0.26)
	_bleach = rng.randf_range(0.75, 0.95)
	_ghost_sat = rng.randf_range(0.35, 0.60)
	_edge_gamma = rng.randf_range(1.30, 2.10)
	_node_gamma = rng.randf_range(1.50, 2.40)
	var sparsity := rng.randf_range(0.25, 0.70)
	var attack := rng.randf_range(4.0, 9.0)
	var decay := rng.randf_range(0.8, 1.8)
	# The firing envelope is crisper than the Activation gate beneath it: the gate asks "is this
	# neuron on this passage", the envelope "is it firing now". Both weights are constants
	# because SimClock's dt is constant.
	_w_att = 1.0 - exp(-attack * 1.5 * _sim.dt)
	_w_dec = 1.0 - exp(-decay * _sim.dt)

	# --- place the sheets ---
	var hw := 1.0
	var hy := hw * float(_rows) / float(_cols)      # square-ish cells whatever the grid
	var cell := 2.0 * hw / float(_cols)
	var n_total := 0
	for l in _layers:
		var s := _topo_scale(topo, l)
		var cl := maxi(2, int(round(float(_cols) * s)))
		var rl := maxi(2, int(round(float(_rows) * s)))
		var z := (float(_layers - 1) * 0.5 - float(l)) * spacing   # sheet 0 nearest the camera
		_start.append(n_total)
		_count.append(rl * cl)
		for r in rl:
			for c in cl:
				var fx := (float(c) + 0.5) / float(cl)
				var fy := (float(r) + 0.5) / float(rl)
				var px := (fx * 2.0 - 1.0) * hw + rng.randf_range(-jitter, jitter) * cell
				var py := (fy * 2.0 - 1.0) * hy + rng.randf_range(-jitter, jitter) * cell
				_pos.append(Vector3(px, py, z))
				_layer_of.append(l)
				_cx.append(fx)
				# Pitch class runs across the sheet (so the harmonic routing has a spatial
				# shape) with a one-step seeded nudge, so the classes are not perfect stripes.
				var pc := (int(fx * 12.0) + rng.randi_range(-1, 1)) % 12
				_pc.append(pc if pc >= 0 else pc + 12)
				_hjit.append(rng.randf_range(-_sch.spread, _sch.spread) * 0.5)
				n_total += 1
	_level.resize(n_total)
	for i in n_total:
		_level[i] = 0.0

	# Normalize the whole slab to a unit bounding radius, so one sampled lens distance frames
	# every seed alike.
	var radius := 0.001
	for i in n_total:
		radius = maxf(radius, _pos[i].length())
	var fit := 1.0 / radius
	for i in n_total:
		_pos[i] = _pos[i] * fit
	_disc_r = _disc_r * cell * fit

	# --- the fan ---
	var n_src := n_total - int(_count[_layers - 1])
	var k := clampi(int(MAX_SEGMENTS / maxi(1, n_src * _segs)), 2, k_want)
	_eoff.resize(n_total)
	_ecnt.resize(n_total)
	for l in _layers:
		var s0 := int(_start[l])
		var n0 := int(_count[l])
		if l == _layers - 1:
			for j in n0:
				_eoff[s0 + j] = _esrc.size()
				_ecnt[s0 + j] = 0
			break
		var s1 := int(_start[l + 1])
		var n1 := int(_count[l + 1])
		var hue_a := _sch.hue_at(l, _layers)
		var hue_b := _sch.hue_at(l + 1, _layers)
		var opp := _sch.opposed(hue_a)
		var dh := fposmod(hue_b - hue_a + 0.5, 1.0) - 0.5      # shortest way round
		for j in n0:
			var i := s0 + j
			_eoff[i] = _esrc.size()
			var picked: Array = []
			for _t in k:
				# Targets come from a neighborhood of the source's own position in the next
				# sheet: a fan of local connections, so a route is legible.
				var tgt := _near_target(rng, i, s1, n1, reach, picked)
				if tgt < 0:
					continue
				picked.append(tgt)
				_esrc.append(i)
				_edst.append(tgt)
				var w := pow(rng.randf(), wexp)
				var neg := rng.randf() < inhib
				_ew.append((-w) if neg else w)
				# An edge takes the color of the gap it crosses: halfway between its two
				# sheets' hues, or the opposed hue when it is inhibitory.
				_ehue.append(opp if neg else fposmod(hue_a + dh * 0.5, 1.0))
			_ecnt[i] = _esrc.size() - int(_eoff[i])

	# --- per-sheet activation + propagation transmission ---
	# Per-sheet transmission, a shade either side of unity, so depth attenuates gently. _step
	# propagates what fired rather than the sheet's mean, which would collapse on a sparse
	# sheet (each hop multiplying the drive by about the sparsity).
	for l in _layers:
		_acts.append(Activation.new(int(_count[l]), rng, sparsity, attack, decay))
		_gain.append(rng.randf_range(0.72, 0.92))

	# --- pre-rolled packet routes and lens angles ---
	# Both are drawn here, never at the audio event that uses them: a live analyzer and an
	# offline bake give different feature streams, so an rng draw on a beat would desynchronize
	# the export from the preview.
	var nroutes := rng.randi_range(10, 24)
	for _r in nroutes:
		var chain := PackedInt32Array()
		var cur := int(_start[0]) + rng.randi() % int(_count[0])
		chain.append(cur)
		for _l in _layers - 1:
			if int(_ecnt[cur]) <= 0:
				break
			var e := int(_eoff[cur]) + rng.randi() % int(_ecnt[cur])
			cur = int(_edst[e])
			chain.append(cur)
		if chain.size() >= 2:
			_routes.append(chain)
	# The side of the slab is chosen once, here, and never changes. Yaw stays in a narrow band on
	# one side and eases slowly (about a degree a second), so it never crosses zero, where the
	# sheets stack on top of each other and the depth collapses.
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	for _b in 8:
		_yaw_bag.append(side * rng.randf_range(0.55, 0.85))
	_yaw_center = _yaw_bag[0]
	_yaw_goal = _yaw_center
	_yaw_amp = rng.randf_range(0.04, 0.10)
	_yaw_rate = rng.randf_range(0.012, 0.035)
	_yaw_phase = rng.randf() * TAU
	# Seconds-ish to close a re-aim; at the widest bag gap (0.30 rad) a peak of about 1.7 deg/s.
	_yaw_ease = rng.randf_range(0.07, 0.14)
	_yaw_i = 1
	# Close, so the near sheet overruns the frame and the far ones recede (the viewer is inside
	# the fan). The near sheet still clears the 0.05 near plane (worst case about 0.7 units).
	_dist = rng.randf_range(1.35, 2.10)
	# A slow push, in world units over the scene's life: at most about 0.01/s.
	_push = rng.randf_range(0.08, 0.26)
	_pitch = rng.randf_range(-0.24, 0.24)
	lens.fov = rng.randf_range(48.0, 62.0)

	# A faint wash behind the slab, on the mood: a pure black void reads as a diagram.
	add_layer("bed", rng, {
		"hue": _sch.accent,
		"sat": clampf(_sch.sat * rng.randf_range(0.4, 0.8), 0.05, 1.0),
		"val": rng.randf_range(0.04, 0.11),
		"pools": rng.randi_range(1, 3),
	})
	return {
		"mood": _sch.name, "layers": _layers, "rows": _rows, "cols": _cols,
		"topology": topo, "neurons": n_total, "edges": _esrc.size(), "fan_out": k,
		"reach": reach, "jitter": jitter, "spacing": spacing, "weight_exp": wexp,
		"inhibitory": inhib, "segments": _segs, "sparsity": sparsity,
		"attack": attack, "decay": decay, "dark_floor": _dark, "disc_sides": _sides,
		"edge_width": _edge_w, "packets": _packets_on, "burst": _burst, "hops": _hops,
		"dist": _dist, "pitch": _pitch, "yaw_rate": _yaw_rate, "routes": _routes.size(),
	}


# How a topology scales sheet `l`'s row/column counts; both axes take the scale, so a funnel
# narrows in area.
func _topo_scale(topo: String, l: int) -> float:
	var t := float(l) / float(maxi(1, _layers - 1))
	match topo:
		"funnel":
			return lerpf(1.0, 0.55, t)
		"fan_out":
			return lerpf(0.55, 1.0, t)
		"bottleneck":
			return lerpf(1.0, 0.5, 1.0 - absf(t * 2.0 - 1.0))
		_:
			return 1.0


# One more target for `src` in the next sheet, near it in world x/y and not already taken.
# `reach` sets how many seeded candidates are compared (more lands near the source's own axis,
# fewer wanders); keeping the closest untaken one stops a fan collapsing onto two neighbors.
# Returns -1 when the sheet has nothing left.
func _near_target(rng: RandomNumberGenerator, src: int, s1: int, n1: int, reach: int,
		taken: Array) -> int:
	if taken.size() >= n1:
		return -1
	var p: Vector3 = _pos[src]
	var best := -1
	var bd := 1e20
	for _t in maxi(3, 10 - reach * 2):
		var c := s1 + rng.randi() % n1
		if taken.has(c):
			continue
		var q: Vector3 = _pos[c]
		var d := (q.x - p.x) * (q.x - p.x) + (q.y - p.y) * (q.y - p.y)
		if d < bd:
			bd = d
			best = c
	return best


func update(f: AudioFeatures, delta: float) -> void:
	_f = f
	tick(f, delta)
	drift_view(f, 0.01, 0.02)
	update_layers(f, delta)
	_sig = signature()
	_ch = chroma_hue()
	_glow = Nonlinear.flare(_glow, clampf(0.35 * f.energy + 0.7 * f.beat, 0.0, 1.0), delta, 9.0, 1.6)

	# A beat onset (a rising edge, not the level) launches packets. Storing the level afterwards
	# keeps repeated update() calls with the same frame idempotent.
	if _packets_on and f.beat > BEAT_ON and _prev_beat <= BEAT_ON and _life - _last_launch > 0.12:
		_last_launch = _life
		_launch(f)
	_prev_beat = f.beat

	# A section change eases the yaw center toward the next pre-rolled angle; rate-limited, or a
	# busy passage would re-aim every few frames.
	if f.movement > _move_thresh and _life - _last_reframe > _reframe_gap and _yaw_bag.size() > 0:
		_last_reframe = _life
		_yaw_goal = _yaw_bag[_yaw_i % _yaw_bag.size()]
		_yaw_i += 1
	_yaw_center = lerpf(_yaw_center, _yaw_goal, 1.0 - exp(-_yaw_ease * delta))
	_yaw_phase += delta * _yaw_rate * TAU
	# The yaw breathes inside a narrow band on one side of the slab: head-on the sheets stack and
	# depth vanishes, near a quarter turn they collapse to lines.
	var yaw := _yaw_center + _yaw_amp * sin(_yaw_phase)
	# The push-in runs on the scene's own clock, not the audio: one unhurried gesture.
	var dist := _dist - _push * smoothstep(0.0, 1.0, clampf(_life / 40.0, 0.0, 1.0))
	lens.orbit(Vector3.ZERO, maxf(dist, 0.9), yaw, _pitch + 0.02 * mod.value("tilt"))

	for _i in _sim.ticks(delta):
		_step(_sim.dt)

	var job := NeuralJob.new()
	job.u = unit()
	job.reveal = view.reveal
	job.fov = lens.fov
	job.lens = Lens3D.new()
	job.lens.eye = lens.eye
	job.lens.look = lens.look
	job.lens.up = lens.up
	job.lens.fov = lens.fov
	job.lens.near = lens.near
	job.pos = _pos                       # immutable after build - safe by reference
	job.layer_of = _layer_of
	job.hjit = _hjit
	job.esrc = _esrc
	job.edst = _edst
	job.ew = _ew
	job.ehue = _ehue
	job.level = _level.duplicate()       # main mutates this every sim tick
	job.hues = PackedFloat32Array()
	for l in _layers:
		job.hues.append(_sch.hue_at(l, _layers))
	job.ch_h = _ch.x
	job.ch_s = _ch.y
	job.sat = _sch.sat
	job.val = _sch.val
	job.dark = _dark
	job.a_floor = _a_floor
	job.bleach = _bleach
	job.ghost_sat = _ghost_sat
	job.edge_gamma = _edge_gamma
	job.node_gamma = _node_gamma
	job.segs = _segs
	job.sides = _sides
	job.disc_r = _disc_r
	job.edge_w = _edge_w
	job.glow = _glow
	job.packets = _packet_marks()
	_forge.kick(job.run, {}, self, job)
	queue_redraw()


func _draw() -> void:
	begin_draw()
	draw_layers()
	_forge.submit(self)


# One fixed generation: the sheets settle, then every live packet steps forward. Called only
# from SimClock.ticks(), never once per update.
func _step(dt: float) -> void:
	var f := _f
	# The drive is content-relative: the moment is judged against the material's own recent
	# level, because `f.energy` is near 0.4 for a mastered track but only about 0.05 for
	# speech, which left every Activation threshold unreachable. (Director._lean() takes the
	# same ratio approach for the cut logic.)
	var bmax := 0.0
	for v in f.bands:
		bmax = maxf(bmax, v)
	if not _ref_seeded:
		_ref_seeded = true
		_e_ref = f.energy
		_b_ref = bmax
	elif f.energy > SILENCE_FLOOR:
		# Silence does not teach the reference anything.
		var k := 1.0 - exp(-dt / _ref_tau)
		_e_ref = lerpf(_e_ref, f.energy, k)
		_b_ref = lerpf(_b_ref, bmax, k)
	var drive := clampf(f.energy / maxf(_e_ref, SILENCE_FLOOR) * DRIVE_MID, 0.0, 1.0)
	var bgain := 1.0 / maxf(_b_ref, SILENCE_FLOOR)

	var prev_fire := 0.0
	var agg_in := 0.0                     # sheet 0's aggregate, the yardstick for every sheet after
	var fire_in := 0.0                    # ...and how hard sheet 0 actually fired under it
	for l in _layers:
		var s := int(_start[l])
		var n := int(_count[l])
		var act: Activation = _acts[l]
		# The sheet's aggregate drives the gate (which neurons are eligible). It is
		# self-normalized: each Activation is a soft threshold, and below it the gates
		# collapse to `gate_floor` - a cliff. So sheet L+1 gets a fraction of what sheet 0
		# managed under its own aggregate, and `_gain` (a shade under unity) makes depth fade.
		var agg: float
		if l == 0:
			agg = clampf(1.8 * drive + 0.6 * f.beat, 0.0, 1.0)
			agg_in = agg
		else:
			agg = clampf(agg_in * (prev_fire / maxf(fire_in, 1e-3)) * float(_gain[l]), 0.0, 1.0)
		act.update(agg, dt)
		var sum := 0.0
		var sum_sq := 0.0
		for j in n:
			var i := s + j
			var raw: float
			if l == 0:
				raw = clampf(f.sample(_cx[i]) * bgain, 0.0, 1.0) * _band_mix
			else:
				raw = agg
			# Harmony decides who, level decides how much: on the input sheet the chroma
			# channel adds to the band drive; deeper in it scales what arrived.
			var pc := int(_pc[i])
			if _sig.size() > pc:
				if l == 0:
					raw += _sig[pc] * _chroma_mix
				else:
					raw *= 0.40 + 1.1 * _sig[pc] * _chroma_mix
			var gate := _gate_floor + (1.0 - _gate_floor) * act.level(j)
			var target := clampf(raw * gate, 0.0, 1.0)
			var cur := _level[i]
			_level[i] = cur + (target - cur) * (_w_att if target > cur else _w_dec)
			sum += _level[i]
			sum_sq += _level[i] * _level[i]
		# What fired, not what is there: the level-weighted mean (sum of squares over sum) is
		# the plain mean for a uniform sheet and the max when one neuron carries it. One extra
		# multiply-add per neuron, no sort.
		prev_fire = sum_sq / maxf(sum, 1e-6)
		if l == 0:
			fire_in = prev_fire

	var pi := _packets.size() - 1
	while pi >= 0:
		var pk: Dictionary = _packets[pi]
		var route: PackedInt32Array = pk["route"]
		var before := int(float(pk["p"]))
		var np: float = float(pk["p"]) + dt / maxf(0.05, float(pk["transit"]))
		pk["p"] = np
		var after := int(np)
		if after > before and after < route.size():
			_level[route[after]] = 1.0        # the packet ARRIVES: that neuron fires outright
		if np >= float(route.size() - 1):
			_packets.remove_at(pi)
		pi -= 1


# Send this onset's packets down the next pre-rolled routes. The route is taken by a counter,
# never an rng draw, so the sequence is identical live and in an export.
func _launch(f: AudioFeatures) -> void:
	if _routes.is_empty():
		return
	var transit := clampf(f.beat_period, 0.2, 1.6) * float(_hops)
	for _b in _burst:
		if _packets.size() >= 20:
			_packets.remove_at(0)
		var route: PackedInt32Array = _routes[_route_i % _routes.size()]
		_route_i += 1
		_packets.append({"route": route, "p": 0.0, "transit": transit})
		_level[route[0]] = 1.0


# Where each live packet is, in world space, resolved on the main thread so the worker never
# walks the route arrays.
func _packet_marks() -> Array:
	var out: Array = []
	for pk in _packets:
		var p: Dictionary = pk
		var route: PackedInt32Array = p["route"]
		var pr: float = clampf(float(p["p"]), 0.0, float(route.size() - 1))
		var li := mini(int(pr), route.size() - 2)
		var t := pr - float(li)
		var a: Vector3 = _pos[route[li]]
		var b: Vector3 = _pos[route[li + 1]]
		out.append(a.lerp(b, t))
	return out


## The whole frame, built off the main thread (the [FrameForge] job object form): project every
## neuron once, color and split every edge, sort together, cut into batch runs. Reads only its
## own members, never the scene node.
class NeuralJob:
	extends RefCounted

	# Restated: an inner class does not inherit the outer script's constants.
	const CHROMA_PULL := 0.35

	var lens: Lens3D
	var u := 1.0
	var fov := 50.0
	var reveal := 1.0
	var pos := PackedVector3Array()
	var layer_of := PackedInt32Array()
	var hjit := PackedFloat32Array()
	var esrc := PackedInt32Array()
	var edst := PackedInt32Array()
	var ew := PackedFloat32Array()
	var ehue := PackedFloat32Array()
	var level := PackedFloat32Array()
	var hues := PackedFloat32Array()
	var packets: Array = []
	var ch_h := 0.0
	var ch_s := 0.0
	var sat := 0.6
	var val := 0.9
	var dark := 0.12
	var a_floor := 0.20
	var bleach := 0.85
	var ghost_sat := 0.45
	var edge_gamma := 1.7
	var node_gamma := 1.9
	var segs := 4
	var sides := 8
	var disc_r := 0.03
	var edge_w := 1.4
	var glow := 0.0

	func run(_s: Dictionary) -> Array:
		var out: Array = []
		if reveal < 0.02:
			return out
		lens.prepare()
		var n := pos.size()
		var sp := PackedVector2Array()
		sp.resize(n)
		var dp := PackedFloat32Array()
		dp.resize(n)
		for i in n:
			var pr := lens.project(pos[i])
			sp[i] = Vector2(pr.x, pr.y) * u
			dp[i] = pr.z
		var near := lens.near
		var focal := 1.0 / tan(deg_to_rad(fov) * 0.5)
		var items: Array = []
		var inv := 1.0 / float(segs)

		# Edges: every one is emitted every frame; only the color moves. `min(level_a, level_b)`
		# makes an edge bright only when both ends are hot. A firing route runs to white (the
		# background is black), so `lit_val` is near 1, not the mood's own value.
		var lit_val := lerpf(val, 1.0, 0.72 + 0.24 * glow)
		for e in esrc.size():
			var a := int(esrc[e])
			var b := int(edst[e])
			var da := dp[a]
			var db := dp[b]
			if da <= near or db <= near:
				continue
			# One pow, with the weight in the exponent: a strong edge lights on a modest pair, a
			# weak one needs both ends hot, and it can still reach the top of the range.
			var sh := pow(minf(level[a], level[b]), edge_gamma * (1.6 - 0.8 * minf(absf(ew[e]), 1.0)))
			var v := dark + maxf(0.0, lit_val - dark) * sh
			var h := _tonal(ehue[e])
			# Color in the middle, white at the top: keep the mood's saturation until the edge is
			# lit, then bleach it.
			var csat := sat * (ghost_sat + (1.0 - ghost_sat) * minf(sh * 3.0, 1.0)) * (1.0 - bleach * sh)
			var col := Color.from_hsv(h, clampf(csat, 0.0, 1.0),
				clampf(v, 0.0, 1.0), reveal * clampf(a_floor + (1.0 - a_floor) * sh, 0.0, 1.0))
			# Split the edge so the painter's sort interleaves it with the discs it passes.
			var pa := sp[a]
			var pb := sp[b]
			var soft := sh > 0.30
			for s in segs:
				var t0 := float(s) * inv
				var t1 := float(s + 1) * inv
				var it := {
					"d": lerpf(da, db, (t0 + t1) * 0.5),
					"a": pa.lerp(pb, t0), "b": pa.lerp(pb, t1),
					"col": col, "w": edge_w}
				if soft:
					it["soft"] = true
				items.append(it)

		# Neurons: a constant world radius, so a disc shrinks only with distance.
		var cs := PackedFloat32Array()
		var sn := PackedFloat32Array()
		for k in sides:
			var ang := TAU * float(k) / float(sides)
			cs.append(cos(ang))
			sn.append(sin(ang))
		var node_floor := clampf(dark + 0.06, 0.08, 0.34)
		for i in n:
			var d := dp[i]
			if d <= near:
				continue
			var fire := level[i]
			var r := disc_r * focal / d * u
			if r < 0.35:
				continue
			var c := sp[i]
			var poly := PackedVector2Array()
			poly.resize(sides)
			for k in sides:
				poly[k] = Vector2(c.x + cs[k] * r, c.y + sn[k] * r)
			var h := _tonal(hues[layer_of[i]] + hjit[i])
			var shn := pow(fire, node_gamma)
			var v := node_floor + maxf(0.0, 1.0 - node_floor) * shn
			var nsat := sat * (ghost_sat + (1.0 - ghost_sat) * minf(shn * 3.0, 1.0)) * (1.0 - bleach * shn)
			items.append({"d": d, "poly": poly,
				"flat": Color.from_hsv(h, clampf(nsat, 0.0, 1.0),
					clampf(v, 0.0, 1.0), reveal)})

		# Packets: the one thing in the frame allowed to be white.
		for p in packets:
			var wp: Vector3 = p
			var pr2 := lens.project(wp)
			if pr2.z <= near:
				continue
			var r2 := disc_r * 1.7 * focal / pr2.z * u
			var c2 := Vector2(pr2.x, pr2.y) * u
			var poly2 := PackedVector2Array()
			poly2.resize(sides)
			for k in sides:
				poly2[k] = Vector2(c2.x + cs[k] * r2, c2.y + sn[k] * r2)
			items.append({"d": pr2.z, "poly": poly2,
				"flat": Color.from_hsv(_tonal(hues[hues.size() - 1]), sat * 0.25, 1.0, reveal)})

		items = TriBatch.painter_sort(items)
		var tb := TriBatch.new()
		for it2 in items:
			var d2: Dictionary = it2
			if d2.has("poly"):
				tb.poly(d2["poly"], d2["flat"])
			else:
				# The dark majority take the cheap 2-triangle line; only lit edges pay for the
				# feathered form.
				tb.line(d2["a"], d2["b"], d2["col"], float(d2["w"]), d2.has("soft"))
		return tb.take_chunks()

	# Pull a hue toward the music's tonal center, the shortest way round, scaled by how tonal
	# the moment is (0 for noise).
	func _tonal(h: float) -> float:
		var d := ch_h - h
		return fposmod(h + (d - round(d)) * CHROMA_PULL * ch_s, 1.0)
