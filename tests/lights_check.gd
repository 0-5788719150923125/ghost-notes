extends SceneTree

## The gate of [Lights] - what lights a table and how that light moves - with no renderer.
##
##   godot --headless --path . --script res://tests/lights_check.gd
##
## - WHATEVER IS WRITTEN BUILDS: unknown looks and kinds are dropped and said so, numbers clamped,
##   directions named or in degrees, colors colors, caps kept (screens, lamps, lamps that cast); a screen
##   or a bird with no sun is left out, and a sun through a wall is lowered to WALL_SUN. Nothing written
##   is `{}`: no light of its own.
## - THE VOCABULARY names every sun, screen, lattice, bird, lamp and direction.
## - THE NOISE both reckon alike stays in range and repeats; fewer octaves are smoother.
## - WHERE THE SUN FALLS: through a window, its patch lands where it is aimed and moves with it, its bars
##   shade some of it, and everything past it is shaded - against no screen, where all of it is lit; an
##   awning shades the share of the table asked of it, a parasol shades round its middle, leaves hold
##   back about what they cover and stir with the time (and not without sway), blinds let through about
##   what they are open, every lattice lets some through and holds some back. A wall stands past
##   everything on the set, on the sun's side; a canopy over it.
## - CLOUDS: none, and the sun is whole; a covered sky holds it back steadily; the time in cloud follows
##   the cover; no cloud passes in a flicker - against the field's four octaves, where some do; the same
##   time gives the same light.
## - BIRDS cross about as often as asked, each over the table, the same every time; a hawk's shadow
##   wheels back over the table more than once in a visit; a flock flies together.
## - LAMPS stand out of the shot - one asked for in it is moved up out of it, one asked for outside it
##   stays; each flickers its own way as a function of the time: lightning dark but for its flashes, a
##   sign steady but for its stutters, headlights only as they pass, a screen changing with its cuts.
## - BUILT: a sun that casts, its screens and birds shadow-only on SCREEN_LAYER, no lamp casting with that
##   layer, at most MAX_SHADOWED lamps casting; a cloud over the sun dims it; fitted, the palest thing in
##   the light takes no more than SUN_HEAT - against the same light unfitted, which is over it.

