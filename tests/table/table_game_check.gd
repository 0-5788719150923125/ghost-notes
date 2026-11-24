extends Node

## table_game_check - a game on a table, as it plays (next/tabletop.md): a session stood on a real table with its dice really thrown, then asked at each moment what is where. What shows on a die is what was rolled, once it lands; a throw comes from where its person sits; a figure stands on its square, hops to the next, lies flat when it falls and is gone with its map; a picture comes up to the lens and goes; the camera goes to the dice and comes back; dice are heard only when they are. A control: nothing has happened before its time, and the camera does not move for a throw behind a screen.
##
##     tests/run_boot_probe.sh tests/table/table_game_check.gd 200

const DT := 1.0 / 30.0
var fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", what)


func _ready() -> void:
	_run.call_deferred()


func _session() -> Dictionary:
	var people := PackedStringArray(["Dell", "Bea", "Milo"])
	var g := GameLedger.from({"Milo": {"hit points": 5}})
	var seed := 11
	var m1: Dictionary = g.map_down("Bridge", "a bridge", [20, 14])["event"]
	var pl: Dictionary = g.place("Goat", [2, 3], "a goat")["event"]
	var mv: Dictionary = g.move("Goat", [6, 3])["event"]
	var r1: Dictionary = g.roll("Milo", "1d20+2", "x", seed)["event"]
	var fl: Dictionary = g.figure_state("fall", "Goat")["event"]
	var r2: Dictionary = g.roll("Bea", "3d6", "y", seed)["event"]
	var r3: Dictionary = g.roll("Dell", "1d20", "z", seed, true)["event"]
	var rv: Dictionary = g.reveal("Goat", "a goat")["event"]
	var m2: Dictionary = g.map_down("Boat", "a boat", [10, 8])["event"]
	var ev := [m1, pl, mv, r1, fl, r2, r3, rv, m2]
	var game := GameBoard.gather(g.events, people, {"people": {"Bea": {"dice": {"material": "metal", "color": "#a0a0a0"}}, "Milo": {"dice": {"material": "plastic"}}}}, {"Bea": -100.0, "Milo": 100.0})
	return {"game": game, "events": ev}


func _run() -> void:
	var s := _session()
	var game: Dictionary = s["game"]
	var ev: Array = s["events"]
	var stage := SubViewport.new()
	stage.size = Vector2i(320, 180)
	stage.own_world_3d = true
	add_child(stage)
	Director.detach()
	var medium: Medium = Medium.make("table")
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	var subs: Subtitles = preload("res://src/show/subtitles.gd").new()
	var plan := {"game": true, "look": {"candles": 0, "palette": ["#3a2a20", "#c8a060", "#6a5a48"]}, "spread": {"positions": []}, "staging": {"source": "none"}}
	var script := "<!-- table: begin -->\n\nA few words to start.\n"
	subs.words = [{"text": "A", "t0": 0.1, "t1": 0.2, "sentence": 0}]
	var dir := "user://_table_game_check"
	DirAccess.make_dir_recursive_absolute(dir)
	TableGame.bake_root = dir
	subs.document = {"source": script, "title": "T", "table": {"show": "game-check", "seed": 41, "dir": ProjectSettings.globalize_path(dir), "plan": plan, "cards": [], "game": game}}
	add_child(subs)
	medium.bind_captions(subs)
	Spectrum.virtual_clock = 0.0
	Spectrum.current.time = 0.0
	subs._process(DT)
	medium.advance(Spectrum.current, DT, 1.0)
	var tm := medium as TableMedium
	var tg: TableGame = tm._work.game
	_check(tg != null, "a table with a session has a game on it")
	if tg == null:
		_end(dir)
		return
	tg.wait_whole()
	_check(not tg._record.is_empty(), "the dice were really thrown: %s" % tg.report())
	# ...when each happened: the marks a reading would place
	var when := {}
	var t := 1.0
	var sched: Array = []
	for e in ev:
		when[int((e as Dictionary)["id"])] = t
		sched.append({"a": {"kind": String((e as Dictionary)["kind"]), "card": int((e as Dictionary)["id"])}, "t0": t, "s": 1.0})
		t += 6.0
	# ...the dice's camera alone: the others (Cameras) are cameras_check's and the look probe's
	tm.feed.cameras = [{"sort": "dice"}]
	tg.schedule(sched)
	_camera(tm, tg, ev, when)
	_board(tg, ev, when)
	_dice(tg, ev, when)
	_sound(tg, ev, when)
	_portrait(tm, tg, ev, when)
	_end(dir)


