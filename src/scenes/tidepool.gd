extends GhostScene

## Tidepool - sunlight through a hand's depth of moving water.
##
## Looking straight down into a clear pool over stones, sand and weed in full daylight. The
## surface is a wave field (a swell from one edge, finer chop crossing it, ring waves where drips
## land); what you watch is the caustic net on the bed, with the stones swimming slightly under
## the crests because the bed's image is refracted too.
##
## The caustics are computed, not drawn. At every grid node the surface normal comes from
## [WaveField]'s closed-form gradient, the sun vector is refracted through it by Snell's law, the
## ray is walked to the bed plane and its energy splatted bilinearly into an accumulation
## buffer; bright ribs are where many rays land together. A short separable blur stands in for
## the sun's angular width. The bed's image is refracted along the straight-down viewing ray.
##
## The seed decides the pool (span, depth 0.05-0.35, an optional dry shelf, turbidity, index of
## refraction 1.30-1.36), the sun, the surface (6-14 Gerstner components around one swell
## heading, one tempo scaling the dispersion), the bed (20-90 stones from an ocean or earth
## [Palette]) and the light.
##
## Audio: each component owns a fixed band by wavelength rank (longest reads the lowest) through
## a slow-attack envelope, so bass grows long swell and brightness grows fine chop. A drip ring
## reads the water it crosses (see [method WaveField.sweep_rings]). Nothing scales with
## loudness: a louder song is a rougher surface, not a bigger one. `f.movement` raises the global
## Gerstner steepness (pinching ribs into knots). Rising edges of `f.beat` drop drips at
## pre-rolled Halton positions (an index into a table, never an rng draw). `chroma_hue()` sets
## the water's tint and the sky reflection's hue; `f.energy` moves only the glare threshold.
##
## Ranges: `f.energy` rarely passes 0.5 and one band through `f.sample()` sits under 0.3, so a
## component's drive is `0.22 + 1.7 * level`. The amplitude-to-wavelength ratio is sampled in
## 0.03-0.075, where caustics appear (below about a fortieth of a wavelength the bed gets a
## mottle, not a net). `jz` is clamped off zero at 0.15: a negative Jacobian is a folded surface.
##
## Cost: the sweep, light cast, blur, shading and batching run in a [FrameForge] job (about 30
## ms at 1920x1080), so the water is rebuilt at 20-30 Hz; that is affordable because the surface
## is slow (the fastest period is 1.5-2.7 s). The grid is sized against [constant SWEEP_BUDGET].
## The mesh is one vertex per node plus one per cell center with shared indices, so a frame
## rewrites only colors. Arrays handed to the main thread are never written again.
##
## The drips and amplitude envelopes are state, so they advance on a [SimClock] (the Director
## sub-steps update() up to fifteen times a frame and pre-warms a new scene twelve times).

## How far the node grid runs past the frame: refraction throws light sideways by up to about
## 1.1 times the depth, so a hard pool edge at the frame would show a dim band; the overdraw plus
## the wrapped accumulation buffer hide it.
const OVER := 1.18

## Node-work per frame the build is allowed, in units of one Gerstner component at one node. The
## grid is derived from this and the component count. It counts all O(nodes) work, not just
## `nodes * components`, or a six-component surface would get the finest grid and cost the most
## (tests/scenes/tidepool_cost_probe.gd). PER_NODE is the rest of the frame in the same unit
## (about fourteen components), which makes the cost flat in the component count.
const SWEEP_BUDGET := 100000
const PER_NODE := 14.0

## Node-count bounds the budget is clamped into, so neither a very simple nor a very busy
## surface leaves the range where a caustic rib is a few cells wide.
const NODES_MIN := 3400
const NODES_MAX := 6800

## Schlick's F0 for an air/water interface, ((1-1.33)/(1+1.33))^2, about 0.02: flat water barely
## reflects, so a pool seen from above is transparent and only steep faces flash.
const F0 := 0.02

## Gerstner surfaces fold over past this Jacobian; clamping there caps how far a crest may
## tilt its own normal instead of letting it invert.
const JZ_FLOOR := 0.15

## At most this many drip rings at once; each costs work proportional to its circumference.
const MAX_RINGS := 4

## Pre-rolled drip slots, walked by an index on a beat, never re-drawn.
const DRIP_SLOTS := 24

var _sim: SimClock
var _forge := FrameForge.new()
var _job: PoolJob
var _wf: WaveField

var _gw := 96
var _gh := 54
var _step := 0.01
var _org := Vector2.ZERO
var _span := 1.0

var _bands := PackedFloat32Array()      # per component: its fixed spectral position
var _drive := PackedFloat32Array()      # per component: gain on that band
var _floor := PackedFloat32Array()      # per component: its amplitude at silence
var _base := PackedFloat32Array()       # per component: amplitude at full drive
var _amp := PackedFloat32Array()        # the live, enveloped amplitudes
var _atk := 0.6
var _rel := 0.35

var _steep := 1.0
var _move_gain := 1.4

var _drips: Array = []                  # the pre-rolled slot table
var _drip_i := 0
var _rings: Array = []
var _beat_prev := 0.0
var _beat_arm := 0.0
var _drip_gap := 0.5
## How far a drip ring's front is carried by the swell it is crossing, as a multiple of the
## swell's live amplitude, and how hard the chop damps it. See WaveField.sweep_rings.
var _ring_warp := 1.6
var _ring_damp := 0.6

var _t_sim := 0.0
var _kicked := false
var _ch := Vector2.ZERO           # the SMOOTHED tonal center, as (hue, strength)
var _ch_vec := Vector2.ZERO       # ... carried in CARTESIAN form, which is what makes it smooth
var _glare_e := 0.0               # enveloped energy behind the glare threshold