var _fails := 0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	_rng.seed = 4242
	for check in [_sanitize, _vocabulary, _noise, _window, _screens, _clouds, _birds, _lamps, _built]:
		var done: Variant = await (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	print("lights_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## A sun, and whatever else is given.
func _light(extra: Dictionary = {}, sun: Dictionary = {"look": "sun", "from": "back left", "height": 35}) -> Dictionary:
	var d := {"sky": {"color": "#a0b8d0", "strength": 0.6}, "sun": sun}
	d.merge(extra, true)
	return Lights.sanitize(d)


## The table a camera on episode 1234 sees, on the old board table's top.
func _seen() -> PackedVector3Array:
	var lay := CardTable.layout_of(1234)
	var top := Tables.sanitize(null, null, {}, [])["top"] as Dictionary
	return CardTable.seen_points(lay["camera"], float(lay["fov"]), top)


func _bounds() -> AABB:
	return AABB(Vector3(-0.95, -0.05, -0.45), Vector3(1.9, 0.45, 0.9))


func _geom(light: Dictionary) -> Array:
	return Lights.screens_of(light, Vector3(0.0, 0.0, -0.02), _bounds(), _seen(), 77)


func _sanitize() -> bool:
	_ok(Lights.sanitize(null).is_empty() and Lights.sanitize({}).is_empty(), "nothing written is not {}")
	var notes := PackedStringArray()
	_ok(Lights.sanitize("a sunny day", notes).is_empty() and not notes.is_empty(), "a light that is not an object is not dropped and said")
	notes = PackedStringArray()
	var l := Lights.sanitize({"sky": {"color": "blue", "strength": 7},
		"sun": {"look": "a laser", "from": "north by northwest", "height": 140, "color": "#ffeedd", "strength": -2},
		"through": [{"kind": "window"}, {"kind": "a chandelier"}, "glass", {"kind": "leaves", "cover": 3, "size": 0.1},
			{"kind": "awning"}, {"kind": "blinds"}],
		"clouds": {"cover": 0.4, "size": 9, "speed": -1},
		"birds": {"look": "dragon"},
		"lamps": [{"look": "torch", "name": "a", "shadows": true}, {"look": "fire", "name": "b", "shadows": true},
			{"look": "lamp", "name": "c", "shadows": true}, {"look": "spotlight"}, {"look": "neon", "name": "d"},
			{"look": "candles", "name": "e"}]}, notes)
	var sky: Dictionary = l["sky"]
	_ok(Props._is_color(sky["color"]) and float(sky["strength"]) == 1.0, "the sky is not made safe: %s" % str(sky))
	var sun: Dictionary = l["sun"]
	_ok(String(sun["look"]) == "sun" and float(sun["height"]) <= Lights.WALL_SUN and float(sun["strength"]) == 0.0
		and float(sun["from"]) == 270.0, "the sun is not made safe: %s" % str(sun))
	var kinds: Array = (l["through"] as Array).map(func(s: Dictionary) -> String: return String(s["kind"]))
	_ok(kinds == ["window", "leaves", "awning"], "screens kept: %s (unknown ones dropped, the cap kept)" % str(kinds))
	var leaves: Dictionary = (l["through"] as Array)[1]
	_ok(float(leaves["cover"]) <= 0.95 and float(leaves["size"]) >= 2.0, "a canopy's numbers are not clamped: %s" % str(leaves))
	_ok(float((l["clouds"] as Dictionary)["size"]) == 1.0 and float((l["clouds"] as Dictionary)["speed"]) == 0.0, "the clouds are not clamped")
	_ok((l["birds"] as Dictionary).is_empty(), "an unknown bird flew")
	var lamps: Array = l["lamps"]
	_ok(lamps.size() == Lights.MAX_LAMPS, "%d lamps kept, the cap is %d" % [lamps.size(), Lights.MAX_LAMPS])
	var casting := 0
	for lamp in lamps:
		casting += 1 if bool((lamp as Dictionary)["shadows"]) else 0
	_ok(casting == Lights.MAX_SHADOWED, "%d lamps cast, at most %d may" % [casting, Lights.MAX_SHADOWED])
	for what in ["a laser", "north by northwest", "a chandelier", "dragon", "spotlight", "past %d screens" % Lights.MAX_SCREENS, "lowered", "casts no shadows"]:
		var said := false
		for n in notes:
			said = said or String(n).contains(what)
		_ok(said, "nothing was said about %s: %s" % [what, str(notes)])
	# named and numbered directions
	_ok(float(Lights.sanitize({"sun": {"from": "front right"}})["sun"]["from"]) == 45.0, "a named direction is not its degrees")
	_ok(is_equal_approx(float(Lights.sanitize({"sun": {"from": -90}})["sun"]["from"]), 270.0), "degrees are not taken round")
	# no sun: no screens, no birds
	notes = PackedStringArray()
	var dark := Lights.sanitize({"sky": {"strength": 0.05}, "through": [{"kind": "window"}], "birds": {"look": "gull"}}, notes)
	_ok((dark["through"] as Array).is_empty() and (dark["birds"] as Dictionary).is_empty() and notes.size() >= 2,
		"with no sun, a screen or a bird was kept, or not said: %s" % str(notes))
	# a sun high over open sky stays high; through a wall it is lowered
	_ok(float(_light({}, {"height": 80})["sun"]["height"]) == 80.0, "an open sky's high sun was lowered")
	_ok(float(_light({"through": [{"kind": "blinds"}]}, {"height": 80})["sun"]["height"]) == Lights.WALL_SUN, "a sun through blinds was not lowered")
	return true


func _vocabulary() -> bool:
	var text := Lights.describe()
	var missing := PackedStringArray()
	for reg in [Lights.SUNS, Lights.SCREENS, Lights.LATTICES, Lights.BIRDS, Lights.LAMPS, Lights.FROM]:
		for k in reg:
			if not text.contains(String(k)):
				missing.append(String(k))
	_ok(missing.is_empty(), "the vocabulary leaves out: %s" % ", ".join(missing))
	var line := Lights.summary(_light({"through": [{"name": "the window", "kind": "window"}], "clouds": {"cover": 0.4},
		"birds": {"look": "gull"}, "lamps": [{"name": "a torch", "look": "torch", "from": "left"}]}))
	_ok(line.contains("window") and line.contains("clouds") and line.contains("gull") and line.contains("a torch"), "the summary leaves things out: %s" % line)
	_ok(Lights.summary({}).is_empty(), "no light has a summary")
	return true


func _noise() -> bool:
	var lo := INF
	var hi := -INF
	var same := true
	var rough := 0.0
	var smooth := 0.0
	for i in 400:
		var p := Vector2(float(i) * 0.37 - 50.0, float(i % 23) * 1.3 - 9.0)
		var v := Lights.fbm(p, 12345)
		lo = minf(lo, v)
		hi = maxf(hi, v)
		same = same and Lights.fbm(p, 12345) == v and Lights.noise(p, 9) == Lights.noise(p, 9)
		var q := p + Vector2(0.01, 0.0)
		rough += absf(Lights.fbm(q, 12345) - v)
		smooth += absf(Lights.fbm(q, 12345, 2) - Lights.fbm(p, 12345, 2))
	_ok(lo >= 0.0 and hi <= 1.0 and hi - lo > 0.3, "the noise is out of range or flat: %.3f..%.3f" % [lo, hi])
	_ok(same, "the noise does not repeat")
	_ok(smooth < rough, "two octaves are not smoother than four (%.4f, %.4f)" % [smooth, rough])
	return true


## WHERE THE SUN FALLS THROUGH A WINDOW, two-sided.
func _window() -> bool:
	var at := Vector2(10.0, -8.0)
	var light := _light({"through": [{"name": "w", "kind": "window", "at": [at.x, at.y], "size": [100, 140], "panes": [2, 3], "bars": 4}]})
	var s := Lights.sun_dir(light["sun"])
	var g := _geom(light)
	var mid := Vector3(at.x * 0.01, 0.0, -0.02 + at.y * 0.01)
	# the middle of the middle pane, a pane's width off in x (a bar lies on the middle line)
	var pane := mid + Vector3(0.0, 0.0, 0.0)
	var lit_near := 0
	for dx in [-0.25, 0.25]:
		lit_near += 1 if Lights.sunlit(g, s, pane + Vector3(dx, 0.0, 0.0), 0.0) else 0
	_ok(lit_near == 2, "the window's patch does not light the panes either side of its middle (%d of 2)" % lit_near)
	_ok(not Lights.sunlit(g, s, mid + Vector3(2.5, 0.0, 0.0), 0.0) and not Lights.sunlit(g, s, mid + Vector3(-2.5, 0.0, 0.0), 0.0),
		"the table far past the window's patch is in the sun")
	# its bars: somewhere inside the patch is shaded
	var shaded_in := 0
	for i in 200:
		var p := mid + Vector3(_rng.randf_range(-0.45, 0.45), 0.0, _rng.randf_range(-0.2, 0.2))
		shaded_in += 0 if Lights.sunlit(g, s, p, 0.0) else 1
	_ok(shaded_in > 5 and shaded_in < 120, "the bars shade %d of 200 points inside the patch" % shaded_in)
	# aimed elsewhere, the patch moves with it
	var moved := _light({"through": [{"name": "w", "kind": "window", "at": [at.x + 60.0, at.y], "size": [100, 140], "panes": [1, 1], "bars": 0}]})
	var gm := _geom(moved)
	_ok(Lights.sunlit(gm, s, mid + Vector3(0.6, 0.0, 0.0), 0.0) and not Lights.sunlit(gm, s, mid + Vector3(-0.6, 0.0, 0.0), 0.0),
		"aimed 60 cm to the right, the patch did not go with it")
	# the control: no screen, all of it lit
	_ok(Lights.coverage(_geom(_light()), s, _seen(), 0.0) == 1.0, "control: with nothing to fall through, not all the table is lit")
	_ok(Lights.coverage(g, s, _seen(), 0.0) < 0.9, "a window lights nearly all the table: the wall shades nothing")
	# THE WALL STANDS PAST EVERYTHING on the sun's side, from every side
	for from in [0.0, 60.0, 90.0, 150.0, 200.0, 270.0, 330.0]:
		for h in [10.0, 40.0, 65.0]:
			var lw := _light({"through": [{"name": "w", "kind": "window"}]}, {"from": from, "height": h})
			var gw: Dictionary = _geom(lw)[0]
			var n: Vector3 = gw["normal"]
			var o: Vector3 = gw["origin"]
			var past := true
			for k in 8:
				past = past and (o - _bounds().get_endpoint(k)).dot(n) > 0.0
			_ok(past, "from %d at %d degrees the wall stands in the set" % [int(from), int(h)])
	var over: Dictionary = _geom(_light({"through": [{"name": "l", "kind": "leaves"}]}))[0]
	_ok((over["origin"] as Vector3).y > _bounds().end.y, "a canopy hangs into the set")
	return true


## WHAT ELSE THE SUN FALLS THROUGH, each against what it was asked.
func _screens() -> bool:
	var seen := _seen()
	var sun := {"look": "sun", "from": "right", "height": 50}
	var s := Lights.sun_dir(Lights.sanitize({"sun": sun})["sun"])
	for cover in [0.2, 0.5, 0.8]:
		var aw := _light({"through": [{"name": "a", "kind": "awning", "cover": cover, "sway": 0.0}]}, sun)
		var lit := Lights.coverage(_geom(aw), s, seen, 0.0)
		_ok(absf((1.0 - lit) - cover) < 0.06, "an awning asked to shade %.0f%% shades %.0f%%" % [cover * 100.0, (1.0 - lit) * 100.0])
	var none := _light({"through": [{"name": "a", "kind": "awning", "cover": 0.0}]}, sun)
	_ok(Lights.coverage(_geom(none), s, seen, 0.0) > 0.97, "control: an awning shading nothing shades the table")
	var pa := _light({"through": [{"name": "p", "kind": "parasol", "at": [20, -10], "size": 200}]}, sun)
	var gp := _geom(pa)
	_ok(not Lights.sunlit(gp, s, Vector3(0.2, 0.0, -0.12), 0.0) and Lights.sunlit(gp, s, Vector3(-1.9, 0.0, -0.12), 0.0),
		"a parasol does not shade round its middle, or shades past its reach")
	# leaves hold back about what they cover, and stir
	var pts := PackedVector3Array()
	for i in 600:
		pts.append(Vector3(_rng.randf_range(-0.6, 0.6), 0.0, _rng.randf_range(-0.5, 0.3)))
	for cover in [0.3, 0.7]:
		var lv := _light({"through": [{"name": "l", "kind": "leaves", "cover": cover, "size": 8, "sway": 0.5}]}, sun)
		var gl := _geom(lv)
		var held := 1.0 - Lights.coverage(gl, s, pts, 0.0)
		_ok(absf(held - cover) < 0.15, "leaves covering %.0f%% hold back %.0f%%" % [cover * 100.0, held * 100.0])
	var stir := _light({"through": [{"name": "l", "kind": "leaves", "cover": 0.5, "size": 8, "sway": 0.6}]}, sun)
	var still := _light({"through": [{"name": "l", "kind": "leaves", "cover": 0.5, "size": 8, "sway": 0.0}]}, sun)
	var moved := 0
	var unmoved := 0
	var gs := _geom(stir)
	var gt := _geom(still)
	for p in pts:
		moved += 1 if Lights.sunlit(gs, s, p, 0.0) != Lights.sunlit(gs, s, p, 3.0) else 0
		unmoved += 1 if Lights.sunlit(gt, s, p, 0.0) != Lights.sunlit(gt, s, p, 3.0) else 0
	_ok(moved > 20 and unmoved == 0, "leaves in a breeze moved %d points in 3 s, in still air %d" % [moved, unmoved])
	for kind in ["fronds", "branches"]:
		var c := Lights.coverage(_geom(_light({"through": [{"name": "c", "kind": kind, "cover": 0.5}]}, sun)), s, pts, 0.0)
		_ok(c > 0.25 and c < 0.75, "%s covering half let through %.0f%%" % [kind, c * 100.0])
	# blinds let through about what they are open, inside the window
	var low := {"look": "sun", "from": "right", "height": 35}
	var sl := Lights.sun_dir(Lights.sanitize({"sun": low})["sun"])
	var bl := _light({"through": [{"name": "b", "kind": "blinds", "size": [300, 300], "slats": 5, "open": 0.4, "bars": 0}]}, low)
	var inside := PackedVector3Array()
	for i in 400:
		inside.append(Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.25, 0.2)))
	var through := Lights.coverage(_geom(bl), sl, inside, 0.0)
	_ok(absf(through - 0.4) < 0.1, "blinds open 40%% let through %.0f%%" % (through * 100.0))
	for pat in Lights.LATTICES:
		var la := _light({"through": [{"name": "x", "kind": "lattice", "size": [300, 300], "pattern": pat, "cell": 8, "bars": 1.5}]}, low)
		var c := Lights.coverage(_geom(la), sl, inside, 0.0)
		_ok(c > 0.1 and c < 0.95, "a lattice of %s lets through %.0f%%" % [pat, c * 100.0])
	var sl_over := _light({"through": [{"name": "s", "kind": "slats", "slats": 20, "open": 0.5}]}, sun)
	var cs := Lights.coverage(_geom(sl_over), s, pts, 0.0)
	_ok(absf(cs - 0.5) < 0.1, "slats open half let through %.0f%%" % (cs * 100.0))
	return true


