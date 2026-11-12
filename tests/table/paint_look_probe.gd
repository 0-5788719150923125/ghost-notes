extends Node

## NOT a gate. The painted surface photographed ([TablePaint], next/painted_surface.md): a mask on its cradle and an artist's station
## ([code]paint_check[/code]'s, or the fixed table of a brief), a design that uses every finish and manner, and acts that lay it all on
## with the station's own tools, read with a synthetic voice; a frame written part way through every act, or at the times asked for.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table/paint_look_probe.gd 900 [--brief <a brief.md>] [--design <skin.json>]
##       [--times 12,30] [--loads N] [--out <dir>/paint] [--clip A,B]
##
## `--loads N`: the first N moments a sponge is pressed hardest into its paint (each load's pumps), photographed.

const Check := preload("res://tests/table/paint_check.gd")
const W := 1280
const H := 720
const DT := 1.0 / 30.0
const DIR := "user://paint_look"
const WORD := 0.36


func _ready() -> void:
	_run.call_deferred()


## The demo design, on a face 150 x 210 mm: every finish and every manner.
static func design() -> Dictionary:
	return {"designs": [{"thing": "mask", "part": "face", "name": "a blue-diamond pierrot", "elements": [
		{"id": "base", "stage": "base", "paint": "#f4f1ea", "fill": "all", "soft": 2},
		{"id": "set", "stage": "base", "paint": "#ffffff", "finish": "powder", "fill": "all"},
		{"id": "brow left", "stage": "lines", "paint": "#141416", "line": "M 30 76 Q 46 56 64 70", "width": 1.8},
		{"id": "brow right", "stage": "lines", "paint": "#141416", "line": "M 120 76 Q 104 56 86 70", "width": 1.8},
		{"id": "diamond", "stage": "color", "paint": "#2d4a9a", "finish": "satin", "fill": "M 102 68 L 117 97 L 102 126 L 87 97 Z"},
		{"id": "diamond edge", "stage": "lines", "paint": "#141416", "line": "M 102 68 L 117 97 L 102 126 L 87 97 Z", "width": 1.0},
		{"id": "mouth", "stage": "color", "paint": "#b3122a", "finish": "gloss", "fill": "M 55 152 Q 66 143 75 147 Q 84 143 95 152 Q 85 164 75 163 Q 65 164 55 152 Z"},
		{"id": "blush", "stage": "depth", "paint": "#e58aa0", "opacity": 0.55, "soft": 3, "fill": "M 18 125 A 12 12 0 1 1 42 125 A 12 12 0 1 1 18 125 Z"},
		{"id": "tear", "stage": "detail", "paint": "#141416", "fill": "M 48 104 Q 53 115 48 119 Q 43 115 48 104 Z"},
		{"id": "smudge", "stage": "detail", "smear": "tear", "line": "M 48 117 Q 47 128 50 140", "width": 4},
		{"id": "crown dots", "stage": "detail", "paint": "#d8b25a", "finish": "metal", "dots": [[58, 42, 1.6], [66, 36, 1.8], [75, 33, 2.2], [84, 36, 1.8], [92, 42, 1.6]]},
		{"id": "star", "stage": "finish", "paint": "#d9c8ff", "finish": "glitter", "fill": "M 36 146 L 38.5 152 L 45 152 L 40 156 L 42 162 L 36 158.5 L 30 162 L 32 156 L 27 152 L 33.5 152 Z"},
		{"id": "stones", "stage": "finish", "paint": "#eef4ff", "stones": [[102, 132, 1.6], [95, 129, 1.2], [109, 129, 1.2]]},
		{"id": "spray", "stage": "finish", "mist": "all"},
	]}]}


