extends GhostScene

## Chladni - grains walking to the places a plate is not moving.
##
## A metal plate seen square-on, dusted with fine sand and lit from a low raking angle so every grain
## throws a speck of shadow. Grains are thrown about where the surface heaves and lie still where it does not,
## so dust organizes into a figure of curved nodal lines. When the key changes the figure boils apart into
## haze and another assembles.
##
## The audio is the physical input: the plate's mode is chosen by the music, so the same seed draws a
## different picture for a different chord. The figure's size never changes, only its shape.
##
## Mode choice: the first twelve channels of [method Spectrum.harmonic_signature] are the chroma. They are
## smoothed, then the strongest and second strongest bins are read by argmax and pushed through a seeded
## permutation into a seeded mode table, giving (m, n); the second and third give the superposed second
## harmonic. Argmax, not a weighted sum (twelve summed eigenfunctions give a gray mush). `mode_tau`
## (0.4 .. 2.0 s) sets both the chroma smoothing and the crossfade between two baked figures: short snaps over
## on a chord change, long dissolves through a formless boil.
##
## The rest of the audio is about dwell, not size: `f.energy` is the plate's driving amplitude (how tightly
## grains pack onto the nodes); `f.beat` is a tap, a drive spike that scatters the figure; `f.flux` trims the
## crossfade rate. Gains are written for measured ranges (energy rarely passes 0.5, flux is 0.01-0.05): the
## drive is `0.30 + 1.30 * energy`.
##
## Cost: [PlateField] bakes the field and gradient onto a grid (a grain step is a bilinear read), in slabs so
## a mode change never hitches. The walk runs on a [SimClock] and steps a rotating third of the grains per
## tick with a longer dt, so per-frame cost is flat in the grain count. The draw (about 30k triangles) is
## built off the main thread through [FrameForge].
##
## The seed decides: the plate (square, circular, hexagonal) and its rim condition (free or clamped); the mode
## table and permutation; grain count, size and settling sensitivity; creep and twitch; the mobility exponent
## (loose sand or heavy filings); the second harmonic's weight; the plate finish and room; the rake light.

## The three plates; each is a different eigenfunction family in [PlateField], not a mask over one shape.
const SHAPES := ["square", "circle", "hex"]

## Valid mode indices per plate: half-wave counts on the square and hexagon, angular order and radial
## index on the circle (m = 0 is plain rings).
const RANGES := {
	"square": {"m": [1, 6], "n": [1, 6]},
	"circle": {"m": [0, 4], "n": [1, 4]},
	"hex": {"m": [1, 5], "n": [1, 5]},
}

## The plate's surface. Absolute ranges rather than multipliers on the mood, since a finish is a
## brightness. `chalk` is the inverted one (pale board, dark filings) and the only one that wants
## [method GhostScene.paint_ground] behind it.
const FINISHES := {
	"brushed": {"sat": [0.06, 0.14], "val": [0.30, 0.46], "streaks": [40, 90], "sheen": [0.30, 0.55], "high": false},
	"matte": {"sat": [0.10, 0.24], "val": [0.06, 0.12], "streaks": [0, 0], "sheen": [0.04, 0.14], "high": false},
	"slate": {"sat": [0.14, 0.30], "val": [0.15, 0.26], "streaks": [0, 26], "sheen": [0.12, 0.30], "high": false},
	"chalk": {"sat": [0.02, 0.07], "val": [0.84, 0.94], "streaks": [0, 24], "sheen": [0.08, 0.22], "high": true},
}

var _sim: SimClock
var _forge: FrameForge
var _field: PlateField
var _light: Lighting
var _tb := TriBatch.new()

# The grains, as parallel packed floats, never an array of dictionaries (at 14k elements that is the difference).
var _count := 0
var _px := PackedFloat32Array()      # plate coordinates, -1..1
var _py := PackedFloat32Array()
var _gsz := PackedFloat32Array()     # per-grain size multiplier (immutable after build)
var _sens := PackedFloat32Array()    # per-grain settling sensitivity (immutable after build)
var _shade := PackedFloat32Array()   # last computed rake shading, 0..1
var _amp := PackedFloat32Array()     # last sampled local |w|, 0..1
var _cursor := 0
var _chunk := 900
var _kicked := false