func _clouds() -> bool:
	_ok(Lights.cloud_field({}, 1).is_empty() and Lights.transmission({}, 12.0) == 1.0, "a clear sky dims the sun")
	var covered := Lights.cloud_field(Lights.sanitize({"sun": {}, "clouds": {"cover": 1.0, "thickness": 0.7}})["clouds"], 3)
	var steady := true
	var tau0 := Lights.transmission(covered, 0.0)
	for t in range(0, 600, 7):
		steady = steady and absf(Lights.transmission(covered, float(t)) - tau0) < 1e-5
	_ok(steady and tau0 < 0.6, "a covered sky does not hold the sun back steadily (%.2f)" % tau0)
	for cover in [0.15, 0.5, 0.85]:
		var under := 0.0
		var n := 0
		for seed in 6:
			var f := Lights.cloud_field(Lights.sanitize({"sun": {}, "clouds": {"cover": cover, "size": 0.3, "speed": 0.6}})["clouds"], seed * 31 + 5)
			for i in 3600:
				under += 1.0 if Lights.cloud_at(f, float(i)) > 0.5 else 0.0
				n += 1
		var share := under / float(n)
		_ok(absf(share - cover) < 0.2, "clouds covering %.0f%% of the sky hide the sun %.0f%% of the time" % [cover * 100.0, share * 100.0])
	# NO CLOUD IN A FLICKER: the shortest passing over an hour, against the four-octave field
	var shortest := INF
	var shortest4 := INF
	var f2 := Lights.cloud_field(Lights.sanitize({"sun": {}, "clouds": {"cover": 0.3, "size": 0.3, "speed": 0.7}})["clouds"], 11)
	var into := -1.0
	var into4 := -1.0
	for i in 36000:
		var t := float(i) * 0.1
		var c := Lights.cloud_at(f2, t) > 0.5
		var p: Vector2 = (f2["start"] as Vector2) - (f2["wind"] as Vector2) * t
		var d4 := Lights.fbm(p, int(f2["salt"]))
		var c4 := d4 > float(f2["thr"])
		if c and into < 0.0:
			into = t
		elif not c and into >= 0.0:
			shortest = minf(shortest, t - into)
			into = -1.0
		if c4 and into4 < 0.0:
			into4 = t
		elif not c4 and into4 >= 0.0:
			shortest4 = minf(shortest4, t - into4)
			into4 = -1.0
	_ok(shortest >= 3.0, "a cloud passes the sun in %.1f s - a flicker" % shortest)
	_ok(shortest4 < shortest, "control: the four-octave field has no shorter passings (%.1f s against %.1f s)" % [shortest4, shortest])
	_ok(Lights.transmission(f2, 123.4) == Lights.transmission(f2, 123.4), "the same time gives another light")
	return true