## The demo acts, a beat a stage, each with the station's own tool.
static func acts() -> Dictionary:
	var a := func(nm: String, beat: int, thing: String, part: String, paint: Array, extra := {}) -> Dictionary:
		var tr := {"thing": thing, "part": part, "law": "paint", "on": "mask", "paint": paint}
		tr.merge(extra)
		return {"name": nm, "beat": beat, "length": "under", "about": "%s laid on" % ", ".join(PackedStringArray(paint)), "tracks": [tr]}
	return {"acts": [
		a.call("base", 1, "sponge dish", "sponge", ["base"], {"from": "white pot"}),
		a.call("set", 1, "powder pot", "puff", ["set"], {"from": "powder pot"}),
		a.call("set again", 1, "powder pot", "puff", ["set"]),
		a.call("brows", 2, "brush tray", "liner brush", ["brow left", "brow right"], {"from": "black pot"}),
		a.call("diamond", 3, "brush tray", "round brush", ["diamond"], {"from": "blue pot", "rinse": "water cup", "dry": "towel"}),
		a.call("diamond edge", 3, "brush tray", "liner brush", ["diamond edge"], {"from": "black pot"}),
		a.call("mouth", 3, "brush tray", "flat brush", ["mouth"], {"from": "red pot", "rinse": "water cup", "dry": "towel"}),
		a.call("blush", 4, "brush tray", "blending brush", ["blush"], {"from": "pink pot"}),
		a.call("soften", 4, "sponge dish", "sponge", ["blush"], {"manner": "blend"}),
		a.call("tear", 5, "brush tray", "round brush", ["tear", "crown dots"], {"from": "black pot", "rinse": "water cup", "dry": "towel"}),
		a.call("smudge", 5, "sponge dish", "sponge", ["smudge"]),
		a.call("star", 6, "brush tray", "round brush", ["star"], {"from": "pink pot"}),
		a.call("stones", 6, "stone dish", "tweezers", ["stones"], {"from": "stone dish"}),
		a.call("spray", 6, "setting spray", "bottle", ["spray"]),
	]}


