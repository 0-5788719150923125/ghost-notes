extends Node

## Gate for the contour map's highlighted elevation, the one saturated line on the sheet. An index
## contour appears at every occurrence of its elevation, so lighting a different one relights loops all
## over the map. The music's tonal center chooses it; mapping `chroma_hue`'s angle straight onto the
## (non-circular) ladder would throw the highlight across the map on a small move over the wrap.
##
## Two properties, which pull against each other (a slow travel rate alone is not enough: the eased
## position hovers at the half-way mark and the rounding chatters):
##
##   Restless music must not move it: a tonal center sweeping through the wrap has no settled answer,
##   so the sheet holds its elevation.
##
##   Settled music must move it: a sustained change has to arrive, or the highlight is frozen.
##
## Run inside a real boot (chroma_hue reads the Spectrum autoload):
##   tests/run_boot_probe.sh tests/scenes/contour_pick_check.gd 120

var _fails: Array = []


func _ready() -> void:
	var sc = load("res://src/scenes/contour_map.gd").new()
	add_child(sc)
	sc.init_with_seed(3, "drift")
	sc.size = Vector2(1920, 1080)
	sc.update(AudioFeatures.new(), 1.0 / 60.0)
	var dt := 1.0 / 60.0
	var prev: int = sc._pick
	var start: int = sc._pick

	# --- restless: sweeping through the hue wrap, twenty seconds ---
	var restless := 0
	var jump := 0
	for i in 1200:
		sc._ch = Vector2(fposmod(float(i) * dt * 0.55, 1.0), 0.9)
		sc._pick_index(dt)
		if sc._pick != prev:
			restless += 1
			jump = maxi(jump, absi(sc._pick - prev))
		prev = sc._pick
	print("contour_pick_check: restless 20s -> %d change(s), largest %d level(s)"
		% [restless, jump])
	_ok(restless <= 2,
		"a restless tonal center must not keep relighting the sheet - %d changes in 20s"
		% restless)
	_ok(jump <= sc._index_every,
		"the highlight must only ever step to an ADJACENT index line, jumped %d" % jump)

	# --- settled: a sustained tonal center at the far end ---
	var settled := 0
	for i in 3000:
		sc._ch = Vector2(0.97, 0.9)
		sc._pick_index(dt)
		if sc._pick != prev:
			settled += 1
		prev = sc._pick
	print("contour_pick_check: settled 50s -> %d change(s), %d -> %d"
		% [settled, start, sc._pick])
	_ok(settled >= 1,
		"a SUSTAINED harmonic change must still move the highlight, or the harmony has "
		+ "stopped meaning anything")
	_ok(sc._pick != start, "it should have arrived somewhere new")

	sc.queue_free()
	await get_tree().process_frame
	if _fails.is_empty():
		print("contour_pick_check: ALL OK")
		get_tree().quit()
		return
	print("contour_pick_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)
