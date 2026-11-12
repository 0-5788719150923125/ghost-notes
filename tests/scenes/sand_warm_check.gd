extends SceneTree

## sand_warm_check - that a falling-sand chamber opens in progress, in a state the automaton would have
## produced.
##   godot --headless --path . --script res://tests/scenes/sand_warm_check.gd
##
## The chamber is not pre-rolled: a tick costs 5-15 ms, so the couple of hundred ticks to raise a cone
## is over a second of CPU at the cut. [method Grains.prefill] deposits the piles in one pass instead.
##
## That only works if the deposit is plausible: a pile drawn by a rule the sim does not share collapses
## when the sim touches it. So the gate settles the deposit with nothing pouring in and measures how much
## of it stayed, beside a scatter of the same amount of matter through the same chamber. The margin
## between them is the measurement.
##
## It also checks the failures on either side: an empty chamber, and one packed to the ceiling (a deposit
## walk that restarted its budget at every shelf came out solid, occupancy 0.78 against 0.48, and cost
## 42 ms per build). The opening must differ between sessions in depth and in lanes running.

## Seeds to sweep: every chamber shape and a spread of fills.
const SEEDS := 14
## Ticks of settling with nothing pouring in (about two seconds of world time): anything unsupported
## falls and anything oversteep avalanches.
const SETTLE := 60

## Matter (excluding the chamber) as a fraction of the grid. Below the floor is a blank slate; above the
## ceiling the sweep and batching cost more than the worker's budget. Measured over 60 seeds: 0.059 min,
## 0.168 median, 0.340 max; the ceiling sits just above that so that a ledged chamber at 0.406 fails.
const MIN_MATTER := 0.015
const MAX_MATTER := 0.40
## How much of the deposit must still be exactly where it was put after settling.
const MIN_KEPT := 0.60
## ...and how far it must beat an arrangement made by nothing.
const MIN_MARGIN := 0.12

var _fails: Array = []
var _fills: Array = []
var _live_counts := {}
var _shapes := {}
var _in_air := 0


func _initialize() -> void:
	for i in SEEDS:
		_run(2200 + i * 7)
	print("sand_warm_check: shapes %s" % [_shapes])
	print("sand_warm_check: lanes pouring at entry %s" % [_live_counts])

	# Not the same every time: the depth and the number of lanes running must differ between sessions.
	if _live_counts.size() < 2:
		_fails.append("every seed opened with the same number of lanes pouring (%s) - the "
			% [_live_counts] + "spouts' duty phases are not spread")
	var lo := 1.0
	var hi := 0.0
	for f in _fills:
		lo = minf(lo, float(f))
		hi = maxf(hi, float(f))
	print("sand_warm_check: matter fraction %.3f..%.3f over %d seeds, %d opened with material "
		% [lo, hi, SEEDS, _in_air] + "still in the air")
	if hi - lo < 0.02:
		_fails.append("every seed opened at the same depth (%.3f..%.3f)" % [lo, hi])
	if _in_air == 0:
		_fails.append("no seed opened with anything falling - the streams are never seeded")

	if _fails.is_empty():
		print("sand_warm_check: ALL OK")
		quit()
		return
	print("sand_warm_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	quit(1)


func _run(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sc: Object = load("res://src/scenes/falling_sand.gd").new()
	var p: Dictionary = sc.build_params(rng)
	var g = sc._job.g
	var shape := String(p["chamber"])
	_shapes[shape] = int(_shapes.get(shape, 0)) + 1

	var before := _matter(g)
	var frac := float(before.size()) / float(g.w * g.h)
	_fills.append(frac)
	if _air_borne(g) > 0:
		_in_air += 1

	var live := 0
	for sp in sc._spouts:
		var d: Dictionary = sp
		if fposmod(float(sc._job.t_sim) / maxf(0.5, float(d["period"])) + float(d["phase"]),
				1.0) < float(d["duty"]):
			live += 1
	_live_counts[live] = int(_live_counts.get(live, 0)) + 1

	# Settle with nothing pouring in: the pour would refill whatever fell over.
	for _t in SETTLE:
		g.step()
	var kept := _kept(g, before)

	# The shadow: the same chamber and amount of matter, arranged by nothing.
	var scatter := _scatter_score(seed_value, before.size())

	print("sand_warm_check: seed %-5d %-9s fill=%.2f matter=%.3f live=%d  kept %.2f "
		% [seed_value, shape, float(p["prefill"]), frac, live, kept]
		+ "(scattered: %.2f)" % scatter)
	if frac < MIN_MATTER:
		_fails.append("seed %d opened with %.3f of the grid holding matter - that is the blank "
			% [seed_value, frac] + "slate the scene was reported for")
	if frac > MAX_MATTER:
		_fails.append("seed %d opened %.3f full - past what the worker can sweep, and nothing "
			% [seed_value, frac] + "is left to fall through")
	if kept < MIN_KEPT:
		_fails.append("seed %d: only %.2f of the deposit was still in place after %d ticks - "
			% [seed_value, kept, SETTLE] + "the piles are not shaped like anything the sim "
			+ "would have built")
	if kept - scatter < MIN_MARGIN:
		_fails.append("seed %d: the deposit held %.2f against %.2f for the same matter thrown "
			% [seed_value, kept, scatter] + "in at random - it is no better arranged than noise")
	sc.free()


## Every cell holding something that is not the chamber itself.
func _matter(g) -> PackedInt32Array:
	var out := PackedInt32Array()
	for y in g.h:
		for x in g.w:
			var m: int = g.at(x, y)
			if m != 0 and m != g.wall_id:
				out.append(y * g.w + x)
	return out


## Matter with nothing under it: the streams still falling.
func _air_borne(g) -> int:
	var n := 0
	for y in g.h - 1:
		for x in g.w:
			var m: int = g.at(x, y)
			if m != 0 and m != g.wall_id and g.at(x, y + 1) == 0:
				n += 1
	return n


## What share of the cells that held matter still do.
func _kept(g, before: PackedInt32Array) -> float:
	if before.is_empty():
		return 0.0
	var same := 0
	for i in before:
		var m: int = g.at(i % g.w, i / g.w)
		if m != 0 and m != g.wall_id:
			same += 1
	return float(same) / float(before.size())


## The same chamber and amount of matter, dropped in with no arrangement. Rebuilt from the seed, since
## the scene owns its grid and cannot fork one.
func _scatter_score(seed_value: int, count: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sc: Object = load("res://src/scenes/falling_sand.gd").new()
	sc.build_params(rng)
	var g = sc._job.g
	# Clear the deposit, keep the chamber.
	for y in g.h:
		for x in g.w:
			var m: int = g.at(x, y)
			if m != 0 and m != g.wall_id:
				g.set_cell(x, y, 0)
	var mat := int((sc._spouts[0] as Dictionary)["mat"])
	var placed := PackedInt32Array()
	var tries := 0
	while placed.size() < count and tries < count * 40:
		tries += 1
		var x := rng.randi_range(0, g.w - 1)
		var y := rng.randi_range(0, g.h - 1)
		if g.at(x, y) != 0:
			continue
		g.set_cell(x, y, mat)
		placed.append(y * g.w + x)
	for _t in SETTLE:
		g.step()
	var score := _kept(g, placed)
	sc.free()
	return score
