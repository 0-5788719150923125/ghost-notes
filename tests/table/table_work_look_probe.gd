extends Node

## NOT a gate. WORK AT THE TABLE photographed ([TableWork], next/table_work.md): table_work_live_check's bench
## - a cauldron steaming, a mortar and pestle, a jar of ink poured into the brew, a clock that runs, hatchlings
## heard by the hearth - read with a synthetic voice (table_look_probe's), and a frame written at the middle
## of every act, or at the times asked for. Real advances, so the work is scheduled as a reading schedules it.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table/table_work_look_probe.gd 400 [--times 12,30] [--out <dir>/work]
##
## `--clip A,B` writes every frame from A to B seconds, for judging motion:
##   ffmpeg -framerate 30 -i <out>_c%04d.png -pix_fmt yuv420p work.mp4

const Live := preload("res://tests/table/table_work_live_check.gd")
const W := 1280
const H := 720
const DT := 1.0 / 30.0
const DIR := "user://table_work_look"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := ProjectSettings.globalize_path(DIR).path_join("work")
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
	for f in [["table.json", Live._table()], ["acts.json", Live._acts()]]:
		var h := FileAccess.open(DIR.path_join(String(f[0])), FileAccess.WRITE)
		h.store_string(JSON.stringify(f[1]))
		h.close()
	var positions := [{"name": "the base", "asks": "x", "work": "the ink is poured in"}, {"name": "the heart", "asks": "y", "work": "the herbs are ground"}]
	var plan := {"look": {"candles": 1, "palette": ["#3a2a20", "#c8a060"]}, "spread": {"positions": positions}, "work_close": "the brew glows"}
	var cards: Array = []
	for i in 2:
		cards.append({"key": "c%d" % i, "name": "Card %d" % i, "numeral": str(i), "reversed": false, "jumper": false,
			"position": positions[i], "booklet": {}, "art": ""})
	var passages: Array = []
	for m in TableProducer.choreography(plan, cards):
		var text := "Some words said about it at an easy pace for a while, and then a few more words after that, slowly."
		if String(m.get("say", "")) == "say:work:2":
			text = "Into the mortar they go and now we <!-- act: grind --> grind them slowly round and round, a little more, until they are fine, and a little more."
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
	subs.document = {"source": script, "title": "Work Look", "table": {"show": "table-work-look", "seed": 4, "dir": DIR, "plan": plan, "cards": cards}}
	add_child(subs)
	medium.bind_captions(subs)
	var tm := medium as TableMedium
	var t := 0.0
	Spectrum.virtual_clock = 0.0
	Spectrum.current.time = t
	subs._process(DT)
	medium.advance(Spectrum.current, DT, 1.0)
	for n in tm._work.notes:
		print("table_work_look_probe: note - %s" % n)
	if times.is_empty() and clip.y <= clip.x:
		for r in tm._work.runs:
			var a: Dictionary = tm._work.acts[int((r as Dictionary)["i"])]
			for u in [0.15, 0.5, 0.85]:
				times.append(lerpf(float(r["t0"]), float(r["t1"]), u))
			print("table_work_look_probe: %-10s %6.1f s to %6.1f s" % [String(a["name"]), float(r["t0"]), float(r["t1"])])
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
			print("table_work_look_probe: t=%.2f -> %s" % [want, path])
	Spectrum.virtual_clock = -1.0
	Director.hold(false)
	Director.detach()
	stage.queue_free()
	for _i in 3:
		await get_tree().process_frame
	get_tree().quit(0)
