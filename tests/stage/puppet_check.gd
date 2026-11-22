extends Node

## puppet_check - a drawing made a puppet, as the stage plays it ([PuppetRig], [PuppetBody], the puppet verbs in [Actions]) and as the
## cartoon's producer checks what its director writes ([CartoonProducer]; next/cartoon.md).
##
##   tests/run_boot_probe.sh tests/stage/puppet_check.gd 120
##
## What it holds, on a rig made here (a body and a jaw on six bones) and a stage made here that steps as the real one does:
##   - the rig reads whole: its bones parents first, its layers' pictures, its anchor (the root over its feet) and height;
##   - its node skins: every vertex of every layer weighs 1 across its bones as the [Polygon2D] holds them (a packed array filled
##     through a dictionary is a copy, and would leave every weight 0 - the control: a layer built that way is found); a puppet of a
##     model sheet builds only the drawing it shows, and another when it swaps to it (the control);
##   - a pose turns an arm toward where it points, never past [constant PuppetBody.REACH]; `rest` takes it back;
##   - `move` carries a puppet to its place along the window; `strike` lands its blow at the swing's end and not before (the victim
##     recoils only then); `hop` is off the ground mid-way and down at the end; `talk` opens the jaw and closing it shuts it;
##   - the producer's check passes a storyboard that plays, and names each fault in one that does not: a rig not in the cast, a
##     backdrop not among the sets, a span aimed at someone not in the shot, a verb there is none of, a length far off (controls);
##   - a director's reply is read through words and fences round its JSON; a board written for a cartoon that loops loops, one that
##     does not holds its last shot (the control);
##   - a pose bends the limbs all the way, and its own drawing swaps in only once they have bent most of the way (the control: not
##     on the step it is asked for), a blow's reeling at once; a drawing facing us is mirrored only where the sheet has no profile;
##   - a camera that frames someone is placed by their place, height and face (its eye straight in front, as far as the size asks;
##     a two-shot holds both), and the producer's check names a camera framing someone not in the shot (the control);
##   - a mood is carried into a character's next shot past shots without it (the control: a shot that sets its own keeps it); a walk
##     that crawls is sent back (the control: a brisk one passes); an arm that reaches in from an edge is kept off it;
##   - `emerge` starts small and faint at the other's middle and ends clear and risen; `move`'s arc bows its path; `change` swaps a
##     backdrop's picture; a profile with two legs walks on them;
##   - a set's ground line reads sorted and is followed between its points; the surveyor's line laid along a painted edge lands on it
##     from points a little off it (the control: `snap: false` keeps them where they were written);
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
	_swaps(r)
	_ground()
	_framing()
	_story()
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
	# a puppet of a model sheet comes up with the drawing it shows built, and builds another when it swaps to it
	var sheet := PuppetRig.new()
	sheet.data = r.data
	sheet.drawings = {"front": r, "scared": r}
	var two := PuppetBody.new(sheet, 1, 1.0)
	var shown := two.build()
	var before := shown.find_children("Rig_*", "Node2D", true, false).map(func(n: Node) -> String: return n.name)
	two.mood = "scared"
	two.show_at(Transform2D.IDENTITY)
	var after := shown.find_children("Rig_*", "Node2D", true, false).filter(func(n: Node2D) -> bool: return n.visible) \
		.map(func(n: Node) -> String: return n.name)
	_ok(before == ["Rig_front"], "a sheet's puppet comes up with only the drawing it shows built (%s)" % str(before))
	_ok(after == ["Rig_scared"], "the control: swapped to another drawing, that one is built and shown alone (%s)" % str(after))
	shown.free()


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
	var round_and_round := CartoonProducer.settled(good, true)
	_ok(bool(round_and_round["loop"]) and not bool(round_and_round["bookend"]), "a cartoon that loops is written to follow its last shot with its first, no fade at its ends")
	_ok(not bool(CartoonProducer.settled(good, false)["loop"]), "the control: one that does not loop holds its last shot")


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


