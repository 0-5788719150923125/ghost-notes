extends Node

## What is built, on a mounted table ([TableAssembly], next/assembly.md): a stock finds its inside on a real thing by rays, its pieces
## lie inside the walls, a thing with no hollow holds none and says so, nothing else stands on the plate, the acts are scheduled under
## the words and through their silences, and what `act` tells a puppeteer is true. A table on the stage begins a real record of it,
## which the show waits for, plays from and hears (what bodies do is assembly_bake_check's). An hour of it costs next to nothing,
## since what is in things is the bake's.
##
##   tests/run_boot_probe.sh tests/table/assembly_table_check.gd 500
##
## Controls: a solid thing named as a stock's container holds nothing; a tub moved whole is refused; a passage far too short for what
## it stands over gets a silence; a table with no `assembly` has none and an `assemble` track on it is refused.
##
## A boot probe (the medium reaches the Director); no GPU - what is checked is where things are, never pixels.

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
	await _live()
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
	# the tub's inside is its inside: the walls left out
	var ti := w._thing_named("toy tub")
	var box: AABB = w._world_rest_thing(ti) * ((w.things[ti] as Dictionary)["box"] as AABB)
	var inner_x := box.size.x - 0.024
	var cells := float(tub.area_cells()) * AssemblyHeap.CELL * AssemblyHeap.CELL
	_ok(cells > 0.7 * inner_x * (box.size.z - 0.024) and cells < 1.05 * box.size.x * box.size.z, "the rays found the tub's inside: %.3f m2 of %.3f" % [cells, box.size.x * box.size.z])
	_ok(not is_nan(tub.bed), "a deep tub is filled over a false floor: %.3f, its rim %.3f" % [tub.bed, tub.rim])
	# every piece in it lies inside its walls, none over the rim by much
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
	# nothing else may stand on the plate or a pile
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
	# the video opens talking, whatever the reader wrote, and the hands are at work under it - once the table has been seen a settle
	# after the intro ([constant Openings.SETTLE])
	var first_word := float((words[0] as Dictionary)["t0"])
	_ok(absf(first_word - Director.intro_hold - Openings.SETTLE) < 1.0, "the first word is said as the video opens, its opening silence moved on: %.1f, the opening %.1f and its settle" % [first_word, Director.intro_hold])
	_ok(float((times["first-look"] as Array)[0]) <= first_word + 0.5, "and the first act has begun by then: %.1f" % float((times["first-look"] as Array)[0]))
	# ...and what was cued at a word waits for its word, in a silence or not
	var si: int = (medium._plan.parse["cues"] as Array).filter(func(c: Dictionary) -> bool: return String(c["name"]) == "start-wall")[0]["si"]
	_ok(absf(float((times["start-wall"] as Array)[0]) - float((words[si] as Dictionary)["t0"])) < 0.6 or float((times["start-wall"] as Array)[0]) >= float((words[si] as Dictionary)["t0"]) - 0.1, "an act cued at a word begins at it")
	# a beat's last silence is its own
	var more_end := float((times["more"] as Array)[1])
	# ...`more` is beat 2's, and beat 3's mark comes after the last word of beat 2's passage
	var next_mark: int = int((medium._plan.parse["actions"] as Array).filter(func(a: Dictionary) -> bool: return String(a["kind"]) == "work" and int(a["card"]) == 3)[0]["after"])
	var ended_at := float((words[next_mark - 1] as Dictionary)["t1"])
	_ok(more_end > ended_at + 4.0, "the work goes on through a silence its words end on: to %.1f, the last word %.1f" % [more_end, ended_at])
	# the steps are in order, and each of an act within its time
	var ordered := true
	for k in range(1, lg.steps.size()):
		if lg._t0[k] < lg._t1[k - 1] - 1e-3:
			ordered = false
	_ok(ordered, "one hand: no step begins before the last has ended")
	# a move is never slower than its pace, however much time it has: what is spare goes into stops
	var slow := 0
	for k in lg.steps.size():
		if lg._len[k] > float((lg.steps[k] as Dictionary)["floor"]) + 1e-3:
			slow += 1
	_ok(slow == 0, "time left over falls between moves: %d moves stretched" % slow)
	# a tub moved whole is refused: what is in it would be left in the air
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


