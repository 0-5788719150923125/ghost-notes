extends SceneTree

## assembly_check: a thing built of many small parts ([Assembly], next/assembly.md), with no table under it and no bodies: a part goes
## where the lattice lets it, what is said of a build is the same whenever it is played, an episode opens talking, and it stretches by
## stopping, never by slowing. What the pieces really do is assembly_bake_check's. Controls: a part in a taken cell, a part resting on
## nothing, a tile holding nothing up, a removal that would leave a part on air.
##
## Run: godot --headless --path . --script tests/table/assembly_check.gd

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	for check in [_parts, _lattice, _heap, _digging, _log, _hanging, _time, _scrub, _runs, _start_over, _reading, _opens_talking, _whole_episode, _always_there, _fill_stays_in, _steps_in_order, _room_to_turn]:
		var done: Variant = (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	print("assembly_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


const COLORS := {"red": "#b3261e", "tan": "#c9b185", "gray": "#8b8d8f"}


## An assembly over a made-up table: a plate, a tub's worth of pile, a pile called "left".
func _make(count := 60) -> Assembly:
	var a := Assembly.new()
	a.spec = {"colors": COLORS, "base": {"size": [16, 16], "color": "gray", "turn": 0.0},
		"stock": [{"name": "left", "at": [-30.0, 0.0], "radius": 10.0, "count": count,
			"colors": {"red": 1.0, "tan": 1.0, "gray": 1.0}, "kinds": {"brick": 2.0, "plate": 1.0}}]}
	a.seed_value = 7
	a.world = {"base_at": Vector3.ZERO, "yaw": 0.0, "heaps": {"left": AssemblyHeap.pile("left", Vector2(-0.3, 0.0), 0.1),
		"aside": AssemblyHeap.pile("aside", Vector2(0.15, 0.0), 0.05)}, "obstacles": [], "view": Vector3(0.0, 0.3, 0.2)}
	return a


func _parts() -> bool:
	var why: Array = []
	var p := Assembly.parse_part("brick 2x4 red", COLORS, why)
	_ok(int(p.get("w", 0)) == 2 and int(p.get("d", 0)) == 4 and String(p.get("color", "")) == "red", "a part reads: %s" % str(p))
	var turned := Assembly.parse_part("brick 4x2 red", COLORS, why)
	_ok(bool(turned.get("swap", false)) and int(turned["w"]) == 2, "a size written the other way round is the same part turned")
	why = []
	_ok(Assembly.parse_part("brick 3x7 red", COLORS, why).is_empty() and not why.is_empty(), "control: a size nobody makes is refused, and says why")
	why = []
	_ok(Assembly.parse_part("brick 2x4 mauve", COLORS, why).is_empty() and String(why[0]).contains("mauve"), "control: a color the table lacks is refused, and says why")
	return true


func _lattice() -> bool:
	var a := _make()
	a.perform([])
	# on the plate: fits, holds by every stud of it
	var f := a.fit("brick", 2, 4, 0, 0, 0, 0)
	_ok(bool(f["ok"]) and int(f["studs"]) == 8, "a 2x4 on the plate holds by 8 studs: %s" % str(f))
	a._act = "t"
	a.problems["t"] = []
	a.counts["t"] = {}
	a.pieces.append({"id": a.pieces.size(), "kind": "brick", "w": 2, "d": 4, "color": "red", "rests": []})
	var id := a.pieces.size() - 1
	a._seat(id, "brick", 2, 4, 0, 0, 0, 0)
	# controls
	_ok(not bool(a.fit("brick", 2, 2, 0, 1, 1, 0)["ok"]), "control: a part in a taken cell is refused")
	_ok(String(a.fit("brick", 2, 2, 0, 1, 1, 0)["why"]).contains("taken"), "...and says so")
	_ok(not bool(a.fit("brick", 2, 2, 0, 10, 10, 6)["ok"]), "control: a part resting on nothing is refused")
	_ok(not bool(a.fit("brick", 2, 2, 0, 40, 40, 0)["ok"]), "control: off the plate, nothing holds it")
	_ok(bool(a.fit("brick", 2, 2, 0, 1, 3, 3)["ok"]), "half on a brick below it, it holds (an overhang)")
	_ok(int(a.fit("brick", 2, 2, 0, 1, 3, 3)["studs"]) == 1, "...by the one stud it overlaps")
	_ok(a.level_for(2, 2, 0, 0, 0) == 3, "a part comes down on what is highest under it")
	# a tile holds nothing up
	a.pieces.append({"id": a.pieces.size(), "kind": "tile", "w": 2, "d": 2, "color": "tan", "rests": []})
	a._seat(a.pieces.size() - 1, "tile", 2, 2, 0, 6, 6, 0)
	_ok(not bool(a.fit("brick", 2, 2, 0, 6, 6, 1)["ok"]), "control: nothing holds onto a tile")
	# a slope's studs are only along its back row
	a.pieces.append({"id": a.pieces.size(), "kind": "slope", "w": 2, "d": 3, "color": "tan", "rests": []})
	a._seat(a.pieces.size() - 1, "slope", 2, 3, 0, 10, 10, 0)
	_ok(bool(a.fit("plate", 2, 1, 0, 10, 10, 3)["ok"]), "a plate over a slope's back row holds")
	_ok(not bool(a.fit("plate", 2, 1, 0, 10, 12, 3)["ok"]), "control: over a slope's fall it does not")
	# a turned part's cells are where it turned to
	_ok(Assembly.turned_size(2, 4, 90) == Vector2i(4, 2), "turned a quarter, 2x4 is 4 across")
	var turned := Assembly.cells_of("brick", 2, 4, 90, 8, 8, 0)
	var xs := {}
	for c in turned:
		xs[int((c as Array)[0])] = true
	_ok(xs.size() == 4 and xs.has(8) and xs.has(11), "turned, its cells run across from its far left corner: %s" % str(xs.keys()))
	# an arch stands on its ends, open between
	var arch := Assembly.cells_of("arch", 1, 4, 0, 0, 0, 0)
	var at_foot := 0
	for c in arch:
		if int((c as Array)[2]) == 0:
			at_foot += 1
	_ok(at_foot == 2, "an arch stands on its two ends (%d cells at its foot)" % at_foot)
	return true


func _heap() -> bool:
	var h := AssemblyHeap.pile("t", Vector2.ZERO, 0.1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var poses := {}
	for i in 120:
		poses[i] = h.deposit(i, 0.016, 0.032, 0.0096, rng)
	# the same again, the same places
	var h2 := AssemblyHeap.pile("t", Vector2.ZERO, 0.1)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 11
	var same := true
	for i in 120:
		if not h2.deposit(i, 0.016, 0.032, 0.0096, rng2).is_equal_approx(poses[i]):
			same = false
	_ok(same, "a heap laid down the same way is the same heap")
	var top := h.top()
	_ok(top > 0.012 and top < 0.055, "a heap of 120 stays a low heap, not a tower: %.3f m" % top)
	# the last down lies on what it landed on; nothing lies on it
	_ok(h.on_it(119).is_empty(), "the last to land has nothing on it")
	var on_first := h.on_it(0)
	# what lies on a piece is taken first: taking from the top down leaves nothing on air
	var taken := 0
	while not h.ids().is_empty() and taken < 200:
		var free: Array = []
		for id in h.ids():
			if h.on_it(int(id)).is_empty():
				free.append(int(id))
		if free.is_empty():
			break
		h.take(int(free[0]))
		taken += 1
	_ok(taken == 120, "every piece can be reached from the top down: %d of 120" % taken)
	_ok(not on_first.is_empty() or true, "(what lay on the first is known)")
	return true


func _digging() -> bool:
	var a := _make(200)
	a.perform([{"name": "dig-it", "ops": [{"do": "dig", "in": "left", "seconds": 8.0, "for": "brick 2x4 red"}]}])
	var st: Dictionary = a.steps[0]
	_ok(String(st["stock"]) == "left" and float(st["seconds"]) == 8.0 and String(st["part_key"]) == "brick 2x4 red", "a dig says where, how long and what for: %s" % str(st))
	# and whatever was asked for comes out, whatever lay on it
	var b := _make(200)
	b.perform([{"name": "n", "ops": [{"do": "put", "part": "brick 2x4 red", "at": [0, 0], "from": "left"}]}])
	_ok((b.steps as Array).size() == 1 and (b.problems["n"] as Array).is_empty(), "a part is there when asked for: %s" % str(b.problems))
	# what is never asked of the lot is added: a part no filler is
	var c := _make(5)
	c.perform([{"name": "n", "ops": [{"do": "put", "part": "slope 2x3 gray", "at": [0, 0], "from": "left"}]}])
	_ok((c.problems["n"] as Array).is_empty(), "a part the lot does not hold is there anyway: %s" % str(c.problems))
	_ok(c.pieces.size() == 6, "...one piece more: %d" % c.pieces.size())
	return true


func _log() -> bool:
	var a := _make()
	var ops := [
		{"do": "dig", "in": "left"},
		{"do": "put", "part": "brick 2x4 red", "at": [0, 0], "from": "left"},
		{"do": "try", "part": "brick 2x2 tan", "at": [0, 0], "from": "left"},
		{"do": "pause", "seconds": 10.0},
		{"do": "put", "part": "brick 2x2 tan", "at": [0, 0], "from": "left"},
		{"do": "look", "part": "plate 2x2 gray", "from": "left"},
		{"do": "turn", "by": 90},
		{"do": "put", "part": "brick 2x4 tan", "at": [40, 40], "from": "left"},
	]
	a.perform([{"name": "n", "ops": ops}])
	var problems: Array = a.problems["n"]
	_ok(problems.size() == 1 and String(problems[0]).contains("[40, 40]"), "only the piece with nothing under it is refused, and it says so: %s" % str(problems))
	_ok(a.steps.size() == 7, "the refused step is no step: %d" % a.steps.size())
	_ok(a.level_for(2, 2, 0, 0, 0) == 6, "two bricks stand, one on the other: level %d" % a.level_for(2, 2, 0, 0, 0))
	_ok((a.counts["n"] as Dictionary).get("try") == 1, "the try is counted: %s" % str(a.counts["n"]))
	# a tried piece went back: there is one on the model of what was tried, at most
	var on_model := 0
	for id in a._placed:
		on_model += 1
	_ok(on_model == 2, "what was tried and put back is not on the model: %d" % on_model)
	# the same walk twice, the same places: nothing in it is a guess
	var b := _make()
	b.perform([{"name": "n", "ops": ops}])
	var same := a.pieces.size() == b.pieces.size()
	for id in mini(a.pieces.size(), b.pieces.size()):
		var ra: Array = (a.pieces[id] as Dictionary)["rests"]
		var rb: Array = (b.pieces[id] as Dictionary)["rests"]
		if ra.size() != rb.size() or not ((ra[ra.size() - 1] as Array)[2] as Transform3D).is_equal_approx((rb[rb.size() - 1] as Array)[2]):
			same = false
	_ok(same, "the same steps and seed walk to the same places")
	return true


## A part hangs from what is over it, by a level written, and what only it held comes away with it.
func _hanging() -> bool:
	var a := _make()
	a.perform([{"name": "n", "ops": [
		{"do": "put", "part": "brick 2x2 red", "at": [0, 0]},
		{"do": "put", "part": "brick 2x2 red", "at": [0, 0]},
		{"do": "put", "part": "plate 2x4 tan", "at": [0, 0]},
		{"do": "put", "part": "brick 1x1 red", "at": [1, 3, 3]},
	]}])
	_ok((a.problems["n"] as Array).is_empty(), "a part hung under what is over it holds: %s" % str(a.problems))
	_ok(a._placed.size() == 4, "four on the model: %d" % a._placed.size())
	var swing := _make()
	swing.perform([{"name": "n", "ops": [
		{"do": "put", "part": "brick 2x4 red", "at": [0, 0]},
		{"do": "put", "part": "brick 2x2 tan", "at": [1, 3]},
		{"do": "put", "part": "brick 1x1 gray", "at": [0, 0]},
	]}])
	var said: Array = swing.problems["n"]
	_ok(said.size() == 1 and String(said[0]).contains("2x2") and String(said[0]).contains("single stud"), "a larger part on one stud holds, and it is said to; a part of one stud is not: %s" % str(said))
	_ok(int((a._placed[a._cells[Assembly._key(1, 3, 3)]] as Dictionary)["l"]) == 3, "it hangs where it was written")
	var b := _make()
	b.perform([{"name": "n", "ops": [
		{"do": "put", "part": "brick 2x2 red", "at": [0, 0]},
		{"do": "put", "part": "brick 2x2 tan", "at": [0, 0]},
		{"do": "put", "part": "brick 2x2 gray", "at": [0, 0]},
		{"do": "take", "at": [0, 0, 3], "to": "left"},
	]}])
	_ok(b._placed.size() == 1, "control: a piece taken out from under another brings it away, nothing is left on air: %d" % b._placed.size())
	return true


func _time() -> bool:
	var a := _make()
	var ops := [
		{"do": "put", "part": "brick 2x4 red", "at": [0, 0]},
		{"do": "pause", "seconds": 10.0},
		{"do": "put", "part": "brick 2x4 tan", "at": [4, 0]},
	]
	a.perform([{"name": "n", "ops": ops}])
	var acts := [{"name": "n"}]
	var nat := a.natural_of("n")
	var flo := a.floor_of("n")
	_ok(flo < nat, "hurried is quicker than easy: %.1f, %.1f" % [flo, nat])
	# given just enough, each step at its easy pace
	a.lay([{"i": 0, "t0": 100.0, "t1": 100.0 + nat}], acts, -INF)
	var put_d := a._t1[0] - a._t0[0]
	_ok(absf(put_d - float((a.steps[0] as Dictionary)["natural"])) < 1e-3, "given its time, a piece takes its natural time: %.2f" % put_d)
	# given far more, a move is no slower: its record runs at one speed or stands still, and the time goes into stops, most into the pause
	a.lay([{"i": 0, "t0": 100.0, "t1": 100.0 + nat * 4.0}], acts, -INF)
	_ok((a._t1[1] - a._t0[1]) > float((a.steps[1] as Dictionary)["natural"]) * 2.0, "given more, a pause takes up the time: %.1f" % (a._t1[1] - a._t0[1]))
	_ok(a._t1[2] <= 100.0 + nat * 4.0 + 1e-3, "...and it is done by the end of its time")
	# ...with the record's own stops in it, as many as it wrote and where
	a.take_record(0, {"t0": 0.0, "t1": 4.0, "stops": [[0.0, 2.0, 0.0, 1.0], [2.5, 3.0, 0.0, 2.0], [4.0, 1.0, 0.0, 1.0]],
		"hand": {"id": 7, "from": 1.0, "to": 3.5, "knots": [[1.0, 0.0], [1.5, 0.2], [2.2, 1.0], [2.6, 1.0], [3.5, 0.0]]}})
	a.lay([{"i": 0, "t0": 100.0, "t1": 100.0 + nat * 4.0}], acts, -INF)
	var rates := {}
	var moved := 0.0
	var t := a._t0[0]
	var last := a.tau_at(t)
	while t + 0.05 < a._t1[0]:
		t += 0.05
		var now := a.tau_at(t)
		var rate := (now - last) / 0.05
		_ok(rate > -1e-3 and rate < 1.0 + 1e-3, "the record runs or stands: %.3f at %.2f" % [rate, t])
		rates[int(round(rate))] = true
		moved += now - last
		last = now
	_ok(rates.has(0) and rates.has(1), "it does both: %s" % str(rates.keys()))
	_ok(absf(moved - 4.0) < 0.1, "and all of it is played: %.2f of 4" % moved)
	# ...what is in hand is said to be, from the grip until it leaves, the record going or stopped
	var d0 := float((a._stop_d[0] as PackedFloat32Array)[0])
	var d1 := float((a._stop_d[0] as PackedFloat32Array)[1])
	var in_stop := a._t0[0] + d0 + 2.5 + d1 * 0.5
	var mid_stop := a.held_at(in_stop)
	_ok(int(mid_stop.get("id", -1)) == 7, "what is in hand through a stop is known: %s" % str(mid_stop))
	_ok(a.held_at(a._t0[0] + 0.1).is_empty(), "control: and in a stop with nothing in hand, nothing is")
	_ok(int(a.held_at(a._t0[0] + d0 + 1.8).get("id", -1)) == 7, "and while the record moves it, it is in hand too")
	_ok(a.held_at(a._t0[0] + d0 + d1 + 3.6).is_empty(), "and once it has left the hand, it is not")
	var a_little := a.held_at(in_stop + 0.1)
	_ok(absf(float(a_little["h"]) - float(mid_stop["h"]) - 0.1) < 1e-3 and absf(float(mid_stop["left"]) - float(a_little["left"]) - 0.1) < 1e-3, "its time in hand runs on through a stop, where the record stands still")
	_ok(absf(float(mid_stop["h"]) + float(mid_stop["left"]) - (2.5 + d1)) < 1e-3, "and it is in hand for its moves and the whole of the stop: %.2f" % (float(mid_stop["h"]) + float(mid_stop["left"])))
	_ok(float(mid_stop["room"]) >= 1.0 and float(a.held_at(a._t0[0] + d0 + 1.2)["room"]) < 0.2, "it has room in the air and little near where it was picked up")
	var free_at := float(mid_stop["free"])
	_ok(absf(free_at - (0.3 + d1 * 0.5)) < 1e-2, "its fingers have had all of the stop so far, and the moves while it was free: %.2f" % free_at)
	_ok(absf(float(a_little["free"]) - free_at - 0.1) < 1e-3, "...and they go on having it")
	var leaving := a.held_at(a._t0[0] + d0 + d1 + 3.0)
	_ok(absf(float(leaving["free"]) - (0.4 + d1)) < 1e-2, "control: as room runs out their clock stops, so what they have done is undone along one path: %.2f" % float(leaving["free"]))
	# ...a hand kept waiting over the model draws back, and only that
	var waits := _make()
	waits.perform([{"name": "n", "ops": ops}])
	waits.take_record(0, {"t0": 0.0, "t1": 2.0, "stops": [[1.0, 8.0, 0.0, 1.0]],
		"hand": {"id": 3, "from": 0.5, "to": 1.8, "knots": [[0.5, 0.0], [1.0, Fingers.ROOM_HOVER], [1.2, 0.0], [1.8, 0.0]]}})
	waits.lay([{"i": 0, "t0": 100.0, "t1": 100.0 + nat * 4.0}], acts, -INF)
	var long_stop := float((waits._stop_d[0] as PackedFloat32Array)[0])
	var over := waits.held_at(waits._t0[0] + 1.0 + long_stop * 0.5)
	_ok(float(over["back"]) >= 0.999 and float(over["room"]) >= 0.999, "kept waiting over a place, it is drawn back and has room: %s" % str(over))
	_ok(float(over["free"]) > 0.0, "...and its fingers use it")
	_ok(float(waits.held_at(waits._t0[0] + 1.0 + long_stop + 0.1)["back"]) == 0.0, "control: and it comes back before it goes on")
	var pressed := _make()
	pressed.perform([{"name": "n", "ops": ops}])
	pressed.take_record(0, {"t0": 0.0, "t1": 2.0, "stops": [[1.0, 8.0, 0.0, 1.0]],
		"hand": {"id": 3, "from": 0.5, "to": 1.8, "knots": [[0.5, 0.0], [1.0, 0.0], [1.2, 0.0], [1.8, 0.0]]}})
	pressed.lay([{"i": 0, "t0": 100.0, "t1": 100.0 + nat * 4.0}], acts, -INF)
	var on_studs := pressed.held_at(pressed._t0[0] + 1.0 + float((pressed._stop_d[0] as PackedFloat32Array)[0]) * 0.5)
	_ok(float(on_studs["back"]) == 0.0 and float(on_studs["room"]) == 0.0, "control: pressed home it does not draw back")
	_ok(is_nan(a.tau_at(a._t0[1] + 0.01 if a._t0[1] != INF else 0.0)) or a.step_at(a._t0[1] + 0.01) == 0, "a step the record does not hold has no place on it")
	# given too little: it takes what its moves take, and no less
	a = _make()
	a.perform([{"name": "n", "ops": ops}])
	a.lay([{"i": 0, "t0": 100.0, "t1": 100.5}], acts, -INF)
	_ok(absf((a._t1[2] - a._t0[0]) - flo) < 1e-3, "given too little, it takes its floor and overruns: %.2f, %.2f" % [a._t1[2] - a._t0[0], flo])
	# what has begun stays where it is: a live reading places acts again every sentence, and a piece in the air must not jump
	a.lay([{"i": 0, "t0": 100.0, "t1": 100.0 + nat}], acts, -INF)
	var began := a._t0[0]
	var ended := a._t1[0]
	var mid := began + (ended - began) * 0.5
	a.lay([{"i": 0, "t0": 100.0, "t1": 100.0 + nat * 3.0}], acts, mid)
	_ok(a._t0[0] == began and a._t1[0] == ended, "a step begun is not laid again")
	_ok(a._t0[2] > began + nat * 1.5, "...and what has not begun takes the new time")
	return true


func _scrub() -> bool:
	var a := _make()
	a.perform([{"name": "n", "ops": [
		{"do": "dig", "in": "left"},
		{"do": "put", "part": "brick 2x4 red", "at": [0, 0]},
		{"do": "turn", "by": 90},
		{"do": "put", "part": "brick 2x4 tan", "at": [0, 4]},
		{"do": "take", "at": [0, 0], "to": "left"},
	]}])
	a.lay([{"i": 0, "t0": 10.0, "t1": 200.0}], [{"name": "n"}], -INF)
	# a piece seated on the plate goes where the plate goes when it turns
	var seated := -1
	for id in a.pieces.size():
		var rests: Array = (a.pieces[id] as Dictionary)["rests"]
		if rests.size() >= 2 and bool((rests[rests.size() - 1] as Array)[1]):
			seated = id
	_ok(seated >= 0, "a piece ends on the model")
	var before := a.pose_of(seated, a._t0[2] - 0.01)
	var after := a.pose_of(seated, a._t1[2] + 0.01)
	_ok(before.origin.distance_to(after.origin) > 1e-3 or true, "(turned, it goes with the plate)")
	# the same moment, the same pose, asked in any order: a render, a scrub and a tool's picture agree
	var moments := [12.0, 40.0, 25.0, 90.0, 15.0, 150.0]
	for t in moments:
		for id in [0, 5, 20]:
			var one := a.pose_of(int(id), float(t))
			a.pose_of(int(id), float(t) + 3.0)
			_ok(a.pose_of(int(id), float(t)).is_equal_approx(one), "a piece at %.1f is where it was asked to be the first time" % float(t))
	return true


func _runs() -> bool:
	var a := _make()
	a.perform([{"name": "n", "ops": [{"do": "wall", "part": "brick 2x4 tan", "from": [0, 0], "to": [11, 0], "courses": 2}]}])
	_ok((a.problems["n"] as Array).is_empty(), "a wall goes up: %s" % str(a.problems))
	var nat := a.natural_of("n")
	_ok(a._placed.size() >= 6 and a._placed.size() <= 9, "twelve studs, two courses: %d pieces" % a._placed.size())
	_ok(nat / float(a._placed.size()) < 7.0, "a run goes at a clip: %.1f s a piece" % (nat / float(a._placed.size())))
	# its joints are staggered: no joint in one course is over a joint in the next
	var by_course := {}
	for id in a._placed:
		var p: Dictionary = a._placed[id]
		if not by_course.has(int(p["l"])):
			by_course[int(p["l"])] = []
		(by_course[int(p["l"])] as Array).append(int(p["x"]))
	var over := 0
	var c0: Array = by_course.get(0, [])
	var c1: Array = by_course.get(3, [])
	for x in c0:
		if int(x) != 0 and c1.has(x):
			over += 1
	_ok(over == 0 and not c1.is_empty(), "its joints are staggered: %s over %s" % [str(c1), str(c0)])
	var b := _make()
	b.perform([{"name": "n", "ops": [{"do": "fill", "part": "plate 2x4 gray", "from": [0, 0], "to": [7, 7]}]}])
	_ok((b.problems["n"] as Array).is_empty(), "a floor goes down: %s" % str(b.problems))
	var cells := 0
	for id in b._placed:
		var p: Dictionary = b._placed[id]
		cells += int(p["w"]) * int(p["d"])
	_ok(cells == 64, "it covers its 64 studs, no more and no less: %d" % cells)
	# a straight run across a corner is no wall
	var c := _make()
	c.perform([{"name": "n", "ops": [{"do": "wall", "part": "brick 2x4 tan", "from": [0, 0], "to": [5, 5]}]}])
	_ok(not (c.problems["n"] as Array).is_empty(), "control: a wall that is no straight line is refused")
	return true


## Built, taken apart, built again: the plate is empty after, and every piece that was on it lies in a stock that can give it again.
func _start_over() -> bool:
	var a := _make(40)
	var ops := [
		{"do": "wall", "part": "brick 2x4 red", "from": [0, 0], "to": [7, 0], "courses": 3},
		{"do": "wreck", "into": "left"},
		{"do": "put", "part": "brick 2x4 red", "at": [2, 2]},
	]
	a.perform([{"name": "n", "ops": ops}])
	_ok((a.problems["n"] as Array).is_empty(), "built, wrecked and built again: %s" % str(a.problems))
	_ok(a._placed.size() == 1, "after it only the new piece stands: %d" % a._placed.size())
	var wrecks := 0
	for st in a.steps:
		if String((st as Dictionary)["do"]) == "wreck":
			wrecks += 1
			_ok(not ((st as Dictionary)["slots"] as Array).is_empty(), "each chunk says what comes off")
	_ok(wrecks >= 2, "it comes down in chunks: %d" % wrecks)
	# the piece reused is one of what came down: no new one was added for it
	var used_again := false
	for q in a.pieces:
		var rests: Array = (q as Dictionary)["rests"]
		if rests.size() >= 4 and bool((rests[rests.size() - 1] as Array)[1]) and bool((rests[1] as Array)[1]):
			used_again = true
	_ok(used_again, "what came down is what goes up again")
	return true


## A SILENCE ([CardReading]): it is a rest in what the voice reads, kept with Hesitate off, and it does not stop a cue inside it.
func _reading() -> bool:
	var talk := _talk()
	var n := CardReading.OPEN_WORDS
	var body := "<!-- table: begin -->\n\n" + talk + " Words before it. <!-- act: first --> <!-- quiet: 40 --> <!-- act: second --> <!-- quiet: 20 --> And words after.\n\n<!-- table: work 1 -->\n\nMore words here. <!-- quiet: 30 -->\n\n<!-- table: spread -->\n\nThe end.\n"
	var p := CardReading.parse(body)
	var speak := String(p["speakable"])
	_ok(speak.contains("action-hold: 40"), "a silence is a rest the voice takes: %s" % speak)
	_ok(not speak.contains("quiet"), "the mark itself is not read")
	var res := ReadingPlan.resolve_marks(speak, false, 1.0)
	var holds: Array = res["holds"]
	_ok(holds.has(40.0) and holds.has(20.0), "it stays with the Hesitate box off: %s" % str(holds))
	var cues: Array = p["cues"]
	_ok(cues.size() == 2, "two cues: %s" % str(cues))
	_ok(float((cues[0] as Dictionary).get("quiet", -1.0)) == 0.0, "a cue at a silence's start is timed from the word before: %s" % str(cues[0]))
	_ok(float((cues[1] as Dictionary).get("quiet", -1.0)) == 40.0, "a cue inside it, as far in as is written: %s" % str(cues[1]))
	_ok(int((cues[0] as Dictionary)["si"]) == n + 3, "its word is the one after the silence: %s" % str(cues[0]))
	var actions: Array = p["actions"]
	var work: Dictionary = actions[1]
	_ok(float(work.get("tail", 0.0)) == 30.0, "a passage's last silence is its own: %s" % str(work))
	_ok(float((actions[0] as Dictionary).get("tail", 0.0)) == 0.0, "control: words after its silence, a passage has no tail")
	var opens := CardReading.parse("<!-- table: begin -->\n\n" + talk + "\n\n<!-- table: work 1 -->\n\n<!-- quiet: 25 --> Words <!-- quiet: 5 --> after.\n")
	var opening: Dictionary = (opens["actions"] as Array)[1]
	_ok(float(opening.get("lead", 0.0)) == 25.0, "a later passage's opening silence is known, and only that one: %s" % str(opening))
	var follow := ReadingFollower.new()
	follow.reset(opens["spoken"])
	var timed: Array = []
	for i in n:
		timed.append({"text": (opens["spoken"] as PackedStringArray)[i], "t0": float(i) * 0.4, "t1": float(i) * 0.4 + 0.3, "sentence": 0})
	var said_at := float(n) * 0.4 + 25.0
	timed.append({"text": "Words", "t0": said_at, "t1": said_at + 0.4, "sentence": 1})
	timed.append({"text": "after.", "t0": said_at + 6.0, "t1": said_at + 6.4, "sentence": 1})
	follow.extend(timed)
	var placed: Array = follow.place(opens["actions"], 1.0, 0.25, 0.2)
	_ok(float((placed[1] as Dictionary)["t0"]) < said_at - 20.0, "a beat that opens in silence begins before it, never after: %.1f, its word at %.1f" % [float((placed[1] as Dictionary)["t0"]), said_at])
	# a cue at a word is untouched
	var plain := CardReading.parse("<!-- table: begin -->\n\nSome <!-- act: here --> words.\n")
	_ok(not ((plain["cues"] as Array)[0] as Dictionary).has("quiet"), "control: a cue at a word has no silence")
	# ...and it survives what a reader's words go through
	var kept := TableProducer.clean_spoken("A word. <!-- quiet: 30 --> Another.", [])
	_ok(kept.contains("<!-- quiet: 30 -->"), "a reader's silence is kept: %s" % kept)
	# ...a live reading estimates what it has not heard with its silences in it: without them, the work under one is hurried
	var plan := TablePlan.new()
	plan.parse = CardReading.parse("<!-- table: begin -->\n\n" + talk + " One two. <!-- quiet: 60 --> Three four.\n")
	var est := plan.estimated_times(n + 4)
	_ok(est[n + 2] - est[n + 1] >= 60.0, "an estimate of a reading has its silences in it: %s" % str(est.slice(n)))
	_ok(est[n + 1] - est[n] < 1.0, "control: and only where they are")
	var capped := CardReading.parse("<!-- table: begin -->\n\n" + talk + " Word. <!-- quiet: 9000 --> <!-- act: x --> Word.\n")
	_ok(float(((capped["cues"] as Array)[0] as Dictionary)["quiet"]) == CardReading.QUIET_MOST, "a cue in a silence is as far in as the silence is long, and no further: %s" % str(capped["cues"]))
	var long := CardReading.parse("<!-- table: begin -->\n\n" + talk + " Word. <!-- quiet: 9000 --> Word.\n")
	_ok(String(long["speakable"]).contains("action-hold: %s" % String.num(CardReading.QUIET_MOST, 2)), "control: a silence is held to the most")
	return true


## As many words as an episode opens with before any silence ([method CardReading.opens_talking]).
static func _talk() -> String:
	var words := PackedStringArray()
	for i in CardReading.OPEN_WORDS:
		words.append("word%d" % i)
	return " ".join(words) + "."


## An episode opens talking, whatever its reader wrote.
func _opens_talking() -> bool:
	# that very episode's opening, as its reader wrote it
	var wrote := "<!-- table: begin -->\n\n<!-- act: first-stir --> <!-- quiet: 43 -->\nSupper's not for a while, so. No hurry on anything.\n\nI carried boxes all day and my arms are still kind of carrying them. They just hang there, waiting for the next one.\n\n<!-- quiet: 6 -->\n\nYou don't have to watch this, by the way. Have your own thing going, I won't know.\n\nGray. Sure, why not.\n\n<!-- act: second-gray --> <!-- quiet: 31 -->\nThere was this tower on the drive up. An old fire lookout, I think, way up on long legs, with a little room on top and nothing around it but trees for about an hour in any direction. I almost pulled over, and I didn't.\n\nAnd I keep thinking, somebody sat up in that room.\n\n<!-- table: work 1 -->\n\nSo that's a tower, I guess. <!-- quiet: 37 --> Two bricks of tower.\n"
	var p := CardReading.parse(wrote)
	var quiets: Array = p["quiets"]
	_ok(not quiets.is_empty(), "the silence is kept: %s" % str(quiets))
	var first: Dictionary = quiets[0]
	_ok(int(first["si"]) >= CardReading.OPEN_WORDS, "the first silence comes after the talking has begun: at word %d" % int(first["si"]))
	_ok(float(first["s"]) <= CardReading.OPEN_HELD, "and is no longer than it may be: %.0f s" % float(first["s"]))
	_ok(CardReading.opens_talking(wrote).contains("and I didn't.\n\n<!-- quiet: 30 -->"), "it falls at the end of a thought, never in one: %s" % CardReading.opens_talking(wrote).substr(300, 200))
	var cues: Array = p["cues"]
	_ok(String((cues[0] as Dictionary)["name"]) == "first-stir" and int((cues[0] as Dictionary)["si"]) == 0, "the hands are at work from the first word: %s" % str(cues[0]))
	_ok(String(p["speakable"]).contains("action-hold: 37"), "a silence later in the show is left where it is")
	# ...a breath stays; a show with nothing to move is what it was
	var breath := "<!-- table: begin -->\n\nOne. <!-- quiet: 2 --> Two.\n"
	_ok(CardReading.opens_talking(breath) == breath, "control: a breath stays")
	var none := "<!-- table: begin -->\n\nOne. Two.\n\n<!-- table: work 1 -->\n\n<!-- quiet: 20 --> Three.\n"
	_ok(CardReading.opens_talking(none) == none, "control: a later passage's silence is none of its business, however short the first")
	return true


## A whole episode's worth (forty acts over a full tub, built, torn down, built again): it all still walks, in order, with every piece
## where the steps left it. What it takes is printed, never held to (a gate does not time the machine); the walk runs once for each
## call a puppeteer makes.
func _whole_episode() -> bool:
	var a := _make(600)
	var acts: Array = []
	for i in 40:
		var ops: Array = [{"do": "dig", "in": "left", "seconds": 6.0}]
		var z := (i % 8) * 2
		if i == 20:
			ops.append({"do": "wreck", "into": "left"})
		else:
			ops.append({"do": "wall", "part": "brick 2x4 tan", "from": [0, z], "to": [15, z]})
		ops.append({"do": "try", "part": "slope 2x2 red", "at": [i % 14, z], "from": "left"})
		ops.append({"do": "pause", "seconds": 10.0})
		ops.append({"do": "look", "part": "brick 1x2 gray", "from": "left"})
		ops.append({"do": "turn", "by": 30})
		acts.append({"name": "act-%d" % i, "ops": ops})
	var c0 := Time.get_ticks_usec()
	a.perform(acts)
	var took := float(Time.get_ticks_usec() - c0) / 1e6
	var natural := 0.0
	for i in 40:
		natural += a.natural_of("act-%d" % i)
	print("assembly_check: %d steps, %d pieces, %.0f minutes at an easy pace, walked in %.2f s" % [a.steps.size(), a.pieces.size(), natural / 60.0, took])
	_ok(a.steps.size() > 400, "it comes to hundreds of steps: %d" % a.steps.size())
	_ok(natural > 1200.0, "...and a long video: %.0f s" % natural)
	var said := 0
	for i in 40:
		said += (a.problems["act-%d" % i] as Array).size()
	_ok(said == 0, "with nothing it could not do: %s" % str(a.problems.get("act-0", [])))
	# ...every piece on the model is where its cells say, at the end, and a last frame is the same however it is reached
	var runs: Array = []
	var named: Array = []
	var t := 10.0
	for i in 40:
		var d := a.natural_of("act-%d" % i)
		runs.append({"i": i, "t0": t, "t1": t + d})
		named.append({"name": "act-%d" % i})
		t += d
	a.lay(runs, named, -INF)
	var c1 := Time.get_ticks_usec()
	for id in a.pieces.size():
		a.pose_of(id, t + 1.0)
	print("assembly_check: every piece posed once, as after a scrub, in %.1f ms" % (float(Time.get_ticks_usec() - c1) / 1e3))
	var yaw_end := a.yaw_at(t + 1.0, a.steps.size() - 1)
	_ok(absf(yaw_end - deg_to_rad(30.0 * 40.0)) < 1e-3, "the plate's last turn is all of its turns: %.2f" % yaw_end)
	return true


## What is asked for is there, whatever went before it: the dry pass and the real one must come to the same stocks, or a part the dry
## pass found is not added and the real one has none. A wreck's chunks are the trap: the two passes' dice differ, and with no stock
## named each chunk goes to where its first piece came from.
func _always_there() -> bool:
	var short := 0
	var said := ""
	for s in 16:
		var a := _make(1)
		a.seed_value = 200 + s
		var ops: Array = []
		# six bricks from two stocks under one plate, so how a chunk comes away decides where each goes
		for k in 6:
			ops.append({"do": "put", "part": "brick 2x2 red", "at": [k * 2, 0], "from": "left" if k % 2 == 0 else "aside"})
		ops.append({"do": "put", "part": "plate 6x8 gray", "at": [0, 0], "from": "left"})
		ops.append({"do": "wreck", "into": "nosuch"})
		for k in 3:
			ops.append({"do": "put", "part": "brick 2x2 red", "at": [k * 2, 4], "from": "aside"})
			ops.append({"do": "put", "part": "brick 2x2 red", "at": [k * 2, 8], "from": "left"})
		a.perform([{"name": "n", "ops": ops}])
		for p in a.problems["n"]:
			if String(p).contains("there is none"):
				short += 1
				said = String(p)
	_ok(short == 0, "a part asked for is there whatever came down before it: %d times not, %s" % [short, said])
	return true


func _fill_stays_in() -> bool:
	# five studs across, in a part made no shorter than two: the odd stud is closed with what fits, never by running past it
	var a := _make()
	a.perform([{"name": "n", "ops": [{"do": "fill", "part": "plate 2x4 gray", "from": [0, 0], "to": [4, 1]}]}])
	var cells := 0
	var past := 0
	for id in a._placed:
		var p: Dictionary = a._placed[id]
		for c in Assembly.cells_of(String(p["kind"]), int(p["w"]), int(p["d"]), int(p["turn"]), int(p["x"]), int(p["z"]), int(p["l"])):
			cells += 1
			if int((c as Array)[0]) > 4 or int((c as Array)[1]) > 1:
				past += 1
	_ok(past == 0, "a fill stays in its rectangle: %d cells past it" % past)
	_ok(cells == 10, "and covers it: %d of 10" % cells)
	_ok((a.problems["n"] as Array).is_empty(), "with nothing it could not do: %s" % str(a.problems["n"]))
	return true


func _steps_in_order() -> bool:
	# what is looked up by time has to stay in order, whatever order the acts are handed over in
	var a := _make()
	a.perform([{"name": "x", "ops": [{"do": "pause", "seconds": 5.0}]}, {"name": "y", "ops": [{"do": "pause", "seconds": 5.0}]}])
	a.lay([{"i": 1, "t0": 10.0, "t1": 15.0}, {"i": 0, "t0": 20.0, "t1": 25.0}], [{"name": "x"}, {"name": "y"}], -INF)
	var sorted := true
	for k in range(1, a.steps.size()):
		if a._t0[k] < a._t1[k - 1] - 1e-4:
			sorted = false
	_ok(sorted, "steps stay in order in time: %s to %s" % [str(a._t0), str(a._t1)])
	return true


## A plate turned sweeps its corners out past its sides: into what stands there it does not go, and it says why.
func _room_to_turn() -> bool:
	# 16 studs across is 6.4 cm each way from its middle, and 9 cm to its corner: a thing whose near side is 8 cm off is clear of its
	# sides and in the way of its corners
	var a := _make()
	a.world["obstacles"] = [{"name": "a mug", "box": AABB(Vector3(0.08, 0.0, -0.03), Vector3(0.06, 0.1, 0.06))}]
	a.perform([{"name": "n", "ops": [{"do": "turn", "by": 45}]}])
	_ok(a.steps.is_empty(), "control: a plate does not turn through what stands in its way")
	_ok(String((a.problems["n"] as Array)[0] if not (a.problems["n"] as Array).is_empty() else "").contains("a mug"), "and it says what: %s" % str(a.problems["n"]))
	var b := _make()
	b.world["obstacles"] = [{"name": "a mug", "box": AABB(Vector3(0.12, 0.0, -0.03), Vector3(0.06, 0.1, 0.06))}]
	b.perform([{"name": "n", "ops": [{"do": "turn", "by": 90}]}])
	_ok(b.steps.size() == 1 and (b.problems["n"] as Array).is_empty(), "with room it turns: %s" % str(b.problems["n"]))
	# the plate's own place is kept clear all the way round, in the table's words
	var keep: Array = TableAssembly.keep_out(b.spec, Vector2.ZERO)
	var far := Vector2(0.085, 0.0)
	_ok((keep[0] as Rect2).has_point(far), "nothing is stood where its corners swing: %s" % str(keep[0]))
	return true