## The pots the set dresser would add beside the fixed ones.
static func tonight() -> Array:
	var pot := func(nm: String, x: float, z: float, mat: String) -> Dictionary:
		return {"name": nm, "at": [x, z], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [2.6, 0], [2.6, 2], [2.3, 2], [2.3, 0.4], [0, 0.4]], "material": "black tin"},
			{"shape": "lathe", "profile": [[0, 0.4], [2.3, 0.4], [2.3, 1.6], [0, 1.65]], "material": mat}]}
	return [pot.call("blue pot", -2, 16, "blue paint"), pot.call("pink pot", 3, 17, "pink paint")]


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := ProjectSettings.globalize_path(DIR).path_join("paint")
	var times: Array = []
	var clip := Vector2(-1.0, -1.0)
	var brief := ""
	var design_path := ""
	var loads := 0
	for i in args.size() - 1:
		match args[i]:
			"--out": out = args[i + 1]
			"--brief": brief = args[i + 1]
			"--design": design_path = args[i + 1]
			"--times":
				for s in String(args[i + 1]).split(",", false):
					times.append(float(s))
			"--loads":
				loads = int(args[i + 1])
			"--clip":
				var ab := String(args[i + 1]).split(",", false)
				if ab.size() == 2:
					clip = Vector2(float(ab[0]), float(ab[1]))
	DirAccess.make_dir_recursive_absolute(DIR)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var table: Dictionary = Check.station()
	if not brief.is_empty():
		var fixed := FixedTable.parse(FileAccess.get_file_as_string(brief))
		print("paint_look_probe: %d fixed things from %s" % [(fixed.get("things", []) as Array).size(), brief])
		table = FixedTable.merge({"things": [], "materials": {}}, fixed)
	(table["things"] as Array).append_array(tonight())
	(table["materials"] as Dictionary).merge({"blue paint": {"kind": "cream", "color": "#2d4a9a", "polish": 0.55, "pattern": 0.4},
		"pink paint": {"kind": "cream", "color": "#e58aa0", "polish": 0.55, "pattern": 0.4},
		"black tin": {"kind": "metal", "color": "#1b1b1d", "polish": 0.55}})
	var skin: Variant = design()
	if not design_path.is_empty():
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(design_path)) == OK:
			skin = j.data
	var the_acts := acts()
	for f in [["table.json", table], ["acts.json", the_acts], ["skin.json", skin]]:
		var h := FileAccess.open(DIR.path_join(String(f[0])), FileAccess.WRITE)
		h.store_string(JSON.stringify(f[1]))
		h.close()
	# a beat a stage, each with words enough for its work at a hand's pace
	var beats := 6
	var positions: Array = []
	for k in beats:
		positions.append({"name": "stage %d" % (k + 1), "asks": "x", "work": "a stage of the face"})
	var plan := {"look": {"candles": 1, "palette": ["#2e2119", "#ece6da"]}, "spread": {"positions": positions}, "staging": {"source": "none"}}
	var cards: Array = []
	var passages: Array = []
	var natural := {}
	for ad in the_acts["acts"]:
		var b := str(int((ad as Dictionary)["beat"]))
		natural[b] = float(natural.get(b, 0.0)) + Skins.act_natural(ad, skin, table)
	for m in TableProducer.choreography(plan, cards):
		var text := ""
		var say := String(m.get("say", ""))
		if not say.is_empty():
			var beat := say.get_slice(":", 1)
			var n := int(ceil(float(natural.get(beat, 6.0)) / WORD)) + 8
			var words := PackedStringArray()
			for k in n:
				words.append("slowly" if k % 7 else "and then, slowly")
			text = " ".join(words) + "."
		passages.append({"kind": m["kind"], "card": m.get("card", 0), "text": text})
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
	subs.words = preload("res://tests/table/table_look_probe.gd").timeline(CardReading.parse(script), WORD, Director.intro_hold)
	subs.document = {"source": script, "title": "Paint Look", "table": {"show": "paint-look", "seed": 731905, "dir": DIR, "plan": plan, "cards": cards}}
	add_child(subs)
	medium.bind_captions(subs)
	var tm := medium as TableMedium
	var t := 0.0
	Spectrum.virtual_clock = 0.0
	Spectrum.current.time = t
	subs._process(DT)
	medium.advance(Spectrum.current, DT, 1.0)
	for n in tm._work.notes:
		print("paint_look_probe: note - %s" % n)
	if tm._work.paint != null:
		for sd in tm._work.paint.skins:
			print("paint_look_probe: skin %s/%s %s mm, %d elements designed, %d laid" % [sd["name"], sd["part"], sd["frame"],
				((sd["design"] as Dictionary).get("elements", []) as Array).size(), (sd["items"] as Dictionary).size()])
			for id in sd["items"]:
				print("paint_look_probe:   %-14s laid %s" % [id, (sd["items"][id] as Dictionary).get("span", "-")])
	# ...the first loads (`--loads N`): each moment a sponge is pressed hardest into its paint, found by posing the work alone
	if loads > 0 and tm._work.paint != null:
		var was := 0.0
		var rising := false
		var tt := 0.0
		while tt < 900.0 and times.size() < loads:
			tm._work.tick(tt)
			var by := 0.0
			for ch in tm._work.paint.tools:
				for sp in (tm._work.paint.tools[ch] as Dictionary).get("sponges", []):
					var v: Variant = ((sp as Dictionary)["mat"] as ShaderMaterial).get_shader_parameter("flat_by")
					by = maxf(by, (v as Vector3).x if v is Vector3 else 0.0)
			if by < was and rising and was > 0.0:
				times.append(tt - 0.05)
				print("paint_look_probe: a load pressed %.1f mm in at %.2f s" % [was * 1000.0, tt - 0.05])
			rising = by > was
			was = by
			tt += 0.05
	if times.is_empty() and clip.y <= clip.x:
		for r in tm._work.runs:
			var a: Dictionary = tm._work.acts[int((r as Dictionary)["i"])]
			# ...while it paints: an act slowed only so far, then resting, paints in about its natural length
			var busy := minf(float(r["t1"]) - float(r["t0"]), float(a.get("_natural", 1e9)) * TablePaint.SLOW_MOST)
			for u in [0.4, 0.75, 1.0]:
				times.append(float(r["t0"]) + busy * u)
			print("paint_look_probe: %-12s %6.1f s to %6.1f s (natural %.0f s)" % [String(a["name"]), float(r["t0"]), float(r["t1"]), float(a.get("_natural", 0.0))])
	if clip.y > clip.x:
		var tc := clip.x
		while tc <= clip.y:
			times.append(tc)
			tc += DT
	times.sort()
	var frame := 0
	var step := 0
	for want in times:
		# a long jump is a scrub: it lands where a play would (the work is a function of time)
		if float(want) - t > 20.0:
			t = float(want) - 2.0
		while t < float(want):
			t += DT
			Spectrum.virtual_clock = t
			Spectrum.current.time = t
			subs._process(DT)
			medium.advance(Spectrum.current, DT, 1.0)
			step += 1
			if step % 20 == 0 or float(want) - t < 0.2:
				await get_tree().process_frame
		for _i in 3:
			await get_tree().process_frame
		var img := stage.get_texture().get_image()
		var path := "%s_t%06.1f.png" % [out, float(want)]
		if clip.y > clip.x and float(want) >= clip.x and float(want) <= clip.y + 1e-4:
			path = "%s_c%04d.png" % [out, frame]
			frame += 1
		if img != null:
			img.save_png(path)
		if clip.y <= clip.x or frame <= 1:
			print("paint_look_probe: t=%.2f -> %s" % [want, path])
	Spectrum.virtual_clock = -1.0
	Director.hold(false)
	Director.detach()
	stage.queue_free()
	for _i in 3:
		await get_tree().process_frame
	get_tree().quit()