func _swaps(r: PuppetRig) -> void:
	r.drawings = {"front": r, "windup": r}
	var pb := PuppetBody.new(r, 1, 1.0)
	pb.pose = pb.pose_angles("windup")
	pb.posed = "windup"
	pb.step(1.0 / 60.0, Vector3.ZERO)
	_ok(pb._doing_drawn() == "windup", "a pose with a drawing of its own wants it")
	_ok(not pb._swap_ready(), "control: its drawing does not swap in on the step it is asked for")
	for i in 20:
		pb.step(1.0 / 60.0, Vector3.ZERO)
	_ok(pb._swap_ready(), "it swaps in once the limbs have bent most of the way")
	for i in 60:
		pb.step(1.0 / 60.0, Vector3.ZERO)
	var want := float(pb.pose.get("arm_l", 0.0))
	_ok(absf(float(pb._angle["arm_l"]) - want) < 0.1 * absf(want), "a pose bends the arm all the way (%.1f of %.1f)" % [pb._angle["arm_l"], want])
	var hit := PuppetBody.new(r, 2, 1.0)
	hit.react("windup", 0.5)
	hit.step(1.0 / 60.0, Vector3.ZERO)
	_ok(hit._swap_ready(), "a reaction's drawing swaps in at once")
	_ok(not pb._has_view("side"), "the fixture sheet has no profile, so its front may be mirrored")
	r.drawings = {}


func _framing() -> void:
	var p := CartoonProducer.new("", "", {"seconds": 10, "cast": [{"name": "x", "picture": ""}, {"name": "y", "picture": ""}],
		"sets": [{"name": "room", "place": "a room"}]})
	var shot := {"cast": [{"id": "set", "kind": "backdrop", "picture": "room", "at": [0, 0, -3]},
		{"id": "a", "kind": "puppet", "rig": _dir, "height": 1.0, "at": [0.5, -0.72, 0]},
		{"id": "b", "kind": "puppet", "rig": _dir, "height": 1.0, "at": [-0.5, -0.72, 0]}]}
	var cam := p.frame_camera(shot, {"frame": "a", "size": "face"})
	# the fixture's face: three quarters up its head bone (16 px down a 56 px figure on row 60); its head from its top to its neck,
	# where the head bone joins (row 40)
	var head_lo := -0.72 + (60.0 - 40.0) / 56.0
	var frame_h := (0.28 - head_lo) * 1.35
	var look: Array = cam.get("look", [0, 0, 0])
	var eye: Array = cam.get("eye", [0, 0, 0])
	_ok(absf(float(look[0]) - 0.5) < 0.01 and absf(float(look[1]) - (0.28 + head_lo) * 0.5) < 0.01, "a face shot looks at the middle of the head (%s)" % [look])
	_ok(absf(float(eye[2]) - frame_h / tan(deg_to_rad(20.0))) < 0.01 and is_equal_approx(float(eye[0]), float(look[0])),
		"its eye stands straight in front, as far as the head fills the frame")
	p._faces["faceless"] = {"x": 0.0, "y": 0.8, "neck": null, "ok": false}
	shot["cast"][2]["rig"] = "faceless"
	var whole := p.frame_camera(shot, {"frame": "b", "size": "face"})
	_ok(absf(float(whole["look"][1]) - (-0.72 + 0.5)) < 0.01 and float(whole["fov"]) == 48.0, "one drawn with no face to aim at is held whole")
	shot["cast"][2]["rig"] = _dir
	var two := p.frame_camera(shot, {"frame": ["a", "b"], "size": "chest"})
	_ok(absf(float(two["look"][0])) < 0.01 and float(two["eye"][2]) > float(eye[2]), "a two-shot is centered between them and farther off")
	_ok(p.frame_camera(shot, {"frame": "nobody"}).is_empty(), "framing nobody in the shot places nothing")
	var board := _board()
	board["sequence"][0]["camera"] = {"frame": "nobody", "size": "face"}
	_ok(p.check(board).contains("frames nobody"), "control: the check names a camera framing someone not in the shot")


