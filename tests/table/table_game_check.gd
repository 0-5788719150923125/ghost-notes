extends Node

## table_game_check - A GAME ON A TABLE, AS IT PLAYS (next/tabletop.md): a session stood on a real table with its dice really thrown, then asked at each moment what is where. What shows on a die is what was rolled, once it lands; a throw comes from where its person sits; a figure stands on its square, hops to the next, lies flat when it falls and is gone with its map; a picture comes up to the lens and goes; the camera goes to the dice and comes back; dice are heard only when they are. A control: nothing has happened before its time, and the camera does not move for a throw behind a screen.
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
	# ...WHEN EACH HAPPENED: the marks a reading would place
	var when := {}
	var t := 1.0
	var sched: Array = []
	for e in ev:
		when[int((e as Dictionary)["id"])] = t
		sched.append({"a": {"kind": String((e as Dictionary)["kind"]), "card": int((e as Dictionary)["id"])}, "t0": t, "s": 1.0})
		t += 6.0
	tg.schedule(sched)
	_camera(tm, tg, ev, when)
	_board(tg, ev, when)
	_dice(tg, ev, when)
	_sound(tg, ev, when)
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
	# THE SHOT: to the dice and back, and never for what is behind a screen
	var r1: Dictionary = ev[3]
	var id := int(r1["id"])
	var thrown := float(when[id]) + TableGame.RISE + TableGame.SHAKE
	var dur := float((tg._record[id] as Dictionary)["dur"])
	_check(tg.shot_at(float(when[id]) - 1.0, base).origin.is_equal_approx(base.origin), "before a throw the camera stands where it stands")
	var close := tg.shot_at(thrown + dur + 0.2, base)
	_check(close.origin.distance_to(base.origin) > 0.2, "as the dice land it goes to them: %.2f" % close.origin.distance_to(base.origin))
	_check(tg.shot_at(thrown + dur + TableGame.SHOT_HOLDS + TableGame.SHOT_OUT + 0.5, base).origin.is_equal_approx(base.origin), "and it comes back")
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


## WHAT SHOWS ON A DIE IS WHAT WAS ROLLED.
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
			_check(GameBoard.LANDS.has_point(Vector2(pos.x, pos.z)), "it is on the table in the picture")
			_check(pos.y < 0.04, "lying down: %.3f" % pos.y)
	# ...the last throw's dice go home as the next is thrown: only one throw on the table
	var r0: Dictionary = tg._rolls[0]
	var next := float(when[int((tg._rolls[1] as Dictionary)["id"])])
	tg.tick(next + TableGame.HOME_TAKES + 0.1)
	for nd in r0["nodes"]:
		_check(not ((nd as Dictionary)["node"] as Node3D).visible, "the last throw's dice have gone home")
	# EACH KEEPS THEIR SET AT THEIR PLACE, and a die in the air is not lying there too
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