var _hue := 0.55
var _sky_hue := 0.58
var _ground_val := 0.72
var _ground_sat := 0.07
var _water_sat := 0.42
var _water_val := 0.86
var _sky_sat := 0.10
var _sun_col := Color(1.0, 0.98, 0.94)
var _amb := 0.4
var _contrast := 1.6
var _sharp := 0.35
var _exposure := 1.0
var _glare_hi := 0.72
var _glare_lo := 0.42
var _glare_gain := 0.9


## What this scene can be told ([method GhostScene.number]): a storyboard entry's `set`, by name;
## a setting not told is drawn from the seed.
const FIELDS := {
	"wave_speed": {"label": "Wave speed", "type": "num", "range": [0.08, 0.17], "default": null,
		"blurb": "How fast the waves move across the pool."},
	"wave_height": {"label": "Wave height", "type": "num", "range": [0.030, 0.075], "default": null,
		"blurb": "How tall the waves stand for their length."},
	"murk": {"label": "Murk", "type": "num", "range": [0.15, 0.85], "default": null,
		"blurb": "How murky the water over the pool floor is."},
	"stones": {"label": "Stones", "type": "num", "range": [20, 90], "default": null,
		"blurb": "How many stones lie on the pool floor."},
	"weed": {"label": "Weed", "type": "num", "range": [0.0, 0.9], "default": null,
		"blurb": "How much of the pool floor is covered in weed."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "canvas"
	framing = "field"

	# Daylight over water: the cold, pale end of the mood table plus one warm dawn option.
	var sch := Scheme.among(["glacier", "teal", "bone", "dawn"], rng)
	_hue = sch.hue
	_sky_hue = sch.accent
	_ground_val = rng.randf_range(0.55, 0.85)
	_ground_sat = rng.randf_range(0.03, 0.11)
	_water_sat = rng.randf_range(0.26, 0.58)
	_water_val = rng.randf_range(0.72, 0.94)
	_sky_sat = rng.randf_range(0.05, 0.18)

	# --- the surface ------------------------------------------------------------------
	var comps := rng.randi_range(6, 14)
	var nodes := clampi(int(float(SWEEP_BUDGET) / (float(comps) + PER_NODE)), NODES_MIN, NODES_MAX)
	# Nominal 16:9 (`size` is unknown during build); the grid maps onto the frame with a uniform
	# scale, so the waves never stretch.
	_gw = maxi(24, int(round(sqrt(float(nodes) * 16.0 / 9.0))))
	_gh = maxi(16, int(round(float(nodes) / float(_gw))))
	_span = rng.randf_range(0.7, 1.6)
	_step = _span / float(_gw - 1)
	_org = Vector2(-float(_gw - 1) * _step * 0.5, -float(_gh - 1) * _step * 0.5)

	# The field's speed: `tempo` scales every component's dispersion-derived frequency. At
	# 0.08-0.17 the fastest chop has a period of 1.3-2.6 s and the longest swell 3.5-7 s; faster,
	# the surface strobes against the 20-30 Hz rebuild. The dispersion relation is untouched (long
	# waves outrun short ones), which keeps swell and chop one body of water.
	var tempo: float = number("wave_speed", rng)
	# A few percent of detune per component, so the field does not return to the same
	# configuration on a fixed cycle.
	var detune := rng.randf_range(0.02, 0.09)
	var swell := rng.randf() * TAU               # the heading the whole sea arrives on
	var fan := rng.randf_range(0.35, 1.25)       # how far components fan off that heading
	var ratio: float = number("wave_height", rng)   # amplitude as a fraction of wavelength
	var q_lo := rng.randf_range(0.25, 0.45)
	var q_hi := rng.randf_range(0.55, 0.95)
	_move_gain = rng.randf_range(0.8, 2.2)
	_atk = rng.randf_range(0.35, 0.8)            # slow ATTACK: a swell takes seconds to build
	_rel = rng.randf_range(0.18, 0.45)

	_wf = WaveField.new()
	var lam: Array = []
	for i in comps:
		# Wavelengths spread geometrically from a long swell to a fine chop (a fraction of the
		# pool, spanning a factor of ten).
		var u := (float(i) + rng.randf_range(0.05, 0.95)) / float(comps)
		lam.append(_span * (0.62 * pow(0.11, u)))
	lam.sort()
	lam.reverse()                                # longest first, so index IS wavelength rank
	for i in comps:
		var wl: float = lam[i]
		var ang := swell + rng.randf_range(-fan, fan) * 0.5
		var q := rng.randf_range(q_lo, q_hi)
		_wf.add(ang, wl, 0.0, q, rng.randf() * TAU, tempo * (1.0 + rng.randf_range(-detune, detune)))
		_base.append(wl * ratio * rng.randf_range(0.7, 1.3))
		# Band assignment is the audio design: rank 0 (longest) reads the bottom of the spectrum,
		# the last the top, jittered so two components never share a band.
		var bt := (float(i) + 0.5) / float(comps)
		_bands.append(clampf(bt + rng.randf_range(-0.05, 0.05), 0.02, 0.97))
		_drive.append(rng.randf_range(1.2, 2.2))
		_floor.append(rng.randf_range(0.10, 0.30))
		_amp.append(0.0)

	# --- drips ---------------------------------------------------------------------------
	# Halton (2, 3) rather than an rng: successive drips spread across the pool, and the
	# sequence is an index, so a beat never touches a random source.
	var half_w := float(_gw - 1) * _step * 0.5
	var half_h := float(_gh - 1) * _step * 0.5
	var ring_speed_lo := rng.randf_range(0.05, 0.11)
	var ring_speed_hi := rng.randf_range(0.14, 0.26)
	for i in DRIP_SLOTS:
		var hx := _halton(i + 3, 2)
		var hy := _halton(i + 3, 3)
		var wl := _span * rng.randf_range(0.035, 0.085)
		_drips.append({
			"x": lerpf(-half_w * 0.92, half_w * 0.92, hx),
			"y": lerpf(-half_h * 0.92, half_h * 0.92, hy),
			"k": TAU / wl,
			"w": _span * rng.randf_range(0.055, 0.13),
			"speed": rng.randf_range(ring_speed_lo, ring_speed_hi),
			"a0": wl * rng.randf_range(0.05, 0.11),
			"q": rng.randf_range(0.3, 0.7),
			"phi_rate": rng.randf_range(1.3, 2.6),   # carrier outruns the front (see WaveField)
			"ph": rng.randf() * TAU,
			"life": rng.randf_range(2.2, 5.5),
		})
	_drip_gap = rng.randf_range(0.25, 0.9)
	# How strongly a ring is carried and eaten by the water it crosses: a property of the pool,
	# so sampled.
	_ring_warp = rng.randf_range(0.9, 2.6)
	_ring_damp = rng.randf_range(0.25, 1.1)

	# --- the pool floor ------------------------------------------------------------------
	var depth := rng.randf_range(0.05, 0.35) * _span
	var turbid: float = number("murk", rng)
	var ior := rng.randf_range(1.30, 1.36)
	var shelf := rng.randf() < 0.45
	var shelf_ang := rng.randf() * TAU
	var shelf_len := _span * rng.randf_range(0.45, 1.05)
	var shelf_wob := _span * rng.randf_range(0.02, 0.09)

	var sun_el := deg_to_rad(rng.randf_range(35.0, 88.0))
	var sun_az := rng.randf() * TAU
	var shine_sq := rng.randi_range(4, 6)          # specular exponent = 2^shine_sq
	_glare_hi = rng.randf_range(0.62, 0.86)
	_glare_lo = rng.randf_range(0.30, 0.52)
	_glare_gain = rng.randf_range(0.55, 1.25)
	_amb = clampf(rng.randf_range(0.24, 0.48) + turbid * 0.18, 0.0, 0.8)
	_contrast = rng.randf_range(1.15, 2.3) * (1.0 - 0.35 * turbid)
	# No sharpening: it squares the caustic contrast, narrowing ribs that are already one or two
	# nodes wide (21-29 screen pixels at 1920x1080), which aliases rather than sharpens.
	_sharp = rng.randf_range(0.0, 0.18)
	_exposure = rng.randf_range(0.94, 1.18)
	_sun_col = Color(1.0, rng.randf_range(0.94, 1.0), rng.randf_range(0.86, 0.99))

	# 20-30 sim ticks a second; the wave is analytic, so this clock serves the ring lifecycles and
	# the amplitude envelopes.
	_sim = SimClock.new(rng.randf_range(22.0, 32.0), 2)

	# The bed is 200-272 texels (a texel 7-10 px at 1920x1080): it is what the scene looks at
	# through the water, and the dry shelf shows it bare. Build-time only (build_bed runs once,
	# O(res^2)).
	var bed_res := rng.randi_range(200, 272)
	var stones: int = number("stones", rng)
	var ramp_name := "ocean" if rng.randf() < 0.55 else "earth"
	var mix := {
		"cobble": rng.randf_range(0.2, 1.0),
		"sand": rng.randf_range(0.4, 1.0),
		"weed": number("weed", rng),
		"shell": rng.randf_range(0.0, 0.6),
	}

	_job = PoolJob.new()
	_job.wf = _wf
	_job.gw = _gw
	_job.gh = _gh
	_job.org = _org
	_job.step = _step
	_job.eta = 1.0 / ior
	# Two to four passes of the five-tap binomial in _blur. The accumulation buffer is at node
	# resolution, so a rib is one or two cells wide and a single pass leaves a hard-edged wedge;
	# widening spreads the shoulder across two or three cells, as the sun's angular width does.
	_job.blur_n = rng.randi_range(2, 3)
	_job.shine_sq = shine_sq
	_job.wet_band = depth * rng.randf_range(0.10, 0.30)
	_job.dry_lift = rng.randf_range(1.02, 1.14)
	_job.sun = Vector3(cos(sun_el) * cos(sun_az), cos(sun_el) * sin(sun_az), sin(sun_el))
	# Blinn half vector against a camera looking straight down: a real specular lobe.
	_job.half_v = (_job.sun + Vector3(0.0, 0.0, 1.0)).normalized()
	_job.alloc()
	_job.build_depth(depth, shelf, shelf_ang, shelf_len, shelf_wob, turbid, rng.randi())
	_job.build_bed(rng, bed_res, _span, ramp_name, stones, mix, sun_az, sun_el)

	if rng.randf() < 0.5:
		# Grit and pollen riding the film, seen from above; no shaft (an overhead shot has no
		# sideways light).
		add_layer("dust", rng, {"count": rng.randi_range(30, 80), "shaft": false,
			"hue": sch.accent, "speed": 0.012, "jitter": 0.04})

	return {
		"mood": sch.name, "components": comps, "grid_w": _gw, "grid_h": _gh,
		"span": _span, "depth": depth, "turbidity": turbid, "ior": ior,
		"tempo": tempo, "swell_deg": rad_to_deg(swell), "fan": fan,
		"amp_ratio": ratio, "steep_range": [q_lo, q_hi], "move_gain": _move_gain,
		"attack": _atk, "release": _rel,
		"sun_elev_deg": rad_to_deg(sun_el), "sun_azim_deg": rad_to_deg(sun_az),
		"shelf": "dry" if shelf else "submerged", "shelf_len": shelf_len,
		"bed_res": bed_res, "stones": stones, "ramp": ramp_name, "mix": mix,
		"ambient": _amb, "contrast": _contrast, "sharp": _sharp,
		"shine": 1 << shine_sq, "glare": [_glare_lo, _glare_hi], "glare_gain": _glare_gain,
		"ground_val": _ground_val, "drip_gap": _drip_gap, "rate": _sim.rate,
		"blur": _job.blur_n,
	}


func update(f: AudioFeatures, delta: float) -> void:
	tick(f, delta)
	# A pool does not pan: the drift is barely there, since an overhead shot with a moving camera
	# reads as a drone.
	drift_view(f, 0.012, 0.018)
	update_layers(f, delta)

	var steps := _sim.ticks(delta)
	for _i in steps:
		_advance(_sim.dt, f)
	if steps <= 0 and _kicked:
		queue_redraw()
		return
	_kicked = true

	# The water's own color, pulled a little toward the music's tonal center (a wash). Blended on
	# the wheel, not the shortest arc ([method GhostScene.blend_hue]): the arc form flips sign at
	# the antipode and jumps the color between frames.
	var wh := blend_hue(_hue, _ch.x, 0.3 * _ch.y)
	var sh := blend_hue(_sky_hue, _ch.x, 0.45 * _ch.y)
	# Glare threshold is the only thing energy touches: a loud passage lowers the bar the specular
	# lobe must clear. It reads the enveloped energy (see _advance), since the glare lays the sky's
	# color over the pool and would strobe on a jumpy source.
	var thr := lerpf(_glare_hi, _glare_lo, _glare_e)

	var rings: Array = []
	for entry in _rings:
		var r: Dictionary = entry
		rings.append({"x": r["x"], "y": r["y"], "r": r["r"], "w": r["w"],
			"a": r["a"], "k": r["k"], "phi": r["phi"], "ph": r["ph"], "q": r["q"],
			# `warp` multiplies the local swell height, so it follows the water actually running.
			# `warp_max` is the largest displacement it can produce (the row spans are widened by
			# it); it needs the live amplitude sum, which folded into `warp` would make the
			# displacement quadratic in it.
			"warp": _ring_warp, "warp_max": _ring_warp * _swell_amp(), "damp": _ring_damp})

	var cell := maxf(maxf(size.x, 1.0) * OVER / float(_gw - 1),
		maxf(size.y, 1.0) * OVER / float(_gh - 1))
	_forge.kick(_job.run, {
		"t": _t_sim,
		"amps": _amp.duplicate(),
		"steep": _steep,
		"rings": rings,
		"cell": cell,
		"water": Color.from_hsv(wh, _water_sat, _water_val),
		"sky": Color.from_hsv(sh, _sky_sat, 1.0),
		"sun": _sun_col,
		"amb": _amb,
		"contrast": _contrast,
		"sharp": _sharp,
		"exposure": _exposure,
		"glare_thr": thr,
		"glare_gain": _glare_gain,
	}, self, _job)
	queue_redraw()


## One fixed simulation step: the amplitude envelopes, the chop, and the drip lifecycles.
func _advance(dt: float, f: AudioFeatures) -> void:
	_t_sim += dt
	for i in _amp.size():
		var lvl := f.sample(_bands[i])
		var target: float = _base[i] * clampf(_floor[i] + _drive[i] * lvl, 0.0, 1.6)
		_amp[i] = Nonlinear.flare(_amp[i], target, dt, _atk, _rel)

	# Movement is a section change, and a section change roughens water: steepness pinches the
	# ribs and moves nothing.
	_steep = Nonlinear.flare(_steep, 1.0 + _move_gain * f.movement, dt, 1.6, 0.7)

	# The tonal center, eased in Cartesian form: chroma_hue() hands back an angle, which flips half
	# a turn when two tonal centers a tritone apart trade dominance. Easing the vector routes that
	# through the middle (an ambiguous tonality reads as low strength and the tint fades out). The
	# 1.2 s constant matches the 2.5 s window the harmonic signature integrates.
	var raw := chroma_hue()
	var want := Vector2(cos(raw.x * TAU), sin(raw.x * TAU)) * raw.y
	_ch_vec = _ch_vec.lerp(want, 1.0 - exp(-0.85 * dt))
	_ch = Vector2(fposmod(_ch_vec.angle() / TAU, 1.0), clampf(_ch_vec.length(), 0.0, 1.0))

	# Same for the glare drive: fast to bloom, slow to fall.
	_glare_e = Nonlinear.flare(_glare_e, clampf(f.energy * 2.0, 0.0, 1.0), dt, 3.5, 1.2)

	_beat_arm += dt
	var rising := f.beat > 0.55 and _beat_prev <= 0.55
	_beat_prev = f.beat
	if rising and _beat_arm >= _drip_gap:
		_beat_arm = 0.0
		_spawn_drip()

	var live: Array = []
	for entry in _rings:
		var r: Dictionary = entry
		var age: float = float(r["age"]) + dt
		var rad: float = float(r["r"]) + float(r["speed"]) * dt
		if age >= float(r["life"]) or rad > _span * 1.2:
			continue
		r["age"] = age
		r["r"] = rad
		r["phi"] = float(r["phi"]) + float(r["phi_rate"]) * dt
		# Two decays, both physical: the packet loses energy with time, and a ring spreads
		# its fixed energy round a growing circumference, so its height falls as 1/sqrt(r).
		var fade := clampf(1.0 - age / maxf(0.01, float(r["life"])), 0.0, 1.0)
		var r0: float = maxf(0.01, float(r["w"]))
		r["a"] = float(r["a0"]) * fade * fade * sqrt(r0 / maxf(rad, r0))
		live.append(r)
	_rings = live


## The swell's live amplitude: the sum of what the components are carrying now. The ring
## couplings scale by it so they answer the water in front of them, not a build-time guess.
func _swell_amp() -> float:
	var a := 0.0
	for v in _amp:
		a += v
	return a


func _spawn_drip() -> void:
	var slot: Dictionary = _drips[_drip_i % _drips.size()]
	_drip_i += 1
	if _rings.size() >= MAX_RINGS:
		_rings.remove_at(0)                  # the oldest yields, deterministically
	_rings.append({
		"x": slot["x"], "y": slot["y"], "r": 0.0, "w": slot["w"],
		"a": 0.0, "a0": slot["a0"], "k": slot["k"], "q": slot["q"],
		"phi": 0.0, "phi_rate": float(slot["phi_rate"]) * float(slot["speed"]) * float(slot["k"]),
		"ph": slot["ph"], "speed": slot["speed"], "age": 0.0, "life": slot["life"],
	})


func _draw() -> void:
	begin_draw()
	# Flat, bright and full bleed, first: the safety net under a drifting camera. It must be the
	# high-key ground, since Layer's bed vignettes and tops out at a mid tone.
	paint_ground(_hue, _ground_sat, _ground_val, _ch.y * 0.4, _ch.x)
	draw_layers("back")
	_forge.submit(self)
	draw_layers("front")


## The radical-inverse of [param i] in [param b] - the Halton sequence, used here so
## successive drips land spread across the pool instead of clumping.
static func _halton(i: int, b: int) -> float:
	var f := 1.0
	var r := 0.0
	var n := i
	while n > 0:
		f /= float(b)
		r += f * float(n % b)
		n /= b
	return r


## The off-thread build (the [FrameForge] job-object form): owns the wave field, scratch buffers,
## the static depth and absorption maps and the baked bed texture; the scene never reads them.
## `pts` and `idx` are rebuilt (as new arrays) only when the frame size changes.
class PoolJob:
	extends RefCounted

	var wf: WaveField
	var gw := 96
	var gh := 54
	var org := Vector2.ZERO
	var step := 0.01

	var hh := PackedFloat32Array()
	var gxx := PackedFloat32Array()
	var gyy := PackedFloat32Array()
	var jzz := PackedFloat32Array()
	var acc := PackedFloat32Array()
	var tmp := PackedFloat32Array()
	var dep := PackedFloat32Array()          # water depth at each node - static
	var att := PackedFloat32Array()          # absorption 0..1 at each node - static

	var bed_r := PackedFloat32Array()
	var bed_g := PackedFloat32Array()
	var bed_b := PackedFloat32Array()
	var bw := 128
	var bh := 128
	var bed_org := Vector2.ZERO
	var bed_step := 0.01

	var pts := PackedVector2Array()
	var idx := PackedInt32Array()
	var pts_cell := -1.0

	var sun := Vector3(0.0, 0.0, 1.0)
	var half_v := Vector3(0.0, 0.0, 1.0)
	var eta := 0.75
	var blur_n := 1
	var shine_sq := 5
	var wet_band := 0.02
	var dry_lift := 1.06
	var wet_nodes := 1


	func alloc() -> void:
		var n := gw * gh
		hh.resize(n)
		gxx.resize(n)
		gyy.resize(n)
		jzz.resize(n)
		acc.resize(n)
		tmp.resize(n)
		dep.resize(n)
		att.resize(n)


	## The pool's floor: a constant depth, optionally rising into a dry shelf along one diagonal
	## with a wandering shoreline. Static, so the absorption it implies is baked here.
	func build_depth(base: float, shelf: bool, ang: float, length: float, wob: float,
			turbid: float, seed_value: int) -> void:
		var edge := Field.make("fbm", seed_value, 2.6 / maxf(0.01, length), 3)
		var dir := Vector2(cos(ang), sin(ang))
		# A depth of a hand over pale sand still reads as clear water: the extinction
		# coefficient is set so the deepest sampled pool loses about two thirds of its bed.
		var sigma := (1.6 + 5.0 * turbid) / maxf(0.02, base)
		var i := 0
		wet_nodes = 0
		for iy in gh:
			for ix in gw:
				var p := org + Vector2(float(ix), float(iy)) * step
				var d := base
				if shelf:
					# Distance along the diagonal from the shallow corner, wobbled so the waterline
					# is a shoreline.
					var u := (p.dot(dir) + length * 0.5 + (edge.at(p) - 0.5) * 2.0 * wob) / length
					d = base * smoothstep(0.0, 1.0, clampf(u, 0.0, 1.0))
				dep[i] = d
				att[i] = 1.0 - exp(-sigma * d)
				if d > 0.0005:
					wet_nodes += 1
				i += 1
		wet_nodes = maxi(1, wet_nodes)


	## Bake the bed (sand, stones, weed, shell) into a color texture sampled bilinearly through
	## the refracted view ray. It spans half again the pool so the lookup never runs off it, at
	## about the node grid's resolution.
	func build_bed(rng: RandomNumberGenerator, res: int, span: float, ramp_name: String,
			stones: int, mix: Dictionary, sun_az: float, sun_el: float) -> void:
		bw = res
		bh = res
		var side := span * 1.5
		bed_step = side / float(bw - 1)
		bed_org = Vector2(-side * 0.5, -side * 0.5)
		var n := bw * bh
		bed_r.resize(n)
		bed_g.resize(n)
		bed_b.resize(n)

		var w_sand: float = mix["sand"]
		var w_weed: float = mix["weed"]
		var w_cobble: float = mix["cobble"]
		var w_shell: float = mix["shell"]

		var ramp := Palette.named(ramp_name, rng)
		var relief := Field.make("fbm", rng.randi(), rng.randf_range(2.0, 4.5), 3)
		var mottle := Field.make("billow", rng.randi(), rng.randf_range(5.0, 11.0), 3)
		var sand_h := rng.randf_range(0.06, 0.13)
		var sand_s := rng.randf_range(0.10, 0.26)
		var sand_v := rng.randf_range(0.62, 0.86)
		var grain := rng.randf_range(0.04, 0.13) * (0.4 + 0.6 * w_sand)
		var weed_thr := lerpf(1.05, 0.42, clampf(w_weed, 0.0, 1.0))
		var weed_h := rng.randf_range(0.22, 0.36)
		var weed_s := rng.randf_range(0.35, 0.7)
		var weed_v := rng.randf_range(0.16, 0.34)
		var hseed := rng.randf() * 100.0

		var i := 0
		for iy in bh:
			for ix in bw:
				var p := bed_org + Vector2(float(ix), float(iy)) * bed_step
				var rl := relief.at(p)
				var mo := mottle.at(p)
				# One cheap hash for the sand grain: the detail only has to be uncorrelated.
				var hsh := sin(float(ix) * 127.1 + float(iy) * 311.7 + hseed) * 43758.5453
				hsh -= floor(hsh)
				var v := clampf(sand_v * (0.82 + 0.30 * rl) + (hsh - 0.5) * grain, 0.0, 1.0)
				var col := Color.from_hsv(fposmod(sand_h + (mo - 0.5) * 0.03, 1.0),
					clampf(sand_s * (0.75 + 0.5 * mo), 0.0, 1.0), v)
				if mo > weed_thr:
					var wk := clampf((mo - weed_thr) / maxf(0.02, 1.0 - weed_thr), 0.0, 1.0)
					col = col.lerp(Color.from_hsv(fposmod(weed_h + (rl - 0.5) * 0.05, 1.0),
						weed_s, weed_v * (0.7 + 0.5 * rl)), wk * 0.85)
				bed_r[i] = col.r
				bed_g[i] = col.g
				bed_b[i] = col.b
				i += 1

		# Stones, rasterized over their own bounding boxes. Each gets a dome normal so it is lit
		# round, and a contact shadow away from the sun: why a top-down cobble reads as solid.
		var sx := cos(sun_az)
		var sy := sin(sun_az)
		var lam := cos(sun_el)
		var count := int(round(float(stones) * clampf(0.3 + w_cobble, 0.3, 1.6)))
		for k in count + int(round(float(stones) * w_shell * 0.5)):
			var shell := k >= count
			var c := bed_org + Vector2(rng.randf(), rng.randf()) * (side)
			var rx: float = span * (rng.randf_range(0.012, 0.030) if shell
				else rng.randf_range(0.022, 0.075))
			var ry := rx * rng.randf_range(0.62, 1.0)
			var rot := rng.randf() * TAU
			var cr := cos(rot)
			var sr := sin(rot)
			var t := rng.randf()
			var sc: Color = ramp.at(0.55 + 0.4 * t)
			if shell:
				sc = Color.from_hsv(fposmod(sand_h + rng.randf_range(-0.04, 0.06), 1.0),
					rng.randf_range(0.04, 0.16), rng.randf_range(0.86, 0.99))
			else:
				sc = Color.from_hsv(sc.h, clampf(sc.s * rng.randf_range(0.5, 1.0), 0.0, 1.0),
					clampf(sc.v * rng.randf_range(0.6, 1.05), 0.0, 1.0))
			var rmax := maxf(rx, ry) + bed_step
			var ix0 := maxi(0, int(floor((c.x - rmax - bed_org.x) / bed_step)))
			var ix1 := mini(bw - 1, int(ceil((c.x + rmax - bed_org.x) / bed_step)))
			var iy0 := maxi(0, int(floor((c.y - rmax - bed_org.y) / bed_step)))
			var iy1 := mini(bh - 1, int(ceil((c.y + rmax - bed_org.y) / bed_step)))
			for iy in range(iy0, iy1 + 1):
				var py := bed_org.y + float(iy) * bed_step - c.y
				for ix in range(ix0, ix1 + 1):
					var px := bed_org.x + float(ix) * bed_step - c.x
					var lx := (px * cr + py * sr) / rx
					var ly := (-px * sr + py * cr) / ry
					var d2 := lx * lx + ly * ly
					if d2 >= 1.0:
						continue
					# A hemisphere's normal, so the shading is the stone's shape.
					var nz := sqrt(1.0 - d2)
					var lit := clampf(0.42 + 0.58 * (lx * sx * lam + ly * sy * lam
						+ nz * sin(sun_el)), 0.0, 1.35)
					var rim := smoothstep(1.0, 0.86, d2)      # darkened contact edge
					var j := iy * bw + ix
					bed_r[j] = clampf(sc.r * lit * rim, 0.0, 1.0)
					bed_g[j] = clampf(sc.g * lit * rim, 0.0, 1.0)
					bed_b[j] = clampf(sc.b * lit * rim, 0.0, 1.0)


	func run(s: Dictionary) -> Array:
		var n := gw * gh
		var amps: PackedFloat32Array = s["amps"]
		wf.steep = float(s["steep"])
		wf.set_amps(amps)

		hh.fill(0.0)
		gxx.fill(0.0)
		gyy.fill(0.0)
		jzz.fill(1.0)
		wf.sweep(float(s["t"]), org, step, gw, gh, hh, gxx, gyy, jzz)
		var rings: Array = s["rings"]
		WaveField.sweep_rings(rings, org, step, gw, gh, hh, gxx, gyy, jzz)

		acc.fill(0.0)
		var total := _cast()
		_blur()
		# Normalize so the average wet node receives 1.0: the net is a contrast about that mean,
		# so a shallow pool and a deep one read equally.
		var norm := float(wet_nodes) / maxf(0.0001, total)

		var cell: float = s["cell"]
		if cell != pts_cell:
			_build_mesh(cell)
		var cols := PackedColorArray()
		cols.resize(n + (gw - 1) * (gh - 1))     # nodes, then the cross-split cell centers
		_shade(s, norm, cols)
		_centers(cols)
		return [{"pts": pts, "cols": cols, "idx": idx}]


	## Refract the sun through every node's surface normal and splat where it lands on the
	## bed. Returns the total energy launched, for the normalization.
	func _cast() -> float:
		var total := 0.0
		var sxv := sun.x
		var syv := sun.y
		var szv := sun.z
		var i := 0
		for iy in gh:
			for ix in gw:
				var d := dep[i]
				if d <= 0.0005:
					i += 1
					continue
				var nx := -gxx[i]
				var ny := -gyy[i]
				var nz := maxf(jzz[i], JZ_FLOOR)
				var inv := 1.0 / sqrt(nx * nx + ny * ny + nz * nz)
				nx *= inv
				ny *= inv
				nz *= inv
				var cosi := nx * sxv + ny * syv + nz * szv
				if cosi <= 0.02:
					i += 1
					continue
				# Snell in vector form, air into water. k2 cannot go negative going into
				# the denser medium, so there is no total internal reflection to handle.
				var k2 := 1.0 - eta * eta * (1.0 - cosi * cosi)
				var fr := eta * cosi - sqrt(maxf(k2, 0.0))
				var tx := -eta * sxv + fr * nx
				var ty := -eta * syv + fr * ny
				var tz := -eta * szv + fr * nz
				if tz >= -0.02:
					i += 1
					continue
				var u := 1.0 - cosi
				var u2 := u * u
				var fres := F0 + (1.0 - F0) * u2 * u2 * u
				var wgt := cosi * (1.0 - fres)
				var travel := (d + hh[i]) / -tz
				# Where the refracted ray lands on the bed, in grid cells: the launch cell plus
				# the lateral travel measured in cells.
				var fx := float(ix) + tx * travel / step
				var fy := float(iy) + ty * travel / step
				# Wrapped, not clamped or dropped: dropping energy leaves a dim band round the
				# frame, piling it at the border a bright one.
				var x0 := int(floor(fx))
				var y0 := int(floor(fy))
				var ax := fx - float(x0)
				var ay := fy - float(y0)
				x0 = x0 % gw
				if x0 < 0:
					x0 += gw
				y0 = y0 % gh
				if y0 < 0:
					y0 += gh
				var x1 := x0 + 1
				if x1 >= gw:
					x1 = 0
				var y1 := y0 + 1
				if y1 >= gh:
					y1 = 0
				var r0 := y0 * gw
				var r1 := y1 * gw
				var w11 := ax * ay
				var w01 := ay - w11
				var w10 := ax - w11
				acc[r0 + x0] += wgt * (1.0 - ax - ay + w11)
				acc[r0 + x1] += wgt * w10
				acc[r1 + x0] += wgt * w01
				acc[r1 + x1] += wgt * w11
				total += wgt
				i += 1
		return total


	## A separable binomial [1 4 6 4 1]/16 pass, wrapped to match the splat (clamping would pile a
	## bright fringe against the border). One pass carries 1.0 cells^2 of variance, twice a
	## [1 2 1] pass, so the net reads as light rather than speckle in half as many passes.
	func _blur() -> void:
		for _p in blur_n:
			for iy in gh:
				var row := iy * gw
				for ix in gw:
					var x1 := ix - 1
					var x2 := ix - 2
					var x3 := ix + 1
					var x4 := ix + 2
					if x1 < 0:
						x1 += gw
					if x2 < 0:
						x2 += gw
					if x3 >= gw:
						x3 -= gw
					if x4 >= gw:
						x4 -= gw
					tmp[row + ix] = 0.0625 * (acc[row + x2] + acc[row + x4]) \
						+ 0.25 * (acc[row + x1] + acc[row + x3]) + 0.375 * acc[row + ix]
			for iy in gh:
				var y1 := iy - 1
				var y2 := iy - 2
				var y3 := iy + 1
				var y4 := iy + 2
				if y1 < 0:
					y1 += gh
				if y2 < 0:
					y2 += gh
				if y3 >= gh:
					y3 -= gh
				if y4 >= gh:
					y4 -= gh
				var row := iy * gw
				var r1 := y1 * gw
				var r2 := y2 * gw
				var r3 := y3 * gw
				var r4 := y4 * gw
				for ix in gw:
					acc[row + ix] = 0.0625 * (tmp[r2 + ix] + tmp[r4 + ix]) \
						+ 0.25 * (tmp[r1 + ix] + tmp[r3 + ix]) + 0.375 * tmp[row + ix]


	## One color per node: the refracted image of the bed, lit by the caustic net,
	## absorbed by the water above it, with the sky and its glare laid over the top.
	func _shade(s: Dictionary, norm: float, cols: PackedColorArray) -> void:
		var water: Color = s["water"]
		var sky: Color = s["sky"]
		var sun_c: Color = s["sun"]
		var amb: float = s["amb"]
		var contrast: float = s["contrast"]
		var sharp: float = s["sharp"]
		var expo: float = s["exposure"]
		var thr: float = s["glare_thr"]
		var gg: float = s["glare_gain"]
		var hx := half_v.x
		var hy := half_v.y
		var hz := half_v.z
		var inv_thr := 1.0 / maxf(0.02, 1.0 - thr)
		var i := 0
		for iy in gh:
			var py := org.y + float(iy) * step
			for ix in gw:
				var px := org.x + float(ix) * step
				var d := dep[i]
				if d <= 0.0005:
					# The dry shelf: bare bed, no tint, no net, lifted a little (dry stone is paler).
					var dc := _bed_rgb(px, py)
					cols[i] = Color(clampf(dc.r * dry_lift, 0.0, 1.0),
						clampf(dc.g * dry_lift, 0.0, 1.0),
						clampf(dc.b * dry_lift, 0.0, 1.0))
					i += 1
					continue
				var nx := -gxx[i]
				var ny := -gyy[i]
				var nz := maxf(jzz[i], JZ_FLOOR)
				var inv := 1.0 / sqrt(nx * nx + ny * ny + nz * nz)
				nx *= inv
				ny *= inv
				nz *= inv

				# The view ray, straight down, refracted through the same normal: the bed we see
				# is not the bed under us, which makes the stones swim.
				var k2 := 1.0 - eta * eta * (1.0 - nz * nz)
				var fr := eta * nz - sqrt(maxf(k2, 0.0))
				var vz := -eta + fr * nz
				var travel := (d + hh[i]) / maxf(0.05, -vz)
				var bc := _bed_rgb(px + fr * nx * travel, py + fr * ny * travel)

				# The caustic, as a contrast about its own mean, optionally sharpened (squaring and
				# blending has the shape of a power at a fifth of the cost).
				var c := 1.0 + contrast * (acc[i] * norm - 1.0)
				if c < 0.0:
					c = 0.0
				c = c + sharp * (c * c - c)
				var lit := (amb + (1.0 - amb) * c) * expo
				var aa := att[i]
				var tr := 1.0 - aa
				var wl := 0.55 + 0.45 * clampf(lit, 0.0, 2.0)

				# Specular: Blinn against a straight-down camera, exponent by repeated
				# squaring so no pow() runs in this loop.
				var sp := nx * hx + ny * hy + nz * hz
				if sp < 0.0:
					sp = 0.0
				for _q in shine_sq:
					sp = sp * sp
				var glare := clampf((sp - thr) * inv_thr, 0.0, 1.0) * gg
				# Fresnel on the view ray: near-normal it is two percent, and only a steep face
				# lifts it, which is when water flashes.
				var uf := 1.0 - nz
				var uf2 := uf * uf
				var refl := F0 + (1.0 - F0) * uf2 * uf2 * uf + glare

				# The shoreline: sand just under the water is darker than sand out of it.
				var wet := 1.0
				if d < wet_band:
					wet = lerpf(0.74, 1.0, clampf(d / maxf(0.0001, wet_band), 0.0, 1.0))

				var rr := bc.r * lit * sun_c.r * tr * wet + water.r * aa * wl + sky.r * refl
				var gg2 := bc.g * lit * sun_c.g * tr * wet + water.g * aa * wl + sky.g * refl
				var bb := bc.b * lit * sun_c.b * tr * wet + water.b * aa * wl + sky.b * refl
				cols[i] = Color(clampf(rr, 0.0, 1.0), clampf(gg2, 0.0, 1.0),
					clampf(bb, 0.0, 1.0))
				i += 1


	## Bilinear read of the baked bed (nearest would make every stone twitch between texels as
	## the refracted lookup moves by a fraction of a texel per frame).
	func _bed_rgb(x: float, y: float) -> Color:
		var fx := clampf((x - bed_org.x) / bed_step, 0.0, float(bw - 1) - 0.001)
		var fy := clampf((y - bed_org.y) / bed_step, 0.0, float(bh - 1) - 0.001)
		var x0 := int(fx)
		var y0 := int(fy)
		var ax := fx - float(x0)
		var ay := fy - float(y0)
		var a := y0 * bw + x0
		var b := a + bw
		var r0 := bed_r[a] + (bed_r[a + 1] - bed_r[a]) * ax
		var r1 := bed_r[b] + (bed_r[b + 1] - bed_r[b]) * ax
		var g0 := bed_g[a] + (bed_g[a + 1] - bed_g[a]) * ax
		var g1 := bed_g[b] + (bed_g[b + 1] - bed_g[b]) * ax
		var b0 := bed_b[a] + (bed_b[a + 1] - bed_b[a]) * ax
		var b1 := bed_b[b] + (bed_b[b + 1] - bed_b[b]) * ax
		return Color(r0 + (r1 - r0) * ay, g0 + (g1 - g0) * ay, b0 + (b1 - b0) * ay)


	## Vertex positions and the index buffer for the node mesh. Built once per frame size, as new
	## arrays (the previous ones may still be on the main thread in a packet being drawn).
	##
	## Cross-split: four triangles about a center vertex, not two about a diagonal, which shades
	## along one line and turns a smooth caustic rib into a herringbone of creases. The center's
	## color is the mean of the four corners, the value bilinear interpolation gives there. One
	## extra vertex and two triangles per cell, still one draw call. The caustic buffer is still
	## accumulated at node resolution, so a rib is one to two cells wide (see blur_n).
	func _build_mesh(cell: float) -> void:
		var cells := (gw - 1) * (gh - 1)
		var p := PackedVector2Array()
		p.resize(gw * gh + cells)
		var ox := -float(gw - 1) * cell * 0.5
		var oy := -float(gh - 1) * cell * 0.5
		var i := 0
		for iy in gh:
			var y := oy + float(iy) * cell
			for ix in gw:
				p[i] = Vector2(ox + float(ix) * cell, y)
				i += 1
		for iy in gh - 1:                      # the cell centers, appended after the nodes
			var y := oy + (float(iy) + 0.5) * cell
			for ix in gw - 1:
				p[i] = Vector2(ox + (float(ix) + 0.5) * cell, y)
				i += 1
		if idx.is_empty():
			var q := PackedInt32Array()
			q.resize(cells * 12)
			var j := 0
			var m := gw * gh
			for iy in gh - 1:
				var row := iy * gw
				var crow := m + iy * (gw - 1)
				for ix in gw - 1:
					var a := row + ix
					var b := a + 1
					var c := a + gw
					var d := c + 1
					var e := crow + ix
					q[j] = a
					q[j + 1] = b
					q[j + 2] = e
					q[j + 3] = b
					q[j + 4] = d
					q[j + 5] = e
					q[j + 6] = d
					q[j + 7] = c
					q[j + 8] = e
					q[j + 9] = c
					q[j + 10] = a
					q[j + 11] = e
					j += 12
			idx = q
		pts = p
		pts_cell = cell


	## The cell-center colors, filled after _shade has written the node colors.
	func _centers(cols: PackedColorArray) -> void:
		var j := gw * gh
		for iy in gh - 1:
			var row := iy * gw
			for ix in gw - 1:
				var a := row + ix
				var b := a + 1
				var c := a + gw
				var d := c + 1
				cols[j] = Color(
					(cols[a].r + cols[b].r + cols[c].r + cols[d].r) * 0.25,
					(cols[a].g + cols[b].g + cols[c].g + cols[d].g) * 0.25,
					(cols[a].b + cols[b].b + cols[c].b + cols[d].b) * 0.25)
				j += 1
