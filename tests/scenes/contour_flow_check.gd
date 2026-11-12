extends Node

## Gate for the contour map's re-print: the sheet is rebuilt a couple of times a second and the viewer
## cannot tell. The sheet is extracted in a worker on a [0.3, 1.0] s cadence and the finished packet is
## re-submitted every frame until the next lands, so two consecutive builds must be the same drawing.
## Asserted:
##
##   Sampling phase: the land is static and only the window moves, so a re-print at the same lattice
##   phase reads the same points and is only translated (_draw does so exactly). The window is snapped
##   to its own lattice, so a drift under one cell gives a byte-identical packet and a drift of exactly
##   one cell the same drawing moved by one cell. The unsnapped case is the control: if it matched as
##   well, the gate would assert nothing.
##
##   Hatch pitch: the ruling is anchored, so a change of pitch slides the whole band. Spacing is the
##   seed's and no audio feature may reach it (`f.flux` must not).
##
##   Ink: the highlighted contour's color is baked into the packet, so the tonal center it comes from
##   must be eased or it arrives as a step every re-print.
##
##   Evolution: the sheet must still change slowly, as erosion and plate tectonics do. It moves (eight
##   seconds visibly redraws it, and over a minute and a half every part has had a turn: nothing is
##   permanently masked); it is not uniform (at any moment some cells reorganize and others hold still,
##   measured per cell of a coarse grid; a window warp, the control, leaves no cell still); and no
##   print is a jump (one re-extraction moves almost nothing, at any cadence).
##
## Run inside a real boot (the scene reaches the Spectrum autoload):
##   tests/run_boot_probe.sh tests/scenes/contour_flow_check.gd 180

const SEEDS := [3, 11, 404]
const QUANT := 50.0            # point-match resolution: a fiftieth of a pixel

var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for sv in SEEDS:
		await _run_seed(sv)
	print("")
	if _fails.is_empty():
		print("contour_flow_check: ALL OK - a re-print is the same drawing.")
	else:
		print("contour_flow_check: %d FAILURE(S)" % _fails.size())
		for f in _fails:
			print("   ", f)
	for _i in 6:
		await get_tree().process_frame
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _run_seed(sv: int) -> void:
	var sc = load("res://src/scenes/contour_map.gd").new()
	add_child(sc)
	sc.init_with_seed(sv, "drift")
	sc.size = Vector2(1920, 1080)
	# The elevation ladder and the summit table, without update(), which would start the cadence and
	# hand a real extraction to a worker (a worker still building at tree teardown faults at exit).
	# Every job runs on this thread so the exit status means something.
	sc._ensure_sites()
	print("")
	print("--- seed %d: grid %d, hatch %s ---"
		% [sv, sc._res, "on" if sc._hatch_on else "off"])

	# The window is pinned by hand: _warp_now() returns _warp_b once _warp_t has arrived.
	sc._warp_t = 1.0
	sc._warp_a = Vector2.ZERO
	sc._warp_b = Vector2.ZERO
	var a = sc._make_job()
	if a == null:
		_fails.append("seed %d: no job - the ladder never got solved" % sv)
		sc.queue_free()
		await get_tree().process_frame
		return
	var cw: float = 1.0 / float(a.nx - 1)           # one grid cell, in warp (sheet) units
	var cpx: float = 2.0 * a.half.x / float(a.nx - 1)   # ...and in pixels
	var pa := _points(a.run({}))

	# --- a drift of less than one cell: nothing may change ---
	var chy: float = 1.0 / float(a.ny - 1)
	sc._warp_b = Vector2(cw * 0.4, chy * 0.4)
	var b = sc._make_job()
	var same_off: bool = a.off.distance_to(b.off) < 1e-6
	var pb := _points(b.run({}))
	var identical := pa == pb
	print("  sub-cell drift: window %s, packet %s (%d pts)"
		% ["snapped to the same lattice point" if same_off else "MOVED",
			"identical" if identical else "DIFFERENT", pb.size()])
	_ok(same_off, "seed %d: a 0.4-cell drift moved the sampling window - it must snap" % sv)
	_ok(identical,
		"seed %d: a 0.4-cell drift changed the packet - the sheet re-wobbles on every "
		% sv + "re-print, which is the jumpiness this gate exists for")

	# --- a drift of exactly one cell: the same drawing, moved by exactly one cell ---
	sc._warp_b = Vector2(cw, 0.0)
	var c = sc._make_job()
	var pc := _points(c.run({}))
	var hit_snap := _match(pa, pc, -cpx)
	# ...against the same drift taken off the lattice, the control.
	sc._warp_b = Vector2.ZERO
	var d = sc._make_job()
	var half_cell: float = cw * 0.5 * a.fspan.x
	d.off = a.off + Vector2(half_cell, 0.0)
	var pd := _points(d.run({}))
	var hit_raw := _match(pa, pd, -cpx * 0.5)
	print("  one-cell drift:  %5.1f%% of the sheet is the same drawing translated"
		% (hit_snap * 100.0))
	print("  half-cell, OFF the lattice (the control): %5.1f%%" % (hit_raw * 100.0))
	_ok(hit_snap > 0.9,
		"seed %d: only %.1f%% of a one-cell re-print is the previous sheet translated - "
		% [sv, hit_snap * 100.0] + "the lattice snap is not holding")
	_ok(hit_raw < hit_snap - 0.2,
		"seed %d: sampling off the lattice matched %.1f%% - as well as sampling on it, so "
		% [sv, hit_raw * 100.0] + "this gate is measuring nothing")

	# --- the hatch pitch belongs to the seed, not to the music ---
	sc._warp_b = Vector2.ZERO
	sc._flux_e = 0.005
	var quiet = sc._make_job()
	sc._flux_e = 0.9
	var busy = sc._make_job()
	print("  hatch: %.2f px at flux 0.005, %.2f px at flux 0.9 (ink %.2f -> %.2f)"
		% [quiet.hatch_sp, busy.hatch_sp, quiet.hatch_col.a, busy.hatch_col.a])
	_ok(absf(quiet.hatch_sp - busy.hatch_sp) < 1e-6,
		"seed %d: flux moved the hatch spacing %.2f -> %.2f px - the ruling is anchored, so "
		% [sv, quiet.hatch_sp, busy.hatch_sp] + "a change of pitch slides the whole band")
	if sc._hatch_on:
		_ok(busy.hatch_col.a > quiet.hatch_col.a + 0.05,
			"seed %d: flux does not reach the hatching at all any more" % sv)

	_evolution_test(sc, sv, a)
	_ease_test(sc, sv)
	# Freed the way the Director does, and waited for: a scene pulled out from under a FrameForge job
	# still building faults at exit.
	sc.queue_free()
	await get_tree().process_frame


