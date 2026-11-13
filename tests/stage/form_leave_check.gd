extends SceneTree

## form_leave_check - ten prisms forming one large tetrahedron as a squadron and holding it, and members leaving the
## frame ([Actions.Form], [Actions.Leave]).
##
##   godot --headless --path . --script res://tests/stage/form_leave_check.gd
##
## What it holds, on ten prisms scattered at their own headings and a stage made here that steps as the real one
## does (verbs, then the bodies, then [method Actions.hold]):
##   - the lattice: ten places are a tetrahedron's corners and edge midpoints - none at its middle - four, its
##     corners alone, and one, its center;
##   - formed: each member at its place, all turned to the shape's one heading (a prism's own frame), each sized to
##     the spacing, so every pair of neighbors meets corner to corner as they are drawn (24 meetings for ten);
##   - latched: with the verb finished, the shape goes on turning as one rigid body (its places measured with the
##     drawn squash taken out), still aligned;
##   - carried on: a second `form` of the same shape starts where the first holds it, with no jump, and stays rigid;
##   - leave: thrown or drifting, a member ends past the frame's edge and hidden, out of the formation, the others
##     still in it; unset, it goes away from the others. Toward the camera it comes nearer and grows, yet is never
##     seen nearer the lens than [constant Actions.Leave.NEAREST] - a straight dive at the lens is turned aside too;
##     away from it, it shrinks and is faded out by its window's end while still inside the frame;
##   - the show's dissolve (data/showcase.json's last two entries, run through their tracks): every actor is hidden by
##     its entry's end, the last red by the end of its own; and, run on from the composite it breaks (the entry before,
##     its actors carried across), every leaving prism, once launched and turned, draws its apex along the exact 3D
##     way it goes (cosine above 0.99), in depth too;
##   - the controls: before the verb the ten are not aligned; unfitted, no neighbors meet; a member that left is not
##     where the shape would hold it; a straight dive at the lens is seen inside the nearest; the way into the distance
##     without its fade is still on the frame at its end; on the flights in depth, a heading flattened onto the screen
##     is told apart from the 3D way.

const DT := 1.0 / 30.0
const HALF := Vector2(0.889, 0.5)
const SIZE := 1.2

var _fails := 0


class FakeStage extends RefCounted:
	var lens := Lens3D.new()
	var cast := {}
	var flashes := 0

	func _init() -> void:
		lens.eye = Vector3(0, 0, 5.0)
		lens.fov = 48.0
		lens.prepare()

	func actor(id: String):
		return cast.get(id)

	func actors() -> Array:
		return cast.values()

	func view_half() -> Vector2:
		return Vector2(0.889, 0.5)

	func tie(_a, _b) -> void:
		pass

	func flash(_a, _c: Color) -> void:
		flashes += 1

	func spatter(_p: Vector3, _n: int, _rng: RandomNumberGenerator, _c := Color.WHITE) -> void:
		pass