func _end(dir: String) -> void:
	OS.execute("rm", ["-rf", ProjectSettings.globalize_path(dir)])
	print("table_game_check: ", "ok" if fails == 0 else "%d failed" % fails)
	get_tree().quit(1 if fails > 0 else 0)


## From high up, looking well down.
func _camera(tm: TableMedium, tg: TableGame, ev: Array, when: Dictionary) -> void:
	var base: Transform3D = tm._plan.cam_base
	var fwd := -base.basis.z
	_check(fwd.y < -0.8, "a game is seen from high up: %.2f" % fwd.y)
	_check(base.origin.y > 0.9, "and from far off: %.2f" % base.origin.y)
	var far_edge: Variant = CardTable.project(base, tm._plan.fov, Vector3(GameBoard.MIDDLE.x, 0.0, GameBoard.MIDDLE.y - GameBoard.MAP_MOST.y * 0.5))
	var near_edge: Variant = CardTable.project(base, tm._plan.fov, Vector3(GameBoard.MIDDLE.x, 0.0, GameBoard.MIDDLE.y + GameBoard.MAP_MOST.y * 0.5))
	var side: Variant = CardTable.project(base, tm._plan.fov, Vector3(GameBoard.MIDDLE.x + GameBoard.MAP_MOST.x * 0.5, 0.0, GameBoard.MIDDLE.y))
	_check(far_edge != null and (far_edge as Vector2).y > 0.02, "the far edge of the biggest map is in the picture")
	_check(near_edge != null and (near_edge as Vector2).y < 0.98, "and the near edge")
	_check(side != null and (side as Vector2).x < 0.98, "and its side")
	# The shot: to the dice and back, and never for what is behind a screen
	var r1: Dictionary = ev[3]
	var id := int(r1["id"])
	var thrown := float(when[id]) + TableGame.RISE + TableGame.SHAKE
	var dur := float((tg._record[id] as Dictionary)["dur"])
	_check(tg.shot_at(float(when[id]) - 1.0, base).origin.is_equal_approx(base.origin), "before a throw the camera stands where it stands")
	var close := tg.shot_at(thrown + dur + 0.2, base)
	_check(close.origin.distance_to(base.origin) > 0.2, "as the dice land it goes to them: %.2f" % close.origin.distance_to(base.origin))
	var ease := TableGame.SHOT_OUT
	for c in tg._claims:
		if absf(float((c as Dictionary)["t0"]) - thrown) < 6.0:
			ease = maxf(ease, float((c as Dictionary).get("ease", 0.0)))
	var back := TableGame.SHOT_HOLDS + ease + 0.5
	_check(tg.shot_at(thrown + dur + back, base).origin.is_equal_approx(base.origin), "and it comes back, as slowly as it went: %.1f s" % back)
	var hidden: Dictionary = ev[6]
	var ht := float(when[int(hidden["id"])]) + TableGame.RISE + TableGame.SHAKE + 1.0
	_check(tg.shot_at(ht, base).origin.distance_to(base.origin) < 0.2, "a throw behind a screen is not gone to")
	# ...never jolts: its move from frame to frame stays a slow one
	var was := tg.shot_at(thrown - 2.0, base).origin
	var most := 0.0
	var at := thrown - 2.0
	while at < thrown + dur + 5.0:
		at += DT
		var now := tg.shot_at(at, base).origin
		most = maxf(most, now.distance_to(was))
		was = now
	_check(most < 0.03, "the shot is gentle, frame to frame: %.3f m" % most)
	# A dice camera set to arrive, low as they land and rising over them as they hold: there, close, looking down on the face at the end
	var stop := thrown + dur
	var rest: Vector3 = (tg._shots[0] as Dictionary)["at"] if not tg._shots.is_empty() else Vector3.ZERO
	for sh in tg._shots:
		if absf(float((sh as Dictionary)["t1"]) - TableGame.SHOT_HOLDS - stop) < 0.01:
			rest = (sh as Dictionary)["at"]
	tm.feed.cameras = [{"sort": "dice", "reach": 1.0, "far": 25.0, "rise": 20.0, "top": 80.0, "lens": 24.0}]
	tg._plan_cameras()
	tg._shot_t = NAN
	var landed := tg.shot_at(stop, base)
	var lifted := tg.shot_at(stop + TableGame.SHOT_HOLDS - 0.05, base)
	var there := tg.shot_at(stop + 0.7, base)
	var drop_landed := rad_to_deg(asin(clampf((landed.origin.y - rest.y) / maxf(landed.origin.distance_to(rest), 0.001), -1.0, 1.0)))
	var drop_lifted := rad_to_deg(asin(clampf((lifted.origin.y - rest.y) / maxf(lifted.origin.distance_to(rest), 0.001), -1.0, 1.0)))
	_check(there.origin.distance_to(rest) < 0.3, "a dice camera set to arrive is there once they land, close: %.2f m" % there.origin.distance_to(rest))
	_check(drop_landed < 35.0 and drop_lifted > 60.0, "...low as they land, rising over them as it holds: %.0f then %.0f degrees" % [drop_landed, drop_lifted])
	_check(absf(tg.fov_at(stop + 0.7) - 24.0) < 1.0, "...through its own lens: %.1f" % tg.fov_at(stop + 0.7))
	tm.feed.cameras = [{"sort": "dice"}]
	tg._plan_cameras()
	tg._shot_t = NAN
	_check(tg.shot_at(stop + 0.7, base).origin.distance_to(rest) > 0.3, "control: the camera as it stood goes only part of the way")


