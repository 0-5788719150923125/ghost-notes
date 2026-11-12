extends Node

## canopy_scatter_check - that the wood is a wood: trees the right size for the hill they stand on,
## scattered in stands rather than on a lattice. Two numbers, reported for every seed.
##
## Height against relief: `_terrain.relief` is the landscape's whole vertical range; a tree's height
## must stay a small fraction of it.
##
## Nearest-neighbor spread: the coefficient of variation of nearest-neighbor distances, which needs no
## estimate of the usable area. About 0.52 is a random (Poisson) scatter, below 0.30 a lattice, above
## 0.60 clustered. The Clark-Evans ratio R is printed for orientation (R > 1 dispersed, R < 1
## clustered), against the area the scatter was allowed to use (water and steep ground remove much).
##
## Run: tests/run_boot_probe.sh tests/scenes/canopy_scatter_check.gd 180

const SEEDS := 10
## A tree may not stand taller than this fraction of the landscape's whole relief.
const MAX_H_FRAC := 0.30
## The wood's mean tree must be well under that, or every tree is a giant.
const MAX_MEAN_H_FRAC := 0.18
## Nearest-neighbor CV below this is a lattice, not a wood.
const MIN_CV := 0.55
## A wood is not a dozen trees on a hill.
const MIN_TREES := 150

var _fails: Array = []


func _ready() -> void:
	var script := load("res://src/scenes/canopy.gd")
	var cv_sum := 0.0
	var hf_sum := 0.0
	for s in SEEDS:
		var sc = script.new()
		sc.init_with_seed(1000 + s, "drift")
		var trees: Array = sc._trees
		var relief: float = sc._terrain.relief
		var n := trees.size()
		if n < 2:
			_fails.append("seed %d placed %d trees" % [1000 + s, n])
			sc.free()
			continue
		var pts := PackedVector2Array()
		pts.resize(n)
		var hmax := 0.0
		var hmean := 0.0
		for i in n:
			var tr: Dictionary = trees[i]
			var p: Vector3 = tr["pos"]
			pts[i] = Vector2(p.x, p.z)
			var th: float = float(tr["h"])
			hmax = maxf(hmax, th)
			hmean += th
		hmean /= float(n)

		# Nearest-neighbor distances, all pairs (n is small enough that a grid is not worth it).
		var nn := PackedFloat32Array()
		nn.resize(n)
		for i in n:
			var best := 1e20
			for j in n:
				if i == j:
					continue
				var d := pts[i].distance_to(pts[j])
				if d < best:
					best = d
			nn[i] = best
		var mean := 0.0
		for d in nn:
			mean += d
		mean /= float(n)
		var var_ := 0.0
		for d in nn:
			var_ += (d - mean) * (d - mean)
		var cv := sqrt(var_ / float(n)) / maxf(0.00001, mean)

	# The usable area, measured: the fraction of the square that is out of the water. Assuming the
	# whole square biases R toward "clustered" on a mostly-sea map, letting a lattice pass.
		var margin: float = sc._terrain.half * 0.94
		var wet := 0
		var probes := 4000
		var r2 := RandomNumberGenerator.new()
		r2.seed = 7777 + s
		for _k in probes:
			if sc._terrain.height_at(r2.randf_range(-margin, margin),
					r2.randf_range(-margin, margin)) <= 0.015:
				wet += 1
		var area := (2.0 * margin) * (2.0 * margin) * (1.0 - float(wet) / float(probes))
		var expect := 0.5 / sqrt(float(n) / maxf(0.0001, area))
		var ce := mean / maxf(0.00001, expect)

		cv_sum += cv
		hf_sum += hmean / maxf(0.0001, relief)
		print("canopy_scatter_check: seed=%d n=%4d  h/relief mean=%.3f max=%.3f  nn_cv=%.2f  clark_evans=%.2f"
			% [1000 + s, n, hmean / maxf(0.0001, relief), hmax / maxf(0.0001, relief), cv, ce])

		if hmax > relief * MAX_H_FRAC:
			_fails.append("seed %d: tallest tree is %.0f%% of the landscape's whole relief (max %.0f%%)"
				% [1000 + s, 100.0 * hmax / maxf(0.0001, relief), 100.0 * MAX_H_FRAC])
		if hmean > relief * MAX_MEAN_H_FRAC:
			_fails.append("seed %d: the AVERAGE tree is %.0f%% of the relief (max %.0f%%)"
				% [1000 + s, 100.0 * hmean / maxf(0.0001, relief), 100.0 * MAX_MEAN_H_FRAC])
		if cv < MIN_CV:
			_fails.append("seed %d: nearest-neighbor CV %.2f (want >= %.2f) - the wood is on a lattice, not in stands"
				% [1000 + s, cv, MIN_CV])
		if n < MIN_TREES:
			_fails.append("seed %d: %d trees is not a wood (want >= %d)" % [1000 + s, n, MIN_TREES])
		sc.free()

	print("canopy_scatter_check: mean nn_cv=%.2f  mean h/relief=%.3f"
		% [cv_sum / float(SEEDS), hf_sum / float(SEEDS)])
	if _fails.is_empty():
		print("canopy_scatter_check: ALL OK")
		get_tree().quit()
		return
	print("canopy_scatter_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)