func _birds() -> bool:
	var birds := Lights.sanitize({"sun": {}, "birds": {"look": "gull", "every": 30, "flock": 3, "speed": 0.5}})["birds"] as Dictionary
	var cs := Lights.crossings(birds, 99)
	var first := []
	for c in cs:
		if float((c as Dictionary)["t"]) < 3600.0:
			first.append(c)
	var mean := 3600.0 / maxf(float(first.size()), 1.0)
	_ok(mean > 30.0 * 0.65 and mean < 30.0 * 1.5, "birds asked every 30 s come every %.0f s" % mean)
	_ok(str(Lights.crossings(birds, 99)) == str(cs), "the same seed gives other skies")
	var over := 0
	var flocks := 0
	for c in first:
		var d: Dictionary = c
		var near := INF
		var t := float(d["t"]) - 1.0
		while t < float(d["t"]) + 1.0:
			for b in Lights.birds_at(cs, "gull", t):
				near = minf(near, ((b as Dictionary)["at"] as Vector2).length())
			t += 0.02
		over += 1 if near < 0.6 else 0
		flocks += 1 if (d["members"] as Array).size() >= 2 else 0
	_ok(over == first.size(), "%d of %d crossings pass over the table" % [over, first.size()])
	_ok(flocks > first.size() / 2, "a flock of 3 flew alone %d times of %d" % [first.size() - flocks, first.size()])
	# a hawk wheels back over the table
	var hawk := Lights.sanitize({"sun": {}, "birds": {"look": "hawk", "every": 60}})["birds"] as Dictionary
	var hc := Lights.crossings(hawk, 7)
	var visit: Dictionary = hc[0]
	var passes := 0
	var was := false
	var t2 := float(visit["t"])
	while t2 < float(visit["t"]) + float(visit["dur"]):
		var now := false
		for b in Lights.birds_at(hc, "hawk", t2):
			now = now or ((b as Dictionary)["at"] as Vector2).length() < 0.8
		if now and not was:
			passes += 1
		was = now
		t2 += 0.05
	_ok(passes >= 2, "a hawk's shadow crossed the table %d time(s) in its visit" % passes)
	return true