## The evolution: does it move and does every part get a turn; is one print's worth small, in pixels of
## ink; is the change a uniform shift of the whole drawing, or the ground?
##
## The first three are measured on the land, not on the drawing: a contour is smoothed and simplified, so
## where it moves it is re-traced along its whole length and a vertex dropped or kept lands up to a grid
## cell from where it was on a line that did not move (a 3 px step at p95 by nearest vertex).
## `SheetJob.sample()` returns the elevation grid the drawing is a function of, and a contour moves
## `dv / |grad v|` for a change dv, so the question is answered in pixels with no drawing involved.
##
## Uniformity stays on the drawn packets: a window warp does not change the field (the window is snapped
## to the sampling lattice), it moves the picture.
##
## Driven through the scene's clock (_step_tectonics), not update() or _step, which submit a FrameForge
## job to a worker (a scene pulled out from under one faults at exit).
func _evolution_test(sc, sv: int, ref) -> void:
	# Explicitly typed: `ref` is untyped, so nothing it returns carries a type for inference.
	var g0: PackedFloat32Array = ref.sample()
	if g0.is_empty():
		_ok(false, "seed %d: the reference sheet is empty" % sv)
		return
	var cpx: float = 2.0 * ref.half.x / float(ref.nx - 1)
	var grad := _grad(g0, ref.nx, ref.ny, ref.relief)
	# One print's worth, in pixels of ink movement: whatever the cadence, this is the step the viewer
	# is handed.
	var prints := int(round(sc._cadence * 60.0))
	for _i in prints:
		sc._step_tectonics(1.0 / 60.0)
	var dp := _sorted(_disp(g0, sc._make_job().sample(), grad, cpx))
	var p50 := _pct(dp, 0.50)
	var p95 := _pct(dp, 0.95)
	# ...and eight seconds of it, the timescale of "slow morphing over time".
	for _i in 480 - prints:
		sc._step_tectonics(1.0 / 60.0)
	var d8 := _disp(g0, sc._make_job().sample(), grad, cpx)
	var blk8 := _sorted(_blocks(d8, ref.nx, ref.ny))
	var quiet := _pct(blk8, 0.10)
	var busy := _pct(blk8, 0.90)
	# Nothing is permanently masked. Sampled at checkpoints and unioned, since the land oscillates: a
	# region mid-reorganization at forty seconds may be back where it started at ninety.
	var reach := _blocks(d8, ref.nx, ref.ny)
	for _c in 5:
		for _i in 1080:
			sc._step_tectonics(1.0 / 60.0)
		var snap := _blocks(_disp(g0, sc._make_job().sample(), grad, cpx), ref.nx, ref.ny)
		for i in reach.size():
			reach[i] = maxf(reach[i], snap[i])
	var still := 0
	for v in reach:
		if v < 2.0:
			still += 1
	var reached := 1.0 - float(still) / float(maxi(1, reach.size()))
	# The control: the same land moved one grid cell, a rigid translation of the whole drawing, put
	# through the identical measure. A translation moves every region by the same distance; ground rising
	# in one place and subsiding in another does not. It is synthesized rather than taken from the scene's
	# window warp: a warp leaves this grid unchanged, and a contour web slid by twenty pixels still has
	# ink within a pixel of most of the old ink, so every nearest-point estimate of the offset reads zero.
	var blk_w := _sorted(_blocks(_disp(g0, _shifted(g0, ref.nx, ref.ny), grad, cpx),
		ref.nx, ref.ny))
	var quiet_w := _pct(blk_w, 0.10)
	var busy_w := _pct(blk_w, 0.90)
	print("  evolution: one print moves the ink %.2f px (median), %.2f px (95th)" % [p50, p95])
	print("             8 s moves it %.1f px; per region of the paper, the quietest tenth "
		% _pct(_sorted(d8), 0.50) + "%.1f px and the busiest tenth %.1f px" % [quiet, busy])
	print("             a rigid one-cell shift of the same land, for comparison: quietest tenth "
		+ "%.1f px, busiest %.1f px" % [quiet_w, busy_w])
	print("             over 90 s, %4.1f%% of the paper has had a turn" % (reached * 100.0))
	# The line is on the tail's size, not the spread below it: the median step is 0.2 to 0.4 px and p95
	# 1.0 to 1.7 px, and that ratio is the non-uniformity this half demands, so a tighter threshold would
	# assert against the feature. What matters is that the tail stays under a step the eye reads as one
	# (the rigid-shift control moves the sheet 20 to 30 px in one go).
	_ok(p95 < 2.0,
		"seed %d: one print moves the ink %.2f px at the 95th percentile - the sheet is rebuilt "
		% [sv, p95] + "one to three times a second, so that arrives as a visible step")
	_ok(p50 > 0.05,
		"seed %d: one print moves the ink %.3f px at the median - the land is standing still"
		% [sv, p50])
	_ok(busy > 2.5,
		"seed %d: over 8 s even the busiest tenth of the paper moved only %.1f px - the map "
		% [sv, busy] + "barely evolves")
	_ok(busy > quiet * 2.0,
		"seed %d: the busiest tenth of the paper moved %.1f px over 8 s against the quietest "
		% [sv, busy] + "tenth's %.1f px - the whole sheet is evolving at one rate, which is not "
		% quiet + "what ground does")
	_ok(busy_w < quiet_w * 1.6,
		"seed %d: a RIGID SHIFT of the same land measured %.1f px in its busiest tenth against "
		% [sv, busy_w] + "%.1f px in its quietest - a translation moves the whole sheet by one "
		% quiet_w + "distance, so if this measure sees a spread there it sees nothing anywhere")
	_ok(reached > 0.70,
		"seed %d: over 90 s only %.1f%% of the paper ever moved - the rest is masked out of the "
		% [sv, reached * 100.0] + "evolution permanently, which is not how ground behaves")


