extends Node

## AN EPISODE BAKED AS ITS EXPORT BAKED IT (next/table_physics.md): the episode a take's sidecar names, stood from a COPY of
## its folder, its acts scheduled on the take's own word times, and what is in things baked through the whole show on this
## thread - then the parts asked for followed frame by frame, and the liquids, streams and holds said. Every cause in
## next/table_physics.md was found this way, never by rendering: the bake is what the picture draws.
##
##   tests/run_boot_probe.sh tests/table/episode_bake_probe.gd 3600 --take=<user://generative/take_N.json> \
##       [--watch=ladle,feather,cork] [--from=0] [--to=end] [--every=0.5] [--acts] [--acts-file=<acts.json>]
##   tests/run_boot_probe.sh tests/table/episode_bake_probe.gd 3600 --take=... --live [--ahead=4] [--from=0] [--to=end] \
##       [--seek=T[:after],wK[:after],... [--after=20]]
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table/episode_bake_probe.gd 3600 --take=... --shots=29,228.5 [--out=<dir>]
##
## A take whose book names `start_words`, `start_index` and `start_time` is a reading started mid-way (a scrub): its words from
## there, timed from 0, and what was done before them baked first ([member TablePhysics._t0]).
##
## - `--watch`: parts or things whose names hold any of these words: each one's place (cm), its tilt from upright and its
##   turn (degrees), whether a hand has it and how far off its hand it is, and what last held it back.
## - `--acts`: when each act runs, as the schedule placed it.
## - `--acts-file`: the copy's `acts.json` replaced by this one - an act tried on the episode as it was exported.
## - `--shots`: on a real renderer, the picture at each of these moments (seconds) as the export drew it, 1280x720, written to
##   `--out` (by default the copy's folder) as `shot_<t>.png` - the bake run up to each, and nothing else baked or followed.
## - `--live`: PLAYED AS THE APP PLAYS IT - the table built on a worker (each frame drawn meanwhile said), the words a sentence at a
##   time, `--ahead` seconds before they are said, the bake on a
##   thread of its own, the clock the wall's (held only while the show waits for its bake) - and each frame that held this
##   thread over 50 ms said, with what took it: what a viewer sees frozen while the voice goes on.
## - `--script`: the episode's `script.md` as it stands now, its words timed from the plan's estimate (`--pace=1`) - a take carries the
##   script it was exported from, and a script written again since cues its acts at other words.
## - `--trace=T0,T1,step`: baked to each moment on this thread, each watched body's state there - held, asleep, its host, what it
##   last touched, what held it back - which no frame keeps.
## - `--seek=T,wK:after,...` (with `--live`): played to `--to`, then SCRUBBED as the reading scrubs, each in turn - started again from
##   the sentence holding T, or from spoken word K, its words timed from 0 - and played `after` seconds (`--after`): whether the table and its bake stood, how long the show
##   waited, and how far each watched part is drawn from where the first pass drew it at the same moment of the episode.
## - `--stalls=T0,T1`: the stretch baked first, then every frame of it played - each over 50 ms said, with what took it.
## - `--held`: each painting program's held keys - how many a tool is stood off its surface at, and how far, and where; how far it is
##   lifted on its way between them. With `--audit`, a painting tool OFF what it paints while the law has it pressing is said too
##   (`GHOST_AUDIT_WHY=1`: whether the law's own place or the drawn one is off).
## - `--live`, its first frames: the medium mounted, the table put back in the tree, and the 20 frames that first draw it (the Director
##   held, the camera is never placed: those frames draw all of it, a cost the app never pays).
## - `--profile=T`: bake through T+2, then measure 60 frames of playback there, with the bake already available. Prints
##   the work's CPU cost, the whole medium's CPU cost and wall time per frame (use GHOST_PROBE_GPU=1 for rendering).
## - `--audit`: THE SHOW AGAINST WHAT MUST ALWAYS HOLD, baked whole and every frame looked at: liquid neither made nor lost; a body in nothing solid, nor through the table; no
##   jump between frames; a hand's thing not held far off its hand; nothing let go hanging in the air; a loose thing inside its vessel's walls; a surface moving smoothly;
##   a painting tool's own surface in nothing but what gives, to a millimeter (a pot's wall is three).
##   Each said once, with when and how much - what a viewer would report, found before they must.
## - `--plan-only` (with `--heard`): the live plans alone, nothing baked - each act's time and every stretch over 8 s the painting hand
##   stands idle. Minutes for a whole episode where a bake takes many.
## - `--heard[=LEAD]`: THE SHOW AS A LIVE PLAN COMES TO KNOW IT, on this thread: the words a sentence at a time, `--ahead` seconds before
##   they are said, the bake LEAD seconds (12) past the clock, each new plan taken as the app takes it, to the end - and whatever follows
##   (`--audit`, `--series`) reads that bake. No wall clock, so as quick as the bake.
## - `--series=<file>`, `--against=<file>`: every body and liquid sampled five times a second into a file, and said where it parts from another's -
##   `--series=whole.bin` on the whole plan, `--heard --series=heard.bin --against=whole.bin`: WHAT A LIVE SHOW DOES THAT THE WHOLE PLAN DOES NOT, none of
##   which a bake of the whole plan can show (feedback 0013: a cork not yet brought, unheard, stopped the pour). `--compare=a,b`: just that, of two files.
## - always: each liquid whose volume changed, at every sample; the streams in the air; each act's HELD BACK.
##
## READ-ONLY: the episode is copied to a scratch folder on the real disk (`--copy=<dir>`, by default the project's
## `dist/episode_bake_probe/`, which Godot never imports), and nothing is written but the copy.

var medium: TableMedium
var subs: Subtitles
var _through_n := {}
var args_soft_trace := false


func _ready() -> void:
	_run.call_deferred()


