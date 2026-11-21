extends Node

## puppet_check - a drawing made a puppet, as the stage plays it ([PuppetRig], [PuppetBody], the puppet verbs in [Actions]) and as the
## cartoon's producer checks what its director writes ([CartoonProducer]; next/cartoon.md).
##
##   tests/run_boot_probe.sh tests/stage/puppet_check.gd 120
##
## What it holds, on a rig made here (a body and a jaw on six bones) and a stage made here that steps as the real one does:
##   - the rig reads whole: its bones parents first, its layers' pictures, its anchor (the root over its feet) and height;
##   - its node skins: every vertex of every layer weighs 1 across its bones as the [Polygon2D] holds them (a packed array filled
##     through a dictionary is a copy, and would leave every weight 0 - the control: a layer built that way is found);
##   - a pose turns an arm toward where it points, never past [constant PuppetBody.REACH]; `rest` takes it back;
##   - `move` carries a puppet to its place along the window; `strike` lands its blow at the swing's end and not before (the victim
##     recoils only then); `hop` is off the ground mid-way and down at the end; `talk` opens the jaw and closing it shuts it;
##   - the producer's check passes a storyboard that plays, and names each fault in one that does not: a rig not in the cast, a
##     backdrop not among the sets, a span aimed at someone not in the shot, a verb there is none of, a length far off (controls);
##   - a director's reply is read through words and fences round its JSON;
##   - a model sheet ([PuppetSheet]): each drawing is painted after the one it is painted from, and the drawing shown is the mood's,
##     else the view's with that mouth (wide falling back to open, open to closed), else the front.

var _fails := 0
var _dir := ""


class FakeView extends RefCounted:
	func matrix(_s: Vector2) -> Transform2D:
		return Transform2D.IDENTITY


class FakeStage extends Node2D:
	var lens := Lens3D.new()
	var view := FakeView.new()
	var size := Vector2(960, 720)
	var cast := {}

	func _init() -> void:
		lens.eye = Vector3(0, 0, 4.0)
		lens.fov = 48.0
		lens.prepare()

	func unit() -> float:
		return 720.0

	func actor(id: String):
		return cast.get(id)

	func actors() -> Array:
		return cast.values()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_dir = ProjectSettings.globalize_path("user://puppet_check/fixture")
	_make_rig(_dir)
	var r := PuppetRig.read_now(_dir)
	_ok(r.ok(), "the rig reads whole (%s)" % r.error)
	_ok((r.data["bones"] as Array).size() == 7 and String(r.data["bones"][0]["name"]) == "root", "its bones read, root first")
	_ok(r.images.has("body") and r.images.has("jaw"), "its layers' pictures read")
	_ok(r.anchor().is_equal_approx(Vector2(32, 60)) and is_equal_approx(r.height(), 56.0), "its anchor is the root over its feet, its height top to feet")
	_skins(r)
	_poses(r)
	_verbs()
	_checks()
	_sheet()
	if _fails == 0:
		print("puppet_check: ok")
	get_tree().quit(_fails)


func _skins(r: PuppetRig) -> void:
	var pb := PuppetBody.new(r, 1, 1.0)
	var node := pb.build()
	var polys := node.find_children("*", "Polygon2D", true, false)
	_ok(polys.size() == 2, "a polygon per layer")
	for p in polys:
		_ok(_sums_to_one(p as Polygon2D), "every vertex of %s weighs 1 across its bones" % (p as Polygon2D).name)
	# the control: weights filled through a dictionary's packed array stay 0
	var bad := Polygon2D.new()
	bad.polygon = (polys[0] as Polygon2D).polygon
	var arr := PackedFloat32Array()
	arr.resize(bad.polygon.size())
	var per := {0: arr}
	for i in bad.polygon.size():
		(per[0] as PackedFloat32Array)[i] = 1.0
	bad.add_bone(NodePath("root"), per[0])
	_ok(not _sums_to_one(bad), "control: weights written into a copy are found to be 0")
	bad.free()
	node.free()


