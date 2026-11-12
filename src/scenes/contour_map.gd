extends GhostScene

## Contour map - the terrain from directly above, as a printed survey sheet.
##
## Warm paper with thin dark isolines at a fixed interval; every fifth is a heavier index contour, the band
## above the inked index line is hatched, a graticule and scale bar frame the margins, and survey crosses sit
## on local summits with a leader to a two-glyph label in an invented script. A sweep plants marks and clears
## them when it comes round again. The land evolves everywhere at different rates ([method _step_tectonics]),
## unlike a window move, which shifts every line by the same vector (tests/scenes/contour_flow_check.gd).
##
## A re-print must not be visible: the sheet is rebuilt a couple of times a second, so the sampling window is
## snapped to its own lattice (the sheet is only translated, see _kick), the hatching pitch is fixed by the
## seed and anchored to the ground ([method Contour.hatch]), and the tonal center is eased (see _ease_audio).
## The contour interval never changes: datum and interval are solved once from the land's elevation range,
## then frozen. Nothing here changes size.
##
## The music moves: the inked index contour (`chroma_hue().x`); the hatching's ink density (`f.flux` x 12);
## the sweep (one sheet width per `f.beat_period` x a sampled [8,32] beats; a `f.beat` rising edge stamps a
## survey cross at the summit nearest it); the window (`f.movement` over a sampled threshold eases the offset
## to the next entry of a pre-rolled ring over 14 to 30 s, with a floor `_warp_gap` of 35 to 75 s); the
## annotation alpha (`f.high`); the paper tint (`f.energy`).
##
## The sheet is re-extracted on a sampled [0.3, 1.0] s cadence inside a [FrameForge] job (synchronous in an
## export) and the packet re-submitted every frame. The grid is about 128 samples across; two rounds of
## Chaikin cutting in [Contour] plus a simplify pass make it draw like a pen, which is why the window must be
## snapped. The paper is painted by [method GhostScene.paint_ground] (`fill_aa` would stroke a hairline on the
## frame edge); the margin is painted back over the contours as the neatline.
##
## The land, ladder, palette, alphabet and warp ring are seed-derived and reproduce exactly; which summits get
## marked and when does not (live and offline beat streams differ). No rng is drawn on an audio event.

## How far past the frame the sampled sheet extends, for camera-drift headroom.
const SHEET := 1.22

## Overdraw for the margin cover; it must never expose a corner.
const OVER := 1.22

## The hatch march, in grid cells. Every run end is refined by bisection inside
## [method Contour.hatch], so band edges land on the contour.
const HATCH_MARCH := 0.5

## Simplify tolerance in pixels, after smoothing; a third of a pixel is below what the feather can show.
const SIMPLIFY_PX := 0.35

## The land: fbm is rolling hills, ridged a mountain chain, billow dunes, cells a plateau of scarps.
const KINDS := ["fbm", "fbm", "ridged", "billow", "cells"]

var _forge: FrameForge
# The warp the packet currently on screen was built at. Live drawing is placed against this, and the
# packet is translated by the difference to the live warp (see _draw), so marks and contours move together.
# It must be the warp of the packet on screen, not of the newest build: it is read off
# [method FrameForge.packet_source], which is swapped with the packet in one assignment on one thread.
var _pkt_warp := Vector2.ZERO
var _pkt_valid := false
var _sim := SimClock.new(60.0)
var _tb := TriBatch.new()
var _prng := RandomNumberGenerator.new()
var _fld: Field
var _sch: Scheme
var _gs: GlyphSet
var _f: AudioFeatures = AudioFeatures.new()
# The tonal center, eased as a vector (a hue is circular). Everything color on this sheet reads this
# rather than `chroma_hue()`: the highlighted contour's ink is baked into a packet rebuilt a couple of
# times a second, so a jittery center would arrive as a step.
var _ch := Vector2.ZERO
var _ch_v := Vector2.ZERO
var _ch_raw := Vector2.ZERO
var _ch_seeded := false
## Seconds for the tonal center and the flux to close most of the way onto a new value; 4 s keeps the inked
## contour's color step across one re-print under 0.05 (contour_flow_check; 2.5 s gave 0.076).
const EASE_SECS := 4.0
# Flux, eased for the same reason: it sets the hatching's ink density, which is in the packet.
var _flux_e := 0.0

# The sampled definition, unpacked into fields the per-frame code reads without a Dictionary lookup.
var _res := 128
var _levels := 14
var _index_every := 5
var _index_phase := 0
var _w_minor := 1.1
var _w_index := 2.4
var _w_pick := 3.2
var _span := 2.0
var _blueprint := false
var _paper_h := 0.09
var _paper_s := 0.07
var _paper_v := 0.92
var _ink_h := 0.08
var _ink_s := 0.30
var _ink_v := 0.16
var _tint := 0.30
var _hatch_deg := 45.0
var _hatch_sp := 8.0
var _hatch_on := true
var _sea_frac := 0.18
var _water := true
var _divs := 10
var _grat_every := 5
var _marks_max := 7
var _cadence := 0.5
var _plate := false
var _plate_px := 1.2
var _sweep_beats := 16.0
var _sweep_trail := 0.10
var _mv_thr := 0.35
var _warp_secs := 9.0
var _warp_gap := 45.0
var _margin := 0.05
var _grat_lo := 0.35
var _grat_hi := 0.85
var _smooth := 2
var _cross_r := 0.010
var _leader := 0.030
var _shelf := 0.028
var _scale_cells := 4
var _scale_w := 0.16

# The elevation ladder, solved once from the land and then frozen (see the header).
var _lo := 0.1
var _step_v := 0.06
var _sea := 0.2
var _ladder := false

# State.
var _ring := PackedVector2Array()
var _ring_i := 0
var _warp_a := Vector2.ZERO
var _warp_b := Vector2.ZERO
var _warp_t := 1.0
var _warp_idle := 0.0               # seconds since the window last moved (see _step)
## The land's own evolution: a small spectral basis of traveling waves in field coordinates off one clock
## (see [method _step_tectonics] and [SheetJob]). Uplift adds elevation; drift displaces the point the land
## is read at. Flat arrays, because they cross onto a worker; units are the picture's: a wavelength is a
## fraction of the sheet's width, an uplift amplitude a contour interval, a drift amplitude a fraction of the sheet.
var _up_kx := PackedFloat32Array()   # wavevector, radians per sheet width
var _up_ky := PackedFloat32Array()
var _up_w := PackedFloat32Array()    # radians per second, either sign
var _up_ph := PackedFloat32Array()
var _up_a := PackedFloat32Array()    # weight, normalized so sum(a * |w|) == 1
var _dr_kx := PackedFloat32Array()
var _dr_ky := PackedFloat32Array()
var _dr_w := PackedFloat32Array()
var _dr_ph := PackedFloat32Array()
var _dr_a := PackedFloat32Array()
var _dr_dx := PackedFloat32Array()   # which way this wave pushes the ground
var _dr_dy := PackedFloat32Array()
## The budget: how far the land may move in one re-print, worst case. See [method _step_tectonics].
var _up_print := 0.04                # contour intervals
var _dr_print := 0.0006              # sheet widths
## The tectonic clock. The fields are a pure function of it, so two builds at the same instant are the same sheet.
var _tect_t := 0.0
## The land's mean relief across one grid cell, measured once and frozen. The uplift is limited
## against it - see [method SheetJob.run].
var _grad_cell := 0.01
var _sites: Array = []              # {n: Vector2, h: float, g: PackedInt32Array}
var _site_key := Vector2.ZERO
var _marks: Array = []              # {i: int, age: float, side: float}
var _ext_t := 999.0
var _sweep_p := 0.0
var _sweep_prev := 0.0
var _prev_beat := 0.0
var _prev_mv := 0.0
var _pick := 0
var _pick_k := 0.0          # the highlight's position on the index ladder, eased
var _pick_seeded := false
var _pick_level := 0        # the committed index line, moved only past a hysteresis band