func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	for a in args:
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
		if a == "--" + key:
			return "1"
	return fallback


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if _arg(args, "compare", "") != "":
		var two := _arg(args, "compare", "").split(",")
		_series_against(_series_read(String(two[1])), _series_read(String(two[0])))
		print("episode_bake_probe: done")
		get_tree().quit(0)
		return
	var take_path := _arg(args, "take", "")
	if take_path.is_empty() or not FileAccess.file_exists(take_path):
		print("episode_bake_probe: --take=<a take's .json> is needed (got '%s')" % take_path)
		get_tree().quit(2)
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(take_path)) != OK or not (j.data is Dictionary):
		print("episode_bake_probe: the take's sidecar is unreadable")
		get_tree().quit(2)
		return
	var take: Dictionary = j.data
	var book: Dictionary = (take.get("book", {}) as Dictionary).duplicate(true)
	# ...a mid-way start (a scrub) as the reading hands it: its first words a PackedStringArray, never JSON's Array
	if book.get("start_words") is Array:
		book["start_words"] = PackedStringArray(book["start_words"] as Array)
	var pay: Dictionary = book.get("table", {})
	var src_dir := String(pay.get("dir", ""))
	if src_dir.is_empty() or not DirAccess.dir_exists_absolute(src_dir):
		print("episode_bake_probe: the take names no episode folder there is: '%s'" % src_dir)
		get_tree().quit(2)
		return
	var copy := _arg(args, "copy", ProjectSettings.globalize_path("res://dist/episode_bake_probe"))
	_copy_dir(src_dir, copy)
	var acts_file := _arg(args, "acts-file", "")
	if not acts_file.is_empty():
		DirAccess.copy_absolute(acts_file, copy.path_join("acts.json"))
	pay["dir"] = copy
	book["table"] = pay
	var watch := _arg(args, "watch", "").split(",", false)
	var t_from := _arg(args, "from", "0").to_float()
	var every := maxf(_arg(args, "every", "0.5").to_float(), 1.0 / float(TablePhysics.FPS))

	var stage := SubViewport.new()
	stage.size = Vector2i(1280, 720)
	stage.own_world_3d = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	Director.detach()
	var mount_at := Time.get_ticks_usec()
	medium = Medium.make("table") as TableMedium
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	var mounted_us := Time.get_ticks_usec() - mount_at
	subs = preload("res://src/show/subtitles.gd").new()
	add_child(subs)
	medium.bind_captions(subs)
	# ...its intro held as the take's bookend held it: the plan is made from it
	var held_in := float((take.get("bookend", {}) as Dictionary).get("in", Director.intro_hold)) if take.get("bookend") is Dictionary else Director.intro_hold
	Director.intro_hold = held_in
	subs.words = take.get("words", [])
	# ...or THE EPISODE'S SCRIPT AS IT STANDS NOW (`--script`): a take's own words and marks are the script's as it was exported, and
	# a script written again since has its acts cued at other words - its words timed from the plan's own estimate instead
	var from_script := _arg(args, "script", "") != ""
	if from_script:
		book["source"] = FileAccess.get_file_as_string(src_dir.path_join("script.md"))
		for key in ["start_words", "start_index", "start_time"]:
			book.erase(key)
		subs.words = []
	# ...or, played live, A SENTENCE AT A TIME, its words arriving `--ahead` seconds before its first is said (the reading's
	# window), and the bake on a thread of its own, as the app has it
	var live := _arg(args, "live", "") != ""
	var ahead := _arg(args, "ahead", "4").to_float()
	var all_words: Array = subs.words
	var heard := _arg(args, "heard", "") != ""
	# (`--plan-only`, with `--heard`: the plans alone, nothing baked - each act's time and every stretch the painting hand stands idle)
	var plan_only := _arg(args, "plan-only", "") != ""
	if live:
		TablePhysics.threaded = true
	if live or heard:
		subs.words = _arrived(all_words, ahead, 0.0)
	subs.document = book
	var clock := Time.get_ticks_msec()
	medium._key = ""
	# ...PLAYED LIVE, the table is built as the app builds it: on a worker, the app drawing meanwhile - each frame it drew said
	TableMedium.away_in_tests = live
	medium._ensure_doc()
	if medium._build_task >= 0:
		var drawn := 0
		var longest := 0
		var over := 0
		var last := Time.get_ticks_msec()
		var first := -1
		var settled_us := 0
		while medium._build_task >= 0:
			await get_tree().process_frame
			var gap := Time.get_ticks_msec() - last
			last = Time.get_ticks_msec()
			first = gap if first < 0 else first
			drawn += 1
			longest = maxi(longest, gap)
			over += 1 if gap > 50 else 0
			if medium._build_task >= 0 and WorkerThreadPool.is_task_completed(medium._build_task):
				var s0 := Time.get_ticks_usec()
				medium._settle_away()
				settled_us = Time.get_ticks_usec() - s0
		print("episode_bake_probe: the table built on a worker in %d ms - %d frames drawn meanwhile, %d over 50 ms, the longest %d ms" % [
			Time.get_ticks_msec() - clock, drawn, over, longest])
		# ...AND WHAT IS STILL ON THIS THREAD: the medium mounted (`medium 'table'`), the first frame after it, the table put back in the
		# tree, and the frames that first draw it (its materials' pipelines, its shadow maps, the probe catching its faces)
		var after := PackedStringArray()
		medium._work.profiling = true
		medium._work.profile = {}
		for i in 20:
			await get_tree().process_frame
			if i == 0:
				var spent := PackedStringArray()
				for key in medium._work.profile:
					if int(medium._work.profile[key]) > 20000:
						spent.append("%s %.0f ms" % [key, int(medium._work.profile[key]) / 1000.0])
				if not spent.is_empty():
					print("episode_bake_probe: the first frame back, the table's work: %s" % ", ".join(spent))
			after.append(str(Time.get_ticks_msec() - last))
			last = Time.get_ticks_msec()
		# (the Director held, the table's camera is never placed: these first frames draw it from where a camera starts, all of it)
		print("episode_bake_probe: mounted in %.1f ms, the first frame after %d ms; put back in the tree in %.1f ms; the 20 frames after: %s ms" % [
			mounted_us / 1000.0, first, settled_us / 1000.0, ", ".join(after)])
	TableMedium.away_in_tests = false
	if from_script:
		all_words = _words_of_plan(_arg(args, "pace", "1").to_float())
		subs.words = _arrived(all_words, ahead, 0.0) if live or heard else all_words
	medium._follow.extend(subs.words)
	medium._sched = medium._follow.place(medium._plan.parse["actions"], maxf(Director.intro_hold, 0.6), TableMedium.LEAD, TableMedium.TAIL)
	medium._work.schedule(medium._sched, medium._plan.parse, medium._follow.said0, medium._follow.said1, medium._est, 0.0)
	var w: TableWork = medium._work
	var ph: TablePhysics = w.physics
	print("episode_bake_probe: %s - %d things, %d works, %d acts, stood in %d ms" % [copy, w.things.size(), w.works.size(), w.acts.size(), Time.get_ticks_msec() - clock])
	# ...HOW FAR EACH PAINTING TOOL IS HELD OFF ITS SURFACE (`--held`): each program's held keys' stand-off, where the surface is under it
	if _arg(args, "held", "") != "" and w.paint != null:
		for si in w.paint.skins.size():
			var sd: Dictionary = w.paint.skins[si]
			for key in (sd.get("held", {}) as Dictionary):
				var kept: Dictionary = sd["held"][key]
				var hs: PackedVector4Array = kept.get("held", PackedVector4Array())
				var most := 0.0
				var over := 0
				for hv in hs:
					most = maxf(most, hv.w)
					over += 1 if hv.w > 0.002 else 0
				var arcs: PackedFloat32Array = kept.get("arcs", PackedFloat32Array())
				var arc_most := 0.0
				var arcs_over := 0
				for av in arcs:
					arc_most = maxf(arc_most, av)
					arcs_over += 1 if av > 0.002 else 0
				print("  HELD %-44s %4d keys, %4d stood off over 2 mm, the most %.1f mm; %d ways lifted over 2 mm, the most %.1f mm" % [String(key).left(44),
					hs.size(), over, most * 1000.0, arcs_over, arc_most * 1000.0])
				# ...and where each key stood off is, on the surface (millimeters) - its program's own key
				var prog_keys: Array = []
				for made in w.paint._made.values():
					var pp: Dictionary = (made as Dictionary).get("program", {})
					if not pp.is_empty() and String(key).begins_with(String(pp.get("id", "")) + "|"):
						prog_keys = pp["keys"]
				var said := 0
				for k in mini(hs.size(), prog_keys.size()):
					if hs[k].w > 0.004 and said < 6:
						said += 1
						var kk: Array = prog_keys[k]
						print("      key %d at (%.1f, %.1f) mm, pressed %.1f, stood off %.1f mm, held %s" % [k, float(kk[1]), float(kk[2]), float(kk[4]), hs[k].w * 1000.0,
							Vector3(hs[k].x, hs[k].y, hs[k].z)])
	for n in w.notes:
		print("  note: " + n)
	if ph == null:
		print("episode_bake_probe: nothing on this table is physical")
		get_tree().quit(1)
		return
	var end := 0.0
	for r in w.runs:
		end = maxf(end, float((r as Dictionary)["t1"]))
	end += 5.0
	var t_to := _arg(args, "to", str(end)).to_float()
	if _arg(args, "acts", "") != "":
		for r in w.runs:
			var a: Dictionary = w.acts[int((r as Dictionary)["i"])]
			print("  act %-22s %7.2f - %7.2f  %s" % [a["name"], float(r["t0"]), float(r["t1"]), String(a.get("about", "")).left(80)])
	# ...the watched: each work or thing whose name holds a word asked for
	var picks: Array = []   # [{label, wi (a work), ti (a thing)}]
	for wi in w.works.size():
		var nm := String((w.works[wi] as Dictionary)["name"]).to_lower()
		for word in watch:
			if nm.contains(String(word).to_lower()):
				picks.append({"label": w._part_label(wi), "wi": wi, "ti": -1})
				break
	for ti in w.things.size():
		var nm := String((w.things[ti] as Dictionary)["name"]).to_lower()
		for word in watch:
			if nm.contains(String(word).to_lower()) and ph._rigid_of.has(-1 - ti):
				picks.append({"label": "thing: " + nm, "wi": -1, "ti": ti})
				break
	for p in picks:
		var key := int((p as Dictionary)["wi"]) if int((p as Dictionary)["wi"]) >= 0 else -1 - int((p as Dictionary)["ti"])
		print("  watching %s (%s)" % [(p as Dictionary)["label"], "a rigid body" if ph._rigid_of.has(key) else ("loose" if ph._loose_of.has(key) else "posed by the work")])
	# ...OR AS A LIVE PLAN COMES TO KNOW IT (`--heard`): new words, a new plan, the bake already past where it changes
	if heard:
		var lead := _arg(args, "heard", "12").to_float()
		lead = 12.0 if lead <= 1.0 else lead
		var last_word := 0.0
		for wd in all_words:
			last_word = maxf(last_word, float((wd as Dictionary)["t1"]))
		var s_at := 0.0
		var plans := 0
		var said_at := 0.0
		clock = Time.get_ticks_msec()
		while s_at < last_word + 1.0:
			var was_n: int = subs.words.size()
			subs.words = _arrived(all_words, ahead, s_at)
			plans += 1 if subs.words.size() != was_n else 0
			Spectrum.virtual_clock = s_at
			Spectrum.current.time = s_at
			medium.advance(Spectrum.current, 1.0 / 60.0, 1.0)
			w = medium._work
			ph = w.physics
			if not plan_only:
				ph.bake_until(s_at + lead)
			if s_at - said_at >= 60.0:
				said_at = s_at
				print("  heard to %6.1f s, %d plans, in %6.1f s, baked to %.1f" % [s_at, plans, float(Time.get_ticks_msec() - clock) / 1000.0, ph.baked_to()])
			s_at += 0.25
		end = 0.0
		for r in w.runs:
			end = maxf(end, float((r as Dictionary)["t1"]))
		end += 5.0
		t_to = _arg(args, "to", str(end)).to_float()
		Spectrum.virtual_clock = -1.0
		print("episode_bake_probe: heard, %d plans in %.1f s" % [plans, float(Time.get_ticks_msec() - clock) / 1000.0])
		if plan_only:
			var rs: Array = w.runs.duplicate()
			rs.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["t0"]) < float(y["t0"]))
			var hand_end := -INF
			var gaps := 0
			for r in rs:
				var a: Dictionary = w.acts[int((r as Dictionary)["i"])]
				if hand_end > -INF and float(r["t0"]) - hand_end > 8.0:
					print("    IDLE %.1f s (%.1f - %.1f)" % [float(r["t0"]) - hand_end, hand_end, float(r["t0"])])
					gaps += 1
				print("  act %-26s %7.2f - %7.2f" % [a["name"], float(r["t0"]), float(r["t1"])])
				hand_end = maxf(hand_end, float(r["t1"]))
			print("episode_bake_probe: plan only, %d acts, %d idle stretches over 8 s" % [rs.size(), gaps])
			get_tree().quit(0)
			return
	if _arg(args, "profile", "") != "":
		var at := _arg(args, "profile", "0").to_float()
		ph.bake_until(at + 2.0)
		Spectrum.virtual_clock = at
		Spectrum.current.time = at
		medium.advance(Spectrum.current, 1.0 / 60.0, 1.0)
		for _k in 12:
			await get_tree().process_frame
		w.profiling = true
		ph.profiling_drawn = true
		ph.drawn_profile = {}
		for mode in ["static", "work", "medium"]:
			var cpu_us := 0
			var started := Time.get_ticks_usec()
			for k in 60:
				var s := at + float(k) / 60.0
				Spectrum.virtual_clock = s
				Spectrum.current.time = s
				var before := Time.get_ticks_usec()
				if mode == "work":
					w.tick(s)
				elif mode == "medium":
					medium.advance(Spectrum.current, 1.0 / 60.0, 1.0)
				cpu_us += Time.get_ticks_usec() - before
				await get_tree().process_frame
			print("  profile %s at %.1f: CPU %.2f ms, wall %.2f ms/frame" % [mode, at, cpu_us / 60000.0, (Time.get_ticks_usec() - started) / 60000.0])
			if mode == "work" and not w.profile.is_empty():
				var parts := PackedStringArray()
				for key in w.profile:
					parts.append("%s %.2f ms" % [key, int(w.profile[key]) / 60000.0])
				for key in ph.drawn_profile:
					parts.append("%s %.2f ms" % [key, int(ph.drawn_profile[key]) / 60000.0])
				print("    the work's frame: " + ", ".join(parts))
				w.profile = {}
				ph.drawn_profile = {}
		Spectrum.virtual_clock = -1.0
		get_tree().quit(0)
		return
	# THE SPOKEN WORDS (`--spoken=A,B`): each with its index and where the plan's estimate has it
	if _arg(args, "spoken", "") != "":
		var sp_at := _arg(args, "spoken", "").split(",")
		var spoken_all: PackedStringArray = medium._plan.parse.get("spoken", PackedStringArray())
		var marks := {}
		for c in medium._plan.parse.get("cues", []):
			marks[int((c as Dictionary)["si"])] = String((c as Dictionary)["name"])
		var line := PackedStringArray()
		for si in range(String(sp_at[0]).to_int(), mini(String(sp_at[1]).to_int(), spoken_all.size())):
			line.append(("\n  [act %s] " % marks[si] if marks.has(si) else "") + "%d:%s" % [si, spoken_all[si]])
		print(" ".join(line))
		get_tree().quit(0)
		return
	# EACH WATCHED BODY AS THE BAKE HAS IT (`--trace=T0,T1,step`): baked up to each moment on this thread, and what it is doing there -
	# held, asleep, what it rests on and last touched, what held it back - what no frame keeps
	if _arg(args, "trace", "") != "":
		var tr_at := _arg(args, "trace", "").split(",")
		var ts := String(tr_at[0]).to_float()
		var te := String(tr_at[1]).to_float() if tr_at.size() > 1 else ts + 10.0
		var step := String(tr_at[2]).to_float() if tr_at.size() > 2 else 0.25
		var tr_v := {}
		while ts <= te:
			ph.bake_until(ts)
			var acting := PackedStringArray()
			for r in w.runs:
				if ts >= float((r as Dictionary)["t0"]) and ts < float((r as Dictionary)["t1"]):
					acting.append(String((w.acts[int((r as Dictionary)["i"])] as Dictionary)["name"]))
			for p in picks:
				var pd: Dictionary = p
				var key := int(pd["wi"]) if int(pd["wi"]) >= 0 else -1 - int(pd["ti"])
				if ph._loose_of.has(key):
					var lp: Variant = ph.pose_of(key, ts)
					if lp != null:
						var lo := (lp as Transform3D).origin
						print("%7.2f [%s] %-34s at (%.1f, %.1f, %.1f) cm, a loose thing, %s" % [ts, ",".join(acting), String(pd["label"]).left(34), lo.x * 100.0, lo.y * 100.0, lo.z * 100.0,
							"held" if ph._held_at(key, ts) else "let go"])
					else:
						print("%7.2f [%s] %-34s lying as built" % [ts, ",".join(acting), String(pd["label"]).left(34)])
					continue
				if not ph._rigid_of.has(key):
					continue
				var b: Dictionary = ph.rigid.bodies[int(ph._rigid_of[key])]
				var pose: Variant = ph.pose_of(key, ts)
				var at: Vector3 = (pose as Transform3D).origin if pose != null else Vector3.INF
				var tilt := rad_to_deg((pose as Transform3D).basis.y.normalized().angle_to(Vector3.UP)) if pose != null else 0.0
				var hs := int(b["host"])
				var tc := int(b["touch"])
				print("%7.2f [%s] %-34s at (%.1f, %.1f, %.1f) cm, tilt %3.0f, %s%s, host %s, touch %s%s" % [ts, ",".join(acting), String(pd["label"]).left(34), at.x * 100.0, at.y * 100.0, at.z * 100.0, tilt,
					"DORMANT " if bool(b.get("dormant", false)) else "", "held" if b["held"] != null else ("asleep" if bool(b["asleep"]) else "awake"),
					ph._solid_label(hs) if hs >= 0 else str(hs), ph._solid_label(tc) if tc >= 0 else str(tc),
					(", held back by " + ph._solid_label(int(b.get("by", -1)))) if int(b.get("by", -1)) != -1 else ""])
			# ...what is awake, by what it belongs to: what the solver is spending its substeps on
			var awake_by := {}
			var awake_n := 0
			for i in ph.sim.n:
				if ph.sim.alive[i] == 1 and ph.sim.asleep[i] == 0:
					awake_n += 1
					var who: int = ph.sim.body[i]
					var nm := "grains" if who < 0 else "body %d" % who
					awake_by[nm] = int(awake_by.get(nm, 0)) + 1
			print("%7.2f awake %d of %d: %s" % [ts, awake_n, ph.sim.n, str(awake_by).left(200)])
			# ...and each liquid holding anything that has changed: how much, its surface, and what it says stands in it
			for li in ph.liquids.size():
				var S: Dictionary = ph._liq[li]
				var v := float(S["v"]) * 1e6
				if v < 0.01 or not S.has("c") or (absf(v - float(tr_v.get(li, v))) < 0.01 and float(S["q"]) == 0.0):
					tr_v[li] = v
					continue
				tr_v[li] = v
				var under := ph._displacers(li)
				print("%7.2f %-40s %.1f ml, surface %.2f cm, tilt (%.2f, %.2f), pouring %.0f ml/s, %.1f ml stands in it (%.1f as built)" % [ts, ph._liquid_label(li).left(40), v,
					(S["c"] as Vector3).y * 100.0, (S["d"] as Vector2).x, (S["d"] as Vector2).y, float(S["q"]) * 1e6, TablePhysics._under(under, (S["c"] as Vector3).y) * 1e6,
					float((ph.liquids[li] as Dictionary).get("d0", 0.0)) * 1e6])
			ts += step
		get_tree().quit(0)
		return
	# WHAT ONE ACT'S MOVES COST TO WORK OUT (`--carry-cost=<act>`): each of its entries posed afresh at its end (what every plan made
	# asks) and at its middle (where it lifts over what is in its way), on this thread, by what took the time
	if _arg(args, "carry-cost", "") != "":
		var act_name := _arg(args, "carry-cost", "")
		w.profiling = true
		for ch in w._chan:
			for e in w._chan[ch]:
				var ed: Dictionary = e
				if String(ed.get("act", "")) != act_name:
					continue
				for at in [["end", float(ed["s1"])], ["middle", (float(ed["s0"]) + float(ed["s1"])) * 0.5]]:
					for key in ["_down", "_clear", "_clear_path", "_room", "_rise", "_pour", "_dip", "_entry"]:
						ed.erase(key)
					w.profile = {}
					var c0 := Time.get_ticks_usec()
					w._eval(ed, float(at[1]) - float(ed["t0"]), float(at[1]))
					var parts := PackedStringArray()
					for key in w.profile:
						parts.append("%s %.0f ms" % [key, int(w.profile[key]) / 1000.0])
					print("  %s %s (%s) at its %s: %.0f ms  [%s]" % [act_name, ch, String((ed["track"] as Dictionary).get("law", "")), at[0],
						(Time.get_ticks_usec() - c0) / 1000.0, ", ".join(parts)])
		get_tree().quit(0)
		return
	# PLAYED LIVE, from `--from` to `--to`: the clock the wall's, as the voice's player keeps it - on through a frame this thread
	# spent elsewhere, held only while the show waits for its bake - every frame's cost on this thread, each over 50 ms said with
	# what took it and how far the bake was ahead
	if live:
		var seen := {}    # a tenth of a second of the episode's clock -> each watched part's place as drawn then
		var first: Dictionary = await _play(all_words, ahead, t_from, t_to, picks, seen, false)
		_said_played(first)
		_streams_said(medium._work.physics)
		# ...AND SCRUBBED BACK (`--seek=T`): the reading started again from the sentence holding T, its words timed from 0, as the
		# reading hands a scrub - and how long until the show plays, whether the table and its bake stood, and where the watched parts
		# are drawn against where the first pass drew them at the same moment of the episode
		var seek_arg := _arg(args, "seek", "")
		for step in (seek_arg.split(",", false) if seek_arg != "" else PackedStringArray()):
			# ...T[:after], or wK[:after]: spoken word K, the script's words being the spoken words one for one
			var what := String(step).get_slice(":", 0)
			var after := String(step).get_slice(":", 1).to_float() if String(step).contains(":") else _arg(args, "after", "20").to_float()
			var fi := 0
			if what.begins_with("w"):
				fi = what.substr(1).to_int()
			else:
				var back := what.to_float()
				while fi < all_words.size() - 1 and float((all_words[fi] as Dictionary)["t0"]) < back:
					fi += 1
				var sent := int((all_words[fi] as Dictionary).get("sentence", 0))
				while fi > 0 and int((all_words[fi - 1] as Dictionary).get("sentence", 0)) == sent:
					fi -= 1
			var t_start := float((all_words[fi] as Dictionary)["t0"])
			var again: Array = []
			for i in range(fi, all_words.size()):
				var wd: Dictionary = (all_words[i] as Dictionary).duplicate()
				wd["t0"] = float(wd["t0"]) - t_start + 0.25
				wd["t1"] = float(wd["t1"]) - t_start + 0.25
				again.append(wd)
			var spoken: PackedStringArray = medium._plan.parse["spoken"]
			var si: int = fi if from_script else (int(medium._follow.map[fi]) if fi < medium._follow.map.size() else fi)
			var doc: Dictionary = (subs.document as Dictionary).duplicate()
			doc["start_words"] = spoken.slice(si, si + 8)
			doc["start_index"] = si
			doc["start_time"] = t_start
			var was_work: TableWork = medium._work
			var was_baked := medium._work.physics.baked_to()
			medium.release()
			subs.queue_free()
			subs = preload("res://src/show/subtitles.gd").new()
			add_child(subs)
			subs.document = doc
			subs.words = []
			medium.bind_captions(subs)
			print("episode_bake_probe: scrubbed to word %d, the bake at %.1f s" % [si, was_baked])
			var started := Time.get_ticks_msec()
			var second: Dictionary = await _play(again, ahead, 0.0, after, picks, seen, true)
			_said_played(second)
			print("episode_bake_probe: after the scrub - the same table %s, %.1f s waited, %d ms in all; drawn against the first pass: %s" % [
				"STOOD" if medium._work == was_work else "was BUILT AGAIN", float(second["waited"]), Time.get_ticks_msec() - started, str(second["against"])])
			if _arg(args, "acts", "") != "":
				for r in medium._work.runs:
					var a: Dictionary = medium._work.acts[int((r as Dictionary)["i"])]
					print("  act %-22s %7.2f - %7.2f" % [a["name"], float(r["t0"]), float(r["t1"])])
		Spectrum.virtual_clock = -1.0
		get_tree().quit(0)
		return
	# THE FRAMES THAT STALL A LIVE SHOW, from T0 to T1: the whole stretch baked first, then every frame of it played at 60 a
	# second as the app's thread plays it, and each that took over 50 ms of this thread said with what it spent it on - what a
	# viewer sees frozen while the voice goes on, whatever the bake
	if _arg(args, "stalls", "") != "":
		var span := _arg(args, "stalls", "0,%f" % end).split(",")
		var s0 := String(span[0]).to_float()
		var s1 := String(span[1]).to_float() if span.size() > 1 else end
		ph.bake_until(s1 + 1.0)
		w.profiling = true
		ph.profiling_drawn = true
		var worst := 0.0
		var spent := 0.0
		var n := 0
		var s := s0
		while s <= s1:
			Spectrum.virtual_clock = s
			Spectrum.current.time = s
			w.profile = {}
			ph.drawn_profile = {}
			var before := Time.get_ticks_usec()
			medium.advance(Spectrum.current, 1.0 / 60.0, 1.0)
			var ms := (Time.get_ticks_usec() - before) / 1000.0
			worst = maxf(worst, ms)
			spent += ms
			n += 1
			if ms > 50.0:
				var parts := PackedStringArray()
				for key in w.profile:
					if int(w.profile[key]) > 2000:
						parts.append("%s %.0f ms" % [key, int(w.profile[key]) / 1000.0])
				for key in ph.drawn_profile:
					if int(ph.drawn_profile[key]) > 2000:
						parts.append("%s %.0f ms" % [key, int(ph.drawn_profile[key]) / 1000.0])
				var acting := PackedStringArray()
				for r in w.runs:
					if s >= float((r as Dictionary)["t0"]) - 0.5 and s < float((r as Dictionary)["t1"]) + 0.5:
						acting.append(String((w.acts[int((r as Dictionary)["i"])] as Dictionary)["name"]))
				print("  STALL at %7.2f s: %6.0f ms  [%s]  (%s)" % [s, ms, ", ".join(parts), ", ".join(acting)])
			await get_tree().process_frame
			s += 1.0 / 60.0
		print("episode_bake_probe: %d frames from %.1f to %.1f s, %.2f ms a frame, the worst %.0f ms" % [n, s0, s1, spent / maxf(n, 1), worst])
		Spectrum.virtual_clock = -1.0
		get_tree().quit(0)
		return
	# THE GAPS ASKED FOR, AS DRAWN: at each moment the medium posed as the export posed it, every watched part's drawn
	# surface against what is drawn under it - a ray down from over each of its vertices onto everything else (the
	# table's top too): the least is how far it floats (or, under 0, sinks), as the eye sees a shadow's gap
	var gaps := _arg(args, "gaps", "").split(",", false)
	if not gaps.is_empty():
		for sh in gaps:
			var t_gap := String(sh).to_float()
			Spectrum.virtual_clock = t_gap
			Spectrum.current.time = t_gap
			medium.advance(Spectrum.current, 1.0 / 60.0, 1.0)
			await get_tree().process_frame
			for p in picks:
				print("  gap %.1f s %s" % [t_gap, _drawn_gap(w, p)])
		Spectrum.virtual_clock = -1.0
		print("episode_bake_probe: done")
		get_tree().quit(0)
		return
	# THE PICTURES ASKED FOR, as the export drew them: the medium advanced to each moment (the bake runs up to it)
	var shots := _arg(args, "shots", "").split(",", false)
	if not shots.is_empty():
		var out := _arg(args, "out", copy)
		DirAccess.make_dir_recursive_absolute(out)
		for sh in shots:
			var t_shot := String(sh).to_float()
			Spectrum.virtual_clock = t_shot
			Spectrum.current.time = t_shot
			medium.advance(Spectrum.current, 1.0 / 60.0, 1.0)
			for _i in 3:
				await get_tree().process_frame
			var img := stage.get_texture().get_image()
			var path := out.path_join("shot_%06.1f.png" % t_shot)
			if img != null:
				img.save_png(path)
			print("  shot %.1f s -> %s%s" % [t_shot, path, "" if img != null else " (no picture: run it with GHOST_PROBE_GPU=1)"])
		Spectrum.virtual_clock = -1.0
		print("episode_bake_probe: done")
		get_tree().quit(0)
		return
	# THE BAKE, on this thread, as a render bakes it
	clock = Time.get_ticks_msec()
	var t := 0.0
	var chunk := _arg(args, "chunk", "30").to_float()
	ph.profiling = _arg(args, "profile-bake", "") != ""
	while t < t_to:
		var k0 := ph._k
		var c0 := Time.get_ticks_msec()
		t = minf(t + chunk, t_to)
		ph.bake_until(t)
		# ...and how many of the chunk's frames were stepped, not the frame before kept (a quiet frame is that same row)
		var stepped := 0
		for k in range(maxi(k0, 1), mini(ph._k, ph.frames.size())):
			if not is_same(ph.frames[k], ph.frames[k - 1]):
				stepped += 1
		print("  baked to %6.1f s in %6.1f s (this chunk %5.1f s, %d of %d frames stepped)" % [t, float(Time.get_ticks_msec() - clock) / 1000.0,
			float(Time.get_ticks_msec() - c0) / 1000.0, stepped, ph._k - k0])
		# ...and with --profile-bake, what the chunk's stepped frames spent their time on, and why each was stepped
		if ph.profiling and not ph.profile.is_empty():
			var keys := ph.profile.keys()
			keys.sort()
			var parts := PackedStringArray()
			for key in keys:
				var v := int(ph.profile[key])
				parts.append(("%s %d" % [key, v]) if String(key).begins_with("why") or String(key) == "frames asked" else ("%s %.2f s" % [key, v / 1e6]))
			print("    " + ", ".join(parts))
			ph.profile = {}
	if _arg(args, "series", "") != "":
		var mine := _series(w, ph, t_to)
		var f := FileAccess.open(_arg(args, "series", ""), FileAccess.WRITE)
		f.store_var(mine)
		f.close()
		print("episode_bake_probe: %d samples of %d things written" % [(mine["t"] as PackedFloat32Array).size(), (mine["items"] as Dictionary).size()])
		if _arg(args, "against", "") != "":
			if FileAccess.file_exists(_arg(args, "against", "")):
				_series_against(mine, _series_read(_arg(args, "against", "")))
			else:
				print("episode_bake_probe: no %s to compare with yet (--compare=a,b, once it is written)" % _arg(args, "against", ""))
	if args.has("--audit"):
		args_soft_trace = args.has("--soft-trace")
		_audit(w, ph, t_to)
		print("episode_bake_probe: done")
		get_tree().quit(0)
		return
	if _arg(args, "series", "") != "":
		print("episode_bake_probe: done")
		get_tree().quit(0)
		return
	# WHAT IT CAME TO, sampled
	var last_v := {}
	var s := t_from
	while s <= t_to:
		var line := PackedStringArray()
		var acts_now := PackedStringArray()
		for r in w.runs:
			if s >= float((r as Dictionary)["t0"]) and s < float((r as Dictionary)["t1"]):
				acts_now.append(String((w.acts[int((r as Dictionary)["i"])] as Dictionary)["name"]))
		for p in picks:
			line.append(_pose_line(w, ph, p, s))
		var f: Variant = ph.frame_at(s)
		if f is Dictionary:
			var liq: PackedFloat32Array = (f as Dictionary)["liq"]
			for li in ph.liquids.size():
				var v := liq[li * 16] * 1e6
				var q := liq[li * 16 + 8] * 1e6
				if absf(v - float(last_v.get(li, -1.0))) > 0.05 or q > 0.0:
					line.append("%s %.1f ml, its surface %.2f cm up%s" % [ph._liquid_label(li), v, liq[li * 16 + 5] * 100.0, (" pouring %.1f ml/s" % q) if q > 0.0 else ""])
					last_v[li] = v
			var streams: Array = (f as Dictionary).get("streams", [])
			if not streams.is_empty():
				var lo := INF
				for st in streams:
					for pt in ((st as Dictionary)["pts"] as PackedVector3Array):
						lo = minf(lo, pt.y)
				line.append("%d stream(s) in the air, the lowest at %.1f cm" % [streams.size(), lo * 100.0])
		print("%7.2f [%s] %s" % [s, ",".join(acts_now), " | ".join(line)])
		s += every
	# EACH POUR'S PLAN, as the bake made it: where its lip was held, against the mouth it poured into
	for k in ph._held:
		var h: Variant = ph._held[k]
		if h is Dictionary and (h as Dictionary).get("_pour") is Dictionary and not ((h as Dictionary)["_pour"] as Dictionary).is_empty():
			var pl: Dictionary = (h as Dictionary)["_pour"]
			var tr: Dictionary = (h as Dictionary)["track"]
			print("  pour %s into %s: lip held at %s cm over the mouth found at %s cm, pre-tilt %.0f, rise %.1f cm; the mouth now %s" % [k, tr.get("into"),
				(pl["at"] as Vector3) * 100.0, (pl["mouth"] as Vector3) * 100.0, rad_to_deg(float(pl["pre"])), float(pl["rise"]) * 100.0,
				ph.twin._mouth_of(String(tr.get("into")), float((h as Dictionary)["t0"]))])
	# EACH ACT'S REPORT, as the puppeteer would be told it
	for r in w.runs:
		if float(r["t1"]) > t_to or float(r["t1"]) < t_from:
			continue
		var a: Dictionary = w.acts[int((r as Dictionary)["i"])]
		# ...each pour judged against what it was meant for, as `act` judges it ([method TableWork.check])
		var pours: Array = []
		for tr in a["tracks"]:
			var td: Dictionary = tr
			if String(td.get("law", "")) == "pour" and (td.has("_ti") or td.has("_wi")):
				pours.append({"label": String(td.get("thing", "")), "from": ph.solids_of_mover(int(td.get("_ti", -1)), int(td.get("_wi", -1))), "into": String(td.get("into", ""))})
		var rep := ph.report(float(r["t0"]), float(r["t1"]), pours)
		for l in rep:
			if l.contains("HELD BACK") or l.contains("let go") or l.contains("came to rest") or l.contains("poured") or l.contains("POUR") \
					or l.contains("roken into") or l.contains("ENDS IN THE AIR") or l.contains(" now "):
				print("  report %s: %s" % [a["name"], l])
	print("episode_bake_probe: done")
	get_tree().quit(0)


