extends Node

## WORK AS A LIVE READING'S WORDS ARRIVE (a probe, for looking): a real episode's work played twice through
## [method TableMedium.advance] - once with every word's time known from the first frame (an export: the take's
## sidecar), once with the words arriving a sentence at a time a few seconds before they are said (the live
## window) - at a voice slower than the plan's estimate. It prints when each act ran in each, and the largest
## jumps of anything the work moves from one frame to the next.
##
##   tests/run_boot_probe.sh tests/table/work_arrival_probe.gd 900 --show the-quiet-crucible --seed 181083
##
## `--word S` a word's length (0.5), `--rest S` the rest after a sentence (0.6), `--ahead S` how long before a
## sentence is said its words arrive (4), `--dt S` the frame (1/30).

const DT_DEFAULT := 1.0 / 30.0

var _show := "the-quiet-crucible"
var _seed := 181083
var _word := 0.5
var _rest := 0.6
var _ahead := 4.0
var _dt := DT_DEFAULT
var _watch := ""
var _trace := ""
var _trace_at := Vector2.ZERO
var _whole_only := false


func _ready() -> void:
	_run.call_deferred()


## The voice's words: each `_word` long, a rest after each sentence and the actions' time where they fall.
func _timeline(parse: Dictionary) -> Array:
	var rests := {}
	for a in parse["actions"]:
		var k := int((a as Dictionary)["after"])
		rests[k] = float(rests.get(k, 0.0)) + float((a as Dictionary)["dur"]) + 0.5
	# where each sentence ends, from the passages' words as the parse counted them ([method CardReading.parse])
	var ends := []
	for p in parse["passages"]:
		for w in String((p as Dictionary)["text"]).split(" ", false):
			for piece in String(w).split("\n", false):
				if not TabletScript.norm(piece).is_empty():
					var raw := String(piece).strip_edges().trim_suffix("*").trim_suffix("\"")
					ends.append(raw.ends_with(".") or raw.ends_with("?") or raw.ends_with("!"))
	var out: Array = []
	var t := Director.intro_hold
	var sentence := 0
	var spoken: PackedStringArray = parse["spoken"]
	for i in spoken.size():
		if rests.has(i):
			t += float(rests[i])
			sentence += 1
		out.append({"text": spoken[i], "t0": t, "t1": t + _word * 0.85, "sentence": sentence})
		t += _word
		if i < ends.size() and bool(ends[i]):
			t += _rest
			sentence += 1
	return out


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--show": _show = args[i + 1]
			"--seed": _seed = int(args[i + 1])
			"--word": _word = float(args[i + 1])
			"--rest": _rest = float(args[i + 1])
			"--ahead": _ahead = float(args[i + 1])
			"--dt": _dt = float(args[i + 1])
			"--watch": _watch = args[i + 1]
			"--trace":
				# --trace "pestle@379.5,380.5": where that part is every frame between
				var bits := String(args[i + 1]).split("@")
				_trace = bits[0]
				var ab := bits[1].split(",")
				_trace_at = Vector2(float(ab[0]), float(ab[1]))
			"--whole-only": _whole_only = args[i + 1] == "1"
	var ep := TableEpisode.open(_show, _seed)
	var script := ep.script()
	if script.is_empty():
		print("work_arrival_probe: no script in %s" % ep.dir)
		get_tree().quit(2)
		return
	var parse := CardReading.parse(script)
	var words := _timeline(parse)
	var end := float((words.back() as Dictionary)["t1"]) + 4.0
	var whole := await _play(ep, script, words, end, false)
	if _whole_only:
		get_tree().quit(0)
		return
	var live := await _play(ep, script, words, end, true)
	print("work_arrival_probe: %d words over %.0f s (the plan's estimate puts the last at %.0f s)" % [words.size(), end, float(whole["est_last"])])
	print("\nwork_arrival_probe: when each act ran        known up front      as the words arrived")
	for name in whole["runs"]:
		var a: Vector2 = whole["runs"][name]
		var b: Vector2 = live["runs"].get(name, Vector2(INF, INF))
		print("  %-26s %7.1f - %-7.1f   %7.1f - %-7.1f %s" % [name, a.x, a.y, b.x, b.y,
			"" if absf(a.x - b.x) < 0.05 and absf(a.y - b.y) < 0.05 else ("  <- %+.1f s, %.2fx as long" % [b.x - a.x, (b.y - b.x) / maxf(a.y - a.x, 1e-3)])])
	for m in [whole, live]:
		print("\nwork_arrival_probe: %s - the largest jumps in a frame (cm):" % m["label"])
		for j in m["jumps"]:
			print("  %6.1f cm  %6.1f deg at %6.1f s  %s" % [float(j[0]) * 100.0, rad_to_deg(float(j[1])), float(j[2]), String(j[3])])
		print("  same part's acts overlapping: %s" % str(m["overlaps"]))
	get_tree().quit(0)