func _lamps() -> bool:
	var lay := CardTable.layout_of(1234)
	var cam: Transform3D = lay["camera"]
	var fov := float(lay["fov"])
	var in_shot := func(at: Vector3) -> bool: return CardTable.in_shot(cam, fov, at)
	var middle := Vector3(0.0, 0.0, -0.02)
	var seen_lamp := Lights.sanitize({"lamps": [{"look": "lantern", "from": "back", "distance": 60, "height": 5}]})["lamps"][0] as Dictionary
	_ok(bool(in_shot.call(middle + Vector3(0.0, 0.05, -0.6))), "the instrument: a lantern on the far cloth is not in the shot")
	var placed := Lights.lamp_place(seen_lamp, middle, in_shot)
	_ok(bool(placed["moved"]) and not bool(in_shot.call(placed["at"])), "a lamp asked for in the shot stays in it")
	var out_lamp := Lights.sanitize({"lamps": [{"look": "torch", "from": "front left", "distance": 150, "height": 90}]})["lamps"][0] as Dictionary
	_ok(not bool(Lights.lamp_place(out_lamp, middle, in_shot)["moved"]), "control: a torch behind the camera was moved")
	# each its own way
	var fk := Lights.flicker_of(Lights.sanitize({"lamps": [{"look": "lightning", "every": 20}]})["lamps"][0], 5)
	var dark := 0
	var lit := 0
	for i in 6000:
		var b := float(Lights.flicker("lightning", fk, float(i) * 0.1)["bright"])
		dark += 1 if b < 0.01 else 0
		lit += 1 if b > 0.5 else 0
	_ok(dark > 5400 and lit > 10, "lightning is not dark but for its flashes (%d dark, %d lit of 6000)" % [dark, lit])
	var nk := Lights.flicker_of(Lights.sanitize({"lamps": [{"look": "neon"}]})["lamps"][0], 6)
	var off := 0
	for i in 60000:
		off += 1 if float(Lights.flicker("neon", nk, float(i) * 0.01)["bright"]) < 0.5 else 0
	_ok(off > 0 and off < 3000, "a sign is not steady but for its stutters (%d of 60000 off)" % off)
	var hk := Lights.flicker_of(Lights.sanitize({"lamps": [{"look": "headlights", "every": 30}]})["lamps"][0], 7)
	var passing := 0
	for i in 6000:
		passing += 1 if float(Lights.flicker("headlights", hk, float(i) * 0.1)["bright"]) > 0.05 else 0
	_ok(passing > 50 and passing < 2000, "headlights shine %d of 6000 moments - not only as they pass" % passing)
	var sk := Lights.flicker_of(Lights.sanitize({"lamps": [{"look": "screen"}]})["lamps"][0], 8)
	var cuts := {}
	for i in 100:
		cuts[snappedf(float(Lights.flicker("screen", sk, float(i) * 0.5)["bright"]), 0.05)] = true
	_ok(cuts.size() >= 4, "a screen's light does not change with its cuts (%d levels)" % cuts.size())
	var tk := Lights.flicker_of(Lights.sanitize({"lamps": [{"look": "torch"}]})["lamps"][0], 9)
	_ok(str(Lights.flicker("torch", tk, 42.0)) == str(Lights.flicker("torch", tk, 42.0)), "the same time gives another flicker")
	return true