func _initialize() -> void:
	# the lattice
	var ten: Array = Actions.Form.slots("tetra", 10, 1.0)
	var middle := 1e9
	for p in ten:
		middle = minf(middle, (p as Vector3).length())
	_ok(ten.size() == 10 and middle > 0.2, "ten places, none at the shape's middle (nearest %.3f)" % middle)
	var one: Array = Actions.Form.slots("tetra", 1, 1.0)
	_ok(one.size() == 1 and (one[0] as Vector3).length() < 1e-6, "one alone has its place at the shape's center")
	var four: Array = Actions.Form.slots("tetra", 4, 1.0)
	_ok(four.size() == 4 and is_equal_approx(Actions.Form.spacing("tetra", 4, 1.0), 1.0)
		and is_equal_approx(Actions.Form.spacing("tetra", 10, 1.0), 0.5), "four are the corners alone; ten are half an edge apart")

	var stage := _stage(true)
	var members: Array = stage.actors()
	var f := AudioFeatures.new()
	_ok(_spread(members) > 0.3, "the control: before the verb the ten point their own ways (spread %.3f)" % _spread(members))

	var args := {"shape": "tetra", "size": SIZE, "center": [0, 0, 0], "tilt": 18.0, "turn": 6.0}
	var form := Actions.make("form", args, _rng(11))
	_run(stage, form, members, f, 60)
	var fm: Dictionary = members[0].state["form"]
	var off := 0.0
	for a in members:
		off = maxf(off, a.pos.distance_to(Actions.Form.place(a.state["form"], float(fm["angle"]))))
	_ok(off < 1e-4, "formed: each member at its place (off by %.6f)" % off)
	_ok(_spread(members) < 1e-3, "formed: all ten turned to one heading (spread %.6f)" % _spread(members))
	var want := Basis(Actions.FLIP * Actions.Form.frame(float(fm["tilt"]), float(fm["angle"])) * Actions.FLIP)
	_ok(_angle(Basis.from_euler((members[0].body as PrismBody).rot), want) < 1e-3,
		"formed: the heading is the shape's own, so each member is a small copy of the whole")
	var fitted := Actions.Form.spacing("tetra", 10, SIZE) / Actions.Form.EDGE
	_ok(members.all(func(a) -> bool: return is_equal_approx(a.scale, fitted)), "formed: each member sized to the spacing (%.3f)" % fitted)
	var met := _meetings(members, fm)
	_ok(met == 24, "formed: every pair of neighbors meets corner to corner as drawn (%d of 24)" % met)
	_ok(stage.flashes == 10, "formed: each member glints once as it locks in (%d)" % stage.flashes)

	# the control: unfitted, they keep their own size and never meet
	var loose := _stage(false)
	var lf := Actions.make("form", args.merged({"fit": false}), _rng(11))
	_run(loose, lf, loose.actors(), f, 60)
	_ok(_meetings(loose.actors(), loose.actors()[0].state["form"]) == 0, "the control: unfitted, no neighbors meet")

	# latched: the verb is done, the stage goes on holding and turning it
	var was: Array = members.map(func(a) -> Vector3: return a.pos)
	var d01 := _apart(members[0], members[4])
	for i in 45:
		_step(stage, f)
	var moved := 0.0
	for i in members.size():
		moved = maxf(moved, members[i].pos.distance_to(was[i]))
	_ok(moved > 0.05, "latched: the shape goes on turning once the verb is done (moved %.3f)" % moved)
	_ok(absf(_apart(members[0], members[4]) - d01) < 1e-4 and _spread(members) < 1e-3,
		"latched: it turns as one rigid body, still aligned")

	# carried on: the same shape again starts where it stands
	var before: Array = members.map(func(a) -> Vector3: return a.pos)
	var flashed := stage.flashes
	var again := Actions.make("form", args.merged({"turn": 18.0}), _rng(12))
	again.begin(stage, members)
	again.apply(stage, members, 0.0, f, DT)
	var jump := 0.0
	for i in members.size():
		jump = maxf(jump, Actions.Form.held_pos(members[i].state["form"]).distance_to(before[i]))
	_ok(jump < 0.02, "carried on: a second form of the same shape starts where the first holds it (jump %.4f)" % jump)
	var rigid := 0.0
	for i in 30:
		again.apply(stage, members, float(i + 1) / 30.0, f, DT)
		_step(stage, f)
		rigid = maxf(rigid, absf(_apart(members[0], members[4]) - d01))
	again.finish(stage, members)
	_ok(rigid < 1e-4 and _spread(members) < 1e-3 and stage.flashes == flashed,
		"carried on: it stays one rigid body while its turning speeds up, and locks in no second time")

	# leave: one thrown, one drifting; the rest stay in the shape
	var thrown = members[0]
	var drifting = members[1]
	_ok(_on_frame(stage, thrown), "the control: before it leaves, it is on the frame")
	var start: Vector3 = thrown.pos
	var mid := Vector3.ZERO
	for a in members.slice(1):
		mid += a.pos
	mid /= 9.0
	_run(stage, Actions.make("leave", {"force": 1.0}, _rng(13)), [thrown], f, 30)
	_ok(not _on_frame(stage, thrown) and thrown.fade == 0.0, "thrown: past the frame's edge and hidden")
	_ok((thrown.pos - start).dot(start - mid) > 0.0, "thrown: away from the others")
	_ok(not (thrown.state.get("form") is Dictionary), "thrown: out of the formation")
	_run(stage, Actions.make("leave", {"force": 0.0, "to": [1, 0, 0]}, _rng(14)), [drifting], f, 60)
	_ok(not _on_frame(stage, drifting) and drifting.pos.x > 0.5, "drifting: out the way it was told, and hidden")
	var rest: Array = members.slice(2)
	var dd := _apart(rest[0], rest[1])
	for i in 30:
		_step(stage, f)
	_ok(absf(_apart(rest[0], rest[1]) - dd) < 1e-4 and _spread(rest) < 1e-3, "the others are still in the shape")
	_ok(thrown.pos.distance_to(Actions.Form.place(fm, float(rest[0].state["form"]["angle"]))) > 1.0,
		"the control: the member that left is not where the shape would hold it")

	_depth(f)
	_dissolve(f)
	_headings(f)
	print("form_leave_check: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(1 if _fails > 0 else 0)


## Leaving in depth: toward the camera, a straight dive at it, and away into the distance.
func _depth(f: AudioFeatures) -> void:
	var near := Actions.Leave.NEAREST
	for way in [[0.3, 0.1, 0.95], [0.0, 0.0, 1.0]]:
		var stage := FakeStage.new()
		stage.cast["p"] = Cast.make("prism", _rng(21), {"id": "p", "at": [0.3, -0.1, 0.0], "scale": 0.3})
		var p = stage.cast["p"]
		var size0 := _size(stage, p)
		var leave := Actions.make("leave", {"to": way, "force": 0.6}, _rng(22))
		leave.begin(stage, [p])
		var seen_near := INF
		var nearest := INF
		var grew := 0.0
		for i in 30:
			leave.apply(stage, [p], float(i + 1) / 30.0, f, DT)
			_step(stage, f)
			var depth: float = stage.lens.project(p.pos).z
			nearest = minf(nearest, depth)
			if p.fade > 0.0 and _on_frame(stage, p):
				seen_near = minf(seen_near, depth)
				grew = maxf(grew, _size(stage, p) / size0)
		leave.finish(stage, [p])
		_ok(nearest < 4.5 and grew > 1.2 and seen_near >= near and p.fade == 0.0,
			"toward the camera %s: it comes nearer (to %.2f) and grows (x%.2f), seen no nearer than %.2f (the least %.1f), then hidden" % [str(way), nearest, grew, seen_near, near])
	# the control: a straight dive at the lens, unturned, is still on the frame inside the nearest
	var lens := FakeStage.new().lens
	var dived := false
	for i in 50:
		var at := Vector3(0.3, -0.1, 0.0) + Vector3(0, 0, 1) * (0.1 * i)
		var pj := lens.project(at)
		dived = dived or (pj.z < near and pj.z > lens.near and absf(pj.x) < HALF.x and absf(pj.y) < HALF.y)
	_ok(dived, "the control: a straight dive at the lens, unturned, is seen inside the nearest")
	# away: it shrinks and is faded out by its window's end, still inside the frame
	var stage := FakeStage.new()
	stage.cast["p"] = Cast.make("prism", _rng(23), {"id": "p", "at": [0.3, -0.1, 0.0], "scale": 0.3})
	var p = stage.cast["p"]
	var size0 := _size(stage, p)
	var leave := Actions.make("leave", {"to": [0.2, 0.3, -0.93], "force": 0.3}, _rng(24))
	leave.begin(stage, [p])
	var mid_fade := 0.0
	for i in 40:
		leave.apply(stage, [p], float(i + 1) / 40.0, f, DT)
		_step(stage, f)
		if i == 19:
			mid_fade = p.fade
	_ok(mid_fade > 0.9 and p.fade == 0.0 and _size(stage, p) < size0 * 0.6,
		"away: it shrinks (to x%.2f) and fades out by its window's end (%.2f halfway, %.2f at the end)" % [_size(stage, p) / size0, mid_fade, p.fade])
	_ok(_on_frame(stage, p), "the control: without its fade it would still be on the frame at its end")
	leave.finish(stage, [p])


## The show's dissolve - data/showcase.json's last two entries, each run through its own track on a stage made here
## at its camera: every actor is hidden by its entry's end (one still showing at a cut it is not carried across would
## vanish there).
func _dissolve(f: AudioFeatures) -> void:
	var sb := Storyboard.load_file("res://data/showcase.json")
	var seq: Array = sb["sequence"]
	var left: Array = []
	for n in [seq.size() - 2, seq.size() - 1]:
		var e: Dictionary = seq[n]
		var stage := FakeStage.new()
		stage.lens.eye = Storyboard.sample_vec3((e["camera"] as Dictionary).get("eye"), _rng(1), Vector3(0, 0, 4))
		stage.lens.prepare()
		var rng := _rng(30 + n)
		for c in e["cast"]:
			stage.cast[String(c["id"])] = Cast.make(String(c["kind"]), rng, c)
		var track := Track.new(e["track"], rng)
		var hold := float(e["hold"])
		var t := 0.0
		while t + DT < hold:
			t += DT
			track.advance(t, hold, stage, f, DT)
			_step(stage, f)
		for a in stage.actors():
			if a.fade > 0.01 and not (n == seq.size() - 2 and a.id == "red"):
				left.append("%s (entry %d, %.2f)" % [a.id, n + 1, a.fade])
	_ok(left.is_empty(), "the dissolve: every actor ends hidden, the last red after its own exit %s" % ("" if left.is_empty() else str(left)))


## The show's break-up as seen: the composite formed (the entry before the dissolve), then the dissolve's track as
## written, its actors carried across as a cut carries them, on a stage at each entry's camera. Each leaving prism, on
## every frame after its launch and turn while it is shown: its apex as it is drawn, in 3D (the prism's own corner,
## its height at 0.8), against the way it goes; and, for a flight in depth, the same for a heading flattened onto the
## screen.
func _headings(f: AudioFeatures) -> void:
	var sb := Storyboard.load_file("res://data/showcase.json")
	var seq: Array = sb["sequence"]
	var stage := FakeStage.new()
	var rng := _rng(40)
	var dt := 1.0 / 15.0
	var formed: Dictionary = seq[seq.size() - 3]
	var broken: Dictionary = seq[seq.size() - 2]
	for c in formed["cast"]:
		stage.cast[String(c["id"])] = Cast.make(String(c["kind"]), rng, c)
	var flights := {}
	for sp in broken["track"]["spans"]:
		if String(sp["action"]) == "leave":
			var force := float((sp["args"] as Dictionary).get("force", 0.5))
			# launched at the wind-up's end, turned to its way a little after ([method Actions.Leave.apply])
			var t0 := float(sp["from"]) + 1.3 * lerpf(0.24, 0.12, force) * (float(sp["to"]) - float(sp["from"])) + 1.5 * dt
			var way := Storyboard.sample_vec3((sp["args"] as Dictionary).get("to"), rng, Vector3.ZERO)
			flights[String(sp["target"])] = {"t0": t0, "t1": float(sp["to"]), "way": way.normalized(), "cos": 1.0, "flat": 1.0, "n": 0}
	for e in [formed, broken]:
		stage.lens.eye = Storyboard.sample_vec3((e["camera"] as Dictionary).get("eye"), _rng(1), Vector3(0, 0, 4))
		stage.lens.prepare()
		var track := Track.new(e["track"], rng)
		var hold := float(e["hold"])
		var t := 0.0
		while t + dt < hold:
			t += dt
			track.advance(t, hold, stage, f, dt)
			for a in stage.actors():
				a.update(f, dt, stage)
			for a in stage.actors():
				Actions.hold(a, dt)
			if e != broken:
				continue
			for id in flights:
				var a = stage.cast[id]
				var fl: Dictionary = flights[id]
				if t < float(fl["t0"]) or t > float(fl["t1"]) or a.fade <= 0.01 or not _on_frame(stage, a):
					continue
				var way: Vector3 = fl["way"]
				fl["cos"] = minf(float(fl["cos"]), _drawn_3d(Basis.from_euler((a.body as PrismBody).rot)).dot(way))
				if absf(way.z) > 0.5:          # in depth
					var flat := Vector3(way.x, way.y, 0.0).normalized()
					fl["flat"] = minf(float(fl["flat"]), _drawn_3d(Basis(Actions.travelling(flat))).dot(way))
				fl["n"] = int(fl["n"]) + 1
	var bad: Array = []
	var deep: Array = []
	for id in flights:
		var fl: Dictionary = flights[id]
		if int(fl["n"]) < 3 or float(fl["cos"]) < 0.99:
			bad.append("%s (%d frames, cosine %.3f)" % [id, int(fl["n"]), float(fl["cos"])])
		if float(fl["flat"]) < 1.0:
			deep.append(float(fl["flat"]))
	_ok(bad.is_empty() and flights.size() >= 9,
		"the break-up: all %d leaving prisms draw their apex along the exact way they go, in depth too %s" % [flights.size(), "" if bad.is_empty() else str(bad)])
	_ok(not deep.is_empty() and deep.all(func(x: float) -> bool: return x < 0.9),
		"the control: headed flat to the screen, the flights in depth point off their way %s" % str(deep.map(func(x: float) -> String: return "%.2f" % x)))


## The direction a prism of frame [param b] draws its apex in, in 3D (right, up, toward the camera): its own corner
## ([constant PrismBody.APEX], y down) with its height drawn at 0.8.
func _drawn_3d(b: Basis) -> Vector3:
	var c: Vector3 = b * PrismBody.APEX
	return Vector3(c.x, -c.y * 0.8, c.z).normalized()


## Where a prism of frame [param b] draws its apex from its center, in its size ([method PrismBody.draw]).
func _drawn_apex(b: Basis) -> Vector2:
	var c: Vector3 = b * PrismBody.APEX
	var persp := 2.0 / (2.0 - c.z * 0.3)
	return Vector2(c.x * persp, c.y * persp * 0.8)


## [param tip]'s length against the length a side-on apex has that way on the screen (its height drawn at 0.8).
func _against_side_on(tip: Vector2) -> float:
	var u := tip.normalized()
	return tip.length() / (0.5 * sqrt(u.x * u.x + 0.64 * u.y * u.y))


## How large [param a] is drawn, in the lens's unit fractions.
func _size(stage: FakeStage, a) -> float:
	var pj := stage.lens.project(a.pos)
	return a.scale * stage.lens._focal / maxf(0.1, pj.z)


## Ten prisms scattered about a stage made here, each at its own heading.
func _stage(_fit: bool) -> FakeStage:
	var stage := FakeStage.new()
	var rng := _rng(7)
	for i in 10:
		var id := "p%d" % i
		var at := [rng.randf_range(-1.2, 1.2), rng.randf_range(-0.8, 0.8), 0.0]
		stage.cast[id] = Cast.make("prism", rng, {"id": id, "at": at, "scale": 0.25})
	return stage


## How many pairs of neighboring members have a corner of one where a corner of the other is drawn: a prism is
## drawn as its corners turned by its heading, sized by its scale and squashed as [constant Actions.Form.SQUASH].
func _meetings(members: Array, fm: Dictionary) -> int:
	var basis := Actions.Form.frame(float(fm["tilt"]), float(fm["angle"]))
	var gap := Actions.Form.spacing("tetra", members.size(), SIZE)
	var corners: Array = []
	for a in members:
		var c: Array = []
		for v in PrismBody.VERTS:
			var w: Vector3 = a.pos + Actions.Form.SQUASH * (basis * (Actions.FLIP * (v as Vector3))) * (a.scale * Actions.Form.EDGE)
			c.append(Vector2(w.x, w.y))
		corners.append(c)
	var met := 0
	for i in members.size():
		for j in range(i + 1, members.size()):
			var oi: Vector3 = members[i].state["form"]["offset"]
			var oj: Vector3 = members[j].state["form"]["offset"]
			if absf(oi.distance_to(oj) - gap) > 0.02 and absf(oi.distance_to(oj) - gap * 1.155) > 0.02:
				continue
			var touch := false
			for x in corners[i]:
				for y in corners[j]:
					touch = touch or (x as Vector2).distance_to(y) < 1e-3
			met += 1 if touch else 0
	return met


## How far apart two members of a formation are in the shape itself: their places with the drawn squash taken out,
## which a rigid turn keeps.
func _apart(a, b) -> float:
	var c: Vector3 = a.state["form"]["center"]
	return ((a.pos - c) / Actions.Form.SQUASH).distance_to((b.pos - c) / Actions.Form.SQUASH)


## A verb run over [param frames] frames as a track runs it, the stage stepping after each.
func _run(stage: FakeStage, verb: Actions.Action, who: Array, f: AudioFeatures, frames: int) -> void:
	verb.begin(stage, who)
	for i in frames:
		verb.apply(stage, who, float(i + 1) / float(frames), f, DT)
		_step(stage, f)
	verb.finish(stage, who)


## One frame of the stage after its verbs: the bodies advance, then formations hold.
func _step(stage: FakeStage, f: AudioFeatures) -> void:
	for a in stage.actors():
		a.update(f, DT, stage)
	for a in stage.actors():
		Actions.hold(a, DT)


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


## The widest gap between any member's heading and the first's.
func _spread(who: Array) -> float:
	var b0 := Basis.from_euler((who[0].body as PrismBody).rot)
	var worst := 0.0
	for a in who:
		worst = maxf(worst, _angle(b0, Basis.from_euler((a.body as PrismBody).rot)))
	return worst


## How far apart two headings are: the widest gap between their axes (about the angle, for a small one; a
## quaternion's angle_to bottoms out near 7e-4 in single precision).
func _angle(x: Basis, y: Basis) -> float:
	return maxf((x.x - y.x).length(), maxf((x.y - y.y).length(), (x.z - y.z).length()))


func _on_frame(stage: FakeStage, a) -> bool:
	var pj := stage.lens.project(a.pos)
	return absf(pj.x) < HALF.x and absf(pj.y) < HALF.y


func _ok(cond: bool, what: String) -> void:
	print(("ok    " if cond else "FAIL  ") + what)
	if not cond:
		_fails += 1
