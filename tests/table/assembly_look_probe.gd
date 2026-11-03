extends Node

## NOT a gate. WHAT IS BUILT ON THE TABLE, photographed ([TableAssembly], next/assembly.md): a real hollow tub, a pile on the table, a
## plate, and a little of what a slow build does - digging, trying, a wall, a wreck, a silence - read with a synthetic voice, and a
## frame at the middle of each act or at the times asked for. Real advances, so it is scheduled as a reading schedules it.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table/assembly_look_probe.gd 400 [--times 12,30] [--out <dir>/bricks] [--size 1280x720]
##
## `--clip A,B` writes every frame from A to B seconds, for judging motion and for the frame's cost (printed at the end), and the work's
## own sound under them to <out>.wav - no voice, none of the room's - for judging that:
##   ffmpeg -framerate 30 -i <out>_c%04d.png -i <out>.wav -pix_fmt yuv420p -shortest bricks.mp4

const DT := 1.0 / 30.0
const DIR := "user://assembly_look"
const WORD := 0.36


static func _table() -> Dictionary:
	return {"materials": {"tub": {"kind": "painted", "color": "#3f6f8f", "polish": 0.55}, "oak": {"kind": "wood", "color": "#a07a4f"}},
		"things": [
			{"name": "toy tub", "at": [-40, -10], "parts": [
				{"shape": "box", "size": [36, 1.2, 26], "material": "tub", "round": 0.6},
				{"shape": "box", "size": [1.2, 13, 26], "at": [-17.4, 0, 0], "material": "tub", "round": 0.5},
				{"shape": "box", "size": [1.2, 13, 26], "at": [17.4, 0, 0], "material": "tub", "round": 0.5},
				{"shape": "box", "size": [36, 13, 1.2], "at": [0, 0, -12.4], "material": "tub", "round": 0.5},
				{"shape": "box", "size": [36, 13, 1.2], "at": [0, 0, 12.4], "material": "tub", "round": 0.5}]}],
		"assembly": {
			"colors": {"red": "#b3261e", "blue": "#1f4f9c", "yellow": "#e8b512", "white": "#ece8dc", "black": "#23252a", "gray": "#8b8d8f", "green": "#2a7a41", "tan": "#c9b185"},
			"base": {"size": [32, 32], "color": "green"},
			"stock": [
				{"name": "the tub", "thing": "toy tub", "fill": 0.85},
				{"name": "the pile", "at": [34, -8], "radius": 11, "colors": {"tan": 3, "white": 2, "red": 1}}]}}


static func _acts() -> Dictionary:
	return {"acts": [
		{"name": "first-look", "beat": "intro", "about": "digging in the tub", "length": "under", "tracks": [{"law": "assemble", "ops": [
			{"do": "dig", "in": "the tub", "seconds": 8},
			{"do": "look", "part": "slope 2x3 blue", "from": "the tub", "seconds": 5},
			{"do": "pause", "seconds": 6}]}]},
		{"name": "start-wall", "beat": 1, "about": "the first wall", "length": "under", "tracks": [{"law": "assemble", "ops": [
			{"do": "wall", "part": "brick 2x4 tan", "from": [4, 6], "to": [19, 6], "courses": 2, "stock": "the pile"},
			{"do": "pause", "seconds": 8},
			{"do": "try", "part": "brick 2x2 red", "at": [4, 6], "from": "the tub", "turn": 0},
			{"do": "dig", "in": "the tub", "for": "brick 2x2 white", "seconds": 5},
			{"do": "put", "part": "brick 2x2 white", "at": [4, 6], "from": "the tub", "hover": 3},
			{"do": "turn", "by": 40}]}]},
		{"name": "more", "beat": 2, "about": "a floor, and a tower", "length": "under", "tracks": [{"law": "assemble", "ops": [
			{"do": "fill", "part": "plate 2x4 gray", "from": [6, 10], "to": [13, 17]},
			{"do": "put", "part": "round 2x2 yellow", "at": [8, 12]},
			{"do": "put", "part": "round 2x2 yellow", "at": [8, 12]},
			{"do": "put", "part": "slope 2x2 red", "at": [8, 12], "look": 4},
			{"do": "pause", "seconds": 14}]}]},
		{"name": "down-it-comes", "beat": 3, "about": "the wall comes down", "length": "under", "tracks": [{"law": "assemble", "ops": [
			{"do": "wreck", "from": [4, 6], "to": [19, 6], "into": "the tub"},
			{"do": "pause", "seconds": 6},
			{"do": "turn", "by": -40}]}]}]}