# The label pass: anchors collected while the paperwork is drawn, flushed as one textured triangle
# array afterwards (the ramp-texture path [GlyphSet] bakes for).
var _lab: Array = []
var _lpts := PackedVector2Array()
var _lcols := PackedColorArray()
var _luvs := PackedVector2Array()
var _lidx := PackedInt32Array()


## What this scene can be told ([method GhostScene.choice], [method GhostScene.number]): a storyboard
## entry's `set`, by name; a setting not told is drawn from the seed.
const FIELDS := {
	"land": {"label": "Land", "type": "choice", "options": "KINDS", "default": null,
		"blurb": "What kind of land the map shows: rolling hills (fbm), a ridged mountain chain, dunes (billow), or a fractured plateau of scarps (cells)."},
	"span": {"label": "Span", "type": "num", "range": [1.1, 2.6], "default": null,
		"blurb": "How wide a stretch of land the map sheet shows."},
	"levels": {"label": "Contour lines", "type": "num", "range": [8, 22], "default": null,
		"blurb": "How many contour lines are drawn across the land."},
	"index_every": {"label": "Index spacing", "type": "num", "range": [4, 6], "default": null,
		"blurb": "How many contour lines apart the heavier index lines fall."},
	"hatch": {"label": "Hatch spacing", "type": "num", "range": [4.0, 12.0], "default": null,
		"blurb": "How far apart the hatching lines are drawn."},
	"sea_level": {"label": "Sea level", "type": "num", "range": [0.0, 0.35], "default": null,
		"blurb": "How much of the low ground lies under the sea, when the map has water."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "canvas"
	framing = "field"
	_forge = FrameForge.new()
	_prng.seed = rng.randi()
	_sch = Scheme.pick(rng)

	var kind := String(choice("land", rng))
	var oct := rng.randi_range(3, 6)
	var freq := rng.randf_range(1.2, 3.4)
	_fld = Field.make(kind, rng.randi(), freq, oct)
	# Domain warp on half the sheets: it makes noise look eroded, and costs three noise evaluations
	# per sample instead of one, so it is a coin flip and the grid is sized for the warped case.
	var warp_amt := 0.0
	if rng.randf() < 0.5:
		warp_amt = rng.randf_range(0.08, 0.35)
		_fld = _fld.warp(Field.make("fbm", rng.randi(), freq * 0.45, 2), warp_amt)
	_span = number("span", rng)
	_res = rng.randi_range(112, 144)

	_levels = number("levels", rng)
	_index_every = number("index_every", rng)
	_index_phase = rng.randi_range(0, _index_every - 1)
	_w_minor = rng.randf_range(0.8, 1.6)
	_w_index = rng.randf_range(1.8, 3.2)
	_w_pick = _w_index * rng.randf_range(1.15, 1.5)

	_blueprint = rng.randf() < 0.25
	if _blueprint:
		# The inversion: a cyanotype is light-on-dark. Still a flat full-bleed ground (a vignette reads as a spotlight).
		_paper_h = rng.randf_range(0.55, 0.60)
		_paper_s = rng.randf_range(0.50, 0.72)
		_paper_v = rng.randf_range(0.20, 0.31)
		_ink_h = fposmod(_paper_h + rng.randf_range(-0.04, 0.04), 1.0)
		_ink_s = rng.randf_range(0.04, 0.14)
		_ink_v = rng.randf_range(0.90, 1.0)
	else:
		_paper_h = rng.randf_range(0.06, 0.13)
		_paper_s = rng.randf_range(0.04, 0.12)
		_paper_v = rng.randf_range(0.86, 0.96)
		_ink_h = _sch.vary(rng, 0.6)
		_ink_s = clampf(_sch.sat * rng.randf_range(0.15, 0.50), 0.05, 0.7)
		_ink_v = rng.randf_range(0.10, 0.26)
	_tint = rng.randf_range(0.18, 0.42)

	_hatch_on = rng.randf() < 0.85
	_hatch_deg = rng.randf_range(30.0, 60.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	# One spacing, chosen here and never changed: the ruling is anchored, so changing its pitch
	# slides the whole hatched band. The music is in the ink instead.
	_hatch_sp = number("hatch", rng)

	_water = rng.randf() < 0.7
	_sea_frac = number("sea_level", rng)
	_divs = rng.randi_range(6, 14)
	_grat_every = rng.randi_range(2, 5)
	_marks_max = rng.randi_range(3, 12)
	_cadence = rng.randf_range(0.30, 1.0)
	_plate = rng.randf() < 0.3
	_plate_px = rng.randf_range(0.6, 2.2)
	_sweep_beats = rng.randf_range(8.0, 32.0)
	_sweep_trail = rng.randf_range(0.05, 0.18)
	# Movement is a section-change score that spends most of a track low: a threshold near 0.5 rewarps
	# only at real changes, near 0.2 keeps the land always moving.
	_mv_thr = rng.randf_range(0.20, 0.50)
	# ... and slower, for the same reason.
	_warp_secs = rng.randf_range(14.0, 30.0)
	# The floor under the section-change trigger: however quiet the track, the window travels at least this often.
	_warp_gap = rng.randf_range(35.0, 75.0)
	_margin = rng.randf_range(0.030, 0.075)
	_grat_lo = rng.randf_range(0.22, 0.45)
	_grat_hi = minf(1.0, _grat_lo + rng.randf_range(0.25, 0.50))
	_smooth = rng.randi_range(1, 3)
	_cross_r = rng.randf_range(0.008, 0.014)
	_leader = rng.randf_range(0.022, 0.045)
	_shelf = rng.randf_range(0.020, 0.040)
	_scale_cells = rng.randi_range(3, 6)
	_scale_w = rng.randf_range(0.11, 0.20)

	# A small, tight hand: map lettering sits beside the drawing rather than being the subject.
	_gs = GlyphSet.new(rng, {
		"advance": rng.randf_range(0.011, 0.019),
		"aspect": rng.randf_range(1.15, 1.65),
		"weight": rng.randf_range(1.0, 2.0),
		"count": rng.randi_range(14, 26),
	})

	# The ring of warp offsets, in sheet fractions: absolute positions (not accumulated deltas) so the
	# sheet wanders inside a bounded region and the summit table stays valid, and pre-rolled because
	# the change that picks the next is audio-conditioned (an rng draw there would diverge in an export).
	var n_ring := rng.randi_range(4, 9)
	for i in n_ring:
		# Small: two consecutive entries must not be a sheet-width apart, or the map crosses itself in
		# the ease time. The camera's own drift provides the motion.
		_ring.append(Vector2(rng.randf_range(-0.16, 0.16), rng.randf_range(-0.16, 0.16)))
	_warp_a = _ring[0]
	_warp_b = _ring[0]

	# The land's own evolution, seeded: uplift, with wavelengths from a third of the sheet to half again its
	# width, and drift, shorter so it shears the sheet.
	var n_up := rng.randi_range(5, 9)
	var n_dr := rng.randi_range(3, 5)
	_roll_waves(rng, n_up, 0.34, 1.55, rng.randf_range(55.0, 130.0),
		_up_kx, _up_ky, _up_w, _up_ph, _up_a)
	_roll_waves(rng, n_dr, 0.26, 0.80, rng.randf_range(40.0, 95.0),
		_dr_kx, _dr_ky, _dr_w, _dr_ph, _dr_a)
	for i in n_dr:
		# Which way this wave pushes: along its wavevector the field is compressive (a range
		# building), across it pure shear. The angle between the two is sampled.
		var rel := rng.randf_range(0.0, TAU)
		var kn := Vector2(_dr_kx[i], _dr_ky[i]).normalized()
		_dr_dx.append(kn.x * cos(rel) - kn.y * sin(rel))
		_dr_dy.append(kn.x * sin(rel) + kn.y * cos(rel))
	# The budget is per re-print, the unit the viewer sees: the largest step any line can take between
	# two frames of the sheet. A twentieth of an interval is a line creeping by a pixel.
	_up_print = rng.randf_range(0.026, 0.033)
	_dr_print = rng.randf_range(0.00036, 0.00046)

	return {
		"land": kind,
		"octaves": oct,
		"freq": freq,
		"warp": warp_amt,
		"span": _span,
		"grid": _res,
		"levels": _levels,
		"index_every": _index_every,
		"width_minor": _w_minor,
		"width_index": _w_index,
		"sheet": "blueprint" if _blueprint else "paper",
		"mood": _sch.name,
		"paper_hue": _paper_h,
		"paper_val": _paper_v,
		"ink_hue": _ink_h,
		"ink_sat": _ink_s,
		"hatch": _hatch_on,
		"hatch_deg": _hatch_deg,
		"hatch_px": _hatch_sp,
		"water": _water,
		"sea_frac": _sea_frac,
		"graticule": _divs,
		"margin": _margin,
		"marks": _marks_max,
		"cadence": _cadence,
		"second_plate": _plate,
		"sweep_beats": _sweep_beats,
		"move_threshold": _mv_thr,
		"warp_seconds": _warp_secs,
		"smooth": _smooth,
		"alphabet": _gs.count(),
		"warp_ring": n_ring,
		"uplift_waves": n_up,
		"drift_waves": n_dr,
		"uplift_per_print": _up_print,
		"drift_per_print": _dr_print,
	}


func update(f: AudioFeatures, delta: float) -> void:
	_f = f
	tick(f, delta)
	# A printed sheet barely moves: it is read, not flown over.
	drift_view(f, 0.02, 0.02)
	update_layers(f, delta)
	queue_redraw()
	if size.x < 4.0:
		return
	_ensure_sites()
	# Read once a frame (the signature behind this is a real cost) and eased on the fixed clock in _ease_audio.
	_ch_raw = chroma_hue()
	if not _ch_seeded:
		_ch_seeded = true
		_ch = _ch_raw
		_ch_v = Vector2(cos(_ch.x * TAU), sin(_ch.x * TAU)) * _ch.y
		_flux_e = f.flux
	# Events, not integration: an edge stays one edge however many times the Director substeps.
	if f.beat > 0.55 and _prev_beat <= 0.55:
		_stamp()
	_prev_beat = f.beat
	if f.movement > _mv_thr and _prev_mv <= _mv_thr:
		_rewarp()
	_prev_mv = f.movement
	for _i in _sim.ticks(delta):
		_step(_sim.dt)


# Everything that integrates time runs here, on the fixed clock: the warp ease, the sweep, the marks'
# fade and the re-extraction cadence (the Director substeps, pre-warms and fast-forwards, so a per-update() sweep would run away).
func _step(dt: float) -> void:
	_ease_audio(dt)
	# The highlight migrates on the fixed clock, not from update().
	_pick_index(dt)
	if _warp_t < 1.0:
		_warp_t = minf(1.0, _warp_t + dt / maxf(0.5, _warp_secs))
		_warp_idle = 0.0
	else:
		# The window may not stall forever: a narration take barely moves the `f.movement` score, so a
		# floor under the section-change trigger, on the same slow ease, makes the map eventually travel.
		_warp_idle += dt
		if _warp_idle >= _warp_gap:
			_rewarp()
	_step_tectonics(dt)
	var period := maxf(2.0, clampf(_f.beat_period, 0.25, 1.6) * _sweep_beats)
	_sweep_prev = _sweep_p
	_sweep_p = fposmod(_sweep_p + dt / period, 1.0)
	_age(dt)
	_ext_t += dt
	if _ext_t >= _cadence:
		_ext_t = 0.0
		_kick()


# Close the eased audio onto its raw reading. Both quantities end up inside a packet rebuilt on the
# extraction cadence, so they are eased here to keep a re-print from stepping them.
func _ease_audio(dt: float) -> void:
	var k := 1.0 - exp(-dt / maxf(0.05, EASE_SECS))
	var raw := _ch_raw
	# On the wheel: the hue is an angle and its strength the vector's length, so a tonal center with
	# no answer shrinks toward the middle instead of racing round the rim.
	_ch_v = _ch_v.lerp(Vector2(cos(raw.x * TAU), sin(raw.x * TAU)) * raw.y, k)
	if _ch_v.length() > 0.0001:
		_ch = Vector2(fposmod(_ch_v.angle() / TAU, 1.0), clampf(_ch_v.length(), 0.0, 1.0))
	else:
		_ch = Vector2(_ch.x, 0.0)
	_flux_e = lerpf(_flux_e, _f.flux, k)


# ---------------------------------------------------------------------------------
# The land: the datum, the summit table, and the warp
# ---------------------------------------------------------------------------------

# Sample a coarse grid over the whole region the sheet can wander across and take two things that
# are then fixed for the session: the elevation ladder (datum and interval, solved from the observed
# range) and the summit table. It runs here, not in build_params, because both need the frame's
# aspect and size is zero until the scene is in the tree. Once only.
func _ensure_sites() -> void:
	var key := Vector2(size.x, size.y)
	if not _sites.is_empty() and key.distance_to(_site_key) < 8.0:
		return
	_site_key = key
	_sites.clear()
	_marks.clear()
	var fspan := _fspan()
	# The sheet occupies -0.5..0.5 and the warp ring reaches 0.55, so the table covers more. Read without
	# the tectonics, deliberately: the ladder and summit table are fixed.
	var dom := 1.20
	var nx := 56
	var ny := 36
	var h := PackedFloat32Array()
	h.resize(nx * ny)
	var lo := 1.0
	var hi := 0.0
	for y in ny:
		var qy := (float(y) / float(ny - 1) - 0.5) * 2.0 * dom * fspan.y
		for x in nx:
			var qx := (float(x) / float(nx - 1) - 0.5) * 2.0 * dom * fspan.x
			var v := _fld.at(Vector2(qx, qy))
			h[y * nx + x] = v
			lo = minf(lo, v)
			hi = maxf(hi, v)
	# The ladder: pulled a little inside the observed range so the top and bottom levels are not
	# single specks, then the span is divided evenly. Never touched again.
	var pad := (hi - lo) * 0.06
	var d_lo := lo + pad
	var d_hi := maxf(d_lo + 0.02, hi - pad)
	_step_v = (d_hi - d_lo) / float(_levels + 1)
	_lo = d_lo + _step_v
	_sea = d_lo + _sea_frac * (d_hi - d_lo)
	_ladder = true
	_measure_relief(fspan)

	# Summits: strict local maxima of the coarse grid, tallest first, stored in sheet fractions of
	# the continent, so tracking one under a warp is a subtraction.
	var found: Array = []
	for y in range(1, ny - 1):
		for x in range(1, nx - 1):
			var v := h[y * nx + x]
			if v < d_lo + (d_hi - d_lo) * 0.45:
				continue
			var top := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if (dx != 0 or dy != 0) and h[(y + dy) * nx + x + dx] >= v:
						top = false
			if not top:
				continue
			found.append({
				"n": Vector2(float(x) / float(nx - 1) - 0.5, float(y) / float(ny - 1) - 0.5) * 2.0 * dom,
				"h": v,
			})
	found.sort_custom(func(a, b): return float(a["h"]) > float(b["h"]))
	var cap := mini(found.size(), 48)
	for i in cap:
		var e: Dictionary = found[i]
		var g := PackedInt32Array()
		# Every station is named once from the build rng, so a peak carries the same two characters every time.
		g.append(_prng.randi() % maxi(1, _gs.count()))
		g.append(_prng.randi() % maxi(1, _gs.count()))
		e["g"] = g
		_sites.append(e)


## Measure the land's mean relief across one grid cell, once, and freeze it. The uplift is limited against it
## in [method SheetJob.run]: a contour moves by `dv / |grad v|`, so the same elevation change that is
## invisible on a scarp sends a line across a basin. Measured at the sheet's own pitch (relief is a fractal)
## over sixteen small patches; frozen, since anything the limit depends on that changed with the window
## would perturb every sample.
func _measure_relief(fspan: Vector2) -> void:
	var cs := fspan.x / float(maxi(2, _res) - 1)      # one grid cell, in field units
	var pn := 10
	var h := PackedFloat32Array()
	h.resize(pn * pn)
	var acc := 0.0
	var cnt := 0
	for py in 4:
		for px in 4:
			var o := Vector2(float(px) - 1.5, float(py) - 1.5) * 0.62 * fspan
			for y in pn:
				for x in pn:
					h[y * pn + x] = _fld.at(o + Vector2(float(x) - 4.5, float(y) - 4.5) * cs)
			for y in range(1, pn - 1):
				for x in range(1, pn - 1):
					var i := y * pn + x
					var gx := (h[i + 1] - h[i - 1]) * 0.5
					var gy := (h[i + pn] - h[i - pn]) * 0.5
					acc += sqrt(gx * gx + gy * gy)
					cnt += 1
	_grad_cell = maxf(1e-6, acc / float(maxi(1, cnt)))


## Take the warp offset of the build whose packet is currently on screen. Call it after the forge
## has flushed (in an export the build happens inside the draw).
func _adopt_packet_warp() -> void:
	var job := _forge.packet_source() as SheetJob
	if job != null:
		_pkt_warp = job.warp
		_pkt_valid = true


func _warp_now() -> Vector2:
	var t := clampf(_warp_t, 0.0, 1.0)
	return _warp_a.lerp(_warp_b, t * t * (3.0 - 2.0 * t))


# A section change eases the window to the next pre-rolled position. A change arriving mid-flight is
# ignored rather than restarting the move.
func _rewarp() -> void:
	if _warp_t < 1.0 or _ring.is_empty():
		return
	_warp_a = _warp_b
	_ring_i = (_ring_i + 1) % _ring.size()
	_warp_b = _ring[_ring_i]
	_warp_t = 0.0
	_warp_idle = 0.0


## The land's own evolution: a summed spectral basis in field coordinates (five to nine traveling waves
## for uplift, three to five for drift), `d(q, t) = sum_i a_i sin(k_i . q + w_i t + phi_i)`. Nowhere is
## pinned: crests, troughs and nodes move across the sheet at different speeds.
##
##   Rate budget: what reads as jumpy is how far the land moves between two prints (cadence [0.3, 1.0] s).
##   The seed sets `_up_print`, the elevation in contour intervals the land may travel in one re-print,
##   worst case over the basis; the per-second rate is that divided by the cadence.
##   Anchored to the land: waves are functions of the field coordinate, so the window's lattice snap holds
##   (after a one-cell window move, grid point (x, y) reads what (x-1, y) read; contour_flow_check).
##   Pure in time: both fields are a function of `_tect_t`, so pre-warm, Echo fast-forward and export
##   reach the same sheet as a live session. No audio touches it.
##
## Drift displaces the point the land is read at, so ridges wander and contours crowd; it is bounded in
## pixels rather than elevation, since a line displaced by d moves by exactly d.
func _step_tectonics(dt: float) -> void:
	_tect_t += dt


## Roll one spectral basis into the arrays given. Wavelengths are sheet widths, periods scale with
## wavelength, amplitudes follow a red spectrum, and the set is normalized so `sum(a * |w|) == 1`:
## multiplying the weights by a rate moves the basis at that rate ([method _step_tectonics]'s budget).
func _roll_waves(rng: RandomNumberGenerator, n: int, lam_lo: float, lam_hi: float,
		period: float, kx: PackedFloat32Array, ky: PackedFloat32Array,
		w: PackedFloat32Array, ph: PackedFloat32Array, a: PackedFloat32Array) -> void:
	var norm := 0.0
	for i in n:
		var lam := rng.randf_range(lam_lo, lam_hi)
		var ang := rng.randf_range(0.0, TAU)
		var k := TAU / maxf(0.05, lam)
		kx.append(cos(ang) * k)
		ky.append(sin(ang) * k)
		# Period jitter keeps the basis from beating (exact period ratios would loop the sheet).
		var t_i := maxf(6.0, period * lam * rng.randf_range(0.72, 1.38))
		var om := TAU / t_i
		w.append(om if rng.randf() < 0.5 else -om)
		ph.append(rng.randf_range(0.0, TAU))
		a.append(lam)
		norm += lam * om
	if norm <= 1e-9:
		return
	for i in n:
		a[a.size() - n + i] = a[a.size() - n + i] / norm


## The sheet's extent in field units; the extraction, summit table and tectonics must agree on it.
func _fspan() -> Vector2:
	var u := maxf(1.0, unit())
	return Vector2(size.x, size.y) * (SHEET * _span / u)


func _site_pos(i: int) -> Vector2:
	var d: Dictionary = _sites[i]
	var n: Vector2 = d["n"]
	var o := _warp_now()
	return Vector2((n.x - o.x) * size.x * SHEET, (n.y - o.y) * size.y * SHEET)


# ---------------------------------------------------------------------------------
# The audio: which contour is inked, and the survey marks
# ---------------------------------------------------------------------------------

# The harmony picks an altitude and the highlight migrates there at a bounded rate, one index line at a
# time to an adjacent elevation: an instant re-pick would relight every loop of that elevation at once, and
# hue is circular where the ladder is not.
## Index lines per second the highlight may travel (four seconds per line). Slow, so a fleeting harmonic
## wobble never completes the trip.
const PICK_RATE := 0.25

func _pick_index(dt: float) -> void:
	var first := posmod(-_index_phase, _index_every)
	var n := 0
	var k := first
	while k < _levels:
		n += 1
		k += _index_every
	if n <= 0:
		_pick = _levels / 2
		return
	var t := _ch.x if _ch.y > 0.02 else 0.5
	var target := clampf(t * float(n), 0.0, float(n - 1))
	if not _pick_seeded:
		_pick_k = target
		_pick_level = clampi(int(round(target)), 0, n - 1)
		_pick_seeded = true
	else:
		_pick_k = move_toward(_pick_k, target, PICK_RATE * dt)
	# Hysteresis, not rounding: with the target alternating between two levels the eased position
	# hovers near half-way and round() would flip on every micro-crossing. The line only moves once
	# the position has committed three quarters of the way to a neighbor.
	if absf(_pick_k - float(_pick_level)) > 0.75:
		_pick_level = clampi(_pick_level + (1 if _pick_k > float(_pick_level) else -1), 0, n - 1)
	_pick = first + clampi(_pick_level, 0, n - 1) * _index_every


# A beat plants the next station: the summit nearest the sweep line. No rng - a function of the feature stream alone.
func _stamp() -> void:
	if _sites.is_empty() or size.x < 4.0:
		return
	var nl := _neatline()
	var sx := lerpf(-nl.x, nl.x, _sweep_p)
	var best := -1
	var best_d := INF
	for i in _sites.size():
		var p := _site_pos(i)
		if absf(p.x) > nl.x * 0.92 or absf(p.y) > nl.y * 0.86:
			continue
		var taken := false
		for m in _marks:
			var md: Dictionary = m
			if int(md["i"]) == i:
				taken = true
		if taken:
			continue
		var d := absf(p.x - sx)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return
	# The leader leaves on the side with more room, so a label never runs off the sheet.
	var pos := _site_pos(best)
	_marks.append({"i": best, "age": 0.0, "side": -1.0 if pos.y > 0.0 else 1.0})
	while _marks.size() > _marks_max:
		_marks.remove_at(0)


# Marks ink in behind the sweep and are cleared when it comes round again, so the sheet is
# continuously re-surveyed.
func _age(dt: float) -> void:
	if _marks.is_empty():
		return
	var nl := _neatline()
	var span := maxf(1.0, nl.x * 2.0)
	var i := _marks.size() - 1
	while i >= 0:
		var m: Dictionary = _marks[i]
		m["age"] = float(m["age"]) + dt
		var p := _site_pos(int(m["i"]))
		var mx := clampf((p.x + nl.x) / span, 0.0, 1.0)
		var crossed := false
		if _sweep_p >= _sweep_prev:
			crossed = mx > _sweep_prev and mx <= _sweep_p
		else:
			crossed = mx > _sweep_prev or mx <= _sweep_p
		# The age guard stops a mark planted on the line from being erased by the pass that planted it.
		if (crossed and float(m["age"]) > 0.75) or absf(p.x) > nl.x or absf(p.y) > nl.y:
			_marks.remove_at(i)
		i -= 1


# ---------------------------------------------------------------------------------
# The sheet: one worker job per cadence tick
# ---------------------------------------------------------------------------------

func _kick() -> void:
	var job := _make_job()
	if job != null:
		_forge.kick(job.run, {}, self, job)


## The next re-print as a job object, without submitting it. Split out of [method _kick] so a gate can
## build two sheets from two states and compare them (consecutive re-prints must be the same drawing).
func _make_job() -> SheetJob:
	if not _ladder or size.x < 4.0:
		return null
	var nx := _res
	var ny := _res
	# Square-ish cells: a square grid over a 16:9 frame samples twice as finely down as across.
	if size.x >= size.y:
		ny = maxi(24, int(round(float(_res) * size.y / maxf(1.0, size.x))))
	else:
		nx = maxi(24, int(round(float(_res) * size.x / maxf(1.0, size.y))))

	var job := SheetJob.new()
	job.fld = _fld
	job.nx = nx
	job.ny = ny
	job.half = Vector2(size.x, size.y) * 0.5 * SHEET
	job.fspan = _fspan()
	# Snap the window to its own sampling lattice. The land is static, so extractions at the same lattice
	# phase read the same field points and give the same contours, and the sheet only has to be translated
	# (_draw does this exactly). Off the lattice, a half-cell shift wobbles the contours by several pixels.
	# The sub-cell remainder goes into `warp`, which _draw turns into the translation; snapping costs at
	# most half a cell of lag at the leading edge, under the margin.
	var cellf := Vector2(job.fspan.x / float(maxi(2, nx) - 1), job.fspan.y / float(maxi(2, ny) - 1))
	var raw := _warp_now() * job.fspan
	job.off = Vector2(round(raw.x / cellf.x) * cellf.x, round(raw.y / cellf.y) * cellf.y)
	job.warp = Vector2(job.off.x / maxf(0.0001, job.fspan.x), job.off.y / maxf(0.0001, job.fspan.y))
	# The land's evolution as of this print, resolved from sheet units into field units. Wavevectors are
	# radians per sheet width, so dividing by the width in field units anchors every wave to the ground.
	# Weights are normalized (`sum(a |w|) == 1`) and the rate is the per-print budget divided by the cadence.
	var fw := maxf(1e-6, job.fspan.x)
	var up_rate := _up_print * _step_v / maxf(0.05, _cadence)
	for i in _up_a.size():
		job.up_kx.append(_up_kx[i] / fw)
		job.up_ky.append(_up_ky[i] / fw)
		job.up_p.append(_up_ph[i] + _up_w[i] * _tect_t)
		job.up_a.append(_up_a[i] * up_rate)
	var dr_rate := _dr_print * fw / maxf(0.05, _cadence)
	for i in _dr_a.size():
		job.dr_kx.append(_dr_kx[i] / fw)
		job.dr_ky.append(_dr_ky[i] / fw)
		job.dr_p.append(_dr_ph[i] + _dr_w[i] * _tect_t)
		job.dr_ax.append(_dr_a[i] * dr_rate * _dr_dx[i])
		job.dr_ay.append(_dr_a[i] * dr_rate * _dr_dy[i])
	job.relief = _grad_cell
	job.lo = _lo
	job.step = _step_v
	job.count = _levels
	job.index_every = _index_every
	job.index_phase = _index_phase
	job.pick = _pick
	job.smooth_iters = _smooth
	job.simp = SIMPLIFY_PX

	var ink := _ink_color(1.0)
	job.minor_col = Color(ink.r, ink.g, ink.b, 0.72)
	job.index_col = ink
	job.pick_col = _pick_color()
	job.w_minor = _w_minor
	job.w_index = _w_index
	job.w_pick = _w_pick
	job.plate = _plate
	job.plate_off = Vector2(_plate_px, -_plate_px * 0.6)
	var pl := _sch.color(_sch.opposed(_ink_h, 0.30), 0.9, 1.0)
	job.plate_col = Color(pl.r, pl.g, pl.b, 0.30)

	job.water = _water
	job.sea = _sea
	job.water_col = _water_color()

	job.hatch_on = _hatch_on
	job.hatch_a = deg_to_rad(_hatch_deg)
	job.hatch_sp = _hatch_sp
	# The music is in the ink, not the pitch. Flux measures 0.01 to 0.05, hence the gain; it is the
	# eased flux because the alpha is baked into the packet.
	job.hatch_col = Color(ink.r, ink.g, ink.b,
		lerpf(0.22, 0.46, clampf(_flux_e * 12.0, 0.0, 1.0)))
	job.hatch_w = maxf(0.7, _w_minor * 0.8)
	job.band_lo = _lo + float(_pick) * _step_v
	job.band_hi = job.band_lo + float(_index_every) * _step_v
	return job


# ---------------------------------------------------------------------------------
# Color
# ---------------------------------------------------------------------------------

func _paper_color() -> Color:
	# The same shift paint_ground performs, so the margin cover and the ground are one white.
	var d := _ch.x - _paper_h
	var h := fposmod(_paper_h + (d - round(d)) * clampf(_tint * _ch.y, 0.0, 1.0) * 0.5, 1.0)
	return Color.from_hsv(h, _paper_s, _paper_v)


func _ink_color(a: float) -> Color:
	return Color.from_hsv(fposmod(_ink_h, 1.0), _ink_s, _ink_v, clampf(a, 0.0, 1.0))


func _pick_color() -> Color:
	# The inked index line takes the accent, pulled toward the tonal center by how tonal the moment is.
	var h := _sch.opposed(_ink_h, 0.22)
	var d := _ch.x - h
	h = fposmod(h + (d - round(d)) * _ch.y * 0.5, 1.0)
	if _blueprint:
		return Color.from_hsv(h, clampf(_ink_s + 0.35, 0.0, 1.0), 1.0, 0.80)
	# 0.80 rather than 0.95: this line is every loop at its elevation, so it covers much of the sheet.
	return Color.from_hsv(h, clampf(_ink_s + 0.40, 0.0, 1.0), clampf(_ink_v + 0.28, 0.0, 0.8), 0.80)


func _water_color() -> Color:
	var h := _sch.opposed(_ink_h, 0.26)
	if _blueprint:
		return Color.from_hsv(h, clampf(_paper_s * 0.6, 0.0, 1.0), clampf(_paper_v + 0.12, 0.0, 1.0), 0.45)
	return Color.from_hsv(h, clampf(_ink_s * 0.9 + 0.10, 0.0, 1.0), 0.90, 0.36)


# The paperwork's ink alpha rides f.high (a band mean that rarely passes 0.5, hence the gain):
# bright passages bring the annotation layer up.
func _paperwork_alpha() -> float:
	return lerpf(_grat_lo, _grat_hi, clampf(_f.high * 2.2, 0.0, 1.0))


func _neatline() -> Vector2:
	var m := _margin * maxf(1.0, unit())
	return Vector2(maxf(20.0, size.x * 0.5 - m), maxf(20.0, size.y * 0.5 - m))


# ---------------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------------

func _draw() -> void:
	begin_draw()
	paint_ground(_paper_h, _paper_s, _paper_v, _tint * _ch.y, _ch.x)
	if size.x < 4.0:
		return
	draw_layers("back")
	# Flush first: in an export the sheet is built here, inside the draw, and the offset must be that build's.
	_forge.flush()
	_adopt_packet_warp()
	# Glide the sheet. The warp is a pure translation of the sampling window, so displaying a packet
	# built at one offset as though built at another is exact except at the strip of new ground at the
	# leading edge, which the next extraction brings in. A re-extraction is a refresh, not a jump.
	var d := _warp_now() - _pkt_warp if _pkt_valid else Vector2.ZERO
	if d != Vector2.ZERO:
		draw_set_transform_matrix(view.matrix(size) * Transform2D(0.0, Vector2.ONE, 0.0,
			Vector2(-d.x * size.x * SHEET, -d.y * size.y * SHEET)))
	_forge.submit(self)          # water, hatching, the plates, every contour
	if d != Vector2.ZERO:
		draw_set_transform_matrix(view.matrix(size))
	_paperwork()
	_labels()
	draw_layers("front")


func _paperwork() -> void:
	_lab.clear()
	var nl := _neatline()
	var u := maxf(1.0, unit())
	var paper := _paper_color()
	var a := _paperwork_alpha()
	var ink := _ink_color(a)
	var hard := _ink_color(minf(1.0, a + 0.15))

	# The sweep, over the land but under the margin, so the neatline clips it.
	var sx := lerpf(-nl.x, nl.x, _sweep_p)
	var wash := _pick_color()
	var trail := maxf(4.0, nl.x * 2.0 * _sweep_trail)
	var x0 := maxf(-nl.x, sx - trail)
	if sx > -nl.x:
		var w0 := Color(wash.r, wash.g, wash.b, 0.0)
		var w1 := Color(wash.r, wash.g, wash.b, 0.10)
		_tb.quad_colored(
			PackedVector2Array([Vector2(x0, -nl.y), Vector2(sx, -nl.y),
				Vector2(sx, nl.y), Vector2(x0, nl.y)]),
			PackedColorArray([w0, w1, w1, w0]))
	_tb.line(Vector2(sx, -nl.y), Vector2(sx, nl.y),
		Color(wash.r, wash.g, wash.b, 0.55), maxf(1.0, _w_index * 0.7), true)

	# The margin, painted back over the land: the neatline, four quads.
	var ov := Vector2(size.x, size.y) * 0.5 * OVER / maxf(0.001, view.zoom_actual())
	_tb.quad(Vector2(-ov.x, -ov.y), Vector2(ov.x, -ov.y),
		Vector2(ov.x, -nl.y), Vector2(-ov.x, -nl.y), paper)
	_tb.quad(Vector2(-ov.x, nl.y), Vector2(ov.x, nl.y),
		Vector2(ov.x, ov.y), Vector2(-ov.x, ov.y), paper)
	_tb.quad(Vector2(-ov.x, -nl.y), Vector2(-nl.x, -nl.y),
		Vector2(-nl.x, nl.y), Vector2(-ov.x, nl.y), paper)
	_tb.quad(Vector2(nl.x, -nl.y), Vector2(ov.x, -nl.y),
		Vector2(ov.x, nl.y), Vector2(nl.x, nl.y), paper)

	Contour.box(_tb, -nl, nl, hard, _w_index * 0.8)
	var minor := u * 0.008
	var major := u * 0.016
	var gw := maxf(0.8, _w_minor)
	Contour.graticule(_tb, Vector2(-nl.x, -nl.y), Vector2(nl.x, -nl.y),
		Vector2(0.0, -1.0), _divs, minor, major, _grat_every, ink, gw)
	Contour.graticule(_tb, Vector2(-nl.x, nl.y), Vector2(nl.x, nl.y),
		Vector2(0.0, 1.0), _divs, minor, major, _grat_every, ink, gw)
	var vdiv := maxi(3, int(round(float(_divs) * size.y / maxf(1.0, size.x))))
	Contour.graticule(_tb, Vector2(-nl.x, -nl.y), Vector2(-nl.x, nl.y),
		Vector2(-1.0, 0.0), vdiv, minor, major, _grat_every, ink, gw)
	Contour.graticule(_tb, Vector2(nl.x, -nl.y), Vector2(nl.x, nl.y),
		Vector2(1.0, 0.0), vdiv, minor, major, _grat_every, ink, gw)

	# The scale bar, on its own patch of paper so it stays legible over hatching.
	var bar_w := nl.x * 2.0 * _scale_w
	var bar_h := u * 0.010
	var org := Vector2(-nl.x + u * 0.030, nl.y - u * 0.040)
	var pad := u * 0.016
	_tb.quad(org + Vector2(-pad, -pad * 1.6), org + Vector2(bar_w + pad, -pad * 1.6),
		org + Vector2(bar_w + pad, bar_h + pad), org + Vector2(-pad, bar_h + pad),
		Color(paper.r, paper.g, paper.b, 0.88))
	Contour.scale_bar(_tb, org, bar_w, _scale_cells, bar_h, hard, paper, gw)
	if _gs != null and _gs.count() > 0:
		var unit_g := PackedInt32Array()
		unit_g.append(0)
		unit_g.append(mini(1, _gs.count() - 1))
		_lab.append({"p": org + Vector2(bar_w + pad * 1.6, bar_h), "g": unit_g, "col": hard})

	# The stations.
	var cr := _cross_r * u
	for m in _marks:
		var md: Dictionary = m
		var p := _site_pos(int(md["i"]))
		var fade := clampf(float(md["age"]) / 0.45, 0.0, 1.0)
		var col := _ink_color(minf(1.0, a + 0.15) * fade)
		Contour.cross(_tb, p, cr, cr * 0.42, col, maxf(1.0, _w_index * 0.7))
		var side: float = md["side"]
		var out := 1.0 if p.x < 0.0 else -1.0
		var anchor := Contour.leader(_tb, p + Vector2(out * cr, side * cr * 0.3),
			Vector2(out, side * 0.85), _leader * u, _shelf * u, col, maxf(0.8, _w_minor))
		var d2: Dictionary = _sites[int(md["i"])]
		var g: PackedInt32Array = d2["g"]
		var lp := anchor + Vector2(0.0, -u * 0.004)
		if out < 0.0:
			lp.x -= _gs.em * u * 2.0 / maxf(0.2, _gs.aspect)
		_lab.append({"p": lp, "g": g, "col": col})

	_tb.flush(self)


# Every label as one textured triangle array: each character is one native transform of its baked
# em-space geometry; the stroke quads carry their own antialiasing in [GlyphSet]'s alpha ramp.
func _labels() -> void:
	if _lab.is_empty() or _gs == null or _gs.count() == 0:
		return
	_lpts.clear()
	_lcols.clear()
	_luvs.clear()
	var sc := _gs.em * maxf(1.0, unit())
	var adv := sc / maxf(0.2, _gs.aspect)
	for e in _lab:
		var d: Dictionary = e
		var p: Vector2 = d["p"]
		var col: Color = d["col"]
		var gi: PackedInt32Array = d["g"]
		var x := p.x
		for k in gi.size():
			var idx := clampi(gi[k], 0, _gs.count() - 1)
			var g: GlyphSet.Glyph = _gs.glyphs[idx]
			if g.verts.size() >= 4:
				var xf := Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2(x, p.y))
				_lpts.append_array(xf * g.verts)
				_luvs.append_array(g.uvs)
				var c := PackedColorArray()
				c.resize(g.verts.size())
				c.fill(col)
				_lcols.append_array(c)
			x += adv
	var quads := _lpts.size() / 4
	if quads <= 0:
		return
	_ensure_idx(quads)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),
		_lidx.slice(0, quads * 6), _lpts, _lcols, _luvs,
		PackedInt32Array(), PackedFloat32Array(), GlyphSet.ramp_texture().get_rid())