func _sums_to_one(p: Polygon2D) -> bool:
	var n := p.polygon.size()
	var tot := PackedFloat32Array()
	tot.resize(n)
	for b in p.get_bone_count():
		var w := p.get_bone_weights(b)
		for i in mini(n, w.size()):
			tot[i] += w[i]
	for i in n:
		if absf(tot[i] - 1.0) > 0.01:
			return false
	return n > 0


func _poses(r: PuppetRig) -> void:
	var pb := PuppetBody.new(r, 1, 1.0)
	var up := pb.pose_angles("arms_up")
	# arm_l points left (180 on the screen); arms_up points it up and left (-125): a turn of 55 degrees clockwise
	_ok(is_equal_approx(float(up.get("arm_l", 0.0)), 55.0), "arms_up turns the left arm toward up and left (%s)" % up.get("arm_l"))
	var far := pb.pose_angles("rest", 10.0, "left")
	_ok(absf(float(far.get("arm_l", 0.0))) <= PuppetBody.REACH + 0.01, "an arm never turns past its reach")
	_ok(pb.pose_angles("rest").is_empty(), "rest holds nothing")


func _verbs() -> void:
	var stage := FakeStage.new()
	add_child(stage)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var a: Cast.Actor = Cast.make("puppet", rng, {"id": "a", "kind": "puppet", "rig": _dir, "height": 1.0, "at": [-0.5, -0.7, 0]})
	var b: Cast.Actor = Cast.make("puppet", rng, {"id": "b", "kind": "puppet", "rig": _dir, "height": 1.0, "at": [0.3, -0.7, 0]})
	stage.cast = {"a": a, "b": b}
	_ok(a.body is PuppetBody, "a puppet's body is made once its rig is read")
	var f := AudioFeatures.new()
	# move
	var mv := Actions.make("move", {"to": [0.0, -0.7, 0.0], "gait": "run"}, rng)
	mv.begin(stage, [a])
	mv.apply(stage, [a], 0.5, f, 0.03)
	_ok(is_equal_approx(a.pos.x, -0.25), "move is half way at half the window")
	mv.apply(stage, [a], 1.0, f, 0.03)
	mv.finish(stage, [a])
	_ok(is_equal_approx(a.pos.x, 0.0) and (a.body as PuppetBody).gait.is_empty(), "move ends on its place, its gait let go")
	# strike: the blow lands at the swing's end
	var pv := b.body as PuppetBody
	var st := Actions.make("strike", {"at": "b", "force": 0.8, "mark": ""}, rng)
	st.begin(stage, [a])
	st.apply(stage, [a], 0.5, f, 0.03)
	_ok(pv._recoil_v.is_zero_approx() and is_zero_approx(pv._spin_v), "no blow lands during the wind-up")
	st.apply(stage, [a], 0.62, f, 0.03)
	_ok(not pv._recoil_v.is_zero_approx() and pv._spin_v != 0.0, "the blow lands at the swing's end")
	_ok(pv._recoil_v.x > 0.0, "the victim reels away from the one who struck")
	st.apply(stage, [a], 1.0, f, 0.03)
	st.finish(stage, [a])
	# hop
	var hp := Actions.make("hop", {"height": 0.4}, rng)
	var pa := a.body as PuppetBody
	hp.begin(stage, [a])
	hp.apply(stage, [a], 0.5, f, 0.03)
	_ok(pa.lift > 0.3, "hop is off the ground mid-way (%.2f)" % pa.lift)
	hp.apply(stage, [a], 1.0, f, 0.03)
	hp.finish(stage, [a])
	_ok(is_zero_approx(pa.lift), "hop is down at the end")
	# talk
	var tk := Actions.make("talk", {"loud": 1.0}, rng)
	tk.apply(stage, [a], 0.5, f, 0.03)
	var opened := 0.0
	for i in 60:
		pa.step(1.0 / 30.0, a.pos)
		opened = maxf(opened, pa._jaw)
	_ok(opened > 0.3, "talking opens the jaw (%.2f)" % opened)
	tk.finish(stage, [a])
	for i in 30:
		pa.step(1.0 / 30.0, a.pos)
	_ok(pa._jaw < 0.05, "stopping shuts it")
	stage.free()