func _built() -> bool:
	var root := Node3D.new()
	get_root().add_child(root)
	var env := Environment.new()
	var light := _light({"through": [{"name": "w", "kind": "window"}, {"name": "l", "kind": "leaves", "cover": 0.3}],
		"clouds": {"cover": 0.6, "size": 0.3, "speed": 0.8, "thickness": 0.9}, "birds": {"look": "crow", "flock": 2},
		"lamps": [{"name": "a", "look": "torch", "from": "left", "shadows": true}, {"name": "b", "look": "lantern", "from": "right"}]})
	var stage := {"middle": Vector3(0.0, 0.0, -0.02), "bounds": _bounds(), "seen": _seen(), "env": env, "room": null, "in_shot": Callable()}
	var rig := Lights.build(light, stage, 11)
	root.add_child(rig.root)
	_ok(rig.sun != null and rig.sun.shadow_enabled, "the sun casts no shadow")
	var screens := 0
	for n in rig.root.get_children():
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n
			_ok(mi.layers == Lights.SCREEN_LAYER and mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,
				"%s is drawn, or off the screens' layer" % mi.name)
			screens += 1
	_ok(screens == 2 + Lights.MAX_BIRDS, "%d screens and birds built" % screens)
	for l in rig.lamps:
		var node: Light3D = (l as Dictionary)["light"]
		_ok((node.shadow_caster_mask & Lights.SCREEN_LAYER) == 0, "a lamp casts with the sun's screens")
	# a cloud dims the sun
	var clear := -1.0
	var cloudy := -1.0
	for i in 2000:
		var t := float(i) * 0.5
		var c := Lights.cloud_at(rig.field, t)
		if c < 0.01 and clear < 0.0:
			clear = t
		if c > 0.99 and cloudy < 0.0:
			cloudy = t
	rig.fit(0.4)
	rig.tick(clear)
	var bright := rig.sun.light_energy
	rig.tick(cloudy)
	_ok(clear >= 0.0 and cloudy >= 0.0 and rig.sun.light_energy < bright * 0.3, "a cloud over the sun leaves %.2f of %.2f" % [rig.sun.light_energy, bright])
	# THE EXPOSURE: fitted to a pale table, the palest thing takes no more than SUN_HEAT - unfitted, more
	var pale := 0.8
	var e := rig.sun_asked * sin(deg_to_rad(rig.sun_height)) + Lights.SKY_MAX * 0.6
	_ok(e * pale > Lights.SUN_HEAT, "control: unfitted, a pale table takes no more than the cap (%.2f)" % (e * pale))
	rig.fit(pale)
	var fitted := rig.sun_energy * sin(deg_to_rad(rig.sun_height)) + rig.sky_energy
	_ok(fitted * pale <= Lights.SUN_HEAT + 1e-4, "fitted, a pale table takes %.2f" % (fitted * pale))
	_ok(absf(rig.sun_energy / rig.sky_energy - rig.sun_asked / (Lights.SKY_MAX * 0.6)) < 1e-3, "fitted, the sun and the sky lost their ratio")
	rig.release()
	root.queue_free()
	await process_frame
	return true
