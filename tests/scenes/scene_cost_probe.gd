extends Node

## What one frame of each catalog scene costs in script (next/csharp.md, next/compute.md step 1): every
## roster scene once at 1920x1080 on the dummy renderer, so only GDScript and the canvas taking its
## arrays are in it. A probe, for looking.
##
##   tests/run_boot_probe.sh tests/scenes/scene_cost_probe.gd 600 [how many scenes]
##
## Processor time, never the wall's: `main` is this thread's cost per frame, split into `update` and the
## rest (`_draw`); `all threads` is every thread's, for a scene that uses the worker pool itself. An
## empty frame is taken off. The forge builds in `_draw`, as an export does ([FrameForge]), so the figure
## is the build's whole cost (live, the build is on a worker).

const WARM := 10
const TIMED := 30


func _ready() -> void:
	_run.call_deferred()


func _ns_of(path: String) -> float:
	# a /proc file has no length to read by: a line is asked for
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0.0
	return float(f.get_line().get_slice(" ", 0))


func _main_ns() -> float:
	return _ns_of("/proc/thread-self/schedstat")


func _all_ns() -> float:
	var total := 0.0
	for tid in DirAccess.get_directories_at("/proc/self/task"):
		total += _ns_of("/proc/self/task/%s/schedstat" % tid)
	return total


func _features(i: int) -> AudioFeatures:
	var f := AudioFeatures.new()
	f.time = float(i) / 30.0
	var k := i % 24
	var loud := 0.85 if k >= 18 else 0.45
	var bands := PackedFloat32Array()
	bands.resize(Spectrum.BAND_COUNT)
	for b in Spectrum.BAND_COUNT:
		var t := float(b) / float(maxi(1, Spectrum.BAND_COUNT - 1))
		bands[b] = clampf(loud * (1.0 - 0.6 * t) * (0.6 + 0.4 * sin(t * 9.0 + f.time * 3.0)), 0.0, 1.0)
	f.bands = bands
	f.energy = loud
	f.bass = loud * 0.9
	f.low_mid = loud * 0.7
	f.mid = loud * 0.6
	f.high = loud * 0.4
	f.treble = loud * 0.3
	f.beat = 1.0 if k == 18 or k == 22 else 0.0
	f.flux = 0.4 if k == 18 else 0.02
	f.movement = 0.8 if k == 18 else 0.1
	f.beat_period = 0.5
	return f


func _run() -> void:
	# (the forge's own switch for an export, set here: `--export` among the arguments would ask more of the autoloads)
	FrameForge._sync_known = true
	FrameForge._sync = true
	var args := OS.get_cmdline_user_args()
	var most := int(args[0]) if args.size() > 0 and String(args[0]).is_valid_int() else 9999
	# an empty canvas item, for what a frame costs with no scene in it
	var empty := Node2D.new()
	add_child(empty)
	for i in 10:
		empty.queue_redraw()
		await get_tree().process_frame
	var b0 := _main_ns()
	for i in 60:
		empty.queue_redraw()
		await get_tree().process_frame
	var base_ms := (_main_ns() - b0) / 1e6 / 60.0
	empty.queue_free()
	print("cost: an empty frame %.3f ms of this thread" % base_ms)
	var seen := {}
	var done := 0
	for e in SceneRoster.SCENES:
		var script: Script = e["script"]
		var path := String(script.resource_path)
		if seen.has(path):
			continue
		seen[path] = true
		if done >= most:
			break
		done += 1
		var sc = script.new()
		add_child(sc)
		var t_build := _main_ns()
		sc.init_with_seed(7, String(e.get("behavior", "drift")))
		sc.size = Vector2(1920, 1080)
		var build_ms := (_main_ns() - t_build) / 1e6
		var n := 0
		for i in WARM:
			sc.update(_features(i), 1.0 / 30.0)
			sc.queue_redraw()
			await get_tree().process_frame
		var m0 := _main_ns()
		var a0 := _all_ns()
		var upd := 0.0
		for i in TIMED:
			var u0 := _main_ns()
			sc.update(_features(WARM + i), 1.0 / 30.0)
			upd += _main_ns() - u0
			sc.queue_redraw()
			await get_tree().process_frame
			n += 1
			if sc.lifecycle == "oneshot" and sc.finished():
				break
		var main_ms := (_main_ns() - m0) / 1e6 / float(n) - base_ms
		var all_ms := (_all_ns() - a0) / 1e6 / float(n) - base_ms
		print("cost %-18s %-9s main %7.2f ms  (update %6.2f, draw %6.2f)  all threads %7.2f ms  build %6.0f ms  frames %d"
			% [path.get_file().get_basename(), String(sc.render_kind), main_ms, upd / 1e6 / float(n),
			main_ms - upd / 1e6 / float(n), all_ms, build_ms, n])
		sc.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	print("cost: done, %d scenes" % done)
	for _i in 6:
		await get_tree().process_frame
	get_tree().quit(0)
