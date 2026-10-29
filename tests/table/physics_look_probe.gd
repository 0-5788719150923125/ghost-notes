extends Node

## NOT a gate. WHAT IS IN THINGS photographed ([TablePhysics], next/table_physics.md): a bench with a cauldron of brew,
## a jar of snow (grains), a shell holding three stones (loose by being a heap) and a mortar with a crystal lying loose in
## it - the jar tipped over the brew, the shell tipped over it, the crystal ground - read with table_look_probe's
## synthetic voice, a frame written a few times through every act, or at the times asked for.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table/physics_look_probe.gd 600 [--times 12,30] [--out <dir>/phys]
##
## `--clip A,B` writes every frame from A to B seconds, for judging motion:
##   ffmpeg -framerate 30 -i <out>_c%04d.png -pix_fmt yuv420p physics.mp4

const W := 1280
const H := 720
const DT := 1.0 / 30.0
const DIR := "user://physics_look"
const MATERIALS := {"iron": {"kind": "metal", "color": "#2c2a28"}, "brew": {"kind": "liquid", "color": "#4a3a8a", "color2": "#c8c0e8"},
	"glass": {"kind": "glass", "color": "#c8dce8", "clarity": 0.9}, "snow": {"kind": "powder", "color": "#f2f4f8", "color2": "#ffffff", "pattern": 0.6},
	"shell": {"kind": "bone", "color": "#3a7a6a", "play": "rainbow"}, "amber": {"kind": "crystal", "color": "#c88a2a", "clarity": 0.4},
	"marble": {"kind": "stone", "color": "#d8d4cc"}, "quartz": {"kind": "crystal", "color": "#e8e0f0", "clarity": 0.3},
	"wood": {"kind": "wood", "color": "#5a3a22"}}


## The bench.
static func _table() -> Dictionary:
	return {"materials": MATERIALS, "things": [
		{"name": "cauldron", "at": [-30, -20], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [10, 0], [12, 10], [12.4, 12], [11.6, 12], [10, 1.5], [0, 1.5]], "material": "iron"},
			{"name": "brew", "shape": "lathe", "profile": [[0, 1.5], [9.9, 1.5], [11, 8], [0, 8]], "material": "brew", "start": {"boil": 0.3}}]},
		{"name": "jar", "at": [-48, -8], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [2.6, 0], [2.6, 6], [2.0, 6.6], [1.8, 6.6], [1.8, 6.1], [2.4, 5.6], [2.4, 0.4], [0, 0.4]], "material": "glass"},
			{"name": "snow", "shape": "grains", "at": [0, 1, 0], "fill": 0.55, "grain": 0.3, "material": "snow"}]},
		{"name": "shell", "at": [24, -22], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [2.2, 0], [4.3, 0.9], [5.4, 1.9], [5.25, 2.05, 0], [4.0, 1.1], [1.8, 0.4], [0, 0.3]], "material": "shell",
				"smooth": true, "warp": {"scale": [1, 1, 0.8]}},
			{"name": "stones", "shape": "ball", "size": [1.3, 1.0, 1.3], "lumpy": 0.5, "facets": true, "material": "amber", "at": [0, 0.4, 0],
				"copies": {"heap": {"count": 3, "radius": 1.4}}}]},
		{"name": "mortar", "at": [44, -26], "parts": [
			{"name": "bowl", "shape": "lathe", "profile": [[0, 0], [5.8, 0], [6.0, 0.6], [5.6, 1.3], [6.1, 4.0], [6.4, 5.9], [6.5, 6.4, 0], [5.3, 6.4, 0], [4.6, 4.5], [3.0, 2.3], [0, 1.85]],
				"material": "marble", "points": {"floor": [0, 1.9, 0]}, "smooth": true},
			{"name": "crystal", "shape": "point", "radius": 0.6, "length": 1.8, "tip": 0.7, "material": "quartz", "at": [0, 2.0, 0], "turn": [0, 0, 90], "loose": true},
			{"name": "pestle", "shape": "lathe", "profile": [[0, 0], [1.3, 0.15], [1.6, 1.1], [1.35, 2.5], [0.8, 4.2], [0.75, 8.6], [1.0, 10.0], [0.75, 10.7], [0, 10.9]],
				"material": "wood", "smooth": true, "at": [9, 0, 0], "joint": {"kind": "free"}, "points": {"tip": [9, 0.2, 0], "grip": [9, 10, 0]}}]}]}