func _pose_line(w: TableWork, ph: TablePhysics, p: Dictionary, s: float) -> String:
	var wi := int(p["wi"])
	var ti := int(p["ti"])
	var key := wi if wi >= 0 else -1 - ti
	var x: Variant = ph.pose_of(key, s) if (ph._rigid_of.has(key) or ph._loose_of.has(key)) else null
	if x == null and wi >= 0:
		x = w._work_world(wi, s)
	if x == null:
		return "%s -" % p["label"]
	var xf: Transform3D = x
	var tilt := rad_to_deg(xf.basis.y.normalized().angle_to(Vector3.UP))
	var yaw := rad_to_deg(atan2(xf.basis.x.z, xf.basis.x.x))
	var extra := ""
	if ph._rigid_of.has(key):
		var bi := int(ph._rigid_of[key])
		var f: Variant = ph.frame_at(s)
		if f is Dictionary:
			var off := ph.held_off(f as Dictionary, bi)
			var by := ph.held_by(f as Dictionary, bi)
			if off > 0.001:
				extra += " off-hand %.1f cm" % (off * 100.0)
			if by >= 0:
				extra += " by " + ph._solid_label(by)
		# ...and where its hand has it, by the plan (its middle, cm)
		if wi >= 0:
			var mid: Vector3 = ((w.works[wi] as Dictionary)["w"] as Dictionary).get("middle", Vector3.ZERO)
			var hx := w._work_world(wi, s) * mid
			var bx := xf * mid
			extra += " | middle (%.1f, %.1f, %.1f) hand (%.1f, %.1f, %.1f)" % [bx.x * 100.0, bx.y * 100.0, bx.z * 100.0, hx.x * 100.0, hx.y * 100.0, hx.z * 100.0]
	return "%s (%.1f, %.1f, %.1f) tilt %.0f turn %.0f%s" % [p["label"], xf.origin.x * 100.0, xf.origin.y * 100.0, xf.origin.z * 100.0, tilt, yaw, extra]


