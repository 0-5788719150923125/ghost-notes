extends Node

## WORK AT THE TABLE ON A MOUNTED TABLE (next/table_work.md; [TableWork]): what `table_work_check` holds on a
## bare medium, here on the episode's own table as the show builds it - its things stood by [TableThings],
## its air, its schedule from a reading with `work K` marks - so everything the work makes with the stage
## under it runs: the steam off a brew, a pour's stream, a cue's burst, the hatchlings' puffs.
##
##   tests/run_boot_probe.sh tests/table/table_work_live_check.gd 300
##
## - THE WORK IS FOUND ON THE TABLE: every act kept, nothing said against it; each runs in its beat - card 1's
##   after `work 1` begins, the close's after the spread - and the cued one at its word.
## - WHAT RUNS, RUNS: the clock's minute hand 30 degrees on five minutes in; the brew's steam rising at every
##   moment looked at; a jar poured into the brew shows its stream while it flows and none after; the brew is
##   its new color when the pour is done; a cue's burst and the hatchlings' huffs have their particles.
## - THE CONTROL: the same table with no acts - nothing scheduled, no stream, no cue - and its clock still runs.
##
## A BOOT probe (the medium reaches the Director); no GPU - what is checked is where things are, never pixels.

const DIR := "user://table_work_live_check"
const MATERIALS := {"iron": {"kind": "metal", "color": "#2c2a28"}, "brew": {"kind": "liquid", "color": "#3a6a3a", "color2": "#c8e0b0"},
	"stone": {"kind": "stone", "color": "#8a8580"}, "leaf": {"kind": "plant", "color": "#4a6a2a"},
	"glass": {"kind": "ceramic", "color": "#5a7a9a"}, "ink": {"kind": "liquid", "color": "#7a2050"}, "brass": {"kind": "metal", "color": "#b08d3c"}}

var medium: TableMedium
var subs: Subtitles
var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


## The bench: a cauldron with its brew steaming, a mortar and pestle, a jar with ink in it, a clock.
static func _table() -> Dictionary:
	return {"materials": MATERIALS, "things": [
		{"name": "cauldron", "at": [-30, -20], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [10, 0], [12, 10], [12.4, 12], [11.6, 12], [10, 1.5], [0, 1.5]], "material": "iron"},
			{"name": "brew", "shape": "lathe", "profile": [[0, 1.5], [9.9, 1.5], [11, 9], [0, 9]], "material": "brew",
				"points": {"mouth": [0, 9, 0]}, "start": {"boil": 0.6}, "emits": {"kind": "steam", "at": "mouth"}}]},
		{"name": "mortar", "at": [25, -22], "parts": [
			{"name": "bowl", "shape": "lathe", "profile": [[0, 0], [5, 0], [6, 5], [6.5, 5.3], [5.4, 5], [4.3, 1.2], [0, 1.2]],
				"material": "stone", "points": {"floor": [0, 1.2, 0]}},
			{"name": "herbs", "shape": "ball", "size": [3, 1, 3], "at": [0, 1.2, 0], "material": "leaf"}]},
		{"name": "pestle", "at": [38, -18], "parts": [
			{"name": "pestle", "shape": "lathe", "profile": [[0, 0], [1.1, 0, 0.5], [0.8, 4], [0.9, 12], [0, 12.4]], "smooth": true,
				"material": "stone", "joint": {"kind": "free"}, "points": {"tip": [0, 0, 0], "grip": [0, 12, 0]}}]},
		{"name": "jar", "at": [-48, -10], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [3, 0], [3, 8], [2.4, 8.6], [2.4, 9.4], [0, 9.4]], "material": "glass"},
			{"name": "ink", "shape": "lathe", "profile": [[0, 0.3], [2.7, 0.3], [2.7, 7], [0, 7]], "material": "ink", "points": {"lip": [2.4, 9.4, 0]}}]},
		{"name": "clock", "at": [50, -32], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [5, 0], [5, 1], [0, 1]], "turn": [90, 0, 0], "at": [0, 7, 0], "material": "brass"},
			{"name": "minute hand", "shape": "box", "size": [0.3, 4, 0.1], "at": [0, 7, 1.1], "material": "iron",
				"joint": {"kind": "hinge", "at": [0, 7, 1.1], "axis": [0, 0, 1]}, "runs": {"law": "turn", "rate": -0.1}}]}],
		"sound": {"creatures": [{"name": "hatchlings", "size": 0.25, "breath": 0.6, "calls": ["purr", "chirp", "huff"], "count": 3,
			"rate": 12, "side": 0.4, "near": 0.4, "awake": [0.6, 0.8]}]}}