func _story() -> void:
	var shot := func(cast: Array, spans: Array) -> Dictionary:
		return {"scene": "stage", "hold": 3.0, "cast": cast, "track": {"nominal": 3.0, "spans": spans}}
	var bed := {"id": "s", "kind": "puppet", "rig": "x", "at": [0.5, -0.72, 0]}
	var other := {"id": "o", "kind": "puppet", "rig": "y", "at": [-0.5, -0.72, 0]}
	var board := {"sequence": [shot.call([bed], [{"action": "feel", "target": "s", "at": 1.0, "args": {"mood": "scared"}}]),
		shot.call([other], []), shot.call([bed.duplicate()], []),
		shot.call([bed.duplicate()], [{"action": "feel", "target": "s", "at": 0.0, "args": {"mood": "dead"}}])]}
	var got := CartoonProducer.carried(board.duplicate(true))
	var third: Array = got["sequence"][2]["track"]["spans"]
	_ok(third.size() == 1 and String(third[0]["args"]["mood"]) == "scared" and is_zero_approx(float(third[0]["at"])),
		"a mood is carried into the next shot it is in, past a shot without it")
	_ok((got["sequence"][3]["track"]["spans"] as Array).size() == 1, "control: a shot that sets its own mood at its start keeps it alone")
	_ok((got["sequence"][1]["track"]["spans"] as Array).is_empty(), "nobody absent is given a mood")
	var p := CartoonProducer.new("", "", {"seconds": 10, "cast": [{"name": "x", "picture": ""}, {"name": "y", "picture": ""},
		{"name": "arm", "picture": "", "reaches": "left"}], "sets": [{"name": "room", "place": "a room"}]})
	var slow := _board()
	slow["sequence"][0]["track"]["spans"].append({"action": "move", "target": "x", "from": 0.0, "to": 4.0, "args": {"to": [1.5, -0.72, 0]}})
	_ok(p.check(slow).contains("a crawl"), "a walk that crawls is sent back")
	var brisk := _board()
	brisk["sequence"][0]["track"]["spans"].append({"action": "move", "target": "x", "from": 0.0, "to": 0.8, "args": {"to": [-1.5, -0.72, 0]}})
	_ok(p.check(brisk).is_empty(), "control: a brisk walk passes (%s)" % p.check(brisk))
	var insert := {"camera": {"eye": [0, 0, 4], "look": [0, 0, 0], "fov": 48},
		"cast": [{"id": "hand", "kind": "puppet", "rig": "arm", "height": 1.0, "at": [0.2, 0, 0]}],
		"track": {"spans": [{"action": "move", "target": "hand", "from": 0, "to": 1, "args": {"to": [0.5, 0, 0]}},
			{"action": "face", "target": "hand", "at": 1.5, "args": {"to": "left"}},
			{"action": "move", "target": "hand", "from": 2, "to": 3, "args": {"to": [-0.8, 0, 0]}}]}}
	p._keep_reaching(insert)
	var half_w := 4.0 * tan(deg_to_rad(24.0)) * 0.5 * CartoonProducer.WIDEST
	var h := float(insert["cast"][0]["height"])
	var w := 0.8 * h
	var x := float(insert["cast"][0]["at"][0])
	var to := float(insert["track"]["spans"][0]["args"]["to"][0])
	_ok(absf(x - w * 0.5 + half_w) < 0.01 and absf(to - x) < 0.01, "an arm reaching in from the left keeps its end at the frame's edge (%.2f)" % (x - w * 0.5))
	_ok(h > 1.0 and absf(to + w * 0.5 - 0.9) < 0.01, "and is drawn bigger, so its far end gets where its move sends it (%.2f tall)" % h)
	var spans: Array = insert["track"]["spans"]
	_ok(spans.size() == 2 and spans.all(func(sp: Dictionary) -> bool: return String(sp["action"]) == "move" and not bool(sp["args"]["turn"])),
		"it never turns round: its moves keep their way and a turn aimed at it is dropped")
	# emerge, arc, change on a stage
	var stage := FakeStage.new()
	add_child(stage)
	var rng := RandomNumberGenerator.new()
	var body: Cast.Actor = Cast.make("puppet", rng, {"id": "body", "kind": "puppet", "rig": _dir, "height": 1.0, "at": [0.0, -0.7, 0]})
	var soul: Cast.Actor = Cast.make("puppet", rng, {"id": "soul", "kind": "puppet", "rig": _dir, "height": 0.5, "at": [0.0, 0.0, 0], "hidden": true})
	var set_a: Cast.Actor = Cast.make("backdrop", rng, {"id": "set", "kind": "backdrop", "picture": "room", "at": [0, 0, -3]})
	stage.cast = {"body": body, "soul": soul, "set": set_a}
	var f := AudioFeatures.new()
	var em := Actions.make("emerge", {"from": "body", "rise": 1.0}, rng)
	em.begin(stage, [soul])
	em.apply(stage, [soul], 0.0, f, 0.03)
	var mid := -0.7 + 0.45
	_ok(soul.fade < 0.01 and soul.scale < 0.15 and absf(soul.pos.y + soul.scale * 0.5 - mid) < 0.01, "emerge starts faint and small at the other's middle")
	em.apply(stage, [soul], 1.0, f, 0.03)
	em.finish(stage, [soul])
	_ok(is_equal_approx(soul.fade, 1.0) and is_equal_approx(soul.scale, 0.5) and soul.pos.y > mid, "and ends clear, full size and risen")
	var mv := Actions.make("move", {"to": [1.0, 0.0, 0.0], "arc": 0.4, "gait": "float"}, rng)
	soul.pos = Vector3(-1.0, 0.0, 0.0)
	mv.begin(stage, [soul])
	mv.apply(stage, [soul], 0.5, f, 0.03)
	_ok(absf(soul.pos.y - 0.4) < 0.01, "a move's arc bows its path up at the middle (%.2f)" % soul.pos.y)
	var ch := Actions.make("change", {"picture": "room_open"}, rng)
	ch.begin(stage, [set_a])
	_ok((set_a as Cast.BackdropActor).picture == "room_open", "change swaps a backdrop's picture")
	stage.free()
	var walker := PuppetRig.read_now(_dir)
	walker.drawings = {"front": walker, "side": walker}
	var pb := PuppetBody.new(walker, 3, 1.0)
	_ok((pb._cels["side"] as PuppetBody.Cel).walks, "a profile with two legs walks on them")
	_ok(not (pb._cels["front"] as PuppetBody.Cel).walks, "control: a front does not")
	walker.drawings = {}


