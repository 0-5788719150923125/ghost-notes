extends SceneTree

## prism_motion_check - how a prism divides, arrives and leaves ([Actions.Split]'s clone, [Actions.Arrive],
## [Actions.Leave]).
##
##   godot --headless --path . --script res://tests/stage/prism_motion_check.gd
##
## What it holds, on a stage made here that steps as the real one does (verbs, then the bodies):
##   - the clone: the twin is born the parent's size, pose and place, in its own hue, and moves with the parent's
##     every turn until the tear; after a moment in place the pull reaches the bond's limit quickly, tugs back and forth there, tears a fixed
##     time before the window ends and springs past its place before settling on it - at windows of 1.5, 2.4 and
##     3.6 seconds alike;
##   - arrive: apex first along its way, past its place and back, still pointing the way it flew - no pivot in the
##     first 0.3 s after the hit - then righting itself slowly once landed: upright by the end of its righting time
##     and still upright half a second on; a clone born while it rights turns exactly as it does until the tear, and
##     the parent goes on to upright;
##   - leave: it draws back first, turns apex first, then goes faster and faster until it is off the frame and hidden;
##   - what the viewer sees: in flight, the apex as the prism draws it leads its motion on the screen (both through
##     the stage's lens: the cosine of center-to-apex with the screen velocity above 0.7 on every flying frame).
##   - the controls: the quick pull to the limit never turns back; after the tear the twin no longer turns as the
##     parent does; the turn to its pose within the landing (as arrive once did) fails the no-pivot measure; a
##     righting too slow to finish is not upright in time; the same screen measure with the apex flipped fails.

const DT := 1.0 / 30.0

var _fails := 0


class FakeStage extends RefCounted:
	var lens := Lens3D.new()
	var cast := {}

	func _init() -> void:
		lens.eye = Vector3(0, 0, 4.0)
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
		pass

	func spatter(_p: Vector3, _n: int, _rng: RandomNumberGenerator, _c := Color.WHITE) -> void:
		pass