## Picked part [param p]'s drawn surface against everything solid drawn under it, as posed now (no liquid's surface): the
## least drop from any of its vertices to what is under it (mm; a vertex as much as [constant SINK] into what is under it reads
## under 0), where, and onto what.
func _drawn_gap(w: TableWork, p: Dictionary) -> String:
	var wi := int(p["wi"])
	var own_root: Node3D = (w.works[wi] as Dictionary)["node"] if wi >= 0 else (w.things[int(p["ti"])] as Dictionary)["node"]
	var own: Array = []
	var others := PackedVector3Array()
	var names: Array = []   # [first face, label]
	for th in w.things:
		for m in (th as Dictionary)["meshes"]:
			var mi := m as MeshInstance3D
			if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
				continue
			if mi == own_root or own_root.is_ancestor_of(mi):
				own.append(mi)
				continue
			if w._is_soft(mi):
				continue
			var xf := w._world_of(mi)
			names.append([others.size() / 3, String((th as Dictionary)["name"]) + "/" + String(mi.get_parent().name) + "/" + String(mi.name)])
			for q in mi.mesh.get_faces():
				others.append(xf * q)
	if own.is_empty():
		return "%s: nothing drawn" % p["label"]
	var tm := TableWork._ray_mesh(others)
	var least := INF
	var at := Vector3.ZERO
	var onto := "the table"
	for mi in own:
		var xf := w._world_of(mi)
		var seen := {}
		for q in (mi as MeshInstance3D).mesh.get_faces():
			var v := xf * q
			var key := Vector3i(v * 2000.0)
			if seen.has(key):
				continue
			seen[key] = true
			var drop := v.y
			var what := "the table"
			var hit: Dictionary = tm.intersect_ray((v + Vector3.UP * SINK) * TableWork.RAY_SCALE, Vector3.DOWN)
			if not hit.is_empty():
				var hy := float((hit["position"] as Vector3).y) / TableWork.RAY_SCALE
				if v.y - hy < drop:
					drop = v.y - hy
					var fi := int(hit.get("face_index", -1))
					what = "?"
					for nm in names:
						if fi >= int((nm as Array)[0]):
							what = String((nm as Array)[1])
			if drop < least:
				least = drop
				at = v
				onto = what
	return "%s: %.2f mm over %s at (%.1f, %.1f, %.1f) cm" % [p["label"], least * 1000.0, onto, at.x * 100.0, at.y * 100.0, at.z * 100.0]