# The sampled definition, unpacked into fields the hot loops read without a Dictionary lookup per grain.
var _shape := "square"
var _base_drive := 1.0
var _settle := 0.06
var _ramp := 0.45
var _damping := 1.0
var _descent := 0.24
var _jitter := 0.14
var _tremor := 0.18       # threshold-free agitation, scaled by local |w| (see build)
var _creep_floor := 0.16  # fraction of the descent that survives at a node
var _shake_floor := 0.28  # fraction of the tremor that survives at a node
var _tau := 1.0
var _min_dwell := 8.0
var _w2 := 0.2
var _lx := 1.0
var _ly := 0.0
var _rake_k := 0.9
var _shadows := true
var _shadow_mul := 2.0
var _shadow_drop := 0.012
var _grain_hue := 0.1
var _grain_sat := 0.12
var _grain_r := 0.002
var _v_lo := 0.3
var _v_hi := 0.95
var _blur := 0.5
var _tint := 0.35
var _plate_hue := 0.6
var _plate_sat := 0.1
var _plate_val := 0.3
var _plate_size := 0.8
var _sheen := 0.35
var _rim_a := 0.35
var _high_key := false
var _room_hue := 0.1
var _room_sat := 0.06
var _room_val := 0.92
var _outline := PackedVector2Array()
var _streaks := 0
var _streak_a := PackedFloat32Array()
var _brush := 0.0
var _bake_rows := 10

# Mode selection.
var _perm := PackedInt32Array()      # chroma bin -> mode-table slot
var _mtab := PackedInt32Array()      # slot -> m
var _ntab := PackedInt32Array()      # slot -> n
var _n_lo := 1
var _n_hi := 6
var _cm := 1
var _cn := 2
var _cm2 := 1
var _cn2 := 2
var _csig := PackedFloat32Array()    # smoothed chroma
var _dwell := 0.0
var _tap := 0.0
var _drive := 0.4
var _ch := Vector2.ZERO


