extends Node

## studio_live_check - the studio as a person works on it while the show stands still ([StudioMedium], [FreeLook]). It holds:
##
## - a thing placed while the show is paused stands where it was placed with no play pressed: the camera's place changed in the live
##   document moves the camera, the tripod staying (control: before the change, where the studio stands it);
## - another version of a make used (a refine's, a version picked in the 3D view) is another choice and stands at once, no restart; the
##   ring light is listed on the Environment card (the camera not) and shines at its share there;
## - an act that goes on under the words is laid in windows from where it begins to where it ends, its motion made that far;
## - a paused show looked over: the eye turned by a look holds while paused, frame after frame (control: the show's own eye before);
## - once the show plays, the eye eases back to the show's own - most of the way within a few seconds, never in one frame.
##
##   tests/run_boot_probe.sh tests/studio/studio_live_check.gd 120

## A feed whose pause the gate holds.
class HeldFeed extends ShowFeed:
	var held := true
	var at := 4.0

	func paused() -> bool:
		return held

	func show_time() -> float:
		return at


var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	Library.root = "user://studio_live_check"
	var makes := {}
	for pair in [["camera", "vlog_camera"], ["tripod", "tripod"], ["microphone", "microphone"], ["ring_light", "ring_light"]]:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/studio/%s.prop.json" % pair[1]))
		ThingLibrary.keep(d["thing"], d["materials"], String(d.get("line", "")), true)
		makes[pair[0]] = {"kept": String((d["thing"] as Dictionary)["name"])}
	var stage := SubViewport.new()
	stage.size = Vector2i(320, 180)
	stage.own_world_3d = true
	add_child(stage)
	var medium := StudioMedium.new()
	var feed := HeldFeed.new()
	medium.mount(stage)
	# (after mounting, which hands it the show's own)
	medium.feed = feed
	var subs: Subtitles = preload("res://src/show/subtitles.gd").new()
	subs.words = [{"text": "Hello.", "t0": 1.0, "t1": 1.4, "sentence": 0, "emph": 0, "speaker": ""}]
	subs.document = {"source": "Hello.", "title": "Live", "medium": {"makes": makes}}
	add_child(subs)
	medium.bind_captions(subs)
	# stood, paused at one moment
	await _frames(medium, 240, func() -> bool: return not medium._set.is_empty())
	var rigs: Dictionary = medium._set.get("rigs", {})
	_ok(rigs.has("camera") and rigs.has("tripod"), "the studio stands, paused")
	if not rigs.has("camera"):
		_end()
		return
	var cam_was: Vector3 = (rigs["camera"] as PropRig).node.position
	var tri_was: Vector3 = (rigs["tripod"] as PropRig).node.position
	# the camera placed in the live document while paused: no play pressed
	(subs.document["medium"] as Dictionary)["places"] = {"camera": {"y": -4.0}}
	await _frames(medium, 240, func() -> bool: return medium._set.get("rigs", {}).has("camera") and not ((medium._set["rigs"] as Dictionary)["camera"] as PropRig).node.position.is_equal_approx(cam_was))
	var now: Dictionary = medium._set.get("rigs", {})
	_ok(now.has("camera") and is_equal_approx(snappedf(((now["camera"] as PropRig).node.position - cam_was).y, 0.001), -0.04)
		and ((now["tripod"] as PropRig).node.position).is_equal_approx(tri_was), "a thing placed while paused stands there with no play pressed, alone (control: where it stood before)")
	# another version of the camera used: stood at once, no restart
	var cam_name := String((makes["camera"] as Dictionary)["kept"])
	var e := ThingLibrary.read(cam_name)
	var bigger: Dictionary = (e["thing"] as Dictionary).duplicate(true)
	bigger["scale"] = 1.5
	var why: Array = []
	var vi := ThingLibrary.add_version(cam_name, bigger, e["materials"], "bigger", "the gate", why)
	ThingLibrary.use_version(cam_name, vi)
	var box_was := StudioScene.box_of(((medium._set["rigs"] as Dictionary)["camera"] as PropRig).node).size
	((subs.document["medium"] as Dictionary)["makes"] as Dictionary)["camera"] = PropMakes.chosen({"kept": cam_name})
	await _frames(medium, 240, func() -> bool: return medium._set.get("rigs", {}).has("camera") and not StudioScene.box_of(((medium._set["rigs"] as Dictionary)["camera"] as PropRig).node).size.is_equal_approx(box_was))
	var box_now := StudioScene.box_of(((medium._set["rigs"] as Dictionary)["camera"] as PropRig).node).size
	_ok(vi >= 0 and box_now.length() > box_was.length() * 1.2, "another version of a make used stands at once, no restart (%s, was %s)" % [str(box_now), str(box_was)])
	# a choice carries the version used: another version used is another choice
	var card := StudioFormat.for_note({})
	card.choose("camera", {"kept": cam_name})
	card.choose("ring_light", makes["ring_light"])
	var v0 := String(card.make_of("camera").get("v", ""))
	var ce := ThingLibrary.read(cam_name)
	var wider: Dictionary = (ce["thing"] as Dictionary).duplicate(true)
	wider["scale"] = 1.2
	var cwhy: Array = []
	ThingLibrary.use_version(cam_name, ThingLibrary.add_version(cam_name, wider, ce["materials"], "wider", "the gate", cwhy))
	var told := StudioProps.new(card).refined("role:camera", cam_name)
	_ok(not v0.is_empty() and told.is_empty() and String(card.make_of("camera").get("v", "")) != v0 and String(card.make_of("camera")["kept"]) == cam_name,
		"a make chosen carries its version used; another version used (a refine's, one picked in 3D) is another choice")
	# the studio's things that throw light, for the Environment card: the ring light, not the camera (control)
	var lit_keys := StudioProps.new(card).lit().map(func(t: Dictionary) -> String: return String(t["key"]))
	_ok(lit_keys.has("ring_light") and not lit_keys.has("camera"), "the ring light is on the Environment card, the camera not (%s)" % str(lit_keys))
	card.free()
	# the Environment card's share of the ring light's light
	var ring: PropRig = (medium._set["rigs"] as Dictionary).get("ring_light")
	var full := _energy(ring)
	subs.document["environment"] = {"lights": {"ring_light": 0.25}}
	await _frames(medium, 5, func() -> bool: return false)
	var dim := _energy((medium._set["rigs"] as Dictionary).get("ring_light"))
	_ok(full > 0.0 and is_equal_approx(snappedf(dim / full, 0.01), 0.25), "the ring light shines at its share on the Environment card (%.2f of %.2f)" % [dim, full])
	# an act that goes on under the words: its windows laid from where it begins, none past where it ends, made as far as that
	var said := "Hello there.\n<!-- rub: fur, left hand -->\n" + "and on and on we go together ".repeat(12) + "\n<!-- /rub -->\nGoodbye now."
	subs.words = StudioScript.rehearsal(StudioScript.parse(said))
	subs.document["source"] = said
	await _frames(medium, 600, func() -> bool: return medium._made.size() == 1 and medium._made[0] != null and medium._keys[0] != null)
	var placed: Array = medium._sounds._placed
	var t0 := medium._t0[0]
	var t1 := medium._t1[0]
	var last_w: float = placed.reduce(func(m: float, p: Dictionary) -> float: return maxf(m, float(p["t0"])), -1.0)
	_ok(t0 < INF and t1 < INF and t1 - t0 > 20.0 and placed.size() >= 3 and is_equal_approx(float((placed[0] as Dictionary)["t0"]), t0)
		and last_w <= t1 + StudioSounds.RELEASE and float((medium._made[0] as Dictionary)["secs"]) >= t1 - t0,
		"an act under the words is laid in windows from where it begins (%.1f s) to where it ends (%.1f s), made that far (%d windows)" % [t0, t1, placed.size()])
	# looked over while paused: held
	await _frames(medium, 3, func() -> bool: return false)
	var own: Transform3D = medium._cam.transform
	medium.look_by(0.6, 0.2, 1.5)
	await _frames(medium, 3, func() -> bool: return false)
	var turned: Transform3D = medium._cam.transform
	var t_was := medium._now
	await _frames(medium, 30, func() -> bool: return false)
	var drift := medium._cam.transform.origin.distance_to(turned.origin)
	_ok(turned.origin.distance_to(own.origin) > 0.1 and drift < 0.003,
		"a paused show looked over: the eye turned holds while paused (%.3f m from the show's own; it drifts %.4f m, its clock %.3f s)" % [turned.origin.distance_to(own.origin), drift, medium._now - t_was])
	# played: eased back, never in a frame
	feed.held = false
	medium.advance(null, 0.05, 1.0)
	var first_step := medium._cam.transform.origin.distance_to(turned.origin)
	for i in 80:
		medium.advance(null, 0.05, 1.0)
	var left := medium._cam.transform.origin.distance_to(own.origin)
	_ok(first_step < turned.origin.distance_to(own.origin) * 0.2 and left < turned.origin.distance_to(own.origin) * 0.05,
		"once it plays the eye eases back: %.3f m in its first frame, %.3f m left after four seconds" % [first_step, left])
	medium.release()
	_end()


## All the light [param rig]'s lights throw now.
func _energy(rig: PropRig) -> float:
	var out := 0.0
	if rig == null:
		return out
	for l in rig.node.find_children("*", "Light3D", true, false):
		out += (l as Light3D).light_energy
	return out


## Up to [param n] frames of the medium advanced with no time passing (paused), until [param done] says so.
func _frames(medium: StudioMedium, n: int, done: Callable) -> void:
	for i in n:
		medium.advance(null, 0.0, 1.0)
		if done.call():
			return
		await get_tree().process_frame


func _end() -> void:
	for f in DirAccess.get_files_at(ThingLibrary.dir()):
		DirAccess.remove_absolute(ThingLibrary.dir().path_join(f))
	Library.root = Library.ROOT
	print("studio_live_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	get_tree().quit(1 if _fails > 0 else 0)