func _ground() -> void:
	var file := ProjectSettings.globalize_path("user://puppet_check/set.ground.json")
	var f := FileAccess.open(file, FileAccess.WRITE)
	f.store_string(JSON.stringify({"line": [[1.0, 0.5], [0.0, 0.7], [0.5, 0.4]]}))
	f.close()
	var line := PuppetRig.read_ground(file)
	_ok(line.size() == 3 and line[0].x == 0.0 and line[2].x == 1.0, "a ground line reads sorted left to right")
	_ok(is_equal_approx(PuppetRig.ground_at(line, 0.25), 0.55) and is_equal_approx(PuppetRig.ground_at(line, 0.75), 0.45),
		"it is followed between its points")
	_ok(is_nan(PuppetRig.ground_at(PackedVector2Array(), 0.5)), "control: no line, no height")
	# a dark curve on pale paper, and points 2% below it
	var img := Image.create(400, 200, false, Image.FORMAT_RGB8)
	img.fill(Color(0.9, 0.9, 0.85))
	var truth := func(x: float) -> float: return 0.5 + 0.1 * sin(x * TAU)
	for x in 400:
		var y := int(truth.call(x / 400.0) * 200.0)
		img.fill_rect(Rect2i(x, y - 1, 1, 3), Color(0.05, 0.05, 0.05))
	var pts := PackedVector2Array()
	for i in 9:
		var x := i / 8.0
		pts.append(Vector2(x, float(truth.call(x)) + 0.02))
	var worst := 0.0
	for p in SurveyorTools.along_edge(img, pts):
		worst = maxf(worst, absf(p.y - float(truth.call(p.x))))
	_ok(worst < 0.012, "the surveyor's line lands on the painted edge (%.3f off at worst)" % worst)
	var job := {"picture": "", "image": img, "points": pts, "snap": false}
	SurveyorTools.work(job)
	var kept: PackedVector2Array = job["line"]
	_ok(kept.size() == pts.size() and is_equal_approx(kept[4].y, pts[4].y), "control: snap off keeps the points as written")
	_ok(job["look"] is Image and (job["look"] as Image).get_width() == 400, "it answers with a picture of the line")


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