func _initialize() -> void:
	var f := AudioFeatures.new()
	for secs in [1.5, 2.4, 3.6]:
		_clone(secs, f)
	_arrive(f)
	_righting_clone(f)
	_leave(f)
	print("prism_motion_check: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(1 if _fails > 0 else 0)


func _clone(secs: float, f: AudioFeatures) -> void:
	var stage := FakeStage.new()
	var rng := _rng(3)
	stage.cast["blue"] = Cast.make("prism", rng, {"id": "blue", "at": [0, 0, 0], "scale": 0.38, "hue": 0.6})
	stage.cast["red"] = Cast.make("prism", rng, {"id": "red", "at": [0.5, 0, 0], "hue": 0.6, "hidden": true})
	var blue = stage.cast["blue"]
	var red = stage.cast["red"]
	var split := Actions.make("split", {"into": "red", "hue": 0.0, "slots": [[-0.5, 0, 0], [0.5, 0, 0]]}, _rng(5))
	split.begin(stage, [blue])
	var tag := "%.1f s:" % secs
	_ok(is_equal_approx(red.scale, blue.scale) and is_equal_approx(red.hue, 0.0) and red.pos == blue.pos
		and (red.body as PrismBody).rot == (blue.body as PrismBody).rot,
		"%s the twin is born the parent's size, pose and place, in its own hue" % tag)
	var frames := int(round(secs / DT))
	var seps: Array = []
	var snap_at := -1.0
	var twin_off := 0.0
	for i in frames:
		split.apply(stage, [blue], float(i + 1) / float(frames), f, DT)
		for a in stage.actors():
			a.update(f, DT, stage)
		var torn := float(blue.state["mit"]["snap"]) >= 0.0
		if torn and snap_at < 0.0:
			snap_at = float(i + 1) * DT
		if not torn:
			twin_off = maxf(twin_off, (red.body as PrismBody).rot.distance_to((blue.body as PrismBody).rot))
		seps.append(red.pos.distance_to(blue.pos))
	_ok(twin_off < 1e-5, "%s until the tear the twin turns exactly as the parent does" % tag)
	var settle := minf(Actions.Split.SETTLE_S, secs * 0.35)
	var ramp := minf(Actions.Split.LEAD_S, secs * 0.12) + minf(Actions.Split.RAMP_S, secs * 0.25)
	_ok(absf(snap_at - (secs - settle)) <= DT * 1.5, "%s it tears %.2f s before the end (at %.2f s)" % [tag, settle, snap_at])
	var n_ramp := int(ramp / DT)
	var n_snap := int(snap_at / DT)
	_ok(_turns(seps.slice(0, n_ramp)) == 0 and float(seps[n_ramp - 1]) > 0.6,
		"%s the control: the quick pull reaches the bond's limit without turning back (%.2f apart)" % [tag, seps[n_ramp - 1]])
	var tugs := _turns(seps.slice(n_ramp, n_snap - 1))
	_ok(tugs >= (1 if secs < 2.0 else 3), "%s at the limit it tugs back and forth (%d turns)" % [tag, tugs])
	var past := 0.0
	for d in seps.slice(n_snap):
		past = maxf(past, float(d))
	_ok(past > 1.02, "%s after the tear each springs past its place (%.3f apart at most, 1 at rest)" % [tag, past])
	split.finish(stage, [blue])
	_ok(is_equal_approx(red.pos.distance_to(blue.pos), 1.0) and red.fade == 1.0, "%s and settles on it" % tag)
	for i in 10:
		for a in stage.actors():
			a.update(f, DT, stage)
	_ok((red.body as PrismBody).rot.distance_to((blue.body as PrismBody).rot) > 0.01,
		"%s the control: after the tear the twin turns on its own" % tag)


func _arrive(f: AudioFeatures) -> void:
	var stage := FakeStage.new()
	stage.cast["p"] = Cast.make("prism", _rng(4), {"id": "p", "at": [0, 0, 0], "scale": 0.38, "hidden": true})
	var p = stage.cast["p"]
	var arrive := Actions.make("arrive", {"from": [3.0, 2.0, 0.0], "upright": 2.0}, _rng(6))
	arrive.begin(stage, [p])
	var way := Vector3(-3.0, -2.0, 0.0).normalized()
	var frames := 66
	var led := 1.0
	var past := 0.0
	var kept := 1.0                   # the least apex-along-the-way in the first 0.3 s after the hit
	var hit := int(Actions.Arrive.APPROACH * frames)
	var seen := Vector2(1.0, 1.0)     # the least screen cosine, as drawn and flipped
	var was := Vector2.INF
	for i in frames:
		var k := float(i + 1) / float(frames)
		arrive.apply(stage, [p], k, f, DT)
		p.update(f, DT, stage)
		Actions.hold(p, DT)
		var now := _screen(stage, p)
		if i >= hit and i < hit + int(0.3 / DT):
			kept = minf(kept, Actions.apex_of(p.body).dot(way))
		if k < Actions.Arrive.APPROACH * 0.8:
			led = minf(led, Actions.apex_of(p.body).dot(way))
			if was != Vector2.INF:
				seen = _least(seen, stage, p, now - was)
		elif k > Actions.Arrive.APPROACH:
			past = maxf(past, p.pos.dot(way))
		was = now
	arrive.finish(stage, [p])
	_ok(seen.x > 0.7, "arrive: as drawn, the apex leads its motion on the screen (least cosine %.3f)" % seen.x)
	_ok(seen.y < 0.7, "arrive: the control: the same measure with the apex flipped fails (%.3f)" % seen.y)
	_ok(led > 0.95, "arrive: apex first along its way (%.3f)" % led)
	_ok(past > 0.02, "arrive: past its place before it settles (%.3f)" % past)
	_ok(p.pos == Vector3.ZERO and p.fade == 1.0, "arrive: landed on its place")
	_ok(kept > 0.9, "arrive: no pivot - in the first 0.3 s after the hit it still points the way it flew (%.3f)" % kept)
	# the control: the turn to its pose within the landing, as arrive once did (smoothstep over 0.7 of the landing)
	var landing := (1.0 - Actions.Arrive.APPROACH) * frames * DT
	var old := Actions.travelling(way).slerp(Actions.pointing(Vector3.UP), smoothstep(0.0, 0.7, 0.3 / landing))
	var old_apex := Actions.FLIP * (Basis(old) * (Actions.FLIP * Vector3.UP))
	_ok(old_apex.dot(way) < 0.9, "arrive: the control: the old turn within the landing fails that measure (%.3f)" % old_apex.dot(way))
	_ok(Actions.apex_of(p.body).dot(way) > 0.9 and p.state.get("upright") is Dictionary,
		"arrive: landed, it still points the way it flew, a righting latched")
	var at_end := _right_for(stage, p, f, 2.0)
	var later := _right_for(stage, p, f, 0.5)
	_ok(at_end > 0.97 and later > 0.9, "arrive: upright by the end of its righting time (%.3f), and half a second on (%.3f)" % [at_end, later])
	# the control: a righting too slow to finish is not upright in time
	var slow := FakeStage.new()
	slow.cast["q"] = Cast.make("prism", _rng(4), {"id": "q", "at": [0, 0, 0], "scale": 0.38, "hidden": true})
	var q = slow.cast["q"]
	var late := Actions.make("arrive", {"from": [3.0, 2.0, 0.0], "upright": 50.0}, _rng(6))
	late.begin(slow, [q])
	for i in frames:
		late.apply(slow, [q], float(i + 1) / float(frames), f, DT)
		q.update(f, DT, slow)
		Actions.hold(q, DT)
	late.finish(slow, [q])
	var unfinished := _right_for(slow, q, f, 2.0)
	_ok(unfinished < 0.97, "arrive: the control: a righting too slow to finish is not upright in time (%.3f)" % unfinished)
	# a window cut on its entry's last frame never finishes: the righting is latched all the same
	var cut := FakeStage.new()
	cut.cast["c"] = Cast.make("prism", _rng(4), {"id": "c", "at": [0, 0, 0], "scale": 0.38, "hidden": true})
	var c = cut.cast["c"]
	var short := Actions.make("arrive", {"from": [3.0, 2.0, 0.0], "upright": 2.0}, _rng(6))
	short.begin(cut, [c])
	for i in frames - 1:
		short.apply(cut, [c], float(i + 1) / float(frames), f, DT)
		_frame(cut, f)
	_ok(c.state.get("upright") is Dictionary, "arrive: cut before its window ends, it still latches its righting")


## A prism that has just landed, righting: a clone is born from it at once; until the tear the clone turns exactly
## as its parent does while both right; after it the parent goes on to upright.
func _righting_clone(f: AudioFeatures) -> void:
	var stage := FakeStage.new()
	var rng := _rng(4)
	stage.cast["blue"] = Cast.make("prism", rng, {"id": "blue", "at": [0, 0, 0], "scale": 0.38, "hue": 0.6, "hidden": true})
	stage.cast["red"] = Cast.make("prism", rng, {"id": "red", "at": [0.5, 0, 0], "hue": 0.6, "hidden": true})
	var blue = stage.cast["blue"]
	var red = stage.cast["red"]
	var arrive := Actions.make("arrive", {"from": [3.0, 2.0, 0.0], "upright": 3.0}, _rng(6))
	arrive.begin(stage, [blue])
	for i in 60:
		arrive.apply(stage, [blue], float(i + 1) / 60.0, f, DT)
		_frame(stage, f)
	arrive.finish(stage, [blue])
	var start := Actions.apex_of(blue.body)
	var split := Actions.make("split", {"into": "red", "hue": 0.0, "slots": [[-0.5, 0, 0], [0.5, 0, 0]]}, _rng(5))
	split.begin(stage, [blue])
	var twin_off := 0.0
	var frames := 60
	for i in frames:
		split.apply(stage, [blue], float(i + 1) / float(frames), f, DT)
		_frame(stage, f)
		if float(blue.state["mit"]["snap"]) < 0.0:
			twin_off = maxf(twin_off, (red.body as PrismBody).rot.distance_to((blue.body as PrismBody).rot))
	split.finish(stage, [blue])
	var turned := rad_to_deg(acos(clampf(start.dot(Actions.apex_of(blue.body)), -1.0, 1.0)))
	_ok(twin_off < 1e-5 and turned > 10.0,
		"righting: a clone born as it rights turns exactly as its parent until the tear (off %.6f), both turning %.0f degrees" % [twin_off, turned])
	_ok(not (red.state.get("upright") is Dictionary) and blue.state.get("upright") is Dictionary,
		"righting: at the tear the twin goes its own way; the parent rights on")
	var up := _right_for(stage, blue, f, 1.2)
	_ok(up > 0.97, "righting: the parent reaches upright (%.3f)" % up)


## One frame of the stage after its verbs: the bodies advance, then what verbs latch is held.
func _frame(stage: FakeStage, f: AudioFeatures) -> void:
	for a in stage.actors():
		a.update(f, DT, stage)
	for a in stage.actors():
		Actions.hold(a, DT)


## [param secs] seconds of the stage with no verb running; how near upright [param a]'s apex is at the end.
func _right_for(stage: FakeStage, a, f: AudioFeatures, secs: float) -> float:
	for i in int(round(secs / DT)):
		_frame(stage, f)
	return Actions.apex_of(a.body).dot(Vector3.UP)


func _leave(f: AudioFeatures) -> void:
	var stage := FakeStage.new()
	stage.cast["p"] = Cast.make("prism", _rng(8), {"id": "p", "at": [0, 0, 0], "scale": 0.38})
	var p = stage.cast["p"]
	var leave := Actions.make("leave", {"to": [1, 0.3, 0], "force": 0.3}, _rng(9))
	leave.begin(stage, [p])
	var way := Vector3(1, 0.3, 0).normalized()
	var frames := 60
	var along: Array = []
	var led := 1.0
	var seen := Vector2(1.0, 1.0)
	var was := Vector2.INF
	for i in frames:
		var k := float(i + 1) / float(frames)
		leave.apply(stage, [p], k, f, DT)
		along.append(p.pos.dot(way))
		p.update(f, DT, stage)
		var now := _screen(stage, p)
		if k > 0.5:
			led = minf(led, Actions.apex_of(p.body).dot(way))
		if k > 0.35 and was != Vector2.INF and _on(stage, p):
			seen = _least(seen, stage, p, now - was)
		was = now
	_ok(seen.x > 0.7, "leave: as drawn, the apex leads its motion on the screen (least cosine %.3f)" % seen.x)
	_ok(seen.y < 0.7, "leave: the control: the same measure with the apex flipped fails (%.3f)" % seen.y)
	var least := 0.0
	for x in along.slice(0, 15):
		least = minf(least, float(x))
	_ok(least < -0.05, "leave: it draws back first (%.3f)" % least)
	var middle := float(along[39]) - float(along[29])
	var late := float(along[59]) - float(along[49])
	_ok(late > middle * 1.3, "leave: it goes faster and faster (%.3f then %.3f a third of a second)" % [middle, late])
	_ok(led > 0.95, "leave: apex first along its way (%.3f)" % led)
	leave.finish(stage, [p])
	_ok(p.fade == 0.0, "leave: gone")


## Where [param a]'s center is drawn on the screen (the lens's unit fractions, y down).
func _screen(stage: FakeStage, a) -> Vector2:
	var pj := stage.lens.project(a.pos)
	return Vector2(pj.x, pj.y)


## Whether [param a]'s center is on the frame.
func _on(stage: FakeStage, a) -> bool:
	var s := _screen(stage, a)
	return absf(s.x) < 0.889 and absf(s.y) < 0.5


## [param least] lowered by this frame's screen cosines of center-to-apex with [param moved]: the apex where the prism
## draws it ([method PrismBody.draw]: its frame's corner, then x and y at 0.8 height, in perspective), and flipped.
func _least(least: Vector2, stage: FakeStage, a, moved: Vector2) -> Vector2:
	if moved.length() < 1e-5:
		return least
	var c: Vector3 = Basis.from_euler((a.body as PrismBody).rot) * PrismBody.APEX
	var persp := 2.0 / (2.0 - c.z * 0.3)
	var tip := Vector2(c.x * persp, c.y * persp * 0.8).normalized()
	var way := moved.normalized()
	return Vector2(minf(least.x, tip.dot(way)), minf(least.y, (-tip).dot(way)))


## How many times [param seps] turns from rising to falling or back.
func _turns(seps: Array) -> int:
	var n := 0
	var last := 0.0
	for i in range(1, seps.size()):
		var d := float(seps[i]) - float(seps[i - 1])
		if absf(d) < 1e-5:
			continue
		if last != 0.0 and signf(d) != signf(last):
			n += 1
		last = d
	return n


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _ok(cond: bool, what: String) -> void:
	print(("ok    " if cond else "FAIL  ") + what)
	if not cond:
		_fails += 1