## The work: card 1's snow and stones tipped into the brew, card 2's crystal ground.
static func _acts() -> Dictionary:
	return {"acts": [
		{"name": "snow-in", "beat": 1, "about": "the jar of snow is tipped over the brew", "length": 8, "tracks": [
			{"thing": "jar", "law": "carry", "to": [-40, 16, -20], "lift": 4, "between": [0.0, 0.3]},
			{"thing": "jar", "law": "path", "keys": [{"at": 0.32}, {"at": 0.5, "turn": [0, 0, -125]}, {"at": 0.75, "turn": [0, 0, -125]}, {"at": 0.85}]},
			{"thing": "jar", "law": "carry", "lift": 4, "between": [0.86, 1.0]}]},
		{"name": "stones-in", "beat": 1, "about": "the shell is tipped over the brew", "length": 8, "tracks": [
			{"thing": "shell", "law": "carry", "to": [-21, 17, -20], "lift": 4, "between": [0.0, 0.3]},
			{"thing": "shell", "law": "path", "keys": [{"at": 0.32}, {"at": 0.5, "turn": [0, 0, 115]}, {"at": 0.75, "turn": [0, 0, 115]}, {"at": 0.85}]},
			{"thing": "shell", "law": "carry", "lift": 4, "between": [0.86, 1.0]}]},
		{"name": "grind", "beat": 2, "about": "the crystal is ground in the mortar", "length": 12, "tracks": [
			{"thing": "mortar", "part": "pestle", "law": "aim",
				"tip": {"point": "tip", "around": "mortar.floor", "radius": 1.0, "period": 1.6, "lift": 0.4, "press": "mortar"},
				"grip": {"point": "grip", "around": "mortar.floor", "radius": 2.6, "period": 1.6, "lift": 9.5}}]}]}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := ProjectSettings.globalize_path(DIR).path_join("phys")
	var times: Array = []
	var clip := Vector2(-1.0, -1.0)
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
	DirAccess.make_dir_recursive_absolute(DIR)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	for f in [["table.json", _table()], ["acts.json", _acts()]]:
		var h := FileAccess.open(DIR.path_join(String(f[0])), FileAccess.WRITE)
		h.store_string(JSON.stringify(f[1]))
		h.close()
	var positions := [{"name": "the base", "asks": "x", "work": "the snow and the stones go in"}, {"name": "the heart", "asks": "y", "work": "the crystal is ground"}]
	var plan := {"look": {"candles": 1, "palette": ["#3a2a20", "#c8a060"]}, "spread": {"positions": positions}, "work_close": "the brew glows"}
	var cards: Array = []
	for i in 2:
		cards.append({"key": "c%d" % i, "name": "Card %d" % i, "numeral": str(i), "reversed": false, "jumper": false,
			"position": positions[i], "booklet": {}, "art": ""})
	var passages: Array = []
	for m in TableProducer.choreography(plan, cards):
		var text := "Some words said about it at an easy pace for a while, and then a few more words after that, slowly."
		if String(m.get("say", "")) == "say:work:2":
			text = "Into the mortar it goes and now we grind it slowly round and round, a little more, until it is fine, and a little more, and a little more again."
		passages.append({"kind": m["kind"], "card": m.get("card", 0), "text": text if not String(m.get("say", "")).is_empty() else ""})
	var script := CardReading.compose(passages)
	var stage := SubViewport.new()
	stage.size = Vector2i(W, H)
	stage.own_world_3d = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	Director.detach()
	var medium: Medium = Medium.make("table")
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	var subs: Subtitles = preload("res://src/show/subtitles.gd").new()
	subs.words = preload("res://tests/table/table_look_probe.gd").timeline(CardReading.parse(script), 0.36, Director.intro_hold)
	subs.document = {"source": script, "title": "Physics Look", "table": {"show": "physics-look", "seed": 4, "dir": DIR, "plan": plan, "cards": cards}}
	add_child(subs)
	medium.bind_captions(subs)
	var tm := medium as TableMedium
	var t := 0.0
	Spectrum.virtual_clock = 0.0
	Spectrum.current.time = t
	subs._process(DT)
	medium.advance(Spectrum.current, DT, 1.0)
	for n in tm._work.notes:
		print("physics_look_probe: note - %s" % n)
	if times.is_empty() and clip.y <= clip.x:
		for r in tm._work.runs:
			var a: Dictionary = tm._work.acts[int((r as Dictionary)["i"])]
			for u in [0.15, 0.5, 0.85]:
				times.append(lerpf(float(r["t0"]), float(r["t1"]), u))
			print("physics_look_probe: %-10s %6.1f s to %6.1f s" % [String(a["name"]), float(r["t0"]), float(r["t1"])])
	if clip.y > clip.x:
		var tc := clip.x
		while tc <= clip.y:
			times.append(tc)
			tc += DT
	times.sort()
	var frame := 0
	var step := 0
	for want in times:
		while t < float(want):
			t += DT
			Spectrum.virtual_clock = t
			Spectrum.current.time = t
			subs._process(DT)
			medium.advance(Spectrum.current, DT, 1.0)
			step += 1
			if step % 20 == 0 or float(want) - t < 0.2:
				await get_tree().process_frame
		for _i in 2:
			await get_tree().process_frame
		var img := stage.get_texture().get_image()
		var path := "%s_t%05.1f.png" % [out, float(want)]
		if clip.y > clip.x and float(want) >= clip.x and float(want) <= clip.y + 1e-4:
			path = "%s_c%04d.png" % [out, frame]
			frame += 1
		if img != null:
			img.save_png(path)
		if clip.y <= clip.x or frame <= 1:
			print("physics_look_probe: t=%.2f -> %s" % [want, path])
	Spectrum.virtual_clock = -1.0
	Director.hold(false)
	Director.detach()
	stage.queue_free()
	for _i in 3:
		await get_tree().process_frame
	get_tree().quit(0)