## How far into what is under it a vertex may be and still be seen by [method _drawn_gap] (meters).
const SINK := 0.003


## A LIVE READING PLAYED from [param s0] to [param s1] of its own clock, [param words] arriving a sentence at a time [param ahead]
## of being said: each frame's cost on this thread, the stalls and the watched parts' jumps said as they happen - and, kept in
## [param seen] by the tenth of a second of the episode's clock (the table's, [member TableMedium._now]), where each watched part was
## drawn; with [param against], how far it is drawn now from where it was drawn at that moment before (the worst, per part).
func _play(words: Array, ahead: float, s0: float, s1: float, picks: Array, seen: Dictionary, against: bool) -> Dictionary:
	var w: TableWork = medium._work
	var ph: TablePhysics = w.physics
	var s := s0
	var last := Time.get_ticks_usec()
	var out := {"from": s0, "to": s1, "n": 0, "spent": 0.0, "worst": 0.0, "over": [0, 0], "waited": 0.0, "against": {}}
	# ...each watched part AS DRAWN: a jump in one frame past a hand's reach (3 cm, 15 degrees), or shown or hidden, said
	var drawn_was := {}
	var off_said := {}
	w.profiling = true
	ph.profiling_drawn = true
	while s <= s1:
		subs.words = _arrived(words, ahead, s)
		Spectrum.virtual_clock = s
		Spectrum.current.time = s
		w.profile = {}
		ph.drawn_profile = {}
		var before := Time.get_ticks_usec()
		medium.advance(Spectrum.current, 1.0 / 60.0, 1.0)
		var ms := (Time.get_ticks_usec() - before) / 1000.0
		w = medium._work
		ph = w.physics
		out["worst"] = maxf(float(out["worst"]), ms)
		out["spent"] = float(out["spent"]) + ms
		out["n"] = int(out["n"]) + 1
		(out["over"] as Array)[0] += 1 if ms > 50.0 else 0
		(out["over"] as Array)[1] += 1 if ms > 100.0 else 0
		if ms > 50.0:
			var parts := PackedStringArray()
			for key in w.profile:
				if int(w.profile[key]) > 2000:
					parts.append("%s %.0f ms" % [key, int(w.profile[key]) / 1000.0])
			for key in ph.drawn_profile:
				if int(ph.drawn_profile[key]) > 2000:
					parts.append("%s %.0f ms" % [key, int(ph.drawn_profile[key]) / 1000.0])
			var acting := PackedStringArray()
			for r in w.runs:
				if medium._now >= float((r as Dictionary)["t0"]) - 0.5 and medium._now < float((r as Dictionary)["t1"]) + 0.5:
					acting.append(String((w.acts[int((r as Dictionary)["i"])] as Dictionary)["name"]))
			print("  STALL at %7.2f s: %6.0f ms, baked to %7.2f s%s  [%s]  (%s)" % [medium._now, ms, ph.baked_to(), "  (waiting)" if Spectrum.waiting() else "",
				", ".join(parts), ", ".join(acting)])
		var bin := int(round(medium._now * 10.0))
		# ...EACH LIQUID AS THE FRAME DRAWN HAS IT, each half second one has changed: what a report of a level would read (feedback 0013)
		if bin % 5 == 0 and bin != int(out.get("liq_bin", -1)):
			out["liq_bin"] = bin
			var fr: Variant = ph.frame_at(medium._now)
			if fr is Dictionary:
				var lq: PackedFloat32Array = (fr as Dictionary)["liq"]
				var said := PackedStringArray()
				for li in ph.liquids.size():
					if li * 16 < lq.size() and lq[li * 16] > 1e-7:
						said.append("%s %.1f ml" % [ph._liquid_label(li).get_slice("'s ", 1), lq[li * 16] * 1e6])
				var line := ", ".join(said)
				if line != String(out.get("liq_was", "")):
					out["liq_was"] = line
					print("  LIQ %7.2f s (baked to %.2f): %s" % [medium._now, ph.baked_to(), line])
		for p in picks:
			var pd: Dictionary = p
			var node: Node3D = (w.works[int(pd["wi"])] as Dictionary)["node"] if int(pd["wi"]) >= 0 else (w.things[int(pd["ti"])] as Dictionary)["node"]
			var xf := node.global_transform
			var vis := node.is_visible_in_tree()
			var was: Variant = drawn_was.get(pd["label"])
			if was != null:
				var d := (xf.origin - ((was as Array)[0] as Transform3D).origin).length()
				var turn := rad_to_deg(Quaternion(xf.basis.orthonormalized()).angle_to(Quaternion(((was as Array)[0] as Transform3D).basis.orthonormalized())))
				if d > 0.03 or turn > 15.0 or vis != bool((was as Array)[1]):
					print("  JUMP %s at %7.2f s: %.1f cm, %.0f deg%s - now at %s, baked to %.2f%s%s" % [pd["label"], medium._now, d * 100.0, turn,
						(", shown" if vis else ", HIDDEN") if vis != bool((was as Array)[1]) else "", str(xf.origin.snapped(Vector3.ONE * 0.001)),
						ph.baked_to(), "  (waiting)" if Spectrum.waiting() else "", "  (outran)" if (int(pd["wi"]) >= 0 and w._outran(int(pd["wi"]), medium._now)) else ""])
			drawn_was[pd["label"]] = [xf, vis]
			# ...AND DRAWN WHERE THE BAKE HAS IT? - a part is a child of its thing's node, posed against it each frame it can change
			var key2 := int(pd["wi"]) if int(pd["wi"]) >= 0 else -1 - int(pd["ti"])
			if ph._rigid_of.has(key2):
				var baked: Variant = ph.pose_of(key2, medium._now)
				if baked != null and not (int(pd["wi"]) >= 0 and w._outran(int(pd["wi"]), medium._now)):
					var there := w._world_of(node)
					var off := there.origin.distance_to((baked as Transform3D).origin)
					if off > 0.003 and medium._now - float(off_said.get(pd["label"], -INF)) > 0.1:
						off_said[pd["label"]] = medium._now
						print("  OFF  %s at %7.2f s: drawn %.1f cm from where the bake has it (settled %s, full %s)" % [pd["label"], medium._now, off * 100.0,
							str(w._settled(int(pd["wi"]), medium._now)) if int(pd["wi"]) >= 0 else "-", str(w._full)])
			if against and (seen.get(bin, {}) as Dictionary).has(pd["label"]):
				var off := xf.origin.distance_to((seen[bin] as Dictionary)[pd["label"]] as Vector3)
				(out["against"] as Dictionary)[pd["label"]] = snappedf(maxf(float((out["against"] as Dictionary).get(pd["label"], 0.0)), off * 100.0), 0.1)
			elif not against:
				if not seen.has(bin):
					seen[bin] = {}
				(seen[bin] as Dictionary)[pd["label"]] = xf.origin
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var real := (now - last) / 1e6
		last = now
		# ...and the WHOLE FRAME, the picture drawn too (on a real renderer, GHOST_PROBE_GPU=1): one held past 200 ms with this
		# thread's work quick was the drawing - a shader made, a buffer allocated
		if real > 0.2:
			print("  FRAME at %7.2f s: %6.0f ms in all, %6.0f ms of it the table's work" % [medium._now, real * 1000.0, ms])
		if Spectrum.waiting():
			out["waited"] = float(out["waited"]) + real
		else:
			s += real
	return out


const SERIES_EVERY := 0.2
const SERIES_CM := 1.0
const SERIES_DEG := 6.0
const SERIES_ML := 1.0


## EVERY BODY AND LIQUID sampled to [param t_to] (`--series`): `{t, items: {label: PackedFloat32Array}}`, a body's seven numbers a sample
## (its place in cm, its turn), a liquid's one (ml). Named by label, each copy told by its number: a table stood twice lists them alike.
func _series(w: TableWork, ph: TablePhysics, t_to: float) -> Dictionary:
	var ts := PackedFloat32Array()
	var items := {}
	var keys: Array = []
	var seen := {}
	for key in ph._rigid_of.keys() + ph._loose_of.keys():
		var label := _series_label(w, ph, int(key))
		var n := int(seen.get(label, 0))
		seen[label] = n + 1
		keys.append([int(key), label if n == 0 else "%s #%d" % [label, n + 1]])
	var s := 0.0
	while s <= t_to:
		ts.append(s)
		var fr: Variant = ph.frame_at(s)
		for pair in keys:
			var pose: Variant = ph.pose_of(int(pair[0]), s)
			var xf: Transform3D = pose if pose != null else Transform3D()
			var q := xf.basis.orthonormalized().get_rotation_quaternion()
			if not items.has(pair[1]):
				items[pair[1]] = PackedFloat32Array()
			var a: PackedFloat32Array = items[pair[1]]
			a.append_array([xf.origin.x * 100.0, xf.origin.y * 100.0, xf.origin.z * 100.0, q.x, q.y, q.z, q.w])
			items[pair[1]] = a
		if fr is Dictionary:
			var lq: PackedFloat32Array = (fr as Dictionary)["liq"]
			for li in ph.liquids.size():
				var name := "liquid: " + ph._liquid_label(li)
				if not items.has(name):
					items[name] = PackedFloat32Array()
				var a: PackedFloat32Array = items[name]
				a.append(lq[li * 16] * 1e6 if li * 16 < lq.size() else 0.0)
				items[name] = a
		s += SERIES_EVERY
	return {"t": ts, "items": items}


func _series_label(w: TableWork, _ph: TablePhysics, key: int) -> String:
	if key >= 0:
		return w._part_label(key)
	return "thing: " + String((w.things[-1 - key] as Dictionary)["name"])


func _series_read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var d: Dictionary = f.get_var()
	f.close()
	return d


## WHERE [param mine] PARTS FROM [param other]: each stretch a body stands over [constant SERIES_CM] cm or [constant SERIES_DEG] degrees from the
## other's, or a liquid holds over [constant SERIES_ML] ml other than the other's - once, with its worst.
func _series_against(mine: Dictionary, other: Dictionary) -> void:
	var ta: PackedFloat32Array = mine["t"]
	var n := mini(ta.size(), (other["t"] as PackedFloat32Array).size())
	var said := 0
	for label in mine["items"]:
		if not (other["items"] as Dictionary).has(label):
			print("  APART %s: the other has none" % label)
			said += 1
			continue
		var a: PackedFloat32Array = mine["items"][label]
		var b: PackedFloat32Array = other["items"][label]
		var stride := 1 if String(label).begins_with("liquid: ") else 7
		var began := -1
		var worst := 0.0
		var worst_turn := 0.0
		var worst_k := 0
		for k in n + 1:
			var off := 0.0
			var turn := 0.0
			if k < n and (k + 1) * stride <= a.size() and (k + 1) * stride <= b.size():
				if stride == 1:
					off = absf(a[k] - b[k])
				else:
					off = Vector3(a[k * 7] - b[k * 7], a[k * 7 + 1] - b[k * 7 + 1], a[k * 7 + 2] - b[k * 7 + 2]).length()
					var dot := absf(a[k * 7 + 3] * b[k * 7 + 3] + a[k * 7 + 4] * b[k * 7 + 4] + a[k * 7 + 5] * b[k * 7 + 5] + a[k * 7 + 6] * b[k * 7 + 6])
					turn = rad_to_deg(2.0 * acos(clampf(dot, 0.0, 1.0)))
			var apart := off > (SERIES_ML if stride == 1 else SERIES_CM) or turn > SERIES_DEG
			if apart:
				if began < 0:
					began = k
					worst = 0.0
					worst_turn = 0.0
					worst_k = k
				if off > worst:
					worst = off
					worst_k = k
				worst_turn = maxf(worst_turn, turn)
			elif began >= 0:
				if stride == 1:
					print("  APART %7.1f - %7.1f s  %s: %.1f ml off at %.1f s (%.1f against %.1f)" % [ta[began], ta[k - 1], label, worst, ta[worst_k], a[worst_k], b[worst_k]])
				else:
					print("  APART %7.1f - %7.1f s  %s: %.1f cm, %.0f deg off, the most at %.1f s" % [ta[began], ta[k - 1], label, worst, worst_turn, ta[worst_k]])
				said += 1
				began = -1
	print("episode_bake_probe: %d stretch(es) apart over %d samples, %.1f s" % [said, n, ta[n - 1] if n > 0 else 0.0])


