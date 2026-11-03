extends Node

## WHAT IS BUILT, ON A MOUNTED TABLE ([TableAssembly], next/assembly.md): a stock finds its inside on a real thing by rays, its pieces
## lie inside the walls, a thing with no hollow holds none and says so, nothing else stands on the plate, the acts are scheduled under
## the words and through their silences, the build is heard no louder than the rest of the work, and what `act` tells a puppeteer is
## true. A hour of it costs the bake next to nothing, for nothing in it is the bake's.
##
##   tests/run_boot_probe.sh tests/table/assembly_table_check.gd 300
##
## Controls: a solid thing named as a stock's container holds nothing; a tub moved whole is refused; a passage far too short for what
## it stands over gets a silence; a table with no `assembly` has none and an `assemble` track on it is refused.
##
## A BOOT probe (the medium reaches the Director); no GPU - what is checked is where things are, never pixels.

const DIR := "user://assembly_table_check"
const Look := preload("res://tests/table/assembly_look_probe.gd")

var medium: TableMedium
var subs: Subtitles
var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


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
	_stands()
	_scheduled()
	_said()
	_heard()
	_long_show()
	_prompts()
	_silence_fits()
	_no_hollow()
	_no_assembly()
	Director.hold(false)
	Director.detach()
	stage.queue_free()
	print("assembly_table_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	get_tree().quit(1 if _fails > 0 else 0)


func _build(table: Dictionary, acts: Dictionary, said: Dictionary) -> void:
	var f := FileAccess.open(DIR.path_join("table.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(table))
	f.close()
	var a := FileAccess.open(DIR.path_join("acts.json"), FileAccess.WRITE)
	a.store_string(JSON.stringify(acts))
	a.close()
	var positions := [{"name": "one", "asks": "x", "work": "a wall"}, {"name": "two", "asks": "y", "work": "a floor"}, {"name": "three", "asks": "z", "work": "down"}]
	var plan := {"look": {"candles": 0, "palette": ["#3a2a20", "#c8a060"]}, "spread": {"positions": positions}, "work_close": "", "staging": {"source": "none"}, "assembly": true}
	var passages: Array = []
	for m in TableProducer.choreography(plan, []):
		var say := String(m.get("say", ""))
		passages.append({"kind": m["kind"], "card": m.get("card", 0), "text": String(said.get(say, "A few plain words said for a while at an easy pace."))})
	var script := CardReading.compose(passages)
	subs.words = Look.timeline(CardReading.parse(script), Director.intro_hold)
	subs.document = {"source": script, "title": "Bricks Check", "table": {"show": "assembly-table-check", "seed": 41, "dir": DIR, "plan": plan, "cards": []}}
	medium._key = ""
	medium._ensure_doc()
	medium._follow.extend(subs.words)
	medium._sched = medium._follow.place(medium._plan.parse["actions"], maxf(Director.intro_hold, 0.6), TableMedium.LEAD, TableMedium.TAIL)
	medium._work.schedule(medium._sched, medium._plan.parse, medium._follow.said0, medium._follow.said1, medium._est, 0.0)


const SAID := {
	"say:intro": "<!-- act: first-look --> <!-- quiet: 14 --> So. A long day and nothing much to show for it. <!-- quiet: 8 --> I was going to do something with these.",
	"say:1": "<!-- act: start-wall --> Somebody at work said a thing today that I keep turning over. <!-- quiet: 40 --> It was not even about me, and I still cannot stop thinking about it, you know how that goes.",
	"say:2": "<!-- act: more --> I think this wants to be a house, or it did. <!-- quiet: 50 --> Anyway. My dad had a tub just like that one, in the basement, with a broken lid. <!-- quiet: 12 -->",
	"say:close": "<!-- act: down-it-comes --> No. That wall was wrong from the start, and I knew it. <!-- quiet: 16 --> Brick by brick.",
}


func _stands() -> void:
	_build(Look._table(), Look._acts(), SAID)
	var w: TableWork = medium._work
	_ok(w.assembly != null, "a table with an `assembly` has one")
	if w.assembly == null:
		return
	var lg: Assembly = w.assembly.log
	var heaps: Dictionary = lg.world["heaps"]
	_ok(heaps.has("the tub") and heaps.has("the pile") and heaps.has("aside"), "its stocks stood, and an aside: %s" % str(heaps.keys()))
	var tub: AssemblyHeap = heaps["the tub"]
	_ok(tub.thing == "toy tub", "the tub's stock knows its thing")
	# THE TUB'S INSIDE IS ITS INSIDE: the walls left out
	var ti := w._thing_named("toy tub")
	var box: AABB = w._world_rest_thing(ti) * ((w.things[ti] as Dictionary)["box"] as AABB)
	var inner_x := box.size.x - 0.024
	var cells := float(tub.area_cells()) * AssemblyHeap.CELL * AssemblyHeap.CELL
	_ok(cells > 0.7 * inner_x * (box.size.z - 0.024) and cells < 1.05 * box.size.x * box.size.z, "the rays found the tub's inside: %.3f m2 of %.3f" % [cells, box.size.x * box.size.z])
	_ok(not is_nan(tub.bed), "a deep tub is filled over a false floor: %.3f, its rim %.3f" % [tub.bed, tub.rim])
	# EVERY PIECE IN IT LIES INSIDE ITS WALLS, none over the rim by much
	var out := 0
	var over := 0
	var in_tub := 0
	for id in lg.pieces.size():
		var rests: Array = (lg.pieces[id] as Dictionary)["rests"]
		if rests.is_empty() or not tub.holds(id):
			continue
		var p: Vector3 = ((rests[rests.size() - 1] as Array)[2] as Transform3D).origin
		in_tub += 1
		if p.x < box.position.x or p.x > box.end.x or p.z < box.position.z or p.z > box.end.z:
			out += 1
		if p.y > tub.rim + 0.03:
			over += 1
	_ok(in_tub > 100, "the tub holds what fills it: %d" % in_tub)
	_ok(out == 0, "nothing in the tub lies through its walls: %d of %d" % [out, in_tub])
	_ok(over == 0, "nothing stands far over its rim: %d" % over)
	# NOTHING ELSE MAY STAND ON THE PLATE OR A PILE
	var keep: Array = medium._things_part.off_limits()
	var at := TableAssembly.base_center(w.assembly_spec, medium._plan)
	_ok(keep.any(func(r: Rect2) -> bool: return r.has_point(at)), "the plate keeps its room on the table")
	_ok(keep.any(func(r: Rect2) -> bool: return r.has_point(Vector2(0.34, -0.08 + Tables.ORIGIN.y))), "a pile keeps its room")
	_ok(not w.notes.has("the stock"), "nothing to say of its stocks: %s" % str(w.notes))


func _scheduled() -> void:
	var w: TableWork = medium._work
	if w.assembly == null:
		return
	var lg: Assembly = w.assembly.log
	var times := {}
	for r in w.runs:
		times[String((w.acts[int((r as Dictionary)["i"])] as Dictionary)["name"])] = [float(r["t0"]), float(r["t1"])]
	_ok(times.size() == 4, "every act placed: %s" % str(times.keys()))
	var words: Array = subs.words
	# THE FIRST ACT BEGINS AS THE VIDEO DOES, not after its opening silence
	var first_word := float((words[0] as Dictionary)["t0"])
	_ok(float((times["first-look"] as Array)[0]) < first_word - 8.0, "a beat that opens in silence begins before its first word: %.1f, the word at %.1f" % [float((times["first-look"] as Array)[0]), first_word])
	# ...AND WHAT WAS CUED AT A WORD WAITS FOR ITS WORD, in a silence or not
	var si: int = (medium._plan.parse["cues"] as Array).filter(func(c: Dictionary) -> bool: return String(c["name"]) == "start-wall")[0]["si"]
	_ok(absf(float((times["start-wall"] as Array)[0]) - float((words[si] as Dictionary)["t0"])) < 0.6 or float((times["start-wall"] as Array)[0]) >= float((words[si] as Dictionary)["t0"]) - 0.1, "an act cued at a word begins at it")
	# A BEAT'S LAST SILENCE IS ITS OWN
	var more_end := float((times["more"] as Array)[1])
	# ...`more` is beat 2's, and beat 3's mark comes after the last word of beat 2's passage
	var next_mark: int = int((medium._plan.parse["actions"] as Array).filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "work" and int(a["card"]) == 3)[0]["after"])
	var ended_at := float((words[next_mark - 1] as Dictionary)["t1"])
	_ok(more_end > ended_at + 4.0, "the work goes on through a silence its words end on: to %.1f, the last word %.1f" % [more_end, ended_at])
	# THE STEPS ARE IN ORDER, AND EACH OF AN ACT WITHIN ITS TIME
	var ordered := true
	for k in range(1, lg.steps.size()):
		if lg._t0[k] < lg._t1[k - 1] - 1e-3:
			ordered = false
	_ok(ordered, "one hand: no step begins before the last has ended")
	# A MOVE IS NEVER SLOWER THAN ITS EASY PACE, however much time it has
	var slow := 0
	for k in lg.steps.size():
		var st: Dictionary = lg.steps[k]
		if String(st["do"]) != "pause" and lg._t1[k] - lg._t0[k] > float(st["natural"]) + 1e-3:
			slow += 1
	_ok(slow == 0, "time left over falls between moves: %d moves stretched" % slow)
	# A TUB MOVED WHOLE IS REFUSED: what is in it would be left in the air
	var raw := Look._acts().duplicate(true)
	(raw["acts"] as Array).append({"name": "shift-tub", "beat": 1, "about": "x", "length": 3, "tracks": [{"thing": "toy tub", "law": "carry", "to": [10, 0, 10]}]})
	medium.rework(raw)
	_ok(Array(w.notes).any(func(n: String) -> bool: return n.contains("toy tub") and n.contains("stays")), "control: what holds a stock stays where it stands: %s" % str(w.notes))
	_build(Look._table(), Look._acts(), SAID)


func _said() -> void:
	var w: TableWork = medium._work
	if w.assembly == null:
		return
	var parts := w.parts_report()
	_ok(parts.contains("THE ASSEMBLY") and parts.contains("the tub") and parts.contains("aside"), "`parts` says what is built here and where the pieces wait")
	var times := w.rehearsed()
	_ok(times.has("start-wall"), "the acts rehearse")
	var nat: float = float((times["start-wall"] as Array)[1]) - float((times["start-wall"] as Array)[0])
	_ok(nat > 40.0, "rehearsed, an act that builds takes its easy time, never a guess: %.1f" % nat)
	var said := String(w.check("start-wall")["text"])
	_ok(said.contains("put x") and said.contains("level 0:"), "`act` says what it does and shows the model: %s" % said.left(300))
	_ok(not said.contains("Nothing in it moves"), "...and never that nothing moves")
	var raw := Look._acts().duplicate(true)
	((((raw["acts"] as Array)[1] as Dictionary)["tracks"] as Array)[0] as Dictionary)["ops"].append({"do": "put", "part": "brick 2x4 tan", "at": [40, 40]})
	medium.rework(raw)
	w.rehearsed()
	var refused := String(w.check("start-wall")["text"])
	_ok(refused.contains("COULD NOT") and refused.contains("[40, 40]"), "control: `act` says what could not be done: %s" % refused.left(300))
	_build(Look._table(), Look._acts(), SAID)


## THE BUILD, HEARD ([WorkSounds]): a dig and a press are heard, and nothing is louder than the rest of the work is allowed to be.
func _heard() -> void:
	var w: TableWork = medium._work
	if w.assembly == null:
		return
	var lg: Assembly = w.assembly.log
	var sounds := WorkSounds.new(w)
	var dig := -1
	var put := -1
	for k in lg.steps.size():
		if dig < 0 and String((lg.steps[k] as Dictionary)["do"]) == "dig":
			dig = k
		if put < 0 and String((lg.steps[k] as Dictionary)["do"]) == "put":
			put = k
	var peak_dig := _rendered_peak(sounds, lg._t0[dig], lg._t1[dig])
	var peak_put := _rendered_peak(sounds, lg._t0[put], lg._t1[put])
	var peak_pause := _rendered_peak(sounds, lg._t1[lg.steps.size() - 1] + 2.0, lg._t1[lg.steps.size() - 1] + 3.0)
	_ok(peak_dig > 0.002, "a dig is heard: %.4f" % peak_dig)
	_ok(peak_put > 0.004, "a press is heard: %.4f" % peak_put)
	_ok(peak_dig <= WorkSounds.PEAK_MOST and peak_put <= WorkSounds.PEAK_MOST, "and neither over what the work may reach: %.4f, %.4f, the most %.3f" % [peak_dig, peak_put, WorkSounds.PEAK_MOST])
	_ok(peak_pause < 0.001, "control: past the last step nothing is heard: %.5f" % peak_pause)
	sounds.stop()


func _rendered_peak(sounds: WorkSounds, t0: float, t1: float) -> float:
	sounds._restart(t0)
	var n := int((t1 - t0) * float(WorkSounds.RATE))
	var out := sounds.render(n)
	var peak := 0.0
	for s in out:
		peak = maxf(peak, maxf(absf(s.x), absf(s.y)))
	return peak


## AN HOUR OF IT (the user: "The video might be long"): nothing here is the bake's, so its frames come to nothing, and a frame of
## the assembly costs what moves. Measured by the frames a bake keeps, never by a clock.
func _long_show() -> void:
	var w: TableWork = medium._work
	if w.assembly == null or w.physics == null:
		return
	var lg: Assembly = w.assembly.log
	w.physics.bake_until(600.0)
	var f0: Variant = w.physics.frame_at(120.0)
	var f1: Variant = w.physics.frame_at(590.0)
	_ok(w.physics.baked_to() >= 590.0, "ten minutes of it bakes: to %.1f" % w.physics.baked_to())
	_ok(f0 != null and f0 == f1, "and leaves the bake with nothing to change, all %d pieces of it outside it" % lg.pieces.size())


## THE PROMPTS, WHOLE, with a show that builds and goes quiet: every name filled in.
func _prompts() -> void:
	var w: TableWork = medium._work
	Rules.clear()
	var plan := {"look": {"candles": 0, "palette": ["#3a2a20"], "light": {"kind": "a lamp", "color": "#ffe2bd", "warmth": "warm"}, "surface": "oak", "setting": "a room"},
		"spread": {"positions": [{"name": "one", "asks": "x", "work": "a wall"}]}, "staging": {"source": "none"}, "assembly": true, "quiet": 0.5,
		"episode_title": "T", "premise": "p", "audience": "a", "topic": "t", "reader_mood": "m"}
	var acts: Array = Motions.sanitize_acts(Look._acts(), 3)["acts"]
	var pup := TablePrompts.puppeteer("Show", "a brief", plan, 3, [], w.parts_report() if w != null else "", 12)
	_ok(String(pup["prompt"]).contains("assemble") and String(pup["prompt"]).contains("brick 2x4 red"), "the puppeteer is told what can be built, in the registry's words")
	var plain := plan.duplicate(true)
	plain["assembly"] = false
	_ok(not String(TablePrompts.puppeteer("Show", "a brief", plain, 3, [], "", 12)["prompt"]).contains("brick"), "control: a show that builds nothing never hears of bricks")
	var said := TablePrompts.reader("Show", "a brief", plan, "1", [], [], 1, false, [], [], [], true, false, [], Motions.of_beat(acts, "1"))
	var prompt := String(said["prompt"])
	_ok(prompt.contains("<!-- quiet:") and prompt.contains("NOBODY TALKS THROUGH ALL OF IT"), "a quiet show's reader is told to write its silences")
	var natural := float((Motions.of_beat(acts, "1")[0] as Dictionary)["length"])
	var budget := Manuscript._rx("Write (\\d+) to (\\d+) words").search(prompt)
	_ok(budget != null and int(budget.get_string(2)) < natural / TablePrompts.SAID_WORD, "its words are fewer than its work's time would take: %s, for %.0f s" % [budget.get_string(0) if budget != null else "none", natural])
	var talky := plan.duplicate(true)
	talky["quiet"] = 0.0
	var loud := TablePrompts.reader("Show", "a brief", talky, "1", [], [], 1, false, [], [], [], true, false, [], Motions.of_beat(acts, "1"))
	_ok(not String(loud["prompt"]).contains("NOBODY TALKS"), "control: a show with no quiet is told nothing of it")
	var set_p := TablePrompts.set_dresser("Show", "a brief", plan, 3, {}, [], false, 12)
	_ok(String(set_p["prompt"]).contains("`assembly`"), "the set dresser is told how to say where the pieces wait")
	_ok(Rules.missing.is_empty(), "every name filled in: %s" % str(Rules.missing.slice(0, 6)))
	Rules.clear()


func _silence_fits() -> void:
	# ...of what it stands over: its words alone would run out long before the work does
	var acts := [{"name": "a", "_natural": 120.0}]
	var words := "One thing happened. Another thing did after that. And then it stopped."
	var fit := TableProducer.fit_silence(words, acts)
	_ok(fit.contains("<!-- quiet:"), "a passage far too short for its work takes a silence: %s" % fit)
	_ok(fit.begins_with("One thing happened. Another thing did after that. <!--"), "before its last sentence, so its last words are after it: %s" % fit)
	var enough := TableProducer.fit_silence("One word. <!-- quiet: 200 --> Another.", acts)
	_ok(not enough.contains("quiet: 20 ") and enough.count("quiet:") == 1, "control: one that already leaves room is left alone: %s" % enough)
	_ok(TableProducer.fit_silence(words, [{"name": "b"}]) == words, "control: work with no floor is no reason for silence")


func _no_hollow() -> void:
	var t := Look._table().duplicate(true)
	(t["things"] as Array).append({"name": "solid block", "at": [35, -25], "parts": [{"shape": "box", "size": [12, 8, 12], "material": "oak"}]})
	var a: Dictionary = t["assembly"]
	(a["stock"] as Array).append({"name": "the block", "thing": "solid block"})
	_build(t, Look._acts(), SAID)
	var w: TableWork = medium._work
	_ok(w.assembly != null and not (w.assembly.log.world["heaps"] as Dictionary).has("the block"), "control: a solid thing holds nothing")
	_ok(Array(w.notes).any(func(n: String) -> bool: return n.contains("the block")), "...and it is said: %s" % str(w.notes))
	var named: Array = (w.assembly.spec["stock"] as Array).map(func(q: Dictionary) -> String: return String(q["name"]))
	_ok(not named.has("the block"), "...and no step can ask it for a piece")


func _no_assembly() -> void:
	var t := Look._table().duplicate(true)
	t.erase("assembly")
	_build(t, Look._acts(), SAID)
	var w: TableWork = medium._work
	_ok(w.assembly == null, "control: a table with no `assembly` has none")
	_ok(w.acts.is_empty(), "...and an act of it is refused")
	_ok(Array(w.notes).any(func(n: String) -> bool: return n.contains("no `assembly`")), "...and says so: %s" % str(w.notes))
