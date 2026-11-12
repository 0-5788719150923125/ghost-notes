extends GhostScene

## Falling sand - a world of matter you never draw, only rule.
##
## A chamber seen straight on, its walls running off every edge. Two to five spouts pour into it and never
## stop: dry sand builds a cone that holds its flank angle until an avalanche runs down the side; water finds
## its level and soaks into what it lands on; oil floats on water; an ember dropped into the oil eats through
## it and leaves ash. On a beat a hatch opens in the floor and the column drains.
##
## Every frame is a state, not a picture: a [Grains] grid where each cell holds one thing, and the
## silhouette comes from local rules (the angle of repose is a slide probability, the avalanche a cone
## steeper than it, the oil film a density comparison, the drainage the absence of a floor).
##
## The seed decides: the chamber (silo, hourglass, stepped ledges, or open sides), grid and wall thickness;
## a two-to-four material subset of [constant Grains.MATTER] with every property sampled from its own range;
## the ember and ash chain (only when a flammable material was drawn); the spouts (column, width, material,
## band, gain, duty cycle); hatches; gravity tilt; a steady draft; the wall strata ramp; a bright or dark air;
## and how long the world has already been running.
##
## The world arrives mid-pour: its clock starts partway through its life (`_job.t_sim`), so each spout's duty
## cycle is wherever it happens to be, and the matter that clock implies is deposited by
## [method Grains.prefill], not simulated (a pre-roll long enough to raise a cone is over a second of CPU).
## Gated by tests/scenes/sand_warm_check.gd.
##
## Audio: each spout owns a fixed band and pours at its gain times that band's level, so pours move against
## each other. A beat on an armed latch opens one floor hatch. `f.movement` past a sampled gate eases gravity
## off vertical by a sampled angle (0.12-0.35 rad, applied as its tangent, the per-step sideways probability).
## `f.flux` scales ember ignition. The tonal center drags every material's hue by a quarter of its strength;
## `f.energy` feeds [method Nonlinear.flare] into emissive materials' value only. Nothing touches grain size.
## Gains are written for measured ranges (`f.energy` rarely passes 0.5, `f.flux` is 0.01-0.05); spout rates
## carry a 0.12 floor so a quiet passage still trickles.
##
## The sim and batching run inside a [FrameForge] job that owns the grid (23000 cells); the scene never
## touches a cell. The sim advances on a [SimClock], not per update() call.

const OVER := 1.12          # the chamber runs this much past the frame's width

## Ceiling on sim ticks handed to one build: caps what several capped update() calls accumulate between
## two drawn frames (pre-warm, Echo jump).
const MAX_PENDING := 8

## The chamber decides what the material does on the way down. A silo is a plain column and one cone; an
## hourglass chokes the pour at a waist and holds a second pile above it; ledges break the fall into
## cascades; open sides let everything walk off, so it never fills. The roll is weighted.
const SHAPE_BAG := ["ledges", "ledges", "ledges", "hourglass", "hourglass", "silo", "open"]

const CHAMBERS := {
	"silo": {"wall": [2, 4], "pillars": [0, 2], "hatch_n": [1, 2], "hatch_w": [0.09, 0.24]},
	"hourglass": {"wall": [2, 3], "waist": [0.44, 0.62], "gap": [0.045, 0.13], "span": [0.16, 0.30],
		"hatch_n": [1, 2], "hatch_w": [0.10, 0.26]},
	"ledges": {"wall": [2, 4], "shelves": [2, 5], "shelf": [0.20, 0.46], "hatch_n": [1, 3],
		"hatch_w": [0.07, 0.19]},
	"open": {"wall": [2, 3], "hatch_n": [1, 3], "hatch_w": [0.08, 0.20]},
}

## What can be poured. Ember, ash and steam arrive only as consequences.
const POURABLE := ["sand", "water", "oil", "salt", "dust"]

## Elevation ramps for the chamber wall, so the stone reads as strata.
const WALL_RAMPS := ["earth", "desert", "alpine", "ocean"]

