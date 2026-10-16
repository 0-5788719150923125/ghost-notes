extends SceneTree

## A part a show mounts is played by the time it is HANDED:
##   godot --headless --path . --script tests/scene_kit/feed_clock_check.gd
##
## WHAT IT HOLDS (next/structure.md, step 11). A scene, a medium and the table read the show's
## clock and the music's signature from their `feed` ([ShowFeed]), never off the audio engine -
## so a show whose time is not a song's (a preview a timeline scrubs, a live show its agents
## conduct) plays them by answering the feed, and they cannot tell. `docs.py --check` holds the
## names (HANDED); this holds the behavior, on one medium and one scene:
##
## - The tablet fades in over its first 1.2 s of show time. Handed 0.6 s, it is half up - with the
##   session clock wound to 100 s, where a medium that read it would be fully up.
## - A scene's tonal color is the signature's chroma on the color wheel ([method
##   GhostScene.chroma_hue]). Handed a signature that is all E, its hue is E's (4/12).
##
## THE CONTROLS: the same medium handed 0 s is dark, and a scene handed nothing has no hue - so
## the two readings above come from what was handed. And A CHECK THAT NEVER FINISHED FAILS: the
## parts are loaded by path once the autoloads exist (a medium that named one would otherwise fail
## to compile, abort the check and leave nothing to fail it), and each check counts itself done.

class PinnedFeed extends ShowFeed:
	var t := 0.0
	var sig := PackedFloat32Array()

	func show_time() -> float:
		return t

	func signature() -> PackedFloat32Array:
		return sig


var _fails: Array = []
var _done := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# THE AUTOLOADS FIRST: the session clock is wound far from what the feed hands
	await process_frame
	var spectrum: Node = root.get_node_or_null("Spectrum")
	if spectrum == null:
		_fails.append("no Spectrum autoload - the clock this gate winds away is missing")
	else:
		spectrum.get("current").set("time", 100.0)
	_check_medium(0.6, 0.5, "handed 0.6 s")
	_check_medium(0.0, 0.0, "control: handed 0 s")
	_check_scene()
	if _done != 3:
		_fails.append("%d of 3 checks finished - a part failed to load or run (read the errors above)" % _done)
	for f in _fails:
		printerr("FAIL: ", f)
	print("feed_clock_check: %s" % ("ALL OK" if _fails.is_empty() else "%d FAILED" % _fails.size()))
	quit(0 if _fails.is_empty() else 1)


func _check_medium(t: float, want: float, what: String) -> void:
	var feed := PinnedFeed.new()
	feed.t = t
	root.add_child(feed)
	var st := SubViewport.new()
	root.add_child(st)
	var tablet: Node = load("res://src/media/tablet.gd").new()
	tablet.feed = feed
	tablet.mount(st)
	tablet.advance(null, 1.0 / 60.0, 1.0)
	var got := float((tablet.get("_env") as Environment).adjustment_brightness)
	if absf(got - want) > 0.02:
		_fails.append("tablet, %s: brightness %.3f, want %.3f - it is not reading the feed's clock" % [what, got, want])
	st.queue_free()
	feed.queue_free()
	_done += 1


func _check_scene() -> void:
	var feed := PinnedFeed.new()
	var sig := PackedFloat32Array()
	sig.resize(12)
	sig[4] = 1.0
	feed.sig = sig
	root.add_child(feed)
	var scene: Node = load("res://src/scene_kit/ghost_scene.gd").new()
	scene.feed = feed
	var hue: Vector2 = scene.chroma_hue()
	if absf(hue.x - 4.0 / 12.0) > 0.01 or hue.y <= 0.5:
		_fails.append("a scene handed an E signature has hue %s, want (0.333, >0.5)" % hue)
	# the control: handed no show, no color
	scene.feed = null
	if scene.chroma_hue() != Vector2.ZERO:
		_fails.append("control: a scene with no feed still has a hue - it reads the music elsewhere")
	scene.free()
	feed.queue_free()
	_done += 1
