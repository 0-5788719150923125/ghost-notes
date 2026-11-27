extends SceneTree

## head_plan_check - a speaker's head performed from a show's phrases ([HeadPlan], [HeadBank], next/head.md). It holds:
##
## - a phrase is made safe: its ranges ordered and bounded, a phrase with no move dropped, each name once in a bank;
## - a pure function of its calls, words, bank and number (control: another number performs otherwise);
## - never the same twice: one phrase performed twice in one show lands in different places;
## - a move changes the head's turn, tip and lean as it goes, the turn leading the lean - never all arriving together;
## - a called phrase begins at its word, and a move written to land on a stressed word lands on one;
## - with nothing called the head still performs from the bank (control: with no bank it rests at home);
## - through the opening and the close it keeps near home, between them it goes out to the sides (the control);
## - turned away from the microphone the voice muffles (control: facing it, it does not); the mouth never enters the windscreen;
## - as gently as the Camera card's head camera says: Reach 0 and Turns 0 keep it home facing the microphone, Pace 0.5 moves less often
##   (control: its own feel performs as before); a mouth at one ear is heard there far more than a lean is;
## - made as the words arrive it performs what the plan of all of them does (control: calmed as if the reading ended there); the head
##   rests at the chair wherever the microphone is moved;
## - measured as its designer is told: a weave crosses the ears, a calm phrase does not;
## - a bank is kept for its show and read back, the one before a version back.
##
##   godot --headless --path . --script tests/motion/head_plan_check.gd

const ROOT := "user://head_plan_check"

var _fails := 0
var _checks := 0