var _w := 192
var _h := 108
var _cell := 6.0
var _org := Vector2.ZERO
var _clock: SimClock
var _forge := FrameForge.new()
var _job: SandJob
var _spouts: Array = []            # [{x0,x1,mat,band,gain,period,phase,duty}]
var _hatches: Array = []           # [{x0,x1}]
var _hatch_i := 0
var _hatch_gap := 5.0
var _hatch_dwell := 0.6
var _hatch_left := 0.0
var _hatch_arm := 0.0
var _drain_x0 := 0
var _drain_x1 := -1
var _beat_prev := 0.0
var _tilt := 0.0
var _tilt_target := 0.0
var _tilt_mag := 0.2
var _tilt_gate := 0.5
var _tilt_dwell := 3.0
var _tilt_rate := 1.2
var _tilt_left := 0.0
var _tilt_signs: Array = []
var _tilt_i := 0
var _wind := 0.0
var _wind_dir := 1
var _ignite := 0.5
var _glow := 0.0
var _hue_base := 0.1
## Guaranteed separation in value between the air and the mean of the materials falling through it
## (a third of the axis; leaves both ends room to be sampled).
const AIR_CONTRAST := 0.34

var _air_sat := 0.08
var _air_val := 0.9
var _air_hue := 0.5
var _depth := 0.28
var _run_cap := 8
var _ch := Vector2.ZERO


