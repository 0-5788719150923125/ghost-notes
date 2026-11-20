extends SceneTree

## Gate for what a seek costs the dispatch desk ([DispatchMedium]): a seek starts the reading again part way and hands the
## desk the same note, and every sentence that lands after it makes the desk's plan again. It holds:
##
## - a reading started inside a walk sounds its own sweeps only: the radar ticks once a sweep from where the leg began,
##   which a mid-way start places far in the past ([constant ReadingFollower.START_PAST]), so its sound plan has the
##   ticks from the reading's first moment to the ping and none before it (the control: every sweep of the leg, counted
##   from where it began, is tens of thousands);
## - the same note handed again is read once: what was read of it is the one object, each glass's words still on its
##   block and each picture's move its span's (the control: other words are read anew);
## - more of the reading heard far ahead of the playhead leaves the plan as it stands, and it is made again once the
##   reading comes within [constant DispatchMedium.PLAN_AHEAD] of what it knows (the control: a gate's and a render's
##   desk makes it at once);
## - the same picture files handed again stay up as they are (the controls: another file, and the same one written
##   again, are decoded anew).
##
## Run: godot --headless --path . --script tests/dispatch/dispatch_seek_check.gd

const DIR := "user://dispatch_seek_check"
const BODY := ("He is in his room, and it is quiet there tonight.\n\n<!-- ping: his room | 200, 0.6 -->\n\n"
	+ "Nothing moves for a while, and the light in the hall is off.\n\n<!-- moving -->\n\n"
	+ "He is up and walking, past the doors, past the laundry room, toward the end of the hall where the stairs go down, "
	+ "and he does not hurry, and he does not look back at the room he left.\n\n<!-- ping: the stairwell | 180, 3 -->\n\n"
	+ "He stands there a while, and then he goes down.\n\n```terminal\n> subjects\nSUBJECTS\n  one on file\n```\n\n"
	+ "That is all the desk knows of him tonight.\n")