## A portrait frame (TikTok, next/portrait.md): the lens is the frame's short side, so it sees the landscape view turned on end; each
## shot keeps a landscape frame's top edge and grows downward; a page covers the tall frame; a picture held up fits its width. The
## control: the same table in landscape, as it always was.
func _portrait(tm: TableMedium, tg: TableGame, ev: Array, when: Dictionary) -> void:
	var base: Transform3D = tm._plan.cam_base
	var at := float(when[int((ev[0] as Dictionary)["id"])]) - 0.5
	tg._shot_t = NAN
	var flat_shot := tg._shot(at)
	var flat_page := tg._page_size(1.5)
	var flat_frame := CardTable.lens(tg._fov, tm.aspect()) * 2.0 * TableGame.PAGE_FAR
	_check(is_equal_approx(tm.aspect(), 16.0 / 9.0), "control: a table nobody frames otherwise is 16:9: %.3f" % tm.aspect())
	_check(is_equal_approx(flat_page.x, flat_frame.x), "control: a landscape page spans a landscape frame: %.3f of %.3f" % [flat_page.x, flat_frame.x])
	var frame_was := Director.frame
	Director.frame = "portrait"
	Director.pin_medium("table", self)
	tg._shot_t = NAN
	_check(absf(tm.aspect() - 9.0 / 16.0) < 0.001, "a portrait table is 9:16: %.3f" % tm.aspect())
	tm._tick_camera(at)
	_check(tm._cam.keep_aspect == Camera3D.KEEP_WIDTH, "its lens holds the frame's width, its short side")
	var k := tan(deg_to_rad(30.0))
	var l := CardTable.lens(60.0, 9.0 / 16.0)
	_check(absf(l.x - k) < 1e-4 and absf(l.y - k * 16.0 / 9.0) < 1e-4, "it sees across what landscape sees up, and up what landscape sees across: %s" % str(l))
	# ...the top edge kept where landscape has it, the view turned down
	var tall_shot := tg._shot(at)
	var top := func(s: Dictionary, aspect: float) -> float:
		var fwd: Vector3 = ((s["at"] as Vector3) - (s["eye"] as Vector3)).normalized()
		return rad_to_deg(asin(fwd.y) + atan(CardTable.lens(float(s["fov"]), aspect).y))
	var pitch := func(s: Dictionary) -> float:
		return rad_to_deg(asin(((s["at"] as Vector3) - (s["eye"] as Vector3)).normalized().y))
	var flat_top: float = top.call(flat_shot, 16.0 / 9.0)
	var tall_top: float = top.call(tall_shot, 9.0 / 16.0)
	_check(absf(flat_top - tall_top) < 0.3, "a portrait shot keeps a landscape one's top edge: %.1f against %.1f degrees" % [tall_top, flat_top])
	_check(float(pitch.call(tall_shot)) < float(pitch.call(flat_shot)) - 2.0, "...and looks further down: %.1f against %.1f" % [pitch.call(tall_shot), pitch.call(flat_shot)])
	# ...a tall page fills it, a landscape one shows its middle
	var frame := CardTable.lens(tg._fov, tm.aspect()) * 2.0 * TableGame.PAGE_FAR
	var tall_page := tg._page_size(2.0 / 3.0)
	var wide_page := tg._page_size(1.5)
	_check(is_equal_approx(tall_page.y, frame.y) and tall_page.x >= frame.x - 1e-5, "a tall page covers a portrait frame: %s for %s" % [str(tall_page), str(frame)])
	_check(is_equal_approx(wide_page.y, frame.y) and wide_page.x > frame.x * 2.0, "a landscape page in it shows its middle, its sides off the frame: %s" % str(wide_page))
	# ...a picture held up fits its width, held farther off
	var rv: Dictionary = ev[7]
	var held_at := float(when[int(rv["id"])]) + TableGame.REVEAL_TAKES + 0.4
	tg._shot_t = NAN
	tg._tick_reveals(held_at)
	var shown: Array = tg._reveals.filter(func(r: Variant) -> bool: return ((r as Dictionary)["node"] as Node3D).visible)
	if shown.is_empty():
		_check(false, "a picture is held up at %.1f" % held_at)
	else:
		var node: Node3D = (shown[0] as Dictionary)["node"]
		var dist := node.transform.origin.distance_to(tg._eye(held_at).origin)
		var across := TableGame.HOLD_SIZE.x / (2.0 * dist * CardTable.lens(tg.fov_at(held_at), tm.aspect()).x)
		_check(across <= TableGame.HOLD_ACROSS + 0.01 and dist > TableGame.HOLD_FAR, "a picture held up in a portrait frame fits it, held farther off: %.2f of its width at %.2f m" % [across, dist])
	Director.unpin_medium(self)
	Director.frame = frame_was
	tg._shot_t = NAN
	tm._tick_camera(at)
	_check(tm._cam.keep_aspect == Camera3D.KEEP_HEIGHT, "control: back in landscape its lens holds the height")