## What this scene can be told ([method GhostScene.choice], [method GhostScene.number]): a storyboard
## entry's `set`, by name; a setting not told is drawn from the seed.
const FIELDS := {
	"chamber": {"label": "Chamber", "type": "choice", "options": "SHAPE_BAG", "default": null,
		"blurb": "The chamber the material falls through: ledges that break the fall into cascades, an hourglass that chokes the pour at a waist, a plain silo, or open sides it walks off."},
	"wall": {"label": "Wall colors", "type": "choice", "options": "WALL_RAMPS", "default": null,
		"blurb": "Which elevation ramp colors the strata of the chamber wall: earth, desert, alpine or ocean."},
	"wall_brightness": {"label": "Wall brightness", "type": "num", "range": [0.30, 0.62], "default": null,
		"blurb": "How bright the colored strata of the chamber wall are."},
	"spouts": {"label": "Spouts", "type": "num", "range": [2, 5], "default": null,
		"blurb": "How many spouts pour material into the chamber from the ceiling."},
	"hatch_gap": {"label": "Hatch gap", "type": "num", "range": [3.5, 10.0], "default": null,
		"blurb": "The fewest seconds between one opening of the floor hatches and the next."},
	"hatch_open": {"label": "Hatch open", "type": "num", "range": [0.35, 1.3], "default": null,
		"blurb": "How many seconds the floor hatches stay open each time they open."},
	"fill": {"label": "Opening fill", "type": "num", "range": [0.10, 0.40], "default": null,
		"blurb": "How full of material the chamber already is when the scene opens."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "swarm"
	framing = "field"
	var sch := Scheme.pick(rng)
	_hue_base = sch.hue
	# The grid stays landscape and modest: the sweep is O(cells) every tick (0.53 us/cell worst case) and past
	# ~25k cells the worker stops keeping up with a 30 Hz clock. 240-300 wide puts a cell at 6.4-8.0 px on a
	# 1920 frame; the per-row activity mask skips settled rows, and a slow build costs a slower pour, not a dropped frame.
	_w = rng.randi_range(240, 300)
	_h = clampi(int(round(float(_w) * rng.randf_range(0.55, 0.60))), 132, 180)
	_run_cap = rng.randi_range(5, 11)
	_depth = rng.randf_range(0.16, 0.36)
	# 20-30 ticks a second: the grid is the quantization, so a slower clock buys back cells.
	_clock = SimClock.new(rng.randf_range(20.0, 30.0), 2)

	# Weighted: the cascading shapes are what this scene is for (matter that runs along a surface, reaches
	# an edge and pours off it).
	var shape := String(choice("chamber", rng))
	var ch: Dictionary = CHAMBERS[shape]
	var thick := _rint(ch["wall"], rng)

	var sim := Grains.new(_w, _h, rng.randi())
	var stone := sim.add("stone", rng)
	sim.wall_id = stone
	sim.floor_h = thick
	sim.spill = shape == "open"

	# --- the matter subset -----------------------------------------------------------
	var bag: Array = POURABLE.duplicate()
	for i in range(bag.size() - 1, 0, -1):          # a seeded shuffle, not a sort
		var j := rng.randi_range(0, i)
		var tmp = bag[i]
		bag[i] = bag[j]
		bag[j] = tmp
	if rng.randf() < 0.8 and bag.find("sand") > 0:  # sand is the scene's name, usually
		var k := bag.find("sand")
		bag[k] = bag[0]
		bag[0] = "sand"
	var pours: Array = []
	for i in mini(rng.randi_range(2, 4), bag.size()):
		pours.append(String(bag[i]))
	var fuelly := false
	for n in pours:
		if Grains.MATTER[String(n)].has("fuel"):
			fuelly = true
	var mats: Array = []
	for n in pours:
		mats.append(String(n))
		sim.add(String(n), rng)
	# Ember and ash exist only as the consequence of a flammable pour, steam only where an ember can reach water.
	if fuelly:
		sim.add("ember", rng)
		sim.add("ash", rng)
		mats.append("ember")
		mats.append("ash")
		if pours.has("water"):
			sim.add("steam", rng)
			mats.append("steam")
	sim.finalize()

	# --- the chamber -----------------------------------------------------------------
	sim.fill_rect(0, 0, _w - 1, thick - 1, stone)
	sim.fill_rect(0, _h - thick, _w - 1, _h - 1, stone)
	if shape != "open":
		sim.fill_rect(0, 0, thick - 1, _h - 1, stone)
		sim.fill_rect(_w - thick, 0, _w - 1, _h - 1, stone)
	match shape:
		"hourglass":
			var wy := int(float(_h) * _rand(ch["waist"], rng))
			var gap := int(float(_w) * _rand(ch["gap"], rng))
			var span := maxi(3, int(float(_h) * _rand(ch["span"], rng)))
			var mouth := int(float(_w) * 0.42)
			for y in range(wy - span, wy + span + 1):
				if y < thick or y >= _h - thick:
					continue
				var u := float(absi(y - wy)) / float(span)
				var half := int(lerpf(float(gap) * 0.5, float(mouth), u * u))
				sim.fill_rect(0, y, _w / 2 - half, y, stone)
				sim.fill_rect(_w / 2 + half, y, _w - 1, y, stone)
		"ledges":
			_cascade(sim, stone, thick, _rint(ch["shelves"], rng), ch, rng)
		"silo":
			for k in _rint(ch["pillars"], rng):
				var px := int(float(_w) * rng.randf_range(0.25, 0.75))
				var py := int(float(_h) * rng.randf_range(0.35, 0.72))
				sim.fill_rect(px, py, px + 1, py + int(float(_h) * rng.randf_range(0.08, 0.20)), stone)

	# Every chamber gets something to spill over: a silo with a few shelves still breaks the pour; an
	# hourglass with a shelf under its waist throws the throat's output sideways. Only the count differs.
	if shape != "ledges":
		var extra := 1 if shape == "open" else rng.randi_range(1, 3)
		if extra > 0:
			_cascade(sim, stone, thick, extra, CHAMBERS["ledges"], rng)

	# Strata: the wall takes its color from an elevation ramp by row, the one place a [Palette] belongs here.
	var ramp := Palette.named(String(choice("wall", rng)), rng)
	var wall_v: float = number("wall_brightness", rng)
	var band := PackedColorArray()
	band.resize(_h)
	for y in _h:
		var c := ramp.at(1.0 - float(y) / float(_h))
		band[y] = Color.from_hsv(c.h, clampf(c.s * 0.75, 0.0, 1.0),
			clampf(c.v * wall_v, 0.0, 1.0))
	sim.wall_band = band

	# --- spouts ----------------------------------------------------------------------
	var ns: int = number("spouts", rng)
	for i in ns:
		var mname := String(pours[i % pours.size()])
		var cx := int(float(_w) * rng.randf_range(0.12, 0.88))
		var half_w := rng.randi_range(0, 2)
		var x0 := clampi(cx - half_w, thick, _w - 1 - thick)
		var x1 := clampi(cx + half_w, thick, _w - 1 - thick)
		# Bands are spread across the spectrum so two spouts cannot pour on one frequency.
		var band_t := clampf((float(i) + 0.5) / float(ns) + rng.randf_range(-0.08, 0.08), 0.0, 1.0)
		_spouts.append({
			"x0": x0, "x1": x1, "y": 0, "mat": sim.id_of(mname), "name": mname,
			"band": band_t, "gain": rng.randf_range(70.0, 240.0),
			"period": rng.randf_range(5.0, 16.0),
			# Phases spread for the same reason, so the chamber does not open and shut as one.
			"phase": fposmod((float(i) + 0.5) / float(ns) + rng.randf_range(-0.12, 0.12), 1.0),
			# Every spout has an off phase: the top of this range stays short of 1, or a lane would never close.
			"duty": rng.randf_range(0.40, 0.92)})
		sim.fill_rect(x0, 0, x1, thick - 1, 0)         # a pipe through the ceiling
	if fuelly:
		# The ignition source is a thin, intermittent spout on the top band, an order of magnitude below a pour.
		var ex := int(float(_w) * rng.randf_range(0.18, 0.82))
		var ex0 := clampi(ex, thick, _w - 1 - thick)
		_spouts.append({
			"x0": ex0, "x1": ex0, "y": 0, "mat": sim.id_of("ember"), "name": "ember",
			"band": rng.randf_range(0.7, 0.97), "gain": rng.randf_range(4.0, 18.0),
			"period": rng.randf_range(6.0, 18.0), "phase": rng.randf(),
			"duty": rng.randf_range(0.15, 0.45)})
		sim.fill_rect(ex0, 0, ex0, thick - 1, 0)

	# --- hatches, tilt, draft ---------------------------------------------------------
	var nh := _rint(ch["hatch_n"], rng)
	for i in nh:
		var hw := maxi(2, int(float(_w) * _rand(ch["hatch_w"], rng)))
		var hx := int(float(_w) * rng.randf_range(0.18, 0.82))
		_hatches.append({"x0": maxi(1, hx - hw / 2), "x1": mini(_w - 2, hx + hw / 2)})
	_hatch_gap = number("hatch_gap", rng)
	_hatch_dwell = number("hatch_open", rng)
	# The tilt is sampled as an angle off vertical and applied as its tangent: a cellular gravity can only
	# take a sideways step with some probability, and tan(angle) is that probability.
	_tilt_mag = tan(rng.randf_range(0.12, 0.35))
	_tilt_gate = rng.randf_range(0.34, 0.68)
	_tilt_dwell = rng.randf_range(1.5, 5.0)
	_tilt_rate = 1.0 / rng.randf_range(0.6, 2.0)
	for i in 6:
		_tilt_signs.append(1 if rng.randf() < 0.5 else -1)
	_wind = 0.0 if rng.randf() < 0.35 else rng.randf_range(0.05, 0.30)
	_wind_dir = 1 if rng.randf() < 0.5 else -1
	_ignite = rng.randf_range(0.25, 0.75)

	# --- air ----------------------------------------------------------------------------
	# Chosen against the sand: measure the materials this chamber got, then put the air a guaranteed
	# distance away in value (the axis legibility lives on), and let hue and saturation open up. The hue is
	# the mood's opposed one, so the background separates from the sand in chroma too.
	var sand_v := 0.0
	for m in mats:
		var mv = Grains.MATTER.get(String(m), {}).get("val", [0.5, 0.7])
		sand_v += (float(mv[0]) + float(mv[1])) * 0.5
	sand_v /= maxf(1.0, float(mats.size()))
	# Take the side that has room. Dark is the default (the sand glows out of it, embers read hot), but a
	# chamber of ash and stone has a mean value near 0.2 with no room underneath for a full margin, so the
	# side is chosen by which can pay.
	var room_dark := sand_v - AIR_CONTRAST      # the highest air value the dark side allows
	var room_lit := sand_v + AIR_CONTRAST       # ...and the lowest the lit side allows
	var can_dark := room_dark >= 0.03
	var can_lit := room_lit <= 0.98
	var lit := (rng.randf() < 0.18) if (can_dark and can_lit) else can_lit
	_air_sat = rng.randf_range(0.04, 0.62) if rng.randf() < 0.75 else rng.randf_range(0.0, 0.08)
	_air_hue = sch.opposed(_hue_base)
	if lit:
		_air_val = rng.randf_range(clampf(room_lit, 0.55, 0.97), 0.99)
	else:
		# A saturated background carries more apparent weight, so the deeper the color the further down
		# it sits, taken off the ceiling of the range so the margin stays a guarantee.
		_air_val = rng.randf_range(0.02, maxf(0.03, minf(room_dark, 0.55) - 0.10 * _air_sat))
	if rng.randf() < 0.5:
		add_layer("dust", rng, {"count": rng.randi_range(40, 90), "shaft": false,
			"hue": sch.accent, "alpha": 0.16, "speed": 0.015})

	var acc := PackedFloat32Array()
	acc.resize(_spouts.size())
	_job = SandJob.new()
	_job.g = sim
	_job.dt = _clock.dt
	_job.spouts = _spouts
	_job.acc = acc
	_job.run_cap = _run_cap
	_job.depth = _depth
	_job.wind_dir = _wind_dir

	# --- ARRIVE MID-POUR --------------------------------------------------------------
	# The world has been running before anyone looked. Its clock starts mid-life, so the spouts' duty phases
	# are scattered, and the matter that clock implies is deposited (see Grains.prefill): piles under the
	# spouts and a stream in the air under open lanes.
	_job.t_sim = rng.randf_range(20.0, 400.0)
	# How deep this session arrives. The top of the range is a cost bound: one build (a tick plus a repaint)
	# runs 12 ms on a nearly empty chamber, 26 at a third full and 42 at half, past which the worker cannot
	# keep up with its 20-30 Hz clock.
	var fill: float = number("fill", rng)
	var seeded: Array = []
	for sp in _spouts:
		var d: Dictionary = sp
		var live := fposmod(_job.t_sim / maxf(0.5, float(d["period"])) + float(d["phase"]),
			1.0) < float(d["duty"])
		var span := maxi(1, int(d["x1"]) - int(d["x0"]) + 1)
		seeded.append({
			"x": (int(d["x0"]) + int(d["x1"])) / 2, "x0": int(d["x0"]), "x1": int(d["x1"]),
			"mat": int(d["mat"]), "live": live,
			# How solid the stream is: the rate this spout pours at a middling level, in grains per tick across its width.
			"flow": clampf(float(d["gain"]) * 0.5 * _clock.dt / float(span), 0.15, 1.0),
			"pile": String(d["name"]) != "ember"})
	sim.prefill(seeded, fill, rng)

	return {"chamber": shape, "mood": sch.name, "grid_w": _w, "grid_h": _h,
		"prefill": fill, "start_t": _job.t_sim,
		"materials": mats, "pours": pours, "spouts": _spouts.size(),
		"hatches": nh, "hatch_dwell": _hatch_dwell, "tilt": _tilt_mag,
		"wind": _wind, "wind_dir": _wind_dir, "ignite": _ignite,
		"rate": _clock.rate, "wall": thick, "run_cap": _run_cap,
		"air": "lit" if lit else "dim", "air_val": _air_val,
		"air_sat": _air_sat, "sand_val": sand_v}


func update(f: AudioFeatures, delta: float) -> void:
	tick(f, delta)
	drift_view(f, 0.015, 0.02)
	update_layers(f, delta)
	_ch = chroma_hue()

	# The hatch: a beat on an armed latch, so it opens on the music but cannot chatter on a dense passage.
	_hatch_arm += delta
	var beat_up := f.beat > 0.55 and _beat_prev <= 0.55
	_beat_prev = f.beat
	if _hatch_left > 0.0:
		_hatch_left -= delta
		if _hatch_left <= 0.0:
			_drain_x0 = 0
			_drain_x1 = -1
	elif beat_up and _hatch_arm >= _hatch_gap and not _hatches.is_empty():
		# The which is an index step, never an rng draw (an audio-conditioned draw would desynchronize an export).
		var hh: Dictionary = _hatches[_hatch_i % _hatches.size()]
		_hatch_i += 1
		_hatch_arm = 0.0
		_hatch_left = _hatch_dwell
		_drain_x0 = int(hh["x0"])
		_drain_x1 = int(hh["x1"])

	# Gravity shear on a section change, held for a while and then eased back.
	if _tilt_left > 0.0:
		_tilt_left -= delta
		if _tilt_left <= 0.0:
			_tilt_target = 0.0
	elif f.movement >= _tilt_gate and not _tilt_signs.is_empty():
		_tilt_target = float(_tilt_signs[_tilt_i % _tilt_signs.size()]) * _tilt_mag
		_tilt_i += 1
		_tilt_left = _tilt_dwell
	_tilt = lerpf(_tilt, _tilt_target, 1.0 - exp(-_tilt_rate * delta))

	# Emissive materials brighten with the mix - fast attack, slow release, VALUE only.
	_glow = Nonlinear.flare(_glow, clampf(f.energy * 1.7 + f.beat * 0.35, 0.0, 1.0),
		delta, 7.0, 1.1)

	# Each spout's rate is its own band's level, so the pours move against each other. The 0.12 floor
	# keeps a band that sits near zero from stopping the pour.
	var rates := PackedFloat32Array()
	rates.resize(_spouts.size())
	for i in _spouts.size():
		var sp: Dictionary = _spouts[i]
		var b: float = sp["band"]
		var gain: float = sp["gain"]
		rates[i] = gain * (0.12 + 0.95 * f.sample(b))

	# Sized to overscan both axes, so the chamber runs off the sides and top at any aspect and the camera
	# drift never exposes a corner.
	_cell = maxf(size.x * OVER / float(_w), size.y * OVER / float(_h))
	# The floor sits one cell inside the bottom edge so the drain is visible; the ceiling and side walls run off the frame.
	_org = Vector2(-float(_w) * _cell * 0.5, size.y * 0.5 - _cell - float(_h) * _cell)
	# Blended on the wheel, not the shortest arc (GhostScene.blend_hue): the arc form flips sign at the
	# antipode and swings every material's color by a quarter turn between frames.
	var hue_rot := blend_hue(_hue_base, _ch.x, 0.25 * _ch.y)

	# Everything the audio decides travels in a fresh snapshot dictionary each frame; only the grid and
	# the tick debt live on the job (mutating the job mid-build would write memory the worker is reading).
	_job.pending = mini(_job.pending + _clock.ticks(delta), MAX_PENDING)
	_forge.kick(_job.run, {
		"rate": rates,
		"tilt": _tilt,
		# The draft breathes on its own slow clock: weather in the chamber, not a reaction.
		"wind": _wind * (0.7 + 0.45 * mod.unit("draft")),
		"ignite": clampf(_ignite * (0.35 + 8.0 * f.flux), 0.0, 1.0),
		"glow": _glow,
		"hue_rot": hue_rot,
		"drain_x0": _drain_x0,
		"drain_x1": _drain_x1,
		"org": _org,
		"cell": _cell,
	}, self, _job)
	queue_redraw()


func _draw() -> void:
	begin_draw()
	# Flat and full-bleed: a gradient would light the pile like a spotlight. Layer's `bed` cannot do this.
	paint_ground(_air_hue, _air_sat, _air_val, _ch.y * 0.5, _ch.x)
	draw_layers("back")
	_forge.submit(self)          # the whole chamber: simulated AND batched off-thread
	draw_layers("front")


func _rand(v, rng: RandomNumberGenerator) -> float:
	var a: Array = v
	return rng.randf_range(float(a[0]), float(a[1]))


func _rint(v, rng: RandomNumberGenerator) -> int:
	var a: Array = v
	return rng.randi_range(int(a[0]), int(a[1]))


## The off-thread job (the [FrameForge] job-object form): it owns the grid, runs the simulation and batches
## the result on the worker. The scene never reads a cell, so a Director cut can free the scene mid-build.
## Pending ticks accumulate here rather than in the forge's snapshot because kick() keeps only the newest
## snapshot, which would discard ticks from the Director's several update() calls per frame.
class SandJob:
	extends RefCounted

	var g: Grains
	var spouts: Array = []       # immutable after build - safe to read from the worker
	var acc := PackedFloat32Array()
	var pending := 0
	var dt := 1.0 / 25.0
	var t_sim := 0.0
	var wind_dir := 1
	var depth := 0.28
	var run_cap := 8

	func run(s: Dictionary) -> Array:
		var n := pending
		pending -= n          # consume; a concurrent increment losing a race costs one tick
		var rate: PackedFloat32Array = s["rate"]
		g.tilt = float(s["tilt"])
		g.wind = float(s["wind"])
		g.wind_dir = wind_dir
		g.ignite = float(s["ignite"])
		g.set_drain(int(s["drain_x0"]), int(s["drain_x1"]))
		for k in n:
			t_sim += dt
			for si in mini(spouts.size(), rate.size()):
				var sp: Dictionary = spouts[si]
				# The duty cycle runs on the sim clock, so a spout's phase belongs to the world, not the frame rate.
				var period: float = sp["period"]
				var duty: float = sp["duty"]
				var phase: float = sp["phase"]
				if fposmod(t_sim / maxf(0.5, period) + phase, 1.0) >= duty:
					continue
				acc[si] += rate[si] * dt
				var cnt := int(acc[si])
				if cnt <= 0:
					continue
				acc[si] -= float(cnt)
				g.emit(int(sp["x0"]), int(sp["x1"]), int(sp["y"]), int(sp["mat"]),
					mini(cnt, 32), si)
			g.step()
		var tb := TriBatch.new()
		var org: Vector2 = s["org"]
		g.paint(tb, org, float(s["cell"]), run_cap, float(s["hue_rot"]),
			float(s["glow"]), depth)
		return [{"pts": tb.pts, "cols": tb.cols, "idx": tb.idx}]


## Sloped shelves, alternating sides, for the material to run along and pour off. A flat shelf heaps and
## spills off both ends; a sloped one is a chute, so the grains leave at one known edge in a stream (the
## waterfall). The slope is one cell of drop per `run` cells, built as a staircase (the grid has no other
## way), each step a small lip that keeps the stream lively.
func _cascade(sim, stone: int, thick: int, count: int, ch: Dictionary,
		rng: RandomNumberGenerator) -> void:
	if count <= 0:
		return
	for k in count:
		# Spread down the chamber, avoiding the very top and the floor (the bottom pile wants room).
		var ly := int(float(_h) * (0.24 + 0.54 * (float(k) + 0.5) / float(count)))
		var ln := maxi(6, int(float(_w) * _rand(ch["shelf"], rng)))
		var left := (k % 2) == 0
		# A shallow slope: steep enough that the sand runs, shallow enough that it piles a little, so the stream pulses.
		var run := rng.randi_range(4, 9)
		var thickness := rng.randi_range(1, 2)
		for i in ln:
			var x := (thick + i) if left else (_w - 1 - thick - i)
			if x < thick or x > _w - 1 - thick:
				continue
			var y := ly + int(i / run)
			if y >= _h - thick - 2:
				break
			sim.fill_rect(x, y, x, y + thickness, stone)