## The work's sound from A to B of [param clip], to a WAV.
static func _write_sound(w: TableWork, clip: Vector2, path: String) -> void:
	var sounds := WorkSounds.new(w)
	sounds._restart(clip.x)
	var pcm := sounds.render(int((clip.y - clip.x) * float(WorkSounds.RATE)))
	sounds.stop()
	Splice.write_wav(path, pcm, 2, WorkSounds.RATE)
	var peak := 0.0
	for f in pcm:
		peak = maxf(peak, maxf(absf(f.x), absf(f.y)))
	print("assembly_look_probe: the work's sound -> %s, its peak %.4f" % [path, peak])


## `--sheet`: one of every kind, seated, in two colors, and one turned over: for the parts' own look.
static func _sheet_acts() -> Dictionary:
	var ops: Array = []
	var x := 1
	var z := 1
	for kind in Assembly.KINDS:
		for s in (Assembly.KINDS[kind] as Dictionary)["sizes"]:
			var w := int((s as Array)[0])
			var d := int((s as Array)[1])
			if w > 4 or d > 6:
				continue
			if x + w > 30:
				x = 1
				z += 8
			ops.append({"do": "put", "part": "%s %dx%d %s" % [kind, w, d, ["red", "yellow", "white", "blue"][(x + z) % 4]], "at": [x, z, 0]})
			x += w + 1
	return {"acts": [{"name": "sheet", "beat": "intro", "about": "every kind", "length": "under", "tracks": [{"law": "assemble", "ops": ops}]}]}


func _ready() -> void:
	_run.call_deferred()


