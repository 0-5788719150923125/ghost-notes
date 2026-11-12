extends Node

## Smoke gate for the whole scene catalog: build, update, draw, free, every entry.
##
## Per entry, at several seeds:
##   build_params  - the seeded definition, including every branch a seed can take
##   update        - a fixed number of frames against synthetic audio features that sweep silence, a
##                   steady middle and a loud transient (scenes branch on all three)
##   _draw         - forced, since projection, polygon winding and color construction only run there
##   free          - a scene that leaks a thread or a job shows up as a hang, not an error
##
## Run inside a real boot, because scenes touch the Spectrum and Director autoloads:
##   tests/run_boot_probe.sh tests/scenes/scene_smoke.gd 300
##
## Exit status is non-zero if any entry failed.

const SEEDS := [1, 7, 999983]
const FRAMES := 24
## Frames after which a real redraw is forced (a draw costs a yielded engine frame), spread so an early,
## a settled and a post-transient state are all rendered.
const DRAW_AT := [4, 13, 23]

var _fails: Array = []
var _checked := 0
var _drawn := 0


func _ready() -> void:
	# The engine must own the draw call (see _run_one), so this is a coroutine.
	_run.call_deferred()


func _run() -> void:
	var entries: Array = SceneRoster.SCENES
	print("scene_smoke: %d registry entries x %d seeds x %d frames"
		% [entries.size(), SEEDS.size(), FRAMES])
	var by_script := {}
	for e in entries:
		var path := String((e["script"] as Script).resource_path)
		by_script[path] = true
		for sv in SEEDS:
			await _run_one(path, e["script"], String(e.get("behavior", "drift")), int(sv))
	print("scene_smoke: %d distinct scripts, %d instantiations, %d rendered frames"
		% [by_script.size(), _checked, _drawn])
	if _fails.is_empty():
		print("scene_smoke: ALL OK")
	else:
		print("scene_smoke: %d FAILURE(S)" % _fails.size())
		for f in _fails:
			print("   ", f)
	# Settle before quitting: freeing many Node2Ds hands the RenderingServer that many canvas items to
	# retire, and quitting in the same frame as the last free tears the server down mid-drain (a fatal
	# out-of-bounds inside the engine rather than our verdict). These frames make the exit status
	# trustworthy.
	for _i in 6:
		await get_tree().process_frame
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _run_one(path: String, script: Script, behavior: String, sv: int) -> void:
	_checked += 1
	var short := path.get_file().get_basename()
	var sc = script.new()
	if sc == null:
		_fails.append("%s: script.new() returned null" % short)
		return
	# Parented before init: a scene may reach for the viewport size in build_params (framing = "field"
	# sizes off it) and an orphan reports zero.
	add_child(sc)
	sc.init_with_seed(sv, behavior)
	sc.size = Vector2(1920, 1080)
	for i in FRAMES:
		sc.update(_features(i), 1.0 / 30.0)
		if DRAW_AT.has(i):
	# The engine must make this call: Godot rejects draw_* issued from anywhere but a real
	# NOTIFICATION_DRAW, so calling sc._draw() directly refuses every draw command. Marking it
	# dirty and yielding a frame renders it.
			sc.queue_redraw()
			await get_tree().process_frame
			_drawn += 1
		if sc.lifecycle == "oneshot" and sc.finished():
			break
	# Tear down as the Director does (queue_free, then let the frame end) and wait for that frame:
	#   without the yield, nothing is collected and every instantiation stays alive, which hangs the run;
	#   without the deferral, an immediate free() can pull a scene out from under a FrameForge job still
	#   building on a worker, which segfaults at exit.
	sc.queue_free()
	await get_tree().process_frame


## A synthetic frame that sweeps the three regimes scenes branch on: frames 0-5 silence (a scene must not
## divide by a zero energy), 6-17 a steady middle, 18+ a hard beat and high flux (activation gates and
## cut triggers fire).
func _features(i: int) -> AudioFeatures:
	var f := AudioFeatures.new()
	f.time = float(i) / 30.0
	var loud := 0.0
	if i >= 18:
		loud = 0.85
	elif i >= 6:
		loud = 0.35
	var bands := PackedFloat32Array()
	bands.resize(Spectrum.BAND_COUNT)
	for b in Spectrum.BAND_COUNT:
	# a tilted spectrum with a moving peak, so per-band code sees structure
		var t := float(b) / float(maxi(1, Spectrum.BAND_COUNT - 1))
		bands[b] = clampf(loud * (1.0 - 0.6 * t) * (0.6 + 0.4 * sin(t * 9.0 + f.time * 3.0)), 0.0, 1.0)
	f.bands = bands
	f.energy = loud
	f.bass = loud * 0.9
	f.low_mid = loud * 0.7
	f.mid = loud * 0.6
	f.high = loud * 0.4
	f.treble = loud * 0.3
	f.beat = 1.0 if i == 18 or i == 22 else 0.0
	f.flux = 0.4 if i == 18 else 0.02
	f.movement = 0.8 if i == 18 else 0.1
	f.beat_period = 0.5
	return f
