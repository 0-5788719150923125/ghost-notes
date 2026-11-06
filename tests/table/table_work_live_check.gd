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
##   moment looked at, A TRAIL, NEVER TUFTS (the-quiet-crucible 181083: "normal heat would produce consistent steam
##   trails") - its young puffs born no further apart than half a puff's size takes to rise (the control: every
##   other one left out is caught); a jar of ink tipped over the brew pours by itself (next/table_physics.md) - its stream
##   shows while it flows and none after, the jar holds less and the brew more; the brew is its new color when the pour is
##   done; a cue's burst and the hatchlings' huffs have their particles.
## - A SCRUB IN THE SAME EPISODE IS A SEEK ([method TableMedium._seek_to]; 2026-11-01, scrubbed back: "it's just stuck on
##   'catching up' ... It might be best if we just saved the buffer"): the reading started again from a word before the grind -
##   its words timed from 0, the document naming where it starts, as the reading hands a scrub - keeps the table, its work and
##   what was baked: nothing built or baked again, the new reading's clock where its first word was heard before, and the pestle
##   drawn where it was at that moment.
## - A SKIP AHEAD LANDS IN THE WORLD THE READING WOULD HAVE REACHED (2026-11-01, the user, skipping an intro watched 20 times: "ensure that
##   timeline scrubbing can recover properly"): only a reading's first words heard, then started again past the grind's word - the
##   acts of the words skipped are placed before the landing, each at its written length, never all at once as it lands.
## - A READING FROM THE TOP AGAIN IS NO SCRUB (2026-11-06, the intro lengthened between a Stop and a Play, "the speaking starting DURING
##   the intro sequence"): the table and its work stand, its clock starts over and its plan takes the new intro - its work later with its
##   words; the control, the same reading named as a scrub to its first word, has its clock put on.
## - THE CONTROL: the same table with no acts - nothing scheduled, no stream, no cue - and its clock still runs; and, its acts
##   written again, it is a new table, never the last one sought in.
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
			{"shape": "lathe", "profile": [[0, 0], [3, 0], [3, 8], [2.4, 8.6], [2.4, 9.4], [2.1, 9.4], [2.1, 8.6], [2.7, 8], [2.7, 0.3], [0, 0.3]],
				"material": "glass"},
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
		# ...up, over the cauldron's rim and down beside it, never through it, and set down on the table after its pour: carried
		# in a low arc its foot had gone through the rim on the way, and left in the air after the pour it was let go over the
		# brew - now that a thing an act moves is solid, it was stopped at the rim and fell into the brew
		{"name": "fetch-jar", "beat": 1, "about": "the jar is carried to the cauldron", "length": 3,
			"tracks": [{"thing": "jar", "law": "path", "keys": [{"at": 0.0}, {"at": 0.35, "by": [0, 22, 0]}, {"at": 0.8, "by": [32, 22, -10]},
				{"at": 1.0, "by": [32, 15, -10]}]}]},
		{"name": "pour-ink", "beat": 1, "about": "the ink is poured into the brew", "length": 4,
			"tracks": [{"thing": "jar", "law": "path", "keys": [{"at": 0.1}, {"at": 0.35, "turn": [0, 0, 110]}, {"at": 0.75, "turn": [0, 0, 110]}, {"at": 0.85}]},
				{"thing": "jar", "law": "carry", "to": [-8, 0, -10], "lift": 8, "down": true, "between": [0.86, 1.0]},
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
	_seek()
	_skip()
	_restarted()
	_laid_rests()
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
	# A TRAIL: the puffs in the air born no further apart than a trail's spacing - those young enough to be seen
	# whole (a puff thins from half its life on, and the oldest die each at their own age)
	if not (w._plumes as Array).is_empty():
		var p: Dictionary = w._plumes[0]
		var look: Dictionary = p["look"]
		var spacing := float(look["size"]) * 0.001 * 0.5 / float(look["rise"])
		var young := float(p["life"]) * 0.75 * 0.45
		_posed(77.0)
		var births: Array = []
		for life in (p["lives"] as PackedVector2Array):
			if 77.0 - life.x >= 0.0 and 77.0 - life.x <= minf(life.y, young):
				births.append(life.x)
		births.sort()
		var gap := func(list: Array) -> float:
			var most := 0.0
			for i in range(1, list.size()):
				most = maxf(most, float(list[i]) - float(list[i - 1]))
			return most
		var halved: Array = births.filter(func(b: float) -> bool: return births.find(b) % 2 == 0)
		_ok(births.size() > 4 and float(gap.call(births)) <= spacing + 0.001, "the steam is a trail: %d puffs in the air, at most %.3f s apart (a trail's %.3f)" % [
			births.size(), float(gap.call(births)), spacing])
		_ok(float(gap.call(halved)) > spacing + 0.001, "control: every other puff left out leaves gaps (%.3f s)" % float(gap.call(halved)))
	# THE TIP IS THE POUR: its stream while it flows and not after, the jar emptier and the brew fuller; the brew its new
	# color once poured
	var pour := _run_of("pour-ink")
	var ph: TablePhysics = w.physics
	var ink := -1
	var brew := -1
	for li in ph.liquids.size():
		var nm := String((w.things[int((ph.liquids[li] as Dictionary)["thing"])] as Dictionary)["name"])
		if bool((ph.liquids[li] as Dictionary)["made"]):
			if nm == "jar":
				ink = li
			elif nm == "cauldron":
				brew = li
	if not pour.is_empty() and ink >= 0 and brew >= 0:
		_posed(float(pour["t0"]))
		var ink0 := float(((ph.frame_at(float(pour["t0"])) as Dictionary)["liq"] as PackedFloat32Array)[ink * 16])
		var brew0 := float(((ph.frame_at(float(pour["t0"])) as Dictionary)["liq"] as PackedFloat32Array)[brew * 16])
		# a wide jar tipped past level empties in about a second, as it tips: looked for through the whole act
		var mid_shown := false
		for k in 28:
			_posed(lerpf(float(pour["t0"]), float(pour["t1"]), 0.05 + 0.03 * float(k)))
			for s in ph._streams:
				mid_shown = mid_shown or (s as MeshInstance3D).visible
		_posed(float(pour["t1"]) + 1.5)
		var after_shown := false
		for s in ph._streams:
			after_shown = after_shown or (s as MeshInstance3D).visible
		_ok(mid_shown and not after_shown, "the stream shows while the ink pours (%s) and not after (%s)" % [mid_shown, after_shown])
		var f1: Dictionary = ph.frame_at(float(pour["t1"]) + 1.5)
		var ink1 := float((f1["liq"] as PackedFloat32Array)[ink * 16])
		var brew1 := float((f1["liq"] as PackedFloat32Array)[brew * 16])
		_ok(ink1 < ink0 * 0.8 and brew1 > brew0 + (ink0 - ink1) * 0.5, "tipped over the brew, the jar went from %.0f to %.0f ml and the brew from %.0f to %.0f" % [
			ink0 * 1e6, ink1 * 1e6, brew0 * 1e6, brew1 * 1e6])
		var bi: int = w._work_of(w._thing_named("cauldron"), "brew")
		var c: Color = ((w.works[bi] as Dictionary)["mats"][0] as ShaderMaterial).get_shader_parameter("color")
		_ok(c.is_equal_approx(Color.html("#5a2a6a")), "the brew is not its new color once poured: %s" % c.to_html(false))
	else:
		_ok(false, "the pour, the jar's ink or the cauldron's brew was not found (%d, %d)" % [ink, brew])
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


func _seek() -> void:
	var w = medium._work
	var ph: TablePhysics = w.physics
	var grind := _run_of("grind")
	if grind.is_empty() or ph == null:
		_ok(false, "the seek: no grind, or no physics, to scrub back over")
		return
	var at := float(grind["t0"]) + 1.0
	ph.bake_until(at + 2.0)
	var baked := ph.baked_to()
	var pestle: int = w._work_of(w._thing_named("pestle"), "pestle")
	var before: Variant = ph.pose_of(pestle, at)
	# ...the reading started again from the word some seconds before the grind
	var words: Array = subs.words
	var fi := 0
	while fi < words.size() - 1 and float((words[fi] as Dictionary)["t0"]) < float(grind["t0"]) - 4.0:
		fi += 1
	var si := int(medium._follow.map[fi])
	var t_start := float((words[fi] as Dictionary)["t0"])
	var again: Array = []
	for i in range(fi, words.size()):
		var wd: Dictionary = (words[i] as Dictionary).duplicate()
		wd["t0"] = float(wd["t0"]) - t_start + 0.25
		wd["t1"] = float(wd["t1"]) - t_start + 0.25
		again.append(wd)
	var doc: Dictionary = (subs.document as Dictionary).duplicate()
	var spoken: PackedStringArray = medium._plan.parse["spoken"]
	doc["start_words"] = spoken.slice(si, si + 8)
	doc["start_index"] = si
	doc["start_time"] = t_start
	medium.release()
	subs.queue_free()
	subs = preload("res://src/show/subtitles.gd").new()
	add_child(subs)
	subs.document = doc
	subs.words = again
	medium.bind_captions(subs)
	medium._ensure_doc()
	medium._follow.extend(subs.words)
	medium._sched = medium._follow.place(medium._plan.parse["actions"], maxf(Director.intro_hold, 0.6), TableMedium.LEAD, TableMedium.TAIL)
	medium._work.schedule(medium._sched, medium._plan.parse, medium._follow.said0, medium._follow.said1, medium._est, at)
	var after: Variant = ph.pose_of(pestle, at)
	_ok(is_same(medium._work, w), "the seek: the table is %s" % ("the one standing" if is_same(medium._work, w) else "BUILT AGAIN"))
	_ok(absf(medium._follow.offset - (t_start - 0.25)) < 1e-3, "the seek: the new reading's clock is put %.2f s on - where its first word was heard, %.2f s" % [
		medium._follow.offset, t_start - 0.25])
	_ok(absf(ph.baked_to() - baked) < 1e-3, "the seek: what was baked stands - to %.2f s, where it was %.2f s" % [ph.baked_to(), baked])
	_ok(before != null and after != null and (after as Transform3D).origin.distance_to((before as Transform3D).origin) < 1e-4,
		"the seek: the pestle at %.1f s of the episode is where it was drawn before" % at)


func _skip() -> void:
	_build(_acts())
	var w = medium._work
	var words: Array = subs.words
	var spoken: PackedStringArray = medium._plan.parse["spoken"]
	# ...the reading from its top, its first words heard
	medium._follow.reset(spoken, -1, medium._est)
	medium._follow.extend(words.slice(0, 5))
	w._begun = {}
	w._last_now = -INF
	w._plan_key = ""
	var heard_to := float((words[4] as Dictionary)["t1"])
	medium._sched = medium._follow.place(medium._plan.parse["actions"], maxf(Director.intro_hold, 0.6), TableMedium.LEAD, TableMedium.TAIL)
	w.schedule(medium._sched, medium._plan.parse, medium._follow.said0, medium._follow.said1, medium._est, heard_to)
	_ok(_run_of("grind").is_empty(), "the skip: before it, the grind's word not heard, the grind is not placed")
	# ...and started again a few words past the grind's
	var fi := 0
	while fi < words.size() - 1 and String((words[fi] as Dictionary)["text"]).to_lower().find("grind") < 0:
		fi += 1
	fi = mini(fi + 3, words.size() - 1)
	var si := spoken.find(TabletScript.norm(String((words[fi] as Dictionary)["text"])), spoken.find("grind"))
	var t_start := float((words[fi] as Dictionary)["t0"])
	var again: Array = []
	for i in range(fi, words.size()):
		var wd: Dictionary = (words[i] as Dictionary).duplicate()
		wd["t0"] = float(wd["t0"]) - t_start + 0.25
		wd["t1"] = float(wd["t1"]) - t_start + 0.25
		again.append(wd)
	var doc: Dictionary = (subs.document as Dictionary).duplicate()
	doc["start_words"] = spoken.slice(si, si + 8)
	doc["start_index"] = si
	doc["start_time"] = t_start
	medium.release()
	subs.queue_free()
	subs = preload("res://src/show/subtitles.gd").new()
	add_child(subs)
	subs.document = doc
	subs.words = []
	medium.bind_captions(subs)
	medium._ensure_doc()
	_ok(is_same(medium._work, w), "the skip: the table is %s" % ("the one standing" if is_same(medium._work, w) else "BUILT AGAIN"))
	var at: float = medium._follow.offset
	subs.words = again.slice(0, 8)
	medium._follow.extend(subs.words)
	medium._sched = medium._follow.place(medium._plan.parse["actions"], maxf(Director.intro_hold, 0.6), TableMedium.LEAD, TableMedium.TAIL)
	w.schedule(medium._sched, medium._plan.parse, medium._follow.said0, medium._follow.said1, medium._est, at)
	for act in [["fetch-jar", 3.0], ["pour-ink", 4.0]]:
		var r := _run_of(String(act[0]))
		_ok(not r.is_empty() and float(r["t1"]) - float(r["t0"]) >= float(act[1]) * 0.9, "the skip: %s runs its written %.0f s, not squeezed: %s" % [act[0], float(act[1]),
			"not placed" if r.is_empty() else "%.2f s" % (float(r["t1"]) - float(r["t0"]))])
		_ok(not r.is_empty() and float(r["t1"]) <= at + 0.01, "the skip: %s is done before the reading lands at %.2f s: %s" % [act[0], at, "not placed" if r.is_empty() else "it ends at %.2f s" % float(r["t1"])])
	var g := _run_of("grind")
	_ok(not g.is_empty() and float(g["t0"]) < at, "the skip: the grind, its word skipped, began before the landing at %.2f s: %s" % [at, "not placed" if g.is_empty() else "at %.2f s" % float(g["t0"])])


## A READING STARTED AGAIN FROM THE TOP is no scrub ([method TableMedium._restart]; 2026-11-06, the intro set from 6 s to 9 s between a Stop
## and a Play: "the speaking starting DURING the intro sequence"): the table and its work stand, but its clock starts over and its plan
## takes the intro the show holds now - its first word estimated where the new intro ends, the grind its words' 3 s later. THE CONTROL:
## the same reading named as a scrub to its first word puts its clock on where that word was heard before.
func _restarted() -> void:
	_build(_acts())
	var w = medium._work
	var spoken: PackedStringArray = medium._plan.parse["spoken"]
	var was_hold: float = Director.intro_hold
	var grind_was := float(_run_of("grind").get("t0", -1.0))
	var heard0: float = medium._follow.st0[0]
	var again := func(start_words: bool) -> void:
		var doc: Dictionary = (subs.document as Dictionary).duplicate()
		doc.erase("start_words")
		doc.erase("start_index")
		doc.erase("start_time")
		if start_words:
			doc["start_words"] = spoken.slice(0, 8)
			doc["start_index"] = 0
		medium.release()
		subs.queue_free()
		subs = preload("res://src/show/subtitles.gd").new()
		add_child(subs)
		subs.document = doc
		subs.words = load("res://tests/table/table_look_probe.gd").timeline(CardReading.parse(String(doc["source"])), 0.36, Director.intro_hold)
		medium.bind_captions(subs)
		medium._ensure_doc()
	# ...Stop, the intro 3 s longer, Play
	Director.intro_hold = was_hold + 3.0
	again.call(false)
	_ok(is_same(medium._work, w), "the restart: the table is %s" % ("the one standing" if is_same(medium._work, w) else "BUILT AGAIN"))
	_ok(medium._follow.offset == 0.0, "the restart: its clock is put %.2f s on, as a scrub's" % medium._follow.offset)
	_ok(absf(medium._plan.hold - Director.intro_hold) < 1e-4 and medium._est.size() > 0 and medium._est[0] >= Director.intro_hold - 1e-4,
		"the restart: its plan keeps the last intro - %.1f s, its first word estimated at %.2f s - not the %.1f s it has now" % [
		medium._plan.hold, medium._est[0] if medium._est.size() > 0 else -1.0, Director.intro_hold])
	medium._follow.extend(subs.words)
	medium._sched = medium._follow.place(medium._plan.parse["actions"], maxf(Director.intro_hold, 0.6), TableMedium.LEAD, TableMedium.TAIL)
	w.schedule(medium._sched, medium._plan.parse, medium._follow.said0, medium._follow.said1, medium._est, 0.0)
	var grind_now := float(_run_of("grind").get("t0", -1.0))
	_ok(grind_was >= 0.0 and absf(grind_now - grind_was - 3.0) < 0.5, "the restart: the grind begins %.2f s later with its words, not 3 (%.2f s, then %.2f s)" % [
		grind_now - grind_was, grind_was, grind_now])
	# THE CONTROL: named as a scrub to its first word, the clock is put where that word was heard last
	var heard_last: float = medium._follow.st0[0]
	again.call(true)
	_ok(absf(medium._follow.offset - heard_last) < 1e-3 and heard_last > heard0, "THE CONTROL: a scrub to the first word puts its clock %.2f s on, not where it was heard last, %.2f s" % [
		medium._follow.offset, heard_last])
	Director.intro_hold = was_hold


## WHAT A HAND LAYS DOWN RESTS ([constant TableWork.LAID_REST]; feedback 0008, the phoenix feather: "It came to the table, touched the table, then immediately bounced
## upward again"): a jar brought back down to the table and taken up by the next act lies there first, on the reading's schedule and on the rehearsal `act` checks alike;
## one set `down` likewise. The control: a jar lowered in the air, over a cauldron, goes straight on into its pour.
func _laid_rests() -> void:
	var up := [{"at": 0.0}, {"at": 0.3, "by": [0, 12, 0]}, {"at": 0.8, "by": [10, 12, 0]}, {"at": 1.0, "by": [10, 0, 0]}]
	var acts := {"acts": [
		{"name": "lay", "beat": 1, "about": "x", "length": 2, "tracks": [{"thing": "jar", "law": "path", "keys": up}]},
		{"name": "again", "beat": 1, "about": "x", "length": 2, "tracks": [{"thing": "jar", "law": "carry", "to": [-8, 0, -10], "lift": 8, "down": true}]},
		{"name": "after-down", "beat": 1, "about": "x", "length": 2, "tracks": [{"thing": "jar", "law": "path", "keys": [{"at": 0.0}, {"at": 1.0, "by": [0, 3, 0]}]}]}]}
	_build(acts)
	var w: TableWork = medium._work
	var gap := float(_run_of("again").get("t0", 0.0)) - float(_run_of("lay").get("t1", 0.0))
	var gap_down := float(_run_of("after-down").get("t0", 0.0)) - float(_run_of("again").get("t1", 0.0))
	_ok(gap >= TableWork.LAID_REST - 0.01, "a jar brought down to the table lies %.2f s before its next act takes it up (at least %.1f)" % [gap, TableWork.LAID_REST])
	_ok(gap_down >= TableWork.LAID_REST - 0.01, "a jar set `down` lies %.2f s before its next act" % gap_down)
	var times: Dictionary = w.rehearse(0.0)
	var again_at := float((times["again"] as Array)[0]) - float((times["lay"] as Array)[1])
	_ok(again_at >= TableWork.LAID_REST - 0.01, "the rehearsal `act` checks gives it the same rest (%.2f s)" % again_at)
	_build(_acts())
	var air := float(_run_of("pour-ink").get("t0", 0.0)) - float(_run_of("fetch-jar").get("t1", 0.0))
	_ok(air < TableWork.LAID_REST * 0.5, "the control: a jar lowered in the air rests %.2f s before its pour" % air)


func _control() -> void:
	_build(null)
	var w = medium._work
	# ...and no stream shown (a stream's node is made with the table, hidden, so the GPU has what it needs before a first drip -
	# TablePhysics._drawn_nodes)
	_ok((w.acts as Array).is_empty() and (w.runs as Array).is_empty() and (w.physics == null
			or (w.physics._streams as Array).all(func(n: Node) -> bool: return not (n as MeshInstance3D).visible)),
		"the control: a table with no acts schedules work - %d acts, %d runs" % [(w.acts as Array).size(), (w.runs as Array).size()])
	_posed(300.0)
	var turned := false
	for wk in w.works:
		if String((wk as Dictionary)["name"]) == "minute hand":
			turned = absf(-rad_to_deg(((wk as Dictionary)["node"] as Node3D).transform.basis.get_euler().z) - 30.0) < 0.1
	_ok(turned, "the control: the clock does not run on a table with no acts")