var _fails: Array = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var parsed := DispatchScript.parse(BODY)
	var words := DispatchScript.rehearsal(parsed, 0.32)
	var spoken: PackedStringArray = parsed["spoken"]
	var st := SubViewport.new()
	st.size = Vector2i(320, 180)
	st.own_world_3d = true
	root.add_child(st)
	var md := DispatchMedium.new()
	md.feed = ShowFeed.new()
	md.mount(st)
	# a reading started inside the walk: after he sets off, before the ping he arrives with
	var k := spoken.find("laundry")
	var since := float((words[k] as Dictionary)["t0"])
	var later: Array = []
	for w in words.slice(k):
		var d: Dictionary = (w as Dictionary).duplicate()
		d["t0"] = float(d["t0"]) - since
		d["t1"] = float(d["t1"]) - since
		later.append(d)
	md.load_note(BODY, {"seed": 3}, spoken.slice(k, k + 8), k, since)
	md._now = 0.0
	md.take_words(later)
	var arrive := -1
	var set_off := -1
	for i in md._actions.size():
		if String(md._actions[i]["kind"]) == "moving":
			set_off = i
		if String(md._actions[i]["kind"]) == "ping" and String(md._actions[i]["place"]) == "the stairwell":
			arrive = i
	var t_ping := md.starts()[arrive] if arrive >= 0 else INF
	var began := INF
	for leg in md._legs:
		if int((leg as Dictionary)["i"]) == arrive:
			began = float(leg["t0"])
	var ticks := md.sound_plan().filter(func(x: Dictionary) -> bool: return String(x.get("what", "")) == "tick")
	var early := ticks.filter(func(x: Dictionary) -> bool: return float(x["t"]) < 0.0).size()
	var own := md.passes(0.0, t_ping).size()
	var every := md.passes(began, t_ping).size() if began < INF else 0
	_ok(md._follower.start_si == k and set_off >= 0 and int(md._actions[set_off]["after"]) < k and t_ping > 2.0 * DispatchMedium.SWEEP
			and t_ping < INF and began < -1000.0,
		"the reading starts inside the walk: he set off before it, far in the past, and arrives in it (leg from %.0f s, ping at %.1f s)" % [began, t_ping])
	_ok(early == 0 and ticks.size() == own and own >= 1 and every > 1000,
		"a walk begun before a mid-way start ticks through the reading's own sweeps (%d ticks, %d before the start, %d sweeps of its own; the control, every sweep of the leg, %d)"
			% [ticks.size(), early, own, every])
	# the same note again, started somewhere else: read once
	var read: Dictionary = md._parsed
	var glass := 0
	for a in md._actions:
		if String((a as Dictionary)["kind"]) == "session" and int((a as Dictionary).get("words", 0)) > 0:
			glass += 1
	var k2 := spoken.find("hurry")
	md.load_note(BODY, {"seed": 3}, spoken.slice(k2, k2 + 8), k2, float((words[k2] as Dictionary)["t0"]))
	var kept: bool = is_same(md._parsed, read)
	var glass2 := 0
	for a in md._actions:
		if String((a as Dictionary)["kind"]) == "session" and int((a as Dictionary).get("words", 0)) > 0:
			glass2 += 1
	md.load_note(BODY + "\nAnd one more sentence, written since.\n", {"seed": 3})
	_ok(kept and glass >= 1 and glass2 == glass and not is_same(md._parsed, read)
			and (md._parsed["spoken"] as PackedStringArray).size() > spoken.size(),
		"the same note handed again is read once, each glass's words kept (kept %s, %d and %d glasses with words; the control, other words, read anew %s)"
			% [str(kept), glass, glass2, str(not is_same(md._parsed, read))])
	# more of the reading heard far ahead of the playhead: in the app the plan stands until the reading nears what it knows
	md.load_note(BODY, {"seed": 3})
	md._now = 0.0
	var some := words.slice(0, spoken.find("Nothing"))
	md.take_words(some)
	var first_made := md._sound_rev
	var room_known: float = md._known_to
	DispatchMedium.away_in_tests = true
	md._now = room_known - DispatchMedium.PLAN_AHEAD - 5.0
	md.take_words(words)
	var stood := md._sound_rev == first_made and md._built_n == some.size()
	md._now = room_known - DispatchMedium.PLAN_AHEAD + 1.0
	md.take_words(words)
	var near := md._sound_rev > first_made and md._built_n == words.size()
	DispatchMedium.away_in_tests = false
	md.load_note(BODY + "\n", {"seed": 3})
	md._now = 0.0
	md.take_words(some)
	var gate_made := md._sound_rev
	md._now = room_known - DispatchMedium.PLAN_AHEAD - 5.0
	md.take_words(words)
	_ok(room_known > 0.0 and room_known < INF and stood and near and md._sound_rev > gate_made and md._built_n == words.size(),
		"more heard far ahead leaves the plan as it stands, and it is made again as the reading nears what it knows (stood %s, made again %s; the control, a gate's desk, makes it at once %s)"
			% [str(stood), str(near), str(md._sound_rev > gate_made)])
	# the same pictures again: left up
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var a_path := ProjectSettings.globalize_path(DIR).path_join("a.png")
	var b_path := ProjectSettings.globalize_path(DIR).path_join("b.png")
	_picture(a_path, Color(0.8, 0.2, 0.2))
	_picture(b_path, Color(0.2, 0.2, 0.8))
	md.load_note(BODY, {"seed": 3, "pictures": {"one": a_path}})
	var up: Texture2D = md._pictures.get("one")
	md.load_note(BODY, {"seed": 3, "pictures": {"one": a_path}}, spoken.slice(k, k + 8), k, since)
	var same: bool = up != null and md._pictures.get("one") == up
	md.load_note(BODY, {"seed": 3, "pictures": {"one": b_path}})
	var other: Texture2D = md._pictures.get("one")
	# written again: the file's time is what says so, and a time is whole seconds
	OS.delay_msec(1100)
	_picture(b_path, Color(0.2, 0.8, 0.2))
	md.load_note(BODY, {"seed": 3, "pictures": {"one": b_path}})
	var again: Texture2D = md._pictures.get("one")
	_ok(same and other != null and other != up and again != null and again != other,
		"the same picture files handed again stay up (kept %s; the controls: another file decoded %s, the same one written again decoded %s)"
			% [str(same), str(other != null and other != up), str(again != null and again != other)])
	md.queue_free()
	for f in [a_path, b_path]:
		DirAccess.remove_absolute(f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))
	if _fails.is_empty():
		print("dispatch_seek_check: ALL OK")
		quit(0)
	else:
		for f in _fails:
			print("dispatch_seek_check: FAIL  " + f)
		quit(1)


func _picture(path: String, color: Color) -> void:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(color)
	img.save_png(path)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