## The land's gradient magnitude per grid cell, floored so the displacement measure does not divide by
## zero at summits and basin floors, where a contour genuinely expands far for a small change.
const GRAD_FLOOR := 0.25

func _grad(h: PackedFloat32Array, nx: int, ny: int, relief: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(nx * ny)
	var floor_g := GRAD_FLOOR * relief
	for y in ny:
		var row := y * nx
		var yn := maxi(0, y - 1) * nx
		var yp := mini(ny - 1, y + 1) * nx
		for x in nx:
			var gx := (h[row + mini(nx - 1, x + 1)] - h[row + maxi(0, x - 1)]) * 0.5
			var gy := (h[yp + x] - h[yn + x]) * 0.5
			out[row + x] = maxf(sqrt(gx * gx + gy * gy), floor_g)
	return out


## How far the ink at each grid point moved, in pixels. A contour is a level set, so a change of `dv`
## slides it by `dv / |grad v|` across the ground.
func _disp(a: PackedFloat32Array, b: PackedFloat32Array, grad: PackedFloat32Array,
		cell_px: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(a.size())
	for i in a.size():
		out[i] = absf(b[i] - a[i]) / grad[i] * cell_px
	return out


## The same, averaged over a coarse grid of regions of the paper (the unit of "some of the sheet is
## reorganizing and some is holding still").
const BLK := 10

func _blocks(d: PackedFloat32Array, nx: int, ny: int) -> PackedFloat32Array:
	var acc := PackedFloat32Array()
	acc.resize(BLK * BLK)
	var cnt := PackedInt32Array()
	cnt.resize(BLK * BLK)
	for y in ny:
		var by := clampi(y * BLK / ny, 0, BLK - 1)
		for x in nx:
			var bi := by * BLK + clampi(x * BLK / nx, 0, BLK - 1)
			acc[bi] += d[y * nx + x]
			cnt[bi] += 1
	for i in BLK * BLK:
		acc[i] = acc[i] / float(maxi(1, cnt[i]))
	return acc


## The same land moved one grid cell diagonally: a rigid translation, built on the grid so it goes
## through the same measure.
func _shifted(h: PackedFloat32Array, nx: int, ny: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(nx * ny)
	for y in ny:
		var sy := maxi(0, y - 1) * nx
		for x in nx:
			out[y * nx + x] = h[sy + maxi(0, x - 1)]
	return out


func _sorted(v: PackedFloat32Array) -> PackedFloat32Array:
	var out := v.duplicate()
	out.sort()
	return out


## The displacement measures work on a subsample (a sheet carries half a million vertices, and a
## nearest-point search over all of them is minutes for a statistic settled by twenty thousand).
## The percentile of an already sorted array.
func _pct(v: PackedFloat32Array, q: float) -> float:
	if v.is_empty():
		return 0.0
	return v[clampi(int(float(v.size() - 1) * q), 0, v.size() - 1)]


## The highlighted contour's ink is baked into a packet rebuilt at most every 0.3 s, so what matters is
## how far its color can move across one re-print under the most hostile input: a tonal center sweeping
## through the hue wrap. Unsmoothed it arrives as a full-saturation step.
func _ease_test(sc, sv: int) -> void:
	var dt := 1.0 / 60.0
	var hist: Array = []
	var worst := 0.0
	for i in 1800:
		sc._ch_raw = Vector2(fposmod(float(i) * dt * 0.7, 1.0), 0.9)
		sc._ease_audio(dt)
		hist.append(sc._pick_color())
		if hist.size() > 18:                   # 0.3 s, the fastest cadence there is
			var then: Color = hist[hist.size() - 19]
			var now: Color = hist[hist.size() - 1]
			worst = maxf(worst, Vector3(now.r - then.r, now.g - then.g, now.b - then.b).length())
	print("  inked contour: worst color step across one re-print %.3f" % worst)
	_ok(worst < 0.06,
		"seed %d: the inked contour's color can move %.3f in one re-print - that is a "
		% [sv, worst] + "flash on every loop at that elevation, all over the sheet at once")


# Every vertex of a packet, as one flat array.
func _points(chunks: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for ch in chunks:
		out.append_array((ch as Dictionary)["pts"] as PackedVector2Array)
	return out


# What fraction of `b` lands on a vertex of `a` shifted by `dx`. Quantized, since the two builds reach
# the same land through different arithmetic and agree only to a float ulp.
func _match(a: PackedVector2Array, b: PackedVector2Array, dx: float) -> float:
	if b.is_empty():
		return 0.0
	var set := {}
	for p in a:
		set[Vector2i(roundi((p.x + dx) * QUANT), roundi(p.y * QUANT))] = true
	var hit := 0
	for p in b:
		if set.has(Vector2i(roundi(p.x * QUANT), roundi(p.y * QUANT))):
			hit += 1
	return float(hit) / float(b.size())


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)