## The build, recorded and heard: a table on the stage asks, the record is made in a process of its own, the pieces then stand where it
## has them, and what is heard is what it holds: a dig and a press are heard, a stop is not, and nothing is louder than the rest of
## the work is allowed to be.
func _heard() -> void:
	var small := {"acts": [{"name": "a-dig", "beat": "intro", "about": "digging", "length": "under", "tracks": [{"law": "assemble", "ops": [
		{"do": "dig", "in": "the pile", "seconds": 6.0}, {"do": "pause", "seconds": 4.0}, {"do": "put", "part": "brick 2x4 red", "at": [2, 2], "from": "the pile"}]}]}]}
	var table := Look._table().duplicate(true)
	# ...a small lot, for a gate does not need a tub's whole record
	((table["assembly"] as Dictionary)["stock"] as Array)[0] = {"name": "the tub", "thing": "toy tub", "fill": 0.85, "count": 30}
	((table["assembly"] as Dictionary)["stock"] as Array)[1] = {"name": "the pile", "at": [34, -8], "radius": 11, "count": 30, "colors": {"tan": 3, "white": 2, "red": 1}}
	_build(table, small, {"say:intro": "<!-- act: a-dig --> So. A long day and nothing much to show for it."})
	var w: TableWork = medium._work
	var at_stand := w.assembly.tick
	var lg: Assembly = w.assembly.log
	_ok(w.assembly.track == null, "standing, a table has made no record: a preview never does")
	var waited := w.assembly.behind(0.0)
	_ok(not waited and w.assembly.track != null and w.assembly.track.baked_to == lg.steps.size(), "a render waits for all of it: %s of %d" % [str(w.assembly.track.baked_to if w.assembly.track != null else -1), lg.steps.size()])
	if w.assembly.track == null or not w.assembly.track.stock_ready:
		return
	at_stand.call(lg._t0[0])
	var dig := 0
	var put := 2
	_ok(String((lg.steps[put] as Dictionary)["do"]) == "put", "its steps: %s" % str(lg.steps.map(func(q: Dictionary) -> String: return String(q["do"]))))
	# ...a moment of the record, at the show's time: a piece is where it says, and a stop stands still
	var tau_a := lg.tau_at(lg._t0[1] + 0.5)
	var tau_b := lg.tau_at(lg._t1[1] - 0.5)
	_ok(tau_a == tau_b, "through a pause the record stands: %.3f, %.3f" % [tau_a, tau_b])
	var sounds := WorkSounds.new(w)
	var peak_dig := _rendered_peak(sounds, lg._t0[dig], lg._t1[dig])
	var peak_put := _rendered_peak(sounds, lg._t0[put], lg._t1[put])
	var peak_pause := _rendered_peak(sounds, lg._t0[1] + 0.5, lg._t1[1] - 0.5)
	_ok(peak_dig > 0.002, "a dig is heard: %.4f" % peak_dig)
	_ok(peak_put > 0.004, "a press is heard: %.4f" % peak_put)
	_ok(peak_dig <= WorkSounds.PEAK_MOST and peak_put <= WorkSounds.PEAK_MOST, "and neither over what the work may reach: %.4f, %.4f, the most %.3f" % [peak_dig, peak_put, WorkSounds.PEAK_MOST])
	_ok(peak_pause < 0.001, "control: a stop is silent: %.5f" % peak_pause)
	sounds.stop()
	_build(Look._table(), Look._acts(), SAID)