func _board(tg: TableGame, ev: Array, when: Dictionary) -> void:
	var goat: Dictionary = tg._figures[0]
	var node: Node3D = goat["node"]
	var map: Dictionary = (tg.game["maps"] as Array)[0]
	var placed := float(when[int((ev[1] as Dictionary)["id"])])
	tg.tick(placed - 0.1)
	_check(not node.visible, "nothing stands before it is placed")
	tg.tick(placed + TableGame.PLACE_TAKES + 0.1)
	var at := GameBoard.at_map(map, [2, 3])
	_check(node.visible and Vector2(node.position.x, node.position.z).distance_to(at) < 0.001, "it stands on its square")
	_check(node.position.y < 0.01, "on the table: %.3f" % node.position.y)
	var moved := float(when[int((ev[2] as Dictionary)["id"])])
	tg.tick(moved + 0.2)
	_check(node.position.y > 0.004, "a move is a hop: %.3f" % node.position.y)
	tg.tick(moved + 3.0)
	var to := GameBoard.at_map(map, [6, 3])
	_check(Vector2(node.position.x, node.position.z).distance_to(to) < 0.001, "and lands on its new square")
	var pivot: Node3D = goat["pivot"]
	var fell := float(when[int((ev[4] as Dictionary)["id"])])
	tg.tick(fell - 0.05)
	var up := pivot.basis * Vector3.UP
	_check(up.y > 0.8, "it stands up to read, leaned back: %.2f" % up.y)
	tg.tick(fell + 1.0)
	up = pivot.basis * Vector3.UP
	_check(up.y < 0.08 and up.z < -0.9, "a fallen figure lies on its back: %s" % str(up))
	var face := pivot.basis * Vector3.BACK
	_check(face.y > 0.9, "its painting up: %s" % str(face))
	var map2 := float(when[int((ev[8] as Dictionary)["id"])])
	tg.tick(map2 + TableGame.PLACE_TAKES + TableGame.MAP_TAKES + 0.2)
	_check(not node.visible, "a new map takes what stood on the last")
	var maps: Array = tg._maps
	_check((maps[0]["node"] as Node3D).visible == false and (maps[1]["node"] as Node3D).visible, "and is the one down")
	# the picture
	var rv := float(when[int((ev[7] as Dictionary)["id"])])
	var pic: Dictionary = tg._reveals[0]
	tg.tick(rv - 0.1)
	_check(not (pic["node"] as Node3D).visible, "no picture before it is shown")
	tg.tick(rv + TableGame.REVEAL_TAKES + 0.5)
	var seen: Variant = CardTable.project(tg._cam, tg._fov, (pic["node"] as Node3D).position)
	_check((pic["node"] as Node3D).visible and seen != null and absf((seen as Vector2).x - 0.5) < 0.1 and absf((seen as Vector2).y - 0.5) < 0.1, "a picture comes up in the middle of the frame: %s" % str(seen))
	tg.tick(rv + TableGame.REVEAL_LASTS + TableGame.REVEAL_TAKES + 0.5)
	_check(not (pic["node"] as Node3D).visible, "and goes")