## WHERE EACH STREAM WENT, by the liquid it left and what caught it: how much, over what stretch, and where the first and last of it
## fell from and to (feedback 0013: a ladle's 27 ml poured over a vial that stayed empty, live only).
func _streams_said(ph: TablePhysics) -> void:
	var by := {}
	for p in ph.parcels:
		var pd: Dictionary = p
		var key := "%s -> %s" % [ph._liquid_label(int(pd["from"])).get_slice("'s ", 1), ph._liquid_label(int(pd["into"])).get_slice("'s ", 1) if int(pd["into"]) >= 0 else str(pd["into"])]
		if not by.has(key):
			by[key] = {"vol": 0.0, "t0": float(pd["t0"]), "t1": float(pd["t0"]), "p0": pd["p"], "p1": pd["p"]}
		var b: Dictionary = by[key]
		b["vol"] = float(b["vol"]) + float(pd["vol"])
		b["t1"] = float(pd["t0"])
		b["p1"] = pd["p"]
	for key in by:
		var b: Dictionary = by[key]
		print("  STREAM %s: %.1f ml from %.2f to %.2f s, left from %s to %s" % [key, float(b["vol"]) * 1e6, float(b["t0"]), float(b["t1"]), str(((b["p0"] as Vector3) * 100.0).snapped(Vector3.ONE * 0.1)), str(((b["p1"] as Vector3) * 100.0).snapped(Vector3.ONE * 0.1))])
	# ...and where what nothing caught stopped: on what, how far down
	var lost := 0
	for p in ph.parcels:
		var pd: Dictionary = p
		if int(pd["into"]) < 0:
			lost += 1
			if lost % 12 == 1:
				var end_at := TablePhysics._parcel_at(pd, float(pd["t1"]) - float(pd["t0"]))
				print("  LOST left %.2f s from %s, stopped %.2f s at %s, on %s" % [float(pd["t0"]), str(((pd["p"] as Vector3) * 100.0).snapped(Vector3.ONE * 0.1)), float(pd["t1"]),
					str((end_at * 100.0).snapped(Vector3.ONE * 0.1)), str(pd["into"])])
	for li in ph.liquids.size():
		if ph._liquid_label(li).contains("vial 1"):
			var sd: Dictionary = ph.solids[int((ph.liquids[li] as Dictionary)["solid"])]
			print("  VESSEL %s stands at %s cm by its solid, moved %s, owner %s" % [ph._liquid_label(li), str(((sd["xf"] as Transform3D).origin * 100.0).snapped(Vector3.ONE * 0.1)), str(sd.get("moving", false)), str(sd.get("owner", ""))])


func _said_played(r: Dictionary) -> void:
	print("episode_bake_probe: played live from %.1f to %.1f s - %d frames, %.2f ms a frame on this thread, the worst %.0f ms, %d over 50 ms, %d over 100; %.1f s waited for the bake" % [
		float(r["from"]), float(r["to"]), int(r["n"]), float(r["spent"]) / maxf(int(r["n"]), 1), float(r["worst"]), int((r["over"] as Array)[0]),
		int((r["over"] as Array)[1]), float(r["waited"])])


## The script's own spoken words as a voice would say them, each where the plan's estimate has it ([member TableMedium._est]), at
## [param pace] times its speed - a "sentence" a dozen words, for what arrives together.
func _words_of_plan(pace: float) -> Array:
	var spoken: PackedStringArray = medium._plan.parse.get("spoken", PackedStringArray())
	var out: Array = []
	for j in spoken.size():
		var t0: float = (medium._est[j] if j < medium._est.size() else float(j) * 0.4) / maxf(pace, 0.01)
		var t1: float = (medium._est[j + 1] if j + 1 < medium._est.size() else t0 + 0.4) / maxf(pace, 0.01)
		out.append({"text": spoken[j], "t0": t0, "t1": minf(t1, t0 + 0.6), "sentence": j / 12, "speaker": "Narrator", "emph": 0})
	return out


## The words a live reading has by show time [param s]: every sentence whose first word is said within [param ahead] seconds.
func _arrived(words: Array, ahead: float, s: float) -> Array:
	var out: Array = []
	var first := {}
	for wd in words:
		var si := int((wd as Dictionary).get("sentence", 0))
		if not first.has(si):
			first[si] = float((wd as Dictionary).get("t0", 0.0))
		if float(first[si]) > s + ahead:
			break
		out.append(wd)
	return out