## A show playing while its record is made, as the app's does: it waits at first, what is written lands bit by bit with no frame
## waiting on a disk, and it goes on. A gate takes the path a render takes everywhere else, so this is the only one that walks it.
## Its control: told to go on past what has landed, it would be behind.
func _live() -> void:
	var own := ProjectSettings.globalize_path("res://dist/assembly_bakes/live_check")
	if DirAccess.dir_exists_absolute(own):
		for d in DirAccess.get_directories_at(own):
			for f in DirAccess.get_files_at(own.path_join(d)):
				DirAccess.remove_absolute(own.path_join(d).path_join(f))
			DirAccess.remove_absolute(own.path_join(d))
	TableAssembly.bake_root = own
	TableAssembly.live_in_tests = true
	var table := Look._table().duplicate(true)
	((table["assembly"] as Dictionary)["stock"] as Array)[0] = {"name": "the tub", "thing": "toy tub", "fill": 0.85, "count": 30}
	((table["assembly"] as Dictionary)["stock"] as Array)[1] = {"name": "the pile", "at": [34, -8], "radius": 11, "count": 30, "colors": {"tan": 3, "white": 2, "red": 1}}
	var ops: Array = []
	for i in 6:
		ops.append({"do": "dig", "in": "the pile", "seconds": 3.0})
		ops.append({"do": "put", "part": "brick 2x4 red", "at": [2 + i * 4, 2], "from": "the pile"})
	_build(table, {"acts": [{"name": "a-long-one", "beat": "intro", "about": "x", "length": "under", "tracks": [{"law": "assemble", "ops": ops}]}]}, {"say:intro": "<!-- act: a-long-one --> So. A long day and nothing much to show for it."})
	var w: TableWork = medium._work
	var lg: Assembly = w.assembly.log
	var first := w.assembly.behind(0.0)
	_ok(first, "at first the show waits for the record it has just begun")
	_ok(w.assembly.track != null and w.assembly.track.baked_to <= 0, "and nothing of it has landed: %d" % (w.assembly.track.baked_to if w.assembly.track != null else -1))
	var seen: Array = []
	var waited := 0
	var slowest := 0
	while w.assembly.behind(0.0) or w.assembly.track.baked_to < lg.steps.size():
		var c0 := Time.get_ticks_usec()
		w.assembly.tick(0.0)
		slowest = maxi(slowest, Time.get_ticks_usec() - c0)
		if seen.is_empty() or int(seen[seen.size() - 1]) != w.assembly.track.baked_to:
			seen.append(w.assembly.track.baked_to)
		await get_tree().create_timer(0.03).timeout
		waited += 1
		if waited > 4000:
			break
	print("assembly_table_check: landed in stretches at %s, waiting %d frames, the slowest frame %.1f ms" % [str(seen), waited, float(slowest) / 1000.0])
	_ok(w.assembly.track.baked_to == lg.steps.size(), "all of it lands as the show goes on: %d of %d" % [w.assembly.track.baked_to, lg.steps.size()])
	_ok(seen.size() >= 2, "bit by bit: %s" % str(seen))
	_ok(not w.assembly.behind(lg._t0[0] + 1.0), "and the show does not wait for what is there")
	# ...its stops and moves are the record's now, and a moment of it is a pose of it
	_ok(not is_nan(lg.tau_at(lg._t0[1] + 0.2)), "a moment of the show is a moment of the record")
	TableAssembly.live_in_tests = false
	TableAssembly.bake_root = ""
	_build(Look._table(), Look._acts(), SAID)


func _rendered_peak(sounds: WorkSounds, t0: float, t1: float) -> float:
	sounds._restart(t0)
	var n := int((t1 - t0) * float(WorkSounds.RATE))
	var out := sounds.render(n)
	var peak := 0.0
	for s in out:
		peak = maxf(peak, maxf(absf(s.x), absf(s.y)))
	return peak


## An hour of it: nothing here is the bake's, so its frames come to nothing, and a frame of the assembly costs what moves. Measured by
## the frames a bake keeps, never by a clock.
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


## The prompts, whole, with a show that builds and goes quiet: every name filled in.
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
	# an episode opens talking: its reader is told, and given the words to do it with, however quiet the show and however little work is under it
	var opening := TablePrompts.reader("Show", "a brief", plan, "intro", [], [], 1, false, [], [], [], true, false, [], Motions.of_beat(acts, "intro"))
	_ok(String(opening["prompt"]).contains("OPENS THE VIDEO"), "the opening passage's reader is told it opens talking")
	var minute := "%d to %d" % [roundi(TablePrompts.QUIET_OPENING_WORDS * 0.8), roundi(TablePrompts.QUIET_OPENING_WORDS * 1.2)]
	_ok(String(opening["prompt"]).contains(minute), "and is asked for a minute's words, %s: %s" % [minute, String(opening["prompt"]).right(400)])
	var said := TablePrompts.reader("Show", "a brief", plan, "1", [], [], 1, false, [], [], [], true, false, [], Motions.of_beat(acts, "1"))
	var prompt := String(said["prompt"])
	_ok(not prompt.contains("OPENS THE VIDEO"), "control: no other passage's is")
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