func _checks() -> void:
	var p := CartoonProducer.new("", "", {"seconds": 10, "cast": [{"name": "x", "picture": ""}, {"name": "y", "picture": ""}],
		"sets": [{"name": "room", "place": "a room"}]})
	var good := _board()
	_ok(p.check(good).is_empty(), "a storyboard that plays passes (%s)" % p.check(good))
	var bad := _board()
	bad["sequence"][0]["cast"][1]["rig"] = "z"
	_ok(p.check(bad).contains("not one of the cast"), "control: a rig not in the cast is named")
	bad = _board()
	bad["sequence"][0]["cast"][0]["picture"] = "hall"
	_ok(p.check(bad).contains("not one of the sets"), "control: a backdrop not among the sets is named")
	bad = _board()
	bad["sequence"][0]["track"]["spans"][0]["target"] = "nobody"
	_ok(p.check(bad).contains("not in that shot"), "control: a span aimed at someone absent is named")
	bad = _board()
	bad["sequence"][0]["cast"][2]["at"] = [-0.45, -0.72, 0]
	_ok(p.check(bad).contains("standing on each other"), "control: two puppets started on the same spot are named")
	bad = _board()
	bad["sequence"][0]["track"]["spans"][0]["action"] = "teleport"
	_ok(p.check(bad).contains("no verb"), "control: a verb there is none of is named")
	bad = _board()
	bad["sequence"][0]["hold"] = 2.0
	bad["sequence"][0]["track"]["nominal"] = 2.0
	bad["sequence"][1]["hold"] = 2.0
	bad["sequence"][1]["track"]["nominal"] = 2.0
	bad["sequence"][1]["track"]["spans"] = []
	bad["sequence"][0]["track"]["spans"] = []
	_ok(p.check(bad).contains("should run about"), "control: a length far off is named")
	var said := "Here it is:\n```json\n" + JSON.stringify(good) + "\n```\nThat is the storyboard."
	var got: Variant = CartoonProducer.parse_board(said)
	_ok(got is Dictionary and (got as Dictionary).get("sequence", []).size() == 2, "a reply's JSON is read through the words and fences round it")
	_ok(is_equal_approx(Storyboard.silent_length(Storyboard.from_data(good, "test")), 10.0), "a silent note runs as long as its storyboard's holds")


func _sheet() -> void:
	var order := PuppetSheet.order()
	_ok(order.size() == PuppetSheet.REGISTRY.size() and order[0] == "front", "a sheet is painted front first, every drawing once")
	for k in order:
		var from := String((PuppetSheet.REGISTRY[k] as Dictionary)["from"])
		_ok(from.is_empty() or order.find(from) < order.find(k), "%s is painted after %s" % [k, from])
	var have := {"front": 1, "front_open": 1, "side": 1, "scared": 1}
	_ok(PuppetSheet.pick(have, "front", "wide", "") == "front_open", "a wide mouth with no wide drawing is the open one")
	_ok(PuppetSheet.pick(have, "side", "open", "") == "side", "an open mouth with no drawing of it is the view's own")
	_ok(PuppetSheet.pick(have, "back", "closed", "") == "front", "a view with no drawing is the front")
	_ok(PuppetSheet.pick(have, "side", "open", "scared") == "scared", "a mood's drawing wins")
	_ok(PuppetSheet.pick(have, "front", "closed", "angry") == "front", "a mood with no drawing is the view's")
	have["reeling"] = 1
	_ok(PuppetSheet.pick(have, "front", "open", "scared", "reeling") == "reeling", "an action's drawing wins over a mood's")
	_ok(PuppetSheet.pick(have, "side", "open", "", "stride") == "side", "an action with no drawing is the view's")


