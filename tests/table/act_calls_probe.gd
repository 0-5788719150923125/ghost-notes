extends Node

## THE PUPPETEER'S CALLS REPLAYED (next/framework_audit.md): an episode's `jobs/acts/tools.jsonl` - every `parts`, `act`,
## `remove` (and with `--watch`, `watch`) its puppeteer made - played again, in order, through the real [PuppeteerTools] on a
## COPY of the episode's folder, each call timed and the bake's restart said: how long a call took, where its bake began again
## and how far it baked. What a puppeteer waits on, measured on the run it waited through - the benchmark for a tool's speed.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table/act_calls_probe.gd 7200 --show=the-quiet-crucible --seed=841899 \
##       [--calls=<a tools.jsonl>] [--first=N] [--last=N] [--watch] [--copy=<dir>]
##
## `--calls` defaults to the episode's own `jobs/acts/tools.jsonl`; `--first`/`--last` replay a stretch of them (the calls
## before `--first` replayed too, untimed, so the draft is the one the puppeteer had). It needs a renderer, as the tools do.
##
## READ-ONLY: the episode is copied to `--copy` (by default the project's `dist/act_calls_probe/`, a real disk Godot never
## imports) and the copy's folder is the episodes' root for the run; nothing of the author's is written.

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
	var show := _arg(args, "show", "the-quiet-crucible")
	var seed_value := _arg(args, "seed", "841899").to_int()
	var src := TableEpisode.open(show, seed_value)
	if not DirAccess.dir_exists_absolute(src.dir):
		print("act_calls_probe: no episode at %s" % src.dir)
		get_tree().quit(2)
		return
	var calls_path := _arg(args, "calls", src.dir.path_join("jobs/acts/tools.jsonl"))
	if not FileAccess.file_exists(calls_path):
		print("act_calls_probe: no calls at %s" % calls_path)
		get_tree().quit(2)
		return
	var calls: Array = []
	for line in FileAccess.get_file_as_string(calls_path).split("\n", false):
		var j := JSON.new()
		if j.parse(line) == OK and j.data is Dictionary:
			calls.append(j.data)
	# ...a copy of the episode, as the episodes' root for the run
	var copy_root := _arg(args, "copy", ProjectSettings.globalize_path("res://dist/act_calls_probe"))
	var copy_dir := copy_root.path_join(show).path_join(str(seed_value))
	_copy_dir(src.dir, copy_dir)
	TableEpisode.root = copy_root
	var ep := TableEpisode.open(show, seed_value)
	var plan: Variant = ep.read_json("plan")
	var table: Variant = ep.read_json("table")
	var job := ep.job_dir("acts").path_join("replay")
	DirAccess.make_dir_recursive_absolute(job)
	var tools := PuppeteerTools.new(ep, plan if plan is Dictionary else {}, job, table if table is Dictionary else {})
	var first := _arg(args, "first", "0").to_int()
	var last := _arg(args, "last", str(calls.size() - 1)).to_int()
	var watch := _arg(args, "watch", "") != ""
	print("act_calls_probe: %d calls from %s, replaying %d-%d on %s" % [calls.size(), calls_path, first, last, copy_dir])
	var total := 0.0
	var timed := 0.0
	for i in calls.size():
		if i > last:
			break
		var c: Dictionary = calls[i]
		var tool := String(c.get("tool", ""))
		if tool == "submit" or (tool == "watch" and not watch):
			continue
		var started := Time.get_ticks_msec()
		var out: Dictionary = await tools.call_tool(tool, c.get("args", {}))
		var took := float(Time.get_ticks_msec() - started) / 1000.0
		total += took
		if i < first:
			continue
		timed += took
		var ph: TablePhysics = null
		var pv: TablePreview = tools._preview
		if pv != null and pv._medium != null and is_instance_valid(pv._medium) and pv._medium._work != null:
			ph = pv._medium._work.physics
		var names := PackedStringArray()
		for a in (c.get("args", {}) as Dictionary).get("acts", []):
			names.append(String((a as Dictionary).get("name", "")))
		print("call %2d %-7s %6.1f s  resumed at %7.1f s, baked to %7.1f s  %s%s" % [i, tool, took,
			ph.resumed_at if ph != null else -1.0, ph.baked_to() if ph != null else -1.0, ",".join(names),
			("  (stood %.1f s, baked %.1f s, checked %.1f s)" % [int(pv.timing.get("stand", 0)) / 1000.0, int(pv.timing.get("bake", 0)) / 1000.0,
				int(pv.timing.get("checks", 0)) / 1000.0]) if tool == "act" and pv != null and not pv.timing.is_empty() else ""])
		var text := String(out.get("text", ""))
		for l in text.split("\n"):
			if l.contains("HELD BACK") or l.contains("PASSES THROUGH") or l.contains("SPILLED") or l.contains("let go") or l.contains("poured") \
					or l.contains("could not") or l.contains("HANGS") or l.contains("MISSED") or l.contains("set down"):
				print("    " + l.strip_edges().left(260))
	print("act_calls_probe: %.1f s for the calls replayed (%.1f s in all)" % [timed, total])
	tools.release()
	get_tree().quit(0)


func _copy_dir(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for f in DirAccess.get_files_at(from):
		DirAccess.copy_absolute(from.path_join(f), to.path_join(f))
	for d in DirAccess.get_directories_at(from):
		if String(d) == "jobs":
			continue
		_copy_dir(from.path_join(d), to.path_join(d))
	DirAccess.make_dir_recursive_absolute(to.path_join("jobs"))