## What shows on a die is what was rolled.
func _dice(tg: TableGame, ev: Array, when: Dictionary) -> void:
	for r in tg._rolls:
		var rd: Dictionary = r
		var id := int(rd["id"])
		var e: Dictionary = rd["event"]
		var at := float(when[id])
		var thrown := at + TableGame.RISE + TableGame.SHAKE
		var rec: Dictionary = tg._record[id]
		tg.tick(at - 0.05)
		for nd in rd["nodes"]:
			_check(not ((nd as Dictionary)["node"] as Node3D).visible, "a die is not out before it is thrown")
		tg.tick(thrown + float(rec["dur"]) + 0.3)
		var nodes: Array = rd["nodes"]
		var thrown_list: Array = e["thrown"]
		for k in nodes.size():
			var nd: Dictionary = nodes[k]
			var n: MeshInstance3D = nd["node"]
			_check(n.visible, "it has been thrown")
			var shape := int(nd["shape"])
			var face := int((thrown_list[k] as Dictionary)["face"])
			var solid := Dice.solid(shape)
			var printed_at: Vector3 = ((solid["faces"] as Array)[int((solid["printed"] as Array)[face])] as Dictionary)["normal"]
			var world: Vector3 = (n.transform.basis.orthonormalized() * printed_at).normalized()
			var up := Vector3.DOWN if shape == 4 else Vector3.UP
			_check(world.dot(up) > 0.99, "roll %d die %d shows what was rolled: %.3f" % [id, k, world.dot(up)])
			var pos := n.transform.origin
			_check(GameBoard.lands(Vector2(pos.x, pos.z)), "it is on the table in the picture")
			_check(pos.y < 0.04, "lying down: %.3f" % pos.y)
	# ...the last throw's dice go home as the next is thrown: only one throw on the table
	var r0: Dictionary = tg._rolls[0]
	var next := float(when[int((tg._rolls[1] as Dictionary)["id"])])
	tg.tick(next + TableGame.HOME_TAKES + 0.1)
	for nd in r0["nodes"]:
		_check(not ((nd as Dictionary)["node"] as Node3D).visible, "the last throw's dice have gone home")
	# Each keeps their set at their place, and a die in the air is not lying there too
	var bea_d6 := -1
	for i in tg._homes.size():
		if String((tg._homes[i] as Dictionary)["who"]) == "Bea" and int((tg._homes[i] as Dictionary)["shape"]) == 6:
			bea_d6 = i
	_check(bea_d6 >= 0, "Bea's set is at her place")
	var bea_roll := float(when[int((ev[5] as Dictionary)["id"])])
	tg.tick(bea_roll - 0.2)
	_check(((tg._homes[bea_d6] as Dictionary)["node"] as Node3D).visible, "her die lies there before she throws")
	tg.tick(bea_roll + 0.4)
	_check(not ((tg._homes[bea_d6] as Dictionary)["node"] as Node3D).visible, "and is not there as it flies")


func _sound(tg: TableGame, ev: Array, when: Dictionary) -> void:
	var id := int((ev[3] as Dictionary)["id"])
	var at := float(when[id])
	_check(tg.sounds_in(at - 0.5, at).is_empty(), "nothing is heard before a throw")
	var shake := tg.sounds_in(at, at + TableGame.RISE + TableGame.SHAKE)
	_check(not shake.is_empty(), "dice in a hand rattle")
	var rec: Dictionary = tg._record[id]
	var thrown := at + TableGame.RISE + TableGame.SHAKE
	var landed := tg.sounds_in(thrown, thrown + float(rec["dur"]) + 0.1)
	_check(landed.size() >= 2, "and hit the table: %d" % landed.size())
	for s in landed:
		var d: Dictionary = s
		_check(float(d["t"]) >= thrown and float(d["t"]) <= thrown + float(rec["dur"]) + 0.1, "a hit is during the throw")
		_check(float(d["strength"]) > 0.0, "and has a strength")
	var lying := tg.sounds_in(thrown + float(rec["dur"]) + 0.5, thrown + float(rec["dur"]) + 2.0)
	_check(lying.is_empty(), "what lies still is silent")