# Indices depend only on a quad's ordinal, so one template grown to the high-water mark serves every frame.
func _ensure_idx(quads: int) -> void:
	var have := _lidx.size() / 6
	if quads <= have:
		return
	_lidx.resize(quads * 6)
	for q in range(have, quads):
		var b := q * 4
		var o := q * 6
		_lidx[o] = b
		_lidx[o + 1] = b + 1
		_lidx[o + 2] = b + 2
		_lidx[o + 3] = b
		_lidx[o + 4] = b + 2
		_lidx[o + 5] = b + 3


# ---------------------------------------------------------------------------------
# The worker job: sample the land, extract every level, draw the sheet
# ---------------------------------------------------------------------------------

## One re-print of the sheet, built off the main thread ([FrameForge]'s job form: a fresh object per
## kick). It samples the field, extracts, smooths and simplifies every contour, and returns the
## triangle chunks: water, hatching, the out-of-register plate, minor lines, index lines, the inked one last.
class SheetJob:
	extends RefCounted

	var fld: Field
	var nx := 128
	var ny := 72
	var half := Vector2.ZERO         # the sheet's half extent in pixels
	var fspan := Vector2.ONE         # the same, in field units
	var off := Vector2.ZERO          # the window's position on the continent
	## The warp offset in sheet fractions this packet was built at. Read back off the job through
	## [method FrameForge.packet_source]: the forge keeps one worker and drops most kicked jobs unrun.
	var warp := Vector2.ZERO
	## The land's evolution in field units with the clock folded into the phase, so the worker evaluates a
	## static field (see [method _step_tectonics]). Flat arrays: this crosses onto a worker thread.
	var up_kx := PackedFloat32Array()
	var up_ky := PackedFloat32Array()
	var up_p := PackedFloat32Array()
	var up_a := PackedFloat32Array()
	var dr_kx := PackedFloat32Array()
	var dr_ky := PackedFloat32Array()
	var dr_p := PackedFloat32Array()
	var dr_ax := PackedFloat32Array()
	var dr_ay := PackedFloat32Array()
	## The land's mean relief across one grid cell (see the scene's _measure_relief); the uplift's displacement is limited against it.
	var relief := 0.01
	var lo := 0.1
	var step := 0.06
	var count := 14
	var index_every := 5
	var index_phase := 0
	var pick := 5
	var smooth_iters := 2
	var simp := 0.35
	var minor_col := Color.BLACK
	var index_col := Color.BLACK
	var pick_col := Color.BLACK
	var w_minor := 1.1
	var w_index := 2.4
	var w_pick := 3.2
	var plate := false
	var plate_off := Vector2.ZERO
	var plate_col := Color.TRANSPARENT
	var water := false
	var sea := 0.2
	var water_col := Color.TRANSPARENT
	var hatch_on := true
	var hatch_a := 0.8
	var hatch_sp := 8.0              # pixels
	var hatch_col := Color.TRANSPARENT
	var hatch_w := 1.0
	var band_lo := 0.0
	var band_hi := 0.0

	## How far the uplift may carry a contour from where the base field puts it, in grid cells, before it
	## saturates: a backstop (it does not bind at the shipped budget; the rate budget and slope weighting shape the picture).
	const MAX_SHIFT := 1.0

	## How far below the land's mean relief the limit stops tightening. Without a floor the limit
	## divides by a gradient that goes to zero at every summit and basin floor, freezing the closed rings.
	const RELIEF_FLOOR := 0.35

	## The most the slope weighting may amplify the uplift where the ground is steep.
	const SLOPE_CAP := 1.8

	func run(_s: Dictionary) -> Array:
		var tb := TriBatch.new()
		if nx < 2 or ny < 2 or count <= 0:
			return tb.take_chunks()
		return _draw_sheet(sample(), tb)


	## The land this print is of: the field read at the grid points with the evolution folded in. Split out of
	## [method run] so a gate can measure the elevation difference between two prints directly (simplified
	## vertices are not comparable).
	func sample() -> PackedFloat32Array:
		var h := PackedFloat32Array()
		if nx < 2 or ny < 2:
			return h
		h.resize(nx * ny)
		var ix := 1.0 / float(nx - 1)
		var iy := 1.0 / float(ny - 1)
		# The sample positions, once. Both bases are separable (sin(A + B) = sinA cosB + cosA sinB), so
		# a wave costs one row table, one column table and two multiplies a sample instead of a sin().
		var qx := PackedFloat32Array()
		qx.resize(nx)
		for x in nx:
			qx[x] = (float(x) * ix - 0.5) * fspan.x + off.x
		var qy := PackedFloat32Array()
		qy.resize(ny)
		for y in ny:
			qy[y] = (float(y) * iy - 0.5) * fspan.y + off.y

		# --- DRIFT: the land is read a little away from where the grid points sit, and by a
		# different amount in different places, so ridges wander and contours crowd where the
		# displacement converges. Applied to the sample POSITION, which bounds what it does in
		# pixels directly - a point displaced by d moves its contour by exactly d, whatever the
		# local slope is - and that is why this half needs no limiter.
		var nd := dr_ax.size()
		var dsx := _table(dr_kx, qx, PackedFloat32Array(), true)
		var dcx := _table(dr_kx, qx, PackedFloat32Array(), false)
		var dsy := _table(dr_ky, qy, dr_p, true)
		var dcy := _table(dr_ky, qy, dr_p, false)

		# --- UPLIFT: ground rising and subsiding, which is the half that can change the
		# TOPOLOGY - open a saddle, close a new ring around a hill that was not there.
		var nu := up_a.size()
		var usx := _table(up_kx, qx, PackedFloat32Array(), true)
		var ucx := _table(up_kx, qx, PackedFloat32Array(), false)
		var usy := _table(up_ky, qy, up_p, true)
		var ucy := _table(up_ky, qy, up_p, false)

		for y in ny:
			var row := y * nx
			for x in nx:
				var px := qx[x]
				var py := qy[y]
				for k in nd:
					var sn := dsx[k * nx + x] * dcy[k * ny + y] + dcx[k * nx + x] * dsy[k * ny + y]
					px += dr_ax[k] * sn
					py += dr_ay[k] * sn
				h[row + x] = fld.at(Vector2(px, py))

		if nu > 0:
			# The limit that keeps a basin from swimming: a contour moves by `dv / |grad v|`, so the displacement
			# is measured in cells against the local gradient, floored at a fraction of the mean relief, and
			# softened (`u / sqrt(1 + (u/lim)^2)`) so there is no seam. The gradient is read off the base grid
			# (a function of the field point), so the lattice snap survives. Solved into its own buffer and
			# added afterwards, so no sample differences land its neighbor already lifted.
			var du := PackedFloat32Array()
			du.resize(nx * ny)
			var floor_g := RELIEF_FLOOR * relief
			for y in ny:
				var row := y * nx
				var yn := maxi(0, y - 1) * nx
				var yp := mini(ny - 1, y + 1) * nx
				for x in nx:
					var u := 0.0
					for k in nu:
						u += up_a[k] * (usx[k * nx + x] * ucy[k * ny + y]
							+ ucx[k * nx + x] * usy[k * ny + y])
					var gx := (h[row + mini(nx - 1, x + 1)] - h[row + maxi(0, x - 1)]) * 0.5
					var gy := (h[yp + x] - h[yn + x]) * 0.5
					var g := maxf(sqrt(gx * gx + gy * gy), floor_g)
					# Tied to the local slope at its square root: the budget is an elevation but the reader
					# sees a displacement. Exact weighting would freeze the elevation change on flat ground,
					# where a new hill is most interesting. Capped for cliffs.
					u *= minf(sqrt(g / relief), SLOPE_CAP)
					var lim := MAX_SHIFT * g
					var r := u / lim
					du[row + x] = u / sqrt(1.0 + r * r)
			for i in nx * ny:
				h[i] += du[i]
		return h


	func _draw_sheet(h: PackedFloat32Array, tb: TriBatch) -> Array:
		var ix := 1.0 / float(nx - 1)
		var iy := 1.0 / float(ny - 1)
		var org := -half
		var cell := Vector2(2.0 * half.x * ix, 2.0 * half.y * iy)
		var cpx := maxf(0.5, (cell.x + cell.y) * 0.5)

		if water:
			Contour.fill_below(tb, h, nx, ny, sea, water_col, org, cell)
		if hatch_on and band_hi > band_lo:
			# Where this grid's origin sits in the land, in cells: the ruling is defined on the ground, so
			# a moved window re-rules the same lines. Whole numbers, because the window is snapped to the lattice.
			var land := Vector2(off.x / maxf(1e-9, fspan.x * ix),
				off.y / maxf(1e-9, fspan.y * iy))
			Contour.hatch(tb, h, nx, ny, band_lo, band_hi, hatch_a,
				maxf(1.0, hatch_sp) / cpx, HATCH_MARCH, hatch_col, hatch_w, org, cell, land)

		var ex := Contour.new()
		var levels := ex.extract(h, nx, ny, lo, step, count)
		var eps := simp / cpx
		for k in count:
			levels[k] = Contour.simplify(Contour.smooth(levels[k], smooth_iters), eps)

		# The second color plate, printed first and a hair out of register (a two-pass press's drop shadow).
		if plate:
			for k in count:
				if ((k + index_phase) % index_every) != 0:
					continue
				Contour.stroke(tb, levels[k], plate_col, w_index,
					org + plate_off, cell, false)
		for k in count:
			if ((k + index_phase) % index_every) == 0:
				continue
			Contour.stroke(tb, levels[k], minor_col, w_minor, org, cell, true)
		for k in count:
			if ((k + index_phase) % index_every) != 0 or k == pick:
				continue
			Contour.stroke(tb, levels[k], index_col, w_index, org, cell, true)
		if pick >= 0 and pick < count:
			Contour.stroke(tb, levels[pick], pick_col, w_pick, org, cell, true)
		return tb.take_chunks()


	# One axis of a separable spectral basis: sin (or cos) of `k[i] * q[j] + bias[i]` for every wave i
	# and sample j, flattened i-major. The bias carries the phase and the clock, so it belongs to one
	# axis; an empty array says the other has none.
	static func _table(k: PackedFloat32Array, q: PackedFloat32Array,
			bias: PackedFloat32Array, want_sin: bool) -> PackedFloat32Array:
		var n := k.size()
		var m := q.size()
		var out := PackedFloat32Array()
		out.resize(n * m)
		for i in n:
			var b: float = bias[i] if i < bias.size() else 0.0
			var base := i * m
			for j in m:
				var a := k[i] * q[j] + b
				out[base + j] = sin(a) if want_sin else cos(a)
		return out