## The words' times a voice would give them, a mark's rest and each silence counted: as table_look_probe's, and silences.
static func timeline(parse: Dictionary, intro: float) -> Array:
	var out: Array = []
	var rest_at := {}
	var n := 0
	var rx := RegEx.new()
	rx.compile("<!--\\s*action-hold\\s*:\\s*([0-9.]+)\\s*-->|([^\\s<]+)")
	for m in rx.search_all(String(parse["speakable"])):
		if not m.get_string(1).is_empty():
			rest_at[n] = float(rest_at.get(n, 0.0)) + float(m.get_string(1))
		elif not TabletScript.norm(m.get_string(2)).is_empty():
			n += 1
	var t := intro
	var spoken: PackedStringArray = parse["spoken"]
	for i in spoken.size():
		t += float(rest_at.get(i, 0.0))
		out.append({"text": spoken[i], "t0": t, "t1": t + WORD * 0.85, "sentence": i / 8})
		t += WORD
	return out


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := ProjectSettings.globalize_path(DIR).path_join("bricks")
	var times: Array = []
	var clip := Vector2(-1.0, -1.0)
	var size := Vector2i(1280, 720)
	var sheet := args.has("--sheet")
	for i in args.size() - 1:
		match args[i]:
			"--out": out = args[i + 1]
			"--times":
				for s in String(args[i + 1]).split(",", false):
					times.append(float(s))
			"--clip":
				var ab := String(args[i + 1]).split(",", false)
				if ab.size() == 2:
					clip = Vector2(float(ab[0]), float(ab[1]))
			"--size":
				var wh := String(args[i + 1]).split("x", false)
				if wh.size() == 2:
					size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(DIR)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	for f in [["table.json", _table()], ["acts.json", _sheet_acts() if sheet else _acts()]]:
		var h := FileAccess.open(DIR.path_join(String(f[0])), FileAccess.WRITE)
		h.store_string(JSON.stringify(f[1]))
		h.close()
	var positions := [{"name": "one", "asks": "x", "work": "a wall"}, {"name": "two", "asks": "y", "work": "a floor"}, {"name": "three", "asks": "z", "work": "it comes down"}]
	var plan := {"look": {"candles": 0, "palette": ["#3a2a20", "#c8a060"], "light": {"kind": "a desk lamp at night", "color": "#ffe2bd", "warmth": "warm"}},
		"spread": {"positions": positions}, "work_close": "", "staging": {"source": "none"}}
	var said := {"say:intro": "<!-- act: sheet --> <!-- quiet: 220 --> Words."} if sheet else {
		"say:intro": "<!-- act: first-look --> <!-- quiet: 14 --> So. A long day and nothing much to show for it. <!-- quiet: 8 --> I was going to do something with these.",
		"say:1": "<!-- act: start-wall --> Somebody at work said a thing today that I keep turning over. <!-- quiet: 40 --> It was not even about me, and I still cannot stop thinking about it, you know how that goes.",
		"say:2": "<!-- act: more --> I think this wants to be a house, or it did. <!-- quiet: 50 --> Anyway. My dad had a tub just like that one, in the basement, with a broken lid.",
		"say:close": "<!-- act: down-it-comes --> No. That wall was wrong from the start, and I knew it. <!-- quiet: 16 --> Brick by brick.",
	}
	var passages: Array = []
	for m in TableProducer.choreography(plan, []):
		var say := String(m.get("say", ""))
		passages.append({"kind": m["kind"], "card": m.get("card", 0), "text": String(said.get(say, "A few plain words said for a while at an easy pace."))})
	# the wreck is its own beat, not the close's: its cue stands in the passage it was written in
	var script := CardReading.compose(passages)
	var stage := SubViewport.new()
	stage.size = size
	stage.own_world_3d = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	Director.detach()
	var medium: Medium = Medium.make("table")
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	var subs: Subtitles = preload("res://src/show/subtitles.gd").new()
	var parse := CardReading.parse(script)
	subs.words = timeline(parse, Director.intro_hold)
	subs.document = {"source": script, "title": "Brick Look", "table": {"show": "assembly-look", "seed": 41, "dir": DIR, "plan": plan, "cards": []}}
	add_child(subs)
	medium.bind_captions(subs)
	var tm := medium as TableMedium
	var t := 0.0
	Spectrum.virtual_clock = 0.0
	Spectrum.current.time = t
	subs._process(DT)
	medium.advance(Spectrum.current, DT, 1.0)
	for n in tm._work.notes:
		print("assembly_look_probe: note - %s" % n)
	var w: TableWork = tm._work
	if sheet:
		var a_cam: Camera3D = tm._cam
		print("assembly_look_probe: lens fov %.1f at %s" % [a_cam.fov, str(tm._plan.cam_base.origin)])
	if w.assembly == null:
		print("assembly_look_probe: NO ASSEMBLY on the table")
	else:
		print(w.assembly.report())
		print("assembly_look_probe: %d pieces, %d steps" % [w.assembly.log.pieces.size(), w.assembly.log.steps.size()])
		for a in w.acts:
			print("assembly_look_probe: %s" % "\n".join(w.assembly.log.report_of(String((a as Dictionary)["name"]))))
	var words: Array = subs.words
	var last_t: float = float((words[words.size() - 1] as Dictionary)["t1"]) if not words.is_empty() else 0.0
	print("assembly_look_probe: the words end at %.1f s" % last_t)
	if times.is_empty() and clip.y <= clip.x:
		for r in w.runs:
			var a: Dictionary = w.acts[int((r as Dictionary)["i"])]
			for u in [0.2, 0.55, 0.9]:
				times.append(lerpf(float(r["t0"]), float(r["t1"]), u))
			print("assembly_look_probe: %-14s %7.1f s to %7.1f s" % [String(a["name"]), float(r["t0"]), float(r["t1"])])
	if clip.y > clip.x:
		var tc := clip.x
		while tc <= clip.y:
			times.append(tc)
			tc += DT
	times.sort()
	var frame := 0
	var step := 0
	var spent := 0
	var ticks := 0
	for want in times:
		while t < float(want):
			t += DT
			Spectrum.virtual_clock = t
			Spectrum.current.time = t
			subs._process(DT)
			var c0 := Time.get_ticks_usec()
			medium.advance(Spectrum.current, DT, 1.0)
			spent += Time.get_ticks_usec() - c0
			ticks += 1
			step += 1
			if step % 20 == 0 or float(want) - t < 0.2:
				await get_tree().process_frame
		for _i in 2:
			await get_tree().process_frame
		var img := stage.get_texture().get_image()
		var path := "%s_t%06.1f.png" % [out, float(want)]
		if clip.y > clip.x and float(want) >= clip.x and float(want) <= clip.y + 1e-4:
			path = "%s_c%04d.png" % [out, frame]
			frame += 1
		if img != null:
			img.save_png(path)
		if clip.y <= clip.x or frame <= 1:
			print("assembly_look_probe: t=%.2f -> %s" % [want, path])
	if clip.y > clip.x:
		_write_sound(w, clip, out + ".wav")
	if w.assembly != null and args.has("--steps"):
		var lg: Assembly = w.assembly.log
		for r in w.runs:
			print("assembly_look_probe: run %s %.1f - %.1f" % [String((w.acts[int((r as Dictionary)["i"])] as Dictionary)["name"]), float(r["t0"]), float(r["t1"])])
		for k in mini(lg.steps.size(), 40):
			print("assembly_look_probe: step %d %s %.1f - %.1f" % [k, String((lg.steps[k] as Dictionary)["do"]), lg._t0[k], lg._t1[k]])
	if ticks > 0:
		print("assembly_look_probe: a frame's work took %.2f ms on the app's thread" % (float(spent) / float(ticks) / 1000.0))
	Spectrum.virtual_clock = -1.0
	Director.hold(false)
	Director.detach()
	stage.queue_free()
	for _i in 3:
		await get_tree().process_frame
	get_tree().quit(0)