static func _copy_dir(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for f in DirAccess.get_files_at(from):
		DirAccess.copy_absolute(from.path_join(f), to.path_join(f))
	for d in DirAccess.get_directories_at(from):
		_copy_dir(from.path_join(d), to.path_join(d))


## How deep a body may stand in what it meets before the audit says so, a jump in a frame, how far off its hand a held thing may be and for how long, how far over what
## is under it what has come to rest may lie (meters, seconds).
const AUDIT_DEEP := 0.004
const AUDIT_JUMP := 0.05
const AUDIT_OFF := 0.03
const AUDIT_OFF_FOR := 0.5
const AUDIT_FLOAT := 0.012
const AUDIT_STEP := 0.1
const AUDIT_SETTLE := 2.5
const AUDIT_THROUGH := 0.0005
const AUDIT_STRETCHED := 0.05


## THE SHOW AGAINST WHAT MUST ALWAYS HOLD (`--audit`): each kind of thing wrong, said once a stretch, with its worst. The bake is done: this only reads frames.
func _audit(w: TableWork, ph: TablePhysics, t_to: float) -> void:
	var found := {}       # what -> {t0, t1, worst}
	var note := func(what: String, t: float, how: float) -> void:
		if not found.has(what):
			found[what] = {"t0": t, "t1": t, "worst": how, "at": t}
		var d: Dictionary = found[what]
		d["t1"] = t
		if how > float(d["worst"]):
			d["worst"] = how
			d["at"] = t
	# ...LIQUID: what is in every vessel, in the air and spilled is what there was, but for what the work fills by hand; and each surface moves smoothly
	var filled := false
	for li in ph.liquids.size():
		filled = filled or w._chan.has("w%d:fill" % int((ph.liquids[li] as Dictionary)["wi"]))
	var first: PackedFloat32Array = (ph.frame_at(0.0) as Dictionary)["liq"]
	var start := 0.0
	for li in ph.liquids.size():
		start += first[li * 16]
	var last_level := {}
	var t := 0.0
	var dt := 1.0 / float(TablePhysics.FPS)
	while t < t_to:
		var f: Dictionary = ph.frame_at(t)
		var lq: PackedFloat32Array = f["liq"]
		var whole := 0.0
		for li in ph.liquids.size():
			whole += lq[li * 16]
			var liq_sd: Dictionary = ph.solids[int((ph.liquids[li] as Dictionary)["solid"])]
			if lq[li * 16] > 1e-6 and not liq_sd.has("body"):
				var y := lq[li * 16 + 5]
				if last_level.has(li) and absf(y - float(last_level[li])) > 0.004:
					note.call("the surface of %s jumps a frame" % ph._liquid_label(li), t, absf(y - float(last_level[li])) * 100.0)
				last_level[li] = y
		for pd in ph.parcels:
			var pp: Dictionary = pd
			if float(pp["t0"]) <= t and (float(pp["t1"]) > t or int(pp["into"]) == -1):
				whole += float(pp["vol"])
		if not filled and absf(whole - start) > 5e-6:
			note.call("liquid is not kept (ml)", t, absf(whole - start) * 1e6)
		t += dt * 3.0
	var by_where := {}
	for pd in ph.parcels:
		var pp: Dictionary = pd
		if int(pp["into"]) == -1:
			var src := ph._liquid_label(int(pp["from"]))
			by_where[src] = float(by_where.get(src, 0.0)) + float(pp["vol"])
	for src in by_where:
		print("  AUDIT %.1f ml spilled from %s" % [float(by_where[src]) * 1e6, src])
	# ...BODIES: each frame's move, each step what it stands in
	var keys: Array = ph._rigid_of.keys()
	var label := func(key: int) -> String:
		return w._part_label(key) if key >= 0 else String((w.things[-1 - key] as Dictionary)["name"])
	var was := {}
	var off_for := {}
	t = 0.0
	while t < t_to:
		var f: Dictionary = ph.frame_at(t)
		for key in keys:
			var bi := int(ph._rigid_of[key])
			if ph._frame_rank(f, bi) < 0:
				continue
			var pose: Variant = ph.pose_of(int(key), t)
			if pose == null:
				continue
			var x: Transform3D = pose
			if was.has(key):
				var moved := x.origin.distance_to((was[key] as Transform3D).origin)
				if moved > AUDIT_JUMP:
					note.call("%s jumps in a frame (cm)" % label.call(key), t, moved * 100.0)
			was[key] = x
			var off := ph.held_off(f, bi)
			if off > AUDIT_OFF:
				off_for[key] = float(off_for.get(key, 0.0)) + dt
				if float(off_for[key]) > AUDIT_OFF_FOR:
					var by := ph.held_by(f, bi)
					note.call("%s kept off its hand by %s (cm)" % [label.call(key), ph._solid_label(by) if by >= 0 else "nothing said"], t, off * 100.0)
			else:
				off_for[key] = 0.0
		t += dt
	# ...what each moved body stands in, and the loose things' own surfaces against the vessel they lie in
	var motion := {}
	var pose_at := func(key: int, at: float) -> Transform3D:
		var pv: Variant = ph.pose_of(key, at)
		return ((pv as Transform3D) * ph._rest_of(key).affine_inverse()) if pv != null else Transform3D.IDENTITY
	var drawn := _audit_loose_points(w, ph)
	var rests := {}
	t = 0.0
	while t < t_to:
		var f: Dictionary = ph.frame_at(t)
		motion = {}
		for key in keys:
			if ph._frame_rank(f, int(ph._rigid_of[key])) >= 0:
				motion[int(ph._rigid_of[key])] = pose_at.call(int(key), t)
		var worlds := {}
		for si in ph.solids.size():
			var sd: Dictionary = ph.solids[si]
			var xf: Transform3D = sd["rest"]
			if sd.has("body") and motion.has(int(sd["body"])):
				xf = (motion[int(sd["body"])] as Transform3D) * xf
			worlds[si] = xf
		for key in keys:
			var bi := int(ph._rigid_of[key])
			if not motion.has(bi):
				continue
			var b: Dictionary = ph.rigid.bodies[bi]
			var m: Transform3D = motion[bi]
			var own: PackedInt32Array = b["solids"]
			var stilled: bool = rests.has(bi) and (rests[bi] as Transform3D).is_equal_approx(m)
			rests[bi] = m
			if stilled:
				continue
			var low := Vector3.INF
			var pts: PackedVector3Array = b["pts"]
			for k in range(0, pts.size(), maxi(pts.size() / 120, 1)):
				var p: Vector3 = m * pts[k]
				if p.y < low.y:
					low = p
				if p.y < -AUDIT_DEEP:
					note.call("%s through the table (mm)" % label.call(key), t, -p.y * 1000.0)
				for si in ph.solids.size():
					if own.has(si):
						continue
					var sd: Dictionary = ph.solids[si]
					var xf: Transform3D = worlds[si]
					if not (xf * (sd["box"] as AABB)).grow(0.002).has_point(p):
						continue
					var depth := -float((sd["field"] as ShapeField).sample(xf.affine_inverse() * p).x)
					if depth > AUDIT_DEEP:
						note.call("%s in %s (mm)" % [label.call(key), ph._solid_label(si)], t, depth * 1000.0)
		# ...a loose thing's surface, past the walls of the inside its middle is in
		for li in drawn:
			var L: Dictionary = ph.loose[int(li)]
			var pv: Variant = ph.pose_of(int(L["wi"]), t)
			# ...one ground to pieces is drawn as its pieces, its pose no longer anywhere
			if pv == null or not ph.whole(int(L["wi"]), t):
				continue
			# ...what a loose thing's points are doing, its own surface aside
			if bool(L["soft"]) and args_soft_trace:
				_audit_soft_line(ph, L, t, worlds)
			# ...a sheet that bends, stretched past what it is: pulled apart
			if bool(L["soft"]) and ph.bend_of(int(L["wi"]), t) != null:
				var most_off := 0.0
				for o in (ph.bend_of(int(L["wi"]), t) as PackedVector3Array):
					most_off = maxf(most_off, o.length())
				if most_off > AUDIT_STRETCHED:
					note.call("%s pulled out of shape (cm)" % String(L["name"]), t, most_off * 100.0)
			# ...a sheet that bends, with a thin tool through it as it is drawn
			if bool(L["soft"]):
				_audit_through(w, ph, L, t, worlds, note)
			var lm := (pv as Transform3D) * (L["built"] as Transform3D).affine_inverse()
			var vs_i := -1
			# ...its middle from its own surface: its `box` is where it last came to rest, the bake being done
			var mid := Vector3.ZERO
			for q in (drawn[li] as PackedVector3Array):
				mid += q
			mid = lm * (mid / float((drawn[li] as PackedVector3Array).size()))
			for vi in ph.liquids.size():
				var sv: Dictionary = ph.solids[int((ph.liquids[vi] as Dictionary)["solid"])]
				var vx: Transform3D = worlds[int((ph.liquids[vi] as Dictionary)["solid"])]
				if ((ph.liquids[vi] as Dictionary)["vessel"] as Vessel).contains(vx.affine_inverse() * mid) and not (sv.has("body") and int(sv["body"]) == int(L["body"])):
					vs_i = vi
					break
			# ...a sheet that bends as it is drawn, its bend and all
			for q in (_audit_drawn_now(w, L, t) if bool(L["soft"]) else (drawn[li] as PackedVector3Array)):
				var w_p: Vector3 = q if bool(L["soft"]) else lm * q
				if w_p.y < -AUDIT_DEEP:
					note.call("%s through the table (mm)" % String(L["name"]), t, -w_p.y * 1000.0)
				if vs_i < 0:
					continue
				var vs: Vessel = (ph.liquids[vs_i] as Dictionary)["vessel"]
				var local: Vector3 = (worlds[int((ph.liquids[vs_i] as Dictionary)["solid"])] as Transform3D).affine_inverse() * w_p
				# ...out of the far side of the wall, what is seen from outside: in the wall itself it is hidden
				if local.y < vs.top_y and not vs.contains(local):
					var past := float(((ph.solids[int((ph.liquids[vs_i] as Dictionary)["solid"])] as Dictionary)["field"] as ShapeField).sample(local).x)
					if past > AUDIT_THROUGH:
						note.call("%s out through the wall of %s (mm)" % [String(L["name"]), ph._liquid_label(vs_i)], t, past * 1000.0)
		t += AUDIT_STEP
	# ...WHAT CAME OF WHAT EACH MOVE LEFT: how far it went on after its hand was done, by itself - fell, slid, tipped
	for key in keys:
		var ch: String = ph._ch_of(int(key))
		var entries: Array = w._chan.get(ch, [])
		for k in entries.size():
			var e: Dictionary = entries[k]
			var after := float(e["s1"]) + AUDIT_SETTLE
			if k + 1 < entries.size() and float((entries[k + 1] as Dictionary)["s0"]) < after + 0.1:
				continue
			if after >= t_to:
				continue
			var left: Variant = ph.pose_of(int(key), float(e["s1"]))
			var pv: Variant = ph.pose_of(int(key), after)
			if pv == null or left == null:
				continue
			var off_d := (pv as Transform3D).origin.distance_to((left as Transform3D).origin)
			var off_t := rad_to_deg(Quaternion((pv as Transform3D).basis.orthonormalized()).angle_to(Quaternion((left as Transform3D).basis.orthonormalized())))
			if off_d > 0.015 or off_t > 10.0:
				note.call("%s after %s goes on %.1f cm, %.0f deg by itself" % [label.call(key), String(e.get("act", "?")), off_d * 100.0, off_t], after, off_d * 100.0)
			# ...and where it came to, over nothing: its lowest points with nothing solid within AUDIT_FLOAT under them
			# ...(a stopper in its neck is held by its sides)
			var gap := _audit_float(w, ph, keys, int(key), after) if ((ph.rigid.bodies[int(ph._rigid_of[key])] as Dictionary).get("seat", PackedInt32Array()) as PackedInt32Array).is_empty() else 0.0
			if gap > AUDIT_FLOAT:
				note.call("%s after %s hangs in the air (cm)" % [label.call(key), String(e.get("act", "?"))], after, gap * 100.0)
	# ...AND WHAT HAS COME TO REST: over what is under it, by how much, and how it lies
	for key in keys:
		var bi := int(ph._rigid_of[key])
		var f: Dictionary = ph.frame_at(t_to - 0.1)
		if ph._frame_rank(f, bi) < 0:
			continue
		var m: Transform3D = pose_at.call(int(key), t_to - 0.1)
		if m.is_equal_approx(Transform3D.IDENTITY):
			continue
		var turned := rad_to_deg(Quaternion(m.basis.orthonormalized()).angle_to(Quaternion.IDENTITY))
		if turned > 15.0:
			note.call("%s ends the show turned from how it was built (deg)" % label.call(key), t_to, turned)
		if m.origin.length() > 0.02:
			note.call("%s ends the show away from where it was built (cm)" % label.call(key), t_to, m.origin.length() * 100.0)
	_audit_paint(w, ph, t_to, note)
	var said: Array = found.keys()
	said.sort_custom(func(a: String, b: String) -> bool: return float((found[a] as Dictionary)["t0"]) < float((found[b] as Dictionary)["t0"]))
	for what in said:
		var d: Dictionary = found[what]
		print("  AUDIT %7.2f - %7.2f  %s: %.1f at %.2f" % [float(d["t0"]), float(d["t1"]), what, float(d["worst"]), float(d["at"])])
	for tool in _through_n:
		print("  AUDIT %s stood through a sheet at %d of the moments looked at" % [tool, int(_through_n[tool])])
	print("  AUDIT %d kind(s) of thing said" % said.size())


## A PAINTING TOOL, LOOKED AT CLOSER THAN A BODY IS: its own mesh's points every [constant AUDIT_PAINT_STEP] of each act it paints in, against
## every solid that does not give ([constant AUDIT_GIVES]: the paint in a pot, water, powder, a towel) - deeper than [constant AUDIT_PAINT_DEEP],
## or than [constant AUDIT_PAINT_PRESS] in the surface it paints, where it is pressed. A body's own look ([constant AUDIT_DEEP]) said nothing of a
## sponge through a pot's tin wall 3 mm thick (feedback 0016, joker-motivation 209459).
const AUDIT_PAINT_STEP := 0.05
const AUDIT_PAINT_DEEP := 0.0008
const AUDIT_PAINT_PRESS := 0.0035
const AUDIT_PAINT_OFF := 0.0015
var _why_said := 0
const AUDIT_GIVES := ["cream", "powder", "liquid", "sponge", "fabric"]


func _audit_paint(w: TableWork, ph: TablePhysics, t_to: float, note: Callable) -> void:
	if w.paint == null:
		return
	for ch in w._chan:
		var cs := String(ch)
		if not cs.begins_with("w") or not cs.ends_with(":pose"):
			continue
		var entries: Array = (w._chan[ch] as Array).filter(func(e: Dictionary) -> bool: return String((e["track"] as Dictionary).get("law", "")) == "paint")
		if entries.is_empty():
			continue
		var wi := cs.substr(1).get_slice(":", 0).to_int()
		var pts := _audit_mesh_points((w.works[wi] as Dictionary)["node"], w, 500)
		if pts.is_empty():
			continue
		var own := AABB(pts[0], Vector3.ZERO)
		for q in pts:
			own = own.expand(q)
		# ...AND ON WHAT IT PAINTS WHILE IT PAINTS (feedback 0019: "This brush is not touching the mask; it is floating above it"): each
		# moment the law has it pressing on the surface, its tip as the bake has it no further off the surface than AUDIT_PAINT_OFF
		# (measured on the skin's own meshes along the tool, as the picture draws it - its field is coarse at a rim)
		var skin_tm: TriangleMesh = null
		for sd in w.paint.skins:
			var faces := PackedVector3Array()
			for m in (sd as Dictionary)["meshes"]:
				var mi := m as MeshInstance3D
				if mi.mesh != null:
					var to := w._world_of(mi)
					for v in mi.mesh.get_faces():
						faces.append(to * v)
			if not faces.is_empty():
				skin_tm = TableWork._ray_mesh(faces)
		var tool: Dictionary = w.paint.tools.get(cs, {})
		for e in entries:
			var t := float((e as Dictionary)["t0"])
			var t1 := minf(float((e as Dictionary)["t1"]), t_to)
			var tr: Dictionary = (e as Dictionary)["track"]
			var span := maxf(float(e["t1"]) - float(e["t0"]), 1e-3)
			var plan: Dictionary = w.paint._plan_entry(e, tr, span) if not tool.is_empty() else {}
			while t < t1:
				var pv: Variant = ph.pose_of(wi, t)
				t += AUDIT_PAINT_STEP
				if pv == null:
					continue
				var x: Transform3D = pv
				if skin_tm != null and not plan.is_empty():
					var tt := t - AUDIT_PAINT_STEP
					var h := TablePaint._hold_of(w.paint._held_at(plan, tr, clampf(tt - float(e["t0"]), 0.0, span), tt, e["from"],
						w._rest.get(cs, Transform3D.IDENTITY), w.paint._home_of(e, e["from"])), tool)
					if bool(h[3]) and float(h[2]) > 0.5:
						var c := TablePaint._contact(tool, TablePaint._contact_of(h))
						var tip_w := x * (c["tip"] as Vector3)
						# (straight in along the face's front, and how far off it that is along the surface's own normal there - along the
						# tool, a brush meeting a steep rim at a graze read a small gap as a long one)
						var skin_w := w.paint.holder_world(0, tt)
						var along: Vector3 = (skin_w.basis * ((w.paint.skins[0] as Dictionary)["surface"] as Dictionary)["front"]).normalized()
						var hit := TableWork._ray(skin_tm, tip_w + along * 0.05, -along)
						var hn: Vector3 = (hit["normal"] as Vector3).normalized() if not hit.is_empty() else along
						hn = hn if hn.dot(along) > 0.0 else -hn
						var off := 0.0 if hit.is_empty() else (tip_w - (hit["position"] as Vector3)).dot(hn)
						if hit.is_empty():
							note.call("%s past the edge of what it paints, pressing on it (mm along it)" % w._part_label(wi), tt, 30.0)
						elif off > AUDIT_PAINT_OFF:
							note.call("%s off what it paints, pressing on it (mm)" % w._part_label(wi), tt, off * 1000.0)
							if OS.get_environment("GHOST_AUDIT_WHY") != "" and off > 0.004 and _why_said < 16 and String(tool.get("kind", "")) == "brush":
								_why_said += 1
								var want: Vector3 = h[0]
								var hit2 := TableWork._ray(skin_tm, want + along * 0.05, -along)
								var want_off := (want - (hit2["position"] as Vector3)).dot(hn) if not hit2.is_empty() else 99.0
								print("  WHY %.2f %s: drawn tip %.1f mm off, the law's own tip %.1f mm off, drawn tip %.1f mm from the law's; contact %s, axis %s, press %.2f" % [
									tt, w._part_label(wi), off * 1000.0, want_off * 1000.0, tip_w.distance_to(want) * 1000.0, TablePaint._contact_of(h), h[1], float(h[2])])
				var reach := x * own
				for si in ph.solids.size():
					var sd: Dictionary = ph.solids[si]
					if int(sd["wi"]) == wi or not sd.has("field"):
						continue
					var part: Dictionary = sd["part"]
					if AUDIT_GIVES.has(String((w.materials.get(String(part.get("material", "")), {}) as Dictionary).get("kind", ""))):
						continue
					var xf: Transform3D = sd["rest"]
					var wb: AABB = xf * (sd["box"] as AABB)
					if not wb.intersects(reach):
						continue
					var allow := AUDIT_PAINT_PRESS if bool(part.get("skin", false)) else AUDIT_PAINT_DEEP
					var inv := xf.affine_inverse()
					var worst := 0.0
					for p in pts:
						var q := x * p
						if wb.grow(0.001).has_point(q):
							worst = maxf(worst, -float((sd["field"] as ShapeField).sample(inv * q).x))
					if worst > allow:
						note.call("%s in %s, painting (mm)" % [w._part_label(wi), ph._solid_label(si)], t - AUDIT_PAINT_STEP, worst * 1000.0)


## [param node]'s own meshes' points in its own space, at most [param most].
static func _audit_mesh_points(node: Node3D, w: TableWork, most: int) -> PackedVector3Array:
	var inv := w._world_of(node).affine_inverse()
	var all := PackedVector3Array()
	var seen := {}
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := inv * w._world_of(mi)
		for v in mi.mesh.get_faces():
			var q := xf * v
			var key := Vector3i(roundi(q.x * 2000.0), roundi(q.y * 2000.0), roundi(q.z * 2000.0))
			if not seen.has(key):
				seen[key] = true
				all.append(q)
	if all.size() <= most:
		return all
	var out := PackedVector3Array()
	for k in most:
		out.append(all[k * all.size() / most])
	return out


## Each loose thing's drawn surface as it lies as built, in the table's space, a couple of hundred points at most: {loose index: points}.
func _audit_loose_points(w: TableWork, ph: TablePhysics) -> Dictionary:
	var out := {}
	for li in ph.loose.size():
		var wi := int((ph.loose[li] as Dictionary)["wi"])
		var node: Node3D = (w.works[wi] as Dictionary)["node"]
		var stack: Array = [node]
		var pts := PackedVector3Array()
		var back := ((ph.loose[li] as Dictionary)["built"] as Transform3D) * w._world_of(node).affine_inverse()
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var xf := back * w._world_of(mi)
			var faces := mi.mesh.get_faces()
			for k in range(0, faces.size(), maxi(faces.size() / 200, 1)):
				pts.append(xf * faces[k])
		if pts.size() > 0 and pts.size() <= 600:
			out[li] = pts
	return out


## How far over what is under it body [param key] stands at [param t] (meters): its dozen lowest points, each looked under, the least - or 0 where one touches.
func _audit_float(w: TableWork, ph: TablePhysics, keys: Array, key: int, t: float) -> float:
	var f: Variant = ph.frame_at(t)
	var bi := int(ph._rigid_of[key])
	var pv: Variant = ph.pose_of(key, t)
	if pv == null or f == null:
		return 0.0
	var m := (pv as Transform3D) * ph._rest_of(key).affine_inverse()
	var worlds := {}
	for other in keys:
		var obi := int(ph._rigid_of[other])
		if ph._frame_rank(f as Dictionary, obi) >= 0:
			worlds[obi] = (ph.pose_of(int(other), t) as Transform3D) * ph._rest_of(int(other)).affine_inverse()
	var b: Dictionary = ph.rigid.bodies[bi]
	var own: PackedInt32Array = b["solids"]
	var ys: Array = []
	for q in (b["pts"] as PackedVector3Array):
		ys.append(m * q)
	ys.sort_custom(func(a: Vector3, c: Vector3) -> bool: return a.y < c.y)
	var least := INF
	for k in mini(12, ys.size()):
		var p: Vector3 = ys[k]
		var d := 0.0
		while d <= AUDIT_FLOAT * 3.0:
			var q := p + Vector3.DOWN * d
			var hit := q.y <= 0.0
			if not hit:
				for si in ph.solids.size():
					if own.has(si):
						continue
					var sd: Dictionary = ph.solids[si]
					var xf: Transform3D = sd["rest"]
					if sd.has("body") and worlds.has(int(sd["body"])):
						xf = (worlds[int(sd["body"])] as Transform3D) * xf
					if (xf * (sd["box"] as AABB)).grow(0.001).has_point(q) and float((sd["field"] as ShapeField).sample(xf.affine_inverse() * q).x) < 0.0:
						hit = true
						break
			if hit:
				break
			d += 0.002
		least = minf(least, d)
	return least if least != INF else 0.0


## SHEET [param L] at [param t], each thin tool's axis against what is drawn of it - where a tool is near it - said through [param note].
func _audit_through(w: TableWork, ph: TablePhysics, L: Dictionary, t: float, worlds: Dictionary, note: Callable) -> void:
	var wi := int(L["wi"])
	var motion := (ph.pose_of(wi, t) as Transform3D) * (L["built"] as Transform3D).affine_inverse()
	var box: AABB = motion * (L["box_built"] as AABB) if L.has("box_built") else AABB(motion * ph.sheet_points(wi)[0], Vector3.ZERO).grow(0.2)
	var segs: Array = []
	for si in ph.solids.size():
		var sd: Dictionary = ph.solids[si]
		if not bool(sd.get("thin", false)) or int(sd["thing"]) == int(L["thing"]):
			continue
		var xf: Transform3D = worlds[si]
		if not (xf * (sd["box"] as AABB)).grow(0.01).intersects(box):
			continue
		var f: ShapeField = sd["field"]
		for k in f.caps_a.size():
			segs.append([xf * f.caps_a[k], xf * f.caps_b[k], ph._solid_label(si)])
	if segs.is_empty():
		return
	w.tick(t)
	var stack: Array = [(w.works[wi] as Dictionary)["node"]]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf := w._world_of(mi)
		var faces := mi.mesh.get_faces()
		for sg in segs:
			var a: Vector3 = (sg as Array)[0]
			var b: Vector3 = (sg as Array)[1]
			for k in range(0, faces.size() - 2, 3):
				if Geometry3D.segment_intersects_triangle(a, b, xf * faces[k], xf * faces[k + 1], xf * faces[k + 2]) != null:
					note.call("%s stands through %s (moments)" % [String((sg as Array)[2]), String(L["name"])], t, 1.0)
					_through_n[String((sg as Array)[2])] = int(_through_n.get(String((sg as Array)[2]), 0)) + 1
					break


## `--soft-trace`, with `--audit`: sheet [param L] at [param t] - where its middle is, how far its points spread, what the deepest of them is doing against the vessel holding it.
func _audit_soft_line(ph: TablePhysics, L: Dictionary, t: float, worlds: Dictionary) -> void:
	var wi := int(L["wi"])
	var motion := (ph.pose_of(wi, t) as Transform3D) * (L["built"] as Transform3D).affine_inverse()
	var off: Variant = ph.bend_of(wi, t)
	var pts: PackedVector3Array = L["spheres"]
	var mid := Vector3.ZERO
	var most := 0.0
	var world := PackedVector3Array()
	for k in pts.size():
		var o: Vector3 = (off as PackedVector3Array)[k] if off != null else Vector3.ZERO
		most = maxf(most, o.length())
		world.append(motion * (pts[k] + o))
		mid += world[k]
	mid /= float(pts.size())
	var bits := PackedStringArray()
	for vi in ph.liquids.size():
		var LQ: Dictionary = ph.liquids[vi]
		var vs: Vessel = LQ["vessel"]
		var inv: Transform3D = (worlds[int(LQ["solid"])] as Transform3D).affine_inverse()
		var inn := 0
		var inwall := 0
		var out := 0
		for p in world:
			var q := inv * p
			if q.y < vs.floor_y - 0.02 or q.y > vs.top_y + 0.02 or Vector2(q.x, q.z).length() > 0.3:
				continue
			if vs.contains(q):
				inn += 1
			elif q.y < vs.top_y:
				if float((ph.solids[int(LQ["solid"])] as Dictionary)["field"].sample(q).x) < 0.0:
					inwall += 1
				else:
					out += 1
		if inn + inwall + out > 0:
			bits.append("%s %d in, %d in its wall, %d out" % [ph._liquid_label(vi).get_slice("'s ", 1), inn, inwall, out])
	print("  SOFT %7.2f %s mid (%.1f, %.1f, %.1f) bent %.1f mm: %s" % [t, String(L["name"]).left(16), mid.x * 100.0, mid.y * 100.0, mid.z * 100.0, most * 1000.0, ", ".join(bits)])


## What sheet [param L] draws at [param t] (the table's space): a couple of hundred of its mesh's points, as the work poses it.
func _audit_drawn_now(w: TableWork, L: Dictionary, t: float) -> PackedVector3Array:
	w.tick(t)
	var out := PackedVector3Array()
	var stack: Array = [(w.works[int(L["wi"])] as Dictionary)["node"]]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf := w._world_of(mi)
		var faces := mi.mesh.get_faces()
		for k in range(0, faces.size(), maxi(faces.size() / 200, 1)):
			out.append(xf * faces[k])
	return out