## One play through: the medium advanced frame by frame, the words all there or arriving [member _ahead] before
## their sentence is said. Returns {label, runs: {name: Vector2}, jumps: [[m, rad, t, name]], overlaps}.
func _play(ep: TableEpisode, script: String, words: Array, end: float, arriving: bool) -> Dictionary:
	var stage := SubViewport.new()
	stage.size = Vector2i(320, 180)
	stage.own_world_3d = true
	add_child(stage)
	Director.detach()
	var medium := Medium.make("table") as TableMedium
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	var subs: Subtitles = preload("res://src/show/subtitles.gd").new()
	var heard: Array = []
	subs.words = heard if arriving else words.duplicate(true)
	subs.document = {"source": script, "title": "probe", "table": ep.document()}
	add_child(subs)
	medium.bind_captions(subs)
	var t := 0.0
	var next := 0
	var last := {}
	var jumps: Array = []
	Spectrum.virtual_clock = 0.0
	var step := 0
	var watched := {}
	var next_watch := 1.0
	while t < end:
		t += _dt
		if arriving:
			# a sentence's words come together, [member _ahead] before its first is said
			while next < words.size() and float((words[next] as Dictionary)["t0"]) - _ahead <= t:
				var s := int((words[next] as Dictionary)["sentence"])
				while next < words.size() and int((words[next] as Dictionary)["sentence"]) == s:
					heard.append((words[next] as Dictionary).duplicate())
					next += 1
		Spectrum.virtual_clock = t
		Spectrum.current.time = t
		subs._process(_dt)
		medium.advance(Spectrum.current, _dt, 1.0)
		var w := medium._work
		for ti in w.things.size():
			var th: Dictionary = w.things[ti]
			if not w._moved.has("t%d:pose" % ti):
				continue
			_jump(last, jumps, "thing " + String(th["name"]), (th["node"] as Node3D).global_transform, t)
		for wi in w.works.size():
			var wk: Dictionary = w.works[wi]
			if wk.get("node") is Node3D:
				_jump(last, jumps, "part " + String(wk["name"]) + " of " + String((w.things[int(wk["thing"])] as Dictionary)["name"]), (wk["node"] as Node3D).global_transform, t)
		if not _trace.is_empty() and t >= _trace_at.x and t <= _trace_at.y and not arriving:
			for wi in w.works.size():
				var wk: Dictionary = w.works[wi]
				if String(wk["name"]) == _trace and wk.get("node") is Node3D:
					var x: Transform3D = (wk["node"] as Node3D).global_transform
					print("work_arrival_probe: %s at %.3f s: (%.4f, %.4f, %.4f) up (%.2f, %.2f, %.2f)" % [_trace, t, x.origin.x, x.origin.y, x.origin.z,
						x.basis.y.normalized().x, x.basis.y.normalized().y, x.basis.y.normalized().z])
		if _trace == "streams" and t >= _trace_at.x and t <= _trace_at.y and not arriving and fmod(t, 0.5) < _dt:
			for st in w._streams:
				var lip: Dictionary = (st as Dictionary)["lip"]
				var at: Array = w._lip_at(lip, t)
				var tr: Dictionary = (st as Dictionary)["track"]
				var iw: Dictionary = (w.works[int(tr["_into"])] as Dictionary)["w"]
				var base: Vector3 = iw.get("base", Vector3.ZERO)
				var surf: float = (w._world_of((w.works[int(tr["_into"])] as Dictionary)["node"]) * Vector3(base.x, (iw["box"] as AABB).end.y, base.z)).y
				print("work_arrival_probe: stream of %s at %.2f s: lip (%.3f, %.3f, %.3f) way %s, surface %.3f, shown %s" % [String(tr["from"]), t,
					(at[0] as Vector3).x, (at[0] as Vector3).y, (at[0] as Vector3).z, str(at[1]), surf, str(((st as Dictionary)["node"] as Node3D).visible)])
		if not _watch.is_empty() and t >= next_watch and not arriving:
			next_watch += 60.0
			for wi in w.works.size():
				var wk: Dictionary = w.works[wi]
				if String(wk["name"]).contains(_watch) and wk.get("node") is Node3D:
					var b := (wk["node"] as Node3D).global_transform.basis.orthonormalized()
					if not watched.has(wi):
						watched[wi] = b
					print("work_arrival_probe: %s at %5.0f s: %.1f deg from where it was at 1 s" % [String(wk["name"]), t,
						rad_to_deg(Quaternion(watched[wi] as Basis).angle_to(Quaternion(b)))])
		step += 1
		if step % 200 == 0:
			await get_tree().process_frame
	jumps.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	var runs := {}
	for r in medium._work.runs:
		runs[String((medium._work.acts[int((r as Dictionary)["i"])] as Dictionary)["name"])] = Vector2(float(r["t0"]), float(r["t1"]))
	var overlaps: Array = []
	for ch in medium._work._chan:
		var list: Array = medium._work._chan[ch]
		for k in range(1, list.size()):
			var p: Dictionary = list[k - 1]
			var e: Dictionary = list[k]
			if int(p["i"]) != int(e["i"]) and float(e["s0"]) < float(p["s1"]) - 0.01:
				overlaps.append("%s: %s over %s by %.1f s" % [ch, String((medium._work.acts[int(e["i"])] as Dictionary)["name"]),
					String((medium._work.acts[int(p["i"])] as Dictionary)["name"]), float(p["s1"]) - float(e["s0"])])
	var out := {"label": "as the words arrived" if arriving else "known up front", "runs": runs, "jumps": jumps.slice(0, 12), "overlaps": overlaps,
		"est_last": medium._est[medium._est.size() - 1] if not medium._est.is_empty() else 0.0}
	Director.hold(false)
	Director.detach()
	subs.queue_free()
	stage.queue_free()
	Spectrum.virtual_clock = -1.0
	for _i in 3:
		await get_tree().process_frame
	return out


## Where [param name] went since the last frame: its move kept when it is among the largest.
func _jump(last: Dictionary, jumps: Array, name: String, x: Transform3D, t: float) -> void:
	if last.has(name):
		var p: Transform3D = last[name]
		var d := p.origin.distance_to(x.origin)
		var q := Quaternion(p.basis.orthonormalized()).angle_to(Quaternion(x.basis.orthonormalized()))
		if d > 0.01 or q > 0.15:
			jumps.append([d, q, t, name])
	last[name] = x