## What this scene can be told ([method GhostScene.choice], [method GhostScene.number]): a storyboard
## entry's `set`, by name; a setting not told is drawn from the seed.
const FIELDS := {
	"plate": {"label": "Plate", "type": "choice", "options": "SHAPES", "default": null,
		"blurb": "The shape of the vibrating plate: a square, a circle or a hexagon, each with its own family of patterns."},
	"finish": {"label": "Finish", "type": "choice", "options": "FINISHES", "default": null,
		"blurb": "The plate's surface: brushed metal, matte black, slate, or chalk - a pale board with dark filings on it."},
	"rim": {"label": "Rim", "type": "num", "range": [0.18, 0.50], "default": null,
		"blurb": "How clearly the thin line around the plate's edge shows."},
	"plate_size": {"label": "Plate size", "type": "num", "range": [0.70, 0.88], "default": null,
		"blurb": "How much of the frame the vibrating plate fills."},
	"lamp_height": {"label": "Lamp height", "type": "num", "range": [0.10, 0.45], "default": null,
		"blurb": "How high the lamp at the side stands; a low lamp rakes long shadows across the ridges of sand."},
	"grains": {"label": "Grains", "type": "num", "range": [4000, 14000], "default": null,
		"blurb": "How many grains of sand lie on the plate."},
	"hold": {"label": "Figure hold", "type": "num", "range": [4.0, 20.0], "default": null,
		"blurb": "The fewest seconds one sand figure holds before the plate changes to another."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "particles"
	framing = "plane"
	_sim = SimClock.new(60.0)
	_forge = FrameForge.new()
	_light = Lighting.new(rng, rng.randi_range(2, 3))
	_csig.resize(12)

	_shape = String(choice("plate", rng))
	var boundary := "clamped" if rng.randf() < 0.45 else "free"
	# 52-88 cells per axis: even the coarse end has eight or nine cells across the highest mode's lobe;
	# the grid sets both the bake cost and the one-off build cost.
	var grid := rng.randi_range(52, 88)
	# Spread a full bake over roughly a quarter second, so a mode change costs a sliver of each frame.
	_bake_rows = maxi(4, int(ceil(float(grid) * 2.0 / 14.0)))
	_field = PlateField.new(_shape, boundary, grid, rng.randf() * TAU)
	_outline = _field.outline(72)

	var fname := String(choice("finish", rng))
	var fin: Dictionary = FINISHES[fname]
	_high_key = bool(fin["high"])
	# One color identity for plate, room and sand: cool metals and bone and the darker moods, nothing
	# that reads as a hot glow (the only light is a lamp at the side of a table).
	var sch := Scheme.among(["ash", "bone", "glacier", "brass", "abyss", "violet", "teal", "dawn"], rng)
	var fs: Array = fin["sat"]
	var fv: Array = fin["val"]
	var fst: Array = fin["streaks"]
	var fsh: Array = fin["sheen"]
	_plate_hue = sch.hue
	_plate_sat = rng.randf_range(float(fs[0]), float(fs[1]))
	_plate_val = rng.randf_range(float(fv[0]), float(fv[1]))
	_sheen = rng.randf_range(float(fsh[0]), float(fsh[1]))
	_rim_a = number("rim", rng)
	_plate_size = number("plate_size", rng)
	_streaks = rng.randi_range(int(fst[0]), int(fst[1]))
	_streak_a.resize(_streaks)
	for i in _streaks:
		_streak_a[i] = rng.randf_range(0.015, 0.075)
	# A brushed square is brushed along an edge; a disc or hexagon can be brushed any way.
	_brush = (0.0 if rng.randf() < 0.5 else PI * 0.5) if _shape == "square" else rng.randf() * PI

	# The rake: a low lamp puts a lit and a shadowed face on every ridge the grains pile into.
	var azimuth := rng.randf() * TAU
	var elevation: float = number("lamp_height", rng)
	_lx = cos(azimuth)
	_ly = sin(azimuth)
	_rake_k = 0.38 / (0.16 + elevation)
	_shadows = rng.randf() < clampf(1.15 - elevation * 2.2, 0.12, 0.95)
	_shadow_mul = 0.8 + 2.4 * (0.45 - elevation) / 0.35
	_shadow_drop = rng.randf_range(0.006, 0.018)

	# The sand. Pale grains on a dark plate, or dark filings on a pale board.
	_grain_hue = sch.accent
	_grain_sat = rng.randf_range(0.05, 0.30) if _high_key else rng.randf_range(0.04, 0.20)
	_v_lo = rng.randf_range(0.03, 0.10) if _high_key else rng.randf_range(0.20, 0.36)
	_v_hi = rng.randf_range(0.26, 0.42) if _high_key else rng.randf_range(0.86, 1.0)
	_blur = rng.randf_range(0.35, 0.75)
	_tint = rng.randf_range(0.20, 0.55)

	_count = number("grains", rng)
	# Grain size shrinks as the count rises so a dense plate stays a dust of specks; 7000 is the nominal count.
	_grain_r = rng.randf_range(0.0016, 0.0034) * sqrt(7000.0 / float(_count))
	_chunk = clampi(_count / 3, 600, 3000)
	_px.resize(_count)
	_py.resize(_count)
	_gsz.resize(_count)
	_sens.resize(_count)
	_shade.resize(_count)
	_amp.resize(_count)
	for i in _count:
		var x := 0.0
		var y := 0.0
		for _try in 12:
			x = rng.randf_range(-1.0, 1.0)
			y = rng.randf_range(-1.0, 1.0)
			if _field.inside(x, y):
				break
		if not _field.inside(x, y):
			x *= 0.4
			y *= 0.4
		_px[i] = x
		_py[i] = y
		_gsz[i] = rng.randf_range(0.62, 1.48)
		# Per-grain settling sensitivity: fines lift on nothing, coarse grains sit through a lot, which
		# keeps a nodal line soft-edged.
		_sens[i] = rng.randf_range(0.55, 1.60)

	# The walk. `descent` and `jitter` are rates in plate-widths per second, so the look does not change
	# with the stepping cadence (a grain is stepped every third tick, dt scaled to match).
	_base_drive = rng.randf_range(0.75, 1.35)
	# A grain stops where its local |w| * drive falls under its own threshold, so `settle` is the width of
	# the band the sand rests in, which is what a nodal line looks like. Kept small (rest only where |w| is
	# under a tenth of peak): a wide band blurs the figure, and a louder passage narrows it.
	_settle = rng.randf_range(0.02, 0.11)
	# How much overshoot past the threshold buys full mobility (else the ramp saturates instantly at these values).
	_ramp = rng.randf_range(0.25, 0.80)
	_descent = rng.randf_range(0.10, 0.40)
	# Twitch is a fraction of the creep: a grain that wanders faster than it descends never arrives.
	_jitter = _descent * rng.randf_range(0.25, 1.10)
	# How much creep and tremor survive at a true node. Both are needed together: tremor alone random-walks
	# the sand off the line, restoring force alone is a frozen plate. Together they give a dynamic
	# equilibrium, a line of finite width always shaken apart and pulled back.
	_creep_floor = rng.randf_range(0.18, 0.34)
	_shake_floor = rng.randf_range(0.45, 0.85)
	# The tremor: the plate vibrates, it does not switch between moving and still. Directed transport (creep
	# down the gradient of |w| until under threshold) alone ends in stillness. This is an agitation floor
	# with no threshold, scaled by local |w| and the drive: zero at a true node, so the lines stay sharp,
	# and a shimmer everywhere else, which makes the figure legible as an absence.
	_tremor = _descent * rng.randf_range(0.35, 0.95)
	_damping = rng.randf_range(0.6, 2.4)
	_w2 = rng.randf_range(0.10, 0.40)
	_tau = rng.randf_range(0.4, 2.0)
	_min_dwell = number("hold", rng)

	# The mode table and chroma-to-mode permutation: a given chord means a different figure in each session
	# and the same figure within one.
	var rr: Dictionary = RANGES[_shape]
	var mr: Array = rr["m"]
	var nr: Array = rr["n"]
	var m_lo := int(mr[0])
	var m_hi := int(mr[1])
	_n_lo = int(nr[0])
	_n_hi = int(nr[1])
	_perm.resize(12)
	_mtab.resize(12)
	_ntab.resize(12)
	for k in 12:
		_perm[k] = k
	for k in range(11, 0, -1):
		var s := rng.randi_range(0, k)
		var tmp := _perm[k]
		_perm[k] = _perm[s]
		_perm[s] = tmp
	for k in 12:
		_mtab[k] = rng.randi_range(m_lo, m_hi)
		_ntab[k] = rng.randi_range(_n_lo, _n_hi)

	# The opening figure comes from the seed: the scene is a picture on its first frame, before any chroma.
	_pick_mode(0, 1, 2)
	_field.begin(_cm, _cn, _cm2, _cn2, _w2)
	_field.complete()

	if _high_key:
		_room_hue = sch.accent
		_room_sat = rng.randf_range(0.02, 0.07)
		_room_val = rng.randf_range(0.88, 0.96)
	else:
		add_layer("bed", rng, {"hue": sch.accent, "sat": sch.sat * 0.5,
			"val": sch.val * rng.randf_range(0.08, 0.17),
			"pools": rng.randi_range(2, 4), "z": "back"})
	# Fines that never landed, turning in the lamp light. No shaft: the lamp is to the side, not overhead.
	add_layer("dust", rng, {"hue": _grain_hue, "shaft": false, "z": "front",
		"count": rng.randi_range(40, 110),
		"speed": rng.randf_range(0.006, 0.018),
		"drift": rng.randf_range(0.001, 0.005)})

	return {
		"shape": _shape,
		"boundary": boundary,
		"finish": fname,
		"mood": sch.name,
		"grains": _count,
		"grid": grid,
		"plate_size": _plate_size,
		"plate_hue": _plate_hue,
		"grain_hue": _grain_hue,
		"drive": _base_drive,
		"settle": _settle,
		"ramp": _ramp,
		"descent": _descent,
		"jitter": _jitter,
		"tremor": _tremor,
		"creep_floor": _creep_floor,
		"shake_floor": _shake_floor,
		"damping": _damping,
		"second_weight": _w2,
		"mode_tau": _tau,
		"min_dwell": _min_dwell,
		"rake_azimuth": azimuth,
		"rake_elevation": elevation,
		"shadows": _shadows,
		"streaks": _streaks,
		"mode_m": _to_array(_mtab),
		"mode_n": _to_array(_ntab),
		"chroma_perm": _to_array(_perm),
		"mode": [_cm, _cn, _cm2, _cn2],
	}


func _to_array(v: PackedInt32Array) -> Array:
	var out: Array = []
	for x in v:
		out.append(int(x))
	return out


func update(f: AudioFeatures, delta: float) -> void:
	tick(f, delta)
	drift_view(f, 0.012, 0.02)
	_light.update(f, delta)
	update_layers(f, delta)
	_ch = chroma_hue()

	# The chroma channels, smoothed on `mode_tau`. Guarded on the signature's size (empty until the analyzer has enough audio).
	var sig := signature()
	if sig.size() >= 12:
		var k := 1.0 - exp(-delta / _tau)
		for c in 12:
			_csig[c] = lerpf(_csig[c], sig[c], k)

	# A tap on the plate: fast attack, slow release, so the sand takes a moment to find the lines again.
	_tap = Nonlinear.flare(_tap, clampf(f.beat, 0.0, 1.0), delta, 12.0, 2.2)
	_drive = clampf(_base_drive * (0.30 + 1.30 * f.energy + 0.85 * _tap), 0.0, 1.8)

	_dwell += delta
	if _field.baking():
		_field.advance(_bake_rows)
	elif _field.blend < 1.0:
		# Flux only trims the crossfade (at 0.01-0.05, a +/-25% nudge). The duration is the sampled tau.
		_field.blend = minf(1.0, _field.blend + delta * (0.55 + 10.0 * f.flux) / _tau)
	elif _dwell >= _min_dwell:
		_change_mode()

	var steps := _sim.ticks(delta)
	for _i in steps:
		_walk(_sim.dt)
	if steps > 0 or not _kicked:
		_kicked = true
		_forge.kick(Callable(get_script(), "_build_grains"), _snapshot(), self)
	queue_redraw()


# Read the mode the music is asking for and start baking it, if it is not already on the plate. No rng
# is touched: this fires on an audio-conditioned event (live and offline feature streams differ).
func _change_mode() -> void:
	var i1 := 0
	for k in 12:
		if _csig[k] > _csig[i1]:
			i1 = k
	var i2 := -1
	for k in 12:
		if k != i1 and (i2 < 0 or _csig[k] > _csig[i2]):
			i2 = k
	var i3 := -1
	for k in 12:
		if k != i1 and k != i2 and (i3 < 0 or _csig[k] > _csig[i3]):
			i3 = k
	var pm := _cm
	var pn := _cn
	var pm2 := _cm2
	var pn2 := _cn2
	_pick_mode(i1, i2, i3)
	if _cm == pm and _cn == pn and _cm2 == pm2 and _cn2 == pn2:
		return
	_field.begin(_cm, _cn, _cm2, _cn2, _w2)
	_dwell = 0.0


func _pick_mode(i1: int, i2: int, i3: int) -> void:
	_cm = _mtab[_perm[i1]]
	_cn = _ntab[_perm[i2]]
	_cm2 = _mtab[_perm[i2]]
	_cn2 = _ntab[_perm[i3]]
	# On the square the antisymmetric pair vanishes when the two indices match, so nudge n by one rather
	# than show an empty plate; the disc and hexagon are sums and have no such degeneracy.
	if _shape == "square":
		var span := _n_hi - _n_lo + 1
		if _cm == _cn:
			_cn = _n_lo + (_cn - _n_lo + 1) % span
		if _cm2 == _cn2:
			_cn2 = _n_lo + (_cn2 - _n_lo + 1) % span


# One generation of the walk, for a rotating slice of the grains. Overdamped: sand creeps, so a grain is
# a position with no momentum, which also halves the state and arithmetic.
func _walk(dt: float) -> void:
	if _count <= 0:
		return
	var chunk := mini(_count, _chunk)
	var dte := dt * float(_count) / float(chunk)
	var gen := _sim.generation
	var drive := _drive
	var settle := _settle
	var ramp := _ramp
	var damp := _damping
	var desc := _descent
	var jit := _jitter
	var tremor := _tremor
	var creep_fl := _creep_floor
	var shake_fl := _shake_floor
	var lx := _lx
	var ly := _ly
	var rk := _rake_k
	for c in chunk:
		var i := (_cursor + c) % _count
		var x: float = _px[i]
		var y: float = _py[i]
		var s := _field.sample(x, y)
		var a: float = s.x
		var gx: float = s.y
		var gy: float = s.z
		var gl := sqrt(gx * gx + gy * gy) + 1e-5
		var ux := -gx / gl
		var uy := -gy / gl
		# Sand piles where the plate is still, so the pile's uphill direction is minus the gradient of |w|
		# and the rake lights the faces turned toward it. The (1 - a) factor is the pile's depth.
		_shade[i] = clampf(0.5 + rk * (ux * lx + uy * ly) * (1.0 - a), 0.0, 1.0)
		_amp[i] = a
		var thr := settle * _sens[i]
		var mob := clampf((a * drive - thr) / ramp, 0.0, 1.0)
		if mob > 0.0:
			# The mobility exponent is the grain character: below 1 the whole plate twitches (loose
			# dry sand), above 1 only the most violent regions move (heavy filings).
			mob = pow(mob, damp)
		# Both channels keep a floor at a node: scaling agitation by local |w| alone is a frozen plate in
		# disguise, since the sand ends up where |w| is smallest (motion fell to a third of a pixel per half second).
		var pull := maxf(mob, creep_fl)
		var trem := tremor * (shake_fl + a * drive)
		# Symmetry-breaking jitter from an integer hash of (grain, generation), not an rng draw: a SimClock's
		# tick count is wall-clock derived, so a seeded draw would desynchronize the export.
		var h := _hash2(i, gen)
		var jx := float(h & 2047) * 0.00097704 - 1.0
		var jy := float((h >> 11) & 2047) * 0.00097704 - 1.0
		var nx := x + (ux * desc * pull + jx * (jit * mob + trem)) * dte
		var ny := y + (uy * desc * pull + jy * (jit * mob + trem)) * dte
		if _field.inside(nx, ny):
			_px[i] = nx
			_py[i] = ny
	_cursor = (_cursor + chunk) % _count


static func _hash2(a: int, b: int) -> int:
	var x := a * 374761393 + b * 668265263
	x = (x ^ (x >> 13)) * 1274126177
	return x ^ (x >> 16)


func _snapshot() -> Dictionary:
	var u := unit()
	var glow := _light.glow()
	# Sound drives color: the sand's hue leans toward the tonal center by how tonal the moment is, and the dusting lifts on the beat glow.
	var dh: float = _ch.x - _grain_hue
	dh = dh - round(dh)
	var gc := Color.from_hsv(fposmod(_grain_hue + dh * _tint * _ch.y, 1.0), _grain_sat, 1.0)
	var pc := _plate_color()
	var gpx := u * _grain_r
	return {
		"n": _count,
		"px": _px.duplicate(),
		"py": _py.duplicate(),
		"shade": _shade.duplicate(),
		"amp": _amp.duplicate(),
		"gsz": _gsz,
		"half": u * _plate_size * 0.5,
		"grain_px": gpx,
		"r": gc.r, "g": gc.g, "b": gc.b,
		"v_lo": _v_lo,
		"v_hi": clampf(_v_hi + 0.22 * glow, 0.0, 1.0),
		"blur": _blur,
		"shadow": _shadows,
		"sx": -_lx * gpx * _shadow_mul,
		"sy": -_ly * gpx * _shadow_mul,
		"sr": pc.r * 0.30, "sg": pc.g * 0.30, "sb": pc.b * 0.30,
		"sa": clampf(0.42 - 0.12 * glow, 0.10, 0.55),
	}


## The grain builder - static and pure (the [FrameForge] contract): it touches only its snapshot and runs
## on a worker live, synchronously in an export. Two passes so every shadow lands under every grain.
static func _build_grains(s: Dictionary) -> Array:
	var tb := TriBatch.new()
	var n: int = s["n"]
	var px: PackedFloat32Array = s["px"]
	var py: PackedFloat32Array = s["py"]
	var sh: PackedFloat32Array = s["shade"]
	var am: PackedFloat32Array = s["amp"]
	var gz: PackedFloat32Array = s["gsz"]
	var half: float = s["half"]
	var gpx: float = s["grain_px"]
	if bool(s["shadow"]):
		var sx: float = s["sx"]
		var sy: float = s["sy"]
		var sr: float = s["sr"]
		var sg: float = s["sg"]
		var sb: float = s["sb"]
		var sa: float = s["sa"]
		var scol := Color(sr, sg, sb, sa)
		for i in n:
			var cx := px[i] * half + sx
			var cy := py[i] * half + sy
			var r := gz[i] * gpx * 1.2
			tb.tri(Vector2(cx, cy - r), Vector2(cx + 0.866 * r, cy + 0.5 * r),
				Vector2(cx - 0.866 * r, cy + 0.5 * r), scol)
	var cr: float = s["r"]
	var cg: float = s["g"]
	var cb: float = s["b"]
	var v_lo: float = s["v_lo"]
	var v_hi: float = s["v_hi"]
	var blur: float = s["blur"]
	var vspan := v_hi - v_lo
	for i in n:
		var cx := px[i] * half
		var cy := py[i] * half
		var r := gz[i] * gpx
		var v := v_lo + vspan * sh[i]
		# A grain still being thrown about is a blur, so it thins out; that is why the nodal lines read as solid.
		var al := clampf(1.0 - blur * am[i], 0.22, 1.0)
		var col := Color(cr * v, cg * v, cb * v, al)
		# A grain is one triangle, not a quad: at two pixels across it is a third fewer vertices.
		tb.tri(Vector2(cx, cy - r), Vector2(cx + 0.866 * r, cy + 0.5 * r),
			Vector2(cx - 0.866 * r, cy + 0.5 * r), col)
	return tb.take_chunks()


func _plate_color() -> Color:
	return Color.from_hsv(
		fposmod(_plate_hue + 0.05 * _light.hue_shift(), 1.0),
		_plate_sat,
		clampf(_plate_val * (0.92 + 0.22 * _light.glow()), 0.0, 1.0))


func _draw() -> void:
	begin_draw()
	if _high_key:
		paint_ground(_room_hue, _room_sat, _room_val, 0.35 * _ch.y, _ch.x)
	draw_layers("back")
	_draw_plate()
	_forge.submit(self)
	draw_layers("front")


func _draw_plate() -> void:
	var u := unit()
	var half := u * _plate_size * 0.5
	var pc := _plate_color()
	var n := _outline.size()
	if n < 3:
		return
	# The plate's own shadow on the table, thrown away from the lamp.
	var off := Vector2(-_lx, -_ly) * u * _shadow_drop
	var shadow := PackedVector2Array()
	for p in _outline:
		shadow.append(p * half + off)
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.34))
	# The face as a fan with per-vertex shading, so the raking light rakes across it.
	var lit := Vector2(_lx, _ly)
	for i in n:
		var pa: Vector2 = _outline[i]
		var pb: Vector2 = _outline[(i + 1) % n]
		_tb.tri_colored(Vector2.ZERO, pa * half, pb * half,
			_face_col(pc, 0.0),
			_face_col(pc, pa.normalized().dot(lit)),
			_face_col(pc, pb.normalized().dot(lit)))
	_tb.flush(self)
	# A scratch on a dark plate catches the lamp, on a pale board it is a dark line: the stroke color follows the finish.
	var mark := 0.0 if _high_key else 1.0
	if _streaks > 0:
		var bd := Vector2(cos(_brush), sin(_brush))
		var pn := Vector2(-bd.y, bd.x)
		var w := maxf(1.0, u * 0.0012)
		for i in _streaks:
			var t := (float(i) + 0.5) / float(_streaks) * 2.0 - 1.0
			var hl := _chord(t)
			if hl <= 0.002:
				continue
			var c := pn * t * _span()
			draw_line((c - bd * hl) * half, (c + bd * hl) * half,
				Color(mark, mark, mark, _streak_a[i]), w, true)
	var ring := _outline.duplicate()
	for i in ring.size():
		ring[i] = ring[i] * half
	ring.append(ring[0])
	draw_polyline(ring, Color(mark, mark, mark, _rim_a), maxf(1.0, u * 0.0022), true)


func _face_col(pc: Color, d: float) -> Color:
	var k := clampf(1.0 + _sheen * d, 0.25, 1.75)
	return Color(pc.r * k, pc.g * k, pc.b * k, 1.0)


# How far the brush stroke at perpendicular offset `t` may run without leaving the plate: the square always
# spans the full width; the disc gets its true chord; the hexagon borrows the inscribed circle's (conservative,
# keeps streaks off the corners).
func _chord(t: float) -> float:
	if _shape == "square":
		return 1.0
	var k := sqrt(maxf(0.0, 1.0 - t * t))
	return k if _shape == "circle" else 0.8660254 * k


func _span() -> float:
	return 0.8660254 if _shape == "hex" else 1.0