func _board() -> Dictionary:
	var shot := func(hold: float, spans: Array) -> Dictionary:
		return {"scene": "stage", "hold": hold, "camera": {"eye": [0, 0, 4], "look": [0, 0, 0], "fov": 48},
			"cast": [{"id": "set", "kind": "backdrop", "picture": "room", "at": [0, 0, -3]},
				{"id": "x", "kind": "puppet", "rig": "x", "height": 1.0, "at": [-0.5, -0.72, 0]},
				{"id": "y", "kind": "puppet", "rig": "y", "height": 1.0, "at": [0.5, -0.72, 0]}],
			"track": {"nominal": hold, "spans": spans}}
	return {"name": "t", "loop": false, "sequence": [
		shot.call(5.0, [{"from": 0.5, "to": 2.0, "action": "talk", "target": "x"}]),
		shot.call(5.0, [{"from": 1.0, "to": 2.0, "action": "strike", "target": "x", "args": {"at": "y"}}])]}


## A rig as rig.py writes one: a 64 x 64 body on a root, a head, an arm and a hand to the left, two legs, and a jaw over a square of
## mouth on the head.
func _make_rig(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for name in ["skin", "jaw"]:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.2, 0.8, 0.3, 1.0) if name == "skin" else Color(0.8, 0.2, 0.2, 1.0))
		img.save_png(dir.path_join(name + ".png"))
	var pts := [4, 4, 60, 4, 60, 60, 4, 60, 32, 32, 16, 16, 48, 16, 16, 48, 48, 48]
	var tris := [0, 1, 4, 1, 2, 4, 2, 3, 4, 3, 0, 4, 0, 5, 4, 1, 6, 4, 3, 7, 4, 2, 8, 4]
	var ws: Array = []
	for i in pts.size() / 2:
		ws.append([[0, 0.5], [1, 0.5]] if i % 2 == 0 else [[2, 0.25], [3, 0.75]])
	var rig := {"version": 1, "size": [64, 64], "top": 4, "ground": 60, "faces": "front",
		"bones": [
			{"name": "root", "parent": "", "head": [32, 60], "tail": [32, 40], "role": "body", "side": ""},
			{"name": "head", "parent": "root", "head": [32, 40], "tail": [32, 8], "role": "head", "side": ""},
			{"name": "arm_l", "parent": "root", "head": [24, 40], "tail": [8, 40], "role": "arm", "side": "left"},
			{"name": "hand_l", "parent": "arm_l", "head": [8, 40], "tail": [4, 30], "role": "hand", "side": "left"},
			{"name": "leg_l", "parent": "root", "head": [26, 56], "tail": [20, 62], "role": "leg", "side": "left"},
			{"name": "leg_r", "parent": "root", "head": [38, 56], "tail": [44, 62], "role": "leg", "side": "right"},
			{"name": "jaw", "parent": "head", "head": [32, 24], "tail": [32, 30], "role": "jaw", "side": ""}],
		"layers": [
			{"name": "body", "image": "skin.png", "points": pts, "tris": tris, "weights": ws},
			{"name": "jaw", "image": "jaw.png", "points": [24, 24, 40, 24, 40, 32, 24, 32], "tris": [0, 1, 2, 0, 2, 3],
				"weights": [[[6, 1.0]], [[6, 1.0]], [[6, 1.0]], [[6, 1.0]]]}],
		"cavity": {"color": "#200808", "bone": "head"}, "eyes": [], "mouth": {"hinge": [32, 24], "open": 12.0, "drop": 4.0},
		"poses": {}, "about": "a fixture"}
	var f := FileAccess.open(dir.path_join("rig.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(rig))
	f.close()


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   " + what)
	else:
		print("  FAIL " + what)
		_fails += 1