## The work: card 1's jar poured into the brew, card 2's herbs ground, the close's brew lit.
static func _acts() -> Dictionary:
	return {"acts": [
		{"name": "fetch-jar", "beat": 1, "about": "the jar is carried to the cauldron", "length": 3,
			"tracks": [{"thing": "jar", "law": "carry", "to": "cauldron.mouth", "by": [8, 4, 0], "lift": 8}]},
		{"name": "pour-ink", "beat": 1, "about": "the ink is poured into the brew", "length": 4,
			"tracks": [{"law": "pour", "from": "jar/ink", "into": "cauldron/brew", "lip": "jar.lip", "amount": 0.8, "gain": 0.05, "between": [0.2, 0.8]},
				{"thing": "cauldron", "part": "brew", "law": "to", "value": "#5a2a6a", "between": [0.3, 0.9]}],
			"cues": [{"at": 0.5, "where": "cauldron.mouth", "burst": {"look": "smoke", "count": 12, "colors": ["#c0a8d8"]}}]},
		{"name": "grind", "beat": 2, "about": "the herbs are ground", "length": "under",
			"tracks": [{"thing": "pestle", "part": "pestle", "law": "aim",
				"tip": {"point": "tip", "around": "mortar.floor", "radius": 1.5, "period": 1.5, "press": "mortar", "gap": 0.3},
				"grip": {"point": "grip", "around": "mortar.floor", "lift": 13, "radius": 3.5, "period": 1.5}},
				{"thing": "mortar", "part": "herbs", "state": "grow", "law": "to", "value": 0.2}]},
		{"name": "light-brew", "beat": "close", "about": "the brew glows", "length": 3,
			"tracks": [{"thing": "cauldron", "part": "brew", "state": "glow", "law": "to", "value": 0.6}]}]}


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var stage := SubViewport.new()
	stage.size = Vector2i(640, 360)
	stage.own_world_3d = true
	add_child(stage)
	Director.detach()
	medium = Medium.make("table") as TableMedium
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	subs = preload("res://src/show/subtitles.gd").new()
	add_child(subs)
	medium.bind_captions(subs)
	_worked()
	_control()
	print("table_work_live_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	get_tree().quit(0 if _fails == 0 else 1)


## The episode built over the bench, with [param acts] (`acts.json`) or none: its words timed as a voice says
## them, and the work scheduled from them.
func _build(acts: Variant) -> void:
	var f := FileAccess.open(DIR.path_join("table.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_table()))
	f.close()
	if acts != null:
		var a := FileAccess.open(DIR.path_join("acts.json"), FileAccess.WRITE)
		a.store_string(JSON.stringify(acts))
		a.close()
	elif FileAccess.file_exists(DIR.path_join("acts.json")):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR.path_join("acts.json")))
	var positions := [{"name": "the base", "asks": "x", "work": "the ink is poured in"}, {"name": "the heart", "asks": "y", "work": "the herbs are ground"}]
	var plan := {"look": {"candles": 0}, "spread": {"positions": positions}, "work_close": "the brew glows"}
	var cards: Array = []
	for i in 2:
		cards.append({"key": "c%d" % i, "name": "Card %d" % i, "numeral": str(i), "reversed": false, "jumper": false,
			"position": positions[i], "booklet": {}, "art": ""})
	var passages: Array = []
	for m in TableProducer.choreography(plan, cards):
		var text := "Some words said about it at an easy pace for a while, and then a few more words after that."
		if String(m.get("say", "")) == "say:work:2":
			text = "Into the mortar they go and now we <!-- act: grind --> grind them slowly round and round, a little more, until they are fine."
		passages.append({"kind": m["kind"], "card": m.get("card", 0), "text": text if not String(m.get("say", "")).is_empty() else ""})
	var script := CardReading.compose(passages)
	var doc := {"show": "table-work-live-check", "seed": 4, "dir": DIR, "plan": plan, "cards": cards}
	subs.words = load("res://tests/table/table_look_probe.gd").timeline(CardReading.parse(script), 0.36, Director.intro_hold)
	subs.document = {"source": script, "title": "Work Check", "table": doc}
	medium._key = ""
	medium._ensure_doc()
	medium._follow.extend(subs.words)
	medium._sched = medium._follow.place(medium._plan.parse["actions"], maxf(Director.intro_hold, 0.6), TableMedium.LEAD, TableMedium.TAIL)
	medium._work.schedule(medium._sched, medium._plan.parse, medium._follow.said0, medium._follow.said1, medium._est, 0.0)


func _posed(t: float) -> void:
	medium._now = t
	medium._pose(t)
	medium._work.tick(t)
	medium._tick_air(t)


func _run_of(name: String) -> Dictionary:
	for r in medium._work.runs:
		if String((medium._work.acts[int((r as Dictionary)["i"])] as Dictionary)["name"]) == name:
			return r
	return {}


func _action_t0(kind: String, card := 0) -> float:
	for e in medium._sched:
		var a: Dictionary = (e as Dictionary)["a"]
		if String(a["kind"]) == kind and (card == 0 or int(a.get("card", 0)) == card):
			return float((e as Dictionary)["t0"])
	return INF


func _worked() -> void:
	_build(_acts())
	var w = medium._work
	_ok((w.acts as Array).size() == 4 and (w.notes as PackedStringArray).is_empty(), "the work is found on the table: %d acts kept, said against it: %s" % [(w.acts as Array).size(), "; ".join(w.notes)])
	_ok((w.runs as Array).size() == 4, "every act is scheduled: %d" % (w.runs as Array).size())
	var fetch := _run_of("fetch-jar")
	var grind := _run_of("grind")
	var close := _run_of("light-brew")
	_ok(not fetch.is_empty() and float(fetch["t0"]) >= _action_t0("work", 1) and float(fetch["t0"]) < INF, "card 1's work begins after its `work 1`: %s, the mark %s" % [fetch.get("t0"), _action_t0("work", 1)])
	_ok(not close.is_empty() and float(close["t0"]) >= _action_t0("spread"), "the close's work begins after the spread")
	var cue_si := -1
	for c in medium._plan.parse.get("cues", []):
		if String((c as Dictionary)["name"]) == "grind":
			cue_si = int((c as Dictionary)["si"])
	_ok(cue_si >= 0 and not grind.is_empty() and absf(float(grind["t0"]) - float((subs.words[cue_si] as Dictionary)["t0"])) < 0.05,
		"the cued act starts at its word: %s, its word %s" % [grind.get("t0"), (subs.words[cue_si] as Dictionary)["t0"] if cue_si >= 0 else "none"])
	# the clock runs
	_posed(300.0)
	var hand: Node3D = null
	for wk in w.works:
		if String((wk as Dictionary)["name"]) == "minute hand":
			hand = (wk as Dictionary)["node"]
	_ok(hand != null and absf(-rad_to_deg(hand.transform.basis.get_euler().z) - 30.0) < 0.1, "the clock's minute hand is 30 degrees on five minutes in: %s" % (str(-rad_to_deg(hand.transform.basis.get_euler().z)) if hand != null else "no hand"))
	# the steam rises at every moment looked at
	var steamy := 0
	for t in [5.0, 31.0, 77.0, 140.0]:
		_posed(t)
		var p: Dictionary = w._plumes[0] if not (w._plumes as Array).is_empty() else {}
		if p.is_empty():
			break
		# (a headless run's MultiMesh hands back nothing: the plume's own record of each puff)
		var alive := 0
		for life in (p["lives"] as PackedVector2Array):
			if t - life.x >= 0.0 and t - life.x <= life.y:
				alive += 1
		if alive > 0:
			steamy += 1
	var why := "no plume" if (w._plumes as Array).is_empty() else "a pool of %d" % int((w._plumes[0] as Dictionary)["n"])
	_ok(steamy == 4, "the brew's steam rises at %d of 4 moments looked at (%s)" % [steamy, why])
	# the pour's stream, while it flows and not after; the brew its new color once poured
	var pour := _run_of("pour-ink")
	if not pour.is_empty() and not (w._streams as Array).is_empty():
		var stream: MeshInstance3D = (w._streams[0] as Dictionary)["node"]
		_posed(lerpf(float(pour["t0"]), float(pour["t1"]), 0.5))
		var mid_shown := stream.visible
		_posed(float(pour["t1"]) + 1.0)
		_ok(mid_shown and not stream.visible, "the stream shows while the ink pours (%s) and not after (%s)" % [mid_shown, stream.visible])
		var bi: int = w._work_of(w._thing_named("cauldron"), "brew")
		var c: Color = ((w.works[bi] as Dictionary)["mats"][0] as ShaderMaterial).get_shader_parameter("color")
		_ok(c.is_equal_approx(Color.html("#5a2a6a")), "the brew is not its new color once poured: %s" % c.to_html(false))
	else:
		_ok(false, "the pour or its stream was not built")
	# THE PESTLE'S SHADE goes with it: gone while it grinds in the bowl, back where it stood before
	var pi: int = w._thing_named("pestle")
	var shade: Node3D = ((w.things[pi] as Dictionary)["shades"][0] as Dictionary)["node"] if not ((w.things[pi] as Dictionary)["shades"] as Array).is_empty() else null
	if shade != null:
		_posed(float(grind["t0"]) - 1.0)
		var before := shade.visible
		_posed(lerpf(float(grind["t0"]), float(grind["t1"]), 0.5))
		_ok(before and not shade.visible, "the pestle's shade does not leave with it: before %s, while it grinds %s" % [before, shade.visible])
	else:
		_ok(false, "the pestle has no shade to follow it")
	# the cue's burst and the hatchlings' huffs have their particles
	var air = w._air
	var bursts: Array = air.bursts if air != null else []
	var counts: Array = bursts.map(func(b: Dictionary) -> int: return ((b["layer"] as Dictionary)["mm"] as MultiMesh).instance_count)
	_ok(counts.size() == 2 and int(counts[0]) > 0 and int(counts[1]) > 0, "the cue's burst and the huffs' puffs were not born: %s" % str(counts))
	_ok(not (w._huffs as Array).is_empty(), "the hatchlings never huff in an hour")


func _control() -> void:
	_build(null)
	var w = medium._work
	_ok((w.acts as Array).is_empty() and (w.runs as Array).is_empty() and (w._streams as Array).is_empty(),
		"the control: a table with no acts schedules work - %d acts, %d runs" % [(w.acts as Array).size(), (w.runs as Array).size()])
	_posed(300.0)
	var turned := false
	for wk in w.works:
		if String((wk as Dictionary)["name"]) == "minute hand":
			turned = absf(-rad_to_deg(((wk as Dictionary)["node"] as Node3D).transform.basis.get_euler().z) - 30.0) < 0.1
	_ok(turned, "the control: the clock does not run on a table with no acts")