func _init() -> void:
	var bank := HeadBank.phrases_of(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/studio/head_bank.json")))
	_ok(bank.size() == 5, "the fixture bank reads whole (%d phrases)" % bank.size())
	var odd := HeadPlan.sanitize_phrase({"name": "Odd ONE", "moves": [{"side": [200, -300], "distance": 0.01, "turn": [90, -90]}]})
	var m0: Dictionary = (odd["moves"] as Array)[0]
	_ok(odd["name"] == "odd one" and m0["side"] == [-135.0, 135.0] and is_equal_approx(float((m0["distance"] as Array)[0]), HeadPlan.NEAREST)
		and m0["turn"] == [-90.0, 90.0], "a phrase is made safe: %s" % str(m0))
	_ok(HeadPlan.sanitize_phrase({"name": "none", "moves": []}).is_empty() and HeadBank.phrases_of({"phrases": [bank[0], bank[0]]}).size() == 1,
		"a phrase with no move is dropped, and a name is kept once")

	var words := _words(200, 0.42, 3.0)
	var calls := [{"at": float((words[60] as Dictionary)["t0"]), "name": "weave"}, {"at": float((words[120] as Dictionary)["t0"]), "name": "weave"}]
	var a := HeadPlan.make(calls, words, bank, 7)
	var b := HeadPlan.make(calls, words, bank, 7)
	var c := HeadPlan.make(calls, words, bank, 8)
	var same := true
	var other := false
	for i in 200:
		var t := float(i) * 0.4
		same = same and HeadPlan.pose_at(a, t) == HeadPlan.pose_at(b, t)
		other = other or not (HeadPlan.pose_at(a, t)["mouth"] as Vector3).is_equal_approx(HeadPlan.pose_at(c, t)["mouth"])
	_ok(same and other, "a pure function of its calls, words, bank and number (control: another number performs otherwise)")

	# the same phrase twice: its keys land apart
	var k1 := _first_key_after(a, float(calls[0]["at"]))
	var k2 := _first_key_after(a, float(calls[1]["at"]))
	_ok((k1["mouth"] as Vector3).distance_to(k2["mouth"]) > 0.01 or absf(float(k1["turn"]) - float(k2["turn"])) > 2.0,
		"one phrase performed twice is never the same: %s vs %s" % [str(k1["mouth"]), str(k2["mouth"])])
	_ok(absf(float(_first_key_after(a, float(calls[0]["at"]) - 0.01)["t"]) - float(calls[0]["at"])) < 3.0,
		"a called phrase begins at its word")

	# the turn leads, the lean lags, within one move
	var keys: Array = a["keys"]
	var leads := 0
	var moves := 0
	for i in range(1, keys.size()):
		var ka: Dictionary = keys[i - 1]
		var kb: Dictionary = keys[i]
		if absf(float(kb["turn"]) - float(ka["turn"])) < 4.0 or absf(float(kb["roll"]) - float(ka["roll"])) < 3.0 or float(kb["t"]) - float(ka["t"]) < 0.4:
			continue
		var mid := (float(ka["t"]) + float(kb["t"])) * 0.5
		var p := HeadPlan.pose_at(a, mid)
		var turned := (float(p["turn"]) - float(ka["turn"])) / (float(kb["turn"]) - float(ka["turn"]))
		var leaned := (float(p["roll"]) - float(ka["roll"])) / (float(kb["roll"]) - float(ka["roll"]))
		moves += 1
		if turned > leaned:
			leads += 1
	_ok(moves > 0 and leads >= moves * 0.7, "the turn leads the lean through a move (%d of %d moves)" % [leads, moves])

	# a move landing on a stressed word
	var stressed := _words(80, 0.4, 3.0)
	for i in stressed.size():
		(stressed[i] as Dictionary)["emph"] = 1 if i % 3 == 1 else 0
	var free_weave: Dictionary = (bank[0] as Dictionary).duplicate(true)
	for mv in free_weave["moves"]:
		(mv as Dictionary)["land"] = "free"
	var on_stress := _landed(HeadPlan.make([{"at": float((stressed[10] as Dictionary)["t0"]), "name": "weave"}], stressed, [bank[0]], 3), stressed)
	var on_free := _landed(HeadPlan.make([{"at": float((stressed[10] as Dictionary)["t0"]), "name": "weave"}], stressed, [free_weave], 3), stressed)
	_ok(on_stress > 0.2 and on_stress > on_free * 3.0, "moves written to land on stressed words land on them (%.0f%% of arrivals; control, free: %.0f%%)" % [on_stress * 100.0, on_free * 100.0])

	# with nothing called it still performs; with no bank it rests
	var idle := HeadPlan.make([], words, bank, 5)
	var rest := HeadPlan.make([], words, [], 5)
	var travel := 0.0
	var still := 0.0
	var last: Vector3 = HeadPlan.pose_at(idle, 40.0)["mouth"]
	var last_r: Vector3 = HeadPlan.pose_at(rest, 40.0)["mouth"]
	for i in range(1, 200):
		var t := 40.0 + float(i) * 0.1
		var p: Vector3 = HeadPlan.pose_at(idle, t)["mouth"]
		var q: Vector3 = HeadPlan.pose_at(rest, t)["mouth"]
		travel += p.distance_to(last)
		still += q.distance_to(last_r)
		last = p
		last_r = q
	_ok(travel > 0.3 and still < travel * 0.1, "with nothing called it performs from the bank (%.2f m in 20 s; control with no bank %.3f m)" % [travel, still])

	# the opening and the close keep near home
	var first := float((words[0] as Dictionary)["t0"])
	var lastw := float((words[words.size() - 1] as Dictionary)["t1"])
	var open_pan := 0.0
	var mid_pan := 0.0
	var close_pan := 0.0
	for i in 60:
		open_pan = maxf(open_pan, absf(HeadPlan.lane_at(idle, first + float(i) * 0.15).x))
		mid_pan = maxf(mid_pan, absf(HeadPlan.lane_at(idle, (first + lastw) * 0.5 + float(i) * 0.3).x))
		close_pan = maxf(close_pan, absf(HeadPlan.lane_at(idle, lastw - 8.0 + float(i) * 0.12).x))
	_ok(open_pan < 0.35 and close_pan < 0.45 and mid_pan > 0.6, "the opening and the close keep near home (pan up to %.2f, %.2f; between, %.2f)" % [open_pan, close_pan, mid_pan])

	# muffled turned away, clear facing; never inside the windscreen
	var away := HeadPlan.make([{"at": 1.0, "name": "turn away"}], [], [bank[2]], 2)
	var most := 0.0
	var nearest := 9.0
	for i in 120:
		var t := 1.0 + float(i) * 0.05
		most = maxf(most, HeadPlan.lane_at(away, t).z)
	for i in 2000:
		nearest = minf(nearest, (HeadPlan.pose_at(idle, float(i) * 0.05)["mouth"] as Vector3).length())
	_ok(most > 0.4 and HeadPlan.lane_at(rest, 50.0).z < 0.1, "turned away the voice muffles (%.2f; control facing %.2f)" % [most, HeadPlan.lane_at(rest, 50.0).z])
	_ok(nearest >= HeadPlan.NEAREST - 0.0005, "the mouth never enters the windscreen (nearest %.3f m)" % nearest)

	# as gently as the head camera says: Reach 0 never leaves home's side, Turns 0 never turns far, Pace 0.5 moves half as often
	var at_home := HeadPlan.make(calls, words, bank, 7, {}, -1.0, {"reach": 0.0, "turns": 0.0})
	var slow := HeadPlan.make(calls, words, bank, 7, {}, -1.0, {"pace": 0.5})
	var widest := 0.0
	var widest_still := 0.0
	var turn_most := 0.0
	var turn_still := 0.0
	for i in 400:
		var t := float(i) * 0.2
		var pa := HeadPlan.pose_at(a, t)
		var ps := HeadPlan.pose_at(at_home, t)
		widest = maxf(widest, absf((pa["mouth"] as Vector3).x))
		widest_still = maxf(widest_still, absf((ps["mouth"] as Vector3).x))
		turn_most = maxf(turn_most, absf(float(pa["turn"])))
		turn_still = maxf(turn_still, absf(float(ps["turn"])))
	_ok(widest > 0.1 and widest_still < 0.05 and turn_most > 10.0 and turn_still < 3.0,
		"Reach 0 and Turns 0 keep the head at home, facing the microphone (%.3f m aside, %.1f deg turned; control: %.3f m, %.1f deg)" % [widest_still, turn_still, widest, turn_most])
	var moves_a := (a["keys"] as Array).filter(func(k: Dictionary) -> bool: return float(k["t"]) < 60.0).size()
	var moves_slow := (slow["keys"] as Array).filter(func(k: Dictionary) -> bool: return float(k["t"]) < 60.0).size()
	_ok(moves_slow < moves_a * 0.75 and HeadPlan.make(calls, words, bank, 7, {}, -1.0, {})["keys"] == a["keys"],
		"Pace 0.5 moves less often (%d keys in a minute, the show's own %d); its own feel performs as before (the control)" % [moves_slow, moves_a])
	# made as the words arrive, it performs what the plan of all of them does, up to where they have reached (control: the close
	# calmed at the last word known, as if the reading ended there)
	var some: Array = words.slice(0, 120)
	var live := HeadPlan.make(calls, some, bank, 7, {}, -1.0, {}, false)
	var ended := HeadPlan.make(calls, some, bank, 7, {}, -1.0, {}, true)
	var reach_t := float((some[some.size() - 1] as Dictionary)["t1"]) - 4.0
	var agree := true
	var differ := false
	var t2 := 0.0
	while t2 < reach_t:
		agree = agree and (HeadPlan.pose_at(live, t2)["mouth"] as Vector3).is_equal_approx(HeadPlan.pose_at(a, t2)["mouth"])
		differ = differ or not (HeadPlan.pose_at(ended, t2)["mouth"] as Vector3).is_equal_approx(HeadPlan.pose_at(a, t2)["mouth"])
		t2 += 0.25
	_ok(agree and differ, "made as the words arrive, it performs what the plan of all of them does (control: calmed as if it ended there)")
	# the head rests at the chair: the microphone moved 20 cm to the right, the rest is 20 cm to its left
	var moved_feel := HeadPlan.feel_of([], {"x": 20.0})
	var resting := HeadPlan.make([], words, [], 7, {}, -1.0, moved_feel)
	var rest_mouth: Vector3 = HeadPlan.pose_at(resting, 5.0)["mouth"]
	_ok(is_equal_approx(snappedf((moved_feel["home"] as Vector3).x, 0.001), -0.2) and rest_mouth.x < -0.15 and HeadPlan.lane_at(resting, 5.0).x < -0.2
		and not HeadPlan.feel_of([], {}).has("home"), "the head rests at the chair: the microphone moved right, the voice rests at its left (%.3f m)" % rest_mouth.x)
	# Sway 0: the head at rest is still - no drift, breath or waver (control: the show's own wanders)
	var calm_plan := HeadPlan.make([], words, [], 7, {}, -1.0, {"sway": 0.0})
	var own_plan := HeadPlan.make([], words, [], 7, {}, -1.0, {})
	var still_most := 0.0
	var own_most := 0.0
	for i in 40:
		still_most = maxf(still_most, (HeadPlan.pose_at(calm_plan, 2.0 + i * 0.1)["eyes"] as Vector3).distance_to(HeadPlan.pose_at(calm_plan, 2.0)["eyes"]))
		own_most = maxf(own_most, (HeadPlan.pose_at(own_plan, 2.0 + i * 0.1)["eyes"] as Vector3).distance_to(HeadPlan.pose_at(own_plan, 2.0)["eyes"]))
	_ok(still_most < 0.0005 and own_most > 0.001, "Sway 0 holds the head at rest still (%.4f m; control: its own wanders %.4f m)" % [still_most, own_most])
	var feel := HeadPlan.feel_of([{"sort": "creator", "reach": 0.4, "pace": 0.6}])
	_ok(is_equal_approx(float(feel["reach"]), 0.4) and is_equal_approx(float(feel["turns"]), 1.0) and is_equal_approx(float(feel["pace"]), 0.6)
		and is_equal_approx(float(feel["sway"]), 1.0)
		and HeadPlan.feel_of([]) == HeadPlan.FEEL, "the feel is the Camera card's head camera, the rest at 1 (none set: the show's own)")
	# the head's place splits the ears far more than a lean (control: a lean's 70/30)
	var g_place := VoiceFX.lean_gains(1.0, VoiceFX.PLACE_SHARE)
	var g_lean := VoiceFX.lean_gains(1.0)
	_ok(20.0 * log(g_place.y / g_place.x) / log(10.0) > 18.0 and 20.0 * log(g_lean.y / g_lean.x) / log(10.0) < 8.0,
		"a mouth at one ear is heard there far more than a lean is (%.1f dB apart; a lean %.1f dB)" % [20.0 * log(g_place.y / g_place.x) / log(10.0), 20.0 * log(g_lean.y / g_lean.x) / log(10.0)])

	# measured
	var weave := HeadPlan.measure(bank[0])
	var calm := HeadPlan.measure(bank[4])
	_ok(float(weave["crossings"]) >= 2.0 and float(calm["crossings"]) < 0.5 and float(weave["differ"]) > 0.003,
		"measured: a weave crosses the ears (%.1f), a calm phrase does not (%.1f), and two performances differ (%.3f m)" % [weave["crossings"], calm["crossings"], weave["differ"]])

	# kept for its show
	Library.root = ROOT
	var err := HeadBank.write("A Test Show!", bank.slice(0, 2), "first")
	var err2 := HeadBank.write("A Test Show!", bank, "second")
	var back := HeadBank.read("a-test-show")
	var file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HeadBank.path_of("a-test-show")))
	_ok(err.is_empty() and err2.is_empty() and back.size() == 5 and (file["versions"] as Array).size() == 1
		and ((file["versions"] as Array)[0]["phrases"] as Array).size() == 2, "a bank is kept for its show, the one before a version back")
	_ok(HeadBank.key_of({"table": {"show": "asmr-for-influencers"}}, "/x/Other Note.md") == "asmr-for-influencers"
		and HeadBank.key_of({}, "/x/Other Note.md") == "other-note", "a show is named by its Table block, else its file")
	DirAccess.remove_absolute(HeadBank.path_of("a-test-show"))
	Library.root = Library.ROOT

	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## [param n] words, one every [param step] seconds from [param from], a sentence every eight.
func _words(n: int, step: float, from: float) -> Array:
	var out: Array = []
	for i in n:
		out.append({"text": "word.", "t0": from + float(i) * step, "t1": from + float(i) * step + step * 0.8, "emph": 1 if i % 5 == 2 else 0, "sentence": i / 8})
	return out


## The share of [param plan]'s arrivals (keys reached by a move) that fall on a stressed word of [param words].
func _landed(plan: Dictionary, words: Array) -> float:
	var reaches := 0
	var landed := 0
	for k in plan["keys"]:
		var kt := float((k as Dictionary)["t"])
		if float((k as Dictionary)["swing"]) == 0.0 or kt < float((words[10] as Dictionary)["t0"]):
			continue
		reaches += 1
		for w in words:
			if int((w as Dictionary)["emph"]) > 0 and absf(float((w as Dictionary)["t0"]) - kt) < 0.02:
				landed += 1
				break
	return float(landed) / maxf(float(reaches), 1.0)


## The first key of [param plan] after [param t].
func _first_key_after(plan: Dictionary, t: float) -> Dictionary:
	for k in plan["keys"]:
		if float((k as Dictionary)["t"]) > t:
			return k
	return {}


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
	print(("ok    " if cond else "FAIL  ") + what)
